#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=${1:?Pass the release version, for example 0.2.7}
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || exit 2
out=${2:-"$PWD/build"}
mkdir -p "$out"
out=$(cd "$out" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
./build.sh "$stage/build"
mkdir "$stage/root" "$stage/components"
app="$stage/root/TypeBlend.app"
ditto "$stage/build/TypeBlend.app" "$app"
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$plist"
sign_args=(--sign -)
pkg_args=()
if [[ -n "${APP_SIGN_ID:-}" || -n "${INSTALLER_SIGN_ID:-}" ]]; then
    sign_args=(--sign "${APP_SIGN_ID:?}" --timestamp --options runtime)
    pkg_args=(--sign "${INSTALLER_SIGN_ID:?}" --timestamp)
fi
codesign --force "${sign_args[@]}" "$app"
codesign --verify --strict "$app"
pkgbuild --analyze --root "$stage/root" "$stage/bundles.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$stage/bundles.plist"
# Replace the existing user-local app, including pre-Installer versions.
# The existing 0.2.6 bundle has integer build number 8.
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsVersionChecked false' "$stage/bundles.plist"
pkgbuild --root "$stage/root" --ownership recommended --component-plist "$stage/bundles.plist" \
    --install-location '/Library/Input Methods' --identifier org.songngu.pkg.TypeBlend \
    --version "$version" "$stage/components/input.pkg"
productbuild --synthesize --package "$stage/components/input.pkg" "$stage/distribution.xml"
python3 - "$stage/distribution.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()
root.find("options").set("hostArchitectures", "arm64")
ET.SubElement(root, "title").text = "TypeBlend"
ET.SubElement(root, "domains", enable_anywhere="false", enable_currentUserHome="true", enable_localSystem="false")
tree.write(path, encoding="utf-8", xml_declaration=True)
PY
productbuild --distribution "$stage/distribution.xml" --package-path "$stage/components" \
    ${pkg_args[@]+"${pkg_args[@]}"} "$stage/TypeBlend.pkg"
mv "$stage/TypeBlend.pkg" "$out/TypeBlend.pkg"
