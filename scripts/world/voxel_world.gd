class_name VoxelWorld
extends Node3D
## Authoritative voxel grid + chunked visuals.
## Gameplay only ever touches the grid API (get/set/raycast). Chunk meshes are
## pure presentation and are skipped entirely when `visual` is false, which is
## how the headless tests and a future dedicated server run.

signal block_changed(cell: Vector3i, old_id: int, new_id: int)

const SX := 96
const SY := 48
const SZ := 48
const CHUNK := 16
const SAVE_MAGIC := "BWJAM1"

var data := PackedByteArray()
var damage: Dictionary = {}        # Vector3i -> accumulated hits
var cheese_cells: Dictionary = {}  # Vector3i -> true (kept in sync by set_block)
var points_of_interest: Array[Vector3] = []
var visual := true

var _dirty: Dictionary = {}
var _chunks: Dictionary = {}
var _mat_opaque: StandardMaterial3D
var _mat_trans: StandardMaterial3D


func _init() -> void:
	data.resize(SX * SY * SZ)


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
	var i := c.x + SX * (c.z + SZ * c.y)
	var old := data[i]
	if old == id:
		return
	data[i] = id
	damage.erase(c)
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
			var hit := (Blocks.SOLID[id] == 1) if solid_only else (Blocks.TARGETABLE[id] == 1)
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

func save_to(path: String) -> bool:
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
	f.close()
	return true


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
	data = raw
	reindex()
	return true
