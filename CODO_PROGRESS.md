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
- [ ] Verify Debug and Release CI on the latest Developer Intelligence commit
- [ ] Add automated tests for command approval, build planning and file change safety
- [ ] Improve Xcode scheme selection and build result parsing
- [x] Add project-wide source/config inventory with file, line and language metrics
- [x] Build source import/include and package dependency links
- [x] Resolve unambiguous local Swift and relative ES module imports into file-to-file graph edges
- [x] Add local build failure fingerprints, common compiler-error classification, next-step hints and credential redaction
- [x] Add persisted sequential Architect, Planner, Implementer and Reviewer Goose roles with stage status, approval gates and retry recovery
- [x] Add static code-quality and performance heuristics, including TODOs, force unwraps, debug output, blocking I/O, deadlock patterns and embedded-secret detection without printing secret values
- [x] Persist project-specific purpose, architecture notes, decisions, next steps and latest scan summary locally
- [x] Feed saved project memory into Goose task context
- [x] Add staged multi-step task planning and handoff into AI Workspace
- [x] Add Git branch creation, staged-only commit, push and GitHub CLI pull-request actions behind explicit approval
- [x] Add Unity editor discovery in system and user Unity Hub locations
- [x] Support npm/yarn/pnpm package manager detection and non-watch test execution
- [x] Add true unified diff parsing and per-file patch review for Goose proposals
- [x] Add automated Developer Intelligence, source graph, build diagnostic and Agent Orchestrator regression tests
- [ ] Add patch parser and Git workflow automated unit tests
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

## Developer Intelligence validation
- Recursive source/config inventory is bounded to 4,000 files and 256 KB per file; common generated/vendor directories are skipped.
- Dependency edges are inferred from language imports/includes and package.json/Unity package manifests. Unambiguous local imports resolve into file-to-file edges; external or ambiguous imports are not guessed. This is a static map, not a compiler-level graph.
- Quality/performance findings are heuristic indicators, not a compiler, runtime profiler or formal security audit. Credential-like values are never shown in the report.
- Project memory is stored locally per project UUID under Application Support/CODO/ProjectMemory and is included in Goose prompts.
- Build errors are fingerprinted, categorized and merged by signature. Common missing-symbol/module, linker, signing, package-resolution and type-check failures receive targeted next-step hints. Credential-like values are redacted before memory storage and when included in build diagnostics.
- Multi-step plans run as sequential role-specific Goose calls: Architect, Planner, Implementer and Reviewer. They share the configured Goose provider/model; these are separate prompted stages, not parallel independent models. Each stage has persisted status and failure/retry handling.
- The Reviewer Agent returns findings for the human patch review. It does not apply changes. Every file still needs explicit approval, and builds/tests require a separate approval.
- Git integration uses fixed Git argument arrays. Commit only includes already staged files. Push and PR creation require a separate approval; PR creation requires an installed and authenticated GitHub CLI.

## AI Patch Review + Build/Fix validation
- Goose unified diff parser accepts modifications to existing supported text files only. It rejects new/deleted/renamed files, unsafe paths, unsupported extensions, oversized patches, and context mismatches.
- Hunk application honors each unified diff source line offset and verifies context against the current file before preparing a change.
- Review UI shows original and proposed content with line numbers; each file has independent Reject and Approve & Apply actions.
- Approved writes use the existing project-root checks, stale-file detection, and automatic backup.
- After all accepted changes are applied, Debug/Release or web/Unity build/test actions can be selected. Each action has a separate confirmation and is executed through the typed command queue.
- Failed build/test output can be sent back to Goose for a proposed patch. The UI limits this feedback cycle to two fix attempts; every new patch still requires per-file review and approval.
- The build feedback loop is user-controlled, not an unattended agent loop. Failed build diagnostics are saved locally and sent to Goose only after the user chooses the fix action.

## Goose Integration validation
- Goose CLI adapter, provider settings UI, Keychain storage, approval prompt, live output, cancellation and Activity history are implemented.
- Goose runs sequential Architect, Planner, Implementer and Reviewer role prompts using the configured provider/model. These roles share the same Goose CLI/model, rather than running as parallel independent agents.
- Goose is instructed to operate in analysis/proposal-only mode. This prompt is not a hard sandbox; the CLI and its configured extensions may still have capabilities. Do not treat it as an enforced read-only boundary.
- Unified diff proposals are parsed and shown in the per-file review sheet. Only supported modifications to existing text files are accepted.
- Saved project memory is appended to Goose task context. This includes the latest project scan summary, purpose, architecture notes, previous decisions and next steps.

## Validation
- Task Engine milestone CI: Debug and Release succeeded on commit b5c29334f5884adf3365529c7a11e1b95f565f75.
- An earlier Command Approval + Build Engine CI attempt exposed a Swift optional-chaining parse error in Xcode scheme discovery; the source was corrected in commit 3f8d93d.
- Goose integration CI exposed that GooseConfiguration needed Codable conformance for preference persistence; fixed in commit 8e91be7.
- Follow-up improvements add npm/yarn/pnpm detection and Unity Hub editor discovery. Goose integration CI initially exposed a duplicate PBX object ID, corrected in commit 12f4d5d. Developer Intelligence CI exposed a missing Xcode project registration for GitWorkflowService.swift; the file reference and source build entry were added in commit 1300410d.
- Developer Intelligence test runs caught and fixed project-root URL normalization in the recursive scanner, and a retry-stage selector that could mistake the Planner step for the Implementer step. Fixes are in commits 71628b1, 57da220 and 120f900.
- Latest CI run 41726171868 succeeded: all six Developer Intelligence/Agent Orchestrator test groups passed, and both Debug and Release Xcode builds succeeded.
- Build adapters are implemented but have not yet been run against real Xcode, Unity or web projects on the user's Mac.
- Physical Mac launch and visual validation have not been performed.

## Next
Add automated tests for unified diff parsing, command approval, build planning and Git workflow safety. Then validate the sequential Goose roles, real Xcode/Unity/web builds and authenticated GitHub CLI on a physical Mac.
