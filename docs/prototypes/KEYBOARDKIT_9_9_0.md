# Blip KeyboardKit prototype

Development build **1.0.4 (7)** on branch `codex/keyboardkit-premium`, based on `a29dded` / main. This prototype is not submitted to App Store Connect and remains unmerged pending Antonio's physical iPhone acceptance.

## Dependency and license

KeyboardKit is pinned to **exactly 9.9.0**, revision `a7e33ac2e6f47e16288ce09ec8d765cd329f918c`, in both the checked-in Xcode project and project.yml; Package.resolved records the same version/revision. The inspected Package.swift has no external dependencies. EmojiKit and GestureButton sources are bundled inside this release. The MIT license and attribution are included in both app and extension bundles via Shared/KeyboardKit-LICENSE.txt. No Pro binary, license key, or newer KeyboardKit license is used.

Reference source: https://github.com/KeyboardKit/KeyboardKit/tree/9.9.0

## Implemented core capabilities

- KeyboardKit SwiftUI key rendering, native-style adaptive key colors, shadows, pressed states and touch areas. Opaque systemGray4 root background removed; the view renderer's background disabled so the system keyboard contour/backdrop can remain visible.
- Existing Blip layout engine supplies EN QWERTY, own DE QWERTZ/umlaut layout, numbers/symbols, large numbers and scan-only. Row heights adapt to portrait/landscape; widths are proportional to each profile's existing key weights.
- Native tap/hold globe when required by iOS, via KeyboardKit's UIKit input-mode switch overlay.
- Contextual primary keys (Search, Go, Send, etc.); a return-arrow key for ordinary Return. The standard primary action still writes a newline through the real document proxy.
- Input previews and sliding long-press accent/currency/punctuation callouts. Custom German accent choices include ä/ö/ü/ß without relying on Pro layouts.
- Shift/caps lock, repeat Delete, spacebar cursor dragging, standard auto-capitalization and double-space sentence ending supported by the core handler.
- Separate Key Clicks / Key Haptics controls in Blip Settings and shared app-group state. Haptics use one selection pulse on press, rather than a pulse on both press and release. Callout feedback uses the same guarded feedback service.
- Scan/Insert toolbar retained, with the original SwiftUI openURL scanner launch and shared request identifiers. Pending-scan scheduling, once-only consumption, insert suffix and Safari manual insertion logic retained. No second scan state engine.

## Feedback limits

Audio replaces KeyboardKit's raw sound-ID playback with UIKit's public `UIDevice.playInputClick()` and `UIInputViewAudioFeedback`. Apple's API respects the system keyboard-click setting; no custom audio session overrides silent mode. Playback is gated on Blip's setting and Full Access. Physical silent-mode behavior remains to be confirmed.

Haptics use KeyboardKit's UIKit feedback generators, gated on Blip's setting and Full Access. There is no public API to read the system keyboard haptics toggle, so Blip exposes its own control; hardware/OS accessibility and haptic settings can suppress output. No vibration fallback or private settings lookup is used. Haptics and sound are implementation claims, not yet confirmed device results.

Apple API reference: https://developer.apple.com/documentation/uikit/uidevice/playinputclick()

## Excluded capabilities

Pro localized layouts, predictive suggestions/autocorrect, Pro dictation, AI and Pro themes are not integrated. Core autocomplete and dictation services remain disabled. The package includes other MIT core components, including emoji models, but Blip does not add an emoji panel or competing layout picker in this prototype.

KeyboardKit 9.9.0 contains optional legacy status inspection and responder-chain URL helpers. Blip does not call its status inspector or URL opener; the existing SwiftUI scan handoff is retained. This is dependency inspection, not an App Review policy clearance or a comprehensive audit of the SDK.

## Verification

- Signed Debug build for paired iPhone 16 Pro Max passed with no compiler warnings after fixing the initial incorrect API method call.
- `codesign --verify --deep --strict` passed; existing team, bundle IDs, and App Group retained.
- Existing pending scan token regression checks passed.
- Package version, revision, license and dependency list inspected. App/extension bundle version: 1.0.4 (7).
- Installed in place on the paired physical iPhone, preserving the application identifier and without uninstalling or clearing app-group preferences.
- No simulator launched, new runtime downloaded, or parallel build started. One build worker; indexing disabled.
- New phone visual/gesture/feedback and scan round-trip results are pending user testing. iPad, floating mode, orientation matrix and VoiceOver are also unverified. ANT-65 remains In Progress.

## Phone acceptance checklist

1. Open a field in Settings search, Safari or Notes and select Blip. Compare light/dark contours and key colors; rotate where supported.
2. Test ordinary Return in Notes and Search/Go in corresponding fields. Hold a/o/u/s for accent choices; tap Shift once and twice; hold Delete; hold/drag Space.
3. Cycle letters, numbers and large numbers. Test German umlauts and English. Disable all layout slots to check scan-only; then restore preferences.
4. With Full Access, toggle Key Clicks/Key Haptics in Blip Settings. Reopen the keyboard. Check both off/on, system keyboard clicks off/on and silent mode. Report suppressed/extra feedback rather than assuming it works.
5. Real physical scan from Chrome/Brave: return to the original field and confirm one insertion with Auto Insert on; check manual Insert with it off. In Safari, manually return to the original tab and use Insert Last Scan. Check repeat cycles and globe tap/hold.

## First physical user feedback

Antonio tested the installed prototype on his iPhone and reported: “wow feels much better than what we had”. This confirms a positive overall physical-device impression. It does not separately verify every gesture, Return context, sound/haptic toggle, silent mode, light/dark/orientation combination or scan round trip. Keep those specific acceptance checks open.
