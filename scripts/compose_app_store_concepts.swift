#!/usr/bin/env swift

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Three editorial concepts for review. The UI inside every device is an existing
// Blip capture; only the surrounding hardware and marketing layout are drawn.

private let size = CGSize(width: 1320, height: 2868)
private let ink = color(0x0B2344)
private let blue = color(0x0875F9)
private let cream = color(0xF5F8FA)

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255,
            alpha: alpha)
}

private func image(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let result = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "BlipConcepts", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode \(url.path)"])
    }
    return result
}

private func context(_ canvas: CGSize) -> CGContext {
    guard let result = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height),
                                 bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Cannot create bitmap context")
    }
    result.interpolationQuality = .high
    return result
}

private func gradient(_ colors: [CGColor], in rect: CGRect, ctx: CGContext, vertical: Bool = true) {
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(gradient,
                           start: vertical ? CGPoint(x: rect.midX, y: rect.maxY) : CGPoint(x: rect.minX, y: rect.midY),
                           end: vertical ? CGPoint(x: rect.midX, y: rect.minY) : CGPoint(x: rect.maxX, y: rect.midY),
                           options: [])
    ctx.restoreGState()
}

private func text(_ string: String, x: CGFloat, baseline: CGFloat, width: CGFloat,
                  size: CGFloat, fontName: String = "AvenirNext-Bold", fill: CGColor, ctx: CGContext) {
    var font = CTFontCreateWithName(fontName as CFString, size, nil)
    func line() -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): fill,
        ]))
    }
    var value = line()
    let measured = CGFloat(CTLineGetTypographicBounds(value, nil, nil, nil))
    if measured > width {
        font = CTFontCreateWithName(fontName as CFString, size * width / measured * 0.98, nil)
        value = line()
    }
    ctx.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(value, ctx)
}

private func lockup(icon: CGImage, x: CGFloat, y: CGFloat, dark: Bool, ctx: CGContext) {
    let rect = CGRect(x: x, y: y, width: 78, height: 78)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 19, cornerHeight: 19, transform: nil))
    ctx.clip()
    ctx.draw(icon, in: rect)
    ctx.restoreGState()
    text("Blip", x: x + 99, baseline: y + 17, width: 250, size: 59,
         fill: dark ? ink : color(0xFFFFFF), ctx: ctx)
}

private func phone(_ screenshot: CGImage, in rect: CGRect, angle: CGFloat, ctx: CGContext) {
    ctx.saveGState()
    ctx.translateBy(x: rect.midX, y: rect.midY)
    ctx.rotate(by: angle * .pi / 180)
    ctx.translateBy(x: -rect.midX, y: -rect.midY)

    let body = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.12,
                      cornerHeight: rect.width * 0.12, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 28, height: -38), blur: 75,
                  color: color(0x07182B, alpha: 0.42))
    ctx.setFillColor(color(0x101A27))
    ctx.addPath(body)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    gradient([color(0xB8C7D1), color(0x536A7F), color(0x152232), color(0x8DA0AF)],
             in: rect, ctx: ctx, vertical: false)
    ctx.restoreGState()
    ctx.setStrokeColor(color(0xDCE5E9, alpha: 0.8))
    ctx.setLineWidth(4)
    ctx.addPath(body)
    ctx.strokePath()

    let bezel = rect.insetBy(dx: rect.width * 0.010, dy: rect.width * 0.010)
    ctx.setFillColor(color(0x050A10))
    ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: rect.width * 0.111,
                       cornerHeight: rect.width * 0.111, transform: nil))
    ctx.fillPath()

    let screen = CGRect(x: rect.minX + rect.width * 0.027,
                        y: rect.minY + rect.width * 0.030,
                        width: rect.width * 0.946,
                        height: rect.height - rect.width * 0.060)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: rect.width * 0.098,
                            cornerHeight: rect.width * 0.098, transform: nil)
    ctx.saveGState()
    ctx.addPath(screenPath)
    ctx.clip()
    ctx.draw(screenshot, in: screen)
    ctx.restoreGState()
    ctx.setStrokeColor(color(0x000000, alpha: 0.7))
    ctx.setLineWidth(3)
    ctx.addPath(screenPath)
    ctx.strokePath()

    // The original capture includes its real status bar and Dynamic Island.
    for (right, topOffset, height) in [(false, 480.0, 84.0), (false, 680.0, 138.0),
                                       (false, 850.0, 138.0), (true, 680.0, 210.0)] {
        let button = CGRect(x: right ? rect.maxX - 2 : rect.minX - 10,
                            y: rect.maxY - CGFloat(topOffset), width: 12, height: CGFloat(height))
        ctx.setFillColor(color(0x52677A))
        ctx.addPath(CGPath(roundedRect: button, cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

private func captureCard(_ screenshot: CGImage, crop: CGRect, in rect: CGRect, ctx: CGContext) {
    guard let excerpt = screenshot.cropping(to: crop) else { fatalError("Cannot crop source capture") }
    let frame = CGPath(roundedRect: rect, cornerWidth: 48, cornerHeight: 48, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 18, height: -30), blur: 56,
                  color: color(0x07182B, alpha: 0.3))
    ctx.setFillColor(color(0x17273B))
    ctx.addPath(frame)
    ctx.fillPath()
    ctx.restoreGState()
    let screen = rect.insetBy(dx: 10, dy: 10)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 40, cornerHeight: 40, transform: nil))
    ctx.clip()
    ctx.draw(excerpt, in: screen)
    ctx.restoreGState()
    ctx.setStrokeColor(color(0xC9D7E3))
    ctx.setLineWidth(3)
    ctx.addPath(frame)
    ctx.strokePath()
}

private func save(_ ctx: CGContext, to url: URL) throws {
    guard let bitmap = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "BlipConcepts", code: 2)
    }
    CGImageDestinationAddImage(destination, bitmap, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "BlipConcepts", code: 3) }
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    .deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("AppStore/Screenshots/final/en-US/iphone")
let output = root.appendingPathComponent("AppStore/Screenshots/concepts-2026-10-06/en-US/iphone")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let icon = try image(root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"))
let keyboard = try image(source.appendingPathComponent("00-keyboard.png"))
let scanner = try image(source.appendingPathComponent("02-scanner.png"))
let history = try image(source.appendingPathComponent("03-history.png"))

do {
    let ctx = context(size)
    ctx.setFillColor(cream)
    ctx.fill(CGRect(origin: .zero, size: size))
    let field = CGMutablePath()
    field.move(to: CGPoint(x: 720, y: 0))
    field.addLine(to: CGPoint(x: 1320, y: 0))
    field.addLine(to: CGPoint(x: 1320, y: 2130))
    field.addLine(to: CGPoint(x: 1115, y: 2200))
    field.closeSubpath()
    ctx.saveGState()
    ctx.addPath(field)
    ctx.clip()
    gradient([color(0x229BFF), color(0x0065E2), color(0x083899)],
             in: CGRect(x: 700, y: 0, width: 620, height: 2200), ctx: ctx)
    ctx.restoreGState()
    lockup(icon: icon, x: 84, y: 2670, dark: true, ctx: ctx)
    text("Scan straight", x: 84, baseline: 2477, width: 1150, size: 151, fill: ink, ctx: ctx)
    text("into your apps.", x: 84, baseline: 2310, width: 1150, size: 151, fill: ink, ctx: ctx)
    text("From the Blip keyboard.", x: 88, baseline: 2182, width: 1120, size: 68,
         fontName: "AvenirNext-Medium", fill: color(0x40627F), ctx: ctx)
    phone(keyboard, in: CGRect(x: 206, y: 46, width: 925, height: 1962), angle: -4.5, ctx: ctx)
    try save(ctx, to: output.appendingPathComponent("01-hero.png"))
}

do {
    let ctx = context(size)
    gradient([color(0x07192F), color(0x0A3A74), color(0x07203F)],
             in: CGRect(origin: .zero, size: size), ctx: ctx)
    // Barcode rhythm in the background echoes the task without mimicking UI.
    for (index, width) in [22, 9, 42, 14, 12, 31, 10, 55, 17, 9].enumerated() {
        let x = CGFloat(65 + index * 84)
        ctx.setFillColor(color(0x49A9FF, alpha: index.isMultiple(of: 3) ? 0.16 : 0.09))
        ctx.fill(CGRect(x: x, y: 85, width: CGFloat(width), height: 2020))
    }
    lockup(icon: icon, x: 84, y: 2670, dark: false, ctx: ctx)
    text("Point. Scan.", x: 84, baseline: 2477, width: 1150, size: 165,
         fill: color(0xFFFFFF), ctx: ctx)
    text("Done.", x: 84, baseline: 2299, width: 1150, size: 165,
         fill: color(0xFFFFFF), ctx: ctx)
    text("Barcodes and QR codes.", x: 88, baseline: 2160, width: 1130, size: 72,
         fontName: "AvenirNext-Medium", fill: color(0xABD8FF), ctx: ctx)
    phone(scanner, in: CGRect(x: 320, y: -300, width: 1110, height: 2353), angle: 3.5, ctx: ctx)
    try save(ctx, to: output.appendingPathComponent("02-scan.png"))
}

do {
    let ctx = context(size)
    ctx.setFillColor(color(0xF5F8FB))
    ctx.fill(CGRect(origin: .zero, size: size))
    let rail = CGRect(x: 965, y: 0, width: 355, height: 1950)
    gradient([color(0x2CA0FF), color(0x0657CD)], in: rail, ctx: ctx)
    lockup(icon: icon, x: 84, y: 2670, dark: true, ctx: ctx)
    text("Your scan.", x: 84, baseline: 2470, width: 1150, size: 151, fill: ink, ctx: ctx)
    text("Ready to use.", x: 84, baseline: 2300, width: 1150, size: 151, fill: ink, ctx: ctx)
    text("Copy a saved scan in one tap.", x: 88, baseline: 2162, width: 1140, size: 70,
         fontName: "AvenirNext-Medium", fill: color(0x3B6285), ctx: ctx)
    phone(history, in: CGRect(x: 398, y: -150, width: 895, height: 1897), angle: 3, ctx: ctx)
    captureCard(history, crop: CGRect(x: 55, y: 675, width: 1210, height: 345),
                in: CGRect(x: 66, y: 930, width: 1160, height: 331), ctx: ctx)
    try save(ctx, to: output.appendingPathComponent("03-use.png"))
}

let thumb = CGSize(width: 220, height: 478)
let margin: CGFloat = 24
let gap: CGFloat = 18
let sheet = CGSize(width: margin * 2 + thumb.width * 3 + gap * 2, height: 24 + thumb.height + 58)
let sheetCtx = context(sheet)
sheetCtx.setFillColor(color(0xCED9E3))
sheetCtx.fill(CGRect(origin: .zero, size: sheet))
for (index, file) in ["01-hero.png", "02-scan.png", "03-use.png"].enumerated() {
    let item = try image(output.appendingPathComponent(file))
    let x = margin + CGFloat(index) * (thumb.width + gap)
    let frame = CGRect(x: x, y: 42, width: thumb.width, height: thumb.height)
    sheetCtx.draw(item, in: frame)
    sheetCtx.setStrokeColor(color(0x718499))
    sheetCtx.setLineWidth(1.5)
    sheetCtx.stroke(frame)
    text(["01 / HERO", "02 / SCAN", "03 / USE"][index], x: x, baseline: 17,
         width: thumb.width, size: 16, fontName: "AvenirNext-DemiBold", fill: ink, ctx: sheetCtx)
}
try save(sheetCtx, to: output.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("contact-sheet.png"))
print("Created three concepts and contact sheet in \(output.path)")
