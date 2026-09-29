#!/bin/bash
# The XCTest host deliberately does not start the Finder service or show UI.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/test-results
result_path="$(mktemp -d "$PWD/build/test-results/run.XXXXXX")/Tests.xcresult"
xcodebuild -project finder-fixer.xcodeproj -scheme finder-fixer \
    -configuration Debug -derivedDataPath build \
    -destination "platform=macOS,arch=$(uname -m)" \
    -parallel-testing-enabled NO -resultBundlePath "$result_path" test
