# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Estado previo confirmado

- A0-A6 — PASS funcional.
- A6.5 — FAIL: bola como autoridad física/collider rompía navegación.
- A6.6 — PASS: Mario conserva física y navegación nativa.
- A6.7 — PASS funcional: giro visual natural.
- A6.8 / A7-A8 slice 1 — PASS lógico:
  - monedas;
  - Goombas;
  - Bob-ombs por threshold;
  - crecimiento;
  - navegación preservada.

## M1 — regresión de activación detectada

La primera implementación de M1 introdujo una regresión:

- dentro de Bob-omb Battlefield no aparecía la bola;
- tampoco aparecía el HUD de M1;
- el juego base continuaba funcionando.

### Causa

El gate de mundo utilizaba:

`gCurrCourseNum == COURSE_BOB`

`gCurrCourseNum` es un global interno del engine C, pero no es la fuente Lua canónica usada para el estado del jugador local.

En Lua, `NetworkPlayer.currCourseNum` y `NetworkPlayer.currLevelNum` sí están expuestos explícitamente como campos read-only.

Por tanto la condición fallaba silenciosamente y M1 se auto-desactivaba.

## M1.1 — ACTIVE

El detector de mundo ahora usa:

```
gNetworkPlayers[0].currCourseNum == COURSE_BOB
OR
gNetworkPlayers[0].currLevelNum == LEVEL_BOB
```

La redundancia curso+nivel evita una desactivación silenciosa por diferencias de sincronización.

### Invariantes preservados

No se modificó:

- física de Mario;
- navegación;
- rigid attachments;
- compact mode;
- requisitos M1;
- NEXO Gate;
- handoff a DOOM.

El único cambio funcional es la detección correcta del mundo donde M1 debe estar activo.

## Criterio de recuperación inmediato

Al entrar en Bob-omb Battlefield:

1. debe volver a aparecer HUD `M1 CARGA IMPOSIBLE`;
2. debe aparecer la bola;
3. la misión debe comenzar con requisitos;
4. castillo/hub debe continuar sin bola ni HUD del proyecto.

Después de recuperar este baseline se continúa evaluando:
- rigid attachments;
- compact mode;
- NEXO Gate;
- misión completa.

## Portal Fabric

Se mantiene la arquitectura definida en `PORTAL_FABRIC.md`.

Primer handoff previsto:
SM64 -> DOOM.

No integrar DOOM hasta M1 PASS.


## M1 — PASS FUNCIONAL / VISUAL QA PENDIENTE

Evidencia del usuario:

- bola + HUD aparecen correctamente dentro de Bob-omb Battlefield;
- no aparecen en el castillo;
- M1 se completa;
- score y best score funcionan;
- handoff se guarda con destino DOOM;
- compact mode funciona;
- thresholds y absorción funcionan;
- navegación permanece estable.

### Deuda visual congelada

Los attachments todavía muestran variación perceptible de distancia:
- algunos quedan demasiado separados;
- otros demasiado embebidos;
- el placeholder del NEXO Gate (estrella transparente) no tiene valor visual final.

Estas tareas NO bloquean la transición P1.

Se registran como `VISUAL-QA-ATTACHMENTS` y `VISUAL-QA-GATE`.

## Portal Fabric P1 — bridge externo iniciado

Se agrega:

- `bridge/nexo_handoff.py`;
- `bridge/README.md`;
- `bridge/nexo-portal-handoff-v1.schema.json`.

El bridge lee los `.sav` de SM64CoopDX en macOS, detecta `handoff_pending=1` y produce un manifiesto neutral JSON.

Aún no lanza DOOM.

Próximo gate técnico:
**P1.1 — leer handoff real desde el Mac y generar handoff.json**.

Después:
**P1.2 — elegir/instalar runtime DOOM y crear doom_adapter mínimo**.


## Portal Fabric P1.1 — PASS

El usuario ejecutó `bridge/nexo_handoff.py --print` tras completar M1.

Resultado:
- pending handoff encontrado;
- target DOOM correcto;
- manifest JSON generado correctamente.

## Portal Fabric P1.2 — ACTIVE: DOOM adapter mínimo

Runtime seleccionado: **GZDoom 4.14.2**.

IWAD de prueba legal: **Freedoom Phase 2 0.13.0**.

Componentes:
- `scripts/setup-doom-macos.sh`
- `bridge/run_doom.py`
- `doom/mod_src/CVARINFO`
- `doom/mod_src/MAPINFO`
- `doom/mod_src/ZSCRIPT`
- `doom/mod_src/zscript/nexo_handoff.zs`
- `doom/README.md`

### Semántica v0.1

- monedas -> ArmorBonus;
- Goombas -> HealthBonus;
- Bob-ombs -> RocketAmmo;
- >=2 Bob-ombs -> RocketLauncher;
- masa >=4.0 -> Backpack;
- score/carga -> mensaje NEXO visible.

### Gate P1.2

PASS si:
1. setup localiza/prepara GZDoom e IWAD;
2. dry-run genera comando válido;
3. GZDoom abre MAP01;
4. PK3 carga sin error;
5. aparece NEXO HANDOFF;
6. recursos recibidos corresponden al manifest;
7. jugar DOOM sigue siendo normal.

No iniciar transición visual P2/P3 antes de P1.2 PASS.


## P1.2 regression — handoff persistence fixed

Observed error:
`No pending NEXO handoff found` when running `run_doom.py --dry-run` after a previously successful M1 handoff.

### Root cause

`reset_progress()` in the SM64 mod wrote:

`handoff_pending = 0`

and `on_level_init()` invokes `reset_progress()`.

Therefore a valid completed handoff could be erased merely by changing/reloading levels before the external bridge consumed it.

### Fix

1. SM64 no longer clears `handoff_pending` on reset/level load.
2. Completed handoff remains durable until overwritten by a newer completed mission.
3. Bridge v0.2 can recover legacy completed payloads whose pending bit was incorrectly cleared.
4. DOOM launcher v0.2 reuses an existing validated `handoff.json` if a refresh from SM64 storage is unavailable.

This makes Portal Fabric state durable across engine/session boundaries.

### Immediate recovery

The user should not need to replay M1 if either:
- the old save still contains the handoff payload fields; or
- `bridge/runtime/handoff.json` already exists from the previously successful export.


## P1.2 setup macOS — hardening

Tras recuperar correctamente un handoff legado, el dry-run llegó al gate de runtime y reportó `GZDoom executable not found`.

Esto confirma que:
- bridge/handoff = operativo;
- fallo actual = runtime local todavía no preparado.

Se endureció `scripts/setup-doom-macos.sh`:
- sin `find -maxdepth` GNU/no portable;
- valida dependencias;
- valida ZIPs antes de extraer;
- detecta GZDoom.app recursivamente;
- valida/chmod del ejecutable;
- valida freedoom2.wad.


## P1.2 GZDoom load regression — ZScript entry point fixed

Observed:
- GZDoom/Freedoom start correctly;
- NEXO PK3 is loaded;
- MAPINFO is parsed;
- `script parsing took 0.00 ms`;
- fatal: `unknown event handler class NexoHandoffHandler`.

Diagnosis:
MAPINFO referenced the handler, but the PK3 ZScript entry point was not being indexed/parsed.

Fix:
- replace extensionless root `ZSCRIPT` with PK3-style root `zscript.zc`;
- keep implementation in `zscript/nexo_handoff.zs`;
- launcher now validates exact PK3 members before launching.

Expected next boot:
ZScript parsing must be non-zero or at least progress to actual ZScript diagnostics instead of `unknown event handler class`.


## P1.2 macOS checkout regression — case collision identified

A dry-run after the ZScript entry-point fix reported:

`NEXO DOOM PK3 is incomplete; missing: zscript/nexo_handoff.zs`

Remote `main` was verified to contain:
- `doom/mod_src/zscript.zc`;
- `doom/mod_src/zscript/nexo_handoff.zs`;
- `doom/mod_src/MAPINFO`;
- `doom/mod_src/CVARINFO`.

Root cause:
the earlier repository state contained both an extensionless file named
`doom/mod_src/ZSCRIPT` and a directory named `doom/mod_src/zscript/`.
On default case-insensitive macOS filesystems these paths collide, so Git could
store both remotely while the Mac working tree could not materialize both.

The rename `ZSCRIPT -> zscript.zc` permanently removes the collision.
Older local checkouts may require one explicit restore of the previously omitted
nested file:

`git restore --source=origin/main -- doom/mod_src/zscript/nexo_handoff.zs`

Do not pop/drop prior autostashes until P1.2 is validated; they may contain
pre-fix local edits.


## Portal Fabric P1.2 — PASS

Evidencia confirmada por el usuario:

- GZDoom 4.14.2 arranca correctamente en Apple M4;
- Freedoom Phase 2 MAP01 carga;
- NEXO PK3 carga;
- ZScript ejecuta;
- mensaje `NEXO HANDOFF SM64 -> DOOM` aparece;
- masa 6.10, monedas 5, Goombas 4, Bob-ombs 5 y score 15824 llegan a DOOM;
- recursos derivados se aplican.

Esto demuestra transferencia de estado real entre dos engines.

## M2 — ACTIVE: ESTABILIZA LA BRECHA

M2 continúa M1 dentro de DOOM.

Objetivo v0:
- eliminar 8 hostiles en MAP01;
- después alcanzar la salida normal del mapa.

Score:
- hereda score M1;
- +500 por baja;
- +3000 bonus al estabilizar la brecha.

Al completar:
- mensaje `BRECHA ESTABILIZADA`;
- salida de MAP01 actúa como NEXO Gate semántico.

Al descargar MAP01 se escribe al log una línea estructurada:
`[NEXO_HANDOFF] ...`

`bridge/doom_handoff.py` convierte esa línea a:
`bridge/runtime/handoff_from_doom.json`.

Target inicial:
`NEXO_HUB`.

El hub es una capa orquestadora para decidir el tercer mundo; no obliga todavía a instalar Portal/Source.

## UI decision

No fusionar menús completos de cada juego por ahora.

Preservar UI nativa de cada mundo + una capa NEXO común y mínima para:
- misión;
- progreso;
- carga/score relevante;
- portal siguiente.


## M2 — PASS and outbound handoff PASS

User completed M2 and exited MAP01.

Verified from log:
- M2 progressed to 8/8 hostiles;
- final chained score = 22824;
- outbound line emitted with target NEXO_HUB;
- `bridge/doom_handoff.py --print` generated `handoff_from_doom.json`;
- carried state includes mass 6.1, coins 5, Goombas 4, Bob-ombs 5 and combat_shards 8.

Regression discovered:
on MAP02 the same SM64 -> DOOM handoff was applied again and M2 restarted.

### Fix

M2 is now explicitly scoped to `MAP01` using `Level.MapName`.
MAP02 and later maps receive no M2 reinitialization.

## Control continuity — ACTIVE

GZDoom does support joystick/gamepad on macOS.

The launcher now forces:
- `use_joystick=true`;
- `m_blockcontrollers=false`.

New one-time diagnostic/setup mode:

`python3 bridge/run_doom.py --controller-setup`

Canonical cross-world semantics are documented in `CONTROLS_NEXO.md`.

Decision:
do not require keyboard-only play for DOOM; controller continuity is a project
requirement unless a target engine genuinely cannot support it.


## GZDoom 4.14.2 compatibility regression — MAP01 gate

Observed compile error:
`Unknown function CompareNoCase` in `nexo_handoff.zs`.

Root cause:
the previous MAP01 scope patch used a String method not exposed as used by
GZDoom 4.14.2 ZScript.

Verified against the exact `g4.14.2` ZScript runtime:
case-insensitive string comparison is supported through the `~==` operator.

Fix:
```zscript
InM2Map = Level.MapName ~== "MAP01";
```

Do not replace this with newer String helper methods without validating against
the pinned GZDoom runtime.


## Controller blocker — root cause identified

Observed on macOS 26.3 / GZDoom 4.14.2:
- controller detected;
- RT opens pause/menu instead of firing;
- LT pauses;
- D-pad Up behaves as permanently pressed;
- controller menu becomes effectively unusable.

This matches upstream GZDoom issue #3142 for macOS 26 / GZDoom 4.14.2:
triggers broken and D-pad/controller mapping corrupted in the native Cocoa backend.

Upstream issue remains open.

### Technical finding

GZDoom 4.14.2 supports two macOS build paths:
- native Cocoa backend (official packaged build);
- SDL2 backend via `OSX_COCOA_BACKEND=OFF`.

The current official runtime is Cocoa and is unsuitable as NEXO's controller
baseline on macOS 26.

### New remediation path

Added:
- `scripts/setup-gzdoom-sdl-macos.sh`
- `bridge/controller_probe.py`
- launcher runtime selection: `--runtime auto|sdl|cocoa`.

`auto` now prefers a locally built SDL GZDoom when available.

Gate CONTROL-1:
1. probe identifies controller HID;
2. SDL GZDoom detects controller;
3. D-pad neutral when untouched;
4. RT can bind/fire;
5. LT can bind without pausing;
6. both sticks usable;
7. M2 still loads.

Do not advance M3 until CONTROL-1 passes.


### CONTROL-1 build correction — ZMusic / Homebrew

The first SDL build attempt reached CMake successfully and detected:
- arm64;
- SDL2;
- libvpx.

It failed specifically at `find_package(ZMusic REQUIRED)`.

Root cause: GZDoom g4.14.2's own macOS CI does not expect ZMusic to come
from Homebrew or from the normal GZDoom source build. It downloads
`zmusic-1.1.14-macos-arm.tar.xz` from the GZDoom `ci_deps` release,
extracts it under the build directory, and passes that directory through
`CMAKE_PREFIX_PATH`.

The SDL setup script now mirrors that upstream procedure exactly.

The script also no longer performs a broad Homebrew install/upgrade. It only
installs missing dependencies, avoiding unrelated ffmpeg upgrades and reducing
exposure to transient ghcr.io failures.


### CONTROL-1A — SDL build PASS / runtime packaging regression

The user's full build log confirms:
- ZMusic was found;
- CMake configured successfully;
- all 835 build steps completed;
- the script reached `[NEXO] SDL2 GZDoom ready`.

The executable then failed before startup with dyld:
`Library not loaded: @rpath/libzmusic.1.dylib`.

Root cause:
the prebuilt ZMusic package was sufficient for CMake/linking through
`libzmusic.dylib`, but the locally generated macOS app bundle did not contain
the versioned runtime filename required by the Mach-O dependency:
`libzmusic.1.dylib`.

GZDoom already embeds `@executable_path` as an rpath on Apple builds.
Therefore the reproducible fix is to copy the resolved ZMusic dylib into
`gzdoom.app/Contents/MacOS/libzmusic.1.dylib`.

Added:
- automatic bundling in `setup-gzdoom-sdl-macos.sh`;
- `scripts/repair-gzdoom-sdl-macos.sh` to repair the already completed build
  without recompiling 835 targets;
- SDL launcher adds the app directory and ZMusic lib directory to
  `DYLD_LIBRARY_PATH` as secondary protection.

Next gate:
run repair script, then launch SDL controller setup. Do not rebuild unless the
repair reports the ZMusic source library itself is absent.


### CONTROL-1B startup regression — renderer root cause identified

After ZMusic repair, the SDL executable itself launches. Runtime evidence:
- `GZDoom ... SDL version`;
- Apple M4 OpenGL 4.1 / GLSL 4.10 context created;
- then fatal shader error:
  - vertex: `attribute : syntax error`;
  - fragment: `varying : syntax error`.

Root cause verified in GZDoom g4.14.2 source:

1. `vid_preferbackend` defaults to **1 = Vulkan**.
2. The local SDL build does not have Vulkan enabled.
3. SDL framebuffer selection checks `V_GetBackend() != 0` and therefore picks
   the **OpenGLES renderer** when backend remains 1.
4. On desktop OpenGL 4.1, GLES runtime selects `GLES_MODE_OGL3` and emits
   `#version 330`.
5. Its GLES shader source still contains legacy `attribute` and `varying`,
   which are invalid in GLSL 330 core.

This exactly explains the observed fatal dialog.

Fix does **not** require another build:
the SDL launcher now forces:
- `vid_preferbackend=0` (normal desktop OpenGL);
- `gl_es=false`.

GZDoom's own menu definition confirms backend values:
- 0 OpenGL;
- 1 Vulkan;
- 2 OpenGLES.

Audio observation:
the SDL run also reported `Sound init failed. Using nosound.`.
The launcher now adds the official working Cocoa runtime directory to
`DYLD_LIBRARY_PATH`; the repair script also copies a bundled OpenAL dylib when
one is present. Audio is secondary to CONTROL-1B but should be retested.

Next gate:
launch the existing SDL build again. No rebuild and no repeated M1/M2.


### CONTROL-1C — axis root cause identified; standardized SDL GameController backport

Observed after SDL/OpenGL startup PASS:
- menu stable;
- D-pad no longer stuck;
- RT fires;
- left stick moves;
- right stick mapping is wrong;
- player continuously looks upward;
- LT affects vertical look.

This is now explained directly by GZDoom's g4.14.2 SDL source. That version
uses raw `SDL_JoystickGetAxis` and assumes fixed raw-axis semantics. The source
itself contains a comment noting that a trigger appearing on a stick axis can
cause the player to look upward uncontrollably.

Current upstream GZDoom has since moved SDL mapped controllers to the
`SDL_GameController` API, which standardizes:
- LeftX / LeftY;
- RightX / RightY;
- LeftTrigger / RightTrigger.

NEXO now backports that concept to the existing g4.14.2 runtime while
preserving the old engine interface:
- prefer exactly one mapped SDL controller on this single-player runtime;
- standardized stick axes map to movement/yaw/pitch;
- triggers are removed from analog look and emitted as trigger buttons;
- standardized A/B/X/Y, shoulders, sticks, Start/Back and D-pad button events;
- mapped controllers use fresh `Joy:GC:*` config sections, avoiding stale
  raw-axis mappings from previous tests.

Added:
- `patches/gzdoom-g4.14.2-sdl-gamecontroller/i_joystick.cpp`;
- `patches/gzdoom-g4.14.2-sdl-gamecontroller/i_input.cpp`;
- `scripts/patch-gzdoom-sdl-gamecontroller.sh`.

This is an incremental rebuild, not a full 835-step rebuild.


## CONTROL-1 — PASS practical

User confirmed the standardized SDL GameController backport now behaves normally:
- left stick = movement;
- right stick = look;
- RT = fire;
- Y = jump;
- A = use/action;
- LB = weapon change;
- D-pad neutral/no phantom input.

This closes the structural controller blocker. Fine tuning may continue, but
controller continuity is no longer blocking world integration.

## PERSPECTIVE-1 — ACTIVE

Canonical rule:
the avatar persists; camera perspective is world-owned.

SM64 handoff now records:
- avatar: MARIO;
- audio_profile: mario_voice_v1;
- perspective source: third_person;
- target: first_person;
- transition: portal_push_in.

DOOM outbound records:
- source: first_person;
- target: adaptive;
- transition: portal_pull_out.

DOOM ZScript now has a perspective transition state. Third-person chase-body
reveal is gated behind `nexo_avatar_body_ready`; until an actual local Mario
body/skin exists, NEXO will not show Doomguy as a fake Mario proxy.

## AUDIO-ID-1 — ACTIVE

Persistent avatar identity is now separated from world audio.

DOOM hooks implemented for local Mario voice/action SFX:
- jump;
- use/action;
- hurt;
- death.

Nintendo audio is not committed. User-local files live under the gitignored
`assets_local/mario_sfx` directory and are embedded only into the locally
generated PK3 when the complete core set is present.

Added:
- `AUDIO_IDENTITY_NEXO.md`;
- `PERSPECTIVE_NEXO.md`;
- `scripts/import-mario-sfx-local.sh`.

## AUDIO-RUNTIME — correction prepared

The SDL build previously reported `Sound init failed. Using nosound.`.

GZDoom g4.14.2 upstream macOS CI uses `DYN_OPENAL=OFF`.
The canonical full SDL setup now mirrors that setting.

For the already-built runtime:
`scripts/patch-gzdoom-sdl-audio.sh` reconfigures/relinks incrementally against
macOS OpenAL without rebuilding from scratch.


## AUDIO-RUNTIME — OpenAL Soft local runtime

The first `DYN_OPENAL=OFF` repair still produced a playable but silent SDL
runtime.

Revised root strategy:
- use GZDoom's dynamic OpenAL path;
- build OpenAL Soft 1.25.2 locally inside `.runtime`;
- bundle `libopenal.1.dylib` next to the SDL GZDoom executable;
- force OpenAL Soft's CoreAudio backend with `ALSOFT_DRIVERS=core`;
- write an OpenAL diagnostic log to `bridge/runtime/openal-soft.log`.

Added:
- `scripts/setup-openal-soft-macos.sh`;
- revised `scripts/patch-gzdoom-sdl-audio.sh`;
- canonical setup uses `DYN_OPENAL=ON`.

This avoids dependence on Apple's deprecated OpenAL framework and avoids
Homebrew/ghcr.io for the OpenAL runtime.

## MARIO-SFX extraction — READY

Added:
`scripts/extract-mario-sfx-from-sm64-rom.sh`.

It clones only open-source sm64coopdx tools and extracts Mario voice samples
locally from the user's own validated SM64 ROM. No Nintendo audio is downloaded
or committed.

Core mapped samples:
- jump <- `00_mario_jump_hoo`;
- hurt <- `0A_mario_attacked`;
- death <- `03_mario_dying`;
- use <- `05_mario_uh`.

Optional identity cues:
- portal <- `0C_mario_here_we_go`;
- celebrate <- `04_mario_yahoo`.

DOOM now plays the portal cue on arrival and celebration cue on M2 completion
when Mario identity audio is enabled.


## AUDIO-RUNTIME — OpenAL Soft compiler regression identified

User log from 2026-10-12 shows OpenAL Soft configuration succeeded and selected
the correct macOS audio backend:
- CoreAudio, WaveFile, Null;
- ARM Neon;
- generation completed.

The build then failed during C++ dependency scanning because CMake inherited
Homebrew LLVM 20.1.7 (`/opt/homebrew/opt/llvm/bin/clang++` and
`clang-scan-deps`). That scanner invocation did not receive the Apple SDK
system include paths and consequently reported ordinary macOS headers as
missing: `pthread.h`, `Availability.h`, `sched.h`, and `time.h`.

This is a compiler/sysroot selection regression, not a missing pthread package
and not a CoreAudio failure.

Fix:
- force `/usr/bin/clang` and `/usr/bin/clang++`;
- resolve the active SDK with `xcrun --sdk macosx --show-sdk-path`;
- pass `CMAKE_OSX_SYSROOT`;
- lock `arm64`;
- disable unnecessary C++ module scanning;
- clear only the stale OpenAL build cache configured with the wrong compiler;
- preserve the already-cloned OpenAL Soft source checkout.


## AUDIO-RUNTIME — AppleClang 21 function-effects regression

After the SDK/toolchain fix, OpenAL Soft now progresses normally through
configuration and compilation and reaches the CoreAudio backend object.

The remaining failure is narrowly isolated to OpenAL Soft 1.25.2 enabling
`-Wfunction-effects` on AppleClang >=17. AppleClang 21 accepts that warning
flag, then treats two CoreAudio callback lambda conversions as errors:

- coreaudio.cpp:646
- coreaudio.cpp:824
- `attribute 'nonblocking' should not be added via type conversion`

The deprecation warnings around
`kAudioObjectPropertyElementMaster` are non-fatal.

Canonical workaround for pinned OpenAL Soft 1.25.2:
- preseed `HAVE_WFUNCTION_EFFECTS=FALSE`;
- keep `ALSOFT_WERROR=OFF`.

This disables only an optional compiler diagnostic; CoreAudio, ARM64, HRTF and
the runtime implementation remain unchanged.

Next gate: rerun `scripts/patch-gzdoom-sdl-audio.sh`.


## AUDIO-RUNTIME — PASS

User confirms the SDL GZDoom runtime now opens with working sound after the
project-local OpenAL Soft/CoreAudio path. Audio is no longer a blocker.

## SDL startup display regression — upstream fix backported

Observed after audio PASS:
- game/audio run;
- initial SDL window can remain black;
- toggling automap causes the game view to appear.

This matches the class of SDL startup/phantom-window issue fixed upstream after
g4.14.2 by GZDoom commit `c3fb744f47fe`:
"Fix phantom window freezing desktop on some systems".

NEXO backports only the relevant startup behavior to pinned g4.14.2:
- create OpenGL window with `SDL_WINDOW_HIDDEN`;
- show the window when the video mode is applied;
- set `setmodeneeded = true` after initial network/game setup.

Added:
- `scripts/apply-gzdoom-sdl-startup-source.py`;
- `scripts/patch-gzdoom-sdl-startup.sh`.

The canonical full SDL setup also applies this source patch automatically.

## DOOM arrival camera normalization

A second startup symptom remained: the view could begin pointed toward the
ceiling even though both sticks then behaved correctly.

The DOOM adapter now centers `pawn.Pitch = 0.0` once on player entry. This is
a destination-camera normalization, not an ongoing override; right-stick look
remains fully active immediately afterward.

## MARIO-SFX extractor macOS compatibility

The first local extraction attempt failed before doing any work because macOS
still ships Bash 3.2, which does not support associative arrays
(`declare -A`).

Extractor v2:
- Bash 3.2 compatible;
- no associative arrays;
- no GNU-only `find -maxdepth`;
- auto-detects US/JP/EU/Shindou by known SHA-1;
- searches common local folders when no ROM path is supplied;
- removes the temporary copied ROM after extraction;
- leaves only gitignored local voice/action samples.
