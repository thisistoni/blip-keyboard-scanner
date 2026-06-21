# Submission Checklist

## One-Time App Store Connect Setup

1. Create a new app in App Store Connect.
2. Platform: iOS.
3. Name: `Blip: Barcode QR Keyboard`.
4. Primary language: English (U.S.) unless you prefer German.
5. Bundle ID: `com.antoniobeslic.Blip`.
6. SKU: `blip-keyboard-scanner`.
7. User Access: Full Access.

## Public URLs

1. Publish `docs/privacy.html` and `docs/support.html`.
2. Verify both URLs open without GitHub login or private-repo access.
3. Enter the privacy policy URL in App Privacy.
4. Enter the support URL in App Information.

## App Privacy

1. In App Store Connect, open App Privacy.
2. Select that the app does not collect data, as long as the current no-backend/no-analytics build remains true.
3. Confirm tracking is not used.
4. Save and publish the App Privacy answers.

## Screenshots

1. Capture iPhone screenshots from the real app.
2. Capture iPad screenshots, preferably on a physical iPad; simulator is acceptable for non-camera screens if the UI is accurate.
3. Prepare English and German screenshot sets if both localizations are submitted.
4. Upload one to ten screenshots for each required device family.

## Build Upload

1. In Xcode, select the `Blip` scheme.
2. Select Any iOS Device or your connected iPhone.
3. Product > Archive.
4. In Organizer, select the archive.
5. Distribute App > App Store Connect > Upload.
6. Wait for App Store Connect processing.
7. Select the processed build on the app version page.

## Metadata

1. Copy localized metadata from `METADATA.md`.
2. Upload the app icon already included in the build.
3. Enter categories, copyright, age rating, and support URL.
4. Add the App Review notes from `AppReview/REVIEW_NOTES.md`.

## Final Physical-Device Smoke Test

Before pressing Submit for Review, install the exact archive/TestFlight build and test:

1. Fresh install shows setup if the keyboard is not enabled.
2. Enabling Blip and Allow Full Access lets the app reach the ready state.
3. Safari text field > Blip keyboard > Scan > camera opens.
4. Barcode and QR code scan correctly.
5. Return target opens and the scan inserts once.
6. Cancel from scanner returns to the selected target app.
7. History can be cleared and the scan page no longer shows stale last-scan data.
8. German localization uses `Rückkehrziel` where return target is shown.

## Do Not Submit Until

- The support email/contact is final and monitored.
- Privacy/support URLs are public.
- Screenshots are clean and match the submitted app version.
- At least one external tester has tried the TestFlight build on a real iPhone.
