#!/bin/bash
# Build locally with ad-hoc signing; no Apple Developer account required.
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
case "$configuration" in
    Debug|Release) ;;
    *) echo "Usage: $0 [Debug|Release]" >&2; exit 2 ;;
esac
xcodebuild -project HTools.xcodeproj -scheme HTools \
    -configuration "$configuration" -derivedDataPath build \
    -destination 'platform=macOS' build
