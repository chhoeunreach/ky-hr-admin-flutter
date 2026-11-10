#!/usr/bin/env bash
set -euo pipefail

task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$task_root"
php tool/sync_backend_server_config.php "${HR_BACKEND_PATH:-../hr-ky-admin}"
flutter build apk "$@"
