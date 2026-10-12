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

echo "[NEXO] Reconfiguring existing SDL build to use macOS OpenAL at link time..."
cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$BUILD/zmusic" \
  -DPK3_QUIET_ZIPDIR=ON \
  -DOSX_COCOA_BACKEND=OFF \
  -DDYN_OPENAL=OFF

CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

echo "[NEXO] Incremental audio rebuild..."
cmake --build "$BUILD" --target gzdoom --parallel "$CPU_COUNT"

echo "[NEXO] Restoring runtime dylibs after relink..."
bash "$ROOT/scripts/repair-gzdoom-sdl-macos.sh"

echo
echo "[NEXO] Audio runtime patch complete."
echo "Test:"
echo "  python3 bridge/run_doom.py --runtime sdl"
