# Test results

Only tests that were actually executed are listed. Date: 2026-11-15.
Engine: Godot 4.7.2.stable.official.ed1daf0bf, Linux x86_64.

## Executed and passing

| Check | Command | Result |
|---|---|---|
| Import + editor validation | `godot --headless --path . --editor --quit` | Pass, no script or resource errors |
| Boot main scene | `godot --headless --path . --quit-after 120` | Pass |
| App-flow smoke test (headless) | `godot --headless --path . res://tests/smoke_runner.tscn` | 34 checks pass, 3 skipped (mouse capture needs a display) |
| Gameplay regression suite | `godot --headless --path . res://tests/test_runner.tscn` | 21 tests, 179 assertions, 0 failed |
| App-flow smoke test on a virtual display (Xvfb, Mesa llvmpipe, OpenGL Compatibility) | same scene with `--rendering-driver opengl3` | 37 checks pass, 0 skipped, at 1280x720 |
| UI fit at each target resolution | smoke test at 1280x720, 1920x1080, 2560x1440, 3440x1440, 5120x1440 | Pass at all five: every menu and dialog inside the viewport |
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

## Not executed

- **No human has played this build.** Mouse-look feel, camera comfort in tunnels, difficulty and pacing are untested by a person.
- **Audio was never heard.** The environment has no audio device (Godot fell back to its dummy driver). Sounds are wired and load without errors; levels and timing are unverified.
- **Real GPU / real monitor.** Rendering was software (llvmpipe). Frame rate on real hardware is unmeasured.
- **Windows and Steam Deck.** Only Linux was run. No export builds were made.
- **Multiplayer.** Not implemented, so not tested.
