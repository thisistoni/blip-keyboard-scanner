# Repository Notes For Codex

- Keep public copy, docs, and Xcode-facing names aligned with the Blip brand.
- Preserve the working keyboard-to-scanner-to-return workflow before redesigning UI.
- Use a physical iPhone for any scan handoff validation.
- Prefer scoped SwiftUI changes and keep app/extension shared state in `Shared/KeyboardSettings.swift` unless there is a clear reason to split it.

## Build storage

- Use one stable `DerivedData/` at the repository root for ordinary Blip builds by passing `-derivedDataPath DerivedData -jobs 2` to `xcodebuild`. Reuse it for app/keyboard, device/simulator, and Debug/Release variants; do not add task-named build roots or duplicate XcodeBuildMCP workspace caches.
- The screenshot lane already uses `fastlane/DerivedData`; use that location only for its screenshot workflow and remove its disposable build output after the screenshots are verified. Preserve the approved images under `AppStore/Screenshots/`.
- Serialize builds sharing a cache. Put genuinely isolated checks in task-owned temporary build directories with exit/signal cleanup, and remove them after collecting results, including on failure or cancellation. Preserve unique harness source separately from generated output.
- Reuse incremental/module/package caches and existing simulator devices. Avoid routine clean builds, copied SDKs/toolchains, and additional simulator installations for simple checks. Keep physical iPhone validation for scanner/keyboard handoff and preserve the installed working Blip app.
- Instructions/documentation-only changes need diff and path review, not an app build, screenshot run, or simulator session. For native changes, build only the destinations/configurations needed to verify the change unless a release requires more.
- Check free space before large builds. At completion, remove task-owned temporary builds and redundant build copies; report retained cache paths and sizes. Keep at most the reusable development cache plus explicitly needed install/release deliverables.
- Before deleting generated output, verify that it contains no tracked source or modified package checkout. Preserve signing files, release `.xcarchive`/dSYM artifacts, release records, and approved screenshots; an ignored `build/` directory can contain archives and must not be removed wholesale.

## Release completion

- Treat an authorized “ship it” request as including repository cleanup, not just App Store submission.
- Prefer a focused release PR targeting `main`. If PRs are stacked, review and merge dependencies first, retarget remaining PRs to `main`, and merge after required checks pass. Do not bypass repository protections.
- Verify that remote `main` contains the exact submitted app source. Record the archive's source commit, version, and build in `AppStore/Releases/<version>.md`; create and push an annotated `v<version>` tag at that source commit, not a later documentation commit.
- After verifying the merges and release tag, delete merged release branches locally and remotely. Preserve unrelated edits and worktree files; report any local checkout that cannot safely be updated or removed.
- Update the relevant Linear issues with source/PR/tag links, verification limits, and the verified App Store state. Submission, approval, and public availability are distinct; keep outstanding customer validation open.
- Before reporting completion, verify remote `main`, merged PR states, published tag, and branch cleanup. Explicitly name any remaining blocker rather than leaving release housekeeping implicit.
