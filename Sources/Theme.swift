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
/// 纸白配色：主窗口、更新卡片、提词卡片是浅色纸面、黑字；刘海是硬件，永远是黑的，刘海里用最下面“刘海”那一组。
enum Theme {
    // 纸面
    static let paper = Color(hex: 0xFBFAF7)          // 主窗口
    static let paperSide = Color(hex: 0xF3F1EC)      // 侧栏
    static let sheet = Color.white                   // 编辑区、弹出卡片
    static let thumb = Color(hex: 0xE9E6DF)          // 样式缩略图的底
    static let selRow = Color(hex: 0xE6E2D9)         // 选中的稿件
    static let line = Color.black.opacity(0.08)      // 细描边、分割线
    static let wash = Color.black.opacity(0.04)      // 浅色块（说明框、未选中的底）

    // 文字
    static let ink = Color(hex: 0x1C1C1E)
    static let ink2 = Color(hex: 0x5E5E63)
    static let ink3 = Color(hex: 0x9A9A9F)
    static let link = ink

    // 按钮和控件：每屏只有一个黑色实心主按钮，其余是浅灰
    static let primaryFill = ink
    static let primaryText = Color.white
    static let buttonFill = Color(hex: 0xEEEBE5)
    static let buttonText = ink
    static let control = ink                         // 开关、滑块打开时
    static let selection = ink                       // 选中的样式缩略图描边

    // 提词卡片：正在读的字用荧光笔黄标出来
    static let highlighter = Color(hex: 0xFFE58A)
    /// 液态玻璃：毛玻璃层的不透明度（越小越能看清后面）和上面那层纸色的不透明度。
    /// 0.7 + 0.5：后面的东西隐约透出来，深色背景上黑字也看得清
    static let glassFrost: CGFloat = 0.7
    static let glassVeil = 0.5
    /// 小抄是一整屏小字，后面太花会看不清：比提词卡片实一些
    static let cheatVeil = 0.8

    // 刘海（黑色背景）
    static let accent = Color(hex: 0xF5F5F7)         // 刘海里的声波、勾、进度
    static let notchPrimaryFill = Color.white
    static let notchPrimaryText = Color.black
    static let soft = Color.white.opacity(0.1)

    // 状态色：表示意思，不跟着配色变。深色底（刘海、字幕胶囊）用这组
    static let amber = Color(hex: 0xFCD34D)          // 字幕胶囊样式
    static let cue = Color(hex: 0xFDBA74)            // 【导演提示】
    static let emphasis = Color(hex: 0xFDE68A)       // **重点**
    static let green = Color(hex: 0x4ADE80)          // 语速正好、完成
    static let sky = Color(hex: 0x7DD3FC)            // 语速偏慢
    static let orange = Color(hex: 0xFB923C)         // 语速偏快、提醒
    static let red = Color(hex: 0xF87171)            // 出错
    // 浅色纸面上的同一组状态色（加深，才看得清）
    static let cueInk = Color(hex: 0xC2410C)
    static let emphasisInk = Color(hex: 0xB7791F)
    static let greenInk = Color(hex: 0x16A34A)
    static let amberInk = Color(hex: 0xB45309)
    static let redInk = Color(hex: 0xDC2626)
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
    /// 刘海里是黑底；放在浅色主窗口里时传 false
    var onDark = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                if let label { Text(label).font(.system(size: 12, weight: .semibold)) }
            }
            .foregroundColor(prominent ? (onDark ? Theme.notchPrimaryText : Theme.primaryText) : (onDark ? .white.opacity(0.9) : Theme.ink))
            .padding(.horizontal, label == nil ? 9 : 13)
            .frame(minWidth: 28)
            .frame(height: 26)
            .background(Capsule().fill(prominent ? (onDark ? Theme.notchPrimaryFill : Theme.primaryFill)
                                                 : (onDark ? Color.white.opacity(0.11) : Theme.buttonFill)))
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
        .overlay(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
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
