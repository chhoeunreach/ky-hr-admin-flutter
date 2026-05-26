#!/bin/bash

set -euo pipefail

PROJECT_TAG="hrky-flutter"
DEVICE_ID="${1:-R3CM903EZ1Y}"

echo "Stopping existing Flutter runs for ${PROJECT_TAG}..."
pkill -f "flutter_tools.snapshot run.*${PROJECT_TAG}" 2>/dev/null || true
pkill -f "frontend_server_aot.dart.snapshot.*${PROJECT_TAG}" 2>/dev/null || true

echo "Clearing generated Flutter caches..."
rm -rf .dart_tool build
flutter clean

echo "Restoring dependencies..."
flutter pub get

echo "Refreshing adb..."
adb kill-server
adb start-server

echo "Starting Flutter on device ${DEVICE_ID}..."
exec flutter run -d "${DEVICE_ID}"
