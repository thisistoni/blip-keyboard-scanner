import UIKit

@MainActor
enum SystemSettingsOpener {
    static func openKeyboardSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }

        UIApplication.shared.open(url)
    }
}
