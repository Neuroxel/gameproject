#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[NEXO] Avatar local pipeline — FP hands v4 + full-body source/preview"
echo

python3 -m py_compile   bridge/run_doom.py   scripts/render-mario-weapon-hands-local.py   scripts/extract-mario-body-parts-from-sm64-rom.py   scripts/render-mario-body-preview-local.py

echo
echo "[NEXO] Rendering FP-MARIO v4 hands..."
python3 scripts/render-mario-weapon-hands-local.py --activate

echo
echo "[NEXO] Extracting AVATAR-BODY-1 local geometry..."
python3 scripts/extract-mario-body-parts-from-sm64-rom.py "$@"

echo
echo "[NEXO] Rendering AVATAR-BODY-2 neutral/portal/death previews..."
python3 scripts/render-mario-body-preview-local.py

echo
echo "[NEXO] Local avatar preparation complete."
echo "[NEXO] First-person hand READY: assets_local/mario_hands/READY"
echo "[NEXO] Full-body runtime READY remains intentionally OFF."
echo "[NEXO] Body previews: assets_local/mario_avatar/body_{neutral,portal,death}_preview.png"
echo
echo "[NEXO] Launch DOOM separately with:"
echo "  python3 bridge/run_doom.py --runtime sdl"
