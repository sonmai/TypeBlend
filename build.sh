#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
out="${1:-$PWD/build}"
app="$out/TypeBlend.app/Contents"
mkdir -p "$app/MacOS" "$app/Resources" "$out/modules"
swiftc -module-cache-path "$out/modules" -O -whole-module-optimization -target arm64-apple-macos13.0 TelexCore/*.swift Core/*.swift App/*.swift -o "$app/MacOS/TypeBlend"
cp Resources/Info.plist "$app/"
cp Resources/english-phrases.txt Resources/ng-tags.bin Resources/ng.bin Resources/collisions.txt Notices/*.txt Resources/model.json Resources/MenuIcon.pdf TelexCore/LICENSE TelexCore/DATA-SOURCES.md "$app/Resources/"
cp LICENSE "$app/Resources/TypeBlend-LICENSE.txt"
cp -R Resources/*.lproj "$app/Resources/"
# macOS uses the input mode ID as the lookup key for its visible name.
mode=$(/usr/libexec/PlistBuddy -c 'Print :ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey:0' "$app/Info.plist")
for lang in en vi; do
    for table in InfoPlist Localizable; do
        name=$(/usr/libexec/PlistBuddy -c "Print :$mode" "$app/Resources/$lang.lproj/$table.strings")
        [[ "$name" == "TypeBlend" ]] || { echo "Invalid $lang input source name in $table" >&2; exit 1; }
    done
done
codesign --force --sign - "$out/TypeBlend.app"
codesign --verify --strict "$out/TypeBlend.app"
