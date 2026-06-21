# Screenshot Plan

Apple requires one to ten screenshots per device family. Use polished screenshots from the real app UI and keep the first three focused on the core workflow.

## Required Device Sets

- iPhone: capture or export 6.9-inch screenshots if possible. Accepted portrait sizes include `1260 x 2736`, `1290 x 2796`, and `1320 x 2868`.
- iPad: because Blip supports iPad, prepare 13-inch iPad screenshots. Accepted portrait sizes include `2048 x 2732` and `2064 x 2752`.

Use PNG. Capture both English and German localizations if you plan to ship both App Store localizations.

## Visual Rules

- Use a real iPhone for scanner screenshots because the simulator has no physical camera.
- Keep the UI clean: no personal data, no messy browser tabs, no notifications, no low battery.
- Use demo codes only. Avoid showing real company codes or customer data.
- Prefer dark-mode screenshots if they best represent the current app, but include enough contrast and readable text.
- Do not claim "works in every app"; show the tested return-target workflow.

## Screenshot Order

### 1. Keyboard Scan Entry

Show Safari or a clean web form with the Blip keyboard open and the Scan button visible.

English caption: `Scan from the keyboard`

German caption: `Direkt aus der Tastatur scannen`

### 2. Scanner

Show the scanner UI with the scan area, target indicator, flashlight control, and zoom controls. Put a demo barcode or QR code inside the scan area.

English caption: `Scan barcodes and QR codes`

German caption: `Barcodes und QR-Codes scannen`

### 3. Inserted Result

Show the selected target app after return, with the scanned value inserted into the original field.

English caption: `Inserted where you started`

German caption: `Dort eingefügt, wo du gestartet bist`

### 4. Keyboard Configuration

Show Settings > Keyboard with language, enabled layouts, scan-only possibility, and open-with configuration.

English caption: `Customize the keyboard`

German caption: `Tastatur flexibel anpassen`

### 5. Scanner Settings

Show Settings > Scanner with scan formats, default zoom, scan area, flashlight, and Blip sound.

English caption: `Tune scanner behavior`

German caption: `Scanner-Verhalten einstellen`

### 6. Local History

Show History with one or two demo scans, clean alignment, and the clear-history button.

English caption: `Keep local scan history`

German caption: `Lokalen Scanverlauf behalten`

### 7. Company Profiles

Show Company Profiles with export/import actions.

English caption: `Share company settings`

German caption: `Firmeneinstellungen teilen`

### 8. Privacy & Trust

Show Privacy & Trust with "Scans stay on this device" and "Why Full Access is needed".

English caption: `Private by design`

German caption: `Datenschutzfreundlich gedacht`

## Optional App Preview Video

Skip for the first submission unless you want extra polish. If you make one later, keep it under 30 seconds and show:

1. Open Safari text field.
2. Switch to Blip keyboard.
3. Tap Scan.
4. Scan demo code.
5. Return and insert.

## Raw Screenshot Folder Naming

Suggested local folders:

- `AppStore/Screenshots/raw/en-US/iphone`
- `AppStore/Screenshots/raw/de-DE/iphone`
- `AppStore/Screenshots/raw/en-US/ipad`
- `AppStore/Screenshots/raw/de-DE/ipad`
- `AppStore/Screenshots/final/en-US`
- `AppStore/Screenshots/final/de-DE`
