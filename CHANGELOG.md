# Changelog

## 1.1.0

- Batch scan mode (opt-in): collect up to 50 codes and insert them as one text, joined by a comma, semicolon, space, tab or new line. Single scan stays the default.
- When several codes are in view, each one is outlined and the user taps the code to use.
- A three-step introduction for new installs: how a scan reaches a text field, turning on the keyboard, and choosing the Return Target. It can be reopened in Settings under How Blip Works.
- Custom Return URL: the field explains what to enter, the test button reports when no app opened, and a failed return is shown as a problem instead of "Scan ready".
- History: a batch is one entry, a value stays on one line, and the newest 2,000 entries are kept. History search is removed.
- History is read and written once per scan and no longer rewritten by the setup timer.
- Camera: 4K capture with near-range autofocus, frame analysis off the main queue, and recovery after interruptions.
- Scanner Settings grouped into Camera, Codes, and Single and Batch Scan.

## 1.0.1

- Improve scan return and one-time insertion in supported browser targets.
- Make automatic insertion optional and provide an explicit Insert Last Scan action.
- Explain Safari's manual return path in the app.

## Unreleased

- Replace private bundle-identifier app launching with public URL-scheme return handling.
- Blip branding applied to app name, keyboard display name, Xcode project, targets, schemes, URL scheme, bundle identifiers, and app group.
- Optional Blip sound feedback when a scan succeeds.
- Custom iOS keyboard extension with configurable English/German layouts.
- Optional scan-only keyboard mode and configurable layout cycling.
- Containing app scanner using AVFoundation and Vision.
- Barcode, QR, and advanced scan-format profiles.
- Keyboard-to-app scan handoff with pending insertion through the shared App Group.
- Configurable return targets for Safari, Chrome, Edge, Firefox, Brave, and custom URL schemes.
- Flashlight support in the scanner.
- Setup flow with keyboard detection, settings shortcut, and diagnostics.
- English and German app localization.
- Blip app icon source and brand guidelines.
