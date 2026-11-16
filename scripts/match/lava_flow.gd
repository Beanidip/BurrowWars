class_name LavaFlow
extends RefCounted
## Flowing lava. Pools sit still until something opens a way out; then lava
## pours down into any gap and creeps sideways a few blocks from where it
## lands. Event-driven: only lava cells next to a recent change are looked at,
## so a quiet map costs nothing. Runs on the authority like every other rule.

const TICK := 0.45        # seconds between flow steps
const REACH := 3          # sideways blocks from a source or a landing point
const CAP := 1200         # safety limit on lava created per match

const SIDES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var m: Match
var active: Dictionary = {}    # Vector3i -> true
var level: Dictionary = {}     # flowed cells only; generated lava counts as REACH
var flowed := 0
var _t := 0.0


func _init(p_match: Match) -> void:
	m = p_match


func wake_all() -> void:
	## Called once after generation so pools that open onto a cave settle.
	var i := m.world.data.find(Blocks.LAVA)
	while i >= 0:
		active[Vector3i(i % VoxelWorld.SX, i / (VoxelWorld.SX * VoxelWorld.SZ), (i / VoxelWorld.SX) % VoxelWorld.SZ)] = true
		i = m.world.data.find(Blocks.LAVA, i + 1)


func on_block_changed(cell: Vector3i, _old: int, new_id: int) -> void:
	if new_id == Blocks.LAVA:
		active[cell] = true
		return
	level.erase(cell)
	if new_id == Blocks.AIR:
		for n: Vector3i in SIDES:
			if m.world.get_cell(cell + n) == Blocks.LAVA:
				active[cell + n] = true
		if m.world.get_cell(cell + Vector3i(0, 1, 0)) == Blocks.LAVA:
			active[cell + Vector3i(0, 1, 0)] = true


func step(dt: float) -> void:
	_t += dt
	if _t < TICK:
		return
	_t = 0.0
	if active.is_empty():
		return
	var batch := active.keys()
	active.clear()
	var w := m.world
	for c: Vector3i in batch:
		if w.get_cell(c) != Blocks.LAVA:
			continue
		var below := c + Vector3i(0, -1, 0)
		var bid := w.get_cell(below)
		if bid == Blocks.AIR and below.y >= 1:
			_pour(below, REACH)      # falls first, and spreads again where it lands
			continue
		var lv := int(level.get(c, REACH))
		if lv <= 0:
			continue
		for n: Vector3i in SIDES:
			if w.get_cell(c + n) == Blocks.AIR:
				_pour(c + n, lv - 1)


func _pour(cell: Vector3i, lv: int) -> void:
	if flowed >= CAP or not VoxelWorld.in_bounds(cell):
		return
	for t in 2:
		if MapGenerator.base_zone(t).grow(1.0).has_point(Vector3(cell) + Vector3(0.5, 0.5, 0.5)):
			return
	flowed += 1
	level[cell] = lv
	m.world.set_block(cell, Blocks.LAVA)
