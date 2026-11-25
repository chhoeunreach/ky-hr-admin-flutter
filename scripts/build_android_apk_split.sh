#!/usr/bin/env bash
set -euo pipefail

# Builds one release APK per CPU architecture so each install only ships the
# native libraries it needs (Play Store / MDM distribution should prefer
# scripts/build_android_store.sh, which builds an App Bundle instead).
#
# Output (on success):
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#   build/app/outputs/flutter-apk/app-x86_64-release.apk

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
flutter build apk --release --split-per-abi "${RELEASE_DART_DEFINES[@]}"

echo
echo "Split release APKs:"
ls -lh build/app/outputs/flutter-apk/*-release.apk
