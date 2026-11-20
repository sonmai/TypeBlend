#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
out="${1:-$PWD/build}"
mkdir -p "$out/modules"
swiftc -module-cache-path "$out/modules" -O -whole-module-optimization TelexCore/*.swift Core/*.swift Tests/main.swift -o "$out/replay"
"$out/replay" Resources/model.json
swiftc -module-cache-path "$out/modules" -O -whole-module-optimization TelexCore/*.swift Core/*.swift App/MarkedText.swift App/InlineComposition.swift Tests/AppKit/main.swift -o "$out/appkit-test"
"$out/appkit-test" Resources
