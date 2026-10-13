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


## Runtime-v2 gate sequence — 2026-10-12

Current near-term order is now more granular:

1. **AUDIO-ID-2 final semantic retest**
   - A/use must contain no destination-marine complaint;
   - pain/death remain Mario;
   - jump grammar uses the canonical SM64 pools;
   - DMX8 quality debt remains separable from functionality.
2. **MARIOMOVE-2 runtime-v2**
   - validate normal/double/triple differentiation under tall and ordinary
     ceilings;
   - validate backflip, side flip, wall kick, long jump, dive/slide and stomp;
   - ceiling governor must prevent routine head collisions.
3. **FP-MARIO-1 runtime-v2**
   - correct glove scale/placement;
   - Fist must no longer expose the native brown fist;
   - Fire/Hold recoil must be visible;
   - native destination weapons remain mechanically intact.
4. **FP-MARIO-2 art/state pass**
   - state-specific Ready/Fire/Reload/Raise/Lower grip art where useful;
   - local masks/reconstruction for baked destination hands that still leak;
   - better cuffs/forearms and movement-specific poses.
5. **MARIOMOVE-3**
   - ground crouch/crawl polish;
   - slope/slide behavior;
   - ledge grab/pull-up;
   - hanging/climbing;
   - poles/swimming only where destination geometry can support them cleanly.
6. **MARIOMOVE-4 compatibility evaluation**
   - contextual punch/kick/aerial/stomp damage;
   - dive collision;
   - pickup/carry/throw;
   - never steal the destination world's dominant combat grammar.
7. **Mario full body**
   - local real Mario body for portals, death, mirrors and external cameras.
8. **Perspective transition grammar**
   - visible 3P -> avatar push-in -> portal -> 1P;
   - reverse pull-out on exit.
9. **HUD/avatar residue audit**
   - identify avatar-specific Doomguy residue (for example face portrait) versus
     destination UI that should remain native;
   - replace only identity-conflicting elements.
10. **NEXO_HUB/router stabilization**.
11. **Source/Portal adapter**.
12. **M3 only when Source/Portal adapter is genuinely ready**.

Do not skip from the current DOOM embodiment work directly to M3.


## Current execution checkpoint — FP-MARIO v3

Latest user runtime evidence:
- general Mario jump behavior is now good;
- canonical jump voice pool loads;
- wall kick remains validated;
- backflip fidelity still needs one focused retest;
- FP-MARIO v2 movement exists but visual/attack quality is insufficient.

Current implementation checkpoint:
1. FP-MARIO v3 grip/sleeve/cuff render + reliable nonlinear attack impulse;
2. backflip stronger backward identity + nonlinear first-person presentation;
3. MARIOMOVE-3 crouch/crawl first-person presentation groundwork;
4. next runtime QA calibrates Fist, Pistol and one representative two-hand
   launcher/long-gun family;
5. after that, proceed to state-specific weapon-hand art and baked-hand
   masking only where screenshots prove it is necessary.

Do not reopen the now-working jump ratios/audio unless runtime regression
evidence appears.


## Progression update — FP-MARIO no longer blocks body-source work

User direction: do not spend multiple cycles indefinitely micro-calibrating
generic first-person hands.

Therefore workstreams now overlap safely:

1. FP-MARIO v4 gets one final generic positioning QA.
2. FP-MARIO-2 state-specific/masking improvements may continue later per weapon
   without blocking architecture.
3. AVATAR-BODY-1 has started now:
   local full-body Mario part extraction + canonical skeleton manifest.
4. AVATAR-BODY-2 follows with neutral/portal/death pose rendering.
5. MARIOMOVE-3 continues in parallel:
   crouch/crawl presentation already exists; ledge/slope/climbing remains the
   next traversal investigation.
6. When body rendering is genuinely coherent, activate the visible
   3P -> portal -> 1P transition.
7. Then HUD/avatar-residue audit, NEXO_HUB/router stabilization and
   Source/Portal adapter.
8. M3 remains blocked until the Source/Portal adapter is genuinely ready.

Working principle:
**visual polish debt may remain local and explicit, but it must not stall
independent architectural phases once the underlying adapter is functional.**


## Execution boundary — generic hands stop blocking architecture

The user has explicitly prioritized forward progress over indefinite generic
hand micro-calibration.

Current boundary:
1. FP-MARIO v6 receives one bottom-anchor/proportion QA.
2. Any remaining weapon-specific hand leakage/placement becomes FP-MARIO-2
   local polish debt.
3. AVATAR-BODY neutral/portal/death pose work proceeds now.
4. Perspective transition implementation may proceed once body QA is coherent.
5. MARIOMOVE-3 traversal work continues in parallel.
6. Router/HUB and Source/Portal readiness work remain downstream as previously
   defined.

Do not reopen successful jump/audio systems to solve unrelated hand art debt.
