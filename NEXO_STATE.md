# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Estado previo confirmado

- A0-A6 — PASS funcional.
- A6.5 — FAIL: bola como autoridad física/collider rompía navegación.
- A6.6 — PASS: Mario conserva física y navegación nativa.
- A6.7 — PASS funcional: giro visual mucho más natural.
- A6.8 / A7-A8 slice 1 — PASS lógico:
  - crecimiento funciona;
  - monedas se absorben;
  - Goombas se absorben;
  - Bob-ombs pequeños se bloquean y grandes se absorben;
  - navegación se preserva.
- Fallos visuales pendientes observados:
  - attachments no forman un cuerpo rígido coherente respecto al escenario;
  - algunos atraviesan suelo/paredes;
  - esfera visual atraviesa geometría porque deliberadamente no tiene collider;
  - crecimiento sin objetivo todavía no constituye un juego.

## Decisión de producto

No se seguirá expandiendo el catálogo de enemigos hasta validar un loop jugable completo.

El proyecto deja de ser "Katamari dentro de Mario" y pasa a probar una gramática propia:

**recolectar -> construir carga -> aumentar caos/capacidad -> regresar -> portal -> siguiente mundo**

Katamari aporta carga/masa.
Crazy Taxi aportará entrega/destino.
Tony Hawk/Skate aportará estilo/riesgo.
GTA aportará director de caos/wanted.
DOOM será el primer runtime/mundo externo.
Portal se incorpora conceptualmente como lenguaje de transición entre mundos.

## A8.1 — RIGID ATTACHMENTS

Se elimina el floor-clamp individual.

Regla nueva:

- cada objeto absorbido conserva un vector radial rígido;
- sólo la rotación de la bola cambia ese vector;
- si una pared/suelo queda entre el centro de la bola y el attachment, el attachment se oculta temporalmente con `GRAPH_RENDER_INVISIBLE`;
- al emerger vuelve a mostrarse;
- no se mueve arbitrariamente para "salvarlo" del suelo.

Esto preserva la ilusión de un cuerpo rígido.

## A8.2 — COMPACT MODE

Se separan tres conceptos:

1. **masa lógica**: progresión real y umbrales;
2. **escala visual**: tamaño dibujado;
3. **clearance**: espacio disponible alrededor.

La masa lógica nunca disminuye.

La escala visual usa raycasts `collision_find_surface_on_ray()` en 8 direcciones horizontales + techo.

Si el escenario no admite el diámetro lógico:

- la bola entra en `COMPACT`;
- se encoge visualmente de forma suave;
- la progresión/masa se mantiene;
- al volver a espacio abierto recupera su tamaño;
- Mario sigue siendo la única autoridad física.

Esto evita volver a romper puertas y pasillos, pero hace visible que la bola está respondiendo al escenario.

## M1 — CARGA IMPOSIBLE

Misión limitada por ahora a Bob-omb Battlefield (`COURSE_BOB`).

### Requisitos

- 5 monedas;
- 4 Goombas;
- 2 Bob-ombs;
- masa lógica >= 3.80.

Cuando se cumplen:

- estado pasa a `RETURN`;
- aparece el **NEXO GATE** en el punto inicial;
- el jugador debe volver al gate.

El gate usa por ahora `E_MODEL_TRANSPARENT_STAR` como placeholder visual, no como diseño final.

Al cruzarlo:

- misión termina;
- se calcula score + bonus de tiempo;
- se guarda best score;
- se escribe un estado persistente de handoff con destino `DOOM`.

### Handoff persistente

Se guardan mediante `mod_storage_*`:

- handoff_pending;
- handoff_source = SM64_BOB;
- handoff_target = DOOM;
- scale;
- monedas;
- Goombas;
- Bob-ombs;
- score.

Esto crea desde ahora un contrato de transición que luego podrá consumir un launcher/bridge externo.

## PORTAL FABRIC — dirección arquitectónica

El "portal" no será sólo un efecto visual.

Será una interfaz estándar:

```
WORLD A
  -> Universal Handoff State
  -> Portal / Gate
  -> World Adapter
  -> WORLD B
```

Primer destino: DOOM.

Destinos futuros posibles:
- Portal/Source;
- ciudades/escenarios de otros juegos;
- mundos 2D usando adapter 2.5D;
- mundos reconstruidos/reimplementados.

El objetivo es que una misión pueda atravesar varios universos y que lo recogido/hecho en uno tenga consecuencias en el siguiente.

## Gate actual: M1 vertical slice

Criterios de PASS:

1. Bob-omb Battlefield inicia sin bola en el castillo/hub.
2. Dentro de BOB, la bola aparece.
3. Attachments se mantienen rígidos respecto a la bola.
4. Attachments ocultos por suelo/pared reaparecen al emerger.
5. No se dispersan ni se floor-clampean individualmente.
6. Cerca de paredes/techos la bola entra en COMPACT.
7. En espacio abierto recupera su escala lógica.
8. La masa lógica no disminuye en compact mode.
9. Monedas/Goombas/Bob-ombs siguen funcionando.
10. HUD muestra objetivos claros.
11. Al cumplir requisitos aparece NEXO Gate en el spawn.
12. Volver y tocar el gate completa la misión.
13. Se muestra score/best/time.
14. No regresan bugs de navegación.

## Próxima decisión

Sólo si M1 es divertido/repetible:

- A9 kill gate de diversión;
- añadir scoring de estilo;
- Crazy Taxi delivery layer;
- prototipo DOOM;
- bridge real de handoff.

No agregar mundos por fama: cada sistema debe cumplir una función en el loop.
