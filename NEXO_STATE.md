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


## SDL BLACK-SCREEN — fullscreen/focus isolation gate

Latest runtime evidence:
- OpenAL initializes successfully and opens `Bocinas de MacBook Pro`;
- GZDoom reaches MAP01;
- audio plays while video remains black;
- controller input is initially unavailable/delayed;
- automap eventually renders and, after leaving it, the 3D view becomes visible;
- arrival pitch normalization works: once the view appears it starts centered.

The previous startup-window source backport did **not** resolve this runtime
behavior. The remaining symptoms are now treated as an SDL/macOS fullscreen /
focus / first-present interaction rather than a controller mapping failure.

Important timing fact:
GZDoom loads `GlobalSettings` before constructing the SDL video backend, while
our `+set` console commands may be applied after the initial window already
exists. Therefore changing `vid_fullscreen` only on the command line is not a
sufficient early-startup control.

New isolation strategy in `bridge/run_doom.py`:
- create/use `bridge/runtime/gzdoom-nexo.ini`;
- seed it once from `~/Library/Preferences/gzdoom.ini` when available, so
  existing bindings/preferences survive;
- force before video initialization:
  - `vid_fullscreen=false`;
  - `win_maximized=false`;
  - OpenGL desktop backend;
  - joystick enabled;
- use a 1200x800 centered window for the stable baseline;
- pass this file through GZDoom's native `-config` argument;
- fullscreen is now explicit opt-in via `--fullscreen`.

This is deliberately diagnostic and conservative: first prove immediate image +
immediate controller focus in windowed mode. Only then reintroduce fullscreen
after the first successful frame.

Audio remains PASS. Controller mapping remains PASS; current delayed input is
classified as startup/focus behavior until this gate is tested.


## SDL BLACK 3D VIEW — deterministic automap prime workaround

Windowed-safe startup disproved fullscreen as the sole cause:
the 1200x800 SDL window still starts with a black 3D view, while input/audio
remain alive. Manually opening automap renders correctly; closing automap then
makes the 3D renderer remain correct.

This gives a deterministic engine-level recovery action.

The SDL launcher now queues after `+map`:
- wait 8 tics;
- `togglemap`;
- wait 2 tics;
- `togglemap`.

This is a temporary first-frame renderer prime and should be nearly
imperceptible. It can be disabled with `--no-render-prime` for diagnosis.

The earlier fullscreen/windowed isolation remains useful, but the current bug
classification is now **3D first-present/render-state initialization**, not
fullscreen-only and not controller mapping.

## MARIO-SFX — extraction PASS; launch-order bug corrected

The user's local US ROM was validated by SHA-1 and extraction completed:
jump, hurt, death, use, portal and celebrate WAV files were created under
`assets_local/mario_sfx`.

The generated DOOM PK3 contains 11 lumps, which matches:
- 4 base NEXO mod lumps;
- 6 Mario WAV files;
- 1 SNDINFO.

A launch ordering flaw remained: `+map` was queued before NEXO CVARs.
The EventHandler may therefore observe default
`nexo_handoff=false` / `nexo_mario_sfx=false` during WorldLoaded.

Canonical order is now:
1. renderer/controller CVARs;
2. NEXO handoff + Mario identity CVARs;
3. `+map`;
4. renderer prime.

WorldLoaded now logs the identity gate values and PlayerEntered logs when the
Mario portal cue is requested.


## 2026-10-13 — ROOT CAUSES: first-frame prime + EventHandler ordering

Two independent assumptions were proven wrong from the exact pinned
GZDoom g4.14.2 source.

### Black 3D startup

The previous command line used separate argv commands:
`+wait 8 +togglemap +wait 2 +togglemap`.

In g4.14.2, `wait` only schedules the **remainder of the same
semicolon-separated AddCommandString buffer**. A standalone `wait 8` has no
remainder and returns; the following command-line `togglemap` is a separate
buffer. Therefore the intended delayed automap prime never actually existed.

Fix:
`bridge/run_doom.py` now writes
`bridge/runtime/nexo-startup.cfg` containing one line:

`wait 8; togglemap; wait 2; togglemap`

and queues it through one `+exec` after `+map`.

### Mario identity / M2 arrival

Pinned g4.14.2 calls local EventHandler `PlayerEntered` **before**
`WorldLoaded` during a fresh map load.

The NEXO handler previously initialized `InM2Map` and `IdentityActive` only
inside `WorldLoaded`. Consequently the first `PlayerEntered` observed both
fields as false, suppressing the Mario arrival cue/perspective path and
returning before M2 handoff application.

Fix:
- arrival state is derived at the start of `PlayerEntered`;
- `WorldLoaded` refreshes/logs but no longer destroys state initialized by
  `PlayerEntered`;
- Mario SFX use dedicated global `CHAN_5` + `CHANF_UI` so Doom player voice
  channels cannot clobber identity cues;
- arrival logs the duration of all six registered Mario sounds via
  `S_GetLength`;
- generated SNDINFO quotes exact PK3 paths.

Expected diagnostic:
`[NEXO] PlayerEntered: map=MAP01 handoff=1 mario_sfx=1 m2=1`
followed by positive Mario SFX durations and the portal cue request.


## P1.3 — NEXO_HUB ROUTER IMPLEMENTED

Added a world-independent campaign routing layer:
- `bridge/campaign.json`;
- `bridge/nexo_router.py`;
- output `bridge/runtime/route.json`.

The router consumes the validated DOOM outbound handoff addressed to
`NEXO_HUB`, preserves score/mass/cargo/identity/perspective/derived state,
and resolves the next campaign chapter.

Current graph:
`M1_CARGA_IMPOSIBLE -> M2_STABILIZE_BREACH -> HUB_AFTER_M2 -> M3_PORTAL_LAB`.

M3 is **planned**, not ready. Its route requires `combat_shards >= 8`, but
even with requirements met the router keeps `launch_allowed=false` until the
destination adapter is explicitly marked `ready`.

This advances Portal Fabric at the data/orchestration layer without pretending
that a Portal/Source runtime integration already exists.


## AUDIO-ID-2 — RESOURCE/DECODER ISOLATION

Latest runtime evidence remains:
- all six local Mario WAV files are embedded in the generated PK3;
- `nexo_mario_sfx=true`;
- PlayerEntered executes and requests the portal cue;
- Doom/Freedoom audio works;
- `S_GetLength()` returns `0.000` for all six Mario logical sounds.

Pinned GZDoom g4.14.2 source was rechecked at the exact tag:
- SNDINFO logical mappings call `S_AddSound(logicalname, lumpname)`;
- that resolves the second token with
  `fileSystem.CheckNumForFullName(lumpname, true, ns_sounds)`;
- ZIP entries retain their full `LongName`, including the leading
  `sounds/` directory, while that directory also assigns `ns_sounds`.

Therefore the current generated mapping form
`nexo/mario/jump "sounds/nexo/mario/jump.wav"`
is consistent with the pinned filesystem/parser implementation. The earlier
"path probably needs the sounds/ prefix removed" hypothesis is rejected.

The remaining unresolved boundary is now:
1. actual runtime resource lookup of each PK3 member; versus
2. decoding/loading of the local WAV payload.

Added deterministic instrumentation:
- ZScript logs `Wads.CheckNumForFullName()` lump id and byte length for all
  six exact PK3 paths before calling `S_GetLength()`;
- `scripts/diagnose-mario-sfx.sh` rebuilds the PK3 via dry-run, verifies
  ZIP integrity and exact SNDINFO targets, parses the six local WAV RIFF/fmt/data
  headers, and reports whether they are standard PCM 16-bit little-endian.

Interpretation gate:
- missing/negative lump => resource/path layer still broken;
- lump >= 0 and bytes > 0, but invalid/non-PCM WAV => local conversion layer;
- lump >= 0 and bytes > 0, standard PCM16LE, but `S_GetLength=0` =>
  resource resolution is proven and the remaining root cause is inside
  GZDoom's sound decode/load path.

No Nintendo audio is committed. No OpenAL/controller/renderer changes were made.
AUDIO-ID-2 remains FAIL until the user runs the deterministic diagnostic and
one normal SDL launch.


## AUDIO-ID-2 — ZMUSIC WAV DECODER BYPASS PREPARED

New evidence from the user's deterministic run:
- all six local files are valid PCM, 16-bit little-endian, mono, 16 kHz;
- generated SNDINFO mappings and PK3 membership are PASS;
- runtime `Wads.CheckNumForFullName()` resolves every exact sound path;
- each runtime lump has the expected non-zero byte size;
- nevertheless all six `S_GetLength()` values remain exactly `0.000`.

This proves the failure occurs after resource lookup.

Pinned GZDoom 4.14.2 source shows non-DMX SFX are passed to
`GSnd->LoadSound()`, which calls ZMusic `CreateDecoder()`.
Pinned ZMusic 1.1.14 shows that generic sound decoding is provided only by
optional libsndfile and mpg123 decoder paths; WAV depends on libsndfile.
Its macOS dynamic-dependencies CI build enables dynamic libsndfile loading while
not installing libsndfile as a build dependency. Therefore the current working
root-cause classification is: **the WAV decoder path is unavailable at runtime,
most likely because ZMusic cannot load libsndfile**.

NEXO now avoids making Mario identity depend on that optional runtime component:
- original local WAV files remain untouched and gitignored;
- `bridge/run_doom.py` converts PCM16LE WAV to native Doom DMX data only while
  constructing the local PK3;
- generated SNDINFO points to `sounds/nexo/mario/*.dmx`;
- DMX is recognized by GZDoom before ZMusic and is loaded through
  `LoadSoundRaw()`;
- source sample rate is preserved; stereo would be mixed to mono;
- no GZDoom rebuild, Homebrew install, Nintendo asset commit, controller change,
  renderer change, or OpenAL change is required.

Tradeoff:
DMX uses unsigned 8-bit mono audio. This is acceptable as a deterministic gate
closure path; if identity quality is materially degraded after it works, a later
quality pass may restore full 16-bit WAV by bundling a known-working libsndfile
runtime.

AUDIO-ID-2 is still NOT PASS until user runtime confirms positive
`S_GetLength()` and audible Mario cues.


## 2026-10-12 — AUDIO-ID-2 audible; semantic dedupe + MARIOMOVE-1 ACTIVE

### New user evidence

The native DMX bridge changed the runtime result materially:
- Mario voice is now audible in DOOM;
- jump produces Mario audio;
- hurt produces Mario audio;
- Doom/Freedoom world audio still works.

This proves:
- PK3 resource lookup PASS;
- native DMX load/decode path PASS;
- OpenAL/CoreAudio playback PASS for Mario runtime assets.

The earlier six-zero-length WAV blocker is therefore functionally bypassed.

### Newly observed audio regressions

The user reported:
- jump played both Mario and Doom-player vocal audio;
- hurt played both Mario and Doom-player vocal audio;
- rapid repeated Jump presses could replay Mario even when no new physical
  jump occurred;
- firing a gun did not produce Mario voice, which is currently correct:
  weapon audio belongs to the destination world.

Root cause:
the first Mario identity implementation inferred jump from raw button edges and
hurt from health deltas, then layered Mario on top of GZDoom's own semantic
player sounds.

### AUDIO-ID-2B — semantic replacement prepared

The adapter now uses engine semantics instead of duplicate inference:
- generated SNDINFO silences native `*jump` and `*usefail`;
- native pain slots map directly to Mario hurt;
- native death/xdeath map directly to Mario death;
- native grunt/land map to Mario stomp when that local cue exists, otherwise
  silence rather than Doomguy voice;
- custom EventHandler jump/hurt/death overlays were removed;
- Use, portal and M2 celebration remain explicit NEXO cues;
- jump audio is owned by the Mario player class and only emits after a real
  engine jump is confirmed.

AUDIO-ID-2 overall remains **ACTIVE / not final PASS** until the user verifies:
- no Doom-player voice under Mario;
- jump button spam does not create false jump cues;
- hurt/death/use/portal/celebrate remain correct;
- DMX8 quality is acceptable for the functional gate.

### MARIOMOVE-1 — ACTIVE

Added `NexoMarioDoomPlayer : DoomPlayer` as a reusable avatar movement adapter,
separate from M2 mission logic.

Feature gate:
`nexo_mario_movement=true`.

First slice:
- normal jump remains native-height baseline;
- moving chained jump 2 ~= 1.08x JumpZ;
- moving chained jump 3 ~= 1.18x JumpZ;
- chain continuation window = 14 tics after landing;
- standing too long resets chain;
- crouch + stationary jump = moderate backflip;
- crouch + running-forward jump = moderate long jump;
- fresh crouch in air = one ground-pound/stomp per airborne cycle;
- stomp damage is intentionally deferred until traversal safety is proven.

Movement voices are local-only:
- jump2;
- jump3;
- backflip;
- longjump;
- stomp;
- dive.

The existing extraction pipeline was expanded and
`scripts/extend-mario-movement-sfx-local.sh` can reuse already-extracted AIFF
samples without requiring another ROM copy.

### Required Mario movement scope

User explicitly requires the broader Mario movement language to be preserved
where compatible with destination engines, including at minimum:
- triple jump;
- stomp/ground pound;
- crouch backflip;
- long jump;
- side flip/turnaround jump;
- wall kick;
- dive/slide;
- ledge grab/climb;
- crouch/crawl;
- swimming/environment traversal where applicable;
- contextual melee/aerial actions where they do not replace the destination's
  dominant combat language.

Canonical contract:
`AVATAR_MOVEMENT_NEXO.md`.

Do not copy exact SM64 heights/camera behavior blindly into FPS worlds.
The goal is Mario identity with destination-world authority.

### Master continuity

Added `NEXO_MASTER_PLAN.md` so the full project order/invariants no longer
depend on one conversation window.

Immediate order remains:
AUDIO-ID-2 semantic validation -> MARIOMOVE validation -> Mario first-person
hands/weapons -> full-body local pipeline -> visible 3P/1P portal grammar ->
router stabilization -> Source/Portal adapter -> M3.


## 2026-10-12 — MARIOMOVE-1 user validation + MARIOMOVE-2 prepared

### User runtime evidence

The user confirmed the first movement slice is materially improved:
- ordinary Mario jump audio/behavior feels better;
- long jump works;
- backflip works;
- stomp/ground-pound works;
- Mario audio now plays at runtime through the generated DMX bridge.

Observed remaining issues:
- Use/action still leaks a Doom-player voice while the action itself works;
- backflip needs to feel more like Mario's higher somersault;
- triple jump does not trigger;
- broader Mario locomotion should continue before first-person hands.

### Triple-jump root cause and correction

The first implementation used a 14-tic chain window while GZDoom keeps
`jumpTics` locked for more than 18 tics after the preceding jump. Therefore a
legal second jump could not occur before NEXO had already reset the chain.

Correction:
- a confirmed landing clears the inherited long DOOM jump cooldown;
- every ground jump now requires a fresh Jump press;
- held Jump cannot auto-hop;
- airborne Jump spam cannot emit extra jump cues;
- chain window = 24 tics after landing;
- jump factors = 1.00 / 1.10 / 1.24 for jump 1/2/3.

Status: **prepared, runtime retest required**.

### Backflip correction

Backflip vertical component increased to ~1.35x base jump.

The FPS camera still does not rotate through a literal 360-degree somersault.
That visual rotation belongs to future Mario hand/weapon animation and
third-person/full-body views.

### MARIOMOVE-2 — prepared

Added directional traversal:
- side flip / turnaround jump:
  - strong direction reversal + fresh Jump;
  - ~1.22x vertical component;
  - momentum redirected to the new input;
- wall kick:
  - airborne + fresh Jump;
  - requires GZDoom `MovementBlockingLine` collision evidence;
  - moderate upward restore + push away from attempted approach;
  - 9-tic anti-abuse cooldown;
- dive:
  - airborne + strong forward motion + fresh crouch/L3;
  - strong forward impulse + modest downward component;
- dive landing -> short 14-tic slide;
- airborne crouch without strong forward intent remains stomp.

No proximity-only wall jump and no infinite slide acceleration.

Status: **ACTIVE / runtime validation pending**.

### Avatar audio dedupe — hardened

`NexoMarioDoomPlayer` now has a dedicated sound namespace:

`Player.SoundClass "nexo_mario"`.

Generated SNDINFO defines both `nexo_mario` and fallback `player` mappings
for all supported genders:
- jump silent at native layer;
- usefail/puzzfail silent;
- pain -> Mario hurt;
- death variants -> Mario death;
- grunt/land -> Mario stomp cue.

This specifically targets the remaining Doom-player voice on Use/action.

Status: **runtime retest required**.

### FP-MARIO-1 groundwork

Added `MARIO_FIRST_PERSON_NEXO.md`.

Target is not a Fist-only reskin. Mario must visibly grip the actual destination
weapons, including at minimum:
- pistol;
- shotgun/super shotgun;
- chaingun;
- rocket launcher;
- plasma;
- BFG;
- chainsaw;
- fist.

Preferred implementation: GZDoom PSprite overlay layers that preserve native
weapon logic and add Mario left/right glove ownership.

Added local readiness gate:
`nexo_mario_hands_ready=false`.

Launcher detects:
`assets_local/mario_hands/READY`.

Added:
`scripts/probe-mario-hands-local.sh`.

The local sm64coopdx source is known to expose Mario hand geometry symbols
(open/closed left/right). Runtime READY must remain absent until a coherent
multi-weapon grip pack exists.


### FP-MARIO-1 prototype pipeline prepared

The first-person embodiment groundwork has advanced beyond documentation.

Runtime:
- `zscript/nexo_mario_hands.zs` defines weapon-compatible static hand states;
- `NexoMarioDoomPlayer` selects a per-weapon back/front grip pair;
- PSprite layer -2 renders behind the native weapon;
- PSprite layer 2 renders in front;
- selector remains dormant unless `nexo_mario_hands_ready=true`;
- unknown/mod weapons clear the overlays rather than reuse a false generic grip.

Validated weapon families:
Fist, Chainsaw, Pistol, Shotgun, SuperShotgun, Chaingun, RocketLauncher,
PlasmaRifle/ID24Incinerator, BFG9000/ID24CalamityBlade.

Local asset pipeline:
- `scripts/probe-mario-hands-local.sh`;
- `scripts/extract-mario-hand-meshes-from-sm64-rom.py`;
- `doom/mario_hands_pose_manifest.json`;
- `scripts/render-mario-weapon-hands-local.py`.

The project state already records that the user's SM64 ROM is validated US, so
the direct ROM geometry extractor matches the current pinned physical segment
layout.

The mesh extractor reconstructs:
- left closed;
- right closed;
- left open;
- right open;
from the user's own ROM into gitignored OBJ files.

The renderer creates all 18 expected transparent PNG layers with no external
Python dependency. It does not activate them unless called with `--activate`.

Launcher gate is hardened:
`nexo_mario_hands_ready` becomes true only when READY exists **and all 18
expected PNGs exist**.

Important visual debt:
destination weapon sprites may include baked Doom/Freedoom hands. The prototype
front layers are positioned to cover them where possible. Runtime visual QA is
required; if any native hand remains obvious, that weapon needs a local visual
mask/reconstruction while preserving native weapon mechanics.

Status: **FP-MARIO-1 PROTOTYPE READY FOR LOCAL GENERATION / NOT PASS**.


## 2026-10-12 — User hand screenshots invalidate FP-MARIO v1; runtime-v2 prepared

### Runtime evidence

The user supplied three in-game screenshots after activating the first local
Mario-hand pack.

Observed:
- the hand pipeline loads and renders successfully;
- the weapon-family selector works;
- white SM64 hand meshes are visible around native weapons;
- however the v1 scale/placement is clearly unacceptable:
  - gloves are approximately 2-3x too large;
  - weapon silhouettes are obscured;
  - hands do not read as convincing grips;
  - the native brown Fist remains visible between Mario gloves;
  - hand overlays do not animate with melee or gun fire.

Movement evidence from the same run:
- wall kick: user-confirmed OK;
- A/use: residual DOOM-player complaint still audible;
- triple jump: voice succession not SM64-faithful;
- double/triple height distinction remains too weak.

### Audio root cause

GZDoom 4.14.2 sound-class inspection found skin precedence can bypass the
actor's default `Player.SoundClass`.

`NexoMarioDoomPlayer` now uses:
- `+NOSKIN`;
- `Player.SoundClass "nexo_mario"`.

This forces player semantic audio through the NEXO class. Generated
`*usefail/*puzzfail DSEMPTY` remains the intended silence.

Status: **A/use retest required**.

### Mario jump runtime-v2

Vertical identity now follows source-family ratios:
- 42 normal;
- 52 double;
- 69 triple;
- 62 backflip/sideflip/wallkick;
- 30 long-jump vertical family.

Enhanced launch speed is dynamically capped by live ceiling headroom and
GZDoom effective gravity, with a 5-unit head reserve.

Triple-jump voice grammar now follows:
- jump 1 random Yah/Wah/Hoo;
- jump 2 Hoo-hoo;
- jump 3 Yahoo/Waha/Yippee weighted 60/20/20.

Chain window = 28 tics after real landing, fresh Jump still required.

Status: **runtime retest required**.

### First-person hand runtime-v2

Visual:
- pose manifest reduced to ~0.20-0.26 glove scales;
- grips moved lower/closer to weapon contact areas;
- renderer adds a thin dark silhouette.

Animation:
- native Fire/Hold/AltFire sequences drive per-weapon recoil/vibration;
- Fist alternates left/right Mario punches;
- native Fist presentation is hidden while mechanics remain native;
- movement actions feed subtle hand offsets for backflip/sideflip/wallkick/
  longjump/dive/stomp.

FP-MARIO-1 remains **NOT PASS** until user visual QA confirms:
- weapon remains readable;
- glove scale is credible;
- Fist brown hand is gone;
- firing/melee visibly animate;
- no obvious destination hand leaks outside Mario overlays.

### Canonical next order after this retest

1. close AUDIO-ID-2 semantic dedupe if A/use is clean;
2. classify MARIOMOVE-2 components PASS/fix;
3. FP-MARIO runtime-v2 scale/recoil QA;
4. FP-MARIO state-specific art + baked-hand masking where needed;
5. MARIOMOVE-3: crouch/crawl/slope + ledge/hanging/climbing feasibility;
6. MARIOMOVE-4: contextual Mario melee/aerial/stomp damage/carry semantics
   only where they do not steal the destination's dominant combat language;
7. full local Mario body for death/portals/external views;
8. visible 3P<->1P perspective transition grammar;
9. NEXO_HUB/router stabilization;
10. Source/Portal adapter;
11. M3 only after that adapter is genuinely ready.


### Post-screenshot hardening — USE and special-move voices

Further exact-source review after the runtime-v2 snapshot:

A/use:
- the EventHandler's unconditional raw-button `PlayMarioUse()` was removed;
- A now leaves door/switch audio to DOOM/Freedoom;
- failed-use semantic sounds remain intentionally silent through SNDINFO;
- `+NOSKIN` still prevents skin-level marine sound overrides;
- the Mario use resource is retained only as an available explicit asset.

Special movements now use source-game voice families:
- backflip -> Yah/Wah/Hoo;
- side flip -> Yah/Wah/Hoo;
- wall kick -> Yah/Wah/Hoo;
- long jump -> Yahoo;
- dive -> Hoo-hoo;
- ground pound -> dedicated Ground-Pound Wah.

Ceiling governor was hardened:
- custom ground actions use the capped value as the final vertical target
  rather than adding it to pre-existing Z speed;
- normal/double/triple jumps also clamp the final post-GZDoom launch velocity,
  protecting the ceiling reserve even when base GZDoom adds existing vertical
  platform motion.

First-person Fist hiding was hardened across weapon switches:
- save the hidden Fist caller/scale;
- restore exact scale only when the same caller remains;
- if a switch already changed the caller, restore neutral per-state scale
  while the new weapon retains its own baseScale.

Static audit:
- no illegal PSprite raw Flags access remains;
- no literal backslash-n include defect;
- no raw-button PlayMarioUse path remains.

Status remains **runtime-v2 retest required; no new PASS declared**.


## 2026-10-12 21:40-21:44 — FP-MARIO v2 runtime QA; v3 prepared

### Terminal evidence

The user's run:
- fast-forwarded local main to the then-current canonical state;
- successfully generated all extended Mario movement voice files;
- Python compilation completed without error;
- rendered and activated all 18 v2 hand layers;
- embedded the complete hand pack in the generated PK3;
- reported `Mario jump voice grammar: CANONICAL SM64 POOL`;
- reported `Mario hand runtime: v2 ...`;
- launched pinned GZDoom g4.14.2 successfully;
- loaded all Mario DMX resources with positive runtime lengths.

This is strong evidence that the remaining v2 hand problem is presentation and
attack-state behavior, not asset-loading or PK3 integration.

### New user visual/playtest evidence

User reports:
- hand overlays do move;
- pistol is materially improved relative to v1;
- gloves are too small;
- the raw hand silhouettes do not read strongly as Mario gloves;
- Fist motion is small and looks like a basic linear translation;
- Fist/attack animation is intermittent across button presses;
- launcher/two-hand grips remain too separated;
- jump behavior now works well;
- backflip physical/effect fidelity remains uncertain.

FP-MARIO v2 is therefore **FAIL as final visual presentation**, while its
underlying overlay/runtime architecture remains accepted.

### FP-MARIO runtime-v3 prepared

Visual:
- glove scales raised to ~0.28-0.34;
- two-hand positions pulled inward;
- Mario-red sleeve + white cuff added behind each hand where present;
- softer facet contrast;
- Fist hands enlarged and converged.

Attack controller:
- fresh physical attack edge always starts a new impulse, even if the previous
  native Fire sequence has not fully exited;
- native Fire-state entry remains a fallback trigger;
- continuous weapons still repeat while held;
- Fist uses a larger nonlinear curved jab with perspective scale growth.

Movement:
- first-person movement hand arcs are nonlinear and stronger;
- backflip residual planar momentum is damped and backward thrust increased to
  better reflect SM64's -16 forward-velocity initialization;
- ceiling governor is unchanged.

### Gate classification after this evidence

- AUDIO-ID-2 core runtime/load path: functionally healthy.
- canonical SM64 jump voice pool: runtime-confirmed loaded.
- MARIOMOVE jump chain: user reports good.
- wall kick: prior user confirmation retained.
- backflip: ACTIVE / fidelity retest.
- FP-MARIO-1: NOT PASS; v3 retest required.
- FP-MARIO-2 state-specific/masking work remains next after v3 calibration.
