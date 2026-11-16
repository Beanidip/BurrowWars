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
		"class_permissions", "win_condition", "vault_raid", "digger_power", "water_exit", "lava_flows", "ladder_stack_and_floor_gadgets",
		"team_block_and_builder", "ice_slides_off_the_end", "scrap_abundance",
		"painted_blocks", "highway_layer", "siege_floor_conveyor", "wrecking_ball_table", "bonked_pilot", "save_load", "free_build",
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
	var mismatches := 0
	for y in VoxelWorld.SY:
		for z in VoxelWorld.SZ:
			for x in VoxelWorld.SX / 2:
				if Blocks.mirror(a.world.get_block(x, y, z)) != a.world.get_block(VoxelWorld.SX - 1 - x, y, z):
					mismatches += 1
	check(mismatches == 0, "red half mirrors blue half (%d mismatches)" % mismatches)
	var blue := 0
	for cell: Vector3i in a.world.cheese_cells:
		if cell.x < VoxelWorld.SX / 2:
			blue += 1
	check(blue * 2 == a.world.cheese_cells.size(), "cheese is split evenly between halves")
	check(a.world.cheese_cells.size() >= 24, "enough cheese on the map (%d)" % a.world.cheese_cells.size())
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
	var base_cell := Vector3i(5, MapGenerator.GROUND - 1, 24)
	r.position = Vector3(5.5, MapGenerator.GROUND, 23.5)
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
	run(m, 1.1)
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
	check(m.use_ability(d, 0, {"cell": Vector3i(5, MapGenerator.GROUND - 1, 24), "normal": Vector3i(0, 1, 0)}) != "", "Super Dig is refused out of reach / on base blocks")
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
	r.position = Vector3(11.0, MapGenerator.GROUND, 24.5)
	check(m.try_place_mat(r, Vector3i(8, MapGenerator.GROUND, 24), "dirt") != "", "bases are protected from building")
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
	check(m.try_place_mat(r, Vector3i(41, 40, 10), "wood") == "", "unlimited materials")
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
	check(m.in_base(r) and r.carried == 0, "touching lava sends a rat home without its cheese (nobody dies)")
	# generated pools exist on both halves
	var per_half := [0, 0]
	var fresh := new_match()
	for i in fresh.world.data.size():
		if fresh.world.data[i] == Blocks.LAVA and i / (VoxelWorld.SX * VoxelWorld.SZ) >= 5:
			per_half[0 if i % VoxelWorld.SX < VoxelWorld.SX / 2 else 1] += 1
	check(per_half[0] > 20 and per_half[0] == per_half[1], "underground lava pools are generated and mirrored (%d per side)" % per_half[0])
	end(fresh)
	end(m)


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
	check(m.try_use_equipped(r, {"cell": Vector3i(5, MapGenerator.GROUND - 1, 24), "normal": Vector3i(0, 1, 0)}, look, false) != "" and int(r.gadgets["highway"]) == 1, "base floor cannot be converted")
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
	for dx in range(1, 4):
		b.ability_cd = [0.0, 0.0]
		if m.use_ability(b, 1, {"cell": ARENA + Vector3i(dx - 1, -1, 0), "normal": Vector3i(1, 0, 0)}) == "":
			placed += 1
	check(placed == 3 and m.world.get_cell(ARENA + Vector3i(2, -1, 0)) == Blocks.TEAM_BLUE, "Builder's Team Block ability places team-coloured blocks")
	check(b.stamina < b.max_stamina(), "it costs stamina, not scrap or materials")
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
	var pk := m.spawn_pickup("stash", Vector3(ARENA) + Vector3(2.5, 0.6, 0.5), Vector3.ZERO)
	pk.lock_id = b.id
	pk.lock_t = 99.0
	pk.mats = {"dirt": 1}
	run(m, 1.0)
	check(pk.pos.y < ARENA.y - 1.0, "loose objects drop through it as well")
	b.ability_cd = [0.0, 0.0]
	check(m.use_ability(b, 1, {"cell": b.feet_cell() + Vector3i(0, -1, 0), "normal": Vector3i(0, 1, 0)}) != "", "cannot be placed inside a teammate")
	# free gates
	var scrap := b.scrap
	check(int(b.gadgets["gate"]) == 4, "Builder starts with team gates")
	check(m.try_buy(b, "gate") == "" and b.scrap == scrap and int(b.gadgets["gate"]) == 5, "Builder gets team gates free at the workshop")
	foe.position = MapGenerator.spawn_point(1)
	foe.scrap = 3
	check(m.try_buy(foe, "gate") != "" and foe.scrap == 3, "other classes still pay for gates")
	check((b.cls["abilities"] as Array).size() == 2 and b.cls["abilities"][1][0] == "teamblock", "Highway ability is replaced by Team Block")
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
	check(m.try_place_paint(r, cell, 3) != "", "painted blocks need stone")
	r.mats["stone"] = 3
	check(m.try_place_paint(r, cell, 3) == "" and m.world.get_cell(cell) == Blocks.PAINT_0 + 3, "places a full block in the chosen colour")
	check(int(r.mats["stone"]) == 2, "it costs one stone")
	check(m.try_place_paint(r, cell + Vector3i(0, 1, 0), 99) != "" and m.try_place_paint(r, cell + Vector3i(0, 1, 0), -1) != "", "colours outside the palette are refused")
	var distinct := {}
	for k in Blocks.PALETTE_SIZE:
		distinct[Blocks.paint_color(k).to_html()] = true
	check(distinct.size() == 12, "twelve distinct palette colours")
	check(r.blocked_at(Vector3(cell) + Vector3(0.5, 0, 0.5)), "painted blocks are solid")
	var n := 0
	while m.world.get_cell(cell) != Blocks.AIR and n < 20:
		r.dig_cd = 0.0
		m.try_dig(r, cell)
		n += 1
	check(n == 4 and int(r.mats["stone"]) == 3, "digging one takes 4 hits and returns the stone (no free material)")
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
	r.position = Vector3(11.0, MapGenerator.GROUND, 24.5)
	r.mats["stone"] = 5
	check(chisel(m, r, Vector3i(9, MapGenerator.GROUND - 1, 24), Vector3i(6, 6, 3)) != "", "base blocks cannot be carved")
	check(chisel(m, r, Vector3i(9, MapGenerator.GROUND, 24), Vector3i(6, 0, 3), true) != "", "cannot chisel material into a base")
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
	m.world.set_block(a + Vector3i(1, 0, 0), Blocks.WOOD)
	m.world.set_block(a + Vector3i(0, 1, 0), Blocks.CHEESE)
	m.world.set_block(a + Vector3i(1, 1, 0), Blocks.TNT)
	m.world.set_block(a + Vector3i(0, 0, 1), Blocks.SCRAP)
	var carved := mask_layers(3)
	carved[0] = 0   # an asymmetric notch so rotation is observable
	m.world.set_mask(a + Vector3i(1, 0, 1), Blocks.WOOD, carved)
	var res := m.copy_region(r, a, a + Vector3i(1, 1, 1))
	check(res.has("blueprint"), "copies a region")
	var bp: Blueprint = res["blueprint"]
	check(bp.size == Vector3i(2, 2, 2) and bp.cells.size() == 3, "captures the 3 material blocks (%d)" % bp.cells.size())
	check(bp.skipped == 3, "cheese, TNT and scrap are never captured (%d skipped)" % bp.skipped)
	var need := bp.cost()
	check(int(need["stone"]) == 343 and int(need["wood"]) == 343 + 146, "material estimate counts carvings exactly")
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
	r.mats["wood"] = 1
	check(m.try_paste(r, bp, dest).begins_with("Not enough wood"), "refused when one material is short")
	check(int(r.mats["stone"]) == 1 and int(r.mats["wood"]) == 1, "a refused paste costs nothing")
	r.mats["wood"] = 2
	check(m.paste_check(r, bp, dest) == "" and m.try_paste(r, bp, dest) == "", "pastes when affordable")
	check(m.world.get_cell(dest) == Blocks.STONE and m.world.get_cell(dest + Vector3i(1, 0, 0)) == Blocks.WOOD, "blocks reproduced")
	check(m.world.get_cell(dest + Vector3i(0, 1, 0)) == Blocks.AIR and m.world.get_cell(dest + Vector3i(1, 1, 0)) == Blocks.AIR, "no cheese or TNT was duplicated")
	var pasted := dest + Vector3i(1, 0, 1)
	check(m.world.has_micro(pasted) and (m.world.micro[pasted] as PackedByteArray) == carved, "carved block reproduced microvoxel for microvoxel")
	check(int(r.mats["stone"]) == 0 and int(r.mats["wood"]) * 343 + int(r.micro_bank.get("wood", 0)) == 686 - 489, "exact materials deducted")
	check(m.try_paste(r, bp, dest) != "", "cannot paste into occupied space")
	r.mats["stone"] = 9
	r.mats["wood"] = 9
	check(m.try_paste(r, bp, r.feet_cell() - Vector3i(0, 0, 0)) != "", "cannot paste on top of a rat")
	r.position = Vector3(12.0, MapGenerator.GROUND, 24.5)
	check(m.try_paste(r, bp, Vector3i(8, MapGenerator.GROUND, 24)) == "Bases are protected", "cannot paste into a base")
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
	check(m.siege.fire(r) == "" and m.siege.shots.size() == 1, "fires a physical projectile")
	check(m.siege.fire(r) == "wait", "cannon has a cooldown")
	var travelled := 0
	while m.siege.shots.size() > 0 and travelled < 200:
		m.step(DT)
		travelled += 1
	check(travelled > 5 and travelled < 60, "projectile takes visible time to arrive (%d ticks)" % travelled)
	var three := 0
	var ones := 0
	var struck := Vector3i.ZERO
	for c: Vector3i in m.world.damage:
		if int(m.world.damage[c]) == 3:
			three += 1
			struck = c
		elif int(m.world.damage[c]) == 1:
			ones += 1
	check(three == 1 and struck.x == ARENA.x + 7, "struck block takes 3x dig damage")
	check(ones == 4, "exactly four neighbouring blocks take excavation damage (%d)" % ones)
	var ring_ok := true
	for n: Vector3i in [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		ring_ok = ring_ok and int(m.world.damage.get(struck + n, 0)) == 1
	check(ring_ok, "the four are the blocks around the impact")
	check(arc[-1].distance_to(Vector3(struck) + Vector3(0.5, 0.5, 0.5)) < 1.2, "shot lands where the preview said")
	check(kinds.has("cannon") and kinds.has("impact"), "firing and impact feedback are emitted")
	# second shot at the same spot: stone (4) breaks, neighbours are at 2
	run(m, Config.CANNON_COOLDOWN + 0.1)
	m.siege.fire(r)
	run(m, 1.0)
	check(m.world.get_cell(struck) == Blocks.AIR, "a second hit breaks the stone")
	check(int(r.mats["stone"]) == 1, "cannon-mined stone goes to the gunner")
	# obsidian resists by its durability
	m.world.set_block(struck, Blocks.OBSIDIAN)
	run(m, Config.CANNON_COOLDOWN)
	m.siege.fire(r)
	run(m, 1.0)
	check(m.world.get_cell(struck) == Blocks.OBSIDIAN and int(m.world.damage.get(struck, 0)) == 3, "obsidian takes the hit and stands (3 of 12)")
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
	m.siege.aim(r, 0.0, 0.0)
	check(SiegeSystem.facing(mc) == Vector3i(0, 0, -1), "blade turns to face where the driver looks")
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
