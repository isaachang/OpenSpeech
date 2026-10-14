import Foundation
import CoreGraphics

enum PrompterMode: String, CaseIterable, Identifiable {
    case voice, pace
    var id: String { rawValue }

    var title: String { self == .voice ? "语音跟读" : "智能匀速" }
    var short: String { self == .voice ? "跟读" : "匀速" }
    var icon: String { self == .voice ? "waveform" : "metronome" }
    var detail: String {
        self == .voice
            ? "实时识别你讲到哪，提词自动跟上。讲快讲慢、跳句、停下来喝水，都能跟。"
            : "按目标语速平滑滚动；检测到你停顿就自动停住，开口再继续。"
    }
}

enum ScreenChoice: String, CaseIterable, Identifiable {
    case auto, primary
    var id: String { rawValue }
    var title: String { self == .auto ? "自动（优先刘海屏）" : "主显示器" }
}

enum LayoutStyle: String, CaseIterable, Identifiable {
    case island, card
    var id: String { rawValue }
    var title: String { self == .island ? "灵动岛展开" : "刘海 + 悬浮卡片" }
}

enum TextAlign: String, CaseIterable, Identifiable {
    case leading, center
    var id: String { rawValue }
    var title: String { self == .leading ? "左对齐" : "居中" }
}

/// 位置预设：用来对比哪种摆法在镜头里最自然（依据见 docs/research-teleprompter-placement.md）
struct PlacementPreset: Identifiable, Equatable {
    let id: Int
    let letter: String
    let name: String
    let style: LayoutStyle
    let degrees: Double
    let lineChars: Int
    let lines: Int
    let fontSize: Double
    var recommended = false

    var detail: String {
        style == .island ? "贴着刘海 · \(lineChars) 字/行 · \(lines) 行"
                         : "镜头下 \(Self.deg(degrees)) · \(lineChars) 字/行 · \(lines) 行"
    }

    static func deg(_ d: Double) -> String { d == d.rounded() ? "\(Int(d))°" : String(format: "%.1f°", d) }

    static let all: [PlacementPreset] = [
        PlacementPreset(id: 1, letter: "A", name: "原版", style: .island, degrees: 2, lineChars: 24, lines: 3, fontSize: 22),
        PlacementPreset(id: 2, letter: "B", name: "刘海窄行", style: .island, degrees: 2, lineChars: 14, lines: 3, fontSize: 22),
        PlacementPreset(id: 3, letter: "C", name: "悬浮卡片", style: .card, degrees: 5, lineChars: 14, lines: 3, fontSize: 22, recommended: true),
        PlacementPreset(id: 4, letter: "D", name: "卡片偏低", style: .card, degrees: 7, lineChars: 14, lines: 2, fontSize: 24),
        PlacementPreset(id: 5, letter: "E", name: "卡片贴近", style: .card, degrees: 3, lineChars: 12, lines: 2, fontSize: 22),
    ]
}

final class PrompterSettings: ObservableObject {
    private let d: UserDefaults

    @Published var mode: PrompterMode { didSet { d.set(mode.rawValue, forKey: "mode") } }
    @Published var targetSpeed: Double { didSet { d.set(targetSpeed, forKey: "targetSpeed") } }
    @Published var fontSize: Double { didSet { d.set(fontSize, forKey: "fontSize") } }
    @Published var visibleLines: Int { didSet { d.set(visibleLines, forKey: "visibleLines") } }
    @Published var layoutStyle: LayoutStyle { didSet { d.set(layoutStyle.rawValue, forKey: "layoutStyle") } }
    /// 悬浮卡片：正在读的那一行在镜头下方多少度
    @Published var cardDegrees: Double { didSet { d.set(cardDegrees, forKey: "cardDegrees") } }
    /// 每行大约几个汉字（决定行宽）
    @Published var lineChars: Int { didSet { d.set(lineChars, forKey: "lineChars") } }
    /// 眼睛到屏幕的距离（厘米），用来把“度”换算成屏幕上的位置
    @Published var viewingDistance: Double { didSet { d.set(viewingDistance, forKey: "viewingDistance") } }
    @Published var cardAlign: TextAlign { didSet { d.set(cardAlign.rawValue, forKey: "cardAlign") } }
    @Published var countdown: Bool { didSet { d.set(countdown, forKey: "countdown") } }
    @Published var pauseOnSilence: Bool { didSet { d.set(pauseOnSilence, forKey: "pauseOnSilence") } }
    @Published var hideFromCapture: Bool { didSet { d.set(hideFromCapture, forKey: "hideFromCapture") } }
    @Published var screenChoice: ScreenChoice { didSet { d.set(screenChoice.rawValue, forKey: "screenChoice") } }
    @Published var trackingLog: Bool { didSet { d.set(trackingLog, forKey: "trackingLog") } }
    @Published var saveAudio: Bool { didSet { d.set(saveAudio, forKey: "saveAudio") } }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        mode = PrompterMode(rawValue: d.string(forKey: "mode") ?? "") ?? .voice
        targetSpeed = d.object(forKey: "targetSpeed") as? Double ?? 240
        fontSize = d.object(forKey: "fontSize") as? Double ?? 22
        visibleLines = d.object(forKey: "visibleLines") as? Int ?? 3
        layoutStyle = LayoutStyle(rawValue: d.string(forKey: "layoutStyle") ?? "") ?? .card
        cardDegrees = d.object(forKey: "cardDegrees") as? Double ?? 5
        lineChars = d.object(forKey: "lineChars") as? Int ?? 14
        viewingDistance = d.object(forKey: "viewingDistance") as? Double ?? 55
        cardAlign = TextAlign(rawValue: d.string(forKey: "cardAlign") ?? "") ?? .center
        countdown = d.object(forKey: "countdown") as? Bool ?? true
        pauseOnSilence = d.object(forKey: "pauseOnSilence") as? Bool ?? true
        hideFromCapture = d.object(forKey: "hideFromCapture") as? Bool ?? true
        screenChoice = ScreenChoice(rawValue: d.string(forKey: "screenChoice") ?? "") ?? .auto
        trackingLog = d.object(forKey: "trackingLog") as? Bool ?? true
        saveAudio = d.object(forKey: "saveAudio") as? Bool ?? false
    }

    /// 文字区宽度（pt）：每行字数 × 字号（汉字基本是 1 em 宽）
    var textWidth: CGFloat { CGFloat(lineChars) * CGFloat(fontSize) * 1.02 }

    func apply(_ p: PlacementPreset) {
        layoutStyle = p.style
        if p.style == .card { cardDegrees = p.degrees }
        lineChars = p.lineChars
        visibleLines = p.lines
        fontSize = p.fontSize
    }

    /// 当前设置正好等于哪个预设（手动调过就是 nil = 自定义）
    var activePreset: PlacementPreset? {
        PlacementPreset.all.first {
            $0.style == layoutStyle && $0.lineChars == lineChars && $0.lines == visibleLines && $0.fontSize == fontSize
                && ($0.style == .island || abs($0.degrees - cardDegrees) < 0.05)
        }
    }
}
