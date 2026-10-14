import SwiftUI

/// `OpenSpeech --snapshot <dir>`：把灵动岛 / 悬浮卡片的各个状态离屏渲染成 PNG（不需要录屏权限）
enum SnapshotRenderer {
    @MainActor
    static func run(dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let suite = "app.openspeech.snapshot"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ScriptStore(inMemory: true)
        let script = store.scripts[0]
        // 14" MacBook Pro（1800×1169 pt 缩放）的刘海与物理尺寸
        let notch = NotchInfo(width: 220, height: 38, hasNotch: true)
        let geo = ScreenGeo(mmPerPt: 0.168, cameraY: 19)

        struct Case {
            let name: String
            var style: DisplayStyle = .glass
            var phase: IslandPhase = .presenting
            var hovering = false
            var cardHovering = false
            var drag: CardPosition?
            var resizing = false
            var paused = false
            var preview = false
        }
        let W: CGFloat = 900, H: CGFloat = 520
        let home = IslandMetrics.defaultPosition(geo)
        let cases = [
            Case(name: "1-peek", phase: .idle, hovering: true),
            Case(name: "2-glass"),
            Case(name: "3-caption", style: .caption),
            Case(name: "4-glass-hover", cardHovering: true),
            Case(name: "5-caption-hover", style: .caption, cardHovering: true),
            Case(name: "6-glass-drag-offcenter", cardHovering: true, drag: CardPosition(dx: 150, readY: home.readY + 120)),
            Case(name: "7-caption-resize", style: .caption, cardHovering: true, resizing: true),
            Case(name: "8-glass-preview", paused: true, preview: true),
            Case(name: "9-glass-countdown", phase: .countdown(3)),
            Case(name: "10-caption-countdown", style: .caption, phase: .countdown(2)),
            Case(name: "11-finished", phase: .finished),
        ]

        for c in cases {
            let settings = PrompterSettings(defaults: defaults)
            settings.displayStyle = c.style
            let engine = PrompterEngine(settings: settings)
            engine.audioDisabled = true
            engine.debugPresent(script: script, cursor: 76, phase: c.phase, paused: c.paused, mode: .voice, preview: c.preview)
            let model = IslandModel()
            model.notch = notch
            model.geo = geo
            model.panelSize = CGSize(width: W, height: H)
            model.snapshot = true
            model.hovering = c.hovering
            model.cardHovering = c.cardHovering
            model.dragPos = c.drag
            model.resizing = c.resizing
            let actions = IslandActions(start: {}, openLibrary: {}, importURLs: { _ in }, cycleScript: { _ in }, resetPosition: {})
            let view = ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0x3B3F6B), Color(hex: 0x6E5A8A), Color(hex: 0xC98B7A)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(Color.black.opacity(0.18)).frame(height: notch.height)
                IslandRootView(model: model, engine: engine, store: store, settings: settings, actions: actions, acceptsDrop: false)
            }
            .frame(width: W, height: H)

            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(c.name).png"))
            }
        }
    }
}
