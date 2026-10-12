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


## Identity + perspective continuity

The v1 handoff schema now documents two optional backwards-compatible blocks:

```json
"identity": {
  "avatar": "MARIO",
  "audio_profile": "mario_voice_v1"
},
"perspective": {
  "source": "third_person",
  "target": "first_person",
  "transition": "portal_push_in"
}
```

World adapters preserve identity while choosing their own native camera mode.


## NEXO_HUB campaign router

After M2 has produced `bridge/runtime/handoff_from_doom.json`, resolve the
next chapter without coupling DOOM directly to another engine:

```bash
python3 bridge/nexo_router.py --print
```

The router reads `bridge/campaign.json` and writes
`bridge/runtime/route.json`.

Current campaign graph:

```
M1_CARGA_IMPOSIBLE / SM64_BOB
  -> M2_STABILIZE_BREACH / DOOM_MAP01
  -> HUB_AFTER_M2 / NEXO_HUB
  -> M3_PORTAL_LAB / PORTAL_LAB
```

`M3_PORTAL_LAB` is deliberately `planned`, not runtime-ready. The router
may resolve it, but `launch_allowed` remains false until the adapter is
explicitly promoted to `ready`. Current requirement: 8 combat shards.
