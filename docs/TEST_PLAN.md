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
