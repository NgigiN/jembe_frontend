#!/bin/bash
set -euo pipefail

ENV_FLAGS="--dart-define=ENV=production"
SPLIT_INFO_DIR="build/split-info"

echo "Building Flutter app for PRODUCTION..."
mkdir -p "${SPLIT_INFO_DIR}"

echo "Building Android App Bundle with shrinking & debug-info splits..."
flutter build appbundle \
  ${ENV_FLAGS} \
  --release \
  --obfuscate \
  --split-debug-info="${SPLIT_INFO_DIR}" \
  --tree-shake-icons

echo "Building per-ABI APKs with shrinking..."
flutter build apk \
  ${ENV_FLAGS} \
  --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info="${SPLIT_INFO_DIR}" \
  --tree-shake-icons

echo "Production builds completed! Outputs are in build/app/outputs/."
