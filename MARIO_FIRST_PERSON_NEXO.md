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


## Local prototype pipeline

The first functional hand pipeline is now repository-driven but asset-local:

1. validate the existing local Mario hand geometry source:
   ```bash
   bash scripts/probe-mario-hands-local.sh
   ```
2. reconstruct left/right open/closed hand meshes from the user's validated US
   SM64 ROM:
   ```bash
   python3 scripts/extract-mario-hand-meshes-from-sm64-rom.py
   ```
3. render the 18 weapon-overlay layers without external Python packages:
   ```bash
   python3 scripts/render-mario-weapon-hands-local.py
   ```
4. visual prototype activation is explicit:
   ```bash
   python3 scripts/render-mario-weapon-hands-local.py --activate
   ```
5. instant rollback:
   ```bash
   rm -f assets_local/mario_hands/READY
   ```

The renderer is intentionally a **prototype art generator**. It uses a
repository pose manifest, low-poly glove geometry, simple local shading and
transparent 320x200 weapon-space layers.

Pose transforms:
`doom/mario_hands_pose_manifest.json`.

The launcher refuses to enable `nexo_mario_hands_ready` unless:
- `assets_local/mario_hands/READY` exists; and
- all 18 expected back/front PNG layers exist.

This prevents a Fist-only or partially rendered pack from being mistaken for
complete first-person embodiment.

## Runtime layer map

GZDoom native weapon PSprite remains layer 1.

NEXO uses:
- layer -2 = Mario hand component behind the weapon;
- layer 2 = Mario hand component in front of the weapon.

Both inherit weapon bob/position through the PSprite system.

Current families:
- Fist: NHFB / NHFF;
- Chainsaw: NHCB / NHCF;
- Pistol: NHPB / NHPF;
- Shotgun: NHSB / NHSF;
- SuperShotgun: NH2B / NH2F;
- Chaingun: NHGB / NHGF;
- Rocket: NHRB / NHRF;
- Plasma/Incinerator: NHEB / NHEF;
- BFG/Calamity: NHBB / NHBF.

Unknown/mod weapons clear the Mario overlays instead of showing a misleading
generic grip.

## Baked destination-hand issue

Many DOOM/Freedoom weapon sprites contain the marine's hand as part of the
weapon image itself.

The prototype therefore uses the front Mario layer to cover those baked hand
pixels where possible. FP-MARIO-1 is not PASS until runtime visual QA confirms
that no obvious Doom-marine hand remains visible.

If overlay occlusion is insufficient for a weapon, the next refinement is a
local runtime mask/reconstruction of that weapon sprite, not removal of the
native weapon logic.


## Runtime-v2 visual correction from user screenshots

Three user screenshots on 2026-10-12 invalidated the first visual prototype as
a final presentation:
- glove meshes were approximately 2-3x too large;
- pistol grip obscured the weapon instead of reading as a hand on the grip;
- two-handed weapons had oversized disconnected white forms;
- Fist still showed the destination brown fist in the center;
- Mario overlays had no attack/recoil animation.

Therefore FP-MARIO-1 remains **NOT PASS**.

### Grip-scale correction

`doom/mario_hands_pose_manifest.json` is now schema
`nexo.mario_hands.pose_manifest.v2`.

Typical glove scales were reduced from roughly 0.48-0.68 to roughly 0.20-0.26.
Grip positions were moved lower and closer to each weapon's actual hand area.

Fist now uses two small low ready gloves rather than two large blocks.

The local renderer adds a one-pixel dark outer silhouette so the white,
low-poly SM64 glove reads as a glove rather than an unbounded white/crystal
shape.

### Native Fist presentation

When:
- Mario hand assets are ready; and
- `ReadyWeapon is Fist`;

NEXO hides only the native **Fist PSprite presentation** by saving its current
PSprite scale and setting that visual scale to zero.

Native Fist:
- damage;
- timing;
- ammo semantics;
- weapon state logic

remain untouched.

Switching away from Fist or disabling the hand gate restores the saved native
weapon scale immediately.

### Procedural weapon-hand animation

The hand controller now inspects the native weapon PSprite and detects
`Fire/Hold/AltFire/AltHold` state sequences.

Presentation response is weapon-specific:
- Fist: alternating left/right Mario punch toward the center/up;
- Chainsaw: vibration;
- Pistol: short trigger-hand recoil;
- Shotgun: stronger two-hand recoil;
- SuperShotgun: larger two-hand recoil/recovery;
- Chaingun: continuous alternating vibration;
- RocketLauncher: backward/downward recoil response;
- Plasma/Incinerator: continuous energy-weapon vibration;
- BFG/Calamity: heavy recoil response.

The overlays retain GZDoom's native `PSPF_ADDWEAPON` and `PSPF_ADDBOB`
semantics, so Raise/Lower and weapon bob remain inherited from the destination
weapon.

### Mario movement coupling

First-person hands now also give a modest presentation response to:
- backflip;
- side flip;
- wall kick;
- long jump;
- dive;
- stomp.

No full-camera somersault is introduced.

### Remaining FP-MARIO work after runtime-v2

The next visual pass, after scale/animation QA, is state-specific art rather
than merely larger procedural offsets:
- dedicated Ready/Fire/Reload/Raise/Lower grip variants where useful;
- local masking/reconstruction for destination weapon sprites whose baked
  marine hand remains visible outside the Mario glove;
- improved forearm/cuff presentation;
- movement-specific hand poses instead of only offsets;
- full-body Mario for external/death/portal views.

Status: **runtime-v2 ready for QA / NOT PASS**.


## Runtime-v3 correction after 21:40-21:44 user QA

New user screenshots and playtest invalidate runtime-v2 as a final hand solution.

Confirmed improvements from v2:
- hand overlays now move with attacks;
- pistol no longer has the catastrophic v1 full-weapon occlusion;
- the runtime pack and Fire/Hold controller load correctly.

Remaining defects observed by the user:
- gloves are now too small;
- the raw low-poly white mesh does not read strongly enough as Mario's glove;
- Fist movement is too small and too linear;
- Fist/attack animation does not retrigger reliably on every fresh press;
- the launcher/two-hand families leave visibly disconnected hands;
- per-weapon size/position still needs calibration.

Therefore FP-MARIO-1 remains **NOT PASS**.

### v3 visual treatment

The pose manifest is now `nexo.mario_hands.pose_manifest.v3`.

Changes:
- moderate scale increase from v2 (~0.20-0.31) to ~0.28-0.34;
- two-hand grips moved inward toward the weapon body;
- pistol remains a single front-layer grip but is enlarged;
- Fist hands are larger and closer together;
- every rendered hand can now include:
  - a Mario-red sleeve;
  - a white glove cuff;
  - dark silhouette edging;
- hand facet contrast is compressed so the genuine N64 mesh reads less like a
  crystal and more like a white cartoon glove.

The red sleeve/cuff are renderer primitives only. The hand geometry remains the
locally extracted genuine SM64 hand mesh from the user's ROM.

### v3 attack reliability

The old logic retriggered primarily when the native PSprite entered Fire.
For weapons such as Fist, a new physical press could occur while the previous
native Fire sequence was still active; that explains the user's
"some presses animate, some do not" report.

v3 starts an animation impulse when either:
- a fresh physical BT_ATTACK/BT_ALTATTACK edge occurs; or
- the native weapon enters a new Fire/Hold sequence.

Continuous weapons still recycle their vibration while held.

### v3 nonlinear motion

Fist no longer translates along a small linear path.

Each punch now:
- alternates left/right;
- follows a nonlinear extend/retract impulse;
- moves strongly inward/upward;
- rotates through the jab;
- grows slightly in apparent scale at peak extension to simulate depth;
- gives the inactive hand a small counter-motion.

Gun families now have larger, weapon-specific recoil vectors rather than only
small vertical offsets.

Mario movement coupling is also nonlinear:
- backflip widens/raises/counter-rotates the hands;
- side flip, wall kick, dive, stomp and long jump have stronger readable
  first-person hand trajectories.

Status: **runtime-v3 prepared / user visual QA required**.


## Runtime-v4 final generic calibration

The 23:22-23:23 screenshots confirm v3 motion is materially better, but the
generic pose layer is still too visually dominant as a task.

The user explicitly requested that the project stop waiting on repeated
micro-calibration and advance independent phases.

v4 therefore serves as the final generic procedural calibration:
- Fist lowered and converged;
- pistol grip lowered;
- two-hand grips pulled toward the weapon;
- glove scale normalized around ~0.27-0.31;
- red sleeve exposure reduced;
- sleeve changed from rounded block/capsule to a tapered arm shape;
- cuff reduced;
- all nonlinear v3 attack/recoil logic retained.

After one v4 QA:
- if a weapon remains imperfect, record it as **local FP-MARIO-2 polish debt**;
- do not hold AVATAR-BODY, perspective, router or traversal architecture;
- use state-specific art/masking only for the weapon families that still prove
  visually wrong.

This is a deliberate boundary between adapter completion and polish debt.
