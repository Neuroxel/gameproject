#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="$ROOT/.runtime/doom"
GZ_DIR="$RUNTIME/gzdoom"
FD_DIR="$RUNTIME/freedoom"

GZ_TAG="g4.14.2"
GZ_ZIP="gzdoom-4-14-2-macos.zip"
GZ_URL="https://github.com/ZDoom/gzdoom/releases/download/$GZ_TAG/$GZ_ZIP"

FD_TAG="v0.13.0"
FD_ZIP="freedoom-0.13.0.zip"
FD_URL="https://github.com/freedoom/freedoom/releases/download/$FD_TAG/$FD_ZIP"

mkdir -p "$GZ_DIR" "$FD_DIR"

if ! find "$GZ_DIR" -name "GZDoom.app" -maxdepth 3 -print -quit | grep -q .; then
  echo "[NEXO] Descargando GZDoom $GZ_TAG para macOS..."
  curl -fL "$GZ_URL" -o "$RUNTIME/$GZ_ZIP"
  rm -rf "$GZ_DIR"/*
  unzip -q "$RUNTIME/$GZ_ZIP" -d "$GZ_DIR"
fi

if ! find "$FD_DIR" -name "freedoom2.wad" -print -quit | grep -q .; then
  echo "[NEXO] Descargando Freedoom $FD_TAG..."
  curl -fL "$FD_URL" -o "$RUNTIME/$FD_ZIP"
  rm -rf "$FD_DIR"/*
  unzip -q "$RUNTIME/$FD_ZIP" -d "$FD_DIR"
fi

GZ_APP="$(find "$GZ_DIR" -name "GZDoom.app" -maxdepth 4 -print -quit)"
FD_WAD="$(find "$FD_DIR" -name "freedoom2.wad" -print -quit)"

if [ -z "$GZ_APP" ]; then
  echo "[NEXO] ERROR: no se encontró GZDoom.app"
  exit 1
fi

if [ -z "$FD_WAD" ]; then
  echo "[NEXO] ERROR: no se encontró freedoom2.wad"
  exit 1
fi

echo
echo "[NEXO] DOOM runtime preparado."
echo "[NEXO] GZDoom: $GZ_APP"
echo "[NEXO] IWAD legal de prueba: $FD_WAD"
echo
echo "Siguiente paso:"
echo "python3 bridge/run_doom.py --dry-run"
echo "python3 bridge/run_doom.py"
echo
echo "Si macOS bloquea GZDoom por seguridad, usa el flujo normal de"
echo "Ajustes del Sistema > Privacidad y seguridad > Abrir de todos modos."
