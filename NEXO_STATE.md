# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Estado previo confirmado

- A0-A6 — PASS funcional.
- A6.5 — FAIL: bola como autoridad física/collider rompía navegación.
- A6.6 — PASS: Mario conserva física y navegación nativa.
- A6.7 — PASS funcional: giro visual natural.
- A6.8 / A7-A8 slice 1 — PASS lógico:
  - monedas;
  - Goombas;
  - Bob-ombs por threshold;
  - crecimiento;
  - navegación preservada.

## M1 — regresión de activación detectada

La primera implementación de M1 introdujo una regresión:

- dentro de Bob-omb Battlefield no aparecía la bola;
- tampoco aparecía el HUD de M1;
- el juego base continuaba funcionando.

### Causa

El gate de mundo utilizaba:

`gCurrCourseNum == COURSE_BOB`

`gCurrCourseNum` es un global interno del engine C, pero no es la fuente Lua canónica usada para el estado del jugador local.

En Lua, `NetworkPlayer.currCourseNum` y `NetworkPlayer.currLevelNum` sí están expuestos explícitamente como campos read-only.

Por tanto la condición fallaba silenciosamente y M1 se auto-desactivaba.

## M1.1 — ACTIVE

El detector de mundo ahora usa:

```
gNetworkPlayers[0].currCourseNum == COURSE_BOB
OR
gNetworkPlayers[0].currLevelNum == LEVEL_BOB
```

La redundancia curso+nivel evita una desactivación silenciosa por diferencias de sincronización.

### Invariantes preservados

No se modificó:

- física de Mario;
- navegación;
- rigid attachments;
- compact mode;
- requisitos M1;
- NEXO Gate;
- handoff a DOOM.

El único cambio funcional es la detección correcta del mundo donde M1 debe estar activo.

## Criterio de recuperación inmediato

Al entrar en Bob-omb Battlefield:

1. debe volver a aparecer HUD `M1 CARGA IMPOSIBLE`;
2. debe aparecer la bola;
3. la misión debe comenzar con requisitos;
4. castillo/hub debe continuar sin bola ni HUD del proyecto.

Después de recuperar este baseline se continúa evaluando:
- rigid attachments;
- compact mode;
- NEXO Gate;
- misión completa.

## Portal Fabric

Se mantiene la arquitectura definida en `PORTAL_FABRIC.md`.

Primer handoff previsto:
SM64 -> DOOM.

No integrar DOOM hasta M1 PASS.
