#!/usr/bin/env python3
"""
Render local Mario hand OBJ meshes into transparent GZDoom weapon overlay PNGs.

No third-party Python packages are required. This intentionally produces a
first functional prototype; transforms live in doom/mario_hands_pose_manifest.json
and can be tuned after in-game visual QA.

Default behavior renders all layers but does NOT activate them.
Use --activate to create assets_local/mario_hands/READY after all 18 layers
have rendered successfully.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
MESH_DIR = ROOT / "assets_local" / "mario_hands" / "meshes"
DEST = ROOT / "assets_local" / "mario_hands"
MANIFEST = ROOT / "doom" / "mario_hands_pose_manifest.json"
READY = DEST / "READY"

EXPECTED = (
    "NHFBA0.png", "NHFFA0.png",
    "NHCBA0.png", "NHCFA0.png",
    "NHPBA0.png", "NHPFA0.png",
    "NHSBA0.png", "NHSFA0.png",
    "NH2BA0.png", "NH2FA0.png",
    "NHGBA0.png", "NHGFA0.png",
    "NHRBA0.png", "NHRFA0.png",
    "NHEBA0.png", "NHEFA0.png",
    "NHBBA0.png", "NHBFA0.png",
)


class RenderError(RuntimeError):
    pass


def load_obj(path: Path):
    vertices = []
    faces = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("v "):
            parts = line.split()
            vertices.append(tuple(float(v) for v in parts[1:4]))
        elif line.startswith("f "):
            idx = []
            for item in line.split()[1:4]:
                idx.append(int(item.split("/", 1)[0]) - 1)
            faces.append(tuple(idx))
    if not vertices or not faces:
        raise RenderError(
            f"OBJ has no usable geometry: {path} "
            f"(vertices={len(vertices)} faces={len(faces)})"
        )
    return vertices, faces


def rotate(v, rx, ry, rz):
    x, y, z = v
    ax = math.radians(rx)
    ay = math.radians(ry)
    az = math.radians(rz)

    cx, sx = math.cos(ax), math.sin(ax)
    cy, sy = math.cos(ay), math.sin(ay)
    cz, sz = math.cos(az), math.sin(az)

    y, z = y * cx - z * sx, y * sx + z * cx
    x, z = x * cy + z * sy, -x * sy + z * cy
    x, y = x * cz - y * sz, x * sz + y * cz
    return (x, y, z)


def cross(a, b):
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def sub(a, b):
    return (a[0]-b[0], a[1]-b[1], a[2]-b[2])


def normalized(v):
    length = math.sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2])
    if length <= 1e-9:
        return (0.0, 0.0, 1.0)
    return (v[0]/length, v[1]/length, v[2]/length)


def edge(a, b, p):
    return (p[0]-a[0]) * (b[1]-a[1]) - (p[1]-a[1]) * (b[0]-a[0])


def draw_triangle(pixels, zbuf, width, height, p0, p1, p2, color):
    a = (p0[0], p0[1])
    b = (p1[0], p1[1])
    c = (p2[0], p2[1])
    area = edge(a, b, c)
    if abs(area) < 1e-6:
        return

    min_x = max(0, int(math.floor(min(a[0], b[0], c[0]))))
    max_x = min(width - 1, int(math.ceil(max(a[0], b[0], c[0]))))
    min_y = max(0, int(math.floor(min(a[1], b[1], c[1]))))
    max_y = min(height - 1, int(math.ceil(max(a[1], b[1], c[1]))))

    inv_area = 1.0 / area
    for y in range(min_y, max_y + 1):
        py = y + 0.5
        for x in range(min_x, max_x + 1):
            p = (x + 0.5, py)
            w0 = edge(b, c, p) * inv_area
            w1 = edge(c, a, p) * inv_area
            w2 = edge(a, b, p) * inv_area
            if w0 < -1e-6 or w1 < -1e-6 or w2 < -1e-6:
                continue

            depth = w0*p0[2] + w1*p1[2] + w2*p2[2]
            pos = y * width + x
            if depth <= zbuf[pos]:
                continue
            zbuf[pos] = depth
            pixels[pos] = color


def paint_rotated_capsule(
    pixels,
    width: int,
    height: int,
    cx: float,
    cy: float,
    w: float,
    h: float,
    angle_deg: float,
    color,
):
    """Paint a rounded capsule in screen space.

    This is used only for Mario's red sleeve / white glove cuff behind the
    locally extracted hand mesh. The hand geometry itself still comes from the
    user's own SM64 ROM.
    """
    if w <= 0 or h <= 0:
        return

    angle = math.radians(angle_deg)
    ca, sa = math.cos(angle), math.sin(angle)
    radius = min(w * 0.5, h * 0.5)
    half_h = h * 0.5
    core = max(0.0, half_h - radius)
    extent = int(math.ceil(max(w, h))) + 3

    min_x = max(0, int(math.floor(cx - extent)))
    max_x = min(width - 1, int(math.ceil(cx + extent)))
    min_y = max(0, int(math.floor(cy - extent)))
    max_y = min(height - 1, int(math.ceil(cy + extent)))

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy

            # Rotate screen-space point into local capsule coordinates.
            lx = dx * ca + dy * sa
            ly = -dx * sa + dy * ca

            aly = abs(ly)
            inside = False
            if aly <= core:
                inside = abs(lx) <= radius
            else:
                cap_y = aly - core
                inside = lx * lx + cap_y * cap_y <= radius * radius

            if inside:
                pixels[y * width + x] = color


def paint_rotated_tapered_sleeve(
    pixels,
    width: int,
    height: int,
    cx: float,
    cy: float,
    top_w: float,
    bottom_w: float,
    h: float,
    angle_deg: float,
    color,
):
    """Paint a small tapered sleeve instead of a rectangular/capsule block."""
    if top_w <= 0 or bottom_w <= 0 or h <= 0:
        return

    angle = math.radians(angle_deg)
    ca, sa = math.cos(angle), math.sin(angle)
    extent = int(math.ceil(max(top_w, bottom_w, h))) + 4

    min_x = max(0, int(math.floor(cx - extent)))
    max_x = min(width - 1, int(math.ceil(cx + extent)))
    min_y = max(0, int(math.floor(cy - extent)))
    max_y = min(height - 1, int(math.ceil(cy + extent)))

    half_h = h * 0.5
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy
            lx = dx * ca + dy * sa
            ly = -dx * sa + dy * ca

            if ly < -half_h or ly > half_h:
                continue

            t = (ly + half_h) / h
            local_half_w = (top_w * (1.0 - t) + bottom_w * t) * 0.5
            if abs(lx) <= local_half_w:
                pixels[y * width + x] = color


def paint_mario_wrist(pixels, width: int, height: int, inst):
    """Add a compact Mario-red sleeve and white cuff under one hand mesh."""
    sleeve = inst.get("sleeve")
    if not sleeve:
        return

    tx = float(inst.get("tx", width / 2))
    ty = float(inst.get("ty", height))
    angle = float(sleeve.get("angle", 0.0))

    sx = tx + float(sleeve.get("dx", 0.0))
    sy = ty + float(sleeve.get("dy", 0.0))
    sw = float(sleeve.get("w", 22.0))
    sh = float(sleeve.get("h", 34.0))

    # Dark external silhouette first, then a tapered Mario-red sleeve.
    # v5 can anchor the forearm physically to the bottom of the 320x200
    # weapon-space instead of rendering a short floating red patch.
    top_w = float(sleeve.get("top_w", sw * 0.72))
    bottom_w = float(sleeve.get("bottom_w", sw))

    if bool(sleeve.get("to_bottom", False)):
        top_x = tx + float(sleeve.get("top_dx", sleeve.get("dx", 0.0)))
        top_y = ty + float(sleeve.get("top_dy", sleeve.get("dy", 4.0)))
        bottom_x = tx + float(sleeve.get("bottom_dx", 0.0))
        bottom_y = float(height + sleeve.get("bottom_overhang", 6.0))

        vx = bottom_x - top_x
        vy = bottom_y - top_y
        sh = max(1.0, math.hypot(vx, vy))
        sx = (top_x + bottom_x) * 0.5
        sy = (top_y + bottom_y) * 0.5

        # Local +Y maps to world (-sin(angle), cos(angle)).
        angle = math.degrees(math.atan2(-vx, vy))
    else:
        top_x = sx
        top_y = sy

    paint_rotated_tapered_sleeve(
        pixels, width, height, sx, sy,
        top_w + 2.5, bottom_w + 3.0, sh + 2.0, angle,
        (52, 25, 26, 255),
    )
    paint_rotated_tapered_sleeve(
        pixels, width, height, sx, sy,
        top_w, bottom_w, sh, angle,
        (184, 39, 34, 255),
    )

    cuff = inst.get("cuff", {})
    if bool(sleeve.get("to_bottom", False)):
        cx = top_x + float(cuff.get("dx", 0.0))
        cy = top_y + float(cuff.get("dy", 0.0))
    else:
        cx = tx + float(cuff.get("dx", sleeve.get("cuff_dx", 0.0)))
        cy = ty + float(cuff.get("dy", sleeve.get("cuff_dy", 2.0)))
    cw = float(cuff.get("w", max(16.0, sw * 0.92)))
    ch = float(cuff.get("h", 11.0))
    ca = float(cuff.get("angle", angle))

    paint_rotated_capsule(
        pixels, width, height, cx, cy,
        cw + 2.0, ch + 2.0, ca,
        (54, 54, 58, 255),
    )
    paint_rotated_capsule(
        pixels, width, height, cx, cy,
        cw, ch, ca,
        (244, 244, 240, 255),
    )


def render_layer(width, height, instances, meshes):
    pixels = [(0, 0, 0, 0)] * (width * height)
    zbuf = [float("-inf")] * (width * height)
    light = normalized((-0.25, -0.45, 0.86))

    for order, inst in enumerate(instances):
        paint_mario_wrist(pixels, width, height, inst)

        mesh_name = inst["mesh"]
        if mesh_name not in meshes:
            mesh_path = MESH_DIR / f"{mesh_name}.obj"
            meshes[mesh_name] = load_obj(mesh_path)

        vertices, faces = meshes[mesh_name]
        rx = float(inst.get("rx", 0.0))
        ry = float(inst.get("ry", 0.0))
        rz = float(inst.get("rz", 0.0))
        scale = float(inst.get("scale", 1.0))
        tx = float(inst.get("tx", width / 2))
        ty = float(inst.get("ty", height))
        flip_x = bool(inst.get("flip_x", False))

        transformed = []
        world = []
        for v in vertices:
            q = rotate(v, rx, ry, rz)
            if flip_x:
                q = (-q[0], q[1], q[2])
            world.append(q)
            transformed.append((
                tx + q[0] * scale,
                ty - q[1] * scale,
                q[2] * scale + order * 1000.0,
            ))

        for ia, ib, ic in faces:
            wa, wb, wc = world[ia], world[ib], world[ic]
            n = normalized(cross(sub(wb, wa), sub(wc, wa)))
            ndotl = abs(n[0]*light[0] + n[1]*light[1] + n[2]*light[2])
            # Keep the genuine N64 faceting, but compress the contrast so the
            # silhouette reads as a white Mario glove instead of a crystal.
            shade = 0.72 + 0.28 * ndotl

            # Mario glove: warm white with enough grey range to preserve the
            # low-poly N64 shape against bright weapon sprites.
            color = (
                max(0, min(255, int(250 * shade))),
                max(0, min(255, int(250 * shade))),
                max(0, min(255, int(246 * shade))),
                255,
            )
            draw_triangle(
                pixels, zbuf, width, height,
                transformed[ia], transformed[ib], transformed[ic], color
            )

    return pixels


def add_glove_outline(pixels, width: int, height: int, radius: int = 1):
    """Add a small dark silhouette edge so the low-poly white glove reads as
    Mario's glove instead of an unbounded white polygon mass.

    The outline is added only outside the existing alpha mask; internal
    low-poly shading is preserved.
    """
    if radius <= 0:
        return pixels

    source = list(pixels)
    output = list(pixels)
    outline = (48, 48, 52, 255)

    for y in range(height):
        for x in range(width):
            pos = y * width + x
            if source[pos][3] != 0:
                continue

            found = False
            for dy in range(-radius, radius + 1):
                yy = y + dy
                if yy < 0 or yy >= height:
                    continue
                for dx in range(-radius, radius + 1):
                    xx = x + dx
                    if xx < 0 or xx >= width or (dx == 0 and dy == 0):
                        continue
                    if source[yy * width + xx][3] != 0:
                        found = True
                        break
                if found:
                    break

            if found:
                output[pos] = outline

    return output


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    body = kind + payload
    return (
        struct.pack(">I", len(payload))
        + body
        + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    )


def write_png(path: Path, width: int, height: int, pixels, grab):
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # PNG filter: None
        row = pixels[y*width:(y+1)*width]
        for r, g, b, a in row:
            raw.extend((r, g, b, a))

    payload = bytearray(b"\x89PNG\r\n\x1a\n")
    payload += png_chunk(
        b"IHDR",
        struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    )
    # GZDoom/ZDoom PNG sprite offsets.
    payload += png_chunk(b"grAb", struct.pack(">ii", int(grab[0]), int(grab[1])))
    payload += png_chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
    payload += png_chunk(b"IEND", b"")
    path.write_bytes(bytes(payload))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Render Mario local hand meshes into GZDoom PSprite layers"
    )
    parser.add_argument(
        "--activate",
        action="store_true",
        help="Create assets_local/mario_hands/READY after all layers render"
    )
    parser.add_argument(
        "--deactivate",
        action="store_true",
        help="Remove READY marker after rendering"
    )
    args = parser.parse_args()

    if not MANIFEST.is_file():
        raise RenderError(f"Pose manifest missing: {MANIFEST}")
    if not MESH_DIR.is_dir():
        raise RenderError(
            f"Hand meshes missing: {MESH_DIR}. "
            "Run scripts/extract-mario-hand-meshes-from-sm64-rom.py first."
        )

    spec = json.loads(MANIFEST.read_text(encoding="utf-8"))
    width, height = spec["canvas"]
    grab = spec.get("grab_offset", [0, 52])
    layers = spec["layers"]

    missing_specs = [name for name in EXPECTED if name not in layers]
    if missing_specs:
        raise RenderError(
            "Pose manifest missing layers: " + ", ".join(missing_specs)
        )

    DEST.mkdir(parents=True, exist_ok=True)
    meshes = {}

    for filename in EXPECTED:
        output = DEST / filename
        instances = layers[filename]
        pixels = render_layer(width, height, instances, meshes)
        pixels = add_glove_outline(pixels, width, height, radius=1)
        write_png(output, width, height, pixels, grab)

        visible = sum(1 for px in pixels if px[3])
        print(
            f"[NEXO] Rendered {filename}: "
            f"{len(instances)} hand instance(s), {visible} visible pixels"
        )

    missing_outputs = [
        name for name in EXPECTED if not (DEST / name).is_file()
    ]
    if missing_outputs:
        raise RenderError(
            "Renderer finished with missing outputs: "
            + ", ".join(missing_outputs)
        )

    if args.deactivate and READY.exists():
        READY.unlink()
        print("[NEXO] Mario first-person hands: DEACTIVATED")

    if args.activate:
        READY.write_text(
            "NEXO FP-MARIO prototype hand pack.\n"
            "Generated locally from user's SM64 hand meshes.\n"
            "Visual QA is required before FP-MARIO-1 PASS.\n",
            encoding="utf-8",
        )
        print("[NEXO] Mario first-person hands: PROTOTYPE ACTIVATED")
        print("[NEXO] Remove assets_local/mario_hands/READY to disable instantly.")
    else:
        print("[NEXO] Mario first-person hands: rendered but NOT activated.")
        print("[NEXO] Re-run with --activate when ready to test in GZDoom.")

    print(f"[NEXO] Output: {DEST}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RenderError, KeyError, ValueError, OSError) as exc:
        print(f"[NEXO] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
