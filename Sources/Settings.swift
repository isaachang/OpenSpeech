import AppKit
import CoreGraphics

enum PrompterMode: String, CaseIterable, Identifiable {
    case voice, pace
    var id: String { rawValue }

    var title: String { self == .voice ? tr("语音跟读", "Voice-follow") : tr("智能匀速", "Constant speed") }
    var short: String { self == .voice ? tr("跟读", "Voice") : tr("匀速", "Pace") }
    var icon: String { self == .voice ? "waveform" : "metronome" }
}

/// 提词的两种样式
enum DisplayStyle: String, CaseIterable, Identifiable {
    case glass, caption
    var id: String { rawValue }
    var title: String { self == .glass ? tr("玻璃卡片", "Glass card") : tr("字幕胶囊", "Caption") }
}

/// 提词卡片的位置：正在读的那一行的中心，相对屏幕顶边中点（摄像头正下方）
struct CardPosition: Equatable {
    /// 水平偏离中线多少 pt（右为正）
    var dx: CGFloat
    /// 正在读的那一行离屏幕顶边多少 pt
    var readY: CGFloat
}

/// 屏幕的稳定标识：用来给每块屏幕分别记住位置
enum ScreenKey {
    static func of(_ screen: NSScreen) -> String {
        guard let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(n.uint32Value))?.takeRetainedValue(),
              let s = CFUUIDCreateString(nil, uuid) as String? else { return screen.localizedName }
        return s
    }
}

final class PrompterSettings: ObservableObject {
    private let d: UserDefaults

    /// 正在读的那一行默认放在镜头下方多少度（依据见 docs/research-teleprompter-placement.md）
    static let defaultDegrees = 5.0
    /// 用来把“度”换算成屏幕上的位置：笔记本放桌上一般 50–60 cm
    static let viewingDistance = 55.0
    static let charsRange = 8...30
    static let linesRange = 1...5

    @Published var mode: PrompterMode { didSet { d.set(mode.rawValue, forKey: "mode") } }
    @Published var targetSpeed: Double { didSet { d.set(targetSpeed, forKey: "targetSpeed") } }
    @Published var fontSize: Double { didSet { d.set(fontSize, forKey: "fontSize") } }
    @Published var displayStyle: DisplayStyle { didSet { d.set(displayStyle.rawValue, forKey: "displayStyle") } }
    /// 玻璃卡片：每行大约几个汉字、显示几行
    @Published var glassChars: Int { didSet { d.set(glassChars, forKey: "glassChars") } }
    @Published var glassLines: Int { didSet { d.set(glassLines, forKey: "glassLines") } }
    /// 字幕胶囊：每行字数（固定显示这一句 + 下一句）
    @Published var captionChars: Int { didSet { d.set(captionChars, forKey: "captionChars") } }
    @Published var countdown: Bool { didSet { d.set(countdown, forKey: "countdown") } }
    @Published var pauseOnSilence: Bool { didSet { d.set(pauseOnSilence, forKey: "pauseOnSilence") } }
    @Published var hideFromCapture: Bool { didSet { d.set(hideFromCapture, forKey: "hideFromCapture") } }
    /// 开会时减少外放回声（默认关；下次开始提词时生效）
    @Published var echoReduction: Bool { didSet { d.set(echoReduction, forKey: "echoReduction") } }
    /// 显示在哪块屏幕：空 = 自动（优先带刘海 / 摄像头的屏幕）
    @Published var screenID: String { didSet { d.set(screenID, forKey: "screenID") } }
    @Published var trackingLog: Bool { didSet { d.set(trackingLog, forKey: "trackingLog") } }
    @Published var saveAudio: Bool { didSet { d.set(saveAudio, forKey: "saveAudio") } }
    /// 提词时右上角的“小抄”（整篇稿子）
    @Published var cheatSheet: Bool { didSet { d.set(cheatSheet, forKey: "cheatSheet") } }
    /// 操作提示：点过“知道了”，或者三种操作都做过一次，就不再提示
    @Published var tipsDismissed: Bool { didSet { d.set(tipsDismissed, forKey: "tipsDismissed") } }
    @Published var didMoveCard: Bool { didSet { d.set(didMoveCard, forKey: "didMoveCard") } }
    @Published var didResizeCard: Bool { didSet { d.set(didResizeCard, forKey: "didResizeCard") } }
    @Published var didResetCard: Bool { didSet { d.set(didResetCard, forKey: "didResetCard") } }
    var showsCardTip: Bool { !tipsDismissed && !(didMoveCard && didResizeCard && didResetCard) }
    /// 小抄的“可以拖动”提示：点过“知道了”或拖过一次就不再出现
    @Published var cheatTipDismissed: Bool { didSet { d.set(cheatTipDismissed, forKey: "cheatTipDismissed") } }
    /// 装了 Zoom 时主窗口里的 “改一个设置” 提示：点过关闭就不再出现
    @Published var zoomTipDismissed: Bool { didSet { d.set(zoomTipDismissed, forKey: "zoomTipDismissed") } }
    /// 小抄左上角的位置（每块屏幕各自记住）；没有记录 = 右上角
    @Published private(set) var cheatPositions: [String: CGPoint] {
        didSet { d.set(cheatPositions.mapValues { [Double($0.x), Double($0.y)] }, forKey: "cheatPositions") }
    }
    func cheatPosition(for screen: String) -> CGPoint? { cheatPositions[screen] }
    func setCheatPosition(_ p: CGPoint?, for screen: String) { cheatPositions[screen] = p }
    /// 每块屏幕各自记住的位置（两种样式共用）；没有记录 = 默认位置
    @Published private(set) var positions: [String: CardPosition] {
        didSet { d.set(positions.mapValues { [Double($0.dx), Double($0.readY)] }, forKey: "cardPositions") }
    }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        // 界面上只保留语音跟读；识别不可用时引擎会自己临时切到匀速
        mode = .voice
        targetSpeed = d.object(forKey: "targetSpeed") as? Double ?? 240
        fontSize = d.object(forKey: "fontSize") as? Double ?? 22
        displayStyle = DisplayStyle(rawValue: d.string(forKey: "displayStyle") ?? "") ?? .glass
        glassChars = d.object(forKey: "glassChars") as? Int ?? Self.defaultGlassChars
        glassLines = d.object(forKey: "glassLines") as? Int ?? Self.defaultGlassLines
        captionChars = d.object(forKey: "captionChars") as? Int ?? Self.defaultCaptionChars
        countdown = d.object(forKey: "countdown") as? Bool ?? true
        pauseOnSilence = d.object(forKey: "pauseOnSilence") as? Bool ?? true
        hideFromCapture = d.object(forKey: "hideFromCapture") as? Bool ?? true
        echoReduction = d.bool(forKey: "echoReduction")
        screenID = d.string(forKey: "screenID") ?? ""
        trackingLog = d.object(forKey: "trackingLog") as? Bool ?? true
        saveAudio = d.object(forKey: "saveAudio") as? Bool ?? false
        cheatSheet = d.object(forKey: "cheatSheet") as? Bool ?? false
        tipsDismissed = d.bool(forKey: "tipsDismissed")
        didMoveCard = d.bool(forKey: "didMoveCard")
        didResizeCard = d.bool(forKey: "didResizeCard")
        didResetCard = d.bool(forKey: "didResetCard")
        cheatTipDismissed = d.bool(forKey: "cheatTipDismissed")
        zoomTipDismissed = d.bool(forKey: "zoomTipDismissed")
        var cp: [String: CGPoint] = [:]
        for (k, v) in (d.dictionary(forKey: "cheatPositions") as? [String: [Double]]) ?? [:] where v.count == 2 {
            cp[k] = CGPoint(x: v[0], y: v[1])
        }
        cheatPositions = cp
        var pos: [String: CardPosition] = [:]
        for (k, v) in (d.dictionary(forKey: "cardPositions") as? [String: [Double]]) ?? [:] where v.count == 2 {
            pos[k] = CardPosition(dx: CGFloat(v[0]), readY: CGFloat(v[1]))
        }
        positions = pos
    }

    /// 当前样式的每行字数
    var lineChars: Int {
        get { displayStyle == .glass ? glassChars : captionChars }
        set {
            let v = min(max(newValue, Self.charsRange.lowerBound), Self.charsRange.upperBound)
            if displayStyle == .glass { glassChars = v } else { captionChars = v }
        }
    }

    /// 当前样式显示几行（字幕胶囊固定 2 行：这一句 + 下一句）
    var visibleLines: Int {
        get { displayStyle == .glass ? glassLines : 2 }
        set { if displayStyle == .glass { glassLines = min(max(newValue, Self.linesRange.lowerBound), Self.linesRange.upperBound) } }
    }

    /// 实际排版用的字号：字幕胶囊字更大一点
    var displayFontSize: Double { displayStyle == .glass ? fontSize : (fontSize * 1.12).rounded() }

    /// 文字区宽度（pt）：每行字数 × 字号（汉字基本是 1 em 宽）
    var textWidth: CGFloat { CGFloat(lineChars) * CGFloat(displayFontSize) * 1.02 }

    /// 预设大小：玻璃卡片每行 14 字、3 行；字幕胶囊每行 16 字
    static let defaultGlassChars = 14
    static let defaultGlassLines = 3
    static let defaultCaptionChars = 16

    /// 当前样式的大小回到预设（双击卡片 / “回到默认位置和大小”）
    func resetSize() {
        if displayStyle == .glass {
            glassChars = Self.defaultGlassChars
            glassLines = Self.defaultGlassLines
        } else {
            captionChars = Self.defaultCaptionChars
        }
    }

    func position(for screen: String) -> CardPosition? { positions[screen] }

    func setPosition(_ p: CardPosition?, for screen: String) { positions[screen] = p }
}
