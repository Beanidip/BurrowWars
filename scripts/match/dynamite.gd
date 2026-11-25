class_name DynamiteSystem
extends RefCounted
## Mobile TNT: small bouncing dynamite sticks. Each stick is a point mass
## simulated by the authority against the voxel grid (carvings included), so
## the result is identical wherever it is replayed. Sticks react to springs,
## conveyors, ice, wall springs, sticky traps, mouse traps and pitfalls, and
## explode through Match.blast() - the same rule stationary TNT uses.
##
## Impulse Grenades fly the same way but stick to the first thing they touch
## (terrain or a rat) and go off Config.IMPULSE_FUSE s later through
## Match.impulse_blast(): no damage of any kind, only a shove that throws
## rats, loose cheese, dynamite and wind-ups away from it.

const RADIUS := 0.14
const GRAVITY := 20.0
const BOUNCE := 0.5
const WALL_BOUNCE := 0.55


class Stick:
	var uid := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var fuse := 3.0
	var owner := -1
	var resting := false
	var spring_cd := 0.0
	var impulse := false       # an Impulse Grenade
	var stuck := false         # (impulse) stuck where it hit
	var age := 0.0
	var stuck_to: Rat = null   # (impulse, authority) the rat it stuck to
	var stuck_at := Vector3.ZERO


var m: Match
var sticks: Array[Stick] = []
var _rng := RandomNumberGenerator.new()


func _init(p_match: Match) -> void:
	m = p_match
	_rng.seed = 90210


func try_throw(rat: Rat, look: Vector3, gentle: bool, kind := "dynamite") -> String:
	if m.over or rat.stun > 0.0:
		return "Can't throw right now"
	if rat.throw_cd > 0.0:
		return "wait"
	if not m.unlimited() and int(rat.gadgets.get(kind, 0)) <= 0:
		return "Out of %s" % ClassDefs.GADGET_NAME.get(kind, kind)
	if sticks.size() >= Config.DYNAMITE_MAX_ACTIVE:
		return "Too much dynamite in the air already"
	var dir := look.normalized() if look.length() > 0.01 else Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
	var start := rat.eye() + dir * 0.45
	if m.world.solid_point(start):
		start = rat.eye()
	if not m.unlimited():
		rat.gadgets[kind] = int(rat.gadgets[kind]) - 1
	rat.throw_cd = 0.5
	var speed := 2.0 if gentle else Config.DYNAMITE_THROW_SPEED
	var vel := dir * speed + Vector3(0, 0.5 if gentle else 2.5, 0) + rat.vel * 0.4
	if gentle and kind == "impulse":
		# set right at your feet: the way to launch yourself
		var flat := Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.ZERO
		start = rat.position + flat * 0.2 + Vector3(0, 0.15, 0)
		vel = Vector3(0, -1.0, 0)
	var s := spawn(start, vel, rat.id, Config.IMPULSE_FLIGHT if kind == "impulse" else -1.0)
	s.impulse = kind == "impulse"
	rat.play_action("use", 0.3)
	m.fx.emit("throw", start, null)
	return ""


func spawn(pos: Vector3, vel: Vector3, owner_id: int, fuse := -1.0) -> Stick:
	var s := Stick.new()
	s.uid = m.take_uid()
	s.pos = pos
	s.vel = vel
	s.owner = owner_id
	s.fuse = Config.DYNAMITE_FUSE if fuse < 0.0 else fuse
	sticks.append(s)
	return s


func on_blast(origin: Vector3, radius: float) -> void:
	## Other sticks caught in a blast are thrown and go off a moment later.
	for s in sticks:
		var d := s.pos - origin
		if d.length() < radius + 0.8:
			s.fuse = minf(s.fuse, 0.2 + 0.05 * float(s.uid % 4))
			if s.stuck:
				continue
			s.vel = (d.normalized() if d.length() > 0.05 else Vector3.UP) * 6.0 + Vector3(0, 4.0, 0)
			s.resting = false


func step(dt: float) -> void:
	var due: Array[Stick] = []
	for s in sticks:
		s.fuse -= dt
		s.age += dt
		s.spring_cd = maxf(0.0, s.spring_cd - dt)
		if s.impulse:
			_simulate_impulse(s, dt)
		else:
			_simulate(s, dt)
		if s.fuse <= 0.0 or s.pos.y < -6.0:
			due.append(s)
	for s in due:
		sticks.erase(s)
		if s.pos.y < -6.0:
			continue
		if s.impulse:
			m.impulse_blast(s.pos)
		else:
			m.tally(m.rat_by_id(s.owner), "tnt")
			m.blast(s.pos, Config.DYNAMITE_RADIUS, Config.DYNAMITE_POWER)


func _simulate_impulse(s: Stick, dt: float) -> void:
	## Fly until it touches terrain or a rat, then hold on there.
	if s.stuck:
		if s.stuck_to != null and is_instance_valid(s.stuck_to):
			s.pos = s.stuck_to.position + s.stuck_at
		return
	var w := m.world
	if w.block_at(s.pos) == Blocks.WATER:
		s.vel *= maxf(0.0, 1.0 - 2.5 * dt)
	s.vel.y = maxf(s.vel.y - GRAVITY * m.gravity() * dt, -30.0)
	var steps := maxi(1, ceili(s.vel.length() * dt / 0.09))
	var h := dt / float(steps)
	for i in steps:
		var np := s.pos + s.vel * h
		var lead := np + s.vel.normalized() * RADIUS if s.vel.length() > 0.01 else np
		if w.solid_point(lead) or w.block_at(lead) == Blocks.LAVA:
			_stick(s, null)
			return
		s.pos = np
		for r in m.rats:
			if (r.id != s.owner or s.age > 0.25) and r.center().distance_to(s.pos) < 0.55:
				_stick(s, r)
				return


func _stick(s: Stick, r: Rat) -> void:
	s.stuck = true
	s.resting = true
	s.vel = Vector3.ZERO
	s.stuck_to = r
	if r != null:
		s.stuck_at = s.pos - r.position
	s.fuse = minf(s.fuse, Config.IMPULSE_FUSE)
	m.fx.emit("impulse_stick", s.pos, null)


func _simulate(s: Stick, dt: float) -> void:
	var w := m.world
	var here := w.block_at(s.pos)
	if here == Blocks.LAVA:
		s.fuse = minf(s.fuse, 0.05)
		return
	if Blocks.is_sticky(here):
		# glue: bleeds off speed fast until the stick sits still
		s.vel.x = move_toward(s.vel.x, 0.0, 30.0 * dt)
		s.vel.z = move_toward(s.vel.z, 0.0, 30.0 * dt)
		s.vel.y = minf(s.vel.y, 0.0)
	elif Blocks.is_trap(here):
		# the trap snaps shut on the stick and kicks it away
		w.set_block(Vector3i(floori(s.pos.x), floori(s.pos.y), floori(s.pos.z)), Blocks.AIR)
		var ang := _rng.randf() * TAU
		s.vel = Vector3(cos(ang) * 4.5, 7.5, sin(ang) * 4.5)
		s.resting = false
		m.fx.emit("trap", s.pos, null)
	elif here == Blocks.WATER:
		s.vel *= maxf(0.0, 1.0 - 2.5 * dt)
	s.vel.y = maxf(s.vel.y - GRAVITY * m.gravity() * dt, -30.0)
	var steps := maxi(1, ceili(s.vel.length() * dt / 0.09))
	var h := dt / float(steps)
	for i in steps:
		# vertical
		var ny := s.pos.y + s.vel.y * h
		var foot := Vector3(s.pos.x, ny + (RADIUS if s.vel.y > 0.0 else -RADIUS), s.pos.z)
		if w.solid_point(foot):
			if s.vel.y < 0.0:
				_touch_ground(s, w.block_at(foot), h)
			else:
				s.vel.y = -s.vel.y * 0.3
		else:
			s.pos.y = ny
		# horizontal, one axis at a time so it deflects off walls
		for axis: int in [0, 2]:
			var v: float = s.vel[axis]
			if v == 0.0:
				continue
			var np := s.pos
			np[axis] += v * h
			var lead := np
			lead[axis] += signf(v) * RADIUS
			if w.solid_point(lead):
				if w.block_at(lead) == Blocks.WALL_SPRING:
					s.vel[axis] = -signf(v) * 12.0
					s.vel.y = maxf(s.vel.y, 4.5)
					m.fx.emit("spring", s.pos, null)
				else:
					s.vel[axis] = -v * WALL_BOUNCE
			else:
				s.pos = np


func _touch_ground(s: Stick, floor_id: int, h: float) -> void:
	if floor_id == Blocks.SPRING and s.spring_cd <= 0.0:
		s.vel.y = 13.0
		s.spring_cd = 0.25
		s.resting = false
		m.fx.emit("spring", s.pos, null)
		return
	var impact := -s.vel.y
	s.vel.y = impact * BOUNCE if impact > 2.2 else 0.0
	s.resting = s.vel.y == 0.0
	if impact > 3.0:
		m.fx.emit("tick", s.pos, null)
	# rolling friction: ice barely slows it, everything else does
	var grip := 0.4 if floor_id == Blocks.ICE else 7.0
	var flat := Vector3(s.vel.x, 0, s.vel.z)
	if Blocks.is_conveyor(floor_id):
		flat = flat.move_toward(Blocks.conveyor_dir(floor_id) * 3.0, 25.0 * h)
	else:
		flat = flat.move_toward(Vector3.ZERO, grip * h)
	s.vel.x = flat.x
	s.vel.z = flat.z
