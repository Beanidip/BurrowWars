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

## Hats

**Customize Rat** (main menu) picks the hat your rat wears: Party Hat, Top Hat, Crown, Cheese
Wedge, Bobble Beanie, Viking Helmet, Chef's Toque, Propeller Cap, Wizard Hat, Daisy, Cowboy Hat,
Pirate Hat, or none. It is remembered, worn in every match (including the results screen and
on your Wind-up Decoys, which pass for you), and online everyone sees it. Purely cosmetic; all
are free. Bots wear none. The preview can show any class and team and turn around.

## The results screen

When a team reaches the goal, everyone sees the results: the winner, the score and the match
time, and every rat standing in a line-up (winners first), each over its tallies for the match:

| Tally | Counts |
|---|---|
| Cheese banked | cheese you carried home |
| Cheese mined | cheese blocks you dug out |
| Cheese stolen | vault raids, plus cheese the other team dropped (bonked, trapped) that you picked up |
| Bonks landed / Times bonked | bonks that hit (not ones a Rat Knight Shield stopped) |
| Blocks broken | blocks your paws broke (not blasts) |
| TNT set off | your TNT and Mobile TNT that went off, whoever lit it |
| Traps placed | Mouse Traps, Sticky Traps, Pitfalls, Cheese Decoys, Squeaker Pads, Wind-up Decoys |
| Scrap earned | scrap from mining (not refunds or the stash) |

The best at each tally is picked out in gold (except Times bonked), and the winning team's
standout gets an **MVP** badge (banked x10, stolen x6, mined x4, bonks x2, plus TNT, traps and
a little for blocks). Small teams stand side by side; bigger ones one above the other, scrolled
to your own card. The lobby playground keeps no tallies.

**Emotes:** while it's up, the movement keys make your rat perform on its card: **W** cheer,
**A** dance, **D** taunt, **S** flop, **Space** flip (a controller: the left stick, **Y** to
flip). Online, everyone sees everyone's. Bots join in: winners celebrate, losers mostly sulk.

**What next:** offline, **Play again** (a new map), **Main menu** or **Quit game**. The host of
an online game picks **Next game** (a new map, straight in), **Back to the lobby** (the
playground first) or **Main menu** (which ends the game for everyone); players stay connected
through either of the first two. Other players see "Waiting for the host" (on a dedicated server,
a countdown to the next round) and can **Leave**.

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
| Builder | 1.0 | 100 | 2 | Remote workshop, team gates free, starts with 6 ladders, spring, 4 gates, 6 team blocks | Patch: fills a 3x3 (5 s) | - (Team Block is now a Q gadget anyone can buy: 4 for 4 scrap) |
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

## The map

Every match generates a new 128 x 128 map from its seed: plains, mountain ranges (the highest
peaks are icy), and valleys whose deepest floors hold lakes. Blue's base is in one corner and
Red's in the opposite corner. The map is exactly symmetric through its centre (Red's half is
Blue's half turned 180 degrees), so terrain, scrap, cheese, lava, water and landmarks are the
same for both teams. Scrap and loose cheese are scattered sector by sector so every part of
the map has some; obsidian vaults, lava basins, ruins (one is a scrap lab) and obsidian dikes
are placed by the seed. A brick sewer runs from just outside each base to the mushroom chapel
at the centre. The ground is flat for about 15 blocks around each base.

**The deep (the lower third, y 1 to 21).** Minecraft-style caves wander through it: about a
dozen tunnel networks per side that swell, narrow and fork, some opening into rooms, plus three
tunnels per side that start as a hole in the hillside and wind down into the depths. Tunnels
keep at least four blocks of roof under the ground elsewhere, so they never break into lakes.
Whatever reaches the very bottom (y 4 and below) is a lava lake, a few deep rooms have lava
across their floor, and about half the sectors hide a small lava pocket. In return the deep is
rich: most of the map's cheese and about twice the scrap of the rest of the underground,
much of it set into cave walls where you can see it from the tunnel. Nothing deep is
placed within about 20 blocks of a base.

## The lobby playground

Hosted games (and dedicated servers between rounds) start in a playground instead of a map: a
round grassy island in a lake (`MapGenerator.lobby`). There are no bases, scores or bots, and
everything is free as in Free Build, but players keep their own class and team. Each rat wears a
jetpack. Teammates can bonk and shoot each other, and bonks and cannonballs fling twice as far
(`Config.LOBBY_LAUNCH`). The fixtures can't be dug, blasted, chiselled or picked up; the island
itself can be burrowed into, and the coloured tower is meant to be knocked down. Fixtures:

- the plaza in the middle (spawns, respawns), with a clockwise conveyor loop round it;
- a trampoline park: a checkerboard of springs (they also fling anyone standing beside them);
- a launch lane of conveyors into a row of springs, aimed at a bullseye wall. Flying into the
  gold centre, or hitting it with a cannonball, scores a "BULLSEYE!";
- a battery of three cannons anyone can man (T), facing the bullseye across the plaza;
- a lava hot tub (the usual lava rules: bounce, then back to the plaza);
- a pier out to a diving tower with a board over deep water.

A host's lobby lasts until the host presses Enter; a dedicated server's runs a countdown.

## Stash, gear and traps

- **Team Stash** (workshop, 12 scrap, up to 2): place it outside the bases. Press B beside it
  (or at base) to put scrap, dirt, stone, ice and obsidian into your team's shared pool or take
  them out. Cheese never goes in. Only TNT hurts it: 5 blasts break it, and the pool survives.
- **Gear slot** (J): one piece of gear at a time. The Jetpack (14 scrap) lifts you for 1.1 s, then
  needs 5 s to cool down; carrying cheese it lifts half as strongly. Bots buy one when they can
  afford it. Bots also mine scrap they pass near (when not hauling cheese) and bank half of what
  they mined into the team pool whenever they're at base or beside a stash. They don't start (or keep up) a vault raid
  on a base that its team has stood guard in for 20 s. The **Rat Knight Shield** (12 scrap) is raised with J for 5 s: bonks, cannonballs
  and wrecking balls bounce off, so nobody can knock cheese out of your paws, but hauling cheese
  behind it you move a quarter slower. 8 s to ready it again.
- **Bubble Shoes** (gear, 10 scrap): J switches them on or off. While on, stepping off an edge
  (not jumping) blows a bubble block under your feet instead of falling, 2 scrap each, so
  walking out over a gap builds a bridge. Bubbles pop after 10 s; anyone can stand on them or
  dig one. With less than 2 scrap the next step off an edge is a plain fall. Online the server
  makes each bubble.
- **Cheese Decoy** (trap, 12 scrap, single use): looks exactly like Golden Cheese, and the other
  team's aim label even calls it that. An enemy who digs it is dazed for 1.5 s in a stink cloud
  and it's gone; your own team digs it back into the pack. Blasts just destroy it. Bots fall for
  the other team's decoys too.
- **Wind-up Decoy** (trap, 14 scrap, single use): a clockwork rat in your team's colours, with
  your class, your name over its head and a Golden Cheese held high, so to the other team it
  looks like you running off with the cheese. Q sets it down facing the way you look and it
  marches off at a carrier's pace: it hops up single steps, turns at walls and drops a crumb
  trail like a real carrier. An enemy who bonks it gets a TNT blast (same radius and power as
  stationary TNT, so they're thrown and drop any cheese). Left alone it goes off after 20 s,
  with "!!" over it for the last 1.5 s. Other blasts, lava and enemy mouse traps set it off
  early; your own team's bonks pass through it (everyone's do in the lobby). Your team sees it
  labelled "Wind-up Decoy". Bots can't tell: they chase it like a carrier and bonk it. At most
  8 march at once. It is not a rat: it never scores, raids, picks anything up or takes a seat.
- **Impulse Grenade** (trap, 2 for 8 scrap): thrown with Q like Mobile TNT, but it sticks to the
  first thing it touches (ground, wall, lava or a rat, whom it then rides) and goes off 0.4 s
  later (`Config.IMPULSE_FUSE`; in mid-air after 2.5 s if it hits nothing). It damages nothing
  at all: no blocks, cracks, gadgets or TNT, and nobody drops cheese. It only shoves: every rat
  within 4 blocks, thrower and teammates included, is thrown away from it (13 blocks/s plus a
  lift beside it, half that at the edge, never more than about 4 blocks of height); carriers are
  heavier and go 60% as far. Loose cheese, dynamite and wind-ups are pushed too. Ctrl+Q sets one
  at your feet to launch yourself about 4 blocks up. Shares Mobile TNT's 16-in-the-air limit.
- **Teleporter Set** (construction, 16 scrap): a one-way pair of floor pads, in the spirit of
  TF2's. Q puts down the entrance, Q again the exit (each needs a floor; not inside bases).
  Anyone on the owner's team who stands on a charged entrance for 0.5 s (`Config.TELE_WAIT`)
  pops out at the exit, which never sends anyone back. Then the entrance recharges for 6 s
  (`Config.TELE_CHARGE`) and goes dark; a charged one glows with rings rising off it. Cheese
  can't go through: a carrier is told so and stays put (one message per visit). The other team
  can't use them, but can see and break them (15 digs, like placed traps; 5 for the owner's
  team; TNT works too). One set per rat: dig your own pad to pick it up and move it; a third pad
  can't go down. If one of yours is broken, buying tops you up to a full set at the price per
  missing pad (8 scrap). With no exit placed, or the exit blocked, the entrance says so.
- **Squeaker Pad** (trap, 15 scrap): a floor pad. An enemy stepping on it squeaks for everyone
  nearby and drops a beacon only its team sees (8 s). At most one squeak per 2 s; the third
  spends it. Like other placed traps: 5 digs for its team, 15 for anyone else.
- **Ground pound**: a double jump taken (nearly) to its full height and landed flat gives the
  block underfoot one dig hit (dirt cracks, a second pound or a dig breaks it; TNT lights).
  Ceilings, ladders, water, springs and jetpacks spoil it.
- **TNT vs team gadgets**: a blast breaks Team Blocks (either team's) and takes half a Team
  Gate's strength, with cracks showing; two blasts break a gate.
- **Placed traps** (mouse trap, sticky, pitfall, wall spring) take 5 digs for the team that
  placed them and 15 for anyone else (blasts count as anyone else).
- **Springs** fling anything within a block of their sides, as well as what lands on them.
- **Wall springs** shove any rat within a block of them (sides or diagonals, at foot or head
  height, either team) straight away, as well as flinging back what runs into them.
- **Team gates** cost 7 scrap; Builders pay 3.

## Hazards and safety valves

Carrying cheese weakens your dash (50% / 40% / 30% of the normal burst with 1 / 2 / 3+ cheese) and makes it cost 40 stamina instead of 25, on top of the carry slowdown (`Config.DASH_CARRY`, `Config.DASH_CARRY_COST`). Enemy name tags only show while you can see that rat.

**Cheese crumbs:** anyone carrying cheese drops a little pile of crumbs on the ground every
1.4 blocks (`Config.CRUMB_EVERY`). Everyone sees them, so a trail leads straight to the
carrier; they last 25 s (`Config.CRUMB_TIME`) and shrink away over the last 4. None fall in
water or mid-air: a jump just holds the count until you land. Bots run after an enemy hauling
cheese within 10 blocks of them, at about their height, when their own paws are empty.


Lava bounces a rat out on the first touch; a second touch within 8 s bounces it again, spills everything it carries right there, and sends it back to base 0.7 s later. Water slows everyone
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
- **Lava flows.** Four molten basins per side sit in their own caverns, and the deep caves hold lava lakes and pockets (see The map). Open one and lava pours down any gap and creeps up to 3 blocks sideways from where it lands, then rests. Plug it with any block. 
- **Gates hold gadgets.** Aim at your own team gate and press Q with a ladder, spring, conveyor, wall spring or highway: it goes inside the gate. Your team uses the gadget; enemies still bump into the gate and cannot dig the gadget out. Digging it out yourself leaves the gate; breaking the gate (10 wrecking-ball hits or 2 TNT blasts) destroys both.
- **Paint and glass.** 26 opaque colours (greys and in-between shades included) and 10 see-through glass colours. A painted block costs one dirt, or one stone when you have no dirt, takes 2 hits (it is dyed dirt) and gives a dirt back. With the Paint slot, left click recolours dirt and painted blocks; stone is never painted, so paint cannot weaken a wall. Glass is whole blocks only.
- **Wood is scenery.** It breaks but gives nothing, and is neither carved nor copied.
- **Loose cheese** is put down where you look (G), or tossed forward. Springs launch it and wall springs bat it back.
- **Water flows** the same way, faster and further: dig into the pond or the sewer channel and it pours into your tunnels (tick 0.25 s, reach 5, cap 2500 blocks). Lava that touches water hardens into stone, so a bucket-less player can still cap a lava basin by flooding it. Liquids never flow into a base. Constants live in `LiquidFlow` (lava: tick 0.45 s, reach 3, cap 1200).
- **Ladders:** Q while aiming at a ladder extends that stack - upward from its top half, downward from its bottom half - even when the end of the stack is out of normal reach.
- **Highways and conveyors** are laid into the floor block you aim at (dirt, grass, stone, wood, brick, ice); the block you swap out goes to your stash. Aimed at a wall they go beside it as before.
- **Target square:** a see-through team-colour outline on the aimed face. The edge nearest the crosshair is solid, and a conveyor runs toward it.
- **Keys:** R changes the Q slot, T pilots siege machines.
- **Digger:** Burrow Sense removed. Default dig is the same as every class; Super Dig (E) is the old big dig.
- **Builder:** Highway ability removed (highways are still sold). Team gates are free. Team Block moved from an ability to a Q gadget (v1.8).
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
