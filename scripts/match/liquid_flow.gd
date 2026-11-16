class_name LiquidFlow
extends RefCounted
## Flowing liquids (one instance per liquid: lava and water). Pools sit still
## until something opens a way out; then the liquid pours down into any gap and
## creeps sideways a few blocks from where it lands. Event-driven: only liquid
## cells next to a recent change are looked at, so a quiet map costs nothing.
## Lava touching water hardens into stone. Runs on the authority like every
## other rule.

const SIDES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const AROUND: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0)]

## Per-liquid tuning: seconds between flow steps, sideways reach from a source
## or landing point, and a safety cap on blocks created per match.
const LAVA_TICK := 0.45
const LAVA_REACH := 3
const LAVA_CAP := 1200
const WATER_TICK := 0.25
const WATER_REACH := 5
const WATER_CAP := 2500

var m: Match
var liquid: int
var tick: float
var reach: int
var cap: int
var active: Dictionary = {}    # Vector3i -> true
var level: Dictionary = {}     # flowed cells only; generated liquid counts as `reach`
var flowed := 0
var _t := 0.0


static func lava(p_match: Match) -> LiquidFlow:
	return LiquidFlow.new(p_match, Blocks.LAVA, LAVA_TICK, LAVA_REACH, LAVA_CAP)


static func water(p_match: Match) -> LiquidFlow:
	return LiquidFlow.new(p_match, Blocks.WATER, WATER_TICK, WATER_REACH, WATER_CAP)


func _init(p_match: Match, p_liquid: int, p_tick: float, p_reach: int, p_cap: int) -> void:
	m = p_match
	liquid = p_liquid
	tick = p_tick
	reach = p_reach
	cap = p_cap


func on_block_changed(cell: Vector3i, _old: int, new_id: int) -> void:
	if new_id == liquid:
		active[cell] = true
		return
	level.erase(cell)
	if new_id == Blocks.AIR or new_id == Blocks.WATER or new_id == Blocks.LAVA:
		for n: Vector3i in AROUND:
			if n.y < 0:
				continue       # liquid below an opened cell does not rise into it
			if m.world.get_cell(cell + n) == liquid:
				active[cell + n] = true


func step(dt: float) -> void:
	_t += dt
	if _t < tick:
		return
	_t = 0.0
	if active.is_empty():
		return
	var batch := active.keys()
	active.clear()
	var w := m.world
	for c: Vector3i in batch:
		if w.get_cell(c) != liquid:
			continue
		if _quench(c):
			continue
		var below := c + Vector3i(0, -1, 0)
		var bid := w.get_cell(below)
		if bid == Blocks.AIR and below.y >= 1:
			_pour(below, reach)      # falls first, and spreads again where it lands
			continue
		var lv := int(level.get(c, reach))
		if lv <= 0:
			continue
		for n: Vector3i in SIDES:
			if w.get_cell(c + n) == Blocks.AIR:
				_pour(c + n, lv - 1)


func _quench(c: Vector3i) -> bool:
	## Lava next to water hardens into stone. Returns true if `c` itself stopped
	## being liquid (lava that touched water).
	var w := m.world
	for n: Vector3i in AROUND:
		var other := w.get_cell(c + n)
		if liquid == Blocks.LAVA and other == Blocks.WATER:
			w.set_block(c, Blocks.STONE)
			m.fx.emit("quench", Vector3(c), null)
			return true
		if liquid == Blocks.WATER and other == Blocks.LAVA:
			w.set_block(c + n, Blocks.STONE)
			m.fx.emit("quench", Vector3(c + n), null)
	return false


func _pour(cell: Vector3i, lv: int) -> void:
	if flowed >= cap or not VoxelWorld.in_bounds(cell):
		return
	if MapGenerator.in_any_base(cell, 1.0):
		return
	flowed += 1
	level[cell] = lv
	m.world.set_block(cell, liquid)
