class_name ExtrasSystem
## The timed match options (Mutators) other than meteors, run on the
## authority. Everything they do is ordinary block changes, effects and
## toasts, so players' games follow without anything new on the wire.
##
##  - Lava Rise: from LAVA_RISE_START, lava fills the open air at the bottom
##    of the map and climbs LAVA_RISE_STEP blocks a minute, a layer at a time
##    and a few cells a tick (so it creeps), up to LAVA_RISE_MAX: the layer
##    just under the base platforms. Anything dug or blasted open below the
##    line fills in again.
##  - Flash Freeze: at FREEZE_AT (warned FREEZE_WARN before), every water
##    block on the map turns to ice.
##  - Fungal Outbreak: from FUNGUS_FIRST, every FUNGUS_GAP_* seconds a giant
##    mushroom grows somewhere on the battlefield over FUNGUS_GROW seconds:
##    stem up, then a broad cap - new platforms and new obstacles.

var m: Match
var _rng := RandomNumberGenerator.new()

# lava rise
var lava_level := 0                # highest y the lava has filled (0: not yet)
var lava_floor := -1               # the lowest level with open air: where it starts (found when it does)
var _lava_queue: Array[Vector3i] = []
var _lava_rate := 1                # cells a tick for the layer being filled
var _refill: Dictionary = {}       # Vector3i -> seconds: opened below the line, lava pours back in
var _lava_told := 0                # rises announced

# flash freeze
var frozen := false
var _freeze_warned := false
var _freeze_queue: Array[Vector3i] = []

# fungal outbreak
var mushrooms := 0
var _fungus_next := Config.FUNGUS_FIRST
var _growing: Array = []           # [[cell, block, seconds until it appears], ...]


func _init(p_match: Match) -> void:
	m = p_match
	_rng.seed = int(m.settings.get("seed", 1)) * 53 + 11


func on(id: String) -> bool:
	return m.has_mutator(id) and not m.free_mode


func step(dt: float) -> void:
	if on("lava_rise"):
		_lava_step(dt)
	if on("flash_freeze"):
		_freeze_step()
	if on("fungal"):
		_fungus_step(dt)


func on_block_changed(cell: Vector3i, _old: int, new_id: int) -> void:
	## Lava Rise: a hole opened below the lava line fills back in.
	if lava_level > 0 and new_id == Blocks.AIR and cell.y <= lava_level and cell.y >= 1 \
			and not MapGenerator.in_any_base(cell, 1.0):
		_refill[cell] = Config.LAVA_REFILL


# ---------------------------------------------------------------- lava rise

func lava_target(t: float) -> int:
	## The height the lava is heading for at match time t (0 before it starts).
	if t < Config.LAVA_RISE_START:
		return 0
	var per_layer := 60.0 / float(Config.LAVA_RISE_STEP)
	return mini(Config.LAVA_RISE_MAX, maxi(lava_floor, 1) + int((t - Config.LAVA_RISE_START) / per_layer))


func _lava_step(dt: float) -> void:
	if not m.over and m.time >= Config.LAVA_RISE_START - 5.0 and _lava_told == 0:
		_lava_told = 1
		m.toast.emit("LAVA RISE: the lava is coming up from below - it climbs %d blocks a minute!" % Config.LAVA_RISE_STEP, -1)
	if lava_floor < 0 and m.time >= Config.LAVA_RISE_START:
		# "the bottom of the map": the lowest level with any open air (the
		# deepest caves); the solid rock under them stays as it is
		lava_floor = 1
		while lava_floor < Config.LAVA_RISE_MAX and _air_at(lava_floor).is_empty():
			lava_floor += 1
		lava_level = lava_floor - 1
	var target := lava_target(m.time)
	if _lava_queue.is_empty() and lava_level < target:
		lava_level += 1
		_lava_queue = _air_at(lava_level)
		_lava_rate = maxi(1, ceili(float(_lava_queue.size()) / (60.0 / float(Config.LAVA_RISE_STEP) * 60.0 * 0.85)))
		if lava_level == Config.LAVA_RISE_MAX:
			m.toast.emit("The lava has stopped rising, just under the bases.", -1)
		elif lava_level > lava_floor and (lava_level - lava_floor) % Config.LAVA_RISE_STEP == 0:
			m.toast.emit("The lava is rising again! (%d blocks under the bases)" % (Config.LAVA_RISE_MAX - lava_level + 1), -1)
	var n := 0
	while not _lava_queue.is_empty() and n < _lava_rate:
		var c: Vector3i = _lava_queue.pop_back()
		if m.world.get_cell(c) == Blocks.AIR:
			m.world.set_block(c, Blocks.LAVA)
			n += 1
	for c: Vector3i in _refill.keys():
		_refill[c] = float(_refill[c]) - dt
		if float(_refill[c]) <= 0.0:
			_refill.erase(c)
			if m.world.get_cell(c) == Blocks.AIR and not _occupied(c):
				m.world.set_block(c, Blocks.LAVA)


func _air_at(y: int) -> Array[Vector3i]:
	## Every open cell on one level, outside the bases, in a shuffled order so
	## the layer creeps in all over rather than sweeping across.
	var out: Array[Vector3i] = []
	for x in VoxelWorld.SX:
		for z in VoxelWorld.SZ:
			var c := Vector3i(x, y, z)
			if m.world.get_cell(c) == Blocks.AIR and not MapGenerator.in_any_base(c, 1.0):
				out.append(c)
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _occupied(c: Vector3i) -> bool:
	var box := AABB(Vector3(c), Vector3.ONE)
	for r in m.rats:
		if box.grow(0.3).has_point(r.center()) or box.has_point(r.position + Vector3(0, 0.1, 0)):
			return true
	return false


# ---------------------------------------------------------------- flash freeze

func _freeze_step() -> void:
	if frozen and _freeze_queue.is_empty():
		return
	if not _freeze_warned and m.time >= Config.FREEZE_AT - Config.FREEZE_WARN:
		_freeze_warned = true
		m.toast.emit("FLASH FREEZE: a cold snap is coming - all the water is about to freeze! Get out of it!", -1)
		m.fx.emit("freeze_warn", Vector3(VoxelWorld.SX * 0.5, MapGenerator.GROUND, VoxelWorld.SZ * 0.5), null)
	if not frozen and m.time >= Config.FREEZE_AT:
		frozen = true
		_freeze_queue = m._find_blocks(Blocks.WATER)
		m.water.active.clear()
		m.toast.emit("FLASH FREEZE! Every drop of water is ice now. Mind your footing.", -1)
		m.fx.emit("freeze", Vector3(VoxelWorld.SX * 0.5, MapGenerator.GROUND, VoxelWorld.SZ * 0.5), _freeze_queue.size())
	var n := 0
	while not _freeze_queue.is_empty() and n < Config.FREEZE_PER_TICK:
		var c: Vector3i = _freeze_queue.pop_back()
		if m.world.get_cell(c) == Blocks.WATER:
			m.world.set_block(c, Blocks.ICE)
			n += 1
	if frozen and _freeze_queue.is_empty():
		for r in m.rats:
			if r.blocked():
				r.unstick()   # caught swimming: out on top of the ice
		for p in m.pickups:
			if m.world.solid_point(p.pos):
				p.pos.y = floorf(p.pos.y) + 1.15


# ---------------------------------------------------------------- fungal outbreak

func _fungus_step(dt: float) -> void:
	if not m.over and mushrooms < Config.FUNGUS_MAX:
		_fungus_next -= dt
		if _fungus_next <= 0.0:
			_fungus_next = _rng.randf_range(Config.FUNGUS_GAP_MIN, Config.FUNGUS_GAP_MAX)
			grow_mushroom()
	for i in range(_growing.size() - 1, -1, -1):
		var g: Array = _growing[i]
		g[2] = float(g[2]) - dt
		if float(g[2]) > 0.0:
			continue
		_growing.remove_at(i)
		var c: Vector3i = g[0]
		if VoxelWorld.in_bounds(c) and m.world.get_cell(c) == Blocks.AIR and not _occupied(c):
			m.world.set_block(c, int(g[1]))


func grow_mushroom(at := Vector3i(-1, -1, -1)) -> bool:
	## Start a giant mushroom growing at a random spot on open ground (or `at`,
	## the cell it stands on top of). False if no good spot turned up.
	var base := at
	if base.x < 0:
		for i in 40:
			var x := _rng.randi_range(6, VoxelWorld.SX - 7)
			var z := _rng.randi_range(6, VoxelWorld.SZ - 7)
			var y := int(m.meteors.surface(x, z))   # (the first free cell above the ground)
			var under := m.world.get_cell(Vector3i(x, y - 1, z))
			if y < 2 or y > VoxelWorld.SY - 16 or Blocks.SOLID[under] == 0 or under == Blocks.LAVA or under == Blocks.WATER:
				continue
			if _near_base(x, z):
				continue
			base = Vector3i(x, y, z)
			break
		if base.x < 0:
			return false
	mushrooms += 1
	var h := _rng.randi_range(Config.FUNGUS_HEIGHT_MIN, Config.FUNGUS_HEIGHT_MAX)
	var r := _rng.randi_range(2, 3)
	var per := Config.FUNGUS_GROW / float(h + r + 2)
	var t := 0.0
	for y in h:
		t += per
		_growing.append([base + Vector3i(0, y, 0), Blocks.SHROOM_STEM, t])
	# the cap: a broad disc, rim first, then a smaller dome on top
	for ring in range(0, r + 1):
		t += per
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var d := Vector2(dx, dz).length()
				if d <= r + 0.4 and int(round(d)) == ring:
					_growing.append([base + Vector3i(dx, h, dz), Blocks.SHROOM_CAP, t])
	t += per
	for dx in range(-(r - 1), r):
		for dz in range(-(r - 1), r):
			if Vector2(dx, dz).length() <= r - 0.6:
				_growing.append([base + Vector3i(dx, h + 1, dz), Blocks.SHROOM_CAP, t])
	m.fx.emit("fungus", Vector3(base) + Vector3(0.5, 0.0, 0.5), h)
	return true


func _near_base(x: int, z: int) -> bool:
	var keep := 6.0
	for team in 2:
		var b := MapGenerator.base_zone(team)
		if x > b.position.x - keep and x < b.end.x + keep and z > b.position.z - keep and z < b.end.z + keep:
			return true
	return false
