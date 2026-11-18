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


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func needs_display(cond: bool, what: String) -> void:
	## Mouse capture does not exist on the headless display server, so these
	## checks only run under a real or virtual display (see docs/TEST_RESULTS.md).
	if DisplayServer.get_name() == "headless":
		print("skip  %s  (needs a display)" % what)
	else:
		check(cond, what)


func look_at(s: GameSession, point: Vector3) -> void:
	var d := point - (s.player.position + Vector3(0, 0.72, 0))
	s.ctl.yaw = atan2(-d.x, -d.z)
	s.ctl.pitch = asin(clampf(d.normalized().y, -1.0, 1.0))


func count_block(w: VoxelWorld, from: Vector3i, size: Vector3i, id: int) -> int:
	var n := 0
	for dx in size.x:
		for dy in size.y:
			for dz in size.z:
				if w.get_cell(from + Vector3i(dx, dy, dz)) == id:
					n += 1
	return n


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func until_loaded(old: GameSession = null) -> void:
	## A new session is up and its loading screen gone (the map is built on
	## worker threads behind it).
	for i in 1800:
		var s: GameSession = main.session
		if s != null and is_instance_valid(s) and s != old and s.loaded:
			return
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
	await frames(3)
	check(main.find_children("*", "LoadingScreen", true, false).size() == 1, "a loading screen covers the start")
	await until_loaded()
	await frames(30)
	var s: GameSession = main.session
	check(main.find_children("*", "LoadingScreen", true, false).is_empty() or s.loading == null, "and lifts once the world is built")
	check(s != null and s.m.rats.size() == 4, "race starts with 2v2 rats")
	check(s.m.world.get_child_count() > 20, "terrain chunks were meshed (%d)" % s.m.world.get_child_count())
	check(s.player.on_floor and s.m.in_base(s.player), "player stands in the base")
	# the corner panels never sit over the hotbar, even with long gadget and gear names
	s.player.gear = "bubbles"
	s.player.gadgets["wallspring"] = 1
	s.player.equipped = "wallspring"
	await frames(5)
	var clear := true
	for p: Control in s.hud._side_panels:
		clear = clear and not p.get_global_rect().intersects(s.hud._hotbar.get_global_rect())
	check(clear, "HUD corner panels don't overlap the hotbar")
	await shot("04_base_third_person")
	await press("jump")
	check(not s.player.on_floor, "Space makes the rat jump")
	# real input path: mouse look, WASD and holding the dig button
	var yaw0 := s.ctl.yaw
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(120, 0)
	Input.parse_input_event(mm)
	await frames(3)
	needs_display(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse is captured during play")
	needs_display(absf(s.ctl.yaw - yaw0) > 0.1, "mouse motion turns the camera")
	s.ctl.yaw = -PI / 2.0
	var x0 := s.player.position.x
	Input.action_press("move_forward")
	await wait(0.5)
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
		await wait(1.6)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		needs_display(s.m.world.get_cell(cell) == Blocks.AIR, "holding left mouse digs the aimed block")
		if DisplayServer.get_name() == "headless":
			for i in 3:   # same request the mouse would make, sent straight to the authority
				s.player.dig_cd = 0.0
				s.m.try_dig(s.player, cell)
		check(s.m.world.get_cell(cell) == Blocks.AIR, "the aimed block is dug out")
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
	await until_loaded(s)
	await frames(30)
	check(main.session != null and main.session != s and not main.session.m.over, "rematch starts a fresh match")
	main.session.hud._exit()
	await frames(10)
	check(main.menu != null and main.session == null, "quit returns to the main menu")

	# --- Free Build -------------------------------------------------------
	main.start_match({"mode": "free", "seed": 5, "goal": 9999, "team": 0, "class": "maestro", "team_size": 1})
	await until_loaded()
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
	# --- chisel, pantograph, Mobile TNT and siege machines, in the real game ----
	s.player.flying = false
	var w := s.m.world
	var pad := Vector3i(30, w.surface_y(30, 12) + 1, 12)
	for dx in range(-6, 13):
		for dz in range(-7, 8):
			w.set_block(pad + Vector3i(dx, -1, dz), Blocks.STONE)
			for dy in 9:
				w.set_block(pad + Vector3i(dx, dy, dz), Blocks.AIR)
	s.player.position = Vector3(pad) + Vector3(0.5, 0, 0.5)
	s.player.vel = Vector3.ZERO
	var block := pad + Vector3i(2, 0, 0)
	w.set_block(block, Blocks.STONE)
	w.set_block(block + Vector3i(0, 1, 0), Blocks.ICE)
	s.ctl.first_person = true
	look_at(s, Vector3(block) + Vector3(0.0, 0.6, 0.5))
	await frames(8)
	await press("chisel")
	check(s.ctl.tool == PlayerController.Tool.CHISEL, "9 equips the chisel")
	check(s.ctl.aim.has("micro") and Vector3i(s.ctl.aim["cell"]) == block, "chisel targets a single microvoxel of the aimed block")
	for my in range(2, 7):
		for mz in range(2, 5):
			for mx in range(0, 7):
				s.player.chisel_cd = 0.0
				s.m.try_chisel_remove(s.player, block, Vector3i(mx, my, mz))
	check(w.has_micro(block) and w.micro_count(block) == 343 - 105, "carving removes exactly the chosen microvoxels (%d left)" % w.micro_count(block))
	await frames(6)
	check(s.ctl.aim.is_empty() or Vector3i(s.ctl.aim["cell"]) != block, "the crosshair now sees straight through the carved tunnel")
	look_at(s, Vector3(block) + Vector3(0.0, 0.15, 0.5))
	await frames(6)
	await wait(0.2)   # chisel cooldown
	var before_add := w.micro_count(block)
	await press("place")
	check(w.micro_count(block) + w.micro_count(block + Vector3i(-1, 0, 0)) == before_add + 1 or w.micro_count(block) == before_add + 1, "right mouse adds one microvoxel")
	await frames(6)
	await shot("16_chisel")
	# pantograph: copy the carved block and the ice on top of it, rotate, preview, paste
	await press("pantograph")
	check(s.ctl.tool == PlayerController.Tool.PANTOGRAPH, "0 equips the pantograph")
	s.ctl.corner = block
	s.ctl.corner_set = true
	look_at(s, Vector3(block) + Vector3(0.0, 1.5, 0.5))   # second corner: the ice block on top
	await frames(6)
	s.ctl._pantograph_click()
	check(s.ctl.blueprint != null and s.ctl.blueprint.size == Vector3i(1, 2, 1), "two corners copy the region")
	var bp_before: Blueprint = s.ctl.blueprint
	await press("rotate_blueprint")
	check(s.ctl.blueprint != bp_before, "X rotates the blueprint")
	look_at(s, Vector3(pad) + Vector3(2.5, -0.01, 2.5))
	await frames(8)
	await shot("17_pantograph_preview")
	var origin: Vector3i = s.ctl.paste_origin() if not s.ctl.aim.is_empty() else Vector3i.ZERO
	await press("place")
	check(w.has_micro(origin) and w.get_cell(origin + Vector3i(0, 1, 0)) == Blocks.ICE, "paste rebuilds the carved block and the block above it")
	check(w.micro_count(origin) == w.micro_count(block), "pasted copy has the same microvoxel count")
	await press("slot_1")
	check(s.ctl.tool == PlayerController.Tool.DIG, "1 goes back to the dig tool")
	# Mobile TNT thrown with Q
	s.ctl.first_person = false
	s.player.equipped = "dynamite"
	look_at(s, Vector3(pad) + Vector3(8.5, 3.0, -3.5))
	await frames(4)
	await press("gadget")
	check(s.m.dynamite.sticks.size() == 1, "Q throws a stick of Mobile TNT")
	await wait(0.5)
	await shot("18_dynamite_in_flight")
	await wait(Config.DYNAMITE_FUSE)
	check(s.m.dynamite.sticks.is_empty(), "it explodes when the fuse runs out")
	check(s.player.position.y > -4.0 and not s.m.over, "the blast hurts nobody")
	# siege machines: place, man with R, aim, work, leave
	for dz in range(-5, 6):
		for dy in 4:
			w.set_block(pad + Vector3i(10, dy, dz), Blocks.STONE)
	s.player.position = Vector3(pad) + Vector3(0.5, 0, 0.5)
	s.player.vel = Vector3.ZERO
	var spots := {"cannon": pad + Vector3i(2, 0, 3), "crane": pad + Vector3i(6, 0, -2), "dozer": pad + Vector3i(9, 0, 3)}
	for kind: String in spots:
		s.player.position = Vector3(spots[kind]) + Vector3(-1.5, 0, 0.5)
		check(s.m.try_place_gadget(s.player, spots[kind], kind) == "", "%s placed" % kind)
	await frames(10)
	for kind: String in ["cannon", "crane", "dozer"]:
		var cell: Vector3i = spots[kind]
		s.player.position = Vector3(cell) + Vector3(-1.6, 0, 0.5)
		s.player.vel = Vector3.ZERO
		look_at(s, Vector3(cell) + Vector3(0.5, 0.5, 0.5))
		await frames(6)
		await press("interact")
		check(s.player.operating != -1, "R mans the %s" % kind)
		var mc: SiegeSystem.Machine = s.m.siege.machines.get(cell)
		s.ctl.yaw = -PI / 2.0
		s.ctl.pitch = 0.12
		await wait(0.3)
		check(mc != null and absf(mc.yaw - s.ctl.yaw) < 0.01, "the mouse aims the %s" % kind)
		var broken_before := count_block(w, pad + Vector3i(10, 0, -5), Vector3i(1, 4, 11), Blocks.STONE)
		for i in (1 if kind == "cannon" else 14):
			s.m.siege.fire(s.player)
			await wait(0.5 if kind == "crane" else 0.25)
		if kind == "cannon":
			await frames(2)
			await shot("19_cannon_shot_and_arc")
			await wait(1.2)
		elif kind == "crane":
			await shot("20_crane_swing")
		else:
			await shot("21_bulldozer")
		var broken_after := count_block(w, pad + Vector3i(10, 0, -5), Vector3i(1, 4, 11), Blocks.STONE)
		var damaged := 0
		for dc: Vector3i in w.damage:
			if dc.x == pad.x + 10:
				damaged += 1
		check(broken_after < broken_before or damaged > 0, "the %s chews the stone wall (%d -> %d blocks, %d cracked)" % [kind, broken_before, broken_after, damaged])
		await press("interact")
		check(s.player.operating == -1, "R leaves the %s" % kind)
	var x1 := s.player.position.x
	s.ctl.yaw = PI / 2.0
	Input.action_press("move_forward")
	await wait(0.4)
	Input.action_release("move_forward")
	check(s.player.position.x < x1 - 0.5, "normal movement works again after leaving a machine")
	s.player.position = Vector3(pad) + Vector3(-3.5, 2.0, 6.5)
	s.ctl.yaw = -PI / 2.0 + 0.55
	s.ctl.pitch = -0.2
	s.ctl.cam_dist = 6.0
	await frames(10)
	await shot("22_siege_yard")
	# --- v1.2: target outline, floor-laid conveyor, key swap, team blocks, water, lava ---
	check(Inputs.KEYS["cycle_gadget"][0] == KEY_R and Inputs.KEYS["interact"][0] == KEY_T, "R changes the Q slot, T pilots siege machines")
	s.ctl.first_person = true
	s.player.position = Vector3(pad) + Vector3(-3.5, 0, -4.5)
	s.player.vel = Vector3.ZERO
	s.player.equipped = "ladder"
	await press("cycle_gadget")
	check(s.player.equipped != "ladder", "pressing R cycles the Q slot (now %s)" % s.player.equipped)
	s.player.equipped = "conveyor"
	var floor_cell := pad + Vector3i(-2, -1, -5)
	look_at(s, Vector3(floor_cell) + Vector3(0.85, 1.0, 0.5))      # near the +X edge of the top face
	await frames(6)
	check(not s.ctl.aim.is_empty() and Vector3i(s.ctl.aim["cell"]) == floor_cell, "crosshair is on the floor block")
	check(s.ctl._highlight.visible and s.ctl.edge_dir.is_equal_approx(Vector3(1, 0, 0)), "the bright edge of the target square is the one nearest the crosshair (%s)" % str(s.ctl.edge_dir))
	await shot("23_target_outline")
	await press("gadget")
	check(w.get_cell(floor_cell) == Blocks.CONV_XP and w.get_cell(floor_cell + Vector3i(0, 1, 0)) == Blocks.AIR, "Q lays the conveyor into the floor, running toward the bright edge")
	look_at(s, Vector3(floor_cell) + Vector3(1.5, 1.0, 0.15))      # next block, near its -Z edge
	await frames(6)
	await press("gadget")
	check(w.get_cell(floor_cell + Vector3i(1, 0, 0)) == Blocks.CONV_ZN, "a different edge gives a different direction")
	# ladder stack via the real aim point
	s.player.equipped = "ladder"
	var lad := pad + Vector3i(-2, 0, -3)
	w.set_block(lad, Blocks.LADDER)
	look_at(s, Vector3(lad) + Vector3(0.2, 0.8, 0.5))
	await frames(6)
	await press("gadget")
	check(w.get_cell(lad + Vector3i(0, 1, 0)) == Blocks.LADDER, "Q on the top half of a ladder stacks one above")
	# team blocks, clear gates, water and lava for the camera
	for i in 3:
		w.set_block(pad + Vector3i(-5 + i, 0, 2), Blocks.TEAM_BLUE)
		w.set_block(pad + Vector3i(-5 + i, 0, 4), Blocks.TEAM_RED)
		w.set_block(pad + Vector3i(-1, i, 3), Blocks.GATE_BLUE)
		w.set_block(pad + Vector3i(0, i, 3), Blocks.GATE_RED)
	for dx in range(1, 5):
		for dz in range(1, 5):
			w.set_block(pad + Vector3i(dx, -1, dz), Blocks.WATER)
			w.set_block(pad + Vector3i(dx, -2, dz), Blocks.WATER)
			w.set_block(pad + Vector3i(dx, -3, dz), Blocks.BRICK if (dx + dz) % 2 == 0 else Blocks.GLOW)
	s.ctl.first_person = false
	s.player.position = Vector3(pad) + Vector3(-2.5, 0, 0.5)
	look_at(s, Vector3(pad) + Vector3(1.5, -1.5, 3.5))
	await frames(12)
	await shot("24_team_blocks_gates_water")
	s.ctl.first_person = true
	s.player.position = Vector3(pad) + Vector3(0.5, 0.6, 2.5)
	look_at(s, Vector3(pad) + Vector3(3.0, -2.0, 3.0))
	await frames(12)
	await shot("24b_water_closeup")
	s.player.position = Vector3(pad) + Vector3(-6.5, 0.3, 3.5)
	look_at(s, Vector3(pad) + Vector3(0.0, 1.2, 3.5))
	await frames(12)
	await shot("24c_gates_closeup")
	# --- v1.3: colour picker, painted blocks, painted microvoxels, highway layer ---
	s.ctl.first_person = true
	s.ctl.tool = PlayerController.Tool.DIG
	s.player.position = Vector3(pad) + Vector3(-4.5, 0, -1.5)
	s.player.vel = Vector3.ZERO
	await press("color_picker")
	check(s.hud._dialog_kind == "colors", "C opens the colour picker")
	await frames(4)
	if s.hud._dialog != null:
		check(fits((s.hud._dialog as Control).get_child(1) as Control), "colour picker fits the viewport")
	await shot("27_colour_picker")
	s.hud.pick_color(5)
	await frames(3)
	check(s.hud._dialog == null and s.ctl.selected_color == 5 and s.ctl.painting(), "picking a colour closes the picker and switches to the Paint slot")
	var paint_floor := pad + Vector3i(-3, -1, -3)
	for k in 3:
		s.ctl.selected_color = k * 2
		look_at(s, Vector3(paint_floor + Vector3i(0, 0, k)) + Vector3(0.5, 1.0, 0.5))    # top face of three floor blocks
		await frames(5)
		await press("place")
	var stacked := 0
	for k in 3:
		if w.get_cell(paint_floor + Vector3i(0, 1, k)) == Blocks.PAINT_0 + k * 2:
			stacked += 1
	check(stacked == 3, "right mouse places painted blocks in whichever colour is picked (%d of 3)" % stacked)
	await press("slot_5")
	check(s.ctl.painting(), "5 selects the Paint slot")
	# chisel a dab of colour onto plain stone
	var plain := pad + Vector3i(-3, 0, 0)
	w.set_block(plain, Blocks.STONE)
	await press("chisel")
	s.ctl.selected_color = 0
	look_at(s, Vector3(plain) + Vector3(0.0, 0.5, 0.5))
	await frames(6)
	for i in 5:
		await wait(0.15)
		await press("place")
	var dabs := 0
	for cc: Vector3i in [plain, plain + Vector3i(-1, 0, 0)]:
		if w.has_micro(cc):
			for b in (w.micro[cc] as PackedByteArray):
				if b >= 2 or (b == 1 and Blocks.is_paint(w.get_cell(cc))):
					dabs += 1
	check(dabs >= 1, "with the chisel, right mouse adds painted microvoxels (%d)" % dabs)
	await press("chisel")
	s.player.equipped = "highway"
	var road_floor := pad + Vector3i(-5, -1, -3)
	look_at(s, Vector3(road_floor) + Vector3(0.5, 1.0, 0.5))
	await frames(6)
	await press("gadget")
	check(w.get_cell(road_floor + Vector3i(0, 1, 0)) == Blocks.HIGHWAY and w.get_cell(road_floor) == Blocks.STONE, "Q lays a highway on top of the floor block, which stays")
	w.set_block(road_floor + Vector3i(1, 1, 0), Blocks.HIGHWAY)
	w.set_block(road_floor + Vector3i(2, 1, 0), Blocks.HIGHWAY)
	for k in Blocks.PALETTE_SIZE:      # the whole palette as a little wall, for the camera
		w.set_block(pad + Vector3i(-6 + k % 6, 1 + k / 6, -6), Blocks.PAINT_0 + k)
	s.player.flying = false
	s.player.position = Vector3(pad) + Vector3(-3.5, 0.0, 1.5)
	s.player.vel = Vector3.ZERO
	await frames(10)
	look_at(s, Vector3(pad) + Vector3(-3.5, 0.6, -4.0))
	await frames(12)
	await shot("28_painted_blocks_and_highway")
	var pool := Vector3i(-1, -1, -1)
	for cy in range(6, 16):
		for cz in range(4, VoxelWorld.SZ - 4):
			for cx in range(4, VoxelWorld.SX - 4):
				if pool.y < 0 and w.get_block(cx, cy, cz) == Blocks.LAVA and w.get_block(cx, cy + 2, cz) == Blocks.AIR and w.get_block(cx + 2, cy, cz) == Blocks.LAVA and w.get_block(cx - 2, cy, cz) == Blocks.LAVA:
					pool = Vector3i(cx, cy, cz)
	check(pool.y > 0, "an underground lava pool exists on this map")
	if pool.y > 0:
		s.player.flying = true
		s.ctl.first_person = true
		s.player.position = Vector3(pool) + Vector3(0.5, 1.6, 0.5)
		s.ctl.yaw = 0.6
		s.ctl.pitch = -0.45
		await frames(12)
		await shot("25_lava_pool")
		# open the basin wall and watch it run
		var before_lava := count_block(w, pool + Vector3i(-8, -6, -8), Vector3i(17, 8, 17), Blocks.LAVA)
		for dx in range(1, 9):
			for dy in range(-1, 2):
				if w.get_cell(pool + Vector3i(dx, dy, 0)) != Blocks.LAVA:
					w.set_block(pool + Vector3i(dx, dy, 0), Blocks.AIR)
		for dx in range(5, 9):
			for dy in range(-5, -1):
				w.set_block(pool + Vector3i(dx, dy, 0), Blocks.AIR)
		await wait(4.0)
		var after_lava := count_block(w, pool + Vector3i(-8, -6, -8), Vector3i(17, 8, 17), Blocks.LAVA)
		check(after_lava > before_lava, "lava runs out through a breach and down the drop (%d -> %d blocks)" % [before_lava, after_lava])
		s.ctl.yaw = -PI / 2.0
		s.ctl.pitch = -0.5
		await frames(8)
		await shot("26_lava_flowing")
	main.queue_free()
	await frames(3)
	print("---- smoke: %d failed ----" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
