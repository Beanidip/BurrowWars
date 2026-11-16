extends Node
## End-to-end smoke test of the real application flow:
## main menu -> every menu page -> Cheese Race -> play -> dialogs -> win ->
## results -> rematch -> menu -> Free Build.
## Headless:   godot --headless --path . res://tests/smoke_runner.tscn
## With a display, set BW_SHOTS=/some/dir to also capture screenshots there.

var _fails := 0
var _shots := ""
var main: Node


func _ready() -> void:
	_shots = OS.get_environment("BW_SHOTS")
	var size_env := OS.get_environment("BW_SIZE")
	if size_env != "":
		var parts := size_env.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(shot_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots)
	img.save_png("%s/%s.png" % [_shots, shot_name])


func fits(c: Control) -> bool:
	## True when a control lies fully inside the visible viewport.
	var r := c.get_global_rect()
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return vp.grow(1.0).encloses(r)


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func _run() -> void:
	await frames(5)
	var menu: MainMenu = main.menu
	check(menu != null, "main menu opens")
	var panel := menu.get_child(2).get_child(0) as Control
	check(fits(panel), "home page fits the viewport")
	var vp_size := get_viewport().get_visible_rect().size
	check(absf(panel.get_global_rect().get_center().x - vp_size.x * 0.5) < 4.0, "menu panel is centred")
	check(menu.size.is_equal_approx(vp_size), "menu covers the whole viewport")
	await shot("01_menu")
	menu._show_setup()
	await frames(3)
	check(fits(panel), "setup page fits the viewport")
	await shot("02_setup")
	menu._show_help()
	await frames(3)
	check(fits(panel), "help page fits the viewport")
	menu._show_settings()
	await frames(3)
	check(fits(panel), "settings page fits the viewport")
	await shot("03_settings")

	# --- Cheese Race -----------------------------------------------------
	main.start_match({"mode": "race", "seed": 4242, "goal": 2, "team": 0, "class": "builder", "team_size": 2})
	await frames(30)
	var s: GameSession = main.session
	check(s != null and s.m.rats.size() == 4, "race starts with 2v2 rats")
	check(s.m.world.get_child_count() > 20, "terrain chunks were meshed (%d)" % s.m.world.get_child_count())
	check(s.player.on_floor and s.m.in_base(s.player), "player stands in the base")
	await shot("04_base_third_person")
	await press("jump")
	check(not s.player.on_floor, "Space makes the rat jump")
	# real input path: mouse look, WASD and holding the dig button
	var yaw0 := s.ctl.yaw
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(120, 0)
	Input.parse_input_event(mm)
	await frames(3)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse is captured during play")
	check(absf(s.ctl.yaw - yaw0) > 0.1, "mouse motion turns the camera")
	s.ctl.yaw = -PI / 2.0
	var x0 := s.player.position.x
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	check(s.player.position.x > x0 + 0.8, "W walks the rat forward (%.2f)" % (s.player.position.x - x0))
	await press("camera_toggle")
	check(s.ctl.first_person, "V toggles first person")
	await frames(5)
	await shot("05_first_person")
	await press("camera_toggle")
	# walk out and look at the world
	s.player.position = Vector3(24.5, s.m.world.surface_y(24, 26), 26.5)
	s.ctl.yaw = -PI / 2.0
	s.ctl.pitch = -0.2
	await frames(20)
	await shot("06_surface")
	# dig a few blocks through the authority using the aimed cell
	s.ctl.pitch = -0.9
	await frames(4)
	check(not s.ctl.aim.is_empty(), "crosshair finds a block to dig")
	if not s.ctl.aim.is_empty():
		var cell: Vector3i = s.ctl.aim["cell"]
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		await frames(90)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		check(s.m.world.get_cell(cell) == Blocks.AIR, "holding left mouse digs the aimed block")
		check(int(s.player.mats["dirt"]) > 0, "dug dirt lands in the hotbar stash")
		await frames(5)
		if not s.ctl.aim.is_empty():
			var before := int(s.player.mats["dirt"])
			await press("place")
			check(int(s.player.mats["dirt"]) == before - 1, "right mouse places a block from the stash")
	await shot("07_dig")
	# underground views: sewer and chapel
	s.player.position = Vector3(30.5, 20.0, 22.5)
	s.ctl.yaw = -PI / 2.0
	s.ctl.pitch = 0.0
	await frames(20)
	await shot("08_sewer")
	s.player.position = Vector3(43.5, 19.0, 24.5)
	await frames(20)
	await shot("09_chapel")
	# dialogs
	s.player.position = MapGenerator.spawn_point(0)
	await frames(10)
	await press("workshop")
	check(s.hud._dialog_kind == "workshop", "B opens the workshop at base")
	if s.hud._dialog != null:
		check(fits((s.hud._dialog as Control).get_child(1) as Control), "workshop fits the viewport")
	s.player.scrap = 50
	s.hud._buy("spring")
	check(int(s.player.gadgets.get("spring", 0)) >= 2, "workshop purchase lands in the pack")
	await frames(3)
	await shot("10_workshop")
	await press("inventory")
	check(s.hud._dialog_kind == "inventory", "I switches to the inventory")
	await frames(3)
	if s.hud._dialog != null:
		check(fits((s.hud._dialog as Control).get_child(1) as Control), "inventory fits the viewport")
	await shot("11_inventory")
	await press("inventory")
	check(s.hud._dialog == null and not s.ctl.ui_open, "I closes it again")
	await press("pause")
	check(s.hud._dialog_kind == "pause" and get_tree().paused, "Esc pauses")
	await frames(3)
	if s.hud._dialog != null:
		check(fits((s.hud._dialog as Control).get_child(1) as Control), "pause menu fits the viewport")
	await shot("12_pause")
	await press("pause")
	check(not get_tree().paused, "Esc resumes")
	# gadgets + a fight for the screenshot
	s.player.position = Vector3(20.5, s.m.world.surface_y(20, 30), 30.5)
	s.player.carried = 2
	var foe: Rat = null
	for r in s.m.rats:
		if r.team == 1:
			foe = r
			break
	s.m.bots.clear()
	foe.position = s.player.position + Vector3(2.5, 0, 0.5)
	var gp := Vector3i(22, s.m.world.surface_y(22, 32), 32)
	for i in 3:
		s.m.world.set_block(gp + Vector3i(0, i, 0), Blocks.LADDER)
	s.m.world.set_block(gp + Vector3i(1, 0, 0), Blocks.SPRING)
	s.m.world.set_block(gp + Vector3i(2, 0, 0), Blocks.TNT)
	s.m.world.set_block(gp + Vector3i(3, 0, 0), Blocks.TRAP_RED)
	s.m.world.set_block(gp + Vector3i(4, -1, 0), Blocks.CONV_XP)
	s.m.world.set_block(gp + Vector3i(5, 0, 0), Blocks.GATE_BLUE)
	s.m.world.set_block(gp + Vector3i(6, 0, 0), Blocks.CHEESE)
	s.m.spawn_pickup("cheese", Vector3(gp) + Vector3(1.5, 0.3, -1.5), Vector3.ZERO).lock_t = 99.0
	s.m.pickups[-1].lock_id = s.player.id
	s.ctl.yaw = -PI / 2.0 - 0.5
	s.ctl.pitch = -0.25
	await frames(30)
	await shot("13_gadgets_and_rivals")
	# win
	s.player.position = MapGenerator.spawn_point(0)
	await frames(20)
	check(s.m.over and s.m.winner == 0, "banking the goal wins the match")
	check(s.hud._dialog_kind == "results", "results screen appears")
	await frames(10)
	if s.hud._dialog != null:
		check(fits((s.hud._dialog as Control).get_child(1) as Control), "results fit the viewport")
	await shot("14_results")
	s.hud.rematch_requested.emit()
	await frames(30)
	check(main.session != null and main.session != s and not main.session.m.over, "rematch starts a fresh match")
	main.session.hud._exit()
	await frames(10)
	check(main.menu != null and main.session == null, "quit returns to the main menu")

	# --- Free Build -------------------------------------------------------
	main.start_match({"mode": "free", "seed": 5, "goal": 9999, "team": 0, "class": "maestro", "team_size": 1})
	await frames(30)
	s = main.session
	check(s.m.free_mode and s.m.rats.size() == 1 and s.player.class_id == "maestro", "Free Build starts solo as Chisel Maestro")
	await press("fly")
	check(s.player.flying, "N toggles creative flight")
	s.player.position = Vector3(40, 44, 24)
	s.ctl.yaw = -PI / 2.0
	s.ctl.pitch = -0.5
	await frames(20)
	await shot("15_free_build_overview")
	await press("save_map")
	check(FileAccess.file_exists("user://maps/free_build.bwmap"), "F5 saves the map")
	main.queue_free()
	await frames(3)
	print("---- smoke: %d failed ----" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
