import AppKit

struct PrompterLine {
    let glyphs: Range<Int>
    let unitRange: Range<Int>
}

/// 自己做折行：保证每一行在灵动岛里正好一行，并且知道每个字落在哪一行（用来滚动）。
enum PrompterLayout {
    static let earRadius: CGFloat = 10

    static func font(_ size: Double) -> NSFont { .systemFont(ofSize: CGFloat(size), weight: .medium) }
    static func lineHeight(_ size: Double) -> CGFloat { (CGFloat(size) * 1.48).rounded() }

    static func layout(_ p: ParsedScript, fontSize: Double, maxWidth: CGFloat) -> [PrompterLine] {
        let font = font(fontSize)
        let limit = maxWidth * 0.97
        var cache: [Character: CGFloat] = [:]
        func width(_ c: Character) -> CGFloat {
            if let w = cache[c] { return w }
            let w = (String(c) as NSString).size(withAttributes: [.font: font]).width
            cache[c] = w
            return w
        }

        let g = p.glyphs
        var lines: [PrompterLine] = []
        var start = 0
        var lineW: CGFloat = 0

        func emit(_ end: Int) {
            defer { start = end; lineW = 0 }
            guard end > start else { return }
            var lo = Int.max, hi = -1, hasInk = false
            for i in start..<end {
                if !g[i].char.isWhitespace { hasInk = true }
                if g[i].isUnit { lo = min(lo, g[i].unit); hi = max(hi, g[i].unit) }
            }
            guard hasInk else { return }
            let units: Range<Int>
            if hi >= 0 {
                units = lo..<(hi + 1)
            } else {
                let u = g[end - 1].unit + 1
                units = u..<u
            }
            lines.append(PrompterLine(glyphs: start..<end, unitRange: units))
        }

        var i = 0
        while i < g.count {
            let c = g[i].char
            if c.isNewline {
                emit(i)
                start = i + 1
                i += 1
                continue
            }
            if lineW == 0 && c.isWhitespace {
                start = i + 1
                i += 1
                continue
            }
            var j = i + 1
            if ScriptChar.isLatinWord(c) {
                while j < g.count {
                    if ScriptChar.isLatinWord(g[j].char) { j += 1; continue }
                    // 数字里的小数点 / 千分位（6.9、f/1.48、10,999）不拆开
                    if j + 1 < g.count, ".,/".contains(g[j].char), g[j - 1].char.isNumber || g[j + 1].char.isNumber,
                       ScriptChar.isLatinWord(g[j + 1].char) { j += 2; continue }
                    break
                }
            }
            var w: CGFloat = 0
            for k in i..<j { w += width(g[k].char) }
            if lineW > 0 && lineW + w > limit && !ScriptChar.isClosingPunct(c) {
                // 避免段尾只剩一两个字孤零零一行：改在本行靠后的逗号处断开
                if let k = phraseBreak(g, start: start, at: i) ?? balancedBreak(g, start: start, at: i, width: width, fontSize: CGFloat(fontSize)) {
                    emit(k)
                    i = k
                    continue
                }
                emit(i)
                if c.isWhitespace {
                    start = i + 1
                    i += 1
                    continue
                }
            }
            lineW += w
            i = j
        }
        emit(g.count)
        return lines
    }

    private static let softBreaks: Set<Character> = ["，", "、", "；", "：", ",", ";", ":"]

    /// 按意群断行：本行后 40% 里有逗号 / 句号，就在那里换行，不把一个词拆到两行
    private static func phraseBreak(_ g: [Glyph], start: Int, at i: Int) -> Int? {
        let minK = start + Int(Double(i - start) * 0.6)
        var k = i - 1
        while k > minK {
            let c = g[k].char
            if softBreaks.contains(c) || ScriptChar.isSentenceEnd(c) { return k + 1 }
            k -= 1
        }
        return nil
    }

    private static func balancedBreak(_ g: [Glyph], start: Int, at i: Int, width: (Character) -> CGFloat, fontSize: CGFloat) -> Int? {
        var rest: CGFloat = 0
        var j = i
        while j < g.count && !g[j].char.isNewline {
            rest += width(g[j].char)
            if rest > fontSize * 3.5 { return nil }
            j += 1
        }
        let minK = start + (i - start) / 3
        var k = i - 1
        while k > minK {
            if softBreaks.contains(g[k].char) { return k + 1 }
            k -= 1
        }
        return nil
    }
}
