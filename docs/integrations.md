# Integrations

## First-Class Agent Sources

Supported today with real local data paths:

- Claude Code
  - hook-managed Unix socket transport
  - captured event history under `~/.agent-island/events/claude`
  - direct reply via live socket bridge or `claude --resume --print`
- Codex
  - session discovery from `~/.codex/session_index.jsonl`
  - rollout parsing from `~/.codex/sessions/**/rollout-*.jsonl`
  - direct reply via `codex resume`
- Gemini CLI
  - session discovery from `~/.gemini/tmp`
  - direct reply via `gemini --resume --prompt`
- OpenCode
  - plugin/socket captures under `~/.agent-island/events/openclaw`
  - fallback snapshot and history from the local OpenCode SQLite database
  - direct reply through the live bridge or stored resume command

## Experimental Sources

Visible in settings, but not treated as first-class shipped support:

- Cursor
- GitHub Copilot

These can expose jump or bridge metadata, but they are not part of the default supported product surface.

## Transport Layer

Realtime coordination is handled by two transport families:

- `HookSocketLiveTransport`
  - consumes Claude/OpenCode socket events through `ClaudeHookTransport`
- `SourceWatchLiveTransport`
  - watches adapter-owned local files and directories and requests source reloads through `SessionCoordinator`

## Terminal And IDE Surfaces

- iTerm2
  - precise AppleScript session jump when a terminal session id is known
- Terminal.app
  - foreground fallback when precise session metadata is unavailable
- VS Code / Cursor
  - shared `terminal-focus` extension metadata and install hints

## Fixtures

Fixtures remain in `Fixtures/` for:

- parser regression coverage
- UI preview data
- smoke tests when a local agent installation is unavailable

Production adapters do not use fixture fallback by default.
