#!/usr/bin/env python3
"""
NEXO Portal Fabric - outbound DOOM handoff parser v0.1

Parses the structured [NEXO_HANDOFF] line written by the GZDoom adapter when
M2 is complete and MAP01 unloads, then emits the same neutral handoff schema.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOG = ROOT / "bridge" / "runtime" / "doom.log"
DEFAULT_OUTPUT = ROOT / "bridge" / "runtime" / "handoff_from_doom.json"

LINE_RE = re.compile(r"^\[NEXO_HANDOFF\]\s+(.*)$")
PAIR_RE = re.compile(r"(\w+)=([^\s]+)")


def parse_value(value: str) -> Any:
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def find_last_handoff(log_path: Path) -> dict[str, Any]:
    if not log_path.exists():
        raise FileNotFoundError(
            f"DOOM mission log not found: {log_path}. "
            "Run DOOM through bridge/run_doom.py first."
        )

    matches: list[dict[str, Any]] = []
    for raw in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = LINE_RE.match(raw.strip())
        if not m:
            continue
        pairs = {k: parse_value(v) for k, v in PAIR_RE.findall(m.group(1))}
        if pairs:
            matches.append(pairs)

    if not matches:
        raise RuntimeError(
            "No completed DOOM handoff found. Finish M2 (8 hostiles) and exit MAP01."
        )

    return matches[-1]


def build_manifest(data: dict[str, Any], log_path: Path) -> dict[str, Any]:
    return {
        "schema": "nexo.portal.handoff.v1",
        "source": {
            "world": str(data.get("source", "DOOM_UNKNOWN")),
            "adapter": "gzdoom",
            "storage_file": str(log_path),
        },
        "target": {
            "world": str(data.get("target", "NEXO_HUB")),
            "adapter": "orchestrator",
        },
        "mission": {
            "id": str(data.get("mission", "M2_UNKNOWN")),
            "score": int(data.get("score", 0)),
        },
        "identity": {
            "avatar": "MARIO",
            "audio_profile": "mario_voice_v1",
        },
        "perspective": {
            "source": str(data.get("perspective", "first_person")),
            "target": "adaptive",
            "transition": "portal_pull_out",
        },
        "player_state": {
            "logical_mass": float(data.get("mass", 0.0)),
        },
        "cargo": {
            "coins": int(data.get("coins", 0)),
            "goombas": int(data.get("goombas", 0)),
            "bobombs": int(data.get("bobombs", 0)),
            "combat_shards": int(data.get("kills", 0)),
        },
        "derived": {
            "next_map": str(data.get("nextmap", "")),
            "breach_stability": int(data.get("kills", 0)),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Export DOOM -> NEXO handoff")
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--print", dest="print_json", action="store_true")
    args = parser.parse_args()

    data = find_last_handoff(args.log)
    manifest = build_manifest(data, args.log)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"[NEXO] DOOM handoff found: {args.log}")
    print(f"[NEXO] Source world: {manifest['source']['world']}")
    print(f"[NEXO] Target world: {manifest['target']['world']}")
    print(f"[NEXO] Manifest written: {args.output}")

    if args.print_json:
        print(json.dumps(manifest, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
