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

private func tablet(_ screenshot: CGImage, in rect: CGRect, angle: CGFloat, ctx: CGContext) {
    ctx.saveGState()
    ctx.translateBy(x: rect.midX, y: rect.midY)
    ctx.rotate(by: angle * .pi / 180)
    ctx.translateBy(x: -rect.midX, y: -rect.midY)
    let body = CGPath(roundedRect: rect, cornerWidth: 95, cornerHeight: 95, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 25, height: -40), blur: 70, color: color(0x07182B, alpha: 0.38))
    ctx.setFillColor(color(0x0D1724))
    ctx.addPath(body)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    gradient([color(0x9EAFBD), color(0x263B50), color(0x0D1927), color(0x728697)], in: rect, ctx: ctx, vertical: false)
    ctx.restoreGState()
    ctx.setStrokeColor(color(0xDAE3E8))
    ctx.setLineWidth(4)
    ctx.addPath(body)
    ctx.strokePath()
    let bezel = rect.insetBy(dx: 17, dy: 17)
    ctx.setFillColor(color(0x050A10))
    ctx.addPath(CGPath(roundedRect: bezel, cornerWidth: 80, cornerHeight: 80, transform: nil))
    ctx.fillPath()
    let screen = rect.insetBy(dx: 34, dy: 34)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: 63, cornerHeight: 63, transform: nil))
    ctx.clip()
    ctx.draw(screenshot, in: screen)
    ctx.restoreGState()
    ctx.setFillColor(color(0x07111E))
    ctx.fillEllipse(in: CGRect(x: rect.midX - 9, y: rect.maxY - 23, width: 18, height: 18))
    ctx.setFillColor(color(0x385776))
    ctx.fillEllipse(in: CGRect(x: rect.midX - 3, y: rect.maxY - 17, width: 6, height: 6))
    ctx.restoreGState()
}

struct SceneCopy {
    let source: String
    let output: String
    let title: [String]
    let subtitle: String
    let style: String
}

let sceneCopy: [String: [String: SceneCopy]] = [
    "en-US": [
        "keyboard": SceneCopy(source: "00-keyboard.png", output: "01-keyboard.png", title: ["Scan straight", "into your apps."], subtitle: "From the Blip keyboard.", style: "hero"),
        "scanner": SceneCopy(source: "02-scanner.png", output: "02-scanner.png", title: ["Point. Scan.", "Done."], subtitle: "Barcodes and QR codes.", style: "scan"),
        "history": SceneCopy(source: "03-history.png", output: "03-history.png", title: ["Your scan.", "Ready to use."], subtitle: "Copy a saved scan in one tap.", style: "history"),
        "workflow": SceneCopy(source: "01-scan.png", output: "04-workflow.png", title: ["Back to", "Chrome."], subtitle: "Auto-insert, or tap to insert.", style: "workflow"),
        "settings": SceneCopy(source: "04-settings.png", output: "05-settings.png", title: ["Make it", "yours."], subtitle: "Fine-tune Blip in Settings.", style: "settings"),
        "profiles": SceneCopy(source: "05-profiles.png", output: "06-profiles.png", title: ["One setup.", "Every device."], subtitle: "Share company settings.", style: "profiles"),
        "privacy": SceneCopy(source: "06-privacy.png", output: "07-privacy.png", title: ["Your scans", "stay yours."], subtitle: "History stays on your device.", style: "privacy"),
    ],
    "de-DE": [
        "keyboard": SceneCopy(source: "00-keyboard.png", output: "01-keyboard.png", title: ["Scannen aus", "der Tastatur."], subtitle: "Ein Tipp öffnet den Scanner.", style: "hero"),
        "scanner": SceneCopy(source: "02-scanner.png", output: "02-scanner.png", title: ["Zielen.", "Scannen."], subtitle: "Barcodes und QR-Codes.", style: "scan"),
        "history": SceneCopy(source: "03-history.png", output: "03-history.png", title: ["Dein Scan.", "Griffbereit."], subtitle: "Gespeicherte Scans sofort kopieren.", style: "history"),
        "workflow": SceneCopy(source: "01-scan.png", output: "04-workflow.png", title: ["Zurück zu", "Chrome."], subtitle: "Automatisch oder per Tipp einfügen.", style: "workflow"),
        "settings": SceneCopy(source: "04-settings.png", output: "05-settings.png", title: ["Blip nach", "deiner Art."], subtitle: "Einstellungen, die zu dir passen.", style: "settings"),
        "profiles": SceneCopy(source: "05-profiles.png", output: "06-profiles.png", title: ["Ein Setup.", "Jedes Gerät."], subtitle: "Firmeneinstellungen teilen.", style: "profiles"),
        "privacy": SceneCopy(source: "06-privacy.png", output: "07-privacy.png", title: ["Deine Scans", "bleiben deine."], subtitle: "Verlauf bleibt auf deinem Gerät.", style: "privacy"),
    ],
]

let root = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    .deletingLastPathComponent().deletingLastPathComponent()
let sourceRoot = root.appendingPathComponent("AppStore/Screenshots/final")
let settingsRoot = root.appendingPathComponent("AppStore/Screenshots/release-source")
let outputRoot = root.appendingPathComponent("AppStore/Screenshots/premium")
let icon = try image(root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"))
try? FileManager.default.removeItem(at: outputRoot)

for locale in ["en-US", "de-DE"] {
    for family in ["iphone", "ipad"] {
        let scenes = family == "iphone"
            ? ["keyboard", "scanner", "history", "workflow", "settings", "profiles", "privacy"]
            : ["scanner", "history", "workflow", "settings", "profiles", "privacy"]
        for (index, scene) in scenes.enumerated() {
            guard let spec = sceneCopy[locale]?[scene] else { continue }
            let freshSettings = settingsRoot.appendingPathComponent("\(locale)/\(family)/settings.png")
            let sourceURL = scene == "settings" && FileManager.default.fileExists(atPath: freshSettings.path)
                ? freshSettings
                : sourceRoot.appendingPathComponent("\(locale)/\(family)/\(spec.source)")
            let capture = try image(sourceURL)
            let canvas = family == "iphone" ? CGSize(width: 1320, height: 2868) : CGSize(width: 2064, height: 2752)
            let ctx = context(canvas)
            let dark = ["scan", "settings", "privacy"].contains(spec.style)
            if dark {
                gradient([color(0x07192F), color(0x0A3A74), color(0x07203F)],
                         in: CGRect(origin: .zero, size: canvas), ctx: ctx)
            } else {
                ctx.setFillColor(cream)
                ctx.fill(CGRect(origin: .zero, size: canvas))
                let accentRect = family == "iphone"
                    ? CGRect(x: 925, y: 0, width: 395, height: 2030)
                    : CGRect(x: 1550, y: 0, width: 514, height: 2060)
                gradient([color(0x259BFF), color(0x0756C8)], in: accentRect, ctx: ctx)
            }
            let foreground = dark ? color(0xFFFFFF) : ink
            let secondary = dark ? color(0xACD9FF) : color(0x476C8C)
            let margin: CGFloat = family == "iphone" ? 84 : 110
            let headerY: CGFloat = family == "iphone" ? 2670 : 2570
            lockup(icon: icon, x: margin, y: headerY, dark: !dark, ctx: ctx)
            let titleSize: CGFloat = family == "iphone" ? 151 : 158
            let titleBase: CGFloat = family == "iphone" ? 2477 : 2415
            let lineStep: CGFloat = family == "iphone" ? 170 : 165
            for (line, value) in spec.title.enumerated() {
                text(value, x: margin, baseline: titleBase - CGFloat(line) * lineStep,
                     width: canvas.width - margin * 2, size: titleSize, fill: foreground, ctx: ctx)
            }
            let subtitleY: CGFloat = family == "iphone" ? 2162 : 2110
            text(spec.subtitle, x: margin + 4, baseline: subtitleY,
                 width: canvas.width - (margin + 4) * 2,
                 size: family == "iphone" ? 70 : 84,
                 fontName: "AvenirNext-Medium", fill: secondary, ctx: ctx)

            if family == "iphone" {
                switch spec.style {
                case "hero":
                    phone(capture, in: CGRect(x: 206, y: 46, width: 925, height: 1962), angle: -4.5, ctx: ctx)
                case "scan":
                    phone(capture, in: CGRect(x: 320, y: -300, width: 1110, height: 2353), angle: 3.5, ctx: ctx)
                case "history":
                    phone(capture, in: CGRect(x: 398, y: -150, width: 895, height: 1897), angle: 3, ctx: ctx)
                    captureCard(capture, crop: CGRect(x: 55, y: 675, width: 1210, height: 345),
                                in: CGRect(x: 66, y: 930, width: 1160, height: 331), ctx: ctx)
                case "workflow":
                    phone(capture, in: CGRect(x: -80, y: -150, width: 1000, height: 2120), angle: -3.5, ctx: ctx)
                case "settings":
                    phone(capture, in: CGRect(x: 235, y: -115, width: 950, height: 2014), angle: -3, ctx: ctx)
                case "profiles":
                    phone(capture, in: CGRect(x: 360, y: -105, width: 900, height: 1908), angle: 3, ctx: ctx)
                    captureCard(capture, crop: CGRect(x: 40, y: 450, width: 1240, height: 650),
                                in: CGRect(x: 54, y: 620, width: 1080, height: 566), ctx: ctx)
                default:
                    phone(capture, in: CGRect(x: 272, y: -120, width: 975, height: 2067), angle: 2.5, ctx: ctx)
                }
            } else {
                let tabletRect = CGRect(x: 302, y: 5, width: 1460, height: 1930)
                let angle: CGFloat = ["scan", "privacy"].contains(spec.style) ? -2.0 : 2.0
                tablet(capture, in: tabletRect, angle: angle, ctx: ctx)
                if spec.style == "history" {
                    captureCard(capture, crop: CGRect(x: 80, y: 390, width: 1900, height: 560),
                                in: CGRect(x: 80, y: 300, width: 1550, height: 457), ctx: ctx)
                } else if spec.style == "profiles" {
                    captureCard(capture, crop: CGRect(x: 65, y: 380, width: 1930, height: 660),
                                in: CGRect(x: 350, y: 160, width: 1460, height: 499), ctx: ctx)
                }
            }

            let destination = outputRoot.appendingPathComponent("\(locale)/\(family)/\(String(format: "%02d", index + 1))-\(scene).png")
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try save(ctx, to: destination)
            print("Created \(destination.path)")
        }
    }
}

private func save(_ ctx: CGContext, to url: URL) throws {
    guard let bitmap = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "BlipConcepts", code: 2)
    }
    CGImageDestinationAddImage(destination, bitmap, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "BlipConcepts", code: 3) }
}
