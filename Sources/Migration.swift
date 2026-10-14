import Foundation

/// 产品改过两次名（NotchCue → OpenPitch → OpenSpeech）：第一次启动时把最近一个旧名字下的
/// 稿件库、跟随日志、识别模型和设置复制过来（旧数据保留不删）
enum Migration {
    /// 从新到旧：旧的 Application Support 文件夹名、旧的设置域
    private static let previous = [("OpenPitch", "app.openpitch.mac"), ("NotchCue", "app.notchcue.demo")]

    static func runIfNeeded() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let new = support.appendingPathComponent("OpenSpeech", isDirectory: true)
        if !fm.fileExists(atPath: new.path),
           let old = previous.map({ support.appendingPathComponent($0.0, isDirectory: true) })
               .first(where: { fm.fileExists(atPath: $0.path) }) {
            try? fm.copyItem(at: old, to: new)
        }

        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedFromPreviousName") else { return }
        if let old = previous.lazy.compactMap({ d.persistentDomain(forName: $0.1) }).first(where: { !$0.isEmpty }) {
            for (k, v) in old where d.object(forKey: k) == nil && !k.hasPrefix("NS") && !k.hasPrefix("Apple") {
                d.set(v, forKey: k)
            }
        }
        d.set(true, forKey: "migratedFromPreviousName")
    }
}
