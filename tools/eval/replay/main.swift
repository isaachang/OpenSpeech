import Foundation
let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/OpenPitch/logs")
var TS = 0, TU = 0, TV = 0; var TA = 0, TB = 0, TL = 0, TN = 0; var lat: [Double] = []; var slowLat = 0
for f in try! FileManager.default.contentsOfDirectory(atPath: dir).sorted() where f.hasSuffix(".jsonl") {
  let lines = try! String(contentsOfFile: dir + "/" + f, encoding: .utf8).split(separator: "\n")
  var script = ""; var evs: [(t: Double, kind: String, text: String, on: Bool, pos: Int)] = []
  for l in lines { guard let o = try? JSONSerialization.jsonObject(with: Data(l.utf8)) as? [String: Any], let ev = o["ev"] as? String, let t = o["t"] as? Double else { continue }
    if ev == "start" { script = o["script"] as! String; if (o["mode"] as? String) != "voice" { script = "" } }
    if ev == "tr" { evs.append((t, "tr", o["text"] as! String, o["p"] as? Bool ?? true, 0)) }
    if ev == "vad" { evs.append((t, "vad", "", o["on"] as! Bool, 0)) }
    if ev == "manual" { evs.append((t, "manual", "", false, o["pos"] as! Int)) } }
  if script.isEmpty || !evs.contains(where: { $0.kind == "tr" }) { continue }
  let (e, s) = makeEngine()
  e.audioDisabled = true
  e.start(script: Script(title: "r", body: script))
  let t0 = 1000.0; e.simulateListening(at: t0)
  let p = ParsedScript.parse(script)
  func lineOf(_ u: Int) -> Int { let ls = e.lines; for (i, l) in ls.enumerated() where l.unitRange.contains(u) || l.unitRange.lowerBound > u { return i }; return ls.count - 1 }
  var voice = false, now = 0.0, idx = 0, nextLevel = 0.0
  var n = 0, ahead = 0, behind = 0, lineAhead = 0
  var lastO = -1, skipAt: Double? = nil, skipTarget = 0
  let end = evs.last!.t + 1; var prevC = 0.0; let nominal = p.isMostlyLatin ? 2.6 : 4.4
  while now < end {
    now += 1.0 / 120
    while idx < evs.count && evs[idx].t <= now {
      let ev = evs[idx]; idx += 1
      if ev.kind == "vad" { voice = ev.on }
      if ev.kind == "manual" { e.debugJump(to: ev.pos) }
      if ev.kind == "tr" {
        e.handleTranscript(ev.text, primary: ev.on, at: t0 + now)
        let u = ParsedScript.parse(ev.text, markup: false, chineseNumbers: !p.isMostlyLatin).units
        if let (o, _) = oracle(u, p.units) {
          // 评估点稍后 0.15s（让显示层有时间反应）
          let c = Int(e.cursor)
          n += 1
          if c > o + 3 { ahead += 1 }
          if c < o - 4 { behind += 1 }
          if lineOf(c) > lineOf(max(0, o - 1)) && c > o + 1 { lineAhead += 1 }
          if lastO >= 0 && o - lastO > 10 && skipAt == nil { skipAt = now; skipTarget = o }
          lastO = o
        }
      }
    }
    if let sa = skipAt, Int(e.cursor) >= skipTarget - 3 { lat.append(now - sa); skipAt = nil }
    if let sa = skipAt, now - sa > 8 { lat.append(8); skipAt = nil }
    if now >= nextLevel { nextLevel = now + 1.0 / 43; e.handleLevel(voice ? -24 : -66, at: t0 + now) }
    e.tick(at: t0 + now)
    let vel = (e.cursor - prevC) * 120; prevC = e.cursor
    if voice && now > 2 { TV += 1; if vel < 0.5 { TS += 1 }; if vel > nominal * 3 { TU += 1 } }
  }
  TA += ahead; TB += behind; TL += lineAhead; TN += n
  print(String(format: "%@ %@ 显示超前>3 %4.1f%% · 落后>4 %4.1f%% · 抢先换行 %3d 次 / %d", String(f.dropFirst(17).prefix(6)), p.isMostlyLatin ? "EN" : "ZH", Double(ahead) * 100 / Double(n), Double(behind) * 100 / Double(n), lineAhead, n))
  _ = s
}
lat.sort(); let med = lat.isEmpty ? 0 : lat[lat.count / 2]
print(String(format: "跳段 %d 次：跟上用时 中位数 %.2fs · 最慢 %.2fs · 超过 1.5 秒的 %d 次", lat.count, med, lat.last ?? 0, lat.filter { $0 > 1.5 }.count))
print(String(format: "说话时停顿感 %.1f%% · 窜动感 %.1f%%", Double(TS) * 100 / Double(TV), Double(TU) * 100 / Double(TV)))
print(String(format: "合计：显示超前>3 %.1f%% · 落后>4 %.1f%% · 抢先换行 %d 次 / %d 条", Double(TA) * 100 / Double(TN), Double(TB) * 100 / Double(TN), TL, TN))
