# CLAUDE.md

Lee `NEXO_STATE.md` primero.

## Gate activo

M1 vertical slice:

- rigid attachments;
- compact mode;
- mission objectives;
- return gate;
- persistent DOOM handoff.

## Restricciones arquitectónicas

- Mario es la única autoridad de navegación/física.
- NO reintroducir collider rígido de la bola.
- Masa lógica y escala visual son variables diferentes.
- Attachments no deben floor-clampearse individualmente.
- No añadir Koopa/otros mundos hasta validar M1.

## Validar

1. Sin bola en castillo.
2. Bola al entrar BOB.
3. Attachments rígidos/ocultables.
4. COMPACT cerca de paredes/techo.
5. Masa lógica preservada.
6. Requisitos M1.
7. Gate en spawn.
8. Mission complete al tocarlo.
9. handoff_target=DOOM guardado.
10. navegación sin regresión.
