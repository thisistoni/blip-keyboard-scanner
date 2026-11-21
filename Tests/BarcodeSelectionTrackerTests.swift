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

    static func main() {
        singleStableCodeIsAcceptedAfterThreeFrames()
        singleCodeAcceptedQuicklyWhenFramesAreSlow()
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
        differentLoneCodeDuringConfirmationIsOffered()
        tapFinishesOnce()
        singleModeNeverReportsAddedKeys()
        batchAddsCodeOnceWhileItStaysInView()
        batchReaddsCodeAfterItLeftAndCameBack()
        batchShortAbsenceDoesNotReadd()
        batchFlickeringCodeIsNotAddedTwice()
        batchMovingToNextCodeAddsIt()
        batchTapAddsCodeAndKeepsScanning()
        batchAddedNeighbourStillMeansAChoice()
        batchHandCoverFallbackKeepsScanning()
        batchPausedFramesKeepCodesBlocked()
        print("BarcodeSelectionTrackerTests passed")
    }

    static func singleStableCodeIsAcceptedAfterThreeFrames() {
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[ean], [ean], [ean], [ean]])
        precondition(decisions[0] == .waiting)
        precondition(decisions[1] == .waiting)
        precondition(decisions[2] == .accept(ean))
        // Later frames are ignored once a code is accepted.
        precondition(decisions[3] == .waiting)
        precondition(tracker.isFinished)
    }

    static func singleCodeAcceptedQuicklyWhenFramesAreSlow() {
        var tracker = BarcodeSelectionTracker()
        // 8 fps analysis: two frames already span 0.125 s.
        let decisions = run(&tracker, [[ean], [ean]], interval: 0.125)
        precondition(decisions == [.waiting, .accept(ean)])
    }

    static func duplicateObservationsOfOneCodeStaySingle() {
        var tracker = BarcodeSelectionTracker()
        let decisions = run(&tracker, [[ean, ean], [ean], [ean, ean]])
        precondition(decisions.last == .accept(ean))
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
        let decisions = run(&tracker, [[qr], [qr], [qr]], start: 1.5)
        precondition(decisions == [.waiting, .waiting, .accept(qr)])
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
        precondition(run(&tracker, [[ean], [], [ean]]) == [.waiting, .waiting, .accept(ean)])
        var once = BarcodeSelectionTracker()
        precondition(run(&once, [[ean], [], []]) == [.waiting, .waiting, .accept(ean)])
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

    static func singleModeNeverReportsAddedKeys() {
        var tracker = BarcodeSelectionTracker()
        _ = run(&tracker, [[ean], [ean], [ean]])
        precondition(tracker.isFinished)
        precondition(tracker.addedKeys.isEmpty)
        // `select` on a single-scan tracker is exactly `finishBySelection`.
        var tapped = BarcodeSelectionTracker()
        _ = run(&tapped, [[ean, code128]])
        precondition(tapped.select(code128))
        precondition(tapped.isFinished)
        precondition(!tapped.select(ean))
    }

    // MARK: - Batch mode

    static func batchTracker() -> BarcodeSelectionTracker {
        BarcodeSelectionTracker(continuesAfterAccept: true)
    }

    static func accepts(_ decisions: [BarcodeSelectionDecision]) -> [BarcodeCandidateKey] {
        decisions.compactMap { if case let .accept(key) = $0 { key } else { nil } }
    }

    static func batchAddsCodeOnceWhileItStaysInView() {
        var tracker = batchTracker()
        // Five seconds of the same code in view.
        let decisions = run(&tracker, Array(repeating: [ean], count: 150))
        precondition(accepts(decisions) == [ean], "a code in view must be added once: \(accepts(decisions))")
        precondition(decisions[2] == .accept(ean))
        precondition(!tracker.isFinished)
        precondition(tracker.addedKeys == [ean])
    }

    static func batchReaddsCodeAfterItLeftAndCameBack() {
        var tracker = batchTracker()
        precondition(accepts(run(&tracker, [[ean], [ean], [ean]])) == [ean])
        // The item is taken away for longer than the re-entry interval...
        let away = BarcodeRescanGuard.reentryAbsenceInterval + 0.1
        let empty = Int((away / frame).rounded(.up))
        _ = run(&tracker, Array(repeating: [], count: empty), start: 3 * frame)
        precondition(tracker.addedKeys.isEmpty)
        // ...and shown again: a second, intentional copy is added.
        let back = run(&tracker, [[ean], [ean], [ean], [ean]], start: 3 * frame + Double(empty) * frame)
        precondition(accepts(back) == [ean], "returning code must be added again: \(back)")
    }

    static func batchShortAbsenceDoesNotReadd() {
        var tracker = batchTracker()
        _ = run(&tracker, [[ean], [ean], [ean]])
        // Away for clearly less than the re-entry interval, then back for 3 s.
        let gap = BarcodeRescanGuard.reentryAbsenceInterval - 0.3
        _ = tracker.process([], at: 0.1)
        let back = run(&tracker, Array(repeating: [ean], count: 90), start: 0.1 + gap)
        precondition(accepts(back).isEmpty, "a short absence must not re-add: \(back)")
    }

    static func batchFlickeringCodeIsNotAddedTwice() {
        var tracker = batchTracker()
        // A worn code that Vision decodes only now and then, with dropouts of up
        // to 1.2 s, stays in view for 10 s.
        var decisions: [BarcodeSelectionDecision] = []
        var time: TimeInterval = 0
        var index = 0
        let dropouts: [TimeInterval] = [0.1, 0.4, 1.2, 0.2, 0.9, 1.2, 0.05, 0.6]
        while time < 10 {
            decisions.append(tracker.process([ean], at: time))
            time += dropouts[index % dropouts.count]
            index += 1
        }
        precondition(accepts(decisions) == [ean], "flicker must not double-add: \(accepts(decisions))")
    }

    static func batchMovingToNextCodeAddsIt() {
        var tracker = batchTracker()
        // First item, then the camera moves on: the first code leaves the view
        // before the second appears, so the fast single-code path is used.
        let decisions = run(&tracker, [[ean], [ean], [ean], [ean], [], [code128], [code128], [code128], [code128]])
        precondition(accepts(decisions) == [ean, code128], "\(decisions)")
        precondition(decisions[7] == .accept(code128))
        precondition(tracker.addedKeys == [ean, code128])
    }

    static func batchTapAddsCodeAndKeepsScanning() {
        var tracker = batchTracker()
        precondition(tracker.process([ean, code128], at: 0) == .choose([ean, code128]))
        precondition(tracker.select(ean))
        // The tapped code cannot be tapped again while it stays in view.
        precondition(!tracker.select(ean))
        precondition(tracker.addedKeys == [ean])
        // Both codes stay outlined (the added one is marked by `addedKeys`) and
        // the other one is never auto-added while the first is still visible.
        var time = frame
        while time < 3 {
            let decision = tracker.process([ean, code128], at: time)
            precondition(decision == .choose([ean, code128]), "remaining code must stay a choice: \(decision)")
            time += frame
        }
        precondition(tracker.select(code128))
        precondition(tracker.addedKeys == [ean, code128])
        // Everything visible was added: nothing left to offer, nothing re-added.
        let rest = run(&tracker, Array(repeating: [ean, code128], count: 60), start: 3)
        precondition(rest.allSatisfy { $0 == .waiting }, "\(rest)")
        precondition(!tracker.isFinished)
    }

    static func batchAddedNeighbourStillMeansAChoice() {
        var tracker = batchTracker()
        _ = run(&tracker, [[ean], [ean], [ean]])
        // The added EAN is still in view when a new code appears next to it.
        let decisions = run(&tracker, [[ean, qr], [ean, qr], [ean, qr], [ean, qr]], start: 0.2)
        precondition(decisions.allSatisfy { $0 == .choose([ean, qr]) }, "\(decisions)")
        precondition(tracker.addedKeys == [ean])
        precondition(tracker.select(qr))
    }

    static func batchHandCoverFallbackKeepsScanning() {
        var tracker = batchTracker()
        _ = run(&tracker, [[ean, code128], [ean, code128]])
        // Only the EAN stays visible: it is added after the fallback interval.
        var acceptedAt: TimeInterval?
        var time = 0.1
        while time < 2 {
            let decision = tracker.process([ean], at: time)
            if case .accept(let key) = decision {
                precondition(key == ean && acceptedAt == nil, "only one add expected")
                acceptedAt = time
            }
            time += frame
        }
        guard let acceptedAt else { preconditionFailure("covered neighbour must fall back to auto-add") }
        precondition(acceptedAt - 0.1 >= BarcodeSelectionTracker.multiToSingleFallbackInterval - 0.0001)
        // Uncovering the Code 128 offers it rather than adding it on its own.
        let uncovered = tracker.process([ean, code128], at: time)
        precondition(uncovered == .choose([ean, code128]), "\(uncovered)")
    }

    static func batchPausedFramesKeepCodesBlocked() {
        var tracker = batchTracker()
        _ = run(&tracker, [[ean], [ean], [ean]])
        // The batch is full for 5 s while the EAN stays in view.
        var time = 3 * frame
        while time < 5 {
            tracker.observeWithoutAccepting([ean], at: time)
            time += frame
        }
        precondition(tracker.addedKeys == [ean])
        // Collection resumes: the EAN, still in view, is not added again.
        let resumed = run(&tracker, Array(repeating: [ean], count: 30), start: time)
        precondition(accepts(resumed).isEmpty, "\(resumed)")
    }
}
