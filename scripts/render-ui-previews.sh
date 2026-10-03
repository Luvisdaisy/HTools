#!/bin/bash
# Render native components offscreen with isolated, illustrative state.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/previews
sources=()
while IFS= read -r path; do sources+=("$path"); done < <(find HTools KeyboardGuardPOC/Sources/KeyboardCore -name '*.swift' ! -name HToolsApp.swift | sort)
xcrun swiftc -D UI_PREVIEW -parse-as-library -target "$(uname -m)-apple-macosx13.0" \
    "${sources[@]}" scripts/render-ui-previews.swift -o build/previews/render
build/previews/render
