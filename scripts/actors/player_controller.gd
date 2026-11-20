class_name PlayerController
extends Node3D
## Human input -> rat intent + requests to the Match authority.
## Owns the camera (first / third person with terrain collision), the tool
## mode (dig / chisel / pantograph), the siege-machine control mode, and the
## team-coloured highlight on whatever the crosshair targets.

signal notice(text: String)

enum Tool { DIG, CHISEL, PANTOGRAPH }

var m: Match
var rat: Rat
var cam: Camera3D
var yaw := 0.0
var pitch := -0.25
var first_person := false
var cam_dist := 4.0
var selected_mat := 0            # 0..3 = stash materials, 4 = painted block
var selected_color := 0          # palette index for painted blocks / chisel dabs
var tool := Tool.DIG
var ui_open := false
var aim: Dictionary = {}
var tool_text := ""            # one-line status for the HUD

# pantograph state (the clipboard is local; pasting is validated by Match)
var corner_set := false
var corner := Vector3i.ZERO
var blueprint: Blueprint
var paste_error := ""

var edge_dir := Vector3.ZERO   # world direction of the bright edge of the target square

var _highlight: Node3D
var _edges: Array[MeshInstance3D] = []   # +X, -X, +Y, -Y in the square's own plane
var _edge_weak: StandardMaterial3D
var _edge_strong: StandardMaterial3D
var _select_box: MeshInstance3D
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _ghost_for: Blueprint
var _shake := 0.0


func _ready() -> void:
	process_physics_priority = -10   # write intent before Match steps the rats
	cam = Camera3D.new()
	cam.near = 0.08
	cam.far = 220.0
	add_child(cam)
	cam.make_current()
	apply_settings()
	yaw = rat.yaw
	var tc: Color = UiKit.TEAM[rat.team]
	# Target square: a see-through outline in team colour. The edge nearest
	# the crosshair is drawn solid; that is the way a conveyor will run.
	_highlight = Node3D.new()
	_edge_weak = _clear_mat(Color(tc.r, tc.g, tc.b, 0.3))
	_edge_strong = _clear_mat(Color(minf(tc.r + 0.25, 1.0), minf(tc.g + 0.25, 1.0), minf(tc.b + 0.25, 1.0), 0.95))
	_edge_weak.no_depth_test = false
	for i in 4:
		var bar := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var thick := 0.07
		quad.size = Vector2(thick, 1.0) if i < 2 else Vector2(1.0, thick)
		bar.mesh = quad
		var off := 0.5 - thick * 0.5
		bar.position = [Vector3(off, 0, 0), Vector3(-off, 0, 0), Vector3(0, off, 0), Vector3(0, -off, 0)][i]
		bar.material_override = _edge_weak
		_highlight.add_child(bar)
		_edges.append(bar)
	_highlight.visible = false
	add_child(_highlight)
	_select_box = MeshInstance3D.new()
	_select_box.mesh = BoxMesh.new()
	_select_box.material_override = _clear_mat(Color(tc.r, tc.g, tc.b, 0.22))
	_select_box.visible = false
	add_child(_select_box)
	_ghost = MeshInstance3D.new()
	_ghost_mat = _clear_mat(Color(0.5, 1.0, 0.5, 0.35))
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	add_child(_ghost)
	m.fx.connect(_on_fx)


static func _clear_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat


func _on_fx(kind: String, pos: Vector3, data: Variant) -> void:
	if kind == "boom":
		var d := pos.distance_to(rat.position)
		_shake = maxf(_shake, clampf(1.0 - d / (float(data) * 6.0), 0.0, 1.0) * 0.5)
	elif kind == "impact" or kind == "thud":
		_shake = maxf(_shake, clampf(1.0 - pos.distance_to(rat.position) / 10.0, 0.0, 1.0) * 0.15)


func apply_settings() -> void:
	cam.fov = float(Config.get_value("fov"))
	cam_dist = float(Config.get_value("camera_distance"))


func forward() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func machine() -> SiegeSystem.Machine:
	return m.siege.by_uid(rat.operating) if rat.operating != -1 else null


func _unhandled_input(event: InputEvent) -> void:
	if ui_open or m.over:
		return
	if event is InputEventJoypadMotion:
		return   # sticks are read every frame, triggers by their press (see _pad_triggers)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens := float(Config.get_value("mouse_sensitivity"))
		yaw -= mm.relative.x * sens
		var dy := mm.relative.y * sens
		pitch = clampf(pitch + (dy if bool(Config.get_value("invert_y")) else -dy), -1.5, 1.5)
		return
	if event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		var wheel := 0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel = -1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel = 1
		if wheel != 0:
			if mb.alt_pressed or Input.is_key_pressed(KEY_ALT):
				cam_dist = clampf(cam_dist + 0.4 * wheel, 1.5, 8.0)   # Alt + wheel: camera distance
			elif rat.operating == -1:
				cycle_gadget(wheel)                                  # wheel: scroll the Q slot
			return
	if event.is_action_pressed("interact"):
		_interact()
		return
	if rat.operating != -1:
		return   # at the controls: only aim, fire (polled) and leave
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if pad and tool == Tool.PANTOGRAPH and blueprint != null and _pad_blueprint(event):
		return
	if event.is_action_pressed("jump"):
		rat.jump_pressed = true
	elif event.is_action_pressed("dash"):
		# on a gamepad B also climbs down: on a ladder, in water or flying it doesn't dash
		if not (pad and (rat.on_ladder or rat.in_water or rat.flying)):
			rat.dash_pressed = true
	elif event.is_action_pressed("next_slot"):
		cycle_slot(1)
	elif event.is_action_pressed("prev_slot"):
		cycle_slot(-1)
	elif event.is_action_pressed("camera_toggle"):
		first_person = not first_person
	elif event.is_action_pressed("dig"):
		if tool == Tool.PANTOGRAPH:
			_pantograph_click()
	elif event.is_action_pressed("place"):
		_secondary()
	elif event.is_action_pressed("gadget"):
		_say(m.try_use_equipped(rat, aim, forward(), Input.is_action_pressed("descend"), edge_dir))
	elif event.is_action_pressed("cycle_gadget"):
		cycle_gadget()
	elif event.is_action_pressed("ability_1"):
		_say(m.use_ability(rat, 0, aim))
	elif event.is_action_pressed("ability_2"):
		_say(m.use_ability(rat, 1, aim))
	elif event.is_action_pressed("gear"):
		if rat.gear == "":
			_say("No gear yet - the workshop sells a Jetpack (Gear)")
		elif rat.gear_cd > 0.0:
			_say("%s recharging (%.0f s)" % [ClassDefs.GEAR.get(rat.gear, rat.gear), ceilf(rat.gear_cd)])
		else:
			rat.gear_pressed = true
	elif event.is_action_pressed("drop_cheese"):
		if not m.drop_cheese(rat, aim, forward()):
			_say("You aren't carrying any cheese")
	elif event.is_action_pressed("respawn"):
		if Input.is_key_pressed(KEY_CTRL):
			m.respawn(rat)
			_say("Back at base. Your cheese and materials stayed behind.")
	elif event.is_action_pressed("fly"):
		if bool(rat.cls["fly"]):
			rat.flying = not rat.flying
			_say("Flight ON - Space up, Ctrl down" if rat.flying else "Flight off")
	elif event.is_action_pressed("chisel"):
		tool = Tool.DIG if tool == Tool.CHISEL else Tool.CHISEL
		if tool == Tool.CHISEL:
			_say("Chisel: left mouse carves one microvoxel, right mouse adds one (uses the selected material)")
	elif event.is_action_pressed("pantograph"):
		if tool == Tool.PANTOGRAPH:
			tool = Tool.DIG
			corner_set = false
		else:
			tool = Tool.PANTOGRAPH
			_say("Pantograph: left-click two corners to copy, right-click to paste. %s rotates, %s mirrors, %s flips, %s inverts" % [
				Inputs.key_name("rotate_blueprint"), Inputs.key_name("mirror_blueprint"), Inputs.key_name("flip_blueprint"), Inputs.key_name("invert_blueprint")])
	elif tool == Tool.PANTOGRAPH and blueprint != null and event.is_action_pressed("rotate_blueprint"):
		blueprint = blueprint.rotated()
	elif tool == Tool.PANTOGRAPH and blueprint != null and event.is_action_pressed("mirror_blueprint"):
		blueprint = blueprint.mirrored()
		_say("Blueprint mirrored")
	elif tool == Tool.PANTOGRAPH and blueprint != null and event.is_action_pressed("flip_blueprint"):
		blueprint = blueprint.flipped()
		_say("Blueprint flipped upside down")
	elif tool == Tool.PANTOGRAPH and blueprint != null and event.is_action_pressed("invert_blueprint"):
		var inv := blueprint.inverted()
		if inv.cells.is_empty():
			_say("Inverting that would leave nothing to build")
		else:
			blueprint = inv
			_say("Blueprint inverted: now needs %s" % blueprint.cost_text())
	else:
		for i in ClassDefs.MATS.size() + 1:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				selected_mat = i
				if tool == Tool.PANTOGRAPH:
					tool = Tool.DIG


func _pad_blueprint(event: InputEvent) -> bool:
	## Holding a blueprint on a gamepad: D-pad Up rotates, D-pad Down mirrors,
	## LB flips it upside down and Y inverts it.
	if event.is_action_pressed("ability_1"):
		blueprint = blueprint.rotated()
	elif event.is_action_pressed("ability_2"):
		blueprint = blueprint.mirrored()
		_say("Blueprint mirrored")
	elif event.is_action_pressed("cycle_gadget"):
		blueprint = blueprint.flipped()
		_say("Blueprint flipped upside down")
	elif event.is_action_pressed("gear"):
		var inv := blueprint.inverted()
		if inv.cells.is_empty():
			_say("Inverting that would leave nothing to build")
		else:
			blueprint = inv
			_say("Blueprint inverted: now needs %s" % blueprint.cost_text())
	else:
		return false
	return true


func slot_index() -> int:
	## Where we are in the build slots: materials, paint, then chisel and pantograph.
	if tool == Tool.CHISEL:
		return ClassDefs.MATS.size() + 1
	if tool == Tool.PANTOGRAPH:
		return ClassDefs.MATS.size() + 2
	return selected_mat


func cycle_slot(step: int) -> void:
	## D-pad Left/Right on a gamepad: dirt, stone, ice, obsidian, paint, chisel, pantograph.
	var n := ClassDefs.MATS.size() + 3
	var i := posmod(slot_index() + step, n)
	if i <= ClassDefs.MATS.size():
		selected_mat = i
		tool = Tool.DIG
	elif i == ClassDefs.MATS.size() + 1:
		tool = Tool.CHISEL
		_say("Chisel: %s carves a microvoxel, %s adds one" % [Inputs.key_name("dig"), Inputs.key_name("place")])
	else:
		tool = Tool.PANTOGRAPH
		corner_set = false
		_say("Pantograph: %s marks two corners to copy, %s pastes" % [Inputs.key_name("dig"), Inputs.key_name("place")])


func painting() -> bool:
	return selected_mat >= ClassDefs.MATS.size()


func _interact() -> void:
	if rat.operating != -1:
		m.siege.release(rat)
		_say("You step away from the controls")
		return
	if not aim.is_empty() and Blocks.is_machine(int(aim["id"])):
		var why := m.siege.try_operate(rat, aim["cell"])
		if why == "":
			var mc := machine()
			yaw = mc.yaw
			pitch = mc.pitch
			_say("At the controls: mouse aims, left mouse works it, %s leaves" % Inputs.key_name("interact"))
		else:
			_say(why)
	else:
		_say("Look at one of your siege machines and press %s to operate it" % Inputs.key_name("interact"))


func _secondary() -> void:
	match tool:
		Tool.DIG:
			if not aim.is_empty():
				if painting():
					_say(m.try_place_paint(rat, _place_cell(), selected_color))
				else:
					_say(m.try_place_mat(rat, _place_cell(), ClassDefs.MATS[selected_mat]))
		Tool.CHISEL:
			if not aim.is_empty():
				var t := _micro_neighbor()
				if painting():
					_say(m.try_chisel_add(rat, t[0], t[1], "stone", selected_color))
				else:
					_say(m.try_chisel_add(rat, t[0], t[1], ClassDefs.MATS[selected_mat]))
		Tool.PANTOGRAPH:
			if blueprint == null:
				_say("Copy something first: left-click two corners")
			elif not aim.is_empty():
				var why := m.try_paste(rat, blueprint, paste_origin())
				_say(why if why != "" else "Structure built")


func _pantograph_click() -> void:
	if aim.is_empty():
		_say("Aim at a block to mark a corner")
		return
	if not corner_set:
		corner = aim["cell"]
		corner_set = true
		_say("First corner set. Click the opposite corner.")
		return
	corner_set = false
	var res := m.copy_region(rat, corner, aim["cell"])
	if res.has("error"):
		_say(res["error"])
		return
	blueprint = res["blueprint"]
	var note := "  (%d non-material blocks left out)" % blueprint.skipped if blueprint.skipped > 0 else ""
	_say("Copied %dx%dx%d: needs %s%s" % [blueprint.size.x, blueprint.size.y, blueprint.size.z, blueprint.cost_text(), note])


func paste_origin() -> Vector3i:
	## The blueprint sits on/against the aimed face, centred on the crosshair.
	var n := Vector3i(aim["normal"])
	var o := Vector3i(aim["cell"]) + n
	var s := blueprint.size
	o.x -= s.x / 2 if n.x == 0 else (s.x - 1 if n.x < 0 else 0)
	o.z -= s.z / 2 if n.z == 0 else (s.z - 1 if n.z < 0 else 0)
	if n.y < 0:
		o.y -= s.y - 1
	return o


func _micro_neighbor() -> Array:
	## [cell, micro] of the empty microvoxel touching the aimed face.
	var g := Vector3i(aim["cell"]) * Blocks.MICRO + Vector3i(aim["micro"]) + Vector3i(aim["normal"])
	var c := Vector3i(floori(g.x / float(Blocks.MICRO)), floori(g.y / float(Blocks.MICRO)), floori(g.z / float(Blocks.MICRO)))
	return [c, g - c * Blocks.MICRO]


func cycle_gadget(step := 1) -> void:
	var owned: Array[String] = []
	for g: String in ClassDefs.GADGETS:
		if m.unlimited() or int(rat.gadgets.get(g, 0)) > 0:
			owned.append(g)
	if owned.is_empty():
		_say("No gadgets yet - buy some at the workshop (B)")
		return
	var i := owned.find(rat.equipped)
	m.set_equipped(rat, owned[posmod(i + step, owned.size())] if i >= 0 else owned[0])


func _place_cell() -> Vector3i:
	return Vector3i(aim["cell"]) + Vector3i(aim["normal"])


func _say(text: String) -> void:
	if text != "" and text != "wait":
		notice.emit(text)


func _physics_process(_delta: float) -> void:
	if ui_open or m.over:
		rat.wish = Vector3.ZERO
		rat.jump_held = false
		rat.down_held = false
		return
	_pad_triggers()
	var firing := Input.is_action_pressed("dig") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if rat.operating != -1:
		rat.wish = Vector3.ZERO
		rat.jump_held = false
		rat.down_held = false
		m.siege.aim(rat, yaw, pitch)
		if firing:
			m.siege.fire(rat)
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	rat.wish = f * -input.y + r * input.x
	rat.yaw = yaw
	rat.jump_held = Input.is_action_pressed("jump")
	rat.down_held = Input.is_action_pressed("descend")
	if not firing:
		return
	if tool == Tool.DIG and rat.dig_cd <= 0.0:
		_swing()
	elif tool == Tool.CHISEL and rat.chisel_cd <= 0.0 and not aim.is_empty():
		_say(m.try_chisel_remove(rat, aim["cell"], aim["micro"]))


var _lt_down := false
var _rt_down := false


func _pad_triggers() -> void:
	## A trigger pull acts once, like a mouse click (holding RT keeps digging,
	## through the "dig" action like a held mouse button).
	var lt := Input.get_joy_axis(Inputs.pad_device, JOY_AXIS_TRIGGER_LEFT) > 0.5
	var rt := Input.get_joy_axis(Inputs.pad_device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	if lt and not _lt_down and rat.operating == -1:
		_secondary()
	if rt and not _rt_down and rat.operating == -1 and tool == Tool.PANTOGRAPH:
		_pantograph_click()
	_lt_down = lt
	_rt_down = rt


func _stick_look(delta: float) -> void:
	## The right stick turns the camera; squared response for fine aiming.
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look == Vector2.ZERO:
		return
	var curve := look * look.length()
	var s := float(Config.get_value("stick_sensitivity"))
	yaw -= curve.x * s * delta
	var dy := curve.y * s * 0.75 * delta
	pitch = clampf(pitch + (dy if bool(Config.get_value("invert_y")) else -dy), -1.5, 1.5)


func _swing() -> void:
	# An enemy rat in front of us takes priority over terrain: bonk!
	var fwd := forward()
	var best: Rat = null
	var best_d := Config.BONK_RANGE
	for other in m.rats:
		if other.team == rat.team:
			continue
		var to := other.center() - rat.eye()
		var d := to.length()
		if d < best_d and to.normalized().dot(fwd) > 0.55:
			best_d = d
			best = other
	# ...or what looks like one: a Wind-up Decoy of theirs, closer still, goes off
	var decoy: WindupSystem.Walker = null
	for w in m.windup.walkers:
		if w.team == rat.team and not m.lobby:
			continue
		var to := w.body.center() - rat.eye()
		var d := to.length()
		if d < best_d and to.normalized().dot(fwd) > 0.55:
			best_d = d
			decoy = w
	if decoy != null and rat.bonk_cd <= 0.0:
		if m.windup.try_bonk(rat, decoy):
			return
	if best != null and rat.bonk_cd <= 0.0:
		if m.try_bonk(rat, best):
			return
	if not aim.is_empty() and painting() and m.paintable(aim["cell"]):
		_say(m.try_paint_block(rat, aim["cell"], selected_color))   # Paint slot: left click dyes the block
	elif not aim.is_empty():
		m.try_dig(rat, aim["cell"])
	else:
		rat.dig_cd = 1.0 / Config.DIG_RATE
		rat.play_action("dig", 0.25)


func _process(delta: float) -> void:
	if rat == null:
		return
	if not ui_open and not m.over:
		_stick_look(delta)
	var fwd := forward()
	var pivot := rat.position + Vector3(0, 0.72, 0)
	var dist := 0.0
	var mc := machine()
	cam.rotation = Vector3(pitch, yaw, 0)
	if mc != null:
		# siege control: always third person, orbiting the machine
		pivot = Vector3(mc.cell) + Vector3(0.5, 1.9, 0.5)
		dist = 5.5
		var mback := (-fwd + Vector3(0, 0.3, 0)).normalized()
		var mhit := m.world.raycast(pivot, mback, dist + 0.3, true)
		if not mhit.is_empty():
			dist = maxf(0.6, float(mhit["dist"]) - 0.3)
		cam.position = pivot + mback * dist
		cam.look_at(pivot + fwd * 6.0)
	elif not first_person:
		dist = cam_dist
		var back := (-fwd + Vector3(0, 0.18, 0)).normalized()
		var hit := m.world.raycast(pivot, back, dist + 0.3, true)
		if not hit.is_empty():
			dist = maxf(0.0, float(hit["dist"]) - 0.3)
		cam.position = pivot + back * dist
	else:
		cam.position = pivot
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.6)
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	var sprite := rat.get_node_or_null("Sprite") as Node3D
	if sprite != null:
		sprite.visible = dist > 0.9
	_update_aim(rat.position + Vector3(0, 0.72, 0), fwd, mc != null)
	_update_tool_visuals()


func _update_aim(eye: Vector3, fwd: Vector3, operating: bool) -> void:
	# Find what the crosshair is over from the camera, then re-cast from the
	# rat's eye so reach is measured from the rat, not from the camera.
	aim = {}
	if operating:
		return
	var look := m.world.raycast_micro(cam.position, fwd, 60.0)
	var point := cam.position + fwd * 30.0
	if not look.is_empty():
		point = cam.position + fwd * (float(look["dist"]) + 0.02)
	var dir := point - eye
	if dir.length() > 0.05:
		var hit := m.world.raycast_micro(eye, dir, Config.DIG_REACH)
		if not hit.is_empty():
			aim = hit
			aim["point"] = eye + dir.normalized() * float(hit["dist"])


func _update_tool_visuals() -> void:
	tool_text = ""
	edge_dir = Vector3.ZERO
	_highlight.visible = false
	_select_box.visible = false
	_ghost.visible = false
	var mc := machine()
	if mc != null:
		var names := {Blocks.CANNON: "Scrap Cannon", Blocks.CRANE: "Wrecking Crane", Blocks.DOZER: "Bulldozer"}
		tool_text = "%s  -  left mouse: %s   [%s] leave%s" % [names[mc.kind],
			{Blocks.CANNON: "fire", Blocks.CRANE: "pump the swing", Blocks.DOZER: "ram the blade"}[mc.kind],
			Inputs.key_name("interact"), "   (reloading %.1fs)" % mc.cd if mc.cd > 0.3 else ""]
		return
	if ui_open:
		return
	if tool == Tool.PANTOGRAPH:
		_update_pantograph()
	elif tool == Tool.CHISEL:
		if painting():
			tool_text = "Chisel  -  LMB carve, RMB add %s paint  (made from dirt, else stone)" % Blocks.PALETTE_NAMES[selected_color]
		else:
			var mat := String(ClassDefs.MATS[selected_mat])
			tool_text = "Chisel  -  LMB carve, RMB add %s  (%.2f blocks of it spare)" % [mat, float(m._micro_available(rat, mat)) / 343.0]
	if aim.is_empty():
		return
	# thin team-coloured square on the targeted face (microvoxel-sized for the chisel)
	var n := Vector3(Vector3i(aim["normal"]))
	var s := 1.0
	var center := Vector3(Vector3i(aim["cell"])) + Vector3(0.5, 0.5, 0.5)
	if tool == Tool.CHISEL:
		s = 1.0 / float(Blocks.MICRO)
		center = Vector3(Vector3i(aim["cell"])) + (Vector3(Vector3i(aim["micro"])) + Vector3(0.5, 0.5, 0.5)) * s
	_highlight.visible = tool != Tool.PANTOGRAPH or blueprint == null
	_highlight.scale = Vector3.ONE * s * 0.98
	_highlight.position = center + n * (s * 0.5 + 0.006)
	if n.x != 0.0:
		_highlight.rotation = Vector3(0, PI / 2.0, 0)
	elif n.y != 0.0:
		_highlight.rotation = Vector3(PI / 2.0, 0, 0)
	else:
		_highlight.rotation = Vector3.ZERO
	# which edge of the square is the crosshair nearest to?
	var local: Vector3 = _highlight.transform.affine_inverse() * Vector3(aim.get("point", _highlight.position))
	var strong := 0
	if absf(local.x) >= absf(local.y):
		strong = 0 if local.x >= 0.0 else 1
	else:
		strong = 2 if local.y >= 0.0 else 3
	for i in 4:
		_edges[i].material_override = _edge_strong if i == strong else _edge_weak
	var world_dir: Vector3 = _highlight.transform.basis * [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN][strong]
	edge_dir = world_dir.normalized() if absf(world_dir.normalized().y) < 0.5 else Vector3.ZERO
	if tool == Tool.DIG and rat.equipped == "conveyor" and edge_dir != Vector3.ZERO:
		tool_text = "Conveyor will run toward the bright edge   [%s]" % Inputs.key_name("gadget")


func _update_pantograph() -> void:
	if corner_set:
		var other: Vector3i = aim["cell"] if not aim.is_empty() else corner
		var lo := Vector3(mini(corner.x, other.x), mini(corner.y, other.y), mini(corner.z, other.z))
		var span := (corner - other).abs() + Vector3i.ONE
		_select_box.visible = true
		_select_box.position = lo + Vector3(span) * 0.5
		_select_box.scale = Vector3(span) + Vector3.ONE * 0.04
		tool_text = "Pantograph  -  selecting %dx%dx%d  (max %d). Click the opposite corner." % [span.x, span.y, span.z, Config.PANTOGRAPH_MAX]
		return
	if blueprint == null:
		tool_text = "Pantograph  -  left-click the first corner of what you want to copy"
		return
	tool_text = "Blueprint %dx%dx%d  needs %s  -  RMB paste, %s rotate, %s mirror, %s flip, %s invert, LMB new copy" % [
		blueprint.size.x, blueprint.size.y, blueprint.size.z, blueprint.cost_text(), Inputs.key_name("rotate_blueprint"),
		Inputs.key_name("mirror_blueprint"), Inputs.key_name("flip_blueprint"), Inputs.key_name("invert_blueprint")]
	if aim.is_empty():
		return
	if _ghost_for != blueprint:
		_ghost_for = blueprint
		_ghost.mesh = _ghost_mesh(blueprint)
	var origin := paste_origin()
	paste_error = m.paste_check(rat, blueprint, origin)
	_ghost.visible = true
	_ghost.position = Vector3(origin)
	_ghost_mat.albedo_color = Color(0.45, 1.0, 0.5, 0.35) if paste_error == "" else Color(1.0, 0.3, 0.25, 0.4)
	if paste_error != "":
		tool_text = "Can't build here: " + paste_error


static func _ghost_mesh(bp: Blueprint) -> ArrayMesh:
	## Transparent preview: a box per block, or the carved shape itself.
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var s := 1.0 / float(Blocks.MICRO)
	var carved := 0
	for e in bp.cells:
		var o := Vector3(Vector3i(e["o"]))
		carved += 0 if e["mask"] == null else 1
		if e["mask"] == null or carved > 20:   # cap preview detail for huge carved blueprints
			ChunkMesher._box(v, c, o + Vector3.ONE * 0.02, o + Vector3.ONE * 0.98, Color.WHITE)
			continue
		var mask: PackedByteArray = e["mask"]
		for my in Blocks.MICRO:
			for mz in Blocks.MICRO:
				for mx in Blocks.MICRO:
					if mask[mx + Blocks.MICRO * (mz + Blocks.MICRO * my)] == 1:
						var mn := o + Vector3(mx, my, mz) * s
						ChunkMesher._box(v, c, mn, mn + Vector3.ONE * s, Color.WHITE)
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
