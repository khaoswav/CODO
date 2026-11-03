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
- [x] Goose CLI process adapter with live output and cancellation
- [x] Provider/model preferences persisted locally and API key stored in macOS Keychain
- [x] AI Workspace task submission with explicit per-run approval
- [x] AI agent output and completion recorded in persistent Activity history
- [x] Parse multi-file Goose unified diffs with project-relative path and hunk-context validation
- [x] Review original and proposed file contents line-by-line, with per-file reject/apply actions
- [x] Apply approved AI patches through ProjectFileChangeService with backup and stale-file checks
- [x] Run project build/test commands from the review flow after a separate explicit approval
- [x] Return failed build/test logs to Goose for a proposed fix, with a two-attempt review loop

## Security boundaries
Current command execution uses fixed, typed command cases and Foundation Process with explicit executable paths and argument arrays. No arbitrary shell string is accepted. Build/test commands require a per-run user approval. File writes are limited to supported text files inside the imported project root, are reviewed before apply, are backed up under Application Support/CODO/Backups, and are rejected if the original file changed after review. Destructive commands, OS-level changes, and autonomous broad file access are not enabled.

## AI Patch Review + Build/Fix validation
- Goose unified diff parser accepts modifications to existing supported text files only. It rejects new/deleted/renamed files, unsafe paths, unsupported extensions, oversized patches, and context mismatches.
- Hunk application honors each unified diff source line offset and verifies context against the current file before preparing a change.
- Review UI shows original and proposed content with line numbers; each file has independent Reject and Approve & Apply actions.
- Approved writes use the existing project-root checks, stale-file detection, and automatic backup.
- After all accepted changes are applied, Debug/Release or web/Unity build/test actions can be selected. Each action has a separate confirmation and is executed through the typed command queue.
- Failed build/test output can be sent back to Goose for a proposed patch. The UI limits this feedback cycle to two fix attempts; every new patch still requires per-file review and approval.
- The build feedback loop is user-controlled, not an unattended agent loop.

## Goose Integration validation
- Goose CLI adapter, provider settings UI, Keychain storage, approval prompt, live output, cancellation and Activity history are implemented.
- Goose is instructed to operate in analysis/proposal-only mode. This prompt is not a hard sandbox; the CLI and its configured extensions may still have capabilities. Do not treat it as an enforced read-only boundary.
- The current milestone does not yet parse unified diffs into the file review sheet or apply AI-generated patches. Existing manual file review/apply remains separate.

## Validation
- Task Engine milestone CI: Debug and Release succeeded on commit b5c29334f5884adf3365529c7a11e1b95f565f75.
- An earlier Command Approval + Build Engine CI attempt exposed a Swift optional-chaining parse error in Xcode scheme discovery; the source was corrected in commit 3f8d93d.
- Goose integration CI exposed that GooseConfiguration needed Codable conformance for preference persistence; fixed in commit 8e91be7.
- Follow-up improvements add npm/yarn/pnpm detection and broader Unity Hub editor discovery. The latest CI attempt for the Goose integration initially failed because a new PBX file reference reused an existing Xcode project object ID. The collision was corrected with unique IDs in commit 12f4d5d; later Goose and patch-review changes still require fresh Debug and Release CI.
- Build adapters are implemented but have not yet been run against real Xcode, Unity or web projects on the user's Mac.
- Physical Mac launch and visual validation have not been performed.

## Next
Verify the latest Debug and Release CI, fix any compiler errors from actual logs, add automated tests for unified diff parsing and file-change safety, then validate the complete workflow on a physical Mac with Goose CLI installed.
