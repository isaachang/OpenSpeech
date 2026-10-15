import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// `OpenSpeech --video-readme <dir>`：README 里的两段演示动画，逐帧渲染成 PNG（再用 ffmpeg 合成视频）。
/// 用的是真实的提词卡片，只是“读到哪”按写好的时间线走：
///   eye/     01 看稿就是看镜头：摄像头 → 5° → 卡片，按正常语速读完“OpenSpeech 是什么”
///   follow/  02 讲快讲慢都跟得上：跨过标题 → 讲快 → 讲慢 → 停下 → 脱稿，下面的胶囊说明这一刻在发生什么
enum ReadmeVideo {
    static let fps = 30.0

    /// 胶囊里显示的“这一刻”
    enum Moment {
        case normal, heading, fast, slow, pause, offScript
        var said: String {
            switch self {
            case .normal: return tr("正常讲", "Normal pace")
            case .heading: return tr("遇到标题", "A heading")
            case .fast: return tr("讲快了", "Talk faster")
            case .slow: return tr("讲慢了", "Slow down")
            case .pause: return tr("停下来", "Pause")
            case .offScript: return tr("脱稿说两句", "Go off script")
            }
        }
        var result: String {
            switch self {
            case .normal: return tr("它稳稳跟着", "it keeps pace")
            case .heading: return tr("不用念，直接跨过", "skipped, never read aloud")
            case .fast: return tr("它也跟着快", "it keeps up")
            case .slow: return tr("它也慢下来", "it slows down")
            case .pause: return tr("它停下等你", "it waits for you")
            case .offScript: return tr("它停在原地", "it holds still")
            }
        }
        var speaking: Bool { self != .pause }
    }

    /// 时间线的一段：从 from 读到 to（单位：字 / 词），用时 duration 秒
    struct Segment {
        var start: Double
        var duration: Double
        var from: Double
        var to: Double
        var moment: Moment
    }

    struct Timeline {
        let units: [SpeechUnit]
        var segments: [Segment] = []
        var pos: Double
        var t = 0.0

        init(units: [SpeechUnit], start: String) {
            self.units = units
            pos = 0
            pos = Double(find(start).lowerBound)
        }

        /// 从当前位置往后找这段文字（中文按字、英文按词）
        func find(_ text: String) -> Range<Int> {
            let tokens = Self.tokens(text)
            var i = Int(pos)
            while i + tokens.count <= units.count {
                if zip(tokens, units[i..<(i + tokens.count)]).allSatisfy({ $0.0 == $0.1.text }) { return i..<(i + tokens.count) }
                i += 1
            }
            fatalError("ReadmeVideo: 找不到 “\(text)”")
        }

        /// 和稿子的切分一样：英文单词一个、汉字一个字一个，标点不算
        static func tokens(_ text: String) -> [String] {
            var out: [String] = [], word = ""
            for ch in text {
                if !ScriptChar.isCJK(ch) && (ch.isLetter || ch.isNumber || ((ch == "'" || ch == "’") && !word.isEmpty)) { word.append(ch); continue }
                if !word.isEmpty { out.append(word.lowercased()); word = "" }
                if ScriptChar.isCJK(ch) { out.append(String(ch)) }
            }
            if !word.isEmpty { out.append(word.lowercased()) }
            return out
        }

        /// 按每秒 rate 个字 / 词读到这段文字的结尾
        mutating func read(_ text: String, rate: Double, _ m: Moment) {
            let end = Double(find(text).upperBound)
            let d = (end - pos) / rate
            segments.append(Segment(start: t, duration: d, from: pos, to: end, moment: m))
            t += d
            pos = end
        }

        mutating func hold(_ seconds: Double, _ m: Moment) {
            segments.append(Segment(start: t, duration: seconds, from: pos, to: pos, moment: m))
            t += seconds
        }

        func at(_ time: Double) -> (cursor: Double, seg: Segment) {
            let s = segments.last { $0.start <= time } ?? segments[0]
            let f = s.duration > 0 ? min(1, (time - s.start) / s.duration) : 1
            return (s.from + (s.to - s.from) * f, s)
        }
    }

    @MainActor
    static func run(dir: String) {
        let zh = Lang.isChinese
        let pitch = zh ? Script(title: "OpenSpeech 一分钟介绍", body: SampleScripts.pitch)
                       : Script(title: "OpenSpeech in One Minute", body: SampleScripts.pitchEnglish)
        let units = ParsedScript.parse(pitch.body).units
        // 正常 / 快 / 慢的语速（中文：字每秒，英文：词每秒）
        let normal = zh ? 4.2 : 2.6, fast = zh ? 7.5 : 4.2, slow = zh ? 2.0 : 1.3

        var eye = Timeline(units: units, start: zh ? "OpenSpeech 是一个" : "OpenSpeech is a teleprompter")
        eye.hold(0.8, .normal)
        eye.read(zh ? "OpenSpeech 是一个住在 Mac 刘海里的提词器" : "OpenSpeech is a teleprompter that lives in your Mac's notch", rate: normal, .normal)
        eye.hold(0.35, .normal)
        eye.read(zh ? "稿子就贴在摄像头正下方你看稿的时候眼神就在看镜头" : "Your script sits right below the camera so reading looks like eye contact", rate: normal, .normal)
        eye.hold(1.6, .normal)

        var follow = Timeline(units: units, start: zh ? "眼神就在看镜头" : "so reading looks like")
        follow.hold(0.6, .normal)
        follow.read(zh ? "眼神就在看镜头" : "so reading looks like eye contact", rate: normal, .normal)
        follow.hold(0.3, .heading)
        follow.read(zh ? "它会听你说话" : "It listens as you speak", rate: normal, .heading)
        follow.hold(0.2, .fast)
        follow.read(zh ? "你讲快它就快" : "Talk faster and it keeps up", rate: fast, .fast)
        follow.read(zh ? "你停下它就等你" : "pause and it waits", rate: slow, .slow)
        follow.hold(1.8, .pause)
        follow.read(zh ? "即兴发挥也不怕" : "Go off script and it", rate: normal, .normal)
        follow.hold(2.2, .offScript)
        follow.read(zh ? "它不会乱跳等你回到稿子再接着走" : "holds still until you come back", rate: normal, .normal)
        follow.hold(1.4, .normal)

        render(eye, name: "eye", dir: dir, script: pitch, size: CGSize(width: 1000, height: 560), camera: true, annotate: true, pill: false)
        render(follow, name: "follow", dir: dir, script: pitch, size: CGSize(width: 1000, height: 560), camera: true, annotate: false, pill: true)
    }

    @MainActor
    static func render(_ tl: Timeline, name: String, dir: String, script: Script, size: CGSize, camera: Bool, annotate: Bool, pill: Bool) {
        let out = URL(fileURLWithPath: dir).appendingPathComponent(name)
        try? FileManager.default.removeItem(at: out)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let suite = "app.openspeech.readme-video"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = PrompterSettings(defaults: defaults)
        settings.displayStyle = .glass
        settings.cheatSheet = false
        settings.tipsDismissed = true
        settings.cheatTipDismissed = true
        let engine = PrompterEngine(settings: settings)
        engine.audioDisabled = true
        let first = tl.at(0)
        engine.debugPresent(script: script, cursor: first.cursor, phase: .presenting, mode: .voice)
        let model = IslandModel()
        model.notch = NotchInfo(width: 220, height: 38, hasNotch: true)
        model.geo = ScreenGeo(mmPerPt: 0.168, cameraY: 19)
        model.panelSize = size
        model.snapshot = true
        model.hideIsland = true
        settings.readmeZoom(model: model)
        let card = IslandMetrics.layout(engine: engine, model: model, settings: settings).card ?? .zero
        let store = ScriptStore(inMemory: true)
        let actions = IslandActions(start: {}, openLibrary: {}, importURLs: { _ in }, cycleScript: { _ in }, resetPosition: {})

        let frames = Int((tl.t * fps).rounded(.up))
        for f in 0..<frames {
            let time = Double(f) / fps
            let (c, seg) = tl.at(time)
            let m = seg.moment
            // 说话时的音量条：几条错开的正弦，讲快时更“满”
            let amp: CGFloat = m.speaking ? (m == .fast ? 1 : m == .slow ? 0.6 : 0.8) : 0
            let levels: [CGFloat] = (0..<5).map { i in
                let w = sin(time * (9 + Double(i) * 2.3) + Double(i) * 1.7) * 0.5 + 0.5
                return m.speaking ? max(0.12, amp * CGFloat(0.35 + 0.65 * w)) : 0.04
            }
            engine.debugFrame(cursor: c, dt: 1 / fps, speaking: m.speaking, levels: levels, speed: nil)
            let fade = min(1, (time - seg.start) / 0.25)
            let view = ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hex: 0x3C3F8F), Color(hex: 0x6A4E8E), Color(hex: 0xB9787E), Color(hex: 0xD99A7C)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if camera { CameraGuide(notch: model.notch, cameraY: model.geo.cameraY, card: card, width: size.width, annotate: annotate) }
                IslandRootView(model: model, engine: engine, store: store, settings: settings, actions: actions, acceptsDrop: false)
                if pill {
                    MomentPill(moment: m, levels: levels, speed: speed(m), fade: fade)
                        .frame(width: size.width)
                        .offset(y: card.maxY + 20)
                }
            }
            .frame(width: size.width, height: size.height)
            let r = ImageRenderer(content: view)
            r.scale = 2
            guard let img = r.cgImage,
                  let dest = CGImageDestinationCreateWithURL(out.appendingPathComponent(String(format: "%04d.png", f)) as CFURL,
                                                             UTType.png.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, img, nil)
            CGImageDestinationFinalize(dest)
        }
        print("✓ \(name)：\(frames) 帧，\(String(format: "%.1f", tl.t)) 秒")
    }

    /// 胶囊右边的语速
    static func speed(_ m: Moment) -> String {
        let zh = Lang.isChinese
        switch m {
        case .fast: return zh ? "450 字/分" : "250 wpm"
        case .slow: return zh ? "120 字/分" : "80 wpm"
        case .pause, .offScript: return "—"
        default: return zh ? "250 字/分" : "155 wpm"
        }
    }
}

extension PrompterSettings {
    /// README 的图比整块屏幕窄（相当于放大看）：卡片和刘海按原尺寸画，
    /// 卡片离刘海的距离按画面宽度等比例缩短，看起来和在整块屏幕上一样贴着镜头
    func readmeZoom(model: IslandModel, screenWidth: CGFloat = 1800) {
        let read = IslandMetrics.cardSize(self).readOffset
        let realTop = IslandMetrics.defaultPosition(model.geo).readY - read
        let gap = (realTop - model.notch.height) * model.panelSize.width / screenWidth
        setPosition(CardPosition(dx: 0, readY: model.notch.height + gap + read), for: model.screenKey)
    }
}

/// 屏幕顶上的硬件刘海，里面淡淡一颗摄像头，旁边标注 “摄像头”；
/// annotate 时再画出视线和 “≈ 5°”：卡片正在读的那一行就在镜头下面约 5°。
struct CameraGuide: View {
    let notch: NotchInfo
    let cameraY: CGFloat
    let card: CGRect
    let width: CGFloat
    var annotate = true
    var labeled = true

    var body: some View {
        let x = width / 2
        ZStack(alignment: .topLeading) {
            NotchShape(topRadius: 6, bottomRadius: 11)
                .fill(Color.black)
                .frame(width: notch.width + 12, height: notch.height)
                .position(x: x, y: notch.height / 2)
            // 镜头：只看得出一点点
            Circle().fill(Color(hex: 0x15171F)).frame(width: 9, height: 9)
                .overlay(Circle().fill(Color(hex: 0x2A3350)).frame(width: 4, height: 4))
                .overlay(Circle().fill(.white.opacity(0.35)).frame(width: 1.6, height: 1.6).offset(x: -1.4, y: -1.4))
                .position(x: x, y: cameraY)
            // 标注：从镜头拉一条细线到刘海右边
            if labeled { label(x) }
            if annotate {
                Path { p in
                    p.move(to: CGPoint(x: x, y: notch.height + 6))
                    p.addLine(to: CGPoint(x: x, y: card.minY - 6))
                }
                .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                Text(tr("≈ 5°，看稿就像在看镜头", "≈ 5° — reading looks like eye contact"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize()
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.16)))
                    .position(x: x, y: (notch.height + card.minY) / 2 + 2)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    @ViewBuilder private func label(_ x: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: x + 8, y: cameraY))
            p.addLine(to: CGPoint(x: x + notch.width / 2 + 30, y: cameraY))
        }
        .stroke(.white.opacity(0.55), lineWidth: 1)
        Circle().fill(.white.opacity(0.8)).frame(width: 4, height: 4).position(x: x + 8, y: cameraY)
        Text(tr("摄像头", "Camera"))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.92))
            .fixedSize()
            .frame(width: 120, alignment: .leading)
            .position(x: x + notch.width / 2 + 36 + 60, y: cameraY)
    }
}

/// 02：卡片下面的胶囊——“你在做什么 → 它怎么跟”
private struct MomentPill: View {
    let moment: ReadmeVideo.Moment
    let levels: [CGFloat]
    let speed: String
    let fade: Double

    var body: some View {
        HStack(spacing: 13) {
            HStack(alignment: .center, spacing: 3) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(moment.speaking ? Theme.ink : Theme.ink3.opacity(0.5))
                        .frame(width: 3.5, height: 3.5 + 16 * levels[i])
                }
            }
            .frame(width: 28, height: 20)
            HStack(spacing: 9) {
                Text(moment.said).foregroundColor(Theme.ink)
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.ink3)
                Text(moment.result).foregroundColor(Theme.ink2)
            }
            .font(.system(size: 17, weight: .semibold))
            .opacity(fade)
            Rectangle().fill(Theme.ink3.opacity(0.35)).frame(width: 1, height: 18)
            Text(speed)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Theme.ink2)
                .frame(minWidth: 74)
                .opacity(fade)
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(Capsule().fill(Color.white.opacity(0.9)))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 7)
    }
}
