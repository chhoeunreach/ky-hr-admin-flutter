#!/usr/bin/env bash
# Shared release dart-defines for Android and iOS builds.
#
# Values are read from environment variables or fall back to verified production defaults:
#   KY_API_BASE_URL (defaults to https://hr.kytech.info/)
#   KY_SECURITY_PINNED_HOSTS (defaults to hr.kytech.info,kneayerng.com,hr.rvstechsolution.com)
#   KY_SECURITY_SPKI_PINS (defaults to live SHA-256 SPKI pins for production hosts)
#   KY_SECURITY_PINNING_ENABLED (defaults to true)

release_defines() {
  local base_url="${KY_API_BASE_URL:-https://hr.kytech.info/}"
  local hosts="${KY_SECURITY_PINNED_HOSTS:-hr.kytech.info,kneayerng.com,hr.rvstechsolution.com}"
  local default_pins="sha256/WjHk78F63xBi7U++NbYE7O23HG3LLJzzvWwcoMozYWs=,sha256/DBeI5z5Fs2n2XzoBH6cR/WVtQunXZm5hr5xBr4CpAOk=,sha256/0DbDAbR7JYvhI/0wXGW346NQDHIT1r5iKC4niOiwePs="
  local pins="${KY_SECURITY_SPKI_PINS:-$default_pins}"
  local pin_enabled="${KY_SECURITY_PINNING_ENABLED:-true}"

  RELEASE_DART_DEFINES=(
    --dart-define="KY_SECURITY_PINNING_ENABLED=${pin_enabled}"
    --dart-define="KY_API_BASE_URL=${base_url}"
    --dart-define="KY_SECURITY_PINNED_HOSTS=${hosts}"
    --dart-define="KY_SECURITY_SPKI_PINS=${pins}"
  )
}
