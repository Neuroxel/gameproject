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
