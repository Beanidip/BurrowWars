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
var gear := ""                    # the one piece of gear worn ("" or a ClassDefs.GEAR id)
var gear_cd := 0.0
var gear_t := 0.0                 # jetpack thrust time left
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
var gear_pressed := false

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
var gear_fired := false           # this step started a jetpack burst
var dashed := false               # this step started a dash
var jumped := false               # this step left the ground (jump, double jump, leap out of water)
var landed_hard := false          # this step hit the ground after a long fall
var bubbles_on := false            # Bubble Shoes switched on (J)
var wants_bubble := false          # this step stepped off an edge: blow a bubble at bubble_cell
var bubble_cell := Vector3i.ZERO
var free_build := false            # Free Build: gear costs nothing
var _bubble_y := 0.0               # the level we stand at while a bubble is on its way
var _bubble_hold := 0.0
var _bubble_last := Vector3i(-1, -1, -1)
var shield_t := 0.0                # seconds the Rat Knight Shield stays raised
var shield_raised := false        # this step raised it
var pounded := false              # this step landed a full double jump flat: a ground pound
var pound_cell := Vector3i.ZERO    # the block it landed on
var pound_cd := 0.0                # (authority) seconds before another pound counts
var _dj_from := -1000.0            # height the current double jump started at (-1000 = none)
var _dj_peak := 0.0
var splashed_in := false          # this step dropped into water
var splashed_out := false         # this step jumped up out of water
var _was_wet := false
var _splash_cd := 0.0

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
		if shield_t > 0.0:
			s *= Config.SHIELD_CARRY_SPEED     # hauling cheese behind a raised shield
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
	gear_cd = maxf(0.0, gear_cd - dt)
	pound_cd = maxf(0.0, pound_cd - dt)
	shield_t = maxf(0.0, shield_t - dt)
	# An enemy sticky trap underfoot keeps you slowed. This lives here, not in
	# Match's hazards, because both the server and a remote player's own game
	# run it: they then agree on `slow`, and the server has nothing to correct.
	var under := _world.block_at(position + Vector3(0, 0.2, 0))
	if Blocks.is_sticky(under) and (0 if under == Blocks.STICKY_BLUE else 1) != team and not flying:
		slow = maxf(slow, 1.2)


func _step_motion(dt: float) -> void:
	landed_on_spring = false
	gear_fired = false
	dashed = false
	jumped = false
	landed_hard = false
	pounded = false
	shield_raised = false
	wants_bubble = false
	splashed_in = false
	splashed_out = false

	var w := wish
	w.y = 0.0
	if w.length() > 1.0:
		w = w.normalized()
	if stun > 0.0:
		w = Vector3.ZERO
		jump_pressed = false
		jump_held = false
		dash_pressed = false
		gear_pressed = false

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
			jumped = true
		elif jump_pressed:
			if on_floor:
				vel.y = JUMP_SPEED
				jumps_left = 1
				on_floor = false
				jumped = true
			elif jumps_left > 0 and stamina >= Config.DOUBLE_JUMP_COST:
				vel.y = DOUBLE_JUMP_SPEED
				jumps_left -= 1
				stamina -= Config.DOUBLE_JUMP_COST
				jumped = true
				_dj_from = position.y
				_dj_peak = position.y
		vel.y = maxf(vel.y, -30.0)

	# dash: a burst along the wish direction (or facing when standing still)
	# gear: the jetpack lifts you for a moment, then needs to cool down
	if gear_pressed and gear == "jetpack" and gear_cd <= 0.0:
		gear_t = Config.JETPACK_TIME
		gear_cd = Config.JETPACK_TIME + Config.JETPACK_COOLDOWN
		gear_fired = true
		play_action("jump", Config.JETPACK_TIME)
	if gear_pressed and gear == "bubbles":
		bubbles_on = not bubbles_on
	if gear_pressed and gear == "shield" and gear_cd <= 0.0:
		shield_t = Config.SHIELD_TIME
		gear_cd = Config.SHIELD_TIME + Config.SHIELD_COOLDOWN
		shield_raised = true
		play_action("use", 0.3)
	if gear_t > 0.0:
		gear_t = maxf(0.0, gear_t - dt)
		vel.y = maxf(vel.y, Config.JETPACK_LIFT * (Config.JETPACK_CARRY if carried > 0 else 1.0))
		_dj_from = -1000.0      # a jetpack flight is no double jump
		on_ladder = false
		jumps_left = 1

	var dash_cost := Config.DASH_CARRY_COST if carried > 0 else Config.DASH_COST
	if dash_pressed and dash_cd <= 0.0 and stamina >= dash_cost:
		var dir := w.normalized() if w.length() > 0.1 else Vector3(-sin(yaw), 0, -cos(yaw))
		# hauling cheese: a weaker burst the more you carry, and it costs more
		var burst := DASH_SPEED * float(Config.DASH_CARRY[mini(carried, Config.DASH_CARRY.size() - 1)])
		vel.x = dir.x * burst
		vel.z = dir.z * burst
		vel.y = maxf(vel.y, 2.5)
		stamina -= dash_cost
		dash_t = 0.16
		dash_cd = 0.6
		dashed = true
	elif dash_t <= 0.0:
		stamina = minf(max_stamina(), stamina + Config.STAMINA_REGEN * dt)

	var motion := vel * dt
	if Blocks.is_conveyor(floor_id):
		motion += Blocks.conveyor_dir(floor_id) * 3.0 * dt
	var was_airborne := not on_floor
	var fall_speed := vel.y
	var y_before := position.y
	_move(motion)
	_bubble_check(not was_airborne, y_before, dt)
	if was_airborne and on_floor and fall_speed < -11.0:
		landed_hard = true
	_pound_check(was_airborne, fall_speed)
	_splash_check(fall_speed, dt)
	_spring_sides()
	_clear_edges()


func _bubble_check(was_on_floor: bool, y_before: float, dt: float) -> void:
	## Bubble Shoes: stepping off an edge (not jumping, not already falling)
	## asks for a bubble under our feet and holds us level until it is there.
	## Online the server makes the bubble, so we hold for a moment while it
	## arrives; if it never does (no scrap), we fall after all.
	_bubble_hold = maxf(0.0, _bubble_hold - dt)
	if on_floor:
		_bubble_last = Vector3i(-1, -1, -1)    # real ground: any cell may be asked for again
		return
	if not bubbles_on or gear != "bubbles" or in_water or on_ladder or flying or jumped or vel.y > 0.0:
		return
	var holding := _bubble_hold > 0.0 and absf(position.y - _bubble_y) < 0.6
	if not was_on_floor and not holding:
		return            # a jump or a drop already under way: the shoes only catch a step off an edge
	var level := _bubble_y if holding else y_before
	var cell := Vector3i(floori(position.x), floori(level + 0.01) - 1, floori(position.z))
	if _world.get_cell(cell) != Blocks.AIR:
		return
	if cell == _bubble_last and not holding:
		return            # we asked for this one and it never came (refused): fall after all
	if cell != _bubble_last:
		if not free_build and scrap < Config.BUBBLE_COST:
			return        # out of scrap: an ordinary step off the edge, and down we go
		wants_bubble = true
		bubble_cell = cell
		_bubble_last = cell
		_bubble_hold = 0.3
		if net_local and not free_build:
			scrap -= Config.BUBBLE_COST   # online: count it now; the server's tally follows
	_bubble_y = level
	position.y = level
	vel.y = 0.0
	on_floor = true


func _pound_check(was_airborne: bool, fall_speed: float) -> void:
	## A double jump taken (nearly) to its full height and landed flat on a
	## block thumps that block like a dig. Ceilings, ladders, water, springs
	## and jetpacks spoil it.
	if _dj_from < -999.0:
		return
	if on_ladder or in_water or flying or landed_on_spring:
		_dj_from = -1000.0
		return
	if not on_floor:
		_dj_peak = maxf(_dj_peak, position.y)
		return
	var full := DOUBLE_JUMP_SPEED * DOUBLE_JUMP_SPEED / (2.0 * GRAVITY)
	if was_airborne and fall_speed <= -6.0 and _dj_peak - _dj_from >= Config.POUND_HEIGHT * full:
		pounded = true
		pound_cell = Vector3i(floori(position.x), floori(position.y - 0.1), floori(position.z))
	_dj_from = -1000.0


func _splash_check(fall_speed: float, dt: float) -> void:
	## Feet going into water from a drop, or leaping up out of it: a splash.
	## Bobbing at the surface or wading in from the bank makes none.
	var wet := _world.block_at(position + Vector3(0, 0.1, 0)) == Blocks.WATER
	_splash_cd = maxf(0.0, _splash_cd - dt)
	if wet != _was_wet and _splash_cd <= 0.0 and not flying:
		if wet and fall_speed < -4.0:
			splashed_in = true
		elif not wet and vel.y > 3.0:
			splashed_out = true
		if splashed_in or splashed_out:
			_splash_cd = 0.4
	_was_wet = wet


func _spring_sides() -> void:
	## A spring flings anything standing right next to it (within a block of
	## its sides), not only what lands on top: up, and away from the spring.
	if not on_floor or flying:
		return
	var f := feet_cell()
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var c := f + Vector3i(dx, 0, dz)
			if _world.get_cell(c) != Blocks.SPRING:
				continue
			var away := position - (Vector3(c) + Vector3(0.5, 0.0, 0.5))
			away.y = 0.0
			away = away.normalized() if away.length() > 0.05 else Vector3(-dx, 0, -dz).normalized()
			vel = away * 5.0 + Vector3(0, Config.SPRING_SIDE_SPEED, 0)
			knock = 0.3
			on_floor = false
			jumps_left = 1
			landed_on_spring = true
			return


func _clear_edges() -> void:
	jump_pressed = false
	dash_pressed = false
	gear_pressed = false


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
