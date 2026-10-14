import AppKit
import SwiftUI

enum GlassCard {
    static let hPad: CGFloat = 30
    static let top: CGFloat = 16
    static let bottom: CGFloat = 20
}

enum CaptionCard {
    static let hPad: CGFloat = 28
    static let top: CGFloat = 10
    static let bottom: CGFloat = 12
    /// 下一句缩小到多少
    static let nextScale: CGFloat = 0.74
}

// MARK: - 提词卡片

/// 提词卡片（玻璃卡片 / 字幕胶囊）：拖中间移动（靠近镜头中线自动吸附），拖四个角调大小，双击回到默认位置。
struct PrompterCard: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var settings: PrompterSettings
    @ObservedObject var model: IslandModel
    let frame: CGRect
    let reset: () -> Void
    @State private var dragStart: CardPosition?
    @State private var resizeStart: (chars: Int, lines: Int)?

    private var glass: Bool { settings.displayStyle == .glass }
    private var showChrome: Bool { model.cardHovering || model.dragging }
    /// 卡片靠右时，角度提示放到左边，免得跑出屏幕
    private var badgeOnLeft: Bool { frame.maxX + 190 > model.panelSize.width }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: glass ? 22 : min(frame.height / 2, 36), style: .continuous)
        ZStack(alignment: .top) {
            background(shape)
            content
            if glass {
                VStack {
                    Spacer()
                    progress.padding(.horizontal, 22).padding(.bottom, 9)
                }
            }
            if showChrome {
                Capsule().fill(Color.white.opacity(dragStart != nil ? 0.55 : 0.28))
                    .frame(width: 38, height: 4)
                    .padding(.top, glass ? 6 : 4)
                    .transition(.opacity)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 14)
        .contentShape(shape)
        .onTapGesture(count: 2, perform: reset)
        .gesture(moveGesture)
        .overlay(alignment: .topLeading) { handle(.topLeft) }
        .overlay(alignment: .topTrailing) { handle(.topRight) }
        .overlay(alignment: .bottomLeading) { handle(.bottomLeft) }
        .overlay(alignment: .bottomTrailing) { handle(.bottomRight) }
        .overlay(alignment: badgeOnLeft ? .trailing : .leading) {
            if model.dragging {
                badge.fixedSize().offset(x: badgeOnLeft ? -frame.width - 14 : frame.width + 14).transition(.opacity)
            }
        }
        .help("拖动移动 · 拖四个角调大小 · 双击回到默认位置")
        .animation(.easeOut(duration: 0.18), value: showChrome)
    }

    @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
        Group {
            if model.snapshot {
                Color(hex: 0x101018).opacity(glass ? 0.94 : 0.97)
            } else if glass {
                VisualEffectBlur().overlay(Color.black.opacity(0.45))
            } else {
                Color.black.opacity(0.86)
            }
        }
        .clipShape(shape)
        shape.strokeBorder(LinearGradient(colors: [.white.opacity(glass ? 0.18 : 0.12), .white.opacity(0.04)],
                                          startPoint: .top, endPoint: .bottom), lineWidth: 1)
    }

    @ViewBuilder private var content: some View {
        let fs = settings.displayFontSize
        if case .countdown(let n) = engine.phase {
            let hint = engine.activeMode == .voice ? "开口就开始 · 看这里 ≈ 看观众" : "按 \(Int(engine.paceSpeed)) \(engine.unitLabel) 滚动"
            Group {
                if glass {
                    VStack(spacing: 4) {
                        Text("\(n)").font(.system(size: 46, weight: .heavy, design: .rounded))
                        Text(hint).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 8)
                } else {
                    HStack(spacing: 12) {
                        Text("\(n)").font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text(hint).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.65))
                    }
                }
            }
            .foregroundStyle(glass ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.amber))
            .contentTransition(.numericText(countsDown: true))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: n)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if glass {
            PrompterTextView(engine: engine, fontSize: fs, visibleLines: settings.visibleLines, textWidth: settings.textWidth)
                .padding(.top, GlassCard.top)
        } else {
            CaptionTextView(engine: engine, fontSize: fs, textWidth: settings.textWidth)
                .padding(.top, CaptionCard.top)
        }
    }

    private var progress: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(Theme.accent).frame(width: max(3, g.size.width * engine.progress))
            }
        }
        .frame(height: 2.5)
    }

    /// 拖动时显示：离镜头多少度、偏没偏
    private var badge: some View {
        let geo = model.geo
        let pos = IslandMetrics.clamp(currentPos, settings: settings, notch: model.notch, panel: model.panelSize)
        let v = geo.degrees(forY: pos.readY, distanceCM: PrompterSettings.viewingDistance)
        let h = geo.degrees(forDX: pos.dx, distanceCM: PrompterSettings.viewingDistance)
        let far = v > 8 || abs(h) > 6
        let title: String = {
            if model.resizing { return glass ? "每行 \(settings.lineChars) 字 · \(settings.visibleLines) 行" : "每行 \(settings.lineChars) 字" }
            return "镜头下 \(String(format: "%.1f", max(0, v)))°"
        }()
        let detail: String = {
            if model.resizing { return "拖四个角调整" }
            if abs(pos.dx) < 0.5 { return "已对准镜头中线" }
            return String(format: "偏%@ %.1f°", h > 0 ? "右" : "左", abs(h))
        }()
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
            Text(detail).font(.system(size: 10.5, weight: .medium)).foregroundColor(.white.opacity(0.6))
            if far && !model.resizing {
                Text("离镜头较远，看稿会更明显").font(.system(size: 10.5)).foregroundColor(Theme.orange)
            }
        }
        .monospacedDigit()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.8)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
    }

    private var currentPos: CardPosition {
        model.dragPos ?? settings.position(for: model.screenKey) ?? IslandMetrics.defaultPosition(model.geo)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { v in
                if dragStart == nil {
                    dragStart = IslandMetrics.clamp(currentPos, settings: settings, notch: model.notch, panel: model.panelSize)
                }
                guard let s = dragStart else { return }
                var p = CardPosition(dx: s.dx + v.translation.width, readY: s.readY + v.translation.height)
                // 靠近镜头中线 / 默认高度时吸过去
                if abs(p.dx) < 16 { p.dx = 0 }
                let home = IslandMetrics.defaultPosition(model.geo).readY
                if p.dx == 0 && abs(p.readY - home) < 10 { p.readY = home }
                model.dragPos = IslandMetrics.clamp(p, settings: settings, notch: model.notch, panel: model.panelSize)
            }
            .onEnded { _ in
                if let p = model.dragPos {
                    let home = IslandMetrics.defaultPosition(model.geo)
                    settings.setPosition(p == home ? nil : p, for: model.screenKey)
                }
                model.dragPos = nil
                dragStart = nil
            }
    }

    // MARK: 拖角调大小

    enum Corner { case topLeft, topRight, bottomLeft, bottomRight
        var left: Bool { self == .topLeft || self == .bottomLeft }
        var top: Bool { self == .topLeft || self == .topRight }
    }

    @ViewBuilder private func handle(_ c: Corner) -> some View {
        if showChrome {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 7, height: 7)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                // 白点正好在卡片的角上
                .offset(x: c.left ? -11 : 11, y: c.top ? -11 : 11)
                .gesture(resizeGesture(c))
                .transition(.opacity)
        }
    }

    private func resizeGesture(_ c: Corner) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { v in
                if resizeStart == nil {
                    resizeStart = (settings.lineChars, settings.visibleLines)
                    model.resizing = true
                }
                guard let s = resizeStart else { return }
                // 卡片以中心为准左右对称伸缩，所以宽度变化是拖动距离的两倍
                let charW = CGFloat(settings.displayFontSize) * 1.02
                let dw = (c.left ? -v.translation.width : v.translation.width) * 2
                let chars = Int((CGFloat(s.chars) + dw / charW).rounded())
                if chars != settings.lineChars { settings.lineChars = chars }
                if glass {
                    let lh = PrompterLayout.lineHeight(settings.displayFontSize)
                    let dh = c.top ? -v.translation.height : v.translation.height
                    let lines = Int((CGFloat(s.lines) + dh / lh).rounded())
                    if lines != settings.visibleLines { settings.visibleLines = lines }
                }
            }
            .onEnded { _ in
                resizeStart = nil
                model.resizing = false
            }
    }
}

// MARK: - 卡片下方：悬停控制条 / 状态提示

struct CardControls: View {
    @ObservedObject var engine: PrompterEngine
    let glass: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundIcon(icon: "chevron.up") { engine.jumpLines(-1) }
            RoundIcon(icon: engine.isPaused ? "play.fill" : "pause.fill", prominent: true, glass: glass) { engine.togglePause() }
            RoundIcon(icon: "chevron.down") { engine.jumpLines(1) }
            RoundIcon(icon: "xmark") { engine.stop() }
        }
        .padding(.horizontal, 8)
        .frame(height: IslandMetrics.controlsSize.height)
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

private struct RoundIcon: View {
    let icon: String
    var prominent = false
    var glass = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(prominent ? .black : .white.opacity(0.9))
                .frame(width: 30, height: 30)
                .background(Circle().fill(prominent
                    ? (glass ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.amber))
                    : AnyShapeStyle(Color.white.opacity(0.12))))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
    }
}

struct CardHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
            .fixedSize()
    }
}

// MARK: - 文字

/// 一行稿子按“已读 / 正在读 / 没读 / 重点 / 导演提示”上色
struct LineStyler {
    let engine: PrompterEngine
    let current: Color
    /// 字幕胶囊里“正在读”已经是黄色，重点改用加粗
    var boldEmphasis = false

    private enum Role { case read, current, upcoming, emphasis, cue, cueRead }

    private func color(_ r: Role) -> Color {
        switch r {
        case .read: return .white.opacity(0.32)
        case .current: return current
        case .upcoming: return .white
        case .emphasis: return boldEmphasis ? .white : Theme.emphasis
        case .cue: return Theme.cue.opacity(0.95)
        case .cueRead: return Theme.cue.opacity(0.35)
        }
    }

    private func role(_ g: Glyph, cursor: Int) -> Role {
        let read = g.unit >= 0 && g.unit < cursor
        if g.style == .cue { return read ? .cueRead : .cue }
        if read { return .read }
        if g.isUnit && (g.unit == cursor || (g.unit == cursor + 1 && !engine.parsed.isMostlyLatin)) { return .current }
        return g.style == .emphasis ? .emphasis : .upcoming
    }

    func text(_ line: PrompterLine, cursor: Int) -> Text {
        var result = Text(verbatim: "")
        var buf = ""
        var runRole: Role?
        func flush() {
            guard let rr = runRole, !buf.isEmpty else { return }
            var t = Text(verbatim: buf).foregroundColor(color(rr))
            if rr == .emphasis && boldEmphasis { t = t.bold() }
            result = result + t
        }
        let glyphs = engine.parsed.glyphs
        for gi in line.glyphs {
            let g = glyphs[gi]
            if g.char.isNewline { continue }
            let r = role(g, cursor: cursor)
            if r != runRole {
                flush()
                buf = ""
                runRole = r
            }
            buf.append(g.char)
        }
        flush()
        return result
    }
}

/// 玻璃卡片：多行滚动，正在读的那一行背后有一条光带
struct PrompterTextView: View {
    @ObservedObject var engine: PrompterEngine
    let fontSize: Double
    let visibleLines: Int
    let textWidth: CGFloat

    var body: some View {
        let lh = PrompterLayout.lineHeight(fontSize)
        let anchor = visibleLines >= 3 ? 1 : 0
        let scroll = engine.scroll
        let base = Int(scroll)
        let lo = max(0, base - 3)
        let hi = min(engine.lines.count, base + visibleLines + 3)
        let cursorInt = Int(engine.cursor)
        let font = Font(PrompterLayout.font(fontSize) as CTFont)
        let styler = LineStyler(engine: engine, current: Theme.mint)

        ZStack(alignment: .topLeading) {
            ForEach(lo..<max(lo, hi), id: \.self) { li in
                styler.text(engine.lines[li], cursor: cursorInt)
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: textWidth, height: lh, alignment: .center)
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.05)))
                .frame(width: textWidth + 24, height: lh * 1.04)
                .offset(x: -12, y: CGFloat(anchor) * lh - lh * 0.02)
        }
        .pausedLook(engine)
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
}

/// 字幕胶囊：只显示这一句（大）和下一句（小、暗）；换行时下一句放大顶上来
struct CaptionTextView: View {
    @ObservedObject var engine: PrompterEngine
    let fontSize: Double
    let textWidth: CGFloat

    var body: some View {
        let lh = PrompterLayout.lineHeight(fontSize)
        let k = CaptionCard.nextScale
        let scroll = engine.scroll
        let base = Int(scroll)
        let lo = max(0, base - 1)
        let hi = min(engine.lines.count, base + 3)
        let cursorInt = Int(engine.cursor)
        let font = Font(PrompterLayout.font(fontSize) as CTFont)
        let styler = LineStyler(engine: engine, current: Theme.amber, boldEmphasis: true)

        ZStack(alignment: .top) {
            ForEach(lo..<max(lo, hi), id: \.self) { li in
                let p = place(Double(li) - scroll, lh: lh, k: k)
                styler.text(engine.lines[li], cursor: cursorInt)
                    .font(font)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: textWidth, height: lh)
                    .scaleEffect(p.scale, anchor: .top)
                    .offset(y: p.y)
                    .opacity(p.opacity)
            }
        }
        .frame(width: textWidth, height: lh * (1 + k), alignment: .top)
        .clipped()
        .pausedLook(engine)
    }

    /// d = 0 正在读（原大），d = 1 下一句（缩小、变暗），d < 0 读完往上淡出
    private func place(_ d: Double, lh: CGFloat, k: CGFloat) -> (y: CGFloat, scale: CGFloat, opacity: Double) {
        let t = CGFloat(d)
        if d <= 0 { return (t * lh * 0.8, 1, max(0, 1 + d * 1.8)) }
        if d <= 1 { return (t * lh, 1 - (1 - k) * t, 1 - 0.45 * d) }
        return (lh + (t - 1) * lh * k, k, max(0, 0.55 - (d - 1) * 0.9))
    }
}

private extension View {
    func pausedLook(_ engine: PrompterEngine) -> some View {
        let dim = engine.isPaused && !engine.previewing
        return blur(radius: dim ? 1.5 : 0)
            .opacity(dim ? 0.55 : 1)
            .animation(.easeOut(duration: 0.2), value: engine.isPaused)
    }
}

/// 刘海到卡片之间的细线：卡片对准镜头中线时显示
struct HangingThread: View {
    let height: CGFloat

    var body: some View {
        LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
            .frame(width: 1.5, height: height)
            .clipShape(Capsule())
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - 提词时的刘海：状态点 · 计时 · 语速提示

struct CompactPresentingContent: View {
    @ObservedObject var engine: PrompterEngine
    let notch: NotchInfo

    private var dot: StatusDot.DotState {
        if engine.isPaused { return .paused }
        if !engine.listening { return .off }
        return engine.isSpeaking ? .speaking : .listening
    }

    var body: some View {
        VStack(spacing: 0) {
            TopStrip(notch: notch) {
                HStack(spacing: 7) {
                    StatusDot(state: dot)
                    Text(Fmt.clock(engine.elapsed))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.9))
                    if engine.previewing {
                        Text("预览").font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.amber)
                    } else if engine.isPaused {
                        Text("暂停").font(.system(size: 11.5, weight: .semibold)).foregroundColor(Theme.amber)
                    } else if engine.listening {
                        Waveform(levels: engine.levels, active: engine.isSpeaking)
                    }
                }
            } right: {
                SpeedChip(engine: engine)
            }
            if let toast = engine.toast {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(toast).lineLimit(1)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Theme.amber)
                .padding(.horizontal, 22)
                .frame(height: 30)
                .transition(.opacity)
            }
        }
    }
}

struct CompactCountdownContent: View {
    let notch: NotchInfo
    @ObservedObject var engine: PrompterEngine

    var body: some View {
        TopStrip(notch: notch) {
            Text(engine.title).lineLimit(1).foregroundColor(.white.opacity(0.55))
        } right: {
            Label(engine.activeMode.short, systemImage: engine.activeMode.icon).foregroundColor(.white.opacity(0.6))
        }
        .font(.system(size: 11.5, weight: .semibold))
    }
}
