# CLAUDE.md

Lee primero:

1. `NEXO_STATE.md`
2. `AGENTS.md`
3. `README.md`

## Rol

Actúa como ejecutor local y depurador del NEXO Mashup Lab. No redefinas la arquitectura ni amplíes el alcance por iniciativa propia.

## Gate actual

**A4-A6 — Goomba detection / absorption / growth.**

A0 y A1-A3.1 están confirmados PASS.

Archivo activo:

`sm64coopdx/NexoMashupA/main.lua`

## Comportamiento esperado

- la bola 3D provisional aparece;
- puede empujarse y golpearse;
- al alcanzar un Goomba estándar, lo absorbe;
- el Goomba desaparece;
- aumenta el contador;
- crecen escala visual e hitbox;
- el HUD confirma la absorción;
- D-Pad abajo reinicia progreso.

## Flujo preferido

1. Leer `NEXO_STATE.md`.
2. `git pull`.
3. `bash scripts/install-macos.sh`.
4. Probar en Bob-omb Battlefield.
5. Si falla, obtener error/log o evidencia exacta antes de cambiar código.
6. Hacer la corrección mínima.
7. No comenzar A7 hasta que A4-A6 esté confirmado PASS.

## Restricciones

- No instalar Ghidra, Godot, RenderDoc, Universal Modder ni otros stacks.
- No tocar ni subir ROMs.
- No hacer refactors no relacionados.
- No convertir las limitaciones aceptadas del gate en trabajo adicional sin necesidad.
