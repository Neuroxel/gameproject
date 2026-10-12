#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.runtime/doom/gzdoom-sdl/build"
GZ_BIN="$BUILD/gzdoom.app/Contents/MacOS/gzdoom"
GZ_DIR="$(dirname "$GZ_BIN")"
ZMUSIC_DIR="$BUILD/zmusic/lib"
ZMUSIC_BASE="$ZMUSIC_DIR/libzmusic.dylib"
ZMUSIC_SONAME="$GZ_DIR/libzmusic.1.dylib"

if [ ! -x "$GZ_BIN" ]; then
  echo "[NEXO] ERROR: SDL GZDoom executable not found:"
  echo "  $GZ_BIN"
  exit 1
fi

if [ ! -e "$ZMUSIC_BASE" ]; then
  echo "[NEXO] ERROR: ZMusic base library not found:"
  echo "  $ZMUSIC_BASE"
  echo "[NEXO] ZMusic directory contents:"
  ls -la "$ZMUSIC_DIR" 2>/dev/null || true
  exit 1
fi

echo "[NEXO] Repairing SDL GZDoom runtime packaging..."
echo "[NEXO] Source ZMusic: $ZMUSIC_BASE"

# GZDoom links against @rpath/libzmusic.1.dylib on macOS. The CI dependency
# package exposes libzmusic.dylib to CMake, but our locally built app bundle does
# not automatically receive the versioned runtime name. Copy the resolved dylib
# into @executable_path, which GZDoom already includes in its rpath.
cp -L "$ZMUSIC_BASE" "$ZMUSIC_SONAME"
chmod 755 "$ZMUSIC_SONAME"

if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -id "@rpath/libzmusic.1.dylib" "$ZMUSIC_SONAME" || true
fi

echo "[NEXO] Runtime dependency now present:"
ls -l "$ZMUSIC_SONAME"

echo
echo "[NEXO] GZDoom dependency reference:"
otool -L "$GZ_BIN" | grep -E "zmusic|gzdoom" || true

echo
echo "[NEXO] Bundled ZMusic dependencies:"
otool -L "$ZMUSIC_SONAME" || true

# Reuse the proven-working OpenAL runtime from the official GZDoom package
# when it is bundled there. This is optional for the controller test, but it
# restores audio without rebuilding the SDL executable.
COCOA_MACOS="$ROOT/.runtime/doom/gzdoom/GZDoom.app/Contents/MacOS"
OPENAL_SRC=""
if [ -d "$COCOA_MACOS" ]; then
  OPENAL_SRC="$(find "$COCOA_MACOS" -maxdepth 1 \( -name 'libopenal.1.dylib' -o -name 'libopenal.dylib' \) -print -quit 2>/dev/null || true)"
fi

if [ -n "$OPENAL_SRC" ]; then
  echo
  echo "[NEXO] Found working OpenAL runtime in official Cocoa package:"
  echo "  $OPENAL_SRC"
  cp -L "$OPENAL_SRC" "$GZ_DIR/libopenal.1.dylib"
  chmod 755 "$GZ_DIR/libopenal.1.dylib"
  if command -v install_name_tool >/dev/null 2>&1; then
    install_name_tool -id "@rpath/libopenal.1.dylib" "$GZ_DIR/libopenal.1.dylib" || true
  fi
  echo "[NEXO] OpenAL runtime bundled for SDL."
else
  echo
  echo "[NEXO] NOTE: no bundled libopenal*.dylib found in official runtime."
  echo "[NEXO] Controller/video testing can continue; audio may remain disabled."
fi

echo
echo "[NEXO] Repair complete."
echo "Test with:"
echo "python3 bridge/run_doom.py --runtime sdl --controller-setup"
