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

    /// 白底圆角方块，左边四根声波竖条，右边变成一行字：“声音变成字”。
    /// 图案按 100×100 的网格设计（和 design/icons.html 里的 04 / 黑白版一致）
    static func draw(_ c: CGContext, _ s: CGFloat) {
        let rgb = CGColorSpaceCreateDeviceRGB()
        let inset = s * 0.1
        let r = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let rad = r.width * 0.225
        let body = CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)

        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.035, color: col(0, 0.35))
        c.addPath(body)
        c.setFillColor(col(0xFFFFFF))
        c.fillPath()
        c.restoreGState()

        c.saveGState()
        c.addPath(body)
        c.clip()
        let bg = CGGradient(colorsSpace: rgb, colors: [col(0xFFFFFF), col(0xE8E8ED)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(bg, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])

        // 网格坐标（y 向下）→ 画布坐标（y 向上）
        let u = r.width / 100
        func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            let rect = CGRect(x: r.minX + x * u, y: r.maxY - (y + h) * u, width: w * u, height: h * u)
            let rr = min(rect.width, rect.height) / 2
            c.addPath(CGPath(roundedRect: rect, cornerWidth: rr, cornerHeight: rr, transform: nil))
            c.setFillColor(col(0x111111))
            c.fillPath()
        }
        bar(20, 44, 4.5, 12)
        bar(28, 37, 4.5, 26)
        bar(36, 42, 4.5, 16)
        bar(44, 46.5, 4.5, 7)
        bar(53, 46.5, 27, 7)
        c.restoreGState()

        c.addPath(body)
        c.setStrokeColor(col(0x000000, 0.1))
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
