# NEXO MASHUP LAB — ESTADO CANÓNICO

Última actualización: 2026-10-12

## Objetivo

Construir progresivamente un mashup jugable, divertido y observable, comenzando por SM64CoopDX y evitando complejidad técnica que no aumente el valor del prototipo.

## Arquitectura decidida

### Fase A — SM64CoopDX + Lua

Orden previsto:

- A0 — pipeline de mod y HUD visible.
- A1 — esfera visible.
- A2 — esfera con física.
- A3 — Mario puede empujarla.
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

Evidencia confirmada el 2026-10-12 mediante captura del usuario:

1. SM64CoopDX abre y corre normalmente.
2. El mod `NexoMashupA` está cargado.
3. El HUD `NEXO MASHUP LAB / GATE A0 PASS` aparece durante gameplay.
4. No se reportó crash ni degradación funcional.

Nota: el pulso de color diseñado para A0 no se adopta como criterio de validación. Era demasiado sutil y una captura fija no puede demostrar animación; el HUD visible y el funcionamiento normal son evidencia suficiente del pipeline.

### A1-A3 — PENDING VALIDATION

Implementación actual:

- una bola de bowling se genera automáticamente frente al Mario local;
- comportamiento físico basado en el ejemplo oficial `behavior-ball.lua` de SM64CoopDX;
- gravedad, fricción, rebote moderado y colisión con suelo/pared;
- Mario puede empujarla caminando/corriendo contra ella;
- los ataques producen un empuje más fuerte;
- D-Pad abajo reinicia/reubica la bola frente a Mario;
- el HUD muestra el estado de la bola.

Criterio de PASS conjunto:

1. La bola aparece automáticamente dentro de gameplay.
2. Cae y reacciona al suelo/pared de forma estable.
3. Mario puede desplazarla chocando con ella.
4. Un ataque produce una respuesta claramente más fuerte.
5. D-Pad abajo la reposiciona.
6. No hay crash, spam de objetos ni bloqueo de control.

Si A1-A3 = PASS, el siguiente gate será A4-A6: detectar Goombas, absorber el primero y hacer crecer la bola.

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
