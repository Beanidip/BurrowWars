class_name MeteorSystem
## The Meteor Shower match option. Now and then (Config.METEOR_*) a meteor
## is picked a random target away from both bases: a red ring marks the spot
## for METEOR_WARN seconds while it falls, then it strikes - a crater through
## the normal blast rule (durability applies: obsidian only chips), every rat
## in reach bonked (knocked flying, a cheese dropped, and in a Scrap Race
## loose scrap), and a lump of scrap left at the bottom of the hole.
##
## The authority decides everything; players' games get the falling meteors
## in snapshots and the crater as ordinary block changes and effects.

class Meteor:
	var uid := 0
	var start := Vector3.ZERO     # where it appears, high in the sky
	var target := Vector3.ZERO    # the spot it was aimed at (on the ground then)
	var t := 0.0                  # seconds since it appeared
	var time := Config.METEOR_WARN

	func pos() -> Vector3:
		var k := clampf(t / time, 0.0, 1.0)
		return start.lerp(target, k * k)   # (it speeds up as it falls)

	func left() -> float:
		return maxf(0.0, time - t)


var m: Match
var list: Array[Meteor] = []
var next_in := Config.METEOR_FIRST
var strikes := 0
var _rng := RandomNumberGenerator.new()
var _uid := 1


func _init(p_match: Match) -> void:
	m = p_match
	_rng.seed = int(m.settings.get("seed", 1)) * 31 + 7


func enabled() -> bool:
	return m.has_mutator("meteors") and not m.free_mode


func step(dt: float) -> void:
	## Authority only.
	if not enabled():
		return
	if not m.over:
		next_in -= dt
		if next_in <= 0.0:
			next_in = _rng.randf_range(Config.METEOR_GAP_MIN, Config.METEOR_GAP_MAX)
			launch()
	for mt in list.duplicate():
		mt.t += dt
		if mt.t >= mt.time:
			list.erase(mt)
			strike(mt)


func launch(at := Vector3.INF) -> Meteor:
	## A new meteor on its way: at a random spot away from both bases, or `at`.
	var target := at
	if target == Vector3.INF:
		for i in 30:
			var x := _rng.randi_range(4, VoxelWorld.SX - 5)
			var z := _rng.randi_range(4, VoxelWorld.SZ - 5)
			if _near_base(x, z):
				continue
			target = Vector3(x + 0.5, surface(x, z), z + 0.5)
			break
		if target == Vector3.INF:
			return null
	var mt := Meteor.new()
	mt.uid = _uid
	_uid += 1
	mt.target = target
	var drift := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * 14.0
	mt.start = target + drift + Vector3(0, Config.METEOR_HEIGHT, 0)
	list.append(mt)
	m.fx.emit("meteor_warn", target, Config.METEOR_WARN)
	for team in 2:
		m.add_marker(target + Vector3(0, 2.0, 0), "METEOR!", team, Config.METEOR_WARN)
	return mt


func _near_base(x: int, z: int) -> bool:
	var keep := Config.METEOR_RADIUS + 4.0
	for team in 2:
		var b := MapGenerator.base_zone(team)
		if x > b.position.x - keep and x < b.end.x + keep and z > b.position.z - keep and z < b.end.z + keep:
			return true
	return false


func surface(x: int, z: int, from_y := VoxelWorld.SY - 1) -> float:
	## The y it lands on in that column: on top of the highest solid block.
	for y in range(mini(from_y, VoxelWorld.SY - 1), 0, -1):
		if Blocks.SOLID[m.world.get_cell(Vector3i(x, y, z))] != 0:
			return float(y + 1)
	return 1.0


func strike(mt: Meteor) -> void:
	## Impact, where the ground is now (someone may have dug or built there).
	var x := floori(mt.target.x)
	var z := floori(mt.target.z)
	var hit := Vector3(mt.target.x, surface(x, z), mt.target.z)
	strikes += 1
	m.meteor_strike(hit)


# ---------------------------------------------------------------- online

func snapshot() -> Array:
	var out: Array = []
	for mt in list:
		out.append([mt.uid, mt.start, mt.target, mt.t, mt.time])
	return out


func apply(raw: Variant) -> void:
	## Replica: the server's meteors (each one keeps falling between snapshots).
	var by_uid := {}
	for mt in list:
		by_uid[mt.uid] = mt
	var out: Array[Meteor] = []
	if raw is Array:
		for e: Variant in raw:
			if not (e is Array) or (e as Array).size() < 5:
				continue
			var mt: Meteor = by_uid.get(int(e[0]))
			if mt == null:
				mt = Meteor.new()
				mt.uid = int(e[0])
			mt.start = e[1]
			mt.target = e[2]
			mt.t = float(e[3])
			mt.time = float(e[4])
			out.append(mt)
	list = out


func glide(dt: float) -> void:
	for mt in list:
		mt.t = minf(mt.t + dt, mt.time)
