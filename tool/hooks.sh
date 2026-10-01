#!/usr/bin/env bash
# Run once per clone.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "core.hooksPath -> .githooks  (pre-push now runs tool/check.sh)"
echo "bypass a single push with: git push --no-verify"
