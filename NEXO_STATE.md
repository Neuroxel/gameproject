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
- A6 — crecimiento real del objeto.
- A7 — umbrales de absorción por tamaño.
- A8 — HUD/progresión de tamaño y puntuación.
- A9 — kill gate de diversión.
- A10 — sistema tipo GTA wanted, sólo si A9 = PASS.
- A11 — sistema de combos tipo Tony Hawk, sólo si el prototipo sigue siendo divertido.

### Fase C

Añadir sistemas tipo Crazy Taxi sólo después de validar la base de A.

### Fase D

Migrar a mashup multi-juego real con Godot + libsm64 + contenido/mapas compatibles con DOOM, sólo tras validar el gameplay.

## Evidencia y gates

### A0 — PASS

Confirmado el 2026-10-12.

### A1-A3.1 — PASS

Confirmado por el usuario el 2026-10-12:

- el modelo provisional se percibe en 3D;
- puede empujarse de forma controlable;
- el golpe fuerte con B produce un desplazamiento claramente mayor;
- la física básica continúa estable.

La limitación de escaleras permanece documentada y no bloquea el gate.

### A4-A6 — PENDING VALIDATION

Implementación actual:

1. La bola recorre los objetos con comportamiento `id_bhvGoomba`.
2. Cuando un Goomba entra en el radio de absorción, se marca para eliminación.
3. El contador `GOOMBAS` aumenta.
4. La escala visual aumenta +0.18 por Goomba, con límite provisional 3.25x.
5. Crecen también `oWallHitboxRadius`, `hitboxRadius` y `hitboxHeight`.
6. El radio de empuje de Mario aumenta con la bola.
7. Se introduce un efecto de masa suave: cuantos más Goombas absorbe, más cuesta empujarla pasivamente.
8. El HUD muestra `GOOMBA ABSORBIDO +1`, tamaño y velocidad.
9. D-Pad abajo reinicia progreso y reposiciona la bola.
10. Cambiar de nivel reinicia el progreso.

Criterios de PASS:

- la bola detecta al menos un Goomba estándar al contacto/proximidad inmediata;
- el Goomba desaparece sin crash;
- el contador aumenta exactamente una vez por Goomba;
- el crecimiento visual es claramente perceptible;
- la colisión/hitbox acompaña al crecimiento;
- tras varios Goombas la bola sigue siendo empujable;
- no se producen absorciones repetidas del mismo Goomba ni spam infinito.

## Limitaciones aceptadas en este gate

- El Goomba absorbido desaparece; todavía no se representa pegado a la superficie.
- Sólo se absorben Goombas estándar.
- No existe todavía un umbral de tamaño por categoría.
- El sistema aún no está validado para multiplayer.
- Puede haber casos de absorción a través de geometría muy fina porque el gate usa distancia simple.
- Escaleras siguen fuera de alcance.

Si A4-A6 = PASS, el siguiente trabajo será A7-A8: clases de objetos/umbrales de tamaño, progresión más rica y feedback visual de absorción.

## Stack autorizado para A0–A9

- SM64CoopDX
- Lua API de SM64CoopDX
- Git/GitHub
- ChatGPT para arquitectura, código, revisión y trazabilidad
- Claude Code sólo cuando la ejecución/depuración local aporte valor

## Fuera de alcance por ahora

- Ghidra
- Frida
- RenderDoc
- Godot
- libsm64-godot
- GodotWadImporter
- Universal Modder
- CrossOver como dependencia de desarrollo

## Reglas de provenance y legalidad

- Nunca versionar ROMs ni dumps.
- Nunca reemplazar originales del usuario.
- Mantener código propio separado de datos propietarios.
- Registrar cambios de arquitectura y cambios de criterio en este archivo.
