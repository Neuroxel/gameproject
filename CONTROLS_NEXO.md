# NEXO CONTROL GRAMMAR v0.1

## Objective

Cross-world transitions should not force the player to relearn basic controls.

NEXO defines semantic actions. Each world adapter maps those semantics onto the
native engine rather than forcing every game to use an identical implementation.

## Canonical semantics

| Physical role | NEXO semantic | SM64 example | DOOM/GZDoom example |
|---|---|---|---|
| Left stick | MOVE | Mario movement | forward/strafe |
| Right stick | LOOK / CAMERA | camera | aim/look |
| South face | CONTEXT / USE | context-dependent | use/open |
| North face | TRAVERSAL | jump | jump |
| Right trigger | PRIMARY ACTION | future adapter action | fire |
| Left trigger | SECONDARY ACTION | future adapter action | alt-fire |
| LB / RB | CYCLE | context | previous/next weapon |
| D-pad Up | WORLD INFO | project HUD/context | automap |
| Start | SYSTEM | pause/menu | main menu |
| Back/Select | PAUSE / META | project-specific | pause |

## Principle

Spatial muscle memory is more important than identical button labels.

A shooter can keep trigger-to-fire while a platformer keeps its native face-button
actions. NEXO should preserve:
- movement stick;
- camera/look stick;
- primary/secondary action locations;
- pause/meta location;
- contextual prompts.

## GZDoom baseline

GZDoom 4.14.2 already includes controller defaults:
- Pad A -> use;
- Pad Y -> jump;
- right trigger -> attack;
- left trigger -> alt attack;
- shoulders -> weapon cycle;
- left stick -> movement;
- right stick -> look.

The NEXO launcher forces `use_joystick=true` and
`m_blockcontrollers=false`.

One-time device configuration can be opened with:

```bash
python3 bridge/run_doom.py --controller-setup
```

If a controller is exposed to macOS as a generic joystick rather than a standard
gamepad, use GZDoom's Joystick Options once to bind axes/buttons. Do not hard-code
Joy1/Joy2 mappings globally because those indices are device-dependent.

## UI rule

Do not merge full native menus.

Keep:
- native game menus for engine-specific settings;
- a small shared NEXO mission/status layer;
- NEXO prompts that use semantic action names where practical.


## macOS 26 / GZDoom Cocoa exception

The native Cocoa controller backend in GZDoom 4.14.2 is not accepted as the
NEXO baseline on macOS 26.

Observed/upstream symptoms include:
- triggers missing or misreported;
- D-pad corruption;
- incorrect button semantics.

NEXO therefore prefers a GZDoom 4.14.2 SDL2 build on macOS.

Commands:

```bash
python3 bridge/controller_probe.py
bash scripts/setup-gzdoom-sdl-macos.sh
python3 bridge/run_doom.py --runtime sdl --controller-setup
```

Do not manually tune dozens of Cocoa Joy bindings as a permanent workaround.


## SDL video/controller coexistence

The controller workaround requires only SDL input; it does **not** require
GZDoom's OpenGLES renderer.

For the local SDL runtime NEXO forces:
- SDL platform/input backend;
- desktop OpenGL renderer (`vid_preferbackend=0`);
- `gl_es=false`.

This avoids the macOS GLSL 330 `attribute`/`varying` crash while preserving
SDL joystick handling.


## Standardized SDL GameController mapping

Raw SDL joystick axis ordering is not accepted as the final NEXO baseline.

For mapped controllers the g4.14.2 SDL runtime is patched to use:
- Left Stick X/Y -> move;
- Right Stick X/Y -> yaw/pitch;
- LT/RT -> trigger buttons, never camera axes;
- SDL standardized face/shoulder/D-pad events.

Mapped devices use `Joy:GC:*` configuration sections so earlier `Joy:JS:*`
experiments cannot contaminate the new mapping.
