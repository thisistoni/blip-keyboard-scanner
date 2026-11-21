import UIKit

/// Draws an outline around each selectable code on the camera preview and
/// resolves taps to the nearest one. It does not receive touches itself; the
/// scanner view's tap recognizer asks it via `candidate(at:)`, so pinch-to-zoom
/// keeps working everywhere.
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
    private static let outlinePadding: CGFloat = 6
    private static let outlineCornerRadius: CGFloat = 8
    private static let appearDuration: CFTimeInterval = 0.15

    private(set) var candidates: [Candidate] = []
    private var outlineLayers: [BarcodeCandidateKey: CAShapeLayer] = [:]

    func update(_ candidates: [Candidate]) {
        self.candidates = candidates
        let keys = Set(candidates.map(\.key))

        CATransaction.begin()
        // Outlines follow the codes frame by frame; implicit animations would lag behind.
        CATransaction.setDisableActions(true)
        for (key, layer) in outlineLayers where !keys.contains(key) {
            layer.removeFromSuperlayer()
            outlineLayers[key] = nil
        }
        for candidate in candidates {
            let outline: CAShapeLayer
            if let existing = outlineLayers[candidate.key] {
                outline = existing
            } else {
                outline = Self.makeOutlineLayer()
                layer.addSublayer(outline)
                outlineLayers[candidate.key] = outline
                if !UIAccessibility.isReduceMotionEnabled {
                    let fade = CABasicAnimation(keyPath: "opacity")
                    fade.fromValue = 0
                    fade.toValue = 1
                    fade.duration = Self.appearDuration
                    outline.add(fade, forKey: "appear")
                }
            }
            Self.applyStyle(to: outline, isAdded: candidate.isAdded)
            outline.path = UIBezierPath(
                roundedRect: candidate.rect.insetBy(dx: -Self.outlinePadding, dy: -Self.outlinePadding),
                cornerRadius: Self.outlineCornerRadius
            ).cgPath
        }
        CATransaction.commit()
    }

    /// Marks the tapped code as chosen and hides the others.
    func highlight(_ key: BarcodeCandidateKey) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (candidateKey, outline) in outlineLayers {
            if candidateKey == key {
                outline.strokeColor = UIColor.systemGreen.cgColor
                outline.fillColor = UIColor.systemGreen.withAlphaComponent(0.25).cgColor
            } else {
                outline.removeFromSuperlayer()
                outlineLayers[candidateKey] = nil
            }
        }
        candidates = candidates.filter { $0.key == key }
        CATransaction.commit()
    }

    /// The candidate whose tap target contains `point`; overlapping targets
    /// resolve to the code whose centre is nearest.
    func candidate(at point: CGPoint) -> BarcodeCandidateKey? {
        candidates
            .filter { !$0.isAdded && Self.tapTarget(for: $0.rect).contains(point) }
            .min { Self.distance($0.rect, point) < Self.distance($1.rect, point) }?
            .key
    }

    static func tapTarget(for rect: CGRect) -> CGRect {
        let padded = rect.insetBy(dx: -tapTargetPadding, dy: -tapTargetPadding)
        let growX = max(0, minimumTapTargetSize - padded.width) / 2
        let growY = max(0, minimumTapTargetSize - padded.height) / 2
        return padded.insetBy(dx: -growX, dy: -growY)
    }

    private static func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(rect.midX - point.x, rect.midY - point.y)
    }

    /// Selectable codes are yellow; codes already in the batch list are green,
    /// like the chosen code in a single scan, with a dashed line so the
    /// difference does not rely on colour alone.
    private static func applyStyle(to outline: CAShapeLayer, isAdded: Bool) {
        if isAdded {
            outline.strokeColor = UIColor.systemGreen.cgColor
            outline.fillColor = UIColor.systemGreen.withAlphaComponent(0.25).cgColor
            outline.lineDashPattern = [8, 5]
        } else {
            outline.strokeColor = UIColor.systemYellow.cgColor
            outline.fillColor = UIColor.white.withAlphaComponent(0.12).cgColor
            outline.lineDashPattern = nil
        }
    }

    private static func makeOutlineLayer() -> CAShapeLayer {
        let outline = CAShapeLayer()
        applyStyle(to: outline, isAdded: false)
        outline.lineWidth = 3
        outline.lineJoin = .round
        // A soft dark halo keeps the outline visible on white labels.
        outline.shadowColor = UIColor.black.cgColor
        outline.shadowOpacity = 0.5
        outline.shadowRadius = 2
        outline.shadowOffset = .zero
        return outline
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
