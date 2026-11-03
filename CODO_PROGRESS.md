# CODO Development Progress

## Product
Native macOS development command center. Tagline: **Think. Code. Create.**

## Design direction
Apple-native SwiftUI, system light/dark appearance, semantic AppKit colors, native project selection, and a restrained violet accent.

## Completed
- [x] Native SwiftUI app entry point and Xcode project
- [x] Adaptive system colors and core dashboard/workspace navigation
- [x] Project model, local JSON persistence, project rail and native folder import
- [x] Security-scoped project bookmarks and project-root constrained file browsing
- [x] Read-only source/config previews with file-size limits
- [x] Project Overview analysis for Xcode, Unity and web projects
- [x] Static Xcode target/product hints and macOS/iOS platform hints
- [x] Unity editor/package inspection and web package/scripts/dependency inspection
- [x] Controlled Process-based diagnostic command runner with no shell interpolation
- [x] Live stdout/stderr output and process cancellation
- [x] Project-scoped working directory and security access held while the process runs
- [x] Fixed diagnostic command allowlist
- [x] Persistent task queue with sequential execution
- [x] Task statuses: queued, running, succeeded, failed and cancelled
- [x] Execution history and logs persisted locally in Application Support/CODO
- [x] Activity workspace with expandable task logs and history cleanup
- [x] Task output capped per task and history bounded to 50 records
- [x] Debug and Release macOS CI workflow

## In progress
- [ ] Verify Debug and Release CI on the latest commit
- [ ] Add unit tests for task queue lifecycle and process completion/cancellation
- [ ] Add a command approval layer before enabling arbitrary shell commands
- [ ] Add project-specific build adapters for Xcode, Unity and web
- [ ] Connect Goose after execution permissions and lifecycle are tested

## Security boundaries
Current commands are a fixed allowlist launched directly with Foundation Process. CODO does not invoke a shell or accept arbitrary user-supplied command strings. The runner is limited to the imported project working directory and holds its security-scoped access while running. No write-capable agent workflow is enabled yet.

## Validation
- The prior CI run for the previous process-runner milestone was pending without assigned jobs when last checked.
- The task queue and Activity workspace changes require fresh Debug and Release CI confirmation.
- Physical Mac launch and visual validation have not been performed.

## Next
Wait for and inspect the fresh CI run, fix any build errors from actual logs, and add automated tests for task lifecycle. Then implement explicit command approval and Xcode/Unity build adapters before Goose integration.