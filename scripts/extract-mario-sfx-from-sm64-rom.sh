#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.runtime/sm64-audio-extractor"
SRC="$RUNTIME/sm64coopdx"
DEST="$ROOT/assets_local/mario_sfx"
VERSION="${2:-us}"

declare -A EXPECTED_SHA1
EXPECTED_SHA1[us]="9bef1128717f958171a4afac3ed78ee2bb4e86ce"
EXPECTED_SHA1[jp]="8a20a5c83d6ceb0f0506cfc9fa20d8f438cafe51"
EXPECTED_SHA1[eu]="4ac5721683d0e0b6bbb561b58a71740845dceea9"
EXPECTED_SHA1[sh]="3f319ae697533a255a1003d09202379d78d5a2e0"

if [ -z "${EXPECTED_SHA1[$VERSION]+x}" ]; then
  echo "[NEXO] ERROR: unsupported SM64 version '$VERSION' (use us, jp, eu, or sh)."
  exit 1
fi

ROM="${1:-}"

if [ -z "$ROM" ]; then
  echo "[NEXO] No ROM path supplied; searching common local folders for a matching $VERSION .z64..."
  for base in "$ROOT" "$HOME/Documents" "$HOME/Downloads"; do
    [ -d "$base" ] || continue
    while IFS= read -r candidate; do
      hash="$(shasum -a 1 "$candidate" | awk '{print $1}')"
      if [ "$hash" = "${EXPECTED_SHA1[$VERSION]}" ]; then
        ROM="$candidate"
        break 2
      fi
    done < <(find "$base" -maxdepth 3 -type f -iname '*.z64' 2>/dev/null)
  done
fi

if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
  echo "[NEXO] ERROR: no matching SM64 ROM found."
  echo "Usage:"
  echo "  bash scripts/extract-mario-sfx-from-sm64-rom.sh /path/to/your/own/baserom.us.z64 us"
  exit 1
fi

ROM_SHA1="$(shasum -a 1 "$ROM" | awk '{print $1}')"
if [ "$ROM_SHA1" != "${EXPECTED_SHA1[$VERSION]}" ]; then
  echo "[NEXO] ERROR: ROM hash does not match the known vanilla $VERSION ROM."
  echo "[NEXO] Found:    $ROM_SHA1"
  echo "[NEXO] Expected: ${EXPECTED_SHA1[$VERSION]}"
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
convert_sample "sound/samples/sfx_mario/0A_mario_attacked.aiff" "hurt"
convert_sample "sound/samples/sfx_mario_peach/03_mario_dying.aiff" "death"
convert_sample "sound/samples/sfx_mario/05_mario_uh.aiff" "use"

# Extra identity cues reserved for portal/campaign events.
convert_sample "sound/samples/sfx_mario/0C_mario_here_we_go.aiff" "portal"
convert_sample "sound/samples/sfx_mario/04_mario_yahoo.aiff" "celebrate"

echo
echo "[NEXO] Mario identity SFX extracted locally."
echo "[NEXO] Destination: $DEST"
echo "[NEXO] These files are gitignored and are never committed."
echo
echo "Launch DOOM with:"
echo "  python3 bridge/run_doom.py --runtime sdl"
