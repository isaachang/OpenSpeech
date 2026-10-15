import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    /// --demo-scripts：只用内置示例稿、不读写真实稿件库（截图 / 测试用）
    let store = ScriptStore(inMemory: CommandLine.arguments.contains("--demo-scripts") || CommandLine.arguments.contains("--demo-interview"))
    let settings = PrompterSettings()
    lazy var engine = PrompterEngine(settings: settings)
    let updates = UpdateModel()
    private lazy var updater = UpdateController(model: updates)
    private var island: IslandController?
    private var libraryWindow: NSWindow?
    private var bag: Set<AnyCancellable> = []
    /// 提词时才占用的 ⌥⌘1…9（跳到第几段）
    private var sectionKeys: [UInt32] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        buildMenu()

        let args = CommandLine.arguments
        if args.contains("--no-audio") { engine.audioDisabled = true }
        if args.contains("--demo-interview") { store.selectedID = store.scripts.first { $0.title.contains("面试") || $0.title.contains("Interview") }?.id }

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
        startUpdates()
        if args.contains("--autostart") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.startSelected() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if libraryWindow?.isVisible != true { showLibrary() }
        return true
    }

    // MARK: - Updates

    private func startUpdates() {
        // 正在提词（不算预览）时不弹更新横幅，讲完再提示
        engine.$phase.combineLatest(engine.$previewing)
            .map { phase, preview in phase.isActive && !preview }
            .removeDuplicates()
            .sink { [weak self] in self?.updates.prompting = $0 }
            .store(in: &bag)
        updater.start()
        if let v = updates.justUpdated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.island?.flash(tr("✓ 已更新到 \(v)", "✓ Updated to \(v)")) }
        }
    }

    @objc func checkForUpdates() { showLibrary(); updater.checkNow() }
    @objc func showChangelog() { showLibrary(); updates.panel = .changelog }

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
            a.messageText = tr("这篇稿件还是空的", "This script is empty")
            a.informativeText = tr("先写点内容，或者导入一个文件。", "Write something first, or import a file.")
            a.runModal()
            return
        }
        engine.start(script: s)
    }

    func importFiles(_ urls: [URL], fromIsland: Bool) {
        let (ok, errors) = store.importFiles(urls)
        if ok > 0 && fromIsland { island?.flash(ok == 1 ? tr("已导入", "Imported") : tr("已导入 \(ok) 篇", "Imported \(ok) scripts")) }
        if !errors.isEmpty {
            let a = NSAlert()
            a.messageText = tr("有文件没能导入", "Some files couldn't be imported")
            a.informativeText = errors.joined(separator: "\n")
            a.runModal()
        }
    }

    @objc func newScript() {
        store.add(Script(title: tr("新稿件", "New script"), body: ""))
        showLibrary()
    }

    @objc func importPanel() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        p.allowedContentTypes = ScriptImporter.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        p.message = tr("选择口播稿（txt / md / docx / pdf / rtf …）", "Choose scripts (txt / md / docx / pdf / rtf …)")
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
    @objc func toggleCheatSheet() { settings.cheatSheet.toggle() }
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
                store: store, settings: settings, updates: updates,
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
            w.backgroundColor = NSColor(red: 0.984, green: 0.98, blue: 0.969, alpha: 1)
            w.appearance = NSAppearance(named: .aqua)
            w.contentView = NSHostingView(rootView: view)
            w.minSize = NSSize(width: 900, height: 560)
            w.center()
            w.setFrameAutosaveName("OpenSpeechLibrary")
            libraryWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        libraryWindow?.makeKeyAndOrderFront(nil)
        updater.checkIfStale()
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
        hk.register(.o) { [weak self] in self?.toggleCheatSheet() }
        // ⌥⌘1…9 只在提词、而且稿子里有标题时才占用；平时还给别的 App
        engine.$phase.combineLatest(engine.$parsed)
            .map { phase, parsed in phase.isActive ? min(9, parsed.sections.count) : 0 }
            .removeDuplicates()
            .sink { [weak self] n in self?.updateSectionKeys(n) }
            .store(in: &bag)
    }

    private func updateSectionKeys(_ count: Int) {
        sectionKeys.forEach { HotKeyCenter.shared.unregister($0) }
        sectionKeys = HotKeyCenter.Key.digits.prefix(count).enumerated().compactMap { n, key in
            HotKeyCenter.shared.register(key) { [weak self] in self?.engine.jump(toSection: n) }
        }
    }

    private func buildMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("关于 OpenSpeech", "About OpenSpeech"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(item(tr("检查更新…", "Check for Updates…"), #selector(checkForUpdates), ""))
        appMenu.addItem(item(tr("版本日志", "Version History"), #selector(showChangelog), ""))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("隐藏 OpenSpeech", "Hide OpenSpeech"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: tr("退出 OpenSpeech", "Quit OpenSpeech"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, to: main)

        let file = NSMenu(title: tr("文件", "File"))
        file.addItem(item(tr("新建稿件", "New Script"), #selector(newScript), "n"))
        file.addItem(item(tr("导入稿件…", "Import Scripts…"), #selector(importPanel), "o"))
        let paste = item(tr("从剪贴板新建", "New from Clipboard"), #selector(pasteNew), "v")
        paste.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(paste)
        file.addItem(.separator())
        file.addItem(item(tr("开始 / 暂停提词（⌥⌘P）", "Start / Pause (⌥⌘P)"), #selector(toggleAction), ""))
        file.addItem(item(tr("结束提词（⌥⌘.）", "Stop (⌥⌘.)"), #selector(stopAction), ""))
        file.addItem(item(tr("提词器回到默认位置和大小", "Reset Prompter Position and Size"), #selector(resetPosition), ""))
        file.addItem(item(tr("显示 / 隐藏小抄（⌥⌘O）", "Show / Hide Cheat Sheet (⌥⌘O)"), #selector(toggleCheatSheet), ""))
        file.addItem(.separator())
        // 开发 / 调优用的选项，放在菜单里，不占设置面板
        let dev = NSMenu(title: tr("开发者选项", "Developer Options"))
        dev.addItem(item(tr("记录跟随日志（只存本机）", "Record Tracking Logs (Local Only)"), #selector(toggleTrackingLog), ""))
        dev.addItem(item(tr("保存测试录音（只存本机）", "Save Test Recordings (Local Only)"), #selector(toggleSaveAudio), ""))
        dev.addItem(item(tr("打开日志文件夹", "Open Logs Folder"), #selector(openLogs), ""))
        let devItem = NSMenuItem(title: tr("开发者选项", "Developer Options"), action: nil, keyEquivalent: "")
        devItem.submenu = dev
        file.addItem(devItem)
        file.addItem(.separator())
        file.addItem(withTitle: tr("关闭窗口", "Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        addSubmenu(file, to: main)

        let edit = NSMenu(title: tr("编辑", "Edit"))
        edit.addItem(withTitle: tr("撤销", "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: tr("重做", "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("剪切", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("拷贝", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("粘贴", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("全选", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        // 和 Notion 一样：⌘⌥1 / 2 / 3 大 / 中 / 小标题，⌘⌥0 正文
        for (title, sel, key) in [(tr("大标题", "Large Heading"), #selector(ScriptTextView.setHeading1(_:)), "1"),
                                  (tr("中标题", "Medium Heading"), #selector(ScriptTextView.setHeading2(_:)), "2"),
                                  (tr("小标题", "Small Heading"), #selector(ScriptTextView.setHeading3(_:)), "3"),
                                  (tr("正文", "Body Text"), #selector(ScriptTextView.setBodyText(_:)), "0")] {
            let i = edit.addItem(withTitle: title, action: sel, keyEquivalent: key)
            i.keyEquivalentModifierMask = [.command, .option]
        }
        addSubmenu(edit, to: main)

        let window = NSMenu(title: tr("窗口", "Window"))
        window.addItem(withTitle: tr("最小化", "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(item(tr("OpenSpeech 主窗口", "OpenSpeech Main Window"), #selector(showLibrary), "1"))
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
