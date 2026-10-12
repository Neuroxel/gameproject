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
