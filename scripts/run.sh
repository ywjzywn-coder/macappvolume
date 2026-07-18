#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodebuild -project AppVolume.xcodeproj -scheme AppVolume -configuration Debug -destination 'platform=macOS' build
APP=$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/AppVolume-*/Build/Products/Debug/AppVolume.app 2>/dev/null | head -1)
if [[ -z "${APP}" ]]; then
  echo "Build product not found"
  exit 1
fi

# Easy-to-find copy
mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/AppVolume.app"
cp -R "$APP" "$ROOT/dist/AppVolume.app"
# Optional user Applications
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/AppVolume.app"
cp -R "$APP" "$HOME/Applications/AppVolume.app"

echo "Launching: $HOME/Applications/AppVolume.app"
open "$HOME/Applications/AppVolume.app"
echo "Also copied to: $ROOT/dist/AppVolume.app"
