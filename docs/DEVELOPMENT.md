# Development

## Requirements

- macOS with Xcode installed
- iOS Simulator installed through Xcode
- Apple Developer account for physical-device testing
- XcodeGen, if regenerating `BarcodeKeyboard.xcodeproj` from `project.yml`

```sh
brew install xcodegen
```

## Open The Project

```sh
open BarcodeKeyboard.xcodeproj
```

The checked-in Xcode project is the current working project. Regenerate only when changing `project.yml`:

```sh
xcodegen generate
```

## Build

Simulator:

```sh
xcodebuild -project BarcodeKeyboard.xcodeproj \
  -scheme BarcodeKeyboard \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Physical iPhone:

```sh
xcodebuild -project BarcodeKeyboard.xcodeproj \
  -scheme BarcodeKeyboard \
  -destination 'id=<DEVICE_ID>' \
  build
```

## Install On Device

```sh
xcrun devicectl device install app \
  --device <DEVICE_ID> \
  ~/Library/Developer/Xcode/DerivedData/BarcodeKeyboard-*/Build/Products/Debug-iphoneos/BarcodeKeyboard.app
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
