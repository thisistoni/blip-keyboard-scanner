import Foundation
import UIKit

enum SupportEmail {
    static let supportAddress = "blip@antoniobeslic.com"
    static let privacyPolicyURL = URL(string: "https://thisistoni.github.io/blip-keyboard-scanner/privacy.html")!
    static let supportURL = URL(string: "https://thisistoni.github.io/blip-keyboard-scanner/support.html")!

    static func feedbackURL() -> URL? {
        mailURL(
            subject: "Blip Feedback",
            body: """
            Hi Blip team,


            Feedback:


            Context:
            \(settingsContext())
            """
        )
    }

    static func scanIssueURL(for item: ScanHistoryItem) -> URL? {
        mailURL(
            subject: "Blip Scan Issue",
            body: """
            Hi Blip team,


            What happened:


            Scan:
            Value: \(item.value)
            Format: \(item.codeFormat ?? "Unknown")
            Date: \(Self.dateFormatter.string(from: item.scannedAt))
            Source: \(item.source.title)
            Return Target: \(item.returnTarget?.title ?? "None")
            Insertion Status: \(item.insertionStatus.title)

            Context:
            \(settingsContext())
            """
        )
    }

    static func open(_ url: URL, onFailure: @escaping () -> Void) {
        UIApplication.shared.open(url) { didOpen in
            guard !didOpen else { return }
            DispatchQueue.main.async {
                onFailure()
            }
        }
    }

    static func settingsContext() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let layouts = SharedKeyboardState.enabledKeyboardLayoutSlots
        let layoutSummary = layouts.isEmpty
            ? NSLocalizedString("Scan Only", comment: "Scan only feedback layout value")
            : layouts.map(\.title).joined(separator: ", ")

        return """
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        Return Target: \(SharedKeyboardState.returnTarget.title)
        Keyboard Language: \(SharedKeyboardState.keyboardLanguage.title)
        Keyboard Profile: \(SharedKeyboardState.keyboardType.title)
        Layouts: \(layoutSummary)
        Opening Layout: \(SharedKeyboardState.startupKeyboardLayoutSlot?.title ?? NSLocalizedString("Scan Only", comment: "Scan only feedback opening layout value"))
        Scan Format Profile: \(SharedKeyboardState.scanFormatProfile.title)
        Default Flashlight: \(SharedKeyboardState.scannerFlashlightMode.title)
        Default Zoom: \(SharedKeyboardState.scannerZoomLevel.title)
        Scan Area: \(SharedKeyboardState.scannerScanArea.title)
        """
    }

    private static func mailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
