#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/android_device.sh
source "${SCRIPT_DIR}/scripts/android_device.sh"

echo "Running Flutter app on Android in LOCAL development mode..."
require_android_device

LOCAL_API_HOST="${LOCAL_API_HOST:-$(detect_local_api_host)}"
if [[ -z "${LOCAL_API_HOST}" ]]; then
  echo "Could not detect a LAN IP for the local backend."
  echo "Pass one manually, for example:"
  echo "  flutter run -d android --dart-define=ENV=local --dart-define=LOCAL_API_HOST=192.168.100.2"
  exit 1
fi

echo "Using local API host: http://${LOCAL_API_HOST}:8080"
echo "Ensure the backend is running and reachable on that address."

flutter run \
  --dart-define=ENV=local \
  --dart-define=LOCAL_API_HOST="${LOCAL_API_HOST}" 
