import AppKit
import Combine
import Sparkle

/// 自动更新的界面状态。Sparkle 负责下载、校验签名、替换、重启；界面全部是我们自己画的（UpdateViews.swift）。
final class UpdateModel: ObservableObject {
    enum Stage: Equatable {
        case idle
        case checking
        case upToDate
        /// 手动检查没成功：offline = 没网 / 连不上；否则是连上了但没拿到更新信息
        case checkFailed(offline: Bool)
        case available
        case downloading(received: UInt64, total: UInt64)
        case verifying
        case installing
        case failed(String)
        case needsMove
    }

    enum Panel { case notes, progress, move, changelog }

    @Published var stage: Stage = .idle
    /// 有新版本时：版本号、更新内容、安装包大小
    @Published var release: ChangelogEntry?
    @Published var releaseSize: UInt64 = 0
    @Published var panel: Panel?
    /// 关掉横幅后只在右下角留提示
    @Published var bannerDismissed = false
    /// 正在提词（不算预览）时不显示横幅
    @Published var prompting = false
    /// 刚更新完重新打开时显示绿色确认
    @Published var justUpdated: String?
    let history = Changelog.bundled()

    let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var showsBanner: Bool { stage == .available && !bannerDismissed && !prompting }
    var hasUpdate: Bool {
        switch stage {
        case .available, .downloading, .verifying, .installing, .failed, .needsMove: return release != nil
        default: return false
        }
    }

    // 界面按钮 → UpdateController
    var onCheck: () -> Void = {}
    var onInstall: () -> Void = {}
    var onLater: () -> Void = {}
    var onSkip: () -> Void = {}
    var onCancel: () -> Void = {}
    var onRetry: () -> Void = {}
    var onMove: () -> Void = {}
}

/// 把 Sparkle 的回调翻译成 UpdateModel 的状态
final class UpdateController: NSObject, SPUUserDriver {
    let model: UpdateModel
    private var updater: SPUUpdater!
    private var foundReply: ((SPUUserUpdateChoice) -> Void)?
    private var cancelDownload: (() -> Void)?
    private var errorAck: (() -> Void)?
    private var userInitiated = false
    /// 失败后点“重试”：重新检查，找到就直接装
    private var installWhenFound = false
    /// 取消下载后再提示一次横幅
    private var reshowAfterDismiss = false
    private var resetWork: DispatchWorkItem?
    private var started = false

    private static let lastRunKey = "lastRunVersion"

    init(model: UpdateModel) {
        self.model = model
        super.init()
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
        model.onCheck = { [weak self] in self?.checkNow() }
        model.onInstall = { [weak self] in self?.install() }
        model.onLater = { [weak self] in self?.later() }
        model.onSkip = { [weak self] in self?.skip() }
        model.onCancel = { [weak self] in self?.cancel() }
        model.onRetry = { [weak self] in self?.retry() }
        model.onMove = { [weak self] in self?.moveToApplications() }
    }

    /// 启动：记下版本（判断是不是刚更新完），过几秒在后台查一次
    func start() {
        let d = UserDefaults.standard
        if let last = d.string(forKey: Self.lastRunKey), last != model.current,
           SUStandardVersionComparator.default.compareVersion(last, toVersion: model.current) == .orderedAscending {
            model.justUpdated = model.current
        }
        d.set(model.current, forKey: Self.lastRunKey)

        do { try updater.start() } catch { NSLog("OpenSpeech updater: \(error.localizedDescription)"); return }
        started = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.updater.canCheckForUpdates else { return }
            self.updater.checkForUpdatesInBackground()
        }
    }

    /// 打开主窗口时：距离上次检查超过 1 小时就在后台再查一次。
    /// App 关掉窗口后还留在刘海里运行，很少真正重新打开，只靠每天一次的定时检查会太慢。
    func checkIfStale() {
        guard started, updater.canCheckForUpdates, model.stage == .idle else { return }
        if let last = updater.lastUpdateCheckDate, Date().timeIntervalSince(last) < 3600 { return }
        updater.checkForUpdatesInBackground()
    }

    // MARK: - 按钮

    func checkNow() {
        if model.hasUpdate { model.panel = .notes; return }
        guard updater.canCheckForUpdates else { return }
        updater.checkForUpdates()
    }

    private var isTranslocated: Bool { Bundle.main.bundlePath.contains("/AppTranslocation/") }

    private func install() {
        // 从「下载」里直接打开的（被系统放到只读的临时位置），没法原地替换：先引导移到「应用程序」
        if isTranslocated { model.stage = .needsMove; model.panel = .move; return }
        guard let reply = foundReply else { return }
        foundReply = nil
        model.stage = .downloading(received: 0, total: model.releaseSize)
        model.panel = .progress
        reply(.install)
    }

    private func later() {
        model.panel = nil
        model.bannerDismissed = true
        // 下载失败后点“以后再说”：结束这次更新，后台重新查一次，右下角继续留着“有新版本”
        if case .failed = model.stage {
            reshowAfterDismiss = true
            model.stage = .idle
            ackError()
        }
    }

    private func skip() {
        model.panel = nil
        foundReply?(.skip)
        foundReply = nil
        model.release = nil
        model.stage = .idle
    }

    private func cancel() {
        reshowAfterDismiss = true
        model.bannerDismissed = false
        cancelDownload?()
        cancelDownload = nil
        model.panel = nil
    }

    private func retry() {
        ackError()
        installWhenFound = true
        model.stage = .downloading(received: 0, total: model.releaseSize)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.updater.checkForUpdates() }
    }

    private func ackError() {
        let ack = errorAck
        errorAck = nil
        ack?()
    }

    /// 把自己复制到 /Applications、去掉隔离标记，从那里重新打开
    private func moveToApplications() {
        let fm = FileManager.default
        let dest = URL(fileURLWithPath: "/Applications/OpenSpeech.app")
        do {
            if fm.fileExists(atPath: dest.path) { try fm.trashItem(at: dest, resultingItemURL: nil) }
            try fm.copyItem(at: Bundle.main.bundleURL, to: dest)
            let x = Process()
            x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            x.arguments = ["-dr", "com.apple.quarantine", dest.path]
            try x.run(); x.waitUntilExit()
        } catch {
            model.stage = .failed("没能移到「应用程序」：\(error.localizedDescription)。可以手动把 OpenSpeech 拖进「应用程序」文件夹。")
            model.panel = .progress
            return
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: dest, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func showBriefly(_ stage: UpdateModel.Stage) {
        model.stage = stage
        resetWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.model.stage == stage else { return }
            self.model.stage = .idle
        }
        resetWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: w)
    }

    /// 真的是网络问题（断网、找不到服务器、超时），而不是服务器上没有更新信息（比如还没发布，返回 404）
    static func isOffline(_ error: NSError) -> Bool {
        var e: NSError? = error
        while let cur = e {
            if cur.domain == NSURLErrorDomain {
                return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost,
                        NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorDNSLookupFailed,
                        NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed].contains(cur.code)
            }
            e = cur.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    private static func message(for error: NSError) -> String {
        switch error.code {
        case Int(SUError.downloadError.rawValue): return "网络断开了，检查网络后重试"
        case Int(SUError.signatureError.rawValue), Int(SUError.validationError.rawValue):
            return "安装包没通过校验，已经丢弃。稍后再试，或者去网页下载"
        case Int(SUError.installationWriteNoPermissionError.rawValue):
            return "没有权限替换旧版本，把 OpenSpeech 放进「应用程序」文件夹后再试"
        default: return error.localizedDescription
        }
    }

    // MARK: - SPUUserDriver

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        userInitiated = true
        if !installWhenFound { model.stage = .checking }
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        let notes = appcastItem.itemDescription.flatMap { Changelog.parse($0).first }
        model.release = notes ?? ChangelogEntry(version: appcastItem.displayVersionString, date: appcastItem.dateString ?? "")
        model.releaseSize = appcastItem.contentLength
        foundReply = reply
        model.stage = .available
        if installWhenFound {
            installWhenFound = false
            install()
        } else if ProcessInfo.processInfo.environment["OPENSPEECH_TEST_AUTO_INSTALL"] == "1" {
            // tools/test-update.sh：替用户点“立即更新”，验证整条更新链路
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.install() }
        } else if state.userInitiated {
            model.panel = .notes
        }
        userInitiated = false
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        if userInitiated { showBriefly(.upToDate) }
        userInitiated = false
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let e = error as NSError
        switch model.stage {
        case .downloading, .verifying, .installing:
            model.stage = .failed(Self.message(for: e))
            model.panel = .progress
            errorAck = acknowledgement
        default:
            // 后台检查失败不打扰；手动检查才提示
            if userInitiated || installWhenFound { showBriefly(.checkFailed(offline: Self.isOffline(e))) }
            installWhenFound = false
            acknowledgement()
        }
        userInitiated = false
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        cancelDownload = cancellation
        model.stage = .downloading(received: 0, total: model.releaseSize)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        if expectedContentLength > 0 { model.releaseSize = expectedContentLength }
        model.stage = .downloading(received: 0, total: model.releaseSize)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        if case .downloading(let got, let total) = model.stage {
            model.stage = .downloading(received: got + length, total: total)
        }
    }

    func showDownloadDidStartExtractingUpdate() {
        cancelDownload = nil
        model.stage = .verifying
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        model.stage = .installing
        // 留一点时间让“安装并重新打开”这一步显示出来
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { reply(.install) }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        model.stage = .installing
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {
        NSApp.activate(ignoringOtherApps: true)
        if model.hasUpdate { model.panel = model.panel ?? .notes }
    }

    func dismissUpdateInstallation() {
        foundReply = nil
        cancelDownload = nil
        if installWhenFound { return }
        switch model.stage {
        case .failed, .needsMove: break
        case .upToDate, .checkFailed: break
        default:
            model.stage = .idle
            model.release = nil
            if model.panel == .progress || model.panel == .notes { model.panel = nil }
        }
        if reshowAfterDismiss {
            reshowAfterDismiss = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.updater.checkForUpdatesInBackground() }
        }
    }
}
