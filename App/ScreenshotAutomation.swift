#if DEBUG
import SwiftUI

enum AppStoreScreenshotScene: String {
    case scan
    case scanner
    case history
    case settings
    case profiles
    case privacy

    // Review-only scenes: not part of the App Store screenshot lane. They show
    // screens that otherwise need a camera, a keyboard round trip or taps.
    case batch
    case historyBatch
    case keyboardSettings
    case scannerSettings
    case returnSettings
    case setup
    case profilePreview
    case profileQR
    case guidance
}

enum ScreenshotAutomation {
    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    static let scene: AppStoreScreenshotScene? = {
        guard let flagIndex = arguments.firstIndex(of: "--app-store-screenshot"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return AppStoreScreenshotScene(rawValue: arguments[flagIndex + 1])
    }()

    static var usesSimulatedCamera: Bool {
        scene == .scanner || scene == .batch
    }

    /// `--test-field-text` fills the Scan tab's test field with a long batch,
    /// to check that the field keeps to its row.
    static var testFieldText: String? {
        guard arguments.contains("--test-field-text") else { return nil }
        return (1...30).map { "40123456789\(String(format: "%02d", $0))" }.joined(separator: ",")
    }

    /// `--test-field-clear` empties that text again after two seconds.
    static var clearsTestFieldText: Bool {
        arguments.contains("--test-field-clear")
    }

    /// The batch review scene opens the scanner in Batch mode with a filled list.
    static var showsBatchReview: Bool {
        scene == .batch
    }

    static func prepareIfNeeded() {
        guard scene != nil,
              let languageIndex = arguments.firstIndex(of: "--screenshot-language"),
              arguments.indices.contains(languageIndex + 1) else {
            return
        }

        SharedKeyboardState.keyboardLanguage = arguments[languageIndex + 1] == "de" ? .german : .english
        if scene == .scan {
            SharedKeyboardState.returnTarget = .chrome
            SharedKeyboardState.autoInsertScans = true
        }
    }

    static let historyItems: [ScanHistoryItem] = [
        ScanHistoryItem(
            value: "4012345678901",
            codeFormat: "EAN13",
            scannedAt: Date(timeIntervalSinceNow: -180),
            source: .keyboard,
            returnTargetRawValue: ReturnTarget.safari.rawValue,
            insertionStatus: .queuedForKeyboardInsertion
        ),
        ScanHistoryItem(
            value: "BLIP-WH-2026-0714",
            codeFormat: "Code128",
            scannedAt: Date(timeIntervalSinceNow: -3_900),
            source: .app,
            returnTargetRawValue: nil,
            insertionStatus: .notQueued
        ),
        ScanHistoryItem(
            value: "https://example.com/setup",
            codeFormat: "QR",
            scannedAt: Date(timeIntervalSinceNow: -86_400),
            source: .keyboard,
            returnTargetRawValue: ReturnTarget.safari.rawValue,
            insertionStatus: .queuedForKeyboardInsertion
        ),
    ]
}

extension ScreenshotAutomation {
    static let reviewBatchEntries: [BatchScanEntry] = [
        BatchScanEntry(value: "4012345678901", codeFormat: "VNBarcodeSymbologyEAN13"),
        BatchScanEntry(value: "https://example.com/products/blip-keyboard-scanner?ref=label&lot=2026-0714", codeFormat: "VNBarcodeSymbologyQR"),
        BatchScanEntry(value: "4012345678901", codeFormat: "VNBarcodeSymbologyEAN13"),
        BatchScanEntry(value: "BLIP-WH-2026-0714", codeFormat: "VNBarcodeSymbologyCode128"),
        BatchScanEntry(value: "LOT,2026,0714", codeFormat: "VNBarcodeSymbologyCode128"),
    ]

    static let reviewHistoryItems: [ScanHistoryItem] = {
        func codes(_ entries: [BatchScanEntry]) -> [ScanHistoryBatchCode] {
            entries.map { ScanHistoryBatchCode(value: $0.value, codeFormat: $0.codeFormat) }
        }
        let eans = (1...12).map { BatchScanEntry(value: "40123456789\(String(format: "%02d", $0))", codeFormat: "VNBarcodeSymbologyEAN13") }
        return [
            ScanHistoryItem(
                value: reviewBatchEntries.map(\.value).joined(separator: ","),
                codeFormat: nil,
                scannedAt: Date(timeIntervalSinceNow: -60),
                source: .keyboard,
                returnTargetRawValue: ReturnTarget.chrome.rawValue,
                insertionStatus: .queuedForKeyboardInsertion,
                batchCodes: codes(reviewBatchEntries)
            ),
            ScanHistoryItem(
                value: eans.map(\.value).joined(separator: "\n"),
                codeFormat: "VNBarcodeSymbologyEAN13",
                scannedAt: Date(timeIntervalSinceNow: -900),
                source: .keyboard,
                returnTargetRawValue: nil,
                insertionStatus: .queuedForKeyboardInsertion,
                batchCodes: codes(eans)
            ),
            ScanHistoryItem(
                value: "https://example.com/products/blip-keyboard-scanner?ref=label&lot=2026-0714&station=warehouse-north-dock-12",
                codeFormat: "VNBarcodeSymbologyQR",
                scannedAt: Date(timeIntervalSinceNow: -2_000),
                source: .keyboard,
                returnTargetRawValue: ReturnTarget.safari.rawValue,
                insertionStatus: .queuedForKeyboardInsertion
            ),
        ] + historyItems
    }()

    static var reviewProfile: BlipCompanyProfile {
        var profile = BlipCompanyProfile.current
        profile.scannerScanMode = SharedKeyboardState.scannerScanMode == .batch ? "single" : "batch"
        profile.batchSeparator = SharedKeyboardState.batchSeparator == .newline ? "comma" : "newline"
        profile.batchSkipDuplicates = !SharedKeyboardState.batchSkipDuplicates
        return profile
    }
}

struct AppStoreScreenshotRootView: View {
    let scene: AppStoreScreenshotScene

    var body: some View {
        switch scene {
        case .scan, .scanner, .history, .settings, .batch:
            appTabs
        case .historyBatch:
            HistoryView(screenshotItems: ScreenshotAutomation.reviewHistoryItems)
        case .keyboardSettings:
            NavigationStack { KeyboardSettingsPage() }
        case .scannerSettings:
            NavigationStack { ScannerSettingsPage() }
        case .returnSettings:
            NavigationStack { ReturnInsertionSettingsPage() }
        case .setup:
            SetupFlowView(status: .current, onCheckAgain: {})
        case .profilePreview:
            CompanyProfilePreview(profile: ScreenshotAutomation.reviewProfile, onCancel: {}, onApply: {})
        case .profileQR:
            if let code = try? CompanyProfileQRCode(profile: .current) {
                CompanyProfileQRCodeView(code: code)
            }
        case .guidance:
            KeyboardReturnGuidanceView(
                // The review follows the stored Return Target, e.g. `-returnTarget custom`.
                guidance: KeyboardReturnGuidance(target: SharedKeyboardState.returnTarget, hasPendingScan: true),
                onClose: {}
            )
        case .profiles:
            NavigationStack {
                CompanyProfilesView()
            }
        case .privacy:
            NavigationStack {
                PrivacyTrustView()
            }
        }
    }

    private var selectedTab: Binding<AppStoreScreenshotScene> {
        .constant(scene)
    }

    private var appTabs: some View {
        TabView(selection: selectedTab) {
            ScannerScreen(
                externalLaunchRequest: nil,
                automaticallyPresentScanner: ScreenshotAutomation.usesSimulatedCamera
            )
            .tabItem {
                Label("Scan", systemImage: "barcode.viewfinder")
            }
            .tag(ScreenshotAutomation.usesSimulatedCamera ? scene : .scan)

            HistoryView(screenshotItems: ScreenshotAutomation.historyItems)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppStoreScreenshotScene.history)

            KeyboardLayoutSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppStoreScreenshotScene.settings)
        }
    }
}
#endif
