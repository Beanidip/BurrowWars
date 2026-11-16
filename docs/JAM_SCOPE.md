# Jam scope lock

The master directive describes a 9-milestone game. A jam ships one loop that is
actually fun and actually finished, so the directive was triaged against a 48-hour
clock. The rule used for every feature: **does the Cheese Race loop break without it?**

## The pitch (one sentence)

Dig to golden cheese, haul it home slowly while rivals bonk it out of your paws.

## Schedule (48-hour jam clock)

| Hours | Block | Exit test |
|---|---|---|
| 0-2 | Scope lock, repo, Godot project, logging/config/input | Project boots to a menu |
| 2-10 | Voxel world, mirrored generator, rat movement, dig/place, camera | Walk, dig, build reliably |
| 10-18 | Cheese pickup/carry/deposit, score, win, results, rematch | One full match start to victory |
| 18-26 | Bonk, classes, scrap economy, workshop, gadgets | Every class plays differently |
| 26-34 | Bots that dig, steal and score | Bots-only match finishes |
| 34-40 | HUD, menus, sound, particles, Free Build | New player understands the screen |
| 40-46 | Test suite, smoke test, screenshots at 5 resolutions, fixes | `tools/check.sh` green |
| 46-48 | Docs, package, submit | Zip opens and runs clean |

Feature freeze was at the 40-hour mark: nothing new after that, only fixes.

## Shipped

- Cheese Race vs bots: mirrored seeded map, two protected bases, score, win, results, rematch
- Destructible voxel terrain: dirt, stone, scrap, obsidian, wood, ice, water, lava, brick, more
- Movement: first/third person, camera collision, jump, double jump, dash, stamina, ladders, swimming, ice, knockback
- Cheese: one block = one cheese, 25% carry speed, capacity per class, drop, deposit
- Nonlethal PvP: bonk with 2 s cooldown and a 2 s authoritative pickup lock
- Four classes with working abilities (Digger, Scout, Builder, Saboteur) and class change at base
- Scrap economy with the cheese progression multiplier; data-driven workshop; inventory and Q slot
- Gadgets: ladder, spring, highway, conveyor, mouse trap, TNT (chains), team gate
- Bots: navigate destructible terrain without a navmesh, mine, collect, return, bonk, avoid lava, unstick
- Free Build: Chisel Maestro, flight, unlimited everything, map save/load
- Menus, HUD, settings, key rebinding, toasts, world markers, sound, particles
- Automated tests: 179 gameplay assertions plus an end-to-end smoke test

## Added after the jam (v1.1)

Chisel, pantograph, Mobile TNT, cannon, crane, bulldozer, sticky trap, pitfall, wall spring,
4-microvoxel step-up, vault raids. See `CHANGELOG.md`.

## Still cut (and why)

| Cut | Why it was cut | Cost to add later |
|---|---|---|
| LAN multiplayer (host/join) | Biggest risk on the board; a broken netcode demo is worse than none. All rules already run through one authority (`Match.try_*`), which is the seam for it. | Large |
| Flowing water / lava | Static liquids give the hazard and the swim without a fluid sim | Medium |
| Bots using class abilities and construction | Bots already complete matches | Medium |
| Controller navigation | Keyboard/mouse first | Medium |
| Windows/Linux export builds | Export templates not set up in the build environment | Small |

## Deviations from the directive worth knowing

- **Rats are one block tall.** Tunnels are one block high, so digging is fast and reads clearly.
- **Custom kinematic movement instead of engine physics.** Deterministic, no collider rebuild hitch when terrain changes, and tests can fast-forward a whole match in under a second.
- **Scenes are composed in code.** Only `main.tscn` and the test scenes exist as files. Faster to iterate in a jam; nothing prevents moving to `.tscn` later.
- **Builder and Saboteur carry 2 cheese** (the directive only fixes Digger 3 and Scout 2).
- **The Digger brush never removes the floor under the Digger** unless they aim downward. Found by watching bots dig themselves into pits.
