#if DEBUG
import SwiftUI

enum AppStoreScreenshotScene: String {
    case scan
    case scanner
    case history
    case settings
    case profiles
    case privacy
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
        scene == .scanner
    }

    static func prepareIfNeeded() {
        guard scene != nil,
              let languageIndex = arguments.firstIndex(of: "--screenshot-language"),
              arguments.indices.contains(languageIndex + 1) else {
            return
        }

        SharedKeyboardState.keyboardLanguage = arguments[languageIndex + 1] == "de" ? .german : .english
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

struct AppStoreScreenshotRootView: View {
    let scene: AppStoreScreenshotScene

    private let setupStatus = SetupVerificationStatus(
        snapshot: KeyboardSetupSnapshot(
            isEnabled: true,
            rawKeyboards: ["com.antoniobeslic.Blip.Keyboard"],
            matchedKeyboard: "com.antoniobeslic.Blip.Keyboard"
        )
    )

    var body: some View {
        switch scene {
        case .scan, .scanner, .history, .settings:
            appTabs
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
                automaticallyPresentScanner: scene == .scanner
            )
            .tabItem {
                Label("Scan", systemImage: "barcode.viewfinder")
            }
            .tag(scene == .scanner ? AppStoreScreenshotScene.scanner : .scan)

            HistoryView(screenshotItems: ScreenshotAutomation.historyItems)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppStoreScreenshotScene.history)

            KeyboardLayoutSettingsView(setupStatus: setupStatus)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppStoreScreenshotScene.settings)
        }
    }
}
#endif
