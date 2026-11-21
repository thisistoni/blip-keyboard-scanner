import Foundation

/// Identity of a decoded code. The trackers treat keys that differ in payload or
/// symbology as different codes; the scanner reports one key per payload within
/// a session (the symbology it was first seen as), because one label can be
/// decoded under two symbologies.
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
/// to pick one of several (single scans; batch scans use `BarcodeBatchTracker`).
/// It is pure (Foundation only) so it can be tested without a camera; the
/// scanner feeds it the filtered candidates of every analysed frame together
/// with the frame timestamp.
///
/// All intervals are measured in scanning time (`BarcodeScanClock`), which
/// does not run while no frames are analysed.
///
/// States:
/// - `idle`: no candidate seen.
/// - `confirming`: one code was seen and no other code since. It is accepted on
///   the first analysed frame at least `singleConfirmationInterval` after its first
///   sighting once it has been reported in at least `singleConfirmationSightings`
///   frames (never on the first frame itself, and never on a single read, which
///   may be a misread) and within `acceptanceRecency` of its latest sighting, so
///   a code that already left the view waits for its next read instead of being
///   entered. Frames with that code or with no code at all keep the
///   confirmation going; any other code switches to `selecting` with both codes
///   offered, unless the confirming code was not seen for `candidateRetention`:
///   then it is stale and the other code starts a confirmation of its own.
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
    /// A lone code is only accepted while it was reported this recently. Longer
    /// than a few dropped frames, so a steadily held code is accepted on time;
    /// short enough that a code already panned past is not.
    static let acceptanceRecency: TimeInterval = 0.15
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
        case confirming(key: BarcodeCandidateKey, firstSeen: TimeInterval, lastSeen: TimeInterval, sightings: Int)
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
    private var clock = BarcodeScanClock()

    var isFinished: Bool { state == .finished }

    /// Feeds the candidates of one analysed frame (after scan-area and profile filters).
    mutating func process(_ frameCandidates: [BarcodeCandidateKey], at frameTime: TimeInterval) -> BarcodeSelectionDecision {
        let distinct = frameCandidates.distinctKeys
        let time = clock.scanTime(forFrameAt: frameTime)

        switch state {
        case .finished:
            return .waiting

        case .idle:
            return begin(with: distinct, at: time)

        case let .confirming(key, firstSeen, lastSeen, sightings):
            if distinct.contains(where: { $0 != key }) {
                // A code not reported for the retention window was a glimpse or a
                // misread; it must not turn the next code into a choice.
                if !distinct.contains(key), time - lastSeen > Self.candidateRetention {
                    return begin(with: distinct, at: time)
                }
                // Any other code during confirmation, in the same frame or a
                // later one, means there is a choice to make.
                return enterSelecting(with: distinct.contains(key) ? distinct : [key] + distinct, at: time)
            }
            // A frame without the code still counts: Vision analysed it and found
            // no neighbour. Requiring consecutive sightings would stop a worn or
            // dim code that only decodes now and then from ever being accepted.
            // The first sighting itself never accepts (it starts `confirming`).
            let isSeen = distinct.contains(key)
            let seen = sightings + (isSeen ? 1 : 0)
            let latestSighting = isSeen ? time : lastSeen
            // The code must still be there: one glimpsed in two frames while
            // panning past it is not entered after it has left the view.
            if time - firstSeen >= Self.singleConfirmationInterval,
               seen >= Self.singleConfirmationSightings,
               time - latestSighting <= Self.acceptanceRecency {
                state = .finished
                return .accept(key)
            }
            state = .confirming(key: key, firstSeen: firstSeen, lastSeen: latestSighting, sightings: seen)
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

    /// Records the user's tap on an outlined code. Returns true only while a
    /// choice is offered and `key` is one of the offered codes, so a tap that
    /// arrives after an auto-accept, or on an outline that just expired, does nothing.
    mutating func select(_ key: BarcodeCandidateKey) -> Bool {
        guard case let .selecting(selection) = state,
              selection.sightings.contains(where: { $0.key == key }) else { return false }
        state = .finished
        return true
    }

    /// The `idle` transition, also used when a stale confirmation is replaced.
    private mutating func begin(with distinct: [BarcodeCandidateKey], at time: TimeInterval) -> BarcodeSelectionDecision {
        switch distinct.count {
        case 0:
            state = .idle
            return .waiting
        case 1:
            state = .confirming(key: distinct[0], firstSeen: time, lastSeen: time, sightings: 1)
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

/// Batch scanning: every code in view is added, with no choice and no taps.
/// Each code that is not yet added is confirmed on its own, independently of
/// whatever else is visible, with the single-scan thresholds: it is added once
/// it has been reported in at least `singleConfirmationSightings` analysed
/// frames and `singleConfirmationInterval` has passed since its first sighting.
/// Several codes that become ready in one frame are all returned, in order of
/// first sighting. A confirmation that has not been reported for
/// `candidateRetention` is dropped, so a single misread does not linger and get
/// added on one more stray read later. Added codes go to a `BarcodeRescanGuard`.
/// All intervals are measured in scanning time (`BarcodeScanClock`).
struct BarcodeBatchTracker {
    private struct Pending: Equatable {
        let key: BarcodeCandidateKey
        let firstSeen: TimeInterval
        var lastSeen: TimeInterval
        var sightings: Int
    }

    /// Codes still confirming, in order of first sighting.
    private var pending: [Pending] = []
    private var rescanGuard = BarcodeRescanGuard()
    private var clock = BarcodeScanClock()
    private var latestScanTime: TimeInterval?
    /// Added codes whose list row was deleted: still blocked, but no longer
    /// marked as added. Always a subset of the blocked codes.
    private var removedKeys: Set<BarcodeCandidateKey> = []

    /// Codes added in this batch that may not be added again yet (including
    /// codes whose row was deleted since).
    var addedKeys: Set<BarcodeCandidateKey> { rescanGuard.blockedKeys }

    /// Added codes reported within `candidateRetention` of the latest frame, so
    /// the scanner can keep marking them as added while they stay in view.
    var visibleAddedKeys: Set<BarcodeCandidateKey> {
        guard let latestScanTime else { return [] }
        return rescanGuard.keys(seenSince: latestScanTime - BarcodeSelectionTracker.candidateRetention)
            .subtracting(removedKeys)
    }

    /// Codes being confirmed, in order of first sighting.
    var confirmingKeys: [BarcodeCandidateKey] { pending.map(\.key) }

    /// Feeds one analysed frame and returns the codes to add now, in order of
    /// first sighting. At most `capacity` codes are returned; ready codes beyond
    /// it stay pending (not blocked) until there is room again.
    mutating func process(
        _ frameCandidates: [BarcodeCandidateKey],
        at frameTime: TimeInterval,
        capacity: Int = .max
    ) -> [BarcodeCandidateKey] {
        let distinct = frameCandidates.distinctKeys
        let time = clock.scanTime(forFrameAt: frameTime)
        latestScanTime = time
        rescanGuard.observe(distinct, at: time)
        // A deleted code that was released is an ordinary code again.
        removedKeys.formIntersection(rescanGuard.blockedKeys)

        // Drop stale confirmations before counting this frame, so a code
        // reappearing after a long gap starts over with one sighting.
        pending.removeAll { time - $0.lastSeen > BarcodeSelectionTracker.candidateRetention }
        for key in distinct where !rescanGuard.isBlocked(key) {
            if let index = pending.firstIndex(where: { $0.key == key }) {
                pending[index].lastSeen = time
                pending[index].sightings += 1
            } else {
                pending.append(Pending(key: key, firstSeen: time, lastSeen: time, sightings: 1))
            }
        }

        var added: [BarcodeCandidateKey] = []
        for entry in pending where added.count < capacity {
            if entry.sightings >= BarcodeSelectionTracker.singleConfirmationSightings,
               time - entry.firstSeen >= BarcodeSelectionTracker.singleConfirmationInterval {
                added.append(entry.key)
            }
        }
        for key in added {
            rescanGuard.block(key, at: time)
        }
        pending.removeAll { added.contains($0.key) }
        return added
    }

    /// The user deleted the row of an added code. It stays blocked under the
    /// normal re-entry rule, so a code still in view is not added straight
    /// back, but it is no longer marked as added.
    mutating func markRemoved(_ key: BarcodeCandidateKey) {
        guard rescanGuard.isBlocked(key) else { return }
        removedKeys.insert(key)
    }

    /// The user undid a deletion. Only matters while the code is still blocked;
    /// once released, `removedKeys` no longer holds it and nothing changes.
    mutating func markRestored(_ key: BarcodeCandidateKey) {
        removedKeys.remove(key)
    }

    /// The list refused an added code (it was full). The code is released
    /// completely, so it is confirmed and added again once there is room.
    mutating func release(_ key: BarcodeCandidateKey) {
        rescanGuard.release(key)
        removedKeys.remove(key)
        pending.removeAll { $0.key == key }
    }
}

/// Turns frame timestamps into scanning time, which does not run while no
/// frames are analysed (screen locked, app switcher, a call, the camera
/// interrupted). Without it every timer would read such a pause as absence:
/// added codes still in view would be released and added a second time.
struct BarcodeScanClock {
    /// A longer gap between analysed frames is a pause, not a run of frames
    /// without a code. Frames are analysed ~31 times a second on the device, so
    /// this is far above any normal gap.
    static let pauseThreshold: TimeInterval = 0.5
    /// What a pause counts as. Below `candidateRetention` and every longer
    /// interval, so no timer fires because of one pause. Not zero, so a device
    /// that only manages a frame or two a second still makes progress instead
    /// of never confirming a code.
    static let pauseStep: TimeInterval = 0.25

    private var lastFrameTime: TimeInterval?
    private var elapsed: TimeInterval = 0

    mutating func scanTime(forFrameAt frameTime: TimeInterval) -> TimeInterval {
        if let lastFrameTime {
            let gap = frameTime - lastFrameTime
            // A clock running backwards adds nothing, so scanning time never decreases.
            elapsed += gap > Self.pauseThreshold ? Self.pauseStep : max(gap, 0)
        }
        lastFrameTime = frameTime
        return elapsed
    }
}

private extension Array where Element == BarcodeCandidateKey {
    /// The keys in order of first appearance, without repeats.
    var distinctKeys: [BarcodeCandidateKey] {
        var distinct: [BarcodeCandidateKey] = []
        for key in self where !distinct.contains(key) {
            distinct.append(key)
        }
        return distinct
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

    mutating func release(_ key: BarcodeCandidateKey) {
        lastSeen[key] = nil
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
