class_name MainMenu
extends Control
## Title screen: mode select, match setup (team, class, goal, bots), settings, help.

signal start_requested(settings: Dictionary)

const HELP := """GOAL  Dig up golden cheese and carry it home. First team to the cheese goal wins. Goals go up to 250; the map always holds at least 2.5 cheese per point of goal.

MAPS  Esc > Export map saves the current map. Pick it under Map when you set up a Cheese Race, a hosted game or Free Build. The Maps folder button opens the folder, so you can share .bwmap files.

DIG  Hold left mouse. Dirt takes 2 hits, stone 4, scrap 5. Mined dirt, stone, ice and obsidian go into your stash; place them with right mouse (1-4 picks the material). Wood is scenery: it breaks but gives nothing.

CHEESE  Each golden block is one cheese. Walk over it to pick it up. Carrying cheese slows you down, more for every extra piece (45% / 34% / 25% speed), and your dash (Shift) is weaker (half with one cheese, less with more) and costs 40 stamina instead of 25 - build highways or get an escort. Walk into your base to bank it. G drops one.

BONK  Left-click an enemy rat to bonk it: nobody gets hurt, but they drop a cheese and can't grab it back for 2 seconds. A Rat Knight Shield (gear, J) raised for 5 s makes you bonk-proof.

GROUND POUND  A full double jump landed flat thumps the block under you like a dig.

SNEAKY STUFF  Bubble Shoes (gear): J switches them on, and stepping off an edge blows a bubble to stand on (2 scrap each, pops after 10 s). Cheese Decoy: looks just like cheese to the other team and dazes whoever digs it. Squeaker Pad: squeaks and marks the spot for your team when an enemy steps on it (three times). Wind-up Decoy: a clockwork you with a cheese, marching off and dropping crumbs - enemies who bonk it get a TNT blast, and it goes off by itself after 20 s. Anyone carrying cheese leaves a crumb trail. Impulse Grenade: sticks where it lands and throws everyone near it away - no damage; Ctrl+Q at your feet launches you. Teleporter Set: Q puts down an entrance, Q again an exit - your team stands on the entrance for a moment and pops out at the exit (one way, no cheese, one set each).

SCRAP  Mine orange scrap for currency. Every cheese either team banks makes new scrap worth more. Spend it in the workshop (B, at your base): ladders, springs, conveyors, traps, TNT, gates. Conveyors and highways are laid into the floor you aim at; a conveyor runs toward the bright edge of your target square. Aim at a ladder and press Q to extend it up or down. Q places the equipped gadget, R changes it, I opens your pack.

COLOUR  Press C to pick one of 36 colours, including greys and see-through glass. With slot 8, left click dyes a dirt or painted block (anything else is dug as usual) and right mouse places painted blocks (each costs one dirt, or stone when you have no dirt; digging one gives a dirt back); with the chisel (9) right mouse adds painted microvoxels (glass is full blocks only).

RAIDS  Stand inside the ENEMY base for 3 seconds to steal a cheese they already banked. Everyone hears the alarm, and any defender standing in their own base locks the vault - so guard it, gate it, trap it.

GATES  Aim at your own Team Gate and press Q to put a ladder, spring, conveyor, wall spring or highway INSIDE it: your team uses the gadget, enemies still bump into the gate. (A highway aimed at the top of a gate lies on top instead.)

CLASSES  Digger: carries 3, Super Dig (E) smashes a 3x3x3. Scout: fast, sniffs out cheese. Builder: patches walls (E), starts with Team Blocks (a Q gadget only your team can stand on; also in the workshop), free team gates, shops anywhere. Saboteur: TNT and traps. E and F are class abilities.

CHISEL (9)  Every block is 7x7x7 microvoxels. Left mouse carves one, right mouse adds one from the selected material. You climb ledges up to 4 microvoxels automatically, so you can carve stairs. Carving and refilling is zero-sum: 343 microvoxels is one block.

PANTOGRAPH (0)  Left-click two corners to copy a build (up to 9 blocks a side, carvings included), aim, then right-click to paste. X rotates, Z mirrors left-right, Y flips upside down, U inverts (empty spots fill with the main material, blocks become empty). Pasting costs the materials. Only building materials copy - never cheese, scrap, traps or TNT.

MOBILE TNT  Q throws a bouncing dynamite stick (Ctrl+Q sets it down). Springs launch it, conveyors carry it, ice lets it slide, wall springs bat it back, glue stops it, pitfalls swallow it.

SIEGE  Buy a Scrap Cannon, Wrecking Crane or Bulldozer, place it with Q, look at it and press T. Mouse aims, left mouse works it, A / D turn the bulldozer, T leaves. Each cannon shot costs 2 scrap. Machines have no engines: put conveyors under or beside them. Stone shrugs off light hits; obsidian (12 hits) laughs at most things.

ALSO  V toggles first/third person. Enemy name tags only show while you can see that rat. Ctrl+K respawns at base (you leave your cheese and materials behind). Lava sends you home. Esc pauses."""

var _page: VBoxContainer
var _team := 0
var _class := "digger"
var _goal := 8
var _mode := "race"                 # the setup page: "race" (Cheese Race) or "scrap" (Scrap Race)
var _scrap_goal := Config.SCRAP_GOAL
var _mutators: Array[String] = []   # the setup page's Extras (Mutators.LIST)
var _team_size := 2
var _skill := 1
var _seed_edit: LineEdit
var _blurb: Label
var _class_buttons: Dictionary = {}
var _team_buttons: Array[Button] = []
var _hosting := false
var _message := ""
var _name_edit: LineEdit
var _address_edit: LineEdit
var _port_edit: LineEdit
var _server_list: VBoxContainer
var _map_pick: OptionButton
var _map_paths: Array[String] = []
var _free_hosting := false
var _lobby_check: CheckBox
var _status: Label
var _back := Callable()   # where B / Esc goes from this page (nowhere on the home page)

## Public servers are listed in servers.json (ServerList.list_url(): the game's
## repository by default), so adding one is a one-line change; each row then
## asks that server for its live status (see docs/MULTIPLAYER.md).
var _server_rows: Array = []        # [entry, status label, ping label, join button]
var _preview: TextureRect           # Customize Rat: your rat, turning and moving
var _preview_as := {"class": "digger", "team": 0, "view": "front", "t": 0.0}
var _hat_buttons: Dictionary = {}   # hat id -> its button


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_team = int(Config.get_value("last_team"))
	_class = String(Config.get_value("last_class"))
	if not ClassDefs.ORDER.has(_class):
		_class = "digger"
	_goal = int(Config.get_value("goal"))
	_mode = "scrap" if String(Config.get_value("last_mode")) == "scrap" else "race"
	_scrap_goal = int(Config.get_value("scrap_goal"))
	_mutators = Mutators.clean(Config.get_value("mutators"))
	_team_size = int(Config.get_value("team_size"))
	_skill = clampi(int(Config.get_value("bot_skill")), 0, 2)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.09, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# strata stripes: a quick "cross-section of earth" backdrop
	var strata := [Color(0.36, 0.56, 0.26), Color(0.42, 0.28, 0.18), Color(0.34, 0.23, 0.15), Color(0.27, 0.25, 0.26), Color(0.2, 0.18, 0.2)]
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	add_child(stack)
	for i in strata.size():
		var band := ColorRect.new()
		band.color = strata[i]
		band.size_flags_vertical = Control.SIZE_EXPAND_FILL
		band.size_flags_stretch_ratio = 0.25 if i == 0 else 1.0
		stack.add_child(band)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	panel.add_child(_page)
	_show_home()


func _clear() -> void:
	_back = Callable()
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()


func _header(subtitle: String) -> void:
	var path := "res://assets/ui/burrow_masthead.png"
	if ResourceLoader.exists(path):
		var art := TextureRect.new()
		art.texture = load(path)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0, 104)
		_page.add_child(art)
	var title := UiKit.label("BURROW WARS", 44, UiKit.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(title)
	var sub := UiKit.label(subtitle, 19, UiKit.PAPER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(sub)


func _show_home() -> void:
	_clear()
	_header("Bunker, Build, Bonk! Bring Home The Golden Cheese!")
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 8)
	_page.add_child(col)
	var play := Icons.on_button(UiKit.button("Cheese Race / Scrap Race (Bots)", _show_setup, Vector2(320, 52)), "cheese")
	if not bool(Config.get_value("tutorial_done")):
		var hint := UiKit.label("New here? Try Learn to Play first - about five minutes.", 15, UiKit.BRASS)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(hint)
	col.add_child(play)
	col.add_child(Icons.on_button(UiKit.button("Learn to Play", _start_tutorial, Vector2(320, 44)), "book"))
	col.add_child(Icons.on_button(UiKit.button("Play Online", _show_online, Vector2(320, 44)), "online"))
	col.add_child(Icons.on_button(UiKit.button("Free Build", _show_free.bind(false), Vector2(320, 44)), "hammer"))
	var dress := UiKit.button("Customize Rat", _show_customize, Vector2(320, 44))
	dress.icon = Hats.icon("party", int(Config.get_value("last_team")))
	dress.expand_icon = true
	dress.add_theme_constant_override("icon_max_width", 26)
	dress.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(dress)
	col.add_child(Icons.on_button(UiKit.button("How to Play", _show_help, Vector2(320, 44)), "book"))
	col.add_child(Icons.on_button(UiKit.button("Settings & Controls", _show_settings, Vector2(320, 44)), "gear"))
	col.add_child(Icons.on_button(UiKit.button("Credits & Licences", _show_credits, Vector2(320, 44)), "book"))
	if not OS.has_feature("web"):
		col.add_child(Icons.on_button(UiKit.button("Quit", func() -> void: get_tree().quit(), Vector2(320, 44)), "door"))
	if _message != "":
		var msg := UiKit.wrapped(_message, 15, UiKit.TEAM[1].lightened(0.3))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page.add_child(msg)
		_message = ""
	play.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	## Controller (and keyboard) navigation: B or Esc goes back a page, and the
	## first stick or D-pad push lands on a button when nothing has the focus.
	if event.is_action_pressed("ui_cancel") and _back.is_valid():
		get_viewport().set_input_as_handled()
		_back.call()
	elif UiKit.is_pad_nav(event) and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()
		UiKit.focus_first(_page)


func show_message(text: String) -> void:
	## Shown on the home page, e.g. why an online game ended.
	_message = text
	_show_home()


func _show_setup() -> void:
	_hosting = false
	_setup_page()


func _show_host_setup() -> void:
	if not _save_identity():
		return
	_hosting = true
	_setup_page()


func _setup_page() -> void:
	_clear()
	_page.add_child(UiKit.label("Host an online game" if _hosting else "Game setup", 28, UiKit.BRASS))
	# mode
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	var first_mode: Button = null
	for mode: String in ["race", "scrap"]:
		var mb := Icons.on_button(UiKit.button("Cheese Race" if mode == "race" else "Scrap Race", func() -> void:
			if _mode != mode:
				_mode = mode
				_setup_page()
				_focus_mode(), Vector2(200, 40)), "cheese" if mode == "race" else "scrap")
		mb.toggle_mode = true
		mb.button_pressed = mode == _mode
		mb.set_meta("mode", mode)
		modes.add_child(mb)
		if first_mode == null:
			first_mode = mb
	var mode_blurb := UiKit.label("Bank the most golden cheese." if _mode == "race" else "Bank scrap; cheese makes yours worth more.", 15, UiKit.PAPER.darkened(0.1))
	modes.add_child(mode_blurb)
	_page.add_child(UiKit.row(UiKit.label("Mode"), modes))
	_page.add_child(UiKit.row(UiKit.label("Extras"), _option_picker(Mutators.EXTRAS, "Events during the match: open the list and tick any.")))
	_page.add_child(UiKit.row(UiKit.label("Modifiers"), _option_picker(Mutators.MODIFIERS, "Rule changes for the whole match: tick any.")))
	# team
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 8)
	_team_buttons.clear()
	for t in 2:
		var b := UiKit.button(Match.TEAM_NAMES[t] + " team", _pick_team.bind(t), Vector2(160, 40))
		b.toggle_mode = true
		b.add_theme_color_override("font_color", UiKit.TEAM[t])
		b.add_theme_color_override("font_pressed_color", UiKit.TEAM[t].lightened(0.3))
		teams.add_child(b)
		_team_buttons.append(b)
	_page.add_child(UiKit.row(UiKit.label("Team"), teams))
	# class
	var classes := HBoxContainer.new()
	classes.add_theme_constant_override("separation", 8)
	_class_buttons.clear()
	for id: String in ClassDefs.ORDER:
		var cb := Icons.on_button(UiKit.button(ClassDefs.CLASSES[id]["name"], _pick_class.bind(id), Vector2(130, 40)), id, true)
		cb.toggle_mode = true
		classes.add_child(cb)
		_class_buttons[id] = cb
	_page.add_child(UiKit.row(UiKit.label("Class"), classes))
	_blurb = UiKit.wrapped("", 15, UiKit.PAPER.darkened(0.1))
	_blurb.custom_minimum_size = Vector2(0, 44)
	_page.add_child(_blurb)
	# goal
	var goal_label := UiKit.label("", 17)
	var goal_slider: HSlider
	if _mode == "scrap":
		goal_slider = UiKit.slider(50, 3000, 50, _scrap_goal, func(v: float) -> void:
			_scrap_goal = int(v)
			goal_label.text = _goal_text()
		)
	else:
		goal_slider = UiKit.slider(3, 250, 1, _goal, func(v: float) -> void:
			_goal = int(v)
			goal_label.text = _goal_text()
		)
	goal_label.text = _goal_text()
	_page.add_child(UiKit.row(goal_label, goal_slider))
	var size_label := UiKit.label("", 17)
	var size_slider := UiKit.slider(1, 8, 1, _team_size, func(v: float) -> void:
		_team_size = int(v)
		size_label.text = _size_text()
	)
	size_label.text = _size_text()
	_page.add_child(UiKit.row(size_label, size_slider))
	var skill_names := ["Relaxed", "Normal", "Fierce"]
	var skill_label := UiKit.label("Bot skill: " + skill_names[_skill], 17)
	var skill_slider := UiKit.slider(0, 2, 1, _skill, func(v: float) -> void:
		_skill = int(v)
		skill_label.text = "Bot skill: " + skill_names[_skill]
	)
	_page.add_child(UiKit.row(skill_label, skill_slider))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.custom_minimum_size = Vector2(220, 34)
	_page.add_child(UiKit.row(UiKit.label("Map seed (same seed = same map)"), _seed_edit))
	_page.add_child(_map_row())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(UiKit.button("Back", _show_online if _hosting else _show_home, Vector2(160, 46)))
	var go := UiKit.button("Open server & play" if _hosting else "Start digging!", _start_race, Vector2(260, 46))
	if _hosting:
		_port_edit = LineEdit.new()
		_port_edit.text = str(Net.DEFAULT_PORT)
		_port_edit.custom_minimum_size = Vector2(120, 34)
		_page.add_child(UiKit.row(UiKit.label("Port (UDP; forward it on your router for internet play)"), _port_edit))
		_lobby_check = CheckBox.new()
		_lobby_check.text = "Wait in the playground lobby: friends join there, and the match starts when you press %s" % Inputs.key_name("start_match")
		_lobby_check.button_pressed = bool(Config.get_value("host_lobby"))
		_lobby_check.toggled.connect(func(on: bool) -> void: go.text = "Open lobby" if on else "Open server & play")
		_page.add_child(UiKit.row(UiKit.label("Lobby"), _lobby_check))
		go.text = "Open lobby" if _lobby_check.button_pressed else "Open server & play"
	buttons.add_child(go)
	_page.add_child(buttons)
	_pick_team(_team)
	_pick_class(_class)
	_back = _show_online if _hosting else _show_home
	go.grab_focus()


func _size_text() -> String:
	if _hosting:
		return "Seats per team: %d  (players take bot seats as they join)" % _team_size
	return "Rats per team: %d  (you + %d bot allies vs %d bots)" % [_team_size, _team_size - 1, _team_size]


func _pick_team(t: int) -> void:
	_team = t
	for i in _team_buttons.size():
		_team_buttons[i].button_pressed = i == t


func _pick_class(id: String) -> void:
	_class = id
	for k: String in _class_buttons:
		(_class_buttons[k] as Button).button_pressed = k == id
	_blurb.text = ClassDefs.CLASSES[id]["blurb"]


func _goal_text() -> String:
	if _mode == "scrap":
		return "Scrap goal: %d  (%d scrap blocks at the starting value)" % [_scrap_goal, ceili(_scrap_goal / float(Config.BASE_SCRAP_PER_BLOCK))]
	return "Cheese goal: %d  (map holds %d+ cheese)" % [_goal, MapGenerator.min_cheese(_goal)]


func _option_picker(ids: Array, hint: String) -> Control:
	## A drop-down checklist of match options (one group of Mutators): tick any number.
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var pick := MenuButton.new()
	pick.flat = false
	pick.custom_minimum_size = Vector2(260, 38)
	pick.focus_mode = Control.FOCUS_ALL
	var popup := pick.get_popup()
	popup.hide_on_checkable_item_selection = false   # (tick several in one go)
	for i in ids.size():
		var id: String = ids[i]
		popup.add_check_item(String(Mutators.NAMES[id]), i)
		popup.set_item_checked(i, _mutators.has(id))
		popup.set_item_tooltip(i, String(Mutators.BLURBS[id]))
	var about := UiKit.wrapped("", 13, UiKit.PAPER.darkened(0.15))
	about.custom_minimum_size = Vector2(460, 0)
	var refresh := func() -> void:
		var mine: Array = _mutators.filter(func(id: String) -> bool: return ids.has(id))
		var names := Mutators.describe(mine)
		pick.text = "%s  v" % (names if names != "" else "None")
		if mine.size() > 2:
			pick.text = "%d ticked  v" % mine.size()
		# (one line: the latest one ticked; each option's tooltip has the rest)
		about.text = String(Mutators.BLURBS[mine[-1]]) if not mine.is_empty() else hint
	popup.id_pressed.connect(func(i: int) -> void:
		var id: String = ids[i]
		if _mutators.has(id):
			_mutators.erase(id)
		else:
			_mutators.append(id)
		_mutators = Mutators.clean(_mutators)
		popup.set_item_checked(i, _mutators.has(id))
		refresh.call())
	refresh.call()
	box.add_child(pick)
	box.add_child(about)
	return box


func _focus_mode() -> void:
	## After switching mode the page is rebuilt: keep the focus on the mode buttons.
	for b in _page.find_children("*", "Button", true, false):
		if b.has_meta("mode") and String(b.get_meta("mode")) == _mode:
			(b as Button).grab_focus()


func _map_row() -> Control:
	## "New map" or a saved / exported map from the maps folder.
	_map_pick = OptionButton.new()
	_map_pick.custom_minimum_size = Vector2(300, 34)
	_map_pick.add_item("New map from the seed")
	_map_paths = VoxelWorld.list_maps()
	for path in _map_paths:
		_map_pick.add_item("Import: " + path.get_file().get_basename())
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_map_pick)
	if not OS.has_feature("web"):   # (a browser has no folder to open)
		box.add_child(UiKit.button("Maps folder", func() -> void:
			DirAccess.make_dir_recursive_absolute(VoxelWorld.MAPS_DIR)
			OS.shell_open(ProjectSettings.globalize_path(VoxelWorld.MAPS_DIR)), Vector2(140, 34)))
	box.tooltip_text = "Maps saved with F5 in Free Build or with Export map in the Esc menu. Put .bwmap files from friends in the maps folder to import them."
	return UiKit.row(UiKit.label("Map"), box)


func _selected_map() -> String:
	if _map_pick == null or not is_instance_valid(_map_pick) or _map_pick.selected <= 0:
		return ""
	return _map_paths[_map_pick.selected - 1]


func _seed() -> int:
	var text := _seed_edit.text.strip_edges() if _seed_edit != null else ""
	if text == "":
		return randi_range(1, 999999)
	return text.to_int() if text.is_valid_int() else absi(hash(text)) % 1000000


func _start_race() -> void:
	Config.set_value("last_team", _team)
	Config.set_value("last_class", _class)
	Config.set_value("goal", _goal)
	Config.set_value("scrap_goal", _scrap_goal)
	Config.set_value("last_mode", _mode)
	Config.set_value("mutators", _mutators)
	Config.set_value("team_size", _team_size)
	Config.set_value("bot_skill", _skill)
	Config.save()
	var s := {"mode": _mode, "mutators": _mutators.duplicate(), "seed": _seed(), "goal": _scrap_goal if _mode == "scrap" else _goal, "team": _team, "class": _class, "team_size": _team_size,
		"bot_rest": [7.0, 3.0, 0.0][_skill]}
	if _selected_map() != "":
		s["map_file"] = _selected_map()
	if _hosting:
		s["net"] = "host"
		s["lobby"] = _lobby_check != null and is_instance_valid(_lobby_check) and _lobby_check.button_pressed
		Config.set_value("host_lobby", s["lobby"])
		Config.save()
		var port_text := _port_edit.text.strip_edges() if _port_edit != null else ""
		var port := port_text.to_int() if port_text.is_valid_int() else 0
		s["port"] = port if port > 0 and port < 65536 else Net.DEFAULT_PORT
	start_requested.emit(s)


func _show_free(hosting := false) -> void:
	_free_hosting = hosting
	_clear()
	_page.add_child(UiKit.label("Host Free Build" if hosting else "Free Build", 28, UiKit.BRASS))
	_page.add_child(UiKit.wrapped("A creative sandbox: fly with N, everything is free. Start on a fresh map, or import one you saved (F5) or exported (Esc > Export map). Imported maps keep their carvings and machines.", 15, UiKit.PAPER.darkened(0.1)))
	_page.add_child(_map_row())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(UiKit.button("Back", _show_online if hosting else _show_home, Vector2(160, 46)))
	var go := UiKit.button("Open server & build" if hosting else "Start building", _start_free, Vector2(260, 46))
	buttons.add_child(go)
	_page.add_child(buttons)
	_back = _show_online if hosting else _show_home
	go.grab_focus()


func _start_free() -> void:
	var s := {"mode": "free", "seed": randi_range(1, 999999), "goal": 9999, "team": 0, "class": "maestro", "team_size": 1}
	if _selected_map() != "":
		s["map_file"] = _selected_map()
	if _free_hosting:
		s["net"] = "host"
		s["port"] = Net.DEFAULT_PORT
	start_requested.emit(s)


func _show_help() -> void:
	_clear()
	_page.add_child(UiKit.label("How to Play", 28, UiKit.BRASS))
	var sc := UiKit.scroll(440)
	var pad := UiKit.wrapped(Inputs.pad_help(), 16, UiKit.BRASS.lightened(0.3))
	(sc[1] as VBoxContainer).add_child(UiKit.wrapped(HELP, 16))
	(sc[1] as VBoxContainer).add_child(pad)
	if Inputs.using_pad:
		(sc[1] as VBoxContainer).move_child(pad, 0)
	_page.add_child(sc[0])
	var back := UiKit.button("Back", _show_home, Vector2(160, 44))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_page.add_child(back)
	_back = _show_home
	back.grab_focus()


func _start_tutorial() -> void:
	start_requested.emit({"mode": "race", "seed": 4242, "goal": 1, "team": 0, "class": "digger", "team_size": 1,
		"tutorial": true, "bot_rest": 0.0})


func _show_credits() -> void:
	_clear()
	_page.add_child(UiKit.label("Credits & Licences", 28, UiKit.BRASS))
	var text := RichTextLabel.new()
	text.bbcode_enabled = false
	text.text = Credits.text()
	text.custom_minimum_size = Vector2(700, 440)
	text.scroll_active = true
	text.selection_enabled = true
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_color_override("default_color", UiKit.PAPER)
	text.focus_mode = Control.FOCUS_ALL
	_page.add_child(text)
	var back := UiKit.button("Back", _show_home, Vector2(160, 44))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_page.add_child(back)
	_back = _show_home
	back.grab_focus()


func _show_settings() -> void:
	_clear()
	_page.add_child(UiKit.label("Settings & Controls", 28, UiKit.BRASS))
	var sc := UiKit.scroll(460)
	(sc[1] as VBoxContainer).add_child(SettingsPanel.new())
	_page.add_child(sc[0])
	var back := UiKit.button("Back", _show_home, Vector2(160, 44))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_page.add_child(back)
	_back = _show_home
	UiKit.focus_first(sc[1])


# ---------------------------------------------------------------- customize

func _show_customize() -> void:
	## Customize Rat: pick the hat your rat wears in every match. The preview
	## can show any class and team, and turn around.
	_clear()
	_page.add_child(UiKit.label("Customize Rat", 28, UiKit.BRASS))
	_preview_as = {"class": _class, "team": _team, "view": "front", "t": 0.0}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_page.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.09, 0.06, 0.9), UiKit.BRASS, 10, 2, 8))
	left.add_child(stage)
	_preview = TextureRect.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(240, 240 * RatSprite.CELL_H / RatSprite.CELL)
	stage.add_child(_preview)
	left.add_child(UiKit.button("Turn around", func() -> void:
		var views := ["front", "side", "back"]
		_preview_as["view"] = views[(views.find(_preview_as["view"]) + 1) % views.size()], Vector2(256, 40)))
	var classes := HBoxContainer.new()
	classes.add_theme_constant_override("separation", 4)
	left.add_child(classes)
	for id: String in ClassDefs.ORDER:
		var b := Icons.on_button(UiKit.button("", func() -> void: _preview_as["class"] = id, Vector2(61, 44)), id, true, 32)
		b.tooltip_text = "See it on a %s" % String(ClassDefs.CLASSES[id]["name"])
		classes.add_child(b)
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 4)
	left.add_child(teams)
	for t in 2:
		var tb := UiKit.button(Match.TEAM_NAMES[t], func() -> void: _preview_as["team"] = t, Vector2(126, 36))
		tb.add_theme_color_override("font_color", UiKit.TEAM[t].lightened(0.3))
		teams.add_child(tb)
	var note := UiKit.label("Preview only: pick your class\nand team when you start a game.", 13, UiKit.PAPER.darkened(0.25))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(note)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(UiKit.label("Hats", 22, UiKit.BRASS))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	var group := ButtonGroup.new()
	_hat_buttons.clear()
	var current := Hats.clean(Config.get_value("hat"))
	for id: String in Hats.LIST:
		var b := UiKit.button(String(Hats.NAMES[id]), _pick_hat.bind(id), Vector2(178, 52))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == current
		var tex := Hats.icon(id, _team)
		if tex != null:
			b.icon = tex
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 36)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(b)
		_hat_buttons[id] = b
	var hint := UiKit.label("Everyone sees your hat online. Purely for looks.", 14, UiKit.PAPER.darkened(0.15))
	right.add_child(hint)

	var back := UiKit.button("Back", _show_home, Vector2(160, 44))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_page.add_child(back)
	_back = _show_home
	(_hat_buttons[current] as Button).grab_focus()


func _pick_hat(id: String) -> void:
	Config.set_value("hat", Hats.clean(id))
	Config.save()
	if _hat_buttons.has(id):
		(_hat_buttons[id] as Button).button_pressed = true


func _animate_preview(delta: float) -> void:
	## The rat in the preview: idle, a little run, a hop, round again.
	_preview_as["t"] = float(_preview_as["t"]) + delta
	var t := float(_preview_as["t"])
	var anim: String = ["idle", "idle", "run", "jump"][int(t / 1.6) % 4]
	var frame := int(t * float(RatSprite.FPS[anim])) % int(RatSprite.FRAMES[anim])
	var hat := Hats.clean(Config.get_value("hat"))
	var cls := String(_preview_as["class"])
	var team := int(_preview_as["team"])
	var view := String(_preview_as["view"])
	var tex := RatSprite._frame(cls, team, anim, frame, view, hat) if view != "side" else null
	if tex == null:
		tex = RatSprite._frame(cls, team, anim, frame, "side", hat)
	_preview.texture = tex


# ---------------------------------------------------------------- online

func _show_online() -> void:
	_clear()
	_hosting = false
	_page.add_child(UiKit.label("Play Online", 28, UiKit.BRASS))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Net.NAME_MAX
	_name_edit.placeholder_text = "your rat's name"
	_name_edit.text = String(Config.get_value("player_name"))
	if _name_edit.text == "":
		_name_edit.text = suggested_name()   # a ready-made name, so a controller never has to type one
	_name_edit.custom_minimum_size = Vector2(260, 34)
	_page.add_child(UiKit.row(UiKit.label("Name"), _name_edit))
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 8)
	_team_buttons.clear()
	for t in 2:
		var b := UiKit.button(Match.TEAM_NAMES[t], _pick_team.bind(t), Vector2(110, 36))
		b.toggle_mode = true
		b.add_theme_color_override("font_color", UiKit.TEAM[t])
		b.add_theme_color_override("font_pressed_color", UiKit.TEAM[t].lightened(0.3))
		teams.add_child(b)
		_team_buttons.append(b)
	_page.add_child(UiKit.row(UiKit.label("Preferred team"), teams))
	var classes := HBoxContainer.new()
	classes.add_theme_constant_override("separation", 6)
	_class_buttons.clear()
	for id: String in ClassDefs.ORDER:
		var cb := Icons.on_button(UiKit.button(ClassDefs.CLASSES[id]["name"], _pick_class.bind(id), Vector2(104, 36)), id, true, 22)
		cb.toggle_mode = true
		classes.add_child(cb)
		_class_buttons[id] = cb
	_page.add_child(UiKit.row(UiKit.label("Class"), classes))
	_blurb = UiKit.wrapped("", 14, UiKit.PAPER.darkened(0.1))
	_page.add_child(_blurb)
	_pick_team(_team)
	_pick_class(_class)

	var head := HBoxContainer.new()
	var title := UiKit.label("Public servers", 20, UiKit.BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button("Refresh", _refresh_servers, Vector2(110, 32)))
	_page.add_child(head)
	var sc := UiKit.scroll(130)
	_server_list = sc[1]
	_page.add_child(sc[0])
	_server_list.add_child(UiKit.label("Looking for servers...", 15, UiKit.PAPER.darkened(0.2)))
	_fetch_servers()

	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "address, address:port or wss://..."
	_address_edit.text = String(Config.get_value("last_address"))
	_address_edit.custom_minimum_size = Vector2(300, 34)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	join_row.add_child(_address_edit)
	join_row.add_child(UiKit.button("Join", func() -> void: _join(_address_edit.text), Vector2(110, 36)))
	_page.add_child(UiKit.row(UiKit.label("Join by address"), join_row))
	_status = UiKit.wrapped("", 15, UiKit.PAPER)
	_page.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(UiKit.button("Back", _show_home, Vector2(160, 46)))
	if Net.enet_available():   # a browser can't open a server, only join WebSocket ones
		buttons.add_child(Icons.on_button(UiKit.button("Host a Race...", _show_host_setup, Vector2(230, 46)), "cheese"))
		buttons.add_child(Icons.on_button(UiKit.button("Host Free Build", _host_free, Vector2(210, 46)), "hammer"))
	_page.add_child(buttons)
	_back = _show_home
	if Inputs.using_pad:
		_team_buttons[_team].grab_focus()   # typing needs the on-screen keyboard: start on the buttons
	else:
		_name_edit.grab_focus()


static func suggested_name() -> String:
	const PARTS := ["Whisker", "Nibbles", "Squeak", "Burrow", "Cheddar", "Scamper", "Gnaw", "Pip"]
	return Net.clean_name("%s%d" % [PARTS[randi() % PARTS.size()], randi_range(10, 99)])


func _host_free() -> void:
	## A creative sandbox friends can join: everyone builds with everything.
	if not _save_identity():
		return
	_show_free(true)


func _save_identity() -> bool:
	var n := Net.clean_name(_name_edit.text) if _name_edit != null and is_instance_valid(_name_edit) else Net.player_name
	if n == "":
		if _status != null and is_instance_valid(_status):
			_status.text = "Pick a name first."
		return false
	Net.player_name = n
	Config.set_value("player_name", n)
	Config.set_value("last_team", _team)
	Config.set_value("last_class", _class)
	Config.save()
	return true


static func split_address(text: String) -> Array:
	## "host", "host:port" or "[ipv6]:port" -> [host, port]
	var t := text.strip_edges()
	var port := Net.DEFAULT_PORT
	if t.begins_with("["):
		var close := t.find("]")
		if close > 0:
			var rest := t.substr(close + 1)
			if rest.begins_with(":") and rest.substr(1).is_valid_int():
				port = rest.substr(1).to_int()
			return [t.substr(1, close - 1), port]
	if t.count(":") == 1:
		var parts := t.split(":")
		if parts[1].is_valid_int():
			port = parts[1].to_int()
		return [parts[0], port]
	return [t, port]


func _join(address: String) -> void:
	if not _save_identity():
		return
	var hp := [address.strip_edges(), 0] if Net.is_ws_url(address) else split_address(address)
	if String(hp[0]) == "":
		_status.text = "Type the server's address (ask the host for it)."
		return
	Config.set_value("last_address", address.strip_edges())
	Config.save()
	var err := Net.join(String(hp[0]), int(hp[1]), {"name": Net.player_name, "team": _team, "class": _class,
		"hat": Hats.clean(Config.get_value("hat"))})
	if err != "":
		_status.text = err
		return
	_status.text = "Connecting to %s ..." % (String(hp[0]) if Net.is_ws_url(address) else "%s:%d" % [hp[0], hp[1]])
	var waiting := _status
	Net.join_failed.connect(func(reason: String) -> void:
		if is_instance_valid(waiting):
			waiting.text = reason, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if _preview != null and is_instance_valid(_preview):
		_animate_preview(delta)
	# joining: the map arrives in parts after the server seats us
	var got := Net.join_progress()
	if got >= 0.0 and _status != null and is_instance_valid(_status):
		_status.text = "Joined - downloading the map... %d%%" % roundi(got * 100.0)


func _refresh_servers() -> void:
	if _server_list == null or not is_instance_valid(_server_list):
		return
	for c in _server_list.get_children():
		c.queue_free()
	_server_list.add_child(UiKit.label("Looking for servers...", 15, UiKit.PAPER.darkened(0.2)))
	_fetch_servers()


func _fetch_servers() -> void:
	var url := ServerList.list_url()
	if not url.begins_with("http"):   # a local file (testing your own list)
		_show_servers.call_deferred(FileAccess.get_file_as_string(url))
		return
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		_show_servers(body.get_string_from_utf8() if result == HTTPRequest.RESULT_SUCCESS and code == 200 else ""))
	if http.request(url) != OK:
		http.queue_free()
		_show_servers("")


func _show_servers(json_text: String) -> void:
	if _server_list == null or not is_instance_valid(_server_list):
		return
	for c in _server_list.get_children():
		c.queue_free()
	_server_rows.clear()
	for entry: Dictionary in ServerList.parse(json_text):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var title := String(entry["name"]) + ("   (%s)" % entry["region"] if String(entry["region"]) != "" else "")
		info.add_child(UiKit.label(title, 16))
		var state := UiKit.label("checking...", 13, UiKit.PAPER.darkened(0.25))
		info.add_child(state)
		row.add_child(info)
		var ping := UiKit.label("", 14, UiKit.PAPER.darkened(0.1))
		ping.custom_minimum_size = Vector2(70, 0)
		row.add_child(ping)
		var join := UiKit.button("Join", _join.bind(String(entry["join"])), Vector2(110, 34))
		var why := ServerList.why_not(entry, null)
		if why != "":
			join.text = why
			join.disabled = true
		row.add_child(join)
		_server_list.add_child(row)
		_server_rows.append([entry, state, ping, join])
		_fetch_status(entry, state, ping, join)
	if _server_rows.is_empty():
		_server_list.add_child(UiKit.wrapped("No public servers listed right now. Join a friend by address, or host a game.", 14, UiKit.PAPER.darkened(0.2)))


func _fetch_status(entry: Dictionary, state: Label, ping: Label, join: Button) -> void:
	## Each row asks its server how it's doing, and times the answer.
	var url := String(entry.get("status", ""))
	if url == "":
		state.text = "no status page"
		return
	var http := HTTPRequest.new()
	http.timeout = 5.0
	add_child(http)
	var t0 := Time.get_ticks_msec()
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		if not is_instance_valid(state):
			return
		var st: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not (st is Dictionary):
			state.text = "not answering"
			state.add_theme_color_override("font_color", UiKit.TEAM[1].lightened(0.2))
			return
		state.text = ServerList.describe(st)
		state.add_theme_color_override("font_color", Color(0.6, 0.95, 0.55))
		ping.text = "~%d ms" % ServerList.ping_ms(float(Time.get_ticks_msec() - t0), url)
		var why := ServerList.why_not(entry, st)
		if why != "":
			join.text = why
			join.disabled = true)
	if http.request(url) != OK:
		http.queue_free()
		state.text = "no status page"
