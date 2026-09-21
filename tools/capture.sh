#!/usr/bin/env bash
# Capture harness wrapper.
#
#   tools/capture.sh --level=res://levels/greybox/Greybox.tscn --input=demo \
#                    --frames=900 --every=60 --out=captures/greybox
#
# Runs Godot under a virtual display with a fixed timestep so captures are
# deterministic regardless of how slow the renderer is.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
FPS="${CAPTURE_FPS:-60}"

exec xvfb-run -a "$GODOT" \
  --path "$ROOT" \
  --rendering-driver vulkan \
  --fixed-fps "$FPS" \
  -- --capture "$@"
