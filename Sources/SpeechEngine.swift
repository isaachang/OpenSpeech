import AVFoundation
import Speech

/// 麦克风 + Apple 语音识别。只负责产出：音量(dB) 与 实时识别文字。
final class SpeechEngine {
    var onLevel: ((Float) -> Void)?
    /// (文字, 是否来自当前这一段识别)。换段时旧的一段还会再听一小会儿，那时 primary = false
    var onTranscript: ((String, Bool) -> Void)?
    var onRecognitionFailed: ((String) -> Void)?
    /// 识别段结束 / 出错（写进跟随日志，方便排查“卡住”）
    var onEvent: ((String) -> Void)?
    var contextualStrings: [String] = []
    /// 用稿子生成的专属语言模型（只在本机识别时可用）
    var languageModel: SFSpeechLanguageModel.Configuration?
    /// 打开时把麦克风声音存成文件（只用于离线调优，默认不开）
    var recordURL: URL?
    private var recordFile: AVAudioFile?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var overlapRequest: SFSpeechAudioBufferRecognitionRequest?
    private var overlapTask: SFSpeechRecognitionTask?
    private var overlapGen = -1
    private let lock = NSLock()
    private var generation = 0
    private var running = false
    private var tapInstalled = false
    private var recognitionOn = false
    private var preferOnDevice = true
    private var quickFailures = 0
    private var taskStartedAt = Date()

    static func requestPermissions(speech: Bool, completion: @escaping (_ mic: Bool, _ speech: Bool) -> Void) {
        let askSpeech: (Bool) -> Void = { mic in
            guard speech, mic else {
                DispatchQueue.main.async { completion(mic, false) }
                return
            }
            SFSpeechRecognizer.requestAuthorization { st in
                DispatchQueue.main.async { completion(mic, st == .authorized) }
            }
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: askSpeech(true)
        case .notDetermined: AVCaptureDevice.requestAccess(for: .audio) { askSpeech($0) }
        default: askSpeech(false)
        }
    }

    func start(localeID: String, recognition: Bool) throws {
        stop()
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "OpenSpeech", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有找到可用的麦克风"])
        }
        let device = AVCaptureDevice.default(for: .audio)?.localizedName ?? "?"
        let thermal = ["nominal", "fair", "serious", "critical"][min(3, ProcessInfo.processInfo.thermalState.rawValue)]
        onEvent?("input: \(device) · \(Int(format.sampleRate))Hz · \(format.channelCount)ch · thermal \(thermal)")
        if let recordURL {
            recordFile = try? AVAudioFile(forWriting: recordURL, settings: format.settings)
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        tapInstalled = true
        audioEngine.prepare()
        try audioEngine.start()
        running = true
        quickFailures = 0
        recognitionOn = recognition
        guard recognition else { return }

        let r = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        guard let r, r.isAvailable else {
            recognitionOn = false
            DispatchQueue.main.async { self.onRecognitionFailed?("当前语言暂不可用") }
            return
        }
        recognizer = r
        preferOnDevice = r.supportsOnDeviceRecognition
        onEvent?(preferOnDevice ? "start: on-device" : "start: server")
        startTask()
    }

    /// 开始一段新的识别。
    /// overlap = true（识别文本太长时）：旧的一段继续听 1.2 秒，新的一段还没出结果前不会断档；
    /// overlap = false（跳行、暂停恢复）：直接丢掉旧的上下文。
    func rotate(overlap: Bool = false) {
        guard running, recognitionOn else { return }
        startTask(overlap: overlap)
    }

    func stop() {
        running = false
        recognitionOn = false
        generation += 1
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        lock.lock()
        let r = request
        request = nil
        lock.unlock()
        r?.endAudio()
        task?.cancel()
        task = nil
        endOverlap()
        recordFile = nil
    }

    private func endOverlap() {
        lock.lock()
        let r = overlapRequest
        overlapRequest = nil
        lock.unlock()
        r?.endAudio()
        overlapTask?.cancel()
        overlapTask = nil
        overlapGen = -1
    }

    private func startTask(overlap: Bool = false) {
        guard let recognizer else { return }
        endOverlap()
        let oldGen = generation
        generation += 1
        let gen = generation
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        req.addsPunctuation = false
        if preferOnDevice {
            req.requiresOnDeviceRecognition = true
            if let languageModel { req.customizedLanguageModel = languageModel }
        }
        if !contextualStrings.isEmpty { req.contextualStrings = contextualStrings }

        lock.lock()
        let old = request
        request = req
        if overlap, old != nil { overlapRequest = old }
        lock.unlock()
        if overlap, old != nil {
            overlapTask = task
            overlapGen = oldGen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self, self.overlapGen == oldGen else { return }
                self.endOverlap()
            }
        } else {
            old?.endAudio()
            task?.cancel()
        }
        taskStartedAt = Date()

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            DispatchQueue.main.async {
                guard let self, self.running else { return }
                if gen == self.overlapGen {
                    if let text, !text.isEmpty { self.onTranscript?(text, false) }
                    return
                }
                guard gen == self.generation else { return }
                if let text, !text.isEmpty {
                    self.quickFailures = 0
                    self.onTranscript?(text, true)
                }
                if error != nil || isFinal { self.handleEnd(error: error, gen: gen) }
            }
        }
    }

    private func handleEnd(error: Error?, gen: Int) {
        onEvent?(error.map { "error: \($0.localizedDescription)" } ?? "final")
        if let error, Date().timeIntervalSince(taskStartedAt) < 1.5 {
            quickFailures += 1
            // 专属语言模型和这台机器的识别器不兼容时，先去掉它再试，不要直接退到联网识别
            if languageModel != nil {
                languageModel = nil
                onEvent?("lm: dropped after error \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self, self.running, self.recognitionOn, gen == self.generation else { return }
                    self.startTask()
                }
                return
            }
            // 本地模型不可用时退回联网识别
            if preferOnDevice {
                preferOnDevice = false
                onEvent?("fallback: server")
            }
            if quickFailures >= 4 {
                recognitionOn = false
                onRecognitionFailed?(error.localizedDescription)
                return
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.running, self.recognitionOn, gen == self.generation else { return }
            self.startTask()
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let r = request
        let o = overlapRequest
        lock.unlock()
        r?.append(buffer)
        o?.append(buffer)
        try? recordFile?.write(from: buffer)

        guard let ch = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in 0..<n { sum += ch[i] * ch[i] }
        let db = 20 * log10(max(sqrt(sum / Float(n)), 1e-7))
        DispatchQueue.main.async { [weak self] in self?.onLevel?(db) }
    }
}
