class_name Rat
extends Node3D
## One rat: authoritative state + kinematic movement against the voxel grid.
## The same body is driven by the PlayerController or by a BotBrain through
## the "intent" fields, so humans and bots obey exactly the same rules.
## Movement is a small custom AABB solver rather than engine physics: it is
## deterministic, cheap, immune to mesh-collider rebuild hitches when terrain
## changes, and can be fast-forwarded by the headless tests.

const RADIUS := 0.3
const HEIGHT := 0.9
const GRAVITY := 24.0
const JUMP_SPEED := 8.3
const DOUBLE_JUMP_SPEED := 7.6
const DASH_SPEED := 14.0
const SPRING_SPEED := 15.5

# identity
var id := 0
var team := 0
var class_id := "digger"
var cls: Dictionary = {}
var is_bot := false
var display_name := "Rat"

# authoritative state
var vel := Vector3.ZERO
var yaw := 0.0
var on_floor := false
var on_ladder := false
var in_water := false
var flying := false
var stamina := 100.0
var carried := 0
var scrap := 0
var mats := {"dirt": 0, "stone": 0, "ice": 0, "obsidian": 0}
var gadgets: Dictionary = {}
var equipped := ""
var raid_t := 0.0
var ice_t := 0.0
var kits_claimed: Dictionary = {}
var class_cd := 0.0
var micro_bank: Dictionary = {}   # material -> spare microvoxels (343 = one block)
var chisel_cd := 0.0
var throw_cd := 0.0
var operating := -1               # uid of the siege machine this rat controls
var jumps_left := 1
var lava_strikes := 0             # 1 after a first lava bounce; the next touch sends you home
var lava_reset := 0.0             # seconds until a first strike is forgiven
var lava_grace := 0.0             # no second strike while still bouncing out
var lava_home := -1.0             # >= 0: heading home in this many seconds

# timers (seconds remaining)
var dig_cd := 0.0
var bonk_cd := 0.0
var stun := 0.0
var slow := 0.0
var knock := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var ability_cd := [0.0, 0.0]

# intent, written by the controller each tick
var wish := Vector3.ZERO
var jump_pressed := false
var jump_held := false
var down_held := false
var dash_pressed := false

# networking (see scripts/net): on the server, the peer that drives this rat
# (0 = local player or bot); on a client, true for the one rat it controls
var net_peer := 0
var net_local := false
var net_pre: Array = []           # server: movement state before this tick, to spot authority changes
var net_kick := 0                 # server: bumped whenever the authority moved this rat itself

# presentation hooks (read by RatSprite)
var anim_action := ""
var anim_action_t := 0.0
var landed_on_spring := false

var _world: VoxelWorld


func setup(world: VoxelWorld, rat_id: int, rat_team: int, rat_class: String, bot: bool) -> void:
	_world = world
	id = rat_id
	team = rat_team
	is_bot = bot
	set_class(rat_class, true)


func set_class(new_class: String, give_kit: bool) -> void:
	class_id = new_class
	cls = ClassDefs.CLASSES[new_class]
	stamina = minf(stamina, max_stamina()) if not give_kit else max_stamina()
	if give_kit and not kits_claimed.has(new_class):
		kits_claimed[new_class] = true  # a starter kit is granted once per class per match
		var kit: Dictionary = cls["kit"]
		for g: String in kit:
			gadgets[g] = maxi(int(gadgets.get(g, 0)), int(kit[g]))
		if equipped == "" and not kit.is_empty():
			equipped = kit.keys()[0]


func max_stamina() -> float:
	return float(cls["stamina"])


func capacity() -> int:
	return int(cls["carry"])


func eye() -> Vector3:
	return position + Vector3(0, 0.7, 0)


func center() -> Vector3:
	return position + Vector3(0, HEIGHT * 0.5, 0)


func feet_cell() -> Vector3i:
	return Vector3i(floori(position.x), floori(position.y + 0.05), floori(position.z))


func play_action(action: String, time := 0.3) -> void:
	anim_action = action
	anim_action_t = time


func move_speed() -> float:
	var s := Config.BASE_SPEED * float(cls["speed"])
	if carried > 0:
		s *= float(Config.CARRY_SPEED[mini(carried, Config.CARRY_SPEED.size() - 1)])
	if slow > 0.0:
		s *= 0.5
	if in_water:
		s *= float(cls["water"])
	if on_floor and _world.block_at(position + Vector3(0, 0.05, 0)) == Blocks.HIGHWAY:
		s *= 1.6
	return s


# ---------------------------------------------------------------- simulation

func step(dt: float) -> void:
	step_timers(dt)
	_step_motion(dt)


func step_timers(dt: float) -> void:
	## Cooldowns and status timers. A networked server runs only this part
	## for a remote player's rat: that player's own game moves the body.
	dig_cd = maxf(0.0, dig_cd - dt)
	bonk_cd = maxf(0.0, bonk_cd - dt)
	stun = maxf(0.0, stun - dt)
	slow = maxf(0.0, slow - dt)
	knock = maxf(0.0, knock - dt)
	dash_t = maxf(0.0, dash_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	class_cd = maxf(0.0, class_cd - dt)
	chisel_cd = maxf(0.0, chisel_cd - dt)
	throw_cd = maxf(0.0, throw_cd - dt)
	anim_action_t = maxf(0.0, anim_action_t - dt)
	ability_cd[0] = maxf(0.0, ability_cd[0] - dt)
	ability_cd[1] = maxf(0.0, ability_cd[1] - dt)


func _step_motion(dt: float) -> void:
	landed_on_spring = false

	var w := wish
	w.y = 0.0
	if w.length() > 1.0:
		w = w.normalized()
	if stun > 0.0:
		w = Vector3.ZERO
		jump_pressed = false
		jump_held = false
		dash_pressed = false

	var body_id := _world.block_at(center())
	in_water = body_id == Blocks.WATER
	# feet in water but chest out: at the surface, able to hop onto the bank
	var wading := not in_water and _world.block_at(position + Vector3(0, 0.1, 0)) == Blocks.WATER
	on_ladder = not flying and (body_id == Blocks.LADDER or _world.block_at(position + Vector3(0, 0.1, 0)) == Blocks.LADDER)
	var floor_id := _world.block_at(position - Vector3(0, 0.1, 0)) if on_floor else Blocks.AIR
	var speed := move_speed()
	var target := w * speed
	ice_t = 0.45 if floor_id == Blocks.ICE else maxf(0.0, ice_t - dt)

	if flying:
		vel = target * 2.2
		vel.y = (9.0 if jump_held else 0.0) - (9.0 if down_held else 0.0)
		position += vel * dt
		position.x = clampf(position.x, 0.5, VoxelWorld.SX - 0.5)
		position.z = clampf(position.z, 0.5, VoxelWorld.SZ - 0.5)
		position.y = clampf(position.y, 1.0, VoxelWorld.SY + 20.0)
		on_floor = false
		_clear_edges()
		return

	# horizontal control
	var accel := 60.0
	if knock > 0.0 or dash_t > 0.0:
		accel = 2.0
	elif ice_t > 0.0:
		accel = 5.0     # on ice, and for a moment after sliding off its end
	elif not on_floor and not on_ladder and not in_water:
		accel = 22.0
	var hv := Vector3(vel.x, 0, vel.z).move_toward(target * (0.6 if on_ladder else 1.0), accel * dt)
	vel.x = hv.x
	vel.z = hv.z

	# vertical control
	if on_ladder:
		vel.y = 0.0
		if jump_held:
			vel.y = 4.2
		elif down_held:
			vel.y = -4.2
		jumps_left = 1
	elif in_water:
		vel.y = move_toward(vel.y, 3.6 if jump_held else -2.0, 20.0 * dt)
		jumps_left = 1
		if jump_pressed and _world.block_at(position + Vector3(0, HEIGHT + 0.3, 0)) != Blocks.WATER:
			vel.y = JUMP_SPEED      # kick off just under the surface
	else:
		vel.y -= GRAVITY * dt
		if wading and (jump_pressed or jump_held) and vel.y < 3.7:
			vel.y = JUMP_SPEED      # leap out of the water instead of bobbing at the surface
			jumps_left = 1
		elif jump_pressed:
			if on_floor:
				vel.y = JUMP_SPEED
				jumps_left = 1
				on_floor = false
			elif jumps_left > 0 and stamina >= Config.DOUBLE_JUMP_COST:
				vel.y = DOUBLE_JUMP_SPEED
				jumps_left -= 1
				stamina -= Config.DOUBLE_JUMP_COST
		vel.y = maxf(vel.y, -30.0)

	# dash: a burst along the wish direction (or facing when standing still)
	if dash_pressed and dash_cd <= 0.0 and stamina >= Config.DASH_COST:
		var dir := w.normalized() if w.length() > 0.1 else Vector3(-sin(yaw), 0, -cos(yaw))
		vel.x = dir.x * DASH_SPEED
		vel.z = dir.z * DASH_SPEED
		vel.y = maxf(vel.y, 2.5)
		stamina -= Config.DASH_COST
		dash_t = 0.16
		dash_cd = 0.6
	elif dash_t <= 0.0:
		stamina = minf(max_stamina(), stamina + Config.STAMINA_REGEN * dt)

	var motion := vel * dt
	if Blocks.is_conveyor(floor_id):
		motion += Blocks.conveyor_dir(floor_id) * 3.0 * dt
	_move(motion)
	_clear_edges()


func _clear_edges() -> void:
	jump_pressed = false
	dash_pressed = false


func _move(motion: Vector3) -> void:
	if blocked():
		unstick()
	var steps := maxi(1, ceili(motion.length() / 0.3))
	var part := motion / float(steps)
	var grounded := on_floor
	on_floor = false
	for i in steps:
		# Y
		var old := position.y
		position.y += part.y
		if blocked():
			position.y = _settle(1, old, position.y)
			if part.y <= 0.0:
				on_floor = true
				grounded = true
				if _world.block_at(position - Vector3(0, 0.1, 0)) == Blocks.SPRING:
					vel.y = SPRING_SPEED
					landed_on_spring = true
					on_floor = false
					jumps_left = 1
				else:
					vel.y = 0.0
					jumps_left = 1
			else:
				vel.y = 0.0
			part.y = 0.0
		# X then Z, each with a small-step climb of up to four microvoxels
		for axis: int in [0, 2]:
			if part[axis] == 0.0:
				continue
			old = position[axis]
			position[axis] += part[axis]
			if not blocked():
				continue
			if grounded and vel.y <= 0.5 and _step_up():
				continue
			var dir := signf(part[axis])
			position[axis] = _settle(axis, old, position[axis])
			var probe := position
			probe[axis] += dir * (RADIUS + 0.12)
			if _world.block_at(probe + Vector3(0, 0.25, 0)) == Blocks.WALL_SPRING or _world.block_at(probe + Vector3(0, 0.75, 0)) == Blocks.WALL_SPRING:
				vel[axis] = -dir * 13.0
				vel.y = 5.5
				knock = 0.35
				landed_on_spring = true
			else:
				vel[axis] = 0.0
			part[axis] = 0.0


func _settle(axis: int, good: float, bad: float) -> float:
	## Bisect between the last free position and the blocked one, so the body
	## comes to rest flush against full blocks and carved microvoxels alike.
	for i in 8:
		var mid := (good + bad) * 0.5
		position[axis] = mid
		if blocked():
			bad = mid
		else:
			good = mid
	return good


func _step_up() -> bool:
	## Automatic climb over ledges up to four microvoxels (4/7 of a block).
	for k in range(1, 5):
		var lift := float(k) / float(Blocks.MICRO) + 0.01
		if not blocked_at(position + Vector3(0, lift, 0)):
			position.y += lift
			return true
	return false


func blocked() -> bool:
	return blocked_at(position)


func blocked_at(p: Vector3) -> bool:
	var mn := Vector3(p.x - RADIUS, p.y + 0.001, p.z - RADIUS)
	var mx := Vector3(p.x + RADIUS, p.y + HEIGHT - 0.001, p.z + RADIUS)
	var layered := not _world.gates.is_empty()
	for y in range(floori(mn.y), floori(mx.y) + 1):
		for z in range(floori(mn.z), floori(mx.z) + 1):
			for x in range(floori(mn.x), floori(mx.x) + 1):
				if layered and int(_world.gates.get(Vector3i(x, y, z), team)) != team:
					return true   # the other team's gate, with a gadget inside it
				if not Blocks.solid_for(_world.get_block(x, y, z), team):
					continue
				var c := Vector3i(x, y, z)
				if not _world.has_micro(c) or _world.micro_box_hit(c, mn, mx):
					return true
	return false


func overlaps_cell(c: Vector3i) -> bool:
	return c.x + 1 > position.x - RADIUS and c.x < position.x + RADIUS \
		and c.z + 1 > position.z - RADIUS and c.z < position.z + RADIUS \
		and c.y + 1 > position.y + 0.001 and c.y < position.y + HEIGHT


func unstick() -> void:
	## Safety net: if terrain appeared on top of us, rise to the first free spot.
	var tries := 0
	while blocked() and tries < 60:
		position.y = floorf(position.y) + 1.0
		tries += 1
