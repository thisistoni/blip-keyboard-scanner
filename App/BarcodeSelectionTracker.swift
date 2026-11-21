import Foundation

/// Identity of a decoded code. Two observations are the same candidate only when
/// both the payload and the symbology match, so an EAN-13 and a Code 128 carrying
/// the same digits are still offered as separate choices.
struct BarcodeCandidateKey: Hashable {
    let value: String
    let symbology: String
}

enum BarcodeSelectionDecision: Equatable {
    /// Nothing to accept or offer yet; any outlines should be hidden.
    case waiting
    /// Accept this code now through the normal scan path.
    case accept(BarcodeCandidateKey)
    /// Several codes are (or were just) visible: outline these and wait for a tap.
    case choose([BarcodeCandidateKey])
}

/// Decides, frame by frame, whether to auto-accept a single code or ask the user
/// to pick one of several. It is pure (Foundation only) so it can be tested
/// without a camera; the scanner feeds it the filtered candidates of every
/// analysed frame together with the frame timestamp.
///
/// States:
/// - `idle`: no candidate seen.
/// - `confirming`: one code was seen and no other code since. It is accepted
///   after `singleConfirmationFrames` analysed frames (counting the first sighting
///   and later frames with that code or with no code), or after
///   `singleConfirmationMinimumFrames` frames once `singleConfirmationInterval` has
///   passed (bounds the delay when frames arrive slowly). Any other code in one of
///   those frames switches to `selecting` with both codes offered.
/// - `selecting`: two or more distinct codes were seen. Never auto-accepts while
///   other codes keep appearing. Each code stays offered for `candidateRetention`
///   after its last sighting so a one-frame Vision dropout does not make its
///   outline flicker. If only one code is seen for `multiToSingleFallbackInterval`
///   (dropouts up to `candidateRetention` are tolerated, any other code restarts
///   the timer) it is accepted,
///   so covering the other codes with a hand still works. With no code seen for
///   `selectingExitInterval` the tracker returns to `idle`.
/// - `finished`: a code was accepted (automatically or by tap); later frames are ignored.
struct BarcodeSelectionTracker {
    /// Analysed frames, starting with the first sighting, that must pass without
    /// any other code before a lone code is auto-accepted. Vision commonly decodes
    /// a neighbouring code one or two frames after the first, so three frames (two
    /// extra, ~66 ms at 30 fps) catch that.
    static let singleConfirmationFrames = 3
    /// Lower frame bound used together with `singleConfirmationInterval`.
    static let singleConfirmationMinimumFrames = 2
    /// When analysis runs slowly (dim light, older devices) two frames spanning at
    /// least this long are enough, keeping the added latency near 0.1 s.
    static let singleConfirmationInterval: TimeInterval = 0.1
    /// How long a code stays outlined after Vision last reported it. Covers typical
    /// one-to-several-frame dropouts without leaving stale outlines on screen.
    static let candidateRetention: TimeInterval = 0.4
    /// After several codes were seen, one code must be alone this long before it is
    /// auto-accepted. Clearly longer than both `candidateRetention` and a normal
    /// Vision dropout, yet short enough that hiding the other codes feels responsive.
    static let multiToSingleFallbackInterval: TimeInterval = 0.8
    /// With no code at all for this long, the selection is abandoned and the next
    /// lone code goes through the fast single-code path again.
    static let selectingExitInterval: TimeInterval = 1.0

    private enum State: Equatable {
        case idle
        case confirming(key: BarcodeCandidateKey, firstSeen: TimeInterval, frames: Int)
        case selecting(Selection)
        case finished
    }

    private struct Sighting: Equatable {
        let key: BarcodeCandidateKey
        var lastSeen: TimeInterval
    }

    private struct LoneRun: Equatable {
        let key: BarcodeCandidateKey
        let since: TimeInterval
        var lastSeen: TimeInterval
    }

    private struct Selection: Equatable {
        /// Codes in first-seen order with the time each was last reported.
        var sightings: [Sighting]
        var lastAnyCodeTime: TimeInterval
        /// The current run of frames that showed exactly one code.
        var lone: LoneRun?
    }

    private var state: State = .idle

    var isFinished: Bool { state == .finished }

    /// Feeds the candidates of one analysed frame (after scan-area and profile filters).
    mutating func process(_ frameCandidates: [BarcodeCandidateKey], at time: TimeInterval) -> BarcodeSelectionDecision {
        var distinct: [BarcodeCandidateKey] = []
        for key in frameCandidates where !distinct.contains(key) {
            distinct.append(key)
        }

        switch state {
        case .finished:
            return .waiting

        case .idle:
            return start(with: distinct, at: time)

        case let .confirming(key, firstSeen, frames):
            // Any other code during confirmation, in the same frame or a later
            // one, means there is a choice to make.
            if distinct.contains(where: { $0 != key }) {
                return enterSelecting(with: distinct.contains(key) ? distinct : [key] + distinct, at: time)
            }
            // A frame without the code still counts: Vision analysed it and found
            // no neighbour. Requiring consecutive sightings would stop a worn or
            // dim code that only decodes now and then from ever being accepted.
            let frameCount = frames + 1
            if frameCount >= Self.singleConfirmationFrames
                || (frameCount >= Self.singleConfirmationMinimumFrames
                    && time - firstSeen >= Self.singleConfirmationInterval) {
                state = .finished
                return .accept(key)
            }
            state = .confirming(key: key, firstSeen: firstSeen, frames: frameCount)
            return .waiting

        case var .selecting(selection):
            for key in distinct {
                if let index = selection.sightings.firstIndex(where: { $0.key == key }) {
                    selection.sightings[index].lastSeen = time
                } else {
                    selection.sightings.append(Sighting(key: key, lastSeen: time))
                }
            }
            selection.sightings.removeAll { time - $0.lastSeen > Self.candidateRetention }

            if distinct.isEmpty {
                if time - selection.lastAnyCodeTime >= Self.selectingExitInterval {
                    state = .idle
                    return .waiting
                }
            } else {
                selection.lastAnyCodeTime = time
            }

            if distinct.count == 1, let only = distinct.first {
                // A lone run continues only while that code keeps being reported;
                // reappearing after a long gap (camera moved away) starts over.
                if var lone = selection.lone, lone.key == only,
                   time - lone.lastSeen <= Self.candidateRetention {
                    if time - lone.since >= Self.multiToSingleFallbackInterval {
                        state = .finished
                        return .accept(only)
                    }
                    lone.lastSeen = time
                    selection.lone = lone
                } else {
                    selection.lone = LoneRun(key: only, since: time, lastSeen: time)
                }
            } else if distinct.count > 1 {
                selection.lone = nil
            }

            state = .selecting(selection)
            let offered = selection.sightings.map(\.key)
            return offered.isEmpty ? .waiting : .choose(offered)
        }
    }

    /// Records the user's tap on an outlined code. Returns false when a code was
    /// already accepted, so a tap can never race a second result through.
    mutating func finishBySelection() -> Bool {
        guard state != .finished else { return false }
        state = .finished
        return true
    }

    private mutating func start(with distinct: [BarcodeCandidateKey], at time: TimeInterval) -> BarcodeSelectionDecision {
        switch distinct.count {
        case 0:
            state = .idle
            return .waiting
        case 1:
            state = .confirming(key: distinct[0], firstSeen: time, frames: 1)
            return .waiting
        default:
            return enterSelecting(with: distinct, at: time)
        }
    }

    private mutating func enterSelecting(with distinct: [BarcodeCandidateKey], at time: TimeInterval) -> BarcodeSelectionDecision {
        state = .selecting(Selection(
            sightings: distinct.map { Sighting(key: $0, lastSeen: time) },
            lastAnyCodeTime: time,
            lone: nil
        ))
        return .choose(distinct)
    }
}
