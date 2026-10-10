# iPad keyboard switch investigation — 10 October 2026

## Confirmed simulator result

Baseline: commit `3b53dd8`, Blip 1.0.2 (5), Debug simulator build. Device: iPad (A16), iOS 26.5, UUID `767EE045-FECE-457C-BE8A-FD85CB765F7E`. This is not the customer's iPad 9th generation / iPadOS 27.0.1. The customer's iPad app version remains unverified; the attached iPhone diagnostics do not establish it.

1. Install Blip and enable its keyboard in Settings > Apps > Blip > Keyboards. Full Access was off for these switching tests.
2. Focus Settings search, use Apple's globe to choose Blip.
3. Blip displays its Scan toolbar and typing keys, with no globe or other system keyboard-switch control. Its 123/NUM key only changes the internal Blip layout.
4. Focus Safari's address field. Blip has the same missing switch control there.

Cause: `KeyboardViewController` did not implement `needsInputModeSwitchKey` or `handleInputModeList(from:with:)`. The simulator's iPad requires a switch key supplied by the custom extension. A system-provided control outside the custom keyboard can mask this omission on some iPhones; it does not make the implementation complete.

## Initial repair (`695b082`)

- Add a globe to the toolbar, visible according to `needsInputModeSwitchKey` and refreshed during layout.
- Send all touch events to Apple's `handleInputModeList(from:with:)`, supporting a tap and a held keyboard-selection menu.
- Let Scan fill the remaining toolbar width alongside the globe.
- Track the Insert Last Scan button explicitly. Counting toolbar children would mistake globe + Scan for the recovery-button state and could repeatedly rebuild the keyboard.

Only `KeyboardExtension/KeyboardViewController.swift` changes. Scanner and return/insertion behavior are not changed by the patch.

## Verification

The incremental `xcodebuild` Debug simulator build passed (exit 0). The updated app was installed and exercised in Safari:

| Check | Result |
| --- | --- |
| Blip letters > globe tap > Apple QWERTY | Passed |
| Blip globe long press > Apple input-mode list | Passed |
| Select Apple QWERTZ from Blip's menu | Passed |
| Apple globe menu > Blip, repeated twice | Passed |
| Globe visible in letters, numbers, large numbers | Passed |
| Large-number key inserts `1` into Safari address field | Passed |
| Rotate with Blip active to landscape | Globe remained visible |
| Landscape large-number globe > Apple QWERTZ | Passed |
| Further app-switch, floating keyboard, recovery button with pending scan | Not completed |
| Physical iPad 9 / iPadOS 27.0.1 | Not tested |
| Physical iPhone scan handoff and repeated scan/return cycles | Not tested in this task |

Screenshots are in `docs/evidence/ANT-27/`: `ipad-baseline-no-switch.png`, `ipad-safari-before.png`, `ipad-safari-letters-after.png`, `ipad-safari-keyboard-list-after.png`, and `ipad-safari-landscape-after.png`.

## Placement correction after user review

The user requested the familiar native bottom-left position. The globe now appears at the far left of the bottom utility row, before Blip's layout key, and uses the same key styling as the surrounding controls. Scan returns to the full toolbar width. The existing UIKit tap/long-press handler is preserved.

Scan-only mode has a separate bottom row for the globe when iOS requires one; the row and its extra height disappear when iOS supplies its own switch control. That fallback is implemented but has not received a dedicated simulator check.

The final Debug simulator build passed with one build worker and indexing disabled. The updated app was installed into the same iPad A16 / iOS 26.5 simulator. Bottom-left placement was visually verified in landscape for letters, numbers, and large numbers. A long press opened Apple's keyboard list, a tap switched to Apple QWERTZ, and Apple's menu returned to Blip. The updated Blip keyboard was left open for user inspection.

Latest placement evidence: `docs/evidence/ANT-27/ipad-bottom-left-landscape.png`. Earlier screenshots above document the initial toolbar placement and remain historical evidence. Physical iPad/iPhone and scan-flow checks remain open.

## Resource interruption

Further simulator work was stopped after the user reported another ChatGPT memory spike and freeze. The simulator was shut down and its GUI closed. No extra runtime or duplicate build was started. Xcode clean and removal of this task's generated indexes/module cache reduced build disk use; user files were preserved.

After shutdown, `footprint` measured 4163 MB across ChatGPT and its renderer/service processes, with the largest renderer at 1193 MB. This verifies substantial ChatGPT memory use, but does not capture or explain the reported earlier 8 GB peak. Restoring the long conversation and its screenshot content is a possible contributor, not a confirmed memory-leak diagnosis.

ANT-27 remains In Progress pending the uncompleted device and scan-flow checks. This task does not submit a release or send customer email.

## Reference

[Apple: Creating a custom keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard)
