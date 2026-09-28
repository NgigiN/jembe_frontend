#!/usr/bin/env bash
#
# The local gate, run by the pre-push hook. Everything here used to run on a runner
# on every push and every PR into both branches.
#
#   ./tool/check.sh          analyze + test          (~1m)
#   ./tool/check.sh --web    + the web console build (~3m)
#
# The web build is the one check that catches a class of bug analyze and test cannot:
# a package:sqlite3 / dart:ffi import creeping back into lib/main_web.dart's dependency
# graph. analyze and test resolve web-only conditional exports to their VM-safe stub, so
# neither ever touches dart:ffi. Run it before any PR that changes imports.
set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=()
step() {
  local name="$1"; shift
  printf '\033[1m==> %s\033[0m\n' "$name"
  local start=$SECONDS
  if "$@"; then printf '    ok (%ss)\n\n' "$(( SECONDS - start ))"
  else printf '    \033[31mFAILED\033[0m (%ss)\n\n' "$(( SECONDS - start ))"; FAILED+=("$name"); fi
}

command -v flutter >/dev/null || { echo "flutter not on PATH"; exit 2; }

step "flutter pub get"   flutter pub get
step "dependency_validator" flutter pub run dependency_validator
step "flutter analyze"   flutter analyze --no-fatal-infos
step "flutter test"      flutter test

if [ "${1:-}" = "--web" ]; then
  step "build web console" flutter build web \
    -t lib/main_web.dart --release --dart-define=ENV=production --base-href=/console/
fi

echo "──────────────────────────────────────────"
if [ "${#FAILED[@]}" -gt 0 ]; then
  printf '  \033[31m%d check(s) failed:\033[0m %s\n' "${#FAILED[@]}" "${FAILED[*]}"
  exit 1
fi
printf '  \033[32mall checks passed\033[0m\n'
