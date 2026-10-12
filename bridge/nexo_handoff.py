#!/usr/bin/env python3
"""
NEXO Portal Fabric bridge v0.2

Reads SM64CoopDX mod-storage *.sav files on macOS and exports a neutral JSON
manifest for the next world adapter.

Robustness rules:
- Prefer a true pending handoff (handoff_pending=1).
- Recover the last complete handoff left by older buggy builds that cleared the
  pending bit on level reload but kept all payload fields.
- Never modify the SM64 save.

No external packages required.
"""

from __future__ import annotations

import argparse
import configparser
import json
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

DEFAULT_SAVE_DIR = Path.home() / "Library" / "Application Support" / "sm64coopdx" / "sav"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "runtime" / "handoff.json"

PAYLOAD_KEYS = {
    "handoff_source",
    "handoff_target",
    "handoff_scale",
    "handoff_coins",
    "handoff_goombas",
    "handoff_bobombs",
    "handoff_score",
}

EXPECTED_KEYS = PAYLOAD_KEYS | {"handoff_pending"}


def parse_save(path: Path) -> Optional[Dict[str, str]]:
    cfg = configparser.ConfigParser()
    cfg.optionxform = str
    try:
        cfg.read(path, encoding="utf-8")
    except Exception:
        return None

    if "storage" not in cfg:
        return None

    return {k: v for k, v in cfg["storage"].items()}


def payload_is_complete(data: Dict[str, str]) -> bool:
    return bool(data.get("handoff_target")) and all(k in data for k in PAYLOAD_KEYS)


def find_handoff(save_dir: Path) -> Tuple[Path, Dict[str, str], bool]:
    """Return (save_path, data, recovered_old_handoff)."""
    if not save_dir.exists():
        raise FileNotFoundError(f"SM64CoopDX sav directory not found: {save_dir}")

    pending = []
    recoverable = []

    for path in sorted(save_dir.rglob("*.sav")):
        data = parse_save(path)
        if not data or not payload_is_complete(data):
            continue

        completeness = sum(1 for k in EXPECTED_KEYS if k in data)
        mtime = path.stat().st_mtime

        row = (completeness, mtime, path, data)
        if data.get("handoff_pending") == "1":
            pending.append(row)
        else:
            # Compatibility recovery for the M1 build that incorrectly reset
            # handoff_pending on every level init while leaving the payload.
            recoverable.append(row)

    pool = pending if pending else recoverable
    if not pool:
        raise RuntimeError(
            "No NEXO handoff payload found. Complete M1 and cross the NEXO Gate first."
        )

    pool.sort(key=lambda row: (row[0], row[1]), reverse=True)
    _, _, path, data = pool[0]
    return path, data, not bool(pending)


def as_int(data: Dict[str, str], key: str, default: int = 0) -> int:
    try:
        return int(float(data.get(key, default)))
    except (TypeError, ValueError):
        return default


def as_float(data: Dict[str, str], key: str, default: float = 0.0) -> float:
    try:
        return float(data.get(key, default))
    except (TypeError, ValueError):
        return default


def build_manifest(
    source_file: Path,
    data: Dict[str, str],
    recovered: bool = False,
) -> Dict[str, Any]:
    return {
        "schema": "nexo.portal.handoff.v1",
        "source": {
            "world": data.get("handoff_source", "UNKNOWN"),
            "adapter": "sm64coopdx",
            "storage_file": str(source_file),
            "recovered_from_legacy_pending_reset": recovered,
        },
        "target": {
            "world": data.get("handoff_target", "UNKNOWN"),
            "adapter": "pending",
        },
        "mission": {
            "id": "M1_CARGA_IMPOSIBLE",
            "score": as_int(data, "handoff_score"),
        },
        "player_state": {
            "logical_mass": as_float(data, "handoff_scale"),
        },
        "cargo": {
            "coins": as_int(data, "handoff_coins"),
            "goombas": as_int(data, "handoff_goombas"),
            "bobombs": as_int(data, "handoff_bobombs"),
        },
        "derived": {
            "explosive_resource": as_int(data, "handoff_bobombs"),
            "currency_resource": as_int(data, "handoff_coins"),
            "companion_tokens": as_int(data, "handoff_goombas"),
        },
    }


def write_manifest(manifest: Dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Export NEXO Portal Fabric handoff")
    parser.add_argument(
        "--save-dir",
        type=Path,
        default=DEFAULT_SAVE_DIR,
        help=f"SM64CoopDX sav directory (default: {DEFAULT_SAVE_DIR})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"JSON output path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--print",
        dest="print_json",
        action="store_true",
        help="Also print the manifest to stdout",
    )
    args = parser.parse_args()

    source_file, data, recovered = find_handoff(args.save_dir)
    manifest = build_manifest(source_file, data, recovered=recovered)
    write_manifest(manifest, args.output)

    if recovered:
        print(
            "[NEXO] WARNING: recovered completed handoff from an older build "
            "that cleared handoff_pending."
        )
    else:
        print(f"[NEXO] Pending handoff found: {source_file}")

    print(f"[NEXO] Source save: {source_file}")
    print(f"[NEXO] Target world: {manifest['target']['world']}")
    print(f"[NEXO] Manifest written: {args.output}")

    if args.print_json:
        print(json.dumps(manifest, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
