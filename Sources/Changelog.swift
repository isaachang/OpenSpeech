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
        return groups.map { tr("\($0.title) \($0.items.count) 项", "\($0.items.count) \($0.title.lowercased())") }.joined(separator: " · ")
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
    /// 中文界面取每条中文 “：” 或 “。” 之前的短标题；英文界面取条目下面缩进的英文那一行（或同一行 “。” 后面的英文）。
    /// 第一行 `>` 是中文总结，第二行 `>` 是英文总结。0.1.0 之前的开发记录不显示。
    static func parse(_ text: String, chinese: Bool = Lang.isChinese) -> [ChangelogEntry] {
        var out: [ChangelogEntry] = []
        var cur: ChangelogEntry?
        var summaries: [String] = []
        /// 上一条中文条目刚加进来，下一行缩进的英文可以替换它
        var awaitingEnglish = false
        func flush() {
            if var c = cur {
                c.summary = chinese ? summaries.first : (summaries.count > 1 ? summaries[1] : summaries.first)
                out.append(c)
            }
            cur = nil
            summaries = []
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                if let m = line.firstMatch(of: #/^## \[(\d+\.\d+\.\d+[^\]]*)\]\s*-?\s*(.*)$/#) {
                    cur = ChangelogEntry(version: String(m.1), date: String(m.2))
                }
                awaitingEnglish = false
                continue
            }
            guard var c = cur else { continue }
            defer { cur = c }
            if line.hasPrefix("### ") {
                let words = line.dropFirst(4).split(separator: " ")
                let zh = String(words.first ?? "")
                let en = words.count > 1 ? words.dropFirst().joined(separator: " ") : zh
                c.groups.append(.init(title: chinese ? zh : en, kind: kind(of: zh), items: []))
                awaitingEnglish = false
            } else if line.hasPrefix("> ") {
                summaries.append(String(line.dropFirst(2)))
            } else if raw.hasPrefix("- "), !c.groups.isEmpty {
                let item = String(line.dropFirst(2))
                var shown = headline(item)
                if !chinese, let r = item.range(of: "。"), item[r.upperBound...].contains(where: { $0.isASCII && $0.isLetter }) {
                    shown = englishHeadline(String(item[r.upperBound...]))
                }
                c.groups[c.groups.count - 1].items.append(shown)
                awaitingEnglish = !chinese
            } else if awaitingEnglish, raw.hasPrefix("  "), !line.isEmpty, !c.groups.isEmpty, var g = c.groups.last, !g.items.isEmpty {
                g.items[g.items.count - 1] = englishHeadline(line)
                c.groups[c.groups.count - 1] = g
                awaitingEnglish = false
            } else {
                awaitingEnglish = false
            }
        }
        flush()
        return out
    }

    /// 英文条目：第一句够短就整句，太长就只留冒号前面
    static func englishHeadline(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        let end = t.range(of: ". ")?.lowerBound ?? t.range(of: "; ")?.lowerBound ?? t.endIndex
        var sentence = String(t[..<end])
        if sentence.hasSuffix(".") { sentence.removeLast() }
        if sentence.count <= 72 { return sentence }
        // 太长：在冒号、逗号或括号处截断，读起来还是完整的一句
        for sep in [":", ", ", " ("] {
            if let r = sentence.range(of: sep), sentence.distance(from: sentence.startIndex, to: r.lowerBound) >= 12,
               sentence.distance(from: sentence.startIndex, to: r.lowerBound) <= 72 {
                return String(sentence[..<r.lowerBound])
            }
        }
        return String(sentence.prefix(70)) + "…"
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
