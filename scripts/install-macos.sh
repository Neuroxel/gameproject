#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$REPO_ROOT/sm64coopdx/NexoMashupA"
MODS_DIR="$HOME/Library/Application Support/sm64coopdx/mods"
TARGET="$MODS_DIR/NexoMashupA"

if [ ! -f "$SOURCE/main.lua" ]; then
  echo "[NEXO] ERROR: no se encontró $SOURCE/main.lua"
  exit 1
fi

mkdir -p "$MODS_DIR"
rm -rf "$TARGET"
cp -R "$SOURCE" "$TARGET"

echo "[NEXO] Gate A0 instalado."
echo "[NEXO] Destino: $TARGET"
echo "[NEXO] Archivo: $TARGET/main.lua"
echo
echo "Siguiente paso:"
echo "1. Abre SM64CoopDX."
echo "2. Entra al panel Mods."
echo "3. Habilita 'NEXO Mashup A' si no está habilitado."
echo "4. Entra al juego."
echo "5. Comprueba que aparezca 'NEXO MASHUP LAB' y 'GATE A0 PASS'."
