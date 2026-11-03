# CODO Development Progress

## Product
Native macOS development command center. Tagline: **Think. Code. Create.**

## Design direction
Apple-native macOS interaction patterns, SwiftUI, SF Symbols, system typography, clear hierarchy, restrained surfaces, native folder selection and keyboard commands. Dark graphite with a violet accent is the initial appearance.

## Current milestone
Milestone 1: Native app foundation and Studio shell.

## Completed in repository
- [x] Repository initialized
- [x] Native SwiftUI app entry point and Xcode project
- [x] Dark design tokens and reusable panel/button components
- [x] Project model and local JSON persistence
- [x] Workspace navigation and project rail
- [x] Dashboard, AI Workspace placeholder, Terminal and Activity placeholders
- [x] macOS CI workflow
- [x] Fixed Xcode source group paths after CI exposed missing source paths
- [x] Native NSOpenPanel project-folder import
- [x] Project type detection for Xcode, Unity and common web projects
- [x] Security-scoped bookmark metadata stored with imported project records
- [x] Project import actions in the project rail and Dashboard

## In progress
- [ ] Confirm CI on the latest project-import commit
- [ ] Improve project type detection for macOS versus iOS Xcode targets
- [ ] Add tests for project persistence and project type detection
- [ ] Add real project detail and file browser

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
- A previous source-path-fix revision passed the macOS GitHub Actions build.
- The latest changes still require CI confirmation.
- Local physical Mac launch and visual validation have not been performed.

## Next task
Verify the latest CI, then add a project detail/file browser with safe security-scoped access and tests.
