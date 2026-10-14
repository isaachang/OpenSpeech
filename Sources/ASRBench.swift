import AVFoundation
import Speech

/// `OpenSpeech --asr-bench <输出目录>`：用系统合成语音把稿子念出来，
/// 同一段音频分别用“普通识别”和“加了稿子专属语言模型的识别”各跑一次，比较错字率和术语识别率。
/// 合成声音 ≠ 真人，只用来验证方向；不用它来调参数。
enum ASRBench {
    struct Case { let name: String; let locale: String; let voice: String; let text: String }

    static func run(outDir: String, scripts: [(String, String)]) {
        let out = URL(fileURLWithPath: outDir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var report = ""
        func log(_ s: String) { print(s); report += s + "\n" }

        let sem = DispatchSemaphore(value: 0)
        SFSpeechRecognizer.requestAuthorization { _ in sem.signal() }
        sem.wait()
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            log("没有语音识别权限，无法测试")
            try? report.write(to: out.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
            return
        }

        var cases: [Case] = []
        for (name, text) in scripts {
            let zh = text.contains { ScriptChar.isCJK($0) }
            let voices = zh ? ["Eddy (Chinese (China mainland))", "Flo (Chinese (China mainland))", "Reed (Chinese (China mainland))"]
                            : ["Samantha", "Fred"]
            for v in voices { cases.append(Case(name: name, locale: zh ? "zh-CN" : "en-US", voice: v, text: text)) }
        }

        var totals: [String: (base: Double, lm: Double, termBase: Double, termLM: Double, n: Int)] = [:]
        let limit = Int(ProcessInfo.processInfo.environment["NC_BENCH_LIMIT"] ?? "") ?? cases.count
        for c in cases.prefix(limit) {
            let audio = out.appendingPathComponent("\(c.name)-\(c.voice.prefix(4)).wav")
            let spoken = c.text.replacingOccurrences(of: #"【[^】]*】|\[[^\]]*\]|\*\*"#, with: "", options: .regularExpression)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            p.arguments = ["-v", c.voice, "--file-format=WAVE", "--data-format=LEI16@16000", "-o", audio.path, spoken]
            try? p.run()
            p.waitUntilExit()

            let base = recognize(audio, locale: c.locale, lm: nil)
            var cfg: SFSpeechLanguageModel.Configuration?
            let s2 = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                ScriptLanguageModel.prepare(script: c.text, localeID: c.locale) { conf, _ in cfg = conf; s2.signal() }
            }
            // prepare 的回调在主线程：这里让主线程跑一下 runloop 等它
            while s2.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            let withLM = cfg.map { recognize(audio, locale: c.locale, lm: $0) } ?? "(专属模型准备失败)"

            let ref = ParsedScript.parse(spoken, markup: false, keys: false, chineseNumbers: c.locale.hasPrefix("zh")).units.map(\.text)
            func cer(_ hyp: String) -> Double {
                let h = ParsedScript.parse(hyp, markup: false, keys: false, chineseNumbers: c.locale.hasPrefix("zh")).units.map(\.text)
                return Double(editDistance(ref, h)) / Double(max(1, ref.count))
            }
            let terms = ScriptLanguageModel.latinTerms(c.text).filter { !$0.contains(" ") || c.locale.hasPrefix("en") }
            func termRate(_ hyp: String) -> Double {
                guard !terms.isEmpty else { return 1 }
                let low = hyp.lowercased().replacingOccurrences(of: " ", with: "")
                return Double(terms.filter { low.contains($0.lowercased().replacingOccurrences(of: " ", with: "")) }.count) / Double(terms.count)
            }
            let cb = cer(base), cl = cer(withLM), tb = termRate(base), tl = termRate(withLM)
            log(String(format: "%@ · %@：错字率 普通 %.1f%% → 专属模型 %.1f%%   术语识别 %.0f%% → %.0f%%",
                       c.name, String(c.voice.prefix(8)), cb * 100, cl * 100, tb * 100, tl * 100))
            log("    普通：" + String(base.prefix(70)))
            log("    专属：" + String(withLM.prefix(70)))
            var t = totals[c.locale] ?? (0, 0, 0, 0, 0)
            t.base += cb; t.lm += cl; t.termBase += tb; t.termLM += tl; t.n += 1
            totals[c.locale] = t
        }
        for (loc, t) in totals.sorted(by: { $0.key < $1.key }) {
            let n = Double(t.n)
            log(String(format: "== %@（%d 段）平均错字率 普通 %.1f%% → 专属模型 %.1f%% · 术语识别 %.0f%% → %.0f%%",
                       loc, t.n, t.base / n * 100, t.lm / n * 100, t.termBase / n * 100, t.termLM / n * 100))
        }
        try? report.write(to: out.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
    }

    private static func recognize(_ url: URL, locale: String, lm: SFSpeechLanguageModel.Configuration?) -> String {
        guard let r = SFSpeechRecognizer(locale: Locale(identifier: locale)) else { return "" }
        let req = SFSpeechURLRecognitionRequest(url: url)
        req.shouldReportPartialResults = false
        req.requiresOnDeviceRecognition = true
        req.addsPunctuation = false
        if let lm { req.customizedLanguageModel = lm }
        // 本机识别会把长音频按停顿分成几段分别给结果：每段结束（新结果不再是上一条的延续）就收起来
        var done: [String] = []
        var current = ""
        var finished = false
        var lastUpdate = Date()
        let task = r.recognitionTask(with: req) { result, error in
            if let result {
                let t = result.bestTranscription.formattedString
                if !current.isEmpty && !t.hasPrefix(String(current.prefix(max(1, current.count / 2)))) { done.append(current) }
                current = t
                if result.isFinal { done.append(current); current = "" }
                lastUpdate = Date()
            }
            if error != nil { finished = true }
        }
        let started = Date()
        var gotAny = false
        while !finished {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            if !done.isEmpty || !current.isEmpty { gotAny = true }
            if task.state == .completed { break }
            if gotAny && Date().timeIntervalSince(lastUpdate) > 8 { break }
            if !gotAny && Date().timeIntervalSince(started) > 120 { break }
        }
        if !current.isEmpty { done.append(current) }
        let text = done.joined(separator: " ")
        task.cancel()
        return text
    }

    private static func editDistance(_ a: [String], _ b: [String]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = prev
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}
