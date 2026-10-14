import Foundation
// ===== 全新稿件（不是调参时用过的稿子）=====
let scripts: [(String, String)] = [
("zh-早餐", "【微笑】今天我们聊一聊早餐。很多人觉得早餐随便吃点就行，其实不吃早餐或者乱吃，对一整天的精力影响非常大。第一，早餐要有蛋白质，比如一个鸡蛋、一杯牛奶，或者一小块豆腐。第二，主食尽量选粗粮，燕麦、玉米、红薯都很好，它们升糖慢，能让你一上午都不容易饿。第三，别忘了蔬菜和水果，一根黄瓜、半个苹果，就能补充维生素和膳食纤维。【停顿】很多上班族说早上太赶了，来不及做。我的建议是前一天晚上准备好，比如把燕麦泡上，第二天早上加点水果就能吃。坚持两周，你会发现上午的状态完全不一样。如果你觉得有用，记得点赞收藏，我们下期再见。"),
("zh-理财", "大家好，这期视频聊聊年轻人怎么开始理财。先说结论：不要一上来就追求高收益。第一步，是建立应急资金，一般建议准备三到六个月的生活费，放在随时能取出来的地方。第二步，了解自己的风险承受能力，问问自己，如果账户亏了百分之二十，你能不能睡得着觉。第三步，才是选择具体的产品，比如指数基金、债券基金，或者银行的定期存款。很多人喜欢听朋友推荐，今天买这个明天换那个，结果手续费交了不少，钱却没赚到。理财最重要的是长期和纪律，每个月固定投入一部分工资，时间会帮你做很多事情。我自己从2020年开始定投，到现在已经坚持了5年。最后提醒一句，任何承诺稳赚不赔的产品，都要特别小心。我们下期见。"),
("en-morning", "Hey everyone, welcome back. Today I want to share three simple habits that completely changed my mornings. First, I stopped checking my phone for the first thirty minutes after waking up. Instead of scrolling through emails and news, I drink a glass of water and open the curtains. It sounds small, but it gives my brain a calm start. Second, I write down the one thing that matters most today. Not a long to do list, just one clear priority. When the day gets busy, I always know what to protect. Third, I move my body for ten minutes. It can be a short walk, a few stretches, or some push ups. The goal is not fitness, it is energy. [pause] I have been doing this for six months now, and my focus at work is noticeably better. Try it for one week and let me know how it goes in the comments. See you next time."),
("en-coding", "If you are thinking about learning to code this year, here is the honest advice I wish someone had given me. Do not start by comparing programming languages for weeks. Pick one, Python is a great choice, and build something tiny on day one. A calculator, a to do app, anything that runs. You will learn more from fixing your own bugs than from watching ten hours of tutorials. Next, learn to read error messages carefully. Most beginners panic and copy the error into a search engine without reading it. The message usually tells you exactly which line is broken. Then, share your work early. Put your projects on GitHub, ask for feedback, and do not worry about looking clever. Finally, be patient with yourself. Everyone feels lost in the first few months. That feeling is not a sign that you are bad at this. It is a sign that you are learning. Good luck, and I will see you in the next video."),
]
let fillerZH = ["对吧", "其实我想说的是", "这个我们后面再讲", "嗯怎么说呢", "大家可以想一想", "我觉得这一点特别重要", "说实话", "就是这样", "你们有没有遇到过"]
let fillerEN = ["you know", "to be honest", "let me think about it", "that is really important", "anyway", "I mean", "right", "if that makes sense"]

struct RNG { var s: UInt64
  mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
  mutating func d() -> Double { Double(next() >> 11) / Double(1 << 53) }
  mutating func chance(_ p: Double) -> Bool { d() < p }
  mutating func int(_ a: Int, _ b: Int) -> Int { a + Int(next() % UInt64(b - a + 1)) }
  mutating func r(_ a: Double, _ b: Double) -> Double { a + (b - a) * d() } }

// 同音字表（从所有稿子的汉字里按拼音分组）
var byKey: [String: [String]] = [:]
for (_, s) in scripts { for u in ParsedScript.parse(s).units where !u.isWord { if !(byKey[u.key]?.contains(u.text) ?? false) { byKey[u.key, default: []].append(u.text) } } }
let allChars = byKey.values.flatMap { $0 }
let allWords = scripts.filter { $0.0.hasPrefix("en") }.flatMap { ParsedScript.parse($0.1).units.map(\.text) }

struct Item { let text: String; let idx: Int?; let t: Double; let dur: Double; var heard: [String] }
struct Result { var adlibAhead = 0; var stall = 0; var surge = 0; var talkN = 0; var absErr = 0.0; var n = 0; var ahead = 0; var behind = 0; var wrongJumps = 0; var bigBack = 0; var catchups: [Double] = []; var lineAhead = 0 }

func run(_ name: String, _ text: String, seed: UInt64) -> Result {
  var g = RNG(s: seed)
  let p = ParsedScript.parse(text); let latin = p.isMostlyLatin
  // 按句切分
  var sentences: [[Int]] = []; var cur: [Int] = []
  for i in 0..<p.units.count { cur.append(i); if p.breakAfter[i] { sentences.append(cur); cur = [] } }; if !cur.isEmpty { sentences.append(cur) }
  // ===== 生成“你说的话” =====
  var items: [Item] = []; var t = 1.0; var skips: [(Double, Int)] = []; var adlibAhead = 0
  func say(_ txt: String, _ idx: Int?, _ rate: Double) { let du = 1 / rate * g.r(0.8, 1.2); items.append(Item(text: txt, idx: idx, t: t, dur: du, heard: [])); t += du }
  for (si, s) in sentences.enumerated() {
    let rate = latin ? g.r(1.9, 3.3) : g.r(3.2, 5.6)
    if si > 0 && si < sentences.count - 1 && g.chance(0.07) { skips.append((t, s.last! + 1)); continue }            // 跳过一句
    if g.chance(0.18) {                                                                                            // 自由发挥
      let words: [String]
      let roll = g.d()
      if roll < 0.3 && s.first! > 30 { let a = g.int(0, s.first! - 15); words = (a..<(a + g.int(6, 12))).map { p.units[$0].text } }  // 复述前文（往回跳的陷阱）
      else if roll < 0.8 && s.last! + 30 < p.units.count { let a = min(p.units.count - 11, s.last! + g.int(20, 80)); words = (a..<(a + g.int(4, 10))).map { p.units[$0].text }; adlibAhead += 1 }  // 自由发挥时说到后面的词（往前跳的陷阱）
      else { let f = (latin ? fillerEN : fillerZH)[g.int(0, (latin ? fillerEN : fillerZH).count - 1)]; words = ParsedScript.parse(f, markup: false).units.map(\.text) }
      for w in words { say(w, nil, rate) }; t += g.r(0.2, 0.6) }
    let para = g.chance(0.10)
    for i in s { if p.units[i].optional && g.chance(0.7) { continue }
      if para && g.chance(0.35) { say(latin ? allWords[g.int(0, allWords.count - 1)] : allChars[g.int(0, allChars.count - 1)], i, rate) } else { say(p.units[i].text, i, rate) } }
    if g.chance(0.05) && s.count > 6 { let k = g.int(4, min(8, s.count)); for i in s.suffix(k) { say(p.units[i].text, i, rate) } }   // 重说
    t += g.r(0.25, 1.0)
  }
  // 识别错误（每个词一次性决定）
  for i in items.indices { var h = [items[i].text]
    if g.chance(0.07) { if latin { h = [allWords[g.int(0, allWords.count - 1)]] } else { let k = Pinyin.key(Character(items[i].text)); let c = byKey[k] ?? []; h = [c.count > 1 && g.chance(0.7) ? c[g.int(0, c.count - 1)] : allChars[g.int(0, allChars.count - 1)]] } }
    else if g.chance(0.03) { h = [] } else if g.chance(0.02) { h.append(latin ? "uh" : "嗯") }
    items[i].heard = h }
  func truth(_ now: Double) -> Int { var v = 0; for it in items where it.t <= now { if let i = it.idx { v = i + 1 } }; return v }
  func speaking(_ now: Double) -> Bool { items.contains { now >= $0.t && now < $0.t + $0.dur } }
  // ===== 跑引擎 =====
  let (e, _) = makeEngine(); e.audioDisabled = true
  e.start(script: Script(title: name, body: text)); let t0 = 1000.0; e.simulateListening(at: t0)
  var res = Result(); var now = 0.0; var nl = 0.0; var nextPartial = 1.2; var segStart = 0.0; var lastItemT = 0.0
  var pendingSkip: (Double, Int)? = nil; var si = 0; var lastAnchor = 0
  func lineOf(_ u: Int) -> Int { for (i, l) in e.lines.enumerated() where l.unitRange.contains(u) || l.unitRange.lowerBound > u { return i }; return e.lines.count - 1 }
  var prevLA = false; var prevC = 0.0
  let nominal = latin ? 2.6 : 4.4
  let end = t + 1.5
  while now < end { now += 1.0 / 120
    if now >= nl { nl = now + 1.0 / 43; e.handleLevel(speaking(now) ? -24 : -66, at: t0 + now) }
    if now >= nextPartial {
      let lag = g.r(0.25, 0.7)
      let heardItems = items.filter { $0.t >= segStart && $0.t + $0.dur <= now - lag + 0.2 }
      if let last = heardItems.last, last.t > lastItemT || g.chance(0.15) {
        // 停顿超过 0.6 秒，识别器有一半概率重新开一段（只给碎片）
        if last.t - lastItemT > 0.6 + 0.24 && lastItemT > 0 && g.chance(0.5) { segStart = last.t - 0.001 }
        let seg = items.filter { $0.t >= segStart && $0.t + $0.dur <= now - lag + 0.2 }
        var words = seg.flatMap { $0.heard }
        if words.count > 140 { segStart = last.t - 0.001; words = Array(words.suffix(3)) }
        if !words.isEmpty && g.chance(0.1) { words[words.count - 1] = latin ? allWords[g.int(0, allWords.count - 1)] : allChars[g.int(0, allChars.count - 1)] }  // 末尾抖动
        e.handleTranscript(words.joined(separator: latin ? " " : ""), primary: true, at: t0 + now)
        lastItemT = last.t
      }
      nextPartial = now + g.r(0.2, 0.45)
    }
    e.tick(at: t0 + now)
    // ===== 记分 =====
    let vel = (e.cursor - prevC) * 120; prevC = e.cursor
    let onScriptTalk = items.contains { now >= $0.t && now < $0.t + $0.dur && $0.idx != nil } && now > 2
    if onScriptTalk { res.talkN += 1; if vel < 0.5 { res.stall += 1 }; if vel > nominal * 3 { res.surge += 1 } }
    let tr = truth(now), c = Int(e.cursor), a = Int(e.debugAnchor)
    if a != lastAnchor { let mv = a - lastAnchor
      if abs(mv) > 4 && a - tr > 6 { res.wrongJumps += 1   // 往前跑到了你还没念到的地方
        if ProcessInfo.processInfo.environment["NC_DEBUG_FOOL"] != nil {
          let said = items.filter { $0.t <= now && $0.t > now - 4 }.map { ($0.idx == nil ? "[" : "") + $0.text + ($0.idx == nil ? "]" : "") }.joined()
          func ctx(_ i: Int) -> String { let lo = max(0, i - 6), hi = min(p.units.count, i + 2); return p.units[lo..<i].map(\.text).joined() + "|" + p.units[i..<hi].map(\.text).joined() }
          print("FOOLED \(name) seed \(seed) t=\(String(format: "%.1f", now)) \(lastAnchor)→\(a) 真实=\(tr) 位置:\(ctx(a)) 真实:\(ctx(tr)) 最近说的：\(said)")
        } }
      if mv < -15 { res.bigBack += 1 }
      lastAnchor = a }
    while si < skips.count && skips[si].0 <= now { pendingSkip = (now, skips[si].1); si += 1 }
    // 产品策略：跳段不自动跟。模拟用户 1.5 秒后发现并手动拖到正确位置（之后的指标照常统计）
    if let ps = pendingSkip, now - ps.0 >= 1.5 { if Int(e.debugAnchor) < truth(now) - 3 { e.debugSetPosition(Double(truth(now))); lastAnchor = Int(e.debugAnchor) }; res.catchups.append(1.5); pendingSkip = nil }
    if tr > 0 && tr < p.units.count - 2 { res.n += 1; let err = c - tr; res.absErr += Double(abs(err)); if err > 3 { res.ahead += 1 }; if err < -5 { res.behind += 1 }
      let la = lineOf(c) > lineOf(max(0, tr - 1)) && c > tr + 1; if la && !prevLA { res.lineAhead += 1 }; prevLA = la }
  }
  res.adlibAhead = adlibAhead
  return res
}

let variant = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "all"
switch variant {
case let v where v.hasPrefix("cov="): Tracker.catchUpCoverage = Double(v.dropFirst(4))!
case "-onset": PrompterEngine.onsetPredict = false
case "-linecap": PrompterEngine.lineCap = false
case "-carry": PrompterEngine.carryContext = false
case "-predict": PrompterEngine.predictionEnabled = false
default: break }
var tot = Result(); var perLang: [String: Result] = [:]
for (name, text) in scripts { for seed in 1...8 {
  let r = run(name, text, seed: UInt64(seed) &* 7919 &+ UInt64(name.count))
  for k in [name.hasPrefix("en") ? "EN" : "ZH", "ALL"] { var a = perLang[k] ?? Result(); a.absErr += r.absErr; a.n += r.n; a.ahead += r.ahead; a.behind += r.behind; a.wrongJumps += r.wrongJumps; a.bigBack += r.bigBack; a.catchups += r.catchups; a.lineAhead += r.lineAhead; a.adlibAhead += r.adlibAhead; a.stall += r.stall; a.surge += r.surge; a.talkN += r.talkN; perLang[k] = a } } }
for k in ["ZH", "EN", "ALL"] { let r = perLang[k]!; let c = r.catchups.sorted()
  print(String(format: "%-10@ %@ 平均偏差 %.2f · 超前>3 %.1f%% · 落后>5 %.1f%% · 被骗往前跑 %d 次(陷阱 %d 次) · 大回退 %d · (跳段=手动) %.2f/%.2f · 抢先换行 %d · 说话时停顿感 %.1f%% · 窜动感 %.1f%%", variant, k, r.absErr / Double(r.n), Double(r.ahead) * 100 / Double(r.n), Double(r.behind) * 100 / Double(r.n), r.wrongJumps, r.adlibAhead, r.bigBack, c.isEmpty ? 0 : c[c.count / 2], c.isEmpty ? 0 : c[min(c.count - 1, c.count * 9 / 10)], r.lineAhead, Double(r.stall) * 100 / Double(max(1, r.talkN)), Double(r.surge) * 100 / Double(max(1, r.talkN)))) }
