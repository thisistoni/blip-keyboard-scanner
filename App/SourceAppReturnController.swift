import UIKit

@MainActor
enum SourceAppReturnController {
    static func openReturnTarget(_ target: ReturnTarget, customURLString: String) {
        openFirstAvailableURL(from: target.urlCandidates(customURLString: customURLString))
    }

    private static func openFirstAvailableURL(from urls: [URL], index: Int = 0) {
        guard urls.indices.contains(index) else { return }

        UIApplication.shared.open(urls[index], options: [:]) { success in
            guard !success else { return }
            openFirstAvailableURL(from: urls, index: index + 1)
        }
    }
}
