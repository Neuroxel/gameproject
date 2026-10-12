#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.runtime/doom/gzdoom-sdl/src"
BUILD="$ROOT/.runtime/doom/gzdoom-sdl/build"

if [ ! -d "$SRC/.git" ] || [ ! -d "$BUILD" ]; then
  echo "[NEXO] ERROR: SDL GZDoom source/build not found."
  echo "Run first: bash scripts/setup-gzdoom-sdl-macos.sh"
  exit 1
fi

echo "[NEXO] Applying upstream SDL startup-window fix to pinned GZDoom g4.14.2..."
python3 "$ROOT/scripts/apply-gzdoom-sdl-startup-source.py" "$SRC"

CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
echo "[NEXO] Incremental rebuild..."
cmake --build "$BUILD" --target gzdoom --parallel "$CPU_COUNT"

echo "[NEXO] Restoring runtime dylibs after relink..."
bash "$ROOT/scripts/repair-gzdoom-sdl-macos.sh"

echo
echo "[NEXO] SDL startup fix ready."
echo "Test with:"
echo "  python3 bridge/run_doom.py --runtime sdl"
