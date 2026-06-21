# Repository Notes For Codex

- Keep this project under `/Users/antoniobeslic/CodexWorkspace/BarcodeIOSApp`.
- Do not move active work into `/Users/antoniobeslic/Documents`.
- The public working name is `Blip: Barcode QR Keyboard`, but the current Xcode targets and bundle identifiers still use `BarcodeKeyboard`.
- Avoid renaming bundle identifiers, app groups, targets, or schemes unless the user explicitly asks. Those values affect provisioning and installed keyboard state.
- Preserve the working keyboard-to-scanner-to-return workflow before redesigning UI.
- Use a physical iPhone for any scan handoff validation.
- Prefer scoped SwiftUI changes and keep app/extension shared state in `Shared/KeyboardSettings.swift` unless there is a clear reason to split it.
