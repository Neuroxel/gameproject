#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.runtime/doom/gzdoom-sdl/src"
BUILD="$ROOT/.runtime/doom/gzdoom-sdl/build"
PATCH_DIR="$ROOT/patches/gzdoom-g4.14.2-sdl-gamecontroller"

JOY_SRC="$SRC/src/common/platform/posix/sdl/i_joystick.cpp"
INPUT_SRC="$SRC/src/common/platform/posix/sdl/i_input.cpp"

if [ ! -d "$SRC/.git" ] || [ ! -d "$BUILD" ]; then
  echo "[NEXO] ERROR: SDL GZDoom source/build not found."
  echo "Run first: bash scripts/setup-gzdoom-sdl-macos.sh"
  exit 1
fi

echo "[NEXO] Applying standardized SDL GameController backport to GZDoom g4.14.2..."
cp "$PATCH_DIR/i_joystick.cpp" "$JOY_SRC"
cp "$PATCH_DIR/i_input.cpp" "$INPUT_SRC"

CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

echo "[NEXO] Incremental rebuild — only changed input objects and dependent link steps should rebuild."
cmake --build "$BUILD" --target gzdoom --parallel "$CPU_COUNT"

echo "[NEXO] Restoring runtime dylibs after relink..."
bash "$ROOT/scripts/repair-gzdoom-sdl-macos.sh"

echo
echo "[NEXO] SDL GameController backport ready."
echo "[NEXO] Important: mapped controllers now use a fresh Joy:GC:* config namespace,"
echo "[NEXO] so stale raw-axis mappings cannot override the standardized defaults."
echo
echo "Test with:"
echo "python3 bridge/run_doom.py --runtime sdl --controller-setup"
