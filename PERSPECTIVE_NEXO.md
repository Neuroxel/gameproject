# NEXO PERSPECTIVE & EMBODIMENT CONTRACT v0.1

## Principle

NEXO transports the **character and state**, not a fixed camera.

Mario remains the same campaign avatar while each world chooses the perspective
that best preserves its native gameplay language.

## Canonical mapping

| World family | Perspective | Embodiment |
|---|---|---|
| SM64/platforming | third person | full Mario body |
| DOOM/shooter | first person | Mario identity + weapon hands/body when assets exist |
| Portal-like | first person | hands/tool + full body in mirrors/cameras/transitions |
| Skate/Taxi/GTA-like | third person | full body/vehicle embodiment |
| 2D worlds | side/projection | sprite/projection adapter |

## Portal camera grammar

Third person -> first person:
1. portal acquisition;
2. camera approaches avatar;
3. avatar/body crosses threshold;
4. camera resolves into eye/weapon viewpoint;
5. native first-person HUD becomes authoritative.

First person -> third person:
1. portal acquisition;
2. viewpoint reaches threshold;
3. camera detaches/pulls out;
4. full avatar becomes authoritative;
5. destination third-person camera takes control.

## Current DOOM implementation

The DOOM adapter records and announces:
`third_person(SM64) -> first_person(DOOM)`.

A short transition state already exists in ZScript.

Third-person chase-body reveal is deliberately gated behind:
`nexo_avatar_body_ready`.

Until a real locally supplied Mario body/skin is available, NEXO does **not**
show Doomguy and call him Mario. First-person remains authoritative.

A local avatar package will later enable:
- portal entry/exit body reveal;
- chase-camera transition;
- death/external camera representation;
- optional mirrors/security cameras;
- Mario-compatible weapon hands.

## Invariant

Do not force one perspective across all engines merely for consistency.
Consistency belongs to identity, controls, state and portal language.
