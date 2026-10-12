#!/usr/bin/env python3
"""
NEXO local-only Mario hand mesh extractor.

Reads the user's own validated US Super Mario 64 ROM plus the existing local
sm64coopdx checkout and reconstructs four vanilla Mario hand meshes as OBJ:

- left_hand_closed.obj
- right_hand_closed.obj
- left_hand_open.obj
- right_hand_open.obj

Nothing extracted by this script is intended for Git. Output lives under
assets_local/mario_hands/meshes/.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
from typing import Dict, Iterable, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
SM64COOPDX = ROOT / ".runtime" / "sm64-audio-extractor" / "sm64coopdx"
MODEL_C = SM64COOPDX / "actors" / "mario" / "model.inc.c"
DEST = ROOT / "assets_local" / "mario_hands" / "meshes"

KNOWN_ROM_SHA1 = {
    "us": "9bef1128717f958171a4afac3ed78ee2bb4e86ce",
    "jp": "8a20a5c83d6ceb0f0506cfc9fa20d8f438cafe51",
    "eu": "4ac5721683d0e0b6bbb561b58a71740845dceea9",
    "sh": "3f319ae697533a255a1003d09202379d78d5a2e0",
}

# The physical ROM segment offsets embedded in the current sm64coopdx
# actors/mario/model.inc.c correspond to the US vanilla ROM layout.
SUPPORTED_REGION = "us"

TARGETS = {
    "left_hand_closed": "mario_left_hand_closed_shared_dl",
    "right_hand_closed": "mario_right_hand_closed_dl",
    "left_hand_open": "mario_left_hand_open_shared_dl",
    "right_hand_open": "mario_right_hand_open_dl",
}

VTX_RE = re.compile(
    r"ROM_ASSET_LOAD_VTX\(\s*"
    r"(?P<name>[A-Za-z0-9_]+)\s*,\s*"
    r"(?P<physical>0x[0-9A-Fa-f]+|\d+)\s*,\s*"
    r"(?P<physical_size>0x[0-9A-Fa-f]+|\d+)\s*,\s*"
    r"(?P<segment>0x[0-9A-Fa-f]+|\d+)\s*,\s*"
    r"(?P<size>0x[0-9A-Fa-f]+|\d+)\s*\)\s*;"
)

DL_RE = re.compile(
    r"const\s+Gfx\s+(?P<name>[A-Za-z0-9_]+)\[\]\s*=\s*\{"
    r"(?P<body>.*?)"
    r"\n\};",
    re.DOTALL,
)

CMD_RE = re.compile(
    r"(?P<cmd>gsSPVertex|gsSP2Triangles|gsSP1Triangle|gsSPDisplayList)"
    r"\s*\((?P<args>[^)]*)\)"
)


class ExtractError(RuntimeError):
    pass


def sha1(path: Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def detect_region(path: Path) -> str | None:
    digest = sha1(path)
    for region, expected in KNOWN_ROM_SHA1.items():
        if digest == expected:
            return region
    return None


def candidate_roms() -> Iterable[Path]:
    roots = [
        ROOT,
        Path.home() / "Documents",
        Path.home() / "Downloads",
        Path.home() / "Library" / "Application Support" / "sm64coopdx",
    ]

    seen: set[Path] = set()
    for base in roots:
        if not base.exists():
            continue
        try:
            for candidate in base.rglob("*.z64"):
                try:
                    resolved = candidate.resolve()
                except OSError:
                    continue
                if resolved in seen:
                    continue
                seen.add(resolved)
                yield candidate
        except (OSError, PermissionError):
            continue


def resolve_rom(explicit: str | None) -> tuple[Path, str, str]:
    if explicit:
        rom = Path(explicit).expanduser()
        if not rom.is_file():
            raise ExtractError(f"ROM not found: {rom}")
        digest = sha1(rom)
        region = next(
            (r for r, expected in KNOWN_ROM_SHA1.items() if digest == expected),
            None,
        )
        if region is None:
            raise ExtractError(
                "Supplied ROM is not a known vanilla SM64 ROM. "
                f"SHA-1={digest}"
            )
        return rom, region, digest

    print("[NEXO] No ROM path supplied; searching common local folders...")
    for candidate in candidate_roms():
        digest = sha1(candidate)
        region = next(
            (r for r, expected in KNOWN_ROM_SHA1.items() if digest == expected),
            None,
        )
        if region is not None:
            return candidate, region, digest

    raise ExtractError(
        "No known vanilla SM64 .z64 was found. "
        "Pass your own ROM path explicitly."
    )


def mio0_decompress(data: bytes) -> bytes:
    if len(data) < 16 or data[:4] != b"MIO0":
        return data

    out_size, comp_off, raw_off = struct.unpack_from(">III", data, 4)
    if comp_off >= len(data) or raw_off >= len(data):
        raise ExtractError("Invalid MIO0 offsets")

    ctrl_off = 16
    out = bytearray()
    comp_cursor = comp_off
    raw_cursor = raw_off
    control_bits = 0
    bits_left = 0

    while len(out) < out_size:
        if bits_left == 0:
            if ctrl_off + 4 > len(data):
                raise ExtractError("Truncated MIO0 control stream")
            control_bits = struct.unpack_from(">I", data, ctrl_off)[0]
            ctrl_off += 4
            bits_left = 32

        if control_bits & 0x80000000:
            if raw_cursor >= len(data):
                raise ExtractError("Truncated MIO0 raw stream")
            out.append(data[raw_cursor])
            raw_cursor += 1
        else:
            if comp_cursor + 2 > len(data):
                raise ExtractError("Truncated MIO0 backreference stream")
            param = struct.unpack_from(">H", data, comp_cursor)[0]
            comp_cursor += 2

            count = (param >> 12) + 3
            distance = (param & 0x0FFF) + 1
            src = len(out) - distance
            if src < 0:
                raise ExtractError("Invalid MIO0 backreference distance")

            for _ in range(count):
                if len(out) >= out_size:
                    break
                out.append(out[src])
                src += 1

        control_bits = (control_bits << 1) & 0xFFFFFFFF
        bits_left -= 1

    return bytes(out)


def parse_vtx_defs(source: str) -> Dict[str, Tuple[int, int, int, int]]:
    defs: Dict[str, Tuple[int, int, int, int]] = {}
    for match in VTX_RE.finditer(source):
        defs[match.group("name")] = (
            int(match.group("physical"), 0),
            int(match.group("physical_size"), 0),
            int(match.group("segment"), 0),
            int(match.group("size"), 0),
        )
    return defs


def parse_display_lists(source: str) -> Dict[str, str]:
    return {
        match.group("name"): match.group("body")
        for match in DL_RE.finditer(source)
    }


def parse_args(text: str) -> List[str]:
    return [part.strip() for part in text.split(",") if part.strip()]


def parse_int(text: str) -> int:
    return int(text.strip(), 0)


def read_vertex_group(
    rom: bytes,
    definition: Tuple[int, int, int, int],
    segment_cache: Dict[Tuple[int, int], bytes],
) -> List[Tuple[float, float, float, int, int, int, int]]:
    physical, physical_size, segment_offset, size = definition
    key = (physical, physical_size)

    if key not in segment_cache:
        end = physical + physical_size
        if physical < 0 or end > len(rom):
            raise ExtractError(
                f"ROM segment outside file: 0x{physical:x}+{physical_size}"
            )
        segment_cache[key] = mio0_decompress(rom[physical:end])

    segment = segment_cache[key]
    if segment_offset + size > len(segment):
        raise ExtractError(
            f"Vertex data outside decompressed segment: "
            f"offset=0x{segment_offset:x} size={size} segment={len(segment)}"
        )
    if size % 16:
        raise ExtractError(f"Vertex group size {size} is not 16-byte aligned")

    vertices = []
    payload = segment[segment_offset : segment_offset + size]
    for off in range(0, len(payload), 16):
        x, y, z, _flag, _s, _t = struct.unpack_from(">hhhhhh", payload, off)
        r, g, b, a = struct.unpack_from(">BBBB", payload, off + 12)
        vertices.append((float(x), float(y), float(z), r, g, b, a))
    return vertices


def build_mesh(
    dl_name: str,
    display_lists: Dict[str, str],
    vtx_defs: Dict[str, Tuple[int, int, int, int]],
    rom: bytes,
    segment_cache: Dict[Tuple[int, int], bytes],
) -> tuple[
    List[Tuple[float, float, float, int, int, int, int]],
    List[Tuple[int, int, int]],
]:
    vertices: List[Tuple[float, float, float, int, int, int, int]] = []
    faces: List[Tuple[int, int, int]] = []
    slots: Dict[int, int] = {}
    recursion: set[str] = set()

    def emit_triangle(a: int, b: int, c: int) -> None:
        try:
            faces.append((slots[a], slots[b], slots[c]))
        except KeyError as exc:
            raise ExtractError(
                f"{dl_name}: triangle references unloaded vertex slot {exc.args[0]}"
            ) from exc

    def process(name: str) -> None:
        if name in recursion:
            raise ExtractError(f"Recursive display list: {name}")
        body = display_lists.get(name)
        if body is None:
            raise ExtractError(f"Display list not found: {name}")

        recursion.add(name)
        try:
            for match in CMD_RE.finditer(body):
                cmd = match.group("cmd")
                args = parse_args(match.group("args"))

                if cmd == "gsSPVertex":
                    if len(args) < 3:
                        raise ExtractError(f"{name}: malformed gsSPVertex")
                    group = args[0]
                    count = parse_int(args[1])
                    start_slot = parse_int(args[2])

                    definition = vtx_defs.get(group)
                    if definition is None:
                        raise ExtractError(
                            f"{name}: vertex group definition missing: {group}"
                        )
                    group_vertices = read_vertex_group(
                        rom, definition, segment_cache
                    )
                    if count > len(group_vertices):
                        raise ExtractError(
                            f"{name}: requests {count} vertices from {group}, "
                            f"only {len(group_vertices)} available"
                        )

                    for idx in range(count):
                        vertices.append(group_vertices[idx])
                        slots[start_slot + idx] = len(vertices)

                elif cmd == "gsSP2Triangles":
                    if len(args) < 8:
                        raise ExtractError(f"{name}: malformed gsSP2Triangles")
                    emit_triangle(
                        parse_int(args[0]), parse_int(args[1]), parse_int(args[2])
                    )
                    emit_triangle(
                        parse_int(args[4]), parse_int(args[5]), parse_int(args[6])
                    )

                elif cmd == "gsSP1Triangle":
                    if len(args) < 4:
                        raise ExtractError(f"{name}: malformed gsSP1Triangle")
                    emit_triangle(
                        parse_int(args[0]), parse_int(args[1]), parse_int(args[2])
                    )

                elif cmd == "gsSPDisplayList":
                    if not args:
                        raise ExtractError(f"{name}: malformed gsSPDisplayList")
                    process(args[0])
        finally:
            recursion.remove(name)

    process(dl_name)
    return vertices, faces


def write_obj(
    path: Path,
    label: str,
    vertices: List[Tuple[float, float, float, int, int, int, int]],
    faces: List[Tuple[int, int, int]],
) -> None:
    lines = [
        f"# NEXO local-only extraction: {label}",
        "# Source: user's own validated SM64 ROM",
        "# Vertex colors/normals are recorded as comments for provenance.",
        "o " + label,
    ]

    for x, y, z, r, g, b, a in vertices:
        lines.append(f"# vc {r} {g} {b} {a}")
        lines.append(f"v {x:.6f} {y:.6f} {z:.6f}")

    for a, b, c in faces:
        lines.append(f"f {a} {b} {c}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract Mario hand meshes locally from the user's SM64 ROM"
    )
    parser.add_argument(
        "rom",
        nargs="?",
        help="Path to your own vanilla SM64 .z64; omitted = auto-search",
    )
    args = parser.parse_args()

    if not MODEL_C.is_file():
        raise ExtractError(
            "Local sm64coopdx Mario model source not found. "
            "Run scripts/extract-mario-sfx-from-sm64-rom.sh first."
        )

    rom_path, region, digest = resolve_rom(args.rom)
    print(f"[NEXO] ROM: {rom_path}")
    print(f"[NEXO] Detected region: {region}")
    print(f"[NEXO] SHA-1: {digest}")

    if region != SUPPORTED_REGION:
        raise ExtractError(
            "The current direct hand-mesh extractor is pinned to the US "
            "vanilla ROM layout because actors/mario/model.inc.c contains US "
            "physical segment offsets. Use a validated US ROM for this stage "
            "or use the Fast64/Blender import path for another region."
        )

    source = MODEL_C.read_text(encoding="utf-8")
    vtx_defs = parse_vtx_defs(source)
    display_lists = parse_display_lists(source)
    rom = rom_path.read_bytes()
    segment_cache: Dict[Tuple[int, int], bytes] = {}

    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema": "nexo.mario_hands.mesh_extract.v1",
        "rom_region": region,
        "rom_sha1": digest,
        "model_source": str(MODEL_C),
        "meshes": {},
    }

    for label, dl_name in TARGETS.items():
        vertices, faces = build_mesh(
            dl_name, display_lists, vtx_defs, rom, segment_cache
        )
        if not vertices or not faces:
            raise ExtractError(
                f"{label}: extraction returned empty geometry "
                f"(vertices={len(vertices)} faces={len(faces)})"
            )

        output = DEST / f"{label}.obj"
        write_obj(output, label, vertices, faces)
        manifest["meshes"][label] = {
            "display_list": dl_name,
            "vertices": len(vertices),
            "faces": len(faces),
            "path": output.name,
        }
        print(
            f"[NEXO] Created {output.name}: "
            f"{len(vertices)} vertices, {len(faces)} triangles"
        )

    manifest_path = DEST / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print()
    print("[NEXO] Mario hand mesh extraction: PASS")
    print(f"[NEXO] Destination: {DEST}")
    print(f"[NEXO] Manifest: {manifest_path}")
    print("[NEXO] Output remains local-only and gitignored.")
    print("[NEXO] This does NOT create assets_local/mario_hands/READY.")
    print("[NEXO] Next stage: render per-weapon back/front grip layers.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ExtractError as exc:
        print(f"[NEXO] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
