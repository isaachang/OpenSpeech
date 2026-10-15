import SwiftUI
import UniformTypeIdentifiers

struct LibraryActions {
    var start: () -> Void
    var newScript: () -> Void
    var importPanel: () -> Void
    var importURLs: ([URL]) -> Void
    var chooseStyle: (DisplayStyle) -> Void
    var resetPosition: () -> Void
}

/// 主窗口：左边稿件列表 · 中间编辑 · 右边只放 6 项设置
struct LibraryView: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let updates: UpdateModel
    let actions: LibraryActions
    @State private var dropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(store: store, settings: settings, actions: actions).frame(width: 250)
            EditorPane(store: store, settings: settings, updates: updates, actions: actions)
            SettingsPane(settings: settings, updates: updates, actions: actions).frame(width: 270)
        }
        .background(Theme.paper.ignoresSafeArea())
        .foregroundColor(Theme.ink)
        .overlay { UpdateOverlay(model: updates) }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Theme.ink)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.paper.opacity(0.92)))
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.down.doc.fill").font(.system(size: 40)).foregroundStyle(Theme.ink)
                            Text(tr("松手导入口播稿", "Drop to import")).font(.system(size: 18, weight: .bold))
                            Text(tr("支持 txt · md · docx · doc · rtf · pdf · html", "txt · md · docx · doc · rtf · pdf · html")).font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    )
                    .padding(14)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            for p in providers where p.canLoadObject(ofClass: URL.self) {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { actions.importURLs([url]) } }
                }
            }
            return true
        }
        .frame(minWidth: 900, minHeight: 560)
        .preferredColorScheme(.light)
    }
}

// MARK: - 左：稿件列表

private struct Sidebar: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let actions: LibraryActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("OpenSpeech").font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                IconButton(icon: "plus", help: tr("新建稿件（⌘N）", "New script (⌘N)"), action: actions.newScript)
                IconButton(icon: "square.and.arrow.down", help: tr("导入文件（⌘O），也可以直接拖进窗口", "Import files (⌘O), or drop them into the window"), action: actions.importPanel)
            }
            .padding(.top, 40)
            .padding(.horizontal, 6)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.scripts) { s in
                        ScriptRow(store: store, script: s, speed: settings.targetSpeed, selected: s.id == store.selectedID)
                            .onTapGesture { store.selectedID = s.id }
                            .contextMenu { ScriptMenuItems(store: store, script: s) }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            if let d = store.lastDeleted {
                UndoToast(title: d.script.title, undo: store.undoDelete)
                    .padding(.horizontal, 12).padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: d.script.id) {
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        withAnimation(.easeOut(duration: 0.25)) { store.forgetDeleted(d.script.id) }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.lastDeleted)
        .background(Theme.paperSide)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea() }
    }
}

private struct IconButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.ink2)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .help(help)
    }
}

private struct ScriptRow: View {
    @ObservedObject var store: ScriptStore
    let script: Script
    let speed: Double
    let selected: Bool
    @State private var hover = false
    @State private var menuHover = false

    var body: some View {
        let stats = ScriptStats(script.body)
        VStack(alignment: .leading, spacing: 3) {
            Text(script.title.isEmpty ? tr("未命名稿件", "Untitled") : script.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(stats.units == 0 ? stats.countText : tr("\(stats.countText) · 约 \(Fmt.clock(stats.duration(speed: speed)))", "\(stats.countText) · ~\(Fmt.clock(stats.duration(speed: speed)))"))
                .font(.system(size: 11))
                .foregroundColor(Theme.ink3)
        }
        .padding(.vertical, 9)
        .padding(.leading, 12)
        .padding(.trailing, hover || selected ? 38 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(selected ? Theme.selRow : hover ? Theme.wash : .clear))
        .overlay(alignment: .trailing) {
            // 「⋯」：重命名、复制一份、导出、删除。移开鼠标只是变透明，菜单打开时不会被拿掉
            Menu { ScriptMenuItems(store: store, script: script) } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.ink2)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(menuHover ? 0.11 : 0.05)))
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .onHover { menuHover = $0 }
            .help(tr("更多：重命名、复制、导出、删除", "More: rename, duplicate, export, delete"))
            .padding(.trailing, 8)
            .opacity(hover || selected ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// 稿件的「⋯」菜单和右键菜单
private struct ScriptMenuItems: View {
    let store: ScriptStore
    let script: Script

    var body: some View {
        Button(tr("重命名", "Rename")) { store.rename(script.id) }
        Button(tr("复制一份", "Duplicate")) { store.duplicate(script.id) }
        Button(tr("导出为 Markdown…", "Export as Markdown…")) { ScriptExport.markdown(script) }
        Divider()
        Button(tr("删除", "Delete"), role: .destructive) { store.delete(script.id) }
    }
}

/// 删掉以后侧栏底部的 “已删除 · 撤销”，几秒后自己消失
private struct UndoToast: View {
    let title: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(tr("已删除「\(title.isEmpty ? "未命名稿件" : title)」", "Deleted \u{201C}\(title.isEmpty ? "Untitled" : title)\u{201D}"))
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Button(action: undo) {
                Text(tr("撤销", "Undo")).font(.system(size: 11.5, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).frame(height: 22)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(PressStyle())
        }
        .padding(.leading, 12).padding(.trailing, 8).frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

/// 把稿子存成 .md 文件
enum ScriptExport {
    static func markdown(_ s: Script) {
        let panel = NSSavePanel()
        let name = (s.title.isEmpty ? tr("未命名稿件", "Untitled") : s.title).replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = name + ".md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.begin { r in
            guard r == .OK, let url = panel.url else { return }
            try? s.body.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - 中：编辑

private struct EditorPane: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let updates: UpdateModel
    let actions: LibraryActions
    @FocusState private var titleFocused: Bool

    private var binding: Binding<Script>? {
        guard let id = store.selectedID, store.scripts.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.scripts.first { $0.id == id } ?? Script(title: "", body: "") },
            set: { new in
                guard let i = store.scripts.firstIndex(where: { $0.id == id }) else { return }
                var s = new
                s.updatedAt = Date()
                store.scripts[i] = s
            }
        )
    }

    var body: some View {
        if let b = binding {
            let stats = ScriptStats(b.wrappedValue.body)
            VStack(alignment: .leading, spacing: 10) {
                UpdateBanner(model: updates)
                ZoomTip(settings: settings)
                TextField(tr("稿件标题", "Script title"), text: b.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .bold))
                    .focused($titleFocused)
                    .onChange(of: store.renameRequest) { id in
                        guard id != nil else { return }
                        titleFocused = true
                        store.renameRequest = nil
                    }

                HStack(spacing: 6) {
                    Text(tr("\(stats.countText) · 约 \(Fmt.clock(stats.duration(speed: settings.targetSpeed))) · \(stats.isLatin ? "English" : "中文")",
                            "\(stats.countText) · ~\(Fmt.clock(stats.duration(speed: settings.targetSpeed))) · \(stats.isLatin ? "English" : "Chinese")")
                         + (stats.cues > 0 ? tr(" · \(stats.cues) 处提示", " · \(stats.cues) cues") : ""))
                    Image(systemName: "questionmark.circle")
                        .help(tr("# 大标题 · ## 中标题 · ### 小标题（⌘⌥1 / 2 / 3）：只是路牌，提词时不用念。# 和 ## 是段落，提词时可以跳过去（⌥⌘← / ⌥⌘→、⌥⌘1…9）。\n【停顿】【看镜头】写导演提示：显示成橙色，不用念，跟读时自动跳过。\n**重点** 标出要重读的词。", "# large · ## medium · ### small heading (⌘⌥1 / 2 / 3): signposts you don't read aloud. # and ## are sections you can jump to (⌥⌘← / ⌥⌘→, ⌥⌘1…9).\n[Pause] or 【…】 are stage directions: orange, optional to read.\n**word** marks emphasis."))
                }
                .font(.system(size: 12))
                .foregroundColor(Theme.ink3)

                ScriptEditor(text: b.body, documentID: store.selectedID)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.sheet))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    Button(action: actions.start) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(tr("开始提词", "Start"))
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.primaryText)
                        .padding(.horizontal, 26)
                        .frame(height: 40)
                        .background(Capsule().fill(Theme.primaryFill))
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                    }
                    .buttonStyle(PressStyle())
                    .keyboardShortcut(.return, modifiers: .command)

                    Text("⌥⌘P").font(.system(size: 11.5, weight: .medium)).foregroundColor(Theme.ink3)
                        .help(tr("在任何 App 里按 ⌥⌘P 开始 / 暂停", "Press ⌥⌘P in any app to start / pause"))
                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 26)
            .padding(.top, 40)
            .padding(.bottom, 22)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "text.badge.plus").font(.system(size: 44)).foregroundStyle(Theme.ink)
                Text(tr("还没有稿件", "No scripts yet")).font(.system(size: 18, weight: .bold))
                Text(tr("新建、粘贴，或者把 txt / md / docx / pdf 拖进来", "Create, paste, or drop in a txt / md / docx / pdf")).foregroundColor(.secondary)
                HStack {
                    IslandButton(icon: "square.and.pencil", label: tr("新建稿件", "New script"), prominent: true, onDark: false, action: actions.newScript)
                    IslandButton(icon: "square.and.arrow.down", label: tr("导入文件", "Import"), onDark: false, action: actions.importPanel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 右：设置

private struct SettingsPane: View {
    @ObservedObject var settings: PrompterSettings
    let updates: UpdateModel
    let actions: LibraryActions

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("显示样式", "Style")).font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.ink3)
                HStack(spacing: 10) {
                    ForEach(DisplayStyle.allCases) { st in
                        StyleThumb(style: st, selected: settings.displayStyle == st) { actions.chooseStyle(st) }
                    }
                }
            }

            HStack(spacing: 10) {
                Text(tr("字号", "Text size")).font(.system(size: 13))
                Spacer()
                Image(systemName: "textformat.size.smaller").font(.system(size: 10)).foregroundColor(Theme.ink3)
                Slider(value: Binding(get: { settings.fontSize }, set: { settings.fontSize = $0.rounded() }), in: 16...36).controlSize(.small).tint(Theme.control).frame(width: 110)
                Image(systemName: "textformat.size.larger").font(.system(size: 12)).foregroundColor(Theme.ink3)
            }
            .help("\(Int(settings.fontSize)) pt")

            SwitchRow(title: tr("共享屏幕时隐藏", "Hide when sharing screen"), isOn: $settings.hideFromCapture)
                .help(tr("录屏、共享屏幕时对方看不到提词器", "Others can't see the prompter in recordings or screen shares"))
            SwitchRow(title: tr("开会时减少外放回声", "Reduce speaker echo in meetings"), isOn: $settings.echoReduction)
                .help(tr("用扬声器外放开会时打开：麦克风不再把对方的声音当成你在说话。戴耳机不需要。下次开始提词时生效。",
                         "Turn on when meeting audio plays through your speakers, so the mic doesn't pick up other people. Not needed with headphones. Takes effect next time you start."))
            SwitchRow(title: tr("开始前倒计时", "Countdown before start"), isOn: $settings.countdown)

            HStack {
                Text(tr("显示在", "Show on")).font(.system(size: 13))
                Spacer()
                Picker("", selection: $settings.screenID) {
                    Text(tr("自动", "Automatic")).tag("")
                    ForEach(NSScreen.screens, id: \.self) { s in
                        Text(s.localizedName).tag(ScreenKey.of(s))
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            HStack {
                Text(tr("界面语言", "Language")).font(.system(size: 13))
                Spacer()
                Picker("", selection: Binding(get: { Lang.choice }, set: { Lang.set($0) })) {
                    ForEach(Lang.Choice.allCases) { c in Text(c.title).tag(c) }
                }
                .labelsHidden()
                .frame(width: 140)
                .help(tr("切换后 App 会自动重新打开", "OpenSpeech relaunches to apply"))
            }

            Button(action: actions.resetPosition) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                    Text(tr("回到默认位置和大小", "Reset position and size"))
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Theme.buttonText)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.buttonFill))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .help(tr("摄像头正下方、预设大小。也可以直接双击提词卡片", "Right below the camera, default size. You can also double-click the card"))

            Spacer()
            UpdateFooter(model: updates)
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
        .padding(.bottom, 20)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea() }
    }
}

private struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.control)
        }
    }
}

/// 两种显示样式的缩略图
private struct StyleThumb: View {
    let style: DisplayStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.thumb)
                    Capsule().fill(Color.black).frame(width: 30, height: 6).offset(y: -1)
                    preview.padding(.top, 14)
                }
                .frame(height: 64)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? AnyShapeStyle(Theme.selection) : AnyShapeStyle(Theme.line),
                                  lineWidth: selected ? 2 : 1))
                Text(style.title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? Theme.ink : Theme.ink2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var preview: some View {
        if style == .glass {
            VStack(spacing: 4) {
                Capsule().fill(Theme.ink.opacity(0.22)).frame(width: 46, height: 2.5)
                Capsule().fill(Theme.ink).frame(width: 56, height: 3)
                    .background(Capsule().fill(Theme.highlighter).frame(width: 24, height: 6), alignment: .trailing)
                Capsule().fill(Theme.ink.opacity(0.22)).frame(width: 46, height: 2.5)
            }
            .frame(width: 74, height: 34)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
        } else {
            Capsule().fill(Theme.amber).frame(width: 40, height: 3)
                .frame(width: 84, height: 18)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .padding(.top, 8)
        }
    }
}
