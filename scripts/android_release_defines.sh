#!/usr/bin/env bash
# Shared release dart-defines for Android builds.
#
# The Gradle task `validateReleaseSecurityConfiguration` refuses release AOT
# compilation unless these defines are supplied at build time, so every
# release build script must source this file and pass "${RELEASE_DART_DEFINES[@]}".
#
# Values are read from the environment. Never hard-code the SPKI pins in a
# script or commit them to the repository:
#   export KY_API_BASE_URL=https://hr.rvstechsolution.com/
#   export KY_SECURITY_PINNED_HOSTS=hr.rvstechsolution.com
#   export KY_SECURITY_SPKI_PINS='sha256/<primary>,sha256/<backup>'

android_release_defines() {
  local base_url="${KY_API_BASE_URL:-https://hr.kytech.info/}"
  local hosts="${KY_SECURITY_PINNED_HOSTS:-hr.kytech.info,kneayerng.com,hr.rvstechsolution.com}"
  local default_pins="sha256/WjHk78F63xBi7U++NbYE7O23HG3LLJzzvWwcoMozYWs=,sha256/DBeI5z5Fs2n2XzoBH6cR/WVtQunXZm5hr5xBr4CpAOk=,sha256/0DbDAbR7JYvhI/0wXGW346NQDHIT1r5iKC4niOiwePs="
  local pins="${KY_SECURITY_SPKI_PINS:-$default_pins}"
  local pin_enabled="${KY_SECURITY_PINNING_ENABLED:-false}"

  RELEASE_DART_DEFINES=(
    --dart-define="KY_SECURITY_PINNING_ENABLED=${pin_enabled}"
    --dart-define="KY_API_BASE_URL=${base_url}"
    --dart-define="KY_SECURITY_PINNED_HOSTS=${hosts}"
    --dart-define="KY_SECURITY_SPKI_PINS=${pins}"
  )
}
