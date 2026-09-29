#!/bin/bash
# Free distribution: ad-hoc signed app, no Developer ID or notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
work_dir="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
xcodebuild -project finder-fixer.xcodeproj -scheme finder-fixer \
    -configuration Release -derivedDataPath "$work_dir/DerivedData" \
    -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build
app="$work_dir/DerivedData/Build/Products/Release/finder-fixer.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
name="Finder-Fixer-${version}-universal.dmg"
if [[ -e "dist/$name" || -e "dist/$name.sha256" ]]; then
    echo "Refusing to overwrite dist/$name or its checksum. Move existing artifacts first." >&2
    exit 1
fi
architectures="$(lipo -archs "$app/Contents/MacOS/finder-fixer")"
for architecture in arm64 x86_64; do
    case " $architectures " in
        *" $architecture "*) ;;
        *) echo "Missing architecture: $architecture" >&2; exit 1 ;;
    esac
done
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dv "$app" 2>&1 | tee "$work_dir/signature.txt"
grep -q '^Signature=adhoc$' "$work_dir/signature.txt"
mkdir "$work_dir/image"
ditto "$app" "$work_dir/image/finder-fixer.app"
ln -s /Applications "$work_dir/image/Applications"
cp INSTALL.md "$work_dir/image/INSTALL.md"
cp LICENSE "$work_dir/image/LICENSE.txt"
hdiutil create -volname "Finder Fixer $version" -srcfolder "$work_dir/image" \
    -format UDZO "$work_dir/$name"
hdiutil verify "$work_dir/$name"
mv "$work_dir/$name" "dist/$name"
(cd dist && shasum -a 256 "$name" > "$name.sha256")
echo "Created dist/$name and dist/$name.sha256 (ad-hoc signed, not notarized)."
