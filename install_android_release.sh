#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/android_device.sh
source "${SCRIPT_DIR}/scripts/android_device.sh"

APK_DIR="${SCRIPT_DIR}/build/app/outputs/flutter-apk"
APK="${APK_DIR}/app-arm64-v8a-release.apk"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android platform-tools or add them to PATH."
  exit 1
fi

if ! adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'; then
  print_no_android_device_help
  exit 1
fi

if [[ ! -f "${APK}" ]]; then
  echo "Release APK not found at:"
  echo "  ${APK}"
  echo ""
  echo "Build it first with:"
  echo "  ./build_production.sh"
  exit 1
fi

echo "Installing release APK on connected Android device..."
adb install -r "${APK}"
echo "Installed. Open Farm Tracker on your phone to test Google Sign-In."
