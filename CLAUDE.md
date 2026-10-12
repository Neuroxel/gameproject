# CLAUDE.md

Lee NEXO_STATE.md y PORTAL_FABRIC.md.

## Gate actual

Portal Fabric P1.2 — SM64 handoff -> GZDoom.

## Baseline confirmado

M1 SM64 = PASS funcional.
P1.1 manifest export = PASS.

## Validar

1. setup-doom-macos.sh;
2. run_doom.py --dry-run;
3. GZDoom inicia;
4. nexo_doom.pk3 compila/carga;
5. ZScript sin errores;
6. mensaje NEXO HANDOFF;
7. recursos derivados presentes.

No tocar física SM64 ni visual QA de attachments durante P1.2.


## Handoff durability invariant

Never clear a completed handoff on level initialization/reset.

Portal state crosses process boundaries and must remain durable until explicitly consumed or superseded.

Bridge v0.2 supports recovery from the legacy pending-reset bug.


## Current baseline

M2 and DOOM -> NEXO_HUB outbound handoff are PASS.

Important regression fixed:
M2 must run only on MAP01. Never reapply SM64 handoff on MAP02+.

Control continuity is now a project invariant. Read CONTROLS_NEXO.md before
changing controller mappings.


## GZDoom compatibility

Pinned runtime: GZDoom 4.14.2.

For case-insensitive String comparison in ZScript use `~==`.
Do not use `String.CompareNoCase()` for the current runtime.


## macOS controller blocker

Official GZDoom 4.14.2 Cocoa backend is rejected for NEXO controller baseline on
macOS 26 due to upstream issue #3142.

Preferred runtime after local setup: GZDoom 4.14.2 SDL2 backend
(`OSX_COCOA_BACKEND=OFF`).

Do not waste time hard-coding Cocoa Joy indices.


## SDL runtime packaging

A completed macOS SDL build may link against `@rpath/libzmusic.1.dylib`
without copying that versioned dylib into the app bundle.

Canonical repair:
`scripts/repair-gzdoom-sdl-macos.sh`.

Do not trigger a full rebuild for this packaging-only failure.


## SDL renderer invariant

For macOS SDL GZDoom 4.14.2 always force:
`vid_preferbackend=0` and `gl_es=false`.

Reason: without Vulkan compiled, backend 1 can select the GLES renderer; on
Apple OpenGL 4.1 it generates GLSL 330 with legacy attribute/varying syntax and
crashes at Default shader compilation.


## SDL controller mapping backport

GZDoom g4.14.2 raw SDL axes are not reliable on this macOS controller.
Use `scripts/patch-gzdoom-sdl-gamecontroller.sh` to backport standardized
SDL_GameController axes/buttons. Do not return to manual raw-axis remapping.


## Identity/perspective baseline

Read PERSPECTIVE_NEXO.md and AUDIO_IDENTITY_NEXO.md.

Invariant:
- Mario identity persists across worlds;
- perspective is destination-native;
- do not show Doomguy as a placeholder and call it Mario;
- Nintendo voice/SFX assets remain local-only and gitignored.

CONTROL-1 is practical PASS with the SDL GameController backport.

For the SDL audio runtime use DYN_OPENAL=OFF; existing builds can be repaired via
scripts/patch-gzdoom-sdl-audio.sh.


## SDL startup-window compatibility

Pinned GZDoom g4.14.2 must also carry the narrow startup backport from upstream
commit c3fb744f47fe. Canonical helper:
`scripts/apply-gzdoom-sdl-startup-source.py`.

Do not remove it when rebuilding the SDL runtime.

DOOM arrival also centers player pitch once. This is required cross-engine
camera normalization, not a persistent camera lock.


## macOS SDL startup profile

Until fullscreen startup is proven stable, `bridge/run_doom.py` must use the
isolated early-load config `bridge/runtime/gzdoom-nexo.ini` and default SDL to
windowed mode.

Reason: `+set vid_fullscreen false` may be processed after the first SDL
window is already constructed. Use GZDoom's `-config` path so
`GlobalSettings` is loaded before video initialization.

Fullscreen is explicit opt-in only.


## SDL first-present workaround

The current macOS 26 SDL/OpenGL g4.14.2 bug is reproducibly recovered by
automap -> 3D transition even in windowed mode. The launcher therefore applies
a short delayed automap prime by default after map startup.

Do not remove until a lower-level renderer fix is proven.

NEXO campaign/identity CVARs must be queued BEFORE +map so EventHandler
WorldLoaded/PlayerEntered sees the intended values.


## g4.14.2 ordering invariants (2026-10-13)

- EventHandler PlayerEntered precedes WorldLoaded on fresh map load.
  Never initialize arrival-critical NEXO state only in WorldLoaded.
- Console `wait` delays only the remainder of the same semicolon-separated
  AddCommandString buffer. Renderer prime must stay in one exec-script line.
- Mario identity SFX use dedicated global CHAN_5/UI; do not reuse Doom's
  native CHAN_VOICE.


## Canonical continuity additions

Before changing cross-engine architecture, avatar identity, or world order, read:
- `NEXO_MASTER_PLAN.md`;
- `NEXO_STATE.md`;
- `AVATAR_MOVEMENT_NEXO.md` when touching Mario movement/physics;
- `AUDIO_IDENTITY_NEXO.md` when touching player/world/NEXO sound ownership.

New invariant:
Mario's recognizable locomotion may persist across worlds through an avatar
adapter, but it must be adapted to the destination's geometry, camera and
dominant mechanics. Do not blindly copy SM64 heights/camera behavior into DOOM.

Do not declare `MARIOMOVE-1` PASS until the user has runtime-tested the
movement slice. Do not restore Doomguy player vocals underneath Mario identity
audio.


## Mario first-person embodiment

Before changing DOOM weapon presentation or Mario hand overlays, read:
- `MARIO_FIRST_PERSON_NEXO.md`;
- `AVATAR_MOVEMENT_NEXO.md`;
- `AUDIO_IDENTITY_NEXO.md`.

Invariant: the destination weapon remains mechanically native. Mario must be
shown as the character holding/operating it. Do not ship a Fist-only Mario
reskin and call first-person embodiment complete.

`nexo_mario_hands_ready` must remain false until a coherent local grip pack
exists for multiple weapons.


## Runtime-v2 DOOM embodiment invariant

Read the latest sections of:
- `NEXO_STATE.md`;
- `AVATAR_MOVEMENT_NEXO.md`;
- `AUDIO_IDENTITY_NEXO.md`;
- `MARIO_FIRST_PERSON_NEXO.md`;
- `NEXO_MASTER_PLAN.md`.

Current non-negotiable facts:
- user has runtime-confirmed wall kick;
- FP-MARIO v1 screenshots are evidence of visual failure, not PASS;
- do not restore v1 glove scales (~0.48-0.68);
- current v2 grip scales are ~0.20-0.26 pending user QA;
- Mario player class uses +NOSKIN so destination skins cannot override semantic
  avatar audio;
- triple jump uses SM64-family 42/52/69 launch ratios with live ceiling
  clamping and canonical voice pools;
- native Fist visual is hidden through reversible PSprite scale while mechanics
  remain native;
- Fire/Hold hand animation is required; static hands are no longer acceptable.

Do not mark AUDIO-ID-2, MARIOMOVE-2 or FP-MARIO-1 PASS without new user runtime
evidence.
