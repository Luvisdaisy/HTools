# HTools

A native macOS menu bar utility for new Finder window sizes and optional built-in keyboard control. HTools succeeds Finder Fixer.

[Download v0.2.1](https://github.com/Luvisdaisy/HTools/releases/tag/v0.2.1) · [简体中文](README.md) · [Installation](INSTALL.md)

## Features

- Resize each new standard Finder window once. Existing windows, manual resizing, tabs and restored windows remain unchanged. Dimensions use logical points; the default is 1000 × 700.
- Show connected keyboards and disable only a confidently identified built-in keyboard while an external keyboard is present. Switching off, quitting, selected-device removal or sleep ends the session; reconnecting never automatically rearms it.
- Configure Accessibility, Input Monitoring and the keyboard service together. Administrator authorization is required to install/update/remove the service; normal keyboard toggles do not need a password.
- Check actual privileged worker permissions as well as foreground consent. Unavailable features lead to the shared Permissions page.

The UI is in Simplified Chinese. No accounts, network requests, analytics or third-party runtime dependencies. No typed content is recorded.

<img src="docs/images/finder.png" width="400" alt="Finder settings component preview">

This image is an offscreen render of real SwiftUI components with illustrative state, not a desktop or hardware test screenshot.

## Install, update and remove

Download `HTools-0.2.1-universal.dmg`, drag HTools to Applications, eject the image and launch the installed copy. Complete the three setup items. This is an **ad-hoc signed preview without Developer ID signing or notarization**; see [INSTALL.md](INSTALL.md) for the system opening flow.

Quit before replacing the app. Update the keyboard service in Permissions after every new binary; macOS may also require renewing privacy permissions. Before deleting HTools, remove its service from the Permissions management menu. Left-click the menu bar icon to toggle a compact anchored panel; right-click for Settings and Quit. The panel has no window controls and cannot detach or move. Press Escape or click outside to dismiss; the app continues running.

## Compatibility and evidence

Targets macOS 13+, with arm64 and x86_64 binaries. The test target needs macOS 14+. Building requires Xcode 26+ for the Icon Composer app icon; local development uses Xcode 27. The user confirmed the integrated keyboard feature works on Apple Silicon / macOS 26.6.2 after the worker-session correction. The new UI has component renders and automated regression checks.

Intel, older macOS versions, multiple displays, complete VoiceOver support and a systematic physical disconnect/crash/sleep recovery matrix remain unverified. Power and Touch ID keys are outside the blocking guarantee. Unit tests and API success are not physical keyboard evidence.

## Development

```sh
git clone https://github.com/Luvisdaisy/HTools.git HTools
cd HTools
./scripts/build.sh
./scripts/test.sh
./scripts/package-dmg.sh
```

Open `HTools.xcodeproj`; regenerate it with `python3 scripts/create-project.py` after adding source files. Test hosts do not start Finder control, install a helper or seize keyboards. See [architecture](docs/design.md), [verification](docs/manual-testing.md), [contributing](CONTRIBUTING.md), [release process](RELEASING.md), [privacy](PRIVACY.md) and [security](SECURITY.md).

The repository URL and historical releases keep their existing addresses. Licensed under [MIT](LICENSE). Finder and macOS are Apple trademarks. This project is not affiliated with Apple.
