#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
  echo "No Apple Distribution signing identity found."
  echo "Open Xcode > Settings > Accounts and download/manage distribution certificates,"
  echo "or sign in with the Apple Developer account that owns com.kneayerng.kycheck."
  exit 1
fi

source "$ROOT_DIR/scripts/release_defines.sh"
release_defines

flutter clean
flutter pub get
flutter build ipa --release "${RELEASE_DART_DEFINES[@]}"

echo
echo "iOS archive/IPA output is under:"
echo "  build/ios/archive"
echo "  build/ios/ipa"
