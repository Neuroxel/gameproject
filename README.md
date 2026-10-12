# NEXO Mashup Lab

Laboratorio incremental para experimentar con mashups sistémicos de videojuegos.

## Fase actual

**A — Super Mario 64 × Katamari × GTA × Tony Hawk**

Motor anfitrión inicial: **SM64CoopDX**  
Estrategia: mod Lua, sin recompilar el juego y sin reverse engineering innecesario.

## Estado

- **A0 — PASS:** pipeline ChatGPT/GitHub -> Mac -> SM64CoopDX validado.
- **A1-A3.1 — VALIDACIÓN ACTIVA:** modelo 3D provisional, física básica y golpe B diferenciado.
- **A4-A6 — BLOQUEADO** hasta validar A1-A3.

El estado canónico detallado vive en `NEXO_STATE.md`.

## Qué debería verse ahora

Al cargar el mod aparece el HUD:

```
NEXO MASHUP LAB
A1-A3 BALL TEST
BOLA: ACTIVA
DPAD ABAJO: reiniciar bola
```

Un objeto esférico 3D provisional (Spiny Ball) debería aparecer automáticamente frente a Mario. Se usa temporalmente para validar volumen, rotación y física antes de crear nuestro modelo propio.

Prueba:

1. caminar/correr contra la bola;
2. pulsar B cerca de ella y comprobar que aparezca `GOLPE FUERTE!` y salga mucho más rápido;
3. dejarla rodar por una pendiente;
4. pulsar D-Pad abajo para reposicionarla.

## Estructura inicial

- `sm64coopdx/NexoMashupA/` — mod instalable en SM64CoopDX.
- `NEXO_STATE.md` — estado canónico, gates y decisiones.
- `AGENTS.md` — instrucciones generales para agentes locales.
- `CLAUDE.md` — instrucciones específicas para Claude Code.
- `.gitignore` — evita subir ROMs y contenido de juego.

## Principios

1. Validar diversión antes de aumentar complejidad.
2. Un gate funcional por vez.
3. Mantener el repositorio libre de ROMs, dumps y assets propietarios.
4. No introducir Ghidra, Godot, RenderDoc u otros stacks hasta que exista una necesidad técnica concreta.
5. Cada cambio debe ser pequeño, reversible y verificable.

## Actualizar e instalar en macOS

Desde el clon local:

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

El mod queda instalado en:

```
~/Library/Application Support/sm64coopdx/mods/NexoMashupA/
```

> Este repositorio no incluye ni debe incluir ROMs, ejecutables comerciales ni assets protegidos de los juegos.
