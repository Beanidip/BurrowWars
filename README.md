# Burrow Wars

Rival rat civilizations dig, build and bonk their way to golden cheese.

A team-based multiplayer voxel digging game: two teams of rats tunnel through a destructible
block world, haul cheese home, raid each other's vaults and build siege machines. Slapstick,
not violent: rats get bonked, drop what they carry and scramble.

**Engine:** Godot 4.7.2 (GDScript, Compatibility renderer). No plugins, no dependencies.
**Platforms:** Windows, Linux, macOS and the web browser (itch.io), keyboard and mouse or a full
controller (Steam Deck at 1280x800).

## Play

1. Open `project.godot` in Godot 4.7.2 (first open imports the art and audio).
2. Press **F5**. Pick **Cheese Race / Scrap Race (Bots)**, choose the mode, team, class, goal,
   bot skill and any Extras or Modifiers, then **Start digging!**

From a terminal: `godot --path .`. New players: **Learn to Play** is a five-minute guided match.

**Online:** main menu > **Play Online**: the public server list, join by address, or **Host a Race**
for friends (UDP port 24565, with an optional playground lobby). Players on desktop and in the
browser play together. Run an always-on server with `--headless -- --server` (8v8 hosted,
up to 16v16 dedicated, WebSocket for browsers, anti-cheat built in).
See [docs/MULTIPLAYER.md](docs/MULTIPLAYER.md).

**Browser:** `tools/web_build.sh` builds the itch.io version; see [docs/ITCH.md](docs/ITCH.md).

## The game in one minute

- **Cheese Race:** dig (hold left mouse) to find **golden cheese** and carry it home. You crawl
  while carrying, so dash, build highways, or bring an escort. First team to the goal wins.
- **Scrap Race:** mine orange **scrap** and carry it home to bank it; first to the scrap goal
  wins. Bonks knock unbanked scrap loose, and cheese you bank makes your team's scrap worth more.
- **Bonk** enemy rats (left-click them): nobody is hurt, but they drop a cheese.
- Spend scrap at the **workshop** (B, at your base) on ladders, springs, highways, conveyors,
  teleporters, traps, decoys, TNT, gear (jetpack, shield, bubble shoes) and team gates.
- **Raid** the enemy base: stand in it for 3 seconds to steal a banked cheese. A defender at
  home locks the vault.
- Build siege machines (cannon, crane with a wrecking ball, bulldozer), move them on conveyors,
  throw Mobile TNT and Impulse Grenades.
- **Extras** (events during a match): Meteor Shower, Lava Rise, Flash Freeze, Fungal Outbreak.
- **Modifiers** (rule changes): Super Springs, Low Gravity, TNT Madness, Class Roulette,
  Scrap Rush, Fragile World, Cheese Rain.
- After each match, a **results screen** tallies everyone's stats (cheese banked, mined and
  stolen, bonks, blocks, TNT, traps, scrap) with an MVP; emote with the movement keys while the
  host picks the next game or the lobby.
- **Customize Rat:** pick a hat; everyone sees it online.
- **Free Build** is a creative sandbox with flight, a chisel for microvoxels, a copy/paste
  pantograph, painted blocks and map saving.

## Controls

Every key can be rebound (Esc > Settings & Controls). A controller works everywhere, menus
included; its layout is under How to Play. On the results screen, W A S D and Space emote.

| Input | Action | Input | Action |
|---|---|---|---|
| WASD / mouse | Move / look | Q | Place equipped gadget |
| Space | Jump, double jump, climb, swim up | R / wheel | Change the Q slot gadget |
| J | Use gear (Jetpack / Rat Knight Shield / Bubble Shoes on-off) | B | Workshop / Team stash |
| Shift | Dash | E / F | Class abilities |
| Left mouse | Dig / bonk | B | Workshop (at base; Builder anywhere) |
| Right mouse | Place selected material | I | Inventory |
| 1-4 | Dirt / stone / ice / obsidian | G | Drop one cheese where you look |
| V | First / third person | Ctrl+K | Respawn at base |
| Ctrl | Climb down / fly down | Esc | Pause, settings, key rebinding |
| N, F5, F9 | Free Build: fly, save map, load map | Mouse wheel | Scroll the Q gadget (Alt + wheel: camera distance) |
| 9 | Chisel: LMB carve, RMB add a microvoxel | 0 | Pantograph: click 2 corners, RMB paste; X rotate, Z mirror, Y flip, U invert |
| T | Pilot / leave a siege machine | Ctrl+Q | Set Mobile TNT down gently |
| 8 / C | Painted block or glass / colour picker (36 colours) | | |

## Verify

```
tools/check.sh /path/to/godot
```

Runs editor validation, a boot test, an end-to-end smoke test of the real menu ->
match -> results flow, the gameplay regression suite, and multiplayer tests that start
real server and client processes on localhost. Exit code 0 means all passed.
See `docs/TEST_RESULTS.md` for what was actually executed and what was not.

## Where things are

- `docs/GAME_DESIGN.md` - rules as implemented: modes, Extras, Modifiers, hats, results screen
- `docs/BALANCE.md` / `docs/balance.csv` - every tunable number, what it does and where it lives
- `docs/ARCHITECTURE.md` - systems and why they are shaped this way
- `docs/MULTIPLAYER.md` - playing online, hosting, dedicated/public servers, the soak test, netcode
- `docs/RELEASE_PLAN.md`, `docs/ITCH.md` - the release plan and the browser build for itch.io
- `docs/ART_TO_MAKE.md`, `docs/SOUND_LIST.md` - every picture and sound in the game, to redo
- `docs/ASSET_LICENSES.md`, `docs/ART_SPEC.md` - where each asset came from; sizes and formats
- `docs/JAM_SCOPE.md` - the original jam scope (history)
- `docs/KNOWN_ISSUES.md`, `docs/NEXT_SESSION.md` - honest status and the next steps

## Art

All of the game's 2D art is a handful of PNGs you can paint over (Aseprite, LibreSprite, Pixelorama):

| File | What it is |
|---|---|
| `assets/rats/<class>.png` | One sprite sheet per class (digger, scout, builder, saboteur): 72x72 cells, 4 columns, one row per animation (idle, run, jump, dig, attack, hurt, build, use, down). Paint team-coloured parts in **magenta**: the game makes the Blue and Red rats from the one drawing. Layout: `docs/rat_sheet_layout.png`. This is the **side** view (turned to the right; mirrored for the left). |
| `assets/rats/<class>_front.png`, `<class>_back.png` | The same rat facing you and facing away, same layout, so players can see whether they're being looked at. Drawn by `tools/rat_views.py` for idle, run and jump; any empty cell (digging, bonking...) shows the side view instead. Paint over them or fill in more rows. |
| `assets/icons/icons.png` | Every gadget, trap, siege, gear, material, tool, ability and menu icon: 16x16 cells, 8 columns. Which icon is where: `docs/icon_sheet_layout.png`. A separate `assets/icons/<id>.png` overrides one icon. |
| `assets/ui/panel_frame.png` | The menu panel (wood and the blue/red frame), a 9-slice: the outer 22 px on each side are frame and corners, the middle stretches. |
| `assets/ui/burrow_*.png` | The masthead and the original UI icons. |
| `assets/blocks/<name>.png` | Block textures (32x32, tiling). Scrap has one; drop in `dirt.png`, `stone.png`... and list them in `scripts/world/block_textures.gd` to texture other blocks. Each face picks a random quarter-turn or mirror so runs of a block don't look stamped. `tools/make_block_textures.py` redraws scrap. |
| `assets/hats/<id>.png` | The hats (Customize Rat), drawn facing you, up to 24x22; magenta takes the team colour. `tools/make_hats.py` draws the placeholders (`preview` shows every hat on every class). |
| `assets/fx/<name>.png` | Effect animations (explosion, block breaks per material, hit sparks, dust for dash/jump/landing, water and lava splashes, jetpack flame, pickup, respawn poof, deposit firework): a grid of frames each. Frame size, count, speed and the anchor point are in `scripts/match/fx_sheets.gd`; keep those in step if you redraw one at a different size. |

Tools: `tools/rat_sheets.py` (`preview` shows your rats in both team colours, `pack`/`unpack`
convert between sheets and single frames, `guide` redraws the layout picture) and
`tools/make_icons.py` (regenerates the icon sheet; it overwrites hand edits, so only rerun it to add icons).
`tools/rat_views.py` redraws the front and back sheets (it overwrites them; `preview DIR` lays the three views side by side).
`tools/import_fx.py /path/to/pixelfx` re-renders the effect sheets from the [pixelfx](https://github.com/patch-gg/pixelfx)
library (needs Node 18+; edit its list to swap, recolour or add effects; it overwrites `assets/fx/`), and
`tools/make_sfx.py` remakes the placeholder `splash`, `sizzle`, `squeak`, `pop` and `toot` sounds.
Other blocks, gadgets and siege machines are still drawn in code from flat colours.

## Credits

The full list of every asset, its source and licence is in [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md); the sizes and layouts new art and sound must follow are in [docs/ART_SPEC.md](docs/ART_SPEC.md). The game's own Credits & Licences page (main menu) shows the notices it ships with.

Music (Sneak Rat, Mr Bones, Ratcano Run, Rat Grass Valley) is made for Burrow Wars by the team.
Rat sprites, UI icons and most sound effects are placeholders carried over from Burrow Wars
v0.15.1 and are being redone (see docs/ART_TO_MAKE.md and docs/SOUND_LIST.md). All code in
this repository is new.

Effect animations in `assets/fx/` are rendered from [pixelfx](https://github.com/patch-gg/pixelfx)
by Patch and Hugo Duprez, MIT License (see `assets/fx/LICENSE-pixelfx.txt`); some recoloured. The `splash`, `sizzle`, `squeak`, `pop` and `toot` sounds are
synthesised placeholders made by `tools/make_sfx.py`.

## License

Copyright (c) 2026 Beanidip. **All rights reserved.** Burrow Wars, its code, art, sound and
music are proprietary: no part of it may be copied, modified, redistributed or reused without
written permission. Released builds may be downloaded and played for personal use. See
[LICENSE](LICENSE). Third-party components (Godot Engine, pixelfx) keep their own licences,
listed in the game's Credits & Licences screen and in docs/ASSET_LICENSES.md.
