# Blip KeyboardKit prototype

Development build **1.0.4 (30)** on branch `codex/keyboardkit-premium`, based on `a29dded` / main. This prototype is not submitted to App Store Connect and remains unmerged pending the remaining physical checks. See the [current combined validation summary](../RELEASE_1_0_4_QA.md); the investigation sections below retain their original build-specific limits.

## Dependency and license

KeyboardKit is pinned to **exactly 9.9.0**, revision `a7e33ac2e6f47e16288ce09ec8d765cd329f918c`, in both the checked-in Xcode project and project.yml; Package.resolved records the same version/revision. The inspected Package.swift has no external dependencies. EmojiKit and GestureButton sources are bundled inside this release. The MIT license and attribution are included in both app and extension bundles via Shared/KeyboardKit-LICENSE.txt. No Pro binary, license key, or newer KeyboardKit license is used.

Reference source: https://github.com/KeyboardKit/KeyboardKit/tree/9.9.0

## Implemented core capabilities

- KeyboardKit SwiftUI key rendering, native-style adaptive key colors, shadows, pressed states and touch areas. Opaque systemGray4 root background removed; the view renderer's background disabled so the system keyboard contour/backdrop can remain visible.
- Lowercase letters use regular weight instead of the core's light weight, retaining context-dependent font sizes. Optional System / Blip Blue appearance is in Blip → Settings → Keyboard Appearance → Appearance (DE: Tastaturdesign → Design). System is the default for absent/unknown preferences; this app-group preference does not modify layout choices. New company profiles include appearance and keyboard feedback choices; older profiles leave omitted choices unchanged. Blip Blue covers the complete extension-owned panel, all characters/numbers/space/modifiers, Scan/Insert and input/accent popups, with separate opaque light/dark blue palettes, clear pressed states and bright primary/active Shift keys. Extra outlines apply under Increase Contrast. Only the background panel is clipped to 12-point top corners; callouts are not clipped. System keeps the transparent root and system contour/backdrop. In System dark mode, opaque gray ordinary keys (white 0.365, approximately #5D5D5D), modifiers (0.255, approximately #414141), pressed keys (0.47, approximately #787878), and white active Shift replace backdrop-dependent alpha-white assets. This is native-like styling, not a measured exact native match. No credits screen is added; full MIT notices remain bundled.
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

## Native keyboard scan test

Build 14 replaces the Scan page’s direct Test Scanner button with a real native test field using the installed Blip extension. The request/field-scoped test stays in Blip and automatically inserts without modifying saved return/Auto Insert preferences; external scans retain their route. See [KEYBOARD_SCAN_TEST.md](KEYBOARD_SCAN_TEST.md) for the cooperative field tag, lifecycle boundaries, checks and physical acceptance steps. Theme rendering is unchanged. ANT-67 tracks this feature separately from ANT-65.

## Debug-only geometry investigation

### Host disconnection crash found during combined validation

Physical iPhone crash reports for build 27 on October 15 identified two delayed reads of a disconnected text-input host. KeyboardKit's queued `KeyboardContext.syncAfterAsync(with:)` and Blip's queued `settledLayout` diagnostic both reached `UIInputViewController.needsInputModeSwitchKey` and crashed in UIKit's `_UITextDocumentInterface._controllerState`. An earlier diagnostic crash reached the proxy's `returnKeyType`. The visible symptom was an unexpected fallback to the system keyboard.

Build 28 snapshots the native globe requirement synchronously in `viewWillAppear`; the overridden getter serves that snapshot to KeyboardKit's deferred sync. Geometry diagnostics no longer inspect live text-input traits. Pending insertion is cancelled before disappearance, and delayed insertion, newline and text-change processing require a presented keyboard. This changes lifecycle handling, not keyboard appearance or height. Debug/Release builds and scan/session/profile checks pass.

Five physical iPhone cycles of Chrome → system keyboard → Blip keyboard → Blip's native test field passed on build 28. The extension retained the same diagnostic process identifier throughout. A subsequent real camera scan with Auto Insert on returned to the same Chrome test page/field and inserted one code plus the configured newline, with Blip selected and the pending token consumed. With Auto Insert off, a fresh camera result returned to an empty Chrome field with Blip selected; tapping Insert inserted once and consumed the token. Post-scan crash-report copies contained no build 28 reports. The extension process identifier stayed unchanged between the two camera retests; continuity is not claimed between the earlier switching stress test and the later camera tests.

The native-field camera retest also passed on build 28 with Safari configured and Auto Insert off: the real field contained exactly one code, corroborated by one proxy write/consumption and the native field's text-change event. Normal scan/history state remained unchanged. The Mac's battery interruption stopped WebDriverAgent, so control was restarted before inspecting the actual field; the saved app/extension trace survived. The subsequent device crash inventory contained no new Blip reports. This validates these tested paths, not broader iPad, older-iOS or VoiceOver behavior.

Build 12 adds numeric-only diagnostics after layout, appearance and host resume, plus an invisible, noninteractive background UIView probe for the SwiftUI panel. All instrumentation is under `#if DEBUG`. It does not change colors, sizing, constraints, content or safe-area handling. Records include frames/bounds, window and screen coordinate conversions, safe-area insets, ordinary/directional layout margins, window/screen dimensions and scale, and up to eight ancestor class/geometry entries. No proxy text, clipboard, scan values or full view descriptions are read or logged.

The physical USB log relay connects successfully. Its 1,024-byte message limit truncated the initial records; compact per-view records fixed that. Build 13 additionally resamples the panel after its hosting ancestor moves, avoiding a stale initial probe position. User confirmed Spotlight was open with Blue selected and the strip visible. The supplied screenshot was inspected at its original 1320×2868 resolution; this is user-supplied visual evidence, not a successful automated device screenshot.

### Measured result

The settled root, input, hosting and SwiftUI panel rectangles are **(0, 0, 440, 256)** in the extension window. Every safe-area inset is **0**. Root/input/hosting layout margins are **(0, 20, 0, 20)**, so there is no top layout margin; the measuring UIView's default 8-point margins do not inset its measured full-size rectangle. Screen bounds are 440×956 points at 3× scale.

At the reference screenshot's centerline, the gray container starts at pixel y=1824, Blue starts at 1875, and Blue ends at 2643. Thus the upper gray band is 51 pixels = **17 points**, while Blue is 768 pixels = **256 points**, matching the entire settled drawable rectangle. The panel has no top offset or uncovered strip inside the root. The band is outside Blip's measured surface, in the host/system container; its specific private owner/class is not observable from the extension. The native globe/microphone region is also outside the 256-point panel. Remote-window `inScreen` values remain local-origin coordinates, not the final on-phone hosting translation (the reference image puts Blue at physical y=625 points).

First presentation transitions through a full-screen 956-point viewport with the 256-point panel centered at local y=350; one brief 245-point root phase puts the panel at y=-5.333. It then settles to 256 points and panel y=0. Repeated shows settled identically. A host-resume sample at 23:12:38 also measured all four rectangles as (0,0,440,256) with zero safe areas. The user's fleeting disappearance of the strip occurred during presentation, but no synchronized video establishes which transition frame caused that visual change; it is not evidence of a 17-point safe-area bug.

Numeric snapshots are in [keyboard-geometry-measurements.json](keyboard-geometry-measurements.json). Only diagnostic code and the build number changed; no appearance adjustment was made.

### Supported options and limits

The settled sample has no internal top inset. It locates the gray band in that screenshot, but covers only one activation path and does not establish that a persistent surrounding gap is unavoidable. Painting outer hosting/input backgrounds was physically rejected in build 10; keep the accepted panel and its rounded top corners while investigating the actual presentation difference.

### Activation-path comparison (2026-10-15)

Antonio reports a difference in the same host and field: opening with Blip already selected removes the gap above Scan, while manually switching from another keyboard to Blip introduces it. The earlier single-path measurement cannot explain this comparison.

A fresh build-24 device snapshot again records an initial 440×224-point root/input/hosting viewport with the 440×256-point panel at y=-16. The layout then settles to 440×256 with panel y=0 and zero safe-area insets. This demonstrates an initial height mismatch, but has not yet been tied to either reported activation path or the persistent gap.

Build 26 adds DEBUG-only, bounded activation timelines alongside the previous latest snapshots. The timeline records controller lifecycle, initial setup and asynchronous KeyboardKit context sync, initial/settled frames, intrinsic sizes, vertical constraints, safe areas and numeric input traits. An invisible toolbar probe measures its position separately from the panel. Records carry a process identifier, activation counter and timestamp, so the two paths can be saved independently through the App Group preference `debugKeyboardActivations`. No proxy contents, clipboard, scan values, field identifiers or host-app detection are recorded. The diagnostic change does not set height, add padding, recolor the surrounding container or alter the test-field reload. Physical A/B comparison is saved in [keyboard-activation-paths.json](keyboard-activation-paths.json). In the same Notes note/field, Antonio confirmed no gap after dismissing and reopening with Blip selected, and a gap after cycling back to Blip. The saved active presentations are A=7 and B=4. In both, didAppear measures a 440×224 root and a 440×256 panel at y=-16; after 1.5 seconds all four settle to 440×256, with panel y=0 and toolbar y=1. Safe areas, numeric input traits, asynchronous context state and vertical constraints match. One hosting intrinsic-width sample differs (209.333 versus 440), with the same actual width and height. The initial height mismatch therefore does not explain the persistent visible difference.

A [firsthand Apple Developer Forums report](https://developer.apple.com/forums/thread/843093) describes matching behavior through iOS 27.0.1: switching from the system letter keyboard adds 17 points while switching from Emoji removes them. Reporters measured a change in the host-owned top constraint while extension bounds and safe areas remained identical, including a plain UIKit keyboard without third-party code. This supports a host presentation-state cause, but Blip's Notes host-owned constraint was not directly measured. QuickTime's local USB screen preview failed, so no paired screenshot or exact pixel comparison is claimed. The desired result is the gap present consistently in both paths. No production spacing workaround has been applied; a fixed internal spacer would add space to both identical extension layouts and cannot selectively correct the external inset.

## Touch-down color feedback — October 15, 2026

Development build 1.0.4 (27) now highlights the key surface immediately on touch-down. This supersedes the earlier pressed-color values above: System uses dark gray/white text in light appearance and light gray/black text in dark appearance; Blue uses #376594/white and #BBD6FB/#102A4C respectively. Build 27 also used those held colors for input and accent callouts. Build 30 instead resolves popup background and foreground through the ordinary, unpressed letter-key style, so the popup matches the surrounding keys in System/Blue and light/dark appearance. Immediate key-down feedback retains its contrasting held surface.

On the physical iPhone running iOS 27.0.1, the bundled SwiftUI drag recognizer sometimes did not deliver the press until roughly 0.75 seconds after UIKit received touch-down. This matches the class of delay described in [KeyboardKit's iOS 27 report](https://keyboardkit.com/blog/2026/09/09/gesture-problems-in-ios-27-public-beta). A passive public UIKit touch observer now drives the visual pressed state and the existing KeyboardKit input-preview callout on iOS 27 and later. It neither recognizes nor prevents a gesture, inserts text, or calls KeyboardKit's action handler. Release, cancellation, reset and view disappearance clear the highlight and dismiss that key's input preview. The preview uses the key geometry in KeyboardKit's existing callout coordinate space; it does not introduce another popup renderer. A release does not dismiss a preview belonging to a different key action. Earlier iOS versions retain KeyboardKit's existing pressed-state path.

KeyboardKit remains pinned to the MIT-licensed 9.9.0. There is no modified package cache, vendored SDK update or paid API dependency. Typing, long-press accents, Delete repeat and cursor movement remain owned by KeyboardKit; this visual repair does not claim to remove its underlying gesture-recognition delay.

Physical checks used WebDriverAgent on an iPhone 16 Pro Max, without a simulator:

- Held and short-pressed keys changed color at initial touch and reset on release in System and Blue, in light and dark appearance.
- The letter accent menu still opened. Individual 90 ms presses entered `q`, `v` and Space exactly once; Delete removed the space.
- Follow-up after user feedback: the input preview and held-key color now appear in the same first pressed video frame, including a 120 ms letter tap and lower-row `v`, in System and Blue. Holding `a` still transitions from the single-letter preview to accent choices. Separate non-overlapping 100 ms automated touches enter `qwe` exactly once. The earlier reused-pointer batch generated unintended events and is excluded from keyboard verification.
- Temporary numeric-only diagnostics measured the style update about 3–5 ms after UIKit touch-down. Video frames confirm the visible change, but their receive timestamps do not establish exact touch-to-display latency.
- Diagnostics were removed before the final in-place installation. Original System theme and light device appearance were restored.

Build 30 physical recordings confirm that letter previews now match ordinary letter keys in System and Blue, in light and dark appearance. Light-mode accent menus were checked in both themes. Signed Debug/Release builds passed, build 30 was installed in place, and the original user preferences plus System/light appearance were restored. This is a popup-color correction; the previously listed gesture, sound/haptic, accessibility and broader-device acceptance limits remain open.

Physical iPad, older-iOS, VoiceOver and multi-touch checks remain unverified. The scan-return workflow was not changed or revalidated in this touch-feedback check. Final visual acceptance remains with the user.

## Feedback limits

Audio replaces KeyboardKit's raw sound-ID playback with UIKit's public `UIDevice.playInputClick()` and `UIInputViewAudioFeedback`. Apple's API respects the system keyboard-click setting; no custom audio session overrides silent mode. Playback is gated on Blip's setting and Full Access. Physical silent-mode behavior remains to be confirmed.

Haptics use KeyboardKit's UIKit feedback generators, gated on Blip's setting and Full Access. There is no public API to read the system keyboard haptics toggle, so Blip exposes its own control; hardware/OS accessibility and haptic settings can suppress output. No vibration fallback or private settings lookup is used. Haptics and sound are implementation claims, not yet confirmed device results.

Apple API reference: https://developer.apple.com/documentation/uikit/uidevice/playinputclick()

## Excluded capabilities

Pro localized layouts, predictive suggestions/autocorrect, Pro dictation, AI and Pro themes are not integrated. Core autocomplete and dictation services remain disabled. The package includes other MIT core components, including emoji models, but Blip does not add an emoji panel or competing layout picker in this prototype.

KeyboardKit 9.9.0 contains optional legacy status inspection and responder-chain URL helpers. Blip does not call its status inspector or URL opener; the existing SwiftUI scan handoff is retained. This is dependency inspection, not an App Review policy clearance or a comprehensive audit of the SDK.

## Verification

- Signed Debug build 13 for paired iPhone 16 Pro Max passed with no compiler warnings.
- Blue foreground/surface contrast calculations passed at least 5.69:1 for all chosen light/dark idle/pressed combinations; this is a color-pair calculation, not a completed physical accessibility audit.
- Full MIT notice in both build 13 bundles matches the source notice byte for byte. No visible credits/licensing screen was added.
- `codesign --verify --deep --strict` passed; existing team, bundle IDs, and App Group retained.
- Existing pending scan token regression checks passed.
- Package version, revision, license and dependency list inspected. App/extension bundle version: 1.0.4 (13).
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
