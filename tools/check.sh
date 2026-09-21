#!/usr/bin/env bash
# Fast script-error check: boot a scene for a few frames at minimum quality and
# report anything Godot pushed to stderr. Catches parse errors that
# `--headless --import` does not.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEVEL="${1:-res://levels/greybox/Greybox.tscn}"

OUT=$(cd "$ROOT" && timeout 300 tools/capture.sh --level="$LEVEL" --input=auto \
  --frames=90 --shots=89 --res=320x180 --quality=0 --warmup=2 --out=captures/_check 2>&1)

echo "$OUT" | grep -viE "ALSA|libpulse|audio|pcm|snd_|Condition \"status" \
  | grep -iE "SCRIPT ERROR|Parse Error|^ERROR|Invalid|Nonexistent|null value" && {
    echo "--- CHECK FAILED"; exit 1; }
echo "--- CHECK CLEAN ($LEVEL)"
