# Architecture

## Overview

Agent Island is split into product-facing layers instead of one large app target.

Main flow:

1. `AgentSourceAdapter` discovers sessions and loads source-specific history or snapshots
2. `AgentLiveTransport` emits live capture or file-change events
3. `SessionCoordinator` reloads the affected sources and merges them into a single event cache
4. `SessionIndexStore` reduces `AgentEvent` values into stable `AgentSession` snapshots
5. `AppModel` exposes those sessions to the notch UI, onboarding, and settings

## Module Map

- `AgentCore`
  - shared enums and payloads
  - support matrix for supported vs experimental sources
  - session reducer and grouping
- `SourceAdapters`
  - live adapters for Claude, Codex CLI, Gemini CLI, OpenCode
  - experimental adapters for Cursor and Copilot
  - hook repair and rollback helpers
- `AgentIslandUI`
  - `AgentLiveTransport`
  - `SessionCoordinator`
  - `AppModel`
  - notch and settings SwiftUI
- `TerminalAdapters`
  - iTerm2 and Terminal jump surfaces
- `IDEBridge`
  - shared VS Code / Cursor bridge metadata
- `SoundKit`
  - local sound categories and playback abstraction
- `UpdateKit`
  - bundle-aware release URL resolution with GitHub-first fallback
- `Telemetry`
  - opt-in settings surface with no-op default client

## Packaging

The repo keeps SwiftPM as the main development surface, while the scripts under `scripts/` act as the product packaging layer:

- `scripts/build-app.sh`
  - builds the executable and helper
  - merges public resources
  - optionally layers in local private assets and reference DMG resources
  - writes product metadata into `Info.plist`
- `scripts/package-dmg.sh`
  - packages the built app into a distributable DMG
  - reuses local private Finder metadata when available

## Current Gaps

- Cursor and Copilot remain experimental rather than first-class sources
- terminal focus is still stronger than full tmux-pane targeting
- exact byte-for-byte parity with the shipped DMG still depends on local private assets and signing material
