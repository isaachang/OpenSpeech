import Foundation

/// 产品从 NotchCue 改名为 OpenPitch：第一次启动时把旧的稿件库、跟随日志、识别模型和设置复制过来（旧数据保留不删）
enum Migration {
    static func runIfNeeded() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = support.appendingPathComponent("NotchCue", isDirectory: true)
        let new = support.appendingPathComponent("OpenPitch", isDirectory: true)
        if fm.fileExists(atPath: old.path) && !fm.fileExists(atPath: new.path) {
            try? fm.copyItem(at: old, to: new)
        }

        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedFromNotchCue"), let oldDefaults = UserDefaults(suiteName: "app.notchcue.demo") else { return }
        for (k, v) in oldDefaults.dictionaryRepresentation() where d.object(forKey: k) == nil && !k.hasPrefix("NS") && !k.hasPrefix("Apple") {
            d.set(v, forKey: k)
        }
        d.set(true, forKey: "migratedFromNotchCue")
    }
}
