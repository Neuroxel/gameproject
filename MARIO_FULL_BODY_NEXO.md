# MARIO FULL BODY — NEXO

Status: **AVATAR-BODY-1 ACTIVE / local source extraction implemented / runtime body NOT READY**

## Purpose

Mario must remain Mario across worlds.

DOOM stays first person, but a real local Mario body is required for:
- SM64 -> portal -> DOOM perspective transitions;
- DOOM -> portal exits;
- external cameras;
- death presentation;
- mirrors/reflections where supported;
- future cutscene or hub views.

This phase must **not** convert normal DOOM play into third person.

## Source authority

Body geometry comes only from the user's own validated vanilla SM64 ROM and the
already-pinned local sm64coopdx model/geo source.

Nothing extracted is committed.

Local destination:
`assets_local/mario_avatar/`

Runtime marker:
`assets_local/mario_avatar/READY`

The marker must remain absent until a coherent rendered body presentation
exists.

## AVATAR-BODY-1 — implemented source extraction

Script:
`scripts/extract-mario-body-parts-from-sm64-rom.py`

It reuses the audited display-list/ROM parser from:
`scripts/extract-mario-hand-meshes-from-sm64-rom.py`

Extracted geometry families:
- butt/root;
- torso;
- normal cap-on head;
- left/right upper arms;
- left/right forearms;
- left/right closed hands;
- left/right thighs;
- left/right legs;
- left/right feet.

The local manifest also stores the canonical hierarchy translations transcribed
from `actors/mario/geo.inc.c`, including:
- torso +68;
- head +87 from torso;
- arm attachments +67/+68 with +/-79 side offsets;
- forearms +65;
- hands +60;
- thigh roots +13/-8 with +/-42 side offsets;
- legs +89;
- feet +67.

This prevents the full-body renderer from reconstructing anatomy by intuition.

## AVATAR-BODY-2 — next

Build local neutral/portal/death pose rendering from the extracted geometry:
- proper Mario color families;
- cap-on head;
- white gloves;
- red shirt/arms;
- blue overalls/legs;
- brown shoes;
- coherent front/back/three-quarter projections.

No READY marker until those views are visually coherent.

## AVATAR-BODY-3 — integration

Use the rendered local body only where external visibility is intentional:
- portal transition;
- death/external view;
- mirror/external camera;
- hub/cutscene.

The current GZDoom perspective adapter already refuses to show a third-person
proxy unless `nexo_avatar_body_ready=true`.

That invariant remains mandatory: **never show Doomguy/Freedoom marine and call
it Mario.**

## Relationship to FP-MARIO

First-person hands and full body are separate render responsibilities:
- FP-MARIO owns weapon manipulation while normal DOOM remains first person;
- AVATAR-BODY owns external/camera-visible Mario.

They share the same avatar identity but do not require the same sprite pipeline.
