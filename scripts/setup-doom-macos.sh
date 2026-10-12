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

for cmd in curl unzip find; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[NEXO] ERROR: falta el comando requerido: $cmd"
    exit 1
  fi
done

mkdir -p "$GZ_DIR" "$FD_DIR"

find_gz_app() {
  find "$GZ_DIR" -name "GZDoom.app" -type d -print -quit 2>/dev/null || true
}

find_fd_wad() {
  find "$FD_DIR" -name "freedoom2.wad" -type f -print -quit 2>/dev/null || true
}

GZ_APP="$(find_gz_app)"
if [ -z "$GZ_APP" ]; then
  echo "[NEXO] Descargando GZDoom $GZ_TAG para macOS..."
  curl --fail --location --show-error "$GZ_URL" -o "$RUNTIME/$GZ_ZIP"

  echo "[NEXO] Verificando archivo GZDoom..."
  unzip -tq "$RUNTIME/$GZ_ZIP" >/dev/null

  rm -rf "$GZ_DIR"
  mkdir -p "$GZ_DIR"
  unzip -q "$RUNTIME/$GZ_ZIP" -d "$GZ_DIR"
  GZ_APP="$(find_gz_app)"
fi

FD_WAD="$(find_fd_wad)"
if [ -z "$FD_WAD" ]; then
  echo "[NEXO] Descargando Freedoom $FD_TAG..."
  curl --fail --location --show-error "$FD_URL" -o "$RUNTIME/$FD_ZIP"

  echo "[NEXO] Verificando archivo Freedoom..."
  unzip -tq "$RUNTIME/$FD_ZIP" >/dev/null

  rm -rf "$FD_DIR"
  mkdir -p "$FD_DIR"
  unzip -q "$RUNTIME/$FD_ZIP" -d "$FD_DIR"
  FD_WAD="$(find_fd_wad)"
fi

if [ -z "$GZ_APP" ]; then
  echo "[NEXO] ERROR: no se encontró GZDoom.app tras extraer el release."
  exit 1
fi

GZ_BIN="$GZ_APP/Contents/MacOS/gzdoom"
if [ ! -f "$GZ_BIN" ]; then
  echo "[NEXO] ERROR: no se encontró el ejecutable esperado:"
  echo "  $GZ_BIN"
  exit 1
fi

if [ ! -x "$GZ_BIN" ]; then
  chmod +x "$GZ_BIN"
fi

if [ -z "$FD_WAD" ] || [ ! -f "$FD_WAD" ]; then
  echo "[NEXO] ERROR: no se encontró freedoom2.wad tras extraer el release."
  exit 1
fi

echo
echo "[NEXO] DOOM runtime preparado."
echo "[NEXO] GZDoom app: $GZ_APP"
echo "[NEXO] GZDoom bin: $GZ_BIN"
echo "[NEXO] IWAD legal de prueba: $FD_WAD"
echo
echo "Siguiente paso:"
echo "python3 bridge/run_doom.py --dry-run"
echo "python3 bridge/run_doom.py"
echo
echo "Si macOS llegara a bloquear GZDoom:"
echo "Ajustes del Sistema > Privacidad y seguridad > Abrir de todos modos."
