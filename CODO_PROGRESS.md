# CODO Development Progress

## Product
Native macOS development command center. Tagline: **Think. Code. Create.**

## Design direction
Apple-native macOS interaction patterns, SwiftUI, SF Symbols, system typography, semantic AppKit colors, native folder selection and keyboard commands. The interface follows the user's system light/dark appearance; violet is the restrained brand accent.

## Current milestone
Milestone 1: Native app foundation and project browsing.

## Completed in repository
- [x] Repository initialized
- [x] Native SwiftUI app entry point and Xcode project
- [x] Adaptive system semantic colors for light and dark appearance
- [x] Reusable panel and button components
- [x] Project model and local JSON persistence
- [x] Workspace navigation and project rail
- [x] Dashboard, AI Workspace placeholder, Terminal and Activity placeholders
- [x] macOS CI workflow with Debug and Release configurations
- [x] Fixed Xcode source group paths after CI exposed missing source paths
- [x] Native NSOpenPanel project-folder import
- [x] Project type detection for common Xcode, Unity and web folders
- [x] Security-scoped bookmark metadata stored with imported project records
- [x] Project import actions in the project rail and Dashboard
- [x] Project Files workspace and folder navigation
- [x] Read-only text previews for supported source/config files up to 256 KB
- [x] Hidden files omitted by default
- [x] Security-scoped access reacquired for project file operations
- [x] Canonical path checks to block symlink escapes outside the project root
- [x] Resolve moved project folders through their stored bookmarks

## In progress
- [ ] Confirm Debug and Release CI on latest commit
- [ ] Add automated tests for project type detection and file access boundaries
- [ ] Improve macOS versus iOS Xcode project classification
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
- Current file-browser and adaptive-theme changes require fresh Debug and Release CI confirmation.
- Local physical Mac launch and visual validation have not been performed.

## Next task
Verify CI. Then add automated model/service tests and a project overview with detected build targets before implementing the background task engine.
