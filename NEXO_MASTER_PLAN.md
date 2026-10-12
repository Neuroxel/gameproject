# NEXO GAMEPROJECT — MASTER PLAN

This file records the durable target architecture and work order. Runtime truth
and latest test evidence still live in `NEXO_STATE.md`.

## Vision

NEXO is one cross-engine campaign, not a menu of disconnected minigames.

Mario is the persistent avatar. Across worlds preserve:
- identity;
- campaign state;
- score;
- logical mass/cargo;
- mission consequences;
- relevant resources;
- avatar audio;
- control grammar.

The destination world owns:
- camera/perspective;
- dominant mechanics;
- level geometry;
- native UI;
- world/weapon/environment audio.

Core rule:

**NEXO transports the avatar and state; it does not transport one universal
camera or force every engine to play identically.**

## Mechanical composition rule

Per chapter prefer:
1. one dominant native mechanic of the destination;
2. one meaningful consequence/resource from earlier chapters;
3. at most one recognizable echo of another mechanic.

Avoid stacking gimmicks.

## Perspective invariant

- SM64: third person.
- DOOM: first person.
- Portal/Source: first person.
- third-person/vehicle/2D worlds use their native perspective.

Mario must never become Doomguy merely because DOOM is the destination.

Transition grammar:
- 3P -> portal push-in -> avatar viewpoint -> 1P;
- 1P -> portal -> camera pull-out -> full avatar -> destination perspective.

## Closed gates that are not to be reopened without regression

- SM64 M1 functional PASS.
- Mario remains SM64 physical/navigation authority.
- Katamari ball remains visual/absorption/growth, not navigation collider.
- SM64 -> DOOM handoff P1 PASS.
- GZDoom g4.14.2 + Freedoom 0.13.0 baseline.
- SDL GameController path PASS practical on macOS.
- desktop OpenGL baseline.
- OpenAL Soft/CoreAudio runtime PASS.
- SDL black-start workaround remains operationally accepted.
- DOOM M2 PASS historically.
- DOOM -> NEXO_HUB outbound handoff PASS.
- MAP01-only M2 scope uses `Level.MapName ~== "MAP01"`.
- Nintendo assets remain local-only and gitignored.

## Immediate work order

1. **AUDIO-ID-2 / avatar audio semantic replacement**
   - Mario DMX decoding/loading is now proven audible.
   - remove Doom-player vocal duplication;
   - trigger jump voice only for confirmed jump;
   - verify hurt/death/use/portal/celebrate;
   - later improve DMX8 quality if needed.

2. **MARIOMOVE — Mario locomotion identity in DOOM**
   - triple jump;
   - backflip;
   - long jump;
   - stomp/ground pound;
   - then side flip, wall kick, dive, ledge/climb, swimming and other compatible
     SM64 movement signatures.

3. **Mario first-person embodiment**
   - Mario hands/gloves;
   - DOOM weapons held by Mario;
   - coherent fire/use/weapon-switch animation;
   - DOOM remains first-person.

4. **Full-body Mario local asset pipeline**
   - portals;
   - external cameras;
   - death;
   - mirrors/security cameras/cinematics where appropriate.

5. **Visible perspective grammar**
   - SM64 3P -> push-in -> portal -> DOOM 1P;
   - DOOM 1P -> portal -> pull-out -> full Mario -> next perspective.

6. **NEXO_HUB/router stabilization**
   - neutral campaign state;
   - adapter readiness;
   - state validation;
   - no hardcoded world progression inside individual launchers.

7. **Portal/Source feasibility + adapter**
   - investigate current Apple Silicon/macOS/CrossOver/runtime reality;
   - build launch/control/state adapter;
   - only then mark adapter ready.

8. **M3**
   - do not declare or launch until Source/Portal adapter is technically ready.

## Universal campaign state direction

Future neutral state should cover:
- campaign/chapter;
- avatar identity/audio profile;
- score;
- logical mass;
- cargo;
- cross-world resources such as combat_shards/portal_energy;
- perspective transition;
- world/mission history;
- flags/unlocks;
- difficulty/consequence state.

Keep engine-specific details inside adapters where possible.

## Avatar adapters

World-independent identity should map to world-specific embodiment:

- SM64 -> full Mario;
- DOOM -> Mario first-person hands + full body for external views;
- Portal -> Mario hands + portal gun + full body when needed;
- skate -> Mario body + board;
- vehicle worlds -> driver/vehicle representation;
- 2D -> Mario projection/sprite.

The same principle applies to movement: carry recognizable Mario locomotion
where it improves identity without destroying the destination's native design.

## Audio layers

Keep separate:
- WORLD AUDIO: weapons, enemies, environment, world music;
- AVATAR AUDIO: Mario voice, movement, hurt/death, exertion;
- NEXO AUDIO: portal/handoff/meta UI.

Do not play Doomguy voice underneath Mario voice.

## Asset pipeline

Repository may contain:
- import/extraction scripts;
- converters;
- hashes/metadata;
- hooks;
- free placeholders.

Repository must not contain proprietary Nintendo assets.

Use:
- `assets_local/`;
- `.runtime/`;
- deterministic import/extraction scripts.

## Control grammar

Preserve muscle memory by semantic role:
- left stick = MOVE;
- right stick = LOOK/CAMERA;
- context/use;
- traversal/jump;
- primary;
- secondary;
- cycle;
- world info;
- system/meta.

Each adapter translates semantics into its own engine.

## Adapter readiness gates

A new world is not READY merely because it launches.

Validate:
- launch;
- controls;
- audio;
- inbound state;
- mission start;
- death/failure;
- outbound state;
- exit;
- next handoff;
- resume;
- identity/perspective;
- QA.

## Final product direction

Eventually provide one NEXO launcher rather than a chain of manual scripts.

Conceptually:
```text
NEXO launcher
 -> campaign state
 -> adapter readiness
 -> launch engine
 -> consume outbound handoff
 -> persist campaign state
 -> route next chapter
```

Setup should eventually converge on one reproducible macOS entrypoint rather
than historical manual repair steps.

## Working discipline

Before repository writes:
- read current `NEXO_STATE.md`;
- fetch latest blob SHA;
- inspect exact pinned runtime APIs when compatibility matters.

After material changes:
- update canonical state/docs;
- do not declare runtime PASS without user evidence;
- do not make the user replay a previously closed gate unless a new change may
  have regressed it;
- prefer deterministic diagnostics over repeated manual guessing.
