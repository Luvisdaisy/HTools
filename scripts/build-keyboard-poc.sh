#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POC_BUILD="$ROOT/build/keyboard-poc"
export CLANG_MODULE_CACHE_PATH="$POC_BUILD/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$POC_BUILD/swift-cache"
mkdir -p "$POC_BUILD" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"
SWIFT_ARGS=(--package-path "$ROOT/KeyboardGuardPOC" --scratch-path "$POC_BUILD" --cache-path "$POC_BUILD/package-cache" --config-path "$POC_BUILD/config" --security-path "$POC_BUILD/security" --disable-sandbox)
if [[ "${1:-}" == "test" ]]; then
    swift test "${SWIFT_ARGS[@]}"
    exit
fi
swift build "${SWIFT_ARGS[@]}"
POC_BIN="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)"
mkdir -p "$ROOT/dist"
cp "$POC_BIN/KeyboardGuardPOC" "$ROOT/dist/KeyboardGuardPOCWorker.next"
codesign --force --sign - "$ROOT/dist/KeyboardGuardPOCWorker.next"
mv "$ROOT/dist/KeyboardGuardPOCWorker.next" "$ROOT/dist/KeyboardGuardPOCWorker"
if [[ "${1:-}" == "worker" ]]; then
    printf 'Built worker: %s\n' "$ROOT/dist/KeyboardGuardPOCWorker"
    exit
fi
POC_APP="$ROOT/dist/KeyboardGuardPOC.app"
mkdir -p "$POC_APP/Contents/MacOS"
cp "$POC_BIN/KeyboardGuardPOC" "$POC_APP/Contents/MacOS/KeyboardGuardPOC"
cat > "$POC_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KeyboardGuardPOC</string>
<key>CFBundleIdentifier</key><string>local.HTools.keyboard-poc</string>
<key>CFBundleName</key><string>KeyboardGuardPOC</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$POC_APP"
printf 'Built: %s\n' "$POC_APP"
