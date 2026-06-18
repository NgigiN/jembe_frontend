#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/android_device.sh
source "${SCRIPT_DIR}/scripts/android_device.sh"

echo "Running Flutter app on Android in PRODUCTION/REMOTE mode..."
require_android_device

flutter run --dart-define=ENV=production
