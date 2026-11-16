class_name MapGenerator
## Procedural Cheese Race maps. Bases sit in opposite corners. Every seed makes
## a different map, but every map has exact 180-degree rotational symmetry about
## its centre: only team 0's half (x < HALF) is generated, and the other half is
## that same half turned around. Both teams therefore always get identical
## terrain, scrap, cheese, lava, water and landmarks, just on the far side of
## the map and facing the other way.
##
## Terrain is three noise layers: a large "continent" layer chooses plains,
## mountain ranges and valleys; ridged noise shapes the peaks; small hills roll
## everything. Valleys below the water line hold lakes. The ground is levelled
## around each base. Resources are scattered by sector (the half is cut into a
## grid and every sector gets its share) so they are spread across the whole
## map instead of clumping.

const GROUND := 32                 # base platform level; plains sit around here
const WATER_LEVEL := GROUND - 5    # only the deepest valley floors hold lakes
const HALF := VoxelWorld.SX / 2
const MID_Z := VoxelWorld.SZ / 2
const BASE_MIN := 6                # base platform corner (team 0)
const BASE_SIZE := 8
const FLAT_RADIUS := 22.0          # terrain is levelled this far around a base (fully flat for 70% of it)
const SECTOR := 16                 # resource scattering grid

static var _cache: Dictionary = {}   # seed -> [data, points of interest]


# ---------------------------------------------------------------- geometry

static func rot_cell(c: Vector3i) -> Vector3i:
	## The matching cell on the other team's side.
	return Vector3i(VoxelWorld.SX - 1 - c.x, c.y, VoxelWorld.SZ - 1 - c.z)


static func rot_point(p: Vector3) -> Vector3:
	return Vector3(VoxelWorld.SX - p.x, p.y, VoxelWorld.SZ - p.z)


static func base_center(team: int) -> Vector3:
	var c := Vector3(BASE_MIN + BASE_SIZE * 0.5, GROUND, BASE_MIN + BASE_SIZE * 0.5)
	return c if team == 0 else rot_point(c)


static func base_zone(team: int) -> AABB:
	## Deposit / workshop / class-change volume above the base platform.
	var zone := AABB(Vector3(BASE_MIN, GROUND, BASE_MIN), Vector3(BASE_SIZE, 4, BASE_SIZE))
	if team == 1:
		zone.position = Vector3(VoxelWorld.SX - BASE_MIN - BASE_SIZE, GROUND, VoxelWorld.SZ - BASE_MIN - BASE_SIZE)
	return zone


static func spawn_point(team: int, slot := 0) -> Vector3:
	var p := Vector3(BASE_MIN + 3.5 + float(slot % 2) * 1.2, GROUND, BASE_MIN + 3.5 + float((slot / 2) % 2) * 1.2)
	return p if team == 0 else rot_point(p)


static func spawn_yaw(team: int) -> float:
	## Facing out of the base's open side (toward its approach point).
	return -0.5 * PI if team == 0 else 0.5 * PI


static func approach_point(team: int) -> Vector3:
	## A spot on open ground in front of the base's open side; bots walk here first.
	var p := Vector3(BASE_MIN + BASE_SIZE + 4.5, GROUND, BASE_MIN + BASE_SIZE * 0.5)
	return p if team == 0 else rot_point(p)


# ---------------------------------------------------------------- generation

const CHEESE_PER_GOAL := 2.5       # a race map always holds at least this many cheese per point of goal


static func min_cheese(goal: int) -> int:
	return ceili(float(goal) * CHEESE_PER_GOAL)


static func generate(world: VoxelWorld, map_seed: int, cheese_at_least := 0) -> void:
	var key := "%d:%d" % [map_seed, cheese_at_least]
	if _cache.has(key):
		var hit: Array = _cache[key]
		world.data = (hit[0] as PackedByteArray).duplicate()
		world.points_of_interest.assign(hit[1])
		world.micro.clear()
		world.gates.clear()
		world.reindex()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	world.data.fill(Blocks.AIR)
	world.micro.clear()
	world.gates.clear()
	world.points_of_interest.clear()
	var heights := _terrain(world, map_seed)
	_landmarks(world, rng, heights)
	_resources(world, rng, heights)
	_surface(world, rng, heights)
	_base(world)
	_more_cheese(world, rng, heights, (cheese_at_least + 1) / 2)
	_rotate_copy(world)
	world.reindex()
	if _cache.size() >= 3:
		_cache.clear()
	_cache[key] = [world.data.duplicate(), world.points_of_interest.duplicate()]


static func _more_cheese(world: VoxelWorld, rng: RandomNumberGenerator, heights: PackedInt32Array, half_target: int) -> void:
	## Big goals need more cheese: add it underground, a sector at a time, so
	## it stays spread over the whole map (the other half gets the same).
	var have := 0
	var i := world.data.find(Blocks.CHEESE)
	while i >= 0:
		if i % VoxelWorld.SX < HALF:
			have += 1
		i = world.data.find(Blocks.CHEESE, i + 1)
	var cols := HALF / SECTOR
	var rows := VoxelWorld.SZ / SECTOR
	var k := 0
	var guard := 0
	while have < half_target and guard < half_target * 40 + 400:
		guard += 1
		var sx := k % cols
		var sz := (k / cols) % rows
		k += 1
		var p := _sector_spot(rng, sx, sz, 1)
		if _near_base(p.x, p.y, 16.0):
			continue
		var y := rng.randi_range(3, maxi(4, surface(heights, p.x, p.y) - 3))
		var cur := world.get_block(p.x, y, p.y)
		if cur == Blocks.STONE or cur == Blocks.DIRT:
			world.set_raw(p.x, y, p.y, Blocks.CHEESE)
			have += 1


static func prepare_imported(world: VoxelWorld, map_seed: int, cheese_at_least: int) -> void:
	## A map loaded from a file, made ready for a Cheese Race: both base
	## platforms are stamped back in, and cheese is topped up in matching
	## pairs (a cell and its turned-around twin) until there is enough.
	_base(world)
	var b1 := base_zone(1)
	for x in range(BASE_MIN, BASE_MIN + BASE_SIZE):
		for z in range(BASE_MIN, BASE_MIN + BASE_SIZE):
			for y in range(GROUND - 4, GROUND + 6):
				world.set_raw(VoxelWorld.SX - 1 - x, y, VoxelWorld.SZ - 1 - z, Blocks.rotate180(world.get_block(x, y, z)))
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	world.reindex()
	var have := world.cheese_cells.size()
	var guard := 0
	while have < cheese_at_least and guard < cheese_at_least * 60 + 600:
		guard += 1
		var c := Vector3i(rng.randi_range(2, VoxelWorld.SX - 3), rng.randi_range(3, GROUND - 3), rng.randi_range(2, VoxelWorld.SZ - 3))
		var t := rot_cell(c)
		if _near_base(c.x, c.z, 16.0) or _near_base(t.x, t.z, 16.0) or c == t:
			continue
		var a := world.get_cell(c)
		var b := world.get_cell(t)
		if (a == Blocks.STONE or a == Blocks.DIRT) and (b == Blocks.STONE or b == Blocks.DIRT) and not world.has_micro(c) and not world.has_micro(t):
			world.set_raw(c.x, c.y, c.z, Blocks.CHEESE)
			world.set_raw(t.x, t.y, t.z, Blocks.CHEESE)
			have += 2
	world.reindex()


static func _noise(seed_value: int, freq: float, fractal := FastNoiseLite.FRACTAL_FBM, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	return n


static func height_at(cont: FastNoiseLite, ridge: FastNoiseLite, hills: FastNoiseLite, x: float, z: float) -> float:
	## Raw terrain height before symmetry and base levelling.
	var c := cont.get_noise_2d(x, z)                       # -1..1: valley < plains < mountains
	var mountains := smoothstep(0.06, 0.42, c)
	var valleys := smoothstep(-0.2, -0.55, c)
	var peaks := 1.0 - absf(ridge.get_noise_2d(x, z))      # sharp ridgelines
	var h := float(GROUND) + hills.get_noise_2d(x, z) * 3.0
	h += mountains * (5.0 + peaks * peaks * 19.0)
	h -= valleys * (6.0 + 5.0 * (hills.get_noise_2d(z * 0.7, x * 0.7) * 0.5 + 0.5))
	return h


static func _terrain(world: VoxelWorld, map_seed: int) -> PackedInt32Array:
	var cont := _noise(map_seed + 11, 0.0135, FastNoiseLite.FRACTAL_FBM, 2)
	var ridge := _noise(map_seed + 23, 0.022, FastNoiseLite.FRACTAL_RIDGED, 3)
	var hills := _noise(map_seed + 37, 0.045, FastNoiseLite.FRACTAL_FBM, 2)
	var caves := _noise(map_seed + 101, 0.07, FastNoiseLite.FRACTAL_NONE, 1)
	var veins := _noise(map_seed + 202, 0.11, FastNoiseLite.FRACTAL_NONE, 1)
	var magma := _noise(map_seed + 303, 0.05, FastNoiseLite.FRACTAL_NONE, 1)
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	var heights := PackedInt32Array()
	heights.resize(HALF * sz)
	var base := base_center(0)
	var d := world.data
	for x in HALF:
		# near the middle line, blend with the turned-around side so the two
		# halves meet without a cliff
		var w := 0.5 * maxf(0.0, 1.0 - absf(float(x) + 0.5 - float(HALF)) / 10.0)
		for z in sz:
			var h := height_at(cont, ridge, hills, x, z)
			if w > 0.0:
				h = lerpf(h, height_at(cont, ridge, hills, sx - 1 - x, sz - 1 - z), w)
			var dist := Vector2(x + 0.5 - base.x, z + 0.5 - base.z).length()
			h = lerpf(h, float(GROUND), smoothstep(FLAT_RADIUS, FLAT_RADIUS * 0.7, dist))
			var top := clampi(roundi(h), 10, VoxelWorld.SY - 6)
			heights[x * sz + z] = top
			var m := magma.get_noise_2d(x, z)
			var deep := dist > 26.0
			var rocky := top >= GROUND + 9
			var under_water := top < WATER_LEVEL
			for y in top:
				var id := Blocks.STONE
				if y == 0:
					id = Blocks.BEDROCK
				elif y == top - 1:
					if under_water:
						id = Blocks.DIRT
					elif top >= GROUND + 19:
						id = Blocks.ICE           # icy peaks
					elif rocky:
						id = Blocks.STONE
					else:
						id = Blocks.GRASS
				elif y >= top - (2 if rocky else 5):
					id = Blocks.DIRT
				elif veins.get_noise_3d(x, y, z) > 0.32:
					id = Blocks.DIRT
				if y >= 1 and y <= 4 and deep:
					if m > 0.3:
						id = Blocks.LAVA if y <= 2 else Blocks.AIR
					elif m > 0.18 and y <= 3:
						id = Blocks.OBSIDIAN
				elif y >= 6 and y < top - 6 and deep and caves.get_noise_3d(x, y * 1.4, z) > 0.42:
					id = Blocks.AIR
				d[x + sx * (z + sz * y)] = id
			for y in range(top, WATER_LEVEL):
				d[x + sx * (z + sz * y)] = Blocks.WATER
	world.data = d
	return heights


static func surface(heights: PackedInt32Array, x: int, z: int) -> int:
	return heights[x * VoxelWorld.SZ + z]


static func _sector_spot(rng: RandomNumberGenerator, sx: int, sz: int, margin := 2) -> Vector2i:
	return Vector2i(sx * SECTOR + rng.randi_range(margin, SECTOR - 1 - margin), sz * SECTOR + rng.randi_range(margin, SECTOR - 1 - margin))


static func _near_base(x: int, z: int, r: float) -> bool:
	var b := base_center(0)
	return Vector2(x + 0.5 - b.x, z + 0.5 - b.z).length() < r


static func _landmarks(world: VoxelWorld, rng: RandomNumberGenerator, heights: PackedInt32Array) -> void:
	# --- the sewer: brick tunnels from just outside the base to the centre ---
	var sy0 := GROUND - 15
	var leg_x := BASE_MIN + BASE_SIZE + 2
	for z in range(leg_x - 2, MID_Z + 3):       # leg 1: out of the base corner along z
		_sewer_slice(world, leg_x, sy0, z, true)
	for x in range(leg_x - 2, HALF):            # leg 2: along x to the chapel
		_sewer_slice(world, x, sy0, MID_Z, false)
	for y in range(sy0 + 2, surface(heights, leg_x, leg_x - 1)):   # manhole with a ladder
		world.set_raw(leg_x, y, leg_x - 1, Blocks.LADDER)
	# --- mushroom chapel at the centre (turns into one symmetric hall) ---
	var cy := GROUND - 15
	for x in range(HALF - 11, HALF):
		for z in range(MID_Z - 6, MID_Z + 6):
			for y in range(cy, cy + 9):
				var wall := x == HALF - 11 or z == MID_Z - 6 or z == MID_Z + 5
				var id := Blocks.AIR
				if y == cy:
					id = Blocks.BRICK
				elif y == cy + 8:
					id = Blocks.SHROOM_CAP
				elif wall:
					id = Blocks.BRICK
				world.set_raw(x, y, z, id)
	for z in range(MID_Z - 2, MID_Z + 2):
		for y in range(cy + 1, cy + 4):
			world.set_raw(HALF - 11, y, z, Blocks.AIR)   # doorway from the sewer
	for zz: int in [MID_Z - 4, MID_Z + 3]:
		for y in range(cy + 1, cy + 8):
			world.set_raw(HALF - 8, y, zz, Blocks.SHROOM_STEM)
	for zz: int in [MID_Z - 3, MID_Z - 1, MID_Z + 2]:
		world.set_raw(HALF - 1, cy + 1, zz, Blocks.GLOW)
		world.set_raw(HALF - 1, cy + 2, zz, Blocks.CHEESE)
	world.points_of_interest.append(Vector3(HALF, cy + 3, MID_Z))
	# --- molten basins: deep, far from the base; they sit still until opened ---
	var placed := 0
	var tries := 0
	while placed < 4 and tries < 60:
		tries += 1
		var lc := Vector3i(rng.randi_range(8, HALF - 8), rng.randi_range(7, 14), rng.randi_range(8, VoxelWorld.SZ - 9))
		if _near_base(lc.x, lc.z, 34.0) or absi(lc.z - MID_Z) < 6:
			continue
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				for dy in range(-2, 3):
					if float(dx * dx) / 10.0 + float(dz * dz) / 10.0 + float(dy * dy) / 4.5 > 1.0 or lc.y + dy < 2:
						continue
					world.set_raw(lc.x + dx, lc.y + dy, lc.z + dz, Blocks.LAVA if dy < 0 else Blocks.AIR)
		world.points_of_interest.append(Vector3(lc) + Vector3(0.5, 0.5, 0.5))
		placed += 1
	# --- ruins (one is a scrap laboratory) ---
	placed = 0
	tries = 0
	while placed < 6 and tries < 80:
		tries += 1
		var rx := rng.randi_range(6, HALF - 6)
		var rz := rng.randi_range(6, VoxelWorld.SZ - 7)
		if _near_base(rx, rz, 24.0) or absi(rz - MID_Z) < 8:
			continue
		var top := surface(heights, rx, rz)
		var rc := Vector3i(rx, rng.randi_range(8, maxi(9, mini(top - 8, GROUND - 6))), rz)
		_ruin(world, rng, rc, placed == 2)
		world.points_of_interest.append(Vector3(rc) + Vector3(0.5, 1.5, 0.5))
		placed += 1


static func _sewer_slice(world: VoxelWorld, x: int, y0: int, z: int, along_z: bool) -> void:
	## One cross-section of a 6-wide brick tunnel with a water channel down the middle.
	for k in range(-3, 3):
		for y in range(y0, y0 + 5):
			var edge := k == -3 or k == 2 or y == y0 or y == y0 + 4
			var cx := x + (k if along_z else 0)
			var cz := z + (0 if along_z else k)
			if cx >= HALF:
				continue
			var cur := world.get_block(cx, y, cz)
			if cur == Blocks.AIR and edge:
				continue    # never brick up a tunnel that crosses this one
			world.set_raw(cx, y, cz, Blocks.BRICK if edge else Blocks.AIR)
	var wx := x
	var wz := z
	if wx < HALF:
		world.set_raw(wx, y0 + 1, wz, Blocks.WATER)
		if along_z:
			world.set_raw(wx - 1, y0 + 1, wz, Blocks.BRICK)
			world.set_raw(wx + 1, y0 + 1, wz, Blocks.BRICK)
		else:
			world.set_raw(wx, y0 + 1, wz - 1, Blocks.BRICK)
			world.set_raw(wx, y0 + 1, wz + 1, Blocks.BRICK)


static func _resources(world: VoxelWorld, rng: RandomNumberGenerator, heights: PackedInt32Array) -> void:
	var cols := HALF / SECTOR
	var rows := VoxelWorld.SZ / SECTOR
	# --- scrap: every sector gets its share, at a random spot and depth ---
	for sx in cols:
		for sz in rows:
			var blobs := 1 if _near_base(sx * SECTOR + 8, sz * SECTOR + 8, 20.0) else 2
			for i in blobs:
				var p := _sector_spot(rng, sx, sz)
				var top := surface(heights, p.x, p.y)
				var y := rng.randi_range(4, maxi(5, top - 3))
				_blob(world, Vector3i(p.x, y, p.y), rng.randi_range(2, 3), Blocks.SCRAP)
	# a few starter veins just outside the base
	for i in 3:
		var a := rng.randf_range(0.0, PI * 0.5)
		var r := rng.randf_range(12.0, 18.0)
		var b := base_center(0)
		_blob(world, Vector3i(int(b.x + cos(a) * r), GROUND - rng.randi_range(3, 7), int(b.z + sin(a) * r)), 2, Blocks.SCRAP)
	# --- loose cheese, one per sector away from the base ---
	for sx in cols:
		for sz in rows:
			var p := _sector_spot(rng, sx, sz, 3)
			if _near_base(p.x, p.y, 22.0):
				continue
			var top := surface(heights, p.x, p.y)
			var y := rng.randi_range(5, maxi(6, top - 4))
			world.set_raw(p.x, y, p.y, Blocks.CHEESE)
	# --- obsidian vaults: cheese sealed in obsidian ---
	var placed := 0
	var tries := 0
	while placed < 3 and tries < 60:
		tries += 1
		var c := Vector3i(rng.randi_range(6, HALF - 6), rng.randi_range(6, 14), rng.randi_range(6, VoxelWorld.SZ - 7))
		if _near_base(c.x, c.z, 34.0) or absi(c.z - MID_Z) < 7:
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					world.set_raw(c.x + dx, c.y + dy, c.z + dz, Blocks.OBSIDIAN)
		world.set_raw(c.x, c.y, c.z, Blocks.CHEESE)
		world.points_of_interest.append(Vector3(c) + Vector3(0.5, 0.5, 0.5))
		placed += 1
	# --- obsidian dikes: dark ribs that force a detour, a long dig, or explosives ---
	for i in 5:
		var oc := Vector3i(rng.randi_range(8, HALF - 6), rng.randi_range(5, 14), rng.randi_range(6, VoxelWorld.SZ - 7))
		if _near_base(oc.x, oc.z, 24.0):
			continue
		for dy in rng.randi_range(3, 5):
			_blob(world, oc + Vector3i(0, dy, 0), 2, Blocks.OBSIDIAN)


static func _surface(world: VoxelWorld, rng: RandomNumberGenerator, heights: PackedInt32Array) -> void:
	# houses on the plains near home
	var houses := 0
	var tries := 0
	while houses < 2 and tries < 40:
		tries += 1
		var hx := rng.randi_range(14, 40)
		var hz := rng.randi_range(14, 52)
		if _near_base(hx, hz, 16.0) or absi(surface(heights, hx, hz) - GROUND) > 2:
			continue
		_house(world, hx, hz)
		houses += 1
	# trees and mushrooms across the plains, by sector so every area gets some
	for sx in HALF / SECTOR:
		for sz in VoxelWorld.SZ / SECTOR:
			for i in 2:
				var p := _sector_spot(rng, sx, sz, 1)
				if _near_base(p.x, p.y, 15.0):
					continue
				if rng.randf() < 0.3:
					_mushroom(world, rng, p.x, p.y)
				else:
					_tree(world, rng, p.x, p.y)
	# stone boulders: early stone without digging deep
	for i in 10:
		var bx := rng.randi_range(4, HALF - 4)
		var bz := rng.randi_range(4, VoxelWorld.SZ - 5)
		if _near_base(bx, bz, 14.0):
			continue
		var by := world.surface_y(bx, bz)
		if world.get_block(bx, by - 1, bz) != Blocks.GRASS:
			continue
		for dx in range(-1, 2):
			for dy in range(0, 2):
				for dz in range(-1, 2):
					if absi(dx) + dy + absi(dz) <= 2 and world.get_block(bx + dx, by + dy, bz + dz) == Blocks.AIR:
						world.set_raw(bx + dx, by + dy, bz + dz, Blocks.STONE)
	# a pond near home
	for i in 20:
		var px := rng.randi_range(18, 34)
		var pz := rng.randi_range(18, 34)
		if _near_base(px, pz, 14.0) or world.get_block(px, world.surface_y(px, pz) - 1, pz) != Blocks.GRASS:
			continue
		var py := world.surface_y(px, pz) - 1
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if absi(dx) + absi(dz) > 3:
					continue
				for y in range(py - 1, py + 4):
					world.set_raw(px + dx, y, pz + dz, Blocks.WATER if y <= py else Blocks.AIR)
				world.set_raw(px + dx, py - 2, pz + dz, Blocks.DIRT)
		break
	# a visible "this is cheese" teaser on a plinth just outside the base
	var t := approach_point(0) + Vector3(3, 0, -2)
	var ty := world.surface_y(int(t.x), int(t.z))
	world.set_raw(int(t.x), ty, int(t.z), Blocks.BRICK)
	world.set_raw(int(t.x), ty + 1, int(t.z), Blocks.CHEESE)


static func _base(world: VoxelWorld) -> void:
	var a := BASE_MIN
	var b := BASE_MIN + BASE_SIZE - 1
	for x in range(a, b + 1):
		for z in range(a, b + 1):
			for y in range(GROUND - 4, GROUND - 1):
				if world.get_block(x, y, z) == Blocks.AIR or world.get_block(x, y, z) == Blocks.WATER:
					world.set_raw(x, y, z, Blocks.DIRT)    # solid ground under the platform
			world.set_raw(x, GROUND - 1, z, Blocks.BASE_BLUE)
			for y in range(GROUND, GROUND + 6):
				world.set_raw(x, y, z, Blocks.AIR)
			if x == a or x == b or z == a or z == b:
				world.set_raw(x, GROUND + 4, z, Blocks.BASE_BLUE)
	for cx: int in [a, b]:
		for cz: int in [a, b]:
			for y in range(GROUND, GROUND + 4):
				world.set_raw(cx, y, cz, Blocks.BASE_BLUE)


static func _rotate_copy(world: VoxelWorld) -> void:
	## Replace the x >= HALF half with team 0's half turned 180 degrees, then
	## give the copied team-coloured and directional blocks to the other side.
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	var src := world.data
	var out := PackedByteArray()
	out.resize(src.size())
	for y in VoxelWorld.SY:
		for z in sz:
			var row := y * sx * sz + z * sx
			var turned := y * sx * sz + (sz - 1 - z) * sx
			for x in HALF:
				var id := src[row + x]
				out[row + x] = id
				out[turned + sx - 1 - x] = Blocks.rotate180(id)
	world.data = out
	var n := world.points_of_interest.size()
	for i in n:
		world.points_of_interest.append(rot_point(world.points_of_interest[i]))


static func _blob(world: VoxelWorld, c: Vector3i, size: int, id: int) -> void:
	for dx in size:
		for dy in size:
			for dz in size:
				var x := c.x + dx
				var y := c.y + dy
				var z := c.z + dz
				if x >= HALF or y < 1:
					continue
				var cur := world.get_block(x, y, z)
				if cur == Blocks.STONE or cur == Blocks.DIRT:
					world.set_raw(x, y, z, id)


static func _ruin(world: VoxelWorld, rng: RandomNumberGenerator, c: Vector3i, lab: bool) -> void:
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for dy in 5:
				var x := c.x + dx
				var y := c.y + dy
				var z := c.z + dz
				if x >= HALF:
					continue
				var shell := absi(dx) == 2 or absi(dz) == 2 or dy == 0 or dy == 4
				var id := Blocks.AIR
				if shell:
					id = Blocks.BRICK
					if lab:
						id = Blocks.SCRAP if (dx + dz + dy) % 3 == 0 else Blocks.WOOD
					if dy > 0 and rng.randf() < 0.14:
						id = Blocks.AIR if dy < 4 else Blocks.DIRT
				world.set_raw(x, y, z, id)
	var spots := [Vector3i(-1, 1, -1), Vector3i(1, 1, 1), Vector3i(1, 1, -1), Vector3i(-1, 1, 1)]
	var count := 2 if lab else rng.randi_range(2, 3)
	for i in count:
		var s: Vector3i = spots[i]
		world.set_raw(c.x + s.x, c.y + s.y, c.z + s.z, Blocks.CHEESE)
	world.set_raw(c.x, c.y + 1, c.z, Blocks.TNT if lab else Blocks.GLOW)
	if lab:
		world.set_raw(c.x - 1, c.y, c.z, Blocks.CONV_XP)
		world.set_raw(c.x + 1, c.y, c.z, Blocks.CONV_XN)


static func _house(world: VoxelWorld, cx: int, cz: int) -> void:
	var gy := world.surface_y(cx, cz)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for y in range(gy - 3, gy):
				if world.get_block(cx + dx, y, cz + dz) == Blocks.AIR:
					world.set_raw(cx + dx, y, cz + dz, Blocks.DIRT)
			world.set_raw(cx + dx, gy - 1, cz + dz, Blocks.WOOD)
			for dy in 5:
				var wall := absi(dx) == 2 or absi(dz) == 2
				var id := Blocks.AIR
				if dy == 3:
					id = Blocks.WOOD
				elif dy == 4:
					id = Blocks.SHROOM_CAP if (absi(dx) < 2 and absi(dz) < 2) else Blocks.AIR
				elif wall:
					id = Blocks.WOOD
				world.set_raw(cx + dx, gy + dy, cz + dz, id)
	world.set_raw(cx + 2, gy, cz, Blocks.AIR)       # door
	world.set_raw(cx + 2, gy + 1, cz, Blocks.AIR)
	world.set_raw(cx - 2, gy + 1, cz, Blocks.ICE)   # window
	world.set_raw(cx - 1, gy, cz - 1, Blocks.SCRAP) # a little starter scrap


static func _tree(world: VoxelWorld, rng: RandomNumberGenerator, x: int, z: int) -> void:
	var gy := world.surface_y(x, z)
	if world.get_block(x, gy - 1, z) != Blocks.GRASS or x + 1 >= HALF:
		return
	var h := rng.randi_range(3, 5)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in 2:
				world.set_raw(x + dx, gy + h - 1 + dy, z + dz, Blocks.LEAVES)
	world.set_raw(x, gy + h + 1, z, Blocks.LEAVES)
	for y in h:
		world.set_raw(x, gy + y, z, Blocks.WOOD)


static func _mushroom(world: VoxelWorld, rng: RandomNumberGenerator, x: int, z: int) -> void:
	var gy := world.surface_y(x, z)
	if world.get_block(x, gy - 1, z) != Blocks.GRASS or x + 1 >= HALF:
		return
	var h := rng.randi_range(2, 4)
	for y in h:
		world.set_raw(x, gy + y, z, Blocks.SHROOM_STEM)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			world.set_raw(x + dx, gy + h, z + dz, Blocks.SHROOM_CAP)
	world.set_raw(x, gy + h + 1, z, Blocks.SHROOM_CAP)
