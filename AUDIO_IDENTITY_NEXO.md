# NEXO AVATAR AUDIO IDENTITY v0.1

## Goal

Mario's vocal/action identity should survive world transitions even when the
destination changes camera, mechanics, HUD and weapons.

The persistent layer is **character voice/action SFX**, not necessarily music.

## Core profile: mario_voice_v1

Initial cross-world hooks:
- jump;
- use/action;
- hurt;
- death.

Future optional hooks:
- landing;
- exertion;
- pickup/celebration;
- portal entry/exit;
- contextual reactions.

## Copyright / distribution rule

Nintendo/Mario audio is **not committed to this repository**.

NEXO supports local assets supplied/extracted by the user from material they are
entitled to use. The local directory is:

`assets_local/mario_sfx/`

It is gitignored.

Expected core files, one supported format each:
- `jump.ogg|wav|flac`
- `hurt.ogg|wav|flac`
- `death.ogg|wav|flac`
- `use.ogg|wav|flac`

Import helper:

```bash
bash scripts/import-mario-sfx-local.sh /path/to/your/own/mario_sfx_folder
```

When all four exist, `bridge/run_doom.py` embeds them only into the locally
generated runtime PK3, writes an additive SNDINFO, and enables
`nexo_mario_sfx=true`.

No copyrighted voice files are versioned.

## DOOM behavior

With the local core set present:
- Mario jump voice on jump rising edge;
- action voice on Use rising edge;
- hurt voice when health drops, with cooldown;
- death voice on player death.

DOOM weapon audio remains DOOM audio. Mario voice sits above it as the persistent
avatar identity layer.

This separation is intentional: the world owns environmental/weapon sound;
the avatar owns voice/action identity.


## Local extraction from the user's own SM64 ROM

NEXO does not download or redistribute Nintendo voice clips.

Instead, the project can use the open-source sm64coopdx extraction tools against
the user's own vanilla SM64 ROM:

```bash
bash scripts/extract-mario-sfx-from-sm64-rom.sh /path/to/baserom.us.z64 us
```

If no ROM path is passed, the script searches common project/Documents/Downloads
locations and accepts only a ROM whose SHA-1 matches the known vanilla version.

The local extraction currently prepares:
- jump;
- hurt;
- death;
- use/action;
- portal/entry ("Here we go");
- celebration ("Yahoo").

These files remain under gitignored `assets_local/mario_sfx/`.

The DOOM adapter uses the first four as the mandatory core profile. Portal and
celebration are optional enhancements, with safe aliases when absent.
