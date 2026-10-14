import Foundation

/// 跟随日志：每次提词一个 JSONL 文件，记录识别文字和每一步位置判断，用于离线回放调参。
/// 只写在本机：~/Library/Application Support/OpenSpeech/logs/
final class SessionLogger {
    static let directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OpenSpeech/logs", isDirectory: true)

    private let queue = DispatchQueue(label: "openspeech.log")
    private var handle: FileHandle?
    /// 这次提词对应的录音文件路径（只有打开“保存测试录音”时才会写）
    private(set) var audioURL: URL?
    private var t0: CFTimeInterval = 0

    func begin(title: String, mode: String, locale: String, script: String, now: CFTimeInterval) {
        end()
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let url = Self.directory.appendingPathComponent("session-\(f.string(from: Date())).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        audioURL = url.deletingPathExtension().appendingPathExtension("caf")
        t0 = now
        write(["ev": "start", "title": title, "mode": mode, "locale": locale, "script": script], now: now)
        prune()
    }

    func write(_ obj: [String: Any], now: CFTimeInterval) {
        guard let handle else { return }
        var o = obj
        o["t"] = (now - t0).rounded(toPlaces: 3)
        guard let data = try? JSONSerialization.data(withJSONObject: o) else { return }
        queue.async {
            handle.write(data)
            handle.write(Data([0x0A]))
        }
    }

    func end() {
        guard let h = handle else { return }
        handle = nil
        queue.async { try? h.close() }
    }

    /// 只保留最近 30 个文件
    private func prune() {
        queue.async {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil) else { return }
            let logs = files.filter { $0.pathExtension == "jsonl" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
            for f in logs.dropFirst(30) { try? fm.removeItem(at: f) }
            // 录音文件比较大，只留最近 10 段
            let audio = files.filter { $0.pathExtension == "caf" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
            for f in audio.dropFirst(10) { try? fm.removeItem(at: f) }
        }
    }
}

private extension Double {
    func rounded(toPlaces p: Int) -> Double {
        let m = pow(10, Double(p))
        return (self * m).rounded() / m
    }
}
