import Foundation

/// `OpenPitch --replay <session.jsonl>`：用当前版本的算法回放一次真实的跟随日志，
/// 打印跳转统计，方便对比调参前后的效果。
enum ReplayTool {
    static func run(path: String) {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { print("读不到文件"); return }
        var script: String?
        var events: [(t: Double, text: String, primary: Bool)] = []
        var manual: [(t: Double, pos: Int)] = []
        for line in text.split(separator: "\n") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let ev = obj["ev"] as? String, let t = obj["t"] as? Double else { continue }
            switch ev {
            case "start": script = obj["script"] as? String
            case "tr": if let s = obj["text"] as? String { events.append((t, s, obj["p"] as? Bool ?? true)) }
            case "manual": if let p = obj["pos"] as? Int { manual.append((t, p)) }
            default: break
            }
        }
        guard let script else { print("日志里没有稿子"); return }
        let parsed = ParsedScript.parse(script)
        var tr = Tracker(units: parsed.units, isLatin: parsed.isMostlyLatin)
        var counts: [String: Int] = [:]
        var bigJumps: [String] = []
        var mi = 0
        for e in events {
            while mi < manual.count && manual[mi].t <= e.t { tr.reset(to: manual[mi].pos); mi += 1 }
            let before = tr.cursor
            let d = tr.process(ParsedScript.parse(e.text, markup: false, chineseNumbers: !parsed.isMostlyLatin).units, now: e.t)
            counts[d.kind.rawValue, default: 0] += 1
            if abs(tr.cursor - before) > tr.smallStep {
                bigJumps.append(String(format: "  %7.2fs  %4d → %4d  (%@)  “…%@”", e.t, before, tr.cursor, d.kind.rawValue, String(e.text.suffix(14))))
            }
        }
        print("稿子 \(parsed.units.count) 字，识别结果 \(events.count) 条，最终位置 \(tr.cursor)")
        print("判断分布：", counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "  "))
        print("大跳（>\(tr.smallStep) 字）\(bigJumps.count) 次：")
        bigJumps.forEach { print($0) }
    }
}
