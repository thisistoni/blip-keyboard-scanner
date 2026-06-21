# Development

## Requirements

- macOS with Xcode installed
- iOS Simulator installed through Xcode
- Apple Developer account for physical-device testing
- XcodeGen, if regenerating `Blip.xcodeproj` from `project.yml`

```sh
brew install xcodegen
```

## Open The Project

```sh
open Blip.xcodeproj
```

The checked-in Xcode project is authoritative. Regenerate only when changing `project.yml`:

```sh
xcodegen generate
```

## Build

Simulator:

```sh
xcodebuild -project Blip.xcodeproj \
  -scheme Blip \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Physical iPhone:

```sh
xcodebuild -project Blip.xcodeproj \
  -scheme Blip \
  -destination 'id=<DEVICE_ID>' \
  build
```

## Install On Device

```sh
xcrun devicectl device install app \
  --device <DEVICE_ID> \
  ~/Library/Developer/Xcode/DerivedData/Blip-*/Build/Products/Debug-iphoneos/Blip.app
```

## Signing

Both targets need the same App Group capability:

- `group.com.antoniobeslic.Blip`

Targets:

- App bundle id: `com.antoniobeslic.Blip`
- Keyboard extension bundle id: `com.antoniobeslic.Blip.KeyboardExtension`

## Localization

Current localizations:

- `App/en.lproj/Localizable.strings`
- `App/de.lproj/Localizable.strings`

Validate strings files with:

```sh
plutil -lint App/en.lproj/Localizable.strings App/de.lproj/Localizable.strings
```

## App Store Screenshots

Install Fastlane dependencies:

```sh
bundle install --path vendor/bundle
```

Check screenshot folders:

```sh
FASTLANE_SKIP_UPDATE_CHECK=1 bundle exec fastlane ios screenshot_status
```

Place real iPhone workflow screenshots in `Marketing/AppStore/raw/manual/iphone`. Use the Fastlane capture lane only after adding a dedicated screenshot UI-test scheme for simulator-safe app screens.
