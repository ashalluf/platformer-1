#!/usr/bin/env bash
# Parse-check every script in the project. Seconds, no render, no display.
#
# This exists because tools/check.sh boots ONE scene (Greybox by default), so a
# parse error in any level it does not load passes clean — which is exactly how
# a broken Ajdabiya.gd got as far as a three-minute capture run. Run this after
# every edit; run tools/verify_all.sh before every commit.
#
# Autoload identifiers (Gx, FX, Audio, ...) are always reported as not-found
# under --check-only because autoloads are not registered for a bare script
# run. Only "Parse Error" means the file is actually broken.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
while IFS= read -r f; do
  out="$(godot --path . --headless --check-only --script "$f" 2>&1 | grep "Parse Error")"
  if [ -n "$out" ]; then
    printf 'FAIL  %s\n' "$f"
    printf '%s\n' "$out" | head -3 | sed 's/^/      /'
    fail=1
  fi
done < <(find scripts levels tools -name '*.gd' | sort)

[ "$fail" -eq 0 ] && echo "PARSE CLEAN ($(find scripts levels tools -name '*.gd' | wc -l) scripts)"
exit "$fail"
