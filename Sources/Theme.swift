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

/// 全 App 的颜色都从这里取，换配色只改这一处。
enum Theme {
    // 品牌色：黑白。主按钮是白底黑字，选中、进度、跟读高亮都用白色的明暗来区分
    static let accent = Color(hex: 0xF5F5F7)
    /// 白色主按钮上的文字和图标
    static let onAccent = Color.black
    /// 开关、滑块打开时的颜色（比纯白暗一点，白色的开关圆钮才看得清）
    static let control = Color(hex: 0xBDBDC2)
    /// 选中的底色、轻微的光晕
    static let soft = Color.white.opacity(0.1)
    static let link = Color.white.opacity(0.88)
    /// 提词：正在读的字纯白、带一条细下划线，还没读到的字灰一些，读过的更灰（LineStyler）
    static let current = Color.white
    static let upcoming = Color.white.opacity(0.58)

    // 状态色：表示意思，不跟着配色变
    static let amber = Color(hex: 0xFCD34D)      // 字幕胶囊样式
    static let cue = Color(hex: 0xFDBA74)        // 【导演提示】
    static let emphasis = Color(hex: 0xFDE68A)   // **重点**
    static let green = Color(hex: 0x4ADE80)      // 语速正好、完成
    static let sky = Color(hex: 0x7DD3FC)        // 语速偏慢
    static let orange = Color(hex: 0xFB923C)     // 语速偏快、提醒
    static let red = Color(hex: 0xF87171)        // 出错
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
            .foregroundColor(prominent ? Theme.onAccent : .white.opacity(0.9))
            .padding(.horizontal, label == nil ? 9 : 13)
            .frame(minWidth: 28)
            .frame(height: 26)
            .background(Capsule().fill(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.11))))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
    }
}

/// 小号 App 图标（和 AppIcon 同一个图案）：白底，左边声波、右边变成一行字
struct AppGlyph: View {
    var size: CGFloat = 28

    var body: some View {
        let u = size / 100
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(hex: 0xE8E8ED)], startPoint: .top, endPoint: .bottom))
            HStack(alignment: .center, spacing: 3.5 * u) {
                ForEach([12.0, 26, 16, 7], id: \.self) { h in
                    Capsule().fill(Color(hex: 0x111111)).frame(width: 4.5 * u, height: h * u)
                }
                Capsule().fill(Color(hex: 0x111111)).frame(width: 27 * u, height: 7 * u).padding(.leading, 1 * u)
            }
        }
        .frame(width: size, height: size)
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
