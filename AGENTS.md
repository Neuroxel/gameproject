# AGENTS.md

## M1.1

Regresión conocida y corregida: detección de mundo.

No usar `gCurrCourseNum` para activar M1 desde Lua.

Fuente canónica:
- `gNetworkPlayers[0].currCourseNum`;
- fallback redundante `currLevelNum == LEVEL_BOB`.

Primero recuperar:
- HUD;
- bola;
- misión en BOB.

Preservar física/navegación M1.
