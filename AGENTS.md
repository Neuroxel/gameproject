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
