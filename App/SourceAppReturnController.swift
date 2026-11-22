import UIKit

@MainActor
enum SourceAppReturnController {
    static func openBrowserReturnTarget(_ target: ReturnTarget, completion: @escaping @Sendable (Bool) -> Void) {
        let scheme: String
        switch target {
        case .chrome: scheme = "googlechrome://"
        case .edge: scheme = "microsoft-edge://"
        case .firefox: scheme = "firefox://"
        case .brave: scheme = "brave://"
        case .safari, .custom:
            completion(false)
            return
        }

        guard let url = URL(string: scheme) else {
            completion(false)
            return
        }

        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }

    /// Opens the app behind a custom URL scheme. The scheme may be given with
    /// or without "://". `completion` reports whether an app opened.
    static func openCustomReturnURL(_ customURLString: String, completion: (@Sendable (Bool) -> Void)? = nil) {
        let trimmed = customURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?(false)
            return
        }

        let normalized = trimmed.contains("://") ? trimmed : trimmed + "://"
        guard let url = URL(string: normalized) else {
            completion?(false)
            return
        }

        UIApplication.shared.open(url, options: [:], completionHandler: completion)
    }
}
