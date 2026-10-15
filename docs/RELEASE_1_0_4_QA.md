# Blip 1.0.4 device validation

Current development build: **29**. The combined update remains in PR #3; it has not been submitted to App Store Connect. Tests use a physical iPhone 16 Pro Max on iOS 27.0.1. No simulator is used.

This is the current acceptance summary. The prototype documents also contain historical investigation results, which are not a claim that every later check is complete.

## Completed

| Area | Physical evidence |
| --- | --- |
| Keyboard feedback visuals | Immediate held color and single-letter preview accepted on iPhone; System/Blue, light/dark, release reset, and accent-menu appearance checked. |
| Basic input | Letters, symbols, large numbers, German umlauts, single Shift, Delete, held Delete, and portrait/landscape input checked. Sliding from the accent menu selected an alternate character. English QWERTY input and spacebar hold/drag cursor movement also passed on build 29. |
| Scan-only mode | Disabling all three layouts left the Scan/Insert controls and system keyboard switch accessible. Scan opened the native test camera; a profile preview was recognized and Cancel preserved settings. |
| Camera format filtering | Under Common Barcodes, a fully visible ordinary QR was ignored; the camera screenshot independently decoded to the expected plain value. Replacing it with a valid company profile opened Preview. Apply then restored the original German/layout/format settings. |
| Keyboard switching | Globe switching out and back checked; five browser/system/Blip/native-field cycles passed after the build 28 lifecycle repair. |
| Native scanner test | Real camera result inserted exactly once with Safari configured and automatic insertion disabled. Repeated scan and Cancel paths checked. Native testing preserved ordinary scan/history state. |
| Chrome | Real camera return to the same test field; automatic insertion exactly once. With automatic insertion off, field stayed empty until Insert was tapped. Build 28. |
| Brave | Real camera return to the same test field and one insertion, with Blip selected. Build 29. |
| Firefox | Real camera return and one insertion after the first-use iOS Open Firefox confirmation. Build 29. |
| Safari | Real camera scan showed the manual instructions. A home-indicator swipe returned to the original tab and empty field; Insert entered the result once. Build 29. |
| Profile import | Real camera preview/Cancel/Apply and file export/import checked. Apply changed the expected five settings; Cancel changed none. |
| Profile QR presentation | QR and settings use the same snapshot. Inactive custom URL omitted. Light/dark and landscape QR decoding checked; settings remain scrollable. |
| Invalid profile camera paths | Unsupported version, malformed JSON, invalid settings, and an oversized payload showed errors. No insertion or configuration change; decoded ordinary history and saved result remained unchanged. |
| QR readability | Build 29 changed summary values to primary text. The physical XCTest contrast audit no longer flags those values; no description, hit-region, or clipped-text findings in that sheet audit. A separate Dynamic Type audit returned no findings. |
| Accessibility display options | Increase Contrast: QR sheet and System keyboard remained readable. Largest standard text size (accessibility sizes off): Scan page and QR summary remained readable and scrollable; every profile value was reachable. Original text size and contrast restored. |
| Stability | Device crash inventory after build 29 browser tests contained only the previously recorded build 4/27 reports. This does not establish crash-free behavior outside tested paths. |

Debug and Release builds, strict code-signature verification, localization lint, and standalone scan/session/profile tests pass for build 29. Build 29 changes QR text contrast and bundle build numbers only; the scan/keyboard repair is unchanged from build 28.

## Still to verify

- Final visual acceptance of the revised profile QR sheet.
- Key-click/haptic on/off and silent-mode behavior by listening and feeling the physical phone.
- Rapid Shift/Caps Lock: automated double-tap attempts produced only one-shot uppercase; distinguish automation timing from a real gesture defect before calling this passed.
- Overlapping touches: one synthesized two-pointer sequence entered no characters; manual rapid typing is needed to distinguish the automation sequence from a gesture defect.
- VoiceOver and the extended accessibility text-size range. The installed automation runner cannot use its VoiceOver-control endpoint on this runtime. An accessibility audit is not a substitute for VoiceOver use.

The native glass Done button is still flagged by the contrast audit despite the screenshot showing black text on white. That result is recorded separately from the corrected summary values; no complete accessibility pass is claimed.

## Unavailable coverage

The owner has only this iPhone available. Physical iPad, older iOS, and a second receiving phone remain untested. Edge is not installed. Do not infer iPad customer-issue resolution or broad device compatibility from these iPhone checks.

The separate keyboard activation-spacing investigation remains unresolved. No new fixed spacer or geometry workaround is part of this verification change.

The final device preferences match the original language, layouts, theme, feedback, return target, auto-insert, suffix, scan formats, camera defaults and history retention. The inactive custom destination remains saved.
