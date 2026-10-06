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
    let accent: RGBColor
}

struct FamilyLayout {
    let canvasSize: CGSize
    let deviceRect: CGRect
    let screenRect: CGRect
    let deviceCornerRadius: CGFloat
    let screenCornerRadius: CGFloat
    let outerMargin: CGFloat
    let iconSize: CGFloat
    let headlineFontSize: CGFloat
    let detailFontSize: CGFloat
    let headlineRect: CGRect
    let detailRect: CGRect
}

let lightBlue = Palette(
    top: RGBColor(0xF4FAFF),
    bottom: RGBColor(0xD9EFFF),
    foreground: RGBColor(0x08284D),
    secondary: RGBColor(0x235477),
    accent: RGBColor(0x1689ED)
)
let brightBlue = Palette(
    top: RGBColor(0x147DFA),
    bottom: RGBColor(0x0649CB),
    foreground: RGBColor(0xFFFFFF),
    secondary: RGBColor(0xE7F3FF),
    accent: RGBColor(0x8AD8FF)
)
let cyan = Palette(
    top: RGBColor(0xF1FCFF),
    bottom: RGBColor(0xC9F0F8),
    foreground: RGBColor(0x073849),
    secondary: RGBColor(0x256070),
    accent: RGBColor(0x31B4CC)
)
let indigo = Palette(
    top: RGBColor(0xF6F8FF),
    bottom: RGBColor(0xDDE6FF),
    foreground: RGBColor(0x1C3158),
    secondary: RGBColor(0x475D82),
    accent: RGBColor(0x6F91E8)
)
let mint = Palette(
    top: RGBColor(0xF4FFFA),
    bottom: RGBColor(0xD5F5E9),
    foreground: RGBColor(0x123C35),
    secondary: RGBColor(0x386B61),
    accent: RGBColor(0x55C4A4)
)

let copy: [String: [String: SlideCopy]] = [
    "en-US": [
        "keyboard": SlideCopy(sourceName: "00-keyboard.png", outputName: "01-keyboard.png", headline: "Scan in one tap", detail: "One tap opens the scanner.", palette: brightBlue),
        "scanner": SlideCopy(sourceName: "02-scanner.png", outputName: "02-scanner.png", headline: "Point. Scan. Done.", detail: "Barcodes and QR codes, fast.", palette: brightBlue),
        "scan": SlideCopy(sourceName: "01-scan.png", outputName: "03-workflow.png", headline: "Back to Chrome", detail: "Auto-insert, or tap to insert.", palette: lightBlue),
        "history": SlideCopy(sourceName: "03-history.png", outputName: "04-history.png", headline: "Find past scans", detail: "Find earlier scans in seconds.", palette: cyan),
        "settings": SlideCopy(sourceName: "04-settings.png", outputName: "05-settings.png", headline: "Make it yours", detail: "Choose layouts and scan options.", palette: lightBlue),
        "profiles": SlideCopy(sourceName: "05-profiles.png", outputName: "06-profiles.png", headline: "Share your setup", detail: "Share settings between devices.", palette: indigo),
        "privacy": SlideCopy(sourceName: "06-privacy.png", outputName: "07-privacy.png", headline: "Scans stay yours", detail: "History stays on your device.", palette: mint),
    ],
    "de-DE": [
        "keyboard": SlideCopy(sourceName: "00-keyboard.png", outputName: "01-keyboard.png", headline: "Scan per Tastatur", detail: "Ein Tipp öffnet den Scanner.", palette: brightBlue),
        "scanner": SlideCopy(sourceName: "02-scanner.png", outputName: "02-scanner.png", headline: "Zielen. Scannen.", detail: "Barcodes und QR-Codes.", palette: brightBlue),
        "scan": SlideCopy(sourceName: "01-scan.png", outputName: "03-workflow.png", headline: "Zurück zu Chrome", detail: "Automatisch oder per Tipp einfügen.", palette: lightBlue),
        "history": SlideCopy(sourceName: "03-history.png", outputName: "04-history.png", headline: "Scans griffbereit", detail: "Frühere Scans schnell finden.", palette: cyan),
        "settings": SlideCopy(sourceName: "04-settings.png", outputName: "05-settings.png", headline: "Deine Tastatur", detail: "Layouts und Scanoptionen wählen.", palette: lightBlue),
        "profiles": SlideCopy(sourceName: "05-profiles.png", outputName: "06-profiles.png", headline: "Setup fürs Team", detail: "Einstellungen einfach teilen.", palette: indigo),
        "privacy": SlideCopy(sourceName: "06-privacy.png", outputName: "07-privacy.png", headline: "Scans bleiben hier", detail: "Verlauf bleibt auf dem Gerät.", palette: mint),
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
            deviceRect: CGRect(x: 164, y: 36, width: 992, height: 2102),
            screenRect: CGRect(x: 190, y: 66, width: 940, height: 2042),
            deviceCornerRadius: 123,
            screenCornerRadius: 101,
            outerMargin: 86,
            iconSize: 90,
            headlineFontSize: 126,
            detailFontSize: 74,
            headlineRect: CGRect(x: 86, y: 2260, width: 1148, height: 340),
            detailRect: CGRect(x: 86, y: 2130, width: 1148, height: 140)
        )
    }

    return FamilyLayout(
        canvasSize: CGSize(width: 2064, height: 2752),
        deviceRect: CGRect(x: 270, y: 58, width: 1524, height: 2032),
        screenRect: CGRect(x: 303, y: 91, width: 1458, height: 1944),
        deviceCornerRadius: 92,
        screenCornerRadius: 65,
        outerMargin: 110,
        iconSize: 105,
        headlineFontSize: 132,
        detailFontSize: 84,
        headlineRect: CGRect(x: 110, y: 2220, width: 1844, height: 300),
        detailRect: CGRect(x: 110, y: 2096, width: 1844, height: 126)
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
    let baseFont = font(named: bold ? "AvenirNext-Bold" : "AvenirNext-Medium", size: fontSize)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): baseFont,
    ]))
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let fittedSize = textWidth > rect.width ? fontSize * (rect.width / textWidth) * 0.98 : fontSize
    let paragraph = CTParagraphStyleCreate([
        CTParagraphStyleSetting(
            spec: .lineSpacingAdjustment,
            valueSize: MemoryLayout<CGFloat>.size,
            value: withUnsafePointer(to: lineSpacing) { UnsafeRawPointer($0) }
        ),
    ], 1)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font(named: bold ? "AvenirNext-Bold" : "AvenirNext-Medium", size: fittedSize),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
    ]
    let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
    precondition(CTFrameGetVisibleStringRange(frame).length == (text as NSString).length, "Clipped screenshot copy: \(text)")
    precondition(CFArrayGetCount(CTFrameGetLines(frame)) == 1, "Wrapped screenshot copy: \(text)")
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

    let labelRect = CGRect(x: iconRect.maxX + 25, y: y + 6, width: 360, height: layout.iconSize)
    drawText(
        "Blip",
        in: labelRect,
        fontSize: layout.iconSize * 0.62,
        bold: true,
        color: palette.foreground.cgColor,
        context: context
    )
}

func drawAtmosphere(layout: FamilyLayout, palette: Palette, context: CGContext) {
    let center = CGPoint(x: layout.canvasSize.width * 0.55, y: layout.deviceRect.midY * 0.95)
    let accent = palette.accent
    for (index, scale) in [0.53, 0.75, 0.99].enumerated() {
        let diameter = layout.canvasSize.width * scale * 2
        let ring = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.setStrokeColor(CGColor(red: accent.red, green: accent.green, blue: accent.blue, alpha: index == 0 ? 0.19 : 0.11))
        context.setLineWidth(index == 0 ? 5 : 3)
        context.strokeEllipse(in: ring)
    }
}

func drawHardwareButton(in rect: CGRect, context: CGContext) {
    let path = CGPath(roundedRect: rect, cornerWidth: min(rect.width, rect.height) / 2, cornerHeight: min(rect.width, rect.height) / 2, transform: nil)
    context.setFillColor(RGBColor(0x465462).cgColor)
    context.addPath(path)
    context.fillPath()
    context.setStrokeColor(CGColor(gray: 0.76, alpha: 0.7))
    context.setLineWidth(2)
    context.addPath(path)
    context.strokePath()
}

func drawDevice(_ image: CGImage, family: String, layout: FamilyLayout, context: CGContext) {
    let body = layout.deviceRect
    let screen = layout.screenRect
    let bodyPath = CGPath(roundedRect: body, cornerWidth: layout.deviceCornerRadius, cornerHeight: layout.deviceCornerRadius, transform: nil)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: layout.screenCornerRadius, cornerHeight: layout.screenCornerRadius, transform: nil)

    // The screen capture already contains its real status bar and, on iPhone, Dynamic Island.
    // Only the hardware around it is drawn here; no UI is recreated or stretched between families.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 18, height: -32), blur: 60, color: CGColor(gray: 0.02, alpha: 0.38))
    context.setFillColor(RGBColor(0x18232F).cgColor)
    context.addPath(bodyPath)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    let metal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        RGBColor(0xA9B8C3).cgColor,
        RGBColor(0x53677A).cgColor,
        RGBColor(0x172432).cgColor,
        RGBColor(0x6E8293).cgColor,
    ] as CFArray, locations: [0, 0.17, 0.65, 1])!
    context.drawLinearGradient(metal, start: CGPoint(x: body.minX, y: body.midY), end: CGPoint(x: body.maxX, y: body.midY), options: [])
    context.restoreGState()

    context.setStrokeColor(CGColor(gray: 0.94, alpha: 0.78))
    context.setLineWidth(4)
    context.addPath(bodyPath)
    context.strokePath()

    let bezel = body.insetBy(dx: family == "iphone" ? 10 : 13, dy: family == "iphone" ? 10 : 13)
    let bezelPath = CGPath(roundedRect: bezel, cornerWidth: layout.deviceCornerRadius - 10, cornerHeight: layout.deviceCornerRadius - 10, transform: nil)
    context.setFillColor(RGBColor(0x050A10).cgColor)
    context.addPath(bezelPath)
    context.fillPath()

    context.saveGState()
    context.addPath(screenPath)
    context.clip()
    context.draw(image, in: screen)
    context.restoreGState()
    context.setStrokeColor(CGColor(gray: 0, alpha: 0.5))
    context.setLineWidth(3)
    context.addPath(screenPath)
    context.strokePath()

    if family == "iphone" {
        drawHardwareButton(in: CGRect(x: body.minX - 10, y: body.maxY - 550, width: 12, height: 92), context: context)
        drawHardwareButton(in: CGRect(x: body.minX - 10, y: body.maxY - 780, width: 12, height: 154), context: context)
        drawHardwareButton(in: CGRect(x: body.minX - 10, y: body.maxY - 963, width: 12, height: 154), context: context)
        drawHardwareButton(in: CGRect(x: body.maxX - 2, y: body.maxY - 815, width: 12, height: 245), context: context)
    } else {
        drawHardwareButton(in: CGRect(x: body.maxX - 2, y: body.maxY - 420, width: 12, height: 145), context: context)
        drawHardwareButton(in: CGRect(x: body.maxX - 2, y: body.maxY - 590, width: 12, height: 145), context: context)
        context.setFillColor(RGBColor(0x0B121B).cgColor)
        context.fillEllipse(in: CGRect(x: body.midX - 8, y: body.maxY - 25, width: 16, height: 16))
        context.setFillColor(CGColor(red: 0.26, green: 0.37, blue: 0.48, alpha: 0.75))
        context.fillEllipse(in: CGRect(x: body.midX - 3, y: body.maxY - 20, width: 6, height: 6))
    }
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
let outputDirectoryName = ProcessInfo.processInfo.environment["BLIP_SCREENSHOT_COMPOSE_OUTPUT"] ?? "composed"
guard !outputDirectoryName.isEmpty,
      !outputDirectoryName.contains("/"),
      outputDirectoryName != ".",
      outputDirectoryName != "..",
      outputDirectoryName != "final" else {
    throw NSError(domain: "BlipScreenshotComposer", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid output directory name"])
}
let outputRoot = repositoryRoot.appendingPathComponent("AppStore/Screenshots/\(outputDirectoryName)")
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

            drawAtmosphere(layout: familyLayout, palette: slide.palette, context: context)
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
            drawDevice(screenshot, family: family, layout: familyLayout, context: context)

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
