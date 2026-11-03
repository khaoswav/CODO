# CODO Development Progress

## Product
Native macOS development command center. Tagline: **Think. Code. Create.**

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

## In progress
- [ ] Verify CI build on GitHub Actions
- [ ] Add project folder picker and real project import
- [ ] Replace sample projects with imported folders

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
- GitHub source files committed; CI result must be checked before claiming build success.
- Local physical Mac launch and visual validation have not been performed.

## Next task
Complete project import with NSOpenPanel, persist real project URLs, and add tests for ProjectStore.
