import UIKit

/// Draws an outline around each selectable code on the camera preview and
/// resolves taps to the nearest one. It does not receive touches itself; the
/// scanner view's tap paths ask it via `candidate(at:)`, so pinch-to-zoom
/// keeps working everywhere.
///
/// Vision boxes jitter by a few points from frame to frame. Each code's rect is
/// low-pass filtered (keyed by code) and path changes glide over a frame or two,
/// so outlines follow the code smoothly instead of jumping. Taps are resolved
/// against the rect that is drawn.
final class BarcodeCandidateOverlayView: UIView {
    struct Candidate {
        let key: BarcodeCandidateKey
        /// Code bounds in this view's (and the preview layer's) coordinates.
        let rect: CGRect
        /// Batch scans only: the code is already in the list and cannot be tapped.
        var isAdded = false
    }

    /// Tap targets are at least this large, even for tiny codes far away.
    static let minimumTapTargetSize: CGFloat = 44
    /// Extra slop around each code so a tap near the outline still counts.
    static let tapTargetPadding: CGFloat = 8
    /// A tap outside every target still selects the nearest code within this distance.
    private static let nearMissDistance: CGFloat = 24
    /// Outlines are drawn at least this large so small codes (the measured
    /// product codes were ~50 x 25 pt) still look like a clear target.
    private static let minimumOutlineSize = CGSize(width: 56, height: 44)
    private static let outlinePadding: CGFloat = 6
    private static let cornerRadius: CGFloat = 10
    private static let lineWidth: CGFloat = 3
    /// Share of the new Vision rect taken per frame (exponential smoothing). At
    /// ~30 analysed frames/s this settles within ~0.1 s yet removes most jitter.
    private static let smoothing: CGFloat = 0.45
    /// A move larger than this (relative to the code size) is a different
    /// position, not jitter: the outline jumps there instead of gliding.
    private static let snapDistanceRatio: CGFloat = 1.5
    /// Path changes animate over about two analysed frames.
    private static let glideDuration: CFTimeInterval = 0.08
    private static let appearDuration: CFTimeInterval = 0.15
    private static let badgeSize: CGFloat = 20

    private(set) var candidates: [Candidate] = []
    private var outlines: [BarcodeCandidateKey: OutlineLayers] = [:]
    private var smoothedRects: [BarcodeCandidateKey: CGRect] = [:]

    /// Takes Vision-derived rects; stores and draws the smoothed ones.
    func update(_ incoming: [Candidate]) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let keys = Set(incoming.map(\.key))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (key, outline) in outlines where !keys.contains(key) {
            outline.container.removeFromSuperlayer()
            outlines[key] = nil
            smoothedRects[key] = nil
        }

        var drawn: [Candidate] = []
        for candidate in incoming {
            let rect = smoothedRect(for: candidate)
            drawn.append(Candidate(key: candidate.key, rect: rect, isAdded: candidate.isAdded))

            let outline: OutlineLayers
            let isNew: Bool
            if let existing = outlines[candidate.key] {
                outline = existing
                isNew = false
            } else {
                outline = OutlineLayers()
                outline.container.frame = bounds
                layer.addSublayer(outline.container)
                outlines[candidate.key] = outline
                isNew = true
            }
            outline.container.frame = bounds
            outline.apply(
                outlineRect: Self.outlineRect(for: rect),
                isAdded: candidate.isAdded,
                animated: !isNew && !reduceMotion,
                duration: Self.glideDuration
            )
            if isNew, !reduceMotion {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0
                fade.toValue = 1
                fade.duration = Self.appearDuration
                outline.container.add(fade, forKey: "appear")
            }
        }
        candidates = drawn
        CATransaction.commit()
    }

    /// Marks the tapped code as chosen and hides the others (single scans).
    func highlight(_ key: BarcodeCandidateKey) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (candidateKey, outline) in outlines where candidateKey != key {
            outline.container.removeFromSuperlayer()
            outlines[candidateKey] = nil
            smoothedRects[candidateKey] = nil
        }
        if let outline = outlines[key], let rect = candidates.first(where: { $0.key == key })?.rect {
            outline.apply(outlineRect: Self.outlineRect(for: rect), isAdded: false, animated: false, duration: 0)
            outline.markChosen()
        }
        candidates = candidates.filter { $0.key == key }
        CATransaction.commit()
    }

    /// The selectable candidate whose tap target contains `point`; overlapping
    /// targets resolve to the code whose centre is nearest. A tap just outside
    /// every target still picks the nearest code within `nearMissDistance`.
    func candidate(at point: CGPoint) -> BarcodeCandidateKey? {
        let selectable = candidates.filter { !$0.isAdded }
        let byDistance = { (lhs: Candidate, rhs: Candidate) in
            Self.distance(lhs.rect, point) < Self.distance(rhs.rect, point)
        }
        if let hit = selectable.filter({ Self.tapTarget(for: $0.rect).contains(point) }).min(by: byDistance) {
            return hit.key
        }
        return selectable
            .filter { Self.tapTarget(for: $0.rect).insetBy(dx: -Self.nearMissDistance, dy: -Self.nearMissDistance).contains(point) }
            .min(by: byDistance)?
            .key
    }

    static func tapTarget(for rect: CGRect) -> CGRect {
        let padded = rect.insetBy(dx: -tapTargetPadding, dy: -tapTargetPadding)
        let growX = max(0, minimumTapTargetSize - padded.width) / 2
        let growY = max(0, minimumTapTargetSize - padded.height) / 2
        return padded.insetBy(dx: -growX, dy: -growY)
    }

    private func smoothedRect(for candidate: Candidate) -> CGRect {
        let target = candidate.rect
        guard let previous = smoothedRects[candidate.key] else {
            smoothedRects[candidate.key] = target
            return target
        }
        let size = max(target.width, target.height, 1)
        let moved = hypot(target.midX - previous.midX, target.midY - previous.midY)
        let resized = max(target.width / max(previous.width, 1), previous.width / max(target.width, 1),
                          target.height / max(previous.height, 1), previous.height / max(target.height, 1))
        let next: CGRect
        if moved > size * Self.snapDistanceRatio || resized > 2 {
            next = target
        } else {
            let a = Self.smoothing
            next = CGRect(
                x: previous.minX + (target.minX - previous.minX) * a,
                y: previous.minY + (target.minY - previous.minY) * a,
                width: previous.width + (target.width - previous.width) * a,
                height: previous.height + (target.height - previous.height) * a
            )
        }
        smoothedRects[candidate.key] = next
        return next
    }

    /// Tight around the code, but never smaller than `minimumOutlineSize`.
    private static func outlineRect(for rect: CGRect) -> CGRect {
        let padded = rect.insetBy(dx: -outlinePadding, dy: -outlinePadding)
        let growX = max(0, minimumOutlineSize.width - padded.width) / 2
        let growY = max(0, minimumOutlineSize.height - padded.height) / 2
        return padded.insetBy(dx: -growX, dy: -growY).integral
    }

    private static func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(rect.midX - point.x, rect.midY - point.y)
    }

    /// Layers for one code: a subtle rounded fill with a thin rim, corner
    /// brackets with a consistent line weight, and (for codes already added to
    /// a batch) a check badge. Added codes differ by shape (full dashed outline
    /// and badge instead of brackets), not only by colour.
    private final class OutlineLayers {
        let container = CALayer()
        private let fill = CAShapeLayer()
        private let brackets = CAShapeLayer()
        private let badge = CALayer()

        init() {
            fill.lineWidth = 1
            fill.shadowColor = UIColor.black.cgColor
            fill.shadowOpacity = 0.35
            fill.shadowRadius = 3
            fill.shadowOffset = .zero

            brackets.fillColor = nil
            brackets.lineWidth = BarcodeCandidateOverlayView.lineWidth
            brackets.lineCap = .round
            brackets.lineJoin = .round
            // A soft dark halo keeps the brackets visible on white labels.
            brackets.shadowColor = UIColor.black.cgColor
            brackets.shadowOpacity = 0.5
            brackets.shadowRadius = 2
            brackets.shadowOffset = .zero

            let size = BarcodeCandidateOverlayView.badgeSize
            badge.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
                .applying(UIImage.SymbolConfiguration(paletteColors: [.white, .systemGreen]))
            let symbol = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)?
                .withRenderingMode(.alwaysOriginal)
            let image = UIGraphicsImageRenderer(size: badge.bounds.size).image { _ in
                symbol?.draw(in: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            }
            badge.contents = image.cgImage
            badge.contentsScale = image.scale
            badge.contentsGravity = .resizeAspect
            badge.isHidden = true

            container.addSublayer(fill)
            container.addSublayer(brackets)
            container.addSublayer(badge)
        }

        func apply(outlineRect rect: CGRect, isAdded: Bool, animated: Bool, duration: CFTimeInterval) {
            let radius = min(BarcodeCandidateOverlayView.cornerRadius, rect.height / 3)
            let fillPath = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
            let bracketPath = Self.bracketPath(in: rect, radius: radius)

            if isAdded {
                fill.fillColor = UIColor.systemGreen.withAlphaComponent(0.22).cgColor
                fill.strokeColor = UIColor.systemGreen.cgColor
                fill.lineWidth = BarcodeCandidateOverlayView.lineWidth - 1
                fill.lineDashPattern = [6, 4]
                brackets.isHidden = true
                badge.isHidden = false
            } else {
                fill.fillColor = UIColor.white.withAlphaComponent(0.14).cgColor
                fill.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
                fill.lineWidth = 1
                fill.lineDashPattern = nil
                brackets.strokeColor = UIColor.systemYellow.cgColor
                brackets.isHidden = false
                badge.isHidden = true
            }

            let badgePosition = CGPoint(x: rect.maxX - 2, y: rect.minY + 2)
            if animated {
                glide(fill, keyPath: "path", to: fillPath, duration: duration)
                glide(fill, keyPath: "shadowPath", to: fillPath, duration: duration)
                glide(brackets, keyPath: "path", to: bracketPath, duration: duration)
                glide(badge, keyPath: "position", to: NSValue(cgPoint: badgePosition), duration: duration)
            }
            fill.path = fillPath
            fill.shadowPath = fillPath
            brackets.path = bracketPath
            badge.position = badgePosition
        }

        /// The chosen code in a single scan: solid green, like before.
        func markChosen() {
            fill.fillColor = UIColor.systemGreen.withAlphaComponent(0.25).cgColor
            fill.strokeColor = UIColor.systemGreen.cgColor
            fill.lineWidth = BarcodeCandidateOverlayView.lineWidth
            fill.lineDashPattern = nil
            brackets.isHidden = true
        }

        /// Animates from what is on screen now, so a new frame arriving mid-glide
        /// continues smoothly instead of restarting from the old target.
        private func glide(_ layer: CALayer, keyPath: String, to value: Any, duration: CFTimeInterval) {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)
            animation.toValue = value
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(animation, forKey: keyPath)
        }

        private static func bracketPath(in rect: CGRect, radius: CGFloat) -> CGPath {
            let arm = min(max(min(rect.width, rect.height) * 0.3, 10), 22)
            let path = UIBezierPath()
            // Top left
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), controlPoint: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
            // Top right
            path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), controlPoint: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
            // Bottom right
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), controlPoint: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
            // Bottom left
            path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), controlPoint: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
            return path.cgPath
        }
    }
}

/// VoiceOver element for one outlined code; activating it selects that code.
final class BarcodeCandidateAccessibilityElement: UIAccessibilityElement {
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}
