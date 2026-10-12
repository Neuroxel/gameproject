# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Objetivo

Construir progresivamente un mashup jugable, divertido y observable, comenzando por SM64CoopDX y evitando complejidad técnica que no aumente el valor del prototipo.

## Arquitectura decidida

### Fase A — SM64CoopDX + Lua

Orden previsto:

- A0 — pipeline de mod y HUD visible.
- A1 — esfera/objeto rodante visible en 3D.
- A2 — física estable.
- A3 — Mario puede empujarla y golpearla con respuestas diferenciadas.
- A4 — detección de entidades absorbibles.
- A5 — primer Goomba absorbible.
- A6 — crecimiento de esfera.
- A7 — umbrales de absorción por tamaño.
- A8 — HUD de tamaño/puntuación.
- A9 — kill gate de diversión.
- A10 — sistema tipo GTA wanted, sólo si A9 = PASS.
- A11 — sistema de combos tipo Tony Hawk, sólo si el prototipo sigue siendo divertido.

### Fase C

Añadir sistemas tipo Crazy Taxi sólo después de validar la base de A.

### Fase D

Migrar a mashup multi-juego real con Godot + libsm64 + contenido/mapas compatibles con DOOM, sólo tras validar el gameplay.

## Evidencia y gates

### A0 — PASS

Confirmado el 2026-10-12 mediante captura del usuario.

### Primera validación A1-A3 — RESULTADO PARCIAL

Observación del usuario:

- el objeto aparece y tiene sombra;
- puede ser empujado;
- cae bajo gravedad;
- en escaleras pierde apoyo y cae;
- el modelo `E_MODEL_BOWLING_BALL` se percibe como una imagen/disco 2D rotando;
- golpe y empuje normal no mostraban diferencia perceptible.

Conclusión:

- **A1: FAIL visual** con el modelo bowling-ball.
- **A2: PARTIAL PASS** para gravedad/rodado/colisión básica; subir escaleras no es requisito de este gate.
- **A3: PARTIAL PASS** para empuje corporal; FAIL para diferenciación de golpe.

### A1-A3.1 — PENDING VALIDATION

Correcciones aplicadas:

1. Se reemplaza temporalmente `E_MODEL_BOWLING_BALL` por `E_MODEL_SPINY_BALL`, el modelo 3D usado por el ejemplo oficial de pelota.
2. El empuje corporal queda limitado a velocidad moderada.
3. Un press explícito de botón B cerca de la bola aplica impulso fuerte y componente vertical.
4. El HUD muestra velocidad aproximada.
5. Cuando se detecta el golpe fuerte, el HUD muestra `GOLPE FUERTE!` durante varios frames.
6. D-Pad abajo sigue reposicionando la bola.

Criterio de PASS:

- el objeto se percibe claramente tridimensional al rodearlo;
- rueda y colisiona de forma estable sobre suelo y pendientes;
- empuje normal es controlable;
- B cerca del objeto produce un salto/impulso perceptiblemente mayor y el HUD confirma `GOLPE FUERTE!`;
- no hay crash ni spam de objetos.

### Limitación conocida: escaleras

`object_step_without_floor_orient()` no proporciona por sí solo un comportamiento de subida de escalones comparable al controlador de Mario. La bola puede caer hacia atrás al intentar subir peldaños. No bloquea A1-A3; se reevaluará después de validar la mecánica Katamari.

Si A1-A3.1 = PASS, el siguiente gate será A4-A6: detectar Goombas, absorber el primero y hacer crecer la bola.

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
