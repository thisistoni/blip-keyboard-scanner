#!/usr/bin/env swift

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PreviewSpec {
    let locale: String
    let family: String
    let thumbnailSize: CGSize
}

func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, weight: CTFontSymbolicTraits, color: CGColor, in context: CGContext) {
    let baseFont = CTFontCreateWithName("SF Pro Display" as CFString, fontSize, nil)
    let font = CTFontCreateCopyWithSymbolicTraits(baseFont, fontSize, nil, weight, weight) ?? baseFont
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = point
    CTLineDraw(line, context)
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repositoryRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceDirectoryName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "final"
let previewDirectoryName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "previews"
let screenshotRoot = repositoryRoot.appendingPathComponent("AppStore/Screenshots/\(sourceDirectoryName)")
let previewRoot = repositoryRoot.appendingPathComponent("AppStore/Screenshots/\(previewDirectoryName)")

let specs = [
    PreviewSpec(locale: "en-US", family: "iphone", thumbnailSize: CGSize(width: 220, height: 478)),
    PreviewSpec(locale: "de-DE", family: "iphone", thumbnailSize: CGSize(width: 220, height: 478)),
    PreviewSpec(locale: "en-US", family: "ipad", thumbnailSize: CGSize(width: 300, height: 400)),
    PreviewSpec(locale: "de-DE", family: "ipad", thumbnailSize: CGSize(width: 300, height: 400)),
]

try FileManager.default.createDirectory(at: previewRoot, withIntermediateDirectories: true)

for spec in specs {
    let sourceDirectory = screenshotRoot
        .appendingPathComponent(spec.locale)
        .appendingPathComponent(spec.family)
    let sources = try FileManager.default.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    guard !sources.isEmpty else {
        throw NSError(domain: "BlipScreenshotPreviews", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "No PNGs found in \(sourceDirectory.path)",
        ])
    }

    let columns = 3
    let rows = Int(ceil(Double(sources.count) / Double(columns)))
    let margin: CGFloat = 28
    let gap: CGFloat = 20
    let titleHeight: CGFloat = 52
    let labelHeight: CGFloat = 24
    let cellHeight = spec.thumbnailSize.height + labelHeight
    let canvasSize = CGSize(
        width: margin * 2 + CGFloat(columns) * spec.thumbnailSize.width + CGFloat(columns - 1) * gap,
        height: margin * 2 + titleHeight + CGFloat(rows) * cellHeight + CGFloat(rows - 1) * gap
    )

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(canvasSize.width),
        height: Int(canvasSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "BlipScreenshotPreviews", code: 2)
    }

    context.setFillColor(CGColor(gray: 0.93, alpha: 1))
    context.fill(CGRect(origin: .zero, size: canvasSize))
    context.interpolationQuality = .high

    let title = "Blip · \(spec.locale) · \(spec.family == "iphone" ? "iPhone 6.9-inch" : "iPad 13-inch")"
    drawText(
        title,
        at: CGPoint(x: margin, y: canvasSize.height - margin - 24),
        fontSize: 22,
        weight: .traitBold,
        color: CGColor(gray: 0.10, alpha: 1),
        in: context
    )

    for (index, source) in sources.enumerated() {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw NSError(domain: "BlipScreenshotPreviews", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Could not decode \(source.path)",
            ])
        }

        let column = index % columns
        let row = index / columns
        let x = margin + CGFloat(column) * (spec.thumbnailSize.width + gap)
        let y = canvasSize.height - margin - titleHeight - CGFloat(row + 1) * cellHeight - CGFloat(row) * gap + labelHeight
        let imageRect = CGRect(x: x, y: y, width: spec.thumbnailSize.width, height: spec.thumbnailSize.height)

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(imageRect.insetBy(dx: -2, dy: -2))
        context.draw(image, in: imageRect)

        drawText(
            source.deletingPathExtension().lastPathComponent,
            at: CGPoint(x: x, y: y - 17),
            fontSize: 12,
            weight: .traitMonoSpace,
            color: CGColor(gray: 0.30, alpha: 1),
            in: context
        )
    }

    guard let outputImage = context.makeImage() else {
        throw NSError(domain: "BlipScreenshotPreviews", code: 4)
    }
    let destinationURL = previewRoot.appendingPathComponent("\(spec.locale)-\(spec.family).png")
    guard let destination = CGImageDestinationCreateWithURL(
        destinationURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "BlipScreenshotPreviews", code: 5)
    }
    CGImageDestinationAddImage(destination, outputImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "BlipScreenshotPreviews", code: 6)
    }
    print("Created \(destinationURL.path)")
}
