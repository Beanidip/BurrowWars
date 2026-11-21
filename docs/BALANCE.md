# Balance chart

Every number that shapes how Burrow Wars plays, what it does, and where to change it.
**Generated from the code** by `tools/balance_sheet.py`: after changing a value, run
`python3 tools/balance_sheet.py` and this chart (and `docs/balance.csv`, the same rows for a
spreadsheet, with a Notes column) shows what the game really uses.

- **Value** is exactly as written in the code. Speeds are blocks per second; times are seconds.
- **In play** is worked out from the values where it helps (heights, times, rates).
- **Where** is the file and line to edit. Change the value, save, and the game uses it next run.
- Online, the server's values win: players only see a change once your server runs it.

## Contents

- [Workshop prices](#workshop-prices)
- [Classes](#classes)
- [Block toughness](#block-toughness)
- [Economy and scrap](#economy-and-scrap)
- [Movement and stamina](#movement-and-stamina)
- [Digging and building](#digging-and-building)
- [Cheese, bonks and raids](#cheese-bonks-and-raids)
- [Traps and tricks](#traps-and-tricks)
- [Explosives](#explosives)
- [Gear](#gear)
- [Siege machines](#siege-machines)
- [Bots](#bots)
- [Map](#map)
- [Online: server checks (change with care)](#online-server-checks-change-with-care)
- [Written into the code](#written-into-the-code)

## Workshop prices

In `scripts/match/class_defs.gd` (`SHOP`): **cost** is scrap for one purchase of **qty** pieces; **max** caps how many you can hold
(otherwise 10). Builders pay less for some items (see Classes).

| Item | Category | Cost | Qty | Scrap each | Max | What it does | Line |
|---|---|---:|---:|---:|---:|---|---:|
| Ladder x3 | Mobility | 4 | 3 | 1.3 | - | Climb with Space, descend with Ctrl. Aim at a ladder's top or bottom half and press Q to extend the stack that way. | 51 |
| Spring | Mobility | 6 | 1 | 6.0 | - | Trampoline. Launches anything that lands on it - friend or foe. | 53 |
| Highway x4 | Mobility | 5 | 4 | 1.2 | - | Plank road, laid into the floor you aim at. Rats run 60% faster on it, even hauling cheese. | 55 |
| Conveyor x3 | Mobility | 6 | 3 | 2.0 | - | Laid into the floor you aim at. Runs toward the bright edge of your target square. | 57 |
| Impulse Grenade x2 | Mobility | 8 | 2 | 4.0 | - | Q throws it; it sticks to whatever it hits - ground, wall or rat - and a moment later bursts, throwing everyone near it away (you too), with loose cheese, dynamite and wind-ups. It damages nothing and nobody drops cheese. Ctrl+Q drops it at your feet: launch yourself. | 71 |
| Wall Spring | Mobility | 6 | 1 | 6.0 | - | Sideways bumper block. Shoves away any rat that comes within a block of it, and flings back dynamite that runs into it. | 77 |
| Teleporter Set | Mobility | 16 | 2 | 8.0 | 2 | A one-way pair of pads. Q puts down the entrance, then Q again the exit. Your team stands on the entrance for half a second and pops out at the exit; then it recharges for 6 s. Cheese can't go through. One set per rat: dig a pad of yours to pick it up and move it; if one gets broken, buying tops you up for half price. | 93 |
| Team Block x4 | Construction | 4 | 4 | 1.0 | - | A block in team colours: solid floor or wall for your team, thin air for enemies (and nothing they can dig). TNT blows it up. Dig it to take it back. | 63 |
| Team Stash | Construction | 12 | 1 | 12.0 | 2 | Place it anywhere outside the bases. Your team deposits and takes scrap, dirt, stone, ice and obsidian here (or at base) with B. Only 5 TNT blasts break it - and the shared pool survives. | 65 |
| Team Gate | Construction | 7 | 1 | 7.0 | - | See-through door. Your team walks through. Two TNT blasts (or ten wrecking-ball hits) break it; cracks show the damage. | 67 |
| Ice x4 | Construction | 3 | 4 | 0.8 | - | Slippery block. Slot 3, place with right mouse. | 85 |
| Mouse Trap | Traps | 5 | 1 | 5.0 | - | Snaps on enemy rats: short stun and they drop a cheese. | 59 |
| TNT | Traps | 8 | 1 | 8.0 | - | Hit it to light a 2 s fuse. Blows up Team Blocks and cracks Team Gates (two blasts break one). Saboteurs detonate remotely. Chains. | 61 |
| Mobile TNT x2 | Traps | 7 | 2 | 3.5 | - | Bouncy dynamite stick, 3 s fuse: a TNT blast wherever it ends up, Team Blocks and Gates included. Q throws it, Ctrl+Q sets it down gently. Springs launch it, conveyors carry it, ice lets it slide. | 69 |
| Sticky Trap x2 | Traps | 4 | 2 | 2.0 | - | Glue pad. Enemy rats wade through at half speed; rolling dynamite stops dead. | 73 |
| Pitfall x2 | Traps | 5 | 2 | 2.5 | - | Fake turf. Solid for your team, a hole for everyone and everything else. | 75 |
| Cheese Decoy | Traps | 12 | 1 | 12.0 | - | Looks exactly like Golden Cheese - even its name, to the other team. An enemy who digs it gets a face full of stink and is dazed. Single use. Dig your own to take it back. | 91 |
| Wind-up Decoy | Traps | 14 | 1 | 14.0 | - | A clockwork rat in your colours, wearing your name and holding a Golden Cheese high. Q sets it marching the way you face: it hops up steps, turns at walls and drops crumbs like a real carrier. An enemy who bonks it gets a TNT blast. Left alone it goes off after 20 s. | 95 |
| Squeaker Pad | Traps | 15 | 1 | 15.0 | - | An alarm on the floor: when an enemy steps on it, it squeaks for everyone nearby and drops a beacon your team sees for 8 s. Three squeaks, then it's spent. | 97 |
| Scrap Cannon | Siege | 26 | 1 | 26.0 | 2 | T to pilot it, mouse to aim, left mouse to fire (2 scrap a shot). Blasts a 3x3x3 hole - 3 dig hits in the middle - and throws enemies near it. | 79 |
| Wrecking Crane | Siege | 30 | 1 | 30.0 | 2 | T to pilot it, mouse to turn, left mouse to pump the swing. The ball smashes through block after block; the faster it swings, the harder it hits. | 81 |
| Bulldozer | Siege | 28 | 1 | 28.0 | 2 | T to pilot it, A / D to turn it, left mouse to ram the blade: 3 wide, 2 high. Has no engine - feed it conveyors. | 83 |
| Jetpack | Gear | 14 | 1 | 14.0 | - | Wear it in your gear slot and press J: a burst of thrust lifts you over trenches and up cliffs, half as high while you carry cheese. 5 s to cool down after each burst. One piece of gear at a time. | 87 |
| Bubble Shoes | Gear | 10 | 1 | 10.0 | - | Press J to switch them on or off. While on, stepping off an edge blows a bubble under your feet instead of falling: a bridge as you walk, each bubble 2 scrap, popping after 10 s. Jump to drop off on purpose. One piece of gear at a time. | 89 |
| Rat Knight Shield | Gear | 12 | 1 | 12.0 | - | Wear it in your gear slot and press J to raise it for 5 s: bonks and cannonballs bounce off, so nobody knocks the cheese out of your paws. Hauling cheese behind it you move a quarter slower. 8 s to ready it again. One piece of gear at a time. | 99 |

## Classes

In `scripts/match/class_defs.gd` (`CLASSES`). Speed multiplies the base walking speed (5.5 blocks/s).
Abilities are listed as cooldown seconds / stamina cost.

| Class | Speed | Walks at | With 1 / 2 / 3 cheese | Stamina | Carries | Swims | Abilities | Starts with | Notes | Line |
|---|---:|---:|---|---:|---:|---:|---|---|---|---:|
| Digger | 0.85 | 4.7 | 2.1 / 1.6 / 1.2 | 150 | 3 | 0.5 | Super Dig 4 s / 12 | - | - | 10 |
| Scout | 1.25 | 6.9 | 3.1 / 2.3 / 1.7 | 100 | 2 | 1 | Sniff 6 s / 15; Beacon 10 s / 10 | - | - | 17 |
| Builder | 1 | 5.5 | 2.5 / 1.9 / 1.4 | 100 | 2 | 0.5 | Patch 3x3 5 s / 25 | ladder x 6, spring x 1, gate x 4, teamblock x 6 | pays less: gate = 3, shops anywhere | 24 |
| Saboteur | 1.05 | 5.8 | 2.6 / 2.0 / 1.4 | 100 | 2 | 0.5 | Detonate 1 s / 0; Plant TNT 0.5 s / 0 | tnt x 3, trap x 2, dynamite x 2 | - | 32 |
| Chisel Maestro | 1.3 | 7.2 | 3.2 / 2.4 / 1.8 | 1000 | 6 | 1 | Detonate 0.5 s / 0; Patch 3x3 0.5 s / 0 | - | shops anywhere, flies (Free Build only) | 40 |

## Block toughness

In `scripts/world/blocks.gd` (`DEFS`, the second column). Dig time at 3 hits a second; the wrecking ball's
hits per blow come from its own rule (soft blocks in one blow, stone-like in two, obsidian in four).

| Block | Dig hits | Dig time | Wrecking ball blows | Line |
|---|---:|---:|---:|---:|
| Dirt | 2 | 0.67 s | 1 | 26 |
| Grass | 2 | 0.67 s | 1 | 27 |
| Stone | 4 | 1.33 s | 2 | 28 |
| Scrap | 5 | 1.67 s | 2 | 29 |
| Obsidian | 12 | 4.00 s | 4 | 30 |
| Wood | 3 | 1.00 s | 1 | 31 |
| Ice | 2 | 0.67 s | 1 | 32 |
| Water | can't be dug: liquid | - | - | 33 |
| Lava | can't be dug: liquid (sends rats home) | - | - | 34 |
| Golden Cheese | 3 | 1.00 s | 1 | 35 |
| Bedrock | can't be dug: the map floor | - | - | 36 |
| Blue Base | can't be dug: base platform | - | - | 37 |
| Red Base | can't be dug: base platform | - | - | 38 |
| Ruin Brick | 4 | 1.33 s | 2 | 39 |
| Leaves | 1 | 0.33 s | 1 | 40 |
| Mushroom Cap | 1 | 0.33 s | 1 | 41 |
| Mushroom Stem | 1 | 0.33 s | 1 | 42 |
| Glow Crystal | 3 | 1.00 s | 1 | 43 |
| Highway | 2 | 0.67 s | 1 | 44 |
| Ladder | 1 | 0.33 s | 1 | 45 |
| Spring | 2 | 0.67 s | 1 | 46 |
| TNT | 1 | 0.33 s | 1 | 47 |
| Mouse Trap | 1 | 0.33 s | 1 | 48 |
| Conveyor | 2 | 0.67 s | 1 | 50 |
| Team Gate | can't be dug: broken by 10 wrecking-ball hits or 2 TNT blasts (GATE_HP) | - | - | 54 |
| Sticky Trap | 1 | 0.33 s | 1 | 56 |
| Pitfall | 1 | 0.33 s | 1 | 58 |
| Wall Spring | 2 | 0.67 s | 1 | 60 |
| Scrap Cannon | can't be dug: picked up by its owner, not dug | - | - | 61 |
| Wrecking Crane | can't be dug: picked up by its owner, not dug | - | - | 62 |
| Bulldozer | can't be dug: picked up by its owner, not dug | - | - | 63 |
| Team Block | 1 | 0.33 s | 1 | 65 |
| Team Stash | can't be dug: broken by 5 TNT blasts (STASH_BLASTS) | - | - | 107 |
| Bubble | 1 | 0.33 s | 1 | 110 |
| Cheese Decoy | 3 | 1.00 s | 1 | 112 |
| Squeaker Pad | 1 | 0.33 s | 1 | 115 |
| Teleporter Entrance | 1 | 0.33 s | 1 | 119 |
| Teleporter Exit | 1 | 0.33 s | 1 | 121 |

## Economy and scrap

Scrap is the money; cheese banked by either team makes every scrap block worth more.

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `2` | `BASE_SCRAP_PER_BLOCK` |  | Scrap you get for mining one scrap block, before the multiplier. | `scripts/core/config.gd:54` |
| `1.5` | `GROWTH_BONUS` |  | How fast scrap gains value as cheese is banked. Value = 1 + (cheese banked by both teams / goal) x this. At 1.5, scrap is worth 2.5x by the time a team wins. | `scripts/core/config.gd:55` |
| `10` | `STACK_MAX` |  | Most of one gadget you can carry (a workshop item can set a lower 'max'). | `scripts/core/config.gd:56` |
| `3.5` | `STASH_REACH` |  | How close (blocks) you must stand to a Team Stash to use it. | `scripts/core/config.gd:25` |
| `5` | `STASH_BLASTS` |  | TNT blasts that break a Team Stash. | `scripts/core/config.gd:24` |
| `2.5` | `CHEESE_PER_GOAL` |  | A Cheese Race map always holds at least this many cheese per point of goal (goal 8 -> 20+ cheese). | `scripts/world/map_generator.gd:104` |

## Movement and stamina

Speeds are in blocks per second; 1 block is about one rat tall.

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `5.5` | `BASE_SPEED` | see the class table for each class's speed | Walking speed at class speed 1.0 (each class multiplies it). | `scripts/core/config.gd:10` |
| `[1.0, 0.45, 0.34, 0.25]` | `CARRY_SPEED` |  | Speed multiplier while carrying 0, 1, 2 and 3+ cheese. | `scripts/core/config.gd:11` |
| `24.0` | `GRAVITY` |  | How fast everything falls (also sets jump heights). | `scripts/actors/rat.gd:12` |
| `8.3` | `JUMP_SPEED` | jumps 1.4 blocks high | Upward speed of a jump. | `scripts/actors/rat.gd:13` |
| `7.6` | `DOUBLE_JUMP_SPEED` | +1.2 blocks from the top of a jump | Upward speed of the double jump (costs stamina, see below). | `scripts/actors/rat.gd:14` |
| `10.0` | `DOUBLE_JUMP_COST` |  | Stamina a double jump costs. | `scripts/core/config.gd:52` |
| `14.0` | `DASH_SPEED` |  | Speed of a dash burst. | `scripts/actors/rat.gd:15` |
| `25.0` | `DASH_COST` | 4 dashes from a full 100 stamina (6 for the Digger's 150) | Stamina a dash costs when you carry no cheese. | `scripts/core/config.gd:19` |
| `[1.0, 0.5, 0.4, 0.3]` | `DASH_CARRY` |  | Dash strength while carrying 0, 1, 2 and 3+ cheese. | `scripts/core/config.gd:20` |
| `40.0` | `DASH_CARRY_COST` |  | Stamina a dash costs while carrying any cheese. | `scripts/core/config.gd:21` |
| `14.0` | `STAMINA_REGEN` | a 100-stamina rat refills in 7 s | Stamina regained per second (not while dashing). | `scripts/core/config.gd:53` |
| `15.5` | `SPRING_SPEED` | about 5.0 blocks up | How hard a Spring launches whoever lands on it. | `scripts/actors/rat.gd:16` |
| `12.0` | `SPRING_SIDE_SPEED` | about 3.0 blocks up | Springs also fling anything standing right next to them, this hard. | `scripts/core/config.gd:27` |
| `13.0` | `WALL_SPRING_SPEED` |  | How hard a Wall Spring shoves anyone within a block of it. | `scripts/core/config.gd:28` |
| `0.85` | `POUND_HEIGHT` |  | Ground pound: a double jump landed flat thumps the block below if you got at least this share of its full height. | `scripts/core/config.gd:50` |
| `0.6` | `POUND_COOLDOWN` |  | Seconds between ground pounds. | `scripts/core/config.gd:51` |

## Digging and building

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `3.0` | `DIG_RATE` | dirt in 0.67 s, stone in 1.33 s | Dig hits per second while holding dig. | `scripts/core/config.gd:8` |
| `4.5` | `DIG_REACH` |  | How far (blocks) you can dig, build and bonk from your eyes. | `scripts/core/config.gd:9` |
| `12` | `OBSIDIAN_HITS` |  | Dig hits to break obsidian (other blocks are in the block table below). | `scripts/world/blocks.gd:18` |
| `9.0` | `CHISEL_RATE` |  | Chisel edits (one microvoxel each) per second. | `scripts/core/config.gd:57` |
| `9` | `PANTOGRAPH_MAX` |  | Biggest blueprint the pantograph copies, in blocks per side. | `scripts/core/config.gd:83` |

## Cheese, bonks and raids

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `2.0` | `BONK_COOLDOWN` |  | Seconds between your bonks. | `scripts/core/config.gd:15` |
| `2.4` | `BONK_RANGE` |  | How close (blocks) a rat must be to bonk it. | `scripts/core/config.gd:16` |
| `2.0` | `BONK_PICKUP_LOCK` |  | Seconds a bonked rat can't pick its dropped cheese back up. | `scripts/core/config.gd:18` |
| `3.0` | `RAID_TIME` |  | Seconds you stand in the enemy base to steal one cheese they banked (a defender in their base stops it). | `scripts/core/config.gd:14` |
| `2.0` | `LOBBY_LAUNCH` |  | In the playground lobby, bonks and cannonballs throw rats this many times harder. | `scripts/core/config.gd:17` |
| `1.4` | `CRUMB_EVERY` |  | Blocks a cheese carrier walks between the crumbs they drop. | `scripts/core/config.gd:45` |
| `25.0` | `CRUMB_TIME` |  | Seconds a crumb stays on the ground. | `scripts/core/config.gd:46` |

## Traps and tricks

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `5` | `TRAP_HITS_OWN` |  | Dig hits for a team to clear its own trap. | `scripts/core/config.gd:22` |
| `15` | `TRAP_HITS_ENEMY` |  | Dig hits for the other team to clear a trap (a blast counts too). | `scripts/core/config.gd:23` |
| `1.5` | `DECOY_STUN` |  | Seconds an enemy is dazed after digging a Cheese Decoy. | `scripts/core/config.gd:39` |
| `3` | `SQUEAKER_USES` |  | Squeaks before a Squeaker Pad is spent. | `scripts/core/config.gd:40` |
| `2.0` | `SQUEAKER_REST` |  | Seconds between squeaks from one pad. | `scripts/core/config.gd:41` |
| `8.0` | `SQUEAKER_MARK` |  | Seconds the beacon a squeak drops for its team lasts. | `scripts/core/config.gd:42` |
| `20.0` | `WINDUP_FUSE` |  | Seconds a Wind-up Decoy marches before going off by itself. | `scripts/core/config.gd:47` |
| `1.5` | `BLINK` |  | Seconds of '!!' warning before a Wind-up goes off by itself. | `scripts/match/windup.gd:17` |
| `8` | `WINDUP_MAX_ACTIVE` |  | Wind-ups marching at once (both teams). | `scripts/core/config.gd:48` |
| `0.5` | `TELE_WAIT` |  | Seconds standing on a charged teleporter entrance before it sends you. | `scripts/core/config.gd:43` |
| `6.0` | `TELE_CHARGE` | one trip every 6.5 s per entrance | Seconds an entrance recharges after each trip. | `scripts/core/config.gd:44` |

## Explosives

Blast power is in dig hits at the centre, falling to nothing at the radius.

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `2.9` | `TNT_RADIUS` |  | Placed TNT: blast radius in blocks. | `scripts/core/config.gd:58` |
| `10.0` | `TNT_POWER` |  | Placed TNT: dig hits at the centre. | `scripts/core/config.gd:59` |
| `2.4` | `DYNAMITE_RADIUS` |  | Mobile TNT: blast radius in blocks. | `scripts/core/config.gd:60` |
| `6.5` | `DYNAMITE_POWER` |  | Mobile TNT: dig hits at the centre. | `scripts/core/config.gd:61` |
| `3.0` | `DYNAMITE_FUSE` |  | Mobile TNT: seconds from throw to boom. | `scripts/core/config.gd:62` |
| `12.0` | `DYNAMITE_THROW_SPEED` |  | Mobile TNT and Impulse Grenades: how hard they're thrown. | `scripts/core/config.gd:63` |
| `16` | `DYNAMITE_MAX_ACTIVE` |  | Sticks and grenades in the air at once (everyone together). | `scripts/core/config.gd:64` |
| `0.4` | `IMPULSE_FUSE` |  | Impulse Grenade: seconds from sticking to bursting. | `scripts/core/config.gd:65` |
| `2.5` | `IMPULSE_FLIGHT` |  | Impulse Grenade: bursts in mid-air after this long if it hits nothing. | `scripts/core/config.gd:66` |
| `4.0` | `IMPULSE_RADIUS` |  | Impulse Grenade: blocks it pushes things within. | `scripts/core/config.gd:67` |
| `13.0` | `IMPULSE_PUSH` |  | Impulse Grenade: speed it throws a rat at right beside it (half at the edge). | `scripts/core/config.gd:68` |
| `8.0` | `IMPULSE_LIFT` |  | Impulse Grenade: extra upward speed, scaled the same way. | `scripts/core/config.gd:69` |
| `14.0` | `IMPULSE_MAX_UP` | about 4.1 blocks up at most | Impulse Grenade: the most upward speed it can give. | `scripts/core/config.gd:70` |
| `0.6` | `IMPULSE_CARRY` |  | Impulse Grenade: a cheese carrier is pushed this much as hard. | `scripts/core/config.gd:71` |
| `10` | `GATE_HP` |  | Hits a Team Gate takes before breaking: wrecking ball hits count 1, a TNT blast 5. | `scripts/core/config.gd:12` |

## Gear

One piece worn at a time; the gear button (J) uses it.

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `1.1` | `JETPACK_TIME` |  | Jetpack: seconds of thrust per use. | `scripts/core/config.gd:30` |
| `9.0` | `JETPACK_LIFT` | about 12 blocks of climb per burn | Jetpack: upward speed while thrusting. | `scripts/core/config.gd:31` |
| `5.0` | `JETPACK_COOLDOWN` |  | Jetpack: seconds after the thrust ends before it can fire again. | `scripts/core/config.gd:32` |
| `0.5` | `JETPACK_CARRY` |  | Jetpack: lift while carrying cheese (0.5 = half). | `scripts/core/config.gd:33` |
| `5.0` | `SHIELD_TIME` |  | Rat Knight Shield: seconds it stays raised (bonks and cannonballs bounce off). | `scripts/core/config.gd:34` |
| `8.0` | `SHIELD_COOLDOWN` |  | Rat Knight Shield: seconds after it drops before you can raise it again. | `scripts/core/config.gd:35` |
| `0.75` | `SHIELD_CARRY_SPEED` |  | Rat Knight Shield: speed while raised and carrying cheese. | `scripts/core/config.gd:36` |
| `2` | `BUBBLE_COST` | a 10-block bridge costs 20 scrap | Bubble Shoes: scrap per bubble you step onto. | `scripts/core/config.gd:37` |
| `10.0` | `BUBBLE_TIME` |  | Bubble Shoes: seconds a bubble lasts before it pops. | `scripts/core/config.gd:38` |

## Siege machines

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `2` | `CANNON_SCRAP` |  | Scrap Cannon: scrap each shot costs the gunner (free in Free Build and the playground). | `scripts/core/config.gd:75` |
| `2.2` | `CANNON_COOLDOWN` | at most 27 shots a minute | Scrap Cannon: seconds between shots. | `scripts/core/config.gd:72` |
| `24.0` | `CANNON_SPEED` |  | Scrap Cannon: speed of the cannonball (higher = flatter, longer shots). | `scripts/core/config.gd:73` |
| `14.0` | `SHOT_GRAVITY` |  | Scrap Cannon: how fast cannonballs drop. | `scripts/match/siege.gd:15` |
| `3` | `CANNON_HIT` |  | Scrap Cannon: dig hits on the struck block; the six touching it take 2, the rest of the 3x3x3 take 1. | `scripts/core/config.gd:74` |
| `13.0` | `CANNON_PUSH` |  | Scrap Cannon: speed a direct hit throws a rat at. | `scripts/core/config.gd:76` |
| `7.0` | `CANNON_LIFT` |  | Scrap Cannon: the upward part of that throw. | `scripts/core/config.gd:77` |
| `2.6` | `CANNON_SPLASH` |  | Scrap Cannon: blocks from the impact the blast still shoves enemy rats. | `scripts/core/config.gd:78` |
| `2.4` | `CRANE_MIN_SPEED` |  | Wrecking Crane: the ball must swing at least this fast (blocks/s) to do damage. | `scripts/core/config.gd:13` |
| `0.85` | `BALL_KEEP_BROKE` |  | Wrecking Crane: share of its speed the ball keeps after smashing a block to pieces. | `scripts/match/siege.gd:378` |
| `0.6` | `BALL_KEEP_HELD` |  | Wrecking Crane: share it keeps after hitting a block that held (it still goes through). | `scripts/match/siege.gd:379` |
| `3.0` | `CRANE_CABLE` |  | Wrecking Crane: cable length (longer = wider, slower swing). | `scripts/match/siege.gd:13` |
| `2.5` | `CRANE_REACH` |  | Wrecking Crane: boom length (how far out the ball hangs). | `scripts/match/siege.gd:12` |
| `4` | `CRANE_MAX_HIT` |  | Not used by the game any more (left over; safe to ignore). | `scripts/core/config.gd:79` |
| `1.0` | `DOZER_COOLDOWN` |  | Bulldozer: seconds between rams. | `scripts/core/config.gd:80` |
| `2` | `DOZER_HIT` |  | Bulldozer: dig hits on each of the 6 blocks (3 wide, 2 high) in front of the blade. | `scripts/core/config.gd:81` |
| `0.45` | `MACHINE_MOVE_TIME` |  | Seconds a machine takes to ride one block along a conveyor. | `scripts/core/config.gd:82` |

## Bots

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `20.0` | `BOT_RAID_GUARDED` |  | Bots give up raiding a base its team has stood guard in for this many seconds. | `scripts/core/config.gd:29` |
| `10.0` | `WINDUP_CHASE` |  | Bots chase a cheese carrier (or a Wind-up that looks like one) within this many blocks. | `scripts/core/config.gd:49` |
| `5` | `SCRAP_REACH` |  | How far (blocks) a bot looks for scrap to mine on the side. | `scripts/actors/bot_brain.gd:10` |
| `40` | `SCRAP_ENOUGH` |  | A bot this rich stops making detours for scrap. | `scripts/actors/bot_brain.gd:11` |

## Map

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `22.0` | `FLAT_RADIUS` |  | Terrain is levelled this far (blocks) around each base. | `scripts/world/map_generator.gd:28` |
| `11` | `CAVE_SYSTEMS` |  | Cave networks per half of the map. | `scripts/world/map_generator.gd:31` |
| `3` | `CAVE_ENTRANCES` |  | Caves per half that climb out to the surface. | `scripts/world/map_generator.gd:32` |
| `4` | `CAVE_LAVA_Y` |  | Cave cells this deep (block height) fill with lava. | `scripts/world/map_generator.gd:33` |
| `8` | `BASE_SIZE` |  | Width of each base platform in blocks. | `scripts/world/map_generator.gd:27` |

## Online: server checks (change with care)

Generous on purpose: lag must never cost an honest player more than a rare correction. If you add a new way to move, raise the matching limit.

| Value | Setting | In play | What it does | Where |
|---|---|---|---|---|
| `40.0` | `MAX_SPEED` |  | Fastest (blocks/s) a player's reported movement may be. | `scripts/net/net_server.gd:19` |
| `3.4` | `JUMP_RISE` |  | Highest (blocks) a rat may rise since it last stood on something, from jumps. | `scripts/net/anti_cheat.gd:28` |
| `6.8` | `SPRING_RISE` |  | ...near a spring. | `scripts/net/anti_cheat.gd:29` |
| `11.8` | `JET_RISE` |  | ...extra when wearing a jetpack. | `scripts/net/anti_cheat.gd:30` |
| `0.2` | `INSIDE_GRACE` |  | Seconds a rat may report itself inside a block before it's put back. | `scripts/net/anti_cheat.gd:24` |
| `8.0` | `STRIKE_LIMIT` |  | Strikes before a dedicated server removes a player. | `scripts/net/anti_cheat.gd:22` |
| `30.0` | `STRIKE_FADE` |  | Seconds for one strike to be forgiven. | `scripts/net/anti_cheat.gd:23` |
| `3` | `SNAP_EVERY` |  | Physics frames between world updates to players (3 = 20 a second). | `scripts/net/net_server.gd:17` |

## Written into the code

These are written straight into the game logic rather than named. Change them there; ask me to
turn any of them into a named setting.

| Value | What | What it does | Where |
|---|---|---|---|
| `6` | Starting scrap | Scrap every rat starts a match with. | `scripts/match/match.gd:194` |
| `7.0` | Bonk throw (sideways) | How hard a bonk shoves the bonked rat away. | `scripts/match/match.gd:1294` |
| `[7.0, 3.0, 0.0]` | Bot rest times | Seconds bots pause between decisions for Relaxed, Normal and Fierce. | `scripts/ui/main_menu.gd:331` |
| `8` | Default cheese goal | Goal offered in the Cheese Race setup the first time (players can change it, 3-250). | `scripts/core/config.gd:99` |
| `1.6` | Highway speed boost | Speed multiplier while running on a Highway (1.6 = 60% faster). | `scripts/actors/rat.gd:170` |
| `0.5` | Sticky Trap slow | Speed multiplier while stuck in an enemy Sticky Trap. | `scripts/actors/rat.gd:166` |
