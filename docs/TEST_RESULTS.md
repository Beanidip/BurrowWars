# Test results

Only tests that were actually executed are listed. Last full run: 2026-11-16 (v1.3).
Engine: Godot 4.7.2.stable.official.ed1daf0bf, Linux x86_64.

## Executed and passing

| Check | Command | Result |
|---|---|---|
| Import + editor validation | `godot --headless --path . --editor --quit` | Pass, no script or resource errors |
| Boot main scene | `godot --headless --path . --quit-after 120` | Pass |
| App-flow smoke test (headless) | `godot --headless --path . res://tests/smoke_runner.tscn` | 80 checks pass, 3 skipped (mouse capture needs a display) |
| Gameplay regression suite | `godot --headless --path . res://tests/test_runner.tscn` | 48 tests, 526 assertions, 0 failed |
| App-flow smoke test on a virtual display (Xvfb, Mesa llvmpipe, OpenGL Compatibility) | same scene with `--rendering-driver opengl3` | 67 checks pass, 0 skipped, at 1280x720, 1920x1080 and 5120x1440 (v1.1) |
| UI fit at each target resolution | smoke test at 1280x720, 1920x1080, 2560x1440, 3440x1440, 5120x1440 | Pass at all five for v1.0; v1.1 re-run at 1280x720, 1920x1080 and 5120x1440 only |
| Gate self-test | made a bonk drop 2 cheese; added a parse error | `tools/check.sh` exited non-zero both times |

All of the above run from one command: `tools/check.sh /path/to/godot` (headless parts).

### What the gameplay suite covers

Map mirroring and determinism, raycast, spawning, movement, walls, jump/double jump/dash,
25% carry speed, dig durability and 3/s rate, base protection, Digger brush, placement
rules, cheese pickup/capacity/deposit, bonk (one cheese, cooldown, 2 s lock, no friendly
fire, no duplication), respawn conservation, scrap multiplier, workshop validation, mouse
trap, TNT chain / obsidian / two-blast gate, ladder, spring, conveyor, team gate, every
class ability, Maestro permission check, class-change cooldown and kit farming, win
condition, map save/load with malformed-file rejection, Free Build, and a bots-only 2v2
match played to the goal with a cheese-conservation check.

### What the smoke test covers

Main menu and every page, starting a race, real key events (jump, W, V, B, I, Esc, N, F5),
real mouse motion and held left / right mouse (display runs), digging, placing, workshop
purchase, inventory, pause/resume, winning, results, rematch, quit to menu, Free Build.

### Visual verification

Screenshots were captured from the real renderer on a virtual display and looked at:
menu, setup, settings, base, first person, surface, sewer, chapel, workshop, inventory,
pause, gadgets, results, Free Build, plus ultrawide. Samples are in `docs/screenshots/`.

## v1.1 acceptance tests (goal document, section 9)

| # | Test | How it was checked | Result |
|---|---|---|---|
| 1 | New match starts without errors | boot + smoke | Pass |
| 2 | Stone takes four dig hits | `stone_and_obsidian` | Pass |
| 3 | Obsidian outlasts stone | `stone_and_obsidian` (12 hits), `dynamite_blast`, `cannon` | Pass |
| 4 | Chiseled geometry survives save and reload | `chisel_persists` | Pass |
| 5 | Microvoxel collision and 4-microvoxel steps | `chisel_collision_and_steps` | Pass |
| 6 | Pantograph copies, rotates, previews, pastes a carved structure | `pantograph` + smoke (ghost preview screenshot) | Pass |
| 7 | Pantograph rejects insufficient resources and protected placement | `pantograph` | Pass |
| 8 | Mobile TNT bounces and detonates on its fuse | `dynamite_physics` | Pass |
| 9 | Spring launches Mobile TNT, physics stays sane | `dynamite_traps` | Pass |
| 10 | Conveyors move TNT and equipment the right way | `dynamite_traps`, `machine_transport` | Pass |
| 11 | Chain reactions leave no stray geometry | `tnt_chain_and_gate`, `dynamite_blast` | Pass |
| 12 | Cannon damages the struck block and four around it | `cannon` | Pass |
| 13 | Crane and bulldozer excavate without corrupting terrain | `crane_and_dozer` + smoke | Pass |
| 14 | Explosion knockback never kills | `dynamite_blast`, smoke | Pass (there is no health or death in the game) |
| 15 | Two connected players see identical terrain and machines | - | **Not met: the project has no multiplayer** |
| 16 | Existing modes, classes, cheese rules, controls still work | the original 21 tests + smoke | Pass |

The smoke test also plays these through the real controller in a running game: 9 and 0
switch tools, the crosshair picks a single microvoxel, right mouse adds one, X rotates,
right mouse pastes, Q throws, R mans and leaves each machine, the mouse aims it, and each
machine visibly chews a stone wall. Screenshots: `docs/screenshots/chisel.jpg`,
`pantograph.jpg`, `cannon.jpg`, `crane.jpg`, `bulldozer.jpg`, `siege_yard.jpg`.

## v1.2 changes and how each was checked

| Change | Automated test | Also seen in the running game |
|---|---|---|
| Leap out of water | `water_exit` (Scout and Digger, hold and tap) | - |
| Lava flows, rests, can be plugged, pools mirrored | `lava_flows` | breach a basin and watch it run (screenshots `lava_pool`, `lava_flowing`) |
| Ladder stack up / down, blocked stack refuses | `ladder_stack_and_floor_gadgets` | Q on a ladder's top half via the real crosshair |
| Conveyor / highway laid into the floor; edge sets direction | `ladder_stack_and_floor_gadgets` | bright edge matches the crosshair, Q lays it that way (`target_outline`) |
| R / T key swap | - | R cycles the Q slot; T mans each machine |
| Super Dig, default dig equal to other classes | `dig_durability_and_rate`, `digger_power`, `class_abilities` | - |
| Team Block rules, free gates for Builder | `team_block_and_builder` | `team_blocks_gates_water` |
| Gate without rod, water see-through | - | looked at close-up screenshots |
| Ice slide-off for rats and objects | `ice_slides_off_the_end` | - |
| More scrap | `scrap_abundance` (about 870 blocks per map) | - |

The display smoke run for v1.2 was at 1280x720 only (76 steps, 0 failed).

## v1.3 changes and how each was checked

| Change | Automated test | Also seen in the running game |
|---|---|---|
| Painted blocks, palette limits, cost and refund | `painted_blocks` | C opens the picker, a pick switches to slot 6, right mouse places three colours (`colour_picker`, `painted_blocks_and_highway`) |
| Painted microvoxels: solid, saved, copied, pasted | `painted_blocks` | chisel + right mouse adds a coloured microvoxel |
| Highway as a surface layer | `highway_layer` | Q lays it on the floor block, which stays |
| Flush conveyor beside a machine moves it | `siege_floor_conveyor` | - |
| Wrecking-ball hit counts and 10-hit gates | `wrecking_ball_table` | - |
| Bonk throws the pilot off | `bonked_pilot` | - |

The display smoke run for v1.3 was at 1280x720 only (83 steps, 0 failed).

## Not executed

- **No human has played this build.** Mouse-look feel, camera comfort in tunnels, difficulty and pacing are untested by a person.
- **Audio was never heard.** The environment has no audio device (Godot fell back to its dummy driver). Sounds are wired and load without errors; levels and timing are unverified.
- **Real GPU / real monitor.** Rendering was software (llvmpipe). Frame rate on real hardware is unmeasured.
- **Windows and Steam Deck.** Only Linux was run. No export builds were made.
- **Multiplayer.** Not implemented, so not tested.
