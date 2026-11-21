import Foundation

// Build and run with:
// xcrun swiftc App/BarcodeSelectionTracker.swift Tests/BarcodeSelectionTrackerTests.swift -o <tmp>/blip-selection-tests

@main
enum BarcodeSelectionTrackerTests {
    static let frame: TimeInterval = 1.0 / 30.0
    static let ean = BarcodeCandidateKey(value: "4012345678901", symbology: "VNBarcodeSymbologyEAN13")
    static let code128 = BarcodeCandidateKey(value: "LOT-2026-11", symbology: "VNBarcodeSymbologyCode128")
    static let qr = BarcodeCandidateKey(value: "https://example.com/item", symbology: "VNBarcodeSymbologyQR")

    /// Feeds frames at 30 fps from `start` and returns every decision.
    static func run(
        _ tracker: inout BarcodeSelectionTracker,
        _ frames: [[BarcodeCandidateKey]],
        start: TimeInterval = 0,
        interval: TimeInterval = frame
    ) -> [BarcodeSelectionDecision] {
        frames.enumerated().map { index, keys in
            tracker.process(keys, at: start + Double(index) * interval)
        }
    }

    static let confirm = BarcodeSelectionTracker.singleConfirmationInterval

    /// Number of 30 fps frames, starting with the first sighting, that safely
    /// spans the confirmation interval (one frame of margin, no exact boundary).
    static let confirmFrames = Int((confirm / frame).rounded(.up)) + 2

    /// Time of the single accept in `decisions` fed at `interval` from `start`.
    static func acceptTime(
        _ decisions: [BarcodeSelectionDecision],
        start: TimeInterval = 0,
        interval: TimeInterval = frame
    ) -> TimeInterval? {
        decisions.firstIndex { if case .accept = $0 { true } else { false } }
            .map { start + Double($0) * interval }
    }

    static func main() {
        singleStableCodeIsAcceptedAfterTheInterval()
        singleCodeAcceptedAfterIntervalWhenFramesAreSlow()
        neighbourDecodedLateIsStillOffered()
        duplicateObservationsOfOneCodeStaySingle()
        secondCodeArrivingOneFrameLateIsOffered()
        secondCodeArrivingTwoFramesLateIsOffered()
        multiStateToleratesFlicker()
        handCoverFallsBackToAutoAccept()
        briefDropoutOfNeighbourDoesNotAutoAccept()
        codesLeavingFrameClearOutlines()
        selectionAbandonedAfterLongEmptyPeriod()
        lateReappearanceRestartsLoneTimer()
        sameValueDifferentSymbologyIsDistinct()
        intermittentlyDecodedCodeIsStillAccepted()
        singleSightingIsNeverAutoAccepted()
        tapNeedsNoSecondSighting()
        loneFallbackNeedsSeveralSightings()
        differentLoneCodeDuringConfirmationIsOffered()
        tapFinishesOnce()
        singleModeSelectFinishesOnce()
        batchAddsCodeOnceWhileItStaysInView()
        batchTwoCodesInViewAreBothAddedInFirstSightingOrder()
        batchCodesReadyInTheSameFrameKeepFirstSightingOrder()
        batchThreeCodesAreAllAddedOnce()
        batchSingleMisreadIsNeverAdded()
        batchReaddsCodeAfterItLeftAndCameBack()
        batchShortAbsenceDoesNotReadd()
        batchFlickeringAddedCodeIsNotAddedTwice()
        batchMovingToNextCodeAddsIt()
        batchCapacityLimitsAddsAndKeepsTheRestPending()
        batchFullListKeepsCodesInViewBlocked()
        print("BarcodeSelectionTrackerTests passed")
    }

    static func singleStableCodeIsAcceptedAfterTheInterval() {
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, Array(repeating: [ean], count: confirmFrames + 5))
        precondition(decisions[0] == .waiting, "never on the first frame")
        guard let accepted = acceptTime(decisions) else { preconditionFailure("lone code must be accepted") }
        precondition(accepted > confirm - frame / 2, "accepted too early: \(accepted)")
        precondition(accepted < confirm + frame * 1.5, "accepted too late: \(accepted)")
        precondition(decisions.filter { $0 == .accept(ean) }.count == 1)
        // Later frames are ignored once a code is accepted.
        precondition(decisions.last == .waiting)
        precondition(tracker.isFinished)
    }

    static func singleCodeAcceptedAfterIntervalWhenFramesAreSlow() {
        var tracker = BarcodeSelectionTracker()
        // 8 fps analysis (0.125 s per frame): the fourth frame (0.375 s) is the
        // first one past the interval.
        let decisions = run(&tracker, [[ean], [ean], [ean], [ean], [ean]], interval: 0.125)
        precondition(decisions == [.waiting, .waiting, .waiting, .accept(ean), .waiting], "\(decisions)")
        // Even a very slow second frame never accepts on the first sighting.
        var single = BarcodeSelectionTracker()
        precondition(single.process([ean], at: 0) == .waiting)
        precondition(single.process([ean], at: 2) == .accept(ean))
    }

    static func neighbourDecodedLateIsStillOffered() {
        // As measured on the device: the second code shows up only in some
        // frames, here first 0.25 s after the first one, with empty frames between.
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[ean], [], [ean], [], [], [ean], [], [ean, code128]], interval: 0.25 / 7)
        precondition(!decisions.contains { if case .accept = $0 { true } else { false } }, "\(decisions)")
        precondition(decisions.last == .choose([ean, code128]))
    }

    static func duplicateObservationsOfOneCodeStaySingle() {
        var tracker = BarcodeSelectionTracker()
        let frames: [[BarcodeCandidateKey]] = (0..<confirmFrames).map { $0.isMultiple(of: 2) ? [ean, ean] : [ean] }
        let decisions = run(&tracker, frames)
        precondition(decisions.filter { $0 == .accept(ean) }.count == 1, "\(decisions)")
        precondition(!decisions.contains { if case .choose = $0 { true } else { false } })
    }

    static func secondCodeArrivingOneFrameLateIsOffered() {
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[ean], [ean, code128], [ean, code128]])
        precondition(decisions[0] == .waiting)
        precondition(decisions[1] == .choose([ean, code128]))
        precondition(decisions[2] == .choose([ean, code128]))
        precondition(!tracker.isFinished)
    }

    static func secondCodeArrivingTwoFramesLateIsOffered() {
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[code128], [code128], [code128, ean]])
        precondition(decisions[2] == .choose([code128, ean]))
        precondition(!tracker.isFinished)
    }

    static func multiStateToleratesFlicker() {
        var tracker = BarcodeSelectionTracker()
        // Vision drops one code for a frame, then both for a frame.
        let decisions = run(&tracker, [
            [ean, code128],
            [ean],
            [ean, code128],
            [],
            [code128],
            [ean, code128],
        ])
        for decision in decisions {
            precondition(decision == .choose([ean, code128]), "flicker must keep both outlines: \(decision)")
        }
        precondition(!tracker.isFinished)
    }

    static func handCoverFallsBackToAutoAccept() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean, code128], [ean, code128]])
        // The user covers the Code 128 from t = 0.1 s on; only the EAN stays visible.
        var accepted: (BarcodeCandidateKey, TimeInterval)?
        var time = 0.1
        while time < 2, accepted == nil {
            if case let .accept(key) = tracker.process([ean], at: time) {
                accepted = (key, time)
            }
            time += frame
        }
        guard let accepted else { preconditionFailure("covered neighbour must fall back to auto-accept") }
        precondition(accepted.0 == ean)
        let delay = accepted.1 - 0.1
        precondition(delay >= BarcodeSelectionTracker.multiToSingleFallbackInterval - 0.0001)
        precondition(delay < BarcodeSelectionTracker.multiToSingleFallbackInterval + 2 * frame)
    }

    static func briefDropoutOfNeighbourDoesNotAutoAccept() {
        var tracker = BarcodeSelectionTracker()
        // The neighbour disappears for 0.5 s at a time but keeps coming back.
        var time: TimeInterval = 0
        while time < 3 {
            let cycle = time.truncatingRemainder(dividingBy: 0.6)
            let keys = cycle < 0.1 ? [ean, code128] : [ean]
            let decision = tracker.process(keys, at: time)
            if case .accept = decision { preconditionFailure("must not auto-accept while the neighbour reappears") }
            time += frame
        }
    }

    static func codesLeavingFrameClearOutlines() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean, code128, qr]])
        // The QR leaves; it remains offered only within the retention window.
        let early = tracker.process([ean, code128], at: 0.2)
        precondition(early == .choose([ean, code128, qr]))
        let later = tracker.process([ean, code128], at: 0.2 + BarcodeSelectionTracker.candidateRetention + 0.05)
        precondition(later == .choose([ean, code128]))
        // Everything leaves: outlines go once the retention window has passed.
        let gone = tracker.process([], at: 0.3 + 2 * BarcodeSelectionTracker.candidateRetention)
        precondition(gone == .waiting)
        precondition(!tracker.isFinished)
    }

    static func selectionAbandonedAfterLongEmptyPeriod() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean, code128]])
        precondition(tracker.process([], at: BarcodeSelectionTracker.selectingExitInterval + 0.01) == .waiting)
        // Back to idle: a lone code now uses the fast single-code path.
        let decisions = run(&tracker, Array(repeating: [qr], count: confirmFrames), start: 1.5)
        precondition(decisions.first == .waiting)
        precondition(accepts(decisions) == [qr], "\(decisions)")
    }

    static func lateReappearanceRestartsLoneTimer() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean, code128]])
        precondition(tracker.process([ean], at: 0.05) == .choose([ean, code128]))
        // Camera moves away for 0.9 s (shorter than the exit interval), then back.
        precondition(tracker.process([], at: 0.5) == .waiting)
        let back = tracker.process([ean], at: 0.95)
        precondition(back == .choose([ean]), "a lone run must not survive a long gap: \(back)")
        precondition(!tracker.isFinished)
    }

    static func sameValueDifferentSymbologyIsDistinct() {
        let digits = BarcodeCandidateKey(value: "4012345678901", symbology: "VNBarcodeSymbologyCode128")
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[ean, digits], [ean, digits], [ean, digits], [ean, digits]])
        precondition(decisions.allSatisfy { $0 == .choose([ean, digits]) })
    }

    static func intermittentlyDecodedCodeIsStillAccepted() {
        // A worn code that Vision only decodes every other frame must not be
        // starved: frames without any other code count towards confirmation.
        var tracker = BarcodeSelectionTracker()
        precondition(run(&tracker, [[ean], [], [ean], [], [ean]], interval: 0.08) == [.waiting, .waiting, .waiting, .waiting, .accept(ean)])
    }

    static func singleSightingIsNeverAutoAccepted() {
        // One read, possibly a misread, followed by 5 s without that code.
        var once = BarcodeSelectionTracker()
        let empty = run(&once, [[ean]] + Array(repeating: [], count: 150))
        precondition(empty.allSatisfy { $0 == .waiting }, "one sighting must not be accepted: \(empty)")
        precondition(!once.isFinished)
        // A worn code simply waits for its second decode, however late.
        precondition(once.process([ean], at: 6) == .accept(ean))


        // The second sighting before the interval is enough once time has passed.
        var early = BarcodeSelectionTracker()
        let decisions = run(&early, [[ean], [ean], [], [], [], [], [], [], [], [], [], [], []])
        precondition(accepts(decisions) == [ean], "\(decisions)")
    }

    static func tapNeedsNoSecondSighting() {
        var tracker = BarcodeSelectionTracker()
        precondition(tracker.process([ean, code128], at: 0) == .choose([ean, code128]))
        precondition(tracker.select(code128))
    }

    static func loneFallbackNeedsSeveralSightings() {
        // After a choice, one more read of a code alone is not enough: the
        // fallback needs that code alone across 0.8 s (gaps up to 0.4 s).
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean, code128]])
        precondition(tracker.process([ean], at: 0.1) == .choose([ean, code128]))
        let empty = run(&tracker, Array(repeating: [], count: 30), start: 0.1 + frame)
        precondition(!empty.contains { if case .accept = $0 { true } else { false } })
    }

    static func differentLoneCodeDuringConfirmationIsOffered() {
        // Two codes decoded in alternating frames are still two codes.
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[ean], [qr], [qr]])
        precondition(decisions[0] == .waiting)
        precondition(decisions[1] == .choose([ean, qr]))
        precondition(decisions[2] == .choose([ean, qr]))
        precondition(!tracker.isFinished)
    }

    static func tapFinishesOnce() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean, code128]])
        precondition(tracker.finishBySelection())
        precondition(!tracker.finishBySelection())
        precondition(tracker.process([ean], at: 2) == .waiting)
    }

    // MARK: - Single mode stays unchanged

    static func singleModeSelectFinishesOnce() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, Array(repeating: [ean], count: confirmFrames))
        precondition(tracker.isFinished)
        // `select` on a single-scan tracker is exactly `finishBySelection`.
        var tapped = BarcodeSelectionTracker()
        _ = run(&tapped, [[ean, code128]])
        precondition(tapped.select(code128))
        precondition(tapped.isFinished)
        precondition(!tapped.select(ean))
    }

    static func accepts(_ decisions: [BarcodeSelectionDecision]) -> [BarcodeCandidateKey] {
        decisions.compactMap { if case let .accept(key) = $0 { key } else { nil } }
    }

    // MARK: - Batch mode: every code in view is added, no choice

    /// Feeds frames at `interval` from `start`; returns the codes added per frame.
    static func feed(
        _ tracker: inout BarcodeBatchTracker,
        _ frames: [[BarcodeCandidateKey]],
        start: TimeInterval = 0,
        interval: TimeInterval = frame,
        capacity: Int = .max
    ) -> [[BarcodeCandidateKey]] {
        frames.enumerated().map { index, keys in
            tracker.process(keys, at: start + Double(index) * interval, capacity: capacity)
        }
    }

    static func batchAddsCodeOnceWhileItStaysInView() {
        var tracker = BarcodeBatchTracker()
        let added = feed(&tracker, Array(repeating: [ean], count: 150))
        precondition(added.flatMap { $0 } == [ean], "a code in view must be added once: \(added)")
        guard let index = added.firstIndex(where: { !$0.isEmpty }) else { preconditionFailure() }
        let time = Double(index) * frame
        precondition(time > confirm - frame / 2 && time < confirm + frame * 1.5, "added at \(time)")
        precondition(tracker.addedKeys == [ean])
        precondition(tracker.visibleAddedKeys == [ean])
        precondition(tracker.confirmingKeys.isEmpty)
    }

    static func batchTwoCodesInViewAreBothAddedInFirstSightingOrder() {
        var tracker = BarcodeBatchTracker()
        // The EAN is seen first, the QR joins a few frames later; both stay.
        let frames = [[ean], [ean], [ean]] + Array(repeating: [qr, ean], count: 40)
        let added = feed(&tracker, frames)
        precondition(added.flatMap { $0 } == [ean, qr], "\(added)")
        precondition(tracker.confirmingKeys.isEmpty)
        // While the QR confirms, it is reported as confirming.
        var confirming = BarcodeBatchTracker()
        _ = feed(&confirming, [[ean, qr]])
        precondition(confirming.confirmingKeys == [ean, qr])
    }

    static func batchCodesReadyInTheSameFrameKeepFirstSightingOrder() {
        var tracker = BarcodeBatchTracker()
        precondition(tracker.process([ean], at: 0).isEmpty)
        precondition(tracker.process([code128], at: 0.05).isEmpty)
        // Both have two sightings and 0.3 s in this frame; Vision lists them in
        // the other order, the result follows first sighting.
        precondition(tracker.process([code128, ean], at: 0.36) == [ean, code128])
        precondition(tracker.addedKeys == [ean, code128])
    }

    static func batchThreeCodesAreAllAddedOnce() {
        var tracker = BarcodeBatchTracker()
        let added = feed(&tracker, Array(repeating: [ean, qr, code128], count: 120))
        precondition(added.flatMap { $0 } == [ean, qr, code128], "\(added)")
        precondition(added.filter { !$0.isEmpty }.count == 1, "all three become ready in one frame")
        precondition(tracker.visibleAddedKeys == [ean, qr, code128])
    }

    static func batchSingleMisreadIsNeverAdded() {
        var tracker = BarcodeBatchTracker()
        // One read of a stray code among frames of another code.
        var frames = Array(repeating: [ean], count: 90)
        frames[20] = [ean, qr]
        let added = feed(&tracker, frames)
        precondition(added.flatMap { $0 } == [ean], "\(added)")
        // Later single stray reads, each after the retention window, never add it.
        for time in [3.5, 4.2, 5.0, 6.1] {
            precondition(tracker.process([ean, qr], at: time).isEmpty, "stray read at \(time) added")
            precondition(tracker.process([ean], at: time + 0.45).isEmpty)
        }
        precondition(!tracker.addedKeys.contains(qr))
        // Two reads within the window are a real code again.
        precondition(tracker.process([ean, qr], at: 7).isEmpty)
        precondition(tracker.process([ean, qr], at: 7.35) == [qr])
    }

    static func batchReaddsCodeAfterItLeftAndCameBack() {
        var tracker = BarcodeBatchTracker()
        precondition(feed(&tracker, Array(repeating: [ean], count: confirmFrames)).flatMap { $0 } == [ean])
        // The item is taken away for longer than the re-entry interval...
        let start = Double(confirmFrames) * frame
        let away = BarcodeRescanGuard.reentryAbsenceInterval + 0.1
        let empty = Int((away / frame).rounded(.up))
        _ = feed(&tracker, Array(repeating: [], count: empty), start: start)
        precondition(tracker.addedKeys.isEmpty)
        // ...and shown again: a second, intentional copy is added.
        let back = feed(&tracker, Array(repeating: [ean], count: confirmFrames), start: start + Double(empty) * frame)
        precondition(back.flatMap { $0 } == [ean], "returning code must be added again: \(back)")
    }

    static func batchShortAbsenceDoesNotReadd() {
        var tracker = BarcodeBatchTracker()
        precondition(feed(&tracker, Array(repeating: [ean], count: confirmFrames)).flatMap { $0 } == [ean])
        // Away for clearly less than the re-entry interval, then back for 3 s.
        let lastSeen = Double(confirmFrames - 1) * frame
        let gap = BarcodeRescanGuard.reentryAbsenceInterval - 0.3
        _ = tracker.process([], at: lastSeen + 0.1)
        let back = feed(&tracker, Array(repeating: [ean], count: 90), start: lastSeen + gap)
        precondition(back.flatMap { $0 }.isEmpty, "a short absence must not re-add: \(back)")
    }

    static func batchFlickeringAddedCodeIsNotAddedTwice() {
        var tracker = BarcodeBatchTracker()
        precondition(feed(&tracker, Array(repeating: [ean], count: confirmFrames)).flatMap { $0 } == [ean])
        // The added code stays in view for 10 s but Vision drops it for up to 1.2 s.
        var time = Double(confirmFrames) * frame
        var index = 0
        let dropouts: [TimeInterval] = [0.1, 0.4, 1.2, 0.2, 0.9, 1.2, 0.05, 0.6]
        while time < 10 {
            precondition(tracker.process([ean], at: time).isEmpty, "flicker re-added at \(time)")
            time += dropouts[index % dropouts.count]
            index += 1
        }
    }

    static func batchMovingToNextCodeAddsIt() {
        var tracker = BarcodeBatchTracker()
        let first = Array(repeating: [ean], count: confirmFrames)
        let second = Array(repeating: [code128], count: confirmFrames)
        let added = feed(&tracker, first + [[]] + second)
        precondition(added.flatMap { $0 } == [ean, code128], "\(added)")
        precondition(tracker.addedKeys == [ean, code128])
    }

    static func batchCapacityLimitsAddsAndKeepsTheRestPending() {
        var tracker = BarcodeBatchTracker()
        // Room for two, counted down as codes are added (as the scanner does):
        // the third ready code is not added and not blocked.
        var remaining = 2
        var added: [BarcodeCandidateKey] = []
        for index in 0..<confirmFrames {
            let now = tracker.process([ean, qr, code128], at: Double(index) * frame, capacity: remaining)
            remaining -= now.count
            added += now
        }
        precondition(added == [ean, qr], "\(added)")
        precondition(tracker.addedKeys == [ean, qr])
        precondition(tracker.confirmingKeys == [code128])
        // Full: nothing is added while frames keep coming.
        let start = Double(confirmFrames) * frame
        let full = feed(&tracker, Array(repeating: [ean, qr, code128], count: 60), start: start, capacity: 0)
        precondition(full.flatMap { $0 }.isEmpty)
        // A slot frees up (an entry was deleted): the waiting code is added, the
        // added ones still in view are not added again.
        let resumed = tracker.process([ean, qr, code128], at: start + 2.1, capacity: 1)
        precondition(resumed == [code128], "\(resumed)")
    }

    static func batchFullListKeepsCodesInViewBlocked() {
        var tracker = BarcodeBatchTracker()
        precondition(feed(&tracker, Array(repeating: [ean], count: confirmFrames)).flatMap { $0 } == [ean])
        // The batch is full for 5 s while the EAN stays in view.
        let start = Double(confirmFrames) * frame
        _ = feed(&tracker, Array(repeating: [ean], count: 150), start: start, capacity: 0)
        precondition(tracker.addedKeys == [ean])
        // Collection resumes: the EAN, still in view, is not added again.
        let resumed = feed(&tracker, Array(repeating: [ean], count: 30), start: start + 5)
        precondition(resumed.flatMap { $0 }.isEmpty, "\(resumed)")
    }
}
