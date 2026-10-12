# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Objetivo

Construir progresivamente un mashup jugable, divertido y observable, comenzando por SM64CoopDX y evitando complejidad técnica que no aumente el valor del prototipo.

## Arquitectura decidida

### Fase A — SM64CoopDX + Lua

- A0 — pipeline de mod y HUD visible.
- A1 — objeto rodante visible en 3D.
- A2 — física estable.
- A3 — Mario puede empujarlo y golpearlo con respuestas diferenciadas.
- A4 — detección de entidades absorbibles.
- A5 — primer Goomba absorbible.
- A6 — crecimiento visual + físico real.
- A7 — umbrales de absorción por tamaño.
- A8 — HUD/progresión de tamaño y puntuación.
- A9 — kill gate de diversión.
- A10 — sistema tipo GTA wanted, sólo si A9 = PASS.
- A11 — sistema de combos tipo Tony Hawk, sólo si el prototipo sigue siendo divertido.

## Gates confirmados

- A0 = PASS.
- A1-A3.1 = PASS.
- A4 = PASS: Goomba detectado.
- A5 = PASS: Goomba absorbido y eliminado; contador aumenta.

## A6 — FAIL / causa de revisión

Evidencia del usuario:

- `GOOMBAS` aumenta correctamente;
- `TAM` cambia de 1.15 a 1.33;
- no se aprecia cambio visual en la esfera;
- la esfera inicial resulta demasiado pequeña y difícil de controlar.

No se considera A6 aprobado.

## A6.1 — PENDING VALIDATION

Cambios:

1. Tamaño inicial sube de 1.15 a **1.80**.
2. Cada Goomba añade **+0.55** de escala objetivo, deliberadamente exagerado para que la validación sea inequívoca.
3. Máximo provisional aumenta a 6.00.
4. La escala se aplica con `obj_scale_xyz()`, que escribe explícitamente X/Y/Z de `header.gfx.scale`.
5. Se anima gradualmente `visual_scale -> target_scale` para que el crecimiento se vea en movimiento.
6. El HUD separa:
   - `OBJ` = escala objetivo lógica;
   - `VIS` = escala visual que estamos aplicando;
   - `GFX` = valor leído de `ball.header.gfx.scale.x` desde el objeto real.
7. Hitbox y wall radius se recalculan usando `visual_scale`.
8. Se aumenta el radio inicial de empuje.
9. Se baja velocidad máxima del empuje normal para mejorar control.
10. El golpe B sigue siendo notablemente más fuerte.

### Criterio de PASS

Después de absorber un Goomba:

- `OBJ` aumenta de 1.80 a 2.35;
- `VIS` anima progresivamente hasta 2.35;
- `GFX` acompaña a `VIS`;
- la esfera aumenta de tamaño de forma visualmente obvia;
- la esfera inicial resulta sensiblemente más fácil de empujar/controlar;
- el crecimiento de hitbox acompaña al visual.

Si `VIS` sube pero `GFX` no, el problema está en la aplicación de escala al objeto.
Si `GFX` sube pero el modelo no crece, el problema está en la jerarquía/GeoLayout del modelo provisional y se reemplazará por geometría propia o un actor distinto.

## Limitaciones aceptadas

- Modelo Spiny Ball provisional.
- Goomba absorbido desaparece en lugar de quedar pegado.
- Sólo Goombas.
- Escaleras fuera de alcance.
- Multiplayer aún no validado.

No comenzar A7 hasta A6.1 PASS.

## Stack autorizado para A0–A9

- SM64CoopDX
- Lua API de SM64CoopDX
- Git/GitHub
- ChatGPT para arquitectura, código, revisión y trazabilidad
- Claude Code sólo cuando la ejecución/depuración local aporte valor

## Reglas

- Nunca versionar ROMs ni dumps.
- Nunca reemplazar originales.
- Registrar cambios de criterio y evidencia.
