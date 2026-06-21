# Fastlane

Blip uses Fastlane for screenshot workflow plumbing, not as the only capture method.

The real App Store story includes Safari, the custom keyboard, live camera scanning, and returning to the original text field. Those shots should be captured manually on a real iPhone and placed in:

```text
Marketing/AppStore/raw/manual/iphone
```

Use Fastlane for repeatable app-screen capture and review helpers:

```sh
FASTLANE_SKIP_UPDATE_CHECK=1 bundle exec fastlane ios screenshot_status
FASTLANE_SKIP_UPDATE_CHECK=1 bundle exec fastlane ios frame_raw_screenshots
```

The `capture_app_screenshots` lane is reserved for simulator-only screens after a dedicated `BlipScreenshots` UI-test scheme is added. It should cover setup, settings, and localized app screens; it should not try to fake the camera or Safari keyboard handoff flow.
