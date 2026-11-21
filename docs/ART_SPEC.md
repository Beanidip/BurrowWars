# Art and audio spec

What the game expects from every art and sound file, so the redone assets drop in **without code
changes**. Keep the file names and layouts below. The game finds assets by name.

The full to-do lists are [`ART_TO_MAKE.md`](ART_TO_MAKE.md) (every picture, what it is, where it
shows) and [`SOUND_LIST.md`](SOUND_LIST.md) (every sound, when it plays, what it should be like).

General rules:
- **Pixel art.** Everything is drawn with nearest-neighbour filtering. Draw at the sizes given; don't
  pre-scale.
- **Transparency.** Rat and effect sprites are cut at 50% alpha. Use fully opaque or fully
  transparent pixels, never soft edges.
- **Team colour.** Anything painted **magenta** becomes Blue or Red in game. Exactly: hue 275–325°
  (0.76–0.90), saturation at least 20%, brightness at least 8%, and both red and blue higher than
  green. Keep everything else, including pink ears, noses and tails, out of that hue range.
- After changing art, run `tools/check.sh <godot>`. The tests check that every sheet the game needs
  is present.

## Rats: `assets/rats/`

The current sprite style stays (decided 2026-11-19).

**Files**
- One set of sheets per class: `digger`, `scout`, `builder`, `saboteur`. The Maestro uses the
  Builder's art.
- `<class>.png` is the **side** view: the rat turned to the right. The game mirrors it for the left.
- `<class>_front.png` is the rat **facing the camera**: both eyes, nose, whiskers. It's shown when a
  rat looks at you.
- `<class>_back.png` is the rat **facing away**: back of the head, tail.

**Sheet layout**
- Cells are **72×72 px**, 4 columns, 9 rows, so the sheet is 288×648.
- Rows top to bottom, with frame counts and playback speed:

  | Row | Animation | Frames | FPS |
  |---|---|---|---|
  | 0 | idle | 2 | 2.5 |
  | 1 | run | 4 | 10 |
  | 2 | jump | 3 | 6 |
  | 3 | dig | 3 | 12 |
  | 4 | attack | 2 | 10 |
  | 5 | hurt | 2 | 6 |
  | 6 | build | 3 | 10 |
  | 7 | use | 3 | 8 |
  | 8 | down | 4 | 5 |

- Frames go left to right; unused cells stay empty.
- To change a frame count or speed, edit `FRAMES` / `FPS` in `scripts/actors/rat_sprite.gd` and
  `tools/rat_sheets.py`.

**Placement**
- The rat stands on the **bottom of the cell**: feet at about y = 62, outline at 63.
- It's about 40–48 px tall including hat. The game shows the cell 1.25 blocks tall, so the rat is
  about 0.9 block.

**Front and back sheets**
- Only idle, run and jump need drawing.
- **Any empty cell falls back to the side view.** Draw more rows (e.g. a front-facing dig) whenever you like.

**Drawn by the game, not the sheets:** carried cheese above the head, name tags, team tint, shield
and dizzy effects.

**Tools**
- `python3 tools/rat_sheets.py guide` draws a labelled layout picture.
- `preview DIR` shows your sheets in both team colours.
- `pack DIR` / `unpack DIR` convert between sheets and single frames.

## Icons: `assets/icons/icons.png`

- **16×16 px cells**, 8 columns, in the order listed in `scripts/ui/icon_sheet.gd` (`IDS`).
- `docs/icon_sheet_layout.png` shows which icon is in which cell.
- To replace just one icon, drop `assets/icons/<id>.png` (16×16); a separate file wins over the sheet.
- `tools/make_icons.py` redraws the whole sheet and **overwrites** it, so once you paint your own,
  only run it again to add new ids.

## UI: `assets/ui/`

| File | Size | Used for |
|---|---|---|
| `burrow_masthead.png` | 512×104 | The title art above the menu |
| `panel_frame.png` | 256×256 | Menu and dialog panels, as a 9-slice. The outer 22 px on each side are the frame and corners; the middle stretches. Left half blue, right half red, wood inside. |
| `burrow_cheese.png` | 48×48 | The spinning loading-screen cheese |
| `burrow_cheese_small.png` | 24×24 | The HUD cheese counter |
| `burrow_hammer_small.png`, `burrow_gear_small.png` | 24×24 | Menu button icons (Free Build, Settings) |
| `burrow_rat`, `burrow_pack`, `burrow_siege`, `burrow_trap` (`.png` 48×48 and `_small.png` 24×24) | | Fallback icons. Not shown while `icons.png` has those ids, so redraw them only if you want to. |
| `burrow_inventory_strip.png`, `burrow_workshop_strip.png` | 512×66 | **Unused**: safe to delete instead of redrawing |
| `app_icon.png` | 256×256 | Window, taskbar and macOS/Linux icon |
| `app_icon.ico` | 16, 32, 48, 64, 128, 256 | Windows exe icon (all sizes in one `.ico`) |

## Blocks: `assets/blocks/`

- Most blocks are flat colours (`scripts/world/blocks.gd`, `DEFS`). The game shades each face and
  darkens blocks deeper underground.
- **Optional textures:** a **32×32** PNG named for the block, registered in
  `scripts/world/block_textures.gd` (`FILES`).
- **Draw them at full brightness:** the face shading is multiplied in.
- They must **tile seamlessly**. Each face picks a random quarter-turn or mirror, so avoid art with
  an obvious "up".
- Today only `scrap.png` exists.

## Effects: `assets/fx/` (kept)

- These are pixelfx (MIT). `tools/import_fx.py` re-renders them.
- Your own effect works too: a PNG grid of frames plus an entry in `scripts/match/fx_sheets.gd`
  giving frame size, columns, count, fps, loop and pivot.
- They're drawn for a 38 px-tall character, so 1 effect pixel is 0.9/38 of a block.

## Sound effects: `assets/sfx/`

**Format**
- WAV, 16-bit, mono, 44.1 kHz (the placeholders are 22.05 kHz; either works).
- Peaks at about −1 dBFS. The game sets its own relative volumes per effect, so keep effects
  roughly equally loud.
- Short and dry, with no long reverb tails: the game spatialises them.

| Name | Plays when | Length |
|---|---|---|
| `mine_dirt`, `mine_stone`, `mine_scrap`, `mine_obsidian`, `mine_wood` | Each dig hit, by material. Pitch is varied randomly, so keep each neutral. | 0.1–0.25 s |
| `break_dirt`, `break_stone`, `break_scrap`, `break_obsidian`, `break_wood` | A block breaks, by material | 0.2–0.4 s |
| `block_place` | Placing a block or gadget; also throws and respawns at other pitches | ~0.25 s |
| `bonk` | Bonking a rat | ~0.2 s |
| `cheese_munch` | Picking up cheese | ~0.5 s |
| `cheese_deposit_fanfare` | Banking cheese at your base | ~1.5 s |
| `team_victory_fanfare` | A team wins | 3–4 s |
| `discovery_chime` | Scrap found, ability used, item bought | ~0.5 s |
| `alarm` | Vault raid (heard by everyone; keep it soft) | ~1.5 s |
| `jetratpack_flame` | Jetpack burst | ~1–2.5 s |
| `tnt_pop` | TNT and Mobile TNT explosions (layered with `siege_impact`) | ~0.5 s |
| `siege_cannon`, `siege_impact`, `siege_grind` | Cannon shot; heavy impacts and blasts; machines moving and fuses | 0.5–1.2 s |
| `splash`, `sizzle` | Into/out of water; touching lava | ~0.5–0.7 s |
| `squeak` | Squeaker Pad | ~0.35 s |
| `pop` | A Bubble Shoes bubble popping | ~0.1 s |
| `toot` | A Cheese Decoy going off | ~0.75 s |
| `windup` | Winding up a Wind-up Decoy | ~0.6 s |
| `teleport` | A teleporter trip (played at both ends) | ~0.7 s |
| `impulse` | An Impulse Grenade bursting | ~0.75 s |

`tools/make_sfx.py` remakes the synthesised placeholders. It will **overwrite** a file of the same
name, so once you replace a sound, remove its line from that script.

## Music: `assets/music/`

- Today there's one looping track, `clockwork_colony.wav`, played from the menu onward.
- For the redo, prefer **Ogg Vorbis** (`.ogg`) for music: much smaller than WAV, and it loops cleanly.
- If you add separate tracks (menu, match, victory), tell me the file names and I'll wire them up.
- The same tracks can go into the Steam soundtrack add-on.
