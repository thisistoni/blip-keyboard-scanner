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
/// - `confirming`: one code was seen and no other code since. It is accepted on
///   the first analysed frame at least `singleConfirmationInterval` after its first
///   sighting once it has been reported in at least `singleConfirmationSightings`
///   frames (never on the first frame itself, and never on a single read, which
///   may be a misread). Frames with that code or with no code at all keep the
///   confirmation going; any other code switches to `selecting` with both codes
///   offered.
/// - `selecting`: two or more distinct codes were seen. Never auto-accepts while
///   other codes keep appearing. Each code stays offered for `candidateRetention`
///   after its last sighting so a one-frame Vision dropout does not make its
///   outline flicker. If only one code is seen for `multiToSingleFallbackInterval`
///   (dropouts up to `candidateRetention` are tolerated, any other code restarts
///   the timer) it is accepted,
///   so covering the other codes with a hand still works. With no code seen for
///   `selectingExitInterval` the tracker returns to `idle`.
/// - `finished`: a code was accepted (automatically or by tap); later frames are ignored.
///
/// Batch scanning creates the tracker with `continuesAfterAccept`. It then never
/// finishes: an accepted code is handed to a `BarcodeRescanGuard`, and while the
/// guard blocks a code it still counts as a visible code (so a label with several
/// codes keeps asking for a choice) but can be neither auto-accepted nor tapped.
/// Accepting from `confirming` returns to `idle`; accepting from `selecting`
/// stays in `selecting`, so the remaining codes still need a tap. With no
/// acceptable code for `selectingExitInterval` the tracker returns to `idle`.
///
/// Moving from item to item: a code that was auto-added as a lone code (from
/// `confirming`) belongs to the previous item. While it stays in view it is
/// ignored when deciding about new codes, so one new code next to it is
/// confirmed and added without a tap, and two or more new codes are still a
/// choice. Codes added from a choice (by tap or by the lone fallback) came from
/// the same label as the codes offered with them, so they keep counting and the
/// remaining codes stay tap-only while they are in view.
/// Without `continuesAfterAccept` the guard stays empty and every rule above is
/// exactly the single-scan behaviour.
struct BarcodeSelectionTracker {
    /// How long a lone code must stay without any other code before it is
    /// auto-accepted. Time-based because Vision does not decode every frame:
    /// measured on an iPhone 16 Pro Max with two EAN-13 products side by side
    /// (4K, ~31 analysed frames/s), only about 45 % of the frames that showed a
    /// code showed both, and the longest gap between frames with any code was
    /// 0.27 s. Waiting 0.3 s covers that gap and spans several frames, so a
    /// neighbour that Vision decodes late is usually seen before the first code
    /// is taken, while a lone code still feels immediate. (A frame-count rule
    /// accepted after 66 ms on the device, before the neighbour was ever decoded.)
    static let singleConfirmationInterval: TimeInterval = 0.3
    /// Analysed frames that must report a lone code before it is auto-accepted.
    /// On the device a code was once read in exactly one frame among hundreds of
    /// reads of two other codes, likely a misread. There is deliberately no
    /// timeout that accepts on one sighting: a worn code waits for its second
    /// decode. (Taps are explicit and need no second sighting; the lone fallback
    /// in `selecting` already needs a run of sightings spanning 0.8 s.)
    static let singleConfirmationSightings = 2
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
        case confirming(key: BarcodeCandidateKey, firstSeen: TimeInterval, sightings: Int)
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
    private var rescanGuard = BarcodeRescanGuard()
    /// Added codes that were auto-accepted as lone codes (batch only).
    private var addedAlone: Set<BarcodeCandidateKey> = []
    private var latestFrameTime: TimeInterval?

    /// True for batch scanning: accepting a code does not finish the tracker.
    let continuesAfterAccept: Bool

    init(continuesAfterAccept: Bool = false) {
        self.continuesAfterAccept = continuesAfterAccept
    }

    var isFinished: Bool { state == .finished }

    /// Codes accepted in this batch that may not be accepted again yet. Always
    /// empty for single scans.
    var addedKeys: Set<BarcodeCandidateKey> { rescanGuard.blockedKeys }

    /// Added codes reported within `candidateRetention` of the latest frame, so
    /// the scanner can keep marking them as added while they stay in view.
    var visibleAddedKeys: Set<BarcodeCandidateKey> {
        guard let latestFrameTime else { return [] }
        return rescanGuard.keys(seenSince: latestFrameTime - Self.candidateRetention)
    }

    /// Feeds the candidates of one analysed frame (after scan-area and profile filters).
    mutating func process(_ frameCandidates: [BarcodeCandidateKey], at time: TimeInterval) -> BarcodeSelectionDecision {
        let distinct = Self.distinct(frameCandidates)
        latestFrameTime = time
        rescanGuard.observe(distinct, at: time)
        addedAlone.formIntersection(rescanGuard.blockedKeys)
        let eligible = distinct.filter { !rescanGuard.isBlocked($0) }
        // Codes that decide between confirming and choosing: everything except
        // lone-added codes of a previous item.
        let relevant = distinct.filter { !addedAlone.contains($0) }

        switch state {
        case .finished:
            return .waiting

        case .idle:
            return start(with: distinct, eligible: eligible, relevant: relevant, at: time)

        case let .confirming(key, firstSeen, sightings):
            // Any other code during confirmation, in the same frame or a later
            // one, means there is a choice to make. In a batch this includes a
            // code added from a choice that is still in view, but not a lone-added
            // code of a previous item.
            if relevant.contains(where: { $0 != key }) {
                return enterSelecting(with: distinct.contains(key) ? distinct : [key] + distinct, at: time)
            }
            // A frame without the code still counts: Vision analysed it and found
            // no neighbour. Requiring consecutive sightings would stop a worn or
            // dim code that only decodes now and then from ever being accepted.
            // The first sighting itself never accepts (it starts `confirming`).
            let seen = sightings + (distinct.contains(key) ? 1 : 0)
            if time - firstSeen >= Self.singleConfirmationInterval,
               seen >= Self.singleConfirmationSightings {
                state = continuesAfterAccept ? .idle : .finished
                if continuesAfterAccept {
                    addedAlone.insert(key)
                }
                return accept(key, at: time)
            }
            state = .confirming(key: key, firstSeen: firstSeen, sightings: seen)
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

            // Codes that were already added keep their outline but no longer keep
            // the selection alive on their own.
            if eligible.isEmpty {
                if time - selection.lastAnyCodeTime >= Self.selectingExitInterval {
                    state = .idle
                    return .waiting
                }
            } else {
                selection.lastAnyCodeTime = time
            }

            if relevant.count == 1, let only = relevant.first, !rescanGuard.isBlocked(only) {
                // A lone run continues only while that code keeps being reported;
                // reappearing after a long gap (camera moved away) starts over.
                if var lone = selection.lone, lone.key == only,
                   time - lone.lastSeen <= Self.candidateRetention {
                    if time - lone.since >= Self.multiToSingleFallbackInterval {
                        if continuesAfterAccept {
                            selection.lone = nil
                            state = .selecting(selection)
                        } else {
                            state = .finished
                        }
                        return accept(only, at: time)
                    }
                    lone.lastSeen = time
                    selection.lone = lone
                } else {
                    selection.lone = LoneRun(key: only, since: time, lastSeen: time)
                }
            } else if !relevant.isEmpty {
                // Several codes, or only one added from a choice: nothing is alone.
                selection.lone = nil
            }

            state = .selecting(selection)
            let offered = selection.sightings.map(\.key)
            guard offered.contains(where: { !rescanGuard.isBlocked($0) }) else { return .waiting }
            return .choose(offered)
        }
    }

    /// Records the user's tap on an outlined code. Returns false when a code was
    /// already accepted, so a tap can never race a second result through.
    mutating func finishBySelection() -> Bool {
        guard state != .finished else { return false }
        state = .finished
        return true
    }

    /// Records a tap on `key`. Single scans finish exactly like
    /// `finishBySelection()`. Batch scans accept the code unless it was already
    /// added and is still blocked, and keep running for the remaining codes.
    mutating func select(_ key: BarcodeCandidateKey) -> Bool {
        guard continuesAfterAccept else { return finishBySelection() }
        guard !rescanGuard.isBlocked(key) else { return false }
        rescanGuard.block(key, at: latestFrameTime ?? 0)
        if case var .selecting(selection) = state {
            selection.lone = nil
            state = .selecting(selection)
        } else {
            // A tap can only follow an offered choice; restart from scratch if
            // the selection has already been abandoned meanwhile.
            state = .idle
        }
        return true
    }

    /// Feeds a frame while the batch cannot take more codes: keeps the re-scan
    /// guard up to date (so a code still in view is not re-added when collection
    /// resumes) but never accepts or offers anything.
    mutating func observeWithoutAccepting(_ frameCandidates: [BarcodeCandidateKey], at time: TimeInterval) {
        latestFrameTime = time
        rescanGuard.observe(Self.distinct(frameCandidates), at: time)
        if state != .finished {
            state = .idle
        }
    }

    private mutating func accept(_ key: BarcodeCandidateKey, at time: TimeInterval) -> BarcodeSelectionDecision {
        if continuesAfterAccept {
            rescanGuard.block(key, at: time)
        }
        return .accept(key)
    }

    private mutating func start(
        with distinct: [BarcodeCandidateKey],
        eligible: [BarcodeCandidateKey],
        relevant: [BarcodeCandidateKey],
        at time: TimeInterval
    ) -> BarcodeSelectionDecision {
        // Nothing new to take: no code, or only codes that were already added.
        guard !eligible.isEmpty else {
            state = .idle
            return .waiting
        }
        if relevant.count == 1 {
            // One new code, possibly next to lone-added codes of a previous item.
            state = .confirming(key: relevant[0], firstSeen: time, sightings: 1)
            return .waiting
        }
        // Several new codes, or a new code next to one added from a choice on
        // the same label: the user chooses.
        return enterSelecting(with: distinct, at: time)
    }

    private static func distinct(_ frameCandidates: [BarcodeCandidateKey]) -> [BarcodeCandidateKey] {
        var distinct: [BarcodeCandidateKey] = []
        for key in frameCandidates where !distinct.contains(key) {
            distinct.append(key)
        }
        return distinct
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

/// Batch-scan re-scan guard. A code (payload + symbology) that was added stays
/// blocked while it keeps appearing in the analysed frames, and is released only
/// after it has been absent from them for `reentryAbsenceInterval`: it left the
/// view and came back. Scanning the same item twice on purpose therefore works,
/// while a code that simply stays in view is added once. There is no timer that
/// releases a code that is still visible.
struct BarcodeRescanGuard {
    /// How long an added code must be missing from every analysed frame before
    /// it can be added again. Well above `candidateRetention` (0.4 s, the typical
    /// Vision dropout) and above `selectingExitInterval`, so a worn or briefly
    /// blurred code that is still in view is not added a second time, yet short
    /// enough that taking an item away and presenting it again feels natural.
    static let reentryAbsenceInterval: TimeInterval = 1.5

    private var lastSeen: [BarcodeCandidateKey: TimeInterval] = [:]

    var blockedKeys: Set<BarcodeCandidateKey> { Set(lastSeen.keys) }

    func isBlocked(_ key: BarcodeCandidateKey) -> Bool {
        lastSeen[key] != nil
    }

    mutating func block(_ key: BarcodeCandidateKey, at time: TimeInterval) {
        lastSeen[key] = time
    }

    func keys(seenSince time: TimeInterval) -> Set<BarcodeCandidateKey> {
        Set(lastSeen.filter { $0.value >= time }.keys)
    }

    /// Releases codes that were absent long enough, then refreshes those seen in
    /// this frame. The order matters: a code reappearing after a long absence is
    /// released by this frame, not kept blocked by it.
    mutating func observe(_ frameKeys: [BarcodeCandidateKey], at time: TimeInterval) {
        guard !lastSeen.isEmpty else { return }
        lastSeen = lastSeen.filter { time - $0.value < Self.reentryAbsenceInterval }
        for key in frameKeys where lastSeen[key] != nil {
            lastSeen[key] = time
        }
    }
}
