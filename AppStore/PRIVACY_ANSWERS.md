# App Privacy Answers

This is the recommended App Store Connect privacy setup for the current Blip build.

## Privacy Links

Required Privacy Policy URL:

`https://thisistoni.github.io/blip-keyboard-scanner/privacy.html`

Support URL:

`https://thisistoni.github.io/blip-keyboard-scanner/support.html`

Before submission, publish these pages and open both URLs in a private browser window to confirm they are public.

## Data Collection

Recommended answer:

`No, we do not collect data from this app.`

Reasoning:

- Scans, scan history, settings, company profiles, and pending insertion state stay on device.
- Camera frames are processed on device and are not uploaded.
- There are no analytics SDKs, ad SDKs, tracking SDKs, accounts, or cloud sync.
- Optional feedback opens a user-visible email draft. Nothing is sent unless the user chooses to send the email.

Apple says data processed only on device is not "collected" for App Privacy answers. Apple also treats optional feedback or customer-support submissions as optional to disclose when they are infrequent, user-initiated, clear to the user, and not used for tracking, advertising, marketing, or other unrelated purposes.

If you later add a backend, analytics, crash reporting, remote support inbox processing, or cloud sync, update this answer.

## Tracking

Recommended answer:

`No, we do not use this app to track users.`

Blip does not link app data with third-party data for advertising or advertising measurement, and it does not share data with data brokers.

## Privacy Manifest

The app now includes `Shared/PrivacyInfo.xcprivacy`.

Declared accessed API:

- `NSPrivacyAccessedAPICategoryUserDefaults`

Declared reasons:

- `CA92.1` - app-specific user defaults.
- `1C8F.1` - user defaults shared by the containing app and keyboard extension through the App Group.

Declared collection/tracking:

- No collected data types.
- No tracking.
- No tracking domains.

## Camera Permission Explanation

Current permission copy:

`Blip uses the camera to scan barcodes and QR codes and insert the scanned value from the custom keyboard.`

This is accurate and should stay direct.

## Full Access Explanation

Use this in review notes and support copy:

Blip requests Full Access because iOS keeps the keyboard extension and containing app separated. Full Access lets the Blip keyboard extension and scanner app exchange the scan request and result through the shared App Group. Blip does not collect keystrokes, send typed text to a server, or use keyboard input for tracking.
