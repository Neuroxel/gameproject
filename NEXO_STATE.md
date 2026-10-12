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

## Gate actual

### A0 — PENDING

Criterio de PASS:

1. SM64CoopDX abre normalmente.
2. El mod `NexoMashupA` aparece y está habilitado.
3. Durante gameplay aparece el texto:
   `NEXO MASHUP LAB — GATE A0 PASS`
4. El juego continúa respondiendo normalmente.

Criterio de FAIL:

- el mod no aparece;
- error Lua;
- crash;
- texto no visible;
- degradación funcional atribuible al mod.

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
