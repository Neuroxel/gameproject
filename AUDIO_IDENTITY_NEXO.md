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


## Dedicated Mario player sound class

`NexoMarioDoomPlayer` now sets:

`Player.SoundClass "nexo_mario"`.

Generated SNDINFO defines the avatar mappings for both:
- `nexo_mario` (canonical NEXO Mario player);
- `player` (fallback resilience for temporary skin/class transitions).

For both classes and all supported genders:
- `*jump` -> silent; movement adapter owns confirmed jump cues;
- `*usefail` and `*puzzfail` -> silent;
- pain -> Mario hurt;
- death variants -> Mario death;
- grunt/land -> Mario stomp cue when available.

This specifically addresses the observed residual Doom-player voice on the
Use/action button while preserving actual door/switch/world sounds.


## Skin-precedence audio fix

User runtime evidence still contained a DOOM-player complaint on the Use/A
button even though generated SNDINFO mapped `*usefail` and `*puzzfail` to
`DSEMPTY`.

Exact GZDoom 4.14.2 source inspection showed why:
- player sound resolution can prefer the active player skin;
- that skin selection happens before the default actor `Player.SoundClass`
  when skins are allowed;
- therefore a correct `nexo_mario` mapping can still be bypassed;
- `DSEMPTY` itself is correctly marked by GZDoom as an intentionally silent
  player sound and is not the defect.

Runtime-v2 makes NEXO Mario a non-skin player class:

```text
+NOSKIN
Player.SoundClass "nexo_mario";
```

This has two purposes:
1. prevent the destination marine skin from becoming Mario's audible identity;
2. force `*usefail/*puzzfail/*pain/*death/*jump` through the NEXO sound class.

The explicit Mario Use identity cue remains separate from destination
door/switch/world sounds.

Status: **prepared; A/use regression retest required**.

## Canonical SM64 triple-jump voice assets

The local extractor now additionally derives from the user's own validated ROM:
- `jump1_hoo.wav` <- 00_mario_jump_hoo;
- `jump1_wah.wav` <- 01_mario_jump_wah;
- `jump1_yah.wav` <- 02_mario_yah;
- `jump2_hoohoo.wav` <- 03_mario_haha (the SM64 Hoo-hoo voice slot);
- `jump3_yahoo.wav` <- 04_mario_yahoo;
- `jump3_waha.wav` <- 18_mario_waha;
- `jump3_yippee.wav` <- 19_mario_yippee.

`scripts/extend-mario-movement-sfx-local.sh` can create these from the already
extracted local sample tree without copying the ROM again.

Generated SNDINFO contains compatibility aliases when an older local asset
folder has not yet been refreshed.


## USE semantic correction — no raw-button vocal

Runtime evidence and code review identified a second source of the perceived
"DOOM complaint" on the A/USE button: the NEXO EventHandler itself played
`nexo/mario/use` (the local 05_mario_uh sample) on every raw BT_USE rising
edge.

That was semantically wrong even when the resource was genuinely Mario:
opening a destination-world door should not make Mario grunt every time.

The handler no longer plays any avatar vocal from raw BT_USE input.

Final ownership:
- usable door/switch -> destination world sound;
- failed use -> `*usefail/*puzzfail = DSEMPTY`;
- no automatic Mario grunt;
- the local `nexo/mario/use` resource remains available for diagnostics or
  future explicitly authored/contextual interactions.

Together with `+NOSKIN`, this removes both known paths for an unwanted player
complaint on A.

Status: runtime confirmation required.

## Exact voice semantics for additional SM64 movements

Source-game airborne action behavior is now mirrored more closely:
- normal jump -> random Yah/Wah/Hoo;
- double jump -> Hoo-hoo;
- triple jump -> Yahoo/Waha/Yippee weighted 60/20/20;
- backflip -> generic Yah/Wah/Hoo;
- side flip -> generic Yah/Wah/Hoo;
- wall kick -> generic Yah/Wah/Hoo;
- long jump -> Yahoo;
- initial dive -> Hoo-hoo;
- ground pound -> dedicated Ground-Pound Wah.

The local extractor now also exposes `ground_pound_wah` from Mario's Wah2
voice slot.

Spin/terrain action effects are intentionally not faked with unrelated voice
samples. They may be added later from the user's local SM64 action-sound bank
if useful, while destination-world environmental audio remains native.
