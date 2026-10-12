#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.runtime/doom/gzdoom-sdl"
SRC="$RUNTIME/src"
BUILD="$RUNTIME/build"
PATCH_DIR="$ROOT/patches/gzdoom-g4.14.2-sdl-gamecontroller"
TAG="g4.14.2"
ZMUSIC_VERSION="1.1.14"
ZMUSIC_PACKAGE="zmusic-${ZMUSIC_VERSION}-macos-arm.tar.xz"
ZMUSIC_URL="https://github.com/coelckers/gzdoom/releases/download/ci_deps/${ZMUSIC_PACKAGE}"

echo "[NEXO] Preparing GZDoom $TAG with SDL2 backend for macOS..."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[NEXO] ERROR: Xcode Command Line Tools are required."
  echo "Run: xcode-select --install"
  exit 1
fi

# Do not upgrade the user's Homebrew installation. The previous version of this
# script used one broad 'brew install' which caused Homebrew to upgrade existing
# formulae and unrelated dependents (ffmpeg, etc.), making a transient ghcr.io
# outage block this build. Install only a dependency that is demonstrably absent.
install_formula() {
  local formula="$1"
  if ! command -v brew >/dev/null 2>&1; then
    echo "[NEXO] ERROR: missing dependency '$formula' and Homebrew is unavailable."
    echo "Install Homebrew from https://brew.sh and rerun this script."
    exit 1
  fi
  echo "[NEXO] Installing missing dependency: $formula"
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 \
    brew install "$formula"
}

if command -v cmake >/dev/null 2>&1; then
  echo "[NEXO] Dependency already present: cmake ($(cmake --version | head -n 1))"
else
  install_formula cmake
fi

if command -v ninja >/dev/null 2>&1; then
  echo "[NEXO] Dependency already present: ninja ($(ninja --version))"
else
  install_formula ninja
fi

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists sdl2; then
  echo "[NEXO] Dependency already present: SDL2 ($(pkg-config --modversion sdl2))"
elif [ -e "/opt/homebrew/lib/libSDL2.dylib" ] || [ -e "/usr/local/lib/libSDL2.dylib" ]; then
  echo "[NEXO] Dependency already present: SDL2 library"
else
  install_formula sdl2
fi

if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists vpx; then
  echo "[NEXO] Dependency already present: libvpx ($(pkg-config --modversion vpx))"
elif [ -e "/opt/homebrew/lib/libvpx.dylib" ] || [ -e "/usr/local/lib/libvpx.dylib" ]; then
  echo "[NEXO] Dependency already present: libvpx library"
else
  install_formula libvpx
fi

mkdir -p "$RUNTIME"

if [ ! -d "$SRC/.git" ]; then
  rm -rf "$SRC"
  echo "[NEXO] Cloning GZDoom $TAG with submodules..."
  git clone \
    --branch "$TAG" \
    --depth 1 \
    --recurse-submodules \
    https://github.com/ZDoom/gzdoom.git \
    "$SRC"
else
  echo "[NEXO] Reusing existing GZDoom source checkout."
fi

if [ -f "$PATCH_DIR/i_joystick.cpp" ] && [ -f "$PATCH_DIR/i_input.cpp" ]; then
  echo "[NEXO] Applying canonical SDL GameController backport before build..."
  cp "$PATCH_DIR/i_joystick.cpp" "$SRC/src/common/platform/posix/sdl/i_joystick.cpp"
  cp "$PATCH_DIR/i_input.cpp" "$SRC/src/common/platform/posix/sdl/i_input.cpp"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

# GZDoom 4.14.2 does not build its bundled ZMusic as part of the normal
# non-Windows build. Its own CI downloads the matching prebuilt ZMusic package
# and points CMake at it. Mirror that exact upstream path here.
echo "[NEXO] Fetching GZDoom CI ZMusic dependency: $ZMUSIC_PACKAGE"
curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 2 \
  --connect-timeout 15 \
  --output "$BUILD/$ZMUSIC_PACKAGE" \
  "$ZMUSIC_URL"

echo "[NEXO] Extracting ZMusic..."
tar -xf "$BUILD/$ZMUSIC_PACKAGE" -C "$BUILD"

if [ ! -d "$BUILD/zmusic" ]; then
  echo "[NEXO] ERROR: expected ZMusic directory was not created: $BUILD/zmusic"
  echo "[NEXO] Archive contents:"
  tar -tf "$BUILD/$ZMUSIC_PACKAGE" | head -n 50 || true
  exit 1
fi

echo "[NEXO] Configuring SDL2 backend (Cocoa backend OFF)..."
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

echo "[NEXO] Building with $CPU_COUNT jobs..."
cmake --build "$BUILD" --parallel "$CPU_COUNT"

GZ_BIN=""
for candidate in \
  "$BUILD/gzdoom" \
  "$BUILD/Release/gzdoom" \
  "$BUILD/gzdoom.app/Contents/MacOS/gzdoom" \
  "$BUILD/GZDoom.app/Contents/MacOS/gzdoom"
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

# Bundle the ZMusic runtime dependency next to the executable. GZDoom on macOS
# links it as @rpath/libzmusic.1.dylib and already includes @executable_path in
# its rpath. The upstream CI dependency package is sufficient for linking but
# the locally generated app bundle does not copy the versioned dylib for us.
GZ_DIR="$(dirname "$GZ_BIN")"
ZMUSIC_BASE="$BUILD/zmusic/lib/libzmusic.dylib"
ZMUSIC_SONAME="$GZ_DIR/libzmusic.1.dylib"

if [ ! -e "$ZMUSIC_BASE" ]; then
  echo "[NEXO] ERROR: linked ZMusic library disappeared after build:"
  echo "  $ZMUSIC_BASE"
  ls -la "$BUILD/zmusic/lib" 2>/dev/null || true
  exit 1
fi

echo "[NEXO] Bundling libzmusic.1.dylib into the app runtime..."
cp -L "$ZMUSIC_BASE" "$ZMUSIC_SONAME"
chmod 755 "$ZMUSIC_SONAME"

if command -v install_name_tool >/dev/null 2>&1; then
  install_name_tool -id "@rpath/libzmusic.1.dylib" "$ZMUSIC_SONAME" || true
fi

if [ ! -f "$ZMUSIC_SONAME" ]; then
  echo "[NEXO] ERROR: failed to bundle ZMusic runtime dependency."
  exit 1
fi

echo "[NEXO] Preparing project-local OpenAL Soft runtime..."
bash "$ROOT/scripts/setup-openal-soft-macos.sh"
bash "$ROOT/scripts/repair-gzdoom-sdl-macos.sh"

echo
echo "[NEXO] SDL2 GZDoom ready."
echo "[NEXO] Executable: $GZ_BIN"
echo
echo "Test controller detection with:"
echo "python3 bridge/run_doom.py --runtime sdl --controller-setup"
