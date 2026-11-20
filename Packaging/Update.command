#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
dst="$HOME/Library/Input Methods/TypeBlend.app"
dir="$(dirname "$dst")"
mkdir -p "$dir"
codesign --verify --strict TypeBlend.app
stage="$(mktemp -d "$dir/.songngu-update.XXXXXX")"
ditto TypeBlend.app "$stage/new.app"
codesign --verify --strict "$stage/new.app"
previous="$dst"
legacy="$dir/SongNgu.app"
if [[ -e "$legacy" ]]; then
    if [[ -e "$dst" ]]; then
        echo "Tìm thấy cả SongNgu.app và TypeBlend.app. Hãy di chuyển bản cũ ra khỏi Input Methods trước khi cập nhật."
        exit 1
    fi
    previous="$legacy"
fi
if [[ -e "$previous" ]]; then
    id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$previous/Contents/Info.plist")
    [[ "$id" == org.songngu.inputmethod.Telex ]] || exit 1
    pkill -x -u "$(id -u)" "$(basename "$previous" .app)" || true
    mv "$previous" "$stage/previous"
fi
if ! mv "$stage/new.app" "$dst"; then
    [[ ! -d "$stage/previous" ]] || mv "$stage/previous" "$previous"
    exit 1
fi
echo "Đã cài TypeBlend 0.2.6"
./activate "$dst" || echo "Hãy chọn TypeBlend từ menu bộ gõ của macOS."
