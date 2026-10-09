#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
# Follow the app build's SDK compatibility fallback.
export SDKROOT="${SDKROOT:-$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1)}"
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  Sources/Tendedero/{Media,ScreenshotWatcher,Line,Inbox,Markup,Localization}.swift \
  scripts/check-recordings.swift -o "$OUT/check-recordings"
"$OUT/check-recordings" "$@"
