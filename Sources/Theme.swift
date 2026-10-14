import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let mint = Color(hex: 0x5EEAD4)
    static let indigo = Color(hex: 0x818CF8)
    static let violet = Color(hex: 0xC084FC)
    static let amber = Color(hex: 0xFCD34D)
    static let cue = Color(hex: 0xFDBA74)
    static let green = Color(hex: 0x4ADE80)
    static let sky = Color(hex: 0x7DD3FC)
    static let orange = Color(hex: 0xFB923C)
    static let emphasis = Color(hex: 0xFDE68A)
    static let accent = LinearGradient(colors: [mint, indigo, violet], startPoint: .leading, endPoint: .trailing)
}

enum Fmt {
    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// 刘海形状：顶部两侧是向外翻的小圆角（和硬件刘海一样），底部是大圆角。
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(topRadius, rect.width / 4)
        let b = max(0, min(bottomRadius, rect.height - t, (rect.width - 2 * t) / 2))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t), control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY), control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b), control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct IslandButton: View {
    let icon: String
    var label: String? = nil
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                if let label { Text(label).font(.system(size: 12, weight: .semibold)) }
            }
            .foregroundColor(prominent ? .black : .white.opacity(0.9))
            .padding(.horizontal, label == nil ? 9 : 13)
            .frame(minWidth: 28)
            .frame(height: 26)
            .background(Capsule().fill(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.11))))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

struct AppGlyph: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2E2A78), Color(hex: 0x0B0B14)], startPoint: .top, endPoint: .bottom))
            Capsule().fill(Color.black)
                .frame(width: size * 0.52, height: size * 0.16)
                .padding(.top, size * 0.1)
            VStack(alignment: .leading, spacing: size * 0.07) {
                Capsule().fill(Color.white.opacity(0.3)).frame(width: size * 0.48, height: size * 0.07)
                Capsule().fill(Theme.accent).frame(width: size * 0.62, height: size * 0.085)
                Capsule().fill(Color.white.opacity(0.85)).frame(width: size * 0.4, height: size * 0.07)
            }
            .frame(width: size * 0.62, alignment: .leading)
            .padding(.top, size * 0.4)
        }
        .frame(width: size, height: size)
        .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
    }
}

extension AnyTransition {
    static var islandContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)).animation(.easeOut(duration: 0.26).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.1))
        )
    }
}
