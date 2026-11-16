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
var mats := {"dirt": 0, "stone": 0, "wood": 0, "ice": 0}
var gadgets: Dictionary = {}
var equipped := ""
var kits_claimed: Dictionary = {}
var class_cd := 0.0
var jumps_left := 1

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
		s *= Config.CARRY_SPEED_MULT
	if slow > 0.0:
		s *= 0.5
	if in_water:
		s *= float(cls["water"])
	if on_floor and _world.block_at(position - Vector3(0, 0.1, 0)) == Blocks.HIGHWAY:
		s *= 1.6
	return s


# ---------------------------------------------------------------- simulation

func step(dt: float) -> void:
	dig_cd = maxf(0.0, dig_cd - dt)
	bonk_cd = maxf(0.0, bonk_cd - dt)
	stun = maxf(0.0, stun - dt)
	slow = maxf(0.0, slow - dt)
	knock = maxf(0.0, knock - dt)
	dash_t = maxf(0.0, dash_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	class_cd = maxf(0.0, class_cd - dt)
	anim_action_t = maxf(0.0, anim_action_t - dt)
	ability_cd[0] = maxf(0.0, ability_cd[0] - dt)
	ability_cd[1] = maxf(0.0, ability_cd[1] - dt)
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
	on_ladder = not flying and (body_id == Blocks.LADDER or _world.block_at(position + Vector3(0, 0.1, 0)) == Blocks.LADDER)
	var floor_id := _world.block_at(position - Vector3(0, 0.1, 0)) if on_floor else Blocks.AIR
	var speed := move_speed()
	var target := w * speed

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
	elif floor_id == Blocks.ICE:
		accel = 5.0
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
	else:
		vel.y -= GRAVITY * dt
		if jump_pressed:
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
	var steps := maxi(1, ceili(motion.length() / 0.35))
	var part := motion / float(steps)
	on_floor = false
	for i in steps:
		# Y
		position.y += part.y
		if blocked():
			if part.y <= 0.0:
				position.y = floorf(position.y) + 1.0
				on_floor = true
				if _world.block_at(position - Vector3(0, 0.1, 0)) == Blocks.SPRING:
					vel.y = SPRING_SPEED
					landed_on_spring = true
					on_floor = false
					jumps_left = 1
				else:
					vel.y = 0.0
					jumps_left = 1
			else:
				position.y = floorf(position.y + HEIGHT) - HEIGHT - 0.001
				vel.y = 0.0
			part.y = 0.0
		# X
		position.x += part.x
		if blocked():
			if part.x > 0.0:
				position.x = floorf(position.x + RADIUS) - RADIUS - 0.001
			else:
				position.x = floorf(position.x - RADIUS) + 1.0 + RADIUS + 0.001
			vel.x = 0.0
			part.x = 0.0
		# Z
		position.z += part.z
		if blocked():
			if part.z > 0.0:
				position.z = floorf(position.z + RADIUS) - RADIUS - 0.001
			else:
				position.z = floorf(position.z - RADIUS) + 1.0 + RADIUS + 0.001
			vel.z = 0.0
			part.z = 0.0


func blocked() -> bool:
	return blocked_at(position)


func blocked_at(p: Vector3) -> bool:
	var x0 := floori(p.x - RADIUS)
	var x1 := floori(p.x + RADIUS)
	var y0 := floori(p.y + 0.001)
	var y1 := floori(p.y + HEIGHT - 0.001)
	var z0 := floori(p.z - RADIUS)
	var z1 := floori(p.z + RADIUS)
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				if Blocks.solid_for(_world.get_block(x, y, z), team):
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
