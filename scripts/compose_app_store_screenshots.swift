#!/usr/bin/env swift

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGBColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(_ hex: UInt32) {
        red = CGFloat((hex >> 16) & 0xff) / 255
        green = CGFloat((hex >> 8) & 0xff) / 255
        blue = CGFloat(hex & 0xff) / 255
    }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

struct SlideCopy {
    let sourceName: String
    let outputName: String
    let headline: String
    let detail: String
    let palette: Palette
}

struct Palette {
    let top: RGBColor
    let bottom: RGBColor
    let foreground: RGBColor
    let secondary: RGBColor
    let frame: RGBColor
}

struct FamilyLayout {
    let canvasSize: CGSize
    let screenRect: CGRect
    let screenCornerRadius: CGFloat
    let outerMargin: CGFloat
    let iconSize: CGFloat
    let headlineFontSize: CGFloat
    let detailFontSize: CGFloat
    let headlineRect: CGRect
    let detailRect: CGRect
}

let lightBlue = Palette(
    top: RGBColor(0xF7FBFF),
    bottom: RGBColor(0xDCEEFF),
    foreground: RGBColor(0x071D3A),
    secondary: RGBColor(0x31577D),
    frame: RGBColor(0xB9DAF8)
)
let brightBlue = Palette(
    top: RGBColor(0x087EFA),
    bottom: RGBColor(0x0346D8),
    foreground: RGBColor(0xFFFFFF),
    secondary: RGBColor(0xD9EDFF),
    frame: RGBColor(0x87D8FF)
)
let cyan = Palette(
    top: RGBColor(0xF4FDFF),
    bottom: RGBColor(0xC9F5FF),
    foreground: RGBColor(0x062A3B),
    secondary: RGBColor(0x356777),
    frame: RGBColor(0x8BDDEB)
)
let indigo = Palette(
    top: RGBColor(0xF7F8FF),
    bottom: RGBColor(0xE1E5FF),
    foreground: RGBColor(0x181A46),
    secondary: RGBColor(0x52567F),
    frame: RGBColor(0xBEC5F5)
)
let mint = Palette(
    top: RGBColor(0xF7FFFC),
    bottom: RGBColor(0xD9F7EC),
    foreground: RGBColor(0x0A342A),
    secondary: RGBColor(0x3D6A60),
    frame: RGBColor(0xA8DECf)
)

let copy: [String: [String: SlideCopy]] = [
    "en-US": [
        "keyboard": SlideCopy(sourceName: "00-keyboard.png", outputName: "01-keyboard.png", headline: "Scan from any app", detail: "Type, scan, and keep working.", palette: brightBlue),
        "scanner": SlideCopy(sourceName: "02-scanner.png", outputName: "02-scanner.png", headline: "Point. Scan. Done.", detail: "Camera, flashlight, and zoom are ready.", palette: brightBlue),
        "scan": SlideCopy(sourceName: "01-scan.png", outputName: "03-workflow.png", headline: "Back where you started", detail: "Blip returns to the original field.", palette: lightBlue),
        "history": SlideCopy(sourceName: "03-history.png", outputName: "04-history.png", headline: "Every scan close at hand", detail: "Stored locally and always searchable.", palette: cyan),
        "settings": SlideCopy(sourceName: "04-settings.png", outputName: "05-settings.png", headline: "Make Blip work your way", detail: "Language, layouts, scan formats, and more.", palette: lightBlue),
        "profiles": SlideCopy(sourceName: "05-profiles.png", outputName: "06-profiles.png", headline: "One setup for every device", detail: "Share a consistent company configuration.", palette: indigo),
        "privacy": SlideCopy(sourceName: "06-privacy.png", outputName: "07-privacy.png", headline: "Private by design", detail: "Your scan history stays on the device.", palette: mint),
    ],
    "de-DE": [
        "keyboard": SlideCopy(sourceName: "00-keyboard.png", outputName: "01-keyboard.png", headline: "Scannen in jeder App", detail: "Tippen, scannen und direkt weiterarbeiten.", palette: brightBlue),
        "scanner": SlideCopy(sourceName: "02-scanner.png", outputName: "02-scanner.png", headline: "Zielen. Scannen. Fertig.", detail: "Kamera, Taschenlampe und Zoom sind bereit.", palette: brightBlue),
        "scan": SlideCopy(sourceName: "01-scan.png", outputName: "03-workflow.png", headline: "Zurück, wo du gestartet bist", detail: "Blip kehrt zum ursprünglichen Feld zurück.", palette: lightBlue),
        "history": SlideCopy(sourceName: "03-history.png", outputName: "04-history.png", headline: "Jeder Scan griffbereit", detail: "Lokal gespeichert und jederzeit durchsuchbar.", palette: cyan),
        "settings": SlideCopy(sourceName: "04-settings.png", outputName: "05-settings.png", headline: "Blip passt sich dir an", detail: "Sprache, Layouts, Scan-Formate und mehr.", palette: lightBlue),
        "profiles": SlideCopy(sourceName: "05-profiles.png", outputName: "06-profiles.png", headline: "Ein Setup für jedes Gerät", detail: "Teile eine einheitliche Firmenkonfiguration.", palette: indigo),
        "privacy": SlideCopy(sourceName: "06-privacy.png", outputName: "07-privacy.png", headline: "Datenschutz von Anfang an", detail: "Dein Scanverlauf bleibt auf dem Gerät.", palette: mint),
    ],
]

let familyScenes: [String: [String]] = [
    "iphone": ["keyboard", "scanner", "scan", "history", "settings", "profiles", "privacy"],
    "ipad": ["scanner", "scan", "history", "settings", "profiles", "privacy"],
]

func layout(for family: String) -> FamilyLayout {
    if family == "iphone" {
        return FamilyLayout(
            canvasSize: CGSize(width: 1320, height: 2868),
            screenRect: CGRect(x: 132, y: -105, width: 1056, height: 2294.4),
            screenCornerRadius: 82,
            outerMargin: 80,
            iconSize: 94,
            headlineFontSize: 92,
            detailFontSize: 39,
            headlineRect: CGRect(x: 80, y: 2390, width: 1160, height: 265),
            detailRect: CGRect(x: 80, y: 2260, width: 1160, height: 100)
        )
    }

    return FamilyLayout(
        canvasSize: CGSize(width: 2064, height: 2752),
        screenRect: CGRect(x: 152, y: -145, width: 1760, height: 2346.7),
        screenCornerRadius: 70,
        outerMargin: 94,
        iconSize: 88,
        headlineFontSize: 82,
        detailFontSize: 35,
        headlineRect: CGRect(x: 94, y: 2400, width: 1876, height: 190),
        detailRect: CGRect(x: 94, y: 2290, width: 1876, height: 80)
    )
}

func loadImage(at url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "BlipScreenshotComposer", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not decode \(url.path)",
        ])
    }
    return image
}

func font(named name: String, size: CGFloat, bold: Bool = false) -> CTFont {
    let base = CTFontCreateWithName(name as CFString, size, nil)
    guard bold else { return base }
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base
}

func drawText(
    _ text: String,
    in rect: CGRect,
    fontSize: CGFloat,
    bold: Bool,
    color: CGColor,
    context: CGContext,
    lineSpacing: CGFloat = 2
) {
    let paragraph = CTParagraphStyleCreate([
        CTParagraphStyleSetting(
            spec: .lineSpacingAdjustment,
            valueSize: MemoryLayout<CGFloat>.size,
            value: withUnsafePointer(to: lineSpacing) { UnsafeRawPointer($0) }
        ),
    ], 1)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font(named: "SF Pro Display", size: fontSize, bold: bold),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
    ]
    let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
    CTFrameDraw(frame, context)
}

func drawAppLockup(icon: CGImage, layout: FamilyLayout, palette: Palette, context: CGContext) {
    let x = layout.outerMargin
    let y = layout.canvasSize.height - layout.outerMargin - layout.iconSize
    let iconRect = CGRect(x: x, y: y, width: layout.iconSize, height: layout.iconSize)

    context.saveGState()
    context.addPath(CGPath(roundedRect: iconRect, cornerWidth: layout.iconSize * 0.23, cornerHeight: layout.iconSize * 0.23, transform: nil))
    context.clip()
    context.draw(icon, in: iconRect)
    context.restoreGState()

    let labelRect = CGRect(
        x: iconRect.maxX + 22,
        y: y + 12,
        width: 260,
        height: layout.iconSize - 18
    )
    drawText(
        "Blip",
        in: labelRect,
        fontSize: layout.iconSize * 0.48,
        bold: true,
        color: palette.foreground.cgColor,
        context: context
    )
}

func drawScreen(_ image: CGImage, layout: FamilyLayout, palette: Palette, context: CGContext) {
    let rect = layout.screenRect
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: layout.screenCornerRadius,
        cornerHeight: layout.screenCornerRadius,
        transform: nil
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 24), blur: 42, color: CGColor(gray: 0.02, alpha: 0.26))
    context.setFillColor(CGColor(gray: 0.03, alpha: 1))
    context.addPath(path)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.draw(image, in: rect)
    context.restoreGState()

    context.setStrokeColor(palette.frame.cgColor)
    context.setLineWidth(9)
    context.addPath(path)
    context.strokePath()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "BlipScreenshotComposer", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "BlipScreenshotComposer", code: 3)
    }
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repositoryRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceRoot = repositoryRoot.appendingPathComponent("AppStore/Screenshots/final")
let outputRoot = repositoryRoot.appendingPathComponent("AppStore/Screenshots/composed")
let iconURL = repositoryRoot.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/Icon-1024.png")
let appIcon = try loadImage(at: iconURL)

try? FileManager.default.removeItem(at: outputRoot)

for locale in ["en-US", "de-DE"] {
    guard let localizedCopy = copy[locale] else { continue }

    for family in ["iphone", "ipad"] {
        let familyLayout = layout(for: family)
        guard let scenes = familyScenes[family] else { continue }

        for scene in scenes {
            guard let slide = localizedCopy[scene] else { continue }
            let sourceURL = sourceRoot
                .appendingPathComponent(locale)
                .appendingPathComponent(family)
                .appendingPathComponent(slide.sourceName)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                print("Skipping missing source \(sourceURL.path)")
                continue
            }

            let screenshot = try loadImage(at: sourceURL)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: Int(familyLayout.canvasSize.width),
                height: Int(familyLayout.canvasSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw NSError(domain: "BlipScreenshotComposer", code: 4)
            }

            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [slide.palette.bottom.cgColor, slide.palette.top.cgColor] as CFArray,
                locations: [0, 1]
            )!
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: familyLayout.canvasSize.width, y: familyLayout.canvasSize.height),
                options: []
            )

            drawAppLockup(icon: appIcon, layout: familyLayout, palette: slide.palette, context: context)
            drawText(
                slide.headline,
                in: familyLayout.headlineRect,
                fontSize: familyLayout.headlineFontSize,
                bold: true,
                color: slide.palette.foreground.cgColor,
                context: context,
                lineSpacing: 5
            )
            drawText(
                slide.detail,
                in: familyLayout.detailRect,
                fontSize: familyLayout.detailFontSize,
                bold: false,
                color: slide.palette.secondary.cgColor,
                context: context
            )
            drawScreen(screenshot, layout: familyLayout, palette: slide.palette, context: context)

            guard let result = context.makeImage() else {
                throw NSError(domain: "BlipScreenshotComposer", code: 5)
            }
            let destinationURL = outputRoot
                .appendingPathComponent(locale)
                .appendingPathComponent(family)
                .appendingPathComponent(slide.outputName)
            try writePNG(result, to: destinationURL)
            print("Created \(destinationURL.path)")
        }
    }
}
