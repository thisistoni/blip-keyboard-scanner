# Real keyboard scan test

Prototype build **1.0.4 (20)** replaces the Scan page's Test Scanner button with a native UITextField. It uses the installed keyboard extension selected by the user, the existing camera scanner, and the extension's real textDocumentProxy insertion. The app never assigns a decoded result directly to the text field or simulates a keyboard.

## User flow

1. Open Blip → Scan and tap Scan result under Test the Blip keyboard.
2. Select Blip with the native globe menu and tap Scan on the extension.
3. Scan a real barcode/QR code. The camera dismisses, the same test field regains focus, and the extension inserts the result once.
4. Repeat or cancel. Try with an external return target configured and Auto Insert off; the test stays in Blip and still inserts automatically. Saved preferences are unchanged.

The keyboard keeps the normal Scan / Insert Last Scan toolbar. A saved last scan remains manually insertable in the test field; a fresh test result takes precedence while waiting for insertion. There is no test-specific keyboard layout or palette. Build 20 restores the original extension input-view sizing. The global self-sizing/intrinsic-height experiments in builds 15–19 were removed after Antonio reported an invisible keyboard in Spotlight. Only the native test field requests a one-time reload of its current input views after keyboardDidShow. No extension height, test-specific padding, palette or key layout is changed.

The normal insert suffix is retained, including a field-tag guard on delayed newline insertion. Test results are stored separately from the normal pending-scan slot and do not overwrite normal last-scan, clipboard or history state. They are consumed by the extension, not pasted programmatically by the app.

## Scope and lifecycle

Before becoming first responder, the cooperating native field sets an explicit UITextContentType raw-value tag containing a fresh UUID ownership nonce. Intentional scanner return reuses that nonce. The keyboard reads the optional public input trait, adds the matching nonce to the ordinary scan URL, and stores a one-use request ID. This is explicit field cooperation, not host-app detection. Physical forwarding of the custom trait remains part of acceptance testing.

The app validates its local field nonce, shared owner, lease, request ID, phase and keyboard source before opening the test camera. Invalid/stale tagged requests fail closed and do not fall back to the configured browser. Ordinary external fields have no test tag and retain the existing return/insertion flow even if an abandoned shared record remains.

Shared state lives in Shared/KeyboardSettings.swift. Its phases are editing → launching → scanning → returning → ready → editing. Payloads use separate slots per ownership generation, preventing delayed cross-process writes from overwriting a newer test. Only the app renews the 10-minute lease while its field/scanner is active. Backgrounding, leaving the Scan tab, ordinary loss of field focus, and app restart invalidate ownership; focus loss during an intentional launch/camera handoff is preserved. Cancel returns to the field without a pending result. A late camera callback after cancellation cannot queue a result or open a browser.

The test alone enables automatic insertion, independent of the saved Auto Insert setting. The extension checks the current field tag immediately before writing and before a delayed suffix. Consuming a test does not overwrite the normal consumed-scan token. The nonnullable SDK documentIdentifier getter is deliberately never read: earlier physical Brave testing showed it can return nil and crash during Swift bridging.

## Verification and acceptance boundary

- Physical-device Debug build passed without compiler warnings, one worker and indexing disabled; no simulator.
- Protocol and existing pending-scan/profile checks pass: foreign field, invalid source, expired/revoked ownership, stale request/replay, cancel, URL round-trip and one-use insertion.
- Static check confirms no documentIdentifier read in the implementation; no return-target/Auto Insert preference writes were added.
- Real camera → keyboard insertion, custom trait forwarding, focus restoration, repeat/cancel and external-app switching still require user testing on the installed iPhone. Build/unit checks are not physical round-trip proof.

Tracks ANT-67. ANT-65 remains separate visual/feedback validation. This is part of the existing keyboard prototype PR; no merge or App Store submission is authorized yet.

## Physical sizing investigation

On the user-confirmed test field in build 17, the initial root/input/hosting bounds were 440×224 points while the SwiftUI panel remained 440×256 and was centered at y=−16. About one second later all four settled to (0,0,440,256), with zero safe-area insets and no top layout margin. That settled size matches the earlier external-app measurement. The initial undersized container explains an initial top overflow, but does not prove the cause of any persistent difference in the surrounding host/system region. A fresh build 18 test-field snapshot measured root and panel at (0,0,440,256) from didAppear through settledLayout: the initial −16-point panel offset is absent. Antonio still observed different surrounding top spacing on first display, which matches other apps after switching keyboards and returning to Blip. Build 19 asks the test UITextField to reload its native input views once after keyboardDidShow, retaining its first responder, selected extension and test identity. Antonio confirmed build 19’s test-field spacing matches immediately. He then reported an invisible keyboard in Spotlight. Build 20 removes both global extension sizing changes while retaining that field-only refresh; Spotlight and first-display test-field appearance need rechecking together.

DEBUG-only geometry snapshots are saved as bounded numeric records in the app group (file plus shared-preferences fallback), with capture timestamps. They include no proxy text, clipboard values or barcode contents. The collector retains windowless/empty layouts and marks non-finite rectangle components as null instead of discarding the record. No release build enables the collector.
