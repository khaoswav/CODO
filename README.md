# CODO

**A local AI coding agent for macOS.**

CODO combines a premium native macOS workspace with a Goose-style coding-agent workflow powered by FreeLLMAPI.

## What CODO does

1. Open a local project folder.
2. Describe the task in natural language.
3. Inspect the project and prepare an implementation plan.
4. Ask for approval before applying code changes or running build/test commands.
5. Review proposed unified diffs and approve file-by-file changes.
6. Run project builds/tests, diagnose failures, and offer bounded fixes.
7. Report the result only after verification.

## Design

- Native SwiftUI macOS app.
- Axor-inspired premium AI control-center atmosphere.
- Plasma Fusion palette: obsidian `#0B0814`, plum glass `#20102B`, electric violet `#8B35FF`, neon pink `#F044B8`, highlight pink `#FF9BCE`.
- Layered translucent surfaces, controlled neon glow, and live agent activity.

## FreeLLMAPI

The default gateway is a local FreeLLMAPI server:

- Server: `http://localhost:3001`
- OpenAI-compatible endpoint: `/v1/chat/completions`
- Default model: `auto`
- Authentication: FreeLLMAPI unified API key, stored in macOS Keychain.

Start FreeLLMAPI on your Mac, copy the unified key from its dashboard, then enter the server URL and key in CODO's Agent Connection settings. Use **Test connection** to verify the `/v1/models` endpoint.

The current agent runtime uses the Goose CLI compatibility adapter with Goose's OpenAI-compatible provider configuration. A built-in CODO runtime is not yet complete.

## Safety

- Project access is scoped to the selected local folder.
- The agent is asked to inspect and propose changes, not directly modify files.
- Every file change is shown as a unified diff and requires explicit approval.
- Build/test commands require separate approval.
- Writes are restricted to supported project files, with backups and stale-file checks.
- Build-fix retries are bounded.

## Requirements

- macOS 14+
- Xcode 16+
- Swift 5.10+
- FreeLLMAPI running locally or at a reachable trusted URL.
- Goose CLI installed for the current compatibility runtime.

## Build

Open `CODO.xcodeproj` in Xcode and run the `CODO` scheme.

## Validation status

GitHub CI validates the source and build workflows. A real provider-backed task and physical Mac launch/visual inspection are still pending.
