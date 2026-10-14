import Foundation
import NaturalLanguage
import Speech

/// 把稿子“喂给”识别器：用这篇稿子生成本机识别器的专属语言模型（macOS 14+ 官方能力），
/// 让识别器更倾向于听出稿子里的词，尤其是专有名词、中英混排（GitHub、Claude Code…）。
/// 同时生成识别提示词（contextualStrings）作为补充。
enum ScriptLanguageModel {
    static let directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OpenPitch/lm", isDirectory: true)

    /// 准备好后回调（主线程）：成功给出配置；失败给出原因（识别仍可正常进行，只是没有专属模型）
    static func prepare(script: String, localeID: String,
                        completion: @escaping (SFSpeechLanguageModel.Configuration?, String) -> Void) {
        let phrases = trainingPhrases(script: script, localeID: localeID)
        guard !phrases.isEmpty else {
            completion(nil, "稿子太短")
            return
        }
        var hasher = Hasher()
        hasher.combine(localeID)
        for p in phrases { hasher.combine(p.phrase); hasher.combine(p.count) }
        let tag = String(UInt(bitPattern: hasher.finalize()), radix: 36)
        let dir = directory.appendingPathComponent(tag, isDirectory: true)
        let asset = dir.appendingPathComponent("data.bin")
        let model = dir.appendingPathComponent("lm")
        let config = SFSpeechLanguageModel.Configuration(languageModel: model)
        let t0 = Date()

        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: asset.path) {
                    let data = SFCustomLanguageModelData(locale: Locale(identifier: localeID),
                                                         identifier: "app.openpitch.script", version: tag)
                    for p in phrases { data.insert(phraseCount: p) }
                    try await data.export(to: asset)
                }
            } catch {
                await MainActor.run { completion(nil, "生成失败：\(error.localizedDescription)") }
                return
            }
            SFSpeechLanguageModel.prepareCustomLanguageModel(for: asset, clientIdentifier: "app.openpitch.mac",
                                                             configuration: config) { err in
                let secs = String(format: "%.1fs", Date().timeIntervalSince(t0))
                DispatchQueue.main.async {
                    if let err {
                        completion(nil, "准备失败：\(err.localizedDescription)")
                    } else {
                        completion(config, "ready \(secs) · \(phrases.count) phrases")
                    }
                }
            }
            prune(keeping: tag)
        }
    }

    /// 训练用的句子：整句 + 按标点切开的短句 + 英文术语。
    /// 次数（count）表示“这句话有多常见”，越高识别器越倾向于听成它
    static func trainingPhrases(script: String, localeID: String) -> [SFCustomLanguageModelData.PhraseCount] {
        let zh = localeID.hasPrefix("zh")
        // 去掉 ** 标记；【】里的提示词保留成单独的短句（有人会念出来）
        let text = script.replacingOccurrences(of: "**", with: "")
        var out: [String: Int] = [:]
        func add(_ s: String, _ n: Int) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "【】[]")))
            guard t.count >= 2, t.count <= 120 else { return }
            out[t] = max(out[t] ?? 0, n)
        }
        let sentenceEnds = CharacterSet(charactersIn: "。！？!?\n")
        let clauseEnds = CharacterSet(charactersIn: "。！？!?\n，、；：,;:“”\"（）()【】[]—…")
        for s in text.components(separatedBy: sentenceEnds) { add(s, 5) }
        for c in text.components(separatedBy: clauseEnds) { add(c, 10) }
        // 阿拉伯数字的短句再加一条中文读法（“60 帧” → “六十帧”）
        if zh {
            for c in text.components(separatedBy: clauseEnds) where c.contains(where: { $0.isNumber && $0.isASCII }) {
                let p = ParsedScript.parse(c, markup: false, keys: false, chineseNumbers: true)
                add(p.units.map(\.text).joined(), 5)
            }
        }
        for term in latinTerms(text) { add(term, 30) }
        return out.map { SFCustomLanguageModelData.PhraseCount(phrase: $0.key, count: $0.value) }
            .sorted { $0.phrase < $1.phrase }
    }

    /// 识别提示词：英文术语（中文稿里的中英混排）、稿子里不常见的词
    static func contextualStrings(script: String, localeID: String) -> [String] {
        var out: [String] = latinTerms(script)
        if localeID.hasPrefix("zh") {
            let tok = NLTokenizer(unit: .word)
            tok.string = script
            var freq: [String: Int] = [:]
            tok.enumerateTokens(in: script.startIndex..<script.endIndex) { r, _ in
                let w = String(script[r])
                if w.count >= 2 && w.count <= 5 && w.allSatisfy({ ScriptChar.isCJK($0) }) { freq[w, default: 0] += 1 }
                return true
            }
            out += freq.filter { $0.value <= 2 }.keys.sorted { $0.count > $1.count }
        }
        var seen = Set<String>()
        return Array(out.filter { seen.insert($0.lowercased()).inserted }.prefix(100))
    }

    /// 英文术语：中文稿里的英文词组（“Claude Code”“GitHub”）；英文稿里大写开头的专有名词（“Isaac”“Capstone”）
    static func latinTerms(_ text: String) -> [String] {
        let zh = text.contains { ScriptChar.isCJK($0) }
        var terms = Set<String>()
        var phrase: [String] = []
        var word = ""
        func endWord() {
            if !word.isEmpty { phrase.append(word) }
            word = ""
        }
        func endPhrase() {
            endWord()
            if zh {
                if !phrase.isEmpty { terms.insert(phrase.joined(separator: " ")) }
                for w in phrase where w.count >= 2 { terms.insert(w) }
            } else {
                var run: [String] = []
                for w in phrase + [""] {
                    if w.first?.isUppercase == true {
                        run.append(w)
                    } else {
                        if run.count > 1 || (run.count == 1 && run[0].count >= 3) { terms.insert(run.joined(separator: " ")) }
                        run = []
                    }
                }
            }
            phrase = []
        }
        for ch in text {
            if ch.isASCII && (ch.isLetter || ch.isNumber || ch == "'" || ch == "-") {
                word.append(ch)
            } else if ch == " " {
                endWord()
            } else {
                endPhrase()
            }
        }
        endPhrase()
        return terms.filter { $0.count >= 2 && !$0.allSatisfy(\.isNumber) }.sorted()
    }

    /// 只保留最近 10 篇稿子的模型
    private static func prune(keeping tag: String) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let sorted = dirs.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for d in sorted.dropFirst(10) where d.lastPathComponent != tag { try? fm.removeItem(at: d) }
    }
}
