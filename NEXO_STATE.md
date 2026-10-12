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
