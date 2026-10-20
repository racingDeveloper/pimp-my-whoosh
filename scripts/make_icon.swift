// Draws the app icon (a "PMW" wordmark in white and amber on charcoal) and writes Resources/AppIcon.icns.
// Run from the repository root: swift scripts/make_icon.swift
import AppKit

let canvas: CGFloat = 1024

func drawIcon(in ctx: CGContext) {
    // macOS icon grid: 824×824 squircle centered in the 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(shape)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(red: 0.24, green: 0.24, blue: 0.25, alpha: 1).cgColor,
        NSColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // "PMW" wordmark: heavy italic sans, white with an amber W, like a sporty cycling logo.
    let amber = NSColor(red: 0.99, green: 0.73, blue: 0.08, alpha: 1)
    let font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 270, weight: .black), toHaveTrait: .italicFontMask)
    let text = NSMutableAttributedString(string: "PMW", attributes: [
        .font: font, .foregroundColor: NSColor.white, .kern: -6,
    ])
    text.addAttribute(.foregroundColor, value: amber, range: NSRange(location: 2, length: 1))

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let size = text.size()
    let origin = CGPoint(x: 512 - size.width / 2, y: 512 - size.height / 2 + 30)
    text.draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()

    // Amber speed stroke under the letters.
    ctx.setLineCap(.round)
    ctx.setLineWidth(26)
    ctx.setStrokeColor(amber.cgColor)
    let underline = origin.y + font.descender * -1 - 70
    ctx.move(to: CGPoint(x: origin.x + 10, y: underline))
    ctx.addLine(to: CGPoint(x: origin.x + size.width - 40, y: underline))
    ctx.strokePath()
    ctx.restoreGState()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try png(size: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "OK: Resources/AppIcon.icns" : "iconutil failed")
