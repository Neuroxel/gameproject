#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SFX_DIR="$ROOT/assets_local/mario_sfx"
PK3="$ROOT/.runtime/doom/nexo_doom.pk3"
BUILD_LOG="$ROOT/bridge/runtime/mario-sfx-dry-run.log"

echo "[NEXO] Mario SFX deterministic diagnostic"
echo "[NEXO] Root: $ROOT"
echo

if [ ! -d "$SFX_DIR" ]; then
  echo "[NEXO] ERROR: local Mario SFX directory is missing: $SFX_DIR"
  exit 2
fi

echo "[NEXO] Rebuilding the local PK3 through the normal launcher path (dry-run only)..."
if python3 "$ROOT/bridge/run_doom.py" --runtime sdl --dry-run >"$BUILD_LOG" 2>&1; then
  echo "[NEXO] Dry-run PK3 build: PASS"
else
  echo "[NEXO] Dry-run PK3 build: FAILED"
  cat "$BUILD_LOG"
  exit 3
fi

python3 - "$ROOT" <<'PY'
from __future__ import annotations

import pathlib
import shlex
import struct
import sys
import zipfile

root = pathlib.Path(sys.argv[1])
sfx_dir = root / "assets_local" / "mario_sfx"
pk3 = root / ".runtime" / "doom" / "nexo_doom.pk3"
names = ("jump", "hurt", "death", "use", "portal", "celebrate")
exts = (".wav", ".ogg", ".flac")

def find_local(name: str):
    for ext in exts:
        p = sfx_dir / f"{name}{ext}"
        if p.exists():
            return p
    return None

def dmx_info(data: bytes):
    if len(data) < 8:
        return {"valid": False, "reason": "short DMX header"}
    fmt, rate, payload_len = struct.unpack_from("<HHI", data, 0)
    valid = fmt == 3 and rate > 0 and payload_len > 0 and payload_len <= len(data) - 8
    return {
        "valid": valid,
        "format": fmt,
        "rate": rate,
        "payload_len": payload_len,
        "file_payload": len(data) - 8,
    }

def wav_info(data: bytes):
    if len(data) < 12:
        return {"valid": False, "reason": "short header"}
    magic = data[:4]
    if magic not in (b"RIFF", b"RIFX") or data[8:12] != b"WAVE":
        return {"valid": False, "reason": f"not RIFF/RIFX WAVE ({data[:12]!r})"}

    endian = "<" if magic == b"RIFF" else ">"
    off = 12
    fmt = None
    data_bytes = None
    while off + 8 <= len(data):
        cid = data[off:off+4]
        size = struct.unpack(endian + "I", data[off+4:off+8])[0]
        payload = data[off+8:off+8+size]
        if cid == b"fmt " and len(payload) >= 16:
            tag, channels, rate, byte_rate, align, bits = struct.unpack(
                endian + "HHIIHH", payload[:16]
            )
            fmt = {
                "tag": tag,
                "channels": channels,
                "rate": rate,
                "byte_rate": byte_rate,
                "align": align,
                "bits": bits,
                "fmt_size": size,
                "endian": "LE" if endian == "<" else "BE",
            }
        elif cid == b"data":
            data_bytes = size
        off += 8 + size + (size & 1)

    if fmt is None:
        return {"valid": False, "reason": "fmt chunk missing"}
    fmt["valid"] = True
    fmt["data_bytes"] = data_bytes
    fmt["pcm16le"] = (
        magic == b"RIFF"
        and fmt["tag"] == 1
        and fmt["bits"] == 16
        and fmt["channels"] in (1, 2)
        and (data_bytes or 0) > 0
    )
    return fmt

print("[NEXO] Local assets")
local = {}
all_pcm16le = True
for name in names:
    p = find_local(name)
    local[name] = p
    if p is None:
        print(f"  {name:10s} MISSING")
        all_pcm16le = False
        continue
    data = p.read_bytes()
    signature = data[:12]
    print(f"  {name:10s} {p.name:20s} bytes={len(data):7d} sig={signature!r}")
    if p.suffix.lower() == ".wav":
        info = wav_info(data)
        if info.get("valid"):
            print(
                " " * 13
                + f"WAV tag={info['tag']} channels={info['channels']} "
                  f"rate={info['rate']} bits={info['bits']} endian={info['endian']} "
                  f"data={info['data_bytes']} pcm16le={int(info['pcm16le'])}"
            )
            all_pcm16le = all_pcm16le and bool(info["pcm16le"])
        else:
            print(" " * 13 + f"WAV INVALID: {info['reason']}")
            all_pcm16le = False
    else:
        all_pcm16le = False

print()
if not pk3.exists():
    print(f"[NEXO] ERROR: PK3 missing after dry-run: {pk3}")
    sys.exit(4)

with zipfile.ZipFile(pk3, "r") as zf:
    members = set(zf.namelist())
    bad = zf.testzip()
    print(f"[NEXO] PK3 integrity: {'PASS' if bad is None else 'FAIL at ' + bad}")
    if "SNDINFO" not in members:
        print("[NEXO] ERROR: SNDINFO missing from PK3")
        sys.exit(5)

    sndinfo = zf.read("SNDINFO").decode("utf-8", errors="replace")
    print("[NEXO] Generated SNDINFO:")
    for line in sndinfo.splitlines():
        print("  " + line)

    mappings = {}
    for raw in sndinfo.splitlines():
        line = raw.strip()
        if not line or line.startswith("$"):
            continue
        toks = shlex.split(line)
        if len(toks) >= 2:
            mappings[toks[0]] = toks[1]

    print()
    mapping_ok = True
    for name in names:
        logical = f"nexo/mario/{name}"
        target = mappings.get(logical)
        exists = target in members if target else False
        size = zf.getinfo(target).file_size if exists else -1
        extra = ""
        target_ok = exists and size > 0
        if exists and target and target.endswith(".dmx"):
            info = dmx_info(zf.read(target))
            extra = (
                f" dmx={int(info.get('valid', False))}"
                f" rate={info.get('rate', 0)}"
                f" payload={info.get('payload_len', 0)}"
            )
            target_ok = target_ok and bool(info.get("valid"))
        print(
            f"[NEXO] map {logical:24s} -> {str(target):34s} "
            f"member={int(exists)} bytes={size}{extra}"
        )
        mapping_ok = mapping_ok and target_ok

print()
print(f"[NEXO] RESULT mapping_and_members={'PASS' if mapping_ok else 'FAIL'}")
print(f"[NEXO] RESULT all_six_pcm16le={'PASS' if all_pcm16le else 'NO'}")
print("[NEXO] Interpretation:")
print("  - local PCM16LE proves source extraction is valid.")
print("  - generated .dmx entries bypass ZMusic/libsndfile and use GZDoom's native raw path.")
print("  - mapping PASS + dmx=1 + runtime S_GetLength>0 => AUDIO-ID-2 decoder bypass works.")
print("  - mapping PASS + dmx=1 + S_GetLength=0 => investigate native DMX/OpenAL load path.")
PY

echo
echo "[NEXO] Last Mario SFX runtime lines (if a run exists):"
if [ -f "$ROOT/bridge/runtime/doom.log" ]; then
  grep -E '\[NEXO\] Mario SFX (resource|probe)|Mario portal cue' "$ROOT/bridge/runtime/doom.log" || true
else
  echo "  no bridge/runtime/doom.log yet"
fi

echo
echo "[NEXO] Diagnostic complete."
