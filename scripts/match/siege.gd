class_name SiegeSystem
extends RefCounted
## Siege machinery: Scrap Cannon, Wrecking Crane, Bulldozer.
## A machine occupies one grid cell as a solid block (so terrain collision,
## placement rules and the pantograph treat it like any obstacle) plus a
## Machine record with its aim, operator and motion. Machines never drive:
## conveyors under or beside them shove them along one block at a time, and
## ice lets them keep sliding. Everything here is deterministic kinematics -
## no rigid bodies - so it cannot explode, jitter or desync.

const CRANE_MAST := 3.6      # pivot height above the machine cell
const CRANE_REACH := 2.5     # boom length
const CRANE_CABLE := 3.0
const BALL_RADIUS := 0.45
const SHOT_GRAVITY := 14.0


class Machine:
	var uid := 0
	var kind := Blocks.CANNON
	var cell := Vector3i.ZERO
	var team := 0
	var owner := -1
	var yaw := 0.0
	var pitch := 0.35
	var operator := -1
	var cd := 0.0
	var move_cd := 0.0
	var slide := Vector3i.ZERO
	var theta := 0.0      # crane swing angle (0 = hanging straight down)
	var omega := 0.0
	var recoil := 0.0     # presentation hint


class Shot:
	var uid := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var owner := -1
	var team := 0
	var life := 6.0


var m: Match
var machines: Dictionary = {}     # Vector3i cell -> Machine
var shots: Array[Shot] = []
var _moving := false


func _init(p_match: Match) -> void:
	m = p_match


# ---------------------------------------------------------------- lifecycle

func register(cell: Vector3i, kind: int, rat: Rat) -> Machine:
	var mc := Machine.new()
	mc.uid = m.take_uid()
	mc.kind = kind
	mc.cell = cell
	mc.team = rat.team
	mc.owner = rat.id
	mc.yaw = rat.yaw
	machines[cell] = mc
	return mc


func on_block_changed(cell: Vector3i, _old: int, new_id: int) -> void:
	if _moving or not machines.has(cell):
		return
	var mc: Machine = machines[cell]
	if new_id != mc.kind:
		_free_operator(mc)
		machines.erase(cell)


func by_uid(uid: int) -> Machine:
	for mc: Machine in machines.values():
		if mc.uid == uid:
			return mc
	return null


func try_pickup(rat: Rat, cell: Vector3i) -> String:
	var mc: Machine = machines.get(cell)
	if mc == null:
		return "That machine is jammed"
	if mc.team != rat.team:
		return "That's the other team's machine - blow up its conveyors instead"
	if mc.operator != -1:
		return "Someone is operating it"
	var item: String = {Blocks.CANNON: "cannon", Blocks.CRANE: "crane", Blocks.DOZER: "dozer"}[mc.kind]
	if int(rat.gadgets.get(item, 0)) >= 2 and not m.free_mode:
		return "You can't carry another one"
	m.world.set_block(cell, Blocks.AIR)
	rat.gadgets[item] = int(rat.gadgets.get(item, 0)) + 1
	m.fx.emit("break", Vector3(cell), mc.kind)
	return ""


func try_operate(rat: Rat, cell: Vector3i) -> String:
	var mc: Machine = machines.get(cell)
	if mc == null:
		return "Nothing to operate there"
	if m.over or rat.stun > 0.0:
		return "Can't do that right now"
	if mc.team != rat.team:
		return "That machine belongs to the other team"
	if mc.operator != -1 and mc.operator != rat.id:
		return "Someone else is at the controls"
	if (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.center()) > 3.2:
		return "Get closer to operate it"
	release(rat)
	mc.operator = rat.id
	rat.operating = mc.uid
	m.fx.emit("ability", rat.position, "operate")
	return ""


func release(rat: Rat) -> void:
	if rat.operating == -1:
		return
	var mc := by_uid(rat.operating)
	if mc != null and mc.operator == rat.id:
		mc.operator = -1
	rat.operating = -1


func _free_operator(mc: Machine) -> void:
	if mc.operator != -1:
		var r := m.rat_by_id(mc.operator)
		if r != null:
			r.operating = -1
		mc.operator = -1


func _machine_of(rat: Rat) -> Machine:
	if rat.operating == -1:
		return null
	var mc := by_uid(rat.operating)
	return mc if (mc != null and mc.operator == rat.id) else null


# ---------------------------------------------------------------- controls

func aim(rat: Rat, yaw: float, pitch: float) -> void:
	var mc := _machine_of(rat)
	if mc == null:
		return
	mc.yaw = yaw
	mc.pitch = clampf(pitch, -0.15, 1.2)


func fire(rat: Rat) -> String:
	## Primary action of whatever the rat is operating. "wait" = on cooldown.
	var mc := _machine_of(rat)
	if mc == null:
		return "You aren't operating a machine"
	if m.over:
		return "Match is over"
	if mc.cd > 0.0:
		return "wait"
	match mc.kind:
		Blocks.CANNON:
			mc.cd = Config.CANNON_COOLDOWN
			mc.recoil = 1.0
			var s := Shot.new()
			s.uid = m.take_uid()
			s.pos = muzzle(mc)
			s.vel = aim_dir(mc) * Config.CANNON_SPEED
			s.owner = rat.id
			s.team = mc.team
			shots.append(s)
			m.fx.emit("cannon", s.pos, null)
		Blocks.CRANE:
			mc.cd = 0.45
			# pump the swing in whichever way the ball is already travelling
			var push := 1.0 if mc.omega >= -0.15 else -1.0
			mc.omega = clampf(mc.omega + push * 1.5, -3.4, 3.4)
			m.fx.emit("crane", ball_pos(mc), null)
		Blocks.DOZER:
			mc.cd = Config.DOZER_COOLDOWN
			mc.recoil = 1.0
			var hit := 0
			for c in dozer_cells(mc):
				if m._damage(rat, c, Config.DOZER_HIT, true):
					hit += 1
					m.fx.emit("break", Vector3(c), Blocks.DIRT)
				elif m.world.damage.has(c):
					m.fx.emit("hit", Vector3(c), {"id": m.world.get_cell(c), "ratio": 0.5})
			m.fx.emit("dozer", Vector3(mc.cell) + Vector3(facing(mc)), hit)
	return ""


static func aim_dir(mc: Machine) -> Vector3:
	return Vector3(-sin(mc.yaw) * cos(mc.pitch), sin(mc.pitch), -cos(mc.yaw) * cos(mc.pitch))


static func muzzle(mc: Machine) -> Vector3:
	return Vector3(mc.cell) + Vector3(0.5, 1.25, 0.5) + aim_dir(mc) * 1.0


static func facing(mc: Machine) -> Vector3i:
	## Yaw snapped to the four grid directions (bulldozer blade).
	var f := Vector3(-sin(mc.yaw), 0, -cos(mc.yaw))
	if absf(f.x) >= absf(f.z):
		return Vector3i(1 if f.x > 0.0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if f.z > 0.0 else -1)


static func dozer_cells(mc: Machine) -> Array[Vector3i]:
	var f := facing(mc)
	var side := Vector3i(f.z, 0, f.x)
	var out: Array[Vector3i] = []
	for w in range(-1, 2):
		for h in 2:
			out.append(mc.cell + f + side * w + Vector3i(0, h, 0))
	return out


static func ball_pos(mc: Machine) -> Vector3:
	var fwd := Vector3(-sin(mc.yaw), 0, -cos(mc.yaw))
	var tip := Vector3(mc.cell) + Vector3(0.5, CRANE_MAST, 0.5) + fwd * CRANE_REACH
	return tip + (fwd * sin(mc.theta) - Vector3.UP * cos(mc.theta)) * CRANE_CABLE


func predict(mc: Machine, points := 14) -> Array[Vector3]:
	## Cannon aiming preview: the arc the next shot would fly.
	var out: Array[Vector3] = []
	var p := muzzle(mc)
	var v := aim_dir(mc) * Config.CANNON_SPEED
	for i in points * 4:
		v.y -= SHOT_GRAVITY * 0.03
		p += v * 0.03
		if i % 4 == 3:
			out.append(p)
		if m.world.solid_point(p):
			out.append(p)
			break
	return out


# ---------------------------------------------------------------- simulation

func step(dt: float) -> void:
	for mc: Machine in machines.values():
		mc.cd = maxf(0.0, mc.cd - dt)
		mc.move_cd = maxf(0.0, mc.move_cd - dt)
		mc.recoil = maxf(0.0, mc.recoil - dt * 4.0)
		if mc.operator != -1:
			var r := m.rat_by_id(mc.operator)
			if r == null or r.stun > 0.0 or r.knock > 0.0 or (Vector3(mc.cell) + Vector3(0.5, 0.5, 0.5)).distance_to(r.center()) > 4.0:
				_free_operator(mc)
		if mc.kind == Blocks.CRANE:
			_swing(mc, dt)
		if mc.move_cd <= 0.0:
			_transport(mc)
	for i in range(shots.size() - 1, -1, -1):
		if _fly(shots[i], dt):
			shots.remove_at(i)


func _transport(mc: Machine) -> void:
	var w := m.world
	var below := w.get_cell(mc.cell + Vector3i(0, -1, 0))
	# gravity first: a machine with nothing under it drops a block
	if Blocks.SOLID[below] == 0 and mc.cell.y > 1:
		if _relocate(mc, mc.cell + Vector3i(0, -1, 0), 0.12):
			mc.slide = Vector3i.ZERO
		return
	var dir := Vector3i.ZERO
	if Blocks.is_conveyor(below):
		dir = Vector3i(Blocks.conveyor_dir(below))
	else:
		for n: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var id := w.get_cell(mc.cell + n)
			if Blocks.is_conveyor(id):
				dir = Vector3i(Blocks.conveyor_dir(id))
				break
	if dir == Vector3i.ZERO and mc.slide != Vector3i.ZERO and below == Blocks.ICE:
		dir = mc.slide   # still gliding across ice
	if dir == Vector3i.ZERO or not _relocate(mc, mc.cell + dir, Config.MACHINE_MOVE_TIME):
		mc.slide = Vector3i.ZERO
		return
	mc.slide = dir if w.get_cell(mc.cell + Vector3i(0, -1, 0)) == Blocks.ICE else Vector3i.ZERO


func _relocate(mc: Machine, dest: Vector3i, time: float) -> bool:
	## Moves a machine one cell if the destination is clear. Ownership, aim,
	## swing state and operator all travel with it.
	var w := m.world
	if not VoxelWorld.in_bounds(dest) or dest.y < 1 or w.get_cell(dest) != Blocks.AIR:
		return false
	for t in 2:
		if MapGenerator.base_zone(t).grow(0.5).has_point(Vector3(dest) + Vector3(0.5, 0.5, 0.5)):
			return false
	var rider: Rat = m.rat_by_id(mc.operator) if mc.operator != -1 else null
	for r in m.rats:
		if r.overlaps_cell(dest):
			return false
	var delta := Vector3(dest - mc.cell)
	_moving = true
	w.set_block(mc.cell, Blocks.AIR)
	machines.erase(mc.cell)
	mc.cell = dest
	machines[dest] = mc
	w.set_block(dest, mc.kind)
	_moving = false
	mc.move_cd = time
	if rider != null and not rider.blocked_at(rider.position + delta):
		rider.position += delta   # the operator rides along
	return true


func _swing(mc: Machine, dt: float) -> void:
	## Damped pendulum, integrated in small fixed slices. The ball damages
	## what it touches in proportion to its speed, then rebounds.
	var slices := 3
	var h := dt / float(slices)
	for i in slices:
		mc.omega += (-(SHOT_GRAVITY / CRANE_CABLE) * sin(mc.theta) - 0.22 * mc.omega) * h
		var before := mc.theta
		mc.theta = clampf(mc.theta + mc.omega * h, -1.45, 1.45)
		if absf(mc.omega) < 0.25:
			continue
		var ball := ball_pos(mc)
		var fwd := Vector3(-sin(mc.yaw), 0, -cos(mc.yaw))
		var tangent := (fwd * cos(mc.theta) + Vector3.UP * sin(mc.theta)) * signf(mc.omega)
		var probe := ball + tangent * BALL_RADIUS
		var speed := absf(mc.omega) * CRANE_CABLE
		if m.world.solid_point(probe):
			var cell := Vector3i(floori(probe.x), floori(probe.y), floori(probe.z))
			if cell != mc.cell:
				var hits := clampi(int(speed / 2.4), 0, Config.CRANE_MAX_HIT)
				var id := m.world.get_cell(cell)
				if hits > 0 and not m._damage(m.rat_by_id(mc.owner), cell, hits, true):
					m.fx.emit("hit", Vector3(cell), {"id": id, "ratio": float(m.world.damage.get(cell, 0)) / maxf(1.0, float(Blocks.HITS[id]))})
				elif hits > 0:
					m.fx.emit("break", Vector3(cell), id)
				m.fx.emit("thud", ball, speed)
			mc.theta = before
			mc.omega = -mc.omega * 0.35
			continue
		if speed > 2.5:
			for r in m.rats:
				if r.team != mc.team and r.knock <= 0.0 and r.center().distance_to(ball) < BALL_RADIUS + 0.45:
					r.vel = tangent * minf(speed, 9.0) + Vector3(0, 5.0, 0)
					r.knock = 0.5
					r.on_floor = false
					if r.carried > 0:
						m._drop(r, 1, Config.BONK_PICKUP_LOCK)
					m.fx.emit("bonk", r.position, null)


func _fly(s: Shot, dt: float) -> bool:
	## Returns true when the shot is spent.
	s.life -= dt
	if s.life <= 0.0:
		return true
	var steps := maxi(1, ceili(s.vel.length() * dt / 0.25))
	var h := dt / float(steps)
	for i in steps:
		s.vel.y -= SHOT_GRAVITY * h
		s.pos += s.vel * h
		if s.pos.y < -4.0:
			return true
		for r in m.rats:
			if r.team != s.team and r.center().distance_to(s.pos) < 0.6:
				r.vel = s.vel.normalized() * 8.0 + Vector3(0, 5.0, 0)
				r.knock = 0.5
				r.on_floor = false
				if r.carried > 0:
					m._drop(r, 1, Config.BONK_PICKUP_LOCK)
				m.fx.emit("bonk", r.position, null)
				return true
		if m.world.solid_point(s.pos):
			_impact(s)
			return true
	return false


func _impact(s: Shot) -> void:
	var cell := Vector3i(floori(s.pos.x), floori(s.pos.y), floori(s.pos.z))
	var shooter := m.rat_by_id(s.owner)
	m.fx.emit("impact", s.pos, m.world.get_cell(cell))
	# 3x dig damage to the struck block...
	m._damage(shooter, cell, Config.CANNON_HIT, true)
	# ...and one hit each to the four blocks around it, in the plane the shot struck
	var a := s.vel.abs()
	var ring: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	if a.y >= a.x and a.y >= a.z:
		ring = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	elif a.z >= a.x:
		ring = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
	for n in ring:
		m._damage(shooter, cell + n, 1, true)


# ---------------------------------------------------------------- persistence

func to_save() -> Array:
	var out := []
	for mc: Machine in machines.values():
		out.append({"kind": mc.kind, "cell": mc.cell, "team": mc.team, "owner": mc.owner, "yaw": mc.yaw, "pitch": mc.pitch})
	return out


func from_save(list: Variant) -> void:
	## Rebuilds machine records after a map load; ignores anything malformed
	## or not backed by a matching machine block in the grid.
	machines.clear()
	shots.clear()
	for r in m.rats:
		r.operating = -1
	if list is Array:
		for e: Variant in list:
			if not (e is Dictionary) or not (e.get("cell") is Vector3i) or not (e.get("kind") is int):
				continue
			var cell: Vector3i = e["cell"]
			if not VoxelWorld.in_bounds(cell) or m.world.get_cell(cell) != int(e["kind"]) or not Blocks.is_machine(int(e["kind"])):
				continue
			var mc := Machine.new()
			mc.uid = m.take_uid()
			mc.kind = int(e["kind"])
			mc.cell = cell
			mc.team = clampi(int(e.get("team", 0)), 0, 1)
			mc.owner = int(e.get("owner", -1))
			mc.yaw = float(e.get("yaw", 0.0))
			mc.pitch = float(e.get("pitch", 0.35))
			machines[cell] = mc
	# a machine block without a record would be an unusable ghost: remove it
	for id: int in [Blocks.CANNON, Blocks.CRANE, Blocks.DOZER]:
		for cell2: Vector3i in m._find_blocks(id):
			if not machines.has(cell2):
				m.world.set_block(cell2, Blocks.AIR)
