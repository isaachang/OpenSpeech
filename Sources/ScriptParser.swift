import Foundation

/// 一个“可被念出来”的单位：中文按单字，英文按单词。
struct SpeechUnit: Equatable {
    let text: String
    /// 用于模糊匹配的 key：中文为去声调 + 模糊音后的拼音，英文为小写单词
    let key: String
    let isWord: Bool
    /// 多音字的其他读音（同样做过模糊音归并）
    var alts: [String] = []
    /// 声母 / 韵母（只对中文有效），用于“读音很像”的部分得分
    var ini: Substring = ""
    var fin: Substring = ""
    /// 【】/[] 里的字：念了能对上，不念也可以直接跳过
    var optional = false

    static func cjk(_ c: Character, keys: Bool) -> SpeechUnit {
        guard keys else { return SpeechUnit(text: String(c), key: String(c), isWord: false) }
        let all = Pinyin.keys(c)
        let k = all[0]
        let (i, f) = Pinyin.split(k)
        return SpeechUnit(text: String(c), key: k, isWord: false, alts: Array(all.dropFirst()), ini: i, fin: f)
    }
}

enum GlyphStyle { case normal, emphasis, cue, heading }

/// 稿子里的 # / ## / ### 标题：只是给自己看的路牌，不用念，跟读时直接跨过去
struct ScriptHeading: Equatable {
    /// 1 = #，2 = ##，3 = ###
    let level: Int
    let title: String
    /// 标题文字在 glyphs 里的位置
    let glyphs: Range<Int>
    /// 标题后面第一个要念的字（跳转到这一段时停在这里）
    let nextUnit: Int
}

/// 屏幕上显示的每个字符
struct Glyph {
    let char: Character
    let isUnit: Bool
    /// 对 unit 字符：所属 unit 下标；对标点/提示等：它前面最后一个 unit 的下标（可能是 -1）
    let unit: Int
    let style: GlyphStyle
}

struct ParsedScript {
    var glyphs: [Glyph] = []
    var units: [SpeechUnit] = []
    /// units[i] 后面是句末（句号、问号、换行…）。预测推进不会越过这些位置。
    var breakAfter: [Bool] = []
    var cjkCount = 0
    var wordCount = 0
    var cueCount = 0
    /// 真正要念的单位数（不含【】里的可选内容）
    var spokenCount: Int { units.count - optionalCount }
    var optionalCount = 0
    /// 最后一个必须念的单位之后的位置（用于判断“讲完了”）
    var spokenEnd: Int { (units.lastIndex { !$0.optional } ?? -1) + 1 }

    var isMostlyLatin: Bool { wordCount > cjkCount }

    var headings: [ScriptHeading] = []

    /// 用来分段、编号、⌥⌘1…9 跳转的那一级标题：有 ## 就用 ##，没有就用 #
    var sectionLevel: Int? { headings.contains { $0.level == 2 } ? 2 : headings.map(\.level).min() }
    var sections: [ScriptHeading] { headings.filter { $0.level == sectionLevel } }

    /// 某个字落在第几段（从 0 开始；在第一个标题之前是 nil）
    func section(at unit: Int) -> Int? {
        sections.lastIndex { $0.nextUnit <= unit }
    }
    var localeID: String { isMostlyLatin ? "en-US" : "zh-CN" }

    /// markup: 解析【导演提示】/[cue] 与 **重音**；keys: 是否计算拼音 key（只统计字数时可关掉）；
    /// chineseNumbers: 阿拉伯数字按中文读法展开（nil = 按文本自动判断）
    static func parse(_ text: String, markup: Bool = true, keys: Bool = true, chineseNumbers: Bool? = nil) -> ParsedScript {
        var p = ParsedScript()
        let chars = Array(text)
        let expandNumbers = chineseNumbers ?? looksChinese(chars)
        var word = ""
        var wordOptional = false
        var inCue = false
        var inEmph = false

        func addUnit(_ u: SpeechUnit) {
            p.units.append(u)
            p.breakAfter.append(false)
        }

        func flush() {
            guard !word.isEmpty else { return }
            let lower = word.lowercased()
            let key = lower.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
            var u = SpeechUnit(text: lower, key: key, isWord: true)
            u.optional = wordOptional
            addUnit(u)
            if wordOptional { p.optionalCount += 1 } else { p.wordCount += 1 }
            word = ""
        }

        var i = 0
        while i < chars.count {
            let c = chars[i]
            // 行首的 # / ## / ###（后面跟空格）：整行是标题，显示但不用念
            if markup && c == "#" && (i == 0 || chars[i - 1].isNewline) {
                var level = 0
                while i + level < chars.count, chars[i + level] == "#" { level += 1 }
                if level <= 6, i + level < chars.count, chars[i + level] == " " || chars[i + level] == "\u{3000}" {
                    flush()
                    var j = i + level
                    while j < chars.count, chars[j] == " " || chars[j] == "\u{3000}" { j += 1 }
                    let g0 = p.glyphs.count
                    var title = ""
                    while j < chars.count, !chars[j].isNewline {
                        p.glyphs.append(Glyph(char: chars[j], isUnit: false, unit: p.units.count - 1, style: .heading))
                        title.append(chars[j])
                        j += 1
                    }
                    if !p.units.isEmpty { p.breakAfter[p.units.count - 1] = true }
                    let t = title.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty {
                        p.headings.append(ScriptHeading(level: level, title: t, glyphs: g0..<p.glyphs.count, nextUnit: p.units.count))
                    }
                    i = j
                    continue
                }
            }
            if c.isNewline {
                // 没闭合的标记不跨段落
                inCue = false
                inEmph = false
            }
            if markup && !inCue && c == "*" && i + 1 < chars.count && chars[i + 1] == "*" {
                flush()
                inEmph.toggle()
                i += 2
                continue
            }
            if markup && !inCue && (c == "【" || c == "[") {
                flush()
                inCue = true
                p.cueCount += 1
            }
            if inCue {
                // 提示里的字也做成可选单位：有人会把【动效】这种关键词念出来
                if ScriptChar.isCJK(c) {
                    flush()
                    var u = SpeechUnit.cjk(c, keys: keys)
                    u.optional = true
                    addUnit(u)
                    p.optionalCount += 1
                    p.glyphs.append(Glyph(char: c, isUnit: true, unit: p.units.count - 1, style: .cue))
                } else if c.isLetter || c.isNumber {
                    if word.isEmpty { wordOptional = true }
                    word.append(c)
                    p.glyphs.append(Glyph(char: c, isUnit: true, unit: p.units.count, style: .cue))
                } else {
                    flush()
                    p.glyphs.append(Glyph(char: c, isUnit: false, unit: p.units.count - 1, style: .cue))
                }
                if c == "】" || c == "]" { inCue = false }
                i += 1
                continue
            }
            let style: GlyphStyle = inEmph ? .emphasis : .normal

            if expandNumbers && word.isEmpty, NumberReading.digit(c) != nil {
                // 2024年 / 3个 / 50% / 3.5 —— 展开成中文读法，和识别结果用同一套规则，两边写法不同也能对上
                var j = i
                var digits = ""
                while j < chars.count {
                    if let d = NumberReading.digit(chars[j]) {
                        digits.append(d)
                    } else if chars[j] == ".", !digits.contains("."), j + 1 < chars.count, NumberReading.digit(chars[j + 1]) != nil {
                        digits.append(".")
                    } else {
                        break
                    }
                    j += 1
                }
                var percent = false
                if j < chars.count, chars[j] == "%" || chars[j] == "％" {
                    percent = true
                    j += 1
                }
                let reading = NumberReading.read(digits, percent: percent, next: j < chars.count ? chars[j] : nil)
                let u0 = p.units.count
                for r in reading {
                    addUnit(.cjk(r, keys: keys))
                    p.cjkCount += 1
                }
                let n = j - i
                let m = reading.count
                for k in 0..<n {
                    let u = u0 + (n == 1 ? m - 1 : k * (m - 1) / (n - 1))
                    p.glyphs.append(Glyph(char: chars[i + k], isUnit: true, unit: u, style: style))
                }
                i = j
                continue
            }

            if ScriptChar.isCJK(c) {
                flush()
                addUnit(.cjk(c, keys: keys))
                p.cjkCount += 1
                p.glyphs.append(Glyph(char: c, isUnit: true, unit: p.units.count - 1, style: style))
            } else if c.isLetter || c.isNumber || ((c == "'" || c == "’") && !word.isEmpty) {
                if word.isEmpty { wordOptional = false }
                word.append(c)
                p.glyphs.append(Glyph(char: c, isUnit: true, unit: p.units.count, style: style))
            } else {
                flush()
                if ScriptChar.isSentenceEnd(c), !p.units.isEmpty { p.breakAfter[p.units.count - 1] = true }
                p.glyphs.append(Glyph(char: c, isUnit: false, unit: p.units.count - 1, style: style))
            }
            i += 1
        }
        flush()
        return p
    }

    private static func looksChinese(_ chars: [Character]) -> Bool {
        var cjk = 0, latin = 0
        for c in chars {
            if ScriptChar.isCJK(c) { cjk += 1 } else if c.isASCII && c.isLetter { latin += 1 }
        }
        // 英文单词按 5 个字母算一个词
        return cjk > 0 && cjk * 5 >= latin
    }
}

enum NumberReading {
    private static let d: [Character] = Array("零一二三四五六七八九")

    /// 半角 / 全角数字 → "0"..."9"
    static func digit(_ c: Character) -> Character? {
        guard let v = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1 else { return nil }
        if (0x30...0x39).contains(v) { return c }
        if (0xFF10...0xFF19).contains(v) { return Character(UnicodeScalar(v - 0xFF10 + 0x30)!) }
        return nil
    }

    static func read(_ s: String, percent: Bool, next: Character?) -> [Character] {
        let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intPart = String(parts[0])
        var out: [Character] = percent ? Array("百分之") : []
        let isYear = !percent && parts.count == 1 && intPart.count == 4 && next == "年"
        if isYear || intPart.count > 8 || (intPart.count > 1 && intPart.hasPrefix("0")) {
            out += intPart.compactMap { $0.wholeNumberValue.map { d[$0] } }
        } else if let n = Int(intPart) {
            out += cardinal(n)
        }
        if parts.count == 2 {
            out.append("点")
            out += parts[1].compactMap { $0.wholeNumberValue.map { d[$0] } }
        }
        return out
    }

    static func cardinal(_ n: Int) -> [Character] {
        if n < 10000 { return small(n, leading: true) }
        let hi = n / 10000, lo = n % 10000
        var out = small(hi, leading: true) + ["万"]
        if lo > 0 {
            if lo < 1000 { out.append("零") }
            out += small(lo, leading: false)
        }
        return out
    }

    private static func small(_ n: Int, leading: Bool) -> [Character] {
        if n == 0 { return ["零"] }
        if n < 10 { return [d[n]] }
        if n < 20 && leading { return n == 10 ? ["十"] : ["十", d[n - 10]] }
        let names: [Character] = ["千", "百", "十"]
        let digits = [n / 1000, (n / 100) % 10, (n / 10) % 10, n % 10]
        var out: [Character] = []
        var zero = false
        var started = false
        for (i, v) in digits.enumerated() {
            if v == 0 {
                if started { zero = true }
                continue
            }
            if zero { out.append("零"); zero = false }
            out.append(d[v])
            if i < 3 { out.append(names[i]) }
            started = true
        }
        return out
    }
}

enum ScriptChar {
    static func isCJK(_ c: Character) -> Bool {
        guard let v = c.unicodeScalars.first?.value else { return false }
        return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v)
            || (0xF900...0xFAFF).contains(v) || (0x20000...0x2EBEF).contains(v)
    }

    static func isLatinWord(_ c: Character) -> Bool {
        (c.isLetter || c.isNumber || c == "'" || c == "’") && !isCJK(c)
    }

    private static let closing: Set<Character> = [
        "，", "。", "！", "？", "、", "；", "：", "”", "’", "）", "》", "」", "』", "】",
        ",", ".", "!", "?", ";", ":", ")", "]", "…", "—", "~", "～",
    ]

    static func isClosingPunct(_ c: Character) -> Bool { closing.contains(c) }

    private static let sentenceEnd: Set<Character> = ["。", "！", "？", "；", "…", "!", "?", ";", "."]

    /// 句末（句号、问号、换行…）：预测推进会停在这里等识别确认
    static func isSentenceEnd(_ c: Character) -> Bool { c.isNewline || sentenceEnd.contains(c) }
}

/// 汉字 → 去声调拼音，并做常见模糊音归并（z/zh、c/ch、s/sh、n/l、前后鼻音），
/// 让识别出的同音字 / 口音也能对上稿子。
enum Pinyin {
    private static var cache: [Character: [String]] = [:]

    /// 系统的拼音转换不看上下文（“银行”会转成 yin xing），常用多音字在这里补上其他读音
    private static let polyphones: [Character: [String]] = [
        "行": ["hang"], "重": ["chong"], "长": ["chang", "zhang"], "乐": ["yue"], "还": ["huan"],
        "得": ["dei"], "地": ["di"], "的": ["di"], "了": ["liao"], "着": ["zhao", "zhuo"],
        "觉": ["jiao"], "调": ["tiao", "diao"], "都": ["du"], "便": ["pian"], "传": ["zhuan"],
        "种": ["chong"], "差": ["chai", "ci"], "大": ["dai"], "和": ["huo", "hu"], "降": ["xiang"],
        "没": ["mo"], "朝": ["zhao"], "藏": ["zang"], "弹": ["tan"], "校": ["jiao"], "系": ["ji"],
        "省": ["xing"], "曾": ["zeng"], "解": ["xie"], "处": ["chu"], "为": ["wei"], "空": ["kong"],
        "数": ["shuo"], "少": ["shao"], "当": ["dang"], "只": ["zhi"], "干": ["gan"], "量": ["liang"],
        "角": ["jue"], "露": ["lou"], "血": ["xie"], "薄": ["bao"], "似": ["shi"], "否": ["pi"],
        "两": ["er"], "二": ["liang"], "哪": ["na"], "那": ["nei"], "这": ["zhei"], "一": ["yao"],
    ]

    static func keys(_ c: Character) -> [String] {
        if let k = cache[c] { return k }
        let m = NSMutableString(string: String(c)) as CFMutableString
        CFStringTransform(m, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(m, nil, kCFStringTransformStripDiacritics, false)
        var out = [normalize((m as String).lowercased().trimmingCharacters(in: .whitespaces))]
        for alt in polyphones[c] ?? [] {
            let k = normalize(alt)
            if !out.contains(k) { out.append(k) }
        }
        cache[c] = out
        return out
    }

    static func key(_ c: Character) -> String { keys(c)[0] }

    private static func normalize(_ raw: String) -> String {
        var s = raw
        for (a, b) in [("zh", "z"), ("ch", "c"), ("sh", "s")] where s.hasPrefix(a) {
            s = b + s.dropFirst(a.count)
        }
        if s.hasPrefix("n") { s = "l" + s.dropFirst() }
        if s.count > 2 && s.hasSuffix("ng") { s = String(s.dropLast()) }
        return s
    }

    private static let initials: Set<Character> = ["b", "p", "m", "f", "d", "t", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w"]

    /// 归并后的拼音拆成声母 + 韵母（归并后声母都只剩一个字母）
    static func split(_ k: String) -> (Substring, Substring) {
        guard let f = k.first, initials.contains(f), k.count > 1 else { return ("", Substring(k)) }
        return (k.prefix(1), k.dropFirst())
    }
}
