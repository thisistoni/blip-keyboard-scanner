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
