import SwiftUI
import UniformTypeIdentifiers

struct IslandActions {
    var start: () -> Void
    var openLibrary: () -> Void
    var importURLs: ([URL]) -> Void
    var cycleScript: (Int) -> Void
}

struct IslandRootView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var store: ScriptStore
    @ObservedObject var settings: PrompterSettings
    let actions: IslandActions
    var acceptsDrop = true

    private var stateKey: String { "\(engine.phase)-\(model.hovering)-\(model.dropTargeted)-\(settings.layoutStyle)" }

    var body: some View {
        let layout = IslandMetrics.layout(engine: engine, model: model, settings: settings)
        ZStack(alignment: .topLeading) {
            if let card = layout.card {
                // 刘海和卡片之间一根细细的“悬挂线”
                HangingThread(height: max(0, card.minY - model.notch.height))
                    .frame(width: model.panelWidth, alignment: .center)
                    .offset(y: model.notch.height)
                    .transition(.opacity)
                PrompterCard(engine: engine, settings: settings, model: model, frame: card)
                    .frame(width: card.width, height: card.height)
                    .offset(x: card.minX, y: card.minY)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: -18)).animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.08)),
                                            removal: .opacity.animation(.easeIn(duration: 0.15))))
            }
            island(layout.island)
                .frame(width: model.panelWidth, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: layout)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: stateKey)
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
            case .countdown(let n):
                if settings.layoutStyle == .card {
                    CompactCountdownContent(notch: model.notch, engine: engine).transition(.islandContent)
                } else {
                    CountdownContent(n: n, notch: model.notch, engine: engine, settings: settings)
                        .transition(.islandContent)
                }
            case .presenting:
                if settings.layoutStyle == .card {
                    CompactPresentingContent(engine: engine, settings: settings, notch: model.notch, hovering: model.hovering)
                        .transition(.islandContent)
                } else {
                    PresentingContent(engine: engine, settings: settings, notch: model.notch, hovering: model.hovering)
                        .transition(.islandContent)
                }
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
                    Text("OpenPitch").font(.system(size: 12, weight: .bold, design: .rounded))
                }
            } right: {
                Group {
                    if let flash {
                        Label(flash, systemImage: "checkmark.circle.fill").foregroundColor(Theme.green)
                    } else {
                        Label(settings.mode.short, systemImage: settings.mode.icon).foregroundColor(.white.opacity(0.55))
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

// MARK: - 倒计时

struct CountdownContent: View {
    let n: Int
    let notch: NotchInfo
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var settings: PrompterSettings

    var hint: String {
        engine.activeMode == .voice
            ? "开口就开始 · 你讲到哪，提词跟到哪"
            : "按 \(Int(engine.paceSpeed)) \(engine.unitLabel) 滚动\(settings.pauseOnSilence ? " · 你停它就停" : "")"
    }

    var body: some View {
        VStack(spacing: 2) {
            TopStrip(notch: notch) {
                Text(engine.title).lineLimit(1).foregroundColor(.white.opacity(0.5))
            } right: {
                Label(engine.activeMode.title, systemImage: engine.activeMode.icon).foregroundColor(.white.opacity(0.6))
            }
            .font(.system(size: 11.5, weight: .semibold))
            Spacer(minLength: 0)
            Text("\(n)")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: n)
            Text(hint).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.7))
            Text("提词就在摄像头正下方，看稿 = 看镜头").font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 正在提词

struct PresentingContent: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var settings: PrompterSettings
    let notch: NotchInfo
    let hovering: Bool

    private var dot: StatusDot.DotState {
        if engine.isPaused { return .paused }
        if !engine.listening { return .off }
        return engine.isSpeaking ? .speaking : .listening
    }

    var body: some View {
        VStack(spacing: 0) {
            TopStrip(notch: notch) {
                HStack(spacing: 8) {
                    StatusDot(state: dot)
                    Text(Fmt.clock(engine.elapsed))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.9))
                    if engine.previewing {
                        Text("预览 · ⌥⌘P 开始").font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.amber)
                    } else if engine.isPaused {
                        Text("已暂停").font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.amber)
                    } else if engine.listening {
                        Waveform(levels: engine.levels, active: engine.isSpeaking)
                    }
                }
            } right: {
                SpeedChip(engine: engine)
            }

            PrompterTextView(engine: engine, fontSize: settings.fontSize, visibleLines: settings.visibleLines,
                             textWidth: settings.textWidth, align: .leading, caret: true, lens: false)
                .padding(.leading, PrompterLayout.caretGap)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            ZStack {
                if hovering {
                    ControlBar(engine: engine, settings: settings).transition(.opacity)
                } else if let toast = engine.toast {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(toast).lineLimit(1)
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.amber)
                    .padding(.horizontal, 26)
                    .transition(.opacity)
                } else {
                    ProgressLine(engine: engine).transition(.opacity)
                }
            }
            .frame(height: 38)
            .animation(.easeOut(duration: 0.18), value: hovering)
            .animation(.easeOut(duration: 0.18), value: engine.toast)
        }
    }
}

struct PrompterTextView: View {
    @ObservedObject var engine: PrompterEngine
    let fontSize: Double
    let visibleLines: Int
    let textWidth: CGFloat
    var align: TextAlign = .leading
    /// 左侧的竖条光标（灵动岛样式）
    var caret = true
    /// 正在读的那一行背后的光带（卡片样式）
    var lens = false

    private enum Role { case read, current, upcoming, emphasis, cue, cueRead }

    private func color(_ r: Role) -> Color {
        switch r {
        case .read: return .white.opacity(0.3)
        case .current: return Theme.mint
        case .upcoming: return .white
        case .emphasis: return Theme.emphasis
        case .cue: return Theme.cue.opacity(0.95)
        case .cueRead: return Theme.cue.opacity(0.35)
        }
    }

    var body: some View {
        let lh = PrompterLayout.lineHeight(fontSize)
        let anchor = visibleLines >= 3 ? 1 : 0
        let scroll = engine.scroll
        let base = Int(scroll)
        let lo = max(0, base - 3)
        let hi = min(engine.lines.count, base + visibleLines + 3)
        let cursorInt = Int(engine.cursor)
        let font = Font(PrompterLayout.font(fontSize) as CTFont)

        ZStack(alignment: .topLeading) {
            ForEach(lo..<max(lo, hi), id: \.self) { li in
                lineText(engine.lines[li], cursor: cursorInt)
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: textWidth, height: lh, alignment: align == .center ? .center : .leading)
                    .offset(y: CGFloat(li) * lh)
                    .opacity(opacity(Double(li) - scroll))
            }
        }
        .frame(width: textWidth, alignment: .topLeading)
        .offset(y: (CGFloat(anchor) - CGFloat(scroll)) * lh)
        .frame(width: textWidth, height: CGFloat(visibleLines) * lh, alignment: .top)
        .clipped()
        .mask(fadeMask)
        .background(alignment: .topLeading) {
            if lens {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.05)))
                    .frame(width: textWidth + 24, height: lh * 1.04)
                    .offset(x: -12, y: CGFloat(anchor) * lh - lh * 0.02)
            }
        }
        .overlay(alignment: .topLeading) {
            if caret {
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 3, height: lh * 0.56)
                    .shadow(color: Theme.mint.opacity(engine.isSpeaking ? 0.9 : 0), radius: 6)
                    .offset(x: -PrompterLayout.caretGap, y: CGFloat(anchor) * lh + lh * 0.22)
            }
        }
        .blur(radius: engine.isPaused && !engine.previewing ? 1.5 : 0)
        .opacity(engine.isPaused && !engine.previewing ? 0.55 : 1)
        .animation(.easeOut(duration: 0.2), value: engine.isPaused)
    }

    private var fadeMask: LinearGradient {
        if visibleLines >= 3 {
            return LinearGradient(stops: [.init(color: .black.opacity(0.25), location: 0),
                                          .init(color: .black, location: 0.3),
                                          .init(color: .black, location: 0.72),
                                          .init(color: .black.opacity(0.15), location: 1)],
                                  startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [.black, .black.opacity(visibleLines == 1 ? 1 : 0.4)], startPoint: .top, endPoint: .bottom)
    }

    /// d = 这一行相对滚动位置的距离（连续值），在各整数点之间线性插值，滚动时亮度也是渐变的
    private func opacity(_ d: Double) -> Double {
        func at(_ i: Int) -> Double {
            switch i {
            case 0: return 1
            case -1: return 0.6
            case 1: return 0.82
            case 2: return 0.62
            default: return 0.4
            }
        }
        let f = d.rounded(.down)
        let t = d - f
        return at(Int(f)) * (1 - t) + at(Int(f) + 1) * t
    }

    private func role(_ g: Glyph, cursor: Int) -> Role {
        let read = g.unit >= 0 && g.unit < cursor
        if g.style == .cue { return read ? .cueRead : .cue }
        if read { return .read }
        if g.isUnit && (g.unit == cursor || (g.unit == cursor + 1 && !engine.parsed.isMostlyLatin)) { return .current }
        return g.style == .emphasis ? .emphasis : .upcoming
    }

    private func lineText(_ line: PrompterLine, cursor: Int) -> Text {
        var result = Text(verbatim: "")
        var buf = ""
        var runRole: Role?
        let glyphs = engine.parsed.glyphs
        for gi in line.glyphs {
            let g = glyphs[gi]
            if g.char.isNewline { continue }
            let r = role(g, cursor: cursor)
            if r != runRole {
                if let rr = runRole, !buf.isEmpty { result = result + Text(verbatim: buf).foregroundColor(color(rr)) }
                buf = ""
                runRole = r
            }
            buf.append(g.char)
        }
        if let rr = runRole, !buf.isEmpty { result = result + Text(verbatim: buf).foregroundColor(color(rr)) }
        return result
    }
}

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
            Image(systemName: engine.activeMode.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
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

struct ProgressLine: View {
    @ObservedObject var engine: PrompterEngine

    var body: some View {
        HStack(spacing: 10) {
            Text(engine.title)
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .leading)
                .foregroundColor(.white.opacity(0.4))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Theme.accent).frame(width: max(4, g.size.width * engine.progress))
                }
            }
            .frame(height: 4)
            Text("\(Int(engine.progress * 100))%").monospacedDigit().foregroundColor(.white.opacity(0.65))
            Text("剩余 \(Fmt.clock(engine.remaining))").monospacedDigit().foregroundColor(.white.opacity(0.4))
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .padding(.horizontal, 30)
    }
}

struct ControlBar: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var settings: PrompterSettings

    var body: some View {
        HStack(spacing: 6) {
            IslandButton(icon: "chevron.up") { engine.jumpLines(-1) }
            IslandButton(icon: engine.isPaused ? "play.fill" : "pause.fill", prominent: true) { engine.togglePause() }
            IslandButton(icon: "chevron.down") { engine.jumpLines(1) }
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 16).padding(.horizontal, 3)
            IslandButton(icon: engine.activeMode.icon, label: engine.activeMode.short) { engine.switchMode() }
            if engine.activeMode == .pace {
                IslandButton(icon: "minus") { engine.adjustSpeed(-10) }
                IslandButton(icon: "plus") { engine.adjustSpeed(10) }
            }
            Spacer(minLength: 4)
            IslandButton(icon: "rectangle.3.group", label: settings.activePreset.map { "预设 \($0.letter)" } ?? "自定义") {
                let all = PlacementPreset.all
                let next = settings.activePreset.map { p in all[(all.firstIndex(of: p)! + 1) % all.count] } ?? all[0]
                settings.apply(next)
                engine.showToast("预设 \(next.letter) · \(next.name) · \(next.detail)", duration: 2.2)
            }
            IslandButton(icon: "textformat.size.smaller") { settings.fontSize = max(16, settings.fontSize - 2) }
            IslandButton(icon: "textformat.size.larger") { settings.fontSize = min(36, settings.fontSize + 2) }
            IslandButton(icon: "xmark") { engine.stop() }
        }
        .padding(.horizontal, 26)
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
