#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties."
  echo "If this is a first Play Store release, run:"
  echo "  ./scripts/create_android_upload_keystore.sh"
  echo
  echo "If this app is already on Play Store, restore the existing upload keystore instead."
  exit 1
fi

source "$ROOT_DIR/scripts/android_release_defines.sh"
android_release_defines

flutter clean
flutter pub get
flutter build appbundle --release "${RELEASE_DART_DEFINES[@]}"

echo
echo "Play Store bundle:"
echo "  build/app/outputs/bundle/release/app-release.aab"
