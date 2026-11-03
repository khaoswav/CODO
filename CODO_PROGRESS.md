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
- [x] Persistent sequential task queue and local execution history
- [x] Activity workspace with expandable task logs and history cleanup
- [x] Explicit approval prompt before Xcode, Unity, web build and web test tasks
- [x] Xcode Debug and Release build command planning
- [x] Unity macOS batch build planning using an installed Unity Hub editor
- [x] Web npm/yarn/pnpm build/test script detection from package.json and lockfiles
- [x] Unity Hub editor discovery in standard system and user Applications locations
- [x] Deterministic selection of the first shared Xcode scheme
- [x] Build commands run directly as executable plus argument arrays, never through a shell
- [x] File editor for supported text/source files up to 256 KB
- [x] Side-by-side original/proposed content review before applying file edits
- [x] File edits require an explicit Apply approval
- [x] Project-root and symlink boundary checks for file changes
- [x] Automatic source backup before each approved write
- [x] Refuse to overwrite if the source file changed after review
- [x] Debug and Release macOS CI workflow

## In progress
- [ ] Verify Debug and Release CI on the latest commit
- [ ] Add automated tests for command approval, build planning and file change safety
- [ ] Improve Xcode scheme selection and build result parsing
- [ ] Add Unity editor discovery beyond the default Unity Hub installation path
- [ ] Support npm/yarn/pnpm package manager detection and non-watch test execution
- [ ] Add true unified diff view and file restore from backups
- [ ] Connect Goose after permission and execution lifecycle are validated

## Security boundaries
Current command execution uses fixed, typed command cases and Foundation Process with explicit executable paths and argument arrays. No arbitrary shell string is accepted. Build/test commands require a per-run user approval. File writes are limited to supported text files inside the imported project root, are reviewed before apply, are backed up under Application Support/CODO/Backups, and are rejected if the original file changed after review. Destructive commands, OS-level changes, and autonomous broad file access are not enabled.

## Validation
- Task Engine milestone CI: Debug and Release succeeded on commit b5c29334f5884adf3365529c7a11e1b95f565f75.
- An earlier Command Approval + Build Engine CI attempt exposed a Swift optional-chaining parse error in Xcode scheme discovery; the source was corrected in commit 3f8d93d.
- Follow-up improvements add npm/yarn/pnpm detection and broader Unity Hub editor discovery. The newest combined commit still requires fresh Debug and Release CI.
- Build adapters are implemented but have not yet been run against real Xcode, Unity or web projects on the user's Mac.
- Physical Mac launch and visual validation have not been performed.

## Next
Inspect the latest CI logs and fix any compiler errors. Add automated tests and harden build result reporting. Then connect Goose to propose code edits and tasks, while keeping the existing review/approval boundary before any project file is changed or build command is run.
