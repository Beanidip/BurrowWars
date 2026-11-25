extends Node
## Headless regression suite. Run with:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code 0 = all assertions passed, 1 = at least one failed.
## Matches run without visuals and are fast-forwarded with Match.step().

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _current := ""


func _ready() -> void:
	var only := OS.get_environment("BW_TEST")
	for t: String in [
		"map_is_mirrored_and_deterministic", "raycast", "spawn_and_settle", "movement_and_walls",
		"carry_slowdown", "dig_durability_and_rate", "placement_rules", "cheese_loop_and_capacity",
		"bonk_rules", "respawn_conserves_cheese", "economy_multiplier", "workshop_rules",
		"mouse_trap", "tnt_chain_and_gate", "ladder_spring_conveyor_gate", "class_abilities",
		"class_permissions", "win_condition", "vault_raid", "digger_power", "water_exit", "lava_flows", "water_flows", "ladder_stack_and_floor_gadgets",
		"team_block_and_builder", "ice_slides_off_the_end", "scrap_abundance",
		"painted_blocks", "review_fixes", "bot_sees_cheese", "enemy_names_need_sight", "spring_sides_and_cheese", "trap_durability", "team_stash", "jetpack_gear", "effect_sheets", "motion_and_splash_fx", "deep_caves_and_riches", "lobby_playground", "moves_and_blasts", "knight_shield", "bubble_shoes", "decoy_and_squeaker", "bots_scrap_and_decoys", "sound_levels", "pools_springs_raids_sparks", "crumb_trail", "windup_decoy", "bots_chase_windups", "windup_replica", "rat_views", "teleporters", "impulse_grenade", "credits_and_licences", "display_and_audio_settings", "threaded_remesh", "merged_terrain_faces", "safe_saves_and_exit", "tutorial", "gamepad_input", "map_in_parts", "anti_cheat_honest_play", "anti_cheat_catches_cheats", "sixteen_a_side", "server_list", "cheat_code", "audio_buses", "wrecking_ball_smashes_through", "workshop_categories", "bulldozer_turns", "results_stats_and_emotes", "hats", "scrap_race", "bots_finish_a_scrap_race", "meteor_shower", "lava_freeze_fungus", "modifiers", "held_until_ready", "unstick_nearest", "bot_crosses_trench", "bot_gear_and_dash", "dash_with_cheese", "paint_on_click", "pantograph_transforms", "big_goal_and_map_import", "cheese_drop_and_springs", "ability_cooldowns", "gate_holds_gadgets", "wood_is_scenery", "highway_layer", "siege_floor_conveyor", "wrecking_ball_table", "bonked_pilot", "save_load", "free_build",
		"stone_and_obsidian", "chisel_rules", "chisel_economy_is_zero_sum", "chisel_collision_and_steps",
		"chisel_persists", "pantograph", "dynamite_physics", "dynamite_traps", "dynamite_blast",
		"new_traps_vs_rats", "cannon", "crane_and_dozer", "machine_transport", "machine_rules",
		"bots_complete_a_match",
	]:
		if only != "" and only != t:
			continue
		_current = t
		var before := _fails
		var t0 := Time.get_ticks_msec()
		call("test_" + t)
		print("%s  %s  (%d ms)" % ["PASS" if _fails == before else "FAIL", t, Time.get_ticks_msec() - t0])
	print("---- %d checks, %d failed ----" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("    ASSERT FAILED [%s]: %s" % [_current, what])


func new_match(extra: Dictionary = {}) -> Match:
	var s := {"mode": "race", "seed": 4242, "goal": 3}
	s.merge(extra, true)
	var m := Match.new()
	m.auto_step = false
	add_child(m)
	m.setup(s, false)
	return m


func run(m: Match, seconds: float) -> void:
	for i in int(seconds / DT):
		m.step(DT)


func end_noop() -> void:
	pass


func end(m: Match) -> void:
	remove_child(m)
	m.free()


func flat_arena(m: Match, at: Vector3i, r := 6) -> void:
	## Carve a flat stone-floored box of air to test in.
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			m.world.set_block(at + Vector3i(dx, -1, dz), Blocks.STONE)
			for dy in 6:
				m.world.set_block(at + Vector3i(dx, dy, dz), Blocks.AIR)


func total_cheese(m: Match) -> int:
	var n := m.world.cheese_cells.size() + m.scores[0] + m.scores[1]
	for r in m.rats:
		n += r.carried
	for p in m.pickups:
		if p.kind == "cheese":
			n += 1
	return n


const ARENA := Vector3i(30, 40, 10)


func arena_rat(m: Match, team: int, cls: String, offset := Vector3.ZERO) -> Rat:
	var r := m.spawn_rat(team, cls, false)
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5) + offset
	return r


# ------------------------------------------------------------------ tests

func test_map_is_mirrored_and_deterministic() -> void:
	var a := new_match()
	var b := new_match()
	check(a.world.data == b.world.data, "same seed gives identical maps")
	var c := new_match({"seed": 99})
	check(a.world.data != c.world.data, "different seed gives a different map")
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	var mismatches := 0
	for y in VoxelWorld.SY:
		for z in sz:
			for x in sx / 2:
				if Blocks.rotate180(a.world.get_block(x, y, z)) != a.world.get_block(sx - 1 - x, y, sz - 1 - z):
					mismatches += 1
	check(mismatches == 0, "red's half is blue's half turned 180 degrees (%d mismatches)" % mismatches)
	var b0 := MapGenerator.base_center(0)
	var b1 := MapGenerator.base_center(1)
	check(b0.x < 16 and b0.z < 16 and b1.x > sx - 16 and b1.z > sz - 16, "the bases sit in opposite corners")
	check(MapGenerator.spawn_point(1).is_equal_approx(MapGenerator.rot_point(MapGenerator.spawn_point(0))), "spawns match through the centre")
	# every resource is shared out equally
	var per := [{}, {}]
	for i in a.world.data.size():
		var side := 0 if i % sx < sx / 2 else 1
		var id := a.world.data[i]
		per[side][id] = int(per[side].get(id, 0)) + 1
	for id: int in [Blocks.SCRAP, Blocks.CHEESE, Blocks.OBSIDIAN, Blocks.LAVA, Blocks.WATER, Blocks.STONE, Blocks.DIRT, Blocks.GRASS, Blocks.ICE]:
		check(int(per[0].get(id, 0)) == int(per[1].get(id, 0)), "%s is split evenly (%d / %d)" % [Blocks.block_name(id), int(per[0].get(id, 0)), int(per[1].get(id, 0))])
	check(a.world.cheese_cells.size() >= 60, "plenty of cheese on the bigger map (%d)" % a.world.cheese_cells.size())
	# scrap is spread out: nearly every 16x16 sector has some
	var sectors := {}
	for i in a.world.data.size():
		if a.world.data[i] == Blocks.SCRAP:
			sectors[Vector2i((i % sx) / 16, ((i / sx) % sz) / 16)] = true
	check(sectors.size() >= (sx / 16) * (sz / 16) * 85 / 100, "scrap is dispersed over the map (%d of %d sectors)" % [sectors.size(), (sx / 16) * (sz / 16)])
	# the landscape has plains, mountains and valleys, on every seed tried
	for m: Match in [a, c]:
		var plains := 0
		var high := 0
		var low := 0
		for x in range(0, sx, 2):
			for z in range(0, sz, 2):
				var top := m.world.surface_y(x, z)
				if absi(top - MapGenerator.GROUND) <= 2:
					plains += 1
				elif top >= MapGenerator.GROUND + 10:
					high += 1
				elif top <= MapGenerator.GROUND - 4:
					low += 1
		check(plains > 600 and high > 60 and low > 60, "seed %d has plains (%d), mountains (%d) and valleys (%d)" % [int(m.settings["seed"]), plains, high, low])
	var counts := {}
	for id in a.world.data:
		counts[id] = int(counts.get(id, 0)) + 1
	for need: int in [Blocks.SCRAP, Blocks.OBSIDIAN, Blocks.WATER, Blocks.LAVA, Blocks.WOOD, Blocks.BRICK,
			Blocks.BASE_BLUE, Blocks.BASE_RED, Blocks.SHROOM_CAP, Blocks.LADDER, Blocks.GLOW]:
		check(int(counts.get(need, 0)) > 0, "map contains " + Blocks.block_name(need))
	print("    cheese=%d scrap=%d air_ratio=%.2f" % [a.world.cheese_cells.size(), counts.get(Blocks.SCRAP, 0),
		float(counts.get(Blocks.AIR, 0)) / a.world.data.size()])
	end(a); end(b); end(c)

func test_raycast() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	m.world.set_block(ARENA + Vector3i(3, 0, 0), Blocks.STONE)
	var hit := m.world.raycast(Vector3(ARENA) + Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), 10.0)
	check(not hit.is_empty() and hit["cell"] == ARENA + Vector3i(3, 0, 0), "ray hits the stone block")
	check(not hit.is_empty() and hit["normal"] == Vector3i(-1, 0, 0), "ray reports the visible face")
	check(m.world.raycast(Vector3(ARENA) + Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), 2.0).is_empty(), "ray respects max distance")
	end(m)


func test_spawn_and_settle() -> void:
	var m := new_match()
	for team in 2:
		for i in 3:
			var r := m.spawn_rat(team, ClassDefs.ORDER[i], i > 0)
			check(not r.blocked(), "spawn point is free for team %d slot %d" % [team, i])
	m.bots.clear()
	run(m, 1.0)
	for r in m.rats:
		check(r.on_floor, "rat %d rests on the base floor" % r.id)
		check(m.in_base(r), "rat %d starts inside its own base" % r.id)
	end(m)


func test_movement_and_walls() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	run(m, 0.3)
	var x0 := r.position.x
	r.wish = Vector3(1, 0, 0)
	run(m, 0.5)
	check(r.position.x > x0 + 2.0, "rat walks forward (moved %.2f)" % (r.position.x - x0))
	# wall two blocks high: cannot be walked through or auto-climbed
	for dy in 2:
		for dz in range(-6, 7):
			m.world.set_block(ARENA + Vector3i(5, dy, dz), Blocks.STONE)
	run(m, 2.0)
	check(r.position.x < ARENA.x + 5.0 - Rat.RADIUS + 0.01, "wall stops the rat (x=%.3f)" % r.position.x)
	check(r.position.y < ARENA.y + 0.05, "no unintended auto-climb of a full block")
	# jump + double jump clears a single block
	r.wish = Vector3.ZERO
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	run(m, 0.2)
	r.jump_pressed = true
	run(m, 0.25)
	var apex := r.position.y - ARENA.y
	check(apex > 1.0, "jump rises over one block (%.2f)" % apex)
	var st := r.stamina
	r.jump_pressed = true
	m.step(DT)
	check(r.vel.y > 5.0 and r.stamina < st, "double jump works and costs stamina")
	run(m, 2.0)
	# dash
	st = r.stamina
	x0 = r.position.x
	r.wish = Vector3(-1, 0, 0)
	r.dash_pressed = true
	run(m, 0.2)
	check(r.stamina <= st - Config.DASH_COST + 4.0, "dash consumes stamina")
	check(x0 - r.position.x > 1.6, "dash covers ground quickly (%.2f)" % (x0 - r.position.x))
	end(m)


func test_carry_slowdown() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 10)
	var r := arena_rat(m, 0, "digger", Vector3(-8, 0, 0))
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	var speeds: Array[float] = []
	for load in 4:
		r.position.x = ARENA.x - 8.0
		r.vel = Vector3.ZERO
		r.carried = load
		run(m, 0.3)
		var x0 := r.position.x
		run(m, 1.0)
		speeds.append(r.position.x - x0)
	for load in range(1, 4):
		var ratio := speeds[load] / speeds[0]
		check(absf(ratio - float(Config.CARRY_SPEED[load])) < 0.04, "carrying %d cheese = %d%% speed (%.2f)" % [load, int(float(Config.CARRY_SPEED[load]) * 100.0), ratio])
	check(speeds[1] > speeds[2] and speeds[2] > speeds[3], "every extra cheese slows the carrier further")
	check(is_equal_approx(float(Config.CARRY_SPEED[3]), 0.25), "a full Digger load is the classic 25% crawl")
	end(m)


func test_dig_durability_and_rate() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var dirt := ARENA + Vector3i(1, 0, 0)
	var stone := ARENA + Vector3i(0, 0, 1)
	m.world.set_block(dirt, Blocks.DIRT)
	m.world.set_block(stone, Blocks.STONE)
	check(m.try_dig(r, dirt), "first dirt hit lands")
	check(not m.try_dig(r, dirt), "dig cooldown blocks an immediate second hit")
	check(m.world.get_cell(dirt) == Blocks.DIRT, "dirt survives one hit")
	run(m, 0.4)
	check(m.try_dig(r, dirt) and m.world.get_cell(dirt) == Blocks.AIR, "dirt breaks on the second hit")
	check(int(r.mats["dirt"]) == 1, "dirt goes to the material stash")
	var hits := 0
	for i in 240:
		m.step(DT)
		if m.world.get_cell(stone) == Blocks.STONE and m.try_dig(r, stone):
			hits += 1
	check(hits == 4, "stone takes 4 hits (%d)" % hits)
	# rate: digs per second against an endless target
	var count := 0
	for i in 180:
		m.step(DT)
		m.world.set_block(dirt, Blocks.OBSIDIAN)
		if m.try_dig(r, dirt):
			count += 1
	check(count >= 8 and count <= 10, "about 3 dig actions per second (%d in 3 s)" % count)
	check(not m.try_dig(r, ARENA + Vector3i(0, -30, 0)), "cannot dig beyond reach")
	var base_cell := Vector3i(8, MapGenerator.GROUND - 1, 10)
	r.position = Vector3(8.5, MapGenerator.GROUND, 9.5)
	run(m, 0.4)
	m.try_dig(r, base_cell)
	check(m.world.get_cell(base_cell) == Blocks.BASE_BLUE, "base blocks are indestructible")
	# Digger: ordinary dig is the same as everyone's; Super Dig (ability) is the big one
	var d := arena_rat(m, 0, "digger")
	for dx in range(1, 4):
		for dy in 3:
			for dz in range(-1, 2):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.DIRT)
	var mid := ARENA + Vector3i(2, 1, 0)
	m.world.set_block(mid, Blocks.STONE)
	run(m, 0.4)
	m.try_dig(d, mid)
	check(m.world.damage.size() == 1 and int(m.world.damage[mid]) == 1, "digger's normal dig hits one block for one hit")
	run(m, 0.4)
	var aim := {"cell": mid, "normal": Vector3i(-1, 0, 0)}
	check(m.use_ability(d, 0, aim) == "", "Super Dig fires")
	check(int(m.world.damage[mid]) == 3, "Super Dig hits the aimed block twice as hard")
	var chipped := 0
	for dx in range(1, 4):
		for dy in 3:
			for dz in range(-1, 2):
				if int(m.world.damage.get(ARENA + Vector3i(dx, dy, dz), 0)) == 1:
					chipped += 1
	check(chipped == 26, "and chips the 26 blocks around it (%d)" % chipped)
	check(m.use_ability(d, 0, aim) != "", "Super Dig has a cooldown")
	run(m, 4.1)
	check(m.use_ability(d, 0, aim) == "", "second Super Dig")
	var gone := 0
	for dx in range(1, 4):
		for dy in 3:
			for dz in range(-1, 2):
				if m.world.get_cell(ARENA + Vector3i(dx, dy, dz)) == Blocks.AIR:
					gone += 1
	check(gone == 27, "two Super Digs clear a 3x3x3 with stone at its heart (%d)" % gone)
	check(d.stamina < d.max_stamina(), "Super Dig costs stamina")
	for dx in range(-1, 3):
		for dz in range(-1, 2):
			m.world.set_block(ARENA + Vector3i(dx, -1, dz), Blocks.DIRT)
	m.world.set_block(ARENA + Vector3i(1, 0, 0), Blocks.DIRT)
	for i in 2:
		run(m, 1.1)
		m.use_ability(d, 0, {"cell": ARENA + Vector3i(1, 0, 0), "normal": Vector3i(-1, 0, 0)})
	check(m.world.get_cell(ARENA + Vector3i(0, -1, 0)) == Blocks.DIRT, "Super Dig does not undermine the digger's own footing when digging level")
	check(m.use_ability(d, 0, {"cell": Vector3i(8, MapGenerator.GROUND - 1, 10), "normal": Vector3i(0, 1, 0)}) != "", "Super Dig is refused out of reach / on base blocks")
	end(m)


func test_placement_rules() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var cell := ARENA + Vector3i(2, 0, 0)
	check(m.try_place_mat(r, cell, "dirt") != "", "cannot place without materials")
	r.mats["dirt"] = 2
	check(m.try_place_mat(r, cell, "dirt") == "" and m.world.get_cell(cell) == Blocks.DIRT, "places a dirt block")
	check(int(r.mats["dirt"]) == 1, "placing consumes one material")
	check(m.try_place_mat(r, cell, "dirt") != "", "cannot place into an occupied cell")
	check(m.try_place_mat(r, r.feet_cell(), "dirt") != "", "cannot entomb a rat")
	check(m.try_place_mat(r, ARENA + Vector3i(0, 0, 30), "dirt") != "", "cannot place out of reach")
	r.position = Vector3(14.0, MapGenerator.GROUND, 10.5)
	check(m.try_place_mat(r, Vector3i(11, MapGenerator.GROUND, 10), "dirt") != "", "bases are protected from building")
	check(int(r.mats["dirt"]) == 1, "failed placements cost nothing")
	end(m)


func test_cheese_loop_and_capacity() -> void:
	var m := new_match({"goal": 10})
	flat_arena(m, ARENA)
	var before := total_cheese(m)
	var r := arena_rat(m, 0, "scout")
	for i in 3:
		m.world.set_block(ARENA + Vector3i(1, 0, i - 1), Blocks.CHEESE)
	check(total_cheese(m) == before + 3, "test cheese registered")
	for i in 3:
		var cell := ARENA + Vector3i(1, 0, i - 1)
		var guard := 0
		while m.world.get_cell(cell) == Blocks.CHEESE and guard < 600:
			m.try_dig(r, cell)
			m.step(DT)
			guard += 1
	check(m.pickups.size() + r.carried == 3, "each cheese block becomes exactly one collectible")
	run(m, 1.0)
	for i in 3:
		r.position = Vector3(ARENA) + Vector3(1.5, 0, i - 0.5)
		run(m, 0.2)
	check(r.carried == 2, "scout carries at most 2 cheese (%d)" % r.carried)
	check(m.pickups.size() == 1, "the third cheese stays in the world")
	check(total_cheese(m) == before + 3, "no cheese created or lost")
	r.position = MapGenerator.spawn_point(0)
	run(m, 0.2)
	check(m.scores[0] == 2 and r.carried == 0, "depositing at own base scores (%d)" % m.scores[0])
	# enemy base does not accept deposits
	var e := m.spawn_rat(1, "scout", false)
	e.carried = 1
	e.position = MapGenerator.spawn_point(0)
	run(m, 0.2)
	check(m.scores[1] == 0 and e.carried == 1, "cannot deposit at the enemy base")
	end(m)


func test_bonk_rules() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var a := arena_rat(m, 0, "scout")
	var b := arena_rat(m, 1, "digger", Vector3(1.2, 0, 0))
	var mate := arena_rat(m, 0, "scout", Vector3(-1.2, 0, 0))
	run(m, 0.3)
	b.carried = 3
	mate.carried = 1
	var before := total_cheese(m)
	check(not m.try_bonk(a, mate), "teammates cannot be bonked")
	check(m.try_bonk(a, b), "enemy in range is bonked")
	check(b.carried == 2 and m.pickups.size() == 1, "bonk drops exactly one cheese")
	check(b.vel.length() > 3.0, "bonk knocks the target back")
	check(not m.try_bonk(a, b), "bonk has a cooldown")
	# victim stands on the dropped cheese: locked out for ~2 s
	var p: Match.Pickup = m.pickups[0]
	a.position += Vector3(0, 0, 5)
	mate.position += Vector3(0, 0, -5)
	for i in int(1.7 / DT):
		p.pos = b.center()
		p.vel = Vector3.ZERO
		m.step(DT)
	check(b.carried == 2, "bonked rat cannot grab its cheese back for ~2 s")
	for i in int(0.6 / DT):
		if m.pickups.size() > 0:
			m.pickups[0].pos = b.center()
		m.step(DT)
	check(b.carried == 3, "after the lock the cheese can be recovered")
	check(total_cheese(m) == before, "bonking never duplicates cheese")
	run(m, 1.0)
	a.position = b.position + Vector3(-1.0, 0, 0)
	check(m.try_bonk(a, b), "bonk works again after 2 s")
	b.position = a.position + Vector3(6, 0, 0)
	run(m, 2.1)
	check(not m.try_bonk(a, b), "out-of-range bonk is rejected")
	end(m)


func test_respawn_conserves_cheese() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "digger")
	run(m, 0.2)
	r.carried = 3
	r.mats["stone"] = 7
	var before := total_cheese(m)
	m.respawn(r)
	check(r.carried == 0 and m.in_base(r), "respawn returns the rat to base without cheese")
	check(int(r.mats["stone"]) == 0, "material stash is left behind")
	check(total_cheese(m) == before, "respawn does not duplicate or destroy cheese")
	var stash := 0
	for p in m.pickups:
		if p.kind == "stash":
			stash += int(p.mats["stone"])
	check(stash == 7, "stash pickup holds the dropped materials")
	m.respawn(r)
	run(m, 1.0)
	check(total_cheese(m) == before and m.scores[0] == 0, "repeated respawn creates nothing")
	end(m)


func test_economy_multiplier() -> void:
	var m := new_match({"goal": 8})
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	r.scrap = 0
	check(is_equal_approx(m.multiplier(), 1.0), "multiplier starts at 1.0")
	var cell := ARENA + Vector3i(1, 0, 0)
	m.world.set_block(cell, Blocks.SCRAP)
	var hits := 0
	while m.world.get_cell(cell) == Blocks.SCRAP and hits < 50:
		if m.try_dig(r, cell):
			hits += 1
		m.step(DT)
	check(hits == 5, "scrap takes 5 hits (%d)" % hits)
	check(r.scrap == Config.BASE_SCRAP_PER_BLOCK, "base scrap yield")
	m.scores[0] = 2
	m.scores[1] = 2
	check(is_equal_approx(m.multiplier(), 1.0 + 4.0 / 8.0 * 1.5), "multiplier = 1 + combined/goal x 1.5")
	check(r.scrap == Config.BASE_SCRAP_PER_BLOCK, "existing scrap is not retroactively multiplied")
	m.world.set_block(cell, Blocks.SCRAP)
	while m.world.get_cell(cell) == Blocks.SCRAP:
		m.try_dig(r, cell)
		m.step(DT)
	check(r.scrap == Config.BASE_SCRAP_PER_BLOCK + roundi(Config.BASE_SCRAP_PER_BLOCK * 1.75), "new scrap uses the multiplier (%d)" % r.scrap)
	end(m)


func test_workshop_rules() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	r.scrap = 100
	check(m.try_buy(r, "spring") != "", "non-builders cannot shop away from base")
	check(r.scrap == 100, "refused purchase costs nothing")
	r.position = MapGenerator.spawn_point(0)
	check(m.try_buy(r, "spring") == "" and int(r.gadgets["spring"]) == 1 and r.scrap == 94, "buys a spring at base")
	check(r.equipped == "spring", "first gadget auto-equips to Q")
	r.scrap = 3
	check(m.try_buy(r, "tnt") != "" and r.scrap == 3, "insufficient scrap is rejected")
	r.scrap = 500
	for i in 12:
		m.try_buy(r, "trap")
	check(int(r.gadgets["trap"]) == Config.STACK_MAX, "stack is capped at %d" % Config.STACK_MAX)
	check(m.try_buy(r, "trap") != "", "full stack refuses further purchases")
	check(m.try_buy(r, "nonsense") != "", "unknown items are rejected")
	var b := arena_rat(m, 0, "builder")
	b.scrap = 10
	check(m.try_buy(b, "ladder") == "", "builder shops remotely")
	check(m.try_buy(r, "ice") == "" and int(r.mats["ice"]) == 4, "materials go to the stash")
	end(m)


func test_mouse_trap() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var owner := arena_rat(m, 0, "saboteur")
	var cell := ARENA + Vector3i(2, 0, 0)
	check(m.try_place_gadget(owner, cell, "trap") == "", "saboteur places a trap from the kit")
	check(m.world.get_cell(cell) == Blocks.TRAP_BLUE, "trap block is team-coloured")
	var mate := arena_rat(m, 0, "scout", Vector3(2, 0, 0))
	run(m, 0.3)
	check(mate.stun <= 0.0 and m.world.get_cell(cell) == Blocks.TRAP_BLUE, "friendly rats do not trigger the trap")
	mate.position += Vector3(0, 0, 4)
	var enemy := arena_rat(m, 1, "scout", Vector3(2, 0, 0))
	enemy.carried = 2
	run(m, 0.1)
	check(enemy.stun > 0.5, "enemy is stunned")
	check(enemy.carried == 1 and m.pickups.size() == 1, "trap makes the enemy drop one cheese")
	check(m.world.get_cell(cell) == Blocks.AIR, "trap is consumed")
	run(m, 2.0)
	check(enemy.stun <= 0.0, "stun is brief")
	end(m)


func test_tnt_chain_and_gate() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var s := arena_rat(m, 0, "saboteur")
	s.gadgets["tnt"] = 5
	s.gadgets["gate"] = 1
	var t1 := ARENA + Vector3i(3, 0, 0)
	var t2 := ARENA + Vector3i(5, 0, 0)
	var wall := ARENA + Vector3i(4, 0, 1)
	var obs := ARENA + Vector3i(4, 0, -1)
	var gate := ARENA + Vector3i(5, 0, 1)
	m.world.set_block(wall, Blocks.STONE)
	m.world.damage[wall] = 2
	m.world.set_block(obs, Blocks.OBSIDIAN)
	m.world.set_block(ARENA + Vector3i(4, 1, 0), Blocks.CHEESE)
	check(m.try_place_gadget(s, t1, "tnt") == "" and m.try_place_gadget(s, t2, "tnt") == "", "TNT placed")
	check(m.try_place_gadget(s, gate, "gate") == "", "gate placed")
	var before := total_cheese(m)
	check(m.use_ability(s, 0) == "", "saboteur detonates remotely")
	run(m, 0.35)
	check(m.world.get_cell(t1) == Blocks.AIR, "first charge exploded")
	check(m.world.get_cell(wall) == Blocks.AIR and not m.world.damage.has(wall), "blast removes terrain and its damage state")
	check(m.world.get_cell(obs) == Blocks.OBSIDIAN, "obsidian shrugs off TNT")
	check(m.world.get_cell(gate) == Blocks.GATE_BLUE, "gate survives one blast")
	run(m, 0.4)
	check(m.world.get_cell(t2) == Blocks.AIR, "chain reaction set off the second charge")
	check(m.world.get_cell(gate) == Blocks.AIR, "two blasts destroy a gate")
	check(total_cheese(m) == before, "exploded cheese block becomes a pickup, not dust")
	check(not m.tnt.has(t1) and not m.tnt.has(t2), "no stale TNT records")
	check(m.use_ability(s, 0) != "", "nothing left to detonate")
	# hitting TNT lights a fuse instead of mining it
	var t3 := ARENA + Vector3i(-3, 0, 0)
	run(m, 1.5)
	s.position = Vector3(ARENA) + Vector3(-1.5, 0, 0.5)
	s.vel = Vector3.ZERO
	check(m.try_place_gadget(s, t3, "tnt") == "", "third charge placed")
	run(m, 0.5)
	check(m.try_dig(s, t3) and m.world.get_cell(t3) == Blocks.TNT, "hitting TNT lights it")
	run(m, 2.2)
	check(m.world.get_cell(t3) == Blocks.AIR, "fuse burns down and it explodes")
	check(s.knock > 0.0, "blast knocks nearby rats around (non-lethal)")
	end(m)


func test_ladder_spring_conveyor_gate() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "builder")
	# ladder
	for dy in 4:
		m.world.set_block(ARENA + Vector3i(0, dy, 0), Blocks.LADDER)
	run(m, 0.2)
	check(r.on_ladder, "rat attaches to the ladder")
	r.jump_held = true
	run(m, 0.5)
	r.jump_held = false
	var y := r.position.y
	check(y > ARENA.y + 1.5, "Space climbs (%.2f)" % (y - ARENA.y))
	run(m, 0.5)
	check(absf(r.position.y - y) < 0.01, "rat stays attached when input is released")
	r.down_held = true
	run(m, 0.3)
	r.down_held = false
	check(r.position.y < y - 0.8, "Ctrl descends")
	# spring
	r.position = Vector3(ARENA) + Vector3(3.5, 1.5, 0.5)
	m.world.set_block(ARENA + Vector3i(3, 0, 0), Blocks.SPRING)
	var top := 0.0
	for i in 120:
		m.step(DT)
		top = maxf(top, r.position.y - ARENA.y)
	check(top > 4.0, "spring launches the rat (%.2f blocks)" % top)
	m.world.set_block(ARENA + Vector3i(3, 0, 0), Blocks.AIR)
	# conveyor
	for i in 4:
		m.world.set_block(ARENA + Vector3i(-2 - i, -1, 3), Blocks.CONV_XN)
	r.position = Vector3(ARENA) + Vector3(-1.5, 0, 3.5)
	r.vel = Vector3.ZERO
	run(m, 1.0)
	check(r.position.x < ARENA.x - 3.5, "conveyor carries a standing rat (%.2f)" % (r.position.x - ARENA.x))
	var pk := m.spawn_pickup("stash", Vector3(ARENA) + Vector3(-1.5, 0.3, 3.5), Vector3.ZERO)
	pk.lock_id = r.id
	pk.lock_t = 99.0
	run(m, 1.0)
	check(pk.pos.x < ARENA.x - 3.0, "conveyor carries dropped objects")
	# gates
	r.position = Vector3(ARENA) + Vector3(0.5, 0, -4.5)
	r.vel = Vector3.ZERO
	for dz in range(-8, 9):
		for dy in 3:
			m.world.set_block(ARENA + Vector3i(dz, dy, -6), Blocks.GATE_BLUE)
	var e := arena_rat(m, 1, "scout", Vector3(2, 0, -5))
	r.wish = Vector3(0, 0, -1)
	e.wish = Vector3(0, 0, -1)
	run(m, 0.8)
	check(r.position.z < ARENA.z - 6.0, "own team passes through its gate")
	check(e.position.z > ARENA.z - 5.0 + Rat.RADIUS - 0.01, "enemy is blocked by the gate")
	e.dig_cd = 0.0
	m.try_dig(e, ARENA + Vector3i(2, 0, -6))
	check(m.world.get_cell(ARENA + Vector3i(2, 0, -6)) == Blocks.GATE_BLUE, "enemy cannot dig a gate")
	r.wish = Vector3.ZERO
	r.position = Vector3(ARENA) + Vector3(0.5, 0, -4.5)
	r.dig_cd = 0.0
	m.try_dig(r, ARENA + Vector3i(0, 0, -6))
	check(m.world.get_cell(ARENA + Vector3i(0, 0, -6)) == Blocks.AIR and int(r.gadgets.get("gate", 0)) == 5, "owner team removes and recovers its gate")
	# ice keeps momentum
	end(m)


func test_class_abilities() -> void:
	var m := new_match()
	var digger := m.spawn_rat(0, "digger", false)
	var scout := m.spawn_rat(0, "scout", false)
	var builder := m.spawn_rat(0, "builder", false)
	check(digger.capacity() == 3 and scout.capacity() == 2, "class carry capacities")
	check(is_equal_approx(digger.max_stamina(), 150.0) and is_equal_approx(scout.max_stamina(), 100.0), "class stamina pools")
	check(scout.move_speed() > digger.move_speed(), "scout is faster than digger")
	digger.position = Vector3(30, MapGenerator.GROUND + 4, 24)
	scout.position = digger.position
	check((digger.cls["abilities"] as Array).size() == 1 and digger.cls["abilities"][0][0] == "superdig", "Digger's ability is Super Dig (Burrow Sense is gone)")
	check(m.use_ability(scout, 0) == "" and m.markers.size() == 1, "Sniff marks cheese")
	check(m.use_ability(scout, 0) != "", "ability cooldown enforced")
	check(m.use_ability(scout, 1) == "" and m.markers.size() == 2, "Beacon drops a team marker")
	check(is_equal_approx(float(m.markers[1]["ttl"]), 120.0), "beacon lasts two minutes")
	flat_arena(m, ARENA)
	builder.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	run(m, 0.3)
	var aim := {"cell": ARENA + Vector3i(3, -1, 0), "normal": Vector3i(0, 1, 0)}
	check(m.use_ability(builder, 0, aim) == "", "Patch fires")
	var filled := 0
	for dx in range(2, 5):
		for dz in range(-1, 2):
			if m.world.get_cell(ARENA + Vector3i(dx, 0, dz)) == Blocks.DIRT:
				filled += 1
	check(filled == 9, "Patch fills a 3x3 (%d)" % filled)
	m.world.set_block(ARENA, Blocks.HIGHWAY)    # a highway is a layer on top of the floor
	run(m, 0.1)
	var base_speed := Config.BASE_SPEED * float(builder.cls["speed"])
	check(builder.move_speed() > base_speed * 1.5, "highway boosts speed")
	check(int(builder.gadgets.get("ladder", 0)) == 6 and int(builder.gadgets.get("gate", 0)) == 4, "builder starts with ladders and team gates")
	builder.stamina = 100.0
	builder.stamina = 0.0
	builder.ability_cd = [0.0, 0.0]
	check(m.use_ability(builder, 0, aim) != "", "abilities need stamina")
	end(m)


func test_class_permissions() -> void:
	var m := new_match()
	var r := m.spawn_rat(0, "scout", false)
	check(m.try_change_class(r, "maestro") != "" and r.class_id == "scout", "clients cannot grant themselves Chisel Maestro in a race")
	check(m.try_change_class(r, "builder") == "" and r.class_id == "builder", "class change works at base")
	check(int(r.gadgets.get("ladder", 0)) == 6, "new class grants its kit once")
	r.gadgets["ladder"] = 0
	check(m.try_change_class(r, "scout") != "", "class change has a cooldown")
	r.class_cd = 0.0
	m.try_change_class(r, "scout")
	r.class_cd = 0.0
	m.try_change_class(r, "builder")
	check(int(r.gadgets.get("ladder", 0)) == 0, "kit cannot be farmed by re-picking a class")
	r.class_cd = 0.0
	r.position = Vector3(40, 40, 10)
	check(m.try_change_class(r, "digger") != "", "class change only at base")
	end(m)


func test_win_condition() -> void:
	var m := new_match({"goal": 2})
	var wins: Array[int] = []
	m.won.connect(func(team: int) -> void: wins.append(team))
	var r := m.spawn_rat(1, "digger", false)
	r.carried = 1
	run(m, 0.2)
	check(m.scores[1] == 1 and not m.over, "first deposit does not end the match")
	r.carried = 1
	run(m, 0.2)
	check(m.over and m.winner == 1 and wins == [1], "reaching the goal wins exactly once")
	r.carried = 1
	run(m, 0.2)
	check(m.scores[1] == 2 and wins.size() == 1, "no scoring after the match ends")
	check(not m.try_dig(r, r.feet_cell() + Vector3i(1, 0, 0)), "no digging after the match ends")
	end(m)


func test_save_load() -> void:
	var m := new_match()
	var path := "user://test_maps/roundtrip.bwmap"
	m.world.set_block(Vector3i(40, 40, 10), Blocks.CHEESE)
	check(m.world.save_to(path), "map saves")
	var snapshot := m.world.data.duplicate()
	m.world.set_block(Vector3i(40, 40, 10), Blocks.AIR)
	m.world.set_block(Vector3i(41, 40, 10), Blocks.STONE)
	check(m.world.load_from(path) and m.world.data == snapshot, "map loads back identically")
	check(m.world.cheese_cells.has(Vector3i(40, 40, 10)), "cheese index rebuilt after load")
	var f := FileAccess.open("user://test_maps/garbage.bwmap", FileAccess.WRITE)
	f.store_string("this is not a map")
	f.close()
	check(not m.world.load_from("user://test_maps/garbage.bwmap") and m.world.data == snapshot, "malformed save is rejected without touching the world")
	check(not m.world.load_from("user://test_maps/nope.bwmap"), "missing file is handled")
	end(m)


func test_free_build() -> void:
	var m := new_match({"mode": "free"})
	var r := m.spawn_rat(0, "maestro", false)
	check(r.class_id == "maestro", "Free Build hands out the creative class")
	r.position = Vector3(40, 40, 10)
	check(m.try_place_mat(r, Vector3i(41, 40, 10), "obsidian") == "", "unlimited materials")
	check(m.try_place_gadget(r, Vector3i(42, 40, 10), "tnt") == "", "unlimited gadgets")
	check(m.try_buy(r, "gate") == "", "workshop is free and remote")
	r.flying = true
	r.jump_held = true
	run(m, 0.5)
	check(r.position.y > 43.0, "creative flight")
	r.carried = 1
	r.position = MapGenerator.spawn_point(0)
	run(m, 0.2)
	check(m.scores[0] == 0 and not m.over, "Free Build has no scoring")
	end(m)


func test_vault_raid() -> void:
	var m := new_match({"goal": 10})
	var thief := m.spawn_rat(1, "scout", false)
	var guard := m.spawn_rat(0, "scout", false)
	guard.position = Vector3(30, 40, 10)
	flat_arena(m, ARENA)
	guard.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	var toasts: Array[String] = []
	m.toast.connect(func(text: String, _team: int) -> void: toasts.append(text))
	thief.position = MapGenerator.spawn_point(0)
	run(m, 4.0)
	check(thief.carried == 0 and m.scores[0] == 0, "an empty vault cannot be raided")
	m.scores[0] = 3
	var before := total_cheese(m)
	run(m, 1.0)
	check(thief.raid_t > 0.5 and thief.carried == 0, "raid is a channel, not instant")
	check(toasts.size() == 1 and toasts[0].contains("ALARM"), "everyone is warned once when a raid starts")
	var marked := false
	for mk in m.markers:
		marked = marked or (int(mk["team"]) == 0 and String(mk["text"]) == "RAID!")
	check(marked, "defenders get a marker on their vault")
	run(m, Config.RAID_TIME - 0.9)
	check(thief.carried == 1 and m.scores[0] == 2, "after %.0f s one banked cheese is lifted" % Config.RAID_TIME)
	check(total_cheese(m) == before, "the stolen cheese is moved, not created")
	# a defender at home freezes the raid
	guard.position = MapGenerator.spawn_point(0, 2)
	var t := thief.raid_t
	run(m, 4.0)
	check(thief.carried == 1 and thief.raid_t <= t + 0.05, "a defender standing in the base locks the vault")
	# a bonk interrupts and the thief drops loot inside the base; capacity limits the haul
	guard.position = thief.position + Vector3(0.8, 0, 0)
	check(m.try_bonk(guard, thief), "defender bonks the thief")
	m.step(DT)
	check(thief.carried == 0 and thief.raid_t == 0.0, "bonk interrupts the raid and shakes the cheese loose")
	check(total_cheese(m) == before, "still conserved after the scuffle")
	guard.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	m.pickups.clear()
	m.scores[0] = 3
	before = total_cheese(m)
	thief.position = MapGenerator.spawn_point(0)
	thief.knock = 0.0
	thief.vel = Vector3.ZERO
	run(m, Config.RAID_TIME * 4.0)
	check(thief.carried == thief.capacity() and m.scores[0] == 3 - thief.capacity(), "a thief can only take what it can carry (%d)" % thief.carried)
	check(total_cheese(m) == before, "conserved")
	# the thief still has to get home with it
	thief.position = MapGenerator.spawn_point(1)
	run(m, 0.2)
	check(m.scores[1] == thief.capacity() and thief.carried == 0, "stolen cheese scores when banked at home")
	# own base is never "raided"
	m.scores[1] = 5
	run(m, 4.0)
	check(m.scores[1] == 5 and thief.carried == 0, "standing in your own base does nothing")
	end(m)


func test_digger_power() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var d := arena_rat(m, 0, "digger")
	var cell := ARENA + Vector3i(1, 0, 0)
	for pair: Array in [[Blocks.STONE, 4], [Blocks.SCRAP, 5], [Blocks.OBSIDIAN, 12], [Blocks.CHEESE, 3]]:
		m.world.set_block(cell, int(pair[0]))
		var n := 0
		while m.world.get_cell(cell) == int(pair[0]) and n < 40:
			d.dig_cd = 0.0
			m.try_dig(d, cell)
			n += 1
		check(n == int(pair[1]), "digger's default dig matches everyone else: %s in %d swings (%d)" % [Blocks.block_name(int(pair[0])), int(pair[1]), n])
	end(m)


func test_water_exit() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	# a pond flush with the ground, like the generated ones: 3 deep, 5 wide
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var inside := absi(dx) <= 2 and absi(dz) <= 2
			for dy in range(-3, 0):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.WATER if inside else Blocks.STONE)
			m.world.set_block(ARENA + Vector3i(dx, -4, dz), Blocks.STONE)
	for cls: String in ["scout", "digger"]:
		var r := arena_rat(m, 0, cls, Vector3(0, -2.5, 0))
		run(m, 0.5)
		check(r.in_water, "%s is swimming" % cls)
		r.jump_held = true
		r.wish = Vector3(1, 0, 0)
		var guard := 0
		while r.position.x < ARENA.x + 4.0 and guard < 400:
			m.step(DT)
			guard += 1
		r.jump_held = false
		r.wish = Vector3.ZERO
		run(m, 0.6)
		check(r.position.x > ARENA.x + 3.0 and r.position.y > ARENA.y - 0.05 and r.on_floor, "%s holds Space and climbs out onto the bank (x=%.1f y=%.2f)" % [cls, r.position.x - ARENA.x, r.position.y - ARENA.y])
		# a single tap at the surface also works
		r.position = Vector3(ARENA) + Vector3(0.5, -1.0, 0.5)
		r.vel = Vector3.ZERO
		run(m, 0.3)
		r.jump_held = true
		var top := -9.0
		for i in 90:
			m.step(DT)
			top = maxf(top, r.position.y - ARENA.y)
		r.jump_held = false
		check(top > 0.4, "%s leaps clear of the surface (feet %.2f above the bank)" % [cls, top])
		r.position = Vector3(ARENA) + Vector3(6.5, 0, 6.5 if cls == "scout" else 5.0)
	end(m)


func test_lava_flows() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	for i in 60:
		m.step(0.5)     # let generated pools settle before counting
	# a walled tank of lava two blocks above the floor
	var tank := ARENA + Vector3i(0, 2, 0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			m.world.set_block(tank + Vector3i(dx, -1, dz), Blocks.STONE)
			if dx != 0 or dz != 0:
				m.world.set_block(tank + Vector3i(dx, 0, dz), Blocks.STONE)
	m.world.set_block(tank, Blocks.LAVA)
	run(m, 3.0)
	var count := func() -> int:
		var n := 0
		for dx in range(-8, 9):
			for dz in range(-8, 9):
				for dy in range(0, 4):
					if m.world.get_cell(ARENA + Vector3i(dx, dy, dz)) == Blocks.LAVA:
						n += 1
		return n
	check(count.call() == 1, "contained lava stays put")
	m.world.set_block(tank + Vector3i(1, 0, 0), Blocks.AIR)    # break the tank wall
	run(m, 1.2)
	check(m.world.get_cell(tank + Vector3i(1, 0, 0)) == Blocks.LAVA, "lava flows into the gap")
	run(m, 6.0)
	check(m.world.get_cell(ARENA + Vector3i(2, 0, 0)) == Blocks.LAVA, "then pours down over the edge")
	check(m.world.get_cell(ARENA + Vector3i(4, 0, 0)) == Blocks.LAVA, "and spreads across the floor")
	var n1: int = count.call()
	run(m, 10.0)
	check(count.call() == n1 and n1 < 60, "the flow comes to rest instead of flooding forever (%d blocks)" % n1)
	check(m.world.get_cell(ARENA + Vector3i(8, 0, 0)) != Blocks.LAVA, "spread is limited to a few blocks from where it lands")
	# plugging and hazards
	var r := arena_rat(m, 0, "scout", Vector3(-6, 0, 0))
	r.mats["dirt"] = 5
	r.position = Vector3(ARENA) + Vector3(5.5, 0, 3.5)
	run(m, 0.2)
	var lava_cell := Vector3i.ZERO
	for dz in range(0, 4):
		if m.world.get_cell(ARENA + Vector3i(4, 0, dz)) == Blocks.LAVA:
			lava_cell = ARENA + Vector3i(4, 0, dz)
	check(m.try_place_mat(r, lava_cell, "dirt") == "", "lava can be plugged with a block")
	r.carried = 1
	r.position = Vector3(ARENA) + Vector3(3.5, 0.2, 0.5)
	m.step(DT)
	check(r.vel.y > 5.0 and r.carried == 1 and not m.in_base(r) and r.lava_strikes == 1, "the first touch of lava bounces you out, cheese and all")
	var safe := Vector3(ARENA) + Vector3(-5.5, 0, -5.5)
	run(m, 0.3)
	r.position = Vector3(ARENA) + Vector3(3.5, 0.2, 0.5)
	m.step(DT)
	check(r.carried == 1 and not m.in_base(r), "no second strike while you are still bouncing out")
	r.position = safe
	r.vel = Vector3.ZERO
	run(m, 1.0)
	var cheese_before := m.pickups.size()
	r.position = Vector3(ARENA) + Vector3(3.5, 0.2, 0.5)
	m.step(DT)
	check(r.vel.y > 5.0 and r.carried == 0 and m.pickups.size() >= cheese_before + 1, "a second touch bounces you and spills your cheese right there")
	check(not m.in_base(r), "... and only then")
	run(m, 1.0)
	check(m.in_base(r) and r.lava_strikes == 0, "you are sent home (nobody dies)")
	# generated pools exist on both halves
	var per_half := [0, 0]
	var fresh := new_match()
	for i in fresh.world.data.size():
		if fresh.world.data[i] == Blocks.LAVA and i / (VoxelWorld.SX * VoxelWorld.SZ) >= 5:
			per_half[0 if i % VoxelWorld.SX < VoxelWorld.SX / 2 else 1] += 1
	check(per_half[0] > 20 and per_half[0] == per_half[1], "underground lava pools are generated and mirrored (%d per side)" % per_half[0])
	end(fresh)
	end(m)


func test_water_flows() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 9)
	for i in 60:
		m.step(0.5)
	var tank := ARENA + Vector3i(0, 2, 0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			m.world.set_block(tank + Vector3i(dx, -1, dz), Blocks.STONE)
			if dx != 0 or dz != 0:
				m.world.set_block(tank + Vector3i(dx, 0, dz), Blocks.STONE)
	m.world.set_block(tank, Blocks.WATER)
	run(m, 2.0)
	var count := func() -> int:
		var n := 0
		for dx in range(-9, 10):
			for dz in range(-9, 10):
				for dy in range(0, 4):
					if m.world.get_cell(ARENA + Vector3i(dx, dy, dz)) == Blocks.WATER:
						n += 1
		return n
	check(count.call() == 1, "contained water stays put")
	m.world.set_block(tank + Vector3i(1, 0, 0), Blocks.AIR)
	run(m, 0.6)
	check(m.world.get_cell(tank + Vector3i(1, 0, 0)) == Blocks.WATER, "water flows into the gap")
	run(m, 5.0)
	check(m.world.get_cell(ARENA + Vector3i(2, 0, 0)) == Blocks.WATER, "then pours down over the edge")
	check(m.world.get_cell(ARENA + Vector3i(6, 0, 0)) == Blocks.WATER, "water runs further than lava (reach %d vs %d)" % [LiquidFlow.WATER_REACH, LiquidFlow.LAVA_REACH])
	var n1: int = count.call()
	run(m, 8.0)
	check(count.call() == n1 and n1 < 140, "the flood comes to rest (%d blocks)" % n1)
	check(m.world.get_cell(ARENA + Vector3i(9, 0, 0)) != Blocks.WATER, "spread is limited")
	# a rat can wade through it and plug it like any liquid
	var r := arena_rat(m, 0, "scout", Vector3(4, 0, 0))
	r.mats["dirt"] = 5
	run(m, 0.3)
	check(r.in_water or m.world.block_at(r.position + Vector3(0, 0.1, 0)) == Blocks.WATER, "flowed water is real water to a rat")
	check(m.try_place_mat(r, ARENA + Vector3i(5, 0, 1), "dirt") == "" or m.world.get_cell(ARENA + Vector3i(5, 0, 1)) != Blocks.WATER, "water can be plugged with a block")
	end(m)
	# lava meets water -> stone, from either side
	var q := new_match()
	flat_arena(q, ARENA, 6)
	for i in 60:
		q.step(0.5)
	var lava_cell := ARENA + Vector3i(-4, 0, -4)
	q.world.set_block(lava_cell, Blocks.LAVA)
	run(q, 3.0)
	var lava_n := 0
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			if q.world.get_cell(ARENA + Vector3i(dx, 0, dz)) == Blocks.LAVA:
				lava_n += 1
	q.world.set_block(ARENA + Vector3i(-1, 2, -1), Blocks.WATER)    # a waterfall beside the lava
	run(q, 6.0)
	var lava_left := 0
	var stone := 0
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			var id := q.world.get_cell(ARENA + Vector3i(dx, 0, dz))
			if id == Blocks.LAVA:
				lava_left += 1
			elif id == Blocks.STONE:
				stone += 1
	check(lava_n > 1, "the lava spread first (%d cells)" % lava_n)
	check(stone > 0 and lava_left < lava_n, "where water meets lava it hardens to stone (%d stone, lava %d -> %d)" % [stone, lava_n, lava_left])
	end(q)


func test_ladder_stack_and_floor_gadgets() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "builder")
	run(m, 0.2)
	r.equipped = "ladder"
	var base := ARENA + Vector3i(2, 0, 0)
	var look := Vector3(1, 0, 0)
	check(m.try_use_equipped(r, {"cell": base + Vector3i(0, -1, 0), "normal": Vector3i(0, 1, 0)}, look, false) == "", "first ladder placed on the floor")
	# aim at the top half -> goes on top of the stack, wherever its top is
	for i in 3:
		check(m.try_use_equipped(r, {"cell": base, "normal": Vector3i(-1, 0, 0), "point": Vector3(base) + Vector3(0, 0.8, 0.5)}, look, false) == "", "extend upward")
	var h := 0
	while m.world.get_cell(base + Vector3i(0, h, 0)) == Blocks.LADDER:
		h += 1
	check(h == 4, "aiming at the top half stacks ladders upward (%d tall)" % h)
	check(int(r.gadgets["ladder"]) == 2, "each one is paid for")
	# a shaft below: aim at the bottom half -> goes under the stack
	for dy in range(-3, 0):
		m.world.set_block(base + Vector3i(0, dy, 0), Blocks.AIR)
	check(m.try_use_equipped(r, {"cell": base, "normal": Vector3i(-1, 0, 0), "point": Vector3(base) + Vector3(0, 0.2, 0.5)}, look, false) == "", "extend downward")
	check(m.world.get_cell(base + Vector3i(0, -1, 0)) == Blocks.LADDER and m.world.get_cell(base + Vector3i(0, 4, 0)) == Blocks.AIR, "aiming at the bottom half adds below the stack")
	m.world.set_block(base + Vector3i(0, 4, 0), Blocks.STONE)
	check(m.try_use_equipped(r, {"cell": base, "normal": Vector3i(-1, 0, 0), "point": Vector3(base) + Vector3(0, 0.9, 0.5)}, look, false) != "" and int(r.gadgets["ladder"]) == 1, "a blocked stack refuses and costs nothing")
	# conveyors and highways are laid INTO the aimed floor block
	r.gadgets["conveyor"] = 3
	r.gadgets["highway"] = 2
	r.equipped = "conveyor"
	var floor_cell := ARENA + Vector3i(0, -1, 2)
	var stone_before := int(r.mats["stone"])
	var aim := {"cell": floor_cell, "normal": Vector3i(0, 1, 0)}
	check(m.try_use_equipped(r, aim, look, false, Vector3(0, 0, -1)) == "", "conveyor placed")
	check(m.world.get_cell(floor_cell) == Blocks.CONV_ZN and m.world.get_cell(floor_cell + Vector3i(0, 1, 0)) == Blocks.AIR, "it replaces the floor block, flush with the ground")
	check(int(r.mats["stone"]) == stone_before + 1, "the swapped-out stone goes to the stash")
	for pair: Array in [[Vector3(1, 0, 0), Blocks.CONV_XP], [Vector3(-1, 0, 0), Blocks.CONV_XN], [Vector3(0, 0, 1), Blocks.CONV_ZP]]:
		r.gadgets["conveyor"] = 3
		var c2 := floor_cell + Vector3i(2, 0, 0)
		m.world.set_block(c2, Blocks.STONE)
		m.try_use_equipped(r, {"cell": c2, "normal": Vector3i(0, 1, 0)}, look, false, pair[0])
		check(m.world.get_cell(c2) == int(pair[1]), "conveyor runs toward the chosen edge %s" % str(pair[0]))
	r.yaw = PI   # facing +Z
	m.world.set_block(floor_cell + Vector3i(2, 0, 0), Blocks.STONE)
	m.try_use_equipped(r, {"cell": floor_cell + Vector3i(2, 0, 0), "normal": Vector3i(0, 1, 0)}, look, false)
	check(m.world.get_cell(floor_cell + Vector3i(2, 0, 0)) == Blocks.CONV_ZP, "with no edge given it falls back to the rat's facing")
	r.equipped = "highway"
	check(m.try_use_equipped(r, {"cell": ARENA + Vector3i(-1, -1, 0), "normal": Vector3i(0, 1, 0)}, look, false) == "", "highway placed")
	check(m.world.get_cell(ARENA + Vector3i(-1, 0, 0)) == Blocks.HIGHWAY and m.world.get_cell(ARENA + Vector3i(-1, -1, 0)) == Blocks.STONE, "a highway lies on top of the block's face; the block itself stays")
	# aimed at a wall face it still goes in the free cell next to it
	m.world.set_block(ARENA + Vector3i(3, 0, 3), Blocks.STONE)
	check(m.try_use_equipped(r, {"cell": ARENA + Vector3i(3, 0, 3), "normal": Vector3i(-1, 0, 0)}, look, false) == "" and m.world.get_cell(ARENA + Vector3i(2, 0, 3)) == Blocks.HIGHWAY, "on a side face the gadget goes beside the block")
	r.gadgets["highway"] = 1
	check(m.try_use_equipped(r, {"cell": Vector3i(8, MapGenerator.GROUND - 1, 10), "normal": Vector3i(0, 1, 0)}, look, false) != "" and int(r.gadgets["highway"]) == 1, "base floor cannot be converted")
	end(m)


func test_team_block_and_builder() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var b := arena_rat(m, 0, "builder")
	var foe := arena_rat(m, 1, "scout", Vector3(4, 0, 0))
	run(m, 0.2)
	# a bridge of team blocks over a gap
	for dx in range(1, 4):
		for dy in range(-3, 0):
			m.world.set_block(ARENA + Vector3i(dx, dy, 0), Blocks.AIR)
		m.world.set_block(ARENA + Vector3i(dx, -4, 0), Blocks.STONE)
	var placed := 0
	check(int(b.gadgets.get("teamblock", 0)) == 6, "Builders start with 6 team blocks")
	b.equipped = "teamblock"
	for dx in range(1, 4):
		if m.try_use_equipped(b, {"cell": ARENA + Vector3i(dx - 1, -1, 0), "normal": Vector3i(1, 0, 0)}, Vector3(1, 0, 0), false) == "":
			placed += 1
	check(placed == 3 and m.world.get_cell(ARENA + Vector3i(2, -1, 0)) == Blocks.TEAM_BLUE, "Team Blocks are placed from the Q slot")
	check(int(b.gadgets["teamblock"]) == 3, "each one uses a team block")
	b.wish = Vector3(1, 0, 0)
	run(m, 0.45)
	b.wish = Vector3.ZERO
	run(m, 0.3)
	check(b.position.y > ARENA.y - 0.05 and b.position.x > ARENA.x + 1.2, "the owning team walks across")
	foe.position = Vector3(ARENA) + Vector3(2.5, 0.3, 0.5)
	foe.vel = Vector3.ZERO
	run(m, 0.8)
	check(foe.position.y < ARENA.y - 1.5, "the other team falls straight through")
	foe.dig_cd = 0.0
	check(not m.try_dig(foe, ARENA + Vector3i(2, -1, 0)) and m.world.get_cell(ARENA + Vector3i(2, -1, 0)) == Blocks.TEAM_BLUE, "enemies cannot dig it")
	foe.mats["dirt"] = 3
	b.dig_cd = 0.0
	check(m.try_dig(b, ARENA + Vector3i(3, -1, 0)) and m.world.get_cell(ARENA + Vector3i(3, -1, 0)) == Blocks.AIR, "its own team removes it in one hit")
	check(int(b.gadgets["teamblock"]) == 4, "and gets the team block back")
	var pk := m.spawn_pickup("stash", Vector3(ARENA) + Vector3(2.5, 0.6, 0.5), Vector3.ZERO)
	pk.lock_id = b.id
	pk.lock_t = 99.0
	pk.mats = {"dirt": 1}
	run(m, 1.0)
	check(pk.pos.y < ARENA.y - 1.0, "loose objects drop through it as well")
	b.equipped = "teamblock"
	check(m.try_use_equipped(b, {"cell": b.feet_cell() + Vector3i(0, -1, 0), "normal": Vector3i(0, 1, 0)}, Vector3(1, 0, 0), false) != "", "cannot be placed inside a teammate")
	var s := arena_rat(m, 0, "scout", Vector3(-3, 0, -3))
	s.position = MapGenerator.spawn_point(0)
	s.scrap = 10
	check(m.try_buy(s, "teamblock") == "" and int(s.gadgets["teamblock"]) == 4 and s.scrap == 6, "any class can buy team blocks in the workshop (4 for 4 scrap)")
	# gates cost scrap; Builders pay less than anyone else
	b.scrap = 10
	check(int(b.gadgets["gate"]) == 4, "Builder starts with team gates")
	var gate_cost := int(ClassDefs.shop_item("gate")["cost"])
	var builder_cost := ClassDefs.price(b.cls, "gate", false)
	check(builder_cost > 0 and builder_cost < gate_cost, "Builders pay for gates, but less (%d vs %d scrap)" % [builder_cost, gate_cost])
	check(m.try_buy(b, "gate") == "" and b.scrap == 10 - builder_cost and int(b.gadgets["gate"]) == 5, "a Builder's gate costs %d scrap" % builder_cost)
	foe.position = MapGenerator.spawn_point(1)
	foe.scrap = gate_cost - 1
	check(m.try_buy(foe, "gate") != "" and foe.scrap == gate_cost - 1, "other classes pay the full %d" % gate_cost)
	foe.scrap = gate_cost
	check(m.try_buy(foe, "gate") == "" and foe.scrap == 0, "and can buy one with it")
	check((b.cls["abilities"] as Array).size() == 1 and b.cls["abilities"][0][0] == "patch", "Builder keeps Patch; Team Block moved to the Q slot (no F ability)")
	end(m)


func test_ice_slides_off_the_end() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 10)
	for dx in range(-6, 1):
		m.world.set_block(ARENA + Vector3i(dx, -1, 0), Blocks.ICE)
	var r := arena_rat(m, 0, "scout", Vector3(-6, 0, 0))
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	while r.position.x < ARENA.x - 0.2:
		m.step(DT)
	r.wish = Vector3.ZERO      # let go just before the last ice block
	var v0 := Vector2(r.vel.x, r.vel.z).length()
	run(m, 0.5)
	check(r.position.x > ARENA.x + 1.6, "a rat slides off the end of the ice instead of stopping at it (%.2f past)" % (r.position.x - ARENA.x - 1.0))
	run(m, 1.5)
	check(Vector2(r.vel.x, r.vel.z).length() < 0.2 and v0 > 3.0, "and comes to rest on normal ground")
	# the same run on stone stops almost at once
	r.position = Vector3(ARENA) + Vector3(-6.5, 0, 4.5)
	r.vel = Vector3.ZERO
	run(m, 0.6)
	r.wish = Vector3(1, 0, 0)
	run(m, 0.8)
	r.wish = Vector3.ZERO
	var x := r.position.x
	run(m, 0.5)
	check(r.position.x - x < 0.5, "ordinary ground still stops you promptly")
	# loose objects
	var pk := m.spawn_pickup("stash", Vector3(ARENA) + Vector3(-5.5, 0.2, 0.5), Vector3(5.0, 0, 0))
	pk.lock_id = r.id
	pk.lock_t = 99.0
	pk.mats = {"dirt": 1}
	run(m, 2.5)
	check(pk.pos.x > ARENA.x + 1.0, "a sliding object leaves the end of the ice (x=%.1f)" % (pk.pos.x - ARENA.x))
	end(m)


func test_painted_blocks() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var cell := ARENA + Vector3i(2, 0, 0)
	r.mats["dirt"] = 0
	check(m.try_place_paint(r, cell, 3) != "", "painted blocks need dirt or stone")
	r.mats["stone"] = 3
	check(m.try_place_paint(r, cell, 3) == "" and m.world.get_cell(cell) == Blocks.PAINT_0 + 3, "places a full block in the chosen colour")
	check(int(r.mats["stone"]) == 2, "with no dirt it costs one stone")
	r.mats["dirt"] = 2
	var pane := cell + Vector3i(0, 0, 2)
	check(m.try_place_paint(r, pane, Blocks.PALETTE_SOLID) == "" and int(r.mats["dirt"]) == 1 and int(r.mats["stone"]) == 2, "dirt is used first")
	check(Blocks.is_glass(m.world.get_cell(pane)) and Blocks.OPAQUE[m.world.get_cell(pane)] == 0 and r.blocked_at(Vector3(pane) + Vector3(0.5, 0, 0.5)), "glass is see-through but solid")
	check(m.try_place_paint(r, cell + Vector3i(0, 1, 0), Blocks.PALETTE_SIZE) != "" and m.try_place_paint(r, cell + Vector3i(0, 1, 0), -1) != "", "colours outside the palette are refused")
	var distinct := {}
	for k in Blocks.PALETTE_SIZE:
		distinct[Blocks.paint_color(k).to_html()] = true
	check(distinct.size() == Blocks.PALETTE_SIZE and Blocks.PALETTE_SIZE >= 36, "%d distinct palette colours" % distinct.size())
	check(Blocks.PALETTE_NAMES.has("Grey") and Blocks.PALETTE_NAMES.has("Light Grey") and Blocks.PALETTE_NAMES.has("Clear Glass"), "greys and clear glass are on the palette")
	check(r.blocked_at(Vector3(cell) + Vector3(0.5, 0, 0.5)), "painted blocks are solid")
	var n := 0
	while m.world.get_cell(cell) != Blocks.AIR and n < 20:
		r.dig_cd = 0.0
		m.try_dig(r, cell)
		n += 1
	check(n == 2 and int(r.mats["dirt"]) == 2 and int(r.mats["stone"]) == 2, "digging one takes 2 hits, like dirt, and gives a dirt back")
	r.chisel_cd = 0.0
	check(m.try_chisel_add(r, cell, Vector3i(0, 0, 0), "stone", Blocks.PALETTE_SOLID + 2) != "" and m.world.get_cell(cell) == Blocks.AIR, "glass is whole blocks only (no glass microvoxels)")
	# chisel: a painted microvoxel on a block of another material
	var stone := ARENA + Vector3i(2, 0, 2)
	m.world.set_block(stone, Blocks.STONE)
	r.position = Vector3(ARENA) + Vector3(1.5, 0, 1.5)
	r.chisel_cd = 0.0
	check(m.try_chisel_remove(r, stone, Vector3i(0, 6, 0)) == "", "carve a corner")
	r.chisel_cd = 0.0
	check(m.try_chisel_add(r, stone, Vector3i(0, 6, 0), "stone", 7) == "", "refill it in blue")
	var mask: PackedByteArray = m.world.micro[stone]
	check(mask[0 + 7 * (0 + 7 * 6)] == 2 + 7 and m.world.micro_count(stone) == 343, "the microvoxel remembers its colour; the block stays carved-with-colour")
	check(m.world.get_cell(stone) == Blocks.STONE, "the parent block is still stone")
	check(r.blocked_at(Vector3(stone) + Vector3(0.5, 0, 0.5)), "coloured microvoxels collide like any other")
	# chisel into empty air creates a painted block
	var air := ARENA + Vector3i(2, 0, -2)
	r.position = Vector3(ARENA) + Vector3(1.5, 0, -1.5)
	r.chisel_cd = 0.0
	check(m.try_chisel_add(r, air, Vector3i(0, 0, 0), "stone", 1) == "" and m.world.get_cell(air) == Blocks.PAINT_0 + 1 and m.world.micro_count(air) == 1, "chiselling colour into thin air starts a painted block")
	# colours survive save/load and the pantograph
	check(m.world.save_to("user://test_maps/paint.bwmap"), "save")
	m.world.set_block(stone, Blocks.AIR)
	check(m.world.load_from("user://test_maps/paint.bwmap") and (m.world.micro[stone] as PackedByteArray)[0 + 7 * (0 + 7 * 6)] == 9, "painted microvoxels persist through save and load")
	r.position = Vector3(ARENA) + Vector3(1.5, 0, 1.5)
	var res := m.copy_region(r, stone, stone)
	check(res.has("blueprint"), "pantograph copies the painted block")
	if res.has("blueprint"):
		r.mats["stone"] = 5
		var dest := ARENA + Vector3i(0, 0, 3)
		check(m.try_paste(r, res["blueprint"], dest) == "" and (m.world.micro[dest] as PackedByteArray)[0 + 7 * (0 + 7 * 6)] == 9, "and pastes it with its colours")
	end(m)


func test_review_fixes() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 6)
	# a remote player standing on an enemy sticky trap: slowed, but the server
	# has nothing to correct, so no kick storm
	var r := arena_rat(m, 0, "scout")
	run(m, 0.3)
	m.world.set_block(r.feet_cell(), Blocks.STICKY_RED)
	r.net_peer = 7
	r.net_pre = Match.net_state(r)
	var diffs := 0
	for i in 30:
		m.step(DT)
		if Match.net_state(r) != r.net_pre:
			diffs += 1
	check(r.slow > 0.0, "an enemy sticky trap still slows a remote player")
	check(diffs == 0, "and the server sees nothing to correct (%d corrections in 30 ticks)" % diffs)
	r.net_peer = 0
	# a spring landing reported by a remote player is played for everyone
	var ns := NetServer.new()
	ns.m = m
	ns.seats[7] = r
	r.net_peer = 7
	var springs := [0]
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void:
		if kind == "spring":
			springs[0] += 1)
	var pkt := {"k": r.net_kick, "p": r.position, "v": Vector3.ZERO, "y": 0.0, "f": 1, "s": r.stamina, "fx": ["spring", "bogus"]}
	ns.on_input(7, pkt)
	ns.on_input(7, pkt)   # a spammed claim right after is ignored
	check(springs[0] == 1, "a remote player's spring bounce plays once for everyone (%d)" % springs[0])
	ns.free()
	r.net_peer = 0
	# a forged blueprint without a mask key is refused, not crashed on
	var forged := Blueprint.new()
	forged.size = Vector3i.ONE
	forged.cells.append({"o": Vector3i.ZERO, "id": Blocks.STONE})
	check(forged.validate() != "" and m.try_paste(r, forged, ARENA + Vector3i(3, 0, 3)) != "", "a blueprint entry without a mask is malformed")
	# paint dabs come back as dirt, so carve + dab + break cannot mint stone
	var b := ARENA + Vector3i(2, 0, 2)
	m.world.set_block(b, Blocks.STONE)
	r.position = Vector3(ARENA) + Vector3(1.5, 0, 1.5)
	r.mats["dirt"] = 2
	r.mats["stone"] = 0
	r.micro_bank.clear()
	r.chisel_cd = 0.0
	m.try_chisel_remove(r, b, Vector3i(0, 6, 0))
	r.chisel_cd = 0.0
	check(m.try_chisel_add(r, b, Vector3i(0, 6, 0), "stone", 3) == "", "dab of paint into the carved spot")
	var before := int(r.mats["stone"]) * 343 + int(r.micro_bank.get("stone", 0)) + int(r.mats["dirt"]) * 343 + int(r.micro_bank.get("dirt", 0))   # 1 + 685
	for i in 6:
		r.dig_cd = 0.0
		m.try_dig(r, b)
	var stone_after := int(r.mats["stone"]) * 343 + int(r.micro_bank.get("stone", 0))
	var dirt_after := int(r.mats["dirt"]) * 343 + int(r.micro_bank.get("dirt", 0))
	check(m.world.get_cell(b) == Blocks.AIR and stone_after == 343, "breaking it refunds the stone part as stone (%d)" % stone_after)
	# start: 2 dirt blocks (686 micro). Carve (+1 stone), dab (-1 dirt), break: 342 stone + 1 dirt back.
	check(dirt_after == 686 and stone_after + dirt_after == before + 343, "and the dab as dirt: nothing minted (%d dirt, %d stone)" % [dirt_after, stone_after])
	end(m)
	# an online player's replica does not build a map of its own
	var rep := Match.new()
	rep.auto_step = false
	add_child(rep)
	rep.setup({"mode": "race", "seed": 4242, "goal": 3}, false, true)
	check(rep.world.data.count(Blocks.AIR) == rep.world.data.size(), "a replica waits for the server's world instead of generating one")
	end(rep)


func test_bot_sees_cheese() -> void:
	## A bot next to a cheese block behind a wall digs the wall first; it no
	## longer mines cheese straight through solid stone.
	var m := new_match()
	flat_arena(m, ARENA, 6)
	var cheese := ARENA + Vector3i(2, 0, 0)
	var wall := ARENA + Vector3i(1, 0, 0)
	m.world.set_block(cheese, Blocks.CHEESE)
	m.world.set_block(wall, Blocks.STONE)
	m.world.set_block(wall + Vector3i(0, 1, 0), Blocks.STONE)
	var bot := m.spawn_rat(0, "digger", true)
	bot.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	var wall_when_mined := -1
	for i in int(12.0 / DT):
		m.step(DT)
		if m.world.get_cell(cheese) != Blocks.CHEESE:
			wall_when_mined = m.world.get_cell(wall)
			break
	check(wall_when_mined != -1, "the bot gets the cheese")
	check(wall_when_mined != Blocks.STONE, "but only after digging through the wall in front of it")
	end(m)


func test_spring_sides_and_cheese() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 1, "scout", Vector3(-6, 0, -6))
	run(m, 0.3)
	var spring := ARENA + Vector3i(0, 0, 0)
	m.world.set_block(spring, Blocks.SPRING)
	# a rat standing right beside the spring is flung up and away
	r.position = Vector3(spring) + Vector3(1.5, 0, 0.5)
	r.vel = Vector3.ZERO
	r.on_floor = true
	m.step(DT)
	check(r.vel.y > 8.0 and r.vel.x > 2.0, "a rat next to a spring's side is bounced up and away (vel %s)" % str(r.vel))
	var diag := arena_rat(m, 0, "digger", Vector3(-6, 0, 6))
	run(m, 0.3)
	diag.position = Vector3(spring) + Vector3(-0.5, 0, -0.5)    # the diagonal neighbour cell
	diag.vel = Vector3.ZERO
	m.step(DT)
	check(diag.vel.y > 8.0, "any team, any side (diagonal too)")
	var far := arena_rat(m, 0, "scout", Vector3(-6, 0, 2))
	run(m, 0.3)
	far.position = Vector3(spring) + Vector3(2.6, 0, 0.5)     # two cells away
	far.vel = Vector3.ZERO
	m.step(DT)
	check(far.vel.y < 1.0, "two blocks away is safe")
	# loose cheese next to a spring is flung too
	var pk := m.spawn_pickup("cheese", Vector3(spring) + Vector3(0.5, 0.15, 1.5), Vector3.ZERO)
	var top := 0.0
	for i in 40:
		m.step(DT)
		top = maxf(top, pk.pos.y)
	check(top > float(spring.y) + 2.0, "loose cheese beside a spring is flung up (peak %.1f)" % (top - spring.y))
	# conveyors carry loose cheese
	var belt := ARENA + Vector3i(-4, -1, 4)
	m.world.set_block(belt, Blocks.CONV_XP)
	m.world.set_block(belt + Vector3i(1, 0, 0), Blocks.CONV_XP)
	var ride := m.spawn_pickup("cheese", Vector3(belt) + Vector3(0.3, 1.2, 0.5), Vector3.ZERO)
	run(m, 0.8)
	check(ride.pos.x > float(belt.x) + 1.0, "a conveyor carries loose cheese along (moved %.2f)" % (ride.pos.x - belt.x - 0.3))
	end(m)


func test_trap_durability() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 6)
	var blue := arena_rat(m, 0, "saboteur")
	var red := arena_rat(m, 1, "digger", Vector3(0, 0, 2))
	run(m, 0.3)
	var digs := func(r: Rat, cell: Vector3i) -> int:
		var n := 0
		while m.world.get_cell(cell) != Blocks.AIR and n < 40:
			r.dig_cd = 0.0
			m.try_dig(r, cell)
			n += 1
		return n
	for kind: String in ["trap", "sticky", "pitfall", "wallspring"]:
		blue.gadgets[kind] = 3
		var own := ARENA + Vector3i(2, 0, -1)
		var theirs := ARENA + Vector3i(2, 0, 1)
		check(m.try_place_gadget(blue, own, kind) == "" and m.try_place_gadget(blue, theirs, kind) == "", "placed two %s" % kind)
		var n_own: int = digs.call(blue, own)
		var n_enemy: int = digs.call(red, theirs)
		check(n_own == Config.TRAP_HITS_OWN and n_enemy == Config.TRAP_HITS_ENEMY, "%s: %d digs for its own team, %d for the enemy" % [kind, n_own, n_enemy])
	blue.gadgets["trap"] = 1
	var t := ARENA + Vector3i(-2, 0, 0)
	m.try_place_gadget(blue, t, "trap")
	m.blast(Vector3(t) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(m.world.get_cell(t) == Blocks.TRAP_BLUE, "a single blast does not clear a placed trap")
	end(m)


func test_team_stash() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var a := arena_rat(m, 0, "builder")
	var b := arena_rat(m, 0, "scout", Vector3(0, 0, 3))
	var foe := arena_rat(m, 1, "scout", Vector3(4, 0, 0))
	run(m, 0.3)
	check(not m.can_use_stash(a) and m.stash_move(a, "dirt", 5) != "", "away from base, with no stash, there is no pool to use")
	a.gadgets["stash"] = 1
	var st := ARENA + Vector3i(1, 0, 1)
	check(m.try_place_gadget(a, st, "stash") == "" and m.world.get_cell(st) == Blocks.STASH_BLUE, "a team stash is placed")
	a.scrap = 20
	a.mats["stone"] = 7
	check(m.can_use_stash(a) and m.stash_move(a, "scrap", 15) == "" and m.stash_move(a, "stone", 9999) == "", "deposit scrap and all the stone")
	check(a.scrap == 5 and int(a.mats["stone"]) == 0 and int(m.team_bank[0]["scrap"]) == 15 and int(m.team_bank[0]["stone"]) == 7, "the pool holds it")
	check(m.stash_move(a, "cheese", 1) != "", "cheese never goes in a stash")
	check(m.stash_move(b, "scrap", -10) == "" and b.scrap == 16 and int(m.team_bank[0]["scrap"]) == 5, "a teammate takes scrap out (6 + 10)")
	check(m.stash_move(foe, "scrap", -5) != "" and int(m.team_bank[0]["scrap"]) == 5, "the other team cannot use your stash")
	check(m.can_use_stash(foe) == false, "(they are not beside a stash of their own)")
	# at base works too, with no stash nearby
	var c := arena_rat(m, 0, "digger")
	c.position = MapGenerator.spawn_point(0)
	check(m.can_use_stash(c) and m.stash_move(c, "stone", -3) == "" and int(c.mats["stone"]) == 3, "the base reaches the pool as well")
	# only TNT breaks it, 5 blasts, and the pool survives
	for i in 6:
		a.dig_cd = 0.0
		m.try_dig(a, st)
		foe.dig_cd = 0.0
		m.try_dig(foe, st)
	check(m.world.get_cell(st) == Blocks.STASH_BLUE, "digging does not hurt a stash")
	for i in Config.STASH_BLASTS - 1:
		m.blast(Vector3(st) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(m.world.get_cell(st) == Blocks.STASH_BLUE, "it survives %d blasts" % (Config.STASH_BLASTS - 1))
	m.blast(Vector3(st) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(m.world.get_cell(st) == Blocks.AIR, "the %dth blast breaks it" % Config.STASH_BLASTS)
	check(int(m.team_bank[0]["scrap"]) == 5 and int(m.team_bank[0]["stone"]) == 4, "the team pool is untouched")
	end(m)


func test_jetpack_gear() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 6)
	var r := arena_rat(m, 0, "scout")
	r.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	var cost := int(ClassDefs.shop_item("jetpack")["cost"])
	r.scrap = cost * 2
	check(r.gear == "" and m.try_buy(r, "jetpack") == "" and r.gear == "jetpack" and r.scrap == cost, "buying a jetpack puts it in the gear slot")
	check(m.try_buy(r, "jetpack") != "" and r.scrap == cost, "you only wear one; buying it again is refused")
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	run(m, 0.3)
	var y0 := r.position.y
	r.gear_pressed = true
	run(m, Config.JETPACK_TIME)
	check(r.position.y > y0 + 5.0, "J lifts you (%.1f blocks)" % (r.position.y - y0))
	check(r.gear_cd > Config.JETPACK_COOLDOWN - 0.2 and r.gear_cd <= Config.JETPACK_COOLDOWN + 0.05, "then it cools down for %.0f s" % Config.JETPACK_COOLDOWN)
	run(m, 2.0)
	var y1 := r.position.y
	r.gear_pressed = true
	run(m, 0.5)
	check(r.position.y <= y1 + 0.05, "no second burst while cooling down")
	run(m, Config.JETPACK_COOLDOWN)
	r.gear_pressed = true
	m.step(DT)
	check(r.vel.y >= Config.JETPACK_LIFT - 0.01, "ready again after the cooldown")
	var plain := arena_rat(m, 1, "scout", Vector3(3, 0, 3))
	run(m, 0.3)
	plain.gear_pressed = true
	m.step(DT)
	check(plain.vel.y < 1.0, "no jetpack, no lift")
	end(m)


func trench_around_base(m: Match, team: int, depth: int) -> void:
	## What an enemy did in a playtest: a moat 2 wide all the way around the base.
	var z := MapGenerator.base_zone(team)
	var x0 := int(z.position.x) - 2
	var x1 := int(z.end.x) + 1
	var z0 := int(z.position.z) - 2
	var z1 := int(z.end.z) + 1
	for x in range(x0, x1 + 1):
		for zz in range(z0, z1 + 1):
			var ring := x < int(z.position.x) or x >= int(z.end.x) or zz < int(z.position.z) or zz >= int(z.end.z)
			if not ring or not VoxelWorld.in_bounds(Vector3i(x, 0, zz)):
				continue
			for d in range(1, depth + 1):
				m.world.set_block(Vector3i(x, MapGenerator.GROUND - d, zz), Blocks.AIR)
			for y in range(MapGenerator.GROUND, MapGenerator.GROUND + 4):
				m.world.set_block(Vector3i(x, y, zz), Blocks.AIR)


func test_bot_crosses_trench() -> void:
	for depth in [2, 3, 5]:
		var m := new_match({"seed": 4242})
		trench_around_base(m, 0, depth)
		var bot := m.spawn_rat(0, "scout", true)
		bot.position = MapGenerator.approach_point(0) + Vector3(6, 0, 0)
		bot.carried = 1
		var start := m.scores[0]
		var respawns := [0]
		m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void:
			if kind == "respawn":
				respawns[0] += 1)
		var t := 0.0
		while t < 45.0 and m.scores[0] == start:
			m.step(DT)
			t += DT
		check(m.scores[0] > start and respawns[0] == 0, "a bot carrying cheese gets home across a %d-deep moat (%.0f s, %d respawns, at %s)" % [depth, t, respawns[0], str(bot.position.floor())])
		end(m)


func test_bot_gear_and_dash() -> void:
	var m := new_match({"seed": 4242})
	var bot := m.spawn_rat(0, "digger", true)
	bot.scrap = 20
	run(m, 0.5)
	check(bot.gear == "jetpack" and bot.scrap == 20 - ClassDefs.price(bot.cls, "jetpack", false), "a bot at base with enough scrap buys a jetpack")
	# dropped into a deep shaft next to home while carrying cheese, it jets out
	var shaft := Vector3i(int(MapGenerator.approach_point(0).x), MapGenerator.GROUND - 1, int(MapGenerator.approach_point(0).z))
	for d in range(0, 7):
		m.world.set_block(shaft - Vector3i(0, d, 0), Blocks.AIR)
	bot.position = Vector3(shaft - Vector3i(0, 6, 0)) + Vector3(0.5, 0, 0.5)
	bot.carried = 1
	var fired := [0]
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void:
		if kind == "jetpack":
			fired[0] += 1)
	var t := 0.0
	var start := m.scores[0]
	while t < 30.0 and m.scores[0] == start:
		m.step(DT)
		t += DT
	check(fired[0] > 0, "the bot fires its jetpack to climb out (%d bursts)" % fired[0])
	check(m.scores[0] > start, "and banks the cheese (%.0f s)" % t)
	# a long run across open ground: bots dash
	var runner := m.spawn_rat(1, "scout", true)
	var dashed := false
	for i in int(20.0 / DT):
		m.step(DT)
		if runner.dash_t > 0.0:
			dashed = true
			break
	check(dashed, "bots dash on long open runs")
	# ...under exactly the player's rules: never twice within the dash cooldown
	var starts: Array[float] = []
	var clock := 0.0
	runner.stamina = runner.max_stamina()
	for i in int(25.0 / DT):
		var was := runner.dash_t
		m.step(DT)
		clock += DT
		if runner.dash_t > was:
			starts.append(clock)
	var closest := INF
	for k in range(1, starts.size()):
		closest = minf(closest, starts[k] - starts[k - 1])
	check(starts.size() >= 2 and closest >= 0.6 - DT * 0.5, "bot dashes respect the player dash cooldown (%d dashes, closest %.2f s apart)" % [starts.size(), closest])
	end(m)


func test_dash_with_cheese() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 9)
	var a := arena_rat(m, 0, "scout", Vector3(-7, 0, -3))
	var b := arena_rat(m, 0, "scout", Vector3(-7, 0, 3))
	var c := arena_rat(m, 0, "digger", Vector3(-7, 0, 0))
	run(m, 0.3)
	b.carried = 1
	c.carried = 3
	var stamina_before := [a.stamina, b.stamina, c.stamina]
	for r in [a, b, c]:
		r.yaw = -PI / 2.0      # face +x
		r.dash_pressed = true
	m.step(DT)
	check(a.vel.x > Rat.DASH_SPEED * 0.9 and absf(b.vel.x - Rat.DASH_SPEED * 0.5) < 0.6, "one cheese halves the dash burst (%.1f vs %.1f)" % [a.vel.x, b.vel.x])
	check(absf(c.vel.x - Rat.DASH_SPEED * 0.3) < 0.6, "a full load of 3 weakens it further (%.1f)" % c.vel.x)
	check(is_equal_approx(stamina_before[0] - a.stamina, Config.DASH_COST) and is_equal_approx(stamina_before[1] - b.stamina, Config.DASH_CARRY_COST) \
		and Config.DASH_CARRY_COST > Config.DASH_COST, "and costs more stamina (%.0f vs %.0f)" % [stamina_before[1] - b.stamina, stamina_before[0] - a.stamina])
	var a0 := a.position.x
	var b0 := b.position.x
	run(m, 0.4)
	var da := a.position.x - a0
	var db := b.position.x - b0
	check(db < da * 0.65, "and the dash covers much less ground (%.2f vs %.2f blocks)" % [db, da])
	# not enough stamina for a loaded dash: nothing happens
	run(m, 1.0)
	b.stamina = Config.DASH_CARRY_COST - 5.0
	b.vel = Vector3.ZERO
	b.dash_cd = 0.0
	b.dash_pressed = true
	m.step(DT)
	check(absf(b.vel.x) < 1.0 and b.stamina >= Config.DASH_CARRY_COST - 5.0, "a loaded dash needs the full %.0f stamina" % Config.DASH_CARRY_COST)
	end(m)


func test_enemy_names_need_sight() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var me := arena_rat(m, 0, "scout")
	var friend := arena_rat(m, 0, "scout", Vector3(5, 0, 0))
	var foe := arena_rat(m, 1, "scout", Vector3(5, 0, 2))
	run(m, 0.3)
	var eye := me.eye()
	check(GameSession.name_visible(m.world, eye, 0, foe), "an enemy in plain view shows their name")
	for dy in range(0, 3):
		for dz in range(-2, 5):
			m.world.set_block(ARENA + Vector3i(3, dy, dz), Blocks.STONE)
	check(not GameSession.name_visible(m.world, eye, 0, foe), "an enemy behind a wall does not")
	check(GameSession.name_visible(m.world, eye, 0, friend), "teammates always show, even behind a wall")
	# glass, team gates and a chiselled window let you see through
	for dy in range(0, 3):
		for dz in range(-2, 5):
			m.world.set_block(ARENA + Vector3i(3, dy, dz), Blocks.PAINT_0 + Blocks.PALETTE_SOLID)
	check(GameSession.name_visible(m.world, eye, 0, foe), "through glass you see them")
	for dy in range(0, 3):
		for dz in range(-2, 5):
			m.world.set_block(ARENA + Vector3i(3, dy, dz), Blocks.STONE)
	var hole := PackedByteArray()
	hole.resize(Blocks.MICRO_COUNT)
	hole.fill(1)
	for my in Blocks.MICRO:
		for mz in Blocks.MICRO:
			for mx in Blocks.MICRO:
				if mz >= 1 and mz <= 5 and my >= 1:
					hole[mx + Blocks.MICRO * (mz + Blocks.MICRO * my)] = 0   # a window cut right through
	var win := ARENA + Vector3i(3, 0, 1)
	m.world.set_mask(win, Blocks.STONE, hole)
	var target := Vector3(win) + Vector3(2.5, 0.5, 0.5)
	check(m.world.line_of_sight(Vector3(win) + Vector3(-1.5, 0.5, 0.5), target), "and through a window chiselled into the wall")
	check(not m.world.line_of_sight(Vector3(win) + Vector3(-1.5, 0.5, -1.5), Vector3(win) + Vector3(2.5, 0.5, -1.5)), "but not through the solid stone beside it")
	end(m)


func test_paint_on_click() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	run(m, 0.2)
	var c := ARENA + Vector3i(2, 0, 0)
	m.world.set_block(c, Blocks.DIRT)
	var mats := r.mats.duplicate()
	r.dig_cd = 0.0
	check(m.paintable(c) and m.try_paint_block(r, c, 5) == "" and m.world.get_cell(c) == Blocks.PAINT_0 + 5, "left click with paint dyes a dirt block")
	check(Blocks.HITS[Blocks.PAINT_0 + 5] == Blocks.HITS[Blocks.DIRT], "painting never changes how tough a block is")
	var st := ARENA + Vector3i(2, 0, -1)
	m.world.set_block(st, Blocks.STONE)
	r.dig_cd = 0.0
	check(not m.paintable(st) and m.try_paint_block(r, st, 5) != "" and m.world.get_cell(st) == Blocks.STONE, "stone cannot be painted weaker (enemy walls stay stone)")
	check(r.mats == mats, "dyeing costs nothing")
	r.dig_cd = 0.0
	check(m.try_paint_block(r, c, Blocks.PALETTE_SOLID + 1) == "" and Blocks.is_glass(m.world.get_cell(c)), "a painted block can be recoloured, even to glass")
	var ob := ARENA + Vector3i(2, 0, 1)
	m.world.set_block(ob, Blocks.OBSIDIAN)
	r.dig_cd = 0.0
	check(not m.paintable(ob) and m.try_paint_block(r, ob, 2) != "" and m.world.get_cell(ob) == Blocks.OBSIDIAN, "obsidian (and other tough blocks) cannot be painted weaker")
	r.position = Vector3(14.0, MapGenerator.GROUND, 10.5)
	r.dig_cd = 0.0
	check(m.try_paint_block(r, Vector3i(12, MapGenerator.GROUND - 1, 10), 2) != "", "base blocks cannot be painted")
	end(m)


func test_pantograph_transforms() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "builder")
	var a := ARENA + Vector3i(2, 0, 0)
	# an L of stone with one carved block: 3 wide, 2 tall, 1 deep
	m.world.set_block(a, Blocks.STONE)
	m.world.set_block(a + Vector3i(1, 0, 0), Blocks.STONE)
	m.world.set_block(a + Vector3i(2, 0, 0), Blocks.ICE)
	var carved := mask_layers(3)
	carved[0] = 0
	m.world.set_mask(a + Vector3i(0, 1, 0), Blocks.STONE, carved)
	var bp: Blueprint = m.copy_region(r, a, a + Vector3i(2, 1, 0))["blueprint"]
	check(bp.cells.size() == 4 and bp.size == Vector3i(3, 2, 1), "copied the L")
	var mir := bp.mirrored()
	var by_o := {}
	for e in mir.cells:
		by_o[e["o"]] = e
	check(int(by_o[Vector3i(0, 0, 0)]["id"]) == Blocks.ICE and by_o.has(Vector3i(2, 1, 0)), "mirror swaps left and right")
	var mk: PackedByteArray = by_o[Vector3i(2, 1, 0)]["mask"]
	check(mk[6] == 0 and mk[0] == 1, "and mirrors the carving inside the block")
	check(_same(bp, bp.mirrored().mirrored()), "mirroring twice restores the original")
	var flp := bp.flipped()
	by_o.clear()
	for e in flp.cells:
		by_o[e["o"]] = e
	check(by_o.has(Vector3i(0, 0, 0)) and by_o[Vector3i(0, 0, 0)]["mask"] != null and by_o.has(Vector3i(1, 1, 0)), "flip turns it upside down")
	var fm: PackedByteArray = by_o[Vector3i(0, 0, 0)]["mask"]
	check(fm[0 + 49 * 6] == 0 and fm.count(1) == 146 and fm[0] == 0 and fm[1 + 49 * 6] == 1, "the carving is flipped too (layers now at the top)")
	check(_same(bp, bp.flipped().flipped()), "flipping twice restores the original")
	var inv := bp.inverted()
	by_o.clear()
	for e in inv.cells:
		by_o[e["o"]] = e
	check(by_o.has(Vector3i(1, 1, 0)) and by_o.has(Vector3i(2, 1, 0)) and int(by_o[Vector3i(1, 1, 0)]["id"]) == Blocks.STONE, "invert fills the empty spots with the main material")
	check(not by_o.has(Vector3i(0, 0, 0)) and not by_o.has(Vector3i(2, 0, 0)), "and empties the full blocks")
	check(by_o.has(Vector3i(0, 1, 0)) and (by_o[Vector3i(0, 1, 0)]["mask"] as PackedByteArray).count(1) == 343 - 146, "a carved block keeps exactly the carved-away part")
	check(inv.validate() == "" and mir.validate() == "" and flp.validate() == "", "transformed blueprints pass the authority's checks")
	r.mats["stone"] = 9
	check(m.try_paste(r, inv, ARENA + Vector3i(-5, 0, -2)) == "", "an inverted blueprint pastes")
	end(m)


func _same(a: Blueprint, b: Blueprint) -> bool:
	if a.size != b.size or a.cells.size() != b.cells.size():
		return false
	for e in a.cells:
		var hit := false
		for f in b.cells:
			if f["o"] == e["o"] and f["id"] == e["id"] and f["mask"] == e["mask"]:
				hit = true
		if not hit:
			return false
	return true


func test_big_goal_and_map_import() -> void:
	var m := new_match({"goal": 250, "seed": 31})
	check(m.world.cheese_cells.size() >= 625, "a 250 goal puts at least 625 cheese on the map (%d)" % m.world.cheese_cells.size())
	var halves := [0, 0]
	for c: Vector3i in m.world.cheese_cells:
		halves[0 if c.x < VoxelWorld.SX / 2 else 1] += 1
	check(halves[0] == halves[1], "split evenly (%d / %d)" % [halves[0], halves[1]])
	var low := new_match({"goal": 8, "seed": 31})
	check(low.world.cheese_cells.size() >= 20, "small goals still get a full map (%d)" % low.world.cheese_cells.size())
	# export a Free Build map with a carving and a machine, import it as a race and as Free Build
	var fb := new_match({"mode": "free", "seed": 5})
	var r := fb.spawn_rat(0, "maestro", false)
	r.position = Vector3(40.5, 58, 40.5)
	fb.world.set_block(Vector3i(40, 57, 42), Blocks.STONE)
	fb.world.set_mask(Vector3i(41, 57, 42), Blocks.STONE, mask_layers(2))
	# wreck a base to prove an import restores it
	for x in range(MapGenerator.BASE_MIN, MapGenerator.BASE_MIN + MapGenerator.BASE_SIZE):
		fb.world.set_block(Vector3i(x, MapGenerator.GROUND - 1, 9), Blocks.AIR)
	var path := VoxelWorld.MAPS_DIR + "/test_export.bwmap"
	check(fb.world.save_to(path, {"machines": fb.siege.to_save()}) and VoxelWorld.file_ok(path) and VoxelWorld.list_maps().has(path), "exported and listed")
	end(fb)
	var race := new_match({"goal": 40, "map_file": path, "seed": 6})
	check(race.world.get_cell(Vector3i(40, 57, 42)) == Blocks.STONE and race.world.has_micro(Vector3i(41, 57, 42)), "an imported map keeps its builds and carvings")
	check(race.world.get_cell(Vector3i(9, MapGenerator.GROUND - 1, 9)) == Blocks.BASE_BLUE and race.world.get_cell(MapGenerator.rot_cell(Vector3i(9, MapGenerator.GROUND - 1, 9))) == Blocks.BASE_RED, "both bases are stamped back for a race")
	check(race.world.cheese_cells.size() >= MapGenerator.min_cheese(40), "cheese is topped up to 2.5x the goal (%d)" % race.world.cheese_cells.size())
	var spawn := MapGenerator.spawn_point(1)
	check(race.world.block_at(spawn + Vector3(0, 0.5, 0)) == Blocks.AIR, "the spawn is clear")
	end(race)
	var free2 := new_match({"mode": "free", "map_file": path, "seed": 6})
	check(free2.world.has_micro(Vector3i(41, 57, 42)), "and loads as Free Build")
	end(free2)
	var bad := new_match({"map_file": "user://maps/does_not_exist.bwmap"})
	check(bad.world.cheese_cells.size() > 0, "a missing map falls back to a generated one")
	end(bad)
	DirAccess.remove_absolute(path)
	end(m)
	end(low)


func test_cheese_drop_and_springs() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "digger")
	run(m, 0.2)
	r.carried = 3
	var floor_cell := ARENA + Vector3i(3, -1, 0)
	check(m.drop_cheese(r, {"cell": floor_cell, "normal": Vector3i(0, 1, 0)}, Vector3(1, -0.3, 0).normalized()), "drop one cheese")
	var pk: Match.Pickup = m.pickups[-1]
	check(r.carried == 2 and Vector3i(pk.pos.floor()) == floor_cell + Vector3i(0, 1, 0), "it lands where you were looking")
	check(m.drop_cheese(r, {}, Vector3(0, 0, 1)), "drop with nothing aimed at")
	var tossed: Match.Pickup = m.pickups[-1]
	check(tossed.vel.z > 3.0, "it is tossed forward instead")
	r.position = Vector3(ARENA) + Vector3(-6.5, 0, 6.5)    # out of the way
	# a spring launches loose cheese
	var spring := ARENA + Vector3i(-3, 0, -3)
	m.world.set_block(spring, Blocks.SPRING)
	var drop := m.spawn_pickup("cheese", Vector3(spring) + Vector3(0.5, 2.5, 0.5), Vector3.ZERO)
	var top := 0.0
	for i in 120:
		m.step(DT)
		top = maxf(top, drop.pos.y)
	check(top > float(spring.y) + 4.0, "a spring launches loose cheese (peak %.1f above it)" % (top - spring.y))
	run(m, 3.0)
	check(Vector3i(drop.pos.floor()) - spring != Vector3i(0, 1, 0) and drop.vel.length() < 0.1, "and it hops off and comes to rest instead of bouncing forever")
	# cheese floats in water
	var pool := ARENA + Vector3i(4, 0, 4)
	for dy in range(-3, 1):
		m.world.set_block(pool + Vector3i(0, dy, 0), Blocks.WATER)
	m.world.set_block(pool + Vector3i(0, -4, 0), Blocks.STONE)
	var wet := m.spawn_pickup("cheese", Vector3(pool) + Vector3(0.5, -3.5, 0.5), Vector3.ZERO)
	run(m, 2.5)
	check(wet.pos.y > float(pool.y) - 0.1 and m.world.block_at(wet.pos) == Blocks.WATER, "loose cheese floats up to the surface of water (y %.2f)" % (wet.pos.y - pool.y))
	# a wall spring bats it back
	var wall := ARENA + Vector3i(0, 0, -6)
	m.world.set_block(wall, Blocks.WALL_SPRING)
	var slide := m.spawn_pickup("cheese", Vector3(wall) + Vector3(0.5, 0.3, 2.2), Vector3(0, 0, -9))
	var turned := false
	for i in 60:
		m.step(DT)
		if slide.vel.z > 3.0:
			turned = true
	check(turned and slide.pos.z > float(wall.z) + 1.0, "a wall spring bats cheese back")
	end(m)


func test_ability_cooldowns() -> void:
	check(float(ClassDefs.CLASSES["digger"]["abilities"][0][2]) == 4.0, "Super Dig recharges in 4 s")
	check(float(ClassDefs.CLASSES["builder"]["abilities"][0][2]) == 5.0, "Patch recharges in 5 s")
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "builder")
	run(m, 0.2)
	var aim := {"cell": ARENA + Vector3i(2, -1, 0), "normal": Vector3i(0, 1, 0)}
	check(m.use_ability(r, 0, aim) == "", "patch")
	run(m, 4.0)
	check(m.use_ability(r, 0, {"cell": ARENA + Vector3i(-2, -1, 0), "normal": Vector3i(0, 1, 0)}).ends_with("recharging"), "still recharging after 4 s")
	run(m, 1.2)
	check(m.use_ability(r, 0, {"cell": ARENA + Vector3i(-2, -1, 0), "normal": Vector3i(0, 1, 0)}) == "", "ready again after 5 s")
	end(m)


func test_gate_holds_gadgets() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "builder")
	var e := arena_rat(m, 1, "digger", Vector3(5, 0, 3))
	run(m, 0.2)
	r.gadgets["gate"] = 5
	r.gadgets["spring"] = 2
	r.gadgets["ladder"] = 2
	r.gadgets["highway"] = 2
	r.gadgets["conveyor"] = 2
	var look := Vector3(1, 0, 0)
	var g := ARENA + Vector3i(3, 0, 0)
	var g2 := ARENA + Vector3i(3, 0, 2)
	var g3 := ARENA + Vector3i(3, 0, -2)
	for c in [g, g2, g3]:
		check(m.try_place_gadget(r, c, "gate") == "" and m.world.get_cell(c) == Blocks.GATE_BLUE, "a blue gate")
	r.equipped = "spring"
	check(m.try_use_equipped(r, {"cell": g, "normal": Vector3i(-1, 0, 0)}, look, false) == "", "Q at your own gate puts the spring inside it")
	check(m.world.get_cell(g) == Blocks.SPRING and m.world.layered_gate(g) == 0 and m.world.gate_at(g) == 0, "the cell holds the spring and the gate")
	check(int(r.gadgets["spring"]) == 1 and m.world.get_cell(g + Vector3i(-1, 0, 0)) == Blocks.AIR, "it costs one spring and nothing lands beside the gate")
	r.equipped = "ladder"
	check(m.try_use_equipped(r, {"cell": g2, "normal": Vector3i(-1, 0, 0)}, look, false) == "" and m.world.get_cell(g2) == Blocks.LADDER, "a ladder inside a gate")
	var inside := Vector3(g2) + Vector3(0.5, 0, 0.5)
	check(not r.blocked_at(inside) and e.blocked_at(inside), "your team climbs through it; the enemy still bumps into the gate")
	check(m.world.solid_for_at(g2, 1) and not m.world.solid_for_at(g2, 0), "bots see the same rule")
	check(m.world.solid_point(inside + Vector3(0, 0.5, 0)), "loose cheese and TNT still stop at the gate")
	# the other team can neither fill nor empty it
	e.gadgets["spring"] = 1
	e.equipped = "spring"
	e.position = Vector3(ARENA) + Vector3(4.5, 0, -1.5)
	m.try_use_equipped(e, {"cell": g3, "normal": Vector3i(1, 0, 0)}, -look, false)
	check(m.world.get_cell(g3) == Blocks.GATE_BLUE and m.world.layered_gate(g3) == -1, "an enemy cannot put a gadget in your gate")
	e.position = Vector3(ARENA) + Vector3(4.5, 0, 0.5)
	for i in 6:
		e.dig_cd = 0.0
		m.try_dig(e, g)
	check(m.world.get_cell(g) == Blocks.SPRING and m.world.layered_gate(g) == 0, "an enemy cannot dig the gadget out of your gate")
	# your team digs the gadget out: the gate stays
	var n := 0
	while m.world.get_cell(g) == Blocks.SPRING and n < 10:
		r.dig_cd = 0.0
		m.try_dig(r, g)
		n += 1
	check(m.world.get_cell(g) == Blocks.GATE_BLUE and m.world.layered_gate(g) == -1 and int(r.gadgets["spring"]) == 2, "digging the spring out returns it and leaves the gate")
	# highway on top of a gate lies on top; a conveyor goes in, facing the bright edge
	r.equipped = "highway"
	check(m.try_use_equipped(r, {"cell": g3, "normal": Vector3i(0, 1, 0)}, look, false) == "" and m.world.get_cell(g3 + Vector3i(0, 1, 0)) == Blocks.HIGHWAY and m.world.get_cell(g3) == Blocks.GATE_BLUE, "a highway aimed at the top of a gate lies on top of it")
	r.equipped = "conveyor"
	check(m.try_use_equipped(r, {"cell": g, "normal": Vector3i(-1, 0, 0)}, look, false, Vector3(0, 0, 1)) == "" and m.world.get_cell(g) == Blocks.CONV_ZP and m.world.layered_gate(g) == 0, "a conveyor inside a gate keeps its direction")
	# save and load keep it
	check(m.world.save_to("user://test_maps/gates.bwmap"), "save")
	m.world.set_gate_layer(g2, -1)
	m.world.set_block(g2, Blocks.AIR)
	check(m.world.load_from("user://test_maps/gates.bwmap") and m.world.get_cell(g2) == Blocks.LADDER and m.world.layered_gate(g2) == 0, "gates holding gadgets survive save and load")
	var snap := m.world.snapshot()
	var copy := VoxelWorld.new()
	copy.visual = false
	check(copy.apply_snapshot(snap) and copy.layered_gate(g2) == 0 and copy.layered_gate(g) == 0, "and a joining player's world snapshot")
	copy.free()
	# two TNT blasts break the gate and whatever it held
	m.blast(Vector3(g) + Vector3(0.5, 0.5, 0.5), 0.8, 1.0)
	check(m.world.get_cell(g) == Blocks.CONV_ZP, "one blast only cracks the gate")
	m.blast(Vector3(g) + Vector3(0.5, 0.5, 0.5), 0.8, 1.0)
	check(m.world.get_cell(g) == Blocks.AIR and m.world.layered_gate(g) == -1, "the second blast breaks the gate and its conveyor")
	end(m)


func test_wood_is_scenery() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	check(not ClassDefs.MATS.has("wood") and not r.mats.has("wood") and ClassDefs.shop_item("wood").is_empty(), "wood is not a material, stash slot or shop item")
	var c := ARENA + Vector3i(2, 0, 0)
	m.world.set_block(c, Blocks.WOOD)
	var before := r.mats.duplicate()
	var n := 0
	while m.world.get_cell(c) == Blocks.WOOD and n < 10:
		r.dig_cd = 0.0
		m.try_dig(r, c)
		n += 1
	check(m.world.get_cell(c) == Blocks.AIR and r.mats == before, "wood still breaks, and gives nothing")
	check(not Blocks.CHISELABLE.has(Blocks.WOOD) and not Blocks.COPYABLE.has(Blocks.WOOD), "it is neither carved nor copied")
	end(m)


func test_highway_layer() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "builder")
	r.gadgets["highway"] = 4
	r.equipped = "highway"
	run(m, 0.2)
	var top := ARENA + Vector3i(2, 0, 0)
	check(m.try_use_equipped(r, {"cell": top + Vector3i(0, -1, 0), "normal": Vector3i(0, 1, 0)}, Vector3(1, 0, 0), false) == "", "placed on a floor")
	check(m.world.get_cell(top) == Blocks.HIGHWAY and m.world.get_cell(top + Vector3i(0, -1, 0)) == Blocks.STONE, "highway sits on the face; the block under it is untouched")
	check(Blocks.SOLID[Blocks.HIGHWAY] == 0 and not r.blocked_at(Vector3(top) + Vector3(0.5, 0, 0.5)), "it is a thin layer you walk on, not a block you bump into")
	r.position = Vector3(top) + Vector3(0.5, 0, 0.5)
	run(m, 0.2)
	check(r.on_floor and absf(r.position.y - ARENA.y) < 0.02, "a rat stands on the floor through it")
	check(r.move_speed() > Config.BASE_SPEED * 1.5, "and gets the highway speed boost")
	check(m.try_place_gadget(r, ARENA + Vector3i(0, 3, 0), "highway") != "" and int(r.gadgets["highway"]) == 3, "a highway needs a floor under it")
	m.world.set_block(top + Vector3i(0, -1, 0), Blocks.AIR)
	check(m.world.get_cell(top) == Blocks.AIR, "dig the floor away and the highway on it goes too")
	end(m)


func test_siege_floor_conveyor() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "builder", Vector3(-1.5, 0, 0))
	r.gadgets["cannon"] = 1
	r.gadgets["conveyor"] = 3
	run(m, 0.2)
	check(m.try_place_gadget(r, ARENA, "cannon") == "", "cannon placed")
	run(m, 1.0)
	check(m.world.get_cell(ARENA) == Blocks.CANNON, "it stays put with no conveyor near")
	# lay a conveyor into the floor NEXT to it (not under it), the way Q places them, facing +X
	r.equipped = "conveyor"
	var beside := ARENA + Vector3i(0, -1, 1)
	check(m.try_use_equipped(r, {"cell": beside, "normal": Vector3i(0, 1, 0)}, Vector3(1, 0, 0), false, Vector3(1, 0, 0)) == "" and m.world.get_cell(beside) == Blocks.CONV_XP, "conveyor laid into the floor beside the machine")
	run(m, 0.7)
	check(m.world.get_cell(ARENA + Vector3i(1, 0, 0)) == Blocks.CANNON, "the machine moves the way that conveyor faces")
	run(m, 1.5)
	check(m.world.get_cell(ARENA + Vector3i(1, 0, 0)) == Blocks.CANNON, "and stops once it has left the conveyor behind")
	# a different facing sends it a different way
	var c2 := ARENA + Vector3i(2, -1, 0)
	m.try_use_equipped(r, {"cell": c2, "normal": Vector3i(0, 1, 0)}, Vector3(1, 0, 0), false, Vector3(0, 0, -1))
	check(m.world.get_cell(c2) == Blocks.CONV_ZN, "second conveyor faces -Z")
	run(m, 0.7)
	check(m.world.get_cell(ARENA + Vector3i(1, 0, -1)) == Blocks.CANNON, "direction always follows the conveyor's facing")
	# rolling over a highway layer puts the highway back behind it
	var road := ARENA + Vector3i(1, 0, -2)
	m.world.set_block(road, Blocks.HIGHWAY)
	m.world.set_block(ARENA + Vector3i(1, -1, -1), Blocks.CONV_ZN)   # under the machine: push it across the road tile
	var seen_on_road := false
	for i in 120:
		m.step(DT)
		seen_on_road = seen_on_road or m.world.get_cell(road) == Blocks.CANNON
	check(seen_on_road, "a conveyor can push a machine across a highway tile")
	check(m.world.get_cell(road) == Blocks.HIGHWAY and m.world.get_cell(road + Vector3i(0, 0, -1)) == Blocks.CANNON, "and the highway is still there after it rolls on")
	check(m.siege.machines.size() == 1, "still exactly one machine")
	end(m)


func test_wrecking_ball_table() -> void:
	check(SiegeSystem.ball_power(Blocks.DIRT) >= Blocks.HITS[Blocks.DIRT] and SiegeSystem.ball_power(Blocks.GRASS) >= Blocks.HITS[Blocks.GRASS], "dirt breaks in one ball hit")
	for pair: Array in [[Blocks.STONE, 2], [Blocks.BRICK, 2], [Blocks.OBSIDIAN, 4]]:
		var need := ceili(float(Blocks.HITS[pair[0]]) / float(SiegeSystem.ball_power(pair[0])))
		check(need == int(pair[1]), "%s takes %d ball hits (%d)" % [Blocks.block_name(pair[0]), pair[1], need])
	check(SiegeSystem.ball_power(Blocks.BEDROCK) == 0 and SiegeSystem.ball_power(Blocks.BASE_BLUE) == 0, "bedrock and bases are immune")
	# count real impacts in the simulation, per material
	for row: Array in [[Blocks.DIRT, 1], [Blocks.STONE, 2], [Blocks.OBSIDIAN, 4], [Blocks.GATE_RED, 10]]:
		var m := new_match()
		flat_arena(m, ARENA, 8)
		var r := arena_rat(m, 0, "builder", Vector3(-1.5, 0, 0))
		r.gadgets["crane"] = 1
		r.yaw = -PI / 2.0
		run(m, 0.2)
		m.try_place_gadget(r, ARENA, "crane")
		var mc: SiegeSystem.Machine = m.siege.machines[ARENA]
		mc.yaw = -PI / 2.0
		m.siege.try_operate(r, ARENA)
		var target := Vector3i(-99, 0, 0)
		var thuds := [0]
		m.fx.connect(func(kind: String, _pos: Vector3, data: Variant) -> void:
			if kind == "thud" and float(data) >= Config.CRANE_MIN_SPEED:
				thuds[0] += 1
		)
		# put the target where the ball first strikes
		var probe_cell := Vector3i(floori(SiegeSystem.ball_pos(mc).x + 1.6), ARENA.y, ARENA.z)
		target = probe_cell
		m.world.set_block(target, int(row[0]))
		var t := 0.0
		while m.world.get_cell(target) == int(row[0]) and t < 90.0:
			m.siege.fire(r)
			m.step(DT)
			t += DT
		check(m.world.get_cell(target) == Blocks.AIR, "%s gives way to the wrecking ball" % Blocks.block_name(int(row[0])))
		check(thuds[0] == int(row[1]), "%s: %d solid hits (counted %d)" % [Blocks.block_name(int(row[0])), int(row[1]), thuds[0]])
		end(m)
	# gates: two TNT blasts still do it
	var g := new_match()
	flat_arena(g, ARENA)
	g.world.set_block(ARENA + Vector3i(2, 0, 0), Blocks.GATE_RED)
	g.blast(Vector3(ARENA) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(g.world.get_cell(ARENA + Vector3i(2, 0, 0)) == Blocks.GATE_RED, "one blast: gate holds")
	g.blast(Vector3(ARENA) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(g.world.get_cell(ARENA + Vector3i(2, 0, 0)) == Blocks.AIR, "two blasts: gate falls")
	end(g)


func test_bonked_pilot() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var pilot := arena_rat(m, 0, "builder", Vector3(-1.2, 0, 0))
	var foe := arena_rat(m, 1, "scout", Vector3(-2.3, 0, 0))
	var mate := arena_rat(m, 0, "scout", Vector3(-1.2, 0, 1.2))
	pilot.gadgets["cannon"] = 1
	run(m, 0.2)
	m.try_place_gadget(pilot, ARENA, "cannon")
	for kind: String in ["bonk"]:
		check(m.siege.try_operate(pilot, ARENA) == "" and pilot.operating != -1, "pilot at the controls")
		check(not m.try_bonk(mate, pilot) and pilot.operating != -1, "a teammate cannot knock you off")
		var x0 := pilot.position.x
		check(m.try_bonk(foe, pilot), "enemy bonks the pilot")
		run(m, 0.3)
		check(pilot.operating == -1 and m.siege.machines[ARENA].operator == -1, "the pilot is thrown off the machine")
		check(pilot.position.x > x0 + 0.5 or absf(pilot.position.z - 0.5 - ARENA.z) > 0.5 or pilot.position.y > ARENA.y + 0.2, "and pushed back (moved %.2f)" % (pilot.position.x - x0))
		check(m.siege.fire(pilot) != "", "the machine no longer answers to them")
		run(m, 1.0)
		pilot.wish = Vector3(0, 0, 1)
		var z0 := pilot.position.z
		run(m, 0.4)
		pilot.wish = Vector3.ZERO
		check(pilot.position.z > z0 + 0.8, "they can walk normally afterwards")
		check(m.world.get_cell(ARENA) == Blocks.CANNON, "the machine itself is unharmed and can be re-manned")
	end(m)


func test_scrap_abundance() -> void:
	var total := 0
	var solid := 0
	for seed_n: int in [7, 21, 4242]:
		var m := new_match({"seed": seed_n})
		for id in m.world.data:
			if id == Blocks.SCRAP:
				total += 1
			if id == Blocks.STONE or id == Blocks.DIRT or id == Blocks.SCRAP:
				solid += 1
		end(m)
	var pct := 100.0 * total / solid
	print("    scrap: %d blocks per map on average, %.2f%% of diggable ground" % [total / 3, pct])
	check(total / 3 > 500, "plenty of scrap on a map (%d)" % (total / 3))
	end_noop()


func test_bots_complete_a_match() -> void:
	var m := new_match({"goal": 6, "seed": 7})
	var before := total_cheese(m)
	for team in 2:
		m.spawn_rat(team, "digger", true)
		m.spawn_rat(team, "scout", true)
	var limit := 8.0 * 60.0
	var dt := 1.0 / 30.0
	var first_score := -1.0
	while not m.over and m.time < limit:
		m.step(dt)
		if first_score < 0.0 and m.scores[0] + m.scores[1] > 0:
			first_score = m.time
	print("    bots: over=%s winner=%d score=%d-%d sim_time=%.0fs first_score=%.0fs" % [m.over, m.winner, m.scores[0], m.scores[1], m.time, first_score])
	check(m.scores[0] + m.scores[1] > 0, "bots find, carry and deposit cheese")
	check(m.over, "a bots-only match reaches the goal within 8 simulated minutes")
	check(total_cheese(m) == before, "cheese is conserved over a full match (%d vs %d)" % [total_cheese(m), before])
	for r in m.rats:
		check(not r.blocked(), "bot %d is not embedded in terrain" % r.id)
	end(m)


# ================================================================== siege & advanced voxel tools

func mask_layers(n: int) -> PackedByteArray:
	## A block mask with only the bottom n microvoxel layers present.
	var mask := PackedByteArray()
	mask.resize(Blocks.MICRO_COUNT)
	for y in n:
		for z in 7:
			for x in 7:
				mask[x + 7 * (z + 7 * y)] = 1
	return mask


func chisel(m: Match, r: Rat, cell: Vector3i, mv: Vector3i, add := false, mat := "stone") -> String:
	r.chisel_cd = 0.0
	return m.try_chisel_add(r, cell, mv, mat) if add else m.try_chisel_remove(r, cell, mv)


func test_stone_and_obsidian() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var stone := ARENA + Vector3i(1, 0, 0)
	var obs := ARENA + Vector3i(0, 0, 1)
	m.world.set_block(stone, Blocks.STONE)
	m.world.set_block(obs, Blocks.OBSIDIAN)
	var n := 0
	while m.world.get_cell(stone) == Blocks.STONE and n < 40:
		r.dig_cd = 0.0
		m.try_dig(r, stone)
		n += 1
	check(n == 4 and int(r.mats["stone"]) == 1, "stone: 4 dig hits, yields stone (%d)" % n)
	n = 0
	while m.world.get_cell(obs) == Blocks.OBSIDIAN and n < 40:
		r.dig_cd = 0.0
		m.try_dig(r, obs)
		n += 1
	check(n == Blocks.OBSIDIAN_HITS and n == 12, "obsidian: 12 dig hits (%d)" % n)
	check(int(r.mats["obsidian"]) == 1, "obsidian yields its own material")
	check(m.try_place_mat(r, obs, "obsidian") == "" and m.world.get_cell(obs) == Blocks.OBSIDIAN, "obsidian can be built with")
	m.world.set_block(obs, Blocks.AIR)   # count only generated obsidian
	var per_half := [0, 0]
	for i in m.world.data.size():
		if m.world.data[i] == Blocks.OBSIDIAN:
			per_half[0 if (i % VoxelWorld.SX) < VoxelWorld.SX / 2 else 1] += 1
	check(per_half[0] == per_half[1] and per_half[0] > 30, "obsidian formations are mirrored (%d per side)" % per_half[0])
	for team in 2:
		var sp := MapGenerator.spawn_point(team)
		check(m.world.block_at(sp + Vector3(0, 0.5, 0)) == Blocks.AIR, "spawn %d is not buried" % team)
	end(m)


func test_chisel_rules() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var cell := ARENA + Vector3i(1, 0, 0)
	m.world.set_block(cell, Blocks.STONE)
	var hit := m.world.raycast_micro(r.eye(), Vector3(1, -0.3, 0), 5.0)
	check(not hit.is_empty() and hit["cell"] == cell and hit["normal"] == Vector3i(-1, 0, 0), "micro ray finds the block face")
	check(not hit.is_empty() and Vector3i(hit["micro"]).x == 0, "micro ray reports the microvoxel on that face")
	check(m.try_chisel_remove(r, cell, Vector3i(0, 3, 3)) == "", "chisel carves one microvoxel")
	check(m.world.has_micro(cell) and m.world.micro_count(cell) == 342, "exactly one of 343 removed")
	check(m.world.get_cell(cell) == Blocks.STONE, "the parent block is still stone")
	check(m.try_chisel_remove(r, cell, Vector3i(0, 3, 4)) == "wait", "chisel has its own rate limit")
	check(chisel(m, r, cell, Vector3i(0, 3, 3)) != "", "cannot carve what is already gone")
	hit = m.world.raycast_micro(Vector3(cell) + Vector3(-0.5, 3.5 / 7.0, 3.5 / 7.0), Vector3(1, 0, 0), 5.0)
	check(not hit.is_empty() and Vector3i(hit["micro"]) == Vector3i(1, 3, 3), "ray passes through the carved hole to the next microvoxel")
	# ordinary digging still removes the whole block
	var n := 0
	while m.world.get_cell(cell) != Blocks.AIR and n < 20:
		r.dig_cd = 0.0
		m.try_dig(r, cell)
		n += 1
	check(n == 4 and not m.world.has_micro(cell) and not m.world.micro.has(cell), "Dig removes the whole carved block and its mask")
	# carve a block away completely
	m.world.set_block(cell, Blocks.DIRT)
	for y in 7:
		for z in 7:
			for x in 7:
				chisel(m, r, cell, Vector3i(x, y, z))
	check(m.world.get_cell(cell) == Blocks.AIR and not m.world.micro.has(cell), "removing all 343 microvoxels removes the block")
	for bad: int in [Blocks.CHEESE, Blocks.SCRAP, Blocks.TNT, Blocks.LADDER]:
		m.world.set_block(cell, bad)
		check(chisel(m, r, cell, Vector3i(0, 3, 3)) != "" and not m.world.has_micro(cell), "%s cannot be chiseled" % Blocks.block_name(bad))
	r.position = Vector3(14.0, MapGenerator.GROUND, 10.5)
	r.mats["stone"] = 5
	check(chisel(m, r, Vector3i(12, MapGenerator.GROUND - 1, 10), Vector3i(6, 6, 3)) != "", "base blocks cannot be carved")
	check(chisel(m, r, Vector3i(12, MapGenerator.GROUND, 10), Vector3i(6, 0, 3), true) != "", "cannot chisel material into a base")
	end(m)


func test_chisel_economy_is_zero_sum() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var air := ARENA + Vector3i(1, 0, 0)
	check(chisel(m, r, air, Vector3i(0, 0, 3), true) != "", "adding needs material")
	r.mats["stone"] = 1
	check(chisel(m, r, air, Vector3i(0, 0, 3), true) == "", "adds a microvoxel into empty space")
	check(m.world.get_cell(air) == Blocks.STONE and m.world.micro_count(air) == 1, "a one-microvoxel stone block exists")
	check(int(r.mats["stone"]) == 0 and int(r.micro_bank["stone"]) == 342, "one block was broken into 343 microvoxels, one spent")
	# the exploit this must stop: 1 microvoxel placed, whole block dug back out
	for i in 6:
		r.dig_cd = 0.0
		m.try_dig(r, air)
	check(m.world.get_cell(air) == Blocks.AIR, "dig removes the sliver")
	check(int(r.mats["stone"]) == 1 and int(r.micro_bank["stone"]) == 0, "digging a sliver returns a sliver, not a block")
	# carve and refill repeatedly: totals never change
	var solid := ARENA + Vector3i(0, 0, 1)
	m.world.set_block(solid, Blocks.STONE)
	for i in 20:
		chisel(m, r, solid, Vector3i(3, 3, 0))
		chisel(m, r, solid, Vector3i(3, 3, 0), true)
	check(int(r.mats["stone"]) * 343 + int(r.micro_bank["stone"]) == 343, "20 carve/refill cycles create nothing")
	check(not m.world.has_micro(solid), "a refilled block is a plain block again")
	check(chisel(m, r, solid, Vector3i(3, 3, 3), true) != "", "cannot add into a filled spot")
	end(m)


func test_chisel_collision_and_steps() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "scout", Vector3(-3, 0, 0))
	run(m, 0.3)
	# a 4-microvoxel ledge is climbed automatically
	m.world.set_mask(ARENA + Vector3i(0, 0, 0), Blocks.STONE, mask_layers(4))
	for dz in [-1, 1]:
		m.world.set_mask(ARENA + Vector3i(0, 0, dz), Blocks.STONE, mask_layers(4))
	r.wish = Vector3(1, 0, 0)
	run(m, 0.55)
	check(absf(r.position.y - (ARENA.y + 4.0 / 7.0)) < 0.03 and r.position.x > ARENA.x, "auto-climbs a 4-microvoxel step (y=%.3f)" % (r.position.y - ARENA.y))
	check(r.on_floor, "stands on carved geometry")
	run(m, 0.6)
	check(absf(r.position.y - ARENA.y) < 0.03 and r.position.x > ARENA.x + 1.3, "steps back down off it")
	# a 5-microvoxel ledge is not
	r.position = Vector3(ARENA) + Vector3(2.5, 0, 0.5)
	r.vel = Vector3.ZERO
	for dz in range(-8, 9):
		m.world.set_mask(ARENA + Vector3i(4, 0, dz), Blocks.STONE, mask_layers(5))
	run(m, 1.5)
	check(r.position.x < ARENA.x + 4.0 - Rat.RADIUS + 0.02 and r.position.y < ARENA.y + 0.05, "a 5-microvoxel ledge needs a jump (x=%.3f y=%.3f)" % [r.position.x - ARENA.x, r.position.y - ARENA.y])
	r.jump_pressed = true
	run(m, 0.8)
	check(r.position.x > ARENA.x + 4.0, "and a jump clears it")
	# a carved doorway: remove the lower part of a wall block and walk through
	r.wish = Vector3.ZERO
	var wall := ARENA + Vector3i(-5, 0, 4)
	var mask := PackedByteArray()
	mask.resize(343)
	for z in 7:
		for x in 7:
			mask[x + 7 * (z + 7 * 6)] = 1   # only the top layer remains: 6/7 of headroom < rat height
	m.world.set_mask(wall, Blocks.STONE, mask)
	r.position = Vector3(wall) + Vector3(0.5, 0, 1.5)
	r.vel = Vector3.ZERO
	r.wish = Vector3(0, 0, -1)
	run(m, 0.6)
	check(r.position.z > wall.z + 1.0, "a gap lower than the rat is still a wall")
	m.world.set_block(wall, Blocks.AIR)
	# stairs carved out of solid blocks: 3 rising treads
	end(m)


func test_chisel_persists() -> void:
	var m := new_match()
	flat_arena(m, ARENA)
	var r := arena_rat(m, 0, "scout")
	var cell := ARENA + Vector3i(1, 0, 0)
	m.world.set_block(cell, Blocks.OBSIDIAN)
	for mv: Vector3i in [Vector3i(0, 0, 0), Vector3i(0, 6, 6), Vector3i(0, 3, 3), Vector3i(1, 3, 3)]:
		check(chisel(m, r, cell, mv) == "", "obsidian can be chiseled")
	var before: PackedByteArray = (m.world.micro[cell] as PackedByteArray).duplicate()
	var path := "user://test_maps/carved.bwmap"
	check(m.world.save_to(path), "carved map saves")
	m.world.set_block(cell, Blocks.AIR)
	check(not m.world.micro.has(cell), "carving cleared with the block")
	check(m.world.load_from(path), "carved map loads")
	check(m.world.get_cell(cell) == Blocks.OBSIDIAN and m.world.has_micro(cell), "carved block is back")
	check(m.world.micro.has(cell) and (m.world.micro[cell] as PackedByteArray) == before, "every microvoxel edit survived save and reload")
	check(m.world.micro.size() == 1, "untouched blocks carry no microvoxel data")
	end(m)


func test_pantograph() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var r := arena_rat(m, 0, "builder")
	var a := ARENA + Vector3i(2, 0, 0)
	m.world.set_block(a, Blocks.STONE)
	m.world.set_block(a + Vector3i(1, 0, 0), Blocks.ICE)
	m.world.set_block(a + Vector3i(0, 1, 0), Blocks.CHEESE)
	m.world.set_block(a + Vector3i(1, 1, 0), Blocks.TNT)
	m.world.set_block(a + Vector3i(0, 0, 1), Blocks.SCRAP)
	var carved := mask_layers(3)
	carved[0] = 0   # an asymmetric notch so rotation is observable
	m.world.set_mask(a + Vector3i(1, 0, 1), Blocks.ICE, carved)
	var res := m.copy_region(r, a, a + Vector3i(1, 1, 1))
	check(res.has("blueprint"), "copies a region")
	var bp: Blueprint = res["blueprint"]
	check(bp.size == Vector3i(2, 2, 2) and bp.cells.size() == 3, "captures the 3 material blocks (%d)" % bp.cells.size())
	check(bp.skipped == 3, "cheese, TNT and scrap are never captured (%d skipped)" % bp.skipped)
	var need := bp.cost()
	check(int(need["stone"]) == 343 and int(need["ice"]) == 343 + 146, "material estimate counts carvings exactly")
	check(m.copy_region(r, a, a + Vector3i(12, 0, 0)).has("error"), "oversized selections are refused")
	# rotation
	var rot := bp.rotated()
	check(rot.size == Vector3i(2, 2, 2) and rot.cells.size() == 3, "rotates by a quarter turn")
	var four := bp.rotated().rotated().rotated().rotated()
	var same := true
	for i in bp.cells.size():
		var found := false
		for e in four.cells:
			if e["o"] == bp.cells[i]["o"] and e["id"] == bp.cells[i]["id"] and e["mask"] == bp.cells[i]["mask"]:
				found = true
		same = same and found
	check(same, "four quarter turns restore the original, carvings included")
	var notch_moved := false
	for e in rot.cells:
		if e["mask"] != null:
			var mk: PackedByteArray = e["mask"]
			notch_moved = mk[0] == 1 and mk[6] == 0 and mk.count(1) == 146
			check(e["o"] == Vector3i(0, 0, 1), "rotated block lands in the rotated position")
	check(notch_moved, "the carving itself is rotated with its block")
	# placement rules
	var dest := ARENA + Vector3i(-5, 0, -2)
	check(m.try_paste(r, bp, dest) != "", "refused without materials")
	check(m.world.get_cell(dest) == Blocks.AIR, "a refused paste builds nothing")
	r.mats["stone"] = 1
	r.mats["ice"] = 1
	check(m.try_paste(r, bp, dest).begins_with("Not enough ice"), "refused when one material is short")
	check(int(r.mats["stone"]) == 1 and int(r.mats["ice"]) == 1, "a refused paste costs nothing")
	r.mats["ice"] = 2
	check(m.paste_check(r, bp, dest) == "" and m.try_paste(r, bp, dest) == "", "pastes when affordable")
	check(m.world.get_cell(dest) == Blocks.STONE and m.world.get_cell(dest + Vector3i(1, 0, 0)) == Blocks.ICE, "blocks reproduced")
	check(m.world.get_cell(dest + Vector3i(0, 1, 0)) == Blocks.AIR and m.world.get_cell(dest + Vector3i(1, 1, 0)) == Blocks.AIR, "no cheese or TNT was duplicated")
	var pasted := dest + Vector3i(1, 0, 1)
	check(m.world.has_micro(pasted) and (m.world.micro[pasted] as PackedByteArray) == carved, "carved block reproduced microvoxel for microvoxel")
	check(int(r.mats["stone"]) == 0 and int(r.mats["ice"]) * 343 + int(r.micro_bank.get("ice", 0)) == 686 - 489, "exact materials deducted")
	check(m.try_paste(r, bp, dest) != "", "cannot paste into occupied space")
	r.mats["stone"] = 9
	r.mats["ice"] = 9
	check(m.try_paste(r, bp, r.feet_cell() - Vector3i(0, 0, 0)) != "", "cannot paste on top of a rat")
	r.position = Vector3(15.0, MapGenerator.GROUND, 10.5)
	check(m.try_paste(r, bp, Vector3i(11, MapGenerator.GROUND, 10)) == "Bases are protected", "cannot paste into a base")
	# a forged blueprint is rejected by the authority
	var forged := Blueprint.new()
	forged.size = Vector3i.ONE
	forged.cells.append({"o": Vector3i.ZERO, "id": Blocks.CHEESE, "mask": null})
	check(m.try_paste(r, forged, Vector3i(20, MapGenerator.GROUND + 6, 24)) != "", "a blueprint containing cheese is rejected")
	end(m)
	var f := new_match({"mode": "free"})
	var maestro := f.spawn_rat(0, "maestro", false)
	maestro.position = Vector3(40, 41, 10)
	check(f.try_paste(maestro, bp, Vector3i(40, 41, 12)) == "", "Chisel Maestro pastes without materials in Free Build")
	end(f)


func drop_stick(m: Match, at: Vector3, vel := Vector3.ZERO, fuse := 30.0) -> DynamiteSystem.Stick:
	return m.dynamite.spawn(at, vel, -1, fuse)


func test_dynamite_physics() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 10)
	for i in range(-11, 12):   # a walled yard, so a thrown stick rebounds instead of leaving the test
		for dy in 4:
			for edge: Vector3i in [Vector3i(i, dy, -11), Vector3i(i, dy, 11), Vector3i(-11, dy, i), Vector3i(11, dy, i)]:
				m.world.set_block(ARENA + edge, Blocks.OBSIDIAN)
	var r := arena_rat(m, 0, "saboteur", Vector3(-6, 0, 0))
	run(m, 0.3)
	var have := int(r.gadgets["dynamite"])
	r.equipped = "dynamite"
	check(m.try_use_equipped(r, {}, Vector3(1, 0.3, 0), false) == "", "throws Mobile TNT")
	check(int(r.gadgets["dynamite"]) == have - 1 and m.dynamite.sticks.size() == 1, "one stick consumed, one in flight")
	check(m.try_use_equipped(r, {}, Vector3(1, 0.3, 0), false) == "wait", "throws are rate limited")
	var s: DynamiteSystem.Stick = m.dynamite.sticks[0]
	var bounces := 0
	var was_falling := false
	var max_after_bounce := 0.0
	var t := 0.0
	var finite := true
	while m.dynamite.sticks.size() > 0 and t < 6.0:
		m.step(DT)
		t += DT
		finite = finite and is_finite(s.pos.x) and is_finite(s.pos.y) and absf(s.pos.x - ARENA.x) < 30.0 and s.pos.y > ARENA.y - 0.5
		if was_falling and s.vel.y > 0.5:
			bounces += 1
		was_falling = s.vel.y < -0.5
		if bounces > 0:
			max_after_bounce = maxf(max_after_bounce, s.pos.y - ARENA.y)
	check(bounces >= 2, "stick bounces (%d bounces)" % bounces)
	check(max_after_bounce > 0.35, "bounce has real height (%.2f)" % max_after_bounce)
	check(finite, "stick stays finite, above the floor and nearby")
	check(absf(t - Config.DYNAMITE_FUSE) < 0.1, "detonates when the %.1f s fuse runs out (%.2f)" % [Config.DYNAMITE_FUSE, t])
	check(s.pos.x > ARENA.x - 4.0, "thrown stick travelled (%.1f blocks)" % (s.pos.x - (ARENA.x - 6.0)))
	# gentle placement stays close
	r.throw_cd = 0.0
	m.try_use_equipped(r, {}, Vector3(1, 0, 0), true)
	var g: DynamiteSystem.Stick = m.dynamite.sticks[0]
	run(m, 1.5)
	check(absf(g.pos.x - r.position.x) < 2.0 and g.resting, "Ctrl+Q sets it down nearby (%.2f)" % absf(g.pos.x - r.position.x))
	# ice vs stone: same shove, ice slides further
	m.dynamite.sticks.clear()
	for i in 14:
		m.world.set_block(ARENA + Vector3i(-7 + i, -1, 5), Blocks.ICE)
	var on_ice := drop_stick(m, Vector3(ARENA) + Vector3(-6.5, 0.2, 5.5), Vector3(5, 0, 0))
	var on_stone := drop_stick(m, Vector3(ARENA) + Vector3(-6.5, 0.2, 8.5), Vector3(5, 0, 0))
	run(m, 3.0)
	check(on_ice.pos.x - on_stone.pos.x > 2.0, "ice: slides much further (%.1f vs %.1f)" % [on_ice.pos.x - ARENA.x + 6.5, on_stone.pos.x - ARENA.x + 6.5])
	# rolls down carved stairs
	m.dynamite.sticks.clear()
	for i in 4:
		m.world.set_mask(ARENA + Vector3i(i, 0, -5), Blocks.STONE, mask_layers(7 - i * 2 if i < 3 else 1))
	var roller := drop_stick(m, Vector3(ARENA) + Vector3(0.5, 1.3, -4.5), Vector3(2.5, 0, 0))
	run(m, 2.5)
	check(roller.pos.x > ARENA.x + 2.0 and roller.pos.y < ARENA.y + 0.6, "tumbles down carved steps (x=%.1f y=%.2f)" % [roller.pos.x - ARENA.x, roller.pos.y - ARENA.y])
	end(m)


func test_dynamite_traps() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 10)
	# spring launches it
	m.world.set_block(ARENA + Vector3i(0, 0, 0), Blocks.SPRING)
	var s := drop_stick(m, Vector3(ARENA) + Vector3(0.5, 2.0, 0.5))
	var top := 0.0
	for i in 150:
		m.step(DT)
		top = maxf(top, s.pos.y - ARENA.y)
	check(top > 4.0, "spring launches dynamite (%.1f blocks up)" % top)
	check(is_finite(s.pos.y) and s.pos.y < ARENA.y + 12.0 and m.dynamite.sticks.has(s), "spring bouncing stays stable")
	m.dynamite.sticks.clear()
	m.world.set_block(ARENA, Blocks.AIR)
	# conveyor carries it in its direction
	for i in 6:
		m.world.set_block(ARENA + Vector3i(i - 2, -1, 3), Blocks.CONV_XP)
	s = drop_stick(m, Vector3(ARENA) + Vector3(-1.5, 0.3, 3.5))
	run(m, 1.5)
	check(s.pos.x > ARENA.x + 1.0, "conveyor carries dynamite along (+%.1f)" % (s.pos.x - ARENA.x + 1.5))
	m.dynamite.sticks.clear()
	# sticky trap stops it
	m.world.set_block(ARENA + Vector3i(2, 0, -3), Blocks.STICKY_RED)
	s = drop_stick(m, Vector3(ARENA) + Vector3(-2.5, 0.2, -2.5), Vector3(7, 0, 0))
	var free_roll := drop_stick(m, Vector3(ARENA) + Vector3(-2.5, 0.2, -5.5), Vector3(7, 0, 0))
	run(m, 2.0)
	check(floori(s.pos.x) == ARENA.x + 2 and s.vel.length() < 0.1, "sticky trap stops dynamite on the pad (x=%.2f)" % (s.pos.x - ARENA.x))
	check(free_roll.pos.x > s.pos.x + 0.5, "without glue it would have rolled on")
	m.dynamite.sticks.clear()
	# mouse trap snaps and jolts it
	var trap := ARENA + Vector3i(-4, 0, 6)
	m.world.set_block(trap, Blocks.TRAP_BLUE)
	s = drop_stick(m, Vector3(trap) + Vector3(0.5, 1.0, 0.5))
	var jolt := 0.0
	for i in 60:
		m.step(DT)
		jolt = maxf(jolt, s.vel.y)
	check(m.world.get_cell(trap) == Blocks.AIR and jolt > 5.0, "mouse trap snaps shut and jolts the stick")
	m.dynamite.sticks.clear()
	# pitfall: falls straight through
	var pit := ARENA + Vector3i(5, -1, 6)
	m.world.set_block(pit, Blocks.PIT_BLUE)
	s = drop_stick(m, Vector3(pit) + Vector3(0.5, 2.0, 0.5))
	run(m, 1.0)
	check(s.pos.y < ARENA.y - 1.5, "dynamite drops through a pitfall")
	m.dynamite.sticks.clear()
	# wall spring bats it back
	for dy in 2:
		m.world.set_block(ARENA + Vector3i(4, dy, -7), Blocks.WALL_SPRING)
	s = drop_stick(m, Vector3(ARENA) + Vector3(1.5, 0.3, -6.5), Vector3(6, 0, 0))
	var back := 0.0
	for i in 60:
		m.step(DT)
		back = minf(back, s.vel.x)
	check(back < -8.0, "wall spring deflects dynamite hard (%.1f)" % back)
	end(m)


func test_dynamite_blast() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var booms: Array[Vector3] = []
	m.fx.connect(func(kind: String, pos: Vector3, _d: Variant) -> void:
		if kind == "boom":
			booms.append(pos))
	var near := arena_rat(m, 1, "scout", Vector3(1.5, 0, 0))
	near.carried = 2
	var before := total_cheese(m)
	var dirt := ARENA + Vector3i(0, 0, 1)
	var far_dirt := ARENA + Vector3i(0, 0, 2)
	var stone := ARENA + Vector3i(-1, 0, 0)
	var far_stone := ARENA + Vector3i(-2, 0, 0)
	var obs := ARENA + Vector3i(0, 0, -1)
	var carved := ARENA + Vector3i(1, 0, 1)
	var tnt := ARENA + Vector3i(-1, 0, -2)
	var chained := ARENA + Vector3i(-3, 0, -3)
	m.world.set_block(dirt, Blocks.DIRT)
	m.world.set_block(far_dirt, Blocks.DIRT)
	m.world.set_block(stone, Blocks.STONE)
	m.world.set_block(far_stone, Blocks.STONE)
	m.world.set_block(obs, Blocks.OBSIDIAN)
	m.world.set_mask(carved, Blocks.DIRT, mask_layers(5))
	m.world.set_block(tnt, Blocks.TNT)
	m.world.set_block(chained, Blocks.STONE)
	var s := drop_stick(m, Vector3(ARENA) + Vector3(0.5, 0.2, 0.5), Vector3.ZERO, 0.5)
	var other := drop_stick(m, Vector3(ARENA) + Vector3(1.5, 0.2, -0.5), Vector3.ZERO, 30.0)
	run(m, 0.55)
	check(booms.size() == 1, "stick explodes")
	check(m.world.get_cell(dirt) == Blocks.AIR, "adjacent dirt is destroyed")
	check(m.world.get_cell(stone) == Blocks.STONE and int(m.world.damage.get(stone, 0)) > 0, "adjacent stone is cracked, not removed (damage %d of 4)" % int(m.world.damage.get(stone, 0)))
	check(int(m.world.damage.get(far_stone, 0)) < int(m.world.damage.get(stone, 0)), "damage falls off with distance")
	check(m.world.get_cell(far_dirt) == Blocks.DIRT, "dirt two blocks out survives a small charge")
	check(m.world.get_cell(obs) == Blocks.OBSIDIAN and int(m.world.damage.get(obs, 0)) <= 4, "obsidian resists")
	check(m.world.get_cell(carved) == Blocks.AIR and not m.world.micro.has(carved) and not m.world.has_micro(carved), "carved block removed cleanly: no leftover microvoxels")
	check(near.knock > 0.0 and near.vel.length() > 5.0, "nearby rat is knocked back")
	check(near.carried == 1, "and drops one cheese")
	check(m.rats.has(near) and near.position.distance_to(MapGenerator.spawn_point(1)) > 20.0, "nobody is killed or sent home by a blast")
	run(m, 0.6)
	check(booms.size() >= 3, "chain reaction: the other stick and the TNT block go off (%d blasts)" % booms.size())
	check(not m.dynamite.sticks.has(other) and m.world.get_cell(tnt) == Blocks.AIR, "chained charges are spent")
	check(m.world.get_cell(chained) == Blocks.AIR or int(m.world.damage.get(chained, 0)) > 0, "the chained TNT damaged terrain the stick could not reach")
	check(total_cheese(m) == before, "blasts never create or destroy cheese")
	check(m.world.micro.is_empty(), "no stray carving data after the chain")
	# same rule for both explosives
	check(Config.TNT_POWER > Config.DYNAMITE_POWER and Config.TNT_RADIUS > Config.DYNAMITE_RADIUS, "stationary TNT stays the bigger charge")
	end(m)


func test_new_traps_vs_rats() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var owner := arena_rat(m, 0, "scout")
	var foe := arena_rat(m, 1, "scout", Vector3(0, 0, 3))
	# pitfall: floor for owners, hole for enemies
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			m.world.set_block(ARENA + Vector3i(dx, -1, dz), Blocks.PIT_BLUE)
			m.world.set_block(ARENA + Vector3i(dx, -1, 3 + dz), Blocks.PIT_BLUE)
	run(m, 0.6)
	check(owner.on_floor and absf(owner.position.y - ARENA.y) < 0.02, "owner stands on its pitfall")
	check(foe.position.y < ARENA.y - 1.0, "enemy falls through it")
	# sticky trap slows enemies only
	foe.position = Vector3(ARENA) + Vector3(5.5, 0, 5.5)
	owner.position = Vector3(ARENA) + Vector3(5.5, 0, -5.5)
	foe.vel = Vector3.ZERO
	m.world.set_block(ARENA + Vector3i(5, 0, 5), Blocks.STICKY_BLUE)
	m.world.set_block(ARENA + Vector3i(5, 0, -5), Blocks.STICKY_BLUE)
	run(m, 0.2)
	check(foe.slow > 0.0 and owner.slow <= 0.0, "sticky trap slows enemies, not its owners")
	# wall spring flings a rat that runs into it
	for dy in 2:
		m.world.set_block(ARENA + Vector3i(-4, dy, 6), Blocks.WALL_SPRING)
	owner.position = Vector3(ARENA) + Vector3(-1.5, 0, 6.5)
	owner.vel = Vector3.ZERO
	owner.wish = Vector3(-1, 0, 0)
	var flung := 0.0
	for i in 60:
		m.step(DT)
		flung = maxf(flung, owner.vel.x)
	check(flung > 8.0, "wall spring launches a rat back the way it came (%.1f)" % flung)
	end(m)


func siege_setup(kind: String, extra: Dictionary = {}) -> Array:
	## [match, operator rat, machine] with the machine at ARENA facing +X.
	var m := new_match(extra)
	flat_arena(m, ARENA, 9)
	var r := arena_rat(m, 0, "builder", Vector3(-1, 0, 0))
	r.yaw = -PI / 2.0
	r.gadgets[kind] = 1
	check(m.try_place_gadget(r, ARENA, kind) == "", "%s placed from the pack" % kind)
	var mc: SiegeSystem.Machine = m.siege.machines.get(ARENA)
	check(mc != null and mc.team == 0 and mc.owner == r.id, "%s is registered to its owner" % kind)
	check(m.siege.try_operate(r, ARENA) == "" and r.operating == mc.uid, "owner takes the controls")
	return [m, r, mc]


func test_cannon() -> void:
	var setup := siege_setup("cannon")
	var m: Match = setup[0]
	var r: Rat = setup[1]
	var mc: SiegeSystem.Machine = setup[2]
	for dz in range(-3, 4):
		for dy in 5:
			m.world.set_block(ARENA + Vector3i(7, dy, dz), Blocks.STONE)
	var kinds := {}
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds[kind] = true)
	m.siege.aim(r, -PI / 2.0, 0.06)
	check(absf(mc.yaw + PI / 2.0) < 0.001 and absf(mc.pitch - 0.06) < 0.001, "rotation and elevation follow the operator")
	m.siege.aim(r, 0.3, 3.0)
	check(mc.pitch <= 1.2, "elevation is limited")
	m.siege.aim(r, -PI / 2.0, 0.06)
	var arc := m.siege.predict(mc)
	check(arc.size() >= 2 and floori(arc[-1].x) == ARENA.x + 7, "aiming preview ends on the wall")
	r.scrap = 7
	check(m.siege.fire(r) == "" and m.siege.shots.size() == 1, "fires a physical projectile")
	check(r.scrap == 5, "a shot costs the gunner %d scrap (%d left)" % [Config.CANNON_SCRAP, r.scrap])
	check(m.siege.fire(r) == "wait", "cannon has a cooldown")
	var travelled := 0
	while m.siege.shots.size() > 0 and travelled < 200:
		m.step(DT)
		travelled += 1
	check(travelled > 5 and travelled < 60, "projectile takes visible time to arrive (%d ticks)" % travelled)
	var three := 0
	var twos := 0
	var ones := 0
	var struck := Vector3i.ZERO
	for c: Vector3i in m.world.damage:
		if int(m.world.damage[c]) == 3:
			three += 1
			struck = c
		elif int(m.world.damage[c]) == 2:
			twos += 1
		elif int(m.world.damage[c]) == 1:
			ones += 1
	check(three == 1 and struck.x == ARENA.x + 7, "struck block takes 3x dig damage")
	# the wall is one block thick, so the 3x3x3 blast finds 9 of its blocks
	var faces_ok := true
	for n: Vector3i in [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		faces_ok = faces_ok and int(m.world.damage.get(struck + n, 0)) == 2
	var corners_ok := true
	for n: Vector3i in [Vector3i(0, 1, 1), Vector3i(0, 1, -1), Vector3i(0, -1, 1), Vector3i(0, -1, -1)]:
		corners_ok = corners_ok and int(m.world.damage.get(struck + n, 0)) == 1
	check(twos == 4 and faces_ok, "the blocks touching it take 2 hits (%d)" % twos)
	check(ones == 4 and corners_ok, "the blast reaches the corners of a 3x3x3 too, for 1 hit (%d)" % ones)
	check(arc[-1].distance_to(Vector3(struck) + Vector3(0.5, 0.5, 0.5)) < 1.2, "shot lands where the preview said")
	check(kinds.has("cannon") and kinds.has("impact"), "firing and impact feedback are emitted")
	# second shot at the same spot: stone (4) breaks, neighbours are at 2
	run(m, Config.CANNON_COOLDOWN + 0.1)
	m.siege.fire(r)
	run(m, 1.0)
	check(m.world.get_cell(struck) == Blocks.AIR, "a second hit breaks the stone")
	var holes := 0
	for n: Vector3i in [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		holes += 1 if m.world.get_cell(struck + n) == Blocks.AIR else 0
	check(holes == 4, "and the four stones touching it (2 + 2 hits)")
	check(int(r.mats["stone"]) == 5, "cannon-mined stone goes to the gunner (%d)" % int(r.mats["stone"]))
	# obsidian resists by its durability
	m.world.set_block(struck, Blocks.OBSIDIAN)
	run(m, Config.CANNON_COOLDOWN)
	m.siege.fire(r)
	run(m, 1.0)
	check(m.world.get_cell(struck) == Blocks.OBSIDIAN and int(m.world.damage.get(struck, 0)) == 3, "obsidian takes the hit and stands (3 of 12)")
	# out of scrap: no shot
	run(m, Config.CANNON_COOLDOWN)
	check(r.scrap == 1 and m.siege.fire(r).begins_with("Each shot costs") and m.siege.shots.is_empty(), "with under 2 scrap it won't fire")
	# knockback: a direct hit throws a rat hard, and the blast shoves the rats around it
	var foe := arena_rat(m, 1, "scout", Vector3(4.5, 0, 0))
	var near := arena_rat(m, 1, "digger", Vector3(6.0, 0, 1.6))
	var mate := arena_rat(m, 0, "digger", Vector3(6.0, 0, -1.6))
	run(m, 0.3)
	r.scrap = 10
	var shot := SiegeSystem.Shot.new()
	shot.pos = foe.center() - Vector3(1.0, 0, 0)
	shot.vel = Vector3(Config.CANNON_SPEED, 0, 0)
	shot.owner = r.id
	shot.team = 0
	m.siege._fly(shot, 0.1)
	check(foe.vel.x > 10.0 and foe.vel.y > 5.0 and foe.knock > 0.0, "a direct hit throws a rat hard (%s)" % str(foe.vel))
	shot = SiegeSystem.Shot.new()
	shot.pos = Vector3(ARENA) + Vector3(6.5, 0.5, 0.5)
	shot.vel = Vector3(Config.CANNON_SPEED, 0, 0)
	shot.owner = r.id
	shot.team = 0
	m.siege._impact(shot)
	check(near.vel.length() > 5.0 and near.vel.z > 0.0 and near.knock > 0.0, "the blast shoves an enemy beside it away (%s)" % str(near.vel))
	check(mate.knock <= 0.0 and mate.vel.length() < 1.0, "but not the gunner's teammate")
	# leaving restores normal movement
	check(r.operating != -1, "still at the controls")
	m.siege.release(r)
	check(r.operating == -1 and mc.operator == -1, "leaving frees the machine")
	var x0 := r.position.x
	r.wish = Vector3(-1, 0, 0)
	run(m, 0.5)
	check(r.position.x < x0 - 1.0, "normal movement works again")
	end(m)


func test_crane_and_dozer() -> void:
	var setup := siege_setup("crane")
	var m: Match = setup[0]
	var r: Rat = setup[1]
	var mc: SiegeSystem.Machine = setup[2]
	m.siege.aim(r, -PI / 2.0, 0.0)
	var column: Array[Vector3i] = [ARENA + Vector3i(4, 0, 0), ARENA + Vector3i(4, 1, 0)]
	for c in column:
		m.world.set_block(c, Blocks.STONE)
	var rest := SiegeSystem.ball_pos(mc)
	check(absf(rest.x - (ARENA.x + 3.0)) < 0.01 and absf(rest.y - (ARENA.y + 0.6)) < 0.01, "ball hangs from the boom tip")
	var max_speed := 0.0
	var max_jump := 0.0
	var last := rest
	var damaged := false
	var t := 0.0
	while t < 10.0:
		m.siege.fire(r)
		m.step(DT)
		t += DT
		var ball := SiegeSystem.ball_pos(mc)
		max_jump = maxf(max_jump, ball.distance_to(last))
		last = ball
		max_speed = maxf(max_speed, absf(mc.omega) * SiegeSystem.CRANE_CABLE)
		for c in column:
			if m.world.get_cell(c) == Blocks.AIR or int(m.world.damage.get(c, 0)) > 0:
				damaged = true
	check(max_speed > 4.0, "pumping builds up a real swing (%.1f blocks/s)" % max_speed)
	check(max_speed < 12.0 and max_jump < 0.3, "swing is smooth and bounded (max %.2f per tick)" % max_jump)
	check(damaged, "the ball damages what it hits")
	check(m.world.get_cell(column[0]) == Blocks.AIR, "repeated blows break stone")
	check(m.world.get_cell(ARENA) == Blocks.CRANE and m.siege.machines.has(ARENA), "the crane never damages itself")
	check(m.world.get_cell(ARENA + Vector3i(3, -1, 0)) == Blocks.STONE, "the floor under the swing is untouched")
	# slow contact does nothing
	m.world.set_block(column[0], Blocks.OBSIDIAN)
	mc.theta = 0.0
	mc.omega = 0.3
	m.siege.release(r)
	run(m, 3.0)
	check(int(m.world.damage.get(column[0], 0)) == 0, "a gentle nudge does no damage: impact depends on speed")
	end(m)

	setup = siege_setup("dozer")
	m = setup[0]
	r = setup[1]
	mc = setup[2]
	m.siege.aim(r, -PI / 2.0, 0.0)
	var cells := SiegeSystem.dozer_cells(mc)
	check(cells.size() == 6, "blade covers 3 wide x 2 high")
	for c in cells:
		check(c.x == ARENA.x + 1, "blade area is directly ahead")
		m.world.set_block(c, Blocks.DIRT)
	m.world.set_block(ARENA + Vector3i(2, 0, 0), Blocks.DIRT)
	m.world.set_block(ARENA + Vector3i(1, 2, 0), Blocks.DIRT)
	check(m.siege.fire(r) == "", "blade rams")
	var cleared := 0
	for c in cells:
		if m.world.get_cell(c) == Blocks.AIR:
			cleared += 1
	check(cleared == 6, "dirt in the blade area is cleared in one ram (%d of 6)" % cleared)
	check(m.world.get_cell(ARENA + Vector3i(2, 0, 0)) == Blocks.DIRT and m.world.get_cell(ARENA + Vector3i(1, 2, 0)) == Blocks.DIRT, "nothing outside the blade area is touched")
	check(int(r.mats["dirt"]) == 6, "bulldozed dirt goes to the driver")
	check(m.siege.fire(r) == "wait", "blade has a cooldown")
	m.world.set_block(cells[0], Blocks.STONE)
	run(m, Config.DOZER_COOLDOWN + 0.05)
	m.siege.fire(r)
	check(m.world.get_cell(cells[0]) == Blocks.STONE and int(m.world.damage[cells[0]]) == Config.DOZER_HIT, "stone needs two rams")
	m.siege.turn(r, -1)
	check(SiegeSystem.facing(mc) == Vector3i(0, 0, -1), "the driver turns the blade (a left turn: +X to -Z)")
	end(m)


func test_machine_transport() -> void:
	# conveyor underneath, stops when obstructed, operator rides along
	var setup := siege_setup("cannon")
	var m: Match = setup[0]
	var r: Rat = setup[1]
	var mc: SiegeSystem.Machine = setup[2]
	m.siege.aim(r, 0.7, 0.4)
	var uid := mc.uid
	for i in 5:
		m.world.set_block(ARENA + Vector3i(i, -1, 0), Blocks.CONV_XP)
	m.world.set_block(ARENA + Vector3i(5, 0, 0), Blocks.STONE)
	var rx := r.position.x
	run(m, 1.0)
	check(mc.cell.x > ARENA.x and mc.cell.x < ARENA.x + 4, "moves a block at a time, not instantly (at +%d after 1 s)" % (mc.cell.x - ARENA.x))
	run(m, 4.0)
	check(mc.cell == ARENA + Vector3i(4, 0, 0), "conveyor carries the machine in its direction until obstructed (+%d)" % (mc.cell.x - ARENA.x))
	check(m.world.get_cell(mc.cell) == Blocks.CANNON and m.world.get_cell(ARENA) == Blocks.AIR, "the grid follows the machine exactly")
	check(m.siege.machines.size() == 1 and m.siege.machines.has(mc.cell), "no duplicate or ghost machines")
	check(mc.uid == uid and mc.team == 0 and mc.owner == r.id, "ownership preserved")
	check(absf(mc.yaw - 0.7) < 0.001 and absf(mc.pitch - 0.4) < 0.001, "orientation preserved")
	check(mc.operator == r.id and r.operating == uid and r.position.x > rx + 3.5, "the operator rides along and keeps control")
	run(m, 2.0)
	check(mc.cell == ARENA + Vector3i(4, 0, 0), "stays put while obstructed")
	m.world.set_block(ARENA + Vector3i(5, 0, 0), Blocks.AIR)
	run(m, 1.0)
	check(mc.cell.x == ARENA.x + 6, "moves on once the way is clear, and the last belt tile shoves it one block past the end (+%d)" % (mc.cell.x - ARENA.x))
	run(m, 2.0)
	check(mc.cell.x == ARENA.x + 6, "then rests: no conveyor is next to it any more")
	end(m)
	# ice: keeps sliding after the conveyor ends
	setup = siege_setup("dozer")
	m = setup[0]
	mc = setup[2]
	m.siege.release(setup[1])
	(setup[1] as Rat).position += Vector3(0, 0, -6)
	m.world.set_block(ARENA + Vector3i(0, -1, 0), Blocks.CONV_XP)
	for i in range(1, 5):
		m.world.set_block(ARENA + Vector3i(i, -1, 0), Blocks.ICE)
	run(m, 6.0)
	check(mc.cell == ARENA + Vector3i(5, 0, 0), "slides across ice and stops on rough ground (+%d)" % (mc.cell.x - ARENA.x))
	end(m)
	# conveyor beside the machine, another machine in the way, and gravity
	setup = siege_setup("crane")
	m = setup[0]
	mc = setup[2]
	var r2: Rat = setup[1]
	m.siege.release(r2)
	r2.position = Vector3(ARENA) + Vector3(0.5, 0, -6.5)
	for i in 3:
		m.world.set_block(ARENA + Vector3i(i, 0, 1), Blocks.CONV_XP)
	r2.gadgets["cannon"] = 1
	r2.position = Vector3(ARENA) + Vector3(2.5, 0, -2.5)
	check(m.try_place_gadget(r2, ARENA + Vector3i(2, 0, 0), "cannon") == "", "second machine placed in the path")
	run(m, 3.0)
	# both machines sit beside the belt: the cannon rides to its end (+3), the crane queues behind it (+2)
	check(m.world.get_cell(ARENA + Vector3i(3, 0, 0)) == Blocks.CANNON, "the cannon ahead rides to the end of the belt")
	check(mc.cell == ARENA + Vector3i(2, 0, 0), "adjacent conveyors move it; it stops behind other equipment (+%d)" % (mc.cell.x - ARENA.x))
	check(m.siege.machines.size() == 2, "two machines, two records")
	for i in 3:
		m.world.set_block(ARENA + Vector3i(i, 0, 1), Blocks.AIR)
	m.world.set_block(ARENA + Vector3i(2, -2, 0), Blocks.STONE)
	m.world.set_block(ARENA + Vector3i(2, -1, 0), Blocks.AIR)
	run(m, 1.0)
	check(mc.cell == ARENA + Vector3i(2, -1, 0), "a machine with no floor under it drops")
	end(m)


func test_machine_rules() -> void:
	var setup := siege_setup("cannon")
	var m: Match = setup[0]
	var r: Rat = setup[1]
	var mc: SiegeSystem.Machine = setup[2]
	var mate := arena_rat(m, 0, "scout", Vector3(0, 0, 1.2))
	var foe := arena_rat(m, 1, "scout", Vector3(0, 0, -1.2))
	check(m.siege.try_operate(mate, ARENA) != "" and mc.operator == r.id, "only one rat can hold the controls")
	check(m.siege.try_operate(foe, ARENA) != "", "enemies cannot operate it")
	check(m.siege.fire(mate) != "" and m.siege.shots.is_empty(), "a rat that is not the operator cannot fire it")
	foe.dig_cd = 0.0
	m.try_dig(foe, ARENA)
	check(m.world.get_cell(ARENA) == Blocks.CANNON, "enemies cannot dig a machine up")
	mate.dig_cd = 0.0
	m.try_dig(mate, ARENA)
	check(m.world.get_cell(ARENA) == Blocks.CANNON, "it cannot be packed up while in use")
	# a bonk knocks the operator off
	foe.position = r.position + Vector3(0, 0, -1.0)
	check(m.try_bonk(foe, r), "operator can be bonked")
	run(m, 0.1)
	check(r.operating == -1 and mc.operator == -1, "a bonk knocks the operator off the controls")
	run(m, 1.0)
	check(m.siege.try_operate(mate, ARENA) == "", "a teammate can take over")
	m.siege.release(mate)
	# blasts do not destroy machines; pasting and placing cannot overlap them
	m.blast(Vector3(ARENA) + Vector3(0.5, 2.6, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)   # overhead: floor stays
	check(m.world.get_cell(ARENA) == Blocks.CANNON and m.siege.machines.has(ARENA), "machines survive explosions")
	run(m, 1.5)
	mate.position = Vector3(ARENA) + Vector3(0.5, 0, 1.5)
	mate.vel = Vector3.ZERO
	mate.mats["dirt"] = 3
	check(m.try_place_mat(mate, ARENA, "dirt") != "", "cannot build inside a machine")
	# save / load keeps machines, aim and ownership
	mc.yaw = 1.1
	var path := "user://test_maps/siege.bwmap"
	check(m.world.save_to(path, {"machines": m.siege.to_save()}), "saves with machines")
	mate.dig_cd = 0.0
	check(m.try_dig(mate, ARENA) and int(mate.gadgets.get("cannon", 0)) == 1, "own team packs it up and gets the item back")
	check(m.siege.machines.is_empty() and m.world.get_cell(ARENA) == Blocks.AIR, "packed machine leaves nothing behind")
	check(m.world.load_from(path), "loads")
	m.siege.from_save(m.world.loaded_extra.get("machines", []))
	var back: SiegeSystem.Machine = m.siege.machines.get(ARENA)
	check(back != null and back.kind == Blocks.CANNON and absf(back.yaw - 1.1) < 0.001 and back.team == 0, "machine, aim and team restored from the save")
	m.siege.from_save([{"kind": Blocks.CANNON, "cell": Vector3i(1, 1, 1)}, "junk", {"cell": 5}])
	check(m.siege.machines.is_empty() and m.world.get_cell(ARENA) == Blocks.AIR, "a save with bad machine records leaves no ghost machines")
	# workshop
	r.position = MapGenerator.spawn_point(0)
	r.scrap = 500
	for id: String in ["cannon", "crane", "dozer", "dynamite", "sticky", "pitfall", "wallspring"]:
		check(m.try_buy(r, id) == "", "workshop sells %s" % id)
	m.try_buy(r, "cannon")
	check(m.try_buy(r, "cannon") != "" and int(r.gadgets["cannon"]) == 2, "at most two of a siege machine in the pack")
	end(m)


func test_effect_sheets() -> void:
	for fx_name: String in FxSheets.SHEETS:
		var s: Dictionary = FxSheets.SHEETS[fx_name]
		var tex: Texture2D = load("res://assets/fx/%s.png" % fx_name)
		var rows := ceili(float(s["frames"]) / float(s["cols"]))
		check(tex != null and tex.get_width() == int(s["w"]) * int(s["cols"]) and tex.get_height() == int(s["h"]) * rows, "%s.png matches its FxSheets entry" % fx_name)
	var holder := Node3D.new()
	add_child(holder)
	check(FxSprite.play(holder, "no_such_effect", Vector3.ZERO) == null, "an unknown effect plays nothing")
	var once := FxSprite.play(holder, "dust", Vector3(1, 2, 3), 0.5)
	check(once != null and once.global_position.is_equal_approx(Vector3(1, 2, 3)), "an effect plays where it was asked")
	var dust: Dictionary = FxSheets.SHEETS["dust"]
	var life := float(dust["frames"]) / float(dust["fps"])
	once._process(life * 0.5)
	check(not once.is_queued_for_deletion() and once._frame > 0, "it animates")
	once._process(life * 0.6)
	check(once.is_queued_for_deletion(), "and frees itself after its last frame")
	var anchor := Node3D.new()
	holder.add_child(anchor)
	var loop := FxSprite.play(holder, "jetpack", Vector3(0, 0.5, 0), 0.4, anchor, 0.5)
	anchor.position = Vector3(5, 0, 0)
	loop._process(0.2)
	check(not loop.is_queued_for_deletion() and loop.global_position.distance_to(Vector3(5, 0, 0)) < 0.3, "a looping effect rides along with its rat")
	var lifted := (loop.offset.y - (float(FxSheets.SHEETS["jetpack"]["pivot"].y) - float(FxSheets.SHEETS["jetpack"]["h"]) * 0.5)) * loop.pixel_size
	check(absf(lifted - 0.5) < 0.01, "level with its feet, the picture lifted %.2f blocks up it (so it sorts behind the rat)" % lifted)
	loop._process(0.4)
	check(loop.is_queued_for_deletion(), "until its time is up")
	holder.queue_free()
	check(MatchView.break_sheet(Blocks.DIRT) == "break_dirt" and MatchView.break_sheet(Blocks.ICE) == "break_ice"
		and MatchView.break_sheet(Blocks.OBSIDIAN) == "break_dark" and MatchView.break_sheet(Blocks.SCRAP) == "break_scrap"
		and MatchView.break_sheet(Blocks.STONE) == "break_stone", "a broken block bursts in its own colours")
	for kind: String in ["spring", "jetpack", "dash", "jump", "land", "splash", "splash_out"]:
		check(NetServer.CLIENT_FX.has(kind), "online, a player's game may report '%s'" % kind)
	# textured blocks: scrap is drawn with its picture, other blocks keep their flat colours
	check(BlockTextures.flags()[Blocks.SCRAP] == 1 and BlockTextures.flags()[Blocks.DIRT] == 0, "scrap has a texture (assets/blocks/scrap.png)")
	var w := VoxelWorld.new()
	w.set_raw(3, 3, 3, Blocks.SCRAP)
	w.set_raw(5, 3, 3, Blocks.DIRT)
	var plain := StandardMaterial3D.new()
	var mesh := ChunkMesher.build(w, Vector3i.ZERO, plain, plain)
	var textured := -1
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) == BlockTextures.material(Blocks.SCRAP):
			textured = i
	check(textured >= 0 and (mesh.surface_get_arrays(textured)[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == 36, "a lone scrap block is six textured faces")
	check(mesh.get_surface_count() == 2, "and the dirt beside it stays a plain coloured surface")
	w.free()


func test_motion_and_splash_fx() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	# a pond flush with the ground, 3 deep, 5 wide (as in water_exit)
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var inside := absi(dx) <= 2 and absi(dz) <= 2
			for dy in range(-3, 0):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.WATER if inside else Blocks.STONE)
			m.world.set_block(ARENA + Vector3i(dx, -4, dz), Blocks.STONE)
	# a one-block lava pit in the floor
	var pit := ARENA + Vector3i(-5, -1, 5)
	m.world.set_block(pit, Blocks.LAVA)
	m.world.set_block(pit + Vector3i(0, -1, 0), Blocks.STONE)
	var kinds: Array[String] = []
	var sizes: Array[float] = []
	m.fx.connect(func(kind: String, _p: Vector3, d: Variant) -> void:
		kinds.append(kind)
		sizes.append(1.0 if d == null else float(d)))
	var r := arena_rat(m, 0, "scout", Vector3(-5, 0, -5))
	run(m, 0.5)
	kinds.clear()
	r.jump_pressed = true
	m.step(DT)
	r.jump_pressed = false
	check(kinds.has("jump"), "jumping kicks up dust")
	run(m, 1.2)
	check(not kinds.has("land"), "an ordinary jump lands softly")
	kinds.clear()
	r.wish = Vector3(0, 0, 1)
	r.dash_pressed = true
	m.step(DT)
	r.dash_pressed = false
	r.wish = Vector3.ZERO
	check(kinds.has("dash"), "dashing kicks up dust")
	r.position = Vector3(ARENA) + Vector3(-4.5, 5, -4.5)
	r.vel = Vector3.ZERO
	r.on_floor = false
	run(m, 0.3)
	kinds.clear()
	run(m, 1.0)
	check(kinds.has("land"), "a long fall lands with a thump")
	# into the pond from a height, then leap back out
	r.position = Vector3(ARENA) + Vector3(0.5, 4, 0.5)
	r.vel = Vector3.ZERO
	kinds.clear()
	run(m, 1.5)
	check(kinds.count("splash") == 1 and not kinds.has("splash_out"), "dropping into water splashes once, and floating makes no more (%s)" % str(kinds))
	r.jump_held = true
	for i in 60:
		m.step(DT)
	r.jump_held = false
	check(kinds.has("splash_out"), "leaping up out of the water splashes")
	r.position = Vector3(ARENA) + Vector3(-6.5, 0, -6.5)
	r.vel = Vector3.ZERO
	run(m, 1.0)
	# a walk in from the bank is quiet
	kinds.clear()
	r.position = Vector3(ARENA) + Vector3(3.5, 0, 0.5)
	r.wish = Vector3(-1, 0, 0)
	run(m, 0.6)
	r.wish = Vector3.ZERO
	check(not kinds.has("splash"), "wading in from the bank makes no splash (%s)" % str(kinds))
	r.position = Vector3(ARENA) + Vector3(-6.5, 0, -6.5)
	r.vel = Vector3.ZERO
	run(m, 1.0)
	# loose cheese splashes (smaller) too, and sizzles on lava
	kinds.clear()
	sizes.clear()
	m.spawn_pickup("cheese", Vector3(ARENA) + Vector3(1.5, 4, 1.5), Vector3.ZERO)
	run(m, 1.5)
	var i := kinds.find("splash")
	check(i >= 0 and sizes[i] < 1.0, "cheese dropped in the pond splashes, a small splash (%s)" % str(kinds))
	kinds.clear()
	var hot := m.spawn_pickup("cheese", Vector3(pit) + Vector3(0.5, 5, 0.5), Vector3.ZERO)
	run(m, 1.5)
	check(kinds.count("sizzle") == 1 and hot.pos.y > pit.y + 1.0, "cheese dropped on lava sizzles once and sits on top (%s, y=%.2f)" % [str(kinds), hot.pos.y - pit.y])
	# a splash sits on the pond's surface, whether you are in it or just above
	var view := MatchView.new()
	view.m = m
	var top := float(ARENA.y) - 1.0 + 0.88
	check(absf(view.surface(Vector3(ARENA) + Vector3(0.5, -2.5, 0.5), Blocks.WATER).y - top) < 0.01
		and absf(view.surface(Vector3(ARENA) + Vector3(0.5, 0.1, 0.5), Blocks.WATER).y - top) < 0.01, "splashes sit on the water's surface")
	check(absf(view.surface(Vector3(ARENA) + Vector3(-5.5, 3, 0.5), Blocks.WATER).y - (ARENA.y + 3)) < 0.01, "and stay put away from any water")
	view.free()
	end(m)


func cave_networks(w: VoxelWorld) -> Array[Dictionary]:
	## Connected pockets of underground air in team 0's half that reach into
	## the lower third: size, footprint, and whether they open to the sky.
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	var half := sx / 2
	var tops := PackedInt32Array()
	tops.resize(half * sz)
	for x in half:
		for z in sz:
			tops[x * sz + z] = w.surface_y(x, z)
	var seen := PackedByteArray()
	seen.resize(w.data.size())
	var out: Array[Dictionary] = []
	for y in range(MapGenerator.CAVE_LAVA_Y + 1, MapGenerator.DEEP_TOP + 1):
		for z in sz:
			for x in half:
				var i := x + sx * (z + sz * y)
				if seen[i] == 1 or w.data[i] != Blocks.AIR or y >= tops[x * sz + z]:
					continue
				var net := {"size": 0, "x0": x, "x1": x, "z0": z, "z1": z, "sky": false}
				var queue := PackedInt32Array([i])
				seen[i] = 1
				var head := 0
				while head < queue.size():
					var c := queue[head]
					head += 1
					var cx := c % sx
					var cz := (c / sx) % sz
					var cy := c / (sx * sz)
					net["size"] += 1
					net["x0"] = mini(net["x0"], cx)
					net["x1"] = maxi(net["x1"], cx)
					net["z0"] = mini(net["z0"], cz)
					net["z1"] = maxi(net["z1"], cz)
					for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
						var nx := cx + d.x
						var ny := cy + d.y
						var nz := cz + d.z
						if nx < 0 or nx >= half or nz < 0 or nz >= sz or ny < 1 or ny >= VoxelWorld.SY:
							continue
						var n := nx + sx * (nz + sz * ny)
						if seen[n] == 1 or w.data[n] != Blocks.AIR:
							continue
						if ny >= tops[nx * sz + nz]:
							net["sky"] = true     # open air above the ground: this cave has a way out
							continue
						seen[n] = 1
						queue.append(n)
				out.append(net)
	return out


func test_deep_caves_and_riches() -> void:
	var deep := MapGenerator.DEEP_TOP
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	for seed_n: int in [4242, 7]:
		var m := new_match({"seed": seed_n})
		var w := m.world
		var cheese := [0, 0]
		var scrap := [0, 0]
		var pools := 0
		for i in w.data.size():
			var id := w.data[i]
			var y := i / (sx * sz)
			var low := 1 if y <= deep else 0
			if id == Blocks.CHEESE:
				cheese[low] += 1
			elif id == Blocks.SCRAP:
				scrap[low] += 1
			elif id == Blocks.LAVA and y > MapGenerator.CAVE_LAVA_Y and y <= deep:
				pools += 1
		var nets := cave_networks(w)
		var big := 0
		var widest := 0
		var open := 0
		for n: Dictionary in nets:
			if int(n["size"]) >= 300:
				big += 1
			widest = maxi(widest, maxi(int(n["x1"]) - int(n["x0"]), int(n["z1"]) - int(n["z0"])))
			if bool(n["sky"]) and int(n["size"]) >= 100:
				open += 1
		print("    seed %d: deep cheese %d (+%d higher), deep scrap %d (+%d), raised lava %d, networks %d (%d big, widest %d, %d open to the sky)" % [
			seed_n, cheese[1], cheese[0], scrap[1], scrap[0], pools, nets.size(), big, widest, open])
		# (before the deep caves, seed 4242 had 80 deep cheese, 1482 deep scrap, 208 raised lava, no way in from the surface)
		check(cheese[1] >= 110 and cheese[1] * 4 >= (cheese[0] + cheese[1]) * 3, "seed %d: most cheese is in the lower third (%d of %d)" % [seed_n, cheese[1], cheese[0] + cheese[1]])
		check(scrap[1] >= 2400, "seed %d: the lower third is rich in scrap (%d)" % [seed_n, scrap[1]])
		check(pools >= 500, "seed %d: lava pools and lakes through the lower third, not only the bottom sheet (%d cells)" % [seed_n, pools])
		check(big >= 3 and widest >= 60, "seed %d: big branching cave networks wander across the map (%d big, widest %d blocks)" % [seed_n, big, widest])
		check(open >= 2, "seed %d: caves climb out to the surface in a few places (%d)" % [seed_n, open])
		var shown := 0
		for i in w.data.size():
			var y := i / (sx * sz)
			if y <= MapGenerator.CAVE_LAVA_Y or y > deep or (w.data[i] != Blocks.CHEESE and w.data[i] != Blocks.SCRAP):
				continue
			var c := Vector3i(i % sx, y, (i / sx) % sz)
			for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if w.get_cell(c + d) == Blocks.AIR:
					shown += 1
					break
		check(shown >= 120, "seed %d: scrap and cheese show in cave walls (%d blocks)" % [seed_n, shown])
		var hot := 0
		for t in 2:
			var b := MapGenerator.base_center(t)
			for x in range(int(b.x) - 20, int(b.x) + 21):
				for z in range(int(b.z) - 20, int(b.z) + 21):
					if Vector2(x + 0.5 - b.x, z + 0.5 - b.z).length() > 20.0:
						continue
					for y in range(1, MapGenerator.GROUND):
						if w.get_cell(Vector3i(x, y, z)) == Blocks.LAVA:
							hot += 1
		check(hot == 0, "seed %d: no lava within 20 blocks of either base (%d)" % [seed_n, hot])
		end(m)


func test_lobby_playground() -> void:
	var m := new_match({"mode": "lobby"})
	check(m.lobby and m.free_mode and m.bots.is_empty(), "the lobby is a free playground with no bots")
	var c := Vector3(MapGenerator.LOBBY_CENTER)
	var a := m.spawn_rat(0, "scout", false)
	var b := m.spawn_rat(0, "digger", false)
	var red := m.spawn_rat(1, "builder", false)
	run(m, 0.6)
	for r: Rat in [a, b, red]:
		check(r.position.distance_to(c) < 4.5 and r.on_floor and absf(r.position.y - c.y) < 0.05, "%s spawns standing on the plaza (%s)" % [r.class_id, str(r.position - c)])
		check(r.gear == "jetpack", "%s wears a jetpack" % r.class_id)
	check(a.class_id == "scout" and red.team == 1, "players keep their class and team")
	check(m.siege.machines.size() == MapGenerator.LOBBY_CANNONS.size(), "the cannon battery is ready (%d)" % m.siege.machines.size())
	# fixtures stay, the island can be dug
	var bull := MapGenerator.LOBBY_BULL
	var before := m.world.get_cell(bull)
	a.position = Vector3(bull) + Vector3(-2.5, -0.5, 0.5)
	a.dig_cd = 0.0
	m.try_dig(a, bull)
	check(m.world.get_cell(bull) == before and Blocks.is_paint(before), "the bullseye can't be dug")
	m.blast(Vector3(bull) + Vector3(-0.5, 0.5, 0.5), 3.0, 50.0)
	check(m.world.get_cell(bull) == before and m.world.get_cell(MapGenerator.LOBBY_CANNONS[0]) == Blocks.CANNON, "or blasted")
	var cannon: Vector3i = MapGenerator.LOBBY_CANNONS[1]
	b.position = Vector3(cannon) + Vector3(-1.5, 0, 0.5)
	b.dig_cd = 0.0
	m.try_dig(b, cannon)
	check(m.world.get_cell(cannon) == Blocks.CANNON and int(b.gadgets.get("cannon", 0)) == 0, "a lobby cannon can't be picked up")
	var ground := Vector3i(int(c.x) + 3, int(c.y) - 1, int(c.z) - 12)
	check(m.world.get_cell(ground) == Blocks.GRASS, "there is open grass to dig")
	b.position = Vector3(ground) + Vector3(0.5, 1, 1.5)
	b.dig_cd = 0.0
	m.try_dig(b, ground)
	check(m.world.get_cell(ground) == Blocks.AIR, "the island itself can be burrowed into")
	# teammates may bonk and shoot each other, and fly further than in a match
	a.position = c + Vector3(0.5, 0, 3.5)
	b.position = c + Vector3(1.5, 0, 3.5)
	a.bonk_cd = 0.0
	run(m, 0.1)
	check(m.try_bonk(a, b) and b.vel.length() > 15.0, "a teammate's bonk launches you (%.1f)" % b.vel.length())
	run(m, 2.0)
	check(m.siege.try_operate(red, cannon) != "", "you must stand at a cannon to man it")
	red.position = Vector3(cannon) + Vector3(-0.5, 0, 0.5)
	run(m, 0.1)
	check(m.siege.try_operate(red, cannon) == "", "a Red rat can man the lobby's cannon")
	var mc: SiegeSystem.Machine = m.siege.machines[cannon]
	mc.pitch = 0.0
	var target := m.siege.muzzle(mc) + m.siege.aim_dir(mc) * 4.0
	a.position = target - Vector3(0, 0.45, 0)
	a.vel = Vector3.ZERO
	a.knock = 0.0
	check(m.siege.fire(red) == "", "and fire it")
	var flung := 0.0
	for i in 40:
		m.step(DT)
		flung = maxf(flung, a.vel.length())
	check(flung > 15.0, "a cannonball flings a friend across the playground (%.1f)" % flung)
	m.siege.release(red)
	# the bullseye
	var cheers: Array[String] = []
	m.toast.connect(func(text: String, _t: int) -> void: cheers.append(text))
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	b.position = Vector3(bull) + Vector3(-Rat.RADIUS - 0.05, 0.1, 0.5)   # flat against the gold
	b.vel = Vector3.ZERO
	m.step(DT)
	check(kinds.has("bullseye") and cheers.size() > 0 and cheers[-1].contains("BULLSEYE"), "flying into the gold scores a BULLSEYE (%s %s at %s)" % [str(kinds), str(cheers), str(b.center() - Vector3(bull))])
	kinds.clear()
	run(m, 0.5)
	check(not kinds.has("bullseye"), "once, not every frame")
	# the diving board is over deep water, and respawning returns to the plaza
	var board_end := Vector3i(int(c.x), int(c.y) + 9, int(c.z) + 32)
	check(m.world.get_cell(board_end) == Blocks.WOOD, "a diving board")
	var deep := 0
	for y in range(board_end.y - 1, 0, -1):
		var id := m.world.get_cell(Vector3i(board_end.x, y, board_end.z))
		if id == Blocks.WATER:
			deep += 1
		elif id != Blocks.AIR:
			break
	check(deep >= 3, "with deep water under it (%d)" % deep)
	m.respawn(b)
	check(b.position.distance_to(c) < 4.5, "respawning brings you back to the plaza")
	check(not m.over and m.scores == [0, 0], "nobody wins a lobby")
	end(m)


func test_moves_and_blasts() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	# a full double jump landed flat thumps the block below
	var floor_cell := ARENA + Vector3i(0, -1, 0)
	m.world.set_block(floor_cell, Blocks.DIRT)
	var r := arena_rat(m, 0, "scout")
	run(m, 0.4)
	var double_jump := func(rat: Rat) -> void:
		rat.jump_pressed = true
		m.step(DT)
		rat.jump_pressed = false
		var guard := 0
		while rat.vel.y > 0.5 and guard < 120:
			m.step(DT)
			guard += 1
		rat.jump_pressed = true
		m.step(DT)
		rat.jump_pressed = false
	kinds.clear()
	double_jump.call(r)
	run(m, 1.2)
	check(kinds.has("pound") and kinds.has("hit") and int(m.world.damage.get(floor_cell, 0)) == 1, "a full double jump landed flat gives the dirt below a dig hit (%s)" % str(kinds))
	m.world.set_block(floor_cell, Blocks.STONE)
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	r.vel = Vector3.ZERO
	r.stamina = r.max_stamina()
	run(m, 1.0)
	kinds.clear()
	double_jump.call(r)
	run(m, 1.2)
	check(kinds.has("pound") and int(m.world.damage.get(floor_cell, 0)) == 1 and m.world.get_cell(floor_cell) == Blocks.STONE, "on stone it lands one dig hit")
	kinds.clear()
	r.jump_pressed = true
	m.step(DT)
	r.jump_pressed = false
	run(m, 1.2)
	check(not kinds.has("pound"), "a single jump does nothing to the floor")
	m.world.set_block(ARENA + Vector3i(0, 3, 0), Blocks.STONE)    # a low ceiling
	r.stamina = r.max_stamina()
	run(m, 0.6)
	kinds.clear()
	double_jump.call(r)
	run(m, 1.2)
	check(not kinds.has("pound"), "a double jump cut short by the ceiling doesn't pound")
	m.world.set_block(ARENA + Vector3i(0, 3, 0), Blocks.AIR)
	# the jetpack lifts half as high with cheese aboard
	var light := arena_rat(m, 0, "scout", Vector3(-4, 0, -4))
	var heavy := arena_rat(m, 1, "scout", Vector3(4, 0, 4))
	light.gear = "jetpack"
	heavy.gear = "jetpack"
	heavy.carried = 1
	run(m, 0.4)
	var y0 := [light.position.y, heavy.position.y]
	light.gear_pressed = true
	heavy.gear_pressed = true
	m.step(DT)
	light.gear_pressed = false
	heavy.gear_pressed = false
	run(m, Config.JETPACK_TIME)
	var lift := [light.position.y - float(y0[0]), heavy.position.y - float(y0[1])]
	check(lift[1] > 1.0 and lift[1] < lift[0] * 0.65, "carrying cheese, the jetpack lifts about half as far (%.1f vs %.1f)" % [lift[1], lift[0]])
	# keys: paint, chisel and pantograph sit on 8, 9 and 0
	check(Inputs.KEYS["slot_5"][0] == KEY_8 and Inputs.KEYS["chisel"][0] == KEY_9 and Inputs.KEYS["pantograph"][0] == KEY_0, "paint 8, chisel 9, pantograph 0")
	# TNT and team gadgets
	var o := ARENA + Vector3i(0, 0, 5)
	m.world.set_block(o + Vector3i(1, 0, 0), Blocks.TEAM_RED)
	m.world.set_block(o + Vector3i(-1, 0, 0), Blocks.TEAM_BLUE)
	m.world.set_block(o + Vector3i(0, 0, 1), Blocks.GATE_RED)
	kinds.clear()
	m.blast(Vector3(o) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(m.world.get_cell(o + Vector3i(1, 0, 0)) == Blocks.AIR and m.world.get_cell(o + Vector3i(-1, 0, 0)) == Blocks.AIR and kinds.count("break") >= 2, "TNT blows up team blocks, either team's")
	check(m.world.get_cell(o + Vector3i(0, 0, 1)) == Blocks.GATE_RED and kinds.has("hit"), "and cracks a team gate, visibly")
	m.blast(Vector3(o) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)
	check(m.world.get_cell(o + Vector3i(0, 0, 1)) == Blocks.AIR, "a second blast breaks the gate")
	check(String(ClassDefs.shop_item("tnt")["desc"]).contains("Team Blocks") and String(ClassDefs.shop_item("teamblock")["desc"]).contains("TNT"), "the workshop says so")
	end(m)
	# hit sparks take the block's colour
	var holder := Node3D.new()
	add_child(holder)
	var spark := FxSprite.play(holder, "hit", Vector3.ZERO, 0.3, null, -1.0, Blocks.COLOR[Blocks.ICE])
	var mat := spark.material_override as ShaderMaterial
	check(mat != null and absf(float(mat.get_shader_parameter("hue")) - Blocks.COLOR[Blocks.ICE].h) < 0.001, "hit sparks are recoloured to the block")
	check(FxSprite.play(holder, "hit", Vector3.ZERO).material_override == null, "untinted effects draw as they are")
	holder.queue_free()
	# spilled liquid slopes down to the ground at its edges
	var w := VoxelWorld.new()
	var g := 10
	for x in range(20, 30):
		for z in range(20, 30):
			w.set_raw(x, g - 1, z, Blocks.STONE)
	for x in range(22, 25):
		for z in range(22, 25):
			w.set_raw(x, g, z, Blocks.WATER)          # a 3x3 puddle on open ground
	for x in range(26, 29):
		for z in range(22, 25):
			for y in [g, g + 1]:
				w.set_raw(x, y, z, Blocks.STONE)
	w.set_raw(27, g + 1, 23, Blocks.WATER)          # a 1x1 pool held by stone walls
	check(is_equal_approx(ChunkMesher.liquid_corner(w.data, 23, g, 23, Blocks.WATER), ChunkMesher.LIQUID_TOP), "the middle of a puddle is level")
	check(is_equal_approx(ChunkMesher.liquid_corner(w.data, 22, g, 22, Blocks.WATER), ChunkMesher.LIQUID_EDGE), "its outer edge runs down to the ground")
	check(is_equal_approx(ChunkMesher.liquid_corner(w.data, 27, g + 1, 23, Blocks.WATER), ChunkMesher.LIQUID_TOP), "water held by walls stays level to the brim")
	w.set_raw(23, g + 1, 23, Blocks.WATER)
	check(is_equal_approx(ChunkMesher.liquid_corner(w.data, 23, g, 23, Blocks.WATER), 1.0), "and rises to meet water stacked on it")
	w.free()


func test_knight_shield() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	var knight := arena_rat(m, 0, "digger")
	knight.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	knight.scrap = 20
	check(m.try_buy(knight, "shield") == "" and knight.gear == "shield" and knight.scrap == 20 - int(ClassDefs.shop_item("shield")["cost"]), "the Rat Knight Shield is sold as gear")
	knight.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	knight.carried = 2
	run(m, 0.3)
	var walk := knight.move_speed()
	kinds.clear()
	knight.gear_pressed = true
	m.step(DT)
	knight.gear_pressed = false
	check(kinds.has("shield") and absf(knight.shield_t - Config.SHIELD_TIME) < 0.05 and knight.gear_cd > Config.SHIELD_TIME + Config.SHIELD_COOLDOWN - 0.1, "J raises it for %.0f s" % Config.SHIELD_TIME)
	check(absf(knight.move_speed() - walk * Config.SHIELD_CARRY_SPEED) < 0.01, "hauling cheese behind it is a quarter slower")
	var bully := arena_rat(m, 1, "scout", Vector3(1.0, 0, 0))
	run(m, 0.2)
	bully.bonk_cd = 0.0
	kinds.clear()
	var before := knight.vel
	m.try_bonk(bully, knight)
	check(kinds.has("shield_block") and knight.carried == 2 and knight.knock <= 0.0 and knight.vel.distance_to(before) < 1.0, "a bonk bounces off: no knock, no dropped cheese")
	# a cannonball glances off too
	var gun := ARENA + Vector3i(-5, 0, 0)
	var mc := m.siege.add_fixed(gun, Blocks.CANNON, -PI * 0.5)
	m.world.set_block(gun, Blocks.CANNON)
	mc.team = 1
	mc.pitch = 0.0
	bully.position = Vector3(gun) + Vector3(-0.5, 0, 0.5)
	run(m, 0.1)
	check(m.siege.try_operate(bully, gun) == "", "an enemy mans a cannon")
	knight.position = m.siege.muzzle(mc) + m.siege.aim_dir(mc) * 3.0 - Vector3(0, 0.45, 0)
	knight.vel = Vector3.ZERO
	kinds.clear()
	m.siege.fire(bully)
	run(m, 0.6)
	check(kinds.has("shield_block") and knight.carried == 2, "and a cannonball glances off the shield")
	m.siege.release(bully)
	# when it drops, bonks land again
	run(m, Config.SHIELD_TIME)
	check(knight.shield_t <= 0.0 and absf(knight.move_speed() - walk) < 0.01, "after %.0f s it drops" % Config.SHIELD_TIME)
	bully.position = knight.position + Vector3(1.0, 0, 0)
	bully.bonk_cd = 0.0
	run(m, 0.05)
	m.try_bonk(bully, knight)
	check(knight.vel.length() > 5.0 and knight.carried == 1, "and bonks land again")
	knight.gear_pressed = true
	m.step(DT)
	knight.gear_pressed = false
	check(knight.shield_t <= 0.0, "it needs %.0f s before it can be raised again" % Config.SHIELD_COOLDOWN)
	# online the authority checks the player's claim
	var plain := arena_rat(m, 1, "builder", Vector3(3, 0, 3))
	check(not m.raise_shield(plain), "no shield, no raising it")
	plain.gear = "shield"
	check(m.raise_shield(plain) and plain.shield_t > 0.0 and not m.raise_shield(plain), "a ready shield is raised once, then cools down")
	check(NetServer.CLIENT_FX.has("shield"), "a player's game reports raising it")
	end(m)


func test_bubble_shoes() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	# a pit three blocks wide across the arena
	for dx in range(2, 5):
		for dz in range(-8, 9):
			for dy in range(-5, 0):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.AIR)
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	var r := arena_rat(m, 0, "scout", Vector3(-1, 0, 0))
	r.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	r.scrap = 30
	check(m.try_buy(r, "bubbles") == "" and r.gear == "bubbles" and r.scrap == 30 - int(ClassDefs.shop_item("bubbles")["cost"]), "Bubble Shoes are sold as gear")
	r.scrap = 20
	r.position = Vector3(ARENA) + Vector3(-0.5, 0, 0.5)
	run(m, 0.3)
	r.gear_pressed = true
	m.step(DT)
	r.gear_pressed = false
	check(r.bubbles_on, "J switches them on")
	var low := r.position.y
	r.wish = Vector3(1, 0, 0)
	var guard := 0
	while r.position.x < ARENA.x + 6.5 and guard < 600:
		m.step(DT)
		low = minf(low, r.position.y)
		guard += 1
	r.wish = Vector3.ZERO
	var made := 0
	for dx in range(2, 5):
		if m.world.get_cell(ARENA + Vector3i(dx, -1, 0)) == Blocks.BUBBLE:
			made += 1
	check(made == 3 and low > ARENA.y - 0.05, "walking off the edge, a bubble bridge forms under your feet (%d bubbles, lowest %.2f)" % [made, low - ARENA.y])
	check(r.scrap == 20 - made * Config.BUBBLE_COST, "each bubble costs %d scrap (%d left)" % [Config.BUBBLE_COST, r.scrap])
	kinds.clear()
	run(m, Config.BUBBLE_TIME + 0.2)
	check(m.world.get_cell(ARENA + Vector3i(3, -1, 0)) == Blocks.AIR and kinds.count("pop") == 3, "after %.0f s the bubbles pop" % Config.BUBBLE_TIME)
	# switched off, you fall
	r.gear_pressed = true
	m.step(DT)
	r.gear_pressed = false
	check(not r.bubbles_on, "J again switches them off")
	r.wish = Vector3(-1, 0, 0)
	run(m, 0.8)
	r.wish = Vector3.ZERO
	check(r.position.y < ARENA.y - 1.0, "and then a step off the edge is a fall")
	# no scrap, no bubbles
	r.position = Vector3(ARENA) + Vector3(-0.5, 0, 2.5)
	r.vel = Vector3.ZERO
	r.bubbles_on = true
	r.scrap = 1
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	run(m, 1.0)
	r.wish = Vector3.ZERO
	check(r.position.y < ARENA.y - 1.0 and r.scrap == 1, "with less than %d scrap you fall" % Config.BUBBLE_COST)
	# running out halfway across: one bubble, then an ordinary fall (no hovering)
	r.position = Vector3(ARENA) + Vector3(-0.5, 0, -5.5)
	r.vel = Vector3.ZERO
	r.scrap = Config.BUBBLE_COST + 1
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	var past := -1
	var frames := 0
	while frames < 240:
		m.step(DT)
		frames += 1
		if past < 0 and r.position.x > ARENA.x + 3.3:
			past = frames
		if past >= 0 and r.position.y < ARENA.y - 0.3:
			break
	r.wish = Vector3.ZERO
	var one := m.world.get_cell(ARENA + Vector3i(2, -1, -6)) == Blocks.BUBBLE and m.world.get_cell(ARENA + Vector3i(3, -1, -6)) == Blocks.AIR
	check(one and past >= 0 and frames - past <= 14, "out of scrap mid-bridge, the next step is a plain fall (%d frames)" % (frames - past))
	# a jump off the edge is a jump: the shoes don't catch it
	r.position = Vector3(ARENA) + Vector3(1.2, 0, -2.5)
	r.vel = Vector3.ZERO
	r.scrap = 20
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	r.jump_pressed = true
	m.step(DT)
	r.jump_pressed = false
	run(m, 0.25)
	r.wish = Vector3.ZERO
	run(m, 1.0)
	check(r.position.y < ARENA.y - 1.0 and r.scrap == 20, "jumping off on purpose drops you down")
	# the authority checks a player's request
	var far := ARENA + Vector3i(3, -1, 6)
	check(not m.place_bubble(r, far), "no bubble far from your feet")
	var other := arena_rat(m, 1, "digger", Vector3(-4, 0, -4))
	check(not m.place_bubble(other, ARENA + Vector3i(-4, -1, -4)), "or without the shoes")
	end(m)


func test_decoy_and_squeaker() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	var blue := arena_rat(m, 0, "builder")
	var red := arena_rat(m, 1, "scout", Vector3(4, 0, 0))
	blue.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	blue.scrap = 40
	check(m.try_buy(blue, "decoy") == "" and int(blue.gadgets.get("decoy", 0)) == 1 and blue.scrap == 28, "a Cheese Decoy costs 12 scrap")
	check(m.try_buy(blue, "squeaker") == "" and int(blue.gadgets.get("squeaker", 0)) == 1 and blue.scrap == 13, "a Squeaker Pad costs 15")
	blue.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	run(m, 0.3)
	# the decoy
	var spot := ARENA + Vector3i(0, 0, -2)
	check(m.try_place_gadget(blue, spot, "decoy") == "" and int(blue.gadgets.get("decoy", 0)) == 0, "placed: single use")
	check(Blocks.is_decoy(m.world.get_cell(spot)) and not m.world.cheese_cells.has(spot), "it's not real cheese")
	check(Blocks.COLOR[Blocks.DECOY_RED] == Blocks.COLOR[Blocks.CHEESE], "but it looks exactly like it")
	red.position = Vector3(spot) + Vector3(0.5, 0, 2.0)
	red.dig_cd = 0.0
	run(m, 0.1)
	kinds.clear()
	m.try_dig(red, spot)
	check(kinds.has("decoy") and red.stun >= Config.DECOY_STUN - 0.1 and m.world.get_cell(spot) == Blocks.AIR, "an enemy who digs it is dazed, and it's gone")
	m._give_gadget(blue, "decoy", 1)
	m.try_place_gadget(blue, spot, "decoy")
	blue.position = Vector3(spot) + Vector3(0.5, 0, 2.0)
	blue.dig_cd = 0.0
	run(m, 0.1)
	m.try_dig(blue, spot)
	check(int(blue.gadgets.get("decoy", 0)) == 1 and blue.stun <= 0.0 and m.world.get_cell(spot) == Blocks.AIR, "your own decoy comes back into your pack")
	# the squeaker
	var pad := ARENA + Vector3i(3, 0, 3)
	blue.position = Vector3(pad) + Vector3(-1.5, 0, 0.5)
	run(m, 0.1)
	check(m.try_place_gadget(blue, pad, "squeaker") == "" and Blocks.is_squeaker(m.world.get_cell(pad)), "a squeaker pad on the floor")
	kinds.clear()
	blue.position = Vector3(pad) + Vector3(0.5, 0, 0.5)
	run(m, 0.5)
	check(not kinds.has("squeak"), "its own team walks over it quietly")
	blue.position = Vector3(ARENA) + Vector3(-5.5, 0, -5.5)
	var squeaks := 0
	for k in 3:
		red.position = Vector3(pad) + Vector3(0.5, 0, 0.5)
		red.vel = Vector3.ZERO
		red.stun = 0.0
		kinds.clear()
		var marks := m.markers.size()
		run(m, 0.5)
		if kinds.has("squeak"):
			squeaks += 1
		if k == 0:
			check(m.markers.size() == marks + 1 and int(m.markers[-1]["team"]) == 0, "an enemy sets it off: a beacon for its team")
			check(kinds.count("squeak") == 1, "once, not every frame")
		red.position = Vector3(pad) + Vector3(3.5, 0, 0.5)
		run(m, Config.SQUEAKER_REST + 0.2)
	check(squeaks == 3 and m.world.get_cell(pad) == Blocks.AIR, "three squeaks, then it's spent (%d)" % squeaks)
	end(m)


func test_bots_scrap_and_decoys() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			for dy in [-3, -2]:
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.STONE)   # no surprise scrap under the floor
	var bot := m.spawn_rat(0, "digger", true)
	bot.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	bot.gear = "jetpack"         # nothing to shop for: the scrap is easy to count
	var brain: BotBrain = null
	for b in m.bots:
		if b.rat == bot:
			brain = b
	for dy in 2:
		m.world.set_block(ARENA + Vector3i(4, dy, 0), Blocks.SCRAP)
	var before := bot.scrap
	var t := 0.0
	while t < 25.0 and (m.world.get_cell(ARENA + Vector3i(4, 0, 0)) == Blocks.SCRAP or m.world.get_cell(ARENA + Vector3i(4, 1, 0)) == Blocks.SCRAP):
		m.step(DT)
		t += DT
	m.step(DT)                   # (the bot counts its last block on its next think)
	var gained := bot.scrap - before
	check(gained > 0 and m.world.get_cell(ARENA + Vector3i(4, 0, 0)) != Blocks.SCRAP, "a bot mines scrap it passes near (+%d in %.0f s)" % [gained, t])
	# at base it banks half of what it mined
	var bank0 := int(m.team_bank[0]["scrap"])
	var mined := brain.mined
	bot.position = MapGenerator.spawn_point(0)
	bot.vel = Vector3.ZERO
	var held := bot.scrap
	run(m, 0.5)
	var banked := int(m.team_bank[0]["scrap"]) - bank0
	check(mined >= 2 and banked == mined / 2 and bot.scrap == held - banked, "and at base banks half of it for the team (%d of %d)" % [banked, mined])
	# the other team's Cheese Decoy fools it; its own team's doesn't
	var own := ARENA + Vector3i(-2, 0, 0)
	var fake := ARENA + Vector3i(2, 0, -2)
	m.world.set_block(own, Blocks.DECOY_BLUE)
	m.world.set_block(fake, Blocks.DECOY_RED)
	bot.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	bot.vel = Vector3.ZERO
	bot.scrap = Config.BUBBLE_COST * 30   # rich enough not to go looking for scrap
	var picked: Variant = brain._pick_cheese()
	check(picked != null and Vector3i((picked as Vector3).floor()) == fake, "a bot takes the other team's decoy for cheese")
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	t = 0.0
	while t < 15.0 and not kinds.has("decoy"):
		m.step(DT)
		t += DT
	check(kinds.has("decoy") and bot.stun > 0.0 and m.world.get_cell(own) == Blocks.DECOY_BLUE, "and digs it, and gets a face full of stink (%.1f s)" % t)
	end(m)


func test_sound_levels() -> void:
	## Someone else's digging is much quieter than your own; dash and pound are soft.
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var me := arena_rat(m, 0, "digger")
	run(m, 0.2)
	var view := MatchView.new()
	view.m = m
	view.listener = me
	var near := Vector3(ARENA) + Vector3(2.5, 0.5, 0.5)
	var far := Vector3(ARENA) + Vector3(9.5, 0.5, 0.5)
	var own := view._volume(near)
	var other := view._volume(far, MatchView.OTHERS_DIG_FALLOFF) + MatchView.OTHERS_DIG_GAIN
	var before := view._volume(far)      # how loud it used to be
	check(other < before - 12.0, "another rat digging 9 blocks off is much quieter than before (%.0f dB vs %.0f dB)" % [other, before])
	check(own > other + 15.0, "and well below your own digging (%.0f dB)" % own)
	view.free()
	end(m)


func test_pools_springs_raids_sparks() -> void:
	# generated water and lava always sit in a bank: nothing faces open air
	for seed_n: int in [4242, 7]:
		var g := VoxelWorld.new()
		g.visual = false
		MapGenerator.generate(g, seed_n, MapGenerator.min_cheese(8))
		var open := 0
		for liquid: int in [Blocks.WATER, Blocks.LAVA]:
			var i := g.data.find(liquid)
			while i >= 0:
				var c := Vector3i(i % VoxelWorld.SX, i / (VoxelWorld.SX * VoxelWorld.SZ), (i / VoxelWorld.SX) % VoxelWorld.SZ)
				for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]:
					if g.get_cell(c + d) == Blocks.AIR:
						open += 1
				i = g.data.find(liquid, i + 1)
		check(open == 0, "seed %d: generated water and lava never face open air (%d)" % [seed_n, open])
		g.free()
	# a wall spring shoves anyone who comes within a block of it
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var wall := ARENA + Vector3i(0, 0, 0)
	m.world.set_block(wall, Blocks.WALL_SPRING)
	var beside := arena_rat(m, 0, "scout", Vector3(1.0, 0, 0))       # standing in the cell next to it
	var corner := arena_rat(m, 1, "digger", Vector3(-1.0, 0, -1.0))  # diagonal
	var far := arena_rat(m, 0, "builder", Vector3(2.6, 0, 3.0))      # two blocks off
	m.step(DT)
	check(beside.vel.x > Config.WALL_SPRING_SPEED * 0.8, "standing right next to a wall spring shoves you away (%s)" % str(beside.vel))
	check(corner.vel.x < -5.0 and corner.vel.z < -5.0, "diagonally too, either team")
	check(far.vel.length() < 1.0, "two blocks away is out of its reach")
	run(m, 1.5)
	check(beside.position.distance_to(Vector3(wall) + Vector3(0.5, 0, 0.5)) > 2.0, "and the shove carries you clear")
	end(m)
	# bots give up raiding a base its team has been guarding for a while
	m = new_match()
	m.scores = [0, 3]                       # blue is well behind: blue bots want to raid
	var raider := m.spawn_rat(0, "scout", true)
	if raider.id % 2 != 0:
		raider = m.spawn_rat(0, "scout", true)
	var brain: BotBrain = null
	for b in m.bots:
		if b.rat == raider:
			brain = b
	var guard := m.spawn_rat(1, "digger", false)
	guard.position = MapGenerator.spawn_point(1)
	run(m, 1.0)
	check(m.guard_t[1] > 0.9 and m.guard_t[1] < 1.2, "the match times how long red has stood guard at home (%.1f s)" % m.guard_t[1])
	brain._retarget()
	check(brain.mode == "raid", "a blue bot well behind goes raiding")
	m.guard_t[1] = Config.BOT_RAID_GUARDED + 1.0
	brain._retarget()
	check(brain.mode != "raid", "but not once red has guarded its base for %.0f s" % Config.BOT_RAID_GUARDED)
	guard.position = MapGenerator.spawn_point(0)
	m.step(DT)
	check(m.guard_t[1] == 0.0, "the clock resets when the guard leaves")
	end(m)
	# dig sparks scatter around the crosshair on the face being dug
	var view := MatchView.new()
	var aimer := PlayerController.new()
	view.ctl = aimer
	var cell := Vector3i(10, 20, 10)
	aimer.aim = {"cell": cell, "normal": Vector3i(0, 1, 0), "point": Vector3(10.5, 21.0, 10.5)}
	var spots: Array[Vector3] = []
	for k in 6:
		spots.append(view._spark_spot(Vector3(cell) + Vector3(0.5, 0.5, 0.5)))
	var on_face := true
	for p in spots:
		on_face = on_face and absf(p.y - 21.06) < 0.01 and Vector2(p.x - 10.5, p.z - 10.5).length() < 0.45
	check(on_face and spots[0] != spots[1], "dig sparks scatter around the crosshair on the face (%s)" % str(spots[0]))
	aimer.free()
	view.free()
	# the new bits of art and sound are there; the old POW is gone
	check(FxSheets.SHEETS.has("dizzy") and not FxSheets.SHEETS.has("pow") and FileAccess.file_exists("res://assets/sfx/alarm.wav"), "bonks show dizzy stars; the raid alarm is the new chime")


func test_crumb_trail() -> void:
	## Everyone carrying cheese leaves crumbs on the ground to follow.
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var crumbs: Array[Vector3] = []
	m.fx.connect(func(kind: String, p: Vector3, _d: Variant) -> void:
		if kind == "crumb":
			crumbs.append(p))
	var r := arena_rat(m, 0, "digger", Vector3(-7, 0, 0))
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	run(m, 2.0)
	check(crumbs.is_empty(), "no cheese, no crumbs")
	r.position = Vector3(ARENA) + Vector3(-6.5, 0, 0.5)
	r.carried = 1
	run(m, 3.0)
	var travelled := r.position.x - (ARENA.x - 6.5)
	check(crumbs.size() >= int(travelled / Config.CRUMB_EVERY) - 1 and crumbs.size() >= 3, "a carrier drops a trail (%d crumbs over %.1f blocks)" % [crumbs.size(), travelled])
	var spaced := true
	for i in range(1, crumbs.size()):
		if crumbs[i].distance_to(crumbs[i - 1]) < Config.CRUMB_EVERY - 0.01:
			spaced = false
	check(spaced, "one crumb every %.1f blocks" % Config.CRUMB_EVERY)
	check(not crumbs.is_empty() and absf(crumbs[0].y - float(ARENA.y)) < 0.05, "on the ground")
	# none in mid-air: a jump holds the count until we land
	crumbs.clear()
	r.position = Vector3(ARENA) + Vector3(-6.5, 0, 2.5)
	r.vel = Vector3.ZERO
	run(m, 0.2)
	crumbs.clear()
	var airborne := 0
	for i in 60:
		r.jump_pressed = r.on_floor
		var n := crumbs.size()
		m.step(DT)
		if crumbs.size() > n and not m.world.solid_point(crumbs[-1] - Vector3(0, 0.12, 0)):
			airborne += 1
	check(airborne == 0, "never in mid-air")
	# the view lays them out and they fade away
	var trail := CrumbTrail.new()
	add_child(trail)
	trail.add(Vector3(ARENA))
	trail.add(Vector3(ARENA) + Vector3(1.4, 0, 0))
	check(trail.count() == 2, "the view draws each crumb")
	trail._process(Config.CRUMB_TIME - 1.0)
	check(trail.count() == 2, "they lie there for %.0f s..." % Config.CRUMB_TIME)
	trail._process(1.5)
	check(trail.count() == 0, "...then they're gone")
	trail.queue_free()
	end(m)


func windup_wall(m: Match, x: int, height: int) -> void:
	for dz in range(-8, 9):
		for dy in height:
			m.world.set_block(ARENA + Vector3i(x, dy, dz), Blocks.STONE)


func test_windup_decoy() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	var blue := arena_rat(m, 0, "digger")
	var red := arena_rat(m, 1, "scout", Vector3(0, 0, 6))
	blue.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	blue.scrap = 20
	check(m.try_buy(blue, "windup") == "" and int(blue.gadgets.get("windup", 0)) == 1 and blue.scrap == 6, "a Wind-up Decoy costs 14 scrap")
	m.set_equipped(blue, "windup")
	check(m.try_place_gadget(blue, ARENA, "windup") != "", "it isn't placed like a block")
	blue.position = Vector3(ARENA) + Vector3(-6.5, 0, 0.5)
	blue.yaw = PI * 0.5
	run(m, 0.2)
	windup_wall(m, -3, 1)    # a step to hop up
	windup_wall(m, 3, 3)     # a wall to turn at
	kinds.clear()
	check(m.try_use_equipped(blue, {}, Vector3(1, 0, 0), false) == "" and m.windup.walkers.size() == 1, "Q sets it down")
	check(kinds.has("windup") and int(blue.gadgets.get("windup", 0)) == 0, "single use")
	var w: WindupSystem.Walker = m.windup.walkers[0]
	var b := w.body
	check(w.team == 0 and b.carried == 1 and b.display_name == blue.display_name and b.class_id == blue.class_id,
		"it wears its owner's colours, class and name, and holds a cheese")
	check(not m.rats.has(b), "it's no rat: it never scores, raids or takes a seat")
	var start := b.position
	run(m, 1.0)
	check(b.position.x - start.x > 1.5 and absf(b.position.z - start.z) < 0.2, "it marches the way it was set down (%.1f blocks)" % (b.position.x - start.x))
	var top := b.position.y
	var t := 0.0
	while t < 4.0 and b.position.x < ARENA.x - 1.0:
		m.step(DT)
		t += DT
		top = maxf(top, b.position.y)
	check(top >= float(ARENA.y) + 1.0 and b.position.x > ARENA.x - 1.0, "it hops up a step (%.1f)" % (top - ARENA.y))
	t = 0.0
	while t < 5.0 and absf(w.dir.z) < 0.5:
		m.step(DT)
		t += DT
	var turned_at := b.position
	run(m, 0.6)
	check(absf(w.dir.z) > 0.5 and absf(b.position.z - turned_at.z) > 0.6 and b.position.x < ARENA.x + 3.0,
		"it turns at a wall and keeps going (%.1f s)" % t)
	check(kinds.has("crumb"), "it drops crumbs like a real carrier")
	# your own team's bonks pass through it; the other team's set it off
	blue.position = b.position + Vector3(0.8, 0, 0)
	blue.bonk_cd = 0.0
	check(not m.windup.try_bonk(blue, w) and m.windup.walkers.size() == 1, "its own team can't set it off")
	red.position = b.position + Vector3(-0.8, 0, 0)
	red.bonk_cd = 0.0
	red.stun = 0.0
	blue.vel = Vector3.ZERO
	kinds.clear()
	var at := b.position
	check(m.windup.try_bonk(red, w) and m.windup.walkers.is_empty(), "an enemy bonk sets it off")
	check(kinds.has("boom") and red.vel.length() > 5.0, "like TNT: the bonker is blown away")
	var holes := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if m.world.get_cell(Vector3i(floori(at.x) + dx, ARENA.y - 1, floori(at.z) + dz)) == Blocks.AIR:
				holes += 1
	check(holes >= 3, "and the floor around it (%d holes)" % holes)
	# left alone it goes off by itself, with a warning first
	m.free_mode = true
	blue.position = Vector3(ARENA) + Vector3(-6.5, 0, -6.5)
	blue.throw_cd = 0.0
	run(m, 0.2)
	kinds.clear()
	m.try_use_equipped(blue, {}, Vector3(0, 0, 1), false)
	var walker: WindupSystem.Walker = m.windup.walkers[0]
	run(m, Config.WINDUP_FUSE - 2.0)
	check(m.windup.walkers.has(walker) and not kinds.has("boom"), "it marches for %.0f s..." % Config.WINDUP_FUSE)
	run(m, 2.5)
	check(not m.windup.walkers.has(walker) and kinds.has("windup_warn") and kinds.has("boom"), "...warns, then goes off by itself")
	# other blasts set it off: chains
	for x in [-5.5, -3.5]:
		var c := m.windup.spawn(0, blue.id, "digger", "x", Vector3(ARENA) + Vector3(x, 0, 6.5), Vector3(0, 0, -1))
		c.fuse = 99.0
	m.blast(Vector3(ARENA) + Vector3(-7.5, 0.5, 6.5), Config.TNT_RADIUS, Config.TNT_POWER)
	run(m, 0.6)
	check(m.windup.walkers.is_empty(), "a blast sets off the wind-ups next to it, one after the other")
	# lava finishes it
	m.world.set_block(ARENA + Vector3i(5, 0, -7), Blocks.LAVA)
	var hot := m.windup.spawn(1, red.id, "scout", "y", Vector3(ARENA) + Vector3(5.5, 0, -5.5), Vector3(0, 0, -1))
	hot.fuse = 99.0
	run(m, 1.5)
	check(m.windup.walkers.is_empty(), "lava sets it off")
	end(m)


func test_bots_chase_windups() -> void:
	## Bots can't tell a Wind-up Decoy from a carrier: they chase it and bonk it.
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var bot := m.spawn_rat(1, "digger", true)
	bot.position = Vector3(ARENA) + Vector3(5.5, 0, 0.5)
	bot.gear = "jetpack"
	bot.scrap = 40
	var blue := arena_rat(m, 0, "digger", Vector3(-7, 0, -7))
	var brain: BotBrain = null
	for b in m.bots:
		if b.rat == bot:
			brain = b
	var w := m.windup.spawn(0, blue.id, "digger", blue.display_name, Vector3(ARENA) + Vector3(-1.5, 0, 0.5), Vector3(0, 0, 1))
	w.fuse = 99.0
	check(brain._pick_carrier() != null, "a bot takes it for a carrier")
	var own := m.windup.spawn(1, bot.id, "digger", "z", Vector3(ARENA) + Vector3(2.5, 0, -5.5), Vector3(1, 0, 0))
	own.fuse = 99.0
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	var t := 0.0
	while t < 8.0 and m.windup.walkers.has(w):
		m.step(DT)
		t += DT
	check(not m.windup.walkers.has(w) and kinds.has("boom"), "and runs after it and bonks it: boom (%.1f s)" % t)
	check(m.windup.walkers.has(own) or own.body.position.y < float(ARENA.y) - 1.0, "but leaves its own team's alone")
	# a real carrier gets chased too
	m.windup.remove(own)
	var red_bot := bot
	red_bot.position = Vector3(ARENA) + Vector3(5.5, 0, 0.5)
	blue.position = Vector3(ARENA) + Vector3(-0.5, 0, 0.5)
	blue.carried = 1
	red_bot.bonk_cd = 0.0
	run(m, 0.1)
	brain._retarget()
	check(brain.mode == "chase", "a bot chases an enemy hauling cheese nearby")
	end(m)


func test_windup_replica() -> void:
	## Online players get each wind-up in the snapshot: same look, same name.
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var blue := arena_rat(m, 0, "builder")
	blue.display_name = "Pip"
	var w := m.windup.spawn(0, blue.id, blue.class_id, blue.display_name, Vector3(ARENA) + Vector3(0.5, 0, 0.5), Vector3(1, 0, 0))
	run(m, 0.5)
	var rep := Match.new()
	rep.auto_step = false
	add_child(rep)
	rep.setup({"mode": "race", "seed": 4242, "goal": 3}, false, true)
	var spawned: Array[Rat] = []
	rep.windup_spawned.connect(func(b: Rat) -> void: spawned.append(b))
	rep.windup.apply(m.windup.snapshot())
	check(rep.windup.walkers.size() == 1 and spawned.size() == 1, "it arrives on a player's game (and gets a sprite)")
	var c: WindupSystem.Walker = rep.windup.walkers[0]
	check(c.uid == w.uid and c.team == 0 and c.body.display_name == "Pip" and c.body.class_id == "builder" and c.body.carried == 1,
		"with its owner's name, class and colours, and a cheese")
	check(rep.rats.is_empty(), "and not as a rat")
	rep.windup.glide(1.0)
	check(c.body.position.distance_to(w.body.position) < 0.3, "it glides to where the server has it")
	run(m, 0.5)
	rep.windup.apply(m.windup.snapshot())
	for i in 30:
		rep.windup.glide(DT)
	check(c.body.position.distance_to(w.body.position) < 0.35, "and follows it as it marches")
	m.windup.explode(w)
	rep.windup.apply(m.windup.snapshot())
	check(rep.windup.walkers.is_empty(), "gone when it goes off")
	# an online player's Q and bonk go through the server's checks
	var red := arena_rat(m, 1, "scout", Vector3(-4, 0, -4))
	red.position = Vector3(ARENA) + Vector3(-3.5, 0, -3.5)
	blue.position = Vector3(ARENA) + Vector3(3.5, 0, 3.5)
	m.free_mode = true
	m.set_equipped(blue, "windup")
	run(m, 0.3)
	var ns := NetServer.new()
	ns.m = m
	ns.seats[7] = blue
	ns.seats[8] = red
	blue.net_peer = 7
	red.net_peer = 8
	ns.on_act(7, "try_use_equipped", [{}, Vector3(-1, 0, -1), false, Vector3.ZERO])
	check(m.windup.walkers.size() == 1 and m.windup.walkers[0].team == 0, "a player's Q sets one marching on the server")
	var uid := m.windup.walkers[0].uid
	ns.on_act(8, "bonk_windup", [uid + 999])
	ns.on_act(8, "bonk_windup", ["junk"])
	check(m.windup.walkers.size() == 1, "a bonk at nothing (or junk) does nothing")
	ns.on_act(8, "bonk_windup", [uid])
	check(m.windup.walkers.size() == 1, "too far away to bonk")
	red.position = m.windup.walkers[0].body.position + Vector3(1.0, 0, 0)
	red.bonk_cd = 0.0
	ns.on_act(8, "bonk_windup", [uid])
	check(m.windup.walkers.is_empty(), "a remote enemy's bonk sets it off")
	ns.free()
	blue.net_peer = 0
	red.net_peer = 0
	remove_child(rep)
	rep.free()
	end(m)


func test_rat_views() -> void:
	## You can tell which way a rat faces: front, side (mirrored) or back.
	var away := Vector3(0, 0, -1)          # the rat faces -z...
	check(RatSprite.pick_view(away, Vector3(0, 0, -1), "side") == "front", "facing the camera: front view")
	check(RatSprite.pick_view(away, Vector3(0, 0, 1), "side") == "back", "facing away: back view")
	check(RatSprite.pick_view(away, Vector3(1, 0, 0), "front") == "side", "side on: side view")
	var edge := Vector3(sin(deg_to_rad(54.0)), 0, -cos(deg_to_rad(54.0)))
	check(RatSprite.pick_view(away, edge, "front") == "front" and RatSprite.pick_view(away, edge, "side") == "side",
		"near the boundary it keeps the view it has (no flicker)")
	for cls: String in ["digger", "scout", "builder", "saboteur"]:
		for v: String in ["front", "back"]:
			var ok := ResourceLoader.exists(RatSprite.sheet_path(cls, v))
			for anim: String in ["idle", "run", "jump"]:
				for f in int(RatSprite.FRAMES[anim]):
					ok = ok and RatSprite._frame(cls, 1, anim, f, v) != null
			check(ok, "%s has a %s view for idle, run and jump" % [cls, v])
	check(RatSprite._frame("digger", 0, "dig", 0, "front") == null and RatSprite._frame("digger", 0, "dig", 0) != null,
		"an empty cell falls back to the side view (digging shows the side)")
	check(RatSprite.sheet_path("maestro", "back") == RatSprite.sheet_path("builder", "back"), "the Maestro wears the Builder's art")
	# in a scene: the sprite follows the camera
	var m := new_match()
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var r := arena_rat(m, 0, "digger")
	var sprite := RatSprite.new()
	sprite.rat = r
	r.add_child(sprite)
	cam.global_position = r.position + Vector3(0, 1.0, -5.0)
	cam.look_at(r.position + Vector3(0, 0.5, 0))
	r.yaw = 0.0                            # facing -z, toward the camera
	sprite._process(0.02)
	check(sprite.view == "front" and sprite.texture != null and not sprite.flip_h, "a rat looking at you shows its face")
	r.yaw = PI
	sprite._process(0.02)
	check(sprite.view == "back", "turned away it shows its back")
	r.yaw = PI / 2.0                       # facing -x
	sprite._process(0.02)
	var left := Vector3(-1, 0, 0).dot(cam.global_transform.basis.x) < 0.0
	check(sprite.view == "side" and sprite.flip_h == left, "side on it shows its side, mirrored to the way it faces")
	r.yaw = -PI / 2.0
	sprite._process(0.02)
	check(sprite.view == "side" and sprite.flip_h != left, "and the other way round")
	r.yaw = 0.0
	r.play_action("dig", 0.3)
	sprite._process(0.02)
	check(sprite.view == "front" and sprite.texture == RatSprite._frame("digger", 0, "dig", 0),
		"digging toward you: the side art (no front dig drawn)")
	cam.queue_free()
	end(m)


func stand_on(m: Match, r: Rat, cell: Vector3i, seconds: float) -> void:
	r.position = Vector3(cell) + Vector3(0.5, 0.0, 0.5)
	r.vel = Vector3.ZERO
	run(m, seconds)


func test_teleporters() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var kinds: Array[String] = []
	var said: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, d: Variant) -> void:
		kinds.append(kind)
		if kind == "tele_no":
			said.append(String(d)))
	var eng := arena_rat(m, 0, "builder")
	var mate := arena_rat(m, 0, "scout", Vector3(0, 0, 3))
	var foe := arena_rat(m, 1, "digger", Vector3(0, 0, -3))
	eng.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	eng.scrap = 40
	check(m.try_buy(eng, "teleporter") == "" and int(eng.gadgets.get("teleporter", 0)) == 2 and eng.scrap == 24, "a Teleporter Set is two pads for 16 scrap")
	check(m.try_buy(eng, "teleporter") != "" and eng.scrap == 24, "one set per rat")
	m.set_equipped(eng, "teleporter")
	check(m.tele_next(eng) == "entrance", "the first pad is the entrance")
	eng.position = Vector3(ARENA) + Vector3(-4.5, 0, 0.5)
	run(m, 0.2)
	var a := ARENA + Vector3i(-3, 0, 0)
	var b := ARENA + Vector3i(5, 0, 5)
	check(m.try_use_equipped(eng, {"cell": a + Vector3i(0, -1, 0), "normal": Vector3i(0, 1, 0)}, Vector3(1, 0, 0), false) == "",
		"Q puts down the entrance")
	check(Blocks.is_tele_in(m.world.get_cell(a)) and m.tele_next(eng) == "exit" and kinds.has("tele_place"), "...and the next one is the exit")
	check(m.try_place_gadget(eng, ARENA + Vector3i(-4, 3, 2), "teleporter") != "", "a pad needs a floor")
	eng.position = Vector3(b) + Vector3(-1.5, 0, 0.5)
	run(m, 0.2)
	check(m.try_use_equipped(eng, {"cell": b + Vector3i(0, -1, 0), "normal": Vector3i(0, 1, 0)}, Vector3(1, 0, 0), false) == ""
		and m.world.get_cell(b) == Blocks.TELE_OUT_BLUE and int(eng.gadgets["teleporter"]) == 0, "then the exit")
	m._give_gadget(eng, "teleporter", 1)
	check(m.try_place_gadget(eng, b + Vector3i(-2, 0, -2), "teleporter") != "" and m.world.get_cell(b + Vector3i(-2, 0, -2)) == Blocks.AIR,
		"no third pad: one set per rat")
	eng.gadgets["teleporter"] = 0
	check(not m.world.solid_point(Vector3(a) + Vector3(0.5, 0.5, 0.5)), "you walk onto a pad, not into it")
	# a teammate standing on the entrance is sent to the exit
	kinds.clear()
	stand_on(m, mate, a, 0.2)
	check(mate.position.distance_to(Vector3(a) + Vector3(0.5, 0, 0.5)) < 0.2, "not at once: you stand on it a moment")
	run(m, Config.TELE_WAIT)
	check(mate.position.distance_to(Vector3(b) + Vector3(0.5, 0, 0.5)) < 0.3 and kinds.has("tele_go") and kinds.has("tele_arrive"),
		"a teammate on the entrance pops out at the exit")
	run(m, 1.0)
	check(mate.position.distance_to(Vector3(b) + Vector3(0.5, 0, 0.5)) < 0.3, "one way: the exit sends nobody back")
	# it recharges
	var ready_pad := func() -> bool:
		for p: Array in m.tele_pads():
			if p[0] == a:
				return bool(p[3])
		return false
	check(not ready_pad.call(), "the entrance recharges after a trip")
	stand_on(m, mate, a, Config.TELE_WAIT + 0.5)
	check(mate.position.distance_to(Vector3(a) + Vector3(0.5, 0, 0.5)) < 0.3, "and sends nobody while it does")
	run(m, Config.TELE_CHARGE)
	check(not ready_pad.call() and mate.position.distance_to(Vector3(b) + Vector3(0.5, 0, 0.5)) < 0.3, "once charged it sends whoever waits on it")
	# the owner uses it too; the other team can't
	stand_on(m, foe, a, Config.TELE_CHARGE + 1.0)
	check(foe.position.distance_to(Vector3(a) + Vector3(0.5, 0, 0.5)) < 0.3, "the other team can't use it")
	foe.position = Vector3(ARENA) + Vector3(-6.5, 0, -6.5)
	# no cheese through teleporters
	said.clear()
	mate.carried = 1
	stand_on(m, mate, a, 1.5)
	check(mate.position.distance_to(Vector3(a) + Vector3(0.5, 0, 0.5)) < 0.3 and mate.carried == 1, "cheese can't go through")
	check(said.size() == 1 and said[0].contains("cheese"), "you're told why, once (%s)" % str(said))
	mate.carried = 0
	mate.position = Vector3(ARENA) + Vector3(6.5, 0, -6.5)
	run(m, 0.1)
	stand_on(m, mate, a, Config.TELE_WAIT + 0.2)
	check(mate.position.distance_to(Vector3(b) + Vector3(0.5, 0, 0.5)) < 0.3, "without it, off you go")
	# a blocked exit
	m.world.set_block(b + Vector3i(0, 1, 0), Blocks.STONE)
	m.world.set_block(b + Vector3i(0, 0, 0), Blocks.AIR)
	check(not m.tele_out.has(eng.id) and m.tele_next(eng) == "exit", "a pad dug or built over is gone from the set")
	# the owner digs a pad back into the pack; anyone else just breaks it
	eng.position = Vector3(a) + Vector3(-1.5, 0, 0.5)
	eng.dig_cd = 0.0
	run(m, 0.1)
	m.try_dig(eng, a)
	check(m.world.get_cell(a) == Blocks.AIR and int(eng.gadgets["teleporter"]) == 1 and not m.tele_in.has(eng.id), "your own pad digs straight back into your pack")
	m.world.set_block(b + Vector3i(0, 1, 0), Blocks.AIR)
	eng.position = Vector3(a) + Vector3(-1.5, 0, 0.5)
	run(m, 0.1)
	m.try_place_gadget(eng, a, "teleporter")
	m._give_gadget(eng, "teleporter", 1)
	eng.position = Vector3(b) + Vector3(-1.5, 0, 0.5)
	run(m, 0.1)
	m.try_place_gadget(eng, b, "teleporter")
	check(m.tele_in.get(eng.id) == a and m.tele_out.get(eng.id) == b, "and goes down again")
	foe.position = Vector3(b) + Vector3(0, 0, -1.5) + Vector3(0.5, 0, 0.5)
	var hits := 0
	while m.world.get_cell(b) == Blocks.TELE_OUT_BLUE and hits < 40:
		foe.dig_cd = 0.0
		m.try_dig(foe, b)
		hits += 1
	check(m.world.get_cell(b) == Blocks.AIR and hits == Config.TRAP_HITS_ENEMY and int(foe.gadgets.get("teleporter", 0)) == 0,
		"the other team needs %d hits to break one, and gets nothing (%d)" % [Config.TRAP_HITS_ENEMY, hits])
	said.clear()
	stand_on(m, mate, a, Config.TELE_CHARGE + 1.0)
	check(mate.position.distance_to(Vector3(a) + Vector3(0.5, 0, 0.5)) < 0.3 and said.has("No exit yet"), "no exit, no trip")
	# a lost pad: buying tops the set up, at half price
	eng.gadgets["teleporter"] = 0
	eng.position = MapGenerator.spawn_point(0)
	eng.scrap = 20
	run(m, 0.2)
	check(m.try_buy(eng, "teleporter") == "" and int(eng.gadgets["teleporter"]) == 1 and eng.scrap == 12, "a broken pad is replaced for half the set's price")
	# online: the server moves a remote player (and so corrects their game), and sends the pads
	eng.position = Vector3(b) + Vector3(-1.5, 0, 0.5)
	run(m, 0.1)
	m.try_place_gadget(eng, b, "teleporter")
	mate.position = Vector3(ARENA) + Vector3(6.5, 0, -6.5)     # (step off: it told us "no exit" last time)
	run(m, Config.TELE_CHARGE)
	mate.net_peer = 9
	mate.position = Vector3(a) + Vector3(0.5, 0, 0.5)
	mate.vel = Vector3.ZERO
	var moved := false
	for i in int((Config.TELE_WAIT + 0.3) / DT):
		m.step(DT)
		if Match.net_state(mate) != mate.net_pre:
			moved = true
			break
		mate.position = Vector3(a) + Vector3(0.5, 0, 0.5)   # (their game keeps them standing there)
	check(moved and mate.position.distance_to(Vector3(b) + Vector3(0.5, 0, 0.5)) < 0.3, "a remote player is sent too, and told so")
	mate.net_peer = 0
	var ns := NetServer.new()
	ns.m = m
	var snap: Dictionary = ns._snapshot()
	ns.free()
	var pads: Array = snap.get("tp", [])
	check(pads.size() == 2, "the pads go out in each snapshot")
	var rep := Match.new()
	rep.auto_step = false
	add_child(rep)
	rep.setup({"mode": "race", "seed": 4242, "goal": 3}, false, true)
	rep.tele_net = pads
	check(rep.tele_pads().size() == 2 and rep.tele_next(eng) == "", "a player's game knows them (and that the set is out)")
	remove_child(rep)
	rep.free()
	end(m)


func test_impulse_grenade() -> void:
	var m := new_match()
	flat_arena(m, ARENA, 8)
	var kinds: Array[String] = []
	m.fx.connect(func(kind: String, _p: Vector3, _d: Variant) -> void: kinds.append(kind))
	var me := arena_rat(m, 0, "scout")
	me.position = MapGenerator.spawn_point(0)
	run(m, 0.3)
	me.scrap = 20
	check(m.try_buy(me, "impulse") == "" and int(me.gadgets.get("impulse", 0)) == 2 and me.scrap == 12, "two Impulse Grenades for 8 scrap")
	m.set_equipped(me, "impulse")
	check(m.try_place_gadget(me, ARENA, "impulse") != "", "it's thrown, not placed")
	# a wall to throw at, with things around it
	for dz in range(-3, 4):
		for dy in 4:
			m.world.set_block(ARENA + Vector3i(4, dy, dz), Blocks.STONE)
	me.position = Vector3(ARENA) + Vector3(-1.5, 0, 0.5)
	me.yaw = -PI / 2.0
	var near := arena_rat(m, 1, "digger", Vector3(2.0, 0, 1.5))
	var far := arena_rat(m, 1, "builder", Vector3(-7, 0, -7))
	near.carried = 1
	var cheese := m.spawn_pickup("cheese", Vector3(ARENA) + Vector3(2.5, 0.1, -1.5), Vector3.ZERO)
	var stick := m.dynamite.spawn(Vector3(ARENA) + Vector3(2.5, 0.2, -0.5), Vector3.ZERO, me.id, 9.0)
	var w := m.windup.spawn(0, me.id, "scout", "x", Vector3(ARENA) + Vector3(2.5, 0, 2.5), Vector3(0, 0, 1))
	w.fuse = 99.0
	run(m, 0.3)
	var before := m.world.data.duplicate()
	var dmg := m.world.damage.size()
	m.world.set_block(ARENA + Vector3i(3, 0, -3), Blocks.TNT)
	m.tnt[ARENA + Vector3i(3, 0, -3)] = {"owner": -1, "fuse": -1.0}
	before = m.world.data.duplicate()
	kinds.clear()
	check(m.try_use_equipped(me, {}, Vector3(1, 0, 0), false) == "" and int(me.gadgets["impulse"]) == 1, "Q throws one")
	var g: DynamiteSystem.Stick = null
	for s2 in m.dynamite.sticks:
		if s2.impulse:
			g = s2
	var t := 0.0
	while t < 1.0 and g != null and not g.stuck:
		m.step(DT)
		t += DT
	check(g != null and g.stuck and g.pos.x > ARENA.x + 3.4 and g.pos.x < ARENA.x + 4.01 and kinds.has("impulse_stick"),
		"it sticks to the wall it hits (%.2f s)" % t)
	var at := g.pos
	run(m, 0.2)
	check(m.dynamite.sticks.has(g) and g.pos == at, "and stays put...")
	var cheese_at := cheese.pos
	var stick_at := stick.pos
	run(m, Config.IMPULSE_FUSE)
	check(not m.dynamite.sticks.has(g) and kinds.has("impulse") and not kinds.has("boom"), "...then promptly bursts")
	var away := Vector3(near.position.x - at.x, 0, near.position.z - at.z).normalized()
	var flat := Vector3(near.vel.x, 0, near.vel.z)
	check(flat.length() > 2.5 and flat.normalized().dot(away) > 0.8 and near.knock > 0.0,
		"a rat near it is thrown away from it (%.1f, %s)" % [flat.length(), str(near.vel)])
	check(near.carried == 1, "and keeps its cheese")
	check(far.vel.length() < 0.5, "nobody far away feels it")
	run(m, 0.15)
	check(cheese.pos.distance_to(at) > cheese_at.distance_to(at) + 0.3, "loose cheese is pushed away")
	check(stick.pos.distance_to(at) > stick_at.distance_to(at) + 0.3, "and dynamite")
	check(w.body.position.distance_to(at) > Vector3(ARENA + Vector3i(2, 0, 2)).distance_to(at), "and wind-ups")
	check(m.world.data == before and m.world.damage.size() == dmg and not kinds.has("break") and float(m.tnt[ARENA + Vector3i(3, 0, -3)]["fuse"]) < 0.0,
		"it damages nothing: no blocks, no cracks, no TNT lit")
	# dropped at your feet it launches you
	m.dynamite.sticks.clear()
	near.position = Vector3(ARENA) + Vector3(-6.5, 0, 6.5)
	me.position = Vector3(ARENA) + Vector3(-1.5, 0, 0.5)
	me.vel = Vector3.ZERO
	me.knock = 0.0
	me.throw_cd = 0.0
	run(m, 0.3)
	var y0 := me.position.y
	check(m.try_use_equipped(me, {}, Vector3(1, 0, 0), true) == "", "Ctrl+Q drops it at your feet")
	var top := y0
	for i in int(2.0 / DT):
		m.step(DT)
		top = maxf(top, me.position.y)
	check(top > y0 + 3.0 and top < y0 + 8.0, "...and it launches you (%.1f blocks up)" % (top - y0))
	print("    self-launch height %.1f" % (top - y0))
	# thrown at a rat it sticks to them
	m.free_mode = true
	me.position = Vector3(ARENA) + Vector3(-4.5, 0, -4.5)
	near.position = Vector3(ARENA) + Vector3(-1.5, 0, -4.5)
	near.vel = Vector3.ZERO
	me.throw_cd = 0.0
	run(m, 0.5)
	m.try_use_equipped(me, {}, Vector3(1, 0.05, 0), false)
	var stuck_to: Rat = null
	for i in 40:
		m.step(DT)
		for s3 in m.dynamite.sticks:
			if s3.stuck:
				stuck_to = s3.stuck_to
	check(stuck_to == near, "thrown at a rat, it sticks to the rat")
	# online players see it in flight and stuck
	me.throw_cd = 0.0
	m.try_use_equipped(me, {}, Vector3(0, 0, 1), false)
	var ns := NetServer.new()
	ns.m = m
	var snap: Dictionary = ns._snapshot()
	ns.free()
	var ok := false
	for e: Array in snap.get("st", []):
		ok = ok or (e.size() > 6 and bool(e[5]))
	check(ok, "the snapshot says which sticks are impulse grenades")
	end(m)


func test_credits_and_licences() -> void:
	## The game must show Godot's licence and every third-party notice it ships with.
	var t := Credits.text()
	check(t.contains("Godot Engine") and t.contains(Engine.get_license_text().substr(0, 60)), "Godot's MIT licence text is in the credits")
	for name: String in ["FreeType", "ENet", "mbed"]:
		check(t.contains(name), "the %s notice is in the credits" % name)
	check(t.contains("pixelfx") and t.contains("Permission is hereby granted"), "pixelfx's MIT licence is in the credits")
	check(not t.contains("licence file missing"), "the pixelfx licence file is packed with the game")
	check(t.contains(String(ProjectSettings.get_setting("application/config/version"))), "and the game version")


func test_display_and_audio_settings() -> void:
	## Music and sound effects have their own buses and sliders; display
	## settings apply without a window (headless) and are stored like the rest.
	var keep := {}
	for k: String in ["sfx_volume", "music_volume", "max_fps", "render_scale"]:
		keep[k] = Config.get_value(k)
	Config.apply_audio()
	check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0, "Music and SFX buses exist")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == &"Master", "and feed the master bus")
	Config.set_value("sfx_volume", 0.25)
	Config.set_value("music_volume", 0.0)
	Config.apply_audio()
	var sfx := AudioServer.get_bus_index("SFX")
	check(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.25)) < 0.01, "the SFX slider sets the SFX bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music at zero mutes the music bus")
	var sfx_players := 0
	var music_players := 0
	for c in Sfx.get_children():
		if c is AudioStreamPlayer:
			if (c as AudioStreamPlayer).bus == &"SFX":
				sfx_players += 1
			elif (c as AudioStreamPlayer).bus == &"Music":
				music_players += 1
	check(sfx_players >= 8 and music_players == 1, "sound effects and music play on their own buses")
	Config.set_value("max_fps", 60)
	Config.set_value("render_scale", 0.7)
	Config.apply_display()
	check(Engine.max_fps == 60 and absf(get_tree().root.scaling_3d_scale - 0.7) < 0.01, "frame cap and 3D resolution apply")
	check(not Config.display_supported(), "(headless: no window to change, and nothing breaks)")
	var panel := SettingsPanel.new()
	add_child(panel)
	var texts: Array[String] = []
	var stack: Array[Node] = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			texts.append((n as Label).text)
		stack.append_array(n.get_children())
	check(texts.has("Effects volume") and texts.has("Frame rate limit") and texts.has("Display"),
		"the settings panel has the display and audio rows")
	panel.queue_free()
	for k: String in keep:
		Config.set_value(k, keep[k])
	Config.apply_audio()
	Config.apply_display()


func _mesh_vertex_count(w: VoxelWorld, k: Vector3i) -> int:
	var mi: MeshInstance3D = w._chunks.get(k)
	if mi == null or mi.mesh == null:
		return -1
	var n := 0
	for i in mi.mesh.get_surface_count():
		n += (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


func test_threaded_remesh() -> void:
	## Digging re-meshes on worker threads: the main thread only starts the
	## job and installs the result, and edits made meanwhile are not lost.
	var w := VoxelWorld.new()
	add_child(w)
	MapGenerator.generate(w, 4242, 3)
	var cell := Vector3i(40, 30, 40)
	var k := Vector3i(cell.x / VoxelWorld.CHUNK, cell.y / VoxelWorld.CHUNK, cell.z / VoxelWorld.CHUNK)
	w._dirty.clear()
	w._rebuild_chunk(k)
	var before := _mesh_vertex_count(w, k)
	w.set_block(cell, Blocks.AIR)
	check(w._dirty.has(k), "an edit marks its chunk dirty")
	var t0 := Time.get_ticks_usec()
	w._process(0.016)
	var start_us := Time.get_ticks_usec() - t0
	check(w._job >= 0 and not w._dirty.has(k), "the chunk goes to a worker")
	# carve another block in the same chunk while the first job runs
	var cell2 := cell + Vector3i(1, 0, 0)
	w.set_block(cell2, Blocks.AIR)
	check(w._dirty.has(k), "an edit during the job marks the chunk dirty again")
	var frames := 0
	var worst_us := start_us
	while w.remesh_busy() and frames < 600:
		OS.delay_msec(1)
		var t1 := Time.get_ticks_usec()
		w._process(0.016)
		worst_us = maxi(worst_us, Time.get_ticks_usec() - t1)
		frames += 1
	check(not w.remesh_busy(), "the new meshes arrive (%d frames)" % frames)
	var expect := 0
	for surf: Array in ChunkMesher.build_arrays(w, k):
		expect += (surf[0] as PackedVector3Array).size()
	var got := _mesh_vertex_count(w, k)
	check(got == expect and got != before, "the final mesh includes both edits (%d -> %d vertices)" % [before, got])
	check(worst_us < 8000, "the main thread never meshes: worst frame %.2f ms" % (worst_us / 1000.0))
	print("    remesh: start %.2f ms, worst frame %.2f ms, %d frames" % [start_us / 1000.0, worst_us / 1000.0, frames])
	remove_child(w)
	w.free()


func test_merged_terrain_faces() -> void:
	## Plain block faces are merged into big quads: the same surface area,
	## far fewer triangles, each tagged for terrain.gdshader.
	var w := VoxelWorld.new()
	w.visual = false
	add_child(w)
	var k := Vector3i(2, 1, 2)
	var o := k * VoxelWorld.CHUNK
	for x in 16:
		for z in 16:
			for y in 6:
				var id := Blocks.STONE if y < 3 else Blocks.DIRT
				if y == 5:
					id = Blocks.GRASS
				w.set_raw(o.x + x, o.y + y, o.z + z, id)
	w.set_raw(o.x + 4, o.y + 6, o.z + 4, Blocks.CHEESE)
	w.set_raw(o.x + 9, o.y + 6, o.z + 9, Blocks.OBSIDIAN)
	w.set_raw(o.x + 12, o.y + 6, o.z + 3, Blocks.STONE)
	# count every exposed face of every block, the old way
	var faces := 0
	for x in 16:
		for y in 16:
			for z in 16:
				var c := o + Vector3i(x, y, z)
				var id := w.get_cell(c)
				if id == Blocks.AIR:
					continue
				for f in 6:
					var n := c + Vector3i(ChunkMesher.NX[f], ChunkMesher.NY[f], ChunkMesher.NZ[f])
					if n.y < 0 or not VoxelWorld.in_bounds(n):
						continue
					if Blocks.OPAQUE[w.get_cell(n)] == 0:
						faces += 1
	var area := 0.0
	var tris := 0
	var modes := {}
	for surf: Array in ChunkMesher.build_arrays(w, k):
		if int(surf[3]) != -1:
			continue
		var v: PackedVector3Array = surf[0]
		var uv: PackedVector2Array = surf[2]
		check(uv.size() == v.size(), "every opaque vertex carries a shading tag")
		for i in range(0, v.size(), 3):
			if uv[i].x < 0.5:
				continue
			tris += 1
			area += (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).length() * 0.5
			modes[int(uv[i].x)] = true
	check(absf(area - float(faces)) < 0.01, "merged quads cover exactly the exposed faces (%.0f vs %d)" % [area, faces])
	check(tris * 4 < faces * 2, "with far fewer triangles (%d instead of %d)" % [tris, faces * 2])
	check(modes.has(1) and modes.has(2) and modes.has(3) and modes.has(4),
		"dirt and grass, cheese, stone and obsidian each get their own shading (%s)" % str(modes.keys()))
	remove_child(w)
	w.free()


func test_safe_saves_and_exit() -> void:
	## Saves go to a temporary file first and are swapped in whole.
	var path := "user://test_atomic.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("a", "b", 42)
	check(Config.write_atomic(path, func(tmp: String) -> int: return cfg.save(tmp)) == OK, "an atomic write succeeds")
	var back := ConfigFile.new()
	check(back.load(path) == OK and int(back.get_value("a", "b", 0)) == 42, "and the file reads back")
	check(not FileAccess.file_exists(path + ".tmp"), "with no temporary file left behind")
	# a failing writer leaves the old file untouched
	check(Config.write_atomic(path, func(_tmp: String) -> int: return ERR_CANT_CREATE) != OK, "a failed write reports an error")
	back = ConfigFile.new()
	check(back.load(path) == OK and int(back.get_value("a", "b", 0)) == 42, "and the old file survives it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# maps too
	var m := new_match()
	var map_path := "user://maps/test_atomic.bwmap"
	check(m.world.save_to(map_path), "a map saves")
	check(VoxelWorld.file_ok(map_path) and not FileAccess.file_exists(map_path + ".tmp"), "whole, with no temporary file left")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	end(m)
	# the shared caches can be emptied at exit and fill again on demand
	check(Icons.tex("cheese") != null, "icons load")
	RatSprite.clear_caches()
	Icons.clear_cache()
	FxSprite.clear_cache()
	BlockTextures.clear_cache()
	UiKit.clear_cache()
	check(Icons.tex("cheese") != null and RatSprite._frame("digger", 0, "idle", 0) != null and UiKit.theme() != null,
		"after clearing, everything loads again")


func test_tutorial() -> void:
	## Learn to Play: each step ticks off when the player has really done it.
	var keep := bool(Config.get_value("tutorial_done"))
	var m := new_match({"goal": 1, "seed": 4242})
	var me := m.spawn_rat(0, "digger", false)
	m.spawn_rat(1, "scout", true)
	run(m, 0.3)
	var guide := TutorialGuide.new()
	guide.m = m
	guide.rat = me
	add_child(guide)
	guide.setup()
	m.fx.connect(guide.on_fx)
	check(m.bots.is_empty() and guide.dummy != null and guide.dummy.team == 1, "nobody else plays; the other rat is the practice rat")
	check(m.world.get_cell(guide.cheese_cell) == Blocks.CHEESE, "a cheese is buried for the lesson")
	check(Blocks.SOLID[m.world.get_cell(guide.cheese_cell + Vector3i(0, 1, 0))] == 1, "under one block of ground")
	check(guide.step == 0 and guide.text_for(0).contains(Inputs.key_name("move_forward")), "step 1 names your own keys")
	# 1 move
	guide.poll()
	check(guide.step == 0, "nothing ticks off by itself")
	me.position += Vector3(3.5, 0, 0)
	guide.poll()
	check(guide.step == 1, "walking ticks off step 1")
	# 2 workshop
	me.position = MapGenerator.spawn_point(0)
	run(m, 0.2)
	check(m.try_buy(me, "ladder") == "", "buy ladders at base")
	guide.poll()
	check(guide.step == 2, "buying something ticks off step 2")
	# 3 dig: three blocks next to the base, for real
	var front := MapGenerator.approach_point(0)
	me.position = Vector3(floorf(front.x) + 0.5, m.world.surface_y(floori(front.x), floori(front.z)), floorf(front.z) + 0.5)
	me.vel = Vector3.ZERO
	run(m, 0.3)
	var dug := 0
	for dz in [1, -1, 2, -2, 3]:
		var cell := Vector3i(floori(me.position.x) + 1, floori(me.position.y) - 1, floori(me.position.z) + dz)
		for hit in 12:
			if Blocks.SOLID[m.world.get_cell(cell)] == 0:
				break
			me.dig_cd = 0.0
			m.try_dig(me, cell)
		if Blocks.SOLID[m.world.get_cell(cell)] == 0:
			dug += 1
	guide.poll()
	check(dug >= 3 and guide.step == 3, "digging 3 blocks ticks off step 3 (%d dug)" % dug)
	# 4 place two blocks
	for dz in [1, -1]:
		var cell := Vector3i(floori(me.position.x) + 1, floori(me.position.y), floori(me.position.z) + dz)
		m.world.set_block(cell, Blocks.AIR)
		m.try_place_mat(me, cell, "dirt" if int(me.mats["dirt"]) > 0 else "stone")
	guide.poll()
	check(guide.step == 4, "placing 2 blocks ticks off step 4")
	check(m.markers.size() == 1 and String(m.markers[0]["text"]) == "Practice Rat", "the practice rat is marked")
	# 5 bonk the practice rat
	me.position = guide.dummy.position + Vector3(1.2, 0, 0)
	me.bonk_cd = 0.0
	me.stun = 0.0
	run(m, 0.05)
	m.try_bonk(me, guide.dummy)
	guide.poll()
	check(guide.step == 5, "bonking it ticks off step 5")
	# 6 pick up the cheese
	check(m.markers.size() == 1 and String(m.markers[0]["text"]) == "Cheese here", "the cheese is marked")
	m.world.set_block(guide.cheese_cell, Blocks.AIR)
	m.spawn_pickup("cheese", me.position + Vector3(0, 0.2, 0), Vector3.ZERO)
	run(m, 0.5)
	guide.poll()
	check(me.carried > 0 and guide.step == 6, "picking it up ticks off step 6")
	# dropping it sends you back for it
	m.drop_cheese(me)
	guide.poll()
	check(guide.step == 5 and me.carried == 0, "drop it and the guide sends you back for it")
	run(m, 2.5)
	me.vel = Vector3.ZERO
	var picked := false
	for p in m.pickups:
		if p.kind == "cheese":
			me.position = p.pos
			picked = true
	run(m, 0.5)
	guide.poll()
	check(picked and me.carried > 0 and guide.step == 6, "pick it up again")
	# 7 bank it
	var done := [false]
	guide.finished.connect(func() -> void: done[0] = true)
	me.position = MapGenerator.spawn_point(0)
	me.vel = Vector3.ZERO
	run(m, 0.5)
	guide.poll()
	check(m.scores[0] >= 1 and m.over and done[0], "banking it wins the match and finishes the tutorial")
	check(bool(Config.get_value("tutorial_done")), "and it's remembered")
	Config.set_value("tutorial_done", keep)
	Config.save()
	guide.queue_free()
	end(m)


func _pad_button(button: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	return e


func _feed(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _pad_axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	return e


func _ac_arena() -> Array:
	## [match, rat, AntiCheat, clock] in the test arena with open sky above.
	var m := new_match()
	flat_arena(m, ARENA, 6)
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			for dy in range(6, 28):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.AIR)
	var r := arena_rat(m, 0, "digger")
	for i in 30:
		r.step(DT)
	var ac := AntiCheat.new()
	ac.log_violations = false
	var clock := [100000]
	ac.reset(7, r, clock[0])
	return [m, r, ac, clock]


func _ac_play(r: Rat, ac: AntiCheat, clock: Array, seconds: float, each: Callable) -> Array:
	## Runs the real rat physics and reports its position 30 times a second,
	## as a player's game does. Returns whatever the checks objected to.
	var bad: Array = []
	for i in int(seconds / DT):
		each.call(i)
		r.step(DT)
		r.jump_pressed = false
		r.gear_pressed = false
		if i % 2 == 1:
			clock[0] += 33
			var v := ac.check_move(7, r, r.position, clock[0])
			if v != "":
				bad.append("%.2f s: %s" % [i * DT, v])
	return bad


func test_anti_cheat_honest_play() -> void:
	## The movement checks never object to anything the real physics does.
	var ctx := _ac_arena()
	var m: Match = ctx[0]
	var r: Rat = ctx[1]
	var ac: AntiCheat = ctx[2]
	var clock: Array = ctx[3]
	check(r.on_floor, "the test rat stands on the arena floor")
	var floor_y := r.position.y
	# walk, jump, double jump at the top
	var bad := _ac_play(r, ac, clock, 2.0, func(i: int) -> void:
		r.wish = Vector3(1, 0, 0) if i < 40 else Vector3.ZERO
		r.jump_pressed = i == 0 or i == 20)
	check(bad.is_empty(), "a jump and a double jump pass %s" % str(bad))
	# a ledge: up onto a 2-high block and off the far side
	var ledge := ARENA + Vector3i(-3, 0, 0)
	m.world.set_block(ledge, Blocks.STONE)
	m.world.set_block(ledge + Vector3i(0, 1, 0), Blocks.STONE)
	r.position = Vector3(ledge) + Vector3(0.5, 2.0, 0.5)
	ac.reset(7, r, clock[0])
	bad = _ac_play(r, ac, clock, 1.5, func(_i: int) -> void: r.wish = Vector3(0, 0, 1))
	check(bad.is_empty() and r.position.y < floor_y + 0.1, "walking off a ledge and falling passes %s" % str(bad))
	# a corner: walk diagonally into a pillar and slide round it
	var pillar := ARENA + Vector3i(2, 0, 2)
	for dy in 3:
		m.world.set_block(pillar + Vector3i(0, dy, 0), Blocks.STONE)
	r.position = Vector3(pillar) + Vector3(-0.8, 0, -0.8)
	ac.reset(7, r, clock[0])
	bad = _ac_play(r, ac, clock, 1.5, func(_i: int) -> void: r.wish = Vector3(1, 0, 1).normalized())
	check(bad.is_empty(), "sliding round a corner is not walking through it %s" % str(bad))
	# a spring: fall onto it, bounce, double jump at the top of the bounce
	var spring := ARENA + Vector3i(-2, -1, -3)
	m.world.set_block(spring, Blocks.SPRING)
	r.position = Vector3(spring) + Vector3(0.5, 4.0, 0.5)
	r.vel = Vector3.ZERO
	r.wish = Vector3.ZERO
	ac.reset(7, r, clock[0])
	var top := [0.0]
	bad = _ac_play(r, ac, clock, 3.0, func(i: int) -> void:
		top[0] = maxf(top[0], r.position.y - floor_y)
		r.jump_pressed = i > 20 and r.vel.y < 0.3 and r.vel.y > -0.3)
	check(top[0] > 4.0, "the spring bounced the rat (%.1f blocks up)" % top[0])
	check(bad.is_empty(), "spring bounces pass %s" % str(bad))
	# a jetpack burn after a jump, then the fall
	m.world.set_block(spring, Blocks.STONE)
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	r.vel = Vector3.ZERO
	for i in 10:
		r.step(DT)
	r.gear = "jetpack"
	r.gear_cd = 0.0
	ac.reset(7, r, clock[0])
	top[0] = 0.0
	bad = _ac_play(r, ac, clock, 4.5, func(i: int) -> void:
		top[0] = maxf(top[0], r.position.y - floor_y)
		r.jump_pressed = i == 0
		r.gear_pressed = i == 12)
	check(top[0] > 9.0, "the jetpack carried the rat up (%.1f blocks)" % top[0])
	check(bad.is_empty(), "a jetpack flight passes %s" % str(bad))
	r.gear = ""
	# swimming up a flooded shaft, and climbing a ladder
	var shaft := ARENA + Vector3i(4, 0, -4)
	for dy in 5:
		m.world.set_block(shaft + Vector3i(0, dy, 0), Blocks.WATER)
		m.world.set_block(shaft + Vector3i(1, dy, 0), Blocks.LADDER)
	r.position = Vector3(shaft) + Vector3(0.5, 0, 0.5)
	r.vel = Vector3.ZERO
	ac.reset(7, r, clock[0])
	bad = _ac_play(r, ac, clock, 2.0, func(_i: int) -> void:
		r.jump_held = true
		r.wish = Vector3.ZERO)
	check(bad.is_empty(), "swimming up passes %s" % str(bad))
	r.position = Vector3(shaft) + Vector3(1.5, 0, 0.5)
	r.vel = Vector3.ZERO
	ac.reset(7, r, clock[0])
	var y0 := r.position.y
	bad = _ac_play(r, ac, clock, 1.5, func(_i: int) -> void: r.jump_held = true)
	r.jump_held = false
	check(r.position.y > y0 + 3.0 and bad.is_empty(), "climbing a ladder passes (%.1f up) %s" % [r.position.y - y0, str(bad)])
	# thrown by the server (an impulse grenade): as high as that throw goes
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	r.vel = Vector3(4, Config.IMPULSE_MAX_UP, 0)
	ac.reset(7, r, clock[0])
	bad = _ac_play(r, ac, clock, 2.0, func(_i: int) -> void: r.wish = Vector3.ZERO)
	check(bad.is_empty(), "a server-side throw passes %s" % str(bad))
	end(m)


func test_anti_cheat_catches_cheats() -> void:
	## Forged movement and floods, as a modified game would send them.
	var ctx := _ac_arena()
	var m: Match = ctx[0]
	var r: Rat = ctx[1]
	var ac: AntiCheat = ctx[2]
	var clock: Array = ctx[3]
	var floor_y := r.position.y
	var start := r.position
	# a 2-thick wall right in front
	for dz in range(-2, 3):
		for dy in 3:
			for dx in [1, 2]:
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.STONE)
	var report := func(pos: Vector3, ms: int = 33) -> String:
		clock[0] += ms
		return ac.check_move(7, r, pos, clock[0])
	# noclip: one report from in front of the wall to behind it
	var v: String = report.call(start + Vector3(3.0, 0, 0), 300)
	check(v.begins_with("moved through"), "stepping through a wall is caught (%s)" % v)
	check(ac.good_position(7, r).distance_to(start) < 0.01, "and the rat goes back to where it was legally")
	ac.reset(7, r, clock[0])   # (the server's correction)
	# noclip, slowly: standing inside the wall
	v = report.call(start + Vector3(1.0, 0, 0))
	check(v == "", "a moment inside a block is let go (someone may just have built there)")
	var x := 1.0
	while v == "" and x < 3.0:
		x += 0.15   # walking pace
		v = report.call(start + Vector3(x, 0, 0))
	# a lagging game gets half a second inside before that alone counts; walking out of the far side is
	# then the tunnel check's catch - either way it never gets through
	check((v.begins_with("inside solid") or v.begins_with("moved through")) and x < 3.0,
		"staying inside it is caught before getting through (%s, at +%.2f)" % [v, x])
	check(ac.good_position(7, r).x < start.x + 0.9, "and goes back to this side of the wall (%s)" % ac.good_position(7, r))
	ac.reset(7, r, clock[0])
	# fly hack: rising steadily from the floor
	var flew := ""
	for i in 40:
		flew = report.call(start + Vector3(0, 0.3 * (i + 1), 0))
		if flew != "":
			check(0.3 * (i + 1) < AntiCheat.JUMP_RISE + AntiCheat.RISE_SLACK + 0.5, "caught by %.1f blocks up" % (0.3 * (i + 1)))
			break
	check(flew.contains("higher than"), "flying up is caught (%s)" % flew)
	ac.reset(7, r, clock[0])
	# hover hack: a hop, then hanging there
	var hung := ""
	var t := 0
	while t < 4000 and hung == "":
		t += 33
		hung = report.call(start + Vector3(0, 1.2, 0))
	check(hung.contains("higher than") and t < 2600, "hanging in the air is caught (after %.1f s)" % (t / 1000.0))
	ac.reset(7, r, clock[0])
	# a jetpack's climb without a jetpack
	r.gear = ""
	var jet := ""
	for i in 40:
		jet = report.call(start + Vector3(0, Config.JETPACK_LIFT * 0.033 * (i + 1), 0))
		if jet != "":
			break
	check(jet != "", "a jetpack climb without the jetpack is caught")
	ac.reset(7, r, clock[0])
	# Free Build flyers may fly
	var flyer := m.spawn_rat(0, "maestro", false)
	flyer.position = start
	ac.reset(8, flyer, clock[0])
	var fly_ok := true
	for i in 40:
		clock[0] += 33
		fly_ok = fly_ok and ac.check_move(8, flyer, start + Vector3(0, 0.3 * (i + 1), 0), clock[0]) == ""
	check(fly_ok, "a class that flies may fly")
	# strikes add up, fade, and (on a public server) remove the player
	ac.kick_out = true
	var removed := false
	var n := 0
	while not removed and n < 20:
		n += 1
		removed = ac.strike(7, "test", 1.0, clock[0])
	check(removed and n == 8 or (removed and n == 7), "a player is removed after %d strikes (%d)" % [int(AntiCheat.STRIKE_LIMIT), n])
	var before := ac.strikes(7)
	ac.strike(7, "test", 0.0, clock[0] + 60000)
	check(absf(ac.strikes(7) - (before - 2.0)) < 0.01, "strikes fade: one per %d s (%.1f -> %.1f)" % [int(AntiCheat.STRIKE_FADE), before, ac.strikes(7)])
	# rate limits: a burst is fine, a flood is dropped
	var passed := 0
	for i in 200:
		passed += 1 if ac.allow(9, "act", 5000) else 0
	check(passed == 60, "a burst of 60 requests goes through, the rest of a flood is dropped (%d of 200)" % passed)
	passed = 0
	for i in 100:
		passed += 1 if ac.allow(9, "act", 6000) else 0
	check(passed == 30, "then 30 a second (%d)" % passed)
	check(ac.strikes(9) >= 2.0, "a flood costs strikes (%.1f)" % ac.strikes(9))
	# through the real server entry points
	var ns := NetServer.new()
	ns.m = m
	var me := arena_rat(m, 1, "scout")
	for i in 30:
		me.step(DT)
	me.net_peer = 11
	ns.seats[11] = me
	ns.ac.log_violations = false
	ns.ac.reset(11, me)
	me.net_pre = Match.net_state(me)
	var here := me.position
	var kick0 := me.net_kick
	ns._last_input[11] = Time.get_ticks_msec() - 400
	ns.on_input(11, {"k": me.net_kick, "p": here + Vector3(3.0, 0, 0), "v": Vector3.ZERO, "y": 0.0, "f": 1, "s": me.stamina})
	check(me.position.distance_to(here) < 0.01 and me.net_kick == kick0 + 1, "a forged move through a wall is refused and the player corrected")
	check(ns.ac.strikes(11) >= 1.0, "and costs a strike")
	me.stamina = 20.0
	me.net_pre = Match.net_state(me)
	ns._last_input[11] = Time.get_ticks_msec() - 100
	ns.on_input(11, {"k": me.net_kick, "p": me.position, "v": Vector3.ZERO, "y": 0.0, "f": 1, "s": 100.0})
	check(me.stamina < 24.0, "stamina claimed back faster than it refills is refused (%.1f)" % me.stamina)
	var acts := 0
	for i in 300:
		var d0 := int(ns.ac._peers[11]["dropped"])
		ns.on_act(11, "set_equipped", ["nothing"])
		acts += 1 if int(ns.ac._peers[11]["dropped"]) == d0 else 0
	check(acts <= 62, "a flood of requests is cut to the burst allowance (%d of 300 run)" % acts)
	ns.free()
	end(m)


func test_sixteen_a_side() -> void:
	## 16v16 on a dedicated server: compact snapshots, names sent only when
	## they change, sixteen spawn spots per base, and the player caps.
	var m := new_match({"team_size": 1})
	var i0 := m.rats.size()
	while m.rats.size() < 32:
		m.spawn_rat(m.rats.size() % 2, ClassDefs.ORDER[m.rats.size() % 4], true)
	check(m.rats.size() == 32 and i0 <= 2, "32 rats in one match")
	# every rat starts on its own spot inside its base
	for team in 2:
		var spots := {}
		var inside := true
		var zone := MapGenerator.base_zone(team)
		for slot in 16:
			var p := MapGenerator.spawn_point(team, slot)
			spots[Vector2(snappedf(p.x, 0.01), snappedf(p.z, 0.01))] = true
			inside = inside and zone.grow(-0.4).has_point(Vector3(p.x, zone.get_center().y, p.z))
		check(spots.size() == 16 and inside, "team %d has 16 separate spawn spots, all well inside the base (%d)" % [team, spots.size()])
	# the binary rat records come back as sent (within their precision)
	var r: Rat = m.rats[3]
	r.position = Vector3(127.3, 70.25, 0.4)
	r.vel = Vector3(-37.5, 22.0, 0.01)
	r.yaw = -0.5
	r.anim_action = "build"
	r.anim_action_t = 0.62
	r.carried = 3
	r.stun = 1.5
	r.knock = 0.3
	r.operating = 123456
	r.on_ladder = true
	r.set_class("maestro", false)
	var back := NetCodec.decode_rats(NetCodec.encode_rats(m.rats), {r.id: "Squeaky"})
	check(back.size() == 32, "all 32 records decode")
	var e: Array = back[3]
	check(int(e[0]) == r.id and int(e[1]) == r.team and String(e[2]) == "maestro" and String(e[3]) == "Squeaky", "id, team, class and name")
	check((e[5] as Vector3).distance_to(r.position) < 0.01 and (e[6] as Vector3).distance_to(r.vel) < 0.01, "position and velocity (%s %s)" % [e[5], e[6]])
	check(absf(wrapf(float(e[7]) - r.yaw, -PI, PI)) < 0.001, "facing")
	check(String(e[8]) == "build" and absf(float(e[9]) - 0.62) < 0.03 and int(e[10]) == 3, "animation and carried cheese")
	check(absf(float(e[11]) - 1.5) < 0.03 and absf(float(e[12]) - 0.3) < 0.03 and int(e[13]) == 123456, "stun, knockback and machine")
	check((int(e[4]) & 2) != 0 and (int(e[4]) & 16) != 0, "flags (on a ladder, a bot)")
	check(NetCodec.decode_rats(PackedByteArray([1, 2, 3]), {}).is_empty(), "a malformed record list decodes to nothing")
	# snapshot size, and names only when they change
	var ns := NetServer.new()
	ns.m = m
	var first := ns._snapshot()
	check(first.has("ro") and (first["ro"] as Dictionary).size() == 32, "the first snapshots carry everyone's name")
	for i in 25:
		ns._snapshot()
	var quiet := ns._snapshot()
	var size := var_to_bytes(quiet).size()
	check(not quiet.has("ro"), "names stay home while nobody changes")
	check(size < 1400, "a 32-rat snapshot is small (%d bytes; it was about 4900)" % size)
	m.rats[5].display_name = "Newcomer"
	var changed := ns._snapshot()
	check(changed.has("ro") and String(changed["ro"][m.rats[5].id]) == "Newcomer", "a new name goes out straight away")
	var with_names := 0
	for i in 40:
		with_names += 1 if ns._snapshot().has("ro") else 0
	check(with_names >= 20 and with_names <= 23, "and for a second after, then once a second (%d of 40)" % with_names)
	# caps
	check(Net.MAX_CLIENTS == 31 and Net.HOST_MAX_CLIENTS == 15 and NetServer.MAX_RATS == 32, "caps: 31 players on a dedicated server, 15 joining a hosted game")
	ns.max_players = 2
	ns.seats[101] = m.rats[1]
	ns.seats[102] = m.rats[2]
	ns.on_hello(103, {"name": "Late", "team": 0, "class": "digger"})
	check(not ns.seats.has(103), "a full server seats nobody else")
	ns.seats.clear()
	ns.free()
	end(m)


func test_server_list() -> void:
	## servers.json entries, their status pages and what the list shows.
	var json := JSON.stringify({"servers": [
		{"name": "EU One", "region": "EU", "url": "wss://play.example.org/eu1"},
		{"name": "Old UDP", "address": "203.0.113.10", "port": 24565},
		{"name": "Own status", "url": "ws://198.51.100.7:9000", "status": "https://status.example.org/x"},
		{"name": "Broken", "port": 5},
		"junk",
		{"address": "2001:db8::5", "port": 24570}]})
	var list := ServerList.parse(json)
	check(list.size() == 4, "good entries are kept, broken ones dropped (%d)" % list.size())
	if list.size() == 4:
		check(list[0]["join"] == "wss://play.example.org/eu1" and list[0]["ws"] and list[0]["status"] == "https://play.example.org/eu1/status",
			"a wss:// server; its status behind the same proxy (%s)" % list[0]["status"])
		check(list[1]["join"] == "203.0.113.10:24565" and not list[1]["ws"] and list[1]["status"] == "http://203.0.113.10:24566/status",
			"an ENet server; status on the next TCP port (%s)" % list[1]["status"])
		check(list[2]["status"] == "https://status.example.org/x", "a status page the list names itself wins")
		check(list[3]["name"] == "Server" and list[3]["status"] == "http://[2001:db8::5]:24571/status", "no name, IPv6 (%s)" % list[3]["status"])
	check(ServerList.parse("").is_empty() and ServerList.parse("{\"servers\": 3}").is_empty(), "an unreadable list is empty, not an error")
	check(ServerList.status_url_for("ws://10.0.0.2:24565/") == "http://10.0.0.2:24566/status", "ws:// status sits on the next port")
	var st := {"players": 12, "max_players": 31, "mode": "race", "score": [3, 1], "goal": 10, "protocol": Net.PROTOCOL, "version": "x"}
	check(ServerList.describe(st) == "12/31 players  -  Cheese Race 3-1 (to 10)", "a status line (%s)" % ServerList.describe(st))
	check(ServerList.describe({"players": 0, "max_players": 31, "mode": "free"}).ends_with("Free Build"), "Free Build servers say so")
	var ws_entry := {"ws": true}
	check(ServerList.why_not(ws_entry, st) == "", "a joinable server")
	st["players"] = 31
	check(ServerList.why_not(ws_entry, st) == "Full", "a full one")
	st["protocol"] = Net.PROTOCOL + 1
	st["version"] = "9.9"
	check(ServerList.why_not(ws_entry, st) == "Needs version 9.9", "another version")
	check(ServerList.why_not({"ws": false}, null) == ("" if Net.enet_available() else "Desktop only"), "UDP servers are for desktop builds")
	check(ServerList.ping_ms(90.0, "https://a/status") == 30 and ServerList.ping_ms(40.0, "http://a/status") == 20, "ping from the fetch time")
	check(ServerList.list_url().begins_with("http") or OS.get_environment("BW_SERVER_LIST") != "", "the list comes from the web by default")


func test_cheat_code() -> void:
	## Up Up Down Down Left Right Left Right B A in the playground: only the
	## host's works, and the match it starts gives everyone infinite resources.
	var code := CheatCode.new()
	var t := 10.0
	var got := 0
	for tok: String in CheatCode.CODE:
		t += 0.2
		got = code.feed(tok, t)
	check(got == 10, "the full code is recognised")
	check(code.feed("u", t + 0.2) == 1, "and then it starts over")
	code = CheatCode.new()
	for tok: String in ["u", "u", "d", "d", "l", "r", "l", "r"]:
		t += 0.2
		got = code.feed(tok, t)
	check(got == 8 and code.feed("", t) == 0, "other keys in between don't count, or break it")
	check(code.feed("b", t + 3.0) == 0, "a long pause starts it over")
	code = CheatCode.new()
	for tok: String in ["u", "u", "u", "d", "d", "l", "r", "l", "r", "b", "a"]:
		t += 0.2
		got = code.feed(tok, t)
	check(got == 10, "an extra Up at the start is forgiven")
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	var pad_b := InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = true
	var w := InputEventKey.new()
	w.keycode = KEY_W
	w.pressed = true
	check(CheatCode.token(up) == "u" and CheatCode.token(pad_b) == "b" and CheatCode.token(w) == "", "arrow keys and the D-pad, B and A")
	# the host's playground
	var lobby := new_match(Match.lobby_settings({"team": 0, "class": "digger"}))
	var host_rat := lobby.spawn_rat(0, "digger", false)
	var toasts: Array = []
	lobby.toast.connect(func(text: String, _team: int) -> void: toasts.append(text))
	check(lobby.lobby and not lobby.infinite_next, "the playground starts with the cheat off")
	check(lobby.cheat_infinite(host_rat) == "" and lobby.infinite_next and bool(lobby.settings["infinite"]), "the host's code turns it on")
	check(toasts.size() == 1 and String(toasts[0]).begins_with("CHEAT CODE"), "and everyone is told (%s)" % str(toasts))
	check(Match.lobby_settings({"infinite": true})["infinite"] == true, "the next playground remembers it")
	lobby.cheat_infinite(host_rat)
	check(not lobby.infinite_next and toasts.size() == 2, "typed again, it's off")
	end(lobby)
	var guest := Match.new()
	guest.auto_step = false
	add_child(guest)
	guest.setup(Match.lobby_settings({"team": 1}), false, true)
	var guest_rat := guest.spawn_rat(1, "scout", false)
	check(guest.cheat_infinite(guest_rat).begins_with("Nice try") and not guest.infinite_next, "a guest's code does nothing (but gets a reply)")
	remove_child(guest)
	guest.free()
	# the match it starts
	var m := new_match({"infinite": true})
	check(m.infinite and m.unlimited() and not m.free_mode and not m.world.cheese_cells.is_empty(), "an infinite match is still a Cheese Race (cheese and all)")
	flat_arena(m, ARENA, 6)
	var r := arena_rat(m, 0, "digger")
	var bot := arena_rat(m, 1, "scout", Vector3(3, 0, 3))
	r.mats["dirt"] = 0
	var cell := ARENA + Vector3i(2, 0, 0)
	check(m.try_place_mat(r, cell, "dirt") == "" and m.world.get_cell(cell) == Blocks.DIRT and int(r.mats["dirt"]) == 0, "blocks without digging any")
	r.gadgets["spring"] = 0
	r.equipped = "spring"
	check(m.try_use_equipped(r, {"cell": ARENA + Vector3i(-2, -1, 0), "normal": Vector3i(0, 1, 0)}, Vector3(-1, 0, 0), false) == "", "gadgets without owning any")
	r.gadgets["dynamite"] = 0
	check(m.dynamite.try_throw(r, Vector3(1, 0.3, 0), false, "dynamite") == "" and int(r.gadgets["dynamite"]) == 0, "Mobile TNT without any sticks")
	bot.mats["stone"] = 0
	check(m.try_place_mat(bot, ARENA + Vector3i(3, 0, 1), "stone") == "", "and it's the same for everyone, the other team too")
	var scrap := r.scrap
	r.position = MapGenerator.spawn_point(0)
	check(m.try_buy(r, "spring") == "" and r.scrap == scrap, "the workshop costs nothing")
	m.world.set_block(cell + Vector3i(0, 1, 0), Blocks.DIRT)
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	r.dig_cd = 0.0
	m.try_dig(r, cell + Vector3i(0, 1, 0))
	check(m.world.get_cell(cell + Vector3i(0, 1, 0)) == Blocks.DIRT, "but digging is as hard as ever (dirt takes two hits)")
	end(m)
	var normal := new_match()
	check(not normal.unlimited(), "a normal match isn't infinite")
	end(normal)


func test_audio_buses() -> void:
	## The Music and SFX buses come from the project's bus layout, not from
	## code at run time: in a browser, buses added at run time get wired into a
	## loop through Master and the browser silences everything (the web build
	## was mute). tools/web_smoke.js listens for the music in a real browser.
	var path := String(ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres"))
	var layout: Resource = load(path) if ResourceLoader.exists(path) else null
	check(layout is AudioBusLayout, "the project has a bus layout (%s)" % path)
	if layout is AudioBusLayout:
		check(layout.get("bus/1/name") == &"Music" and layout.get("bus/1/send") == &"Master", "Music is in it, sending to Master")
		check(layout.get("bus/2/name") == &"SFX" and layout.get("bus/2/send") == &"Master", "SFX is in it, sending to Master")
	check(AudioServer.bus_count == 3 and AudioServer.get_bus_index("Music") == 1 and AudioServer.get_bus_index("SFX") == 2,
		"and the game runs with exactly those three buses (%d)" % AudioServer.bus_count)


func test_wrecking_ball_smashes_through() -> void:
	## The ball goes through what's in its way instead of bouncing off it:
	## one swing smashes several blocks, and it can't get stuck in terrain.
	var setup := siege_setup("crane")
	var m: Match = setup[0]
	var r: Rat = setup[1]
	var mc: SiegeSystem.Machine = setup[2]
	m.siege.aim(r, -PI / 2.0, 0.0)
	m.siege.release(r)
	var wall: Array[Vector3i] = []
	for dx in [4, 5]:
		for dy in [0, 1]:
			wall.append(ARENA + Vector3i(dx, dy, 0))
	for c in wall:
		m.world.set_block(c, Blocks.DIRT)
	mc.theta = 0.0
	mc.omega = 3.4   # a full swing, outward through the wall
	var furthest := -99.0
	var turned_in_wall := false
	var last_x := SiegeSystem.ball_pos(mc).x
	for i in 60:
		m.step(DT)
		var x := SiegeSystem.ball_pos(mc).x
		if x < last_x - 0.001 and x < ARENA.x + 5.0:
			turned_in_wall = true
		if mc.omega <= 0.0:
			break
		furthest = maxf(furthest, x)
		last_x = x
	var broken := 0
	for c in wall:
		broken += 1 if m.world.get_cell(c) == Blocks.AIR else 0
	check(broken >= 3, "one swing smashes through several blocks (%d of 4 broken)" % broken)
	check(not turned_in_wall and furthest > ARENA.x + 5.0, "without bouncing back off the first (reached x %.1f)" % (furthest - ARENA.x))
	end(m)
	# a ball hanging inside a block still swings
	setup = siege_setup("crane")
	m = setup[0]
	r = setup[1]
	mc = setup[2]
	m.siege.aim(r, -PI / 2.0, 0.0)
	var rest := SiegeSystem.ball_pos(mc)
	var inside := Vector3i(floori(rest.x), floori(rest.y), floori(rest.z))
	m.world.set_block(inside, Blocks.STONE)
	m.world.set_block(inside + Vector3i(1, 0, 0), Blocks.STONE)
	var top := 0.0
	var t := 0.0
	while t < 6.0:
		m.siege.fire(r)
		m.step(DT)
		t += DT
		top = maxf(top, absf(mc.omega) * SiegeSystem.CRANE_CABLE)
	check(top > 4.0, "pumping a ball that hangs inside rock still gets it swinging (%.1f blocks/s)" % top)
	check(m.world.get_cell(inside + Vector3i(1, 0, 0)) != Blocks.STONE or int(m.world.damage.get(inside + Vector3i(1, 0, 0), 0)) > 0,
		"and it chews into the rock around it")
	end(m)


func test_workshop_categories() -> void:
	## The workshop lists each category once, with everything that belongs to it.
	var items := ClassDefs.shop_in_order()
	check(items.size() == ClassDefs.SHOP.size(), "every item is still for sale (%d)" % items.size())
	var seen: Array[String] = []
	for item: Dictionary in items:
		if seen.is_empty() or seen[-1] != String(item["cat"]):
			seen.append(String(item["cat"]))
	check(seen == ["Mobility", "Construction", "Traps", "Siege", "Gear"], "each category once, in order (%s)" % str(seen))
	var cat_of := {}
	for item: Dictionary in ClassDefs.SHOP:
		cat_of[item["id"]] = item["cat"]
	for id: String in ["wallspring", "impulse", "teleporter", "ladder", "spring"]:
		check(cat_of.get(id) == "Mobility", "%s is under Mobility" % id)
	for id: String in ["trap", "tnt", "dynamite", "sticky", "pitfall", "decoy", "windup", "squeaker"]:
		check(cat_of.get(id) == "Traps", "%s is under Traps" % id)
	for item: Dictionary in ClassDefs.SHOP:
		if item["kind"] == "gear":
			check(item["cat"] == "Gear", "%s (gear) is under Gear" % item["name"])


func test_bulldozer_turns() -> void:
	## A / D turn the bulldozer a quarter at a time; looking around doesn't.
	var setup := siege_setup("dozer")
	var m: Match = setup[0]
	var r: Rat = setup[1]
	var mc: SiegeSystem.Machine = setup[2]
	check(SiegeSystem.facing(mc) == Vector3i(1, 0, 0), "placed facing the way its owner looked (+X)")
	m.siege.aim(r, 0.0, 0.0)
	check(SiegeSystem.facing(mc) == Vector3i(1, 0, 0), "looking around doesn't turn it")
	m.siege.turn(r, 1)
	check(SiegeSystem.facing(mc) == Vector3i(0, 0, 1), "a right turn: +X becomes +Z")
	m.siege.turn(r, 1)
	m.siege.turn(r, 1)
	check(SiegeSystem.facing(mc) == Vector3i(0, 0, -1), "two more: facing -Z")
	m.siege.turn(r, -1)
	check(SiegeSystem.facing(mc) == Vector3i(-1, 0, 0), "a left turn: -Z becomes -X")
	# rams the way it now faces
	var old_ahead := ARENA + SiegeSystem.facing(mc)
	m.siege.turn(r, -1)
	var ahead := ARENA + SiegeSystem.facing(mc)
	check(SiegeSystem.facing(mc) == Vector3i(0, 0, 1), "another left: +Z")
	m.world.set_block(ahead, Blocks.DIRT)
	m.world.set_block(old_ahead, Blocks.DIRT)
	m.siege.fire(r)
	check(m.world.get_cell(ahead) == Blocks.AIR or m.world.damage.has(ahead), "the blade hits what's in front after turning")
	check(m.world.get_cell(old_ahead) == Blocks.DIRT and not m.world.damage.has(old_ahead), "and not where it used to face")
	# the pilot's A / D, through the real controls
	var ctl := PlayerController.new()
	ctl.m = m
	ctl.rat = r
	add_child(ctl)
	ctl.yaw = mc.yaw   # (taking the controls lines the view up behind the machine)
	var before := SiegeSystem.facing(mc)
	Input.action_press("move_right")
	ctl._physics_process(DT)
	Input.action_release("move_right")
	ctl._physics_process(DT)
	check(SiegeSystem.facing(mc) != before, "D at the controls turns it (%s -> %s)" % [str(before), str(SiegeSystem.facing(mc))])
	var fwd := Vector3(-sin(ctl.yaw), 0, -cos(ctl.yaw))
	check(Vector3(SiegeSystem.facing(mc)).dot(fwd) > 0.9, "and the view swings round behind the blade")
	remove_child(ctl)
	ctl.free()
	# a player online asks the server
	var ns := NetServer.new()
	ns.m = m
	ns.seats[12] = r
	ns.ac.log_violations = false
	before = SiegeSystem.facing(mc)
	ns.on_act(12, "turn_machine", [-1])
	check(SiegeSystem.facing(mc) != before, "online, the server turns it on request")
	ns.on_act(12, "turn_machine", ["left"])
	ns.free()
	# other machines still aim with the view
	end(m)
	setup = siege_setup("cannon")
	m = setup[0]
	r = setup[1]
	mc = setup[2]
	m.siege.aim(r, 1.0, 0.3)
	check(absf(mc.yaw - 1.0) < 0.001, "a cannon still turns with the view")
	end(m)


class HeldCatcher:
	## Stands in for a NetClient: records what Net hands over.
	var got: Array = []
	func on_events(p: Variant) -> void: got.append(["events", p])
	func on_kick(p: Variant) -> void: got.append(["kick", p])
	func on_private(p: Variant) -> void: got.append(["private", p])
	func on_notice(p: Variant) -> void: got.append(["notice", p])


func test_held_until_ready() -> void:
	## What the server sends after a welcome (block changes, corrections,
	## inventory) is held until the new session is up, then handed over in
	## order. Before, it was lost while the map downloaded, or went to the
	## previous round's session: players' maps missed changes, and a lost
	## correction made the server ignore their movement.
	Net.close()
	Net._s_welcome({"rat": 1, "ws": 41, "parts": 1, "bytes": 10})
	Net._s_events(var_to_bytes({"b": PackedInt32Array([1, 2, 3, 4]), "n": 1}))
	Net._s_kick({"k": 77})
	Net._s_snap(var_to_bytes({"t": 1.0}))
	Net._s_private({"scrap": 9})
	Net._s_events(var_to_bytes({"n": 2}))
	Net._s_notice("Too far")
	check(Net._held.size() == 5, "everything after the welcome is held, except snapshots (the welcome has its own) (%d)" % Net._held.size())
	var c := HeldCatcher.new()
	Net.release_held(c)
	var kinds: Array = []
	for g: Array in c.got:
		kinds.append(g[0])
	check(kinds == ["events", "kick", "private", "events", "notice"], "handed to the new session in the order it came (%s)" % str(kinds))
	check(int(c.got[1][1]["k"]) == 77 and int(c.got[3][1]["n"]) == 2, "with what it said")
	Net._s_events(var_to_bytes({"n": 3}))
	check(Net._held.is_empty() and c.got.size() == 5, "after that, nothing is held")
	Net._s_welcome({"rat": 1, "ws": 42, "parts": 1, "bytes": 10})
	Net._s_kick({"k": 78})
	Net.close()
	check(Net._held.is_empty() and not Net._holding, "leaving drops anything still held")


func test_unstick_nearest() -> void:
	## A block appearing inside a rat (someone built there) moves it to the
	## nearest free spot, not up through whatever is above to open sky.
	var m := new_match()
	flat_arena(m, ARENA, 6)
	# a one-block-high tunnel along X under 12 blocks of rock
	for dx in range(-4, 5):
		for dz in range(-2, 3):
			for dy in range(0, 12):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.STONE)
	for dx in range(-4, 5):
		m.world.set_block(ARENA + Vector3i(dx, 0, 0), Blocks.AIR)
	var r := arena_rat(m, 0, "digger")
	check(not r.blocked(), "the rat fits in the tunnel")
	m.world.set_block(ARENA, Blocks.DIRT)   # built right where it stands
	r.unstick()
	check(not r.blocked() and absf(r.position.y - ARENA.y) < 0.01 and absf(r.position.x - (ARENA.x + 0.5)) <= 1.3,
		"in a tunnel it steps aside along the tunnel (now at %s)" % str(r.position - Vector3(ARENA)))
	# out in the open: up onto the new block
	var o := ARENA + Vector3i(0, 12, 0)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in range(0, 4):
				m.world.set_block(o + Vector3i(dx, dy, dz), Blocks.AIR)
	r.position = Vector3(o) + Vector3(0.5, 0, 0.5)
	m.world.set_block(o, Blocks.DIRT)
	r.unstick()
	var moved := r.position.distance_to(Vector3(o) + Vector3(0.5, 0, 0.5))
	check(not r.blocked() and moved <= 1.01, "in the open it steps just out of the block, aside or onto it (%.2f blocks)" % moved)
	# boxed in completely: the old way out, straight up to the first free spot
	r.position = Vector3(ARENA) + Vector3(2.5, 0, 0.5)
	for dx in range(-4, 5):
		m.world.set_block(ARENA + Vector3i(dx, 0, 0), Blocks.STONE)
	r.unstick()
	check(not r.blocked() and r.position.y >= ARENA.y + 12.0, "sealed in rock, it still gets out (up to y+%.0f)" % (r.position.y - ARENA.y))
	# on a server: a player's game stepping out the same way is legal; anywhere else is not
	for dx in range(-4, 5):
		m.world.set_block(ARENA + Vector3i(dx, 0, 0), Blocks.AIR)
	var ns := NetServer.new()
	ns.m = m
	ns.ac.log_violations = false
	r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)
	r.vel = Vector3.ZERO
	r.net_peer = 12
	ns.seats[12] = r
	ns.ac.reset(12, r)
	r.net_pre = Match.net_state(r)
	m.world.set_block(ARENA, Blocks.DIRT)   # built where the server last had it
	var inside := r.position
	r.unstick()
	var out := r.position
	r.position = inside
	var kick0 := r.net_kick
	ns._last_input[12] = Time.get_ticks_msec() - 50
	ns.on_input(12, {"k": r.net_kick, "p": out, "v": Vector3.ZERO, "y": 0.0, "f": 1, "s": r.stamina})
	check(r.net_kick == kick0 and r.position.distance_to(out) < 0.01 and ns.ac.strikes(12) == 0.0,
		"its game stepping it out to the server's own way out is accepted, no strike (%.1f)" % ns.ac.strikes(12))
	r.position = inside   # (buried again)
	r.net_pre = Match.net_state(r)
	ns._last_input[12] = Time.get_ticks_msec() - 50
	ns.on_input(12, {"k": r.net_kick, "p": inside + Vector3(0, 12.0, 0), "v": Vector3.ZERO, "y": 0.0, "f": 1, "s": r.stamina})
	check(r.net_kick == kick0 + 1 and not r.blocked() and r.position.y < ARENA.y + 2.0,
		"but popping up through the rock to open sky is refused: put back in the tunnel (at y+%.1f)" % (r.position.y - ARENA.y))
	ns.free()
	end(m)


func test_map_in_parts() -> void:
	## Joining: the map follows the welcome in parts, is put back together,
	## and parts from an older welcome (a new round started) are ignored.
	var world := {"d": PackedByteArray(), "m": {}, "g": {}}
	var big := PackedByteArray()
	big.resize(130000)
	for i in big.size():
		big[i] = (i * 7) % 251
	world["d"] = big
	var bytes := var_to_bytes(world)
	var parts: Array[PackedByteArray] = []
	for at in range(0, bytes.size(), Net.WORLD_PART):
		parts.append(bytes.slice(at, at + Net.WORLD_PART))
	check(parts.size() == 3, "a 130 KB map goes in 3 parts (%d)" % parts.size())
	var got: Array = []
	var on_join := func(info: Dictionary) -> void: got.append(info)
	Net.joined.connect(on_join)
	Net._s_welcome({"rat": 4, "ws": 7, "parts": parts.size(), "bytes": bytes.size()})
	check(got.is_empty() and Net.join_progress() == 0.0, "the welcome alone doesn't start the game")
	Net._s_world(7, 0, parts[0])
	Net._s_world(6, 1, PackedByteArray([1, 2, 3]))   # left over from the previous round
	Net._s_world(7, 2, parts[2])                      # out of order: ignored
	check(got.is_empty() and is_equal_approx(Net.join_progress(), 1.0 / 3.0), "stray and out-of-order parts are ignored")
	Net._s_world(7, 1, parts[1])
	Net._s_world(7, 2, parts[2])
	check(got.size() == 1 and int(got[0]["rat"]) == 4, "the last part starts the game")
	check(got.size() == 1 and got[0]["world"] is Dictionary and (got[0]["world"]["d"] as PackedByteArray) == big, "with the map exactly as sent")
	check(got.size() == 1 and not got[0].has("parts"), "and no joining bookkeeping left in the welcome")
	check(Net.join_progress() < 0.0, "nothing more to wait for")
	# a lying welcome is refused
	Net._s_welcome({"ws": 8, "parts": 1, "bytes": Net.WORLD_MAX + 1})
	check(Net.join_progress() < 0.0, "a welcome promising a huge map is refused")
	# a damaged map: the client gives up cleanly
	var failed: Array = []
	var on_fail := func(r: String) -> void: failed.append(r)
	Net.join_failed.connect(on_fail)
	Net._s_welcome({"ws": 9, "parts": 1, "bytes": 100})
	Net._s_world(9, 0, PackedByteArray([1, 2, 3]))
	check(got.size() == 1 and failed.size() == 1, "a damaged map fails the join instead of starting")
	Net.join_failed.disconnect(on_fail)
	Net.joined.disconnect(on_join)
	# addresses
	check(Net.is_ws_url("wss://bw.example.org/play") and Net.is_ws_url(" WS://1.2.3.4:9000") and not Net.is_ws_url("1.2.3.4:24565"),
		"ws:// and wss:// addresses are recognised")
	Net.close()
	check(Net.ws_url_for("bw.example.org", 24565) == "wss://bw.example.org:24565" and Net.ws_url_for("127.0.0.1", 9) == "ws://127.0.0.1:9"
		and Net.ws_url_for("2001:db8::1", 9) == "wss://[2001:db8::1]:9", "a bare address becomes wss:// (ws:// to this machine) where only WebSocket exists")


func test_gamepad_input() -> void:
	## Everything you do in a match has a controller button, prompts name the
	## controller's buttons once you use it, and the sticks drive the rat.
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "look_left", "look_right", "look_up", "look_down",
			"jump", "dash", "descend", "interact", "gear", "gadget", "cycle_gadget", "dig", "place", "next_slot", "prev_slot",
			"ability_1", "ability_2", "drop_cheese", "camera_toggle", "pause", "workshop"]:
		var has_pad := false
		for e in InputMap.action_get_events(action):
			has_pad = has_pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		check(has_pad, "%s is on the controller" % action)
	var ok_a := false
	var ok_b := false
	for e in InputMap.action_get_events("ui_accept"):
		ok_a = ok_a or (e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A)
	for e in InputMap.action_get_events("ui_cancel"):
		ok_b = ok_b or (e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	check(ok_a and ok_b, "menus: A confirms, B goes back")
	# prompts follow the device
	Inputs._input(_pad_button(JOY_BUTTON_A))
	check(Inputs.using_pad and Inputs.key_name("jump") == "A" and Inputs.key_name("dig") == "RT", "after touching the pad, prompts show its buttons")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Inputs._input(key)
	check(not Inputs.using_pad and Inputs.key_name("jump") == OS.get_keycode_string(KEY_SPACE), "after touching the keyboard, keys again")
	# the sticks drive a real rat
	var m := new_match()
	flat_arena(m, ARENA, 6)
	var r := arena_rat(m, 0, "digger")
	var ctl := PlayerController.new()
	ctl.m = m
	ctl.rat = r
	add_child(ctl)
	ctl.yaw = 0.0
	_feed(_pad_axis(JOY_AXIS_LEFT_Y, -1.0))
	ctl._physics_process(DT)
	check(r.wish.dot(Vector3(0, 0, -1)) > 0.9, "left stick forward walks forward (%s)" % str(r.wish))
	_feed(_pad_axis(JOY_AXIS_LEFT_Y, 0.0))
	_feed(_pad_axis(JOY_AXIS_LEFT_X, 0.5))
	ctl._physics_process(DT)
	check(r.wish.length() > 0.2 and r.wish.length() < 0.8 and r.wish.x > 0.0, "half a tilt walks slower (%.2f)" % r.wish.length())
	_feed(_pad_axis(JOY_AXIS_LEFT_X, 0.0))
	_feed(_pad_axis(JOY_AXIS_RIGHT_X, 1.0))
	ctl._process(0.5)
	check(ctl.yaw < -0.5, "right stick turns the camera (%.2f)" % ctl.yaw)
	_feed(_pad_axis(JOY_AXIS_RIGHT_X, 0.0))
	var y0 := ctl.yaw
	ctl._process(0.5)
	check(ctl.yaw == y0, "and stops when let go")
	# B: dash on the ground, climb down on a ladder
	r.dash_pressed = false
	r.on_ladder = true
	ctl._unhandled_input(_pad_button(JOY_BUTTON_B))
	check(not r.dash_pressed, "on a ladder B climbs down instead of dashing")
	r.on_ladder = false
	ctl._unhandled_input(_pad_button(JOY_BUTTON_B))
	check(r.dash_pressed, "on the ground B dashes")
	# D-pad left/right: materials, paint, then the chisel and the pantograph
	ctl.selected_mat = 0
	ctl.tool = PlayerController.Tool.DIG
	ctl._unhandled_input(_pad_button(JOY_BUTTON_DPAD_RIGHT))
	check(ctl.selected_mat == 1, "D-pad Right picks the next material")
	for i in 4:
		ctl.cycle_slot(1)
	check(ctl.tool == PlayerController.Tool.CHISEL, "past the paint slot comes the chisel")
	ctl.cycle_slot(1)
	check(ctl.tool == PlayerController.Tool.PANTOGRAPH, "then the pantograph")
	ctl.cycle_slot(1)
	check(ctl.tool == PlayerController.Tool.DIG and ctl.selected_mat == 0, "and round to dirt again")
	ctl._unhandled_input(_pad_button(JOY_BUTTON_DPAD_LEFT))
	check(ctl.tool == PlayerController.Tool.PANTOGRAPH, "D-pad Left goes back")
	# holding a blueprint: D-pad Up rotates it
	var bp := Blueprint.new()
	bp.size = Vector3i(3, 1, 1)
	for x in 3:
		bp.cells.append({"o": Vector3i(x, 0, 0), "id": Blocks.STONE, "mask": null})
	ctl.blueprint = bp
	ctl._unhandled_input(_pad_button(JOY_BUTTON_DPAD_UP))
	check(ctl.blueprint.size == Vector3i(1, 1, 3), "D-pad Up rotates a blueprint")
	remove_child(ctl)
	ctl.free()
	end(m)


func test_results_stats_and_emotes() -> void:
	## The results screen's tallies: what each rat did over the match, counted
	## by the authority; emotes once it's over; and what each screen offers.
	var m := new_match()
	flat_arena(m, ARENA, 6)
	var a := arena_rat(m, 0, "digger")
	var b := arena_rat(m, 1, "scout", Vector3(1.0, 0, 0))
	# digging: blocks broken, cheese mined, scrap earned
	var dirt := ARENA + Vector3i(0, 0, -2)
	m.world.set_block(dirt, Blocks.DIRT)
	var cheese := ARENA + Vector3i(-1, 0, -2)
	m.world.set_block(cheese, Blocks.CHEESE)
	var scrap := ARENA + Vector3i(1, 0, -2)
	m.world.set_block(scrap, Blocks.SCRAP)
	var scrap0 := a.scrap
	for c: Vector3i in [dirt, cheese, scrap]:
		var n := 0
		while m.world.get_cell(c) != Blocks.AIR and n < 40:
			a.dig_cd = 0.0
			m.try_dig(a, c)
			n += 1
	check(int(a.stats.get("blocks", 0)) >= 3, "blocks broken counted (%d)" % int(a.stats.get("blocks", 0)))
	check(int(a.stats.get("mined", 0)) == 1, "cheese mined counted")
	check(int(a.stats.get("scrap", 0)) > 0 and int(a.stats["scrap"]) == a.scrap - scrap0, "scrap earned counted (%d)" % int(a.stats.get("scrap", 0)))
	# bonks: one landed, one taken; the dropped cheese picked up by the other team is stolen
	b.carried = 1
	a.bonk_cd = 0.0
	check(m.try_bonk(a, b), "bonk")
	check(int(a.stats.get("bonks", 0)) == 1 and int(b.stats.get("bonked", 0)) == 1, "bonks landed and times bonked")
	check(m.pickups.size() >= 1 and m.pickups[-1].from_team == 1, "the dropped cheese remembers whose it was")
	var p: Match.Pickup = m.pickups[-1]
	p.lock_t = 0.0
	p.pos = a.center()
	p.vel = Vector3.ZERO
	var before := a.carried
	m._step_pickups(DT)
	check(a.carried == before + 1 and int(a.stats.get("stolen", 0)) == 1, "picking up the other team's dropped cheese is a steal")
	# your own team's dropped cheese is not
	var mate := arena_rat(m, 0, "builder", Vector3(-1.0, 0, 0))
	var own := m.spawn_pickup("cheese", mate.center(), Vector3.ZERO)
	own.from_team = 0
	m._step_pickups(DT)
	check(mate.carried == 1 and int(mate.stats.get("stolen", 0)) == 0, "a teammate's dropped cheese isn't stolen")
	# a vault raid is a steal too
	m.scores[1] = 2
	var thief := arena_rat(m, 0, "scout")
	thief.position = MapGenerator.spawn_point(1)
	for r in m.rats:
		if r.team == 1:
			r.position = Vector3(ARENA) + Vector3(0.5, 0, 0.5)   # no defender home
	for i in int(Config.RAID_TIME / DT) + 5:
		m._check_raid(thief, DT)
	check(int(thief.stats.get("stolen", 0)) == 1, "a vault raid counts as stolen")
	# banking
	a.carried = 2
	m._deposit(a)
	check(int(a.stats.get("banked", 0)) == 2, "cheese banked counted")
	# traps and TNT
	a.gadgets = {"trap": 2, "tnt": 1, "ladder": 1}
	check(m.try_place_gadget(a, ARENA + Vector3i(0, 0, 2), "trap") == "", "place a trap")
	check(m.try_place_gadget(a, ARENA + Vector3i(0, 0, 3), "ladder") == "", "place a ladder")
	check(int(a.stats.get("traps", 0)) == 1, "traps placed (ladders aren't traps)")
	var t := ARENA + Vector3i(3, 0, 3)
	check(m.try_place_gadget(a, t, "tnt") == "", "place TNT")
	m.light_tnt(t, 0.05)
	for i in 10:
		m._step_tnt(DT)
	check(int(a.stats.get("tnt", 0)) == 1, "TNT set off counted for the rat who placed it")
	# the network form
	var packed := m.stats_packed()
	var copy := new_match()
	for r in m.rats:
		copy.spawn_rat(r.team, r.class_id, true, r.id)
	copy.apply_stats(packed)
	var same := true
	for r in m.rats:
		for k: String in Match.STATS:
			same = same and int(copy.rat_by_id(r.id).stats.get(k, 0)) == int(r.stats.get(k, 0))
	check(same, "the tallies survive the trip to a player's game")
	end(copy)
	# emotes: only once it's over, only real ones
	check(not m.emote(a, "cheer"), "no emotes mid-match")
	m.over = true
	m.winner = 0
	check(not m.emote(a, "moonwalk"), "only the known emotes")
	check(m.emote(a, "cheer") and a.emote == "cheer" and a.emote_t > 0.0, "W: cheer")
	check(not m.emote(a, "cheer"), "held down, it plays to the end rather than restarting")
	check(m.emote(a, "flop") and a.emote == "flop", "another emote cuts in")
	var fake := FakeRemote.new()
	m.remote = fake
	m.emote(a, "dance")
	check(fake.acts.size() == 1 and fake.acts[0] == ["emote", ["dance"]], "a player's emote goes to the server")
	m.remote = null
	# bots join in
	m.make_bot(b)
	var bot_emoted := false
	for i in 600:
		m.step(DT)
		if b.emote_t > 0.0:
			bot_emoted = true
			break
	check(bot_emoted, "bots emote on the results screen (%s)" % b.emote)
	# input -> emote
	var ev := InputEventAction.new()
	ev.pressed = true
	var want := {"move_forward": "cheer", "move_left": "dance", "move_right": "taunt", "move_back": "flop", "jump": "flip", "dig": ""}
	var all_ok := true
	for action: String in want:
		ev.action = action
		all_ok = all_ok and ResultsScreen.emote_for(ev) == want[action]
	check(all_ok, "W A D S and Space pick the five emotes; other keys don't")
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	var pad_y := InputEventJoypadButton.new()
	pad_y.button_index = JOY_BUTTON_Y
	pad_y.pressed = true
	check(ResultsScreen.emote_for(pad_a) == "" and ResultsScreen.emote_for(pad_y) == "flip", "on a gamepad A presses buttons and Y flips")
	# leaders, MVP and who gets which buttons
	check(ResultsScreen.mvp(m.rats, 0) == a, "the MVP is the winners' standout")
	check(int(ResultsScreen.leaders(m.rats)["banked"]) == 2, "the top value per tally is picked out")
	var rs := ResultsScreen.new()
	rs.m = m
	rs.me = a
	add_child(rs)
	check(rs.host_role() == "offline" and rs.first_button().text.begins_with("Play again"), "offline: Play again")
	rs.free()
	m.networked = true
	rs = ResultsScreen.new()
	rs.m = m
	rs.me = a
	add_child(rs)
	var texts := []
	for btn in rs.find_children("*", "Button", true, false):
		texts.append((btn as Button).text)
	check(rs.host_role() == "host" and texts.has("Next game (new map)") and texts.has("Back to the lobby"), "the host: Next game, Back to the lobby (%s)" % str(texts))
	rs.free()
	m.replica = true
	m.next_in = 7.2
	rs = ResultsScreen.new()
	rs.m = m
	rs.me = a
	add_child(rs)
	check(rs.host_role() == "client" and rs.status_text() == "Next round in 8 s" and rs.first_button().text.begins_with("Leave"),
		"a player on someone's server: the countdown and Leave (%s)" % rs.status_text())
	m.next_in = -1.0
	check(rs.status_text().contains("Waiting for the host"), "on a friend's game: waiting for the host")
	rs.free()
	m.replica = false
	m.networked = false
	# the playground counts nothing
	var lob := new_match({"mode": "lobby"})
	var l1 := lob.spawn_rat(0, "digger", false)
	lob.tally(l1, "bonks")
	check(l1.stats.is_empty(), "the lobby playground keeps no tallies")
	end(lob)
	end(m)


class FakeRemote:
	var acts := []
	func act(method: String, args: Array) -> String:
		acts.append([method, args])
		return ""


func test_hats() -> void:
	## Hats: every one loads, sits on the head in every frame of every view,
	## takes the team colour, and is the player's own online.
	for id: String in Hats.LIST:
		check(id == "" or Hats.image(id) != null, "hat art for %s" % (id if id != "" else "(none)"))
	check(Hats.clean("crown") == "crown" and Hats.clean("jetpack") == "" and Hats.clean(42) == "", "only known hats are worn")
	RatSprite.clear_caches()
	var plain := RatSprite._frame("digger", 0, "idle", 0, "front")
	var crowned := RatSprite._frame("digger", 0, "idle", 0, "front", "crown")
	check(plain != null and crowned != null and plain.get_height() == RatSprite.CELL_H and plain.get_width() == RatSprite.CELL,
		"frames have room above for a hat (%d x %d)" % [plain.get_width() if plain else 0, plain.get_height() if plain else 0])
	var a := (plain as AtlasTexture).atlas.get_image().get_region(Rect2i((plain as AtlasTexture).region))
	var b := (crowned as AtlasTexture).atlas.get_image().get_region(Rect2i((crowned as AtlasTexture).region))
	var top_a := a.get_used_rect().position.y
	var top_b := b.get_used_rect().position.y
	check(top_a >= Hats.ROOM - 1 and top_b < top_a, "the crown sits on top of the head (top row %d -> %d)" % [top_a, top_b])
	# on every drawn frame: the hat is there, above the head, inside the frame
	var sheet := (load(RatSprite.sheet_path("scout", "side")) as Texture2D).get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var anchors := Hats.anchors_of(sheet, RatSprite.CELL)
	var inside := true
	for at: Vector2i in anchors:
		var p: Vector2i = anchors[at]
		inside = inside and p.x >= 4 and p.x < RatSprite.CELL - 4 and p.y + Hats.ROOM >= (Hats.image("wizard").get_height() - Hats.SINK)
	check(anchors.size() >= 20 and inside, "every scout frame has a head to put a hat on, with room for the tallest hat (%d frames)" % anchors.size())
	# team colours: the party hat's magenta stripes go blue or red
	var blue := (Hats.icon("party", 0) as Texture2D).get_image()
	var red := (Hats.icon("party", 1) as Texture2D).get_image()
	var stripe := Vector2i(5, 6)
	check(blue.get_pixelv(stripe).b > blue.get_pixelv(stripe).r and red.get_pixelv(stripe).r > red.get_pixelv(stripe).b,
		"a hat's magenta takes the team colour")
	# a match: you wear yours; bots none; online the server takes it from your hello
	var m := new_match({"team_size": 1})
	var ns := NetServer.new()
	ns.m = m
	add_child(ns)
	m.spawn_rat(1, "scout", true)            # (the seat the player takes)
	var bot := m.spawn_rat(1, "scout", true)
	ns.on_hello(55, {"name": "Hatter", "team": 1, "class": "scout", "hat": "tophat"})
	var me: Rat = ns.seats.get(55)
	check(me != null and me.hat == "tophat", "a joining player's hat comes with them")
	ns.on_hello(56, {"name": "Sneaky", "team": 0, "class": "digger", "hat": "../../secret"})
	var other: Rat = ns.seats.get(56)
	check(other != null and other.hat == "", "an unknown hat from a client is ignored")
	var snap := ns._snapshot(true)
	check((snap.get("ha", {}) as Dictionary).get(me.id, "") == "tophat", "the server tells everyone who wears what")
	var copy := new_match({"team_size": 1})
	var nc := NetClient.new(copy, {"rat": -99, "snap": snap, "world": m.world.snapshot(), "private": {}})
	add_child(nc)
	nc.on_snap(snap)
	var seen := copy.rat_by_id(me.id)
	check(seen != null and seen.hat == "tophat" and copy.rat_by_id(bot.id) != null and copy.rat_by_id(bot.id).hat == "",
		"a player's game puts it on the right rat")
	remove_child(nc)
	nc.free()
	end(copy)
	# the wind-up decoy wears its owner's hat
	me.gadgets["windup"] = 1
	me.equipped = "windup"
	var why := m.windup.try_place(me, Vector3(1, 0, 0))
	check(why == "" and m.windup.walkers.size() == 1 and m.windup.walkers[0].body.hat == "tophat",
		"a Wind-up Decoy wears its owner's hat (%s)" % why)
	ns.on_peer_left(55)
	check(me.is_bot and me.hat == "", "a bot taking over the seat takes the hat off")
	ns.free()
	end(m)


func test_scrap_race() -> void:
	## Scrap Race: the score is scrap carried home and banked; cheese banked
	## raises your own team's scrap value; unbanked scrap is knocked loose by
	## bonks and lost to spending.
	var m := new_match({"mode": "scrap", "goal": 40})
	flat_arena(m, ARENA, 6)
	check(m.scrap_race and not m.free_mode and m.goal == 40, "a Scrap Race to 40")
	check(Match.cheese_needed({"mode": "scrap", "goal": 40}) == MapGenerator.min_cheese(Config.SCRAP_CHEESE_REF * 2),
		"the map still holds plenty of cheese (it's the multiplier)")
	check(m.scrap_cells.size() > 500, "the bots know where the scrap is (%d blocks)" % m.scrap_cells.size())
	var a := arena_rat(m, 0, "digger")
	var b := arena_rat(m, 1, "scout", Vector3(1.0, 0, 0))
	check(is_equal_approx(m.multiplier(0), 1.0) and is_equal_approx(m.multiplier(1), 1.0), "everyone starts at x1")
	# banked cheese raises only that team's scrap value; it isn't the score
	a.carried = 4
	m._deposit(a)
	check(m.vault[0] == 4 and m.scores[0] == 0, "cheese goes into the vault, not the score")
	check(is_equal_approx(m.multiplier(0), 1.0 + 4.0 / Config.SCRAP_CHEESE_REF * Config.GROWTH_BONUS) and is_equal_approx(m.multiplier(1), 1.0),
		"and raises our scrap value only (x%.2f vs x%.2f)" % [m.multiplier(0), m.multiplier(1)])
	# mining scrap: worth our value, carried until banked
	var cell := ARENA + Vector3i(0, 0, -2)
	m.world.set_block(cell, Blocks.SCRAP)
	var s0 := a.scrap
	var n := 0
	while m.world.get_cell(cell) != Blocks.AIR and n < 40:
		a.dig_cd = 0.0
		m.try_dig(a, cell)
		n += 1
	var gain := roundi(Config.BASE_SCRAP_PER_BLOCK * m.multiplier(0))
	check(a.scrap == s0 + gain and a.scrap_held == gain, "a scrap block is worth our value (+%d), carried, not banked" % gain)
	check(not m.scrap_cells.has(cell), "and the bots forget the mined block")
	# a bonk knocks half of it loose; anyone can grab it
	a.scrap_held = 10
	a.scrap = maxi(a.scrap, 10)
	var before := a.scrap
	b.bonk_cd = 0.0
	check(m.try_bonk(b, a), "bonk")
	check(a.scrap_held == 5 and a.scrap == before - 5, "a bonk knocks half the unbanked scrap loose (held 10 -> %d)" % a.scrap_held)
	var loose: Match.Pickup = null
	for p in m.pickups:
		if p.kind == "scrap":
			loose = p
	check(loose != null and int(loose.mats["scrap"]) == 5, "as a pickup of 5 scrap")
	loose.lock_t = 0.0
	loose.pos = b.center()
	loose.vel = Vector3.ZERO
	var bs := b.scrap
	m._step_pickups(DT)
	check(b.scrap == bs + 5 and b.scrap_held == 5, "the other team grabs it: theirs to bank now")
	# spending unbanked scrap: that part never counts
	a.scrap = 3
	m.step(DT)
	check(a.scrap_held == 3, "spend it before banking and it's gone from the haul (%d)" % a.scrap_held)
	# home: it's banked, and it stays yours to spend
	a.scrap = 30
	a.scrap_held = 30
	a.position = MapGenerator.spawn_point(0)
	m._check_rat_hazards(a, DT)
	check(m.scores[0] == 30 and a.scrap_held == 0 and a.scrap == 30 and int(a.stats.get("scrapbank", 0)) == 30,
		"home: 30 scrap banked for the team, still in our pocket to spend")
	check(not m.over, "not there yet (30 / 40)")
	a.scrap = 50
	a.scrap_held = 12
	m._check_rat_hazards(a, DT)
	check(m.over and m.winner == 0 and m.scores[0] == 42, "banking past the goal wins (%d)" % m.scores[0])
	# raids still steal cheese: the other team's scrap value
	var m2 := new_match({"mode": "scrap", "goal": 500})
	m2.vault[1] = 2
	var thief := m2.spawn_rat(0, "scout", false)
	thief.position = MapGenerator.spawn_point(1)
	for i in int(Config.RAID_TIME / DT) + 5:
		m2._check_raid(thief, DT)
	check(m2.vault[1] == 1 and thief.carried == 1 and m2.scores == [0, 0], "a raid steals a cheese (their scrap value), not scrap")
	# bots: miners go for scrap anywhere and haul it home; one in three fetches cheese
	thief.position = MapGenerator.spawn_point(0)   # (out of their vault: nothing to defend)
	var miner: Rat = null
	var runner: Rat = null
	while miner == null or runner == null:
		var r := m2.spawn_rat(1, "digger", true)
		var brain: BotBrain = m2.bots[-1]
		if brain.cheese_runner() and runner == null:
			runner = r
		elif not brain.cheese_runner() and miner == null:
			miner = r
	var mb: BotBrain = null
	for br in m2.bots:
		if br.rat == miner:
			mb = br
	mb._retarget()
	check(mb.mode == "scrap" and m2.world.get_cell(mb.target_cell) == Blocks.SCRAP, "a miner bot heads for scrap (%s)" % mb.mode)
	miner.scrap = 40
	miner.scrap_held = Config.BOT_SCRAP_HAUL
	mb._retarget()
	check(mb.mode == "home", "with %d scrap on it, it heads home to bank" % Config.BOT_SCRAP_HAUL)
	# on the wire, and on screen
	var ns := NetServer.new()
	ns.m = m2
	var snap := ns._snapshot(true)
	check(snap.get("va") == [0, 1], "players get the vaults (%s)" % str(snap.get("va")))
	check(int(ns._private(miner).get("sh", -1)) == Config.BOT_SCRAP_HAUL, "and their own unbanked scrap")
	ns.free()
	var st := {"players": 3, "max_players": 31, "mode": "scrap", "score": [120, 90], "goal": 300}
	check(ServerList.describe(st) == "3/31 players  -  Scrap Race 120-90 (to 300)", "the server list says so (%s)" % ServerList.describe(st))
	m.networked = false
	var rs := ResultsScreen.new()
	rs.m = m
	rs.me = a
	add_child(rs)
	var shows := false
	for l in rs.find_children("*", "Label", true, false):
		shows = shows or (l as Label).text == "Scrap banked"
	check(shows, "the results screen tallies scrap banked")
	rs.free()
	var race := new_match()
	race.over = true
	race.winner = 0
	var r0 := race.spawn_rat(0, "digger", false)
	rs = ResultsScreen.new()
	rs.m = race
	rs.me = r0
	add_child(rs)
	shows = false
	for l in rs.find_children("*", "Label", true, false):
		shows = shows or (l as Label).text == "Scrap banked"
	check(not shows, "but not in a Cheese Race")
	rs.free()
	end(race)
	end(m2)
	end(m)


func test_bots_finish_a_scrap_race() -> void:
	## 2v2 bots, a Scrap Race to the default goal: they mine, haul it home
	## and bank it, fetch some cheese, and someone wins in reasonable time.
	var m := new_match({"mode": "scrap", "goal": Config.SCRAP_GOAL, "seed": 7})
	for team in 2:
		m.spawn_rat(team, "digger", true)
		m.spawn_rat(team, "scout", true)
	var limit := 15.0 * 60.0
	var dt := 1.0 / 30.0
	var first_bank := -1.0
	while not m.over and m.time < limit:
		m.step(dt)
		if first_bank < 0.0 and m.scores[0] + m.scores[1] > 0:
			first_bank = m.time
	print("    scrap bots: over=%s winner=%d score=%d-%d vault=%d-%d x%.2f/x%.2f sim_time=%.0fs first_bank=%.0fs" % [
		m.over, m.winner, m.scores[0], m.scores[1], m.vault[0], m.vault[1], m.multiplier(0), m.multiplier(1), m.time, first_bank])
	check(first_bank > 0.0, "bots mine scrap and bank it")
	check(m.vault[0] + m.vault[1] > 0, "and still bank some cheese for the multiplier")
	check(m.over, "a bots-only Scrap Race to %d finishes within 15 simulated minutes" % Config.SCRAP_GOAL)
	for r in m.rats:
		check(not r.blocked(), "bot %d is not embedded in terrain" % r.id)
	end(m)


func test_meteor_shower() -> void:
	## The Meteor Shower match option: warned, then a crater, everyone in it
	## bonked, scrap left behind; only when it's switched on.
	check(Mutators.clean(["meteors", "nonsense", "meteors"]) == ["meteors"] and Mutators.clean(PackedStringArray(["meteors"])) == ["meteors"]
		and Mutators.clean(null).is_empty(), "only known options, once each")
	var plain := new_match({"goal": 50})
	plain.spawn_rat(0, "digger", true)
	for i in int(60.0 / DT):
		plain.step(DT)
	check(plain.meteors.strikes == 0 and plain.meteors.list.is_empty(), "no meteors unless the option is on")
	end(plain)
	var m := new_match({"goal": 50, "mutators": ["meteors"]})
	check(m.has_mutator("meteors") and m.meteors.enabled(), "switched on from the settings")
	flat_arena(m, ARENA, 7)
	# a solid floor 3 deep to dig a crater in
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			for dy in range(-4, -1):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.DIRT)
	var victim := arena_rat(m, 1, "scout", Vector3(1.0, 0, 0))
	victim.carried = 1
	var far := arena_rat(m, 0, "digger", Vector3(6.0, 0, 6.0))
	var target := Vector3(ARENA) + Vector3(0.5, 0.0, 0.5)
	m.meteors.next_in = 999.0
	var mt := m.meteors.launch(target)
	check(mt != null and m.meteors.list.size() == 1, "a meteor on its way")
	var warned := false
	for mk in m.markers:
		warned = warned or String(mk["text"]) == "METEOR!"
	check(warned and mt.pos().y > target.y + 30.0, "the spot is marked while it is still high up (%.0f blocks)" % (mt.pos().y - target.y))
	var t := 0.0
	while not m.meteors.list.is_empty() and t < 10.0:
		m.step(DT)
		t += DT
	check(m.meteors.strikes == 1 and absf(t - Config.METEOR_WARN) < 0.2, "it strikes after the warning (%.1f s)" % t)
	var holes := 0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if m.world.get_cell(ARENA + Vector3i(dx, -1, dz)) == Blocks.AIR:
				holes += 1
	check(holes >= 12, "a crater where it hit (%d of the 25 floor blocks under it gone)" % holes)
	check(victim.knock > 0.0 and victim.carried == 0 and int(victim.stats.get("bonked", 0)) == 1, "the rat under it is bonked: knocked flying, its cheese dropped")
	check(far.knock == 0.0, "a rat outside the zone is fine")
	var scrap := 0
	for dx in range(-1, 3):
		for dy in range(-5, 1):
			for dz in range(-1, 2):
				scrap += 1 if m.world.get_cell(ARENA + Vector3i(dx, dy, dz)) == Blocks.SCRAP else 0
	check(scrap == Config.METEOR_SCRAP, "the meteorite leaves %d scrap in the crater (%d)" % [Config.METEOR_SCRAP, scrap])
	# on its own: first after METEOR_FIRST, then every so often, never on a base
	var m2 := new_match({"goal": 50, "mutators": ["meteors"]})
	var launched: Array[Vector3] = []
	m2.fx.connect(func(kind: String, pos: Vector3, _d: Variant) -> void:
		if kind == "meteor_warn":
			launched.append(pos))
	var first := -1.0
	while m2.time < Config.METEOR_FIRST + Config.METEOR_GAP_MAX * 2.0 + Config.METEOR_WARN:
		m2.step(DT)
		if first < 0.0 and not launched.is_empty():
			first = m2.time
	check(absf(first - Config.METEOR_FIRST) < 0.1 and launched.size() >= 3, "the first after %.0f s, then more (%d in %.0f s)" % [first, launched.size(), m2.time])
	var clear := true
	for p in launched:
		for team in 2:
			clear = clear and not MapGenerator.base_zone(team).grow(Config.METEOR_RADIUS + 1.0).has_point(Vector3(p.x, MapGenerator.GROUND + 1.0, p.z))
	check(clear, "never on a base")
	# bots run out of the ring
	var bot := m2.spawn_rat(0, "digger", true)
	var brain: BotBrain = m2.bots[-1]
	bot.position = MapGenerator.spawn_point(0) + Vector3(20, 0, 20)
	bot.position.y = m2.meteors.surface(floori(bot.position.x), floori(bot.position.z))
	var ring := m2.meteors.launch(bot.position + Vector3(1.0, 0, 0))
	brain.think(DT)
	check(ring != null and bot.wish.x < -0.5, "a bot in the ring runs out of it (%s)" % str(bot.wish))
	# online: the meteors go in the snapshot, and keep falling between them
	var ns := NetServer.new()
	ns.m = m2
	var snap := ns._snapshot(true)
	ns.free()
	var copy := new_match({"goal": 50, "mutators": ["meteors"]})
	copy.replica = true
	copy.meteors.apply(snap.get("mt"))
	check(copy.meteors.list.size() == m2.meteors.list.size() and copy.meteors.list.size() > 0, "a player's game gets the falling meteors")
	var y0 := copy.meteors.list[0].pos().y
	copy.step(0.5)
	check(copy.meteors.list[0].pos().y < y0, "and they keep falling between snapshots")
	end(copy)
	check(ServerList.describe({"players": 1, "max_players": 31, "mode": "race", "score": [0, 0], "goal": 10, "mutators": ["meteors"]})
		== "1/31 players  -  Cheese Race 0-0 (to 10)  +  Meteor Shower", "the server list shows the options")
	var free := new_match({"mode": "free", "mutators": ["meteors"]})
	check(not free.meteors.enabled(), "Free Build has no meteors")
	end(free)
	end(m2)
	end(m)


func count_blocks(m: Match, id: int, y := -1) -> int:
	var n := 0
	for x in VoxelWorld.SX:
		for z in VoxelWorld.SZ:
			if y >= 0:
				n += 1 if m.world.get_cell(Vector3i(x, y, z)) == id else 0
			else:
				for yy in VoxelWorld.SY:
					n += 1 if m.world.get_cell(Vector3i(x, yy, z)) == id else 0
	return n


func test_lava_freeze_fungus() -> void:
	## Lava Rise, Flash Freeze and Fungal Outbreak.
	check(Mutators.clean(["fungal", "lava_rise", "flash_freeze", "meteors"]) == ["meteors", "lava_rise", "flash_freeze", "fungal"], "four extras")
	# --- Lava Rise: the schedule, and a layer creeping in ---
	var m := new_match({"goal": 50, "mutators": ["lava_rise"]})
	var x := m.extras
	check(x.lava_target(59.0) == 0, "no lava for the first minute")
	m.time = 60.0
	x.step(DT)
	var fl := x.lava_floor
	check(fl >= 1 and fl < 10 and x.lava_target(60.0) == fl and x.lava_target(72.0) == fl + 1 and x.lava_target(120.0) == fl + 5,
		"then from the lowest open air (y %d), 5 blocks a minute, a layer at a time" % fl)
	check(x.lava_target(99999.0) == Config.LAVA_RISE_MAX and Config.LAVA_RISE_MAX == MapGenerator.GROUND - 2,
		"and it stops at the layer just under the bases (y %d)" % Config.LAVA_RISE_MAX)
	var air0 := x._lava_queue.size() + count_blocks(m, Blocks.LAVA, fl) - count_blocks(new_match_cached(), Blocks.LAVA, fl)
	var ticks := 0
	while ticks < int(12.0 / DT):
		x.step(DT)
		ticks += 1
	var air1 := 0
	for xx in VoxelWorld.SX:
		for zz in VoxelWorld.SZ:
			var c := Vector3i(xx, fl, zz)
			air1 += 1 if m.world.get_cell(c) == Blocks.AIR and not MapGenerator.in_any_base(c, 1.0) else 0
	check(x.lava_level == fl and air0 > 500 and air1 == 0, "over 12 s the bottom layer fills with lava (%d open cells -> %d)" % [air0, air1])
	check(count_blocks(m, Blocks.LAVA, fl + 1) == count_blocks(new_match_cached(), Blocks.LAVA, fl + 1), "the next layer hasn't started yet")
	# rock under the lava line can still be tunnelled: nothing refills it
	var rock := Vector3i(-1, -1, -1)
	for xx in range(8, VoxelWorld.SX - 8):
		for zz in range(8, VoxelWorld.SZ - 8):
			var c := Vector3i(xx, fl, zz)
			if rock.x >= 0 or m.world.get_cell(c) != Blocks.STONE:
				continue
			var near_lava := false
			for n: Vector3i in LiquidFlow.AROUND:
				near_lava = near_lava or m.world.get_cell(c + n) == Blocks.LAVA
			if not near_lava:
				rock = c
	m.world.set_block(rock, Blocks.AIR)
	for i in int(2.0 / DT):
		x.step(DT)
		m.lava.step(DT)
	check(rock.x >= 0 and m.world.get_cell(rock) == Blocks.AIR, "a tunnel dug through the rock under the lava stays open")
	# but break into the lava and it pours in, as lava always does
	m.world.set_block(rock + Vector3i(1, 0, 0), Blocks.STONE)    # a wall...
	m.world.set_block(rock + Vector3i(2, 0, 0), Blocks.LAVA)     # ...with lava behind it
	for i in int(1.0 / DT):
		m.lava.step(DT)
	m.world.set_block(rock + Vector3i(1, 0, 0), Blocks.AIR)      # dig through
	for i in int(2.0 / DT):
		m.lava.step(DT)
	check(m.world.get_cell(rock + Vector3i(1, 0, 0)) == Blocks.LAVA, "dig into the lava and it flows in, as lava always does")
	check(m.lava.flowed < 50, "the rising layers don't use up the lava's flow budget (%d flowed)" % m.lava.flowed)
	end(m)
	# --- Flash Freeze ---
	var f := new_match({"goal": 50, "mutators": ["flash_freeze"]})
	var water0 := count_blocks(f, Blocks.WATER)
	var ice0 := count_blocks(f, Blocks.ICE)
	var toasts: Array[String] = []
	f.toast.connect(func(t: String, _team: int) -> void: toasts.append(t))
	f.time = Config.FREEZE_AT - Config.FREEZE_WARN + 0.1
	f.extras.step(DT)
	check(toasts.size() == 1 and toasts[0].contains("cold snap") and not f.extras.frozen, "a warning first")
	f.time = Config.FREEZE_AT
	for i in 60:
		f.extras.step(DT)
	check(water0 > 100 and count_blocks(f, Blocks.WATER) == 0 and count_blocks(f, Blocks.ICE) == ice0 + water0,
		"then every water block turns to ice (%d)" % water0)
	end(f)
	# --- Fungal Outbreak ---
	var g := new_match({"goal": 50, "mutators": ["fungal"]})
	flat_arena(g, ARENA, 6)
	for dx in range(-5, 6):
		for dz in range(-5, 6):
			for dy in range(0, 14):
				g.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.AIR)
	var under := arena_rat(g, 0, "scout", Vector3(2.0, 0, 0))   # (where a cap might reach: never entombed)
	g.extras._fungus_next = 999.0
	check(g.extras.grow_mushroom(ARENA), "a mushroom starts growing")
	check(g.world.get_cell(ARENA) == Blocks.AIR, "it grows, rather than appearing at once")
	for i in int((Config.FUNGUS_GROW + 0.3) / DT):
		g.extras.step(DT)
	var stem := 0
	while g.world.get_cell(ARENA + Vector3i(0, stem, 0)) == Blocks.SHROOM_STEM:
		stem += 1
	var cap := 0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			cap += 1 if g.world.get_cell(ARENA + Vector3i(dx, stem, dz)) == Blocks.SHROOM_CAP else 0
	check(stem >= Config.FUNGUS_HEIGHT_MIN and stem <= Config.FUNGUS_HEIGHT_MAX and cap >= 13,
		"a giant mushroom: a %d-block stem and a %d-block cap to stand on" % [stem, cap])
	check(not under.blocked(), "nobody is grown into it")
	end(g)
	var g2 := new_match({"goal": 50, "mutators": ["fungal"]})
	var caps0 := count_blocks(g2, Blocks.SHROOM_CAP)
	g2.spawn_rat(0, "digger", true)
	while g2.time < Config.FUNGUS_FIRST + Config.FUNGUS_GROW + 0.5:
		g2.step(DT)
	check(g2.extras.mushrooms == 1 and count_blocks(g2, Blocks.SHROOM_CAP) > caps0 + 10, "on its own: the first one %.0f s in" % Config.FUNGUS_FIRST)
	end(g2)
	end_cached()


var _cached: Match = null


func new_match_cached() -> Match:
	## (an untouched copy of the default test map, for comparisons)
	if _cached == null:
		_cached = new_match({"goal": 50})
	return _cached


func end_cached() -> void:
	if _cached != null:
		end(_cached)
		_cached = null


func jump_height(m: Match) -> float:
	## How high a rat gets from a standing jump on the arena floor.
	var r := arena_rat(m, 0, "digger")
	for i in 20:
		r.step(DT)
	var y0 := r.position.y
	r.jump_pressed = true
	var top := y0
	for i in 400:
		r.step(DT)
		r.jump_pressed = false
		top = maxf(top, r.position.y)
	m.remove_rat(r)
	return top - y0


func test_modifiers() -> void:
	## The Modifiers drop-down: rule changes for the whole match.
	check(Mutators.MODIFIERS.size() == 7 and Mutators.LIST.size() == Mutators.EXTRAS.size() + 7, "seven modifiers, in their own list")
	var plain := new_match()
	flat_arena(plain, ARENA, 6)
	var base_jump := jump_height(plain)
	# Low Gravity
	var lg := new_match({"mutators": ["low_gravity"]})
	flat_arena(lg, ARENA, 6)
	var lg_jump := jump_height(lg)
	check(is_equal_approx(lg.gravity(), Config.LOW_GRAVITY) and lg_jump > base_jump * 2.0,
		"Low Gravity: jumps go much higher (%.1f vs %.1f blocks)" % [lg_jump, base_jump])
	# ...and the server's anti-cheat knows it: an honest low-gravity jump is fine
	var r := arena_rat(lg, 0, "scout")
	for i in 20:
		r.step(DT)
	var ac := AntiCheat.new()
	ac.log_violations = false
	var clock := 10000
	ac.reset(5, r, clock)
	r.jump_pressed = true
	var bad := ""
	for i in 300:
		r.step(DT)
		r.jump_pressed = false
		if i % 2 == 0:
			clock += 33
			var v := ac.check_move(5, r, r.position, clock)
			if v != "" and bad == "":
				bad = v
	check(bad == "", "and an honest low-gravity jump passes the server's checks (%s)" % bad)
	# Super Springs
	var ss := new_match({"mutators": ["super_springs"]})
	flat_arena(ss, ARENA, 6)
	ss.world.set_block(ARENA + Vector3i(0, -1, 0), Blocks.SPRING)
	var sr := arena_rat(ss, 0, "digger")
	sr.position.y += 2.0
	var launch := 0.0
	for i in 120:
		sr.step(DT)
		if sr.landed_on_spring:
			launch = sr.vel.y
			break
	check(is_equal_approx(launch, Rat.SPRING_SPEED * Config.SUPER_SPRING), "Super Springs: launched at %.1f (three times as high)" % launch)
	# TNT Madness
	var tm := new_match({"mutators": ["tnt_madness"]})
	var tr := tm.spawn_rat(0, "digger", false)
	check(tm.price(tr, "tnt") == maxi(1, roundi(ClassDefs.price(tr.cls, "tnt", false) * Config.TNT_MADNESS_PRICE))
		and tm.price(tr, "tnt") < ClassDefs.price(tr.cls, "tnt", false) and tm.price(tr, "jetpack") == ClassDefs.price(tr.cls, "jetpack", false),
		"TNT Madness: TNT costs %d instead of %d; the rest as usual" % [tm.price(tr, "tnt"), ClassDefs.price(tr.cls, "tnt", false)])
	# Class Roulette
	var cr := new_match({"mutators": ["class_roulette"]})
	var classes := {}
	for i in 4:
		var rr := cr.spawn_rat(i % 2, ClassDefs.ORDER[i], true)
		classes[rr.id] = rr.class_id
	cr.extras.roulette()
	var changed := 0
	for rr in cr.rats:
		changed += 1 if rr.class_id != classes[rr.id] and ClassDefs.ORDER.has(rr.class_id) else 0
	check(changed == 4, "Class Roulette: everyone becomes a different class (%d of 4)" % changed)
	cr.time = 0.0
	cr.extras._roulette_next = 0.5
	for i in 40:
		cr.extras.step(DT)
	check(cr.extras.roulettes == 2, "and it spins on its own")
	# Scrap Rush
	var sc := new_match({"mutators": ["scrap_rush"]})
	flat_arena(sc, ARENA, 6)
	var miner := arena_rat(sc, 0, "digger")
	var cell := ARENA + Vector3i(0, 0, -2)
	sc.world.set_block(cell, Blocks.SCRAP)
	var s0 := miner.scrap
	for i in 40:
		miner.dig_cd = 0.0
		sc.try_dig(miner, cell)
		if sc.world.get_cell(cell) == Blocks.AIR:
			break
	check(miner.scrap - s0 == Config.BASE_SCRAP_PER_BLOCK * Config.SCRAP_RUSH, "Scrap Rush: a scrap block is worth %d" % (miner.scrap - s0))
	# Fragile World
	var fw := new_match({"mutators": ["fragile_world"]})
	check(fw.hits_for(null, Vector3i.ZERO, Blocks.OBSIDIAN) == 1 and fw.hits_for(null, Vector3i.ZERO, Blocks.STONE) == 1
		and fw.hits_for(null, Vector3i.ZERO, Blocks.BEDROCK) == int(Blocks.HITS[Blocks.BEDROCK]),
		"Fragile World: everything breaks in one hit (bedrock and bases still don't)")
	# Cheese Rain
	var rain := new_match({"mutators": ["cheese_rain"]})
	var n := rain.extras.rain_cheese()
	check(n >= 1 and rain.pickups.size() == n and rain.pickups[0].pos.y > VoxelWorld.SY - 4, "Cheese Rain: %d cheese appear high in the sky" % n)
	for i in int(8.0 / DT):
		rain._step_pickups(DT)
	var landed := true
	for p in rain.pickups:
		landed = landed and p.vel.length() < 0.01 and p.pos.y < VoxelWorld.SY - 10
	check(landed, "and fall to the ground")
	for mm in [plain, lg, ss, tm, cr, sc, fw, rain]:
		end(mm)
