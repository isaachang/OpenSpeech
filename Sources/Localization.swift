import AppKit

/// 界面语言：设置里可以选“自动 / 中文 / English”。
/// 自动：系统语言列表里有中文就用中文（很多人的 Mac 系统语言是英文、第二语言是中文），完全没有中文才用英文。
/// 截图 / 测试时可以用 `OPENSPEECH_LANG=en` / `zh` 强制指定。改了要重新打开 App 才生效。
enum Lang {
    enum Choice: String, CaseIterable, Identifiable {
        case auto, zh, en
        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: return tr("自动", "Automatic")
            case .zh: return "中文"
            case .en: return "English"
            }
        }
    }

    static let key = "uiLanguage"
    static var choice: Choice { Choice(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .auto }

    static let isChinese: Bool = {
        if let forced = ProcessInfo.processInfo.environment["OPENSPEECH_LANG"] { return forced.hasPrefix("zh") }
        switch choice {
        case .zh: return true
        case .en: return false
        case .auto: return Locale.preferredLanguages.contains { $0.hasPrefix("zh") }
        }
    }()

    /// 换语言：存下来，重新打开 App
    static func set(_ c: Choice) {
        guard c != choice else { return }
        UserDefaults.standard.set(c.rawValue, forKey: key)
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

/// 同一句话的中文和英文写在一起，按界面语言挑一个
func tr(_ zh: String, _ en: String) -> String { Lang.isChinese ? zh : en }
