# NEXO MARIO FIRST-PERSON EMBODIMENT v0.1

## Goal

Inside first-person worlds, the camera belongs to the destination but the body
seen operating tools/weapons must still read as Mario.

For DOOM this means:

- keep the native DOOM/Freedoom weapon as the world object;
- replace the anonymous/Doom-marine hand ownership with Mario gloves/hands;
- show Mario actually gripping and operating every supported weapon;
- do not limit embodiment to the Fist weapon;
- do not convert normal DOOM gameplay to third person.

## Required weapon coverage

Initial DOOM family:
- Fist;
- Chainsaw;
- Pistol;
- Shotgun;
- SuperShotgun;
- Chaingun;
- RocketLauncher;
- PlasmaRifle;
- BFG9000;
- Freedoom/ID24 equivalents when the current IWAD exposes them.

Each weapon needs hand poses for the states that actually occur:
- Raise;
- Ready/Idle;
- Fire;
- AltFire where applicable;
- Reload where applicable;
- Lower;
- recoil/recovery frames where necessary.

## Rendering architecture

Preferred GZDoom mechanism:
**PSprite overlay layers**, not replacement of the world weapon logic.

GZDoom 4.14.2 exposes:
- `A_Overlay`;
- `A_OverlayOffset`;
- `A_OverlayScale`;
- `A_OverlayRotate`;
- additional PSprite layers independent from `PSP_WEAPON`.

Therefore the target composition is:

```text
PSP_WEAPON
  = native DOOM/Freedoom weapon sprite / firing logic

NEXO hand overlay layers
  = Mario left/right gloves
  = pose and offset selected for current ReadyWeapon/state
```

This preserves:
- weapon firing;
- ammo;
- recoil timing;
- muzzle flash;
- weapon switching;
- map/mod compatibility.

## Asset rule

Mario hand geometry/art is local-only.

The existing user-local sm64coopdx extraction checkout contains canonical Mario
hand geometry symbols including:
- `mario_right_hand_closed`;
- `mario_right_hand_open`;
- `mario_left_hand_closed`;
- `mario_left_hand_open`.

Use the user's local extracted/build material to derive first-person renders.
Do not commit Nintendo-origin hand renders, textures or geometry.

Repository may contain:
- renderer/export scripts;
- pose manifests;
- coordinates;
- hashes;
- transparent placeholders;
- ZScript overlay logic.

Runtime local directory:
`assets_local/mario_hands/`.

## Pose strategy

Do not paste a generic glove on every gun.

Use per-weapon grip roles:

- Fist: both Mario gloves / punch pose.
- Chainsaw: two-handed wide grip.
- Pistol: dominant hand grip + optional support hand.
- Shotgun: trigger hand + fore-end/support hand.
- SuperShotgun: two-handed grip + reload/open handling.
- Chaingun: two-handed stabilizing grip.
- RocketLauncher: trigger/support grip positioned around launcher body.
- Plasma/BFG: wide two-handed sci-fi grip.

The gun remains visually recognizable as the destination weapon.

## Movement coupling

Mario movement should affect embodiment without rotating the FPS camera through
full somersaults.

Examples:
- backflip: hands/weapon lift and roll subtly while body performs the implied
  somersault externally;
- side flip: lateral hand/weapon response;
- wall kick: brief recoil away from wall;
- dive: weapon lowers/extends forward;
- stomp: weapon lifts slightly before impact.

These are presentation cues, not weapon input suppression.

## Gate FP-MARIO-1

PASS requires:
1. Mario glove identity is visible in first person;
2. pistol grip reads correctly;
3. shotgun grip reads correctly;
4. rocket launcher grip reads correctly;
5. plasma/BFG grip reads correctly;
6. Fist is Mario, but the implementation is not Fist-only;
7. firing/reloading/switching remain native;
8. no Doom-marine hands remain visibly embedded under the Mario overlay;
9. no camera/perspective regression;
10. assets remain local-only.

## Order

Do not activate a visible overlay before at least pistol + shotgun + rocket
launcher poses are available locally. A partial Fist-only implementation would
misrepresent the intended avatar embodiment.
