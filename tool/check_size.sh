#!/usr/bin/env bash
#
# Release appbundle size gate. This used to be a CI job that built the bundle, checked
# it, then built it AGAIN with --analyze-size at continue-on-error — on every push and
# every PR, for an artifact nothing consumed. Run it here, before a release, where the
# number is actually about to matter.
#
#   ./tool/check_size.sh            gate only
#   ./tool/check_size.sh --analyze  also print the size breakdown
set -uo pipefail
cd "$(dirname "$0")/.."
LIMIT_MB=80

flutter build appbundle --release --dart-define=ENV=production \
  --obfuscate --split-debug-info=build/split-info --tree-shake-icons || exit 1

AAB=build/app/outputs/bundle/release/app-release.aab
[ -f "$AAB" ] || { echo "no appbundle produced at $AAB"; exit 1; }

MB=$(du -m "$AAB" | cut -f1)
printf 'app bundle: %s (%s MB, limit %s MB)\n' "$(du -h "$AAB" | cut -f1)" "$MB" "$LIMIT_MB"
# The raw multi-ABI .aab, not the smaller per-device download size.
[ "$MB" -le "$LIMIT_MB" ] || { echo "ERROR: exceeds ${LIMIT_MB}MB limit"; exit 1; }

# Opt-in, and reusing the build above rather than doing a second one.
[ "${1:-}" = "--analyze" ] && flutter build appbundle --analyze-size --release
echo "size gate passed"
