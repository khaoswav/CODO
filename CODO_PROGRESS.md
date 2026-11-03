# CODO Development Progress

## Product
Native macOS development command center. Tagline: **Think. Code. Create.**

## Design direction
Apple-native macOS interaction patterns, SwiftUI, SF Symbols, system typography, semantic AppKit colors, native folder selection and keyboard commands. The interface follows the user's system light/dark appearance; violet is the restrained brand accent.

## Current milestone
Milestone 1: Native app foundation, project browsing, and static project inspection.

## Completed in repository
- [x] Repository initialized
- [x] Native SwiftUI app entry point and Xcode project
- [x] Adaptive system semantic colors for light and dark appearance
- [x] Reusable panel and button components
- [x] Project model and local JSON persistence
- [x] Workspace navigation and project rail
- [x] Dashboard, AI Workspace placeholder, Terminal and Activity placeholders
- [x] macOS CI workflow with Debug and Release configurations
- [x] Native NSOpenPanel project-folder import
- [x] Project type detection for common Xcode, Unity and web folders
- [x] Security-scoped bookmark metadata stored with imported project records
- [x] Project Files workspace and folder navigation
- [x] Read-only text previews for supported source/config files up to 256 KB
- [x] Hidden files omitted by default
- [x] Security-scoped access reacquired for project file operations
- [x] Canonical path checks to block symlink escapes outside the project root
- [x] Resolve moved project folders through their stored bookmarks
- [x] Project Overview workspace
- [x] Static Xcode project inspection for native target names and product types
- [x] Unity Editor version, top-level Assets count, and package manifest inspection
- [x] Web package name/version, scripts, and dependency count inspection
- [x] macOS/iOS Xcode platform hint detection
- [x] Project metadata displayed in native SwiftUI surfaces

## In progress
- [ ] Confirm Debug and Release CI on latest commit
- [ ] Add automated tests for analyzer and file-access boundaries
- [ ] Improve Xcode workspace and scheme discovery
- [ ] Add build-time target inspection through the future Xcode command adapter
- [ ] Add safe file editing and change review after the execution engine exists

## Not implemented yet
- Agent/task execution
- Goose integration
- Process streaming and cancellation
- Terminal command execution
- Xcode and Unity build adapters
- Git/GitHub operations from the app
- Task history and persistent execution logs
- Release packaging

## Validation
- A previous source-path-fix revision passed a macOS Debug CI build.
- Project browser and analyzer changes are awaiting fresh Debug and Release CI confirmation.
- Local physical Mac launch and visual validation have not been performed.

## Next task
Verify CI and add automated tests. Then implement the project-scoped process runner with live output and cancellation, before connecting Goose.
