# NEXO Mashup Lab

Laboratorio incremental para experimentar con mashups sistémicos de videojuegos.

## Fase actual

**A — Super Mario 64 × Katamari × GTA × Tony Hawk**

Motor anfitrión inicial: **SM64CoopDX**  
Estrategia: mod Lua, sin recompilar el juego y sin reverse engineering innecesario.

## Estado

- **A0 — PASS**
- **A1-A3.1 — PASS**
- **A4-A6 — VALIDACIÓN ACTIVA:** detectar Goombas, absorberlos y hacer crecer realmente la bola.
- **A7+ — BLOQUEADO** hasta validar A4-A6.

El estado canónico detallado vive en `NEXO_STATE.md`.

## Qué debería verse ahora

```
NEXO MASHUP LAB
A4-A6 KATAMARI TEST
GOOMBAS: 0 | TAM: 1.15x | VEL: ...
```

La bola sigue usando el modelo 3D provisional de Spiny Ball.

## Prueba recomendada

Usa **Bob-omb Battlefield**, donde hay Goombas accesibles.

1. Empuja la bola hacia un Goomba.
2. Al tocarlo/dejarlo entrar en el radio de la bola:
   - el Goomba debe desaparecer;
   - debe sonar feedback;
   - debe aparecer `GOOMBA ABSORBIDO +1`;
   - `GOOMBAS` debe subir;
   - `TAM` debe aumentar;
   - la bola debe hacerse físicamente más grande.
3. Absorbe varios Goombas y comprueba que sigue siendo jugable.
4. Pulsa D-Pad abajo para reiniciar tamaño/contador y reposicionar la bola.

## Actualizar e instalar en macOS

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Después reinicia SM64CoopDX y habilita el mod si fuera necesario.

## Principios

1. Validar diversión antes de aumentar complejidad.
2. Un gate funcional por vez.
3. Mantener el repositorio libre de ROMs, dumps y assets propietarios.
4. No introducir tooling pesado hasta que exista una necesidad técnica concreta.
5. Cada cambio debe ser pequeño, reversible y verificable.

> Este repositorio no incluye ni debe incluir ROMs, ejecutables comerciales ni assets protegidos de los juegos.
