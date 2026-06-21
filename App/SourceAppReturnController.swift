import UIKit

@MainActor
enum SourceAppReturnController {
    static func openReturnTarget(_ target: ReturnTarget, customURLString: String) {
        if let bundleIdentifier = target.bundleIdentifier,
           openApplication(bundleIdentifier: bundleIdentifier) {
            return
        }

        openFirstAvailableURL(from: target.urlCandidates(customURLString: customURLString))
    }

    private static func openApplication(bundleIdentifier: String) -> Bool {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type else {
            return false
        }

        let defaultWorkspaceSelector = NSSelectorFromString("defaultWorkspace")
        guard workspaceClass.responds(to: defaultWorkspaceSelector),
              let workspace = workspaceClass.perform(defaultWorkspaceSelector)?
                .takeUnretainedValue() as? NSObject
        else {
            return false
        }

        let openSelector = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: openSelector) else { return false }

        _ = workspace.perform(openSelector, with: bundleIdentifier)
        return true
    }

    private static func openFirstAvailableURL(from urls: [URL], index: Int = 0) {
        guard urls.indices.contains(index) else { return }

        UIApplication.shared.open(urls[index], options: [:]) { success in
            guard !success else { return }
            openFirstAvailableURL(from: urls, index: index + 1)
        }
    }
}
