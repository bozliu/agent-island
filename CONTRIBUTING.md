# Contributing

## Principles

- Keep the project public-safe: no private credentials, no local release materials, no machine-specific task notes.
- Prefer real product behavior over marketing placeholders.
- Keep changes scoped to one subsystem or one user-visible story when possible.

## Local validation

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c debug --product AgentIslandApp
scripts/build-app.sh
```

`swift test` is also expected where the local Xcode toolchain exposes `XCTest`.

## Pull requests

- Open a PR against `main`
- Include validation notes
- Keep release-facing copy aligned with the actual shipped product surface
- Do not commit `dist/`, `.build/`, `.omx/`, local task-state files, or private assets

## Main contribution areas

- `Modules/AgentCore/`
- `Modules/SourceAdapters/`
- `Modules/TerminalAdapters/`
- `Modules/IDEBridge/`
- `App/`
- `scripts/`
