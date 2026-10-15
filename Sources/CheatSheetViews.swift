import SwiftUI

// 提词时的两个小东西：第一次用时的操作提示气泡、右上角的“小抄”（整篇稿子）

// MARK: - 操作提示

/// 第一次看到提词卡片时，旁边告诉用户可以拖、可以调大小、可以双击。做过的那条打勾，点“知道了”就不再出现
struct CardTip: View {
    @ObservedObject var settings: PrompterSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.ink)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.highlighter))
                Text("提词卡片可以随手调").font(.system(size: 13.5, weight: .bold)).foregroundColor(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 7) {
                row("arrow.up.and.down.and.arrow.left.and.right", "拖中间：移动位置", "靠近中线会吸附", done: settings.didMoveCard)
                row("arrow.up.left.and.arrow.down.right", "拖四个角：调大小", "每行字数 · 行数", done: settings.didResizeCard)
                row("cursorarrow.click.2", "双击：回到默认", "位置和大小", done: settings.didResetCard)
            }
            .padding(.vertical, 11)
            HStack {
                Text("只提示这一次").font(.system(size: 11)).foregroundColor(Theme.ink3)
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { settings.tipsDismissed = true } } label: {
                    Text("知道了").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.primaryText)
                        .padding(.horizontal, 14).frame(height: 24)
                        .background(Capsule().fill(Theme.primaryFill))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.sheet))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(0.08)))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ icon: String, _ title: String, _ hint: String, done: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: done ? "checkmark" : icon)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(done ? Theme.greenInk : Theme.ink)
                .frame(width: 26, height: 20)
                .background(RoundedRectangle(cornerRadius: 6).fill(done ? Theme.greenInk.opacity(0.12) : Theme.wash))
            Text(title).font(.system(size: 12.5)).foregroundColor(done ? Theme.ink3 : Theme.ink)
            Spacer(minLength: 4)
            Text(done ? "做过了" : hint).font(.system(size: 10.5)).foregroundColor(Theme.ink3)
        }
        .animation(.easeOut(duration: 0.2), value: done)
    }
}

// MARK: - 小抄

/// 小抄里的标题行：编号 + 标题 + 快捷键；正在讲的这段编号是黑底
struct CheatHeadingRow: View {
    let heading: ScriptHeading
    let number: Int?
    let current: Bool
    let read: Bool

    var body: some View {
        HStack(spacing: 7) {
            if let number {
                Text("\(number)").font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(current ? .white : Theme.ink2)
                    .frame(width: 19, height: 19)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(current ? Theme.ink : Color.black.opacity(0.08)))
            }
            Text(heading.title)
                .font(.system(size: heading.level <= 1 ? 14 : 13, weight: .heavy))
                .foregroundColor(read ? Theme.ink3 : Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let number, number <= 9 {
                Text("⌥⌘\(number)").font(.system(size: 10.5, weight: .semibold)).foregroundColor(Theme.ink3)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

/// 稿子的一段（按换行分）：点一下跳到这一段开头
struct CheatParagraph: Identifiable {
    let id: Int
    let glyphs: Range<Int>
    let firstUnit: Int?
    let lastUnit: Int
    /// 这一段是 # 标题：点一下跳到标题后面第一个字
    var heading: ScriptHeading? = nil
    /// 第几段（分段那一级标题才有，从 1 开始）
    var number: Int? = nil

    static func split(_ p: ParsedScript) -> [CheatParagraph] {
        var out: [CheatParagraph] = []
        var start = 0
        func close(_ end: Int) {
            defer { start = end + 1 }
            guard start < end else { return }
            let r = start..<end
            guard p.glyphs[r].contains(where: { !$0.char.isWhitespace }) else { return }
            let units = p.glyphs[r].filter(\.isUnit).map(\.unit)
            var para = CheatParagraph(id: out.count, glyphs: r, firstUnit: units.first, lastUnit: units.last ?? (out.last?.lastUnit ?? -1))
            if let g = r.first(where: { !p.glyphs[$0].char.isWhitespace }), p.glyphs[g].style == .heading,
               let h = p.headings.first(where: { $0.glyphs.contains(g) }) {
                para.heading = h
                if h.level == p.sectionLevel { para.number = p.sections.firstIndex(of: h).map { $0 + 1 } }
            }
            out.append(para)
        }
        for (i, g) in p.glyphs.enumerated() where g.char.isNewline { close(i) }
        close(p.glyphs.count)
        return out
    }

    /// 读过的灰、正在读的字用荧光笔标出来、没读的黑字；【导演提示】是橙色
    func text(_ p: ParsedScript, cursor: Int) -> Text {
        var out = AttributedString()
        var buf = ""
        var role = -1
        func flush() {
            guard !buf.isEmpty else { return }
            var a = AttributedString(buf)
            switch role {
            case 0: a.foregroundColor = Theme.ink3
            case 1: a.foregroundColor = .black; a.backgroundColor = Theme.highlighter
            case 2: a.foregroundColor = Theme.cueInk.opacity(0.45)
            case 3: a.foregroundColor = Theme.cueInk
            default: a.foregroundColor = Theme.ink
            }
            out += a
            buf = ""
        }
        for gi in glyphs {
            let g = p.glyphs[gi]
            let read = g.unit >= 0 && g.unit < cursor
            let r: Int
            if g.style == .cue { r = read ? 2 : 3 }
            else if read { r = 0 }
            else if g.isUnit && g.unit == cursor { r = 1 }
            else { r = 4 }
            if r != role { flush(); role = r }
            buf.append(g.char)
        }
        flush()
        return Text(out)
    }
}

/// 提词时屏幕右上角的整篇稿子：跟着讲到哪滚到哪，点一段就跳过去。和提词卡片一样，共享屏幕时对方看不到
/// 拖动小抄：按住顶部拖，松手记住位置（每块屏幕各记各的）；双击顶部回到右上角
struct CheatMove {
    let model: IslandModel
    let settings: PrompterSettings
    let frame: CGRect

    func gesture(start: Binding<CGPoint?>) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { v in
                if start.wrappedValue == nil { start.wrappedValue = frame.origin }
                guard let s = start.wrappedValue else { return }
                model.cheatDragPos = CGPoint(x: s.x + v.translation.width, y: s.y + v.translation.height)
            }
            .onEnded { _ in
                if let p = model.cheatDragPos {
                    let c = IslandMetrics.cheatFrame(panel: model.panelSize, notch: model.notch, origin: p)
                    settings.setCheatPosition(c.origin, for: model.screenKey)
                    settings.cheatTipDismissed = true
                }
                model.cheatDragPos = nil
                start.wrappedValue = nil
            }
    }

    func reset() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { settings.setCheatPosition(nil, for: model.screenKey) }
        settings.cheatTipDismissed = true
    }
}

struct CheatSheet: View {
    @ObservedObject var engine: PrompterEngine
    let move: CheatMove
    let close: () -> Void
    @State private var dragStart: CGPoint?

    var body: some View {
        let parsed = engine.parsed
        let paras = CheatParagraph.split(parsed)
        let cur = Int(engine.cursor)
        let curPara = paras.first(where: { ($0.firstUnit ?? Int.max) <= cur && cur <= $0.lastUnit })?.id
            ?? paras.last(where: { ($0.firstUnit ?? Int.max) <= cur })?.id ?? 0
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let curSection = parsed.section(at: cur).map { $0 + 1 }

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                // 六个小点：告诉用户这里可以抓住拖动
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.black.opacity(0.25)).frame(width: 3, height: 3) } }
                    GridRow { ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.black.opacity(0.25)).frame(width: 3, height: 3) } }
                }
                Text("小抄").font(.system(size: 13, weight: .bold))
                Text(engine.title).font(.system(size: 11.5)).foregroundColor(Theme.ink3).lineLimit(1)
                Spacer(minLength: 4)
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(Theme.ink2)
                        .frame(width: 20, height: 20).background(Circle().fill(Theme.wash))
                }
                .buttonStyle(PressStyle())
            }
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { move.reset() }
            .gesture(move.gesture(start: $dragStart))
            .help("按住拖动 · 双击回到右上角")

            let fade = LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                                              .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                                      startPoint: .top, endPoint: .bottom)
            if move.model.snapshot {
                // 离屏渲染画不出滚动视图：从当前这段往前几段开始直接排出来
                Color.clear
                    .overlay(alignment: .top) {
                        rows(Array(paras.dropFirst(max(0, curPara - 3))), parsed: parsed, cur: cur, curPara: curPara, curSection: curSection)
                    }
                    .clipped()
                    .mask(fade)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        rows(paras, parsed: parsed, cur: cur, curPara: curPara, curSection: curSection)
                    }
                    .mask(fade)
                    .onAppear { proxy.scrollTo(curPara, anchor: .center) }
                    .onChange(of: curPara) { _, n in withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(n, anchor: .center) } }
                }
            }

            HStack {
                Text(parsed.sections.isEmpty ? "点一段跳过去" : "点标题或段落跳过去").font(.system(size: 10.5))
                Spacer()
                Text("⌥⌘O 收起").font(.system(size: 10.5))
            }
            .foregroundColor(Theme.ink3)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .padding(.top, 2)
        }
        .background(Group {
            if move.model.snapshot { Theme.paper.opacity(0.9) }
            else { VisualEffectBlur(dark: false, opacity: Theme.glassFrost).overlay(Theme.paper.opacity(Theme.cheatVeil)) }
        }.clipShape(shape))
        .overlay(GlassSheen(shape: shape).allowsHitTesting(false))
        .shadow(color: .black.opacity(move.model.cheatDragPos != nil ? 0.32 : 0.22), radius: move.model.cheatDragPos != nil ? 32 : 24, y: 12)
        .environment(\.colorScheme, .light)
    }
}

extension CheatSheet {
    @ViewBuilder
    func rows(_ paras: [CheatParagraph], parsed: ParsedScript, cur: Int, curPara: Int, curSection: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(paras) { p in
                if let h = p.heading {
                    CheatHeadingRow(heading: h, number: p.number, current: p.number != nil && p.number == curSection,
                                    read: p.number.map { $0 < (curSection ?? 0) } ?? false)
                        .contentShape(Rectangle())
                        .onTapGesture { engine.jump(toUnit: h.nextUnit) }
                        .help("跳到这一段")
                        .id(p.id)
                } else {
                    p.text(parsed, cursor: cur)
                        .font(.system(size: 13.5))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(p.id == curPara ? Color.white.opacity(0.6) : .clear))
                        .contentShape(Rectangle())
                        .onTapGesture { if let u = p.firstUnit { engine.jump(toUnit: u) } }
                        .help("跳到这一段")
                        .id(p.id)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

/// 第一次打开小抄时：告诉用户可以拖、可以双击回去
struct CheatTip: View {
    @ObservedObject var settings: PrompterSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.ink)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.highlighter))
                Text("小抄可以拖到任何地方").font(.system(size: 13, weight: .bold)).foregroundColor(Theme.ink)
            }
            Text("按住顶部拖动；双击顶部回到右上角。每块屏幕各记各的位置。")
                .font(.system(size: 12)).foregroundColor(Theme.ink2).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button { withAnimation(.easeOut(duration: 0.2)) { settings.cheatTipDismissed = true } } label: {
                    Text("知道了").font(.system(size: 11.5, weight: .bold)).foregroundColor(Theme.primaryText)
                        .padding(.horizontal, 12).frame(height: 22)
                        .background(Capsule().fill(Theme.primaryFill))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.sheet))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(0.08)))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .fixedSize(horizontal: false, vertical: true)
    }
}
