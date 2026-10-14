import SwiftUI
import UniformTypeIdentifiers

struct LibraryActions {
    var start: () -> Void
    var preview: () -> Void
    var applyPreset: (PlacementPreset) -> Void
    var newScript: () -> Void
    var importPanel: () -> Void
    var pasteNew: () -> Void
    var importURLs: ([URL]) -> Void
}

struct LibraryView: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let actions: LibraryActions
    @State private var dropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(store: store, actions: actions).frame(width: 240)
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
            EditorPane(store: store, settings: settings, actions: actions)
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
            SettingsPane(settings: settings, actions: actions).frame(width: 300)
        }
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: 0x101019), Color(hex: 0x08080C)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Theme.indigo.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 520)
                RadialGradient(colors: [Theme.mint.opacity(0.06), .clear], center: .bottomLeading, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        )
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
        .frame(minWidth: 1020, minHeight: 620)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var store: ScriptStore
    let actions: LibraryActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                AppGlyph(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenPitch").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("刘海里的口播提词器").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(.top, 44)

            HStack(spacing: 6) {
                SideButton(icon: "square.and.pencil", title: "新建", action: actions.newScript)
                SideButton(icon: "square.and.arrow.down", title: "导入", action: actions.importPanel)
                SideButton(icon: "doc.on.clipboard", title: "粘贴", action: actions.pasteNew)
            }

            Text("我的稿件").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).padding(.top, 4)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.scripts) { s in
                        ScriptRow(script: s, selected: s.id == store.selectedID)
                            .onTapGesture { store.selectedID = s.id }
                            .contextMenu {
                                Button("删除", role: .destructive) { store.delete(s.id) }
                            }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("拖进来就能导入", systemImage: "hand.draw.fill").font(.system(size: 11.5, weight: .semibold))
                Text("把文件拖进这个窗口，或者直接拖到屏幕顶部的刘海上。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 14)
        .background(Color.black.opacity(0.18))
    }
}

private struct SideButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 10.5, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

private struct ScriptRow: View {
    let script: Script
    let selected: Bool

    var body: some View {
        let stats = ScriptStats(script.body)
        VStack(alignment: .leading, spacing: 3) {
            Text(script.title.isEmpty ? "未命名稿件" : script.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(script.body.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text("\(stats.countText) · \(script.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.white.opacity(0.09) : .clear))
        .overlay(alignment: .leading) {
            if selected { Capsule().fill(Theme.accent).frame(width: 3, height: 24) }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Editor

private struct EditorPane: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
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
            VStack(alignment: .leading, spacing: 14) {
                TextField("稿件标题", text: b.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .bold))

                HStack(spacing: 8) {
                    StatChip(icon: "character.cursor.ibeam", text: stats.countText)
                    StatChip(icon: "clock", text: "约 \(Fmt.clock(stats.duration(speed: settings.targetSpeed)))")
                    StatChip(icon: "globe", text: stats.isLatin ? "English" : "中文")
                    if stats.cues > 0 { StatChip(icon: "theatermasks.fill", text: "\(stats.cues) 处导演提示") }
                }

                TextEditor(text: b.body)
                    .font(.system(size: 15))
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))

                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill").foregroundColor(Theme.amber)
                    Text("用 ")
                        + Text("【停顿】【看镜头】").foregroundColor(Theme.cue)
                        + Text(" 写导演提示（不用念，跟读时自动跳过）；用 ")
                        + Text("**重点**").foregroundColor(Theme.emphasis)
                        + Text(" 标出要重读的词。")
                }
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)

                HStack(spacing: 14) {
                    Button(action: actions.start) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("在灵动岛开始提词")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .frame(height: 42)
                        .background(Capsule().fill(Theme.accent))
                        .shadow(color: Theme.indigo.opacity(0.5), radius: 16, y: 4)
                    }
                    .buttonStyle(PressStyle())
                    .keyboardShortcut(.return, modifiers: .command)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("⌘↩ 或 ⌥⌘P 开始").font(.system(size: 11.5, weight: .medium))
                        Text("提词时可以切到任何 App，快捷键全局有效").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 28)
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

private struct StatChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10.5, weight: .semibold))
            Text(text)
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Settings

private struct SettingsPane: View {
    @ObservedObject var settings: PrompterSettings
    let actions: LibraryActions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(text: "提词模式")
                VStack(spacing: 8) {
                    ForEach(PrompterMode.allCases) { m in
                        ModeCard(mode: m, selected: settings.mode == m) { settings.mode = m }
                    }
                }

                SectionTitle(text: "语速")
                SliderRow(title: "目标语速", value: $settings.targetSpeed, range: 120...360, step: 10,
                          display: "\(Int(settings.targetSpeed)) 字/分")
                Text("跟读模式：用来提示你“偏快 / 偏慢”。匀速模式：就是滚动速度。英文稿自动按约 60% 换算成 词/分。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    SectionTitle(text: "位置与尺寸")
                    Spacer()
                    Text(settings.activePreset.map { "当前：预设 \($0.letter)" } ?? "当前：自定义")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.mint)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(PlacementPreset.all) { p in
                        PresetCard(preset: p, selected: settings.activePreset == p) { actions.applyPreset(p) }
                    }
                }
                Button(action: actions.preview) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("预览位置（不开麦）")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.1)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                Text("预览时可以直接拖动卡片调高度；在任何地方按 ⌥⌘1–5 切换预设，⌥⌘P 正式开始。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("", selection: $settings.layoutStyle) {
                    ForEach(LayoutStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if settings.layoutStyle == .card {
                    SliderRow(title: "离镜头", value: $settings.cardDegrees, range: 0...14, step: 0.5,
                              display: String(format: "%.1f° · %.1f cm", settings.cardDegrees,
                                              settings.viewingDistance * tan(settings.cardDegrees * .pi / 180)))
                    HStack {
                        Text("对齐").font(.system(size: 12.5))
                        Spacer()
                        Picker("", selection: $settings.cardAlign) {
                            ForEach(TextAlign.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 140)
                    }
                }
                SliderRow(title: "每行字数", value: Binding(get: { Double(settings.lineChars) }, set: { settings.lineChars = Int($0) }),
                          range: 8...30, step: 1, display: "约 \(settings.lineChars) 字")
                SliderRow(title: "字号", value: $settings.fontSize, range: 16...36, step: 1, display: "\(Int(settings.fontSize)) pt")
                HStack {
                    Text("显示行数").font(.system(size: 12.5))
                    Spacer()
                    Picker("", selection: $settings.visibleLines) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 170)
                }
                SliderRow(title: "你离屏幕", value: $settings.viewingDistance, range: 35...90, step: 5,
                          display: "\(Int(settings.viewingDistance)) cm")
                Text("用来把“度”换算成屏幕上的位置。笔记本放桌上一般是 50–60 cm。")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SectionTitle(text: "细节")
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("开始前 3 秒倒计时", isOn: $settings.countdown)
                    Toggle("匀速模式：不说话时自动停住", isOn: $settings.pauseOnSilence)
                    Toggle("录屏 / 共享屏幕时隐藏提词器", isOn: $settings.hideFromCapture)
                    Toggle("记录跟随日志（只存本机，用于调优）", isOn: $settings.trackingLog)
                    Toggle("保存测试录音（只存本机，用于对比识别效果）", isOn: $settings.saveAudio)
                        .disabled(!settings.trackingLog)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 12.5))
                HStack {
                    Text("显示在").font(.system(size: 12.5))
                    Spacer()
                    Picker("", selection: $settings.screenChoice) {
                        ForEach(ScreenChoice.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                SectionTitle(text: "全局快捷键")
                VStack(spacing: 7) {
                    ShortcutRow(keys: "⌥⌘P", text: "开始 / 暂停 / 继续")
                    ShortcutRow(keys: "⌥⌘↑  ⌥⌘↓", text: "上一行 / 下一行")
                    ShortcutRow(keys: "⌥⌘←  ⌥⌘→", text: "匀速 减速 / 加速")
                    ShortcutRow(keys: "⌥⌘.", text: "结束提词")
                    ShortcutRow(keys: "⌥⌘1 … ⌥⌘5", text: "切换位置预设 A–E")
                    ShortcutRow(keys: "双指滑动", text: "在灵动岛上手动翻行")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .background(Color.black.opacity(0.12))
    }
}

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.45)).textCase(.uppercase)
    }
}

private struct ModeCard: View {
    let mode: PrompterMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 34, height: 34)
                    Image(systemName: mode.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(selected ? .black : .white.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(mode.title).font(.system(size: 13.5, weight: .semibold))
                        if mode == .voice {
                            Text("推荐").font(.system(size: 9.5, weight: .bold)).foregroundColor(.black)
                                .padding(.horizontal, 5).padding(.vertical, 1.5)
                                .background(Capsule().fill(Theme.mint))
                        }
                    }
                    Text(mode.detail).font(.system(size: 11.5)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(selected ? 0.07 : 0.025)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.08)),
                                  lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12.5))
                Spacer()
                Text(display).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundColor(Theme.mint)
            }
            Slider(value: $value, in: range, step: step).controlSize(.small).tint(Theme.indigo)
        }
    }
}

private struct ShortcutRow: View {
    let keys: String
    let text: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
            Spacer()
            Text(text).font(.system(size: 11.5)).foregroundColor(.secondary)
        }
    }
}

// MARK: - 位置预设卡片

private struct PresetCard: View {
    let preset: PlacementPreset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                PresetThumbnail(preset: preset)
                    .frame(height: 50)
                HStack(spacing: 4) {
                    Text(preset.letter).font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.8)))
                    Text(preset.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    if preset.recommended {
                        Text("推荐").font(.system(size: 9, weight: .bold)).foregroundColor(.black)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Theme.mint))
                    }
                }
                Text(preset.detail).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(selected ? 0.08 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.08)),
                              lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 预设缩略图：按大致比例画出屏幕、刘海、提词条 / 卡片的位置
private struct PresetThumbnail: View {
    let preset: PlacementPreset

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            // 以 14" 屏、55 cm 视距的比例粗略换算：每度约 0.05 × 屏高
            let perDeg = h * 0.05
            let textW = min(w * 0.9, w * CGFloat(preset.lineChars) / 34)
            let lineGap = h * 0.075
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white.opacity(0.1))
                if preset.style == .island {
                    NotchShape(topRadius: 2, bottomRadius: 5).fill(Color.black)
                        .frame(width: textW + 10, height: h * 0.1 + CGFloat(preset.lines) * lineGap + 6)
                    lines(textW, gap: lineGap).padding(.top, h * 0.1 + 3)
                } else {
                    NotchShape(topRadius: 2, bottomRadius: 3).fill(Color.black)
                        .frame(width: w * 0.32, height: h * 0.1)
                    let cardH = CGFloat(preset.lines) * lineGap + 6
                    let top = max(h * 0.14, CGFloat(preset.degrees) * perDeg - cardH / 2)
                    Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: max(0, top - h * 0.1))
                        .padding(.top, h * 0.1)
                    RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                        .frame(width: textW + 8, height: cardH)
                        .overlay(lines(textW, gap: lineGap))
                        .padding(.top, top)
                }
            }
        }
    }

    private func lines(_ w: CGFloat, gap: CGFloat) -> some View {
        VStack(spacing: gap * 0.45) {
            ForEach(0..<preset.lines, id: \.self) { i in
                Capsule().fill(i == (preset.lines >= 3 ? 1 : 0) ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.4)))
                    .frame(width: w * (i == 0 ? 1 : 0.85), height: gap * 0.55)
            }
        }
    }
}
