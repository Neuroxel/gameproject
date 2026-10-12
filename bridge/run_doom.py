#!/usr/bin/env python3
"""
NEXO Portal Fabric - DOOM launcher/adapter v0.2

Pipeline:
SM64CoopDX mod_storage -> handoff.json -> GZDoom command line -> NEXO DOOM PK3.

Robustness:
- First try to refresh handoff.json from SM64 storage.
- If refresh fails but a previously validated handoff.json exists, reuse it.
- Never modify SM64 saves during prototyping.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "bridge"
HANDOFF = BRIDGE / "runtime" / "handoff.json"
DOOM_LOG = BRIDGE / "runtime" / "doom.log"
MOD_SRC = ROOT / "doom" / "mod_src"
PK3 = ROOT / ".runtime" / "doom" / "nexo_doom.pk3"


def export_handoff() -> bool:
    cmd = [sys.executable, str(BRIDGE / "nexo_handoff.py")]
    proc = subprocess.run(cmd, text=True, capture_output=True)

    if proc.returncode == 0:
        if proc.stdout:
            print(proc.stdout, end="")
        return True

    if proc.stderr:
        print(proc.stderr, end="", file=sys.stderr)

    return False


def validate_handoff(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))

    if data.get("schema") != "nexo.portal.handoff.v1":
        raise RuntimeError("Unsupported handoff schema")

    target = data.get("target", {}).get("world")
    if target != "DOOM":
        raise RuntimeError(f"Handoff target is {target!r}, expected 'DOOM'")

    return data


def load_handoff() -> dict:
    refreshed = export_handoff()

    if refreshed:
        return validate_handoff(HANDOFF)

    if HANDOFF.exists():
        print(
            "[NEXO] WARNING: could not refresh from SM64 storage; "
            "using existing validated bridge/runtime/handoff.json."
        )
        return validate_handoff(HANDOFF)

    raise RuntimeError(
        "No current SM64 handoff and no cached handoff.json are available. "
        "Complete M1 and cross the NEXO Gate first."
    )


def build_pk3() -> Path:
    if not MOD_SRC.exists():
        raise FileNotFoundError(f"DOOM mod source missing: {MOD_SRC}")

    required = {
        "CVARINFO",
        "MAPINFO",
        "zscript.zc",
        "zscript/nexo_handoff.zs",
    }

    PK3.parent.mkdir(parents=True, exist_ok=True)
    members: list[str] = []

    with zipfile.ZipFile(PK3, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(MOD_SRC.rglob("*")):
            if path.is_file():
                arcname = path.relative_to(MOD_SRC).as_posix()
                zf.write(path, arcname)
                members.append(arcname)

    missing = sorted(required.difference(members))
    if missing:
        hint = ""
        if "zscript/nexo_handoff.zs" in missing:
            hint = (
                "\nRecovery on macOS:\n"
                "  git restore --source=origin/main -- "
                "doom/mod_src/zscript/nexo_handoff.zs\n"
                "This can occur on an older checkout that had the former "
                "ZSCRIPT/zscript case-insensitive path collision."
            )
        raise RuntimeError(
            "NEXO DOOM PK3 is incomplete; missing: "
            + ", ".join(missing)
            + hint
        )

    print("[NEXO] PK3 members: " + ", ".join(members))
    return PK3


def find_gzdoom(explicit: str | None) -> Path:
    candidates = []
    if explicit:
        candidates.append(Path(explicit).expanduser())

    env = os.getenv("NEXO_GZDOOM")
    if env:
        candidates.append(Path(env).expanduser())

    candidates += [
        ROOT / ".runtime/doom/gzdoom/GZDoom.app/Contents/MacOS/gzdoom",
        Path("/Applications/GZDoom.app/Contents/MacOS/gzdoom"),
        Path.home() / "Applications/GZDoom.app/Contents/MacOS/gzdoom",
    ]

    runtime = ROOT / ".runtime/doom/gzdoom"
    if runtime.exists():
        candidates.extend(runtime.glob("**/GZDoom.app/Contents/MacOS/gzdoom"))

    for path in candidates:
        if path.exists():
            return path

    raise FileNotFoundError(
        "GZDoom executable not found. Run: bash scripts/setup-doom-macos.sh"
    )


def find_iwad(explicit: str | None) -> Path:
    candidates = []
    if explicit:
        candidates.append(Path(explicit).expanduser())

    env = os.getenv("NEXO_DOOM_IWAD")
    if env:
        candidates.append(Path(env).expanduser())

    runtime = ROOT / ".runtime/doom/freedoom"
    if runtime.exists():
        candidates.extend(runtime.glob("**/freedoom2.wad"))

    for path in candidates:
        if path.exists():
            return path

    raise FileNotFoundError(
        "No Doom-compatible IWAD found. Run setup-doom-macos.sh "
        "or pass --iwad /path/to/DOOM2.WAD"
    )


def cvar_args(data: dict) -> list[str]:
    cargo = data.get("cargo", {})
    player = data.get("player_state", {})
    mission = data.get("mission", {})

    values = {
        "nexo_handoff": "true",
        "nexo_mass": str(float(player.get("logical_mass", 0.0))),
        "nexo_coins": str(int(cargo.get("coins", 0))),
        "nexo_goombas": str(int(cargo.get("goombas", 0))),
        "nexo_bobombs": str(int(cargo.get("bobombs", 0))),
        "nexo_score": str(int(mission.get("score", 0))),
    }

    args: list[str] = []
    for key, value in values.items():
        args += ["+set", key, value]
    return args


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch NEXO DOOM handoff")
    parser.add_argument("--gzdoom", help="Path to gzdoom executable")
    parser.add_argument("--iwad", help="Path to Doom II compatible IWAD")
    parser.add_argument("--map", default="MAP01", help="Starting map")
    parser.add_argument(
        "--controller-setup",
        action="store_true",
        help="Open GZDoom joystick/gamepad configuration menu on launch",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print command only")
    args = parser.parse_args()

    handoff = load_handoff()
    pk3 = build_pk3()
    gzdoom = find_gzdoom(args.gzdoom)
    iwad = find_iwad(args.iwad)

    DOOM_LOG.parent.mkdir(parents=True, exist_ok=True)
    if DOOM_LOG.exists():
        DOOM_LOG.unlink()

    cmd = [
        str(gzdoom),
        "+logfile", str(DOOM_LOG),
        "-iwad", str(iwad),
        "-file", str(pk3),

        # Keep controls continuous across worlds. GZDoom has native
        # joystick/gamepad support on macOS; explicitly enable it so the
        # adapter does not silently fall back to keyboard/mouse.
        "+set", "use_joystick", "true",
        "+set", "m_blockcontrollers", "false",

        "+map", args.map,
    ]
    cmd += cvar_args(handoff)

    if args.controller_setup:
        cmd += ["+menu_joystick"]

    print("[NEXO] Portal Fabric P1.2")
    print(f"[NEXO] Source: {handoff['source']['world']}")
    print(f"[NEXO] Target: {handoff['target']['world']}")
    print(f"[NEXO] GZDoom: {gzdoom}")
    print(f"[NEXO] IWAD: {iwad}")
    print(f"[NEXO] PK3: {pk3}")
    print(f"[NEXO] Mission log: {DOOM_LOG}")
    print("[NEXO] Controller: joystick/gamepad forced ON")
    if args.controller_setup:
        print("[NEXO] Controller setup menu: requested")
    print("[NEXO] Command:")
    print(" ".join(shlex.quote(x) for x in cmd))

    if args.dry_run:
        return 0

    subprocess.Popen(cmd, cwd=str(ROOT))
    print("[NEXO] GZDoom launched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
