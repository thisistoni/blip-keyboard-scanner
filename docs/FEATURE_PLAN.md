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

- [ ] Add a local scan history model.
- [ ] Persist scanned value.
- [ ] Persist detected code format when available.
- [ ] Persist scan date/time.
- [ ] Persist scan source: app scan or keyboard-launched scan.
- [ ] Persist return target used for keyboard-launched scans.
- [ ] Persist insertion status when the scan was queued for keyboard insertion.
- [ ] Keep history local to the device.
- [ ] Do not add cloud sync.
- [ ] Do not send history to analytics or external services.

### 2. History UI

- [ ] Add a History tab.
- [ ] Show scan value, code format, date/time, source, and return target.
- [ ] Add search.
- [ ] Add tap-to-copy.
- [ ] Add delete for individual history items.
- [ ] Add clear-all history action with confirmation.
- [ ] Add an empty state.
- [ ] Add a history retention setting: Off, 24 Hours, 7 Days, 30 Days, Forever.
- [ ] Apply retention cleanup on app open and after new scans.

### 3. History Integration

- [ ] Record every successful scanner result exactly once.
- [ ] Record scans launched from the app.
- [ ] Record scans launched from the keyboard.
- [ ] Do not change existing keyboard insertion behavior.
- [ ] Do not insert history items when manual simulator test values are used unless that path is intentionally treated as a scan.

### 4. Feedback And Support

- [ ] Add a Help & Feedback area.
- [ ] Add Send Feedback email action.
- [ ] Prefill subject with `Blip Feedback`.
- [ ] Prefill body with app version.
- [ ] Prefill body with iOS version.
- [ ] Prefill body with device model.
- [ ] Prefill body with selected return target.
- [ ] Prefill body with keyboard language.
- [ ] Prefill body with keyboard profile/layout configuration.
- [ ] Prefill body with scan format profile.
- [ ] Handle missing Mail app gracefully.

### 5. Report Scan Issue

- [ ] Add Report Scan Issue from a history item.
- [ ] Prefill email subject with `Blip Scan Issue`.
- [ ] Include selected scan value.
- [ ] Include code format when available.
- [ ] Include scan date/time.
- [ ] Include scan source and return target.
- [ ] Include app/device/settings context.
- [ ] Make clear in UI that sending feedback is optional and user-initiated.

### 6. Privacy And Trust

- [ ] Add Privacy & Trust screen.
- [ ] Explain that scans stay on this device.
- [ ] Explain that history can be disabled and cleared.
- [ ] Explain that Blip does not use cloud sync.
- [ ] Explain that Full Access is used so the scanner app and keyboard extension can share scan results.
- [ ] Explain that feedback emails include only the diagnostic context shown to the user.
- [ ] Link to feedback/support from this screen.

### 7. Company Profiles

- [ ] Add Company Profiles area in Settings.
- [ ] Export current Blip configuration to a shareable file.
- [ ] Import a Blip profile file.
- [ ] Preview profile changes before applying.
- [ ] Allow cancelling an import before settings are changed.
- [ ] Include keyboard language.
- [ ] Include enabled keyboard layouts.
- [ ] Include keyboard type/profile.
- [ ] Include scan suffix.
- [ ] Include scan format profile.
- [ ] Include return target.
- [ ] Include custom return URL when configured.
- [ ] Include sound-on-scan setting.
- [ ] Include default flashlight setting.
- [ ] Include default zoom setting.
- [ ] Include scan-area setting.
- [ ] Include profile version for future compatibility.
- [ ] Validate profile file shape before applying.
- [ ] Do not include scan history in exported profiles.

### 8. Scanner Zoom Settings

- [ ] Add default scanner zoom setting.
- [ ] Support 1x.
- [ ] Support 1.5x.
- [ ] Support 2x.
- [ ] Support 3x.
- [ ] Store setting in shared settings.
- [ ] Apply default zoom whenever scanner opens.
- [ ] Clamp requested zoom to the active camera device maximum.

### 9. Live Scanner Zoom

- [ ] Add pinch-to-zoom to the scanner preview.
- [ ] Keep zoom smooth while the camera session is active.
- [ ] Clamp live zoom to the camera-supported range.
- [ ] Show compact zoom indicator, for example `2.0x`.
- [ ] Keep flashlight and barcode detection working while zoom changes.
- [ ] Do not freeze the camera feed when zoom changes.

### 10. Scan-Area Overlay

- [ ] Add scan-area setting.
- [ ] Support Full Frame.
- [ ] Support Centered Box.
- [ ] Store scan-area setting in shared settings.
- [ ] Show a centered overlay when Centered Box is active.
- [ ] Dim the area outside the active scan region.
- [ ] Keep the overlay visually clean on iPhone and iPad.

### 11. Functional Scan-Area Filtering

- [ ] Convert Vision barcode observation bounds into the same coordinate space as the active scan region.
- [ ] Accept detections inside the active region.
- [ ] Ignore detections outside the active region.
- [ ] Full Frame mode should preserve current behavior.
- [ ] Centered Box mode must be functional, not only decorative.
- [ ] Test with more than one code visible when possible.

### 12. Settings Organization

- [ ] Keep Settings easy to understand.
- [ ] Add sections for Keyboard, Scanner, Return, History, Company Profiles, Privacy, and Feedback.
- [ ] Avoid burying important employee-facing setup instructions.
- [ ] Avoid debug-looking labels in production-facing sections.
- [ ] Keep diagnostics clearly separate if still present.

## Verification Checklist

- [ ] Build app and keyboard extension for physical iPhone.
- [ ] Install on physical iPhone.
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
- [ ] Run plist and localization lint.
- [ ] Commit and push after verification.
