import Foundation
var failures = 0
func check(_ name: String, _ ok: Bool, _ info: String) { print(ok ? "✅" : "❌", name, info); if !ok { failures += 1 } }

let script = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
let p = ParsedScript.parse(script)
func pos(of s: String) -> Int {   // 稿子里第一次出现 s 的 unit 下标
  let t = ParsedScript.parse(s, markup: false).units.map(\.text)
  for i in 0...(p.units.count - t.count) where Array(p.units[i..<i+t.count].map(\.text)) == t { return i }
  fatalError("not found \(s)")
}
var clock = 0.0
/// 逐字“说”出 text：模拟识别器 partial 一字一字增长；prefix 是同一段识别里之前已经识别出的文字
func speak(_ tr: inout Tracker, _ text: String, prefix: String = "", log: inout [Int]) {
  var acc = prefix
  for ch in text { acc.append(ch); clock += 0.25
    let u = ParsedScript.parse(acc, markup: false, chineseNumbers: true).units
    _ = tr.process(u, now: clock); log.append(tr.cursor) }
}
func maxStep(_ log: [Int], from: Int) -> Int { var prev = from, mx = 0; for c in log { if c > prev { mx = max(mx, (prev..<c).filter { !p.units[$0].optional }.count) }; prev = c }; return mx }

// 1. 正常朗读 + 同音错字 + 漏字
do { var tr = Tracker(units: p.units); var log: [Int] = []
  speak(&tr, "你有没有过这种经历录一条口播内容早就想好了可一对着镜头脑子就一片空白", log: &log)
  speak(&tr, "于是你把稿子放在屏幕边上眼睛一会看搞一会儿看镜头", log: &log)   // 漏“儿”，稿→搞
  let exp = pos(of: "看镜头，观众") + 3
  check("正常朗读带错字", abs(tr.cursor - exp) <= 1, "cursor=\(tr.cursor) exp=\(exp) maxStep=\(maxStep(log, from: 0))")
  check("正常朗读不会大跳", maxStep(log, from: 0) <= 3, "")
}
// 2. 重开识别后只有两三个字（常见词），不应该往后跳
do { var tr = Tracker(units: p.units); let start = pos(of: "你讲快"); tr.reset(to: start); var log: [Int] = []
  speak(&tr, "你讲快", log: &log)   // 新识别段，开头就三个字；“它就”“你讲”后面都还会出现
  check("短尾巴不乱跳", tr.cursor <= start + 3, "cursor=\(tr.cursor) start=\(start)")
  speak(&tr, "它就跟着快你讲慢它就慢慢等你", prefix: "你讲快", log: &log)
  let exp = pos(of: "慢慢等你") + 4
  check("重复句式跟得住", abs(tr.cursor - exp) <= 1, "cursor=\(tr.cursor) exp=\(exp) maxStep=\(maxStep(log, from: start))")
}
// 3. 跳过一句：产品策略是不自动跳（中间那句没念过），等用户手动翻
do { var tr = Tracker(units: p.units); let s = pos(of: "今天给你介绍"); tr.reset(to: s); var log: [Int] = []
  speak(&tr, "它把你Mac上的那块刘海变成了一个提词器", log: &log)
  // 不能跳到错误的位置：要么停在原地，要么跟到真正在念的地方（“提词器”之后）
  let truth = pos(of: "提词器") + 3
  check("跳过一句：不跳错", tr.cursor <= s + 2 || abs(tr.cursor - truth) <= 2, "cursor=\(tr.cursor) start=\(s) truth=\(truth)")
}
// 4. 脱稿闲聊：位置不动
do { var tr = Tracker(units: p.units); let s = pos(of: "但它最厉害"); tr.reset(to: s); var log: [Int] = []
  speak(&tr, "哎呀不好意思我刚才说错了重新来一遍啊", log: &log)
  check("脱稿不乱动", tr.cursor == s, "cursor=\(tr.cursor) start=\(s)")
}
// 5. 自由发挥时说到了后面段落的话：不自动跳
do { var tr = Tracker(units: p.units); let s = pos(of: "但它最厉害"); tr.reset(to: s); var log: [Int] = []
  speak(&tr, "嗯这个我们等下再说", log: &log)
  speak(&tr, "用起来也很简单把稿子拖到刘海上按一下开始然后开口说话就行了", log: &log)
  check("说到后面段落：不自动跳", tr.cursor <= s + 2, "cursor=\(tr.cursor) start=\(s)")
}
// 6. 数字两种写法
do { let s2 = "我们在2024年做了3个版本，转化率提升了50%。然后在二零二五年又做了十二个实验。"
  let q = ParsedScript.parse(s2); var tr = Tracker(units: q.units); clock = 100
  var acc = ""; for ch in "我们在二零二四年做了三个版本转化率提升了百分之五十" { acc.append(ch); clock += 0.25; _ = tr.process(ParsedScript.parse(acc, markup:false, chineseNumbers: true).units, now: clock) }
  check("稿子阿拉伯数字 / 念中文", tr.cursor == q.units.firstIndex { $0.text == "然" }!, "cursor=\(tr.cursor)")
  acc = ""; for ch in "然后在2025年又做了12个实验" { acc.append(ch); clock += 0.25; _ = tr.process(ParsedScript.parse(acc, markup:false, chineseNumbers: true).units, now: clock) }
  check("稿子中文数字 / 识别成阿拉伯", tr.cursor == q.units.count, "cursor=\(tr.cursor) total=\(q.units.count)")
}
// 7. 多音字：识别出同音不同字
do { let s3 = "我们去银行取钱，然后还要还书。"; let q = ParsedScript.parse(s3); var tr = Tracker(units: q.units)
  var acc = ""; for ch in "我们去银杭取钱然后孩要环书" { acc.append(ch); clock += 0.25; _ = tr.process(ParsedScript.parse(acc, markup:false).units, now: clock) }
  check("多音字/同音字", tr.cursor >= q.units.count - 1, "cursor=\(tr.cursor) total=\(q.units.count)")
}
// 8. 讲到后面自由发挥，说了一句和开头很像的话：不能跳回开头
do { var tr = Tracker(units: p.units); let s = pos(of: "最后说个小秘密"); tr.reset(to: s); var log: [Int] = []
  speak(&tr, "其实你有没有过这种经历录一条口播内容早就想好了可一对着镜头脑子就一片空白对吧", log: &log)
  check("后段复述前文不回跳", tr.cursor >= s, "cursor=\(tr.cursor) start=\(s)")
}
// 9. 刚才那句重说一遍：允许小范围退回
do { var tr = Tracker(units: p.units); let s = pos(of: "不用踩踏板"); tr.reset(to: s + 14); var log: [Int] = []
  speak(&tr, "不用踩踏板不用请人帮你滚屏", log: &log)
  check("重说上一句能退回", abs(tr.cursor - (pos(of: "帮你滚屏") + 4)) <= 1, "cursor=\(tr.cursor) exp=\(pos(of: "帮你滚屏") + 4)")
}
// 10. 识别卡了一下、一口气补上一大段（你是一路念过来的）：要能跟上
do { var tr = Tracker(units: p.units); let s = pos(of: "它把你"); tr.reset(to: s); clock += 10
  let u = ParsedScript.parse("它把你Mac上的那块刘海变成了一个", markup: false, chineseNumbers: true).units
  _ = tr.process(u, now: clock)
  check("一口气补上一段能跟上", tr.cursor >= pos(of: "变成了一个") + 4, "cursor=\(tr.cursor) exp≥\(pos(of: "变成了一个") + 4)")
}
// 11. 识别漏听了一大段（念过来了但识别得很差），恢复后要追上去
do { var tr = Tracker(units: p.units); let s = pos(of: "你讲快"); tr.reset(to: s); clock += 10
  // 中间那段识别得很烂（同音错字、漏字），但大体是念过来的
  let bad = "你讲快他就跟着快你讲慢他就慢慢等你你停下来喝口水他就安静停在原地就算你临时跳过一句"
  var acc = ""; for ch in bad { acc.append(ch); clock += 0.25; _ = tr.process(ParsedScript.parse(acc, markup: false, chineseNumbers: true).units, now: clock) }
  check("识别很烂但念过来了：能追上", tr.cursor >= pos(of: "跳过一句") , "cursor=\(tr.cursor) exp≥\(pos(of: "跳过一句"))")
}
print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
