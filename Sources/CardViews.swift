import AppKit
import SwiftUI

// MARK: - 悬浮稿件卡片

/// 刘海下方的悬浮稿件卡片：毛玻璃底、阅读光带、底部细进度条；鼠标悬停可上下拖动调整离镜头的角度。
struct PrompterCard: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var settings: PrompterSettings
    @ObservedObject var model: IslandModel
    let frame: CGRect
    @State private var dragStartDeg: Double?

    private var dragging: Bool { dragStartDeg != nil }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack(alignment: .top) {
            Group {
                if model.snapshot {
                    Color(hex: 0x101018).opacity(0.94)
                } else {
                    VisualEffectBlur().overlay(Color.black.opacity(0.45))
                }
            }
            .clipShape(shape)

            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.04)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)

            content

            VStack {
                Spacer()
                progress.padding(.horizontal, 22).padding(.bottom, 9)
            }

            if model.cardHovering || dragging {
                Capsule().fill(Color.white.opacity(dragging ? 0.55 : 0.28))
                    .frame(width: 38, height: 4)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 14)
        .contentShape(shape)
        .gesture(dragGesture)
        .overlay(alignment: .leading) {
            if model.cardHovering || dragging {
                angleBadge.fixedSize().offset(x: frame.width + 14).transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let hint = hintText {
                Text(hint)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
                    .fixedSize()
                    .offset(y: 36)
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.cardHovering)
        .animation(.easeOut(duration: 0.18), value: dragging)
    }

    @ViewBuilder private var content: some View {
        if case .countdown(let n) = engine.phase {
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Text("\(n)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: n)
                Text(engine.activeMode == .voice ? "开口就开始 · 看这里 ≈ 看观众" : "按 \(Int(engine.paceSpeed)) \(engine.unitLabel) 滚动")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)
        } else {
            PrompterTextView(engine: engine, fontSize: settings.fontSize, visibleLines: settings.visibleLines,
                             textWidth: settings.textWidth, align: settings.cardAlign, caret: false, lens: true)
                .padding(.top, IslandMetrics.cardTop)
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

    private var hintText: String? {
        if engine.previewing { return "预览：拖动卡片调高度 · ⌥⌘1–5 换预设 · ⌥⌘P 开始" }
        if engine.isPaused && engine.phase == .presenting { return "已暂停 · ⌥⌘P 继续" }
        return nil
    }

    private var angleBadge: some View {
        let deg = settings.cardDegrees
        let cm = settings.viewingDistance * tan(deg * .pi / 180)
        return VStack(alignment: .leading, spacing: 2) {
            Text("镜头下 \(String(format: "%.1f", deg))°")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text("约 \(String(format: "%.1f", cm)) cm · 视距 \(Int(settings.viewingDistance)) cm")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            Text(deg > 8 ? "偏低，可能像在念稿" : "上下拖动调整")
                .font(.system(size: 10.5))
                .foregroundColor(deg > 8 ? Theme.orange : .white.opacity(0.4))
        }
        .monospacedDigit()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.8)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { v in
                if dragStartDeg == nil { dragStartDeg = settings.cardDegrees }
                let geo = model.geo
                let y0 = geo.y(forDegrees: dragStartDeg ?? settings.cardDegrees, distanceCM: settings.viewingDistance)
                let deg = geo.degrees(forY: y0 + v.translation.height, distanceCM: settings.viewingDistance)
                settings.cardDegrees = (max(0, min(14, deg)) * 10).rounded() / 10
            }
            .onEnded { _ in dragStartDeg = nil }
    }
}

/// 刘海到卡片之间的细线，让卡片看起来是“挂”在刘海下面的
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

// MARK: - 卡片样式下的刘海小岛

/// 卡片样式时刘海只横向展开一点，显示计时 / 波形 / 语速；悬停时向下展开控制条
struct CompactPresentingContent: View {
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
            if hovering {
                ControlBar(engine: engine, settings: settings)
                    .frame(height: 48)
                    .transition(.opacity)
            } else if let toast = engine.toast {
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
