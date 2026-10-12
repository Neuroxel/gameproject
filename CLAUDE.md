# CLAUDE.md

Lee primero:

1. `NEXO_STATE.md`
2. `AGENTS.md`
3. `README.md`

## Rol

Actúa como ejecutor local y depurador del NEXO Mashup Lab. No redefinas la arquitectura ni amplíes el alcance por iniciativa propia.

## Gate actual

A0. El objetivo único es instalar/cargar:

`sm64coopdx/NexoMashupA/main.lua`

en SM64CoopDX para macOS y verificar que el HUD muestre:

`NEXO MASHUP LAB`
`GATE A0 PASS`

## Flujo preferido

1. Inspeccionar el entorno local sin modificar nada innecesario.
2. Verificar que SM64CoopDX existe y ya funciona.
3. Ejecutar `bash scripts/install-macos.sh`.
4. Si es posible, lanzar SM64CoopDX y verificar el mod.
5. Si no es posible observar el juego de forma fiable, detenerse y pedir sólo la evidencia mínima al usuario.
6. Si falla, capturar error/log exacto antes de modificar código.
7. Realizar la corrección mínima.
8. No comenzar A1 hasta que A0 sea PASS confirmado.

## Restricciones

- No instalar Ghidra, Godot, RenderDoc, Universal Modder ni otros stacks durante A0.
- No buscar, copiar, modificar ni subir ROMs.
- No borrar ni reemplazar originales del usuario.
- No hacer refactors no relacionados.
- Mantener cambios pequeños y trazables.
- Si modificas código, haz commit descriptivo o deja un diff claro para revisión.
