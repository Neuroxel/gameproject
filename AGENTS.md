# AGENTS.md

## Gate actual: Portal Fabric P1.2

M1 y P1.1 están cerrados.

No modificar SM64 salvo regresión crítica.

Trabajar sólo en:
- bridge;
- launcher;
- GZDoom adapter;
- handoff semantics.

Runtime baseline: GZDoom 4.14.2.
Legal test IWAD: Freedoom Phase 2 0.13.0.


## Portal durability invariant

Do not set `handoff_pending=0` from ordinary SM64 level reset/init code.
A completed cross-engine handoff must survive process/level transitions.


## Control invariant

Read CONTROLS_NEXO.md.

Do not assume keyboard-only input for a world if its engine supports gamepad.
Do not hard-code generic Joy1/Joy2 indices globally; device layouts vary.

## M2 scope invariant

SM64 -> DOOM handoff and M2 apply only on MAP01.
MAP02+ must remain native unless assigned a later NEXO mission.


## GZDoom 4.14.2 invariant

Case-insensitive map-name comparison must use `~==`.
Current M2 gate:
`Level.MapName ~== "MAP01"`.


## Controller runtime invariant

On macOS 26, prefer the SDL2 GZDoom build.
The official Cocoa GZDoom 4.14.2 controller backend has known trigger/D-pad
breakage. Do not treat per-button Cocoa remapping as a final solution.


## SDL ZMusic packaging invariant

For the local SDL GZDoom app, ensure
`gzdoom.app/Contents/MacOS/libzmusic.1.dylib` exists.

Use the repair script for an already completed build; do not rebuild 835 targets
for a missing runtime dylib.


## SDL renderer invariant

SDL is used for controller input, not GLES rendering.
Always launch the macOS SDL runtime with desktop OpenGL:
`vid_preferbackend=0`, `gl_es=false`.
Do not re-enable the default Vulkan preference unless Vulkan is actually built.


## Controller mapping invariant

On the macOS SDL runtime, mapped controllers must use the NEXO
SDL_GameController backport. Triggers must never participate in pitch/yaw.
Avoid raw `Joy:JS:*` axis assumptions for the final control baseline.


## Avatar identity invariant

Read PERSPECTIVE_NEXO.md and AUDIO_IDENTITY_NEXO.md.

Do not conflate player identity with camera mode.
Do not commit Nintendo/Mario audio or visual assets.
Local identity assets belong only under gitignored assets_local/.

DOOM remains first-person during native combat; a third-person body reveal is
enabled only when a real local Mario avatar package is available.


## SDL startup-window invariant

The macOS SDL runtime uses the g4.14.2 startup-window backport corresponding to
upstream GZDoom commit c3fb744f47fe. Full setup must apply it before build.

On DOOM PlayerEntered, center pitch exactly once; never continuously override
right-stick look.


## SDL first-window invariant

On macOS 26, NEXO SDL defaults to the isolated windowed-safe config. Do not make
fullscreen startup the default while black-screen/delayed-focus behavior is
unresolved. Fullscreen tests require explicit `--fullscreen`.


## Launch ordering invariant

For DOOM launch:
1. renderer/controller CVARs;
2. NEXO handoff/identity CVARs;
3. +map;
4. SDL renderer prime.

Never place nexo_handoff or nexo_mario_sfx after +map.

The automatic automap prime is a temporary macOS 26 first-present workaround
and is diagnostic-toggleable with --no-render-prime.


## Exact pinned-engine invariants

For GZDoom g4.14.2:
- PlayerEntered occurs before WorldLoaded during fresh level load.
- standalone `+wait N` does not delay later independent `+command` argv
  entries; delayed sequences must be one semicolon-separated command string.
- keep Mario/NEXO voice cues off native CHAN_VOICE; use dedicated CHAN_5/UI.


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


## Runtime-v3 DOOM embodiment invariant

New user QA on 2026-10-12 21:40-21:44 supersedes the runtime-v2 visual hand
assumptions.

Confirmed:
- canonical SM64 jump voice pool loads at runtime;
- general jump behavior now feels good to the user;
- wall kick remains previously confirmed;
- v2 hand overlays move and the pistol is materially improved.

Not confirmed / still active:
- backflip fidelity;
- FP-MARIO-1 visual pass;
- final A/use semantic silence.

Runtime-v3 hand rules:
- use pose manifest v3, not v2;
- glove scales are now ~0.28-0.34, not the old ~0.20-0.26;
- two-hand grips are pulled inward;
- genuine local SM64 hand mesh remains authoritative;
- renderer adds Mario-red sleeve + white cuff and softer facet contrast;
- every fresh attack edge must trigger a hand impulse even if native Fire has
  not fully exited;
- native Fire-state entry remains a fallback trigger;
- Fist attack is nonlinear, larger and perspective-scaled;
- movement hand presentation is nonlinear;
- crouch/crawl has first-person body-language presentation only; native GZDoom
  crouch movement remains authoritative.

Backflip:
- vertical family remains SM64 62/42 with ceiling governor;
- residual planar momentum is damped;
- backward thrust is stronger;
- no literal 360-degree first-person camera roll.

Do not mark FP-MARIO-1 or backflip fidelity PASS without new user runtime
evidence.


## AVATAR-BODY phase invariant

Full-body Mario is now an active local-only pipeline:
- `MARIO_FULL_BODY_NEXO.md`;
- `scripts/extract-mario-body-parts-from-sm64-rom.py`;
- `scripts/render-mario-body-preview-local.py`.

Do not set `assets_local/mario_avatar/READY` merely because OBJ parts or one
preview exist.

READY requires coherent portal/death/external body presentation.

Never show Doomguy/Freedoom marine in chasecam and call it Mario.
Normal DOOM remains first-person.
