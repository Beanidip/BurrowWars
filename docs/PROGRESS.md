# Progress

Status: **v1.1 - siege, chisel, pantograph and Mobile TNT added on top of the jam build**; originally **jam build complete** - a finished, replayable solo Cheese Race plus Free Build.
Not the full directive: see the cut list in JAM_SCOPE.md.

## Against the directive's milestones

| Milestone | Status |
|---|---|
| 0 Foundation | Done: project, autoloads (log/config/input/audio), scene transitions, test infrastructure, docs |
| 1 Movement and world | Done: voxel terrain, chunks, first/third person, camera collision, jump/dash, dig, place, save/load |
| 2 First playable | Done: bases, mirrored map, cheese, carry slowdown, deposit, scores, victory, rematch |
| 3 Multiplayer | **Cut** for the jam. Authority seam in place (`Match.try_*`). |
| 4 Classes and economy | Done: four classes, class switching, stamina, scrap, multiplier, workshop |
| 5 Construction sandbox | Done (v1.1): ladders, gates, highways, traps (mouse, sticky, pitfall, wall spring), TNT, Mobile TNT, conveyors, ice, springs, inventory, chisel, pantograph |
| 6 Siege engineering | Done (v1.1): cannon, crane, bulldozer, operation, conveyor transport |
| 7 World personality | Partial: sewer, ruins, lab, chapel, vaults, houses, trees, mushrooms, pond, lava caverns, sprites, sounds, particles. Blocks are flat-coloured, no textures |
| 8 Bots and Free Build | Done: bot navigation/objectives/count/skill, Free Build, Chisel Maestro, map save/load |
| 9 Polish and balance | Started: UI verified at five resolutions, rebinding, regression suite. Needs human playtesting |

## Definition of done (directive section 22)

Met: launches reliably, terrain dig/build, cheese and scoring, all standard classes, scrap
economy, inventory and workshop, major construction tools, bots, readable interface, no
known progression blockers, tests pass, reproducible instructions, both modes function.

Not met: host/join multiplayer. This is a jam entry, not the
"initial complete playable release" the directive defines.

## Commits

See `git log`. Three checkpoints: foundation + rules + tests; UI + view + bots + docs; final verification.
