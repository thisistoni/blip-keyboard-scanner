import SwiftUI
import os
import UIKit
#if DEBUG
import CoreImage.CIFilterBuiltins
#endif

private let scanInsertionLogger = Logger(subsystem: "com.antoniobeslic.Blip", category: "ScanInsertion")

struct ScannerScreen: View {
    let externalLaunchRequest: KeyboardScanRequest?
    let automaticallyPresentScanner: Bool

    @AppStorage(SharedKeyboardState.Keys.lastScannedCode, store: SharedKeyboardState.appStorageDefaults)
    private var lastScannedCode = ""

    @AppStorage(SharedKeyboardState.Keys.scannerFlashlightMode, store: SharedKeyboardState.appStorageDefaults)
    private var scannerFlashlightModeRawValue = ScannerFlashlightMode.off.rawValue

    @AppStorage(SharedKeyboardState.Keys.scanFormatProfile, store: SharedKeyboardState.appStorageDefaults)
    private var scanFormatProfileRawValue = SharedKeyboardState.scanFormatProfile.rawValue

    @AppStorage(SharedKeyboardState.Keys.scannerZoomLevel, store: SharedKeyboardState.appStorageDefaults)
    private var scannerZoomLevelRawValue = SharedKeyboardState.scannerZoomLevel.rawValue

    @AppStorage(SharedKeyboardState.Keys.scannerScanArea, store: SharedKeyboardState.appStorageDefaults)
    private var scannerScanAreaRawValue = SharedKeyboardState.scannerScanArea.rawValue

    @AppStorage(SharedKeyboardState.Keys.playScanSound, store: SharedKeyboardState.appStorageDefaults)
    private var playScanSound = SharedKeyboardState.playScanSound

    @AppStorage(SharedKeyboardState.Keys.returnTarget, store: SharedKeyboardState.appStorageDefaults)
    private var returnTargetRawValue = ReturnTarget.safari.rawValue

    @AppStorage(SharedKeyboardState.Keys.customReturnURL, store: SharedKeyboardState.appStorageDefaults)
    private var customReturnURL = ""

    @Environment(\.scenePhase) private var scenePhase
    @State private var testFocused = false
    @State private var testFieldID = UUID().uuidString
    @State private var restoreTestField = false
    @State private var pendingProfileAction: ScannedProfileAction?
    @State private var profileReview: PendingCompanyProfile?
    @State private var profileError: String?
    private let testLeaseTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var activeSession: ScannerSession?
    @State private var returnGuidance: KeyboardReturnGuidance?
    @State private var handledLaunchRequestID: String?
    @State private var didAutomaticallyPresentScanner = false

    init(
        externalLaunchRequest: KeyboardScanRequest?,
        automaticallyPresentScanner: Bool = false
    ) {
        self.externalLaunchRequest = externalLaunchRequest
        self.automaticallyPresentScanner = automaticallyPresentScanner
    }

    private var returnTarget: ReturnTarget {
        ReturnTarget(rawValue: returnTargetRawValue) ?? .safari
    }

    private var scanFormatProfile: ScanFormatProfile {
        ScanFormatProfile(rawValue: scanFormatProfileRawValue) ?? .allSupported
    }

    private var scannerZoomLevel: ScannerZoomLevel {
        ScannerZoomLevel(rawValue: scannerZoomLevelRawValue) ?? .x1
    }

    private var scannerScanArea: ScannerScanArea {
        ScannerScanArea(rawValue: scannerScanAreaRawValue) ?? .fullFrame
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    Section {
                        ScannerWorkflowGuideView()
                    } header: {
                        Text("How It Works")
                    }

                    Section {
                        KeyboardTestTextField(focused: $testFocused, sessionID: testFieldID,
                            onPrepare: prepareTestFieldEditing, onEnd: endTestFieldEditing)
                            .frame(minHeight: 36)
                            .id("keyboardTestField")
                    } header: {
                        Text("Test the Blip keyboard")
                    } footer: {
                        Text("Choose Blip with the globe key, then tap Scan. This test returns here.")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    guard testFocused else { return }
                    withAnimation {
                        scrollProxy.scrollTo("keyboardTestField", anchor: .center)
                    }
                }
            }
            .navigationTitle("Scan")
            .onAppear {
                handleExternalLaunchRequest()
                presentScannerForScreenshotIfNeeded()
            }
            .onChange(of: externalLaunchRequest) { request in
                handleExternalLaunchRequest(request)
            }
            .onReceive(testLeaseTimer) { _ in
                if scenePhase == .active, testFocused || activeSession?.testSessionID == testFieldID || restoreTestField {
                    SharedKeyboardState.renewKeyboardTest(id: testFieldID)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { cancelTestField() }
            }
            .onDisappear {
                if activeSession?.testSessionID != testFieldID, !restoreTestField { cancelTestField() }
            }
            .fullScreenCover(item: $activeSession, onDismiss: scannerDidDismiss) { session in
                ScannerPresentation(
                    session: session,
                    playScanSound: playScanSound,
                    defaultZoomLevel: scannerZoomLevel,
                    scanArea: scannerScanArea,
                    defaultFlashlightMode: ScannerFlashlightMode(rawValue: scannerFlashlightModeRawValue) ?? .off
                ) { result in
                    handleScannedCode(result, for: session)
                } onCancel: {
                    handleScannerCancel(for: session)
                }
            }
            .fullScreenCover(item: $returnGuidance) { guidance in
                KeyboardReturnGuidanceView(guidance: guidance) {
                    returnGuidance = nil
                }
            }
            .sheet(item: $profileReview, onDismiss: restoreTestFieldAfterScanner) { pending in
                CompanyProfilePreview(profile: pending.profile,
                    onCancel: { profileReview = nil },
                    onApply: {
                        do {
                            try pending.profile.apply()
                            profileReview = nil
                        } catch {
                            profileError = error.localizedDescription
                        }
                    })
            }
            .alert("Company Profile", isPresented: Binding(
                get: { profileError != nil },
                set: { if !$0 { profileError = nil } }
            )) {
                Button("OK", role: .cancel) {
                    if profileReview == nil { restoreTestFieldAfterScanner() }
                }
            } message: {
                Text(profileError ?? "")
            }
        }
    }

    private func prepareTestFieldEditing() -> String {
#if DEBUG
        KeyboardTestDiagnostics.record("prepare", source: "app", details: ["focused": testFocused])
#endif
        if let session = SharedKeyboardState.keyboardTestSession,
           session.id == testFieldID {
            // UIKit can preflight focus repeatedly, including while opening the camera.
            // Preserve every live phase; only a revoked/expired scope gets a new owner.
            // Queue the result before UIKit creates/resumes the extension's document proxy.
            _ = SharedKeyboardState.resumeKeyboardTest(id: testFieldID)
#if DEBUG
            KeyboardTestDiagnostics.record("resumeBeforeFocus", source: "app")
#endif
            return testFieldID
        }
        // A fresh ownership nonce prevents delayed extension writes from reviving an abandoned test.
        let id = UUID().uuidString
        testFieldID = id
        SharedKeyboardState.beginKeyboardTest(id: id)
#if DEBUG
        KeyboardTestDiagnostics.record("newOwner", source: "app")
#endif
        return id
    }

    private func endTestFieldEditing() {
#if DEBUG
        KeyboardTestDiagnostics.record("endEditing", source: "app")
#endif
        let phase = SharedKeyboardState.keyboardTestSession?.phase
        if phase != .launching && phase != .scanning && phase != .returning {
            SharedKeyboardState.cancelKeyboardTest(id: testFieldID)
#if DEBUG
            KeyboardTestDiagnostics.record("cancelOnEndEditing", source: "app")
#endif
        }
    }

    private func cancelTestField() {
        restoreTestField = false
        testFocused = false
        SharedKeyboardState.cancelKeyboardTest(id: testFieldID)
    }

    private func restoreTestFieldAfterScanner() {
        guard restoreTestField else { return }
        restoreTestField = false
        DispatchQueue.main.async {
            guard scenePhase == .active,
                  SharedKeyboardState.keyboardTestSession?.id == testFieldID else { return }
            testFocused = true
#if DEBUG
            KeyboardTestDiagnostics.record("focusRequested", source: "app")
#endif
        }
    }

    private func scannerDidDismiss() {
        guard let action = pendingProfileAction else {
            restoreTestFieldAfterScanner()
            return
        }
        pendingProfileAction = nil
        switch action {
        case .preview(let profile): profileReview = PendingCompanyProfile(profile: profile)
        case .error(let message): profileError = message
        }
    }

    private func finishProfileScan(_ action: ScannedProfileAction, for session: ScannerSession) {
        if let testID = session.testSessionID {
            guard SharedKeyboardState.finishKeyboardTest(id: testID, requestID: session.id, code: nil) else {
                activeSession = nil
                return
            }
            restoreTestField = true
        } else if session.source == .keyboard {
            // A configuration QR is reviewed in Blip, never queued as text or sent to a browser.
            SharedKeyboardState.consumedScanIdentifier = session.id
        }
        pendingProfileAction = action
        activeSession = nil
    }

    private func presentScannerForScreenshotIfNeeded() {
        guard automaticallyPresentScanner, !didAutomaticallyPresentScanner else { return }
        didAutomaticallyPresentScanner = true
        activeSession = ScannerSession(
            id: "app-store-screenshot",
            source: .app,
            scanFormatProfile: scanFormatProfile,
            returnTarget: returnTarget,
            customReturnURL: customReturnURL
        )
    }

    private func handleExternalLaunchRequest(_ request: KeyboardScanRequest? = nil) {
        let request = request ?? externalLaunchRequest
        guard let request, request.id != handledLaunchRequestID else { return }

        handledLaunchRequestID = request.id
        returnGuidance = nil
        if request.testSessionID != nil {
            guard request.testSessionID == testFieldID,
                  SharedKeyboardState.acceptKeyboardTestRequest(request, ownerID: testFieldID) else {
                if SharedKeyboardState.activeScanRequestIdentifier == request.id {
                    SharedKeyboardState.activeScanRequestIdentifier = ""
                }
                return
            }
            testFocused = false
        } else {
            cancelTestField()
        }
        activeSession = ScannerSession(
            id: request.id,
            source: request.launchedFromKeyboard ? .keyboard : .app,
            testSessionID: request.testSessionID,
            scanFormatProfile: scanFormatProfile,
            returnTarget: returnTarget,
            customReturnURL: customReturnURL
        )
    }

    private func handleScannedCode(_ result: ScannerCodeResult, for session: ScannerSession) {
        guard !result.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            if let profile = try BlipCompanyProfileQR.decodeIfRecognized(result.value) {
                ScanSoundPlayer.shared.playIfEnabled(playScanSound)
                finishProfileScan(.preview(profile), for: session)
                return
            }
        } catch {
            finishProfileScan(.error(error.localizedDescription), for: session)
            return
        }

        if let testID = session.testSessionID {
            guard SharedKeyboardState.finishKeyboardTest(id: testID, requestID: session.id, code: result.value) else {
                activeSession = nil
                return
            }
            ScanSoundPlayer.shared.playIfEnabled(playScanSound)
#if DEBUG
            KeyboardTestDiagnostics.record("cameraFinished", source: "app")
#endif
            restoreTestField = true
            activeSession = nil
            return
        }

        ScanSoundPlayer.shared.playIfEnabled(playScanSound)
        lastScannedCode = result.value
        UIPasteboard.general.string = result.value

        if !result.isManualEntry {
            ScanHistoryStore.record(
                ScanHistoryItem(
                    value: result.value,
                    codeFormat: result.codeFormat,
                    source: session.source.historySource,
                    returnTargetRawValue: session.source == .keyboard ? session.returnTarget.rawValue : nil,
                    insertionStatus: session.source == .keyboard ? .queuedForKeyboardInsertion : .notQueued
                )
            )
        }

        activeSession = nil

        guard session.source == .keyboard else { return }

        SharedKeyboardState.queuePendingInsertion(
            result.value,
            requestIdentifier: session.id,
            autoInsert: session.returnTarget.shouldAutomaticallyInsertScan(userEnabled: SharedKeyboardState.autoInsertScans)
        )
        scanInsertionLogger.info("Scan queued for keyboard and copied to clipboard")

        let returnDelay: TimeInterval = playScanSound ? 0.45 : 0.2

        DispatchQueue.main.asyncAfter(deadline: .now() + returnDelay) {
            finishKeyboardSession(session, hasPendingScan: true)
        }
    }

    private func handleScannerCancel(for session: ScannerSession) {
        if let testID = session.testSessionID {
            restoreTestField = SharedKeyboardState.finishKeyboardTest(id: testID, requestID: session.id, code: nil)
            activeSession = nil
            return
        }
        activeSession = nil

        guard session.source == .keyboard else { return }

        SharedKeyboardState.consumedScanIdentifier = session.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            finishKeyboardSession(session, hasPendingScan: false)
        }
    }

    private func finishKeyboardSession(_ session: ScannerSession, hasPendingScan: Bool) {
        if session.returnTarget == .custom {
            SourceAppReturnController.openCustomReturnURL(session.customReturnURL)
            return
        }

        if session.returnTarget != .safari {
            SourceAppReturnController.openBrowserReturnTarget(session.returnTarget) { didOpen in
                guard !didOpen else { return }
                Task { @MainActor in
                    returnGuidance = KeyboardReturnGuidance(
                        target: session.returnTarget,
                        hasPendingScan: hasPendingScan
                    )
                }
            }
            return
        }

        returnGuidance = KeyboardReturnGuidance(
            target: session.returnTarget,
            hasPendingScan: hasPendingScan
        )
    }
}

private enum ScannedProfileAction {
    case preview(BlipCompanyProfile)
    case error(String)
}

private struct ScannerWorkflowGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScannerWorkflowGuideRow(
                systemImage: "keyboard",
                title: "Use the Blip keyboard",
                message: "In Safari or another app, tap a text field and switch to Blip with the bottom-left keyboard button."
            )

            ScannerWorkflowGuideRow(
                systemImage: "barcode.viewfinder",
                title: "Scan from the keyboard",
                message: "Blip returns automatically to Chrome, Edge, Firefox, or Brave. Safari uses manual return and Insert Last Scan."
            )

            ScannerWorkflowGuideRow(
                systemImage: "text.cursor",
                title: "Inserted where you started",
                message: "Blip attempts to insert the scan and copies it for Paste if needed."
            )

        }
        .padding(.vertical, 4)
    }
}

private struct KeyboardReturnGuidance: Identifiable {
    let id = UUID()
    let target: ReturnTarget
    let hasPendingScan: Bool
}

private struct KeyboardReturnGuidanceView: View {
    let guidance: KeyboardReturnGuidance
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: guidance.hasPendingScan ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 68))
                    .foregroundStyle(guidance.hasPendingScan ? .green : .secondary)

                VStack(spacing: 8) {
                    Text(guidance.hasPendingScan ? "Scan ready" : "Scanner closed")
                        .font(.title.bold())

                    if guidance.target == .safari {
                        Text("Blip can't automatically return to your original Safari tab.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(guidance.hasPendingScan ? "Your scan is queued for the Blip keyboard." : "No scan was queued.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(alignment: .leading, spacing: 18) {
                    if guidance.target == .safari {
                        Label("Return to your original Safari tab and text field with iOS's previous-app control.", systemImage: "arrow.backward.circle.fill")
                    } else {
                        Label {
                            Text(
                                String(
                                    format: NSLocalizedString("Tap the previous-app control in the top-left to return to %@.", comment: "Previous app return instruction"),
                                    guidance.target.title
                                )
                            )
                        } icon: {
                            Image(systemName: "arrow.backward.circle.fill")
                        }
                    }

                    Divider()

                    Label("Or swipe right across the Home indicator at the very bottom of the screen.", systemImage: "hand.draw.fill")

                    if guidance.target == .safari, guidance.hasPendingScan {
                        Divider()
                        Label("Tap Insert Last Scan on the Blip keyboard.", systemImage: "keyboard")
                    }
                }
                .font(.headline)
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Text(guidance.target == .safari
                     ? "For automatic return, choose another supported Return Target."
                     : "If the app did not reopen, use iOS's previous-app control.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
            .navigationTitle(guidance.target == .safari ? "Return to Safari Manually" : "Return to Previous App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}

private struct ScannerWorkflowGuideRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ScannerSession: Identifiable, Equatable {
    enum Source: Equatable {
        case app
        case keyboard

        var historySource: ScanHistorySource {
            switch self {
            case .app:
                .app
            case .keyboard:
                .keyboard
            }
        }
    }

    let id: String
    let source: Source
    var testSessionID: String? = nil
    let scanFormatProfile: ScanFormatProfile
    let returnTarget: ReturnTarget
    let customReturnURL: String

    var title: String {
        if testSessionID != nil { return NSLocalizedString("Return to Keyboard Test", comment: "Scanner test return title") }
        return switch source {
        case .app:
            NSLocalizedString("Scanner", comment: "Scanner title")
        case .keyboard:
            String(format: NSLocalizedString("Return to %@", comment: "Scanner return target title"), returnTarget.title)
        }
    }
}

private struct ScannerPresentation: View {
    let session: ScannerSession
    let playScanSound: Bool
    let defaultZoomLevel: ScannerZoomLevel
    let scanArea: ScannerScanArea
    let onCode: (ScannerCodeResult) -> Void
    let onCancel: () -> Void

    @State private var flashlightMode: ScannerFlashlightMode
    @State private var isTorchAvailable = false
    @State private var isTorchOn = false
    @State private var scannerStatusMessage: String?
    @State private var scannedCode: String?
    @State private var currentZoomFactor = 1.0

    init(
        session: ScannerSession,
        playScanSound: Bool,
        defaultZoomLevel: ScannerZoomLevel,
        scanArea: ScannerScanArea,
        defaultFlashlightMode: ScannerFlashlightMode,
        onCode: @escaping (ScannerCodeResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.session = session
        self.playScanSound = playScanSound
        self.defaultZoomLevel = defaultZoomLevel
        self.scanArea = scanArea
        // A toolbar toggle applies to this scan; only Settings changes the next scan's default.
        _flashlightMode = State(initialValue: defaultFlashlightMode)
        self.onCode = onCode
        self.onCancel = onCancel
    }

    private var scannerFeedIsAvailable: Bool {
#if DEBUG
        ScreenshotAutomation.usesSimulatedCamera || BarcodeScannerView.isScannerAvailable
#else
        BarcodeScannerView.isScannerAvailable
#endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                cameraFeed

                if scanArea == .centeredBox, scannerFeedIsAvailable {
                    ScannerAreaGuideOverlay()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                scannerOverlay
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                ScanSoundPlayer.shared.prepareIfEnabled(playScanSound)
#if DEBUG
                if ScreenshotAutomation.usesSimulatedCamera {
                    isTorchAvailable = true
                    isTorchOn = flashlightMode == .on
                    currentZoomFactor = defaultZoomLevel.factor
                    scannerStatusMessage = nil
                }
#endif
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        flashlightMode = flashlightMode == .on ? .off : .on
#if DEBUG
                        if ScreenshotAutomation.usesSimulatedCamera {
                            isTorchOn = flashlightMode == .on
                        }
#endif
                    } label: {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundStyle(isTorchOn ? .yellow : .primary)
                    }
                    .accessibilityLabel(
                        isTorchOn
                            ? NSLocalizedString("Flashlight On", comment: "Flashlight on accessibility label")
                            : NSLocalizedString("Flashlight Off", comment: "Flashlight off accessibility label")
                    )
                    .disabled(!isTorchAvailable || scannedCode != nil)
                }
            }
        }
    }

    @ViewBuilder
    private var cameraFeed: some View {
#if DEBUG
        if ScreenshotAutomation.usesSimulatedCamera {
            SimulatedCameraFeed()
                .ignoresSafeArea()
        } else {
            physicalCameraFeed
        }
#else
        physicalCameraFeed
#endif
    }

    @ViewBuilder
    private var physicalCameraFeed: some View {
        if BarcodeScannerView.isScannerAvailable {
            BarcodeScannerView(
                scanFormatProfile: session.scanFormatProfile,
                flashlightMode: flashlightMode,
                defaultZoomFactor: defaultZoomLevel.factor,
                scanArea: scanArea,
                isTorchAvailable: $isTorchAvailable,
                isTorchOn: $isTorchOn,
                statusMessage: $scannerStatusMessage,
                currentZoomFactor: $currentZoomFactor,
                onCode: handleCode
            )
            .ignoresSafeArea()
        } else {
            ManualScanFallback(onCode: handleCode)
        }
    }

    private var scannerOverlay: some View {
        VStack {
            if let scannedCode {
                ScanStatusPill(
                    title: "Scanned",
                    detail: scannedCode,
                    systemImage: "checkmark.circle.fill",
                    color: .green
                )
                .padding(.top, 18)
            } else if let scannerStatusMessage {
                ScanStatusPill(
                    title: "Scanner",
                    detail: scannerStatusMessage,
                    systemImage: "camera.fill",
                    color: .blue
                )
                .padding(.top, 18)
            } else if session.source == .keyboard {
                ScanStatusPill(
                    title: "Target",
                    detail: session.testSessionID == nil ? session.returnTarget.title : NSLocalizedString("Keyboard Test", comment: "Keyboard test target"),
                    systemImage: "arrowshape.turn.up.backward.fill",
                    color: .blue
                )
                .padding(.top, 18)
            }

            Spacer()

            if scannerFeedIsAvailable {
                ZoomIndicator(value: currentZoomFactor)
                    .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }

    private func handleCode(_ result: ScannerCodeResult) {
        guard scannedCode == nil else { return }

        scannedCode = result.value.hasPrefix(BlipCompanyProfileQR.marker)
            ? NSLocalizedString("Company Profile", comment: "Recognized profile scan") : result.value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onCode(result)
        }
    }
}

#if DEBUG
private struct SimulatedCameraFeed: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("DemoWarehouse")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                VStack(spacing: 7) {
                    Image(uiImage: Self.barcodeImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: min(geometry.size.width * 0.55, 390), height: 86)

                    Text("4 012345 678901")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black)
                }
                .offset(y: geometry.size.height * 0.015)
            }
        }
        .background(.black)
        .accessibilityHidden(true)
    }

    private static let barcodeImage: UIImage = {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data("4012345678901".utf8)
        filter.quietSpace = 10

        guard let outputImage = filter.outputImage else { return UIImage() }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }()
}
#endif

private struct ScannerAreaGuideOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let guideRect = ScannerScanAreaGuide.rect(
                in: CGRect(origin: .zero, size: geometry.size)
            )

            ZStack(alignment: .topLeading) {
                ScannerAreaDimmingShape(
                    guideRect: guideRect,
                    cornerRadius: ScannerScanAreaGuide.cornerRadius
                )
                .fill(.black.opacity(0.42), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: ScannerScanAreaGuide.cornerRadius)
                    .strokeBorder(.white.opacity(0.92), lineWidth: 2)
                    .frame(width: guideRect.width, height: guideRect.height)
                    .offset(x: guideRect.minX, y: guideRect.minY)
            }
        }
    }
}

private struct ScannerAreaDimmingShape: Shape {
    let guideRect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: guideRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

private struct ZoomIndicator: View {
    let value: Double

    var body: some View {
        Text(String(format: "%.1fx", value))
            .font(.caption.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
    }
}

private struct ScanStatusPill: View {
    let title: LocalizedStringKey
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ManualScanFallback: View {
    @State private var code = ""
    let onCode: (ScannerCodeResult) -> Void

    var body: some View {
        List {
            Section {
                EmptyStateView(
                    title: "Scanner unavailable",
                    systemImage: "camera",
                    message: "Use a physical iPhone or iPad with camera access to scan barcodes and QR codes."
                )
            }

            Section {
                TextField("Manual test code", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    onCode(
                        ScannerCodeResult(
                            value: code,
                            codeFormat: nil,
                            isManualEntry: true
                        )
                    )
                } label: {
                    Label("Use Code", systemImage: "keyboard")
                }
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Simulator Test")
            }
        }
    }
}

private struct EmptyStateView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}


/// A native input field, using the installed extension selected by the user.
private struct KeyboardTestTextField: UIViewRepresentable {
    @Binding var focused: Bool
    let sessionID: String
    let onPrepare: () -> String
    let onEnd: () -> Void

    func makeUIView(context: Context) -> UITextField {
#if DEBUG
        KeyboardTestDiagnostics.record("fieldCreated", source: "app")
#endif
        let field = UITextField()
        field.delegate = context.coordinator
        field.placeholder = NSLocalizedString("Scan result", comment: "Keyboard test text field")
        field.accessibilityLabel = NSLocalizedString("Test the Blip keyboard", comment: "Keyboard test text field label")
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.textContentType = UITextContentType(rawValue: KeyboardTestSession.contentTypePrefix + sessionID)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if focused, !field.isFirstResponder { field.becomeFirstResponder() }
        if !focused, field.isFirstResponder { field.resignFirstResponder() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: KeyboardTestTextField
        private weak var activeField: UITextField?
        private var needsPresentationRefresh = false

        init(_ parent: KeyboardTestTextField) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)),
                name: UIResponder.keyboardDidShowNotification, object: nil)
#if DEBUG
            for name in [UIResponder.keyboardWillShowNotification,
                         UIResponder.keyboardWillChangeFrameNotification,
                         UIResponder.keyboardDidChangeFrameNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(recordHostKeyboardFrame(_:)),
                    name: name, object: nil)
            }
#endif
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        @objc private func keyboardDidShow(_ notification: Notification) {
#if DEBUG
            recordHostKeyboardFrame(notification)
#endif
            guard needsPresentationRefresh, let field = activeField, field.isFirstResponder else { return }
            // Refresh UIKit's initial host presentation once, retaining the selected extension and focus.
            needsPresentationRefresh = false
#if DEBUG
            KeyboardTestDiagnostics.record("willReload", source: "app", details: ["hasText": field.hasText])
#endif
            field.reloadInputViews()
#if DEBUG
            KeyboardTestDiagnostics.record("didReload", source: "app", details: ["hasText": field.hasText])
#endif
        }
#if DEBUG
        @objc private func recordHostKeyboardFrame(_ notification: Notification) {
            guard let field = activeField, field.isFirstResponder,
                  let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            func rect(_ value: CGRect) -> [Double] {
                [value.origin.x, value.origin.y, value.width, value.height].map(Double.init)
            }
            KeyboardTestDiagnostics.record("hostKeyboardFrame", source: "app", details: [
                "notification": notification.name.rawValue,
                "keyboardFrame": rect(frame),
                "windowBounds": field.window.map { rect($0.bounds) } ?? [],
                "windowSafeArea": field.window.map {
                    [$0.safeAreaInsets.top, $0.safeAreaInsets.left, $0.safeAreaInsets.bottom, $0.safeAreaInsets.right].map(Double.init)
                } ?? [],
                "fieldAccessoryHeight": Double(field.inputAccessoryView?.bounds.height ?? 0),
                "fieldFirstResponder": field.isFirstResponder,
                "refreshPending": needsPresentationRefresh])
        }
#endif
        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            // Set the explicit cooperating-field trait before UIKit asks the extension for input.
            textField.textContentType = UITextContentType(rawValue: KeyboardTestSession.contentTypePrefix + parent.onPrepare())
#if DEBUG
            KeyboardTestDiagnostics.record("nativeWillBegin", source: "app", details: ["hasText": textField.hasText])
#endif
            return true
        }
        func textFieldDidBeginEditing(_ textField: UITextField) {
            activeField = textField
            needsPresentationRefresh = true
            parent.focused = true
#if DEBUG
            KeyboardTestDiagnostics.record("nativeDidBegin", source: "app", details: ["hasText": textField.hasText])
#endif
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
#if DEBUG
            KeyboardTestDiagnostics.record("nativeDidEnd", source: "app", details: ["hasText": textField.hasText])
#endif
            needsPresentationRefresh = false
            activeField = nil
            parent.focused = false
            parent.onEnd()
        }

#if DEBUG
        func textFieldDidChangeSelection(_ textField: UITextField) {
            KeyboardTestDiagnostics.record("nativeSelectionChanged", source: "app",
                details: ["hasText": textField.hasText, "firstResponder": textField.isFirstResponder])
        }
#endif
    }
}
