import SwiftUI

// 主窗口里的更新界面：顶部横幅、右下角版本号、居中的更新卡片 / 版本日志

private let cardFill = Theme.sheet
private let linkColor = Theme.link

private func sizeText(_ bytes: UInt64) -> String {
    bytes == 0 ? "" : String(format: "%.1f MB", Double(bytes) / 1_000_000)
}

// MARK: - 顶部横幅

struct UpdateBanner: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        VStack(spacing: 0) {
            if model.showsBanner, let r = model.release {
                bar(border: Theme.line, fill: AnyShapeStyle(Theme.sheet)) {
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("OpenSpeech \(r.version) 可以更新了", "OpenSpeech \(r.version) is available")).font(.system(size: 13, weight: .semibold))
                        Text(r.shortLine).font(.system(size: 11.5)).foregroundColor(Theme.ink2).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    LinkButton(title: tr("查看更新内容", "What's new")) { model.panel = .notes }
                    AccentButton(title: tr("立即更新", "Update now"), action: model.onInstall)
                    CloseButton { withAnimation(.easeOut(duration: 0.3)) { model.bannerDismissed = true } }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let v = model.justUpdated {
                bar(border: Theme.greenInk.opacity(0.3), fill: AnyShapeStyle(Theme.greenInk.opacity(0.07))) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundColor(Theme.greenInk).frame(width: 26)
                    Text(tr("已更新到 \(v)", "Updated to \(v)")).font(.system(size: 13, weight: .semibold))
                    Text(tr("稿件和设置都在", "Your scripts and settings are kept")).font(.system(size: 11.5)).foregroundColor(Theme.ink2)
                    Spacer(minLength: 8)
                    LinkButton(title: tr("看看更新了什么", "See what's new")) { model.panel = .changelog }
                    CloseButton { withAnimation(.easeOut(duration: 0.3)) { model.justUpdated = nil } }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: model.showsBanner)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: model.justUpdated)
    }

    private func bar<C: View>(border: Color, fill: AnyShapeStyle, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 10) { content() }
            .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 11).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(border, lineWidth: 1))
            .padding(.bottom, 8)
    }
}

// MARK: - 右下角：版本号 · 检查更新 · 版本日志

struct UpdateFooter: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        HStack(spacing: 6) {
            switch model.stage {
            case .checking:
                ProgressView().controlSize(.mini)
                Text(tr("正在检查更新…", "Checking for updates…"))
            case .upToDate:
                Image(systemName: "checkmark").foregroundColor(Theme.greenInk)
                Text(tr("已是最新版本（\(model.current)）", "You're up to date (\(model.current))"))
            case .checkFailed(let offline):
                Image(systemName: offline ? "wifi.exclamationmark" : "exclamationmark.circle").foregroundColor(Theme.amberInk)
                Text(offline ? tr("连不上网络，检查网络后再试", "Can't connect. Check your network") : tr("暂时查不到更新信息，稍后再试", "No update info right now. Try later"))
            default:
                Text(tr("版本 \(model.current) ·", "v\(model.current) ·"))
                if model.hasUpdate, let r = model.release {
                    Button(action: model.onCheck) {
                        HStack(spacing: 5) {
                            Circle().fill(Theme.ink).frame(width: 6, height: 6)
                            Text(tr("有新版本 \(r.version)", "New version \(r.version)"))
                        }
                    }
                    .buttonStyle(.plain).foregroundColor(linkColor)
                } else {
                    Button(tr("检查更新", "Check for updates"), action: model.onCheck).buttonStyle(.plain).foregroundColor(linkColor)
                }
                Text("·")
                Button(tr("版本日志", "Changelog")) { model.panel = .changelog }.buttonStyle(.plain).foregroundColor(linkColor)
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundColor(Theme.ink3)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: model.stage)
    }
}

// MARK: - 居中卡片

struct UpdateOverlay: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        ZStack {
            if let panel = model.panel {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { if panel == .changelog || panel == .notes { model.panel = nil } }
                    .transition(.opacity)
                Group {
                    switch panel {
                    case .notes: NotesPanel(model: model)
                    case .progress: ProgressPanel(model: model)
                    case .move: MovePanel(model: model)
                    case .changelog: ChangelogPanel(model: model)
                    }
                }
                .padding(24)
                .frame(width: panel == .changelog ? 600 : 540)
                .background(RoundedRectangle(cornerRadius: 20).fill(cardFill))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 40, y: 20)
                .padding(.vertical, 40)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.panel)
    }
}

private struct PanelHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    var warn = false
    var spinning = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: warn ? [Color(hex: 0xFFF4E0), Color(hex: 0xFCE7C3)] : [Theme.paperSide, Theme.thumb],
                                         startPoint: .top, endPoint: .bottom))
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(warn ? Theme.amberInk : Theme.ink)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(spinning ? .linear(duration: 1.4).repeatForever(autoreverses: false) : .default, value: spinning)
            }
            .frame(width: 54, height: 54)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 19, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundColor(Theme.ink2)
            }
            Spacer()
        }
        .padding(.bottom, 16)
    }
}

private struct NotesPanel: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        let r = model.release
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "arrow.down.circle", title: tr("更新到 OpenSpeech \(r?.version ?? "")", "Update to OpenSpeech \(r?.version ?? "")"),
                        subtitle: [tr("当前 \(model.current)", "Current \(model.current)"), sizeText(model.releaseSize).isEmpty ? nil : tr("约 \(sizeText(model.releaseSize))", "~\(sizeText(model.releaseSize))"), r?.date]
                            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
            if let r { EntryBody(entry: r).padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Theme.wash)) }
            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield.fill").foregroundColor(Theme.greenInk)
                Text(tr("稿件、设置、卡片位置都会保留，麦克风权限也不用重新给。", "Scripts, settings and card position are kept; no need to grant the microphone again."))
            }
            .font(.system(size: 12)).foregroundColor(Theme.ink2)
            .padding(.vertical, 14)
            HStack(spacing: 10) {
                Button(tr("跳过这个版本", "Skip this version"), action: model.onSkip).buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold)).foregroundColor(Theme.ink3)
                Spacer()
                SecondaryButton(title: tr("以后再说", "Later"), action: model.onLater)
                AccentButton(title: tr("立即更新", "Update now"), big: true, action: model.onInstall)
            }
        }
    }
}

private struct ProgressPanel: View {
    @ObservedObject var model: UpdateModel

    private enum StepState { case wait, run, ok, err }

    var body: some View {
        let failed: String? = { if case .failed(let m) = model.stage { return m }; return nil }()
        let (s1, s2, s3, fraction) = steps(failed: failed != nil)
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: failed == nil ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle",
                        title: failed == nil ? tr("正在更新到 \(model.release?.version ?? "新版本")…", "Updating to \(model.release?.version ?? "the new version")…") : tr("更新没完成", "Update didn't finish"),
                        subtitle: tr("当前 \(model.current)", "Current \(model.current)") + (model.releaseSize > 0 ? tr(" · 约 \(sizeText(model.releaseSize))", " · ~\(sizeText(model.releaseSize))") : ""),
                        warn: failed != nil, spinning: failed == nil)
            VStack(alignment: .leading, spacing: 4) {
                StepRow(state: s1, title: tr("下载新版本", "Download"), detail: failed ?? downloadDetail)
                StepRow(state: s2, title: tr("确认是官方发布的版本", "Verify it's an official release"), detail: tr("检查安装包的签名，防止被篡改", "Checks the signature so it can't be tampered with"))
                StepRow(state: s3, title: tr("安装并重新打开", "Install and relaunch"), detail: tr("替换旧版本，稿件和设置不动 · 大约 1 秒", "Replaces the old version, keeps your data · about 1 s"))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.wash)
                        Capsule().fill(failed == nil ? Theme.ink : Theme.redInk)
                            .frame(width: g.size.width * fraction)
                            .animation(.easeOut(duration: 0.35), value: fraction)
                    }
                }
                .frame(height: 5)
                .padding(.top, 10)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.wash))
            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                Text(failed != nil ? tr("旧版本没有被改动，可以照常使用。", "The old version is untouched and works as before.")
                     : model.stage == .installing ? tr("马上会自动重新打开，不用做任何操作。", "It will relaunch by itself in a moment.") : tr("下载在后台进行，可以继续编辑稿件。", "Downloading in the background; keep editing if you like."))
            }
            .font(.system(size: 12)).foregroundColor(Theme.ink2)
            .padding(.vertical, 14)
            HStack(spacing: 10) {
                if failed != nil {
                    Link(tr("去网页下载", "Download from the website"), destination: URL(string: "https://github.com/isaachang/OpenSpeech/releases/latest")!)
                        .font(.system(size: 12.5, weight: .semibold)).foregroundColor(Theme.ink3)
                    Spacer()
                    SecondaryButton(title: tr("以后再说", "Later"), action: model.onLater)
                    AccentButton(title: tr("重试", "Try again"), big: true, action: model.onRetry)
                } else {
                    Spacer()
                    if case .downloading = model.stage { SecondaryButton(title: tr("取消", "Cancel"), action: model.onCancel) }
                }
            }
            .frame(minHeight: 34)
        }
    }

    private var downloadDetail: String {
        if case .downloading(let got, let total) = model.stage, total > 0 {
            return "\(sizeText(min(got, total))) / \(sizeText(total))"
        }
        return model.releaseSize > 0 ? "\(sizeText(model.releaseSize)) / \(sizeText(model.releaseSize))" : tr("已下载", "Downloaded")
    }

    private func steps(failed: Bool) -> (StepState, StepState, StepState, CGFloat) {
        if failed { return (.err, .wait, .wait, 0.27) }
        switch model.stage {
        case .downloading(let got, let total):
            let f = total > 0 ? min(1, Double(got) / Double(total)) : 0
            return (.run, .wait, .wait, 0.7 * f)
        case .verifying: return (.ok, .run, .wait, 0.82)
        case .installing: return (.ok, .ok, .run, 1)
        default: return (.run, .wait, .wait, 0.02)
        }
    }

    private struct StepRow: View {
        let state: StepState
        let title: String
        let detail: String
        @State private var spin = false

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    switch state {
                    case .wait: Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 2)
                    case .run:
                        Circle().trim(from: 0, to: 0.75).stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            .rotationEffect(.degrees(spin ? 360 : 0))
                            .onAppear { withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true } }
                    case .ok:
                        Circle().fill(Theme.greenInk)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundColor(.white)
                    case .err:
                        Circle().fill(Theme.redInk)
                        Image(systemName: "exclamationmark").font(.system(size: 11, weight: .black)).foregroundColor(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .semibold))
                    Text(detail).font(.system(size: 11.5))
                        .foregroundColor(state == .err ? Theme.redInk : Theme.ink2)
                }
            }
            .opacity(state == .wait ? 0.45 : 1)
            .padding(.vertical, 5)
            .animation(.easeOut(duration: 0.25), value: state)
        }
    }
}

private struct MovePanel: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "folder", title: tr("先把 OpenSpeech 放进「应用程序」", "Move OpenSpeech to Applications first"), subtitle: tr("它现在是从「下载」文件夹里直接打开的", "It's running straight from Downloads"), warn: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("macOS 不允许直接替换「下载」里的 App，所以没法在这里更新。", "macOS won't let an app in Downloads replace itself, so it can't update from here."))
                Text(tr("点下面的按钮，OpenSpeech 会把自己移到「应用程序」文件夹并重新打开，然后就能更新了。", "Click below and OpenSpeech will move itself to Applications and relaunch, then it can update."))
                Text(tr("只需要做这一次。", "You only need to do this once.")).foregroundColor(Theme.ink3)
            }
            .font(.system(size: 13)).lineSpacing(3)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.wash))
            HStack(spacing: 10) {
                Spacer()
                SecondaryButton(title: tr("以后再说", "Later"), action: model.onLater)
                AccentButton(title: tr("移到「应用程序」", "Move to Applications"), big: true, action: model.onMove)
            }
            .padding(.top, 18)
        }
    }
}

// MARK: - 版本日志

private struct ChangelogPanel: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(tr("版本日志", "Version history")).font(.system(size: 19, weight: .bold))
                Spacer()
                CloseButton { model.panel = nil }
            }
            .padding(.bottom, 14)
            ScrollView { ChangelogList(model: model) }
                .frame(maxHeight: 520)
            HStack {
                Spacer()
                Link(tr("在 GitHub 上看完整日志", "Full changelog on GitHub"), destination: URL(string: "https://github.com/isaachang/OpenSpeech/blob/main/CHANGELOG.md")!)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(linkColor)
            }
            .padding(.top, 12)
        }
    }
}

/// 版本日志卡片列表：有新版本时排在最上面
struct ChangelogList: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        VStack(spacing: 12) {
            if model.hasUpdate, let r = model.release, !model.history.contains(where: { $0.version == r.version }) {
                ChangelogCard(entry: r, badge: .available, onInstall: model.onInstall)
            }
            ForEach(model.history) { e in
                ChangelogCard(entry: e, badge: e.version == model.current ? .current : nil)
            }
        }
    }
}

private struct ChangelogCard: View {
    enum Badge { case current, available }
    let entry: ChangelogEntry
    var badge: Badge?
    var onInstall: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(entry.version).font(.system(size: 16, weight: .heavy, design: .rounded))
                if badge == .current { Pill(text: tr("当前版本", "Current"), color: Theme.greenInk) }
                if badge == .available { Pill(text: tr("可以更新", "Available"), color: Theme.ink) }
                Spacer()
                Text(entry.date).font(.system(size: 11.5)).foregroundColor(Theme.ink3)
            }
            if let s = entry.summary {
                Text(s).font(.system(size: 13)).foregroundColor(Theme.ink).fixedSize(horizontal: false, vertical: true)
            }
            EntryBody(entry: entry, compact: true)
            if let onInstall {
                HStack { Spacer(); AccentButton(title: tr("立即更新", "Update now"), action: onInstall) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(badge == .available ? Theme.sheet : Theme.wash))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(badge == .available ? Theme.ink.opacity(0.35) : Theme.line, lineWidth: 1))
    }
}

/// 一个版本的分组条目：新增 / 改进 / 修复 / 移除
private struct EntryBody: View {
    let entry: ChangelogEntry
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            ForEach(Array(entry.groups.enumerated()), id: \.offset) { _, g in
                VStack(alignment: .leading, spacing: 3) {
                    Text(g.title).font(.system(size: 11, weight: .heavy)).foregroundColor(color(g.kind))
                    ForEach(Array(g.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("•").foregroundColor(Theme.ink3)
                            Text(item).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: compact ? 12.5 : 13))
                        .foregroundColor(Theme.ink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(_ k: ChangelogEntry.Kind) -> Color {
        switch k {
        case .added: return Theme.greenInk
        case .changed: return Theme.ink2
        case .fixed: return Theme.amberInk
        case .removed: return Theme.ink3
        }
    }
}

// MARK: - 小控件

private struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.system(size: 10.5, weight: .bold)).foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

private struct AccentButton: View {
    let title: String
    var big = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: big ? 13.5 : 12.5, weight: .bold)).foregroundColor(Theme.primaryText)
                .padding(.horizontal, big ? 20 : 15).frame(height: big ? 34 : 28)
                .background(Capsule().fill(Theme.primaryFill))
        }
        .buttonStyle(PressStyle())
    }
}

private struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.buttonText)
                .padding(.horizontal, 18).frame(height: 34)
                .background(Capsule().fill(Theme.buttonFill))
        }
        .buttonStyle(PressStyle())
    }
}

struct LinkButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(Theme.link).padding(.horizontal, 6).frame(height: 26)
        }
        .buttonStyle(PressStyle())
    }
}

struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.ink3)
                .frame(width: 24, height: 24).contentShape(Circle())
        }
        .buttonStyle(PressStyle())
    }
}
