# Repository Notes For Codex

- Keep public copy, docs, and Xcode-facing names aligned with the Blip brand.
- Preserve the working keyboard-to-scanner-to-return workflow before redesigning UI.
- Use a physical iPhone for any scan handoff validation.
- Prefer scoped SwiftUI changes and keep app/extension shared state in `Shared/KeyboardSettings.swift` unless there is a clear reason to split it.
