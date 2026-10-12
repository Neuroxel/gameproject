# NEXO DOOM Adapter v0.1

Primer destino real de Portal Fabric.

## Runtime elegido

**GZDoom 4.14.2**.

Motivos:
- macOS release oficial;
- scripting moderno con ZScript;
- custom CVARs;
- EventHandlers;
- carga de PK3;
- compatible con Doom/Doom II y Freedoom.

## IWAD

Para la prueba automática usamos **Freedoom Phase 2** (`freedoom2.wad`), que es contenido libre compatible con Doom II.

Si posees `DOOM2.WAD`, puedes usarlo directamente:

```bash
python3 bridge/run_doom.py --iwad "/ruta/a/DOOM2.WAD"
```

## Semántica del primer handoff

| SM64 cargo | DOOM effect |
|---|---|
| Monedas | +2 ArmorBonus por moneda |
| Goombas | +3 HealthBonus por Goomba |
| Bob-ombs | +2 rockets por Bob-omb |
| >=2 Bob-ombs | Rocket Launcher |
| Masa >=4.0 | Backpack |
| Score | visible en mensaje NEXO |

Esto es deliberadamente simple: P1.2 valida que el estado de un engine altere realmente el siguiente.

## Setup macOS

```bash
bash scripts/setup-doom-macos.sh
```

Después:

```bash
python3 bridge/run_doom.py --dry-run
python3 bridge/run_doom.py
```

Al entrar a MAP01 debe aparecer un mensaje:

```
NEXO HANDOFF
SM64 -> DOOM
...
```

y los recursos deben reflejar la carga de M1.
