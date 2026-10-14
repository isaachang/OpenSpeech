import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let store = ScriptStore()
    let settings = PrompterSettings()
    lazy var engine = PrompterEngine(settings: settings)
    private var island: IslandController?
    private var libraryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        buildMenu()

        let args = CommandLine.arguments
        if args.contains("--no-audio") { engine.audioDisabled = true }

        island = IslandController(
            engine: engine, store: store, settings: settings,
            actions: IslandActions(
                start: { [weak self] in self?.startSelected() },
                openLibrary: { [weak self] in self?.showLibrary() },
                importURLs: { [weak self] in self?.importFiles($0, fromIsland: true) },
                cycleScript: { [weak self] in self?.store.cycleSelection($0) },
                resetPosition: { [weak self] in self?.island?.resetPosition() }
            )
        )
        registerHotKeys()
        showLibrary()
        if args.contains("--autostart") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.startSelected() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if libraryWindow?.isVisible != true { showLibrary() }
        return true
    }

    // MARK: - Actions

    func startOrToggle() {
        switch engine.phase {
        case .idle, .finished: startSelected()
        case .countdown: engine.stop()
        case .presenting: engine.togglePause()
        }
    }

    func startSelected() {
        guard let s = store.selected else { showLibrary(); return }
        guard !ParsedScript.parse(s.body, keys: false).units.isEmpty else {
            let a = NSAlert()
            a.messageText = "这篇稿件还是空的"
            a.informativeText = "先写点内容，或者导入一个文件。"
            a.runModal()
            return
        }
        engine.start(script: s)
    }

    func importFiles(_ urls: [URL], fromIsland: Bool) {
        let (ok, errors) = store.importFiles(urls)
        if ok > 0 && fromIsland { island?.flash(ok == 1 ? "已导入" : "已导入 \(ok) 篇") }
        if !errors.isEmpty {
            let a = NSAlert()
            a.messageText = "有文件没能导入"
            a.informativeText = errors.joined(separator: "\n")
            a.runModal()
        }
    }

    @objc func newScript() {
        store.add(Script(title: "新稿件", body: ""))
        showLibrary()
    }

    @objc func importPanel() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        p.allowedContentTypes = ScriptImporter.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        p.message = "选择口播稿（txt / md / docx / pdf / rtf …）"
        NSApp.activate(ignoringOtherApps: true)
        if p.runModal() == .OK { importFiles(p.urls, fromIsland: false) }
    }

    @objc func pasteNew() {
        if let s = ScriptImporter.fromPasteboard() {
            store.add(s)
        } else {
            NSSound.beep()
        }
    }

    @objc func toggleAction() { startOrToggle() }

    /// 换显示样式；没在提词时顺便把稿子摆出来看看效果
    func chooseStyle(_ st: DisplayStyle) {
        settings.displayStyle = st
        if !engine.phase.isActive { previewSelected() }
    }

    @objc func resetPosition() {
        island?.resetPosition()
        if !engine.phase.isActive { previewSelected() }
    }

    /// 不开麦、不滚动，直接把稿子摆出来看位置
    func previewSelected() {
        guard let s = store.selected else { showLibrary(); return }
        if engine.phase == .presenting && engine.previewing { return }
        engine.start(script: s, preview: true)
    }

    @objc func openLogs() {
        try? FileManager.default.createDirectory(at: SessionLogger.directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(SessionLogger.directory)
    }
    @objc func stopAction() { engine.stop() }
    @objc func toggleTrackingLog() { settings.trackingLog.toggle() }
    @objc func toggleSaveAudio() { settings.saveAudio.toggle() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleTrackingLog): item.state = settings.trackingLog ? .on : .off
        case #selector(toggleSaveAudio):
            item.state = settings.saveAudio ? .on : .off
            return settings.trackingLog
        default: break
        }
        return true
    }

    @objc func showLibrary() {
        if libraryWindow == nil {
            let view = LibraryView(
                store: store, settings: settings,
                actions: LibraryActions(
                    start: { [weak self] in self?.startSelected() },
                    newScript: { [weak self] in self?.newScript() },
                    importPanel: { [weak self] in self?.importPanel() },
                    importURLs: { [weak self] in self?.importFiles($0, fromIsland: false) },
                    chooseStyle: { [weak self] in self?.chooseStyle($0) },
                    resetPosition: { [weak self] in self?.resetPosition() }
                )
            )
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "OpenSpeech"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
            w.contentView = NSHostingView(rootView: view)
            w.minSize = NSSize(width: 900, height: 560)
            w.center()
            w.setFrameAutosaveName("OpenSpeechLibrary")
            libraryWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        libraryWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Hotkeys & menu

    private func registerHotKeys() {
        let hk = HotKeyCenter.shared
        hk.register(.p) { [weak self] in self?.startOrToggle() }
        hk.register(.period) { [weak self] in self?.engine.stop() }
        hk.register(.up) { [weak self] in self?.engine.jumpLines(-1) }
        hk.register(.down) { [weak self] in self?.engine.jumpLines(1) }
        hk.register(.left) { [weak self] in self?.engine.adjustSpeed(-10) }
        hk.register(.right) { [weak self] in self?.engine.adjustSpeed(10) }
    }

    private func buildMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 OpenSpeech", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 OpenSpeech", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 OpenSpeech", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, to: main)

        let file = NSMenu(title: "文件")
        file.addItem(item("新建稿件", #selector(newScript), "n"))
        file.addItem(item("导入稿件…", #selector(importPanel), "o"))
        let paste = item("从剪贴板新建", #selector(pasteNew), "v")
        paste.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(paste)
        file.addItem(.separator())
        file.addItem(item("开始 / 暂停提词（⌥⌘P）", #selector(toggleAction), ""))
        file.addItem(item("结束提词（⌥⌘.）", #selector(stopAction), ""))
        file.addItem(item("提词器回到默认位置", #selector(resetPosition), ""))
        file.addItem(.separator())
        // 开发 / 调优用的选项，放在菜单里，不占设置面板
        let dev = NSMenu(title: "开发者选项")
        dev.addItem(item("记录跟随日志（只存本机）", #selector(toggleTrackingLog), ""))
        dev.addItem(item("保存测试录音（只存本机）", #selector(toggleSaveAudio), ""))
        dev.addItem(item("打开日志文件夹", #selector(openLogs), ""))
        let devItem = NSMenuItem(title: "开发者选项", action: nil, keyEquivalent: "")
        devItem.submenu = dev
        file.addItem(devItem)
        file.addItem(.separator())
        file.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        addSubmenu(file, to: main)

        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        addSubmenu(edit, to: main)

        let window = NSMenu(title: "窗口")
        window.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(item("OpenSpeech 主窗口", #selector(showLibrary), "1"))
        addSubmenu(window, to: main)

        NSApp.mainMenu = main
        NSApp.windowsMenu = window
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func addSubmenu(_ menu: NSMenu, to main: NSMenu) {
        let i = NSMenuItem()
        i.submenu = menu
        main.addItem(i)
    }
}
