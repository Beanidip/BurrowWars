class_name ChunkMesher
## Builds one mesh per 16^3 chunk: hidden faces culled, vertex-coloured,
## unshaded. Gadget blocks (ladders, traps, springs...) are drawn as small
## boxes so they read at a glance without any textures.

const SHADE := [0.84, 0.84, 1.0, 0.55, 0.70, 0.70]  # +X -X +Y -Y +Z -Z
const NX := [1, -1, 0, 0, 0, 0]
const NY := [0, 0, 1, -1, 0, 0]
const NZ := [0, 0, 0, 0, 1, -1]


static func build(world: VoxelWorld, k: Vector3i, mat_opaque: Material, mat_trans: Material) -> ArrayMesh:
	var ov := PackedVector3Array()
	var oc := PackedColorArray()
	var tv := PackedVector3Array()
	var tc := PackedColorArray()
	var d := world.data
	var sx := VoxelWorld.SX
	var sy := VoxelWorld.SY
	var sz := VoxelWorld.SZ
	var x0 := k.x * VoxelWorld.CHUNK
	var y0 := k.y * VoxelWorld.CHUNK
	var z0 := k.z * VoxelWorld.CHUNK
	var opaque := Blocks.OPAQUE
	var mf := world.micro_flag
	for y in range(y0, y0 + VoxelWorld.CHUNK):
		var depth := clampf(0.58 + 0.42 * float(y) / 28.0, 0.58, 1.0)
		for z in range(z0, z0 + VoxelWorld.CHUNK):
			for x in range(x0, x0 + VoxelWorld.CHUNK):
				var id := d[x + sx * (z + sz * y)]
				if id == Blocks.AIR:
					continue
				var mn := Vector3(x, y, z)
				var col: Color = Blocks.COLOR[id]
				var tint: float = 0.93 + 0.14 * float((x * 73856093 ^ y * 19349663 ^ z * 83492791) & 255) / 255.0
				if opaque[id] == 1 and mf[x + sx * (z + sz * y)] == 1:
					_micro_block(world, ov, oc, Vector3i(x, y, z), id, tint * depth)
					continue
				if opaque[id] == 1:
					var glow := id == Blocks.CHEESE or id == Blocks.GLOW or id == Blocks.BASE_BLUE or id == Blocks.BASE_RED or Blocks.is_team_block(id) or Blocks.is_paint(id)
					var base := col * (tint if glow else tint * depth)
					for f in 6:
						var ax: int = x + NX[f]
						var ay: int = y + NY[f]
						var az: int = z + NZ[f]
						var nid := Blocks.AIR
						if ay < 0:
							continue
						if ax >= 0 and az >= 0 and ax < sx and az < sz and ay < sy:
							nid = d[ax + sx * (az + sz * ay)]
						elif ay < sy:
							continue  # world edge walls are never visible
						if opaque[nid] == 1 and mf[ax + sx * (az + sz * ay)] == 0:
							continue
						var c := base
						if id == Blocks.GRASS and f != 2:
							c = Blocks.COLOR[Blocks.DIRT] * tint * depth
						if id == Blocks.STONE or id == Blocks.OBSIDIAN or id == Blocks.BRICK:
							_rocky_face(ov, oc, mn, f, _shade(c, SHADE[f]), id, x * 7 + y * 13 + z * 29 + f)
						else:
							_face(ov, oc, mn, mn + Vector3.ONE, f, _shade(c, SHADE[f]))
					if id == Blocks.WALL_SPRING:
						for wf in [0, 1, 4, 5]:
							var o: Vector3 = Vector3(NX[wf], 0, NZ[wf]) * 0.045
							_box(ov, oc, mn + Vector3(0.2, 0.2, 0.2) + o * 6.0, mn + Vector3(0.8, 0.8, 0.8) + o * 6.0, Color(0.8, 0.8, 0.85))
					if Blocks.is_conveyor(id):
						_conveyor_arrow(ov, oc, mn, Blocks.conveyor_dir(id))
					elif id == Blocks.TNT:
						_box(ov, oc, mn + Vector3(0.42, 1.0, 0.42), mn + Vector3(0.58, 1.22, 0.58), Color(0.95, 0.9, 0.7))
						_box(ov, oc, mn + Vector3(-0.01, 0.4, -0.01), mn + Vector3(1.01, 0.6, 1.01), Color(0.95, 0.9, 0.8))
					continue
				match id:
					Blocks.WATER, Blocks.LAVA:
						var is_lava := id == Blocks.LAVA
						var top := 0.88
						if y + 1 < sy and d[x + sx * (z + sz * (y + 1))] == id:
							top = 1.0
						for f in 6:
							var ax2: int = x + NX[f]
							var ay2: int = y + NY[f]
							var az2: int = z + NZ[f]
							if ax2 < 0 or ay2 < 0 or az2 < 0 or ax2 >= sx or ay2 >= sy or az2 >= sz:
								continue
							var nid2 := d[ax2 + sx * (az2 + sz * ay2)]
							if nid2 == id or opaque[nid2] == 1:
								continue
							if is_lava:
								_face(ov, oc, mn, mn + Vector3(1, top, 1), f, _shade(col * tint, 0.8 + 0.2 * SHADE[f]))
							else:
								_face(tv, tc, mn, mn + Vector3(1, top, 1), f, _shade(col, SHADE[f]))
					Blocks.GATE_BLUE, Blocks.GATE_RED:
						_box(tv, tc, mn + Vector3(0.01, 0.01, 0.01), mn + Vector3(0.99, 0.99, 0.99), col)
					Blocks.LADDER:
						var wood := col * depth
						_box(ov, oc, mn + Vector3(0.12, 0, 0.44), mn + Vector3(0.22, 1, 0.56), wood)
						_box(ov, oc, mn + Vector3(0.78, 0, 0.44), mn + Vector3(0.88, 1, 0.56), wood)
						_box(ov, oc, mn + Vector3(0.44, 0, 0.12), mn + Vector3(0.56, 1, 0.22), wood)
						_box(ov, oc, mn + Vector3(0.44, 0, 0.78), mn + Vector3(0.56, 1, 0.88), wood)
						for r in 3:
							var ry := 0.18 + 0.32 * r
							_box(ov, oc, mn + Vector3(0.12, ry, 0.46), mn + Vector3(0.88, ry + 0.08, 0.54), wood * 1.15)
							_box(ov, oc, mn + Vector3(0.46, ry, 0.12), mn + Vector3(0.54, ry + 0.08, 0.88), wood * 1.15)
					Blocks.SPRING:
						_box(ov, oc, mn + Vector3(0.1, 0, 0.1), mn + Vector3(0.9, 0.2, 0.9), Color(0.35, 0.3, 0.28))
						_box(ov, oc, mn + Vector3(0.35, 0.2, 0.35), mn + Vector3(0.65, 0.78, 0.65), Color(0.75, 0.75, 0.8))
						_box(ov, oc, mn + Vector3(0.04, 0.78, 0.04), mn + Vector3(0.96, 1.0, 0.96), col)
					Blocks.HIGHWAY:
						# a plank road lying on the face of the block below
						_box(ov, oc, mn + Vector3(0.0, 0.0, 0.0), mn + Vector3(1.0, 0.06, 1.0), col * depth)
						for pl in 3:
							var px := 0.06 + 0.32 * pl
							_box(ov, oc, mn + Vector3(px, 0.06, 0.03), mn + Vector3(px + 0.24, 0.085, 0.97), col * depth * (1.12 if pl != 1 else 0.92))
					Blocks.STICKY_BLUE, Blocks.STICKY_RED:
						_box(ov, oc, mn + Vector3(0.05, 0, 0.05), mn + Vector3(0.95, 0.05, 0.95), Color(0.62, 0.72, 0.2))
						_box(ov, oc, mn + Vector3(0.25, 0.05, 0.3), mn + Vector3(0.6, 0.1, 0.7), Color(0.75, 0.85, 0.3))
						_box(ov, oc, mn + Vector3(0.42, 0.05, 0.42), mn + Vector3(0.58, 0.14, 0.58), col)
					Blocks.PIT_BLUE, Blocks.PIT_RED:
						# looks like turf from above; a small team pip warns its owners
						_box(ov, oc, mn + Vector3(0, 0.9, 0), mn + Vector3(1, 1, 1), Blocks.COLOR[Blocks.GRASS] * tint * 0.97)
						var pip: Color = Blocks.COLOR[Blocks.BASE_BLUE if id == Blocks.PIT_BLUE else Blocks.BASE_RED]
						_box(ov, oc, mn + Vector3(0.44, 1.0, 0.44), mn + Vector3(0.56, 1.02, 0.56), pip)
					Blocks.TRAP_BLUE, Blocks.TRAP_RED:
						_box(ov, oc, mn + Vector3(0.12, 0, 0.12), mn + Vector3(0.88, 0.08, 0.88), Color(0.78, 0.62, 0.38))
						_box(ov, oc, mn + Vector3(0.2, 0.08, 0.42), mn + Vector3(0.8, 0.16, 0.58), col)
						_box(ov, oc, mn + Vector3(0.42, 0.08, 0.6), mn + Vector3(0.58, 0.2, 0.76), Color(1.0, 0.85, 0.2))
	var mesh := ArrayMesh.new()
	_commit(mesh, ov, oc, mat_opaque)
	_commit(mesh, tv, tc, mat_trans)
	return mesh if mesh.get_surface_count() > 0 else null


static func _shade(c: Color, s: float) -> Color:
	return Color(c.r * s, c.g * s, c.b * s, c.a)


static func _commit(mesh: ArrayMesh, v: PackedVector3Array, c: PackedColorArray, mat: Material) -> void:
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func _box(v: PackedVector3Array, c: PackedColorArray, mn: Vector3, mx: Vector3, col: Color) -> void:
	for f in 6:
		_face(v, c, mn, mx, f, _shade(col, SHADE[f]))


static func _conveyor_arrow(v: PackedVector3Array, c: PackedColorArray, mn: Vector3, dir: Vector3) -> void:
	var yellow := Color(1.0, 0.82, 0.2)
	var ctr := mn + Vector3(0.5, 1.0, 0.5)
	var side := Vector3(dir.z, 0, dir.x).abs()
	var along := dir.abs()
	# shaft
	var h := along * 0.3 + side * 0.07
	_box(v, c, ctr - h, ctr + h + Vector3(0, 0.05, 0), yellow)
	# head, pushed toward the travel direction
	var hc := ctr + dir * 0.3
	var hh := along * 0.09 + side * 0.24
	_box(v, c, hc - hh, hc + hh + Vector3(0, 0.07, 0), yellow)


static func _face(v: PackedVector3Array, c: PackedColorArray, mn: Vector3, mx: Vector3, f: int, col: Color) -> void:
	var a: Vector3
	var b: Vector3
	var cc: Vector3
	var dd: Vector3
	match f:
		0:
			a = Vector3(mx.x, mn.y, mn.z); b = Vector3(mx.x, mx.y, mn.z); cc = Vector3(mx.x, mx.y, mx.z); dd = Vector3(mx.x, mn.y, mx.z)
		1:
			a = Vector3(mn.x, mn.y, mx.z); b = Vector3(mn.x, mx.y, mx.z); cc = Vector3(mn.x, mx.y, mn.z); dd = Vector3(mn.x, mn.y, mn.z)
		2:
			a = Vector3(mn.x, mx.y, mn.z); b = Vector3(mn.x, mx.y, mx.z); cc = Vector3(mx.x, mx.y, mx.z); dd = Vector3(mx.x, mx.y, mn.z)
		3:
			a = Vector3(mn.x, mn.y, mx.z); b = Vector3(mn.x, mn.y, mn.z); cc = Vector3(mx.x, mn.y, mn.z); dd = Vector3(mx.x, mn.y, mx.z)
		4:
			a = Vector3(mx.x, mn.y, mx.z); b = Vector3(mx.x, mx.y, mx.z); cc = Vector3(mn.x, mx.y, mx.z); dd = Vector3(mn.x, mn.y, mx.z)
		_:
			a = Vector3(mn.x, mn.y, mn.z); b = Vector3(mn.x, mx.y, mn.z); cc = Vector3(mx.x, mx.y, mn.z); dd = Vector3(mx.x, mn.y, mn.z)
	# Godot front faces wind clockwise.
	v.append(a); v.append(cc); v.append(b)
	v.append(a); v.append(dd); v.append(cc)
	for i in 6:
		c.append(col)


static func _rocky_face(v: PackedVector3Array, c: PackedColorArray, mn: Vector3, f: int, col: Color, id: int, seed_i: int) -> void:
	## Stone, brick and obsidian get a chunky 2x2 mottled face so they read as
	## rock; obsidian picks up the occasional purple glint.
	var u := Vector3(0, 0, 0.5) if f < 2 else Vector3(0.5, 0, 0)
	var w := Vector3(0, 0.5, 0) if f != 2 and f != 3 else Vector3(0, 0, 0.5)
	var flat := Vector3(NX[f], NY[f], NZ[f]).abs()
	for i in 4:
		var h := float(((seed_i + i * 37) * 2654435761) >> 8 & 255) / 255.0
		var k := 0.86 + 0.26 * h
		var tile := Color(col.r * k, col.g * k, col.b * k)
		if id == Blocks.OBSIDIAN and h > 0.72:
			tile = Color(col.r * 1.9 + 0.08, col.g * 1.1, col.b * 2.1 + 0.1)
		var a := mn + u * float(i % 2) + w * float(i / 2)
		_face(v, c, a, a + u + w + flat, f, tile)


static func _micro_block(world: VoxelWorld, v: PackedVector3Array, c: PackedColorArray, cell: Vector3i, id: int, shade: float) -> void:
	## A carved block: one small quad per exposed microvoxel face. Interior
	## faces are culled; faces against an uncarved opaque neighbour are too.
	var mask: PackedByteArray = world.micro[cell]
	var m := Blocks.MICRO
	var s := 1.0 / float(m)
	var base := Vector3(cell)
	var col: Color = Blocks.COLOR[id] * shade
	var side: Color = (Blocks.COLOR[Blocks.DIRT] * shade) if id == Blocks.GRASS else col
	var open_side := PackedByteArray()
	for f in 6:
		var n := cell + Vector3i(NX[f], NY[f], NZ[f])
		var nid := world.get_cell(n)
		open_side.append(0 if (Blocks.OPAQUE[nid] == 1 and not world.has_micro(n) and VoxelWorld.in_bounds(n)) else 1)
	for my in m:
		for mz in m:
			for mx in m:
				var mv := mask[mx + m * (mz + m * my)]
				if mv == 0:
					continue
				var mn := base + Vector3(mx, my, mz) * s
				var k := 0.94 + 0.12 * float((mx * 7 + my * 3 + mz * 5) % 4) / 3.0
				for f in 6:
					var ax: int = mx + NX[f]
					var ay: int = my + NY[f]
					var az: int = mz + NZ[f]
					if ax < 0 or ay < 0 or az < 0 or ax >= m or ay >= m or az >= m:
						if open_side[f] == 0:
							continue
					elif mask[ax + m * (az + m * ay)] != 0:
						continue
					var fc := col if (f == 2 or id != Blocks.GRASS) else side
					if mv > 1:
						fc = Blocks.paint_color(mv - 2)
					_face(v, c, mn, mn + Vector3(s, s, s), f, _shade(fc, SHADE[f] * k))
