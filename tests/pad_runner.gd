extends Node
## Controller-only playthrough at the Steam Deck's 1280x800: every menu page
## and dialog can be reached, used and left with a gamepad alone, the focus is
## always somewhere visible, text is at least 12 px and everything fits.
## Headless:   godot --headless --path . res://tests/pad_runner.tscn
## With a display, set BW_SHOTS=/some/dir to also capture screenshots there.

const MIN_TEXT := 12

var _fails := 0
var _shots := ""
var main: Node


func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	_shots = OS.get_environment("BW_SHOTS")
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


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func shot(shot_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, shot_name])


func pad(button: int) -> void:
	## Press and release one controller button, as a real pad would.
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var up := InputEventJoypadButton.new()
	up.device = 0
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func stick(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	await frames(1)


func focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func focus_text() -> String:
	var f := focus()
	return (f as Button).text if f is Button else ("<%s>" % f.get_class() if f != null else "<none>")


func inside(root: Node) -> bool:
	var f := focus()
	return f != null and root != null and root.is_ancestor_of(f) and f.is_visible_in_tree()


func fits(c: Control) -> bool:
	var r := c.get_global_rect()
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return vp.grow(1.0).encloses(r)


func small_text(root: Node) -> Array[String]:
	## Every visible piece of text under `root` smaller than MIN_TEXT pixels.
	var bad: Array[String] = []
	for c in root.find_children("*", "", true, false):
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		var size := 99
		var text := ""
		if c is Label:
			text = (c as Label).text
			size = (c as Control).get_theme_font_size("font_size")
		elif c is Button:
			text = (c as Button).text
			size = (c as Control).get_theme_font_size("font_size")
		elif c is LineEdit:
			text = (c as LineEdit).text + (c as LineEdit).placeholder_text
			size = (c as Control).get_theme_font_size("font_size")
		elif c is RichTextLabel:
			text = (c as RichTextLabel).text
			size = (c as Control).get_theme_font_size("normal_font_size")
		if text.strip_edges() != "" and size < MIN_TEXT:
			bad.append("%s (%d px)" % [text.substr(0, 24), size])
	return bad


func button(root: Node, text: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		if (c as Button).text.begins_with(text) and (c as Control).is_visible_in_tree():
			return c
	return null


func page_has(menu: MainMenu, text: String) -> bool:
	for c in menu._page.find_children("*", "", true, false):
		if (c is Label and (c as Label).text == text) or (c is Button and (c as Button).text == text):
			return true
	return false


func _run() -> void:
	await frames(5)
	check(get_viewport().get_visible_rect().size.y >= 719.0, "runs at the Steam Deck's 16:10 (%s)" % str(get_viewport().get_visible_rect().size))
	var menu: MainMenu = main.menu
	var panel := menu.get_child(2).get_child(0) as Control
	# --- home page: the focus starts on Play and the D-pad moves it ------
	await pad(JOY_BUTTON_DPAD_UP)
	check(Inputs.using_pad, "touching the pad switches prompts to the controller")
	check(focus_text().contains("Cheese Race"), "home page: the focus starts on the first button (%s)" % focus_text())
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(focus_text().contains("Learn to Play"), "D-pad Down moves to the next button (%s)" % focus_text())
	await shot("pad_01_home")
	for i in 3:
		await pad(JOY_BUTTON_DPAD_DOWN)
	check(focus_text().contains("Customize Rat"), "and on down the list (%s)" % focus_text())
	# --- Customize Rat with a controller: pick a hat, back out -----------
	var hat_was := String(Config.get_value("hat"))
	Config.set_value("hat", "")
	await pad(JOY_BUTTON_A)
	check(page_has(menu, "Customize Rat") and focus_text() == "No hat", "A opens Customize Rat, on your current hat (%s)" % focus_text())
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_A)
	check(String(Config.get_value("hat")) == "party", "D-pad and A pick a hat (%s)" % String(Config.get_value("hat")))
	await shot("pad_01b_customize")
	await pad(JOY_BUTTON_B)
	check(page_has(menu, "Learn to Play"), "B goes back home")
	Config.set_value("hat", hat_was)
	Config.save()
	for i in 5:
		await pad(JOY_BUTTON_DPAD_DOWN)
	check(focus_text().contains("How to Play"), "further down: How to Play (%s)" % focus_text())
	await pad(JOY_BUTTON_A)
	check(page_has(menu, "How to Play"), "A opens the focused page")
	var help_scroll: ScrollContainer = menu._page.find_children("*", "ScrollContainer", true, false)[0]
	await stick(JOY_AXIS_RIGHT_Y, 1.0)
	await wait(0.3)
	await stick(JOY_AXIS_RIGHT_Y, 0.0)
	check(help_scroll.scroll_vertical > 50, "the right stick scrolls the help text (%d)" % help_scroll.scroll_vertical)
	var pad_text := false
	for c in help_scroll.find_children("*", "Label", true, false):
		pad_text = pad_text or (c as Label).text.begins_with("CONTROLLER")
	check(pad_text, "How to Play explains the controller")
	await pad(JOY_BUTTON_B)
	check(page_has(menu, "Learn to Play"), "B goes back to the home page")
	check(inside(menu._page), "with the focus on a button again (%s)" % focus_text())
	await pad(JOY_BUTTON_B)
	check(page_has(menu, "Learn to Play"), "B on the home page stays put (it never quits)")
	check(small_text(menu).is_empty(), "home page text is at least %d px %s" % [MIN_TEXT, str(small_text(menu))])
	# --- every other page: lands on a button, fits, and B leaves it ------
	var pages := {"setup": menu._show_setup, "free build": menu._show_free.bind(false), "credits": menu._show_credits,
		"settings": menu._show_settings, "online": menu._show_online}
	for page_name: String in pages:
		(pages[page_name] as Callable).call()
		await frames(3)
		check(inside(menu._page), "%s page: the focus starts on a control (%s)" % [page_name, focus_text()])
		check(fits(panel), "%s page fits 1280x800" % page_name)
		var small := small_text(menu)
		check(small.is_empty(), "%s page text is at least %d px %s" % [page_name, MIN_TEXT, str(small)])
		if page_name == "settings":
			var sc: ScrollContainer = menu._page.find_children("*", "ScrollContainer", true, false)[0]
			var first := focus()
			var y0 := first.get_global_rect().position.y
			await stick(JOY_AXIS_LEFT_Y, 1.0)
			await wait(2.0)
			await stick(JOY_AXIS_LEFT_Y, 0.0)
			print("      settings: focus went from y %.0f to y %.0f in the list" % [y0, focus().get_global_rect().position.y + sc.scroll_vertical])
			check(focus() != first and inside(sc), "holding the stick down keeps moving through the settings (%s)" % focus_text())
			check(sc.scroll_vertical > 0, "and the list scrolls along with the focus (%d)" % sc.scroll_vertical)
		if page_name == "online":
			check(menu._name_edit.text != "", "a ready-made name, so nobody has to type one (%s)" % menu._name_edit.text)
		await pad(JOY_BUTTON_B)
		check(page_has(menu, "Learn to Play"), "B leaves the %s page" % page_name)
	menu._show_online()
	await frames(2)
	menu._show_host_setup()
	await frames(2)
	await pad(JOY_BUTTON_B)
	check(page_has(menu, "Public servers"), "B from hosting setup goes back to Play Online")
	await pad(JOY_BUTTON_B)

	# --- a Cheese Race, played from the pad ---------------------------
	main.start_match({"mode": "race", "seed": 4242, "goal": 3, "team": 0, "class": "digger", "team_size": 2})
	for i in 1800:
		if main.session != null and main.session.loaded:
			break
		await frames(1)
	await frames(30)
	var s: GameSession = main.session
	s.m.bots.clear()
	var hud: Hud = s.hud
	check(small_text(hud).is_empty(), "HUD text is at least %d px %s" % [MIN_TEXT, str(small_text(hud))])
	check(focus() == null, "nothing has the focus during play (A jumps)")
	# pause menu
	await pad(JOY_BUTTON_START)
	check(hud._dialog_kind == "pause" and get_tree().paused, "Menu pauses")
	check(focus_text() == "Resume", "the focus starts on Resume (%s)" % focus_text())
	check(fits((hud._dialog as Control).get_child(1) as Control), "pause menu fits 1280x800")
	check(small_text(hud._dialog).is_empty(), "pause menu text is at least %d px %s" % [MIN_TEXT, str(small_text(hud._dialog))])
	check(button(hud._dialog, "Close [B]") != null, "the close button names B")
	# effects volume at the top of the pause menu, kept in step with Settings > Audio
	var fx_slider: HSlider = null
	for c in hud._dialog.find_children("*", "HSlider", true, false):
		if c.get_meta("volume", "") == "sfx_volume":
			fx_slider = c
	check(fx_slider != null, "the pause menu has an effects volume slider")
	if fx_slider != null:
		var was := float(Config.get_value("sfx_volume"))
		fx_slider.value = 0.25
		var bus := AudioServer.get_bus_index("SFX")
		check(absf(float(Config.get_value("sfx_volume")) - 0.25) < 0.01 and absf(db_to_linear(AudioServer.get_bus_volume_db(bus)) - 0.25) < 0.02,
			"moving it turns the effects down (bus at %.2f)" % db_to_linear(AudioServer.get_bus_volume_db(bus)))
		var twin: HSlider = null
		for c in hud._dialog.find_children("*", "SettingsPanel", true, false):
			twin = (c as SettingsPanel).sliders.get("sfx_volume")
		check(twin != null and absf(twin.value - 0.25) < 0.01, "and the Effects volume in Settings below moves with it")
		fx_slider.value = was
	await shot("pad_02_pause")
	await pad(JOY_BUTTON_B)
	check(hud._dialog == null and not get_tree().paused and focus() == null, "B resumes and lets go of the focus")
	# respawn from the pause menu (Ctrl+K has no button)
	s.player.position = Vector3(20.5, s.m.world.surface_y(20, 30), 30.5)
	await frames(3)
	await pad(JOY_BUTTON_START)
	var respawn := button(hud._dialog, "Respawn at base")
	check(respawn != null, "the pause menu has Respawn at base")
	if respawn != null:
		respawn.grab_focus()
		await pad(JOY_BUTTON_A)
		check(hud._dialog_kind == "pause" and respawn.text == "Really respawn?", "it asks once before respawning")
		await pad(JOY_BUTTON_A)
		await frames(3)
		check(hud._dialog == null and s.m.in_base(s.player), "and the second press sends you home")
	# workshop, pack and colours are tabs
	s.player.position = MapGenerator.spawn_point(0)
	await frames(5)
	await pad(JOY_BUTTON_BACK)
	check(hud._dialog_kind == "workshop", "View opens the workshop at base")
	check(inside(hud._dialog) and (focus_text().begins_with("Buy") or focus_text().begins_with("Put")),
		"the focus starts on the first thing to buy (%s)" % focus_text())
	var tabs := 0
	for c in hud._dialog.find_children("*", "Button", true, false):
		tabs += 1 if c.has_meta("tab") else 0
	check(tabs == 3, "Workshop | Pack | Colours tabs (%d)" % tabs)
	check(fits((hud._dialog as Control).get_child(1) as Control), "workshop fits 1280x800")
	var headings: Array[String] = []
	for c in hud._dialog.find_children("*", "Label", true, false):
		if (c as Label).text in ClassDefs.SHOP_CATS:
			headings.append((c as Label).text)
	check(headings == ClassDefs.SHOP_CATS, "the workshop shows each category once (%s)" % str(headings))
	check(small_text(hud._dialog).is_empty(), "workshop text is at least %d px %s" % [MIN_TEXT, str(small_text(hud._dialog))])
	for i in 6:
		await pad(JOY_BUTTON_DPAD_DOWN)
	var list: ScrollContainer = hud._dialog.find_children("*", "ScrollContainer", true, false)[0]
	check(inside(list) and list.scroll_vertical > 0, "moving down the shop scrolls it (%d)" % list.scroll_vertical)
	await shot("pad_03_workshop")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(hud._dialog_kind == "inventory", "RB: the pack")
	check(fits((hud._dialog as Control).get_child(1) as Control) and small_text(hud._dialog).is_empty(), "pack fits, text big enough")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(hud._dialog_kind == "colors", "RB: the colours (no keyboard C needed)")
	check(fits((hud._dialog as Control).get_child(1) as Control) and small_text(hud._dialog).is_empty(), "colours fit, text big enough")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(hud._dialog_kind == "workshop", "RB wraps round to the workshop")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(hud._dialog_kind == "colors", "LB goes the other way")
	await shot("pad_04_colours")
	var c0 := s.ctl.selected_color
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_A)
	check(hud._dialog == null and s.ctl.selected_color == c0 + 1, "D-pad and A pick a colour (%d -> %d)" % [c0, s.ctl.selected_color])
	# away from base the same button opens the pack, with two tabs
	s.player.position = Vector3(20.5, s.m.world.surface_y(20, 30), 30.5)
	await frames(5)
	await pad(JOY_BUTTON_BACK)
	check(hud._dialog_kind == "inventory", "away from base View opens the pack")
	tabs = 0
	for c in hud._dialog.find_children("*", "Button", true, false):
		tabs += 1 if c.has_meta("tab") else 0
	check(tabs == 2, "Pack | Colours tabs only (%d)" % tabs)
	await pad(JOY_BUTTON_B)
	check(hud._dialog == null, "B closes it")
	# picked up the pad with a dialog already open from the keyboard
	Inputs.using_pad = false
	hud.open_dialog("pause")
	await frames(2)
	check(focus() == null, "opened with the keyboard: nothing pre-selected")
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(inside(hud._dialog), "the first D-pad press lands on a button (%s)" % focus_text())
	hud.close_dialog()
	hud._exit()
	await frames(10)

	# --- Free Build: flight and saves are pause-menu buttons -----------
	main.start_match({"mode": "free", "seed": 5, "goal": 9999, "team": 0, "class": "maestro", "team_size": 1})
	for i in 1800:
		if main.session != null and main.session.loaded:
			break
		await frames(1)
	await frames(30)
	s = main.session
	hud = s.hud
	await pad(JOY_BUTTON_START)
	for label: String in ["Flight on / off", "Quick save", "Quick load"]:
		check(button(hud._dialog, label) != null, "Free Build pause menu has %s" % label)
	check(fits((hud._dialog as Control).get_child(1) as Control), "Free Build pause menu fits 1280x800")
	var fly := button(hud._dialog, "Flight on / off")
	if fly != null:
		fly.grab_focus()
		await pad(JOY_BUTTON_A)
		check(s.player.flying and hud._dialog == null, "Flight on / off toggles flight")
	hud._exit()
	await frames(10)
	print("---- pad run: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails > 0 else 0)
