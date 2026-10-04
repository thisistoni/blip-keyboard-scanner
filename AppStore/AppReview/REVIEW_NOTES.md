# App Review Notes

Blip is a custom iOS keyboard extension with a barcode and QR scanning workflow.

The keyboard extension cannot access the camera directly, so scanning happens in the containing app. The workflow is:

1. Open a target app such as Safari.
2. Tap a text field.
3. Switch to the Blip keyboard using the iOS keyboard button.
4. Tap Scan.
5. Blip opens the scanner in the containing app.
6. Scan a demo barcode or QR code.
7. For Chrome, Edge, Firefox, Brave, or a configured custom URL scheme, Blip opens the selected return target. When the keyboard and original text field become active again, it can insert the scan automatically if Auto Insert is enabled. The user can also tap Insert Last Scan.

For Safari, Blip asks the user to return to the original Safari tab manually, then tap Insert Last Scan. Safari is not presented as an automatic return target.

Return targets are opened through public URL-scheme handling with
`UIApplication.open`. Blip does not use private APIs to open apps by bundle
identifier. If a configured app cannot handle its URL scheme, the reviewer can
use iOS's system Back-to-app control to return to the original text field. The
queued scan remains available through Insert Last Scan.

Keyboard setup steps:

1. Open Blip.
2. Tap Open Keyboard Settings.
3. In iOS Settings, tap Keyboards.
4. Enable Blip.
5. Enable Allow Full Access.
6. Return to Blip and tap Check Again.

Why Full Access is requested:

Full Access lets the Blip keyboard extension and scanner app share the scan request and scan result through the shared App Group. Blip does not collect keystrokes, does not send typed text to a server, and does not use keyboard input for tracking.

Privacy summary:

- Scan history stays local on device.
- Camera frames are processed on device.
- No analytics SDKs.
- No advertising SDKs.
- No account system.
- No cloud sync.
- No tracking.

If a test barcode is needed, any standard EAN-13, Code 128, or QR code can be used.
