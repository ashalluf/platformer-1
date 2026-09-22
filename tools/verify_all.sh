#!/usr/bin/env bash
# Whole-project verification. Reimports once, then loads every scene in the
# game and reports which ones fail.
#
# This exists because the project is built by many hands at once and a single
# broken class_name takes every level with it. Run it before every commit.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== reimport"
xvfb-run -a godot --path . --headless --import 2>&1 \
  | grep -iE "^(ERROR|SCRIPT ERROR)" | head -20

SCENES=(
  res://levels/menu/TitleScreen.tscn
  res://levels/menu/WorldMap.tscn
  res://levels/menu/Collection.tscn
  res://levels/brega/Brega.tscn
  res://levels/brega/BregaBeauty.tscn
  res://levels/ajdabiya/Ajdabiya.tscn
  res://levels/ice/IceBonus01.tscn
  res://levels/ice/IceBonus02.tscn
  res://levels/ice/IceBonus03.tscn
  res://levels/greybox/Greybox.tscn
  res://levels/lab/MaterialShowcase.tscn
  res://levels/lab/CharacterShowcase.tscn
  res://levels/lab/EnemyShowcase.tscn
  # Last on purpose: it compiles every shader in res://shaders/, including
  # the ones no level has adopted yet. Nothing else in this list covers them,
  # and nothing short of a real Vulkan render compiles a shader at all.
  res://levels/lab/ShaderLab.tscn
)

fail=0
echo "=== scenes"
for s in "${SCENES[@]}"; do
  out="$(tools/check.sh "$s" 2>&1 | tail -1)"
  case "$out" in
    *CLEAN*) printf '  ok    %s\n' "$s" ;;
    *)       printf '  FAIL  %s\n' "$s"; fail=1 ;;
  esac
done

echo "=== scripts"
while IFS= read -r f; do
  # Autoload identifiers are always "not found" under --check-only; only a
  # genuine Parse Error means the file is broken.
  if godot --path . --headless --check-only --script "$f" 2>&1 | grep -q "Parse Error"; then
    printf '  FAIL  %s\n' "$f"
    godot --path . --headless --check-only --script "$f" 2>&1 | grep "Parse Error" | head -2 | sed 's/^/        /'
    fail=1
  fi
done < <(find scripts levels tools -name '*.gd' | sort)

if [ "$fail" -eq 0 ]; then
  echo "=== ALL CLEAN"
else
  echo "=== FAILURES ABOVE"
fi
exit "$fail"
