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

/// `OpenSpeech --snapshot-updates <dir>`：把更新横幅、更新卡片、进度、版本日志各个状态渲染成 PNG
enum UpdateSnapshot {
    @MainActor
    static func run(dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let sample = Changelog.parse("""
        ## [0.4.0] - 2026-11-01

        > 示例更新：修复了几个小问题。
        > Example update with a few small fixes.

        ### 新增 Added
        - 小抄可以调大小。
          The cheat sheet can be resized.
        ### 修复 Fixed
        - 外接屏上卡片位置偏移。
          Card position on external displays.
        - 暂停后偶尔要说两遍才继续。
          Resuming after a pause sometimes needed two tries.
        """).first

        func model(_ stage: UpdateModel.Stage, panel: UpdateModel.Panel? = nil, justUpdated: String? = nil) -> UpdateModel {
            let m = UpdateModel()
            m.release = sample
            m.releaseSize = 4_100_000
            m.stage = stage
            m.panel = panel
            m.justUpdated = justUpdated
            return m
        }
        func save<V: View>(_ name: String, width: CGFloat, height: CGFloat? = nil, _ view: V) {
            let r = ImageRenderer(content: view
                .padding(20)
                .frame(width: width, height: height, alignment: .top)
                .background(Theme.paper)
                .environment(\.colorScheme, .light))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }

        save("1-banner", width: 640, UpdateBanner(model: model(.available)))
        save("2-notes", width: 640, height: 640, UpdateOverlay(model: model(.available, panel: .notes)))
        save("3-downloading", width: 640, height: 560, UpdateOverlay(model: model(.downloading(received: 2_600_000, total: 4_100_000), panel: .progress)))
        save("4-installing", width: 640, height: 560, UpdateOverlay(model: model(.installing, panel: .progress)))
        save("5-failed", width: 640, height: 560, UpdateOverlay(model: model(.failed("网络断开了，检查网络后重试"), panel: .progress)))
        save("6-move", width: 640, height: 460, UpdateOverlay(model: model(.needsMove, panel: .move)))
        save("7-updated", width: 640, UpdateBanner(model: model(.idle, justUpdated: "0.3.1")))
        save("8-changelog-cards", width: 600, ChangelogList(model: model(.available)))
        let footers: [UpdateModel.Stage] = [.idle, .available, .checking, .upToDate, .checkFailed(offline: true), .checkFailed(offline: false)]
        save("9-footer", width: 320, VStack(spacing: 14) {
            ForEach(Array(footers.enumerated()), id: \.offset) { _, st in UpdateFooter(model: model(st)) }
        })
    }
}

/// `OpenSpeech --snapshot-readme <dir>`：README 用的干净截图（统一的桌面壁纸，不带屏幕上别的内容，不画刘海）
enum ReadmeSnapshot {
    @MainActor
    static func run(dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let suite = "app.openspeech.readme"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let zh = Lang.isChinese
        let pitch = zh ? Script(title: "OpenSpeech 一分钟介绍", body: SampleScripts.pitch)
                       : Script(title: "OpenSpeech in One Minute", body: SampleScripts.pitchEnglish)
        let notch = NotchInfo(width: 220, height: 38, hasNotch: true)
        let geo = ScreenGeo(mmPerPt: 0.168, cameraY: 19)

        /// 找某段文字（中文按字、英文按词）第一次出现的位置；offset：从这段文字的第几个字开始
        func unit(_ text: String, offset: Int = 0) -> Double {
            let p = ParsedScript.parse(pitch.body)
            let tokens: [String] = text.allSatisfy({ $0.isASCII })
                ? text.lowercased().split(separator: " ").map(String.init) : text.map { String($0) }
            for i in p.units.indices where i + tokens.count <= p.units.count {
                if zip(tokens, p.units[i..<(i + tokens.count)]).allSatisfy({ $0.0 == $0.1.text }) { return Double(i + offset) }
            }
            return 0
        }

        /// 被共享出去的那块屏幕：一页演示文稿
        func slide() -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840], id: \.self) { c in Circle().fill(Color(hex: UInt32(c))).frame(width: 9, height: 9) }
                    Spacer()
                }
                .padding(10)
                .background(Color(hex: 0xECECEF))
                VStack(alignment: .leading, spacing: 14) {
                    Text(zh ? "Q3 产品规划" : "Q3 Product Plan").font(.system(size: 30, weight: .bold)).foregroundColor(Color(hex: 0x1C1C1E))
                    ForEach(zh ? ["用户增长：月活 +35%", "上线协作空间", "移动端体验重做"] : ["Growth: MAU +35%", "Launch shared workspaces", "Rebuild the mobile app"], id: \.self) { t in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0x5B5BD6)).frame(width: 4, height: 18)
                            Text(t).font(.system(size: 17)).foregroundColor(Color(hex: 0x3A3A3F))
                        }
                    }
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach([0.45, 0.62, 0.8, 1.0], id: \.self) { h in
                            RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x5B5BD6).opacity(0.25 + 0.6 * h)).frame(width: 46, height: 110 * h)
                        }
                    }
                    .padding(.top, 6)
                    Spacer()
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        }

        func render(_ name: String, w: CGFloat, h: CGFloat, cursor: Double, style: DisplayStyle = .glass,
                    cheat: Bool = false, cardHovering: Bool = false, showCard: Bool = true, presentation: Bool = false,
                    transparent: Bool = false) {
            let settings = PrompterSettings(defaults: defaults)
            settings.displayStyle = style
            settings.cheatSheet = cheat
            settings.tipsDismissed = true
            settings.cheatTipDismissed = true
            let engine = PrompterEngine(settings: settings)
            engine.audioDisabled = true
            engine.debugPresent(script: pitch, cursor: cursor, phase: .presenting, mode: .voice)
            let model = IslandModel()
            model.notch = notch
            model.geo = geo
            model.panelSize = CGSize(width: w, height: h)
            model.snapshot = true
            model.hideIsland = true
            model.cardHovering = cardHovering
            let s = ScriptStore(inMemory: true)
            let actions = IslandActions(start: {}, openLibrary: {}, importURLs: { _ in }, cycleScript: { _ in }, resetPosition: {})
            let view = ZStack(alignment: .top) {
                if !transparent {
                    LinearGradient(colors: [Color(hex: 0x3C3F8F), Color(hex: 0x6A4E8E), Color(hex: 0xB9787E), Color(hex: 0xD99A7C)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                if presentation { slide().padding(.horizontal, 70).padding(.top, 140).padding(.bottom, 40) }
                if showCard {
                    IslandRootView(model: model, engine: engine, store: s, settings: settings, actions: actions, acceptsDrop: false)
                }
            }
            .frame(width: w, height: h)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
        }

        // 首图 / 提词卡片：停在 “OpenSpeech 是什么” 这一段，荧光笔在 “镜头” / “eye contact”
        let whatItIs = zh ? unit("摄像头") : unit("right below the camera", offset: 1)
        render("hero", w: 1280, h: 640, cursor: whatItIs, cheat: true)
        render("card", w: 900, h: 400, cursor: whatItIs, cardHovering: true)
        render("heading", w: 900, h: 340, cursor: zh ? unit("它会听") : unit("it listens"))
        render("caption", w: 900, h: 300, cursor: zh ? unit("提词器") : unit("teleprompter"), style: .caption)
        // 共享屏幕对比：你看到的（演示文稿 + 提词卡片）和对方看到的（只有演示文稿）
        render("share-you", w: 900, h: 560, cursor: whatItIs, presentation: true)
        render("share-them", w: 900, h: 560, cursor: whatItIs, showCard: false, presentation: true)
        // 只有提词卡片、背景透明：叠到真实桌面截图上（共享屏幕对比图用）
        render("card-only", w: 900, h: 600, cursor: whatItIs, transparent: true)
    }
}
