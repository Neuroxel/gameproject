# NEXO Mashup Lab

Laboratorio incremental para experimentar con mashups sistémicos de videojuegos.

## Fase actual

**A — Super Mario 64 × Katamari × GTA × Tony Hawk**

Motor anfitrión inicial: **SM64CoopDX**  
Estrategia: mod Lua, sin recompilar el juego y sin reverse engineering innecesario.

## Primer objetivo

Gate A0: comprobar el pipeline completo:

```
ChatGPT/GitHub -> archivo Lua -> Mac -> SM64CoopDX -> HUD visible
```

Cuando el mod cargue correctamente debe aparecer en pantalla:

**NEXO MASHUP LAB — GATE A0 PASS**

## Estructura inicial

- `sm64coopdx/NexoMashupA/` — mod instalable en SM64CoopDX.
- `NEXO_STATE.md` — estado canónico, gates y decisiones.
- `AGENTS.md` — instrucciones de trabajo para agentes locales.
- `.gitignore` — evita subir ROMs y contenido de juego.

## Principios

1. Validar diversión antes de aumentar complejidad.
2. Un gate funcional por vez.
3. Mantener el repositorio libre de ROMs, dumps y assets propietarios.
4. No introducir Ghidra, Godot, RenderDoc u otros stacks hasta que exista una necesidad técnica concreta.
5. Cada cambio debe ser pequeño, reversible y verificable.

## Instalación manual del mod en macOS

Copiar la carpeta:

```
sm64coopdx/NexoMashupA
```

a:

```
~/Library/Application Support/sm64coopdx/mods/
```

El resultado debe quedar así:

```
~/Library/Application Support/sm64coopdx/mods/NexoMashupA/main.lua
```

Después iniciar SM64CoopDX, habilitar **NEXO Mashup A** en el menú de mods y entrar al juego.

> Este repositorio no incluye ni debe incluir ROMs, ejecutables comerciales ni assets protegidos de los juegos.
