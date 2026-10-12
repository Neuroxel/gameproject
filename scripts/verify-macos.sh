#!/bin/bash
set -euo pipefail

TARGET="$HOME/Library/Application Support/sm64coopdx/mods/NexoMashupA/main.lua"

if [ -f "$TARGET" ]; then
  echo "[NEXO] PASS: main.lua está instalado en:"
  echo "$TARGET"
  echo
  shasum -a 256 "$TARGET"
else
  echo "[NEXO] FAIL: no se encontró:"
  echo "$TARGET"
  exit 1
fi
