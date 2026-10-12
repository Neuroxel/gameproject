#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GZ="$ROOT/.runtime/doom/gzdoom-sdl/build/gzdoom.app/Contents/MacOS/gzdoom"
GZ_DIR="$(dirname "$GZ")"
OAL_ROOT="$ROOT/.runtime/doom/openal-soft/install"
OAL_LIB_DIR="$OAL_ROOT/lib"
OAL_INFO="$OAL_ROOT/bin/openal-info"
LOG="$ROOT/bridge/runtime/openal-soft.log"

echo "[NEXO] DOOM audio diagnostic"
echo

if [ ! -x "$GZ" ]; then
  echo "[FAIL] SDL GZDoom executable missing: $GZ"
  exit 1
fi

echo "[OK] GZDoom: $GZ"

if ls "$OAL_LIB_DIR"/libopenal*.dylib >/dev/null 2>&1; then
  echo "[OK] Project-local OpenAL Soft:"
  ls -l "$OAL_LIB_DIR"/libopenal*.dylib
else
  echo "[FAIL] No project-local libopenal dylib."
  echo "Run: bash scripts/setup-openal-soft-macos.sh"
fi

if [ -f "$GZ_DIR/libopenal.1.dylib" ]; then
  echo "[OK] Bundled app runtime: $GZ_DIR/libopenal.1.dylib"
  otool -L "$GZ_DIR/libopenal.1.dylib" || true
else
  echo "[WARN] App bundle has no libopenal.1.dylib yet."
fi

echo
echo "[NEXO] GZDoom compile/cache audio flags:"
grep -E 'DYN_OPENAL|NO_OPENAL|OPENAL_(INCLUDE|LIBRARY)' "$ROOT/.runtime/doom/gzdoom-sdl/build/CMakeCache.txt" 2>/dev/null || true

if [ -x "$OAL_INFO" ]; then
  echo
  echo "[NEXO] Direct OpenAL Soft/CoreAudio probe:"
  set +e
  DYLD_LIBRARY_PATH="$OAL_LIB_DIR:$GZ_DIR" \
  ALSOFT_DRIVERS=core \
  ALSOFT_LOGLEVEL=3 \
  "$OAL_INFO" 2>&1 | head -n 160
  RC=${PIPESTATUS[0]}
  set -e
  echo "[NEXO] openal-info exit code: $RC"
fi

if [ -f "$LOG" ]; then
  echo
  echo "[NEXO] Last OpenAL Soft runtime log:"
  tail -n 120 "$LOG"
else
  echo
  echo "[NEXO] No GZDoom OpenAL log yet: $LOG"
fi
