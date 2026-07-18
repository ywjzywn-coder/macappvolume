#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
BUILD_ROOT="$ROOT/dist/release-build"
PRODUCT="$BUILD_ROOT/Build/Products/Release/AppVolume.app"
ARCHIVE="$ROOT/dist/AppVolume-$VERSION.zip"

cd "$ROOT"
rm -rf "$BUILD_ROOT" "$ARCHIVE"

xcodebuild \
  -project AppVolume.xcodeproj \
  -scheme AppVolume \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_ROOT" \
  MARKETING_VERSION="$VERSION" \
  CLANG_ENABLE_CODE_COVERAGE=NO \
  GCC_GENERATE_TEST_COVERAGE_FILES=NO \
  GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO \
  CODE_SIGN_IDENTITY="-" \
  build

if [[ ! -d "$PRODUCT" ]]; then
  printf 'Release product not found: %s\n' "$PRODUCT" >&2
  exit 1
fi

if [[ -d "$PRODUCT/Contents/PlugIns" ]] || [[ -d "$PRODUCT/Contents/Frameworks/XCTest.framework" ]]; then
  printf 'Release product unexpectedly contains test bundles or XCTest.\n' >&2
  exit 1
fi

codesign --verify --deep --strict "$PRODUCT"
ditto -c -k --sequesterRsrc --keepParent "$PRODUCT" "$ARCHIVE"

printf '\nCreated %s\n' "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
