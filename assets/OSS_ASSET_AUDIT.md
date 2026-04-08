# OSS Asset Audit

This file tracks which assets from the shipped commercial DMG are safe to reproduce in the OSS rebuild.

## Excluded Until Verified

- App icon from the commercial bundle
- Pixel cursor image
- Extension icon
- Onboarding wallpaper
- Bundled QR code images
- Bundled font files
- Bundled sound files

## Replacement Policy

- Replace excluded assets with placeholders, public-domain assets, or newly created originals
- Record provenance for every new asset added to `assets/`
- Do not copy binary resources from the commercial app into this repository unless redistribution rights are confirmed in writing

## Current Placeholder Strategy

- Use SwiftUI styling and SF Symbols for the prototype
- Keep packaging scripts icon-optional
- Track future asset work in issues labeled `design-system` or `asset-audit`
