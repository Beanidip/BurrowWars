class_name MapGenerator
## Deterministic, seeded Cheese Race map. Only the blue (west) half is
## generated; the red half is an exact mirror, which guarantees fair resource
## distribution while each seed still explores differently.

const GROUND := 30
const HALF := VoxelWorld.SX / 2
const MID_Z := VoxelWorld.SZ / 2


static func base_zone(team: int) -> AABB:
	## Deposit / workshop / class-change volume above the base platform.
	var zone := AABB(Vector3(3, GROUND, 20), Vector3(7, 4, 8))
	if team == 1:
		zone.position.x = VoxelWorld.SX - zone.position.x - zone.size.x
	return zone


static func spawn_point(team: int, slot := 0) -> Vector3:
	var p := Vector3(6.5, GROUND, 22.5 + float(slot % 4) * 1.2)
	if team == 1:
		p.x = VoxelWorld.SX - p.x
	return p


static func approach_point(team: int) -> Vector3:
	## A spot on open ground in front of the base; bots walk here first.
	var p := Vector3(12.5, GROUND, 24.5)
	if team == 1:
		p.x = VoxelWorld.SX - p.x
	return p


static func generate(world: VoxelWorld, map_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var hills := FastNoiseLite.new()
	hills.seed = map_seed
	hills.frequency = 0.045
	var caves := FastNoiseLite.new()
	caves.seed = map_seed + 101
	caves.frequency = 0.075
	var veins := FastNoiseLite.new()
	veins.seed = map_seed + 202
	veins.frequency = 0.11
	var magma := FastNoiseLite.new()
	magma.seed = map_seed + 303
	magma.frequency = 0.06
	world.data.fill(Blocks.AIR)
	world.points_of_interest.clear()

	# --- terrain columns -------------------------------------------------
	for x in HALF:
		var blend := clampf(float(x - 14) / 8.0, 0.0, 1.0)
		for z in VoxelWorld.SZ:
			var h := GROUND + roundi(hills.get_noise_2d(x, z) * 4.0 * blend)
			var m := magma.get_noise_2d(x, z)
			for y in h:
				var id := Blocks.STONE
				if y == 0:
					id = Blocks.BEDROCK
				elif y == h - 1:
					id = Blocks.GRASS
				elif y >= h - 5:
					id = Blocks.DIRT
				elif veins.get_noise_3d(x, y, z) > 0.3:
					id = Blocks.DIRT
				if y >= 1 and y <= 4 and x > 12:
					if m > 0.28:
						id = Blocks.LAVA if y <= 2 else Blocks.AIR
					elif m > 0.16 and y <= 3:
						id = Blocks.OBSIDIAN
				elif y >= 5 and y < h - 6 and x > 12 and caves.get_noise_3d(x, y * 1.4, z) > 0.4:
					id = Blocks.AIR
				world.set_raw(x, y, z, id)

	# --- sewer: a brick tunnel from each side toward the centre ------------
	for x in range(14, HALF):
		for z in range(MID_Z - 3, MID_Z + 3):
			for y in range(18, 23):
				var edge := z == MID_Z - 3 or z == MID_Z + 2 or y == 18 or y == 22
				world.set_raw(x, y, z, Blocks.BRICK if edge else Blocks.AIR)
		world.set_raw(x, 18, MID_Z, Blocks.BRICK)
		world.set_raw(x, 19, MID_Z - 1, Blocks.BRICK)
		world.set_raw(x, 19, MID_Z + 1, Blocks.BRICK)
		world.set_raw(x, 19, MID_Z - 2, Blocks.BRICK)
		world.set_raw(x, 19, MID_Z, Blocks.WATER)
	# manhole with a ladder down into the sewer
	for y in range(20, world.surface_y(15, MID_Z - 1)):
		world.set_raw(15, y, MID_Z - 1, Blocks.LADDER)

	# --- mushroom chapel at the centre (mirrors into one symmetric hall) ---
	for x in range(41, HALF):
		for z in range(MID_Z - 6, MID_Z + 6):
			for y in range(18, 27):
				var wall := x == 41 or z == MID_Z - 6 or z == MID_Z + 5
				var id2 := Blocks.AIR
				if y == 18:
					id2 = Blocks.BRICK
				elif y == 26:
					id2 = Blocks.SHROOM_CAP
				elif wall:
					id2 = Blocks.BRICK
				world.set_raw(x, y, z, id2)
	for z in range(MID_Z - 2, MID_Z + 2):
		for y in range(19, 22):
			world.set_raw(41, y, z, Blocks.AIR)  # doorway from the sewer
	for zz: int in [MID_Z - 4, MID_Z + 3]:
		for y in range(19, 26):
			world.set_raw(44, y, zz, Blocks.SHROOM_STEM)
	for zz: int in [MID_Z - 3, MID_Z - 1, MID_Z + 2]:
		world.set_raw(HALF - 1, 19, zz, Blocks.GLOW)
		world.set_raw(HALF - 1, 20, zz, Blocks.CHEESE)
	world.points_of_interest.append(Vector3(HALF, 21, MID_Z))

	# --- resource deposits -------------------------------------------------
	for i in 8:
		var s := rng.randi_range(2, 4)
		var cx := rng.randi_range(10, 20) if i < 2 else rng.randi_range(14, 44)
		_blob(world, Vector3i(cx, rng.randi_range(5, 22), rng.randi_range(3, 44)), s, Blocks.SCRAP)
	for i in 2:
		var c := Vector3i(rng.randi_range(26, 43), rng.randi_range(6, 13), rng.randi_range(5, 42))
		if absi(c.z - MID_Z) < 9:
			c.z = 8 + i * 30
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					world.set_raw(c.x + dx, c.y + dy, c.z + dz, Blocks.OBSIDIAN)
		world.set_raw(c.x, c.y, c.z, Blocks.CHEESE)
		world.points_of_interest.append(Vector3(c) + Vector3(0.5, 0.5, 0.5))
	# obsidian dikes: tall dark ribs that force a detour, a long dig, or explosives
	for i in 3:
		var oc := Vector3i(rng.randi_range(16, 44), rng.randi_range(4, 11), rng.randi_range(3, 44))
		var tall := rng.randi_range(3, 5)
		for dy in tall:
			_blob(world, oc + Vector3i(0, dy, 0), 2, Blocks.OBSIDIAN)
	for i in 4:
		var lc := Vector3i(rng.randi_range(14, 45), rng.randi_range(5, 16), rng.randi_range(3, 44))
		if absi(lc.z - MID_Z) < 7:
			lc.z = (lc.z + 14) % VoxelWorld.SZ
		world.set_raw(lc.x, lc.y, lc.z, Blocks.CHEESE)

	# --- ruins and a scrap laboratory ---------------------------------------
	var slots := [18, 26, 34, 39]
	for i in slots.size():
		var rz := rng.randi_range(5, 14) if rng.randf() < 0.5 else rng.randi_range(33, 42)
		var rc := Vector3i(slots[i] + rng.randi_range(-1, 1), rng.randi_range(7, 15), rz)
		_ruin(world, rng, rc, i == 2)
		world.points_of_interest.append(Vector3(rc) + Vector3(0.5, 1.5, 0.5))

	# --- surface dressing ---------------------------------------------------
	var hz := 10 if rng.randf() < 0.5 else 36
	_house(world, 19, hz)
	for i in 7:
		var tx := rng.randi_range(13, 46)
		var tz := rng.randi_range(2, 45)
		if absi(tz - MID_Z) < 4 or (absi(tx - 19) < 4 and absi(tz - hz) < 4):
			continue
		if i % 3 == 2:
			_mushroom(world, rng, tx, tz)
		else:
			_tree(world, rng, tx, tz)
	# stone boulders scattered on the surface: early stone without digging deep
	for i in 3:
		var bx := rng.randi_range(14, 45)
		var bz := rng.randi_range(3, 44)
		if absi(bz - MID_Z) < 5 or (absi(bx - 19) < 5 and absi(bz - hz) < 5):
			continue
		var by := world.surface_y(bx, bz)
		if world.get_block(bx, by - 1, bz) != Blocks.GRASS:
			continue
		for dx in range(-1, 2):
			for dy in range(0, 2):
				for dz in range(-1, 2):
					if absi(dx) + dy + absi(dz) <= 2 and world.get_block(bx + dx, by + dy, bz + dz) == Blocks.AIR:
						world.set_raw(bx + dx, by + dy, bz + dz, Blocks.STONE)
	# pond
	var px := rng.randi_range(27, 38)
	var pz := 46 - hz
	var py := world.surface_y(px, pz) - 1
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if absi(dx) + absi(dz) > 3:
				continue
			for y in range(py - 1, py + 4):
				world.set_raw(px + dx, y, pz + dz, Blocks.WATER if y <= py else Blocks.AIR)
			world.set_raw(px + dx, py - 2, pz + dz, Blocks.DIRT)
	# a visible "this is cheese" teaser on a plinth between the bases
	var ty := world.surface_y(27, MID_Z + 2)
	world.set_raw(27, ty, MID_Z + 2, Blocks.BRICK)
	world.set_raw(27, ty + 1, MID_Z + 2, Blocks.CHEESE)

	# --- base ----------------------------------------------------------------
	for x in range(3, 10):
		for z in range(20, 28):
			world.set_raw(x, GROUND - 1, z, Blocks.BASE_BLUE)
			var rim := x == 3 or x == 9 or z == 20 or z == 27
			if rim:
				world.set_raw(x, GROUND + 4, z, Blocks.BASE_BLUE)
	for cx2: int in [3, 9]:
		for cz2: int in [20, 27]:
			for y in range(GROUND, GROUND + 4):
				world.set_raw(cx2, y, cz2, Blocks.BASE_BLUE)

	# --- mirror blue half onto red half ---------------------------------------
	for y in VoxelWorld.SY:
		for z in VoxelWorld.SZ:
			for x in HALF:
				world.set_raw(VoxelWorld.SX - 1 - x, y, z, Blocks.mirror(world.get_block(x, y, z)))
	var n := world.points_of_interest.size()
	for i in n:
		var p := world.points_of_interest[i]
		if p.x < HALF - 0.5:
			world.points_of_interest.append(Vector3(VoxelWorld.SX - p.x, p.y, p.z))
	world.reindex()


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
	if world.get_block(x, gy - 1, z) != Blocks.GRASS:
		return
	var h := rng.randi_range(3, 4)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in 2:
				world.set_raw(x + dx, gy + h - 1 + dy, z + dz, Blocks.LEAVES)
	world.set_raw(x, gy + h + 1, z, Blocks.LEAVES)
	for y in h:
		world.set_raw(x, gy + y, z, Blocks.WOOD)


static func _mushroom(world: VoxelWorld, rng: RandomNumberGenerator, x: int, z: int) -> void:
	var gy := world.surface_y(x, z)
	if world.get_block(x, gy - 1, z) != Blocks.GRASS:
		return
	var h := rng.randi_range(2, 4)
	for y in h:
		world.set_raw(x, gy + y, z, Blocks.SHROOM_STEM)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			world.set_raw(x + dx, gy + h, z + dz, Blocks.SHROOM_CAP)
	world.set_raw(x, gy + h + 1, z, Blocks.SHROOM_CAP)
