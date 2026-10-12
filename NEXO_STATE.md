# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Gates confirmados

- A0 — PASS.
- A1-A3.1 — PASS.
- A4-A5 — PASS.
- A6 — PASS: crecimiento visual.
- A6.5 — FAIL: bola como autoridad física rompía navegación.
- **A6.6 — PASS:** Mario vuelve a ser la autoridad física; el usuario confirma que puede entrar correctamente al escenario y navegar sin los bloqueos anteriores.

## Evidencia A6.6

El usuario confirma:

- navegación mucho mejor;
- entrada al escenario funciona;
- crecimiento continúa funcionando;
- Goombas absorbidos quedan visibles asociados a la bola;
- ya no aparecen los bloqueos graves de puertas/superficies de A6.5.

Quedan dos defectos visuales, no estructurales:

1. los Goombas aparecen demasiado separados de la superficie;
2. la esfera/attachments giran demasiado rápido al avanzar.

La arquitectura de navegación **no se toca**.

## A6.7 — ACTIVE: pegado visual + giro natural

### Causa identificada

El actor `spiny_ball_geo` tiene un `GEO_SCALE(..., 16384)`, equivalente a una escala interna de 0.25. La aproximación anterior del radio visible (`48 * escala + 28`) sobredimensionaba fuertemente la superficie utilizada para posicionar attachments.

Además, la rotación anterior era:

`pitch += distancia * 420`

lo que no dependía del radio y producía un giro visual excesivo.

### Correcciones

1. Radio visual del cuerpo rojo:
   `radio = 24 * visual_scale`.
2. Los Goombas adheridos se colocan ligeramente dentro de la superficie:
   `radio_attachment = radio - 7`.
3. El radio de absorción se mantiene cómodo con padding independiente (+62), para no hacer más difícil capturar enemigos.
4. El giro se calcula desde la relación física:
   `ángulo ~= distancia / radio`.
5. Conversión a unidades angulares SM64:
   `65536 / (2π) ~= 10430.378`.
6. Se aplica un factor visual 0.35 para que el giro sea deliberadamente más lento y legible.
7. El yaw visual deja de saltar instantáneamente con cada giro de Mario; aproxima lentamente con paso `0x180`.
8. La distancia visual Mario-bola se reajusta al nuevo radio, sin devolver colisiones a la bola.

### Criterios de PASS

- navegación debe permanecer igual de buena que A6.6;
- Goombas deben verse tocando/incrustados en la esfera, no flotando separados;
- al avanzar, la rotación debe ser notoriamente más lenta;
- al girar Mario, attachments no deben orbitar bruscamente alrededor de la bola;
- crecimiento sigue funcionando;
- absorción sigue siendo fácil;
- no reaparecen bloqueos de puertas/superficies.

## Decisión de arquitectura preservada

Mario = autoridad física y navegación.

Bola = visual + absorción + crecimiento + attachments.

No restaurar hitbox rígida de la bola durante esta fase.

## Próximo gate

Si A6.7 = PASS, A7-A8:
- clases de objetos;
- umbrales de tamaño;
- Bob-ombs, Koopas y objetos pequeños;
- feedback "demasiado grande";
- attachments por categoría.

## Reglas

- No versionar ROMs.
- No instalar tooling pesado sin necesidad.
- Priorizar evidencia nueva.
