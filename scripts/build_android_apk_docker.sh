#!/usr/bin/env bash
set -euo pipefail

# Builds an Android APK using Flutter inside Docker to avoid local Flutter/Dart issues.
#
# Output (on success):
#   build/app/outputs/flutter-apk/app-release.apk

IMAGE_DEFAULT="ghcr.io/cirruslabs/flutter:stable"
IMAGE="${FLUTTER_DOCKER_IMAGE:-$IMAGE_DEFAULT}"

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

echo "Using image: $IMAGE"
echo "Project dir: $project_dir"

docker pull "$IMAGE"

# Run as the host user to avoid root-owned files in the repo.
uid="$(id -u)"
gid="$(id -g)"

docker run --rm \
  -u "${uid}:${gid}" \
  -v "${project_dir}:/work" \
  -w /work \
  "$IMAGE" \
  bash -lc "flutter --version && flutter pub get && flutter build apk --release"

echo
echo "APK generated:"
echo "  ${project_dir}/build/app/outputs/flutter-apk/app-release.apk"

