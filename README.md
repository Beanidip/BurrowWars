# Burrow Wars: Jam Edition

Rival rat civilizations dig, build and bonk their way to golden cheese.
A from-scratch rebuild of Burrow Wars, scoped like a 48-hour game-jam entry:
one complete, playable loop first, everything else on the cut list.

**Engine:** Godot 4.7.2 (GDScript, Compatibility renderer). No plugins, no dependencies.

## Play

1. Open `project.godot` in Godot 4.7.2 (first open imports the art and audio).
2. Press **F5**. Pick **Cheese Race**, choose a team, class, goal and bot skill, then **Start digging!**

From a terminal: `godot --path .`

**Online:** main menu > **Play Online** to join a server or host a game for friends
(UDP port 24565). Run an always-on public server with `--headless -- --server`.
See [docs/MULTIPLAYER.md](docs/MULTIPLAYER.md).

## The game in one minute

- Dig (hold left mouse) to find **golden cheese**. Each block is one cheese.
- Carry it home. You crawl while carrying, so dash, build highways, or bring an escort.
- **Bonk** enemy rats (left-click them): nobody is hurt, but they drop a cheese.
- Mine orange **scrap**, spend it at the **workshop** (B, at your base) on ladders,
  springs, highways, conveyors, mouse traps, TNT and team gates.
- Every cheese banked by either team raises the value of newly mined scrap.
- **Raid** the enemy base: stand in it for 3 seconds to steal a banked cheese. A defender at home locks the vault.
- Build siege machines (cannon, crane, bulldozer), move them on conveyors, throw bouncing Mobile TNT.
- First team to the cheese goal wins. **Free Build** is a creative sandbox with flight.

| Input | Action | Input | Action |
|---|---|---|---|
| WASD / mouse | Move / look | Q | Place equipped gadget |
| Space | Jump, double jump, climb, swim up | R / wheel | Change the Q slot gadget |
| J | Use gear (Jetpack) | B | Workshop / Team stash |
| Shift | Dash | E / F | Class abilities |
| Left mouse | Dig / bonk | B | Workshop (at base; Builder anywhere) |
| Right mouse | Place selected material | I | Inventory |
| 1-4 | Dirt / stone / ice / obsidian | G | Drop one cheese where you look |
| V | First / third person | Ctrl+K | Respawn at base |
| Ctrl | Climb down / fly down | Esc | Pause, settings, key rebinding |
| N, F5, F9 | Free Build: fly, save map, load map | Mouse wheel | Scroll the Q gadget (Alt + wheel: camera distance) |
| 9 | Chisel: LMB carve, RMB add a microvoxel | 0 | Pantograph: click 2 corners, RMB paste; X rotate, Z mirror, Y flip, U invert |
| T | Pilot / leave a siege machine | Ctrl+Q | Set Mobile TNT down gently |
| 5 / C | Painted block or glass / colour picker (36 colours) | | |

## Verify

```
tools/check.sh /path/to/godot
```

Runs editor validation, a boot test, an end-to-end smoke test of the real menu ->
match -> results flow, the gameplay regression suite, and multiplayer tests that start
real server and client processes on localhost. Exit code 0 means all passed.
See `docs/TEST_RESULTS.md` for what was actually executed and what was not.

## Where things are

- `docs/JAM_SCOPE.md` - the scope lock, schedule and cut list
- `docs/GAME_DESIGN.md` - rules as implemented
- `docs/ARCHITECTURE.md` - systems and why they are shaped this way
- `docs/MULTIPLAYER.md` - playing online, hosting, dedicated/public servers, netcode
- `docs/KNOWN_ISSUES.md`, `docs/NEXT_SESSION.md` - honest status and the next steps

## Art

All of the game's 2D art is a handful of PNGs you can paint over (Aseprite, LibreSprite, Pixelorama):

| File | What it is |
|---|---|
| `assets/rats/<class>.png` | One sprite sheet per class (digger, scout, builder, saboteur): 72x72 cells, 4 columns, one row per animation (idle, run, jump, dig, attack, hurt, build, use, down). Paint team-coloured parts in **magenta**: the game makes the Blue and Red rats from the one drawing. Layout: `docs/rat_sheet_layout.png`. |
| `assets/icons/icons.png` | Every gadget, trap, siege, gear, material, tool, ability and menu icon: 16x16 cells, 8 columns. Which icon is where: `docs/icon_sheet_layout.png`. A separate `assets/icons/<id>.png` overrides one icon. |
| `assets/ui/panel_frame.png` | The menu panel (wood and the blue/red frame), a 9-slice: the outer 22 px on each side are frame and corners, the middle stretches. |
| `assets/ui/burrow_*.png` | The masthead and the original UI icons. |

Tools: `tools/rat_sheets.py` (`preview` shows your rats in both team colours, `pack`/`unpack`
convert between sheets and single frames, `guide` redraws the layout picture) and
`tools/make_icons.py` (regenerates the icon sheet; it overwrites hand edits, so only rerun it to add icons).
Blocks, gadgets and siege machines are still drawn in code from flat colours.

## Credits

Rat sprites, UI icons, sound effects and music are the project owner's own assets,
carried over from Burrow Wars v0.15.1. All code in this repository is new.
