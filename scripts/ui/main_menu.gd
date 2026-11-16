class_name MainMenu
extends Control
## Title screen: mode select, match setup (team, class, goal, bots), settings, help.

signal start_requested(settings: Dictionary)

const HELP := """GOAL  Dig up golden cheese and carry it home. First team to the cheese goal wins.

DIG  Hold left mouse. Dirt takes 2 hits, stone 4, scrap 5. Mined dirt, stone and wood go into your stash; place them with right mouse (1-4 picks the material).

CHEESE  Each golden block is one cheese. Walk over it to pick it up. Carrying cheese slows you down, more for every extra piece (45% / 34% / 25% speed) - dash (Shift), build highways or get an escort. Walk into your base to bank it. G drops one.

BONK  Left-click an enemy rat to bonk it: nobody gets hurt, but they drop a cheese and can't grab it back for 2 seconds.

SCRAP  Mine orange scrap for currency. Every cheese either team banks makes new scrap worth more. Spend it in the workshop (B, at your base): ladders, springs, conveyors, traps, TNT, gates. Conveyors and highways are laid into the floor you aim at; a conveyor runs toward the bright edge of your target square. Aim at a ladder and press Q to extend it up or down. Q places the equipped gadget, R changes it, I opens your pack.

COLOUR  Press C to pick one of 12 colours. Slot 6 places painted blocks with right mouse; with the chisel (9) right mouse adds painted microvoxels.

RAIDS  Stand inside the ENEMY base for 3 seconds to steal a cheese they already banked. Everyone hears the alarm, and any defender standing in their own base locks the vault - so guard it, gate it, trap it.

CLASSES  Digger: carries 3, Super Dig (E) smashes a 3x3x3. Scout: fast, sniffs out cheese. Builder: patches walls, free team gates, Team Blocks (F) only your team can stand on, shops anywhere. Saboteur: TNT and traps. E and F are class abilities.

CHISEL (9)  Every block is 7x7x7 microvoxels. Left mouse carves one, right mouse adds one from the selected material. You climb ledges up to 4 microvoxels automatically, so you can carve stairs. Carving and refilling is zero-sum: 343 microvoxels is one block.

PANTOGRAPH (0)  Left-click two corners to copy a build (up to 9 blocks a side, carvings included), aim, X to rotate, right-click to paste. It costs the materials. Only building materials copy - never cheese, scrap, traps or TNT.

MOBILE TNT  Q throws a bouncing dynamite stick (Ctrl+Q sets it down). Springs launch it, conveyors carry it, ice lets it slide, wall springs bat it back, glue stops it, pitfalls swallow it.

SIEGE  Buy a Scrap Cannon, Wrecking Crane or Bulldozer, place it with Q, look at it and press T. Mouse aims, left mouse works it, T leaves. Machines have no engines: put conveyors under or beside them. Stone shrugs off light hits; obsidian (12 hits) laughs at most things.

ALSO  V toggles first/third person. Ctrl+K respawns at base (you leave your cheese and materials behind). Lava sends you home. Esc pauses."""

var _page: VBoxContainer
var _team := 0
var _class := "digger"
var _goal := 8
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
var _status: Label

## Public servers are listed in servers.json in the game's GitHub repository,
## so adding one is a one-line change (see docs/MULTIPLAYER.md).
const SERVER_LIST_URL := "https://raw.githubusercontent.com/Beanidip/BurrowWars/main/servers.json"


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_team = int(Config.get_value("last_team"))
	_class = String(Config.get_value("last_class"))
	if not ClassDefs.ORDER.has(_class):
		_class = "digger"
	_goal = int(Config.get_value("goal"))
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
	var sub := UiKit.label(subtitle, 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(sub)


func _show_home() -> void:
	_clear()
	_header("Jam Edition  -  dig, build, bonk, and bring home the golden cheese")
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 8)
	_page.add_child(col)
	var play := UiKit.button("Cheese Race", _show_setup, Vector2(320, 52))
	col.add_child(play)
	col.add_child(UiKit.button("Play Online", _show_online, Vector2(320, 44)))
	col.add_child(UiKit.button("Free Build", _start_free, Vector2(320, 44)))
	col.add_child(UiKit.button("How to Play", _show_help, Vector2(320, 44)))
	col.add_child(UiKit.button("Settings & Controls", _show_settings, Vector2(320, 44)))
	col.add_child(UiKit.button("Quit", func() -> void: get_tree().quit(), Vector2(320, 44)))
	if _message != "":
		var msg := UiKit.wrapped(_message, 15, UiKit.TEAM[1].lightened(0.3))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page.add_child(msg)
		_message = ""
	play.grab_focus()


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
	_page.add_child(UiKit.label("Host an online game" if _hosting else "Cheese Race setup", 28, UiKit.BRASS))
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
		var cb := UiKit.button(ClassDefs.CLASSES[id]["name"], _pick_class.bind(id), Vector2(130, 40))
		cb.toggle_mode = true
		classes.add_child(cb)
		_class_buttons[id] = cb
	_page.add_child(UiKit.row(UiKit.label("Class"), classes))
	_blurb = UiKit.wrapped("", 15, UiKit.PAPER.darkened(0.1))
	_blurb.custom_minimum_size = Vector2(0, 44)
	_page.add_child(_blurb)
	# goal
	var goal_label := UiKit.label("", 17)
	var goal_slider := UiKit.slider(3, 16, 1, _goal, func(v: float) -> void:
		_goal = int(v)
		goal_label.text = "Cheese goal: %d" % _goal
	)
	goal_label.text = "Cheese goal: %d" % _goal
	_page.add_child(UiKit.row(goal_label, goal_slider))
	var size_label := UiKit.label("", 17)
	var size_slider := UiKit.slider(1, 4, 1, _team_size, func(v: float) -> void:
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
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(UiKit.button("Back", _show_home, Vector2(160, 46)))
	if _hosting:
		_port_edit = LineEdit.new()
		_port_edit.text = str(Net.DEFAULT_PORT)
		_port_edit.custom_minimum_size = Vector2(120, 34)
		_page.add_child(UiKit.row(UiKit.label("Port (UDP; forward it on your router for internet play)"), _port_edit))
	var go := UiKit.button("Open server & play" if _hosting else "Start digging!", _start_race, Vector2(260, 46))
	buttons.add_child(go)
	_page.add_child(buttons)
	_pick_team(_team)
	_pick_class(_class)
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


func _seed() -> int:
	var text := _seed_edit.text.strip_edges() if _seed_edit != null else ""
	if text == "":
		return randi_range(1, 999999)
	return text.to_int() if text.is_valid_int() else absi(hash(text)) % 1000000


func _start_race() -> void:
	Config.set_value("last_team", _team)
	Config.set_value("last_class", _class)
	Config.set_value("goal", _goal)
	Config.set_value("team_size", _team_size)
	Config.set_value("bot_skill", _skill)
	Config.save()
	var s := {"mode": "race", "seed": _seed(), "goal": _goal, "team": _team, "class": _class, "team_size": _team_size,
		"bot_rest": [7.0, 3.0, 0.0][_skill]}
	if _hosting:
		s["net"] = "host"
		var port_text := _port_edit.text.strip_edges() if _port_edit != null else ""
		var port := port_text.to_int() if port_text.is_valid_int() else 0
		s["port"] = port if port > 0 and port < 65536 else Net.DEFAULT_PORT
	start_requested.emit(s)


func _start_free() -> void:
	start_requested.emit({"mode": "free", "seed": randi_range(1, 999999), "goal": 9999, "team": 0, "class": "maestro", "team_size": 1})


func _show_help() -> void:
	_clear()
	_page.add_child(UiKit.label("How to Play", 28, UiKit.BRASS))
	var sc := UiKit.scroll(440)
	(sc[1] as VBoxContainer).add_child(UiKit.wrapped(HELP, 16))
	_page.add_child(sc[0])
	var back := UiKit.button("Back", _show_home, Vector2(160, 44))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_page.add_child(back)
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


# ---------------------------------------------------------------- online

func _show_online() -> void:
	_clear()
	_hosting = false
	_page.add_child(UiKit.label("Play Online", 28, UiKit.BRASS))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Net.NAME_MAX
	_name_edit.placeholder_text = "your rat's name"
	_name_edit.text = String(Config.get_value("player_name"))
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
		var cb := UiKit.button(ClassDefs.CLASSES[id]["name"], _pick_class.bind(id), Vector2(104, 36))
		cb.toggle_mode = true
		classes.add_child(cb)
		_class_buttons[id] = cb
	_page.add_child(UiKit.row(UiKit.label("Class"), classes))
	_blurb = UiKit.wrapped("", 14, UiKit.PAPER.darkened(0.1))
	_page.add_child(_blurb)
	_pick_team(_team)
	_pick_class(_class)

	_page.add_child(UiKit.label("Public servers", 20, UiKit.BRASS))
	var sc := UiKit.scroll(110)
	_server_list = sc[1]
	_page.add_child(sc[0])
	_server_list.add_child(UiKit.label("Looking for servers...", 15, UiKit.PAPER.darkened(0.2)))
	_fetch_servers()

	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "address or address:port"
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
	buttons.add_child(UiKit.button("Host a game...", _show_host_setup, Vector2(240, 46)))
	_page.add_child(buttons)
	_name_edit.grab_focus()


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
	var hp := split_address(address)
	if String(hp[0]) == "":
		_status.text = "Type the server's address (ask the host for it)."
		return
	Config.set_value("last_address", address.strip_edges())
	Config.save()
	var err := Net.join(String(hp[0]), int(hp[1]), {"name": Net.player_name, "team": _team, "class": _class})
	if err != "":
		_status.text = err
		return
	_status.text = "Connecting to %s:%d ..." % [hp[0], hp[1]]
	var waiting := _status
	Net.join_failed.connect(func(reason: String) -> void:
		if is_instance_valid(waiting):
			waiting.text = reason, CONNECT_ONE_SHOT)


func _fetch_servers() -> void:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		_show_servers(body.get_string_from_utf8() if result == HTTPRequest.RESULT_SUCCESS and code == 200 else ""))
	if http.request(SERVER_LIST_URL) != OK:
		http.queue_free()
		_show_servers("")


func _show_servers(json_text: String) -> void:
	if _server_list == null or not is_instance_valid(_server_list):
		return
	for c in _server_list.get_children():
		c.queue_free()
	var data: Variant = JSON.parse_string(json_text) if json_text != "" else null
	var list: Array = []
	if data is Dictionary and data.get("servers") is Array:
		list = data["servers"]
	var shown := 0
	for e: Variant in list:
		if not (e is Dictionary) or not (e.get("address") is String):
			continue
		var addr := String(e["address"]).strip_edges()
		var port := int(e.get("port", Net.DEFAULT_PORT))
		var title := Net.clean_name(e.get("name", "")) if e.get("name") is String else ""
		var region := Net.clean_name(e.get("region", "")) if e.get("region") is String else ""
		var info := UiKit.label("%s   %s:%d   %s" % [title if title != "" else "Server", addr, port, region], 15)
		_server_list.add_child(UiKit.row(info, UiKit.button("Join", _join.bind("%s:%d" % [addr, port]), Vector2(100, 34))))
		shown += 1
	if shown == 0:
		_server_list.add_child(UiKit.wrapped("No public servers listed right now. Join a friend by address, or host a game.", 14, UiKit.PAPER.darkened(0.2)))
