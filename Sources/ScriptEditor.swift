import AppKit
import SwiftUI

/// 主窗口的稿件编辑区：存的还是纯文本 Markdown，但边写边排版（和 Typora / Obsidian 一样）——
/// `# ` 大标题、`## ` 中标题、`### ` 小标题，`**重点**` 加粗，【导演提示】橙色。
/// # 和 ** 这些标记平时藏起来，光标所在的那一行才淡淡显示，方便改。
struct ScriptEditor: NSViewRepresentable {
    @Binding var text: String
    /// 换稿件时把光标和滚动位置放回开头
    var documentID: UUID?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let tv = ScriptTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.textContainerInset = NSSize(width: 10, height: 14)
        tv.insertionPointColor = NSColor(Theme.ink)
        tv.typingAttributes = MarkdownStyle.body
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = tv

        tv.string = text
        MarkdownStyle.apply(to: tv)
        context.coordinator.lastID = documentID
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? ScriptTextView, !tv.hasMarkedText() else { return }
        if tv.string != text {
            tv.string = text
            MarkdownStyle.apply(to: tv)
        }
        if context.coordinator.lastID != documentID {
            context.coordinator.lastID = documentID
            tv.setSelectedRange(NSRange(location: 0, length: 0))
            tv.scroll(.zero)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScriptEditor
        var lastID: UUID?
        /// 上次显示标记的是哪几行：光标换到别的行才需要重新上色
        private var revealed = NSRange(location: NSNotFound, length: 0)

        init(_ parent: ScriptEditor) { self.parent = parent }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            // 拼音还没选字时不动排版，免得打断输入法
            if !tv.hasMarkedText() { revealed = MarkdownStyle.apply(to: tv) }
            if parent.text != tv.string { parent.text = tv.string }
        }

        func textViewDidChangeSelection(_ n: Notification) {
            guard let tv = n.object as? NSTextView, !tv.hasMarkedText() else { return }
            let lines = (tv.string as NSString).lineRange(for: tv.selectedRange())
            if lines != revealed { revealed = MarkdownStyle.apply(to: tv) }
        }
    }
}

/// 编辑区的 NSTextView：⌘⌥1 / 2 / 3 把当前行变成大 / 中 / 小标题，⌘⌥0 变回正文（和 Notion 一样）
final class ScriptTextView: NSTextView {
    @objc func setHeading1(_ sender: Any?) { setHeading(1) }
    @objc func setHeading2(_ sender: Any?) { setHeading(2) }
    @objc func setHeading3(_ sender: Any?) { setHeading(3) }
    @objc func setBodyText(_ sender: Any?) { setHeading(0) }

    override func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(setHeading1(_:)), #selector(setHeading2(_:)), #selector(setHeading3(_:)), #selector(setBodyText(_:)):
            return isEditable
        default:
            return super.validateMenuItem(item)
        }
    }

    /// 选中的每一行：去掉原来的 #，按需要加上新的
    func setHeading(_ level: Int) {
        let ns = string as NSString
        let lines = ns.lineRange(for: selectedRange())
        var out: [String] = []
        ns.substring(with: lines).enumerateLines { line, _ in
            let body = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
            out.append(level == 0 ? body : String(repeating: "#", count: level) + " " + body)
        }
        var new = out.joined(separator: "\n")
        if ns.substring(with: lines).hasSuffix("\n") { new += "\n" }
        guard shouldChangeText(in: lines, replacementString: new) else { return }
        textStorage?.replaceCharacters(in: lines, with: new)
        didChangeText()
        let end = lines.location + (new as NSString).length - (new.hasSuffix("\n") ? 1 : 0)
        setSelectedRange(NSRange(location: end, length: 0))
    }
}

enum MarkdownStyle {
    static let bodySize: CGFloat = 15

    private static func para(spacingBefore: CGFloat = 0, lineSpacing: CGFloat = 6) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = lineSpacing
        p.paragraphSpacingBefore = spacingBefore
        p.paragraphSpacing = 2
        return p
    }

    static let body: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: bodySize),
        .foregroundColor: NSColor(Theme.ink),
        .paragraphStyle: para(),
    ]

    /// 大 / 中 / 小标题的字号和字重
    private static func headingFont(_ level: Int) -> NSFont {
        switch level {
        case 1: return .systemFont(ofSize: 26, weight: .bold)
        case 2: return .systemFont(ofSize: 20, weight: .bold)
        default: return .systemFont(ofSize: 17, weight: .semibold)
        }
    }

    private static let heading = try! NSRegularExpression(pattern: #"^( {0,3}(#{1,6}) )(.*)$"#, options: .anchorsMatchLines)
    private static let bold = try! NSRegularExpression(pattern: #"(\*\*)(.+?)(\*\*)"#)
    private static let cue = try! NSRegularExpression(pattern: #"【[^】\n]*】|\[[^\]\n]*\]"#)

    /// 藏起来的标记：透明、几乎没有宽度（字还在，只是看不见，存下来的仍是标准 Markdown）
    private static let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.clear, .font: NSFont.systemFont(ofSize: 0.1)]

    /// 整篇重新上色（只改样式，不改文字，所以撤销、光标都不受影响）。返回这次显示标记的行
    @discardableResult
    static func apply(to tv: NSTextView) -> NSRange {
        guard let storage = tv.textStorage else { return NSRange(location: NSNotFound, length: 0) }
        let s = storage.string
        let all = NSRange(location: 0, length: (s as NSString).length)
        let marker = NSColor(Theme.ink3)
        // 光标（或选中范围）所在的行：这几行的标记淡淡显示，其他行藏起来
        let reveal = (s as NSString).lineRange(for: tv.selectedRange())
        func shows(_ r: NSRange) -> Bool { NSIntersectionRange(r, reveal).length > 0 || NSLocationInRange(r.location, reveal) }
        storage.beginEditing()
        storage.setAttributes(body, range: all)
        heading.enumerateMatches(in: s, range: all) { m, _, _ in
            guard let m else { return }
            let level = min(3, m.range(at: 2).length)
            storage.addAttributes([.font: headingFont(level),
                                   .paragraphStyle: para(spacingBefore: level == 1 ? 14 : 10, lineSpacing: 4)], range: m.range)
            // 前面的 # 和空格：光标在这一行时浅灰、小一点；不在时藏起来，只剩干净的标题
            if shows(m.range) {
                storage.addAttributes([.foregroundColor: marker, .font: NSFont.systemFont(ofSize: headingFont(level).pointSize * 0.8, weight: .medium)],
                                      range: m.range(at: 1))
            } else {
                storage.addAttributes(hidden, range: m.range(at: 1))
            }
        }
        bold.enumerateMatches(in: s, range: all) { m, _, _ in
            guard let m else { return }
            let f = (storage.attribute(.font, at: m.range(at: 2).location, effectiveRange: nil) as? NSFont) ?? .systemFont(ofSize: bodySize)
            storage.addAttribute(.font, value: NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask), range: m.range(at: 2))
            if shows(m.range) {
                storage.addAttribute(.foregroundColor, value: marker, range: m.range(at: 1))
                storage.addAttribute(.foregroundColor, value: marker, range: m.range(at: 3))
            } else {
                storage.addAttributes(hidden, range: m.range(at: 1))
                storage.addAttributes(hidden, range: m.range(at: 3))
            }
        }
        cue.enumerateMatches(in: s, range: all) { m, _, _ in
            guard let m else { return }
            storage.addAttribute(.foregroundColor, value: NSColor(Theme.cueInk), range: m.range)
        }
        storage.endEditing()
        tv.typingAttributes = body
        return reveal
    }
}
