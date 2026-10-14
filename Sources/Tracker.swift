import Foundation

/// 把语音识别的实时文字对齐到稿子上，算出“讲到哪了”。
///
/// 思路和业界的语音跟随提词器一致：语音识别 → 与稿子做模糊对齐 → 带置信度门槛地移动位置。
/// 产品原则：**只跟“一路念过来”的前进，不自动跳。**
/// 自由发挥时很容易说出稿子后面（或前面）出现过的词，一旦跳过去就回不来，所以：
/// - 小步前进（中文 ≤6 字 / 英文 ≤4 词）：对得上就走；
/// - 稍大的前进（识别一口气补上好几个字）：只有当“从当前位置到新位置”这一路大部分都对上了，才算你念过来了；
/// - 中间一大段没念过（跳段 / 自由发挥）：原地不动，等你回到稿子上，或手动 ⌥⌘↓ / 双指滑动；
/// - 往回：只允许退回十几个字（“刚才那句重说”），并且要持续被确认。

struct Tracker {
    struct Decision {
        enum Kind: String { case advance, back, pending, hold, miss }
        let kind: Kind
        let pos: Int
        let raw: Double
        let m: Int
    }

    let units: [SpeechUnit]
    let isLatin: Bool
    private(set) var cursor = 0
    private var pending: (pos: Int, time: Double, sig: String, count: Int, first: Double)?
    /// 最多允许自动退回多少个单位
    var maxBack: Int { isLatin ? 8 : 15 }

    /// 不用确认就能直接前进的最大步长：中文 6 个字，英文 4 个词（都约 1.5 秒）
    var smallStep: Int { isLatin ? 4 : 6 }

    /// rank[i] = 第 i 个单位之前有几个必须念的单位；算距离时不把【】里的可选字算进去
    private let rank: [Int]

    init(units: [SpeechUnit], isLatin: Bool = false) {
        self.units = units
        self.isLatin = isLatin
        var r = [0]
        for u in units { r.append(r.last! + (u.optional ? 0 : 1)) }
        rank = r
    }

    private func dist(_ from: Int, _ to: Int) -> Int {
        rank[max(0, min(to, units.count))] - rank[max(0, min(from, units.count))]
    }

    mutating func reset(to pos: Int) {
        cursor = max(0, min(pos, units.count))
        pending = nil
    }

    static func sim(_ a: SpeechUnit, _ b: SpeechUnit) -> Double {
        if a.text == b.text { return 1 }
        if a.isWord != b.isWord { return 0 }
        if a.isWord {
            if a.key == b.key { return 0.9 }
            if a.key.count > 3 && b.key.count > 3 && a.key.prefix(4) == b.key.prefix(4) { return 0.5 }
            return 0
        }
        if a.key == b.key || a.alts.contains(b.key) || b.alts.contains(a.key) { return 0.85 }
        // 读音很像：韵母相同，或声母相同且韵母只差介音（ian/an、uan/an、iao/ao…）
        if !a.fin.isEmpty && a.fin == b.fin { return 0.35 }
        if !a.ini.isEmpty && a.ini == b.ini && (a.fin.hasSuffix(b.fin) || b.fin.hasSuffix(a.fin)) { return 0.35 }
        return 0
    }

    mutating func process(_ transcript: [SpeechUnit], now: Double) -> Decision {
        let m = min(transcript.count, 12)
        guard m >= 2, !units.isEmpty else { return Decision(kind: .hold, pos: cursor, raw: 0, m: m) }
        let tail = Array(transcript.suffix(m))
        let sig = transcript.suffix(4).map(\.text).joined(separator: " ")

        // 尾巴越短，越只看眼前；门槛按“对上了几个字”算（最多按 8 个计），前面接上的旧文字只帮忙对位
        let ahead = m >= 6 ? 150 : (m >= 4 ? 12 : 8)
        let mCap = Double(min(m, 8))
        let nearNeed = m >= 4 ? max(2.4, mCap * 0.4) : Double(m) * 0.8
        guard let b = bestMatch(tail, lo: cursor - 20, hi: cursor + ahead), b.raw >= nearNeed else {
            return Decision(kind: .miss, pos: cursor, raw: 0, m: m)
        }
        let newPos = b.e + 1
        let d = newPos == cursor ? 0 : (dist(cursor, newPos) == 0 && newPos > cursor ? 1 : dist(cursor, newPos))
        if d == 0 {
            pending = nil
            return Decision(kind: .hold, pos: cursor, raw: b.raw, m: m)
        }
        if d >= -1 && d <= smallStep {
            pending = nil
            cursor = newPos
            return Decision(kind: .advance, pos: newPos, raw: b.raw, m: m)
        }
        if d > 0 {
            // 前进了好几个字：要求“从当前位置到新位置”这一路在识别结果里出现过（你是念过来的）。
            // - 识别卡了一下又一次补上 / 识别漏听了一段：这一路多少都能对上 → 跟上去
            // - 跳段 / 自由发挥时说到了后面的词：中间那段根本没念过 → 不动
            let heard = Array(transcript.suffix(min(transcript.count, d + 12)))
            let path = pathScore(heard, from: cursor, to: b.e)
            if d <= readThrough && path >= Double(d) * 0.6 {
                pending = nil
                cursor = newPos
                return Decision(kind: .advance, pos: newPos, raw: path, m: m)
            }
            // 这一路没有那么完整（临场改了几个字、识别漏了一段）：至少 3 成对上、终点那几个字要清楚，
            // 并且两次识别都这么认为，才追上去。近处和远处用同一条规则，避免“近的反而更难走”的死区
            if m >= 6 && b.raw >= 4.0 && path >= Double(d) * Self.catchUpCoverage {
                return confirmForward(to: newPos, raw: path, m: m, now: now, sig: sig)
            }
            return Decision(kind: .hold, pos: cursor, raw: path, m: m)
        }
        if d < 0 && m >= 4 && b.raw >= mCap * 0.75 {
            return confirmBack(to: newPos, raw: b.raw, m: m, now: now, sig: sig)
        }
        // 前方很远 / 中间没念过：不跳，原地等
        return Decision(kind: .hold, pos: cursor, raw: b.raw, m: m)
    }

    /// 远距离追赶时，这一路至少要有多少比例在识别结果里出现过
    static var catchUpCoverage = 0.3
    /// 一口气“念过来”不需要二次确认的最大距离：中文 16 字，英文 10 词
    var readThrough: Int { isLatin ? 10 : 16 }

    /// 从 from 到 to 这一路稿子，被识别结果覆盖了多少（对上 +分，稿子里被跳过的字 −0.3）
    private func pathScore(_ a: [SpeechUnit], from: Int, to e: Int) -> Double {
        let s0 = max(0, from)
        guard e >= s0, !a.isEmpty else { return 0 }
        let n = e - s0 + 1, m = a.count
        // dp[j]：稿子前 j 个（从 s0 起）都要被覆盖；识别结果前面的部分可以不计
        var prev = [Double](repeating: 0, count: n + 1)
        for j in 1...n { prev[j] = prev[j - 1] - (units[s0 + j - 1].optional ? 0 : 0.3) }
        var cur = prev
        var best = prev[n] - 0.15 * Double(m)
        for i in 1...m {
            cur[0] = 0
            for j in 1...n {
                let s = Self.sim(a[i - 1], units[s0 + j - 1])
                let skip = units[s0 + j - 1].optional ? 0.0 : 0.3
                cur[j] = max(prev[j - 1] + (s > 0 ? s : -0.4), prev[j] - 0.15, cur[j - 1] - skip)
            }
            best = max(best, cur[n] - 0.15 * Double(m - i))
            swap(&prev, &cur)
        }
        return best
    }

    /// 远距离追赶：两次不同的识别结果都指向同一处（第二次允许又往前念了几个字）
    private mutating func confirmForward(to pos: Int, raw: Double, m: Int, now: Double, sig: String) -> Decision {
        if let p = pending, p.pos > cursor, now - p.time < 2.5, p.sig != sig, pos >= p.pos - 2, pos <= p.pos + 12 {
            pending = nil
            cursor = pos
            return Decision(kind: .advance, pos: pos, raw: raw, m: m)
        }
        if pending == nil || pending!.sig != sig || abs(pending!.pos - pos) > 2 {
            pending = (pos, now, sig, 1, now)
        }
        return Decision(kind: .pending, pos: pos, raw: raw, m: m)
    }

    /// 往回（“刚才那句重说”）：只在十几个字以内，并且要 3 次不同的识别结果、持续 1.2 秒以上都指向那里
    private mutating func confirmBack(to pos: Int, raw: Double, m: Int, now: Double, sig: String) -> Decision {
        if dist(pos, cursor) > maxBack { return Decision(kind: .hold, pos: cursor, raw: raw, m: m) }
        if var p = pending, now - p.time < 2.5, p.sig != sig, pos >= p.pos - 2, pos <= p.pos + 12 {
            p.count += 1
            p.pos = pos
            p.time = now
            p.sig = sig
            if p.count >= 3 && now - p.first >= 1.2 {
                pending = nil
                cursor = pos
                return Decision(kind: .back, pos: pos, raw: raw, m: m)
            }
            pending = p
            return Decision(kind: .pending, pos: pos, raw: raw, m: m)
        }
        if pending == nil || pending!.sig != sig || abs(pending!.pos - pos) > 2 {
            pending = (pos, now, sig, 1, now)
        }
        return Decision(kind: .pending, pos: pos, raw: raw, m: m)
    }

    /// 在 [lo, hi] 里找最佳结尾点 e（离当前位置越远先验越低）
    private func bestMatch(_ tail: [SpeechUnit], lo: Int, hi: Int) -> (e: Int, raw: Double)? {
        let lo = max(0, lo)
        let hi = min(units.count - 1, hi)
        guard lo <= hi else { return nil }
        let step = smallStep
        var cands: [(e: Int, score: Double, raw: Double)] = []
        for e in lo...hi {
            // 结尾必须和最近 3 个识别单位之一对得上，否则不考虑
            var endOK = false
            for t in tail.suffix(3) where Self.sim(units[e], t) >= 0.5 { endOK = true; break }
            if !endOK { continue }
            let raw = align(tail, end: e)
            let d = dist(cursor, e + 1)
            let penalty: Double
            if d >= 0 {
                penalty = d <= step ? Double(d) * 0.01 : 0.06 + Double(d - step) * 0.03
            } else {
                penalty = 0.6 + Double(-d) * 0.05
            }
            cands.append((e, raw - penalty, raw))
        }
        guard let best = cands.max(by: { $0.score < $1.score }) else { return nil }
        return (best.e, best.raw)
    }

    /// 局部对齐，要求以稿子第 e 个单位结尾。
    /// 对上 +sim；稿子里跳过一个 −0.3（【】里的可选字不扣）；识别多出一个 −0.15；对错 −0.4；尾巴前面对不上的部分不计分。
    private func align(_ a: [SpeechUnit], end e: Int) -> Double {
        let m = a.count
        let s0 = max(0, e - (m + 6) + 1)
        let n = e - s0 + 1
        var prev = [Double](repeating: 0, count: n + 1)
        var cur = prev
        var best = 0.0
        for i in 1...m {
            cur[0] = 0
            for j in 1...n {
                let s = Self.sim(a[i - 1], units[s0 + j - 1])
                let diag = prev[j - 1] + (s > 0 ? s : -0.4)
                let skip = units[s0 + j - 1].optional ? 0.0 : 0.3
                cur[j] = max(0, diag, prev[j] - 0.15, cur[j - 1] - skip)
            }
            // 尾巴最后几个还没对上的识别单位（多说的、识别错的）各扣 0.15
            best = max(best, cur[n] - 0.15 * Double(m - i))
            swap(&prev, &cur)
        }
        return best
    }
}
