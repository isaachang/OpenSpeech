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

    /// 水平偏离中线 dx pt 对应多少度
    func degrees(forDX dx: CGFloat, distanceCM: Double) -> Double {
        atan(Double(dx * mmPerPt) / (distanceCM * 10)) * 180 / .pi
    }
}

final class IslandModel: ObservableObject {
    @Published var notch = NotchInfo(width: 200, height: 32, hasNotch: false)
    @Published var geo = ScreenGeo()
    @Published var hovering = false
    @Published var cardHovering = false
    @Published var dropTargeted = false
    @Published var flash: String?
    /// 正在拖动卡片：拖动中的位置（松手才保存）
    @Published var dragPos: CardPosition?
    /// 正在拖角调大小
    @Published var resizing = false
    /// 卡片下方一闪而过的确认（比如双击后“已回到默认位置和大小”）
    @Published var cardToast: String?
    /// 正在拖小抄：拖动中左上角的位置（松手才保存）
    @Published var cheatDragPos: CGPoint?
    /// 当前屏幕的标识（位置按屏幕分别记住）
    var screenKey = ""
    var panelSize = CGSize(width: 1100, height: 800)
    /// 离屏渲染截图时用纯色代替毛玻璃
    var snapshot = false

    var dragging: Bool { dragPos != nil || resizing }
}

struct IslandLayout: Equatable {
    var island: CGSize
    /// 提词卡片，坐标以面板左上角为原点
    var card: CGRect?
    /// 卡片下方的悬停控制条
    var controls: CGRect?
    /// 卡片在摄像头中线上（显示悬挂细线）
    var centered = false
    /// 第一次用时卡片旁边的操作提示
    var tip: CGRect?
    /// 右上角的小抄
    var cheat: CGRect?
    /// 第一次打开小抄时旁边的“可以拖动”提示
    var cheatTip: CGRect?
}

enum IslandMetrics {
    static let peekWidth: CGFloat = 520
    static let compactSide: CGFloat = 156
    static let controlsSize = CGSize(width: 214, height: 40)
    static let tipSize = CGSize(width: 278, height: 150)
    static let cheatWidth: CGFloat = 300

    /// 操作提示放在卡片右边，放不下就放左边
    static func tipFrame(card: CGRect, panel: CGSize) -> CGRect {
        let s = tipSize
        let right = card.maxX + 14
        let x = right + s.width <= panel.width - 8 ? right : max(8, card.minX - 14 - s.width)
        return CGRect(x: x, y: card.minY, width: s.width, height: s.height)
    }

    static let cheatTipSize = CGSize(width: 250, height: 112)
    /// 小抄拖动时顶部能抓的那一条
    static let cheatGripHeight: CGFloat = 36

    /// 小抄默认在屏幕右上角；拖过就用记住的位置（收在屏幕里，不压住菜单栏）
    static func cheatFrame(panel: CGSize, notch: NotchInfo, origin: CGPoint?) -> CGRect {
        let h = min(480, max(260, panel.height * 0.5))
        let def = CGPoint(x: panel.width - cheatWidth - 20, y: notch.height + 14)
        let o = origin ?? def
        let x = min(max(o.x, 8), panel.width - cheatWidth - 8)
        let y = min(max(o.y, notch.height + 6), panel.height - h - 8)
        return CGRect(x: x, y: y, width: cheatWidth, height: h)
    }

    /// 小抄提示放在小抄左边，放不下就放右边
    static func cheatTipFrame(cheat: CGRect, panel: CGSize) -> CGRect {
        let s = cheatTipSize
        let left = cheat.minX - 14 - s.width
        let x = left >= 8 ? left : min(cheat.maxX + 14, panel.width - s.width - 8)
        return CGRect(x: x, y: cheat.minY + 8, width: s.width, height: s.height)
    }

    /// 卡片尺寸，以及正在读的那一行的中心离卡片顶边多远
    static func cardSize(_ s: PrompterSettings) -> (size: CGSize, readOffset: CGFloat) {
        let lh = PrompterLayout.lineHeight(s.displayFontSize)
        switch s.displayStyle {
        case .glass:
            let anchor: CGFloat = s.visibleLines >= 3 ? 1 : 0
            return (CGSize(width: s.textWidth + 2 * GlassCard.hPad,
                           height: GlassCard.top + CGFloat(s.visibleLines) * lh + GlassCard.bottom),
                    GlassCard.top + anchor * lh + lh / 2)
        case .caption:
            return (CGSize(width: s.textWidth + 2 * CaptionCard.hPad,
                           height: CaptionCard.top + lh * (1 + CaptionCard.nextScale) + CaptionCard.bottom),
                    CaptionCard.top + lh / 2)
        }
    }

    /// 默认位置：摄像头正下方 5°
    static func defaultPosition(_ geo: ScreenGeo) -> CardPosition {
        CardPosition(dx: 0, readY: geo.y(forDegrees: PrompterSettings.defaultDegrees, distanceCM: PrompterSettings.viewingDistance))
    }

    /// 卡片放在屏幕里、不压住刘海和菜单栏
    static func cardFrame(_ pos: CardPosition, settings: PrompterSettings, notch: NotchInfo, panel: CGSize) -> CGRect {
        let (size, read) = cardSize(settings)
        let w = min(size.width, panel.width - 40)
        let x = min(max(panel.width / 2 + pos.dx - w / 2, 8), panel.width - w - 8)
        let y = min(max(pos.readY - read, notch.height + 10), max(notch.height + 10, panel.height - size.height - 64))
        return CGRect(x: x, y: y, width: w, height: size.height)
    }

    /// 把拖到屏幕外的位置收回来
    static func clamp(_ pos: CardPosition, settings: PrompterSettings, notch: NotchInfo, panel: CGSize) -> CardPosition {
        let f = cardFrame(pos, settings: settings, notch: notch, panel: panel)
        return CardPosition(dx: f.midX - panel.width / 2, readY: f.minY + cardSize(settings).readOffset)
    }

    static func controlsFrame(card: CGRect, panel: CGSize) -> CGRect {
        let s = controlsSize
        let below = card.maxY + 10
        let y = below + s.height + 8 > panel.height ? card.minY - 10 - s.height : below
        return CGRect(x: card.midX - s.width / 2, y: y, width: s.width, height: s.height)
    }

    static func layout(phase: IslandPhase, hovering: Bool, dropTargeted: Bool, hasToast: Bool,
                       model: IslandModel, settings: PrompterSettings) -> IslandLayout {
        let notch = model.notch
        if dropTargeted { return IslandLayout(island: CGSize(width: peekWidth, height: notch.height + 112)) }
        switch phase {
        case .idle:
            return IslandLayout(island: hovering ? CGSize(width: peekWidth, height: notch.height + 124)
                                                 : CGSize(width: notch.width, height: notch.height))
        case .finished:
            return IslandLayout(island: CGSize(width: peekWidth, height: notch.height + 96))
        case .countdown, .presenting:
            let compactW = notch.width + 2 * compactSide
            let island = CGSize(width: hasToast ? max(compactW, 500) : compactW, height: notch.height + (hasToast ? 30 : 0))
            let pos = model.dragPos ?? settings.position(for: model.screenKey) ?? defaultPosition(model.geo)
            let card = cardFrame(pos, settings: settings, notch: notch, panel: model.panelSize)
            var l = IslandLayout(island: island, card: card,
                                 controls: controlsFrame(card: card, panel: model.panelSize),
                                 centered: abs(card.midX - model.panelSize.width / 2) < 0.5)
            if settings.showsCardTip && !model.dragging && !model.snapshot { l.tip = tipFrame(card: card, panel: model.panelSize) }
            if settings.cheatSheet {
                let c = cheatFrame(panel: model.panelSize, notch: notch,
                                   origin: model.cheatDragPos ?? settings.cheatPosition(for: model.screenKey))
                l.cheat = c
                if !settings.cheatTipDismissed && model.cheatDragPos == nil && !model.snapshot {
                    l.cheatTip = cheatTipFrame(cheat: c, panel: model.panelSize)
                }
            }
            return l
        }
    }

    static func layout(engine: PrompterEngine, model: IslandModel, settings: PrompterSettings) -> IslandLayout {
        layout(phase: engine.phase, hovering: model.hovering, dropTargeted: model.dropTargeted, hasToast: engine.toast != nil,
               model: model, settings: settings)
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

/// 管理覆盖整块屏幕的透明面板：定位、鼠标穿透（只有刘海和卡片会拦鼠标）、悬停检测、触控板滚动翻行。
final class IslandController {
    let panel = IslandPanel()
    let model = IslandModel()
    private let engine: PrompterEngine
    private let settings: PrompterSettings
    private var mouseTimer: Timer?
    private var leaveWork: DispatchWorkItem?
    private var cardLeaveWork: DispatchWorkItem?
    private var flashWork: DispatchWorkItem?
    private var scrollAccum: CGFloat = 0
    private var scrollMonitor: Any?
    private var toastWork: DispatchWorkItem?
    /// 小抄的位置（屏幕坐标）：鼠标在里面滚动时让小抄自己滚，不翻提词卡片
    private var cheatGlobal: CGRect?
    /// 现在是不是我们改过光标（离开时要还原成箭头）
    private var customCursor = false
    private var bag = Set<AnyCancellable>()

    init(engine: PrompterEngine, store: ScriptStore, settings: PrompterSettings, actions: IslandActions) {
        self.engine = engine
        self.settings = settings

        let root = IslandRootView(model: model, engine: engine, store: store, settings: settings, actions: actions)
        let host = IslandHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: model.panelSize)
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
        settings.$screenID.dropFirst()
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

    static func targetScreen(_ settings: PrompterSettings) -> NSScreen? {
        if !settings.screenID.isEmpty, let s = NSScreen.screens.first(where: { ScreenKey.of($0) == settings.screenID }) {
            return s
        }
        return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }

    /// 回到默认位置（当前屏幕）和预设大小（当前样式）
    func resetPosition() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) {
            settings.setPosition(nil, for: model.screenKey)
            settings.resetSize()
        }
        settings.didResetCard = true
        guard engine.phase.isActive else { return }
        model.cardToast = "已回到默认位置和大小"
        toastWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.model.cardToast = nil }
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: w)
    }

    func reposition() {
        guard let screen = Self.targetScreen(settings) else { return }
        let (info, _) = NotchInfo.of(screen)
        model.notch = info
        model.geo = ScreenGeo.of(screen, notch: info)
        model.screenKey = ScreenKey.of(screen)
        // 面板盖住整块屏幕（透明部分不拦鼠标），卡片拖到哪都装得下；刘海总在屏幕顶部正中
        model.panelSize = screen.frame.size
        panel.setFrame(screen.frame, display: true)
        model.objectWillChange.send()
    }

    private func pollMouse() {
        let p = NSEvent.mouseLocation
        let layout = IslandMetrics.layout(engine: engine, model: model, settings: settings)
        let size = layout.island
        let f = panel.frame
        func global(_ r: CGRect) -> CGRect { CGRect(x: f.minX + r.minX, y: f.maxY - r.maxY, width: r.width, height: r.height) }
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
            // 四个角的拖柄在卡片外面一点；悬停时把下方控制条也算进来，鼠标移过去不会消失
            var area = c.insetBy(dx: -14, dy: -14)
            if model.cardHovering, let ctl = layout.controls { area = area.union(ctl.insetBy(dx: -6, dy: -6)) }
            inCard = global(area).contains(p)
        }
        if inCard || model.dragging {
            cardLeaveWork?.cancel()
            cardLeaveWork = nil
            if !model.cardHovering { model.cardHovering = true }
        } else if model.cardHovering && cardLeaveWork == nil {
            let w = DispatchWorkItem { [weak self] in
                self?.model.cardHovering = false
                self?.cardLeaveWork = nil
            }
            cardLeaveWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
        }
        cheatGlobal = layout.cheat.map(global)
        let inExtras = [layout.tip, layout.cheat, layout.cheatTip].compactMap { $0 }.contains { global($0).contains(p) }
        let interactive = inside || inCard || inExtras || model.dragging || model.cheatDragPos != nil
        updateCursor(p, layout: layout, global: global)
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

    /// 光标：平时箭头；拖动条 / 小抄的六个小点上是张开的手，拖动时握住的手，四个角是斜向箭头。
    /// 面板不会变成当前窗口，系统的悬停事件进不来，所以和悬停检测一起在定时器里做，每次都重新设一遍
    private func updateCursor(_ p: CGPoint, layout: IslandLayout, global: (CGRect) -> CGRect) {
        var cursor: NSCursor?
        if model.dragPos != nil || model.cheatDragPos != nil {
            cursor = .closedHand
        } else if let c = layout.card.map(global), c.insetBy(dx: -14, dy: -14).contains(p) {
            let corners: [(CGPoint, Bool, Bool)] = [(CGPoint(x: c.minX, y: c.maxY), true, true), (CGPoint(x: c.maxX, y: c.maxY), true, false),
                                                    (CGPoint(x: c.minX, y: c.minY), false, true), (CGPoint(x: c.maxX, y: c.minY), false, false)]
            // 和 macOS 窗口标题栏一样：整张卡片都能拖，但平时是箭头；只有顶部那条拖动条上是张开的手
            let grab = CGRect(x: c.midX - 40, y: c.maxY - 22, width: 80, height: 22)
            if let k = corners.first(where: { hypot($0.0.x - p.x, $0.0.y - p.y) < 16 }) {
                cursor = CardCursor.resize(top: k.1, left: k.2)
            } else if grab.contains(p) {
                cursor = .openHand
            }
            if model.resizing { return }
        } else if let ch = layout.cheat.map(global) {
            // 小抄：只有左上角那六个小点上是张开的手
            let grip = CGRect(x: ch.minX + 6, y: ch.maxY - IslandMetrics.cheatGripHeight, width: 30, height: IslandMetrics.cheatGripHeight)
            if grip.contains(p) { cursor = .openHand }
        }
        if let cursor {
            cursor.set()
            customCursor = true
        } else if customCursor {
            NSCursor.arrow.set()
            customCursor = false
        }
    }

    private func handleScroll(_ e: NSEvent) -> NSEvent? {
        guard e.window === panel, engine.phase.isActive else { return e }
        if let c = cheatGlobal, c.contains(NSEvent.mouseLocation) { return e }
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
