# CLAUDE.md

Lee NEXO_STATE.md y PORTAL_FABRIC.md.

## Gate actual

Portal Fabric P1.2 — SM64 handoff -> GZDoom.

## Baseline confirmado

M1 SM64 = PASS funcional.
P1.1 manifest export = PASS.

## Validar

1. setup-doom-macos.sh;
2. run_doom.py --dry-run;
3. GZDoom inicia;
4. nexo_doom.pk3 compila/carga;
5. ZScript sin errores;
6. mensaje NEXO HANDOFF;
7. recursos derivados presentes.

No tocar física SM64 ni visual QA de attachments durante P1.2.


## Handoff durability invariant

Never clear a completed handoff on level initialization/reset.

Portal state crosses process boundaries and must remain durable until explicitly consumed or superseded.

Bridge v0.2 supports recovery from the legacy pending-reset bug.
