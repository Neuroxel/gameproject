#!/usr/bin/env python3
"""
Render a local neutral Mario full-body preview from AVATAR-BODY-1 OBJ parts.

This is deliberately a SOURCE/POSE QA renderer:
- no third-party packages;
- no runtime READY marker;
- no DOOM third-person activation;
- no Nintendo geometry committed.

The goal is to prove that the extracted part hierarchy can be assembled into a
coherent Mario-shaped external avatar before portal/death-camera integration.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
BODY_ROOT = ROOT / "assets_local" / "mario_avatar"
MESH_DIR = BODY_ROOT / "meshes"
MANIFEST = BODY_ROOT / "body_source_manifest.json"
HAND_RENDERER = ROOT / "scripts" / "render-mario-weapon-hands-local.py"

WIDTH = 512
HEIGHT = 512
MARGIN = 34

COLORS = {
    "blue": (44, 69, 181, 255),
    "red_blue": (191, 39, 35, 255),
    "skin_red_brown": (238, 173, 123, 255),
    "red": (191, 39, 35, 255),
    "white": (246, 246, 240, 255),
    "brown": (102, 57, 34, 255),
}

# Static external-view pose families. SM64 geometry bones extend along local +X.
# These are local QA poses, not animation data and not a replacement for the
# source skeleton.
POSES = {
    "neutral": {
        "left_arm": 180.0,
        "right_arm": 180.0,
        "left_thigh": 180.0,
        "right_thigh": 180.0,
    },
    "portal": {
        # Forward/transition silhouette: arms angle toward the portal while
        # legs keep a readable running/brace stance.
        "left_arm": 148.0,
        "right_arm": 212.0,
        "left_forearm": 332.0,
        "right_forearm": 28.0,
        "left_thigh": 166.0,
        "right_thigh": 194.0,
        "left_leg": 18.0,
        "right_leg": 342.0,
    },
    "death": {
        # External death/collapse source pose. Runtime death animation remains
        # a later integration concern.
        "root": 88.0,
        "left_arm": 162.0,
        "right_arm": 198.0,
        "left_thigh": 170.0,
        "right_thigh": 190.0,
    },
}


class RenderError(RuntimeError):
    pass


def load_renderer_helper():
    spec = importlib.util.spec_from_file_location(
        "nexo_hand_renderer_helper", HAND_RENDERER
    )
    if spec is None or spec.loader is None:
        raise RenderError("Could not load local PNG renderer helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_obj(path: Path):
    vertices = []
    faces = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("v "):
            _, x, y, z = line.split()[:4]
            vertices.append((float(x), float(y), float(z)))
        elif line.startswith("f "):
            items = line.split()[1:4]
            faces.append(tuple(int(v.split("/", 1)[0]) - 1 for v in items))
    if not vertices or not faces:
        raise RenderError(f"Empty OBJ: {path}")
    return vertices, faces


def mat_identity():
    return (
        (1.0, 0.0, 0.0, 0.0),
        (0.0, 1.0, 0.0, 0.0),
        (0.0, 0.0, 1.0, 0.0),
        (0.0, 0.0, 0.0, 1.0),
    )


def mat_mul(a, b):
    return tuple(
        tuple(sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4))
        for r in range(4)
    )


def mat_translate(x, y, z):
    m = [list(row) for row in mat_identity()]
    m[0][3] = x
    m[1][3] = y
    m[2][3] = z
    return tuple(tuple(row) for row in m)


def mat_rot_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (
        (c, -s, 0.0, 0.0),
        (s, c, 0.0, 0.0),
        (0.0, 0.0, 1.0, 0.0),
        (0.0, 0.0, 0.0, 1.0),
    )


def transform_point(m, v):
    x, y, z = v
    return (
        m[0][0]*x + m[0][1]*y + m[0][2]*z + m[0][3],
        m[1][0]*x + m[1][1]*y + m[1][2]*z + m[1][3],
        m[2][0]*x + m[2][1]*y + m[2][2]*z + m[2][3],
    )


def shade(color, factor):
    r, g, b, a = color
    return (
        max(0, min(255, int(r * factor))),
        max(0, min(255, int(g * factor))),
        max(0, min(255, int(b * factor))),
        a,
    )


def render_pose(pose_name: str, output: Path) -> int:
    pose_z_deg = POSES[pose_name]

    if not MANIFEST.is_file():
        raise RenderError(
            f"Body source manifest missing: {MANIFEST}. "
            "Run scripts/extract-mario-body-parts-from-sm64-rom.py first."
        )

    spec = json.loads(MANIFEST.read_text(encoding="utf-8"))
    parts = spec.get("parts", {})
    skeleton = spec.get("skeleton", {})
    if not parts or not skeleton:
        raise RenderError("Body source manifest has no parts/skeleton")

    meshes = {}
    for name, meta in parts.items():
        path = MESH_DIR / meta["path"]
        meshes[name] = load_obj(path)

    world_mats = {}

    def resolve_node(node_name):
        if node_name in world_mats:
            return world_mats[node_name]

        node = skeleton[node_name]
        parent_name = node.get("parent")
        parent = mat_identity() if parent_name is None else resolve_node(parent_name)

        ox, oy, oz = node.get("offset", [0, 0, 0])
        local = mat_translate(float(ox), float(oy), float(oz))

        pose_deg = pose_z_deg.get(node_name, 0.0)
        if pose_deg:
            local = mat_mul(local, mat_rot_z(pose_deg))

        world = mat_mul(parent, local)
        world_mats[node_name] = world
        return world

    transformed_parts = []
    projected_raw = []

    for node_name, node in skeleton.items():
        part_name = node.get("part")
        if not part_name or part_name not in meshes:
            continue

        matrix = resolve_node(node_name)
        vertices, faces = meshes[part_name]
        world_vertices = [transform_point(matrix, v) for v in vertices]

        # Front external view: SM64 Z becomes horizontal screen direction,
        # SM64 X becomes vertical, and Y is depth.
        projected = [(v[2], -v[0], -v[1]) for v in world_vertices]
        projected_raw.extend(projected)
        transformed_parts.append((node_name, part_name, projected, faces))

    if not projected_raw:
        raise RenderError("No body geometry projected")

    min_x = min(p[0] for p in projected_raw)
    max_x = max(p[0] for p in projected_raw)
    min_y = min(p[1] for p in projected_raw)
    max_y = max(p[1] for p in projected_raw)

    span_x = max(1.0, max_x - min_x)
    span_y = max(1.0, max_y - min_y)
    scale = min(
        (WIDTH - 2*MARGIN) / span_x,
        (HEIGHT - 2*MARGIN) / span_y,
    )

    center_x = (min_x + max_x) * 0.5
    center_y = (min_y + max_y) * 0.5

    triangles = []
    for node_name, part_name, projected, faces in transformed_parts:
        family = parts[part_name].get("color_family", "white")
        base_color = COLORS.get(family, COLORS["white"])

        for a, b, c in faces:
            p0, p1, p2 = projected[a], projected[b], projected[c]
            sx0 = WIDTH*0.5 + (p0[0] - center_x) * scale
            sy0 = HEIGHT*0.5 + (p0[1] - center_y) * scale
            sx1 = WIDTH*0.5 + (p1[0] - center_x) * scale
            sy1 = HEIGHT*0.5 + (p1[1] - center_y) * scale
            sx2 = WIDTH*0.5 + (p2[0] - center_x) * scale
            sy2 = HEIGHT*0.5 + (p2[1] - center_y) * scale

            depth = (p0[2] + p1[2] + p2[2]) / 3.0

            # Cheap directional shading from projected triangle orientation.
            cross = (sx1-sx0)*(sy2-sy0) - (sy1-sy0)*(sx2-sx0)
            factor = 0.82 if cross < 0 else 1.0
            color = shade(base_color, factor)

            triangles.append((
                depth,
                (sx0, sy0, p0[2]),
                (sx1, sy1, p1[2]),
                (sx2, sy2, p2[2]),
                color,
            ))

    # Back-to-front painter pass; body preview does not need gameplay z-buffer.
    triangles.sort(key=lambda item: item[0])

    helper = load_renderer_helper()
    pixels = [(0, 0, 0, 0)] * (WIDTH * HEIGHT)
    zbuf = [float("-inf")] * (WIDTH * HEIGHT)

    for _depth, p0, p1, p2, color in triangles:
        helper.draw_triangle(
            pixels, zbuf, WIDTH, HEIGHT,
            p0, p1, p2, color
        )

    pixels = helper.add_glove_outline(pixels, WIDTH, HEIGHT, radius=1)
    BODY_ROOT.mkdir(parents=True, exist_ok=True)
    helper.write_png(output, WIDTH, HEIGHT, pixels, (0, 0))

    visible = sum(1 for px in pixels if px[3])
    print(f"[NEXO] Mario full-body {pose_name} preview: RENDERED")
    print(f"[NEXO] Output: {output}")
    print(f"[NEXO] Visible pixels: {visible}")
    return visible


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Render local Mario full-body QA poses"
    )
    parser.add_argument(
        "--pose",
        choices=sorted(POSES),
        default=None,
        help="Render only one QA pose; omitted renders neutral/portal/death",
    )
    args = parser.parse_args()

    pose_names = [args.pose] if args.pose else ["neutral", "portal", "death"]

    for pose_name in pose_names:
        output = BODY_ROOT / f"body_{pose_name}_preview.png"
        render_pose(pose_name, output)

    print("[NEXO] Runtime READY was NOT created.")
    print("[NEXO] Body poses require visual QA before external-camera integration.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RenderError, OSError, ValueError, KeyError) as exc:
        print(f"[NEXO] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
