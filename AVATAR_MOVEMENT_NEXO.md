# NEXO AVATAR MOVEMENT — MARIO v0.1

## Principle

NEXO transports Mario's identity and a recognizable locomotion grammar into
other worlds, but the destination world keeps authority over level geometry,
combat pacing, camera and core engine rules.

For DOOM this means:

- DOOM remains first-person during normal play;
- Doom weapons and world collision remain native;
- Mario gains selected traversal signatures;
- SM64 heights/speeds are adapted rather than copied literally;
- no movement feature may create flight, infinite bunny-hop escalation or
  trivialize map progression.

This is an **avatar adapter**, not an M2 mission mechanic.

## MARIOMOVE-1 — first DOOM slice

Implemented behind:

`nexo_mario_movement=true`

Current slice:

### Normal / triple jump

- first jump: native DOOM jump height;
- second chained jump: ~1.10x JumpZ;
- third chained jump: ~1.24x JumpZ;
- chain advancement requires movement intent;
- the next jump must follow landing promptly (24 tics);
- staying grounded breaks the chain;
- after jump 3 the sequence restarts at jump 1;
- the engine still performs the actual jump legality check.

Audio:
- jump 1 -> `nexo/mario/jump`;
- jump 2 -> `nexo/mario/jump2`;
- jump 3 -> `nexo/mario/jump3`.

The sound is emitted only after a real jump is confirmed. Raw button presses do
not create jump voices.

### Backflip

Crouch + fresh jump press near standstill:

- requires enough clearance to stand;
- uncrouches safely;
- distinctly higher vertical boost (~1.35x base jump);
- small backward impulse;
- resets triple-jump chain.

Audio:
`nexo/mario/backflip`.

### Long jump

Crouch + fresh jump press while moving forward:

- requires enough clearance to stand;
- lower vertical component (~0.78x);
- forward impulse;
- resets triple-jump chain.

Audio:
`nexo/mario/longjump`.

### Ground pound / stomp

Fresh crouch press while airborne:

- cancels most horizontal momentum;
- forces a fast downward velocity;
- only one activation per airborne cycle;
- resets after landing;
- does **not** yet deal radial/stomp damage.

Audio:
`nexo/mario/stomp`.

Impact damage is intentionally deferred until traversal safety is proven.

## Local movement voice set

Nintendo audio remains local-only and gitignored.

Expanded optional local cues:

- `jump2.wav`
- `jump3.wav`
- `backflip.wav`
- `longjump.wav`
- `stomp.wav`
- `dive.wav`

The existing extraction checkout can be reused without the ROM copy:

```bash
bash scripts/extend-mario-movement-sfx-local.sh
```

If those samples are absent, runtime SNDINFO falls back to existing Mario cues
rather than failing.

## Required future Mario locomotion catalog

"All Mario movements" is a project requirement to evaluate through the avatar
adapter. They should be integrated when compatible with the destination world,
not blindly copied.

### MARIOMOVE-2 — directional traversal

Required:
- side flip / turnaround jump;
- wall kick / wall jump;
- dive;
- dive-to-slide / slope slide;
- crouch/crawl where useful;
- landing/impact semantics.

### MARIOMOVE-3 — environment interactions

Required where engine geometry supports them:
- ledge grab;
- ledge pull-up;
- hanging/climbing;
- pole/climb semantics;
- swimming/water movement;
- steep-slope behavior.

### MARIOMOVE-4 — action grammar

Evaluate without replacing shooter combat unnecessarily:
- punch/kick as contextual/melee identity;
- jump kick / aerial action;
- stomp damage;
- dive collision;
- pickup/carry/throw where a world adapter can support it.

Guns remain the dominant combat language in DOOM. Mario melee should be an
avatar capability or contextual echo, not a reason to remove DOOM's native
weapon system.

## First-person readability

Moves that were designed for a third-person camera require first-person
adaptation:

- avoid violent camera rotations;
- backflip does not literally spin the camera 360 degrees;
- side flip/wall kick should communicate direction through velocity, sound,
  weapon/hand animation and modest camera response;
- ground pound should not make the player disoriented;
- external full-body animation can become visible later during portal/camera
  transitions once the Mario body asset pipeline exists.

## Control grammar

Current semantics:

- TRAVERSAL / Jump -> normal and chained jump;
- CROUCH / MOVEMENT MODIFIER:
  - ground + jump + stationary -> backflip;
  - ground + jump + forward motion -> long jump;
  - air + fresh crouch -> stomp.

A controller binding for crouch/movement modifier must be validated as a
separate control QA step. Do not steal RT fire, LT secondary action, A use or Y
jump from the already validated DOOM mapping.

## Safety gates

MARIOMOVE-1 is PASS only after the user confirms:

1. ordinary jump still works;
2. button spam while airborne does not replay jump audio;
3. moving chained jumps reach 1 -> 2 -> 3 and reset;
4. jump heights remain compatible with MAP01;
5. crouch + stationary jump performs backflip;
6. crouch + running jump performs long jump;
7. airborne crouch performs one stomp per airborne cycle;
8. no stuck crouch / ceiling clip;
9. weapons, use, controller and M2 remain functional;
10. death/respawn does not preserve a broken movement chain.

Do not expand to wall-kick/side-flip/dive until this slice is stable.


## MARIOMOVE-2 — directional traversal implementation

### Side flip / turnaround jump

Implemented:
- requires a strong forward/back or left/right input reversal;
- requires a fresh Jump press on the reversal;
- moderate high jump (~1.22x);
- redirects momentum toward the new input;
- resets the triple-jump chain;
- does not spin the first-person camera.

Audio:
`nexo/mario/sideflip`, currently aliased locally to the backflip cue unless a
dedicated local cue is added later.

### Wall kick / wall jump

Implemented conservatively:
- player must be airborne;
- Jump must be a fresh press;
- GZDoom's `MovementBlockingLine` must report that a real wall stopped the
  current XY movement;
- vertical velocity is restored to a moderate jump;
- horizontal impulse pushes away from the attempted approach direction;
- 9-tic cooldown prevents repeated same-frame/same-contact abuse;
- triple chain, dive and stomp state reset.

Audio:
`nexo/mario/wallkick`, currently aliased to jump2.

This intentionally does not allow proximity-only wall jumps.

### Dive -> slide

Implemented:
- airborne + strong forward motion + fresh crouch/L3 = dive;
- strong forward impulse;
- modest downward component;
- landing starts a short 14-tic ground slide;
- slide receives only a small sustaining thrust and cannot accelerate forever;
- jumping or leaving the ground ends the slide.

Audio:
`nexo/mario/dive`.

### Ground pound distinction

Airborne L3 now means:
- strong forward intent -> dive;
- otherwise -> stomp/ground pound.

This lets both Mario actions share the existing movement modifier without
stealing DOOM's fire/use bindings.

## Triple-jump correction

The first implementation could never reach jump 2/3 because GZDoom keeps
`jumpTics` blocked for more than 18 tics after a jump while the NEXO chain
window was only 14 tics.

Correction:
- landing clears the inherited DOOM jump cooldown;
- every Mario ground jump requires a **fresh Jump press**;
- held Jump cannot auto-hop;
- the chain window is now 24 tics after landing;
- jump 1/2/3 factors are ~1.00 / 1.10 / 1.24;
- rapid Jump spam while airborne cannot create extra jumps or jump voices.

## First-person rotation rule

Backflip/side-flip/wall-kick mechanics preserve directional physics but do not
rotate the first-person camera through Mario's full body rotation.

The visual somersault belongs to:
- first-person Mario hand/weapon animation;
- eventual third-person/full-body views during portals/cinematics/death.

This preserves Mario identity without inducing FPS camera sickness.


## MARIOMOVE-2 runtime-v2 — SM64 proportions

User evidence on 2026-10-12 confirmed:
- wall kick is functional;
- the first triple-jump implementation still felt too flat;
- the jump voice succession did not match SM64 closely enough.

The adapter is now anchored to the source-game vertical families instead of
small arbitrary multipliers.

SM64 source-family launch values used as ratios:
- normal jump: ~42;
- double jump: ~52;
- triple jump: ~69;
- backflip: ~62;
- side flip: ~62;
- wall kick: ~62;
- long jump: ~30 plus strong horizontal travel.

NEXO therefore targets:
- normal: 1.000x;
- double: 52/42 (~1.238x);
- triple: 69/42 (~1.643x);
- backflip/side flip/wall kick: 62/42 (~1.476x);
- long jump: 30/42 (~0.714x) vertically.

These are **launch-speed ratios**, not unconstrained map-height multipliers.

### Ceiling-aware jump governor

Every enhanced vertical launch is passed through
`NexoCeilingSafeLaunch()`.

The governor:
1. measures live headroom from Mario's full standing height to `CeilingZ`;
2. reserves 5 map units of head clearance;
3. reads GZDoom's effective `GetGravity()`;
4. solves the discrete ballistic apex estimate for the maximum safe launch
   speed;
5. uses the smaller of the Mario target and that safe speed.

Result:
- in tall rooms Mario gets the strong double/triple/backflip distinction;
- in ordinary DOOM rooms the jump rises as high as the room safely permits;
- low ceilings dynamically compress the jump instead of causing routine head
  collisions;
- there is no one global low multiplier that makes Mario feel flat everywhere.

### Canonical jump voice grammar

The previous fixed `jump/jump2/jump3` mapping was not faithful enough.

Runtime-v2 follows SM64's voice grammar:
- jump 1: random Yah / Wah / Hoo;
- jump 2: dedicated Hoo-hoo;
- jump 3: Yahoo / Waha / Yippee with 60/20/20 weighting.

Local logical cues:
- `jump1_hoo`;
- `jump1_wah`;
- `jump1_yah`;
- `jump2_hoohoo`;
- `jump3_yahoo`;
- `jump3_waha`;
- `jump3_yippee`.

The chain window is 28 tics after a real landing and still requires a fresh
Jump press. Held Jump and airborne button spam remain invalid.

Status: **runtime-v2 prepared; user retest required**.
