# Next session handoff

## Start here

1. `tools/check.sh /path/to/godot` - must be green before touching anything (about 75 s,
   including the multiplayer tests that start real server/client processes).
2. Play one Cheese Race by hand, then **one online match with two real PCs** (one hosting,
   or both joining a dedicated server). No two humans have played together yet.

## Recommended order

1. **Playtest fixes** (feel, camera in tunnels, bot difficulty, audio levels, goal length).
2. **Multiplayer polish** (done: host/join, dedicated servers, server list; see
   docs/MULTIPLAYER.md). Next: live player counts/ping in the server list (a tiny status
   query), chat, a scoreboard (Tab), kick/ban for server operators, snapshot deltas to cut
   bandwidth, and a relay or NAT punch-through so hosting needs no port forwarding.
3. Bots that use siege machines and Mobile TNT against gates.
4. Bots: use springs/ladders they own, Saboteur bots plant TNT at enemy gates.
5. Textures or a small atlas for blocks. (Windows and Linux export presets exist.)
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
- New rule-changing Match methods need the `if remote != null:` forward at the top AND a
  case in `NetServer.on_act` with argument type checks, or they silently do nothing online.
- Anything new that moves on screen must be added to `NetServer._snapshot` and
  `NetClient.on_snap`, or clients will not see it.
- Bump `Net.PROTOCOL` whenever the wire format changes.
