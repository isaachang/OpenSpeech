import AppKit
import CoreGraphics

enum PrompterMode: String, CaseIterable, Identifiable {
    case voice, pace
    var id: String { rawValue }

    var title: String { self == .voice ? "语音跟读" : "智能匀速" }
    var short: String { self == .voice ? "跟读" : "匀速" }
    var icon: String { self == .voice ? "waveform" : "metronome" }
}

/// 提词的两种样式
enum DisplayStyle: String, CaseIterable, Identifiable {
    case glass, caption
    var id: String { rawValue }
    var title: String { self == .glass ? "玻璃卡片" : "字幕胶囊" }
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
    /// 显示在哪块屏幕：空 = 自动（优先带刘海 / 摄像头的屏幕）
    @Published var screenID: String { didSet { d.set(screenID, forKey: "screenID") } }
    @Published var trackingLog: Bool { didSet { d.set(trackingLog, forKey: "trackingLog") } }
    @Published var saveAudio: Bool { didSet { d.set(saveAudio, forKey: "saveAudio") } }
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
        glassChars = d.object(forKey: "glassChars") as? Int ?? 14
        glassLines = d.object(forKey: "glassLines") as? Int ?? 3
        captionChars = d.object(forKey: "captionChars") as? Int ?? 16
        countdown = d.object(forKey: "countdown") as? Bool ?? true
        pauseOnSilence = d.object(forKey: "pauseOnSilence") as? Bool ?? true
        hideFromCapture = d.object(forKey: "hideFromCapture") as? Bool ?? true
        screenID = d.string(forKey: "screenID") ?? ""
        trackingLog = d.object(forKey: "trackingLog") as? Bool ?? true
        saveAudio = d.object(forKey: "saveAudio") as? Bool ?? false
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

    func position(for screen: String) -> CardPosition? { positions[screen] }

    func setPosition(_ p: CardPosition?, for screen: String) { positions[screen] = p }
}
