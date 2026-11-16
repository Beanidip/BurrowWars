class_name BotBrain
extends RefCounted
## Bot AI for destructible terrain. There is no navmesh to rebuild: a bot
## reasons only about the handful of cells around its feet ("can I step
## there? do I need to dig, build a stair, or bridge a gap?") and tunnels
## axis-aligned toward its goal. Bots play by the same Match rules as humans.

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)

var m: Match
var rat: Rat
var rng := RandomNumberGenerator.new()

var mode := "seek"               # seek | home
var target := Vector3.ZERO
var target_cell := Vector3i(-1, -1, -1)
var retarget_t := 0.0
var detour_t := 0.0
var detour_dir := Vector3i(1, 0, 0)
var use_x := true
var stuck_t := 0.0
var stuck_pos := Vector3.ZERO
var stuck_count := 0
var jitter := 0.0
var final_run := false
var rest_t := 0.0
var last_carried := 0


func _init(p_match: Match, p_rat: Rat, p_seed: int) -> void:
	m = p_match
	rat = p_rat
	rng.seed = p_seed
	jitter = rng.randf_range(0.0, 1000.0)
	stuck_pos = rat.position


func think(dt: float) -> void:
	rat.wish = Vector3.ZERO
	rat.jump_held = false
	rat.down_held = false
	if rat.stun > 0.0 or rat.knock > 0.0:
		return
	rat.mats["dirt"] = maxi(int(rat.mats["dirt"]), 12)  # bots always have stair dirt
	_try_bonk()
	# skill knob: lower-skill bots pause to celebrate every pickup and deposit
	if rat.carried != last_carried:
		last_carried = rat.carried
		rest_t = float(m.settings.get("bot_rest", 0.0))
	if rest_t > 0.0:
		rest_t -= dt
		return
	retarget_t -= dt
	if retarget_t <= 0.0:
		retarget_t = 0.8 + rng.randf() * 0.4
		_retarget()
	_track_stuck(dt)
	if detour_t > 0.0:
		detour_t -= dt
		_step_level(detour_dir)
		return
	_navigate()


# ---------------------------------------------------------------- goals

func _retarget() -> void:
	target_cell = Vector3i(-1, -1, -1)
	var enemy := 1 - rat.team
	if not m.free_mode and rat.carried == 0:
		# defend: someone is in our vault and we are close enough to matter
		for other in m.rats:
			if other.team == enemy and m.in_base(other, rat.team) and other.position.distance_to(rat.position) < 30.0 and m.scores[rat.team] > 0:
				mode = "defend"
				target = other.position
				return
	# raid: when clearly behind, half the team goes for the enemy vault instead of digging
	var behind := m.scores[enemy] - m.scores[rat.team]
	if not m.free_mode and m.scores[enemy] > 0 and rat.carried < rat.capacity() \
			and ((mode == "raid" and behind >= 0) or (behind >= 2 and rat.id % 2 == 0 and rat.carried == 0)):
		mode = "raid"
		var ez := MapGenerator.base_zone(enemy)
		target = ez.position + Vector3(ez.size.x * 0.5, 0.0, ez.size.z * 0.5)
		return
	var cheese: Variant = _pick_cheese()
	var full := rat.carried >= rat.capacity()
	var far := cheese == null or (cheese as Vector3).distance_to(rat.position) > 12.0
	if rat.carried > 0 and (full or far or mode == "raid"):
		mode = "home"
		var zone := MapGenerator.base_zone(rat.team)
		var gate := MapGenerator.approach_point(rat.team)
		# front edge of the platform: the first spot that counts as "home"
		var door := Vector3(zone.position.x + (zone.size.x - 0.5 if rat.team == 0 else 0.5), zone.position.y, gate.z)
		var flat := Vector2(rat.position.x - gate.x, rat.position.z - gate.z).length()
		if not final_run and flat < 1.5 and rat.position.y > MapGenerator.GROUND - 0.5:
			final_run = true
		elif final_run and rat.position.y < MapGenerator.GROUND - 1.5:
			final_run = false   # fell into a hole: regroup at the gate
		target = door if final_run else gate
		return
	final_run = false
	mode = "seek"
	if cheese != null:
		target = cheese
	else:
		target = Vector3(VoxelWorld.SX * 0.5, 20.0, VoxelWorld.SZ * 0.5)


func _pick_cheese() -> Variant:
	var best: Variant = null
	var best_cost := INF
	for p in m.pickups:
		if p.kind != "cheese" or (p.lock_id == rat.id and p.lock_t > 0.0):
			continue
		var d := p.pos.distance_to(rat.position)
		if d < 22.0 and d < best_cost:
			best_cost = d
			best = p.pos
	if best != null:
		return best
	for c: Vector3i in m.world.cheese_cells:
		var p2 := Vector3(c) + Vector3(0.5, 0.0, 0.5)
		# per-bot preference noise so teammates spread over different deposits
		var noise := fmod(absf(float(c.x * 31 + c.y * 17 + c.z * 13) + jitter), 9.0)
		var cost := p2.distance_to(rat.position) + noise + absf(p2.y - rat.position.y) * 0.5
		if cost < best_cost:
			best_cost = cost
			best = p2
			target_cell = c
	return best


func _try_bonk() -> void:
	if rat.bonk_cd > 0.0:
		return
	for other in m.rats:
		if other.team != rat.team and other.center().distance_to(rat.center()) < 1.9:
			m.try_bonk(rat, other)
			return


# ---------------------------------------------------------------- movement

func _navigate() -> void:
	var c := rat.feet_cell()
	var d := target - rat.position
	if rat.in_water:
		rat.jump_held = d.y > -0.5
	if rat.on_ladder:
		rat.jump_held = d.y > 0.4
		rat.down_held = d.y < -0.4
	# cheese block within paw's reach: mine it
	if mode == "seek" and target_cell.y >= 0 and m.world.get_cell(target_cell) == Blocks.CHEESE:
		if (Vector3(target_cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) < 2.1:
			_face(Vector3(target_cell) + Vector3(0.5, 0.5, 0.5) - rat.eye())
			m.try_dig(rat, target_cell)
			return
	var ax := absf(d.x)
	var az := absf(d.z)
	# close underneath (or on top of) the goal: go straight up or down
	if (ax < 0.45 and az < 0.45) or (d.y > 0.6 and ax < 2.5 and az < 2.5 and mode == "home"):
		_vertical(c, d.y)
		return
	# stay on one axis until it is used up: keeps tunnels straight
	if use_x and ax < 0.45:
		use_x = false
	elif not use_x and az < 0.45:
		use_x = true
	var dir := Vector3i(1 if d.x > 0.0 else -1, 0, 0) if use_x else Vector3i(0, 0, 1 if d.z > 0.0 else -1)
	if d.y > 0.6:
		_step_up(c, dir)
	elif d.y < -0.6:
		_step_down(c, dir)
	else:
		_step_level(dir)


func _vertical(c: Vector3i, dy: float) -> void:
	if dy > 0.6:
		if _solid(c + UP):
			_dig(c + UP)
			return
		if rat.on_floor:
			rat.jump_pressed = true
		elif rat.vel.y < 2.0 and not _solid(c + DOWN) and absf(rat.position.y - floorf(rat.position.y)) > 0.05:
			m.try_place_mat(rat, c + DOWN, "dirt")   # pillar up
	elif dy < -0.6:
		var below := c + DOWN
		if m.world.get_cell(below + DOWN) == Blocks.LAVA or m.world.get_cell(below) == Blocks.LAVA:
			_start_detour()
		elif _solid(below):
			_dig(below)


func _step_up(c: Vector3i, dir: Vector3i) -> void:
	var ahead := c + dir
	if _solid(c + UP):
		_dig(c + UP)
		return
	if _solid(ahead + UP):
		_dig(ahead + UP)
		return
	if not _solid(ahead) and rat.on_floor:
		# nothing to climb onto: build a dirt stair (falls back to walking if refused)
		if m.try_place_mat(rat, ahead, "dirt") == "":
			return
	if rat.on_floor and _solid(ahead):
		rat.jump_pressed = true
	_walk(dir)


func _step_down(c: Vector3i, dir: Vector3i) -> void:
	var ahead := c + dir
	if _solid(ahead):
		_dig(ahead)
		return
	var lower := ahead + DOWN
	if _is_lava(lower) or _is_lava(lower + DOWN):
		_step_level(dir)
		return
	if _solid(lower):
		_dig(lower)
		return
	_walk(dir)


func _step_level(dir: Vector3i) -> void:
	var c := rat.feet_cell()
	var ahead := c + dir
	if _solid(ahead):
		_dig(ahead)
		return
	var below := ahead + DOWN
	var chasm := not _solid(below) and not _solid(below + DOWN) and not _solid(below + DOWN * 2)
	if _is_lava(below) or (chasm and rat.on_floor):
		m.try_place_mat(rat, below, "dirt")   # bridge hazards and deep drops
	_walk(dir)


func _walk(dir: Vector3i) -> void:
	var w := Vector3(dir)
	# drift toward the middle of the lane so the body fits one-block tunnels
	if dir.x != 0:
		w.z = clampf((floorf(rat.position.z) + 0.5 - rat.position.z) * 3.0, -0.6, 0.6)
	else:
		w.x = clampf((floorf(rat.position.x) + 0.5 - rat.position.x) * 3.0, -0.6, 0.6)
	rat.wish = w
	_face(Vector3(dir))


func _face(v: Vector3) -> void:
	if absf(v.x) + absf(v.z) > 0.01:
		rat.yaw = atan2(-v.x, -v.z)


func _solid(c: Vector3i) -> bool:
	return Blocks.solid_for(m.world.get_cell(c), rat.team)


func _is_lava(c: Vector3i) -> bool:
	return m.world.get_cell(c) == Blocks.LAVA


func _dig(c: Vector3i) -> void:
	var id := m.world.get_cell(c)
	# never open a tunnel straight into lava: plug it first
	for n: Vector3i in [c + UP, c + DOWN, c + Vector3i(1, 0, 0), c + Vector3i(-1, 0, 0), c + Vector3i(0, 0, 1), c + Vector3i(0, 0, -1)]:
		if _is_lava(n):
			if m.try_place_mat(rat, n, "dirt") == "":
				return
	var own_gate := Blocks.is_gate(id) and Blocks.gate_team(id) == rat.team
	if (Blocks.HITS[id] == 0 and not own_gate and id != Blocks.TNT) or not VoxelWorld.in_bounds(c):
		_start_detour()
		return
	_face(Vector3(c) + Vector3(0.5, 0.5, 0.5) - rat.eye())
	m.try_dig(rat, c)


func _start_detour() -> void:
	detour_t = 1.0 + rng.randf()
	var options: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	detour_dir = options[rng.randi() % 4]


func _track_stuck(dt: float) -> void:
	stuck_t += dt
	if stuck_t < 6.0:
		return
	stuck_t = 0.0
	if rat.position.distance_to(stuck_pos) > 0.8:
		stuck_count = 0
	else:
		stuck_count += 1
		_start_detour()
		if rat.on_floor:
			rat.jump_pressed = true
		if stuck_count >= 4:
			stuck_count = 0
			m.respawn(rat)
	stuck_pos = rat.position
