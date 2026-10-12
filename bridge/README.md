# NEXO Portal Bridge

Primer bridge externo de **Portal Fabric**.

## Estado

SM64CoopDX ya guarda el handoff de M1 mediante `mod_storage_*`.

En macOS, SM64CoopDX guarda los archivos de mod storage bajo:

```
~/Library/Application Support/sm64coopdx/sav/
```

El script `nexo_handoff.py`:

1. busca todos los `.sav`;
2. encuentra uno con `handoff_pending=1`;
3. valida que tenga destino;
4. exporta un manifiesto neutral JSON;
5. no modifica el save ni lanza todavía otro juego.

## Uso

Después de completar M1 y cruzar el NEXO Gate:

```bash
cd ~/Documents/gameproject
python3 bridge/nexo_handoff.py --print
```

Salida esperada:

```
[NEXO] Pending handoff found: .../sav/NexoMashupA.sav
[NEXO] Target world: DOOM
[NEXO] Manifest written: .../bridge/runtime/handoff.json
```

## Manifest

Ejemplo:

```json
{
  "schema": "nexo.portal.handoff.v1",
  "source": {
    "world": "SM64_BOB",
    "adapter": "sm64coopdx"
  },
  "target": {
    "world": "DOOM",
    "adapter": "pending"
  },
  "mission": {
    "id": "M1_CARGA_IMPOSIBLE",
    "score": 15824
  },
  "player_state": {
    "logical_mass": 4.7
  },
  "cargo": {
    "coins": 5,
    "goombas": 4,
    "bobombs": 2
  }
}
```

## Próximo paso

Crear `doom_adapter` que convierta este manifest en estado inicial DOOM.

Nada de este bridge requiere tocar la ROM ni modificar los originales.
