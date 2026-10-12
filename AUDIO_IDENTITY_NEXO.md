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

With the local core set present, avatar voice now **replaces** equivalent Doom
player vocals rather than playing on top of them.

Semantic ownership:
- jump: Doom's native `*jump` player sound is silenced; the Mario player
  adapter emits jump1/2/3 only after a real engine jump is confirmed;
- hurt: native `*pain100/*pain75/*pain50/*pain25` resolve directly to Mario
  hurt audio;
- death/xdeath: native player death events resolve directly to Mario death;
- use/action: NEXO retains a Mario cue on Use rising edge while native
  `*usefail` is silenced;
- grunt/land: use the local Mario stomp cue when available, otherwise remain
  silent rather than leaking Doomguy voice;
- portal and campaign celebration remain explicit NEXO events.

DOOM weapon, enemy, environment and music audio remain DOOM/Freedoom audio.

This is the intended split:
- WORLD AUDIO belongs to the destination;
- AVATAR AUDIO belongs to Mario;
- NEXO AUDIO belongs to portal/handoff/meta-state.

Do not restore Doomguy player vocals underneath Mario.


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


## DMX runtime bridge

The user confirmed that Mario becomes audible when local PCM16LE WAV sources are
converted only at PK3 build time to native Doom DMX.

Why:
- GZDoom 4.14.2 resolves the resources correctly;
- the generic WAV route enters ZMusic decoding;
- in the current runtime that route produced zero-length loads;
- native DMX bypasses the optional decoder and reaches GZDoom's raw sound path.

Source WAV files remain unchanged and gitignored.

Current functional bridge:
`local WAV -> generated DMX8 mono -> runtime PK3`.

Quality debt:
DMX is unsigned 8-bit mono. Once semantic behavior is stable, a later audio
quality pass may restore PCM16/OGG by shipping or locating a known-working
libsndfile/decoder path. Do not reopen the functional loader diagnosis merely
because a higher-fidelity format is desired.

## Movement audio extension

Optional local movement cues:
- jump2;
- jump3;
- backflip;
- longjump;
- stomp;
- dive.

Refresh from already-extracted local SM64 samples:
```bash
bash scripts/extend-mario-movement-sfx-local.sh
```

If absent, SNDINFO aliases them to existing Mario core cues so gameplay remains
functional.
