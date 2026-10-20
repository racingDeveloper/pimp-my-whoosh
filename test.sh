#!/bin/bash
# Compiles and runs Tests/main.swift against the non-UI sources, plus the translation coverage check.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -swift-version 5 -o build/tests Sources/Settings.swift Sources/GameConfig.swift Sources/Details.swift Tests/main.swift
./build/tests
for strings in Resources/*.lproj/Localizable.strings; do
  [[ "$strings" == Resources/en.lproj/* ]] && continue
  python3 scripts/extract_strings.py --check "$strings"
done
echo "All tests passed"
