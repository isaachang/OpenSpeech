import AppKit
import Combine
import SwiftUI

struct NotchInfo: Equatable {
    var width: CGFloat
    var height: CGFloat
    var hasNotch: Bool

    /// 返回刘海尺寸和它在全局坐标里的中心 x
    static func of(_ screen: NSScreen) -> (NotchInfo, CGFloat) {
        if screen.safeAreaInsets.top > 0,
           let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            let w = screen.frame.width - l.width - r.width
            return (NotchInfo(width: w, height: screen.safeAreaInsets.top, hasNotch: true),
                    screen.frame.minX + l.width + w / 2)
        }
        // 没有刘海的屏幕：在菜单栏中间“造”一个
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return (NotchInfo(width: 190, height: max(26, min(menuBar, 34)), hasNotch: false), screen.frame.midX)
    }
}

/// 屏幕物理尺寸：用来把“镜头下多少度”换算成屏幕上的 pt
struct ScreenGeo: Equatable {
    var mmPerPt: CGFloat = 0.2
    /// 摄像头中心在屏幕顶边下方多少 pt（外接屏的摄像头在屏幕上沿外面，为负数）
    var cameraY: CGFloat = 16

    static func of(_ screen: NSScreen, notch: NotchInfo) -> ScreenGeo {
        var mm: CGFloat = 0.2
        if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let size = CGDisplayScreenSize(CGDirectDisplayID(n.uint32Value))
            if size.height > 50 { mm = size.height / screen.frame.height }
        }
        return ScreenGeo(mmPerPt: mm, cameraY: notch.hasNotch ? notch.height * 0.5 : -8 / mm)
    }

    func y(forDegrees d: Double, distanceCM: Double) -> CGFloat {
        cameraY + CGFloat(distanceCM * 10 * tan(d * .pi / 180)) / mmPerPt
    }

    func degrees(forY y: CGFloat, distanceCM: Double) -> Double {
        atan(Double((y - cameraY) * mmPerPt) / (distanceCM * 10)) * 180 / .pi
    }
}

final class IslandModel: ObservableObject {
    @Published var notch = NotchInfo(width: 200, height: 32, hasNotch: false)
    @Published var geo = ScreenGeo()
    @Published var hovering = false
    @Published var cardHovering = false
    @Published var dropTargeted = false
    @Published var flash: String?
    var panelWidth: CGFloat = IslandController.panelWidth
    /// 离屏渲染截图时用纯色代替毛玻璃
    var snapshot = false
}

struct IslandLayout: Equatable {
    var island: CGSize
    /// 悬浮稿件卡片，坐标以面板左上角为原点
    var card: CGRect?
}

enum IslandMetrics {
    static let peekWidth: CGFloat = 470
    static let compactSide: CGFloat = 156
    static let cardHPad: CGFloat = 30
    static let cardTop: CGFloat = 16
    static let cardBottom: CGFloat = 20

    static func layout(phase: IslandPhase, hovering: Bool, dropTargeted: Bool, hasToast: Bool,
                       notch: NotchInfo, geo: ScreenGeo, settings: PrompterSettings, panelWidth: CGFloat) -> IslandLayout {
        let lh = PrompterLayout.lineHeight(settings.fontSize)
        let lines = CGFloat(settings.visibleLines)
        let maxW = panelWidth - 40
        if dropTargeted { return IslandLayout(island: CGSize(width: peekWidth, height: notch.height + 112)) }
        switch phase {
        case .idle:
            return IslandLayout(island: hovering ? CGSize(width: peekWidth, height: notch.height + 124)
                                                 : CGSize(width: notch.width, height: notch.height))
        case .finished:
            return IslandLayout(island: CGSize(width: peekWidth, height: notch.height + 96))
        case .countdown, .presenting:
            if settings.layoutStyle == .island {
                let w = settings.textWidth + 2 * (PrompterLayout.earRadius + PrompterLayout.sidePadding) + PrompterLayout.caretGap
                return IslandLayout(island: CGSize(width: min(maxW, max(w, notch.width + 280, hovering ? 640 : 0)),
                                                   height: notch.height + 6 + lines * lh + 38))
            }
            let compactW = notch.width + 2 * compactSide
            var island = CGSize(width: compactW, height: notch.height)
            if hovering {
                island = CGSize(width: max(compactW, 620), height: notch.height + 48)
            } else if hasToast {
                island = CGSize(width: max(compactW, 500), height: notch.height + 30)
            }
            let cw = min(maxW, settings.textWidth + 2 * cardHPad)
            let ch = cardTop + lines * lh + cardBottom
            let anchor: CGFloat = settings.visibleLines >= 3 ? 1 : 0
            let readY = geo.y(forDegrees: settings.cardDegrees, distanceCM: settings.viewingDistance)
            let top = max(readY - (cardTop + anchor * lh + lh / 2), notch.height + 14)
            return IslandLayout(island: island, card: CGRect(x: (panelWidth - cw) / 2, y: top, width: cw, height: ch))
        }
    }

    static func layout(engine: PrompterEngine, model: IslandModel, settings: PrompterSettings) -> IslandLayout {
        layout(phase: engine.phase, hovering: model.hovering, dropTargeted: model.dropTargeted, hasToast: engine.toast != nil,
               notch: model.notch, geo: model.geo, settings: settings, panelWidth: model.panelWidth)
    }
}

final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        // 必须在 isFloatingPanel 之后设置，否则会被重置成 .floating，被菜单栏盖住
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// 管理刘海上的透明大面板：定位、鼠标穿透、悬停检测、触控板滚动翻行。
final class IslandController {
    static let panelWidth: CGFloat = 1100

    let panel = IslandPanel()
    let model = IslandModel()
    private let engine: PrompterEngine
    private let settings: PrompterSettings
    private var mouseTimer: Timer?
    private var leaveWork: DispatchWorkItem?
    private var flashWork: DispatchWorkItem?
    private var scrollAccum: CGFloat = 0
    private var scrollMonitor: Any?
    private var bag = Set<AnyCancellable>()

    init(engine: PrompterEngine, store: ScriptStore, settings: PrompterSettings, actions: IslandActions) {
        self.engine = engine
        self.settings = settings

        let root = IslandRootView(model: model, engine: engine, store: store, settings: settings, actions: actions)
        let host = IslandHostingView(rootView: root)
        host.frame = CGRect(x: 0, y: 0, width: Self.panelWidth, height: 800)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        engine.attachDisplay(to: host)
        reposition()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.reposition() }
        settings.$hideFromCapture
            .sink { [weak self] hide in self?.panel.sharingType = hide ? .none : .readOnly }
            .store(in: &bag)
        settings.$screenChoice.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &bag)

        let t = Timer(timeInterval: 1.0 / 40.0, repeats: true) { [weak self] _ in self?.pollMouse() }
        RunLoop.main.add(t, forMode: .common)
        mouseTimer = t

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            guard let self else { return e }
            return self.handleScroll(e)
        }
    }

    func flash(_ text: String) {
        model.flash = text
        flashWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.model.flash = nil }
        flashWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    private func targetScreen() -> NSScreen? {
        switch settings.screenChoice {
        case .auto: return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
        case .primary: return NSScreen.screens.first
        }
    }

    func reposition() {
        guard let screen = targetScreen() else { return }
        let (info, centerX) = NotchInfo.of(screen)
        model.notch = info
        model.geo = ScreenGeo.of(screen, notch: info)
        // 面板和屏幕一样高（透明部分不拦鼠标），卡片放多低都装得下
        let w = Self.panelWidth, h = screen.frame.height
        panel.setFrame(NSRect(x: centerX - w / 2, y: screen.frame.maxY - h, width: w, height: h), display: true)
    }

    private func pollMouse() {
        let p = NSEvent.mouseLocation
        let layout = IslandMetrics.layout(engine: engine, model: model, settings: settings)
        let size = layout.island
        let f = panel.frame
        var rect = CGRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
        if engine.phase == .idle && !model.hovering && !model.dropTargeted {
            // 收起时热区稍微放大一点，更容易“碰”到刘海
            rect = rect.insetBy(dx: -12, dy: 0)
            rect.origin.y -= 8
            rect.size.height += 8
        }
        let inside = rect.contains(p)
        var inCard = false
        if let c = layout.card {
            inCard = CGRect(x: f.minX + c.minX, y: f.maxY - c.maxY, width: c.width, height: c.height).contains(p)
        }
        if model.cardHovering != inCard { model.cardHovering = inCard }
        let interactive = inside || inCard
        if panel.ignoresMouseEvents == interactive { panel.ignoresMouseEvents = !interactive }

        if inside {
            leaveWork?.cancel()
            leaveWork = nil
            if !model.hovering { model.hovering = true }
        } else if (model.hovering || model.dropTargeted) && leaveWork == nil {
            let w = DispatchWorkItem { [weak self] in
                self?.model.hovering = false
                self?.model.dropTargeted = false
                self?.leaveWork = nil
            }
            leaveWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
        }
    }

    private func handleScroll(_ e: NSEvent) -> NSEvent? {
        guard e.window === panel, engine.phase.isActive else { return e }
        let dy = e.hasPreciseScrollingDeltas ? e.scrollingDeltaY : e.scrollingDeltaY * 12
        scrollAccum += dy
        if abs(scrollAccum) > 36 {
            engine.jumpLines(scrollAccum > 0 ? -1 : 1)
            scrollAccum = 0
        }
        if e.phase == .ended || e.momentumPhase == .ended { scrollAccum = 0 }
        return nil
    }
}
