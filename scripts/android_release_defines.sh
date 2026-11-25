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
  local missing=()
  [[ "${KY_API_BASE_URL:-}" == https://* ]] || missing+=("KY_API_BASE_URL (https origin)")
  [[ -n "${KY_SECURITY_PINNED_HOSTS:-}" ]] || missing+=("KY_SECURITY_PINNED_HOSTS")
  [[ "${KY_SECURITY_SPKI_PINS:-}" == sha256/*,sha256/* ]] || missing+=("KY_SECURITY_SPKI_PINS (sha256/<a>,sha256/<b>)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing release security defines:" >&2
    for value in "${missing[@]}"; do
      echo "  - $value" >&2
    done
    echo >&2
    echo "Export them in the release environment (see docs/app-security/deployment-guide.md)." >&2
    return 1
  fi

  RELEASE_DART_DEFINES=(
    --dart-define=KY_SECURITY_PINNING_ENABLED=true
    --dart-define="KY_API_BASE_URL=${KY_API_BASE_URL}"
    --dart-define="KY_SECURITY_PINNED_HOSTS=${KY_SECURITY_PINNED_HOSTS}"
    --dart-define="KY_SECURITY_SPKI_PINS=${KY_SECURITY_SPKI_PINS}"
  )
}
