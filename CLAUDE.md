# CLAUDE.md

Lee primero:

1. `NEXO_STATE.md`
2. `AGENTS.md`
3. `README.md`

## Rol

Actúa como ejecutor local y depurador del NEXO Mashup Lab. No redefinas la arquitectura ni amplíes el alcance por iniciativa propia.

## Gate actual

**A1-A3.1 — validación de modelo 3D provisional, física básica y golpe fuerte diferenciado.**

A0 ya está confirmado PASS.

El archivo activo es:

`sm64coopdx/NexoMashupA/main.lua`

El comportamiento esperado es:

- aparece automáticamente un objeto esférico 3D provisional;
- rueda/cae con gravedad;
- Mario puede empujarlo;
- botón B cerca del objeto produce un impulso mucho más fuerte;
- el HUD muestra `GOLPE FUERTE!` cuando ese impulso se detecta;
- D-Pad abajo reposiciona el objeto.

## Flujo preferido

1. Inspeccionar el entorno local sin modificar nada innecesario.
2. Ejecutar `git pull` y `bash scripts/install-macos.sh`.
3. Verificar A1-A3.1 en SM64CoopDX.
4. Si falla, capturar error/log exacto antes de modificar código.
5. Realizar la corrección mínima.
6. No comenzar A4 hasta que A1-A3.1 sea PASS confirmado en `NEXO_STATE.md`.

## Restricciones

- No instalar Ghidra, Godot, RenderDoc, Universal Modder ni otros stacks durante A1-A9 salvo decisión explícita registrada.
- No buscar, copiar, modificar ni subir ROMs.
- No borrar ni reemplazar originales del usuario.
- No hacer refactors no relacionados.
- Mantener cambios pequeños y trazables.
- La limitación de escaleras está documentada y no bloquea este gate.
