import AppKit
import PDFKit

struct Script: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var createdAt = Date()
    var updatedAt = Date()
}

struct ScriptStats {
    let units: Int
    let isLatin: Bool
    let cues: Int

    init(_ body: String) {
        let p = ParsedScript.parse(body, keys: false)
        units = p.spokenCount
        isLatin = p.isMostlyLatin
        cues = p.cueCount
    }

    func duration(speed: Double) -> TimeInterval {
        Double(units) / max(1, isLatin ? speed * 0.6 : speed) * 60
    }

    var countText: String { isLatin ? "\(units) words" : tr("\(units) 字", "\(units) chars") }
}

final class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = [] { didSet { scheduleSave() } }
    @Published var selectedID: UUID?

    private let url: URL?
    private var saveWork: DispatchWorkItem?

    init(inMemory: Bool = false) {
        if inMemory {
            url = nil
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OpenSpeech", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("scripts.json")
        }
        if let url, let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = list
        }
        if scripts.isEmpty {
            // 示例稿跟着界面语言：中文界面三篇（含一篇英文），英文界面两篇英文
            scripts = Lang.isChinese ? [
                Script(title: "示例：OpenSpeech 一分钟介绍", body: SampleScripts.pitch),
                Script(title: "Sample: OpenSpeech in One Minute", body: SampleScripts.pitchEnglish),
                Script(title: "示例：面试故事库（用 ## 分段）", body: SampleScripts.interview),
            ] : [
                Script(title: "Sample: OpenSpeech in One Minute", body: SampleScripts.pitchEnglish),
                Script(title: "Sample: Interview Stories (## sections)", body: SampleScripts.interviewEnglish),
            ]
        }
        selectedID = scripts.first?.id
    }

    var selected: Script? { scripts.first { $0.id == selectedID } }

    func add(_ s: Script) {
        scripts.insert(s, at: 0)
        selectedID = s.id
    }

    /// 刚删掉的那篇：底部 “已删除 · 撤销” 用，几秒后清掉
    @Published private(set) var lastDeleted: DeletedScript?
    /// 稿件菜单里点了 “重命名”：编辑区把光标放到标题上
    @Published var renameRequest: UUID?

    struct DeletedScript: Equatable {
        let script: Script
        let index: Int
    }

    func delete(_ id: UUID) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        lastDeleted = DeletedScript(script: scripts[idx], index: idx)
        scripts.remove(at: idx)
        if selectedID == id {
            selectedID = scripts.isEmpty ? nil : scripts[min(idx, scripts.count - 1)].id
        }
    }

    func undoDelete() {
        guard let d = lastDeleted else { return }
        scripts.insert(d.script, at: min(d.index, scripts.count))
        selectedID = d.script.id
        lastDeleted = nil
    }

    /// 撤销提示自己消失时调用；只清掉还是这一篇的那条
    func forgetDeleted(_ id: UUID) {
        if lastDeleted?.script.id == id { lastDeleted = nil }
    }

    /// 复制一份，放在原稿下面
    func duplicate(_ id: UUID) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        var copy = scripts[idx]
        copy.id = UUID()
        copy.title = tr("\(copy.title) 副本", "\(copy.title) copy")
        copy.createdAt = Date()
        copy.updatedAt = Date()
        scripts.insert(copy, at: idx + 1)
        selectedID = copy.id
    }

    func rename(_ id: UUID) {
        selectedID = id
        renameRequest = id
    }

    func cycleSelection(_ delta: Int) {
        guard !scripts.isEmpty else { return }
        let idx = scripts.firstIndex { $0.id == selectedID } ?? 0
        let n = scripts.count
        selectedID = scripts[((idx + delta) % n + n) % n].id
    }

    /// 返回成功数量与错误信息
    func importFiles(_ urls: [URL]) -> (Int, [String]) {
        var ok = 0
        var errors: [String] = []
        for u in urls {
            do {
                add(try ScriptImporter.load(u))
                ok += 1
            } catch {
                errors.append("\(u.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        return (ok, errors)
    }

    private func scheduleSave() {
        guard let url else { return }
        saveWork?.cancel()
        let snapshot = scripts
        let w = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
        saveWork = w
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: w)
    }
}

enum ScriptImporter {
    static let supportedExtensions = ["txt", "md", "markdown", "rtf", "rtfd", "docx", "doc", "odt", "html", "htm", "pdf"]

    struct ImportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func load(_ url: URL) throws -> Script {
        let ext = url.pathExtension.lowercased()
        var text: String
        switch ext {
        case "pdf":
            guard let doc = PDFDocument(url: url), let s = doc.string else { throw ImportError(message: tr("PDF 里没读到文字（可能是扫描件）", "No text found in the PDF (it may be a scan)")) }
            text = s
        case "docx", "doc", "rtf", "rtfd", "odt", "html", "htm":
            text = try NSAttributedString(url: url, options: [:], documentAttributes: nil).string
        case "md", "markdown":
            text = cleanMarkdown(try readPlain(url))
        default:
            text = try readPlain(url)
        }
        text = normalize(text)
        guard !text.isEmpty else { throw ImportError(message: tr("文件是空的", "The file is empty")) }
        return Script(title: url.deletingPathExtension().lastPathComponent, body: text)
    }

    static func fromPasteboard() -> Script? {
        guard let s = NSPasteboard.general.string(forType: .string) else { return nil }
        let body = normalize(s)
        guard !body.isEmpty else { return nil }
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? tr("粘贴的稿件", "Pasted script")
        let title = String(firstLine.replacingOccurrences(of: "【", with: "").prefix(18))
        return Script(title: title, body: body)
    }

    private static func readPlain(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let s = String(data: data, encoding: .utf8) { return s }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let s = String(data: data, encoding: String.Encoding(rawValue: gb)) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        throw ImportError(message: tr("无法识别文本编码", "Unknown text encoding"))
    }

    static func cleanMarkdown(_ s: String) -> String {
        var t = s
        let rules: [(String, String)] = [
            (#"(?m)^\s{0,3}(#{1,6})\s*"#, "$1 "),
            (#"(?m)^\s{0,3}>\s?"#, ""),
            (#"(?m)^\s*[-+]\s+"#, ""),
            (#"(?m)^\s*\*\s+"#, ""),
            (#"(?m)^\s*\d+[.)]\s+"#, ""),
            (#"!\[[^\]]*\]\([^)]*\)"#, ""),
            (#"\[([^\]]+)\]\([^)]*\)"#, "$1"),
            (#"`{1,3}([^`]*)`{1,3}"#, "$1"),
            (#"(?m)^\s*([-*_]\s*){3,}$"#, ""),
        ]
        for (p, r) in rules { t = t.replacingOccurrences(of: p, with: r, options: .regularExpression) }
        return t
    }

    static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SampleScripts {
    /// 产品介绍（README 截图也用这一篇）：痛点 → 是什么 → 怎么跟着你 → 开会也能用 → 免费开源
    static let pitch = """
    ## 痛点
    对着镜头讲话，最难的不是内容，而是记稿子。
    眼睛一会儿看稿、一会儿看镜头，观众一眼就看得出你在念。

    ## OpenSpeech 是什么
    OpenSpeech 是一个住在 Mac 刘海里的提词器。
    稿子就贴在摄像头正下方，你看稿的时候，眼神就在看**镜头**。

    ## 它会跟着你
    它会听你说话：你讲快它就快，你停下它就等你。
    即兴发挥也不怕，它不会乱跳，等你回到稿子再接着走。

    ## 开会、面试都能用
    共享屏幕时，对方看不到它。
    把经历分好段，被问到哪一段，按一下就跳过去。

    ## 免费、开源
    OpenSpeech 完全免费开源，所有处理都在你的 Mac 上完成。
    """

    static let pitchEnglish = """
    ## The problem
    Talking to a camera is easy. Remembering the script is not.
    Your eyes jump between the script and the lens, and everyone can tell.

    ## What it is
    OpenSpeech is a teleprompter that lives in your Mac's notch.
    Your script sits right below the camera, so reading looks like eye contact.

    ## It follows you
    It listens as you speak. Talk faster and it keeps up; pause and it waits.
    Go off script and it holds still until you come back.

    ## Ready for meetings and interviews
    When you share your screen, nobody else can see it.
    Split your stories into sections and jump to any of them with a keystroke.

    ## Free and open source
    OpenSpeech is free, open source, and everything stays on your Mac.
    """

    /// 英文版的面试故事库（人名是虚构的）
    static let interviewEnglish = """
    ## About me
    Hi, I'm Alex. I'm a product manager working on team collaboration tools.
    I like to understand the user's problem before I design anything.

    ## A conflict across teams
    We got stuck with the design team on the launch date.
    I listed the **concerns** on both sides, then found the smallest version everyone could accept.
    We shipped the core feature a week early, and design still had time to polish.

    ## My first failed project
    In my second year I built a campus marketplace app. After a month it had forty users.
    Looking back, we never checked whether people needed it before we started coding.
    Since then, I talk to five real users before I build anything.

    ## Why this company
    I've followed your work on collaboration tools for a long time.
    I'd love to bring my product experience to a bigger platform.
    """

    /// 演示 # / ## 标题：标题只是路牌，不用念；提词时按 ⌥⌘1…9 跳到第几段，或在小抄里点标题
    static let interview = """
    ## 自我介绍
    面试官好，我叫林然，目前在做 B 端产品，主要负责企业协作工具。
    我习惯先把用户的问题想清楚，再动手做方案。

    ## 团队冲突：跨部门排期
    那次我们和设计组在上线时间上卡住了。
    我先把两边的**顾虑**都列出来，再找一个大家都能接受的最小版本。
    最后提前一周上线了核心功能，设计组也有时间打磨细节。

    ## 第一次项目失败
    大二做的那个校园二手 App，上线一个月只有四十个用户。
    复盘下来，问题是我们没有先验证需求，就直接开始写代码了。
    从那以后，我做任何功能都会先找五个真实用户聊一聊。

    ## 为什么选择我们
    我关注贵司很久了，尤其是你们在协作工具上的思路。
    我希望能把自己做 B 端产品的经验，用在更大的平台上。
    """

    static let chinese = """
    【看镜头，微笑】
    大家好！你有没有发现，录口播最难的往往不是内容，而是**记稿子**？
    眼睛一会儿看稿，一会儿看镜头，观众一眼就能看出来你在念。
    【停顿一拍】
    所以我们做了 OpenSpeech，一个住在 Mac 刘海里的提词器。
    它就贴在摄像头正下方，你看稿的时候，眼神几乎就是在**直视镜头**。
    更厉害的是，它会听你说话：你讲快，它就跟着快；你停下来喝口水，它就安静地等你；你跳过一句，它也能马上跟上。
    不用踩踏板，不用找人帮你滚屏，**你只需要专心表达**。
    【放慢语速】
    好了，现在就试试吧：把你的稿子拖到刘海上，点开始，然后开口说话。我们下期见！
    """

    static let english = """
    [Look at the camera]
    Hi everyone! Here is a little secret about recording videos on a Mac.
    The hardest part is not what you say. It is **remembering** what you want to say.
    [Pause]
    OpenSpeech lives right inside your notch, just below the camera.
    It listens while you talk, and the script follows your voice.
    Speed up, slow down, or skip a line. It keeps up with you.
    Give it a try, and see you in the next one!
    """
}
