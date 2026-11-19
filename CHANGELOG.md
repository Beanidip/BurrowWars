# Changelog

## Unreleased - Cheese crumbs, Wind-up Decoy, rats seen from the front and back, teleporters

| Change | Files |
|---|---|
| Cheese crumbs: everyone carrying cheese drops a little pile of crumbs on the ground every 1.4 blocks, so a trail leads to them. Everyone sees it; crumbs last 25 s, then shrink away. None in water or mid-air. One MultiMesh draws them all | `match/match.gd`, `match/crumb_trail.gd`, `match/match_view.gd`, `core/config.gd` |
| Wind-up Decoy (trap, 14 scrap, single use): Q sets down a clockwork rat in your colours, with your class, your name and a Golden Cheese held high. It marches the way you face at a carrier's pace, hops up steps, turns at walls and leaves crumbs. An enemy's bonk sets it off like TNT; left alone it goes off after 20 s (with a "!!" warning); other blasts, lava and enemy mouse traps set it off early. Your team sees it labelled "Wind-up Decoy". Its body is an ordinary rat body outside the rat list, so it moves by the same rules but never scores, raids or takes a seat. Sent to online players in each snapshot; their bonks are checked by the server | `match/windup.gd`, `match/match.gd`, `match/class_defs.gd`, `actors/player_controller.gd`, `actors/rat_sprite.gd`, `match/game_session.gd`, `net/net_server.gd`, `net/net_client.gd` |
| Bots run after an enemy hauling cheese within 10 blocks (at about their height) when their own paws are empty, so they fall for Wind-up Decoys too and bonk them | `actors/bot_brain.gd` |
| Teleporter Set (construction, 16 scrap): a one-way pair of floor pads, like TF2's. Q puts down the entrance, then the exit; your team stands on a charged entrance for half a second and pops out at the exit, then it recharges for 6 s. Cheese can't go through (carriers are told so), the other team can't use them but can break them, and each rat has one set (dig your own pad to move it; a broken pad is replaced at half price). Charged entrances glow with rising rings and every trip flashes a beam at both ends, in team colour (pixelfx scifi/teleporter-pad and scifi/warp-in); a new teleport sound and icon. Online the server sends you and lists the pads in each snapshot | `match/match.gd`, `match/teleporter_view.gd`, `world/blocks.gd`, `world/chunk_mesher.gd`, `match/class_defs.gd`, `ui/hud.gd`, `net/net_server.gd`, `net/net_client.gd`, `tools/import_fx.py`, `tools/make_sfx.py`, `tools/make_icons.py` |
| Rats have a front and a back view as well as the side view, so you can see whether someone is looking at you: a rat facing your camera shows its face (both eyes, nose, whiskers), one facing away shows the back of its head and its tail, and side on it shows its side, now mirrored to whichever way it faces (it always faced right before). Your own rat is seen from behind. Idle, run and jump are drawn for every class (`assets/rats/<class>_front.png`, `_back.png`, made by `tools/rat_views.py`); other animations show the side view | `actors/rat_sprite.gd`, `tools/rat_views.py`, `assets/rats/` |
| Wind-up icon and a ratchet sound (`assets/sfx/windup.wav`); new loading-screen tips. Network protocol 9 | `tools/make_icons.py`, `tools/make_sfx.py`, `ui/loading_screen.gd`, `net/net.gd` |

## 2.1.0 - Knight shield, bubble shoes, decoys, loading screen, scrap texture (2026-11-18)

| Change | Files |
|---|---|
| Version 2.1.0, network protocol 8 (new block ids: 2.0 and 2.1 refuse each other with a clear message) | `project.godot`, `export_presets.cfg`, `net/net.gd` |
| Title screen tagline: "Bunker, Build, Bonk! Bring Home The Golden Cheese!" | `ui/main_menu.gd` |
| Bubble Shoes (gear, 10 scrap): J switches them on/off; stepping off an edge blows a bubble block under your feet (2 scrap each, pops after 10 s), so you can walk a bridge over a gap. Server-checked online | `actors/rat.gd`, `match/match.gd`, `net/net_server.gd`, `world/blocks.gd` |
| Cheese Decoy (trap, 12 scrap, single use): looks exactly like Golden Cheese to the other team, name included; digging it dazes them in a stink cloud. Your own team digs it back up | `match/match.gd`, `world/blocks.gd`, `ui/hud.gd` |
| Squeaker Pad (trap, 15 scrap): an enemy stepping on it squeaks for everyone nearby and drops an 8 s beacon for its team; three squeaks, then it's spent | `match/match.gd`, `world/blocks.gd`, `world/chunk_mesher.gd` |
| Placeholder sounds for the new items (squeak, pop, toot); the sound script is now `tools/make_sfx.py`. New icons. Network protocol 8 (new block ids) | `tools/make_sfx.py`, `tools/make_icons.py`, `net/net.gd` |
| Block-break bursts take the broken block's colour (hue-shifted like hit sparks, on a sheet as bright or dark as the block) | `match/match_view.gd` |
| The sparks knocked off a block while digging are fully that block's colour, highlights included (the hue shader can now colourise, not just shift hue) | `assets/shaders/fx_hue.gdshader`, `match/fx_sprite.gd`, `match/match_view.gd` |
| The shard burst when a block breaks or a cannonball hits it is the block's own colour (dirt brown, grass green, stone grey...), with just a little light and shade; cannon impacts were not tinted at all before | `assets/shaders/fx_hue.gdshader`, `match/match_view.gd` |
| Loading screen with a spinning cheese, a progress bar and a tip when a match starts or you join one. Behind it the map is generated on a worker thread and the whole world is meshed on every CPU core (nearest first), so the game no longer freezes and then stutters for a couple of seconds while chunks stream in; the match waits until it's ready | `ui/loading_screen.gd`, `core/main.gd`, `match/game_session.gd`, `world/voxel_world.gd`, `world/chunk_mesher.gd`, `world/map_generator.gd` |
| Generated water and lava always sit in a bank: open air beside or under them (a pond on a slope, the sewer channel over a cave, lava pools against tunnels) becomes dirt by water, stone by lava. No more see-through water walls or floating lava | `world/map_generator.gd` |
| Wall springs shove anyone who comes within a block of them (sides or diagonals, foot or head height, either team), not only rats that run into them | `actors/rat.gd`, `core/config.gd`, `match/class_defs.gd` |
| Bots stop raiding a base its team has stood guard in for 20 s (the match times each team's guard). Bots dash under exactly the player rules (now covered by a test) | `actors/bot_brain.gd`, `match/match.gd` |
| Bonks show stars and birds circling the dazed rat's head (pixelfx status/stunned) instead of the POW burst | `match/match_view.gd`, `assets/fx/dizzy.png`, `tools/import_fx.py` |
| Dig sparks fly from around the crosshair on the face you hit, scattered a little differently each hit (others' digging: a random spot on the face toward you), with more chips | `match/match_view.gd`, `match/game_session.gd` |
| The raid alarm is a soft two-tone chime, 10 dB quieter than the old grinding siren | `match/match_view.gd`, `assets/sfx/alarm.wav`, `tools/make_sfx.py` |
| HUD: the gadget and gear slots have a fixed width (long names end in "..."), and the abilities panel is smaller and sits to the right of the hotbar instead of over it | `ui/hud.gd` |
| Bots mine scrap within about 5 blocks when they aren't hauling cheese, and bank half of what they mined into the team stash pool whenever they're at base or beside a stash | `actors/bot_brain.gd` |
| Bots fall for the other team's Cheese Decoys (and ignore their own) | `actors/bot_brain.gd`, `match/match.gd` |
| Bubble Shoes out of scrap: the next step off an edge is a plain fall, no hovering; online the cost is counted on your own game straight away | `actors/rat.gd` |
| Other rats' digging is about 9 dB quieter and fades faster with distance (your own digging is unchanged); dash and ground pound sounds are softer | `match/match_view.gd` |
| Scrap blocks have a pixel-art texture (a jumble of nuts, washers, springs, screws, a red clamp and a yellow plug in oily grime), turned and mirrored per face. Blocks can now have textures: `assets/blocks/<name>.png` | `world/block_textures.gd`, `world/chunk_mesher.gd`, `assets/blocks/scrap.png`, `tools/make_block_textures.py` |
| Hit sparks take the colour of the block being hit (a hue-shift shader); painted blocks burst in their own colour | `match/fx_sprite.gd`, `match/match_view.gd`, `assets/shaders/fx_hue.gdshader` |
| Spilled water and lava slope down to the ground at their edges instead of ending in see-through cubes; pools held by banks stay level, and the surface rises to meet liquid stacked above | `world/chunk_mesher.gd`, `world/voxel_world.gd` |
| TNT visibly cracks Team Gates (two blasts break one) and blows up Team Blocks of either team; the workshop says so | `match/match.gd`, `match/class_defs.gd` |
| Dash plays a whoosh along the ground (mirrored to the dash direction) | `match/match_view.gd`, `assets/fx/dash.png` |
| Ground pound: a full double jump landed flat gives the block underfoot a dig hit (TNT lights); server-checked online | `actors/rat.gd`, `match/match.gd`, `net/net_server.gd`, `assets/fx/pound.png` |
| The jetpack lifts half as strongly while you carry cheese | `actors/rat.gd`, `core/config.gd` |
| Paint moved to 8 (chisel 9, pantograph 0 as before) | `core/inputs.gd`, `ui/hud.gd` |
| Rat Knight Shield (gear, 12 scrap): J raises it for 5 s; bonks, cannonballs and wrecking balls bounce off and you keep your cheese, but carrying cheese behind it you move a quarter slower; 8 s cooldown. Server-checked online | `actors/rat.gd`, `match/match.gd`, `match/siege.gd`, `match/class_defs.gd`, `net/net_server.gd`, `ui/hud.gd`, `assets/fx/shield_*.png`, `tools/make_icons.py` |

## 2.0.0 - Lobby playground, deep caves, pixel effects, art pipeline (2026-11-18)

| Change | Files |
|---|---|
| Version 2.0.0, network protocol 7 (the wire format and block list changed: 1.9 and 2.0 refuse each other with a clear message) | `project.godot`, `export_presets.cfg`, `net/net.gd` |
| Team gates cost scrap again: 7 for everyone, 3 for Builders | `match/class_defs.gd` (`price`), `match/match.gd`, `ui/hud.gd` |
| Springs fling any rat or loose cheese within a block of their sides (any team), not only what lands on top | `actors/rat.gd`, `match/match.gd` |
| Team Stash (12 scrap, max 2): a placeable door into your team's shared pool of scrap, dirt, stone, ice and obsidian (no cheese), also reachable at base with B. Only 5 TNT blasts break it; the pool survives | `world/blocks.gd`, `match/match.gd`, `ui/hud.gd`, `net/*` |
| Placed traps (mouse trap, sticky, pitfall, wall spring) take 5 digs for their own team and 15 for the other team or a blast | `match/match.gd` |
| Gear slot (J): one piece worn at a time. Jetpack (14 scrap): 1.1 s of lift, then 5 s to cool down | `actors/rat.gd`, `match/class_defs.gd`, `ui/hud.gd`, `actors/player_controller.gd` |
| Fix: the ground right beside a base could be dug but never built on, so a moat dug around a base could not be filled. Base protection now covers the base itself and grows sideways only | `world/map_generator.gd` |
| Pixel-art icons (16x16) for every gadget, trap, siege machine, gear, material, tool and ability, shown on the hotbar, abilities panel, workshop, team stash, inventory and main menu buttons; class buttons show each class's rat. Icons are PNGs in `assets/icons/` (drawn by `tools/make_icons.py`) and can be replaced with your own art | `ui/icons.gd`, `ui/hud.gd`, `ui/main_menu.gd`, `assets/icons/`, `tools/make_icons.py` |
| Rat art is one sprite sheet per class (72x72 cells, a row per animation) instead of 208 single-frame PNGs. Team colour is painted in magenta and swapped for Blue or Red when the sheet loads, so each class is drawn once. `tools/rat_sheets.py` previews the team colours, packs/unpacks sheets, and draws `docs/rat_sheet_layout.png` | `actors/rat_sprite.gd`, `ui/icons.gd`, `assets/rats/`, `tools/rat_sheets.py` |
| Icons are one sheet, `assets/icons/icons.png` (layout in `docs/icon_sheet_layout.png`); single-icon PNGs still override. The menu panel frame is an editable image, `assets/ui/panel_frame.png` | `ui/icons.gd`, `ui/icon_sheet.gd`, `ui/ui_kit.gd`, `tools/make_icons.py` |
| Bots heading home bridge any gap, climb out of moats near the door instead of walking away, buy and fire jetpacks, and dash on long open runs | `actors/bot_brain.gd` |
| Pixel-art effect animations (from the MIT pixelfx library): TNT explosions, block breaks coloured per material (dirt, stone, ice, scrap, obsidian, wood), hit sparks, BONK pow, pickup sparkle, respawn and cannon puffs, a deposit firework, and a jetpack flame worn on the rat's back. Sheets live in `assets/fx/` and can be redrawn | `match/fx_sprite.gd`, `match/fx_sheets.gd`, `match/match_view.gd`, `assets/fx/`, `tools/import_fx.py` |
| Dust puffs for dashing, jumping and hard landings (a fall of about 3 blocks or more, with a thud) | `actors/rat.gd`, `match/match.gd`, `match/match_view.gd` |
| Water and lava splashes: a rat dropping into water or leaping out of it splashes (bobbing at the surface or wading in from the bank does not), and so does loose cheese. Lava splashes in orange with a sizzle when a rat touches it or an item lands on it | `actors/rat.gd`, `match/match.gd`, `match/match_view.gd`, `assets/sfx/splash.wav`, `assets/sfx/sizzle.wav` |
| Online, a player's game reports its own dash, jump, landing and splash effects; the server plays them for everyone (whitelisted, rate-limited) | `match/match.gd`, `net/net_server.gd` |
| Minecraft-style caves in the lower third of the map: winding tunnel networks that swell, narrow and fork, with rooms, and three tunnels per side that climb out to the surface. The old round noise caves are rarer | `world/map_generator.gd` |
| More lava down deep: tunnels that reach the bottom are lava lakes, some deep rooms have lava floors, and about half the sectors hide a small lava pocket (roughly 3-4x the lava above the bottom layer). None within 20 blocks of a base | `world/map_generator.gd` |
| The lower third is richer: about twice the scrap and 1.7x the cheese, much of it set into cave walls where it shows. Both halves still get exactly the same | `world/map_generator.gd` |
| Lobby playground: a hosted game opens in a playground island (trampoline park, conveyor loop, a cannon battery anyone can man, a bullseye wall to fling each other at, a lava hot tub, a block tower to knock down, a diving tower over the lake). Everyone wears a jetpack, everything is free, and teammates can bonk and shoot each other twice as hard. The match starts only when the host presses Enter; after it, Back to the lobby returns everyone there. A "Lobby" option in the host setup turns it off | `world/map_generator.gd`, `match/match.gd`, `match/siege.gd`, `core/main.gd`, `ui/hud.gd`, `ui/main_menu.gd`, `net/net_server.gd` |
| Dedicated servers hold a 30 s playground lobby before each round (`--lobby S`, 0 turns it off); the countdown runs only while someone is connected | `net/dedicated_server.gd`, `net/net_client.gd` |

## 1.9.0 - Review fixes, line-of-sight names, loaded dash (2026-11-17)

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
| Enemy name tags only show while you have line of sight to that rat (glass, water, team gates and chiselled holes count as see-through); teammates always show | `world/voxel_world.gd` (`line_of_sight`), `match/game_session.gd`, `actors/rat_sprite.gd` |
| Dash while carrying cheese: burst 50% / 40% / 30% of normal for 1 / 2 / 3+ cheese, and it costs 40 stamina instead of 25 | `actors/rat.gd`, `core/config.gd` |
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
