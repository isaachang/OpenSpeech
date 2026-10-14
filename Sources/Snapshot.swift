import SwiftUI

/// `OpenPitch --snapshot <dir>`：把灵动岛 / 悬浮卡片的各个状态离屏渲染成 PNG（不需要录屏权限）
enum SnapshotRenderer {
    @MainActor
    static func run(dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let suite = "app.openpitch.snapshot"
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
            var preset: PlacementPreset?
            var phase: IslandPhase = .presenting
            var hovering = false
            var cardHovering = false
            var drop = false
            var paused = false
            var preview = false
            var mode: PrompterMode = .voice
        }
        let p = PlacementPreset.all
        let cases = [
            Case(name: "1-peek", preset: p[2], phase: .idle, hovering: true),
            Case(name: "2-preset-A", preset: p[0]),
            Case(name: "3-preset-B", preset: p[1]),
            Case(name: "4-preset-C", preset: p[2]),
            Case(name: "5-preset-D", preset: p[3]),
            Case(name: "6-preset-E", preset: p[4]),
            Case(name: "7-C-hover-island", preset: p[2], hovering: true, mode: .pace),
            Case(name: "8-C-drag-card", preset: p[2], cardHovering: true),
            Case(name: "9-C-preview", preset: p[2], paused: true, preview: true),
            Case(name: "10-C-countdown", preset: p[2], phase: .countdown(3)),
            Case(name: "11-finished", preset: p[2], phase: .finished),
        ]

        for c in cases {
            let settings = PrompterSettings(defaults: defaults)
            if let pr = c.preset { settings.apply(pr) }
            let engine = PrompterEngine(settings: settings)
            engine.audioDisabled = true
            engine.debugPresent(script: script, cursor: 58, phase: c.phase, paused: c.paused, mode: c.mode, preview: c.preview)
            let model = IslandModel()
            model.notch = notch
            model.geo = geo
            model.panelWidth = 900
            model.snapshot = true
            model.hovering = c.hovering
            model.cardHovering = c.cardHovering
            model.dropTargeted = c.drop
            let actions = IslandActions(start: {}, openLibrary: {}, importURLs: { _ in }, cycleScript: { _ in })
            let view = ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0x3B3F6B), Color(hex: 0x6E5A8A), Color(hex: 0xC98B7A)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(Color.black.opacity(0.18)).frame(height: notch.height)
                IslandRootView(model: model, engine: engine, store: store, settings: settings, actions: actions, acceptsDrop: false)
            }
            .frame(width: 900, height: 520)

            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(c.name).png"))
            }
        }
    }
}
