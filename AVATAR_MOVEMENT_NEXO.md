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
- second chained jump: ~1.08x JumpZ;
- third chained jump: ~1.18x JumpZ;
- chain advancement requires movement intent;
- the next jump must follow landing promptly (14 tics);
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
- moderate vertical boost (~1.18x base jump);
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
