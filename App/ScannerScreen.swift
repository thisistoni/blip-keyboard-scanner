import SwiftUI

struct ScannerScreen: View {
    let externalLaunchRequest: KeyboardScanRequest?

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

    @State private var activeSession: ScannerSession?
    @State private var handledLaunchRequestID: String?

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
            List {
                Section {
                    if lastScannedCode.isEmpty {
                        EmptyStateView(
                            title: "No scan yet",
                            systemImage: "barcode.viewfinder",
                            message: "Start a scan here, or tap Scan from the keyboard inside another app."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Scan")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(lastScannedCode)
                                .font(.title3.monospaced())
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ScannerWorkflowGuideView()
                } header: {
                    Text("How It Works")
                }

                Section {
                    Button {
                        activeSession = ScannerSession(
                            id: UUID().uuidString,
                            source: .app,
                            scanFormatProfile: scanFormatProfile,
                            returnTarget: returnTarget,
                            customReturnURL: customReturnURL
                        )
                    } label: {
                        Label("Start Scanner", systemImage: "barcode.viewfinder")
                    }

                    LabeledContent("Keyboard return target", value: returnTarget.title)
                }

                Section {
                    Button(role: .destructive) {
                        lastScannedCode = ""
                    } label: {
                        Label("Clear Last Scan", systemImage: "trash")
                    }
                    .disabled(lastScannedCode.isEmpty)
                }
            }
            .navigationTitle("Scan")
            .onAppear {
                handleExternalLaunchRequest()
            }
            .onChange(of: externalLaunchRequest) { request in
                handleExternalLaunchRequest(request)
            }
            .fullScreenCover(item: $activeSession) { session in
                ScannerPresentation(
                    session: session,
                    playScanSound: playScanSound,
                    defaultZoomLevel: scannerZoomLevel,
                    scanArea: scannerScanArea,
                    flashlightModeRawValue: $scannerFlashlightModeRawValue
                ) { result in
                    handleScannedCode(result, for: session)
                } onCancel: {
                    handleScannerCancel(for: session)
                }
            }
        }
    }

    private func handleExternalLaunchRequest(_ request: KeyboardScanRequest? = nil) {
        let request = request ?? externalLaunchRequest
        guard let request, request.id != handledLaunchRequestID else { return }

        handledLaunchRequestID = request.id
        activeSession = ScannerSession(
            id: request.id,
            source: request.launchedFromKeyboard ? .keyboard : .app,
            scanFormatProfile: scanFormatProfile,
            returnTarget: returnTarget,
            customReturnURL: customReturnURL
        )
    }

    private func handleScannedCode(_ result: ScannerCodeResult, for session: ScannerSession) {
        guard !result.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        ScanSoundPlayer.shared.playIfEnabled(playScanSound)
        lastScannedCode = result.value

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

        SharedKeyboardState.queuePendingInsertion(result.value, requestIdentifier: session.id)

        let returnDelay: TimeInterval = playScanSound ? 0.45 : 0.2

        DispatchQueue.main.asyncAfter(deadline: .now() + returnDelay) {
            SourceAppReturnController.openReturnTarget(
                session.returnTarget,
                customURLString: session.customReturnURL
            )
        }
    }

    private func handleScannerCancel(for session: ScannerSession) {
        activeSession = nil

        guard session.source == .keyboard else { return }

        SharedKeyboardState.consumedScanIdentifier = session.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            SourceAppReturnController.openReturnTarget(
                session.returnTarget,
                customURLString: session.customReturnURL
            )
        }
    }
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
                message: "Tap Scan, scan the barcode or QR code, and Blip returns to the original app."
            )

            ScannerWorkflowGuideRow(
                systemImage: "text.cursor",
                title: "Inserted where you started",
                message: "The barcode is inserted into the original text field with your configured suffix."
            )

            Divider()

            ScannerWorkflowGuideRow(
                systemImage: "keyboard.badge.ellipsis",
                title: "Best company setup",
                message: "Remove unused keyboards in iOS Keyboard settings so employees do not accidentally switch to a keyboard without Scan."
            )
        }
        .padding(.vertical, 4)
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
    let scanFormatProfile: ScanFormatProfile
    let returnTarget: ReturnTarget
    let customReturnURL: String

    var title: String {
        switch source {
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
    @Binding var flashlightModeRawValue: String
    let onCode: (ScannerCodeResult) -> Void
    let onCancel: () -> Void

    @State private var isTorchAvailable = false
    @State private var isTorchOn = false
    @State private var scannerStatusMessage: String?
    @State private var scannedCode: String?
    @State private var currentZoomFactor = 1.0

    private var flashlightMode: ScannerFlashlightMode {
        ScannerFlashlightMode(rawValue: flashlightModeRawValue) ?? .off
    }

    var body: some View {
        NavigationStack {
            ZStack {
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

                if scanArea == .centeredBox, BarcodeScannerView.isScannerAvailable {
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
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        flashlightModeRawValue = (flashlightMode == .on ? ScannerFlashlightMode.off : ScannerFlashlightMode.on).rawValue
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
                    detail: session.returnTarget.title,
                    systemImage: "arrowshape.turn.up.backward.fill",
                    color: .blue
                )
                .padding(.top, 18)
            }

            Spacer()

            if BarcodeScannerView.isScannerAvailable {
                ZoomIndicator(value: currentZoomFactor)
                    .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }

    private func handleCode(_ result: ScannerCodeResult) {
        guard scannedCode == nil else { return }

        scannedCode = result.value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onCode(result)
        }
    }
}

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
