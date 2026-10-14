import AppKit

/// 用代码画 App 图标（构建时导出成 .icns）
enum AppIcon {
    static func render(_ px: Int) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        draw(ctx.cgContext, CGFloat(px))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    static func draw(_ c: CGContext, _ s: CGFloat) {
        let rgb = CGColorSpaceCreateDeviceRGB()
        let inset = s * 0.1
        let r = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let rad = r.width * 0.225
        let body = CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)

        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.035, color: col(0, 0.45))
        c.addPath(body)
        c.setFillColor(col(0x0B0B14))
        c.fillPath()
        c.restoreGState()

        c.saveGState()
        c.addPath(body)
        c.clip()
        let bg = CGGradient(colorsSpace: rgb, colors: [col(0x2E2A78), col(0x15132E), col(0x07070C)] as CFArray,
                            locations: [0, 0.55, 1])!
        c.drawLinearGradient(bg, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        let glowCenter = CGPoint(x: r.midX, y: r.minY + r.height * 0.36)
        let glow = CGGradient(colorsSpace: rgb, colors: [col(0x818CF8, 0.45), col(0x818CF8, 0)] as CFArray, locations: [0, 1])!
        c.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: r.width * 0.55, options: [])

        // 灵动岛
        let pillW = r.width * 0.54, pillH = r.height * 0.15
        let pill = CGRect(x: r.midX - pillW / 2, y: r.maxY - r.height * 0.09 - pillH, width: pillW, height: pillH)
        c.addPath(CGPath(roundedRect: pill, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil))
        c.setFillColor(col(0x000000))
        c.fillPath()
        let d = pillH * 0.34
        c.setFillColor(col(0x4ADE80))
        c.fillEllipse(in: CGRect(x: pill.minX + pillH * 0.42, y: pill.midY - d / 2, width: d, height: d))
        let bars: [CGFloat] = [0.4, 0.75, 1, 0.55]
        let bw = pillH * 0.1
        for (k, h) in bars.enumerated() {
            let bh = pillH * 0.56 * h
            let x = pill.maxX - pillH * 0.5 - CGFloat(bars.count - k) * bw * 1.9
            c.addPath(CGPath(roundedRect: CGRect(x: x, y: pill.midY - bh / 2, width: bw, height: bh),
                             cornerWidth: bw / 2, cornerHeight: bw / 2, transform: nil))
            c.setFillColor(col(0x5EEAD4))
            c.fillPath()
        }

        // 三行提词
        let x0 = r.minX + r.width * 0.16
        func line(_ yFrac: CGFloat, _ wFrac: CGFloat, _ hFrac: CGFloat, _ color: CGColor?) {
            let h = r.height * hFrac
            let rect = CGRect(x: x0, y: r.minY + r.height * yFrac, width: r.width * wFrac, height: h)
            let path = CGPath(roundedRect: rect, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
            if let color {
                c.addPath(path)
                c.setFillColor(color)
                c.fillPath()
            } else {
                c.saveGState()
                c.addPath(path)
                c.clip()
                let g = CGGradient(colorsSpace: rgb, colors: [col(0x5EEAD4), col(0x818CF8), col(0xC084FC)] as CFArray,
                                   locations: [0, 0.5, 1])!
                c.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.midY), end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
                c.restoreGState()
            }
        }
        line(0.52, 0.5, 0.065, col(0xFFFFFF, 0.28))
        line(0.36, 0.68, 0.085, nil)
        line(0.22, 0.44, 0.065, col(0xFFFFFF, 0.85))
        // 光标
        let caretH = r.height * 0.11
        c.addPath(CGPath(roundedRect: CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.36 - (caretH - r.height * 0.085) / 2,
                                             width: r.width * 0.025, height: caretH),
                         cornerWidth: r.width * 0.0125, cornerHeight: r.width * 0.0125, transform: nil))
        c.setFillColor(col(0x5EEAD4))
        c.fillPath()
        c.restoreGState()

        c.addPath(body)
        c.setStrokeColor(col(0xFFFFFF, 0.08))
        c.setLineWidth(s * 0.004)
        c.strokePath()
    }

    static func exportIconset(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let specs: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
                                      ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
                                      ("512x512", 512), ("512x512@2x", 1024)]
        for (name, px) in specs {
            if let data = render(px).representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("icon_\(name).png"))
            }
        }
    }
}
