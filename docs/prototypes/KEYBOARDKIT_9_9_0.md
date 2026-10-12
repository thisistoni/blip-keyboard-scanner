# Blip KeyboardKit prototype

Development build **1.0.4 (11)** on branch `codex/keyboardkit-premium`, based on `a29dded` / main. This prototype is not submitted to App Store Connect and remains unmerged pending Antonio's physical iPhone acceptance.

## Dependency and license

KeyboardKit is pinned to **exactly 9.9.0**, revision `a7e33ac2e6f47e16288ce09ec8d765cd329f918c`, in both the checked-in Xcode project and project.yml; Package.resolved records the same version/revision. The inspected Package.swift has no external dependencies. EmojiKit and GestureButton sources are bundled inside this release. The MIT license and attribution are included in both app and extension bundles via Shared/KeyboardKit-LICENSE.txt. No Pro binary, license key, or newer KeyboardKit license is used.

Reference source: https://github.com/KeyboardKit/KeyboardKit/tree/9.9.0

## Implemented core capabilities

- KeyboardKit SwiftUI key rendering, native-style adaptive key colors, shadows, pressed states and touch areas. Opaque systemGray4 root background removed; the view renderer's background disabled so the system keyboard contour/backdrop can remain visible.
- Lowercase letters use regular weight instead of the core's light weight, retaining context-dependent font sizes. Optional System / Blip Blue appearance is in Blip → Settings → Keyboard Appearance → Appearance (DE: Tastaturdesign → Design). System is the default for absent/unknown preferences; this independent app-group preference does not modify company profiles or layout choices. Blip Blue covers the complete extension-owned panel, all characters/numbers/space/modifiers, Scan/Insert and input/accent popups, with separate opaque light/dark blue palettes, clear pressed states and bright primary/active Shift keys. Extra outlines apply under Increase Contrast. Only the background panel is clipped to 12-point top corners; callouts are not clipped. System keeps the transparent root and system contour/backdrop. In System dark mode, opaque gray ordinary keys (white 0.365, approximately #5D5D5D), modifiers (0.255, approximately #414141), pressed keys (0.47, approximately #787878), and white active Shift replace backdrop-dependent alpha-white assets. This is native-like styling, not a measured exact native match. No credits screen is added; full MIT notices remain bundled.
- Existing Blip layout engine supplies EN QWERTY, own DE QWERTZ/umlaut layout, numbers/symbols, large numbers and scan-only. Row heights adapt to portrait/landscape; widths are proportional to each profile's existing key weights.
- Native tap/hold globe when required by iOS, via KeyboardKit's UIKit input-mode switch overlay.
- Contextual primary keys (Search, Go, Send, etc.); a return-arrow key for ordinary Return. Primary keys and layout/shift/delete/space/globe controls have human-readable EN/DE accessibility labels. The standard primary action still writes a newline through the real document proxy.
- Input previews and sliding long-press accent/currency/punctuation callouts. Letter-only accent hold delay is 0.35 seconds, reduced from the bundled GestureButton default 0.5 seconds. Other keys retain standard configuration (0.5-second long/repeat delay, 0.2-second double-tap timeout, 50-point max hold drag). UIKit globe tap/hold overlay is unaffected, and space cursor handlers are unchanged. Input popup letters use regular weight. Custom German accent choices include ä/ö/ü/ß without relying on Pro layouts.
- Shift/caps lock, repeat Delete, spacebar cursor dragging, standard auto-capitalization and double-space sentence ending supported by the core handler.
- Separate Key Clicks / Key Haptics controls in Blip Settings and shared app-group state. Haptics use one selection pulse on press, rather than a pulse on both press and release. Callout feedback uses the same guarded feedback service.
- Scan/Insert toolbar retained, with the original SwiftUI openURL scanner launch and shared request identifiers. Pending-scan scheduling, once-only consumption, insert suffix and Safari manual insertion logic retained. No second scan state engine.

## Rendering and theme details

The inspected core resolves the button-style builder in KeyboardViewItem, then passes the result to Keyboard.ButtonKey, which paints `background` over `backgroundColor`. Blip clears any background layer before applying its opaque Blue colors, so they affect real key shapes, including idle keys. KeyboardView uses the environment callout style because the installed standard style service returns nil; both popup bodies and button overlays consume that style. The SwiftUI panel is painted behind the complete KeyboardView, not clipped around the popup-bearing view. Build 11 restores build 9's bounded rendering exactly: input and hosting views stay transparent, and only the SwiftUI Blue panel is painted with its 12-point top-corner mask. Build 10's outer fill was rejected after physical testing: corners appeared unrounded, Blue overflowed the gray container, and the top strip remained. The assumption that the reported strip was uncovered extension-owned space was not established by visual evidence. No further geometry change is attempted until a real screenshot or live preview identifies the strip's relationship to the extension bounds. Spacers stay transparent over the Blue panel. iOS-owned globe/home-indicator space outside the extension's surface is not recolored.

| Surface | Blue light sRGB | Blue dark sRGB |
| --- | --- | --- |
| Panel | #BCD2F2 | #101F3B |
| Letters/numbers/space/popups | #EEF5FF | #23466E |
| Modifiers | #C8DDFA | #193655 |
| Pressed ordinary/modifier | #90B7ED | #376594 |
| Ordinary text | #102A4C | #F3F8FF |
| Scan/Insert/Return/active Shift/selected accent | #245AB5 | #2E65AE |
| Pressed emphasized | #1B4385 | #1B4385 |
| Emphasized text | #FFFFFF | #FFFFFF |

Lowercase key weight is regular; KeyboardKit's standard font sizing remains intact (normally 26-point lowercase / 23-point uppercase on iPhone; context can adjust sizes). Large-number keys remain 28-point regular; the layout switch remains 15-point medium. No exact native color or timing equivalence is claimed.

## Feedback limits

Audio replaces KeyboardKit's raw sound-ID playback with UIKit's public `UIDevice.playInputClick()` and `UIInputViewAudioFeedback`. Apple's API respects the system keyboard-click setting; no custom audio session overrides silent mode. Playback is gated on Blip's setting and Full Access. Physical silent-mode behavior remains to be confirmed.

Haptics use KeyboardKit's UIKit feedback generators, gated on Blip's setting and Full Access. There is no public API to read the system keyboard haptics toggle, so Blip exposes its own control; hardware/OS accessibility and haptic settings can suppress output. No vibration fallback or private settings lookup is used. Haptics and sound are implementation claims, not yet confirmed device results.

Apple API reference: https://developer.apple.com/documentation/uikit/uidevice/playinputclick()

## Excluded capabilities

Pro localized layouts, predictive suggestions/autocorrect, Pro dictation, AI and Pro themes are not integrated. Core autocomplete and dictation services remain disabled. The package includes other MIT core components, including emoji models, but Blip does not add an emoji panel or competing layout picker in this prototype.

KeyboardKit 9.9.0 contains optional legacy status inspection and responder-chain URL helpers. Blip does not call its status inspector or URL opener; the existing SwiftUI scan handoff is retained. This is dependency inspection, not an App Review policy clearance or a comprehensive audit of the SDK.

## Verification

- Signed Debug build 11 for paired iPhone 16 Pro Max passed with no compiler warnings.
- Blue foreground/surface contrast calculations passed at least 5.69:1 for all chosen light/dark idle/pressed combinations; this is a color-pair calculation, not a completed physical accessibility audit.
- Full MIT notice in both build 11 bundles matches the source notice byte for byte. No visible credits/licensing screen was added.
- `codesign --verify --deep --strict` passed; existing team, bundle IDs, and App Group retained.
- Existing pending scan token regression checks passed.
- Package version, revision, license and dependency list inspected. App/extension bundle version: 1.0.4 (11).
- Installed in place on the paired physical iPhone, preserving the application identifier and without uninstalling or clearing app-group preferences.
- No simulator launched, new runtime downloaded, or parallel build started. One build worker; indexing disabled.
- Build 9 theme design has user acceptance, except for the reported gray top area. Build 11 restoration of bounded rendering, detailed gesture/feedback and scan round-trip results are pending user testing. iPad, floating mode, orientation matrix and VoiceOver are also unverified. ANT-65 remains In Progress.

## Phone acceptance checklist

1. Open a field in Settings search, Safari or Notes and select Blip. Compare System dark ordinary/modifier colors with the system keyboard. Select Blip Blue in Settings and reopen the keyboard; check every key, panel edge, space/modifier, pressed/active state, popup, light/dark mode and Increase Contrast. Rotate where supported.
2. Test ordinary Return in Notes and Search/Go in corresponding fields. Hold a/o/u/s for accent choices; tap Shift once and twice; hold Delete; hold/drag Space.
3. Cycle letters, numbers and large numbers. Test German umlauts and English. Disable all layout slots to check scan-only; then restore preferences.
4. With Full Access, toggle Key Clicks/Key Haptics in Blip Settings. Reopen the keyboard. Check both off/on, system keyboard clicks off/on and silent mode. Report suppressed/extra feedback rather than assuming it works.
5. Real physical scan from Chrome/Brave: return to the original field and confirm one insertion with Auto Insert on; check manual Insert with it off. In Safari, manually return to the original tab and use Insert Last Scan. Check repeat cycles and globe tap/hold.

## First physical user feedback

Antonio tested build 7 on his iPhone and reported: “wow feels much better than what we had”; subsequent feedback also said it looks much better. This confirms a positive overall physical-device impression. It does not separately verify every gesture, Return context, sound/haptic toggle, silent mode, light/dark/orientation combination or scan round trip. Build 8 was tested: Antonio reported dark System keys did not match the native keyboard, accent holds felt too slow, and the partial blue styling was unsatisfactory. Build 9 addresses those specific reports with opaque dark grays, a shorter letter hold and full blue surfaces. Antonio accepted build 9's full Blue design and said System looks fine, with a remaining gray area above Blue. Build 10 was worse on the phone: unrounded corners, Blue overflow and the original gray strip remaining. Build 11 removes only its outer input/hosting fill and returns the keyboard controller source byte for byte to build 9. The top strip remains unresolved. USB screenshot capture previously failed with Invalid service and then No device found; no active phone-mirroring/QuickTime preview was present in the Mac app inventory. No new capture attempt or screenshot verification is claimed. Native equivalence, detailed orientation/Increase Contrast/popup selection and physical timing have not been measured. Keep those specific acceptance checks open.
