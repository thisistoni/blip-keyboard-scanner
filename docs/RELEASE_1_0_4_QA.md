# Blip 1.0.4 device validation

Submitted release: **1.0.4 (37)**, archived from `73fb163e276edcc4e0e864f094b3b96b3964975e`, supplied by PR #3. App Store Connect shows **Waiting for Review**, verified on **20 October 2026**. Tests use a physical iPhone 16 Pro Max on iOS 27.0.1. No simulator is used.

## Release candidate 37

The owner approved shipping the combined update with the existing **700 ms** settling interval restored and no adjustable delay setting. The 400 ms work and the isolated event-driven research are not part of this release's timing behavior. Historical results below retain their actual build numbers.

Signed Debug build, Release archive, strict signature verification, distribution export, localization/plist lint, and standalone scan/session/profile tests pass. App and extension version/build agree at **1.0.4 (37)**; MIT notices are present in both bundles. The archived app installed in place. Non-history shared preferences and all 19 decoded history records match the pre-install snapshot.

The final archived-build physical smoke test passed on 20 October after restarting phone automation. The installed app inventory confirmed **1.0.4 (37)**. Real camera scans verified:

- Brave with Auto Insert on: the exact value appeared once in the original Google field; the matching pending request was consumed.
- Brave with Auto Insert off: the field remained empty and the result remained unconsumed after returning. Explicit Insert entered the exact value once. The configured Enter suffix submitted the Google search as expected.
- Blip's native test field: the scan returned to Blip and inserted once with Brave still configured and Auto Insert off.
- With the QR display blank, opening the native scanner and cancelling left the field unchanged. Refocusing did not insert again.

All saved configuration preferences match the current pre-test snapshot after restoring Auto Insert. The pre-test history was empty; the two ordinary browser scans added two test records. Native scans did not add ordinary history records. Temporary scan/result identifiers changed as expected. Phone automation settings were restored and the runner stopped. Private device screenshots, accessibility captures and preference comparisons are retained outside the repository.

The earlier 15 October automation failures occurred before this final smoke test and did not validate device behavior. The submitted runtime source is unchanged from the archived commit; subsequent commits update release records only.

This is the current acceptance summary. The prototype documents also contain historical investigation results, which are not a claim that every later check is complete.

## Completed

| Area | Physical evidence |
| --- | --- |
| Keyboard feedback visuals | Immediate held color and single-letter preview accepted on iPhone; System/Blue, light/dark, release reset, and accent-menu appearance checked. |
| Popup colors | Build 30 recordings show letter previews matching ordinary key surfaces in System and Blue, light and dark. Light-mode accent menus also match in both themes. Original System/light settings restored and user preferences compared with the pre-test snapshot. |
| Basic input | Letters, symbols, large numbers, German umlauts, single Shift, Delete, held Delete, and portrait/landscape input checked. Sliding from the accent menu selected an alternate character. English QWERTY input and spacebar hold/drag cursor movement also passed on build 29. |
| Scan-only mode | Disabling all three layouts left the Scan/Insert controls and system keyboard switch accessible. Scan opened the native test camera; a profile preview was recognized and Cancel preserved settings. |
| Camera format filtering | Under Common Barcodes, a fully visible ordinary QR was ignored; the camera screenshot independently decoded to the expected plain value. Replacing it with a valid company profile opened Preview. Apply then restored the original German/layout/format settings. |
| Keyboard switching | Globe switching out and back checked; five browser/system/Blip/native-field cycles passed after the build 28 lifecycle repair. |
| Settings organization | Build 32: Keyboard Settings, Scanner Settings, Return & Insertion, and Company Profiles opened on the phone. Key Clicks and Auto Insert were switched off/on; the pages remained open. Chrome showed automatic-insertion controls; Safari showed its manual help and hid that toggle. The Safari alert opened/dismissed. The Scan page no longer shows an external destination, and its native field still opens the installed Blip keyboard. Light-appearance screenshots reviewed; owner visual acceptance remains pending. Original preferences and saved scan state match the pre-install snapshot, with history compared as decoded items. |
| App language and diagnostics | Build 33: App Language opens Settings → Apps → Blip on the physical phone. Opening Language shows English (default) and Deutsch. No language selection changed. Keyboard Setup Status is absent from the Settings list and its unused page is removed. Returned to Blip Settings; original user preferences and decoded saved scan/history state match the pre-install snapshot. |
| Music during scanner opening | Build 30 reproduced the interruption: iOS media controls changed from Pause to Play after a fresh scanner open. Build 31 configures mixing before beep preloading and disables capture-session audio reconfiguration. With the same music resumed, the real scanner opened and media controls stayed on Pause (playing). |
| Native scanner test | Real camera result inserted exactly once with Safari configured and automatic insertion disabled. Repeated scan and Cancel paths checked. Native testing preserved ordinary scan/history state. |
| Chrome | Real camera return to the same test field; automatic insertion exactly once. With automatic insertion off, field stayed empty until Insert was tapped. Build 28. |
| Brave | Real camera return to the same test field and one insertion, with Blip selected. Build 29. |
| Insertion timing experiment, not shipped | Build 36: two real QR scans returned to the same Brave Google field and inserted the exact value once. Each matching request had one proxy write and was consumed; the last scheduling event to write measured about 417 ms. With Auto Insert off, a third scan left the field empty and request unconsumed; explicit Insert entered the value once. These checks ran over Wi-Fi. Build 37 restores 700 ms. |
| Flashlight default | Build 35: saved OFF → manually ON → cancel/reopen started OFF; saved ON → manually OFF → cancel/reopen started ON. Shared preferences retained the saved default during both overrides. Build 36: a completed Brave scan with the flashlight manually ON left the saved default OFF; the next scanner started OFF. |
| Firefox | Real camera return and one insertion after the first-use iOS Open Firefox confirmation. Build 29. |
| Safari | Real camera scan showed the manual instructions. A home-indicator swipe returned to the original tab and empty field; Insert entered the result once. Build 29. |
| Profile import | Real camera preview/Cancel/Apply and file export/import checked. Apply changed the expected five settings; Cancel changed none. |
| Profile QR presentation | QR and settings use the same snapshot. Inactive custom URL omitted. Light/dark and landscape QR decoding checked; settings remain scrollable. |
| Invalid profile camera paths | Unsupported version, malformed JSON, invalid settings, and an oversized payload showed errors. No insertion or configuration change; decoded ordinary history and saved result remained unchanged. |
| QR readability | Build 29 changed summary values to primary text. The physical XCTest contrast audit no longer flags those values; no description, hit-region, or clipped-text findings in that sheet audit. A separate Dynamic Type audit returned no findings. |
| Accessibility display options | Increase Contrast: QR sheet and System keyboard remained readable. Largest standard text size (accessibility sizes off): Scan page and QR summary remained readable and scrollable; every profile value was reachable. Original text size and contrast restored. |
| Stability | Device crash inventory after build 29 browser tests contained only the previously recorded build 4/27 reports. This does not establish crash-free behavior outside tested paths. |

Debug and Release builds, strict code-signature verification, localization lint, and standalone scan/session/profile tests pass for build 29. Build 29 changed QR text contrast and bundle build numbers. Build 30 changes input/accent popup colors to use the ordinary letter-key style; the scan/session repair is unchanged from build 28. Debug and Release builds and strict signature verification pass for build 30. Build 31 corrects audio-session ordering and video-only capture configuration; signed Debug/Release builds pass. Build 32 groups the existing settings into dedicated pages with local state ownership, retaining their shared storage keys/defaults and typed bindings. It also removes the misleading external-target row from the native test and adds English/German release-note drafts. Signed Debug/Release builds, localization lint, and in-place installation pass. The earlier scan/profile checks retain their stated build numbers; no fresh camera round trip is claimed for this navigation-only change.

Build 33 adds the public app-settings shortcut and removes the diagnostic Settings page and its unused state/strings. Signed Debug/Release builds and localization lint pass, and the update is installed in place. The shortcut uses `UIApplication.openSettingsURLString`; the user taps Language on the destination app-settings page. This follows [Apple's recommended per-app language flow](https://developer.apple.com/videos/play/wwdc2019/403/).

Build 34 removes the Best company setup row and its divider from the Scan guide, plus the unused English/German copy. Signed Debug/Release builds and localization lint pass; installed in place. Visual review is left to the owner for this copy-only change. No new automated device interaction or camera round trip is claimed.

Build 36 gives each scanner presentation its own flashlight state initialized from the saved default; the camera toolbar no longer writes the next scan's default. Automatic insertion now waits 400 ms after the latest scheduling event instead of 700 ms, preserving cancellation, lifecycle checks, manual insertion and consumption guards. A 200 ms trial in build 35 issued proxy writes but left Brave's field empty, so it was not retained. Debug-only bounded traces record request identifiers and scheduling/write timestamps without barcode text. Signed Debug/Release builds, plist lint and standalone scan/session/profile tests pass. Installed in place wirelessly. The measured delay is the settling interval, not the full scan-to-return time, and this does not establish reliability in every host app.

## Still to verify

- Music through an actual completed scan/beep, repeated open/cancel, and the sound-disabled variant on build 31. Opening with sound enabled is already verified; the later scan checks did not verify concurrent audio playback.

- Final visual acceptance of the revised profile QR sheet.
- Visual acceptance of the reorganized Settings pages in builds 32–33. Dark appearance and German-language navigation labels have not been physically reviewed for this organization change.
- Key-click/haptic on/off and silent-mode behavior by listening and feeling the physical phone.
- Rapid Shift/Caps Lock: automated double-tap attempts produced only one-shot uppercase; distinguish automation timing from a real gesture defect before calling this passed.
- Overlapping touches: one synthesized two-pointer sequence entered no characters; manual rapid typing is needed to distinguish the automation sequence from a gesture defect.
- VoiceOver and the extended accessibility text-size range. The installed automation runner cannot use its VoiceOver-control endpoint on this runtime. An accessibility audit is not a substitute for VoiceOver use.

The native glass Done button is still flagged by the contrast audit despite the screenshot showing black text on white. That result is recorded separately from the corrected summary values; no complete accessibility pass is claimed.

## Unavailable coverage

The owner has only this iPhone available. Physical iPad, older iOS, and a second receiving phone remain untested. Edge is not installed. Do not infer iPad customer-issue resolution or broad device compatibility from these iPhone checks.

The separate keyboard activation-spacing investigation remains unresolved. No new fixed spacer or geometry workaround is part of this verification change.

The final device preferences match the original language, layouts, theme, feedback, return target, auto-insert, suffix, scan formats, camera defaults and history retention. The inactive custom destination remains saved.
