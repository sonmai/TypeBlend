#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
out="${1:-$PWD/build}"
app="$out/SongNgu.app/Contents"
mkdir -p "$app/MacOS" "$app/Resources" "$out/modules"
swiftc -module-cache-path "$out/modules" -O -whole-module-optimization -target arm64-apple-macos13.0 TelexCore/*.swift Core/*.swift App/main.swift -o "$app/MacOS/SongNgu"
cp Resources/Info.plist "$app/"
cp Resources/ng-tags.bin Resources/ng.bin Resources/collisions.txt Notices/*.txt Resources/model.json Resources/MenuIcon.pdf TelexCore/LICENSE TelexCore/DATA-SOURCES.md "$app/Resources/"
codesign --force --sign - "$out/SongNgu.app"
codesign --verify --strict "$out/SongNgu.app"
