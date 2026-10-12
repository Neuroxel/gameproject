# NEXO Mashup Lab

## Estado actual

**M1.1 — recuperación de activación**

La primera versión de M1 tenía un bug en la detección de Bob-omb Battlefield: el mod seguía cargado, pero interpretaba el nivel como fuera de alcance y ocultaba bola + HUD.

Ya está corregido usando el estado Lua expuesto del jugador local:

```
gNetworkPlayers[0].currCourseNum
gNetworkPlayers[0].currLevelNum
```

## Actualizar

```bash
cd ~/Documents/gameproject
git pull
bash scripts/install-macos.sh
```

Reinicia SM64CoopDX.

## Verificación inmediata

### Castillo / hub
Debe seguir sin aparecer la bola ni el HUD M1.

### Bob-omb Battlefield
Deben aparecer de nuevo:

- bola;
- HUD `M1 CARGA IMPOSIBLE`;
- MASA/VIS;
- checklist de carga.

Si eso vuelve, la regresión está recuperada y continúa la prueba normal de M1:

- rigid attachments;
- COMPACT;
- 5 monedas;
- 4 Goombas;
- 2 Bob-ombs;
- masa 3.80;
- regreso al NEXO Gate;
- handoff preparado a DOOM.


## Portal Fabric bridge

M1 ya alcanza `HANDOFF PREPARADO -> DOOM`.

El siguiente componente está en:

```
bridge/nexo_handoff.py
```

Después de completar M1:

```bash
python3 bridge/nexo_handoff.py --print
```

Esto exporta un manifiesto JSON neutral que será la entrada del futuro adapter DOOM.


## Siguiente gate: DOOM

```bash
git pull
bash scripts/setup-doom-macos.sh
python3 bridge/run_doom.py --dry-run
python3 bridge/run_doom.py
```

El primer adapter usa GZDoom + Freedoom Phase 2 por defecto, o tu propio Doom II IWAD con `--iwad`.


### Handoff durability fix

Portal handoffs are now durable across SM64 level reloads.

For older saves affected by the previous bug, `nexo_handoff.py` can recover the last complete payload even if `handoff_pending` was reset to 0. `run_doom.py` can also reuse an existing validated `bridge/runtime/handoff.json`.
