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
import re
import shlex
import shutil
import subprocess
import struct
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "bridge"
HANDOFF = BRIDGE / "runtime" / "handoff.json"
DOOM_LOG = BRIDGE / "runtime" / "doom.log"
MOD_SRC = ROOT / "doom" / "mod_src"
PK3 = ROOT / ".runtime" / "doom" / "nexo_doom.pk3"
LOCAL_MARIO_SFX = ROOT / "assets_local" / "mario_sfx"
LOCAL_MARIO_BODY = ROOT / "assets_local" / "mario_avatar"
OPENAL_SOFT_LIB = ROOT / ".runtime" / "doom" / "openal-soft" / "install" / "lib"
OPENAL_LOG = BRIDGE / "runtime" / "openal-soft.log"
NEXO_GZDOOM_CONFIG = BRIDGE / "runtime" / "gzdoom-nexo.ini"
USER_GZDOOM_CONFIG = Path.home() / "Library" / "Preferences" / "gzdoom.ini"
NEXO_STARTUP_CFG = BRIDGE / "runtime" / "nexo-startup.cfg"

MARIO_SFX_NAMES = ("jump", "hurt", "death", "use")
MARIO_SFX_OPTIONAL = (
    "portal", "celebrate",
    "jump2", "jump3", "backflip", "longjump", "stomp", "dive",
    "sideflip", "wallkick",
)
MARIO_SFX_EXTS = (".ogg", ".wav", ".flac")


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


def find_local_mario_sfx() -> dict[str, Path]:
    found: dict[str, Path] = {}
    for logical in MARIO_SFX_NAMES + MARIO_SFX_OPTIONAL:
        for ext in MARIO_SFX_EXTS:
            candidate = LOCAL_MARIO_SFX / f"{logical}{ext}"
            if candidate.exists():
                found[logical] = candidate
                break
    return found


def _wav_pcm16le_to_dmx(path: Path) -> tuple[bytes, int]:
    """Convert a standard PCM16LE WAV to native Doom DMX sound data.

    GZDoom 4.14.2 recognizes DMX before invoking ZMusic's generic decoder,
    so this bypasses the optional runtime libsndfile dependency while keeping
    the user's original local WAV untouched.
    """
    data = path.read_bytes()
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError(f"{path.name}: expected little-endian RIFF/WAVE")

    off = 12
    fmt: tuple[int, int, int, int] | None = None
    pcm = b""

    while off + 8 <= len(data):
        chunk_id = data[off:off + 4]
        chunk_size = struct.unpack_from("<I", data, off + 4)[0]
        start = off + 8
        end = start + chunk_size
        if end > len(data):
            raise ValueError(f"{path.name}: truncated WAV chunk {chunk_id!r}")

        payload = data[start:end]
        if chunk_id == b"fmt " and len(payload) >= 16:
            tag, channels, rate, _byte_rate, _align, bits = struct.unpack_from(
                "<HHIIHH", payload, 0
            )
            fmt = (tag, channels, rate, bits)
        elif chunk_id == b"data":
            pcm = payload

        off = end + (chunk_size & 1)

    if fmt is None or not pcm:
        raise ValueError(f"{path.name}: missing fmt/data WAV chunks")

    tag, channels, rate, bits = fmt
    if tag != 1 or bits != 16 or channels not in (1, 2) or rate <= 0:
        raise ValueError(
            f"{path.name}: DMX bridge requires PCM16LE mono/stereo; "
            f"got tag={tag} channels={channels} rate={rate} bits={bits}"
        )

    frame_bytes = channels * 2
    usable = len(pcm) - (len(pcm) % frame_bytes)
    if usable <= 0:
        raise ValueError(f"{path.name}: empty PCM payload")

    out = bytearray()
    if channels == 1:
        for (sample,) in struct.iter_unpack("<h", pcm[:usable]):
            out.append((sample + 32768) >> 8)
    else:
        for left, right in struct.iter_unpack("<hh", pcm[:usable]):
            sample = (left + right) // 2
            out.append((sample + 32768) >> 8)

    # Native Doom DMX sound header:
    # uint16 format=3, uint16 sample_rate, uint32 payload_length.
    header = struct.pack("<HHI", 3, rate, len(out))
    return header + bytes(out), rate


def build_pk3() -> tuple[Path, bool]:
    if not MOD_SRC.exists():
        raise FileNotFoundError(f"DOOM mod source missing: {MOD_SRC}")

    required = {
        "CVARINFO",
        "MAPINFO",
        "zscript.zc",
        "zscript/nexo_handoff.zs",
        "zscript/nexo_mario_player.zs",
    }

    PK3.parent.mkdir(parents=True, exist_ok=True)
    members: list[str] = []
    mario_sfx = find_local_mario_sfx()
    mario_sfx_ready = all(name in mario_sfx for name in MARIO_SFX_NAMES)

    with zipfile.ZipFile(PK3, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(MOD_SRC.rglob("*")):
            if path.is_file():
                arcname = path.relative_to(MOD_SRC).as_posix()
                zf.write(path, arcname)
                members.append(arcname)

        if mario_sfx:
            sndinfo_lines: list[str] = []
            runtime_targets: dict[str, str] = {}
            for logical, path in sorted(mario_sfx.items()):
                if path.suffix.lower() == ".wav":
                    dmx, rate = _wav_pcm16le_to_dmx(path)
                    arcname = f"sounds/nexo/mario/{logical}.dmx"
                    zf.writestr(arcname, dmx)
                    print(
                        f"[NEXO] Mario SFX native bridge: "
                        f"{path.name} -> {logical}.dmx ({rate} Hz, DMX8)"
                    )
                else:
                    arcname = f"sounds/nexo/mario/{path.name}"
                    zf.write(path, arcname)
                runtime_targets[logical] = arcname
                members.append(arcname)
                sndinfo_lines.append(f'nexo/mario/{logical} "{arcname}"')

            if mario_sfx_ready:
                # Optional movement cues remain functional even before the user
                # refreshes the expanded local extraction set.
                fallback_aliases = {
                    "portal": "use",
                    "celebrate": "jump",
                    "jump2": "jump",
                    "jump3": "jump",
                    "backflip": "jump2",
                    "longjump": "jump3",
                    "stomp": "use",
                    "dive": "use",
                    "sideflip": "backflip",
                    "wallkick": "jump2",
                }
                for logical, fallback in fallback_aliases.items():
                    if logical not in mario_sfx:
                        sndinfo_lines.append(
                            f"$alias nexo/mario/{logical} nexo/mario/{fallback}"
                        )

                # Avatar audio replaces Doom's *player voice* layer instead of
                # playing on top of it. World/weapon/enemy audio remains native.
                #
                # Jump is intentionally silent here: NexoMarioDoomPlayer plays
                # jump1/2/3 only after the engine confirms a real jump.
                hurt_target = runtime_targets["hurt"]
                death_target = runtime_targets["death"]
                stomp_target = runtime_targets.get("stomp")

                # Define both the inherited generic class and the dedicated
                # NEXO class. NexoMarioDoomPlayer sets SoundClass=nexo_mario;
                # keeping player too makes the dedupe resilient to skins or
                # temporary player-class transitions.
                for sound_class in ("player", "nexo_mario"):
                    for gender in ("male", "female", "neutral", "other"):
                        sndinfo_lines.append(
                            f"$playersound {sound_class} {gender} *jump DSEMPTY"
                        )
                        sndinfo_lines.append(
                            f"$playersound {sound_class} {gender} *usefail DSEMPTY"
                        )
                        sndinfo_lines.append(
                            f"$playersound {sound_class} {gender} *puzzfail DSEMPTY"
                        )
                        for pain_name in ("*pain100", "*pain75", "*pain50", "*pain25"):
                            sndinfo_lines.append(
                                f'$playersound {sound_class} {gender} {pain_name} "{hurt_target}"'
                            )
                        for death_name in ("*death", "*xdeath", "*crazydeath", "*wimpydeath"):
                            sndinfo_lines.append(
                                f'$playersound {sound_class} {gender} {death_name} "{death_target}"'
                            )
                        if stomp_target:
                            sndinfo_lines.append(
                                f'$playersound {sound_class} {gender} *grunt "{stomp_target}"'
                            )
                            sndinfo_lines.append(
                                f'$playersound {sound_class} {gender} *land "{stomp_target}"'
                            )
                        else:
                            sndinfo_lines.append(
                                f"$playersound {sound_class} {gender} *grunt DSEMPTY"
                            )
                            sndinfo_lines.append(
                                f"$playersound {sound_class} {gender} *land DSEMPTY"
                            )

            zf.writestr("SNDINFO", "\n".join(sndinfo_lines) + "\n")
            members.append("SNDINFO")

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
    if mario_sfx_ready:
        print("[NEXO] Mario identity SFX: core set embedded (jump/hurt/death/use)")
        print("[NEXO] Mario locomotion adapter: ON (triple/backflip/longjump/stomp/sideflip/wallkick/dive)")
    elif mario_sfx:
        missing_sfx = [name for name in MARIO_SFX_NAMES if name not in mario_sfx]
        print("[NEXO] Mario identity SFX: partial; disabled until complete: " + ", ".join(missing_sfx))
    else:
        print("[NEXO] Mario identity SFX: no local assets; hooks remain disabled")
    return PK3, mario_sfx_ready


def find_gzdoom(explicit: str | None, runtime_mode: str = "auto") -> tuple[Path, str]:
    if explicit:
        path = Path(explicit).expanduser()
        if path.exists():
            return path, "explicit"
        raise FileNotFoundError(f"Explicit GZDoom executable not found: {path}")

    env = os.getenv("NEXO_GZDOOM")
    if env:
        path = Path(env).expanduser()
        if path.exists():
            return path, "env"

    sdl_candidates = [
        ROOT / ".runtime/doom/gzdoom-sdl/build/gzdoom",
        ROOT / ".runtime/doom/gzdoom-sdl/build/Release/gzdoom",
    ]
    sdl_root = ROOT / ".runtime/doom/gzdoom-sdl/build"
    if sdl_root.exists():
        sdl_candidates.extend(sdl_root.glob("**/gzdoom"))

    cocoa_candidates = [
        ROOT / ".runtime/doom/gzdoom/GZDoom.app/Contents/MacOS/gzdoom",
        Path("/Applications/GZDoom.app/Contents/MacOS/gzdoom"),
        Path.home() / "Applications/GZDoom.app/Contents/MacOS/gzdoom",
    ]
    cocoa_root = ROOT / ".runtime/doom/gzdoom"
    if cocoa_root.exists():
        cocoa_candidates.extend(cocoa_root.glob("**/GZDoom.app/Contents/MacOS/gzdoom"))

    def first_existing(candidates: list[Path]) -> Path | None:
        for path in candidates:
            if path.exists() and path.is_file():
                return path
        return None

    if runtime_mode in {"auto", "sdl"}:
        sdl = first_existing(sdl_candidates)
        if sdl is not None:
            return sdl, "sdl"
        if runtime_mode == "sdl":
            raise FileNotFoundError(
                "SDL GZDoom not found. Run: bash scripts/setup-gzdoom-sdl-macos.sh"
            )

    if runtime_mode in {"auto", "cocoa"}:
        cocoa = first_existing(cocoa_candidates)
        if cocoa is not None:
            return cocoa, "cocoa"

    raise FileNotFoundError(
        "GZDoom executable not found. Run setup-doom-macos.sh "
        "or setup-gzdoom-sdl-macos.sh"
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


def _set_ini_key(text: str, section: str, key: str, value: str) -> str:
    """Set one key in one GZDoom INI section without destroying other settings."""
    lines = text.splitlines()
    section_header = f"[{section}]"
    section_index: int | None = None
    next_section = len(lines)

    for idx, line in enumerate(lines):
        if line.strip().lower() == section_header.lower():
            section_index = idx
            break

    if section_index is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend([section_header, f"{key}={value}"])
        return "\n".join(lines) + "\n"

    for idx in range(section_index + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            next_section = idx
            break

        match = re.match(r"^\s*([^#;][^=]*)=(.*)$", lines[idx])
        if match and match.group(1).strip().lower() == key.lower():
            lines[idx] = f"{key}={value}"
            return "\n".join(lines) + "\n"

    lines.insert(next_section, f"{key}={value}")
    return "\n".join(lines) + "\n"


def prepare_nexo_gzdoom_config(fullscreen: bool) -> Path:
    """Create an isolated early-load config for the SDL runtime.

    +set commands are intentionally not relied upon for the first SDL window:
    GZDoom loads GlobalSettings before constructing the video backend, while
    delayed console commands can run after the first window already exists.

    The first time, seed from the user's normal gzdoom.ini so bindings and
    preferences are preserved. Subsequent NEXO changes persist in the isolated
    runtime config.
    """
    NEXO_GZDOOM_CONFIG.parent.mkdir(parents=True, exist_ok=True)

    if not NEXO_GZDOOM_CONFIG.exists():
        if USER_GZDOOM_CONFIG.exists():
            shutil.copy2(USER_GZDOOM_CONFIG, NEXO_GZDOOM_CONFIG)
            print(f"[NEXO] Seeded isolated GZDoom config from: {USER_GZDOOM_CONFIG}")
        else:
            NEXO_GZDOOM_CONFIG.write_text("[GlobalSettings]\n", encoding="utf-8")
            print("[NEXO] Created clean isolated GZDoom config")

    text = NEXO_GZDOOM_CONFIG.read_text(encoding="utf-8", errors="replace")

    # These values must exist before SDL creates its first window/context.
    early_values = {
        "vid_fullscreen": "true" if fullscreen else "false",
        "win_maximized": "false",
        "vid_preferbackend": "0",
        "gl_es": "false",
        "use_joystick": "true",
        "m_blockcontrollers": "false",
    }

    if not fullscreen:
        early_values.update({
            "win_x": "-1",
            "win_y": "-1",
            "win_w": "1200",
            "win_h": "800",
        })

    for key, value in early_values.items():
        text = _set_ini_key(text, "GlobalSettings", key, value)

    NEXO_GZDOOM_CONFIG.write_text(text, encoding="utf-8")
    return NEXO_GZDOOM_CONFIG



def prepare_runtime_startup_script(render_prime: bool) -> Path | None:
    """Build delayed startup commands that must remain one command string.

    GZDoom's `wait` only delays the remainder of the *same* AddCommandString
    buffer. Separate command-line tokens such as `+wait 8 +togglemap` do not
    form a delayed chain: the standalone wait has no remainder to schedule.

    An exec file preserves the semicolon-separated chain as one string.
    """
    if not render_prime:
        return None

    NEXO_STARTUP_CFG.parent.mkdir(parents=True, exist_ok=True)
    NEXO_STARTUP_CFG.write_text(
        "wait 8; togglemap; wait 2; togglemap\n",
        encoding="utf-8",
    )
    return NEXO_STARTUP_CFG

def cvar_args(data: dict, mario_sfx_ready: bool, avatar_body_ready: bool) -> list[str]:
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
        "nexo_mario_sfx": "true" if mario_sfx_ready else "false",
        "nexo_mario_movement": "true",
        "nexo_perspective_transition": "true",
        "nexo_avatar_body_ready": "true" if avatar_body_ready else "false",
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
        "--runtime",
        choices=("auto", "sdl", "cocoa"),
        default="auto",
        help="GZDoom backend: prefer SDL, force SDL, or force official Cocoa build",
    )
    parser.add_argument(
        "--fullscreen",
        action="store_true",
        help=(
            "Opt in to fullscreen startup. SDL/macOS 26 currently defaults "
            "to NEXO's isolated windowed-safe startup profile."
        ),
    )
    parser.add_argument(
        "--no-render-prime",
        action="store_true",
        help=(
            "Disable NEXO's SDL first-frame automap prime. The prime is a "
            "temporary macOS 26 workaround for a black 3D view that wakes "
            "after the automap is toggled."
        ),
    )
    parser.add_argument(
        "--controller-setup",
        action="store_true",
        help="Open GZDoom joystick/gamepad configuration menu on launch",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print command only")
    args = parser.parse_args()

    handoff = load_handoff()
    pk3, mario_sfx_ready = build_pk3()
    avatar_body_ready = (LOCAL_MARIO_BODY / "READY").exists()
    gzdoom, runtime_kind = find_gzdoom(args.gzdoom, args.runtime)
    iwad = find_iwad(args.iwad)
    nexo_config = (
        prepare_nexo_gzdoom_config(fullscreen=args.fullscreen)
        if runtime_kind == "sdl"
        else None
    )

    render_prime = runtime_kind == "sdl" and not args.no_render_prime
    startup_script = prepare_runtime_startup_script(render_prime)

    if args.controller_setup and runtime_kind == "cocoa":
        print(
            "[NEXO] WARNING: GZDoom 4.14.2 Cocoa controller input is known "
            "broken on macOS 26 (triggers/D-pad)."
        )
        print(
            "[NEXO] Recommended: bash scripts/setup-gzdoom-sdl-macos.sh "
            "then rerun with --runtime sdl --controller-setup"
        )

    DOOM_LOG.parent.mkdir(parents=True, exist_ok=True)
    if DOOM_LOG.exists():
        DOOM_LOG.unlink()

    cmd = [
        str(gzdoom),
    ]

    if nexo_config is not None:
        cmd += ["-config", str(nexo_config)]

    cmd += [
        "+logfile", str(DOOM_LOG),
        "-iwad", str(iwad),
        "-file", str(pk3),

        # SDL controller runtime is compiled without Vulkan. GZDoom's global
        # default is vid_preferbackend=1 (Vulkan); if Vulkan is not compiled,
        # the SDL platform code otherwise falls through to the GLES renderer.
        # On macOS OpenGL 4.1 that renderer emits GLSL 330 while still using
        # legacy 'attribute'/'varying' tokens, causing the fatal Default shader
        # error observed on Apple M4. Force the normal desktop OpenGL renderer.
        "+set", "vid_preferbackend", "0",
        "+set", "gl_es", "false",
        "+set", "vid_fullscreen", "true" if args.fullscreen else "false",

        # Keep controls continuous across worlds. GZDoom has native
        # joystick/gamepad support on macOS; explicitly enable it so the
        # adapter does not silently fall back to keyboard/mouse.
        "+set", "use_joystick", "true",
        "+set", "m_blockcontrollers", "false",
    ]

    # Identity/campaign CVARs must be queued BEFORE +map. EventHandler
    # WorldLoaded/PlayerEntered reads them while the destination map starts.
    # Putting them after +map can leave the first world-load event seeing the
    # CVAR defaults (notably nexo_handoff=false / nexo_mario_sfx=false).
    cmd += cvar_args(handoff, mario_sfx_ready, avatar_body_ready)

    cmd += ["+map", args.map]

    # Empirical macOS 26 / SDL / Apple OpenGL workaround:
    # the 3D scene is black from startup, while entering automap renders
    # immediately and returning from it permanently wakes the normal 3D view.
    #
    # IMPORTANT: GZDoom's wait command only delays commands that follow it in
    # the same semicolon-separated command string. Therefore this must run
    # through one +exec script, not as separate +wait/+togglemap argv tokens.
    if startup_script is not None:
        cmd += ["+exec", str(startup_script)]

    if args.controller_setup:
        cmd += ["+menu_joystick"]

    print("[NEXO] Portal Fabric P1.2")
    print(f"[NEXO] Source: {handoff['source']['world']}")
    print(f"[NEXO] Target: {handoff['target']['world']}")
    print(f"[NEXO] GZDoom: {gzdoom}")
    print(f"[NEXO] Runtime backend: {runtime_kind.upper()}")
    print(f"[NEXO] IWAD: {iwad}")
    print(f"[NEXO] PK3: {pk3}")
    print(f"[NEXO] Mission log: {DOOM_LOG}")
    if nexo_config is not None:
        print(f"[NEXO] Isolated config: {nexo_config}")
        print(
            "[NEXO] Startup display: "
            + ("FULLSCREEN (explicit opt-in)" if args.fullscreen else "WINDOWED-SAFE")
        )
    print(f"[NEXO] Avatar identity: MARIO")
    print(f"[NEXO] Perspective: third-person source -> first-person DOOM")
    print(f"[NEXO] Mario voice SFX: {'ON' if mario_sfx_ready else 'OFF (local core set not present)'}")
    print(f"[NEXO] Third-person Mario body: {'READY' if avatar_body_ready else 'PENDING local avatar assets'}")
    if runtime_kind == "sdl":
        print("[NEXO] Renderer: desktop OpenGL forced (vid_preferbackend=0)")
        openal_local = list(OPENAL_SOFT_LIB.glob("libopenal*.dylib")) if OPENAL_SOFT_LIB.exists() else []
        print(f"[NEXO] OpenAL Soft runtime: {'READY' if openal_local else 'MISSING'}")
    print("[NEXO] Controller: joystick/gamepad forced ON")
    if runtime_kind == "sdl":
        print(
            "[NEXO] Renderer wake-up prime: "
            + ("OFF (--no-render-prime)" if args.no_render_prime else "ON (delayed automap prime)")
        )
        if startup_script is not None:
            print(f"[NEXO] Startup command script: {startup_script}")
    if args.controller_setup:
        print("[NEXO] Controller setup menu: requested")
    print("[NEXO] Command:")
    print(" ".join(shlex.quote(x) for x in cmd))

    if args.dry_run:
        return 0

    launch_env = os.environ.copy()

    if runtime_kind == "sdl":
        # Extra safety for locally built macOS runtime dependencies. The setup
        # script also bundles libzmusic.1.dylib next to the executable.
        dyld_paths = [
            str(OPENAL_SOFT_LIB),
            str(gzdoom.parent),
            str(ROOT / ".runtime/doom/gzdoom-sdl/build/zmusic/lib"),

            # The official Cocoa runtime already proved OpenAL works on this
            # machine. Expose its bundled runtime directory to the SDL build
            # as a compatibility source for libopenal and any sibling dylibs.
            str(ROOT / ".runtime/doom/gzdoom/GZDoom.app/Contents/MacOS"),
        ]
        existing = launch_env.get("DYLD_LIBRARY_PATH")
        if existing:
            dyld_paths.append(existing)
        launch_env["DYLD_LIBRARY_PATH"] = ":".join(dyld_paths)
        launch_env["ALSOFT_DRIVERS"] = "core"
        launch_env["ALSOFT_LOGLEVEL"] = "3"
        launch_env["ALSOFT_LOGFILE"] = str(OPENAL_LOG)
        print(f"[NEXO] DYLD_LIBRARY_PATH: {launch_env['DYLD_LIBRARY_PATH']}")
        print(f"[NEXO] OpenAL backend forced: CoreAudio")
        print(f"[NEXO] OpenAL log: {OPENAL_LOG}")

    subprocess.Popen(cmd, cwd=str(ROOT), env=launch_env)
    print("[NEXO] GZDoom launched.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
