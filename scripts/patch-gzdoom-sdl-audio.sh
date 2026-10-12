#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.runtime/doom/gzdoom-sdl/src"
BUILD="$ROOT/.runtime/doom/gzdoom-sdl/build"

if [ ! -d "$SRC/.git" ] || [ ! -d "$BUILD" ]; then
  echo "[NEXO] ERROR: existing SDL GZDoom build not found."
  echo "Run first: bash scripts/setup-gzdoom-sdl-macos.sh"
  exit 1
fi

echo "[NEXO] Building project-local OpenAL Soft first..."
bash "$ROOT/scripts/setup-openal-soft-macos.sh"

echo "[NEXO] Reconfiguring GZDoom to dynamically load project-local OpenAL Soft..."
cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$BUILD/zmusic" \
  -DPK3_QUIET_ZIPDIR=ON \
  -DOSX_COCOA_BACKEND=OFF \
  -DDYN_OPENAL=ON

CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

echo "[NEXO] Incremental GZDoom audio rebuild..."
cmake --build "$BUILD" --target gzdoom --parallel "$CPU_COUNT"

echo "[NEXO] Bundling runtime dylibs..."
bash "$ROOT/scripts/repair-gzdoom-sdl-macos.sh"

echo
echo "[NEXO] SDL audio runtime patch complete."
echo "Test:"
echo "  python3 bridge/run_doom.py --runtime sdl"
