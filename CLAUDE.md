# CLAUDE.md

Lee `NEXO_STATE.md`.

## Gate actual

M1.1 — recuperación de activación.

La regresión fue causada por usar `gCurrCourseNum` como gate Lua.

### Invariante

Usar para localización del jugador:

`gNetworkPlayers[0].currCourseNum`
`gNetworkPlayers[0].currLevelNum`

No restaurar `gCurrCourseNum` como fuente del gate M1.

## Validar primero

1. Castillo: sin bola/HUD.
2. BOB: bola + HUD aparecen.
3. Sólo después validar compact/attachments/mission gate.

No ampliar features hasta recuperar baseline.
