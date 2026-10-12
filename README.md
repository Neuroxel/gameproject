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
