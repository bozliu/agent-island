# Privacy

Agent Island is designed to route attention back to the right terminal or IDE session with minimal data collection.

## What The Open-Source Build Does

- Reads local fixture files in `Fixtures/` for demo and test use
- Will later read local agent state from user-controlled config and session files such as `.claude/` and `.codex/`
- Uses Apple Events for terminal or IDE jumping where the operating system and the user explicitly grant permission
- Keeps telemetry disabled by default

## What It Does Not Do By Default

- It does not upload prompts, transcripts, terminal history, or file contents to any hosted service
- It does not bundle private Sentry configuration
- It does not ship a closed commercial license or trial system

## Telemetry

- Telemetry is opt-in
- The current default telemetry client is a no-op implementation
- Any future analytics surface must document event names, payload shape, and retention policy in public

## Diagnostics

- The current prototype can expose a local diagnostics message inside the UI
- If diagnostics export becomes a file-based feature, it must redact sensitive paths and any prompt content by default

## Updates

- The OSS rebuild uses GitHub Releases as the public update surface
- Private Sparkle feeds and signing material from the commercial app are intentionally excluded
