import AppKit
import SwiftUI

/// Zoom 默认的屏幕捕获方式会把提词器一起共享出去（腾讯会议、Teams、钉钉不会）。
/// 这台 Mac 装了 Zoom、又开着 “共享屏幕时隐藏” 时，主窗口顶上提示一次要改哪个设置。
enum Zoom {
    static let bundleID = "us.zoom.xos"
    static var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

    /// Zoom 里要改的那一项（和 README、安装脚本里写的一样）
    static var settingPath: String {
        tr("Zoom › 设置 › 共享屏幕 › 高级 › 屏幕捕获模式 → 「高级捕获（带窗口过滤）」",
           "Zoom › Settings › Share Screen › Advanced › Screen capture mode → Advanced capture with window filtering")
    }
}

struct ZoomTip: View {
    @ObservedObject var settings: PrompterSettings
    /// 打开窗口时查一次就够了
    @State private var zoom = Zoom.appURL

    var body: some View {
        if let zoom, settings.hideFromCapture, !settings.zoomTipDismissed {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: zoom.path))
                    .resizable().frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("用 Zoom 共享屏幕？改一个设置，对方就看不到提词器",
                            "Sharing your screen in Zoom? Change one setting to keep the prompter hidden"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(Zoom.settingPath).font(.system(size: 11.5)).foregroundColor(Theme.ink2)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                LinkButton(title: tr("打开 Zoom", "Open Zoom")) { NSWorkspace.shared.open(zoom) }
                CloseButton { withAnimation(.easeOut(duration: 0.3)) { settings.zoomTipDismissed = true } }
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.sheet))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 1))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
