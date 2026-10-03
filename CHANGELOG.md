# Changelog

## 0.2.0 — 2026-10-03

- Rename app, project and products to HTools; migrate valid window preferences.
- Add keyboard control and unified first-launch permission setup.
- Install a signature-pinned keyboard service once; later toggles need no administrator prompt.
- Run privileged keyboard workers in the login user session and verify actual worker Input Monitoring access.
- Refresh the native settings UI, add permission progress and service management, preserve invalid drafts when navigating, and adapt the menu bar symbol to light/dark mode.
- Publish Chinese/English usage, architecture, privacy and verification documentation with component previews.


Notable changes are recorded here. Version numbers follow semantic versioning; 0.x releases may change before a stable 1.0 release.

## 0.1.1 — 2026-09-29

- Free universal DMG preview packaging with ad-hoc signing, architecture checks and SHA-256 checksums.
- Chinese/English installation, first-launch and update permission guidance.
- No Developer ID signing or notarization; Finder resizing behavior is unchanged.

## 0.1.0 — 2026-09-29

Initial public source preview.

- Native macOS menu bar app with configurable fixed Finder window dimensions.
- One-time automatic adjustment for new standard windows, local settings and an off switch.
- Accessibility permission guidance and screen-aware geometry policies.
- Unit tests for geometry, persistence, migration and settings drafts.
- MIT license, Chinese/English README, contributor documentation and macOS CI.

No signed/notarized binary is provided. Multiple displays, Intel and older macOS versions remain unverified through real desktop use. See [compatibility](README.en.md#compatibility).
