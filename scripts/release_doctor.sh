#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Flutter =="
flutter --version
flutter doctor -v

echo
echo "== Android release config =="
grep -n "compileSdkVersion\\|targetSdkVersion\\|applicationId" android/app/build.gradle
if [[ -f android/key.properties ]]; then
  echo "android/key.properties: present"
else
  echo "android/key.properties: missing"
fi

echo
echo "== iOS signing identities =="
security find-identity -v -p codesigning || true

echo
echo "== iOS plist =="
plutil -lint ios/Runner/Info.plist

echo
echo "== Dart analysis =="
flutter analyze
