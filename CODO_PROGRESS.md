# CODO Development Progress

## Product
Native macOS development command center. Tagline: **Think. Code. Create.**

## Design direction
Apple-native macOS interaction patterns, SwiftUI, SF Symbols, system typography, semantic AppKit colors, native folder selection and keyboard commands. The interface follows the user's system light/dark appearance; violet is the restrained brand accent.

## Completed
- [x] Native SwiftUI app entry point and Xcode project
- [x] Adaptive system semantic colors for light and dark appearance
- [x] Dashboard, AI Workspace shell, Terminal and Activity surfaces
- [x] Project model, local JSON persistence and project rail
- [x] Native project-folder import and security-scoped bookmark metadata
- [x] Project Files browser with read-only source previews
- [x] Hidden files omitted and canonical path checks for symlink escapes
- [x] Project Overview and static project inspection
- [x] Xcode target/product type hints and macOS/iOS platform hints
- [x] Unity editor version and package manifest inspection
- [x] Web package metadata, scripts and dependency count inspection
- [x] Controlled process runner using Process, no shell command interpolation
- [x] Project-root working directory and security-scoped access held for process lifetime
- [x] Live combined stdout/stderr output
- [x] Stop/cancel running process
- [x] Initial diagnostic command allowlist: pwd, ls, git status, xcodebuild -list, swift --version, node --version, npm --version
- [x] Native Terminal workspace connected to process runner
- [x] Debug and Release macOS CI workflow

## In progress
- [ ] Verify latest Debug and Release CI
- [ ] Add automated tests for command policy, process lifecycle and project access boundaries
- [ ] Add task execution history and durable logs
- [ ] Add build adapters for Xcode, Unity and web
- [ ] Add user-approved file editing and diff review
- [ ] Connect Goose as the coding agent after execution infrastructure is stable

## Security and execution boundaries
Commands are selected from a fixed allowlist and launched directly with Process. No shell command interpolation is used. The first version intentionally offers diagnostic commands only. It does not yet provide arbitrary commands, write-capable automation, or agent execution. Destructive operations and broader command permissions require a separate approval layer.

## Validation
- Project Overview and process runner changes are awaiting fresh Debug and Release CI confirmation.
- Previous CI runs were cancelled by newer commits while the branch was being updated.
- Physical Mac launch and visual validation have not been performed.

## Next
Confirm CI, add tests, then build the permission/approval layer and a project task queue with streamed logs and cancellation. Goose integration follows after those foundations.