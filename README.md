# NEXO Mashup Lab

## Estado actual

**M1.1 — recuperación de activación**

La primera versión de M1 tenía un bug en la detección de Bob-omb Battlefield: el mod seguía cargado, pero interpretaba el nivel como fuera de alcance y ocultaba bola + HUD.

Ya está corregido usando el estado Lua expuesto del jugador local:

```
gNetworkPlayers[0].currCourseNum
gNetworkPlayers[0].currLevelNum
```

## Actualizar

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

## Verificación inmediata

### Castillo / hub
Debe seguir sin aparecer la bola ni el HUD M1.

### Bob-omb Battlefield
Deben aparecer de nuevo:

- bola;
- HUD `M1 CARGA IMPOSIBLE`;
- MASA/VIS;
- checklist de carga.

Si eso vuelve, la regresión está recuperada y continúa la prueba normal de M1:

- rigid attachments;
- COMPACT;
- 5 monedas;
- 4 Goombas;
- 2 Bob-ombs;
- masa 3.80;
- regreso al NEXO Gate;
- handoff preparado a DOOM.


## Portal Fabric bridge

M1 ya alcanza `HANDOFF PREPARADO -> DOOM`.

El siguiente componente está en:

```
bridge/nexo_handoff.py
```

Después de completar M1:

```bash
python3 bridge/nexo_handoff.py --print
```

Esto exporta un manifiesto JSON neutral que será la entrada del futuro adapter DOOM.


## Siguiente gate: DOOM

```bash
git pull
bash scripts/setup-doom-macos.sh
python3 bridge/run_doom.py --dry-run
python3 bridge/run_doom.py
```

El primer adapter usa GZDoom + Freedoom Phase 2 por defecto, o tu propio Doom II IWAD con `--iwad`.


### Handoff durability fix

Portal handoffs are now durable across SM64 level reloads.

For older saves affected by the previous bug, `nexo_handoff.py` can recover the last complete payload even if `handoff_pending` was reset to 0. `run_doom.py` can also reuse an existing validated `bridge/runtime/handoff.json`.


### macOS setup robustness

El setup de DOOM evita opciones GNU de `find` no portables en macOS y valida ZIP, `GZDoom.app`, ejecutable e IWAD antes de declarar el runtime preparado.

Orden correcto:

```bash
git pull
bash scripts/setup-doom-macos.sh
python3 bridge/run_doom.py --dry-run
python3 bridge/run_doom.py
```


### GZDoom ZScript entry point

The DOOM PK3 now uses a root `zscript.zc` entry point and validates these members before launch:

- `CVARINFO`
- `MAPINFO`
- `zscript.zc`
- `zscript/nexo_handoff.zs`

This prevents launching a PK3 whose handler class cannot be discovered.


## M2 — DOOM: ESTABILIZA LA BRECHA

Después del handoff SM64 -> DOOM:

1. elimina 8 hostiles;
2. aparecerá `BRECHA ESTABILIZADA`;
3. busca la salida normal de MAP01;
4. al salir, GZDoom escribe un handoff DOOM -> NEXO_HUB.

El launcher guarda la consola en:

```
bridge/runtime/doom.log
```

Después de salir de MAP01:

```bash
python3 bridge/doom_handoff.py --print
```

Debe generar:

```
bridge/runtime/handoff_from_doom.json
```

Este manifest será la entrada del tercer mundo.


## Gamepad continuity

GZDoom supports controllers on macOS. NEXO now forces controller input enabled.

For a one-time controller setup:

```bash
python3 bridge/run_doom.py --controller-setup
```

After mapping the device once, normal launches remain:

```bash
python3 bridge/run_doom.py
```

M2 is now restricted to MAP01, so entering MAP02 no longer reapplies the original
SM64 handoff or restarts the mission.


### GZDoom runtime compatibility

NEXO currently pins GZDoom 4.14.2. MAP scoping uses ZScript's
case-insensitive `~==` operator:

```zscript
Level.MapName ~== "MAP01"
```

Avoid newer String helper APIs unless tested against 4.14.2.


## macOS 26 controller workaround

The official GZDoom 4.14.2 Cocoa backend has a known upstream controller bug on
macOS 26 affecting triggers and D-pad.

Probe the controller:

```bash
python3 bridge/controller_probe.py
```

Build the same GZDoom version with its SDL2 backend:

```bash
bash scripts/setup-gzdoom-sdl-macos.sh
```

Then test:

```bash
python3 bridge/run_doom.py --runtime sdl --controller-setup
```

Normal `--runtime auto` prefers SDL once that build exists.


### SDL build dependency note

For GZDoom 4.14.2, ZMusic is supplied exactly as in upstream CI:
`zmusic-1.1.14-macos-arm.tar.xz` from the GZDoom `ci_deps` release, with
`CMAKE_PREFIX_PATH` pointed at the extracted package.

The setup script deliberately avoids upgrading already-installed Homebrew
formulae. A temporary ghcr.io/Homebrew outage therefore should not block the
build when cmake, ninja, SDL2, and libvpx are already present.


### Repair an already-built SDL runtime

If the SDL build finished but macOS reports:

```
Library not loaded: @rpath/libzmusic.1.dylib
```

do **not** rebuild GZDoom. Repair the app bundle:

```bash
git pull
bash scripts/repair-gzdoom-sdl-macos.sh
python3 bridge/run_doom.py --runtime sdl --controller-setup
```

The repair copies the already downloaded ZMusic dylib into GZDoom's
`Contents/MacOS` directory under the runtime filename the executable requests.


### SDL renderer fix on macOS

The SDL build must launch with desktop OpenGL explicitly selected:

```
vid_preferbackend = 0
gl_es = false
```

Why: GZDoom 4.14.2 defaults to Vulkan (`vid_preferbackend=1`). If Vulkan was
not compiled into the local SDL build, its SDL platform path can select the GLES
renderer, which fails on Apple's OpenGL 4.1 core context with legacy
`attribute`/`varying` shader syntax.

`bridge/run_doom.py` now forces the correct desktop OpenGL backend for SDL.
No rebuild is required.


### Fix raw SDL axis mapping on macOS controllers

GZDoom 4.14.2's SDL backend still uses raw joystick axis ordering. On some
Xbox-compatible Bluetooth controllers this can expose a trigger as a look axis,
causing constant upward pitch or making LT control vertical look.

Apply NEXO's small backport of SDL's standardized GameController API:

```bash
git pull
bash scripts/patch-gzdoom-sdl-gamecontroller.sh
python3 bridge/run_doom.py --runtime sdl --controller-setup
```

The patch rebuilds only the changed input objects plus relinking and then
re-runs the runtime dylib repair.


## Persistent Mario identity across worlds

NEXO now separates:
- avatar identity;
- camera perspective;
- world mechanics;
- audio identity.

SM64 -> DOOM is formally:
`Mario / third person -> Mario identity / first person`.

See:
- `PERSPECTIVE_NEXO.md`
- `AUDIO_IDENTITY_NEXO.md`

### Restore audio in the SDL runtime

```bash
git pull
bash scripts/patch-gzdoom-sdl-audio.sh
python3 bridge/run_doom.py --runtime sdl
```

### Local Mario action/voice SFX

The repository does not distribute Nintendo audio.

Provide your own local core set and import it:

```bash
bash scripts/import-mario-sfx-local.sh /path/to/mario_sfx
python3 bridge/run_doom.py --runtime sdl
```

Required names: `jump`, `hurt`, `death`, `use` in OGG/WAV/FLAC.


## Current audio recovery path

For the existing silent SDL runtime:

```bash
git pull
bash scripts/patch-gzdoom-sdl-audio.sh
python3 bridge/run_doom.py --runtime sdl
```

This builds project-local OpenAL Soft, re-enables GZDoom's dynamic OpenAL
loader, bundles `libopenal.1.dylib`, and forces the CoreAudio backend.

If sound still fails, inspect:

```
bridge/runtime/openal-soft.log
```

## Extract Mario voice identity from your own SM64 ROM

Do not download third-party Mario voice packs. Use the ROM you already own:

```bash
bash scripts/extract-mario-sfx-from-sm64-rom.sh /path/to/baserom.us.z64 us
python3 bridge/run_doom.py --runtime sdl
```

The extracted files stay local and gitignored.


If the OpenAL Soft patch still launches silently, run:

```bash
bash scripts/diagnose-doom-audio.sh
```

It reports the bundled dylib, GZDoom CMake audio flags, a direct CoreAudio
device probe, and the last OpenAL Soft runtime log.


### OpenAL Soft macOS compiler recovery

If the audio patch fails with missing `pthread.h`, `Availability.h`,
`sched.h`, or `time.h` while the command line points at Homebrew LLVM,
update and rerun:

```bash
git pull
bash scripts/patch-gzdoom-sdl-audio.sh
```

The OpenAL builder now forces Apple Clang and the active macOS SDK, and removes
only the stale OpenAL build cache created with the wrong compiler.


### AppleClang 21 / OpenAL Soft 1.25.2

On macOS 26 with AppleClang 21, OpenAL Soft 1.25.2 may fail in
`coreaudio.cpp` with:

```
attribute 'nonblocking' should not be added via type conversion
[-Werror,-Wfunction-effects]
```

The project setup now disables OpenAL Soft's optional
`-Wfunction-effects` diagnostic for this pinned build and explicitly keeps
`ALSOFT_WERROR=OFF`. No source-code behavior is changed.


### Fix black SDL startup window + centered arrival view

The pinned GZDoom 4.14.2 runtime now carries a narrow backport of upstream
commit `c3fb744f47fe` ("Fix phantom window freezing desktop on some systems").

For an existing build:

```bash
git pull
bash scripts/patch-gzdoom-sdl-startup.sh
python3 bridge/run_doom.py --runtime sdl
```

The DOOM adapter also centers Mario's first-person pitch once on arrival so a
previous/stale extreme view angle cannot start the mission looking at the
ceiling.

### Mario SFX extractor on stock macOS Bash

`scripts/extract-mario-sfx-from-sm64-rom.sh` is now compatible with Apple's
Bash 3.2. With no arguments it scans common local folders and auto-detects a
known vanilla SM64 region by SHA-1:

```bash
bash scripts/extract-mario-sfx-from-sm64-rom.sh
```

Or provide your own ROM explicitly:

```bash
bash scripts/extract-mario-sfx-from-sm64-rom.sh /path/to/baserom.us.z64 us
```


### macOS SDL black-screen safe startup

The NEXO SDL launcher now defaults to an isolated **windowed-safe** startup
profile because fullscreen startup can produce a black window with delayed
controller focus on macOS 26.

Normal test:

```bash
git pull
python3 bridge/run_doom.py --runtime sdl
```

The launcher creates `bridge/runtime/gzdoom-nexo.ini`, seeded once from the
user's normal `~/Library/Preferences/gzdoom.ini` when present, and forces
windowed OpenGL before SDL constructs its first window.

Fullscreen remains available only as an explicit test:

```bash
python3 bridge/run_doom.py --runtime sdl --fullscreen
```

Do not use `--fullscreen` as the baseline until the macOS first-present/focus
regression is closed.


### SDL black 3D view: automatic first-frame prime

The remaining macOS 26 SDL issue is no longer fullscreen-specific: even the
windowed-safe profile can start with a black 3D view, while automap renders and
returning from automap fixes the view permanently.

NEXO now automates that proven recovery immediately after map startup:

```
wait 8
togglemap
wait 2
togglemap
```

Normal launch:

```bash
git pull
python3 bridge/run_doom.py --runtime sdl
```

Disable only for diagnosis:

```bash
python3 bridge/run_doom.py --runtime sdl --no-render-prime
```

### Mario SFX launch-order correction

NEXO identity CVARs are now queued before `+map`. This ensures
`WorldLoaded` sees `nexo_handoff=true` and, when the local core WAV set is
present, `nexo_mario_sfx=true`.

The runtime log now prints the identity gate and a line when the portal cue is
requested.


### 2026-10-13: corrected startup prime and EventHandler order

Two exact g4.14.2 semantics matter for the current SDL runtime:

- `wait` delays only the remainder of the same semicolon-separated console
  string. NEXO therefore runs the renderer wake-up as one runtime cfg line,
  not as separate `+wait/+togglemap` argv entries.
- `PlayerEntered` runs before `WorldLoaded` on a fresh level. NEXO derives
  MAP01/identity state directly in `PlayerEntered` before applying M2 or
  Mario identity behavior.

Normal retest remains:

```bash
git pull
python3 bridge/run_doom.py --runtime sdl
```

The runtime should now self-toggle automap briefly without user input, and
MAP01 should log the Mario SFX probe plus play the arrival cue.
