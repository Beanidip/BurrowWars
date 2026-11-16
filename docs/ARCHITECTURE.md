# Architecture

```
scripts/
  core/    log.gd  config.gd  inputs.gd  sfx.gd   (autoloads)   main.gd (scene transitions)
  world/   blocks.gd (block table)  voxel_world.gd (grid, raycast, save/load, chunk nodes)
           chunk_mesher.gd (mesh build)  map_generator.gd (seeded, mirrored)
  actors/  rat.gd (state + kinematic movement)  rat_sprite.gd (presentation)
           player_controller.gd (input, camera)  bot_brain.gd (AI)
  match/   match.gd (THE AUTHORITY)  class_defs.gd (classes, shop)  match_view.gd (fx/audio)
           game_session.gd (composition root for one session)
  ui/      ui_kit.gd  main_menu.gd  hud.gd  settings_panel.gd
tests/     test_runner (gameplay suite)  smoke_runner (real app flow)  dev/bot_debug
```

## The one rule

**Only `Match` changes gameplay state, and only through validated requests.**

`try_dig`, `try_place_mat`, `try_place_gadget`, `try_bonk`, `try_buy`, `try_change_class`,
`use_ability`, `drop_cheese`, `respawn`. Each checks range, cooldowns, ownership, resources
and protection zones, then applies the change and emits signals (`fx`, `toast`,
`score_changed`, `won`). The human controller and the bots call exactly the same methods.

This is the multiplayer seam. A listen server keeps `Match` as is; clients send these
requests as RPCs and replay `block_changed` / `fx` events. Nothing in the UI or controller
writes scores, wallets, terrain or inventories directly.

## State vs presentation

- `VoxelWorld.visual = false` and `Match.setup(settings, false)` run the full game with no
  meshes, sprites, sound or UI. The test suite and the bot debugger use this.
- `MatchView`, `RatSprite` and `Hud` only read state and listen to signals.
- `Match.step(dt)` advances everything (bots, rats, pickups, TNT, markers). In play it is
  called from `_physics_process`; tests call it in a loop to fast-forward.

## Terrain

- One `PackedByteArray` of block ids (96 x 48 x 48), plus sparse dictionaries for block
  damage, TNT fuses and gate damage. No per-voxel nodes.
- 16^3 chunks. A block change marks its chunk (and neighbours on a border) dirty; up to 6
  chunks are remeshed per frame. Hidden faces are culled; meshes are vertex-coloured and unshaded.
- Gadgets are block ids, so placing, digging, blasting, saving and (later) syncing them is
  the same code path as dirt.

## Movement

`Rat.step` is a small AABB-vs-grid solver (move Y, X, Z separately and snap to cell edges),
with ladders, water, ice friction, conveyors, springs, team gates, dash and knockback.
Chosen over `CharacterBody3D` because terrain changes every few frames: there is no
collider to rebuild, results are deterministic, and it costs almost nothing per rat.

## Bots

No navmesh. A bot looks only at the cells around its feet and picks one of four moves
toward its goal: step level (dig what blocks it, bridge chasms and lava), stair up (dig
headroom, place a dirt step, jump), stair down, or go vertical (dig down / pillar up).
Goals: nearest loose cheese, else a cheese block chosen with per-bot noise so teammates
spread out, else home via an approach point in front of the base. A stuck timer detours,
then respawns as a last resort.

## Data-driven tables

Block behaviour: `Blocks.DEFS`. Classes, abilities, kits, shop stock: `ClassDefs`.
Tuning constants: `Config`. Key bindings: `Inputs.KEYS` (one place, conflict-checked on rebind).

## Performance notes (measured in the headless suite)

- Map generation + index: about 0.2 s.
- A 2v2 bots-only match of 153 simulated seconds runs in about 0.6 s of wall time.
- Not yet profiled on real hardware with a GPU: chunk remesh cost when TNT touches 8 chunks at once.
