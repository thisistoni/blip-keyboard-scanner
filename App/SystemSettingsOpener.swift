import UIKit

@MainActor
enum SystemSettingsOpener {
    static func openKeyboardSettings() {
        openAppSettings()
    }

    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }

        UIApplication.shared.open(url)
    }
}
