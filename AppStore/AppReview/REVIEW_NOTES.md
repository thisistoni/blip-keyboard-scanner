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

Keyboard setup steps (from version 1.1.0 a new install starts with a
three-step introduction):

1. Open Blip. The introduction explains the workflow. Tap Continue.
2. Tap Open Settings.
3. In iOS Settings, tap Keyboards.
4. Enable Blip.
5. Enable Allow Full Access.
6. Return to Blip. The introduction shows "The Blip keyboard is on." Tap Continue.
7. Choose the app Blip should open after a scan (the Return Target), then tap Done. Choose Chrome, Edge, Firefox or Brave for automatic return, or "Safari or another app" for manual return.

Batch scanning (new in 1.1.0): in the scanner, the stack button at the top
switches between Single and Batch. In Batch mode every scanned code is added
to a list, and the Insert Codes button hands the whole list to the text field
as one text.

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
