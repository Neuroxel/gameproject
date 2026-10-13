#!/usr/bin/env python3
"""
NEXO local-only full-body Mario geometry extractor.

This advances AVATAR-BODY-1 without committing Nintendo assets. It reuses the
already-audited ROM/display-list parser from the first-person hand extractor and
writes body-part OBJ files under assets_local/mario_avatar/meshes/.

The output is a neutral geometry/skeleton source pack for portal transitions,
external/death cameras and later animated full-body rendering. It does NOT turn
DOOM into third person and it does NOT create the runtime READY marker.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
HELPER_PATH = ROOT / "scripts" / "extract-mario-hand-meshes-from-sm64-rom.py"
DEST = ROOT / "assets_local" / "mario_avatar" / "meshes"
MANIFEST = ROOT / "assets_local" / "mario_avatar" / "body_source_manifest.json"

# Display-list choices intentionally use the normal/cap-on Mario geometry.
TARGETS = {
    "butt": "mario_butt",
    "torso": "mario_torso",
    "head_cap_on": "mario_cap_on_eyes_front",

    "left_arm": "mario_left_arm",
    "left_forearm": "mario_left_forearm_shared_dl",
    "left_hand_closed": "mario_left_hand_closed",

    "right_arm": "mario_right_arm",
    "right_forearm": "mario_right_forearm_shared_dl",
    "right_hand_closed": "mario_right_hand_closed",

    "left_thigh": "mario_left_thigh",
    "left_leg": "mario_left_leg_shared_dl",
    "left_foot": "mario_left_foot",

    "right_thigh": "mario_right_thigh",
    "right_leg": "mario_right_leg_shared_dl",
    "right_foot": "mario_right_foot",
}

# Canonical neutral skeleton offsets transcribed from actors/mario/geo.inc.c.
# Values are SM64 model-space translations. Rotation/animation remains a later
# renderer concern; keeping these offsets explicit prevents guessed anatomy.
SKELETON = {
    "root": {"part": "butt", "offset": [0, 0, 0]},
    "torso": {"parent": "root", "part": "torso", "offset": [68, 0, 0]},
    "head": {"parent": "torso", "part": "head_cap_on", "offset": [87, 0, 0]},

    "left_arm": {"parent": "torso", "part": "left_arm", "offset": [67, -10, 79]},
    "left_forearm": {"parent": "left_arm", "part": "left_forearm", "offset": [65, 0, 0]},
    "left_hand": {"parent": "left_forearm", "part": "left_hand_closed", "offset": [60, 0, 0]},

    "right_arm": {"parent": "torso", "part": "right_arm", "offset": [68, -10, -79]},
    "right_forearm": {"parent": "right_arm", "part": "right_forearm", "offset": [65, 0, 0]},
    "right_hand": {"parent": "right_forearm", "part": "right_hand_closed", "offset": [60, 0, 0]},

    "left_thigh": {"parent": "root", "part": "left_thigh", "offset": [13, -8, 42]},
    "left_leg": {"parent": "left_thigh", "part": "left_leg", "offset": [89, 0, 0]},
    "left_foot": {"parent": "left_leg", "part": "left_foot", "offset": [67, 0, 0]},

    "right_thigh": {"parent": "root", "part": "right_thigh", "offset": [13, -8, -42]},
    "right_leg": {"parent": "right_thigh", "part": "right_leg", "offset": [89, 0, 0]},
    "right_foot": {"parent": "right_leg", "part": "right_foot", "offset": [67, 0, 0]},
}

PART_COLORS = {
    "butt": "blue",
    "torso": "red_blue",
    "head_cap_on": "skin_red_brown",
    "left_arm": "red",
    "left_forearm": "red",
    "left_hand_closed": "white",
    "right_arm": "red",
    "right_forearm": "red",
    "right_hand_closed": "white",
    "left_thigh": "blue",
    "left_leg": "blue",
    "left_foot": "brown",
    "right_thigh": "blue",
    "right_leg": "blue",
    "right_foot": "brown",
}


class BodyExtractError(RuntimeError):
    pass


def load_hand_helper():
    if not HELPER_PATH.is_file():
        raise BodyExtractError(f"Missing shared extraction helper: {HELPER_PATH}")

    spec = importlib.util.spec_from_file_location("nexo_sm64_mesh_helper", HELPER_PATH)
    if spec is None or spec.loader is None:
        raise BodyExtractError("Could not load SM64 mesh helper")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract local full-body Mario part geometry from user's SM64 ROM"
    )
    parser.add_argument(
        "rom",
        nargs="?",
        help="Path to own vanilla SM64 .z64; omitted = helper auto-search",
    )
    args = parser.parse_args()

    helper = load_hand_helper()

    if not helper.MODEL_C.is_file():
        raise BodyExtractError(
            "Local sm64coopdx Mario model source not found. "
            "Run scripts/extract-mario-sfx-from-sm64-rom.sh first."
        )

    rom_path, region, digest = helper.resolve_rom(args.rom)
    if region != helper.SUPPORTED_REGION:
        raise BodyExtractError(
            "Current direct geometry offsets are pinned to the validated US "
            "vanilla ROM layout."
        )

    print(f"[NEXO] ROM: {rom_path}")
    print(f"[NEXO] Detected region: {region}")
    print(f"[NEXO] SHA-1: {digest}")

    source = helper.MODEL_C.read_text(encoding="utf-8")
    vtx_defs = helper.parse_vtx_defs(source)
    display_lists = helper.parse_display_lists(source)
    rom = rom_path.read_bytes()
    segment_cache = {}

    DEST.mkdir(parents=True, exist_ok=True)

    manifest = {
        "schema": "nexo.mario_avatar.body_source.v1",
        "rom_region": region,
        "rom_sha1": digest,
        "model_source": str(helper.MODEL_C),
        "geo_source": str(
            ROOT / ".runtime" / "sm64-audio-extractor" / "sm64coopdx"
            / "actors" / "mario" / "geo.inc.c"
        ),
        "parts": {},
        "skeleton": SKELETON,
        "part_color_family": PART_COLORS,
        "runtime_ready": False,
        "notes": [
            "Local-only body source geometry; no Nintendo asset is committed.",
            "Skeleton offsets are canonical SM64 geo.inc.c translations.",
            "This source pack is for external/portal/death views, not third-person DOOM.",
            "READY must not be created until a coherent rendered body pack exists.",
        ],
    }

    for label, dl_name in TARGETS.items():
        try:
            vertices, faces = helper.build_mesh(
                dl_name,
                display_lists,
                vtx_defs,
                rom,
                segment_cache,
            )
        except Exception as exc:
            raise BodyExtractError(
                f"{label}: failed to reconstruct display list {dl_name}: {exc}"
            ) from exc

        if not vertices or not faces:
            raise BodyExtractError(
                f"{label}: empty geometry (vertices={len(vertices)} faces={len(faces)})"
            )

        output = DEST / f"{label}.obj"
        helper.write_obj(output, label, vertices, faces)
        manifest["parts"][label] = {
            "display_list": dl_name,
            "vertices": len(vertices),
            "faces": len(faces),
            "path": output.name,
            "color_family": PART_COLORS[label],
        }
        print(
            f"[NEXO] Created {output.name}: "
            f"{len(vertices)} vertices, {len(faces)} triangles"
        )

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print()
    print("[NEXO] Mario full-body source extraction: PASS")
    print(f"[NEXO] Mesh destination: {DEST}")
    print(f"[NEXO] Source manifest: {MANIFEST}")
    print("[NEXO] Runtime READY remains intentionally absent.")
    print("[NEXO] Next: neutral/portal pose renderer + external-camera integration.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (BodyExtractError, OSError, ValueError, KeyError) as exc:
        print(f"[NEXO] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
