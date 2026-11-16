# Changelog

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
