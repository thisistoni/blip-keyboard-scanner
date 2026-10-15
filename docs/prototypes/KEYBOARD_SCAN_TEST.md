# Real keyboard scan test

Prototype build **1.0.4 (23)** replaces the Scan page's Test Scanner button with a native UITextField. It uses the installed keyboard extension selected by the user, the existing camera scanner, and the extension's real textDocumentProxy insertion. The app never assigns a decoded result directly to the text field or simulates a keyboard.

## User flow

1. Open Blip → Scan and tap Scan result under Test the Blip keyboard.
2. Select Blip with the native globe menu and tap Scan on the extension.
3. Scan a real barcode/QR code. The camera dismisses, the same test field regains focus, and the extension inserts the result once.
4. Repeat or cancel. Try with an external return target configured and Auto Insert off; the test stays in Blip and still inserts automatically. Saved preferences are unchanged.

The keyboard keeps the normal Scan / Insert Last Scan toolbar. A saved last scan remains manually insertable in the test field; a fresh test result takes precedence while waiting for insertion. There is no test-specific keyboard layout or palette. Build 20 restores the original extension input-view sizing. The global self-sizing/intrinsic-height experiments in builds 15–19 were removed after Antonio reported an invisible keyboard in Spotlight. Only the native test field requests a one-time reload of its current input views after keyboardDidShow. No extension height, test-specific padding, palette or key layout is changed.

The normal insert suffix is retained, including a field-tag guard on delayed newline insertion. Test results are stored separately from the normal pending-scan slot and do not overwrite normal last-scan, clipboard or history state. They are consumed by the extension, not pasted programmatically by the app.

## Scope and lifecycle

Before becoming first responder, the cooperating native field sets an explicit UITextContentType raw-value tag containing a fresh UUID ownership nonce. Intentional scanner return reuses that nonce. The keyboard reads the optional public input trait, adds the matching nonce to the ordinary scan URL, and stores a one-use request ID. This is explicit field cooperation, not host-app detection. Physical forwarding of this custom trait was confirmed by the build 23 trace and successful native-field insertion.

The app validates its local field nonce, shared owner, lease, request ID, phase and keyboard source before opening the test camera. Invalid/stale tagged requests fail closed and do not fall back to the configured browser. Ordinary external fields have no test tag and retain the existing return/insertion flow even if an abandoned shared record remains.

Shared state lives in Shared/KeyboardSettings.swift. Its phases are editing → launching → scanning → returning → ready → editing. Payloads use separate slots per ownership generation, preventing delayed cross-process writes from overwriting a newer test. Only the app renews the 10-minute lease while its field/scanner is active. Backgrounding, leaving the Scan tab, ordinary loss of field focus, and app restart invalidate ownership; focus loss during an intentional launch/camera handoff is preserved. Cancel returns to the field without a pending result. A late camera callback after cancellation cannot queue a result or open a browser.

The test alone enables automatic insertion, independent of the saved Auto Insert setting. The extension checks the current field tag immediately before writing and before a delayed suffix. Consuming a test does not overwrite the normal consumed-scan token. The nonnullable SDK documentIdentifier getter is deliberately never read: earlier physical Brave testing showed it can return nil and crash during Swift bridging.

## Verification and acceptance boundary

- Physical-device Debug build passed without compiler warnings, one worker and indexing disabled; no simulator.
- Protocol and existing pending-scan/profile checks pass: foreign field, invalid source, expired/revoked ownership, stale request/replay, cancel, URL round-trip and one-use insertion.
- Static check confirms no documentIdentifier read in the implementation; no return-target/Auto Insert preference writes were added.
- Antonio confirmed a real camera → native test field insertion on the paired iPhone 16 Pro Max in build 23. The trace retains one owner through scanning/returning/ready, issues one extension proxy write, consumes the request, and records the native first responder receiving text. The saved return target was Safari and the saved Auto Insert setting remained its default; the test stayed in Blip.
- Build 27: canceling the real scanner returned to the empty native field without insertion. A scanned company profile opened its preview, and canceling preserved the configuration.
- Build 27 scrolls the focused test field above the keyboard after presentation and allows interactive keyboard dismissal. Both behaviors were checked on the physical iPhone.
- Build 27: a real camera scan with Safari configured and Auto Insert off returned to Blip and inserted the test value exactly once. Device preferences retained those choices; the extension trace shows one proxy write and consumption, followed by the native field receiving text. The normal last scan and history remained unchanged.
- Build 27: repeating the real camera scan produced exactly one additional copy in the native field, with one new proxy write and consumption. Opening the scanner again and canceling retained those two results without another insertion. An unsupported profile QR displayed its warning and left the field, settings, normal last scan and history unchanged.
- Build 27: letters, symbols and large-number layout cycling, number entry, deletion, globe switching out and back, and landscape letter entry/deletion passed on the physical iPhone. The test field and keyboard controls remained visible in landscape. This does not resolve the separately documented activation-spacing inconsistency.
- Build 27 external regression check: a real scan from a separate Chrome textarea returned to the same test page and field, retained the Blip keyboard, and inserted the code once plus the configured newline. The native test did not intercept the external scan. The ordinary pending token was consumed and normal scan/history state updated as expected.
- Build 27 with Auto Insert off returned to an empty Chrome field with a fresh, unconsumed scan. The extension crashed during that return; after explicitly reselecting Blip, the field still remained empty until Insert Last Scan was tapped, which inserted once plus the configured newline. This verifies the preference/manual-insertion behavior, not stability of that build. The crash and build 28 repair are documented in the keyboard notes.
- Build 28: five physical cycles between Chrome, the system keyboard, Blip's keyboard and its native test field passed. The extension process identifier stayed unchanged and no new Blip crash report appeared during this test.
- Scan round trips after the build 28 lifecycle repair, other external apps, iPad, older iOS and VoiceOver require further physical verification.

Tracks ANT-67. ANT-65 remains separate visual/feedback validation. This is part of the existing keyboard prototype PR; no merge or App Store submission is authorized yet.

## Physical sizing investigation

On the user-confirmed test field in build 17, the initial root/input/hosting bounds were 440×224 points while the SwiftUI panel remained 440×256 and was centered at y=−16. About one second later all four settled to (0,0,440,256), with zero safe-area insets and no top layout margin. That settled size matches the earlier external-app measurement. The initial undersized container explains an initial top overflow, but does not prove the cause of any persistent difference in the surrounding host/system region. A fresh build 18 test-field snapshot measured root and panel at (0,0,440,256) from didAppear through settledLayout: the initial −16-point panel offset is absent. Antonio still observed different surrounding top spacing on first display, which matches other apps after switching keyboards and returning to Blip. Build 19 asks the test UITextField to reload its native input views once after keyboardDidShow, retaining its first responder, selected extension and test identity. Antonio confirmed build 19’s test-field spacing matches immediately. He then reported an invisible keyboard in Spotlight. Build 20 removes both global extension sizing changes while retaining that field-only refresh; Antonio confirmed both Spotlight and first-display test-field appearance are correct in build 20. He then reported that a scanned result did not appear in the test field.

DEBUG-only geometry snapshots are saved as bounded numeric records in the app group (file plus shared-preferences fallback), with capture timestamps. They include no proxy text, clipboard values or barcode contents. The collector retains windowless/empty layouts and marks non-finite rectangle components as null instead of discarding the record. No release build enables the collector.

## Native field contents and return ordering

Build 21 removes the unused SwiftUI text binding and all assignments to UITextField.text. The native field owns its content; updates to focus or other app state cannot restore an obsolete SwiftUI text snapshot over an extension insertion. A returning result becomes ready in textFieldShouldBeginEditing, before UIKit requests the extension/proxy, rather than in textFieldDidBeginEditing afterward. Every still-owned phase and its nonce survive repeated focus preflights, including launching/scanning before focus completes. Only revocation or expiry creates a new owner. The ordinary keyboard and its sizing remain unchanged. Protocol checks pass; the full camera-to-native-field round trip was physically confirmed in build 23.

Build 22’s physical trace identified the actual dropped-result path: UIKit preflighted field focus while the live session was scanning and the focused binding was false. The previous preparation guard replaced that owner, so camera completion could no longer match its session and discarded the result. Build 23 preserves the live owner in every phase. The DEBUG trace uses separate bounded app/extension rings with phase, generated session ID and boolean input/focus flags; it never records barcode or field contents. Antonio confirmed the result appears in build 23, corroborated by the native input trace. The previously observed owner replacement during scanning is absent.
