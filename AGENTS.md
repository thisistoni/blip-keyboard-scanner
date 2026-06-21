# Repository Notes For Codex

- Keep this project under `/Users/antoniobeslic/CodexWorkspace/BarcodeIOSApp`.
- Do not move active work into `/Users/antoniobeslic/Documents`.
- The public working name is `Blip: Barcode QR Keyboard`. The Xcode project and target names still use `BarcodeKeyboard`, but bundle identifiers and the app group use Blip branding.
- Avoid renaming targets or schemes unless the user explicitly asks. Bundle identifiers and app groups affect provisioning and installed keyboard state.
- Preserve the working keyboard-to-scanner-to-return workflow before redesigning UI.
- Use a physical iPhone for any scan handoff validation.
- Prefer scoped SwiftUI changes and keep app/extension shared state in `Shared/KeyboardSettings.swift` unless there is a clear reason to split it.
