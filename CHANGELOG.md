# Changelog

## Unreleased - code review fixes

| Change | Files |
|---|---|
| Fix: an online player on an enemy sticky trap was corrected by the server every tick and frozen in place. The sticky slowdown is now part of the shared rat simulation | `actors/rat.gd`, `match/match.gd` |
| Fix: springs made no sound or BOING for online players; their game reports the bounce and the server plays it for everyone (rate-limited) | `match/match.gd`, `net/net_client.gd`, `net/net_server.gd` |
| Painted blocks are dyed dirt: 2 hits. Left-click paint works on dirt and painted blocks only, so it can never weaken a stone wall | `world/blocks.gd`, `match/match.gd` |
| Fix: a forged blueprint without a mask key errored on the server; it is now refused as malformed | `match/blueprint.gd` |
| Online players no longer generate a map that the server's snapshot replaces (about 0.7 s saved per join and per round) | `match/match.gd` |
| Fix: carving, dabbing paint and breaking a block turned dirt into stone; dabs now refund (and cost in the pantograph) as dirt | `match/match.gd`, `match/blueprint.gd` |
| Server encodes each snapshot and event batch once for all players and reads the peer list once per tick (net protocol 6) | `net/net_server.gd`, `net/net.gd` |
| Fix: loose cheese on a spring bounced forever (and played BOING forever); each launch now nudges it sideways so it hops off | `match/match.gd` |
| Loose cheese floats up to the surface of water instead of sinking | `match/match.gd` |
| Fix: bots mined cheese through walls; they now need a clear line of sight, otherwise they dig toward it | `actors/bot_brain.gd` |
| Cleanup: removed the unused Team Block ability code, `Blocks.mirror`, `LiquidFlow.wake_all`; one `MapGenerator.in_any_base` rule and one `Match.wire_aim` helper replace copied code | several |

## 1.8.0 - Team Block gadget, cheese dash, team-coloured menus (2026-11-16)

| Change | Files |
|---|---|
| Team Block is a Q-slot gadget: Builders start with 6, anyone can buy 4 for 4 scrap, digging your own gives it back. The Builder's F ability is gone | `match/class_defs.gd`, `world/blocks.gd` |
| Carrying cheese halves your dash | `actors/rat.gd` |
| Menus: grained wood panels framed blue (top/left) and red (bottom/right), generated in code as a 9-slice | `ui/ui_kit.gd` |

## 1.7.0 - Big goals, map export/import, paint brush, pantograph transforms (2026-11-16)

| Change | Files |
|---|---|
| Cheese goal up to 250; every race map holds at least 2.5 cheese per point of goal, spread by sector and split evenly | `world/map_generator.gd`, `match/match.gd`, `ui/main_menu.gd`, `net/dedicated_server.gd` |
| Esc > Export map (offline or hosting) saves the map with carvings, gate layers and machines | `ui/hud.gd`, `world/voxel_world.gd` |
| Map picker on Cheese Race, Host and Free Build setup: import a saved map as a bot race, a hosted game or Free Build. Races get both bases stamped back and cheese topped up in matching pairs. Maps folder button | `ui/main_menu.gd`, `world/map_generator.gd`, `match/match.gd` |
| Dedicated servers take `--map file.bwmap` | `net/dedicated_server.gd` |
| Paint slot + left click dyes dirt, stone or painted blocks (other blocks are dug as usual) | `match/match.gd`, `actors/player_controller.gd`, `net/net_server.gd` |
| Pantograph: Z mirrors, Y flips upside down, U inverts (filled <-> empty), alongside X rotate; carvings transform too | `match/blueprint.gd`, `actors/player_controller.gd`, `core/inputs.gd` |

## 1.6.0 - Procedural maps (2026-11-16)

| Change | Files |
|---|---|
| Bigger world: 128 x 128 (was 96 x 48), 64 tall | `world/voxel_world.gd` |
| Procedural terrain: plains, ridged snow-capped mountain ranges and valleys with lakes, different every seed | `world/map_generator.gd` |
| Bases in opposite corners; the map has exact 180-degree symmetry so both sides get identical terrain and resources | `world/map_generator.gd`, `world/blocks.gd` (`rotate180`) |
| Scrap and cheese scattered by sector across the whole map (scrap in nearly every 16 x 16 area) | `world/map_generator.gd` |
| Sewer runs from just outside each base to the centre chapel; lava basins, ruins, vaults and dikes placed by seed | `world/map_generator.gd` |
| Faster loading: generated maps are cached, cheese indexing uses a search, and chunks near you are built first while the rest stream in | `world/map_generator.gd`, `world/voxel_world.gd`, `match/game_session.gd` |
| Bots find the doorway of a corner base | `actors/bot_brain.gd` |
| Map tests: exact symmetry, equal resources per side, scrap spread, plains + mountains + valleys present | `tests/test_runner.gd` |

Free Build maps saved by earlier versions do not load (different world size). Net protocol 4.

## 1.5.0 - Playtest round 2 (2026-11-16)

| Change | Files |
|---|---|
| Wood is scenery (breaks, gives nothing); removed from stash, hotbar, shop, chisel, pantograph. Paint is slot 5 | `world/blocks.gd`, `match/class_defs.gd`, `core/inputs.gd`, `ui/hud.gd` |
| 36 paint colours: greys, in-between shades, 10 see-through glass colours. Paint costs dirt (stone when out of dirt), gives dirt back, 3 hits | `world/blocks.gd`, `world/chunk_mesher.gd`, `match/match.gd`, `ui/hud.gd` |
| Ladders, springs, conveyors, wall springs and highways can go inside your own team gate | `world/voxel_world.gd`, `match/match.gd`, `actors/rat.gd`, `net/*` |
| G puts cheese where you look; springs and wall springs move loose cheese | `match/match.gd`, `actors/player_controller.gd` |
| Lava: first touch bounces you; a second touch spills your load and sends you home | `match/match.gd`, `actors/rat.gd`, `match/match_view.gd` |
| Mouse wheel scrolls the Q gadget (Alt + wheel zooms the camera); hotbar shows the real "next" key | `actors/player_controller.gd`, `ui/hud.gd` |
| Super Dig 4 s and Patch 5 s cooldowns | `match/class_defs.gd` |
| Play Online can host a Free Build map; menu says "Cheese Race (Bot Game)" | `ui/main_menu.gd` |
| Music volume at the top of the Esc menu | `ui/hud.gd` |
| Fix: the sea no longer shows as a blue sheet through underground tunnels | `match/game_session.gd` |

## 1.4.0 - Online multiplayer, flowing water (2026-11-16)

| Change | Files |
|---|---|
| Online multiplayer: Play Online menu (join by address or from the public server list), host a game from a normal Cheese Race; players take bot seats and bots take them back | `net/net.gd`, `net/net_server.gd`, `net/net_client.gd`, `ui/main_menu.gd`, `core/main.gd`, `match/game_session.gd` |
| Dedicated server mode (`--headless -- --server`): always-on, bots fill teams, new map after each win, idles when empty | `net/dedicated_server.gd` |
| Match runs as authority or replica; every request goes through `Match.remote` on a client and is re-validated by the server | `match/match.gd`, `match/siege.gd`, `actors/rat.gd`, `world/voxel_world.gd` |
| Online games never pause; Free Build map loading is offline-only | `ui/hud.gd` |
| Public server list read from `servers.json` in this repository | `servers.json`, `ui/main_menu.gd` |
| Multiplayer end-to-end tests with real processes (dedicated, player-hosted, round rollover) | `tests/net_client_test.gd`, `tests/net_host_test.gd`, `tools/net_check.sh` |
| Water flows like lava, faster and further (reach 5); lava touching water turns to stone with a hiss of steam | `match/liquid_flow.gd` (was `lava_flow.gd`), `match/match.gd`, `match/match_view.gd` |
| Windows export preset (single-file exe) | `export_presets.cfg` |

## 1.3.0 - Colours, highway layer, wrecking-ball table (2026-11-16)

| Change | Files |
|---|---|
| Painted blocks in 12 colours: slot 6 places full blocks, C opens the colour picker | `world/blocks.gd`, `match/match.gd`, `ui/hud.gd`, `actors/player_controller.gd`, `core/inputs.gd` |
| Chisel adds painted microvoxels in the picked colour (each microvoxel remembers its own colour; saved, copied and pasted with it) | `world/voxel_world.gd`, `world/chunk_mesher.gd`, `match/blueprint.gd` |
| Highway is a thin layer on top of a block's face; the block stays | `world/blocks.gd`, `world/chunk_mesher.gd`, `actors/rat.gd`, `match/match.gd` |
| A conveyor laid into the floor beside a siege machine moves it the way the conveyor faces | `match/siege.gd` |
| Wrecking ball: dirt 1 hit, stone 2, obsidian 4, team gate 10 (TNT still needs 2 blasts for a gate) | `match/siege.gd`, `match/match.gd`, `core/config.gd` |
| Hotbar slots narrowed so seven slots fit at 1280x720 | `ui/hud.gd` |

Already true and now covered by a test: an enemy bonk throws a pilot off their machine and
knocks them back. Tests: 526 assertions in 48 tests; smoke test 83 steps.

## 1.2.0 - Playtest changes (2026-11-16)

| Change | Files |
|---|---|
| Rats can leap out of water (hold or tap Space at the surface) | `actors/rat.gd` |
| Flowing lava + three underground lava basins per side | `match/lava_flow.gd` (new), `world/map_generator.gd`, `match/match.gd` |
| Q on a ladder extends the stack up or down by which half you aim at | `match/match.gd` |
| R changes the Q slot; T pilots siege machines | `core/inputs.gd` |
| Digger: Burrow Sense removed, normal dig by default, Super Dig ability | `match/class_defs.gd`, `match/match.gd` |
| Builder: free team gates, Team Block ability replaces Highway | `match/class_defs.gd`, `match/match.gd`, `ui/hud.gd` |
| Team blocks (solid for one team only) | `world/blocks.gd`, `world/chunk_mesher.gd` |
| Team gate is a plain transparent block; water is more see-through | `world/chunk_mesher.gd`, `world/blocks.gd` |
| Highways and conveyors are laid into the aimed floor block | `match/match.gd` |
| Outline target square; bright edge sets conveyor direction | `actors/player_controller.gd` |
| Ice: rats and loose objects slide off the end | `actors/rat.gd`, `match/match.gd` |
| Roughly twice the scrap | `world/map_generator.gd` |

Tests: 467 assertions in 43 tests; smoke test 76 steps. One thing to know if you
rebound keys earlier: saved custom bindings win over the new R / T defaults.

## 1.1.0 - Siege Engineering & Advanced Voxel Tools (2026-11-16)

Built on top of the 1.0 jam project; nothing was rebuilt.

### New systems

| System | Where | What it does |
|---|---|---|
| Microvoxel storage, meshing, collision, raycast | `world/voxel_world.gd`, `world/chunk_mesher.gd`, `actors/rat.gd` | Any carved block keeps a 7x7x7 mask. Rats collide with the carved shape and auto-climb ledges up to 4 microvoxels. Saved in map format v2 (v1 maps still load). |
| Chisel (key 9) | `match/match.gd`, `actors/player_controller.gd` | Left mouse carves one microvoxel, right mouse adds one. Zero-sum economy: 343 microvoxels = 1 block, tracked per rat. |
| Pantograph (key 0) | `match/blueprint.gd`, `match/match.gd` | Two corners copy up to 9x9x9, X rotates, ghost preview turns red when illegal, right mouse pastes. Costs materials; never copies cheese, scrap, gadgets, TNT or machines. |
| Mobile TNT | `match/dynamite.gd` | Thrown (Q) or set down (Ctrl+Q) stick with a 3 s fuse. Bounces, slides on ice, rides conveyors, is launched by springs and wall springs, glued by sticky traps, jolted by mouse traps, drops through pitfalls. |
| One blast model | `Match.blast()` | TNT and Mobile TNT share it: damage falls off with distance and respects block durability; chains; knockback only. |
| Siege machines | `match/siege.gd`, `match/contraption_view.gd` | Scrap Cannon, Wrecking Crane, Bulldozer. R mans / leaves, mouse aims, left mouse works. Moved only by conveyors (under or beside), slide on ice, stop when blocked, fall when unsupported, operator rides along. |
| New traps | `world/blocks.gd` | Sticky trap, pitfall, wall spring. |
| Terrain | `world/blocks.gd`, `world/map_generator.gd` | Obsidian is 12 hits and drops obsidian (slot 5); obsidian dikes and surface stone boulders, mirrored; stone/obsidian/brick get a mottled face texture. |

### Design and balance changes (made for fun and fairness)

- **Vault raids.** Stand in the enemy base for 3 s to steal one banked cheese. Everyone hears an alarm; a defender standing in their own base locks the vault. Gives gates, traps and siege a target, and gives the losing team a comeback.
- **Carry speed scales with load:** 45% / 34% / 25% for 1 / 2 / 3 cheese (was a flat 25%). One cheese is a brisk jog; a full haul is a real gamble.
- **Digger hits twice as hard** on the aimed block (stone in 2 swings, obsidian in 6). It is now the fastest tunneller as well as the widest, and stays the slowest walker.
- **Bots raid and defend.** A team 2+ behind sends half its bots at your vault; bots near home chase raiders.
- **Blasts respect durability.** TNT no longer deletes everything in range: stone at the edge is cracked, obsidian needs three charges.
- Siege prices 26-30 scrap, at most 2 of each in the pack; Mobile TNT 7 scrap for 2.

### Controls added

5 obsidian, 9 chisel, 0 pantograph, X rotate blueprint, R use/leave machine, Ctrl+Q gentle placement. All rebindable; no existing key changed.

### Tests

411 gameplay assertions in 37 tests (was 179 in 21) and a 67-step smoke test that drives every new system in the running game. See `docs/TEST_RESULTS.md`.
