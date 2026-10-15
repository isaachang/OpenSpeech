import AppKit
import Combine
import QuartzCore

enum IslandPhase: Equatable {
    case idle
    case countdown(Int)
    case presenting
    case finished

    var isActive: Bool {
        switch self {
        case .countdown, .presenting: return true
        default: return false
        }
    }

    var isCountdown: Bool { if case .countdown = self { return true }; return false }
}

struct SessionSummary {
    let duration: TimeInterval
    let avgSpeed: Double?
    let unitLabel: String
}

enum SpeedVerdict { case slow, good, fast }

final class PrompterEngine: ObservableObject {
    @Published private(set) var phase: IslandPhase = .idle
    @Published private(set) var isPaused = false
    @Published private(set) var parsed = ParsedScript()
    @Published private(set) var lines: [PrompterLine] = []
    @Published private(set) var cursor: Double = 0
    @Published private(set) var currentLine = 0
    /// 连续的滚动位置（单位：行）。一行读到后半段就开始平滑上移，不再一格一格地翻
    @Published private(set) var scroll: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var liveSpeed: Double?
    @Published private(set) var isSpeaking = false
    @Published private(set) var listening = false
    @Published private(set) var levels: [CGFloat] = Array(repeating: 0, count: 5)
    @Published private(set) var toast: String?
    @Published private(set) var title = ""
    @Published private(set) var activeMode: PrompterMode = .voice
    @Published private(set) var summary: SessionSummary?
    /// 预览模式：显示稿子但不听、不走，用来调位置；⌥⌘P 正式开始
    @Published private(set) var previewing = false

    let settings: PrompterSettings
    var audioDisabled = false

    private let speech = SpeechEngine()
    private var tracker = Tracker(units: [])
    private var target: Double = 0
    /// 语音跟读：识别确认的位置（anchor）和在它基础上按语速预测的位置（predicted）
    private var anchor: Double = 0
    private var predicted: Double = 0
    private var anchorAdvancedAt: CFTimeInterval = 0
    private var lastPrimaryAt: CFTimeInterval = 0
    private var lastWatchdogAt: CFTimeInterval = 0
    /// 识别器每次断句后会从头开始一段新文字（常常只有两三个字）；把上一段的结尾拼在前面再去对位
    private var carryText = ""
    private var lastPrimaryText = ""
    private var lastPrimaryCount = 0
    /// 这一段连续出声是从什么时候开始的
    private var speechOnsetAt: CFTimeInterval = 0
    private var unitToLine: [Int] = []
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var linkProxy: FrameProxy?
    private let logger = SessionLogger()
    private var lastTick: CFTimeInterval = 0
    private var noiseFloor: Float = -55
    private var lastVoiceAt: CFTimeInterval = -10
    private var latestDB: Float = -90
    private var speakingTime: Double = 0
    private var samples: [(wall: Double, speak: Double, pos: Double)] = []
    private var lastSampleAt: CFTimeInterval = 0
    private var lastLevelAt: CFTimeInterval = 0
    private var sessionToken = 0
    private var toastWork: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()

    init(settings: PrompterSettings) {
        self.settings = settings
        speech.onLevel = { [weak self] in self?.handleLevel($0) }
        speech.onTranscript = { [weak self] in self?.handleTranscript($0, primary: $1) }
        speech.onEvent = { [weak self] info in
            self?.logger.write(["ev": "seg", "info": info], now: CACurrentMediaTime())
        }
        speech.onRecognitionFailed = { [weak self] reason in
            guard let self, self.phase.isActive else { return }
            self.activeMode = .pace
            self.showToast(tr("语音识别不可用（\(reason)），已切到智能匀速", "Speech recognition unavailable (\(reason)); switched to constant speed"))
        }
        // 字号 / 样式 / 每行字数变了就重新折行（objectWillChange 在改之前发出，切到下一轮主线程再读新值）
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                let key = "\(self.settings.displayFontSize)-\(self.settings.textWidth)"
                if key != self.layoutKey { self.relayout() }
            }
            .store(in: &bag)
    }

    /// 用视图所在屏幕的刷新率驱动动画（ProMotion 屏可到 120Hz），没有时退回 60Hz 定时器
    func attachDisplay(to view: NSView) {
        let proxy = FrameProxy { [weak self] in self?.tick() }
        let link = view.displayLink(target: proxy, selector: #selector(FrameProxy.step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.isPaused = timer == nil
        link.add(to: .main, forMode: .common)
        linkProxy = proxy
        displayLink = link
    }

    // MARK: - Derived

    var unitLabel: String { parsed.isMostlyLatin ? tr("词/分", "wpm") : tr("字/分", "cpm") }
    var paceSpeed: Double { parsed.isMostlyLatin ? settings.targetSpeed * 0.6 : settings.targetSpeed }
    var progress: Double { parsed.units.isEmpty ? 0 : min(1, cursor / Double(parsed.units.count)) }

    var remaining: TimeInterval {
        let left = Double(parsed.units.count) - cursor
        let sp = (activeMode == .voice ? liveSpeed : nil) ?? paceSpeed
        return max(0, left / max(sp, 1) * 60)
    }

    var speedText: String {
        switch activeMode {
        case .pace: return "\(Int(paceSpeed)) \(unitLabel)"
        case .voice: return liveSpeed.map { "\(Int($0)) \(unitLabel)" } ?? (listening ? tr("聆听中…", "Listening…") : tr("准备中…", "Getting ready…"))
        }
    }

    var verdict: SpeedVerdict? {
        guard activeMode == .voice, let s = liveSpeed else { return nil }
        let r = s / paceSpeed
        return r < 0.85 ? .slow : (r > 1.15 ? .fast : .good)
    }

    // MARK: - Control

    func start(script: Script, preview: Bool = false) {
        let p = ParsedScript.parse(script.body)
        guard !p.units.isEmpty else { NSSound.beep(); return }
        teardown()
        sessionToken += 1
        parsed = p
        title = script.title.isEmpty ? tr("未命名稿件", "Untitled") : script.title
        cursor = 0
        target = 0
        anchor = 0
        predicted = 0
        scroll = 0
        tracker = Tracker(units: p.units, isLatin: p.isMostlyLatin)
        lastPrimaryAt = CACurrentMediaTime()
        carryText = ""
        lastPrimaryText = ""
        lastPrimaryCount = 0
        elapsed = 0
        speakingTime = 0
        samples = []
        liveSpeed = nil
        summary = nil
        isPaused = false
        toast = nil
        activeMode = settings.mode
        scriptBody = script.body
        relayout()
        speech.contextualStrings = ScriptLanguageModel.contextualStrings(script: script.body, localeID: p.localeID)
        prepareLanguageModel(script: script.body, localeID: p.localeID)
        if preview {
            previewing = true
            isPaused = true
            phase = .presenting
            startTimer()
            return
        }
        previewing = false
        beginLogging()
        if settings.countdown {
            phase = .countdown(3)
            runCountdown(3, token: sessionToken)
        } else {
            phase = .presenting
        }
        startTimer()
        startAudio()
    }

    func stop() {
        sessionToken += 1
        teardown()
        isPaused = false
        previewing = false
        phase = .idle
    }

    func togglePause() {
        guard phase == .presenting else { return }
        if previewing {
            // 从预览直接开始：从当前位置开讲
            previewing = false
            isPaused = false
            lastTick = CACurrentMediaTime()
            beginLogging()
            startAudio()
            return
        }
        isPaused.toggle()
        lastTick = CACurrentMediaTime()
        logger.write(["ev": isPaused ? "pause" : "resume"], now: lastTick)
        if !isPaused {
            speech.rotate()
            samples = []
            lastPrimaryAt = lastTick
        }
    }

    func jumpLines(_ delta: Int) {
        guard phase.isActive, !lines.isEmpty, delta != 0 else { return }
        let step = delta > 0 ? 1 : -1
        var li = max(0, min(lines.count - 1, currentLine + delta))
        while lines[li].unitRange.isEmpty, (0..<lines.count).contains(li + step) { li += step }
        setPosition(Double(lines[li].unitRange.lowerBound))
    }

    /// 小抄里点一段：跳到这一段开头，语音跟随从这里接着走
    func jump(toUnit u: Int) {
        guard phase.isActive, !parsed.units.isEmpty else { return }
        setPosition(Double(max(0, min(u, parsed.units.count - 1))))
    }

    /// ⌥⌘1…9 / 小抄里点标题：跳到第 n 段（从 0 开始）的第一个字
    func jump(toSection n: Int) {
        let secs = parsed.sections
        guard phase.isActive, secs.indices.contains(n) else { return }
        jump(toUnit: secs[n].nextUnit)
        showToast("→ \(n + 1)  \(secs[n].title)", duration: 1.6)
    }

    /// 现在在第几段（从 0 开始；还在第一个标题之前是 nil）
    var currentSection: Int? { parsed.section(at: Int(cursor)) }

    /// ⌥⌘← / ⌥⌘→、卡片顶上的 ‹ ›：上一段 / 下一段
    func stepSection(_ d: Int) {
        let n = d > 0 ? (currentSection ?? -1) + 1 : (currentSection ?? 0) - 1
        jump(toSection: n)
    }

    func adjustSpeed(_ d: Double) {
        settings.targetSpeed = max(100, min(400, settings.targetSpeed + d))
        if phase.isActive { showToast(tr("匀速语速 \(Int(paceSpeed)) \(unitLabel)", "Speed \(Int(paceSpeed)) \(unitLabel)"), duration: 1.6) }
    }

    func switchMode() {
        guard phase.isActive else { return }
        let newMode: PrompterMode = activeMode == .voice ? .pace : .voice
        settings.mode = newMode
        activeMode = newMode
        if previewing {
            showToast(tr("开始后使用：\(newMode.title)", "After start: \(newMode.title)"), duration: 1.6)
            return
        }
        speech.stop()
        listening = false
        target = cursor
        anchor = cursor
        predicted = cursor
        tracker.reset(to: Int(cursor))
        samples = []
        liveSpeed = nil
        logger.write(["ev": "mode", "mode": newMode.rawValue], now: CACurrentMediaTime())
        startAudio()
        showToast(newMode == .voice ? tr("已切到语音跟读：开口说话即可", "Voice-follow on: just start talking") : tr("已切到智能匀速：\(Int(paceSpeed)) \(unitLabel)", "Constant speed: \(Int(paceSpeed)) \(unitLabel)"))
    }

    func showToast(_ s: String, duration: Double = 4) {
        toast = s
        toastWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: w)
    }

    // MARK: - Internals

    private var scriptBody = ""

    /// 用这篇稿子生成识别器的专属语言模型（约 1 秒，倒计时期间完成）；好了之后从下一段识别开始生效
    private func prepareLanguageModel(script: String, localeID: String) {
        speech.languageModel = nil
        guard !audioDisabled else { return }   // 离线模拟 / 截图时不需要
        let token = sessionToken
        ScriptLanguageModel.prepare(script: script, localeID: localeID) { [weak self] config, info in
            guard let self, self.sessionToken == token else { return }
            self.speech.languageModel = config
            self.logger.write(["ev": "lm", "ok": config != nil, "info": info], now: CACurrentMediaTime())
            if config != nil && self.phase == .presenting && !self.isPaused && self.listening { self.speech.rotate(overlap: true) }
        }
    }

    private func beginLogging() {
        guard settings.trackingLog else { return }
        logger.begin(title: title, mode: activeMode.rawValue, locale: parsed.localeID, script: scriptBody, now: CACurrentMediaTime())
    }

    private func runCountdown(_ n: Int, token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            guard let self, self.sessionToken == token, case .countdown = self.phase else { return }
            if n > 1 {
                self.phase = .countdown(n - 1)
                self.runCountdown(n - 1, token: token)
            } else {
                self.phase = .presenting
                self.lastTick = CACurrentMediaTime()
                self.lastPrimaryAt = self.lastTick
                self.speech.rotate()
            }
        }
    }

    private func startAudio() {
        listening = false
        guard !audioDisabled else { return }
        let wantSpeech = activeMode == .voice
        guard wantSpeech || settings.pauseOnSilence else { return }
        let token = sessionToken
        SpeechEngine.requestPermissions(speech: wantSpeech) { [weak self] mic, speechOK in
            guard let self, self.sessionToken == token, self.phase.isActive else { return }
            guard mic else {
                if self.activeMode == .voice { self.activeMode = .pace }
                self.showToast(tr("没有麦克风权限，已改为纯匀速（系统设置 › 隐私与安全性 › 麦克风）", "No microphone access; using constant speed (System Settings › Privacy & Security › Microphone)"), duration: 6)
                return
            }
            var recognition = wantSpeech
            if wantSpeech && !speechOK {
                recognition = false
                self.activeMode = .pace
                self.showToast(tr("没有语音识别权限，已切到智能匀速（系统设置 › 隐私与安全性 › 语音识别）", "No speech recognition access; using constant speed (System Settings › Privacy & Security › Speech Recognition)"), duration: 6)
            }
            self.speech.recordURL = self.settings.saveAudio ? self.logger.audioURL : nil
            do {
                try self.speech.start(localeID: self.parsed.localeID, recognition: recognition)
                self.listening = true
            } catch {
                if self.activeMode == .voice { self.activeMode = .pace }
                self.showToast(tr("麦克风启动失败：\(error.localizedDescription)", "Microphone failed to start: \(error.localizedDescription)"), duration: 6)
            }
        }
    }

    private func teardown() {
        timer?.invalidate()
        timer = nil
        displayLink?.isPaused = true
        logger.end()
        speech.stop()
        listening = false
        isSpeaking = false
        levels = Array(repeating: 0, count: levels.count)
    }

    private func finish() {
        let avg: Double?
        if speakingTime > 3 {
            avg = Double(parsed.units.count) / speakingTime * 60
        } else if elapsed > 3 {
            avg = Double(parsed.units.count) / elapsed * 60
        } else {
            avg = nil
        }
        summary = SessionSummary(duration: elapsed, avgSpeed: avg, unitLabel: unitLabel)
        logger.write(["ev": "finish", "elapsed": elapsed], now: CACurrentMediaTime())
        teardown()
        phase = .finished
        let token = sessionToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.sessionToken == token, self.phase == .finished else { return }
            self.phase = .idle
        }
    }

    func debugSetPosition(_ u: Double) { setPosition(u) }
    var debugAnchor: Double { anchor }
    var debugCarry: String { carryText }

    private func setPosition(_ u: Double) {
        cursor = u
        target = u
        anchor = u
        predicted = u
        tracker.reset(to: Int(u))
        samples = []
        carryText = ""
        lastPrimaryText = ""
        lastPrimaryCount = 0
        logger.write(["ev": "manual", "pos": Int(u)], now: CACurrentMediaTime())
        currentLine = lineIndex(for: Int(u))
        speech.rotate()
    }

    private var layoutKey = ""

    private func relayout() {
        guard !parsed.glyphs.isEmpty else { return }
        layoutKey = "\(settings.displayFontSize)-\(settings.textWidth)"
        lines = PrompterLayout.layout(parsed, fontSize: settings.displayFontSize,
                                      maxWidth: settings.textWidth)
        var map = Array(repeating: 0, count: parsed.units.count)
        for (i, l) in lines.enumerated() { for u in l.unitRange { map[u] = i } }
        unitToLine = map
        currentLine = lineIndex(for: Int(cursor))
    }

    private func lineIndex(for u: Int) -> Int {
        guard !unitToLine.isEmpty else { return 0 }
        return unitToLine[max(0, min(u, unitToLine.count - 1))]
    }

    /// 滚动该停在哪：3 行以上时，读到一行 70% 后开始平滑上移；
    /// 1–2 行时正在读的那行在最上面，提前滑会把它滑出去，所以读完整行才换（快速过渡）
    private func scrollGoal(cursor c: Double, line li: Int) -> Double {
        guard settings.visibleLines >= 3 else { return Double(li) }
        let r = lines[li].unitRange
        var f = 0.0
        if !r.isEmpty { f = max(0, min(1, (c - Double(r.lowerBound)) / Double(r.count))) }
        let x = max(0, min(1, (f - 0.7) / 0.3))
        return Double(li) + x * x * (3 - 2 * x)
    }

    func handleLevel(_ db: Float, at now: CFTimeInterval = CACurrentMediaTime()) {
        latestDB = db
        let threshold = max(noiseFloor + 10, -50)
        if db < noiseFloor {
            noiseFloor += (db - noiseFloor) * 0.2
        } else {
            noiseFloor = min(noiseFloor + (db > threshold ? 0.004 : 0.03), -25)
        }
        if db > threshold { lastVoiceAt = now }
    }

    func handleTranscript(_ text: String, primary: Bool, at now: CFTimeInterval = CACurrentMediaTime()) {
        let raw = ParsedScript.parse(text, markup: false, chineseNumbers: !parsed.isMostlyLatin).units
        var units = raw
        if primary {
            lastPrimaryAt = now
            if raw.count > 140 { speech.rotate(overlap: true) }
            // 文字突然变得很短 = 识别器开始了新的一段：把上一段结尾接上
            if Self.carryContext && raw.count + 3 < lastPrimaryCount && raw.count <= 10 && !lastPrimaryText.isEmpty {
                carryText = String(lastPrimaryText.suffix(parsed.isMostlyLatin ? 80 : 24))
                logger.write(["ev": "carry", "text": carryText], now: now)
                lastPrimaryCount = 0
            }
            lastPrimaryCount = raw.count
            lastPrimaryText = text
            if !carryText.isEmpty {
                let sep = parsed.isMostlyLatin ? " " : ""
                units = ParsedScript.parse(carryText + sep + text, markup: false, chineseNumbers: !parsed.isMostlyLatin).units
            }
        }
        guard phase == .presenting, !isPaused, activeMode == .voice else { return }
        let before = anchor
        let d = tracker.process(units, now: now)
        let pos = Double(tracker.cursor)
        if pos != anchor {
            anchor = pos
            if pos > before { anchorAdvancedAt = now }
            if d.kind != .advance || pos < before {
                // 确认过的远跳 / 往回：预测从新位置重新开始
                predicted = pos
            } else if Self.predictionEnabled && now - lastVoiceAt < 0.3 {
                // 识别结果比嘴慢一点：正在说话时，真实位置大约在 anchor 之后一点点
                predicted = max(predicted, pos + min(speechRate * Self.recognitionLag, leadCap))
            }
        }
        if settings.trackingLog {
            logger.write(["ev": "tr", "p": primary, "text": String(text.suffix(40)), "kind": d.kind.rawValue,
                          "pos": d.pos, "raw": (d.raw * 100).rounded() / 100, "m": d.m, "cur": Int(cursor)], now: now)
        }
    }

    /// 识别延迟补偿（秒）与预测最多领先的时间（秒）。
    /// 按真实日志校准：识别结果大约每 0.2–0.3 秒更新一次，领先太多会“抢跑到下一行”
    private static let recognitionLag = 0.2
    private static let maxLead = 0.6
    /// 预测最多领先几个单位：中文 3 个字，英文 1 个词多一点
    private var leadCap: Double { parsed.isMostlyLatin ? 1.2 : 3 }

    /// 当前语速（单位/秒）
    private var speechRate: Double {
        min(8, max(1.5, (liveSpeed ?? paceSpeed) / 60))
    }

    /// 从 anchor 往后，第一个句读处（逗号 / 句号…）。预测不会越过它，
    /// 避免你在句末停顿时高亮自己跑进下一句
    private func nextBreak(after a: Double) -> Double {
        let start = max(0, Int(a))
        var i = start
        while i < parsed.breakAfter.count {
            if parsed.breakAfter[i] { return Double(i + 1) }
            i += 1
        }
        return Double(parsed.units.count)
    }

    /// anchor 所在行的行尾：预测不越过这一行，下一行要等识别确认后才切过去（避免“抢先换行”）
    private func lineEnd(of a: Double) -> Double {
        guard Self.lineCap, !lines.isEmpty else { return .infinity }
        let r = lines[lineIndex(for: Int(a))].unitRange
        return r.isEmpty ? .infinity : Double(r.upperBound)
    }

    private func startTimer() {
        timer?.invalidate()
        lastTick = CACurrentMediaTime()
        if let displayLink {
            // timer 只作为“正在运行”的标记；真正的帧由屏幕刷新驱动
            timer = Timer(timeInterval: 3600, repeats: false) { _ in }
            displayLink.isPaused = false
            return
        }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func tick(at now: CFTimeInterval = CACurrentMediaTime()) {
        let dt = min(0.1, now - lastTick)
        lastTick = now

        let speaking = listening && now - lastVoiceAt < 0.7
        if speaking != isSpeaking {
            if speaking { speechOnsetAt = now }
            isSpeaking = speaking
            logger.write(["ev": "vad", "on": speaking], now: now)
        }
        if now - lastLevelAt > 0.07 {
            lastLevelAt = now
            let v: CGFloat = listening ? CGFloat(max(0, min(1, (latestDB - noiseFloor) / 30))) : 0
            var l = levels
            l.removeFirst()
            l.append(v)
            levels = l
        }

        guard phase == .presenting, !isPaused else { return }
        let total = Double(parsed.units.count)
        elapsed += dt
        if speaking { speakingTime += dt }

        var c = cursor
        switch activeMode {
        case .pace:
            let hold = settings.pauseOnSilence && listening && !speaking
            if !hold { c += paceSpeed / 60 * dt }
            target = c
        case .voice:
            // 预测：正在出声时按你的语速往前推，识别结果回来再校正；
            // 最多领先 anchor 一小段，且不越过下一个逗号/句号
            // 识别 0.8 秒没确认新进度（说错、改词、识别卡了）就不再往前猜
            let rate = speechRate
            // 刚重新开口（停顿后 0.6 秒内）也允许先往前走一点，不必等第一条识别结果
            let resuming = Self.onsetPredict && now - speechOnsetAt < 0.6 && speechOnsetAt > anchorAdvancedAt
            let confirming = now - anchorAdvancedAt < 0.8 || resuming
            if Self.predictionEnabled && confirming && now - lastVoiceAt < 0.25 { predicted += rate * dt }
            predicted = min(predicted, anchor + min(rate * Self.maxLead, leadCap), nextBreak(after: anchor), lineEnd(of: anchor), total)
            predicted = max(predicted, anchor)
            target = anchor
            let goal = predicted
            if goal >= c {
                c += (goal - c) * min(1, dt * 12)
            } else if goal < c - 3 {
                // 真的往回了（确认过的回跳 / 手动翻行）
                c += (goal - c) * min(1, dt * 10)
            } else if goal < c - 0.8 {
                // 猜过头了：轻轻退回去
                c += (goal - c) * min(1, dt * 4)
            }
        }
        c = max(0, min(c, total))
        if abs(c - cursor) > 0.0001 { cursor = c }
        let li = lineIndex(for: Int(c))
        if li != currentLine { currentLine = li }

        if li < lines.count {
            let goal = scrollGoal(cursor: c, line: li)
            let next = scroll + (goal - scroll) * min(1, dt * 11)
            if abs(next - scroll) > 0.0005 { scroll = abs(goal - next) < 0.001 ? goal : next }
        }

        // 看门狗：你已经连续说了 2 秒多，识别却一直没有任何结果 → 识别器可能悄悄停了，重启一段
        if activeMode == .voice && listening && speaking && now - max(lastPrimaryAt, speechOnsetAt) > 2.2 && now - lastWatchdogAt > 4 {
            lastWatchdogAt = now
            lastPrimaryAt = now
            speech.rotate(overlap: true)
            logger.write(["ev": "watchdog"], now: now)
        }

        if now - lastSampleAt > 0.5 {
            lastSampleAt = now
            samples.append((elapsed, speakingTime, activeMode == .voice ? target : c))
            samples.removeAll { elapsed - $0.wall > 12 }
            if let first = samples.first, let last = samples.last, last.speak - first.speak > 2.5 {
                let sp = (last.pos - first.pos) / (last.speak - first.speak) * 60
                if sp >= 0 { liveSpeed = liveSpeed.map { $0 * 0.6 + sp * 0.4 } ?? sp }
            }
        }

        // 跟读模式：识别经常漏掉最后几个字，接近结尾且安静 2 秒就算讲完
        let spokenEnd = Double(parsed.spokenEnd)
        let nearEnd = target >= total - 0.5
            || (activeMode == .voice && target >= spokenEnd - 4 && now - lastVoiceAt > 2.0)
        if nearEnd && c >= min(target, total) - 0.3 { finish() }
    }

    // MARK: - Snapshot / debug / simulation

    /// 仅用于离线模拟对比
    static var predictionEnabled = true
    static var carryContext = true
    static var lineCap = true
    static var onsetPredict = true

    func simulateListening(at now: CFTimeInterval) {
        listening = true
        lastTick = now
    }

    /// README 动图的一帧：直接给出读到哪、有没有在说话，滚动按真实规则平滑跟上
    func debugFrame(cursor c: Double, dt: Double, speaking: Bool, levels lv: [CGFloat], speed: Double?) {
        cursor = c
        currentLine = lineIndex(for: Int(c))
        if currentLine < lines.count {
            let goal = scrollGoal(cursor: c, line: currentLine)
            scroll += (goal - scroll) * min(1, dt * 11)
        }
        isSpeaking = speaking
        levels = lv
        liveSpeed = speed
    }

    func debugPresent(script: Script, cursor c: Double, phase ph: IslandPhase, paused: Bool = false, mode: PrompterMode = .voice, preview: Bool = false) {
        previewing = preview
        parsed = ParsedScript.parse(script.body)
        title = script.title
        activeMode = mode
        relayout()
        cursor = c
        target = c
        currentLine = lineIndex(for: Int(c))
        scroll = Double(currentLine)
        phase = ph
        isPaused = paused
        listening = true
        isSpeaking = !paused
        liveSpeed = 236
        levels = [0.35, 0.75, 1, 0.6, 0.4]
        elapsed = 42
        summary = SessionSummary(duration: 133, avgSpeed: 228, unitLabel: unitLabel)
    }
}

private final class FrameProxy: NSObject {
    let onFrame: () -> Void
    init(_ onFrame: @escaping () -> Void) { self.onFrame = onFrame }
    @objc func step(_ link: CADisplayLink) { onFrame() }
}
