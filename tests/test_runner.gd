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
		"class_permissions", "win_condition", "save_load", "free_build", "bots_complete_a_match",
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
	var r := arena_rat(m, 0, "scout", Vector3(-8, 0, 0))
	run(m, 0.3)
	r.wish = Vector3(1, 0, 0)
	var x0 := r.position.x
	run(m, 1.0)
	var free_speed := r.position.x - x0
	r.position.x = ARENA.x - 8.0
	r.vel = Vector3.ZERO
	r.carried = 1
	x0 = r.position.x
	run(m, 1.0)
	var carry_speed := r.position.x - x0
	check(absf(carry_speed / free_speed - Config.CARRY_SPEED_MULT) < 0.06, "carrying cheese = ~25%% speed (%.2f)" % (carry_speed / free_speed))
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
	# digger brush
	var d := arena_rat(m, 0, "digger")
	for dx in range(1, 4):
		for dy in 3:
			for dz in range(-1, 2):
				m.world.set_block(ARENA + Vector3i(dx, dy, dz), Blocks.DIRT)
	run(m, 0.4)
	m.try_dig(d, ARENA + Vector3i(2, 1, 0))
	run(m, 0.4)
	m.try_dig(d, ARENA + Vector3i(2, 1, 0))
	var gone := 0
	for dx in range(1, 4):
		for dy in 3:
			for dz in range(-1, 2):
				if m.world.get_cell(ARENA + Vector3i(dx, dy, dz)) == Blocks.AIR:
					gone += 1
	check(gone == 27, "digger brush clears a 3x3x3 of dirt in two swings (%d)" % gone)
	for dx in range(-1, 3):
		for dz in range(-1, 2):
			m.world.set_block(ARENA + Vector3i(dx, -1, dz), Blocks.DIRT)
	m.world.set_block(ARENA + Vector3i(1, 0, 0), Blocks.DIRT)
	for i in 2:
		run(m, 0.4)
		m.try_dig(d, ARENA + Vector3i(1, 0, 0))
	check(m.world.get_cell(ARENA + Vector3i(0, -1, 0)) == Blocks.DIRT, "digger brush does not undermine its own footing when digging level")
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
	check(m.world.get_cell(ARENA + Vector3i(0, 0, -6)) == Blocks.AIR and int(r.gadgets.get("gate", 0)) == 1, "owner team removes and recovers its gate")
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
	check(m.use_ability(digger, 0) == "" and m.markers.size() == 1, "Burrow Sense marks a hollow")
	check(m.use_ability(digger, 0) != "", "ability cooldown enforced")
	check(m.use_ability(scout, 0) == "" and m.markers.size() == 2, "Sniff marks cheese")
	check(m.use_ability(scout, 1) == "" and m.markers.size() == 3, "Beacon drops a team marker")
	check(is_equal_approx(float(m.markers[2]["ttl"]), 120.0), "beacon lasts two minutes")
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
	builder.yaw = PI / 2.0   # facing -X
	builder.stamina = 100.0
	check(m.use_ability(builder, 1) == "", "Highway fires")
	check(m.world.get_cell(ARENA + Vector3i(-3, -1, 0)) == Blocks.HIGHWAY, "Highway lays planks ahead")
	run(m, 0.1)
	var base_speed := Config.BASE_SPEED * float(builder.cls["speed"])
	check(builder.move_speed() > base_speed * 1.5, "highway boosts speed")
	check(int(builder.gadgets.get("ladder", 0)) == 6, "builder starts with ladders")
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
