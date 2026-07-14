import SwiftUI

@main
struct BlipApp: App {
    init() {
#if DEBUG
        ScreenshotAutomation.prepareIfNeeded()
#endif
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let screenshotScene = ScreenshotAutomation.scene {
                AppStoreScreenshotRootView(scene: screenshotScene)
            } else {
                AppRootView()
            }
#else
            AppRootView()
#endif
        }
    }
}
