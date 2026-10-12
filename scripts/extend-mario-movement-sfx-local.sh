#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.runtime/sm64-audio-extractor/sm64coopdx"
DEST="$ROOT/assets_local/mario_sfx"

if ! command -v afconvert >/dev/null 2>&1; then
  echo "[NEXO] ERROR: afconvert is required on macOS."
  exit 1
fi

if [ ! -d "$SRC/sound/samples" ]; then
  echo "[NEXO] Existing extracted SM64 samples were not found:"
  echo "  $SRC/sound/samples"
  echo
  echo "Run the full local extractor once with your own validated ROM:"
  echo "  bash scripts/extract-mario-sfx-from-sm64-rom.sh /path/to/baserom.us.z64 us"
  exit 2
fi

mkdir -p "$DEST"

convert_sample() {
  local source_rel="$1"
  local output_name="$2"
  local source="$SRC/$source_rel"
  local output="$DEST/$output_name.wav"

  if [ ! -f "$source" ]; then
    echo "[NEXO] ERROR: expected previously extracted sample missing:"
    echo "  $source"
    exit 3
  fi

  afconvert "$source" "$output" -f WAVE -d LEI16
  echo "[NEXO] Created $(basename "$output") <- $(basename "$source")"
}

# Canonical SM64 jump voice grammar.
# Jump 1 randomizes Yah/Wah/Hoo, jump 2 is Hoo-hoo, and jump 3 uses the
# Yahoo/Waha/Yippee pool (weighted in ZScript to match the source game).
convert_sample "sound/samples/sfx_mario/00_mario_jump_hoo.aiff" "jump1_hoo"
convert_sample "sound/samples/sfx_mario/01_mario_jump_wah.aiff" "jump1_wah"
convert_sample "sound/samples/sfx_mario/02_mario_yah.aiff" "jump1_yah"
convert_sample "sound/samples/sfx_mario/03_mario_haha.aiff" "jump2_hoohoo"
convert_sample "sound/samples/sfx_mario/04_mario_yahoo.aiff" "jump3_yahoo"
convert_sample "sound/samples/sfx_mario/18_mario_waha.aiff" "jump3_waha"
convert_sample "sound/samples/sfx_mario/19_mario_yippee.aiff" "jump3_yippee"

# Legacy logical cues remain generated for backward compatibility with older
# NEXO builds and non-triple movement actions.
convert_sample "sound/samples/sfx_mario/01_mario_jump_wah.aiff" "jump2"
convert_sample "sound/samples/sfx_mario/02_mario_yah.aiff" "jump3"
convert_sample "sound/samples/sfx_mario/18_mario_waha.aiff" "backflip"
convert_sample "sound/samples/sfx_mario/19_mario_yippee.aiff" "longjump"
convert_sample "sound/samples/sfx_mario/0B_mario_ooof.aiff" "stomp"
convert_sample "sound/samples/sfx_mario/08_mario_whoa.aiff" "dive"

echo
echo "[NEXO] Mario movement SFX extension: READY"
echo "[NEXO] Local-only destination: $DEST"
echo "[NEXO] No ROM or copyrighted sample was added to Git."
