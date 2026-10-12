#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.runtime/doom/openal-soft"
SRC="$RUNTIME/src"
BUILD="$RUNTIME/build"
INSTALL="$RUNTIME/install"
TAG="1.25.2"

echo "[NEXO] Preparing OpenAL Soft $TAG for macOS/CoreAudio..."

for cmd in git cmake ninja xcrun; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[NEXO] ERROR: missing required command: $cmd"
    exit 1
  fi
done

mkdir -p "$RUNTIME"

if [ ! -d "$SRC/.git" ]; then
  echo "[NEXO] Cloning OpenAL Soft $TAG..."
  git clone --depth 1 --branch "$TAG" https://github.com/kcat/openal-soft.git "$SRC"
else
  echo "[NEXO] Reusing existing OpenAL Soft source checkout."
fi

# Do not inherit Homebrew LLVM from CC/CXX or PATH for this build.
# On this Mac, CMake selected /opt/homebrew/opt/llvm/bin/clang++ and its
# clang-scan-deps did not receive the Apple SDK system include paths. That made
# ordinary macOS headers such as pthread.h, Availability.h, sched.h and time.h
# appear to be missing. Use Apple's toolchain and an explicit macOS SDK.
APPLE_CC="/usr/bin/clang"
APPLE_CXX="/usr/bin/clang++"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

if [ ! -x "$APPLE_CC" ] || [ ! -x "$APPLE_CXX" ] || [ ! -d "$SDKROOT" ]; then
  echo "[NEXO] ERROR: Apple Clang/macOS SDK not available."
  echo "Run: xcode-select --install"
  exit 1
fi

echo "[NEXO] Apple compiler: $("$APPLE_CXX" --version | head -n 1)"
echo "[NEXO] macOS SDK: $SDKROOT"

# A CMake build directory cannot safely switch compilers in-place. The failed
# build was configured with Homebrew LLVM, so discard only OpenAL Soft's build
# cache/artifacts; the downloaded source checkout is preserved.
if [ -f "$BUILD/CMakeCache.txt" ]; then
  CACHED_CXX="$(grep '^CMAKE_CXX_COMPILER:FILEPATH=' "$BUILD/CMakeCache.txt" | cut -d= -f2- || true)"
  if [ "$CACHED_CXX" != "$APPLE_CXX" ]; then
    echo "[NEXO] Clearing stale OpenAL build cache from compiler: ${CACHED_CXX:-unknown}"
    rm -rf "$BUILD"
  fi
fi

mkdir -p "$BUILD"

env -u CC -u CXX cmake \
  -S "$SRC" \
  -B "$BUILD" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$APPLE_CC" \
  -DCMAKE_CXX_COMPILER="$APPLE_CXX" \
  -DCMAKE_OSX_SYSROOT="$SDKROOT" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_CXX_SCAN_FOR_MODULES=OFF \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DLIBTYPE=SHARED \
  -DALSOFT_UTILS=ON \
  -DALSOFT_EXAMPLES=OFF \
  -DALSOFT_TESTS=OFF \
  -DALSOFT_INSTALL_EXAMPLES=OFF \
  -DALSOFT_INSTALL_CONFIG=OFF

CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

echo "[NEXO] Building OpenAL Soft..."
cmake --build "$BUILD" --parallel "$CPU_COUNT"

echo "[NEXO] Installing OpenAL Soft into project runtime..."
cmake --install "$BUILD"

OPENAL_LIB="$(find "$INSTALL/lib" -maxdepth 1 -type f -name 'libopenal*.dylib' -print -quit 2>/dev/null || true)"
if [ -z "$OPENAL_LIB" ]; then
  OPENAL_LIB="$(find "$INSTALL/lib" -maxdepth 1 -type l -name 'libopenal*.dylib' -print -quit 2>/dev/null || true)"
fi

if [ -z "$OPENAL_LIB" ]; then
  echo "[NEXO] ERROR: OpenAL Soft built but no libopenal dylib was found."
  find "$INSTALL" -maxdepth 3 -type f -o -type l 2>/dev/null | head -n 80 || true
  exit 1
fi

echo "[NEXO] OpenAL Soft library: $OPENAL_LIB"
otool -L "$OPENAL_LIB" || true

OPENAL_INFO="$INSTALL/bin/openal-info"
if [ -x "$OPENAL_INFO" ]; then
  echo
  echo "[NEXO] CoreAudio/OpenAL device probe:"
  set +e
  DYLD_LIBRARY_PATH="$INSTALL/lib" ALSOFT_DRIVERS=core ALSOFT_LOGLEVEL=2 "$OPENAL_INFO" 2>&1 | head -n 100
  PROBE_RC=${PIPESTATUS[0]}
  set -e
  if [ "$PROBE_RC" -ne 0 ]; then
    echo "[NEXO] WARNING: openal-info returned $PROBE_RC. GZDoom test may provide more detail."
  fi
fi

echo
echo "[NEXO] OpenAL Soft runtime ready."
