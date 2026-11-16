class_name PlayerController
extends Node3D
## Human input -> rat intent + requests to the Match authority.
## Owns the camera (first / third person with terrain collision) and the
## thin team-coloured highlight on the targeted block face.

signal notice(text: String)

var m: Match
var rat: Rat
var cam: Camera3D
var yaw := 0.0
var pitch := -0.25
var first_person := false
var cam_dist := 4.0
var selected_mat := 0
var ui_open := false
var aim: Dictionary = {}

var _highlight: MeshInstance3D
var _notice_cd := 0.0


func _ready() -> void:
	process_physics_priority = -10   # write intent before Match steps the rats
	cam = Camera3D.new()
	cam.near = 0.08
	cam.far = 220.0
	add_child(cam)
	cam.make_current()
	apply_settings()
	yaw = rat.yaw
	_highlight = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.98, 0.98)
	_highlight.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tc: Color = UiKit.TEAM[rat.team]
	mat.albedo_color = Color(tc.r, tc.g, tc.b, 0.38)
	_highlight.material_override = mat
	_highlight.visible = false
	add_child(_highlight)


func apply_settings() -> void:
	cam.fov = float(Config.get_value("fov"))
	cam_dist = float(Config.get_value("camera_distance"))


func forward() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func _unhandled_input(event: InputEvent) -> void:
	if ui_open or m.over:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens := float(Config.get_value("mouse_sensitivity"))
		yaw -= mm.relative.x * sens
		var dy := mm.relative.y * sens
		pitch = clampf(pitch + (dy if bool(Config.get_value("invert_y")) else -dy), -1.5, 1.5)
		return
	if event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(1.5, cam_dist - 0.4)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(8.0, cam_dist + 0.4)
	if event.is_action_pressed("jump"):
		rat.jump_pressed = true
	elif event.is_action_pressed("dash"):
		rat.dash_pressed = true
	elif event.is_action_pressed("camera_toggle"):
		first_person = not first_person
	elif event.is_action_pressed("place"):
		if not aim.is_empty():
			_say(m.try_place_mat(rat, _place_cell(), ClassDefs.MATS[selected_mat]))
	elif event.is_action_pressed("gadget"):
		if aim.is_empty():
			_say("Aim at a surface to place a gadget")
		else:
			_say(m.try_place_gadget(rat, _place_cell()))
	elif event.is_action_pressed("cycle_gadget"):
		cycle_gadget()
	elif event.is_action_pressed("ability_1"):
		_say(m.use_ability(rat, 0, aim))
	elif event.is_action_pressed("ability_2"):
		_say(m.use_ability(rat, 1, aim))
	elif event.is_action_pressed("drop_cheese"):
		if not m.drop_cheese(rat):
			_say("You aren't carrying any cheese")
	elif event.is_action_pressed("respawn"):
		if Input.is_key_pressed(KEY_CTRL):
			m.respawn(rat)
			_say("Back at base. Your cheese and materials stayed behind.")
	elif event.is_action_pressed("fly"):
		if bool(rat.cls["fly"]):
			rat.flying = not rat.flying
			_say("Flight ON - Space up, Ctrl down" if rat.flying else "Flight off")
	else:
		for i in 4:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				selected_mat = i


func cycle_gadget() -> void:
	var owned: Array[String] = []
	for g: String in ClassDefs.GADGETS:
		if m.free_mode or int(rat.gadgets.get(g, 0)) > 0:
			owned.append(g)
	if owned.is_empty():
		_say("No gadgets yet - buy some at the workshop (B)")
		return
	var i := owned.find(rat.equipped)
	rat.equipped = owned[(i + 1) % owned.size()]


func _place_cell() -> Vector3i:
	return Vector3i(aim["cell"]) + Vector3i(aim["normal"])


func _say(text: String) -> void:
	if text != "":
		notice.emit(text)


func _physics_process(delta: float) -> void:
	_notice_cd = maxf(0.0, _notice_cd - delta)
	if ui_open or m.over:
		rat.wish = Vector3.ZERO
		rat.jump_held = false
		rat.down_held = false
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	rat.wish = f * -input.y + r * input.x
	rat.yaw = yaw
	rat.jump_held = Input.is_action_pressed("jump")
	rat.down_held = Input.is_action_pressed("descend")
	if Input.is_action_pressed("dig") and rat.dig_cd <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_swing()


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
	if best != null and rat.bonk_cd <= 0.0:
		if m.try_bonk(rat, best):
			return
	if not aim.is_empty():
		m.try_dig(rat, aim["cell"])
	else:
		rat.dig_cd = 1.0 / Config.DIG_RATE
		rat.play_action("dig", 0.25)


func _process(_delta: float) -> void:
	if rat == null:
		return
	var pivot := rat.position + Vector3(0, 0.72, 0)
	var fwd := forward()
	cam.rotation = Vector3(pitch, yaw, 0)
	var dist := 0.0
	if not first_person:
		dist = cam_dist
		var back := (-fwd + Vector3(0, 0.18, 0)).normalized()
		var hit := m.world.raycast(pivot, back, dist + 0.3, true)
		if not hit.is_empty():
			dist = maxf(0.0, float(hit["dist"]) - 0.3)
		cam.position = pivot + back * dist
	else:
		cam.position = pivot
	# hide our own sprite when the camera is (nearly) inside it
	var sprite := rat.get_node_or_null("Sprite") as Node3D
	if sprite != null:
		sprite.visible = dist > 0.9
	_update_aim(pivot, fwd)


func _update_aim(eye: Vector3, fwd: Vector3) -> void:
	# Find what the crosshair is over from the camera, then re-cast from the
	# rat's eye so reach is measured from the rat, not from the camera.
	aim = {}
	var look := m.world.raycast(cam.position, fwd, 60.0)
	var point := cam.position + fwd * 30.0
	if not look.is_empty():
		point = cam.position + fwd * (float(look["dist"]) + 0.02)
	var dir := point - eye
	if dir.length() > 0.05:
		var hit := m.world.raycast(eye, dir, Config.DIG_REACH)
		if not hit.is_empty():
			aim = hit
	if aim.is_empty() or ui_open:
		_highlight.visible = false
		return
	var n := Vector3(Vector3i(aim["normal"]))
	_highlight.visible = true
	_highlight.position = Vector3(Vector3i(aim["cell"])) + Vector3(0.5, 0.5, 0.5) + n * 0.505
	if n.x != 0.0:
		_highlight.rotation = Vector3(0, PI / 2.0, 0)
	elif n.y != 0.0:
		_highlight.rotation = Vector3(PI / 2.0, 0, 0)
	else:
		_highlight.rotation = Vector3.ZERO
