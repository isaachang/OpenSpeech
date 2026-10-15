import AppKit
import SwiftUI

/// Zoom 默认的屏幕捕获方式会把提词器一起共享出去（腾讯会议、Teams、钉钉不会）。
/// 这台 Mac 装了 Zoom、又开着 “共享屏幕时隐藏” 时，主窗口顶上一行提示；点「查看」弹出要改的三步。
enum Zoom {
    static let bundleID = "us.zoom.xos"
    static var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

    /// 在 Zoom 里依次点的地方，最后一步选 choice（和 README、安装脚本里写的一样）
    static var steps: [String] {
        [tr("设置 › 共享屏幕", "Settings › Share Screen"), tr("高级", "Advanced"), tr("屏幕捕获模式", "Screen capture mode")]
    }
    static var choice: String { tr("高级捕获（带窗口过滤）", "Advanced capture with window filtering") }
}

struct ZoomTip: View {
    @ObservedObject var settings: PrompterSettings
    /// 打开窗口时查一次就够了
    @State private var zoom = Zoom.appURL
    @State private var showSteps = false

    var body: some View {
        if let zoom, settings.hideFromCapture, !settings.zoomTipDismissed {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: zoom.path))
                    .resizable().frame(width: 22, height: 22)
                Text(tr("用 Zoom 共享屏幕前，务必修改以下设置", "Before sharing your screen in Zoom, change this setting"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer(minLength: 8)
                Button { showSteps.toggle() } label: {
                    Text(tr("查看", "View")).font(.system(size: 12.5, weight: .semibold)).foregroundColor(Theme.ink)
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(Capsule().fill(showSteps ? Theme.buttonFill : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .popover(isPresented: $showSteps, arrowEdge: .bottom) {
                    ZoomSteps(open: { NSWorkspace.shared.open(zoom) }, done: dismiss)
                }
                CloseButton(action: dismiss)
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.sheet))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 1))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func dismiss() {
        showSteps = false
        withAnimation(.easeOut(duration: 0.3)) { settings.zoomTipDismissed = true }
    }
}

/// 弹出框：按顺序点哪里，最后一步要选的那一项做成 Zoom 里下拉框的样子
private struct ZoomSteps: View {
    let open: () -> Void
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(tr("按照以下步骤修改：", "Follow these steps:")).font(.system(size: 11.5)).foregroundColor(Theme.ink2)
            ForEach(Array(Zoom.steps.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 8) {
                    Text("\(i + 1)").font(.system(size: 10.5, weight: .bold)).foregroundColor(Theme.ink2)
                        .frame(width: 18, height: 18).background(Circle().fill(Theme.buttonFill))
                    if i == Zoom.steps.count - 1 {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { step(s); choice }
                            VStack(alignment: .leading, spacing: 6) { step(s); choice }
                        }
                    } else {
                        step(s)
                    }
                }
            }
            HStack(spacing: 8) {
                Spacer()
                pill(tr("改好了", "Done"), primary: false, action: done)
                pill(tr("打开 Zoom", "Open Zoom"), primary: true, action: open)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 340)
        .background(Theme.sheet)
    }

    private func step(_ s: String) -> some View {
        Text(s).font(.system(size: 12.5, weight: .medium)).foregroundColor(Theme.ink).fixedSize()
    }

    private var choice: some View {
        HStack(spacing: 5) {
            Text(Zoom.choice).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.ink)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 8.5, weight: .bold)).foregroundColor(Theme.ink3)
        }
        .padding(.horizontal, 9).frame(height: 22)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.highlighter.opacity(0.55)))
        .fixedSize()
    }

    private func pill(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .foregroundColor(primary ? Theme.primaryText : Theme.buttonText)
                .padding(.horizontal, 12).frame(height: 26)
                .background(Capsule().fill(primary ? Theme.primaryFill : Theme.buttonFill))
        }
        .buttonStyle(PressStyle())
    }
}
