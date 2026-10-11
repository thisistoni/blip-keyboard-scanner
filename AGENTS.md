# Repository Notes For Codex

- Keep public copy, docs, and Xcode-facing names aligned with the Blip brand.
- Preserve the working keyboard-to-scanner-to-return workflow before redesigning UI.
- Use a physical iPhone for any scan handoff validation.
- Prefer scoped SwiftUI changes and keep app/extension shared state in `Shared/KeyboardSettings.swift` unless there is a clear reason to split it.

## Release completion

- Treat an authorized “ship it” request as including repository cleanup, not just App Store submission.
- Prefer a focused release PR targeting `main`. If PRs are stacked, review and merge dependencies first, retarget remaining PRs to `main`, and merge after required checks pass. Do not bypass repository protections.
- Verify that remote `main` contains the exact submitted app source. Record the archive's source commit, version, and build in `AppStore/Releases/<version>.md`; create and push an annotated `v<version>` tag at that source commit, not a later documentation commit.
- After verifying the merges and release tag, delete merged release branches locally and remotely. Preserve unrelated edits and worktree files; report any local checkout that cannot safely be updated or removed.
- Update the relevant Linear issues with source/PR/tag links, verification limits, and the verified App Store state. Submission, approval, and public availability are distinct; keep outstanding customer validation open.
- Before reporting completion, verify remote `main`, merged PR states, published tag, and branch cleanup. Explicitly name any remaining blocker rather than leaving release housekeeping implicit.
