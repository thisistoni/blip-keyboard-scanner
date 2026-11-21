# Test Plan

Use a physical iPhone for the full workflow. The simulator cannot validate camera scanning or real host-app keyboard behavior.

## Setup Flow

- Fresh install opens the setup screen when the keyboard is not enabled.
- `Open Keyboard Settings` opens the app settings page.
- Enable the keyboard and Allow Full Access in iOS Settings.
- Return to Blip and tap `Check Again`.
- If iOS does not refresh the state, fully close and reopen the app.

## Keyboard

- Switch to the Blip keyboard from Safari or another text field.
- Confirm the top bar only exposes the scan action.
- Confirm configured keyboard layouts match Settings.
- Confirm English/German keyboard language selection.
- Confirm scan-only mode shows only the scan control.

## Scanner

- Scan a Code 128 or EAN product barcode.
- Scan a QR code when the selected scan profile supports QR.
- Confirm `Common Barcodes` does not detect QR codes.
- Confirm `Barcodes + QR` detects QR codes and common 1D barcodes.
- Confirm `All Supported Formats` detects QR, Data Matrix, PDF417, Aztec, and common 1D barcodes where test labels are available.
- Toggle flashlight while the camera preview is live.
- With music playing in another app, cold-launch Blip and open the scanner with Blip sound enabled. Music must keep playing before any code is scanned.
- Complete a scan and verify the beep mixes with the music; repeat opening/canceling the scanner.
- Repeat the music test with Blip sound disabled.
- In Single scan mode, with a label carrying several codes, confirm every code is outlined, the hint appears, and tapping an outline returns that code. A single code must still scan without a tap, and covering the other codes with a hand must fall back to automatic scanning after about a second.

- In Batch scan mode (Settings or the scanner's Scan Mode menu), scan several items: there is no choice and nothing to tap; every code in view is added without a tap (several codes at once are all added, each with its own beep and row), a code still confirming shows a thin white outline and an added code a dashed green one with a check, each code is added once while it stays in view, the list numbers them, a code taken away for about two seconds and shown again is added again, and the finish button inserts all codes joined with the Batch Separator followed by the Scan Suffix once.
- Batch survives a second request: from a field in Chrome, tap Scan and collect a few codes, switch back to the browser, focus a different field, and tap Scan on the Blip keyboard again. The scanner must still show the same list (no discard prompt, nothing lost); add one more code, finish, and confirm the whole list is inserted once into the field that asked last and not into the first one. With an empty list the second Scan must open a fresh scanner as before.
- With added codes still in view, lock and unlock the phone, open the app switcher and come back, and take an incoming call during a batch. Codes that stay in view must not be added again.
- Delete a row: the delete button is easy to hit, "Removed …" with Undo shows for about four seconds, and Undo puts the row back at its old number. With VoiceOver on, both are announced. A deleted code still in view is added again only after it has been out of view for about two seconds.
- Hold a code so it sits behind the batch panel: it must not be added. Move it above the panel and it is added. Repeat in landscape.
- Batch Separator New Line and Tab: finish a batch into a single-line input in Safari and in Chrome, into a textarea, and into a native app field, each with Scan Suffix None, Return and Tab. Record which fields keep all codes, which submit the form or move focus, and which drop the separator.
- Skip Duplicate Codes (Settings, off by default): with it on, scan an item in Batch mode, take it out of view for two seconds and show it again. It is not added a second time; the panel shows "Already in the list", the phone gives a different haptic and no scan sound. Delete its row and show it again: it is added. With the setting off the same steps add it again, marked "Added again" and tagged Duplicate.
- Switch Single ↔ Batch in the scanner while a code is in view: it must be handled once, in the new mode only (in Batch added once, in Single returned once).
- In Single mode, tap Cancel right after a code is accepted (the green Scanned pill): the scanner closes without inserting, copying or saving that code to History.
- Long batch session with the torch on: the phone must not auto-lock while the scanner is open; note how warm the phone gets and whether iOS turns the torch off.

The multi-code and batch re-scan logic, and the batch list, have standalone test executables:

```sh
xcrun swiftc App/BarcodeSelectionTracker.swift Tests/BarcodeSelectionTrackerTests.swift -o /tmp/blip-selection-tests
/tmp/blip-selection-tests
xcrun swiftc Shared/KeyboardSettings.swift Shared/ScanHistory.swift App/BatchScanCollection.swift Tests/BatchScanCollectionTests.swift -o /tmp/blip-batch-tests
/tmp/blip-batch-tests
```

## Wedge Flow

- In Safari, place the cursor in a text field.
- Switch to the Blip keyboard.
- Tap `Scan`.
- Scan a code.
- Confirm Blip returns to the configured target app.
- Confirm the scanned text inserts once into the original field.
- Repeat with the configured scan suffix: none, tab, enter, and space.
- Press `Cancel` in the scanner and confirm it returns to the configured target app.

## Return Targets

Test each target on a physical iPhone before trusting it for company rollout:

- Safari
- Chrome
- Edge
- Firefox
- Brave
- Custom URL scheme
