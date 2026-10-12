#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.runtime/doom/gzdoom-sdl"
SRC="$RUNTIME/src"
BUILD="$RUNTIME/build"
TAG="g4.14.2"

echo "[NEXO] Preparing GZDoom $TAG with SDL2 backend for macOS..."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[NEXO] ERROR: Xcode Command Line Tools are required."
  echo "Run: xcode-select --install"
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[NEXO] ERROR: Homebrew is required for the SDL2 build dependencies."
  echo "Install Homebrew from https://brew.sh and rerun this script."
  exit 1
fi

echo "[NEXO] Installing/verifying build dependencies..."
brew install cmake ninja sdl2 libvpx molten-vk vulkan-volk || true

mkdir -p "$RUNTIME"

if [ ! -d "$SRC/.git" ]; then
  rm -rf "$SRC"
  echo "[NEXO] Cloning GZDoom $TAG with submodules..."
  git clone     --branch "$TAG"     --depth 1     --recurse-submodules     https://github.com/ZDoom/gzdoom.git     "$SRC"
else
  echo "[NEXO] Reusing existing GZDoom source checkout."
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "[NEXO] Configuring SDL2 backend (Cocoa backend OFF)..."
cmake   -S "$SRC"   -B "$BUILD"   -G Ninja   -DCMAKE_BUILD_TYPE=Release   -DOSX_COCOA_BACKEND=OFF

CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

echo "[NEXO] Building with $CPU_COUNT jobs..."
cmake --build "$BUILD" --parallel "$CPU_COUNT"

GZ_BIN=""
for candidate in   "$BUILD/gzdoom"   "$BUILD/Release/gzdoom"
do
  if [ -x "$candidate" ]; then
    GZ_BIN="$candidate"
    break
  fi
done

if [ -z "$GZ_BIN" ]; then
  GZ_BIN="$(find "$BUILD" -type f -name gzdoom -perm -111 -print -quit 2>/dev/null || true)"
fi

if [ -z "$GZ_BIN" ]; then
  echo "[NEXO] ERROR: build completed but no gzdoom executable was found."
  exit 1
fi

echo
echo "[NEXO] SDL2 GZDoom ready."
echo "[NEXO] Executable: $GZ_BIN"
echo
echo "Test controller detection with:"
echo "python3 bridge/run_doom.py --runtime sdl --controller-setup"
