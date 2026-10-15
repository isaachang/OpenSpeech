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
        .background(Color(hex: 0x16161C).ignoresSafeArea())
        .overlay { UpdateOverlay(model: updates) }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Theme.accent)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.55)))
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.down.doc.fill").font(.system(size: 40)).foregroundStyle(Theme.accent)
                            Text("松手导入口播稿").font(.system(size: 18, weight: .bold))
                            Text("支持 txt · md · docx · doc · rtf · pdf · html").font(.system(size: 12)).foregroundColor(.secondary)
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
        .preferredColorScheme(.dark)
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
                IconButton(icon: "plus", help: "新建稿件（⌘N）", action: actions.newScript)
                IconButton(icon: "square.and.arrow.down", help: "导入文件（⌘O），也可以直接拖进窗口", action: actions.importPanel)
            }
            .padding(.top, 40)
            .padding(.horizontal, 6)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.scripts) { s in
                        ScriptRow(script: s, speed: settings.targetSpeed, selected: s.id == store.selectedID)
                            .onTapGesture { store.selectedID = s.id }
                            .contextMenu {
                                Button("删除", role: .destructive) { store.delete(s.id) }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .background(Color(hex: 0x111116))
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
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .help(help)
    }
}

private struct ScriptRow: View {
    let script: Script
    let speed: Double
    let selected: Bool

    var body: some View {
        let stats = ScriptStats(script.body)
        VStack(alignment: .leading, spacing: 3) {
            Text(script.title.isEmpty ? "未命名稿件" : script.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(stats.units == 0 ? stats.countText : "\(stats.countText) · 约 \(Fmt.clock(stats.duration(speed: speed)))")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).fill(selected ? Color.white.opacity(0.08) : .clear))
        .contentShape(Rectangle())
    }
}

// MARK: - 中：编辑

private struct EditorPane: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let updates: UpdateModel
    let actions: LibraryActions

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
                TextField("稿件标题", text: b.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .bold))

                HStack(spacing: 6) {
                    Text("\(stats.countText) · 约 \(Fmt.clock(stats.duration(speed: settings.targetSpeed))) · \(stats.isLatin ? "English" : "中文")"
                         + (stats.cues > 0 ? " · \(stats.cues) 处提示" : ""))
                    Image(systemName: "questionmark.circle")
                        .help("【停顿】【看镜头】写导演提示：显示成橙色，不用念，跟读时自动跳过。\n**重点** 标出要重读的词。")
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))

                TextEditor(text: b.body)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    Button(action: actions.start) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("开始提词")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.onAccent)
                        .padding(.horizontal, 26)
                        .frame(height: 40)
                        .background(Capsule().fill(Theme.accent))
                        .shadow(color: Theme.accent.opacity(0.18), radius: 14, y: 4)
                    }
                    .buttonStyle(PressStyle())
                    .keyboardShortcut(.return, modifiers: .command)

                    Text("⌥⌘P").font(.system(size: 11.5, weight: .medium)).foregroundColor(.white.opacity(0.4))
                        .help("在任何 App 里按 ⌥⌘P 开始 / 暂停")
                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 26)
            .padding(.top, 40)
            .padding(.bottom, 22)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "text.badge.plus").font(.system(size: 44)).foregroundStyle(Theme.accent)
                Text("还没有稿件").font(.system(size: 18, weight: .bold))
                Text("新建、粘贴，或者把 txt / md / docx / pdf 拖进来").foregroundColor(.secondary)
                HStack {
                    IslandButton(icon: "square.and.pencil", label: "新建稿件", prominent: true, action: actions.newScript)
                    IslandButton(icon: "square.and.arrow.down", label: "导入文件", action: actions.importPanel)
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
                Text("显示样式").font(.system(size: 11.5, weight: .semibold)).foregroundColor(.white.opacity(0.45))
                HStack(spacing: 10) {
                    ForEach(DisplayStyle.allCases) { st in
                        StyleThumb(style: st, selected: settings.displayStyle == st) { actions.chooseStyle(st) }
                    }
                }
            }

            HStack(spacing: 10) {
                Text("字号").font(.system(size: 13))
                Spacer()
                Image(systemName: "textformat.size.smaller").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
                Slider(value: Binding(get: { settings.fontSize }, set: { settings.fontSize = $0.rounded() }), in: 16...36).controlSize(.small).tint(Theme.control).frame(width: 110)
                Image(systemName: "textformat.size.larger").font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
            }
            .help("\(Int(settings.fontSize)) pt")

            SwitchRow(title: "共享屏幕时隐藏", isOn: $settings.hideFromCapture)
                .help("录屏、共享屏幕时对方看不到提词器")
            SwitchRow(title: "开始前倒计时", isOn: $settings.countdown)

            HStack {
                Text("显示在").font(.system(size: 13))
                Spacer()
                Picker("", selection: $settings.screenID) {
                    Text("自动").tag("")
                    ForEach(NSScreen.screens, id: \.self) { s in
                        Text(s.localizedName).tag(ScreenKey.of(s))
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            Button(action: actions.resetPosition) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                    Text("回到默认位置")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.07)))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .help("摄像头正下方。也可以直接双击提词卡片")

            Spacer()
            UpdateFooter(model: updates)
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
        .padding(.bottom, 20)
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
                    RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0x2C2C31))
                    Capsule().fill(Color.black).frame(width: 30, height: 6).offset(y: -1)
                    preview.padding(.top, 14)
                }
                .frame(height: 64)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.08)),
                                  lineWidth: selected ? 2 : 1))
                Text(style.title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .white : .white.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var preview: some View {
        if style == .glass {
            VStack(spacing: 4) {
                Capsule().fill(Color.white.opacity(0.35)).frame(width: 46, height: 2.5)
                Capsule().fill(Theme.accent).frame(width: 56, height: 3)
                Capsule().fill(Color.white.opacity(0.35)).frame(width: 46, height: 2.5)
            }
            .frame(width: 74, height: 34)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.65)))
        } else {
            Capsule().fill(Theme.amber).frame(width: 40, height: 3)
                .frame(width: 84, height: 18)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .padding(.top, 8)
        }
    }
}
