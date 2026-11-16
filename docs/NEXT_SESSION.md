# Next session handoff

## Start here

1. `tools/check.sh /path/to/godot` - must be green before touching anything (about 30 s).
2. Open the project in Godot 4.7.2 and **play one Cheese Race by hand**. No human has yet.
   Write down what feels wrong before reading the list below.

## Recommended order

1. **Playtest fixes** (feel, camera in tunnels, bot difficulty, audio levels, goal length).
2. **LAN multiplayer.** Keep `Match` as the host authority. Clients send the existing
   `try_*` / `use_ability` requests by RPC; host broadcasts `block_changed`, `fx`, scores
   and rat state. World sync for joiners = seed + list of changed cells. Start with
   `tests/dev` running host and client as two headless processes.
3. Bots that use siege machines and Mobile TNT against gates.
4. Bots: use springs/ladders they own, Saboteur bots plant TNT at enemy gates.
5. Textures or a small atlas for blocks; export presets for Windows and Linux.
6. Chisel brush sizes and pantograph support for gadgets (ladders, conveyors with orientation).

## Balance questions to answer by playing

- Is a 3 s vault raid too fast when you are alone on defence? (`Config.RAID_TIME`)
- Is the Digger now simply the best class? Its double hit also mines scrap faster.
- Cannon at 26 scrap: worth it, or do players just buy TNT? (`ClassDefs.SHOP`)
- Mobile TNT fuse 3 s / radius 2.4 / power 6.5 (`Config.DYNAMITE_*`)

## Things that will bite you

- Anything that changes score, scrap, inventory or terrain must go through `Match`. If you
  are editing `rat.mats` from UI code, stop.
- `Rat` is not a physics body. Use `rat.blocked_at()` / `VoxelWorld.raycast()`, not Godot physics queries.
- New block types: add a row to `Blocks.DEFS` *and* the enum in the same position, then
  decide its look in `ChunkMesher` and its sound in `MatchView._material_sound`.
- New keys: add to `Inputs.KEYS` only. The rebinding UI and conflict check pick it up.
- Mouse-capture checks in the smoke test only run with a display (`xvfb-run` works).
- `tests/dev/bot_debug.tscn` (env `SEED=n`) prints what every bot is doing every 20 s.
