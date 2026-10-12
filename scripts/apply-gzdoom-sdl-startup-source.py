#!/usr/bin/env python3
"""
Backport the GZDoom SDL startup-window fix to the pinned g4.14.2 source tree.

Upstream reference:
ZDoom/gzdoom commit c3fb744f47fe
"Fix phantom window freezing desktop on some systems" (2025-08-21).

The patch is deliberately narrow:
- create the SDL OpenGL window hidden;
- show it only when the video mode is actually applied;
- force the first mode application after D_CheckNetGame.

This avoids the black/phantom initial window observed on macOS 26 while
preserving the pinned g4.14.2 renderer and NEXO controller backport.
"""

from __future__ import annotations

from pathlib import Path
import sys


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f"[NEXO] Already patched: {label}")
        return text
    if old not in text:
        raise RuntimeError(f"Cannot locate expected g4.14.2 source block: {label}")
    print(f"[NEXO] Applying: {label}")
    return text.replace(old, new, 1)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: apply-gzdoom-sdl-startup-source.py /path/to/gzdoom/source", file=sys.stderr)
        return 2

    src = Path(sys.argv[1]).expanduser().resolve()
    sdl = src / "src/common/platform/posix/sdl/sdlglvideo.cpp"
    dmain = src / "src/d_main.cpp"

    if not sdl.exists() or not dmain.exists():
        raise FileNotFoundError("Pinned GZDoom source tree is incomplete")

    text = sdl.read_text(encoding="utf-8")

    text = replace_once(
        text,
        """SystemBaseFrameBuffer::SystemBaseFrameBuffer (void *, bool fullscreen)
: DFrameBuffer (vid_defwidth, vid_defheight)
{
	if (Priv::window != nullptr)
	{
		SDL_SetWindowFullscreen(Priv::window, fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
		SDL_ShowWindow(Priv::window);
	}
}
""",
        """SystemBaseFrameBuffer::SystemBaseFrameBuffer (void *, bool fullscreen)
: DFrameBuffer (vid_defwidth, vid_defheight)
{
}
""",
        "defer initial SDL window show",
    )

    text = replace_once(
        text,
        """void SystemBaseFrameBuffer::ToggleFullscreen(bool yes)
{
	SDL_SetWindowFullscreen(Priv::window, yes ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
""",
        """void SystemBaseFrameBuffer::ToggleFullscreen(bool yes)
{
	SDL_ShowWindow(Priv::window);
	SDL_SetWindowFullscreen(Priv::window, yes ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0);
""",
        "show window when video mode is applied",
    )

    text = replace_once(
        text,
        """		Priv::CreateWindow(SDL_WINDOW_OPENGL | (fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0));
""",
        """		Priv::CreateWindow(SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | (fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0));
""",
        "create OpenGL window hidden",
    )

    sdl.write_text(text, encoding="utf-8")

    text = dmain.read_text(encoding="utf-8")
    text = replace_once(
        text,
        """		if (!D_CheckNetGame ())
		{
			return 0;
		}
	}

	// [SP] Force vanilla transparency auto-detection to re-detect our game lumps now
""",
        """		if (!D_CheckNetGame ())
		{
			return 0;
		}
		setmodeneeded = true;
	}

	// [SP] Force vanilla transparency auto-detection to re-detect our game lumps now
""",
        "force first video mode application",
    )
    dmain.write_text(text, encoding="utf-8")

    print("[NEXO] SDL startup-window backport applied.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
