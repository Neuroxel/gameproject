#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/assets_local/mario_sfx"

if [ "$#" -ne 1 ]; then
  echo "Usage:"
  echo "  bash scripts/import-mario-sfx-local.sh /path/to/your/own/mario_sfx_folder"
  echo
  echo "Expected core filenames (one supported extension each):"
  echo "  jump.ogg|wav|flac"
  echo "  hurt.ogg|wav|flac"
  echo "  death.ogg|wav|flac"
  echo "  use.ogg|wav|flac"
  exit 1
fi

SRC="$1"
if [ ! -d "$SRC" ]; then
  echo "[NEXO] ERROR: source folder not found: $SRC"
  exit 1
fi

mkdir -p "$DEST"
rm -f "$DEST"/jump.* "$DEST"/hurt.* "$DEST"/death.* "$DEST"/use.*

missing=0
for name in jump hurt death use; do
  found=""
  for ext in ogg wav flac; do
    if [ -f "$SRC/$name.$ext" ]; then
      found="$SRC/$name.$ext"
      break
    fi
  done

  if [ -n "$found" ]; then
    cp "$found" "$DEST/"
    echo "[NEXO] Imported $name: $(basename "$found")"
  else
    echo "[NEXO] MISSING: $name.(ogg|wav|flac)"
    missing=1
  fi
done

echo
echo "[NEXO] Local destination: $DEST"
echo "[NEXO] This folder is gitignored and will not be committed."

if [ "$missing" -ne 0 ]; then
  echo "[NEXO] Core Mario identity audio is incomplete; DOOM hooks will stay disabled."
  exit 2
fi

echo "[NEXO] Core Mario identity audio ready."
echo "Launch with:"
echo "  python3 bridge/run_doom.py --runtime sdl"
