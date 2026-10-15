import Foundation

/// CHANGELOG.md 里的一个版本，给「版本日志」卡片和更新提示用
struct ChangelogEntry: Identifiable, Equatable {
    enum Kind { case added, changed, fixed, removed }

    struct Group: Equatable {
        let title: String
        let kind: Kind
        var items: [String]
    }

    let version: String
    let date: String
    var summary: String?
    var groups: [Group] = []
    var id: String { version }

    /// 短标题列表（更新横幅上的“英文跟读更准 · 修复 3 个问题”）
    var shortLine: String {
        if let summary { return summary }
        return groups.map { "\($0.title) \($0.items.count) 项" }.joined(separator: " · ")
    }
}

enum Changelog {
    /// App 里打包的 CHANGELOG.md
    static func bundled() -> [ChangelogEntry] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    /// 解析 Keep a Changelog 格式：`## [x.y.z] - 日期`、`> 一句话总结`、`### 新增 Added`、`- 条目`。
    /// 每条只取中文部分 “：” 或 “。” 之前的短标题；英文缩进行和 0.1.0 之前的开发记录不显示。
    static func parse(_ text: String) -> [ChangelogEntry] {
        var out: [ChangelogEntry] = []
        var cur: ChangelogEntry?
        func flush() { if let c = cur { out.append(c) }; cur = nil }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                if let m = line.firstMatch(of: #/^## \[(\d+\.\d+\.\d+[^\]]*)\]\s*-?\s*(.*)$/#) {
                    cur = ChangelogEntry(version: String(m.1), date: String(m.2))
                }
                continue
            }
            guard cur != nil else { continue }
            if line.hasPrefix("### ") {
                let title = String(line.dropFirst(4).split(separator: " ").first ?? "")
                cur?.groups.append(.init(title: title, kind: kind(of: title), items: []))
            } else if line.hasPrefix("> ") {
                cur?.summary = String(line.dropFirst(2))
            } else if raw.hasPrefix("- "), var c = cur, !c.groups.isEmpty {
                c.groups[c.groups.count - 1].items.append(headline(String(line.dropFirst(2))))
                cur = c
            }
        }
        flush()
        return out
    }

    private static func kind(of title: String) -> ChangelogEntry.Kind {
        switch title {
        case "新增": return .added
        case "修复": return .fixed
        case "移除": return .removed
        default: return .changed
        }
    }

    /// 第一句够短就整句显示（“产品改名：OpenPitch → OpenSpeech”），太长就只留冒号前面（“界面极简化”）
    static func headline(_ s: String) -> String {
        let sentence = s[..<(s.firstIndex(of: "。") ?? s.endIndex)]
        if sentence.count <= 28 { return sentence.trimmingCharacters(in: .whitespaces) }
        let cut = sentence.firstIndex(of: "：") ?? sentence.endIndex
        return String(sentence[..<cut]).trimmingCharacters(in: .whitespaces)
    }
}
