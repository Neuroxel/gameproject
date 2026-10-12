#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.runtime/sm64-audio-extractor/sm64coopdx"
MODEL="$SRC/actors/mario/model.inc.c"
HEADER="$SRC/actors/mario/geo_header.h"
DEST="$ROOT/assets_local/mario_hands"

if [ ! -f "$MODEL" ] || [ ! -f "$HEADER" ]; then
  echo "[NEXO] Mario model checkout not found under:"
  echo "  $SRC"
  echo
  echo "Run the SM64 local extraction pipeline first."
  exit 2
fi

required=(
  mario_right_hand_closed
  mario_right_hand_open
  mario_left_hand_closed
  mario_left_hand_open
)

missing=0
for sym in "${required[@]}"; do
  if grep -q "$sym" "$MODEL" "$HEADER"; then
    echo "[NEXO] hand geometry source: FOUND $sym"
  else
    echo "[NEXO] hand geometry source: MISSING $sym"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "[NEXO] Mario first-person hand source probe: FAIL"
  exit 3
fi

mkdir -p "$DEST"

cat > "$DEST/SOURCE_READY.txt" <<'EOF'
NEXO Mario hand source geometry is present locally.

This is NOT the runtime READY marker.
A rendered weapon-grip pack still needs to be generated before
nexo_mario_hands_ready may become true.
EOF

echo
echo "[NEXO] Mario first-person hand source probe: PASS"
echo "[NEXO] Source marker: $DEST/SOURCE_READY.txt"
echo "[NEXO] Runtime READY remains intentionally absent."
echo "[NEXO] Next stage: render per-weapon transparent hand overlays."
