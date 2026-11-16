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
| Digger | 0.85 | 150 | 3 | 3x3x3 brush on natural terrain | Burrow Sense: marks nearest hollow/ruin within 30 | - |
| Scout | 1.25 | 100 | 2 | Full speed in water | Sniff: marks nearest cheese within 30 | Beacon: team marker, 120 s |
| Builder | 1.0 | 100 | 2 | Remote workshop, starts with 6 ladders + spring | Patch: fills a 3x3 | Highway: 7 planks ahead, +60% speed |
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
