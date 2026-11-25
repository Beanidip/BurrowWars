# Visual assets: what to make for your own coat of paint

Every picture the game uses, what it is, where it shows up, and its size. Sizes and layouts
(team colour, transparency, sheet rows) are in [`ART_SPEC.md`](ART_SPEC.md): follow them and new
art drops in **without code changes**. Replace a file by saving yours with the same name and size.

The **Status** column says where each one stands today:
- **Replace**: art from earlier versions, made from free-licence or AI-generated sources (your note,
  2026-11-21).
- **Generated**: drawn by a script in `tools/` from the art above, or simple shapes. Placeholder
  until you redraw it.
- **Keep (MIT)**: the pixelfx effects (MIT licence, credited in game). You can keep these or
  replace them.

Priority order if you go one at a time: **rats** (everyone looks at them all game), **title and
menu art**, **icons**, **app icon**, then the rest.

## 1. Rats: `assets/rats/` (12 files, the most important)

Each file is a **288 × 648** sheet: 4 columns × 9 rows of **72 × 72** frames, rat standing on the
cell's bottom edge. Paint team-coloured parts **magenta** (the game recolours them blue or red).

| File | What | Status | Notes |
|---|---|---|---|
| `digger.png` | Digger, side view (facing right), all 9 animations | Replace | Hard hat. Rows: idle, run, jump, dig, attack (bonk), hurt, build, use, down |
| `scout.png` | Scout, side view | Replace | |
| `builder.png` | Builder, side view (also used by the Free Build Chisel Maestro) | Replace | |
| `saboteur.png` | Saboteur, side view | Replace | |
| `digger_front.png` / `_back.png` | Digger facing the camera / facing away | Generated (from the side view by `tools/rat_views.py`) | Only idle, run and jump rows are needed; empty rows fall back to the side view |
| `scout_front.png` / `_back.png` | Scout, front / back | Generated | |
| `builder_front.png` / `_back.png` | Builder, front / back | Generated | |
| `saboteur_front.png` / `_back.png` | Saboteur, front / back | Generated | |

The Wind-up Decoy is drawn from the same sheets (a clockwork copy of its owner), so it updates with them.

### Hats: `assets/hats/` (12 files)

Chosen under **Customize Rat** in the main menu. One small PNG each, drawn **facing you**, up to
**24 × 22** pixels. The bottom row is where it sits: the game finds the top of the head in every
frame and puts the hat there, so one picture works for every class, animation and view (front,
side, back). Magenta parts take the team colour. The placeholders come from `tools/make_hats.py`
(`python3 tools/make_hats.py preview` writes `build/hats_preview.png`: every hat on every class).

| File | Hat | File | Hat |
|---|---|---|---|
| `party.png` | Party Hat (team-coloured stripes) | `chef.png` | Chef's Toque |
| `tophat.png` | Top Hat (team-coloured band) | `propeller.png` | Propeller Cap |
| `crown.png` | Crown | `wizard.png` | Wizard Hat |
| `cheese.png` | Cheese Wedge | `flower.png` | Daisy |
| `beanie.png` | Bobble Beanie | `cowboy.png` | Cowboy Hat |
| `viking.png` | Viking Helmet | `pirate.png` | Pirate Hat |

To add one: draw `assets/hats/<id>.png`, then add `<id>` to `LIST` and its name to `NAMES` in
`scripts/actors/hats.gd`. Each class already wears its own headgear in the art (hard hat,
goggles, cap), so hats sit on top of it; if you redraw the rats bareheaded, hats will sit on
the head itself, no code change.

## 2. Title screen and menus: `assets/ui/`

| File | Size | What | Status |
|---|---|---|---|
| `burrow_masthead.png` | 512 × 104 | The banner above the main menu (rat, cheese, title strip) | Replace |
| `panel_frame.png` | 256 × 256 | Frame of every menu and dialog, stretched as a 9-slice (outer 22 px = frame and corners; left half blue, right half red, wood inside) | Generated |
| `burrow_cheese.png` | 48 × 48 | The spinning cheese on the loading screen | Replace |
| `burrow_cheese_small.png` | 24 × 24 | Cheese counter in the HUD | Replace |
| `burrow_hammer_small.png`, `burrow_gear_small.png` | 24 × 24 | Icons on the Free Build and Settings menu buttons | Replace |
| `burrow_hammer.png`, `burrow_gear.png` | 48 × 48 | Larger versions of the same | Replace |
| `burrow_rat`, `burrow_pack`, `burrow_siege`, `burrow_trap` (`.png` 48 × 48, `_small.png` 24 × 24) | | Fallback icons, not shown while `icons.png` has those icons | Replace or **delete** |
| `burrow_inventory_strip.png`, `burrow_workshop_strip.png` | 512 × 66 | **Not used**: delete instead of redrawing | Replace |

## 3. App icon: `assets/ui/`

| File | Size | What | Status |
|---|---|---|---|
| `app_icon.png` | 256 × 256 | Window, taskbar, Linux and Mac icon, browser tab | Generated (`tools/make_app_icon.py`) |
| `app_icon.ico` | 16, 32, 48, 64, 128 and 256 in one file | The Windows .exe icon | Generated |

Stores need more sizes later (Steam: capsule images, library art; itch: cover image 630 × 500).
Those are separate store art, not game files.

## 4. Icons: `assets/icons/icons.png`

One **128 × 96** sheet of **16 × 16** icons, 8 per row, in this order (left to right, top to
bottom). They show in the hotbar, workshop, pack, ability panel and menu buttons. Status: Generated
(`tools/make_icons.py`). You can also replace one at a time: save `assets/icons/<name>.png` (16 × 16)
and it wins over the sheet. `docs/icon_sheet_layout.png` shows the grid.

| # | Name | Shows | # | Name | Shows |
|---|---|---|---|---|---|
| 1 | dirt | Dirt material | 22 | decoy | Cheese Decoy |
| 2 | stone | Stone material | 23 | teleporter | Teleporter Set |
| 3 | ice | Ice material | 24 | windup | Wind-up Decoy |
| 4 | obsidian | Obsidian material | 25 | squeaker | Squeaker Pad |
| 5 | scrap | Scrap (money) | 26 | cannon | Scrap Cannon |
| 6 | paint | Paint slot | 27 | crane | Wrecking Crane |
| 7 | cheese | Golden cheese | 28 | dozer | Bulldozer |
| 8 | ladder | Ladder | 29 | jetpack | Jetpack |
| 9 | spring | Spring | 30 | shield | Rat Knight Shield |
| 10 | highway | Highway | 31 | bubbles | Bubble Shoes |
| 11 | conveyor | Conveyor | 32 | chisel | Chisel tool |
| 12 | gate | Team Gate | 33 | pantograph | Pantograph tool |
| 13 | teamblock | Team Block | 34 | superdig | Digger's Super Dig |
| 14 | stash | Team Stash | 35 | sniff | Scout's Sniff |
| 15 | trap | Mouse Trap | 36 | beacon | Scout's Beacon |
| 16 | tnt | TNT | 37 | patch | Builder's Patch 3x3 |
| 17 | dynamite | Mobile TNT | 38 | detonate | Saboteur's Detonate |
| 18 | impulse | Impulse Grenade | 39 | plant | Saboteur's Plant TNT |
| 19 | sticky | Sticky Trap | 40 | online | Play Online button |
| 20 | pitfall | Pitfall | 41 | book | Learn / How to Play / Credits buttons |
| 21 | wallspring | Wall Spring | 42 | door | Quit button |

The class portraits on the class buttons come from the rat sheets, not from icons.

## 5. Blocks: `assets/blocks/`

| File | Size | What | Status |
|---|---|---|---|
| `scrap.png` | 32 × 32 | Texture on scrap ore blocks | Generated (`tools/make_block_textures.py`, after your reference picture) |

Every other block (dirt, grass, stone, obsidian, wood, ice, cheese, bases, gadgets, the 36 paint
colours...) is a **flat colour** with shading worked out by the game; the colours are in
`scripts/world/blocks.gd` (`DEFS`). To give any block its own texture, draw a **32 × 32**
seamless tile at full brightness and tell me its name; I'll hook it up (one line).

## 6. Effects: `assets/fx/` (pixelfx, MIT: keep or replace)

Animated sprite sheets. Each sheet's frame size and timing is in `scripts/match/fx_sheets.gd`.
If you redraw one with a different frame size or count, tell me and I'll update that line.

| File | Plays when |
|---|---|
| `explosion.png` | TNT, Mobile TNT and Wind-up blasts |
| `hit.png` | Each dig hit (tinted to the block's colour), cannonball impacts |
| `break_dirt.png`, `break_stone.png`, `break_ice.png`, `break_scrap.png`, `break_wood.png`, `break_dark.png` | A block breaking (tinted to its colour; the file sets light and shade); `break_wood` also when a mouse trap snaps |
| `dust.png` | Jumps, landings, wrecking-ball hits, a Wind-up setting off |
| `dizzy.png` | Circling stars over a bonked rat |
| `collect.png` | Picking up cheese or a stash; a Squeaker Pad squeaking |
| `poof.png` | Respawning, a Cheese Decoy going off, a bubble popping, cannon fire smoke, lava cooling |
| `firework.png` | Banking cheese at your base |
| `jetpack.png` | Jetpack flame |
| `splash.png` / `splash_lava.png` | Into or out of water / touching lava |
| `dash.png` | Dash whoosh |
| `pound.png` | Ground pound shockwave |
| `shield_up.png` / `shield_block.png` | Rat Knight Shield raised / blocking a hit |
| `tele_pad.png` / `tele_beam.png` | Charged teleporter entrance / a teleporter trip |
| `impulse.png` | Impulse Grenade burst |

## 7. Drawn by the game in code (no image file)

These are built from simple shapes and colours in code. To restyle them you'd send me a picture or
a model and I'd swap it in, so they're more work than the files above.

| What | Looks like now | Where in code |
|---|---|---|
| Siege machines (Cannon, Crane, Bulldozer) | Boxes in wood, brass, hazard yellow and team colour; a sphere for the wrecking ball | `scripts/match/contraption_view.gd` |
| Gadgets in the world (ladders, springs, traps, conveyors, teleporter pads, gates...) | Shaped blocks and coloured details | `scripts/world/chunk_mesher.gd` |
| Loose cheese, dropped-stash and knocked-loose scrap pickups | A cheese wedge, a sack, an orange heap | `scripts/match/match_view.gd` (`_make_pickup`) |
| Meteors (Meteor Shower) and their warning ring | A glowing rock of boxes with a fiery tail; a red ring on the ground | `scripts/match/contraption_view.gd` (`_sync_meteors`) |
| Cheese crumbs | Little yellow clusters | `scripts/match/crumb_trail.gd` |
| Dynamite and impulse grenades in flight, cannonballs | Small boxes and spheres | `scripts/match/contraption_view.gd` |
| Impulse Grenade bubble, crack overlay on damaged blocks, aim previews | See-through shapes | `scripts/match/match_view.gd`, `contraption_view.gd` |
| HUD (bars, slots, panels, toasts), name tags, map markers | Coloured boxes, the panel frame and the default font | `scripts/ui/hud.gd`, `scripts/ui/ui_kit.gd` |
| Sky, water and lava colours, terrain shading | Colours and a shader | `scripts/match/game_session.gd`, `assets/shaders/terrain.gdshader` |
| Font | Godot's built-in font (licence covered in Credits) | Any `.ttf` / `.otf` you like can replace it game-wide |

## 8. Before you publish

- Steam asks whether the game contains AI-generated content and how it was made, and itch.io lets
  you tag AI use. Keep `docs/ASSET_LICENSES.md` up to date as you replace things, so you can answer
  accurately.
- When a file is replaced with your own art, change its row in `ASSET_LICENSES.md` to "yours".
