# AGENTS.md

## Estado canónico

Leer `NEXO_STATE.md`.

## Gate actual

M1 vertical slice.

### Invariantes

- Mario = física/navegación.
- Bola = visual/absorción/progresión.
- Masa lógica != escala visual.
- Compact mode sólo cambia presentación.
- Attachments son rígidos; se ocultan si la geometría los tapa.
- No floor-clamp individual.
- NEXO Gate usa handoff persistente.

No ampliar catálogo ni integrar DOOM hasta PASS de M1.
