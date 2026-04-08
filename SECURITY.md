# Security Policy

## Supported Versions

Security fixes will target the latest `main` branch and the most recent tagged release after the repository is published.

## Reporting a Vulnerability

Please do not open a public GitHub issue for a sensitive security report.

Preferred path:

1. Use GitHub Security Advisories for the repository once it is published.
2. If advisories are not enabled yet, contact the maintainers through the private contact channel listed in the repository settings.

Please include:

- A clear description of the issue
- Affected module or surface
- Reproduction steps or proof of concept
- Any mitigation ideas you already validated

## Scope

High-priority areas for review:

- Hook installation and repair logic for local agent CLIs
- Apple Events and terminal jump execution paths
- Update checks and packaging scripts
- Any future telemetry, diagnostics export, or external network surfaces
