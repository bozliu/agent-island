# Release Process

Agent Island is distributed publicly through GitHub only:

- repository: `github.com/bozliu/agent-island`
- downloads: GitHub Releases

## Code submission checklist

Before you submit code publicly:

1. Remove task-state files, local notes, screenshots used only for private iteration, build artifacts, and local machine metadata.
2. Run local validation:
   - `swift build -c debug --product AgentIslandApp`
   - `scripts/build-app.sh`
3. Review `git status` and make sure only intentional public files remain.
4. Open a focused PR to `main`.
5. Let CI pass before merging.

## Public release lane

1. Merge to `main`
2. Tag a release
3. Let GitHub Actions build the app and draft the release
4. Upload or attach release notes
5. If Apple signing and notarization secrets are configured, ship the notarized app bundle / DMG from the release

## CI/CD expectations

- CI should validate buildability and packaging smoke checks
- Release workflow should package artifacts and create a draft GitHub Release
- Signing and notarization must be secrets-driven, never committed to the repo

## Sensitive material that must stay out of git

- signing certificates
- notarization credentials
- private feeds or private release keys
- local overlay assets
- `.omx/`, build outputs, and local task-state files
