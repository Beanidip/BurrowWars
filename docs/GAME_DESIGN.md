# Game design (as implemented)

Authoritative source for numbers: `scripts/core/config.gd`, `scripts/world/blocks.gd`,
`scripts/match/class_defs.gd`. This file explains intent.

## Cheese Race

Two teams on a mirrored 96 x 48 x 48 map. Bases sit at the west (Blue) and east (Red) ends.
A team scores when a rat carrying cheese steps into its own base. First to the goal
(3-16, default 8) wins. A typical map holds 36-40 cheese, split evenly.

Where the cheese is: a teaser block on a plinth in the open, ruins and a scrap laboratory
underground, single blocks buried in stone, obsidian vaults (slow to crack), and a
jackpot in the mushroom chapel at the centre, reached by the sewer that both teams share.

## Core numbers

| Rule | Value |
|---|---|
| Dig rate | 3 swings / second |
| Hits to break | dirt 2, stone 4, scrap 5, cheese 3, brick 4, wood 3, obsidian 14 |
| Reach | 4.5 blocks |
| Carry speed | 25% while holding any cheese |
| Bonk | range 2.4, cooldown 2 s, victim drops 1 cheese and is locked out of it for 2 s |
| Dash | 25 stamina; double jump 10; regen 14 / s |
| Scrap per block | 2 x multiplier |
| Multiplier | 1 + (blue + red score) / goal x 1.5, applied to newly mined scrap only |

## Classes

| Class | Speed | Stamina | Carry | Identity | E | F |
|---|---|---|---|---|---|---|
| Digger | 0.85 | 150 | 3 | Biggest hauler; normal dig like everyone | Super Dig: 2 hits on the aimed block + 1 on the 3x3x3 around it (1 s, 12 stamina) | - |
| Scout | 1.25 | 100 | 2 | Full speed in water | Sniff: marks nearest cheese within 30 | Beacon: team marker, 120 s |
| Builder | 1.0 | 100 | 2 | Remote workshop, team gates free, starts with 6 ladders, spring, 4 gates | Patch: fills a 3x3 | Team Block: a block only your team can stand on or remove (0.8 s, 12 stamina) |
| Saboteur | 1.05 | 100 | 2 | Starts with 3 TNT + 2 traps | Detonate nearest own TNT | Plant TNT at crosshair |
| Chisel Maestro | 1.3 | 1000 | 6 | Free Build only: flight, everything free | Detonate | Patch |

Class changes happen in the workshop, at base, with a 15 s cooldown. Starter kits are
granted once per class per match so they cannot be farmed.

## Gadgets (all are voxel blocks, so they obey the same dig/blast rules)

Ladder (climb with Space/Ctrl, stays attached), spring (launches anything that lands on it),
highway (+60% speed), conveyor (moves rats and loose cheese along the placer's facing),
mouse trap (enemy only: 1.5 s stun, drops one cheese, consumed), TNT (hit it for a 2 s
fuse; radius 2.6; chains; obsidian, bases and bedrock survive; cheese blocks pop out as
pickups), team gate (own team walks through; two blasts destroy it; owners can pick it up).
Digging a gadget returns it to the digger's pack.

## Hazards and safety valves

Lava sends a rat back to base (cheese stays behind, floating on top). Water slows everyone
but Scouts. Ctrl+K respawns: cheese and the material stash are left behind as pickups.
Bases cannot be dug or built in.

## Design review notes

- The 25% carry speed is brutal on purpose; highways, springs, conveyors and dashing are the answer, and it makes escorting and bonking matter.
- Bots are honest: same dig rate, same rules. Skill only changes how long they pause after a pickup or deposit.
- Open question for playtesting: is goal 8 the right default length? Bots at Fierce bank about 6 cheese in 2.5-4 minutes.

## v1.1 additions

**Vault raids.** An enemy rat inside your base for 3 s (`Config.RAID_TIME`) takes one banked
cheese: your score drops by one and they carry it. An alarm toast and a RAID marker go out
when it starts. While any defender stands in the base the timer is frozen. A bonk, stun or
stepping out resets it. A thief can only take what it can carry and still has to walk home.

**Carry speed by load.** 1 cheese 45%, 2 cheese 34%, 3 cheese 25% (`Config.CARRY_SPEED`).

**Digger power.** Aimed block takes 2 hits per swing; the 26 blocks around it take 1.

**Chisel.** Works on dirt, grass, stone, brick, wood, ice and obsidian. 9 edits per second.
Carving returns microvoxels to a per-material spare-change bank; adding spends them; 343
make a block. Digging a carved block returns only what is left of it. A fully carved block disappears.

**Pantograph.** Copies the same materials including their carved shapes, up to 9 blocks per
side. Paste is all-or-nothing: every cell must be free, outside both bases, clear of rats
and machines, and paid for. Chisel Maestro pastes free in Free Build.

**Mobile TNT.** Fuse 3 s, radius 2.4, power 6.5 at the centre (stationary TNT: radius 2.9,
power 10). Damage = power x (1 - distance / radius), in dig hits, so dirt goes at the edge,
stone near the middle, and obsidian only after repeated blasts. Rats are knocked back and
drop one cheese; nobody is hurt. Up to 16 live sticks.

**Siege.** One machine per cell, 2 of each in the pack, only your team can man or pack up
yours. Cannon: 2.2 s reload, 3 hits on impact + 1 on the four blocks around it, knocks rats.
Crane: left mouse pumps a pendulum; hit strength grows with ball speed, capped at 4 hits.
Bulldozer: 3 wide x 2 high directly ahead, 2 hits, 1 s. Machines move one block per 0.45 s
on a conveyor under or beside them, keep sliding on ice, and stop at anything solid.

**New traps.** Sticky trap (enemies at half speed), pitfall (solid for your team only),
wall spring (flings back whatever runs into it).

## v1.2 changes

- **Water:** hold or tap Space at the surface to leap out. Water is drawn see-through.
- **Lava flows.** Three molten basins per side sit in their own caverns. Open one and lava pours down any gap and creeps up to 3 blocks sideways from where it lands, then rests. Plug it with any block. `LavaFlow` constants: tick 0.45 s, reach 3, cap 1200 blocks per match.
- **Ladders:** Q while aiming at a ladder extends that stack - upward from its top half, downward from its bottom half - even when the end of the stack is out of normal reach.
- **Highways and conveyors** are laid into the floor block you aim at (dirt, grass, stone, wood, brick, ice); the block you swap out goes to your stash. Aimed at a wall they go beside it as before.
- **Target square:** a see-through team-colour outline on the aimed face. The edge nearest the crosshair is solid, and a conveyor runs toward it.
- **Keys:** R changes the Q slot, T pilots siege machines.
- **Digger:** Burrow Sense removed. Default dig is the same as every class; Super Dig (E) is the old big dig.
- **Builder:** Highway ability removed (highways are still sold). Team gates are free. New ability Team Block.
- **Team block:** solid only for its own team. Enemies and loose objects pass through; enemies cannot dig it; its team removes it in one hit; explosions destroy it.
- **Team gate** is a plain see-through coloured block (centre rod removed).
- **Ice:** rats keep sliding for a moment after the ice ends; dropped cheese and stashes slide across and off it.
- **Scrap:** 15 deposits per side instead of 8 - about 870 scrap blocks per map.

## v1.3 changes

- **Painted blocks.** Twelve colours. Press C for the picker, 6 for the Paint slot; right mouse places a full painted block. A painted block is dyed stone: it costs one stone, takes 4 hits, and gives the stone back.
- **Painted microvoxels.** With the chisel out and Paint selected, right mouse adds a microvoxel in the picked colour, onto any chiselable block or into thin air. It is charged to the block's own material like any other chisel add.
- **Highway** is a plank layer lying on the face of the block under it. Rats walk through it on the real floor and get the +60% speed. It needs a floor, goes when that floor is dug out, and can be picked up by digging it.
- **Conveyors and siege.** A machine is moved by a conveyor under it, beside it at the same level, or laid into the floor beside it.
- **Wrecking ball** (must be moving at 2.4 or faster to count): dirt and other soft blocks 1 hit, stone / brick / scrap 2, obsidian 4, team gates 10 (`Config.GATE_HP`). A TNT blast is worth 5 gate hits.
- **Bonked pilots** are thrown off their machine and knocked back; teammates cannot knock you off.
