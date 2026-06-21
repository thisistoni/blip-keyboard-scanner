# Blip Feature Plan

This file is the execution checklist for the next Blip feature pass. Keep it updated as work lands by changing `[ ]` to `[x]` only after the feature is implemented and verified.

## Goal

Build the next product layer around Blip without adding scan validation rules. The app should become a practical company utility with local scan history, support/feedback, privacy/trust information, company profile import/export, scanner zoom, and optional scan-area targeting.

## Explicitly Out Of Scope

These are hard constraints, not implementation tasks:

- Do not add EAN-only, QR-only, or format-only business restrictions beyond the existing scan-format profile.
- Do not add code-length validation.
- Do not add duplicate rejection timers.
- Do not add automatic scan text transformation rules such as trimming, prefixing, or custom suffixing beyond the existing scan suffix setting.
- Do not block a scan just because it does not match a company-specific rule.

## Feature Checklist

### 1. Local Scan History

- [x] Add a local scan history model.
- [x] Persist scanned value.
- [x] Persist detected code format when available.
- [x] Persist scan date/time.
- [x] Persist scan source: app scan or keyboard-launched scan.
- [x] Persist return target used for keyboard-launched scans.
- [x] Persist insertion status when the scan was queued for keyboard insertion.
- [x] Keep history local to the device.
- [x] Do not add cloud sync.
- [x] Do not send history to analytics or external services.

### 2. History UI

- [x] Add a History tab.
- [x] Show scan value, code format, date/time, source, and return target.
- [x] Add search.
- [x] Add tap-to-copy.
- [x] Add delete for individual history items.
- [x] Add clear-all history action with confirmation.
- [x] Add an empty state.
- [x] Add a history retention setting: Off, 24 Hours, 7 Days, 30 Days, Forever.
- [x] Apply retention cleanup on app open and after new scans.

### 3. History Integration

- [x] Record every successful scanner result exactly once.
- [x] Record scans launched from the app.
- [x] Record scans launched from the keyboard.
- [x] Do not change existing keyboard insertion behavior.
- [x] Do not insert history items when manual simulator test values are used unless that path is intentionally treated as a scan.

### 4. Feedback And Support

- [x] Add a Help & Feedback area.
- [x] Add Send Feedback email action.
- [x] Prefill subject with `Blip Feedback`.
- [x] Prefill body with app version.
- [x] Prefill body with iOS version.
- [x] Prefill body with device model.
- [x] Prefill body with selected return target.
- [x] Prefill body with keyboard language.
- [x] Prefill body with keyboard profile/layout configuration.
- [x] Prefill body with scan format profile.
- [x] Handle missing Mail app gracefully.

### 5. Report Scan Issue

- [x] Add Report Scan Issue from a history item.
- [x] Prefill email subject with `Blip Scan Issue`.
- [x] Include selected scan value.
- [x] Include code format when available.
- [x] Include scan date/time.
- [x] Include scan source and return target.
- [x] Include app/device/settings context.
- [x] Make clear in UI that sending feedback is optional and user-initiated.

### 6. Privacy And Trust

- [x] Add Privacy & Trust screen.
- [x] Explain that scans stay on this device.
- [x] Explain that history can be disabled and cleared.
- [x] Explain that Blip does not use cloud sync.
- [x] Explain that Full Access is used so the scanner app and keyboard extension can share scan results.
- [x] Explain that feedback emails include only the diagnostic context shown to the user.
- [x] Link to feedback/support from this screen.

### 7. Company Profiles

- [x] Add Company Profiles area in Settings.
- [x] Export current Blip configuration to a shareable file.
- [x] Import a Blip profile file.
- [x] Preview profile changes before applying.
- [x] Allow cancelling an import before settings are changed.
- [x] Include keyboard language.
- [x] Include enabled keyboard layouts.
- [x] Include keyboard type/profile.
- [x] Include scan suffix.
- [x] Include scan format profile.
- [x] Include return target.
- [x] Include custom return URL when configured.
- [x] Include sound-on-scan setting.
- [x] Include default flashlight setting.
- [x] Include default zoom setting.
- [x] Include scan-area setting.
- [x] Include profile version for future compatibility.
- [x] Validate profile file shape before applying.
- [x] Do not include scan history in exported profiles.

### 8. Scanner Zoom Settings

- [x] Add default scanner zoom setting.
- [x] Support 1x.
- [x] Support 1.5x.
- [x] Support 2x.
- [x] Support 3x.
- [x] Store setting in shared settings.
- [x] Apply default zoom whenever scanner opens.
- [x] Clamp requested zoom to the active camera device maximum.

### 9. Live Scanner Zoom

- [x] Add pinch-to-zoom to the scanner preview.
- [x] Keep zoom smooth while the camera session is active.
- [x] Clamp live zoom to the camera-supported range.
- [x] Show compact zoom indicator, for example `2.0x`.
- [x] Keep flashlight and barcode detection working while zoom changes.
- [x] Do not freeze the camera feed when zoom changes.

### 10. Scan-Area Overlay

- [x] Add scan-area setting.
- [x] Support Full Frame.
- [x] Support Centered Box.
- [x] Store scan-area setting in shared settings.
- [x] Show a centered overlay when Centered Box is active.
- [x] Dim the area outside the active scan region.
- [x] Keep the overlay visually clean on iPhone and iPad.

### 11. Functional Scan-Area Filtering

- [x] Convert Vision barcode observation bounds into the same coordinate space as the active scan region.
- [x] Accept detections inside the active region.
- [x] Ignore detections outside the active region.
- [x] Full Frame mode should preserve current behavior.
- [x] Centered Box mode must be functional, not only decorative.
- [ ] Test with more than one code visible when possible.

### 12. Settings Organization

- [x] Keep Settings easy to understand.
- [x] Add sections for Keyboard, Scanner, Return, History, Company Profiles, Privacy, and Feedback.
- [x] Avoid burying important employee-facing setup instructions.
- [x] Avoid debug-looking labels in production-facing sections.
- [x] Keep diagnostics clearly separate if still present.

## Verification Checklist

- [x] Build app and keyboard extension for physical iPhone.
- [x] Install on physical iPhone.
- [ ] Verify keyboard-launched scan still returns and inserts once.
- [ ] Verify app-launched scan records history.
- [ ] Verify keyboard-launched scan records history.
- [ ] Verify history copy/delete/clear/search.
- [ ] Verify history retention setting.
- [ ] Verify feedback email opens with context.
- [ ] Verify report scan issue email opens with selected history context.
- [ ] Verify Privacy & Trust screen copy.
- [ ] Verify company profile export/import round trip.
- [ ] Verify default zoom applies when scanner opens.
- [ ] Verify pinch zoom works without camera freeze.
- [ ] Verify scan-area overlay appears correctly.
- [ ] Verify scan-area filtering ignores detections outside the box.
- [ ] Verify existing settings still persist via App Group.
- [x] Run plist and localization lint.
- [x] Commit and push after verification.
