#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.runtime/sm64-audio-extractor"
SRC="$RUNTIME/sm64coopdx"
DEST="$ROOT/assets_local/mario_sfx"
REQUESTED_VERSION="${2:-auto}"

expected_sha1() {
  case "$1" in
    us) echo "9bef1128717f958171a4afac3ed78ee2bb4e86ce" ;;
    jp) echo "8a20a5c83d6ceb0f0506cfc9fa20d8f438cafe51" ;;
    eu) echo "4ac5721683d0e0b6bbb561b58a71740845dceea9" ;;
    sh) echo "3f319ae697533a255a1003d09202379d78d5a2e0" ;;
    *) return 1 ;;
  esac
}

version_for_sha1() {
  case "$1" in
    9bef1128717f958171a4afac3ed78ee2bb4e86ce) echo "us" ;;
    8a20a5c83d6ceb0f0506cfc9fa20d8f438cafe51) echo "jp" ;;
    4ac5721683d0e0b6bbb561b58a71740845dceea9) echo "eu" ;;
    3f319ae697533a255a1003d09202379d78d5a2e0) echo "sh" ;;
    *) return 1 ;;
  esac
}

if [ "$REQUESTED_VERSION" != "auto" ] && ! expected_sha1 "$REQUESTED_VERSION" >/dev/null 2>&1; then
  echo "[NEXO] ERROR: unsupported SM64 version '$REQUESTED_VERSION' (use auto, us, jp, eu, or sh)."
  exit 1
fi

ROM="${1:-}"
VERSION=""

identify_rom() {
  local candidate="$1"
  local hash
  local detected

  [ -f "$candidate" ] || return 1
  hash="$(shasum -a 1 "$candidate" | awk '{print $1}')"
  detected="$(version_for_sha1 "$hash" 2>/dev/null || true)"
  [ -n "$detected" ] || return 1

  if [ "$REQUESTED_VERSION" != "auto" ] && [ "$detected" != "$REQUESTED_VERSION" ]; then
    return 1
  fi

  ROM="$candidate"
  VERSION="$detected"
  return 0
}

if [ -n "$ROM" ]; then
  if ! identify_rom "$ROM"; then
    echo "[NEXO] ERROR: supplied ROM is not a known vanilla SM64 ROM"
    echo "[NEXO] or it does not match requested region '$REQUESTED_VERSION'."
    exit 1
  fi
else
  echo "[NEXO] No ROM path supplied; searching common local folders for a known vanilla SM64 .z64..."
  for base in     "$ROOT"     "$HOME/Documents"     "$HOME/Downloads"     "$HOME/Library/Application Support/sm64coopdx"
  do
    [ -d "$base" ] || continue

    # macOS ships Bash 3.2 and BSD find; avoid associative arrays and
    # non-portable GNU find options such as -maxdepth.
    while IFS= read -r candidate; do
      if identify_rom "$candidate"; then
        break 2
      fi
    done < <(find "$base" -type f -iname '*.z64' 2>/dev/null)
  done
fi

if [ -z "$ROM" ] || [ -z "$VERSION" ]; then
  echo "[NEXO] ERROR: no known vanilla SM64 ROM was found."
  echo "Usage:"
  echo "  bash scripts/extract-mario-sfx-from-sm64-rom.sh /path/to/your/own/baserom.us.z64 us"
  echo
  echo "The script supports US, JP, EU and Shindou vanilla ROM hashes."
  exit 1
fi

EXPECTED_SHA1="$(expected_sha1 "$VERSION")"
ROM_SHA1="$(shasum -a 1 "$ROM" | awk '{print $1}')"

echo "[NEXO] ROM: $ROM"
echo "[NEXO] Detected version: $VERSION"
echo "[NEXO] SHA-1: $ROM_SHA1"

if [ "$ROM_SHA1" != "$EXPECTED_SHA1" ]; then
  echo "[NEXO] ERROR: ROM hash validation changed unexpectedly."
  exit 1
fi

for cmd in git python3 make afconvert; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[NEXO] ERROR: missing required command: $cmd"
    exit 1
  fi
done

mkdir -p "$RUNTIME" "$DEST"

if [ ! -d "$SRC/.git" ]; then
  echo "[NEXO] Cloning open-source sm64coopdx extraction tools..."
  git clone --depth 1 https://github.com/coop-deluxe/sm64coopdx.git "$SRC"
else
  echo "[NEXO] Reusing existing sm64coopdx extraction checkout."
fi

BASEROM="$SRC/baserom.$VERSION.z64"
cleanup_rom_copy() {
  rm -f "$BASEROM"
}
trap cleanup_rom_copy EXIT
cp "$ROM" "$BASEROM"

echo "[NEXO] Extracting copyrighted audio locally from the user's own ROM..."
(
  cd "$SRC"
  python3 extract_assets.py "$VERSION"
)

convert_sample() {
  local source_rel="$1"
  local output_name="$2"
  local source="$SRC/$source_rel"
  local output="$DEST/$output_name.wav"

  if [ ! -f "$source" ]; then
    echo "[NEXO] ERROR: expected extracted sample not found:"
    echo "  $source"
    exit 1
  fi

  afconvert "$source" "$output" -f WAVE -d LEI16
  echo "[NEXO] Created $(basename "$output") <- $(basename "$source")"
}

# Core profile used by the DOOM adapter.
convert_sample "sound/samples/sfx_mario/00_mario_jump_hoo.aiff" "jump"

# Mario locomotion identity. These remain optional at runtime; generated
# SNDINFO falls back safely when an older local extraction only has the core set.
convert_sample "sound/samples/sfx_mario/01_mario_jump_wah.aiff" "jump2"
convert_sample "sound/samples/sfx_mario/02_mario_yah.aiff" "jump3"
convert_sample "sound/samples/sfx_mario/18_mario_waha.aiff" "backflip"
convert_sample "sound/samples/sfx_mario/19_mario_yippee.aiff" "longjump"
convert_sample "sound/samples/sfx_mario/0B_mario_ooof.aiff" "stomp"
convert_sample "sound/samples/sfx_mario/08_mario_whoa.aiff" "dive"
convert_sample "sound/samples/sfx_mario/0A_mario_attacked.aiff" "hurt"
convert_sample "sound/samples/sfx_mario_peach/03_mario_dying.aiff" "death"
convert_sample "sound/samples/sfx_mario/05_mario_uh.aiff" "use"

# Extra identity cues reserved for portal/campaign events.
convert_sample "sound/samples/sfx_mario/0C_mario_here_we_go.aiff" "portal"
convert_sample "sound/samples/sfx_mario/04_mario_yahoo.aiff" "celebrate"

echo
echo "[NEXO] Mario identity SFX extracted locally."
echo "[NEXO] Destination: $DEST"
echo "[NEXO] The temporary ROM copy was removed; only local extracted SFX remain."
echo "[NEXO] These files are gitignored and are never committed."
echo
echo "Launch DOOM with:"
echo "  python3 bridge/run_doom.py --runtime sdl"
