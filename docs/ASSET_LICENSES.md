# Asset licences

Every file the game ships, where it came from, and what may be done with it. **Keep this up to
date whenever an asset is added or replaced.** Steam's content survey asks about AI-generated
content that players see or hear, so record that too. The in-game credits
(`scripts/ui/credits.gd`, `TEAM` and `ASSETS`) must name every third-party source listed here.

Status key:
- **Legacy placeholder:** your assets from Burrow Wars v0.15.1. You told me (2026-11-21) the
  visual ones came from free-licence sources or AI generation; the exact sources aren't recorded.
  They are being redone (see `ART_TO_MAKE.md` and `SOUND_LIST.md`) and shouldn't ship as they are
  unless each source and licence is written down here.
- **Project-made:** drawn or synthesised by this repository's own `tools/` scripts. Part of the game.
- **Third-party:** someone else's work under the licence given.

| Files | Status | Source | Licence | AI-generated? | Ship? |
|---|---|---|---|---|---|
| `assets/rats/digger.png`, `scout.png`, `builder.png`, `saboteur.png` (side views) | Legacy placeholder | v0.15.1 | Unknown | Unknown | **No: being redrawn** |
| `assets/rats/*_front.png`, `*_back.png` | Project-made | `tools/rat_views.py` | Part of the game | No (procedural) | Placeholder until the redraw |
| `assets/ui/burrow_*.png` (masthead, cheese, gear, hammer, pack, rat, siege, trap, inventory and workshop strips) | Legacy placeholder | v0.15.1 | Unknown | Unknown | **No: being redrawn** |
| `assets/ui/panel_frame.png` | Project-made | Drawn by `UiKit` (saved as a file to make it editable) | Part of the game | No | Yes, or redraw |
| `assets/ui/app_icon.png`, `app_icon.ico` | Project-made | `tools/make_app_icon.py` | Part of the game | No | Placeholder until the redraw |
| `assets/icons/icons.png` | Project-made | `tools/make_icons.py` | Part of the game | No | Yes, or redraw |
| `assets/hats/*.png` | Project-made | `tools/make_hats.py` | Part of the game | No | Placeholder until the redraw |
| `assets/blocks/scrap.png` | Project-made | `tools/make_block_textures.py` (drawn after your reference picture) | Part of the game | No | Yes, or redraw |
| `assets/fx/*.png` (all effect sheets: explosions, block breaks, hit sparks, dust, splashes, jetpack, teleport, impulse...) | Third-party | [pixelfx](https://github.com/patch-gg/pixelfx) by Patch and Hugo Duprez, rendered by `tools/import_fx.py`, some recoloured | MIT (`assets/fx/LICENSE-pixelfx.txt`, shown in Credits) | Per pixelfx's README: procedurally drawn effects; check before launch | **Yes** (kept) |
| `assets/sfx/splash.wav`, `sizzle.wav`, `squeak.wav`, `pop.wav`, `toot.wav`, `alarm.wav`, `windup.wav`, `teleport.wav`, `impulse.wav` | Project-made | `tools/make_sfx.py` (synthesised) | Part of the game | No | Placeholder until the redo |
| `assets/sfx/*.wav` (all others: mining, breaking, bonk, place, fanfares, chime, munch, jetpack, siege, TNT) | Legacy placeholder | v0.15.1 | Unknown | Unknown | **No: being redone** |
| `assets/music/sneak_rat.ogg`, `mr_bones.mp3`, `ratcano_run.ogg`, `rat_grass_valley.mp3` | Developer's own | Made for Burrow Wars by the developer (the WAVs converted to Ogg Vorbis for size) | Owned by the developer | Developer to confirm how they were made (any tools or samples with their own terms) | **Yes** |
| `assets/shaders/fx_hue.gdshader` | Project-made | This repository | Part of the game | No | Yes |
| Default UI font | Third-party | Godot's built-in default font (bundled with the engine) | Covered by Godot's third-party notices (shown in Credits) | No | Yes |
| Godot Engine and its third-party components | Third-party | godotengine.org | MIT plus the component licences (shown in Credits) | No | Yes |

## When you add an asset

1. Add a row here: who made it, where it came from (store page or URL), the licence, whether AI
   was used, and the purchase receipt or licence file if there is one (keep those outside the repo
   if they're private).
2. If it isn't your own work, add it to `Credits.ASSETS` in `scripts/ui/credits.gd`, and put its
   licence text in the game if the licence asks for that (as pixelfx's does).
3. Prefer CC0, CC-BY or your own work. Avoid "non-commercial" licences, and any licence that forbids
   redistribution inside a game.
