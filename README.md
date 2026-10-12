# NEXO Mashup Lab

Laboratorio incremental de mashups sistémicos de videojuegos.

## Estado

- A0 — PASS
- A1-A3.1 — PASS
- A4 — PASS
- A5 — PASS
- **A6.1 — VALIDACIÓN ACTIVA: crecimiento visible y control**
- A7+ — bloqueado hasta A6.1 PASS

## Prueba actual

La bola ahora parte considerablemente más grande y el HUD muestra:

```
GOOMBAS: 0 | OBJ: 1.80 | VIS: 1.80
GFX: 1.80 | VEL: ...
```

Al absorber el primer Goomba:

```
OBJ: 2.35
VIS: 1.80 -> ... -> 2.35
GFX: debe acompañar a VIS
```

La esfera debería crecer de forma inequívoca mientras aparece:

`CRECIENDO! GOOMBA +1`

La velocidad pasiva se redujo y el radio de empuje aumentó para hacerla más controlable.

## Actualizar e instalar

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

Usa Bob-omb Battlefield y absorbe uno o más Goombas. Si el modelo no crece, anota especialmente los valores **VIS** y **GFX** del HUD; éstos permiten localizar exactamente dónde falla la escala.

> No incluir ROMs ni assets comerciales en este repositorio.
