# NEXO PORTAL FABRIC — ARQUITECTURA CANÓNICA v0.1

## Propósito

Convertir los portales en una interfaz de transición entre mundos/engines, no sólo en un efecto visual.

## Contrato universal

Cada mundo produce un estado neutral:

```
HandoffState
- source_world
- target_world
- mission_id
- score
- elapsed_time
- logical_mass
- cargo[]
- abilities[]
- chaos_level
- style_multiplier
```

Cada adapter decide qué significan esos datos en su juego.

Ejemplo:

```
SM64
  Goombas/Bob-ombs/monedas
        |
        v
Universal Handoff
        |
        v
DOOM adapter
  Bob-ombs -> explosivos
  monedas -> recurso/vida
  masa -> resistencia/capacidad
```

## Niveles de portal

### P0 — Gate semántico
Mismo engine. Completa misión y guarda handoff.

Implementado en M1.

### P1 — Hard transition
Gate -> launcher/bridge -> cerrar/suspender mundo A -> abrir mundo B.

Primer objetivo: SM64 -> DOOM.

### P2 — Coordinated transition
Ambos runtimes disponibles; portal coordina estado y cambio con latencia mínima.

### P3 — Visual passthrough
Se ve/renderiza el otro mundo a través del portal antes de cruzar.

Alta dificultad.

### P4 — Bidirectional seamless portal
Movimiento/render/depth/state cruzan motores en tiempo real.

Objetivo de investigación, no requisito inicial.

## Portal / Valve Portal

El juego Portal es una referencia natural y un posible mundo futuro, pero no debe confundirse con el sistema NEXO Portal Fabric.

Podemos reutilizar su lenguaje:
- entrada/salida;
- continuidad espacial;
- conservación de momentum;
- puzzles de tránsito.

Un mundo Source/Portal requerirá su propio adapter.

## Mundos 2D

Tres estrategias posibles:

1. **2.5D adapter**: cámara lateral + profundidad restringida; jugador 3D actúa dentro del plano.
2. **Avatar projection**: estado 3D se convierte en sprite/representación 2D durante el mundo.
3. **Portal surface**: mundo 2D aparece como superficie dentro del 3D antes del handoff.

El contrato universal permite cambiar representación sin perder carga/score/estado.

## Orden de implementación

1. Validar M1 en SM64.
2. Definir manifiesto de handoff real fuera de mod_storage.
3. Crear launcher/bridge local en macOS.
4. Elegir runtime DOOM.
5. Implementar DOOM adapter mínimo.
6. SM64 -> Gate -> DOOM.
7. DOOM -> return gate -> SM64 u otro mundo.
8. Sólo después estudiar passthrough visual/seamless.

## Principio

No integrar un juego sólo por ser famoso.

Cada mundo o mecánica debe aportar una función:
- Katamari: carga/crecimiento.
- Crazy Taxi: entrega/tiempo/ruta.
- Tony Hawk/Skate: estilo/riesgo.
- GTA: caos/dificultad dinámica.
- Portal: tránsito/puzzles espaciales.
- DOOM: combate/conversión de carga en recursos.
