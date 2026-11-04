# CODO Development Progress

## Product definition

CODO is a single-purpose native macOS coding agent. FreeLLMAPI supplies model access; the Goose-compatible agent runtime performs coding tasks against the user's local project.

The complete user flow is:
1. Select a local project.
2. Describe a task.
3. Inspect the project and prepare a plan.
4. Obtain approval before applying changes or executing build/test commands.
5. Review and approve unified diffs.
6. Run build/tests and offer bounded fixes for failures.
7. Report only verified results.

## Design system

Axor-inspired premium AI control center, implemented in native SwiftUI.

| Token | Hex |
|---|---|
| Obsidian background | `#0B0814` |
| Plum glass surfaces | `#20102B` |
| Electric violet | `#8B35FF` |
| Neon pink | `#F044B8` |
| Highlight pink | `#FF9BCE` |

Layered translucent panels, controlled violet/pink glow, high-contrast typography, and animation used to communicate agent activity.

## Implemented

- [x] Native macOS SwiftUI app and Xcode project.
- [x] Single agent workspace with local project picker.
- [x] Plasma Fusion theme and Axor-inspired live agent control rail.
- [x] Project-scoped access using security-scoped bookmarks.
- [x] Goose CLI compatibility adapter with streaming output and cancellation.
- [x] FreeLLMAPI default provider using the OpenAI-compatible API.
- [x] Default FreeLLMAPI server URL `http://localhost:3001` and model `auto`.
- [x] FreeLLMAPI unified key stored in macOS Keychain.
- [x] Authenticated `/v1/models` connection check.
- [x] Provider environment setup for Goose: `OPENAI_HOST`, `OPENAI_BASE_PATH`, and `OPENAI_API_KEY`.
- [x] Per-task approval before agent analysis.
- [x] Unified diff parsing and per-file patch review.
- [x] Approved writes constrained to the selected project, with backups and stale-file checks.
- [x] Separate approval for build/test commands.
- [x] Bounded build-failure repair loop.
- [x] Legacy dashboard, project-browser, project-overview, terminal, and developer-intelligence views removed from the app target and source tree.

## Remaining

- [ ] Finish and verify Debug/Release CI on the latest branch commit.
- [ ] Verify the packaged macOS app and Xcode source ZIP artifacts.
- [ ] Remove unused backend modules only after confirming they are not shared by the agent, project memory, patch review, or build/test workflow.
- [ ] Replace the Goose CLI compatibility adapter with a built-in CODO agent runtime.
- [ ] Run a real FreeLLMAPI-backed coding task on the user's Mac.
- [ ] Physically launch CODO and validate the complete workflow on the user's Mac.

## Security and honesty

- API keys are stored in macOS Keychain and are not written to project files.
- The current Goose prompt requests read-only inspection/proposals, but this prompt alone is not a hard sandbox.
- File writes are separately reviewed and approved by the user.
- Build/test commands require a separate approval.
- The app must not report success unless the requested operation and verification actually succeeded.
- GitHub CI does not count as physical Mac validation.
- No PR has been merged.
