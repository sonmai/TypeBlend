#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
dst="$HOME/Library/Input Methods/SongNgu.app"
dir="$(dirname "$dst")"
mkdir -p "$dir"
codesign --verify --strict SongNgu.app
stage="$(mktemp -d "$dir/.songngu-update.XXXXXX")"
ditto SongNgu.app "$stage/new.app"
codesign --verify --strict "$stage/new.app"
if [[ -e "$dst" ]]; then
    id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$dst/Contents/Info.plist")
    [[ "$id" == org.songngu.inputmethod.Telex ]] || exit 1
    pkill -x -u "$(id -u)" SongNgu || true
    mv "$dst" "$stage/previous"
fi
if ! mv "$stage/new.app" "$dst"; then
    [[ ! -d "$stage/previous" ]] || mv "$stage/previous" "$dst"
    exit 1
fi
echo "Đã cài SongNgu 0.2.2"
./activate "$dst" || echo "Hãy chọn SongNgu từ menu bộ gõ của macOS."
