import SwiftUI
import UniformTypeIdentifiers

struct IslandActions {
    var start: () -> Void
    var openLibrary: () -> Void
    var importURLs: ([URL]) -> Void
    var cycleScript: (Int) -> Void
    var resetPosition: () -> Void
}

struct IslandRootView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let actions: IslandActions
    var acceptsDrop = true

    private var stateKey: String { "\(engine.phase)-\(model.hovering)-\(model.dropTargeted)-\(settings.displayStyle)" }

    private var hint: String? {
        if engine.previewing { return "预览：拖动调位置 · 双击回默认 · ⌥⌘P 开始" }
        if engine.isPaused && engine.phase == .presenting { return "已暂停 · ⌥⌘P 继续" }
        return nil
    }

    var body: some View {
        let layout = IslandMetrics.layout(engine: engine, model: model, settings: settings)
        let spring = Animation.spring(response: 0.42, dampingFraction: 0.8)
        ZStack(alignment: .topLeading) {
            if let card = layout.card {
                if layout.centered {
                    // 对准镜头中线时，刘海和卡片之间一根细细的“悬挂线”
                    HangingThread(height: max(0, card.minY - model.notch.height))
                        .frame(width: model.panelSize.width, alignment: .center)
                        .offset(y: model.notch.height)
                        .transition(.opacity)
                }
                PrompterCard(engine: engine, settings: settings, model: model, frame: card, reset: actions.resetPosition)
                    .offset(x: card.minX, y: card.minY)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -18)).animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08)),
                                            removal: .opacity.animation(.easeIn(duration: 0.15))))
                if let ctl = layout.controls {
                    ZStack {
                        if model.cardHovering && !model.dragging && engine.phase == .presenting {
                            CardControls(engine: engine, glass: settings.displayStyle == .glass).transition(.opacity)
                        } else if let hint, !model.dragging {
                            CardHint(text: hint).transition(.opacity)
                        }
                    }
                    .frame(width: ctl.width, height: ctl.height)
                    .offset(x: ctl.minX, y: ctl.minY)
                    .animation(.easeOut(duration: 0.18), value: model.cardHovering)
                }
            }
            island(layout.island)
                .frame(width: model.panelSize.width, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 拖动 / 调大小时卡片要紧跟鼠标，不加弹簧
        .animation(model.dragging ? nil : spring, value: layout)
        .animation(spring, value: stateKey)
        .environment(\.colorScheme, .dark)
    }

    private func island(_ s: CGSize) -> some View {
        let expanded = s.height > model.notch.height + 1
        let shape = NotchShape(topRadius: PrompterLayout.earRadius, bottomRadius: expanded ? 24 : 10)
        return ZStack(alignment: .top) {
            shape.fill(Color.black)
                .shadow(color: .black.opacity(expanded ? 0.5 : 0), radius: 22, x: 0, y: 12)
            content
                .frame(width: s.width, height: s.height, alignment: .top)
                .clipShape(shape)
        }
        .frame(width: s.width, height: s.height)
        .contentShape(shape)
        .modifier(DropModifier(enabled: acceptsDrop, targeted: $model.dropTargeted, handle: handleDrop))
    }

    @ViewBuilder private var content: some View {
        if model.dropTargeted {
            DropContent(notch: model.notch).transition(.islandContent)
        } else {
            switch engine.phase {
            case .idle:
                if model.hovering {
                    PeekContent(store: store, settings: settings, notch: model.notch, flash: model.flash, actions: actions)
                        .transition(.islandContent)
                }
            case .countdown:
                CompactCountdownContent(notch: model.notch, engine: engine).transition(.islandContent)
            case .presenting:
                CompactPresentingContent(engine: engine, notch: model.notch).transition(.islandContent)
            case .finished:
                FinishedContent(summary: engine.summary, notch: model.notch)
                    .transition(.islandContent)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var any = false
        for p in providers where p.canLoadObject(ofClass: URL.self) {
            any = true
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { actions.importURLs([url]) }
            }
        }
        return any
    }
}

private struct DropModifier: ViewModifier {
    let enabled: Bool
    @Binding var targeted: Bool
    let handle: ([NSItemProvider]) -> Bool

    func body(content: Content) -> some View {
        if enabled {
            content.onDrop(of: [UTType.fileURL], isTargeted: $targeted, perform: handle)
        } else {
            content
        }
    }
}

// MARK: - 顶部条（刘海左右两侧）

struct TopStrip<L: View, R: View>: View {
    let notch: NotchInfo
    let left: L
    let right: R

    init(notch: NotchInfo, @ViewBuilder left: () -> L, @ViewBuilder right: () -> R) {
        self.notch = notch
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(spacing: 0) {
            left.frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: max(0, notch.width - 10))
            right.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: notch.height)
    }
}

// MARK: - 悬停预览

struct PeekContent: View {
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let notch: NotchInfo
    let flash: String?
    let actions: IslandActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TopStrip(notch: notch) {
                HStack(spacing: 6) {
                    AppGlyph(size: 15)
                    Text("OpenSpeech").font(.system(size: 12, weight: .bold, design: .rounded))
                }
            } right: {
                Group {
                    if let flash {
                        Label(flash, systemImage: "checkmark.circle.fill").foregroundColor(Theme.green)
                    }
                }
                .font(.system(size: 11.5, weight: .semibold))
                .labelStyle(.titleAndIcon)
            }
            .foregroundColor(.white)

            Spacer(minLength: 8)

            if let s = store.selected {
                let stats = ScriptStats(s.body)
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.title.isEmpty ? "未命名稿件" : s.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(stats.countText) · 约 \(Fmt.clock(stats.duration(speed: settings.targetSpeed))) · 共 \(store.scripts.count) 篇")
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer(minLength: 4)
                    if store.scripts.count > 1 {
                        IslandButton(icon: "chevron.left") { actions.cycleScript(-1) }
                        IslandButton(icon: "chevron.right") { actions.cycleScript(1) }
                    }
                }
                HStack(spacing: 8) {
                    IslandButton(icon: "play.fill", label: "开始提词", prominent: true, action: actions.start)
                    IslandButton(icon: "books.vertical.fill", label: "稿件库", action: actions.openLibrary)
                    Spacer()
                    Text("拖文件到这里导入 · ⌥⌘P")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.32))
                }
                .padding(.top, 12)
            } else {
                Text("还没有稿件").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text("把 txt / md / docx / pdf 拖到刘海上，或打开稿件库新建")
                    .font(.system(size: 11.5)).foregroundColor(.white.opacity(0.5)).padding(.top, 4)
                IslandButton(icon: "books.vertical.fill", label: "打开稿件库", prominent: true, action: actions.openLibrary)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

// MARK: - 状态小部件

struct StatusDot: View {
    enum DotState { case off, listening, speaking, paused }
    let state: DotState
    @State private var pulse = false

    private var color: Color {
        switch state {
        case .off: return .white.opacity(0.35)
        case .listening: return .white.opacity(0.75)
        case .speaking: return Theme.green
        case .paused: return Theme.amber
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.15 : 0.55)
                .opacity(state == .speaking ? 1 : 0)
            Circle().fill(color).frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct Waveform: View {
    let levels: [CGFloat]
    let active: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(active ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.3)))
                    .frame(width: 3, height: 3 + 12 * levels[i])
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.1), value: levels)
    }
}

struct SpeedChip: View {
    @ObservedObject var engine: PrompterEngine

    var body: some View {
        HStack(spacing: 6) {
            if engine.activeMode == .pace {
                Image(systemName: engine.activeMode.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
            }
            if let v = engine.verdict {
                let (label, color): (String, Color) = {
                    switch v {
                    case .slow: return ("偏慢", Theme.sky)
                    case .good: return ("正好", Theme.green)
                    case .fast: return ("偏快", Theme.orange)
                    }
                }()
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(label).foregroundColor(color)
                }
            }
            Text(engine.speedText).monospacedDigit().foregroundColor(.white.opacity(0.85))
        }
        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
        .lineLimit(1)
    }
}

// MARK: - 结束 / 拖入

struct FinishedContent: View {
    let summary: SessionSummary?
    let notch: NotchInfo

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.height)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("讲完啦，漂亮！").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    if let s = summary {
                        Text("用时 \(Fmt.clock(s.duration))" + (s.avgSpeed.map { " · 平均 \(Int($0)) \(s.unitLabel)" } ?? ""))
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 30)
            Spacer(minLength: 0)
        }
    }
}

struct DropContent: View {
    let notch: NotchInfo

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notch.height)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(Theme.accent)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.indigo.opacity(0.08)))
                .overlay(
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill").font(.system(size: 24)).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("松手，把稿子放进灵动岛").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            Text("txt · md · docx · pdf · rtf · html").font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                        }
                    }
                )
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 16)
        }
    }
}
