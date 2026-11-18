class_name ChunkMesher
## Builds one mesh per 16^3 chunk: hidden faces culled, vertex-coloured,
## unshaded. Gadget blocks (ladders, traps, springs...) are drawn as small
## boxes so they read at a glance without any textures.

const SHADE := [0.84, 0.84, 1.0, 0.55, 0.70, 0.70]  # +X -X +Y -Y +Z -Z
const NX := [1, -1, 0, 0, 0, 0]
const NY := [0, 0, 1, -1, 0, 0]
const NZ := [0, 0, 0, 0, 1, -1]


static func build(world: VoxelWorld, k: Vector3i, mat_opaque: Material, mat_trans: Material) -> ArrayMesh:
	return make_mesh(build_arrays(world, k), mat_opaque, mat_trans)


static func make_mesh(surfaces: Array, mat_opaque: Material, mat_trans: Material) -> ArrayMesh:
	## Main thread: the arrays from build_arrays into a mesh. Surface key -1 is
	## opaque, -2 see-through, anything else a textured block id.
	if surfaces.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for surf: Array in surfaces:
		var key: int = surf[3]
		var mat: Material = mat_opaque if key == -1 else (mat_trans if key == -2 else BlockTextures.material(key))
		_commit(mesh, surf[0], surf[1], mat, surf[2])
	return mesh


static func build_arrays(world: VoxelWorld, k: Vector3i) -> Array:
	## The geometry of one chunk as plain arrays: [vertices, colours, uvs, key]
	## per surface. Only reads the world, so it can run on a worker thread
	## (VoxelWorld.start_prebuild meshes a whole map on every core this way).
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
	var textured := BlockTextures.flags()
	var colors := Blocks.COLOR      # local copies: worker threads meshing side by side don't fight over the shared tables
	var tex: Dictionary = {}     # block id -> [vertices, colours, uvs] for textured faces
	var layered := not world.gates.is_empty()
	for y in range(y0, y0 + VoxelWorld.CHUNK):
		var depth := clampf(0.58 + 0.42 * float(y) / 28.0, 0.58, 1.0)
		for z in range(z0, z0 + VoxelWorld.CHUNK):
			for x in range(x0, x0 + VoxelWorld.CHUNK):
				var id := d[x + sx * (z + sz * y)]
				if id == Blocks.AIR:
					continue
				var mn := Vector3(x, y, z)
				var col: Color = colors[id]
				var tint: float = 0.93 + 0.14 * float((x * 73856093 ^ y * 19349663 ^ z * 83492791) & 255) / 255.0
				if layered and world.gates.has(Vector3i(x, y, z)):
					# a gate holding a gadget: the see-through gate box wraps the gadget
					var gcol: Color = Blocks.COLOR[Blocks.GATE_BLUE if int(world.gates[Vector3i(x, y, z)]) == 0 else Blocks.GATE_RED]
					_box(tv, tc, mn - Vector3(0.012, 0.012, 0.012), mn + Vector3(1.012, 1.012, 1.012), gcol)
				if Blocks.is_glass(id) or id == Blocks.BUBBLE:
					# glass (and bubbles): one see-through face wherever it meets something it can be seen through
					for f in 6:
						var gx: int = x + NX[f]
						var gy: int = y + NY[f]
						var gz: int = z + NZ[f]
						if gy < 0 or gx < 0 or gz < 0 or gx >= sx or gz >= sz:
							continue
						if gy < sy:
							var gn := d[gx + sx * (gz + sz * gy)]
							if gn == id or (opaque[gn] == 1 and mf[gx + sx * (gz + sz * gy)] == 0):
								continue
						_face(tv, tc, mn, mn + Vector3.ONE, f, _shade(col, 0.85 + 0.15 * SHADE[f]))
					continue
				if opaque[id] == 1 and mf[x + sx * (z + sz * y)] == 1:
					_micro_block(world, ov, oc, Vector3i(x, y, z), id, tint * depth)
					continue
				if opaque[id] == 1:
					var glow := id == Blocks.CHEESE or Blocks.is_decoy(id) or id == Blocks.GLOW or id == Blocks.BASE_BLUE or id == Blocks.BASE_RED or Blocks.is_team_block(id) or Blocks.is_paint(id)
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
							c = colors[Blocks.DIRT] * tint * depth
						if textured[id] == 1:
							if not tex.has(id):
								tex[id] = [PackedVector3Array(), PackedColorArray(), PackedVector2Array()]
							var shade: float = tint * depth * float(SHADE[f])
							_face(tex[id][0], tex[id][1], mn, mn + Vector3.ONE, f, Color(shade, shade, shade))
							_face_uv(tex[id][2], f, ((x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (f * 2654435761)) >> 4 & 7)
						elif id == Blocks.STONE or id == Blocks.OBSIDIAN or id == Blocks.BRICK:
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
						_liquid_cell(d, x, y, z, id, ov if is_lava else tv, oc if is_lava else tc,
							col * tint if is_lava else col, is_lava)
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
					Blocks.SQUEAK_BLUE, Blocks.SQUEAK_RED:
						# a rubber pad with a squeaky bulb in the middle
						_box(ov, oc, mn + Vector3(0.1, 0, 0.1), mn + Vector3(0.9, 0.07, 0.9), col * 0.85)
						_box(ov, oc, mn + Vector3(0.18, 0.07, 0.18), mn + Vector3(0.82, 0.1, 0.82), col)
						_box(ov, oc, mn + Vector3(0.38, 0.1, 0.38), mn + Vector3(0.62, 0.24, 0.62), Color(1.0, 0.88, 0.3))
						_box(ov, oc, mn + Vector3(0.44, 0.24, 0.44), mn + Vector3(0.56, 0.28, 0.56), Color(1.0, 0.96, 0.7))
					Blocks.TRAP_BLUE, Blocks.TRAP_RED:
						_box(ov, oc, mn + Vector3(0.12, 0, 0.12), mn + Vector3(0.88, 0.08, 0.88), Color(0.78, 0.62, 0.38))
						_box(ov, oc, mn + Vector3(0.2, 0.08, 0.42), mn + Vector3(0.8, 0.16, 0.58), col)
						_box(ov, oc, mn + Vector3(0.42, 0.08, 0.6), mn + Vector3(0.58, 0.2, 0.76), Color(1.0, 0.85, 0.2))
	var out: Array = []
	if not ov.is_empty():
		out.append([ov, oc, PackedVector2Array(), -1])
	for tid: int in tex:
		out.append([tex[tid][0], tex[tid][1], tex[tid][2], tid])
	if not tv.is_empty():
		out.append([tv, tc, PackedVector2Array(), -2])
	return out


# --- liquids -------------------------------------------------------------------
# A liquid's surface is drawn from heights at the corners of the grid, so
# neighbouring cells always meet. Where liquid has spread onto open ground its
# edge slopes down to that ground (a wedge, not a cube); against banks and walls
# it stays level; under more liquid it is full height. Collision is unchanged.

const LIQUID_TOP := 0.88      # the surface of still liquid in its cell
const LIQUID_EDGE := 0.04     # where an edge meets open ground


static func _covered(d: PackedByteArray, x: int, y: int, z: int, id: int) -> bool:
	return y + 1 < VoxelWorld.SY and d[x + VoxelWorld.SX * (z + VoxelWorld.SZ * (y + 1))] == id


static func liquid_corner(d: PackedByteArray, px: int, y: int, pz: int, id: int) -> float:
	## Surface height at grid point (px, pz) of row y, from the four cells round it.
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	var edge := false
	for k in 4:
		var cx := px - 1 + (k & 1)
		var cz := pz - 1 + (k >> 1)
		if cx < 0 or cz < 0 or cx >= sx or cz >= sz:
			continue
		var n := d[cx + sx * (cz + sz * y)]
		if n == id:
			if _covered(d, cx, y, cz, id):
				return 1.0          # rises to meet the liquid stacked above
		elif Blocks.SOLID[n] == 0 and y > 0:
			var under := d[cx + sx * (cz + sz * (y - 1))]
			if under == id or Blocks.SOLID[under] == 1:
				edge = true         # open ground beside it: the liquid runs out onto it
	return LIQUID_EDGE if edge else LIQUID_TOP


static func _liquid_cell(d: PackedByteArray, x: int, y: int, z: int, id: int, v: PackedVector3Array, c: PackedColorArray,
		col: Color, lava: bool) -> void:
	var sx := VoxelWorld.SX
	var sz := VoxelWorld.SZ
	var mn := Vector3(x, y, z)
	var full := _covered(d, x, y, z, id)
	# this cell's corner heights, indexed by grid point (dx, dz) in {0,1}
	var h := [1.0, 1.0, 1.0, 1.0] if full else [liquid_corner(d, x, y, z, id), liquid_corner(d, x + 1, y, z, id),
		liquid_corner(d, x, y, z + 1, id), liquid_corner(d, x + 1, y, z + 1, id)]
	var shade := func(f: int) -> Color:
		return _shade(col, 0.8 + 0.2 * SHADE[f]) if lava else _shade(col, SHADE[f])
	# top
	if not full:
		var a := mn + Vector3(0, h[0], 0)
		var b := mn + Vector3(0, h[2], 1)
		var cc := mn + Vector3(1, h[3], 1)
		var dd := mn + Vector3(1, h[1], 0)
		v.append(a); v.append(cc); v.append(b)
		v.append(a); v.append(dd); v.append(cc)
		for i in 6:
			c.append(shade.call(2))
	# bottom
	if y > 0:
		var below := d[x + sx * (z + sz * (y - 1))]
		if below != id and Blocks.OPAQUE[below] == 0:
			_face(v, c, mn, mn + Vector3(1, 1, 1), 3, shade.call(3))
	# sides: [face, first corner (dx, dz), second corner] in the winding _face uses
	for side: Array in [[0, 1, 0, 1, 1], [1, 0, 1, 0, 0], [4, 1, 1, 0, 1], [5, 0, 0, 1, 0]]:
		var f: int = side[0]
		var nx: int = x + NX[f]
		var nz: int = z + NZ[f]
		if nx < 0 or nz < 0 or nx >= sx or nz >= sz:
			continue
		var n := d[nx + sx * (nz + sz * y)]
		if Blocks.OPAQUE[n] == 1 and n != id:
			continue
		var i0: int = side[1] + 2 * side[2]
		var i1: int = side[3] + 2 * side[4]
		var lo0 := 0.0
		var lo1 := 0.0
		if n == id:
			if full and not _covered(d, nx, y, nz, id):
				lo0 = liquid_corner(d, x + side[1], y, z + side[2], id)
				lo1 = liquid_corner(d, x + side[3], y, z + side[4], id)
			else:
				continue        # the neighbour's surface meets ours
		if h[i0] - lo0 < 0.01 and h[i1] - lo1 < 0.01:
			continue
		var p0 := mn + Vector3(side[1], 0, side[2])
		var p1 := mn + Vector3(side[3], 0, side[4])
		var a := p0 + Vector3(0, lo0, 0)
		var b := p0 + Vector3(0, h[i0], 0)
		var cc := p1 + Vector3(0, h[i1], 0)
		var dd := p1 + Vector3(0, lo1, 0)
		v.append(a); v.append(cc); v.append(b)
		v.append(a); v.append(dd); v.append(cc)
		for i in 6:
			c.append(shade.call(f))


static func _shade(c: Color, s: float) -> Color:
	return Color(c.r * s, c.g * s, c.b * s, c.a)


static func _commit(mesh: ArrayMesh, v: PackedVector3Array, c: PackedColorArray, mat: Material,
		uv := PackedVector2Array()) -> void:
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
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


static func _face_uv(uv: PackedVector2Array, f: int, variant := 0) -> void:
	## Texture coordinates for one _face, in its vertex order (a, cc, b, a, dd,
	## cc). `variant` 0-7 turns (by quarters) and mirrors the picture, so a
	## run of the same block doesn't look stamped out.
	var q := PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]) if f == 2 or f == 3 \
		else PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	for i in 4:
		var p := q[i] - Vector2(0.5, 0.5)
		if variant & 4:
			p.x = -p.x
		for k in variant & 3:
			p = Vector2(-p.y, p.x)
		q[i] = p + Vector2(0.5, 0.5)
	uv.append(q[0]); uv.append(q[2]); uv.append(q[1])
	uv.append(q[0]); uv.append(q[3]); uv.append(q[2])


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
