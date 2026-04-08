# Permissions

## Apple Events

Terminal jumping requires Apple Events access for the relevant apps.

Current adapter surfaces:

- `com.googlecode.iterm2`
- `com.apple.Terminal`
- future IDE bridge surfaces for Cursor and VS Code compatible environments

## Why The App Needs These Permissions

The core behavior of Agent Island is to route you back to the exact terminal or IDE context where an agent needs attention. That requires foregrounding the app and, for supported terminals, selecting the target tab or session.

## OSS Policy

- Request the minimum permission needed for the requested jump
- Do not silently broaden to unrelated apps
- Document every new permission in this file before merging
- Keep fallback behavior explicit when precise jump support is unavailable

## Current State

- iTerm2: AppleScript-based precise session jumping scaffolded
- Terminal.app: AppleScript-based custom-title lookup scaffolded
- Warp: app foregrounding scaffolded, precise jump deferred
- IDEs: install hints exist, packaged bridge extension deferred
