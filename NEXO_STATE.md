# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Estado verificado

- A0 — PASS.
- A1-A3.1 — PASS.
- A4-A5 — PASS.
- A6 — PASS: crecimiento.
- A6.5 — FAIL: bola como collider/autoridad física rompía navegación.
- A6.6 — PASS: Mario vuelve a ser autoridad física; navegación y entrada a niveles funcionan.
- A6.7 — PASS PARCIAL: velocidad de giro ya es mucho más natural y navegación sigue estable.

## Evidencia nueva

El usuario confirma:

- la bola ahora rueda mucho mejor y más lento;
- la navegación sigue funcionando;
- al crecer, el centro visual no sube y la esfera se hunde progresivamente en el piso;
- los Goombas ya están más cerca, pero quedan demasiado embebidos en la esfera;
- quiere preservar exactamente la física/navegación actual y avanzar A7-A8.

## A6.8 — ACTIVE: grounding visual y contacto de attachments

### Corrección vertical

El modelo provisional tiene:

- radio visible aproximado = `24 * visual_scale`;
- desplazamiento interno Y de `-34` bajo `GEO_SCALE 0.25`, equivalente a ~`8.5 * visual_scale`.

La altura visual ahora se calcula:

`Y = floor + radio_visible + offset_centro_modelo`

Por tanto, al crecer, la bola también sube y su parte inferior permanece cerca del suelo en vez de hundirse.

### Corrección de objetos pegados

Los objetos ya no se colocan dentro de la esfera.

Posición radial:

`radio_attachment = radio_bola + offset_por_tipo`

Offsets iniciales:

- moneda: +8;
- Goomba: +28;
- Bob-omb: +25.

Además, los attachments del hemisferio inferior reciben un clamp visual contra el piso para evitar desaparecer profundamente bajo el terreno.

## A7-A8 — ACTIVE: primera progresión por tamaños

Se introduce un sistema de specs por categoría.

### Tier 1 — disponible desde el inicio

**Moneda**
- threshold: 1.80
- crecimiento: +0.08
- attachment visual pasivo

**Goomba**
- threshold: 1.80
- crecimiento: +0.35
- attachment visual pasivo

### Tier 2 — bloqueado inicialmente

**Bob-omb**
- threshold: 2.70
- crecimiento: +0.50
- attachment visual pasivo

Si la bola toca/se acerca a un objeto que supera su tier, el HUD muestra:

`DEMASIADO GRANDE: BOB-OMB requiere TAM 2.70`

No se elimina ni modifica el enemigo.

### HUD A8

Muestra:

- total de objetos;
- tamaño;
- contador de monedas;
- contador de Goombas;
- contador de Bob-ombs;
- feedback de absorción;
- feedback de bloqueo por tamaño.

## Criterios de PASS A6.8 + A7/A8 slice 1

1. La bola no se hunde progresivamente al crecer.
2. Su base visual permanece aproximadamente apoyada en el terreno.
3. Goombas quedan pegados/sobre la superficie y no profundamente fusionados.
4. Objetos en la parte inferior no desaparecen completamente bajo el piso.
5. Navegación A6.6 no regresa.
6. Monedas pueden absorberse desde el inicio.
7. Goombas pueden absorberse desde el inicio.
8. Bob-ombs no pueden absorberse bajo tamaño 2.70.
9. El HUD avisa correctamente del bloqueo.
10. Al alcanzar 2.70, Bob-ombs sí pueden absorberse y quedan visibles pegados.
11. El crecimiento continúa suave.
12. No hay crash ni soft-lock.

## Próximo slice A7-A8

Después de PASS:

- Koopa / shell;
- un tier mayor;
- objetos estáticos seleccionados;
- puntuación y bonus por cadena;
- feedback visual más rico;
- evaluar reemplazo del modelo con puntas por esfera propia.

## Restricción arquitectónica

Mario = física y navegación.

Bola = visual, absorción, crecimiento y attachments.

No reintroducir collider rígido de la bola en niveles SM64.
