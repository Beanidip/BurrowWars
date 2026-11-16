class_name VoxelWorld
extends Node3D
## Authoritative voxel grid + chunked visuals.
## Gameplay only ever touches the grid API (get/set/raycast). Chunk meshes are
## pure presentation and are skipped entirely when `visual` is false, which is
## how the headless tests and a future dedicated server run.

signal block_changed(cell: Vector3i, old_id: int, new_id: int)
signal micro_changed(cell: Vector3i)
signal gate_layer_changed(cell: Vector3i)

const SX := 96
const SY := 48
const SZ := 48
const CHUNK := 16
const SAVE_MAGIC := "BWJAM1"
const M := Blocks.MICRO

var data := PackedByteArray()
var damage: Dictionary = {}        # Vector3i -> accumulated hits
var cheese_cells: Dictionary = {}  # Vector3i -> true (kept in sync by set_block)
# Microvoxels: only chiseled blocks carry a 343-entry mask.
# 0 = empty, 1 = the block's own material, 2 + k = painted in palette colour k.
# Untouched blocks cost nothing; micro_flag gives hot loops an O(1) test.
var micro: Dictionary = {}         # Vector3i -> PackedByteArray(343)
var micro_flag := PackedByteArray()
## Team gates that also hold a gadget: cell -> team. The block id in such a
## cell is the gadget (a spring, ladder, conveyor...); the gate is a layer
## that keeps the other team out. Removing the gadget leaves the plain gate.
var gates: Dictionary = {}
var loaded_extra: Dictionary = {}  # non-terrain data from the last load (machines...)
var points_of_interest: Array[Vector3] = []
var visual := true

var _dirty: Dictionary = {}
var _chunks: Dictionary = {}
var _mat_opaque: StandardMaterial3D
var _mat_trans: StandardMaterial3D


func _init() -> void:
	data.resize(SX * SY * SZ)
	micro_flag.resize(SX * SY * SZ)


func _ready() -> void:
	_mat_opaque = StandardMaterial3D.new()
	_mat_opaque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_opaque.vertex_color_use_as_albedo = true
	_mat_trans = StandardMaterial3D.new()
	_mat_trans.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_trans.vertex_color_use_as_albedo = true
	_mat_trans.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_trans.cull_mode = BaseMaterial3D.CULL_DISABLED


static func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < SX and c.y < SY and c.z < SZ


func get_block(x: int, y: int, z: int) -> int:
	if y >= SY:
		return Blocks.AIR
	if x < 0 or z < 0 or y < 0 or x >= SX or z >= SZ:
		return Blocks.BEDROCK
	return data[x + SX * (z + SZ * y)]


func get_cell(c: Vector3i) -> int:
	return get_block(c.x, c.y, c.z)


func block_at(p: Vector3) -> int:
	return get_block(floori(p.x), floori(p.y), floori(p.z))


func set_raw(x: int, y: int, z: int, id: int) -> void:
	## Generator-only write: no signals, no dirty tracking.
	if x < 0 or z < 0 or y < 0 or x >= SX or z >= SZ or y >= SY:
		return
	data[x + SX * (z + SZ * y)] = id


func set_block(c: Vector3i, id: int) -> void:
	if not in_bounds(c):
		return
	if not gates.is_empty() and gates.has(c):
		var team := int(gates[c])
		if id == Blocks.AIR:
			id = Blocks.GATE_BLUE if team == 0 else Blocks.GATE_RED   # the gadget goes, the gate stays
		if not Blocks.GATE_GADGETS.has(id):
			gates.erase(c)
			gate_layer_changed.emit(c)
	var i := c.x + SX * (c.z + SZ * c.y)
	var old := data[i]
	if old == id:
		return
	data[i] = id
	damage.erase(c)
	if micro_flag[i] == 1:
		# replacing a block always discards its carving: nothing can float behind
		micro_flag[i] = 0
		micro.erase(c)
	if old == Blocks.CHEESE:
		cheese_cells.erase(c)
	if id == Blocks.CHEESE:
		cheese_cells[c] = true
	_mark_dirty(c)
	block_changed.emit(c, old, id)


func reindex() -> void:
	## Rebuild derived indexes after bulk writes (generation / map load).
	cheese_cells.clear()
	damage.clear()
	micro_flag.fill(0)
	for mc: Vector3i in micro:
		micro_flag[mc.x + SX * (mc.z + SZ * mc.y)] = 1
	for y in SY:
		for z in SZ:
			for x in SX:
				if data[x + SX * (z + SZ * y)] == Blocks.CHEESE:
					cheese_cells[Vector3i(x, y, z)] = true
	mark_all_dirty()


func surface_y(x: int, z: int) -> int:
	## Y of the first free cell above the highest solid block in a column.
	for y in range(SY - 1, -1, -1):
		if Blocks.SOLID[get_block(x, y, z)] == 1:
			return y + 1
	return 0


# ---------------------------------------------------------------- raycast

func raycast(origin: Vector3, dir: Vector3, max_dist: float, solid_only := false) -> Dictionary:
	## Voxel DDA. Returns {} on a miss, else {cell, normal, id, dist}.
	## The cell containing the origin is never reported, so a rat standing in a
	## ladder or trap can still dig what is in front of it.
	if dir.length_squared() < 0.000001:
		return {}
	var d := dir.normalized()
	var cell := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i.ZERO
	var t_max := Vector3.ZERO
	var t_delta := Vector3.ZERO
	for a in 3:
		if absf(d[a]) < 0.0000001:
			t_max[a] = INF
			t_delta[a] = INF
			step[a] = 0
		else:
			step[a] = 1 if d[a] > 0.0 else -1
			var bound := float(cell[a] + (1 if d[a] > 0.0 else 0))
			t_max[a] = (bound - origin[a]) / d[a]
			t_delta[a] = absf(1.0 / d[a])
	var normal := Vector3i.ZERO
	var t := 0.0
	for i in 200:
		if i > 0:
			var id := get_cell(cell)
			var hit := (Blocks.SOLID[id] == 1 or (not gates.is_empty() and gates.has(cell))) if solid_only else (Blocks.TARGETABLE[id] == 1)
			if hit:
				return {"cell": cell, "normal": normal, "id": id, "dist": t}
		var axis := 0
		if t_max.y < t_max.x and t_max.y <= t_max.z:
			axis = 1
		elif t_max.z < t_max.x and t_max.z < t_max.y:
			axis = 2
		t = t_max[axis]
		if t > max_dist:
			return {}
		cell[axis] += step[axis]
		t_max[axis] += t_delta[axis]
		normal = Vector3i.ZERO
		normal[axis] = -step[axis]
	return {}


# ---------------------------------------------------------------- microvoxels

func has_micro(c: Vector3i) -> bool:
	return in_bounds(c) and micro_flag[c.x + SX * (c.z + SZ * c.y)] == 1


func micro_count(c: Vector3i) -> int:
	## Microvoxels present in a block: 343 for an uncarved solid block.
	if not has_micro(c):
		return Blocks.MICRO_COUNT if get_cell(c) != Blocks.AIR else 0
	return Blocks.MICRO_COUNT - (micro[c] as PackedByteArray).count(0)


func micro_at(c: Vector3i, mv: Vector3i) -> bool:
	if not has_micro(c):
		return Blocks.TARGETABLE[get_cell(c)] == 1
	return (micro[c] as PackedByteArray)[mv.x + M * (mv.z + M * mv.y)] != 0


func set_micro(c: Vector3i, mv: Vector3i, on: bool, new_block := Blocks.AIR, value := 1) -> void:
	## Sets one microvoxel. Carving the last one removes the parent block;
	## filling the last gap turns it back into a plain block. `new_block` is
	## the material used when adding into an empty cell.
	if not in_bounds(c):
		return
	var i := c.x + SX * (c.z + SZ * c.y)
	var mask: PackedByteArray
	if micro_flag[i] == 1:
		mask = micro[c]
	elif data[i] == Blocks.AIR:
		if not on or new_block == Blocks.AIR:
			return
		set_block(c, new_block)
		mask = PackedByteArray()
		mask.resize(Blocks.MICRO_COUNT)
	else:
		mask = PackedByteArray()
		mask.resize(Blocks.MICRO_COUNT)
		mask.fill(1)
	mask[mv.x + M * (mv.z + M * mv.y)] = clampi(value, 1, 1 + Blocks.PALETTE_SIZE) if on else 0
	if mask.count(0) == Blocks.MICRO_COUNT:
		set_block(c, Blocks.AIR)
		return
	if mask.count(1) == Blocks.MICRO_COUNT:
		micro.erase(c)
		micro_flag[i] = 0
	else:
		micro[c] = mask
		micro_flag[i] = 1
	damage.erase(c)
	_mark_dirty(c)
	micro_changed.emit(c)


func set_mask(c: Vector3i, block: int, mask: PackedByteArray) -> void:
	## Writes a whole carved block at once (pantograph paste, map load).
	set_block(c, block)
	if mask.size() != Blocks.MICRO_COUNT or mask.count(1) == Blocks.MICRO_COUNT:
		return
	if mask.count(0) == Blocks.MICRO_COUNT:
		set_block(c, Blocks.AIR)
		return
	micro[c] = mask.duplicate()
	micro_flag[c.x + SX * (c.z + SZ * c.y)] = 1
	_mark_dirty(c)
	micro_changed.emit(c)


func solid_point(p: Vector3) -> bool:
	## Point test against solid terrain, honouring carved blocks.
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var id := get_cell(c)
	if Blocks.SOLID[id] == 0:
		return not gates.is_empty() and gates.has(c)   # a gate holding a ladder or highway is still a wall to loose things
	if not has_micro(c):
		return true
	var mx := clampi(int((p.x - c.x) * M), 0, M - 1)
	var my := clampi(int((p.y - c.y) * M), 0, M - 1)
	var mz := clampi(int((p.z - c.z) * M), 0, M - 1)
	return (micro[c] as PackedByteArray)[mx + M * (mz + M * my)] == 1


func micro_box_hit(c: Vector3i, mn: Vector3, mx: Vector3) -> bool:
	## Does the box [mn, mx] touch any microvoxel of carved block c?
	var mask: PackedByteArray = micro[c]
	var x0 := clampi(floori((mn.x - c.x) * M), 0, M - 1)
	var x1 := clampi(ceili((mx.x - c.x) * M) - 1, 0, M - 1)
	var y0 := clampi(floori((mn.y - c.y) * M), 0, M - 1)
	var y1 := clampi(ceili((mx.y - c.y) * M) - 1, 0, M - 1)
	var z0 := clampi(floori((mn.z - c.z) * M), 0, M - 1)
	var z1 := clampi(ceili((mx.z - c.z) * M) - 1, 0, M - 1)
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				if mask[x + M * (z + M * y)] != 0:
					return true
	return false


func raycast_micro(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	## DDA at microvoxel resolution. Returns {} or
	## {cell, micro, normal, id, dist}: the block, the microvoxel inside it,
	## the face normal and the block id. Uncarved blocks count as fully solid.
	if dir.length_squared() < 0.000001:
		return {}
	var d := dir.normalized()
	var o := origin * float(M)
	var g := Vector3i(floori(o.x), floori(o.y), floori(o.z))
	var start_cell := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i.ZERO
	var t_max := Vector3.ZERO
	var t_delta := Vector3.ZERO
	for a in 3:
		if absf(d[a]) < 0.0000001:
			t_max[a] = INF
			t_delta[a] = INF
		else:
			step[a] = 1 if d[a] > 0.0 else -1
			t_max[a] = (float(g[a] + (1 if d[a] > 0.0 else 0)) - o[a]) / d[a]
			t_delta[a] = absf(1.0 / d[a])
	var normal := Vector3i.ZERO
	var t := 0.0
	var limit := max_dist * float(M)
	for i in 1500:
		var c := Vector3i(floori(g.x / float(M)), floori(g.y / float(M)), floori(g.z / float(M)))
		if c != start_cell or has_micro(c):
			var id := get_cell(c)
			if Blocks.TARGETABLE[id] == 1:
				var mv := g - c * M
				if not has_micro(c) or (micro[c] as PackedByteArray)[mv.x + M * (mv.z + M * mv.y)] == 1:
					if normal != Vector3i.ZERO:
						return {"cell": c, "micro": mv, "normal": normal, "id": id, "dist": t / float(M)}
		var axis := 0
		if t_max.y < t_max.x and t_max.y <= t_max.z:
			axis = 1
		elif t_max.z < t_max.x and t_max.z < t_max.y:
			axis = 2
		t = t_max[axis]
		if t > limit:
			return {}
		g[axis] += step[axis]
		t_max[axis] += t_delta[axis]
		normal = Vector3i.ZERO
		normal[axis] = -step[axis]
	return {}


# ---------------------------------------------------------------- visuals

func _mark_dirty(c: Vector3i) -> void:
	if not visual:
		return
	var k := Vector3i(c.x / CHUNK, c.y / CHUNK, c.z / CHUNK)
	_dirty[k] = true
	var l := Vector3i(c.x % CHUNK, c.y % CHUNK, c.z % CHUNK)
	for a in 3:
		if l[a] == 0:
			var n := k
			n[a] -= 1
			_dirty[n] = true
		elif l[a] == CHUNK - 1:
			var n2 := k
			n2[a] += 1
			_dirty[n2] = true


func mark_all_dirty() -> void:
	if not visual:
		return
	for cy in SY / CHUNK:
		for cz in SZ / CHUNK:
			for cx in SX / CHUNK:
				_dirty[Vector3i(cx, cy, cz)] = true


func rebuild_dirty(budget: int) -> void:
	var done := 0
	for k: Vector3i in _dirty.keys():
		_dirty.erase(k)
		if k.x < 0 or k.y < 0 or k.z < 0 or k.x >= SX / CHUNK or k.y >= SY / CHUNK or k.z >= SZ / CHUNK:
			continue
		_rebuild_chunk(k)
		done += 1
		if done >= budget:
			return


func _process(_delta: float) -> void:
	if visual and not _dirty.is_empty():
		rebuild_dirty(6)


func _rebuild_chunk(k: Vector3i) -> void:
	var mi: MeshInstance3D = _chunks.get(k)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_chunks[k] = mi
	mi.mesh = ChunkMesher.build(self, k, _mat_opaque, _mat_trans)


# ---------------------------------------------------------------- persistence

func save_to(path: String, extra: Dictionary = {}) -> bool:
	## Format: header, sizes, zstd block data, then one Variant holding the
	## carved-block masks and any extra state (siege machines).
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Log.warn("map save failed: %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_pascal_string(SAVE_MAGIC)
	f.store_32(SX)
	f.store_32(SY)
	f.store_32(SZ)
	var packed := data.compress(FileAccess.COMPRESSION_ZSTD)
	f.store_32(packed.size())
	f.store_buffer(packed)
	var masks := {}
	for c: Vector3i in micro:
		masks[c.x + SX * (c.z + SZ * c.y)] = micro[c]
	f.store_var({"micro": masks, "gates": _gates_by_index(), "extra": extra}, false)
	f.close()
	return true


func snapshot() -> Dictionary:
	## The whole terrain (blocks + carvings) as one compact Variant, for a
	## player joining a networked match.
	var masks := {}
	for c: Vector3i in micro:
		masks[c.x + SX * (c.z + SZ * c.y)] = micro[c]
	return {"d": data.compress(FileAccess.COMPRESSION_ZSTD), "m": masks, "g": _gates_by_index()}


func apply_snapshot(snap: Variant) -> bool:
	## Validates like load_from: a bad snapshot is rejected, never half-applied.
	if not (snap is Dictionary) or not (snap.get("d") is PackedByteArray) or not (snap.get("m") is Dictionary):
		return false
	var raw: PackedByteArray = (snap["d"] as PackedByteArray).decompress(SX * SY * SZ, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != SX * SY * SZ:
		return false
	for i in raw.size():
		if raw[i] >= Blocks.COUNT:
			return false
	var new_micro := {}
	var masks: Dictionary = snap["m"]
	for key: Variant in masks:
		var mask: Variant = masks[key]
		if not (key is int) or not (mask is PackedByteArray) or int(key) < 0 or int(key) >= raw.size() \
				or (mask as PackedByteArray).size() != Blocks.MICRO_COUNT or raw[int(key)] == Blocks.AIR:
			return false
		var idx := int(key)
		new_micro[Vector3i(idx % SX, idx / (SX * SZ), (idx / SX) % SZ)] = mask
	var new_gates: Variant = _read_gates(snap.get("g", {}), raw)
	if new_gates == null:
		return false
	data = raw
	micro = new_micro
	gates = new_gates
	reindex()
	return true


func _gates_by_index() -> Dictionary:
	var out := {}
	for c: Vector3i in gates:
		out[c.x + SX * (c.z + SZ * c.y)] = int(gates[c])
	return out


static func _read_gates(raw_gates: Variant, raw: PackedByteArray) -> Variant:
	## Validated gate layers, or null if the data is malformed.
	if not (raw_gates is Dictionary):
		return null
	var out := {}
	for key: Variant in raw_gates:
		var team: Variant = raw_gates[key]
		if not (key is int) or not (team is int) or int(key) < 0 or int(key) >= raw.size() or (int(team) != 0 and int(team) != 1) \
				or not Blocks.GATE_GADGETS.has(int(raw[int(key)])):
			return null
		var idx := int(key)
		out[Vector3i(idx % SX, idx / (SX * SZ), (idx / SX) % SZ)] = int(team)
	return out


func gate_at(c: Vector3i) -> int:
	## Team of the gate in this cell, plain or holding a gadget; -1 if none.
	var id := get_cell(c)
	if Blocks.is_gate(id):
		return Blocks.gate_team(id)
	return int(gates.get(c, -1))


func layered_gate(c: Vector3i) -> int:
	## Team of a gate that holds a gadget in this cell, or -1.
	return int(gates.get(c, -1)) if not gates.is_empty() else -1


func set_gate_layer(c: Vector3i, team: int) -> void:
	## team -1 removes the layer (the block id is left as it is).
	if team < 0:
		if gates.erase(c):
			_mark_dirty(c)
			gate_layer_changed.emit(c)
		return
	gates[c] = team
	_mark_dirty(c)
	gate_layer_changed.emit(c)


func solid_for_at(c: Vector3i, team: int) -> bool:
	## Collision for a rat of `team`, including gates that hold gadgets.
	if not gates.is_empty() and gates.has(c) and int(gates[c]) != team:
		return true
	return Blocks.solid_for(get_cell(c), team)


func micro_mask(c: Vector3i) -> Variant:
	## The carving of one cell, or null when it is a plain block.
	return micro[c] if has_micro(c) else null


func load_from(path: String) -> bool:
	## Rejects malformed or mismatched saves instead of corrupting the world.
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	if f.get_pascal_string() != SAVE_MAGIC:
		Log.warn("map load rejected (bad header): " + path)
		return false
	if f.get_32() != SX or f.get_32() != SY or f.get_32() != SZ:
		Log.warn("map load rejected (size mismatch): " + path)
		return false
	var n := f.get_32()
	if n <= 0 or n > 8 * SX * SY * SZ:
		Log.warn("map load rejected (bad length): " + path)
		return false
	var raw := f.get_buffer(n).decompress(SX * SY * SZ, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != SX * SY * SZ:
		Log.warn("map load rejected (corrupt data): " + path)
		return false
	for i in raw.size():
		if raw[i] >= Blocks.COUNT:
			Log.warn("map load rejected (unknown block id): " + path)
			return false
	var new_micro := {}
	var new_gates: Variant = {}
	var extra := {}
	if f.get_position() < f.get_length():   # older saves simply end here
		var tail: Variant = f.get_var(false)
		if not (tail is Dictionary) or not (tail.get("micro", {}) is Dictionary):
			Log.warn("map load rejected (bad carving data): " + path)
			return false
		var masks: Dictionary = tail["micro"]
		for key: Variant in masks:
			var mask: Variant = masks[key]
			if not (key is int) or not (mask is PackedByteArray) or int(key) < 0 or int(key) >= raw.size() \
					or (mask as PackedByteArray).size() != Blocks.MICRO_COUNT or raw[int(key)] == Blocks.AIR:
				Log.warn("map load rejected (bad carving entry): " + path)
				return false
			var idx := int(key)
			new_micro[Vector3i(idx % SX, idx / (SX * SZ), (idx / SX) % SZ)] = mask
		if tail.get("extra", {}) is Dictionary:
			extra = tail["extra"]
		new_gates = _read_gates(tail.get("gates", {}), raw)
		if new_gates == null:
			Log.warn("map load rejected (bad gate data): " + path)
			return false
	data = raw
	micro = new_micro
	gates = new_gates
	loaded_extra = extra
	reindex()
	return true
