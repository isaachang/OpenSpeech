import SwiftUI

/// 面板里的悬停：面板不是普通窗口，SwiftUI 的 onHover 收不到，
/// 由 IslandController.pollMouse 把鼠标位置放进 model.mouse，这里看它落没落在自己身上
struct PanelHover<Content: View>: View {
    let mouse: CGPoint?
    @ViewBuilder let content: (Bool) -> Content
    @State private var frame: CGRect = .zero

    var body: some View {
        content(mouse.map { frame.contains($0) } ?? false)
            .background(GeometryReader { g in
                let f = g.frame(in: .named(IslandRootView.space))
                Color.clear.onAppear { frame = f }.onChange(of: f) { frame = $0 }
            })
    }
}

/// 卡片顶上：“2 / 5 · 段名”。平时淡淡显示；鼠标移到卡片上出现 ‹ ›，点段名弹出所有段落
struct SectionNav: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var model: IslandModel
    let expanded: Bool
    let maxWidth: CGFloat

    var body: some View {
        let secs = engine.parsed.sections
        let cur = engine.currentSection
        HStack(spacing: 6) {
            if expanded {
                arrow("chevron.left", enabled: (cur ?? 0) > 0, tip: tr("上一段  ⌥⌘←", "Previous section  ⌥⌘←")) { engine.stepSection(-1) }
            }
            PanelHover(mouse: model.mouse) { hover in
                Button { model.sectionMenuOpen.toggle() } label: {
                    HStack(spacing: 5) {
                        if let cur {
                            Text("\(cur + 1) / \(secs.count)").foregroundColor(Theme.ink.opacity(expanded ? 0.45 : 0.32)).monospacedDigit()
                            Text(secs[cur].title).lineLimit(1)
                        } else {
                            Text(tr("开场 · 共 \(secs.count) 段", "Intro · \(secs.count) sections")).lineLimit(1)
                        }
                        if expanded {
                            Image(systemName: "chevron.down").font(.system(size: 7.5, weight: .bold))
                                .rotationEffect(.degrees(model.sectionMenuOpen ? 180 : 0))
                        }
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Theme.ink.opacity(expanded ? 0.78 : 0.42))
                    .padding(.horizontal, expanded ? 9 : 0)
                    .frame(height: 20)
                    .background(Capsule().fill(Color.black.opacity(!expanded ? 0 : (hover || model.sectionMenuOpen) ? 0.12 : 0.05)))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
            }
            if expanded {
                arrow("chevron.right", enabled: (cur ?? -1) + 1 < secs.count, tip: tr("下一段  ⌥⌘→", "Next section  ⌥⌘→")) { engine.stepSection(1) }
            }
        }
        .frame(maxWidth: maxWidth)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeOut(duration: 0.12), value: model.mouse)
    }

    private func arrow(_ icon: String, enabled: Bool, tip: String, action: @escaping () -> Void) -> some View {
        PanelHover(mouse: model.mouse) { hover in
            Button(action: action) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.ink.opacity(enabled ? 0.8 : 0.25))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(enabled && hover ? 0.14 : 0.06)))
                    .scaleEffect(enabled && hover ? 1.08 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .disabled(!enabled)
            .overlay(alignment: .top) {
                if hover && enabled {
                    Text(tip).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 9).frame(height: 22)
                        .background(Capsule().fill(Color.black.opacity(0.78)))
                        .fixedSize()
                        .offset(y: -28)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

/// 点段名弹出的段落列表：点哪段跳哪段
struct SectionMenu: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var model: IslandModel

    var body: some View {
        let secs = engine.parsed.sections
        let cur = engine.currentSection
        let rows = VStack(spacing: 0) {
            ForEach(Array(secs.enumerated()), id: \.offset) { i, s in
                PanelHover(mouse: model.mouse) { hover in
                    Button {
                        engine.jump(toSection: i)
                        model.sectionMenuOpen = false
                    } label: {
                        HStack(spacing: 9) {
                            Text("\(i + 1)").font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(i == cur ? .white : Theme.ink2)
                                .frame(width: 18, height: 18)
                                .background(RoundedRectangle(cornerRadius: 5).fill(i == cur ? Theme.ink : Theme.buttonFill))
                            Text(s.title).font(.system(size: 12.5, weight: i == cur ? .semibold : .regular))
                                .foregroundColor(Theme.ink).lineLimit(1)
                            Spacer(minLength: 6)
                            if i < 9 { Text("⌥⌘\(i + 1)").font(.system(size: 11)).foregroundColor(Theme.ink3) }
                        }
                        .padding(.horizontal, 9)
                        .frame(height: IslandMetrics.sectionRowHeight)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(hover ? 0.07 : i == cur ? 0.04 : 0)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        Group {
            if secs.count > 10 { ScrollView(showsIndicators: false) { rows } } else { rows }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.sheet))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        .animation(.easeOut(duration: 0.1), value: model.mouse)
    }
}
