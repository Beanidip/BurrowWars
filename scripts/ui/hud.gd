class_name Hud
extends CanvasLayer
## In-match interface: scoreboard, stamina, hotbar, ability cards, toasts,
## world markers, plus the workshop / inventory / pause / results dialogs.
## Reads match state every frame; all purchases and class changes go through
## the Match authority.

signal exit_requested
signal rematch_requested

const MAT_ICON_COLORS := [Color(0.47, 0.31, 0.20), Color(0.50, 0.50, 0.54), Color(0.62, 0.44, 0.24), Color(0.70, 0.88, 0.96)]

var m: Match
var rat: Rat
var ctl: PlayerController

var _root: Control
var _score_labels: Array[Label] = []
var _score_bars: Array[ProgressBar] = []
var _mult: Label
var _stamina: ProgressBar
var _stamina_text: Label
var _slots: Array[PanelContainer] = []
var _slot_counts: Array[Label] = []
var _q_name: Label
var _q_count: Label
var _status: Label
var _cheese_row: HBoxContainer
var _abilities: Label
var _hint: Label
var _target: Label
var _toasts: VBoxContainer
var _marker_labels: Array[Label] = []
var _dialog: Control
var _dialog_kind := ""
var _dialog_notice: Label
var _dialog_scrap: Label
var _crosshair: Control
var _style_slot: StyleBoxFlat
var _style_slot_on: StyleBoxFlat
var _cheese_tex: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	if ResourceLoader.exists("res://assets/ui/burrow_cheese_small.png"):
		_cheese_tex = load("res://assets/ui/burrow_cheese_small.png")
	_style_slot = UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.WOOD_LIGHT, 8, 2, 6)
	_style_slot_on = UiKit.box(Color(0.22, 0.15, 0.08, 0.95), UiKit.BRASS, 8, 3, 6)
	_build_top()
	_build_bottom()
	_build_crosshair()
	m.toast.connect(_on_toast)
	m.won.connect(_on_won)
	ctl.notice.connect(func(text: String) -> void: _push_toast(text, UiKit.PAPER))
	_capture(true)
	if m.free_mode:
		_push_toast("Free Build: N toggles flight, F5 saves the map, F9 loads it. Everything is free.", UiKit.BRASS)
	else:
		_push_toast("Dig for golden cheese and carry it back to your base. First to %d wins!" % m.goal, UiKit.BRASS)


func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- layout

func _build_top() -> void:
	var top := UiKit.panel()
	top.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.BRASS, 10, 2, 8))
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 8
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	top.add_child(h)
	for t in 2:
		var l := UiKit.label("0", 26, UiKit.TEAM[t])
		l.custom_minimum_size = Vector2(110, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if t == 0 else HORIZONTAL_ALIGNMENT_LEFT
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(170, 20)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.TEAM[t], UiKit.TEAM[t].lightened(0.3), 6, 1, 0))
		if t == 1:
			bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		_score_labels.append(l)
		_score_bars.append(bar)
	_mult = UiKit.label("", 15, UiKit.BRASS)
	_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult.custom_minimum_size = Vector2(150, 0)
	h.add_child(_score_labels[0])
	h.add_child(_score_bars[0])
	h.add_child(_mult)
	h.add_child(_score_bars[1])
	h.add_child(_score_labels[1])
	top.visible = not m.free_mode
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.position.y = 70
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toasts)


func _build_bottom() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y = -10
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 5)
	_root.add_child(bottom)
	_target = UiKit.label("", 15, UiKit.PAPER)
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_target)
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(420, 18)
	_stamina.show_percentage = false
	_stamina.add_theme_stylebox_override("fill", UiKit.box(Color(0.45, 0.82, 0.4), Color(0.7, 0.95, 0.6), 6, 1, 0))
	_stamina_text = UiKit.label("", 12, UiKit.INK)
	_stamina_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamina_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamina_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamina.add_child(_stamina_text)
	bottom.add_child(_stamina)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	bottom.add_child(bar)
	# Q gadget slot
	var q := PanelContainer.new()
	q.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.BRASS, 8, 2, 6))
	q.custom_minimum_size = Vector2(120, 62)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 0)
	q.add_child(qv)
	qv.add_child(UiKit.label("Q  gadget", 12, UiKit.BRASS))
	_q_name = UiKit.label("-", 15)
	_q_count = UiKit.label("", 13, UiKit.PAPER.darkened(0.15))
	qv.add_child(_q_name)
	qv.add_child(_q_count)
	bar.add_child(q)
	for i in 4:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(78, 62)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		slot.add_child(v)
		var head := HBoxContainer.new()
		head.add_child(UiKit.label(str(i + 1), 12, UiKit.BRASS))
		var chip := ColorRect.new()
		chip.color = MAT_ICON_COLORS[i]
		chip.custom_minimum_size = Vector2(16, 16)
		head.add_child(chip)
		v.add_child(head)
		v.add_child(UiKit.label(String(ClassDefs.MATS[i]).capitalize(), 14))
		var count := UiKit.label("0", 13, UiKit.PAPER.darkened(0.15))
		v.add_child(count)
		_slots.append(slot)
		_slot_counts.append(count)
		bar.add_child(slot)
	# left: identity, scrap, cheese
	var left := UiKit.panel()
	left.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.TEAM[rat.team], 10, 2, 10))
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.position = Vector2(12, -12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	_status = UiKit.label("", 16)
	lv.add_child(_status)
	_cheese_row = HBoxContainer.new()
	_cheese_row.custom_minimum_size = Vector2(0, 28)
	lv.add_child(_cheese_row)
	# right: abilities + key hints
	var right := UiKit.panel()
	right.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.WOOD_LIGHT, 10, 2, 10))
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-12, -12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	right.add_child(rv)
	_abilities = UiKit.label("", 15)
	rv.add_child(_abilities)
	_hint = UiKit.label("", 12, UiKit.PAPER.darkened(0.2))
	rv.add_child(_hint)


func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	for size: Vector2 in [Vector2(14, 2), Vector2(2, 14)]:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.85)
		r.size = size
		r.position = -size * 0.5
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crosshair.add_child(r)


# ---------------------------------------------------------------- per frame

func _process(_delta: float) -> void:
	if rat == null:
		return
	for t in 2:
		_score_labels[t].text = "%s  %d / %d" % [Match.TEAM_NAMES[t], m.scores[t], m.goal] if t == 0 else "%d / %d  %s" % [m.scores[t], m.goal, Match.TEAM_NAMES[t]]
		_score_bars[t].max_value = m.goal
		_score_bars[t].value = m.scores[t]
	_mult.text = "Scrap value x%.2f" % m.multiplier()
	_stamina.max_value = rat.max_stamina()
	_stamina.value = rat.stamina
	_stamina_text.text = "Stamina %d / %d" % [int(rat.stamina), int(rat.max_stamina())]
	for i in 4:
		_slots[i].add_theme_stylebox_override("panel", _style_slot_on if i == ctl.selected_mat else _style_slot)
		_slot_counts[i].text = "inf" if m.free_mode else "x%d" % int(rat.mats[ClassDefs.MATS[i]])
	if rat.equipped != "":
		_q_name.text = ClassDefs.GADGET_NAME[rat.equipped]
		_q_count.text = "unlimited" if m.free_mode else "x%d   (T: next)" % int(rat.gadgets.get(rat.equipped, 0))
	else:
		_q_name.text = "empty"
		_q_count.text = "buy at workshop"
	_status.text = "%s  -  %s team\nScrap: %d" % [rat.cls["name"], Match.TEAM_NAMES[rat.team], rat.scrap]
	_sync_cheese()
	var lines := PackedStringArray()
	var keys := ["ability_1", "ability_2"]
	var list: Array = rat.cls["abilities"]
	for i in list.size():
		var cd := float(rat.ability_cd[i])
		lines.append("[%s] %s%s" % [Inputs.key_name(keys[i]), list[i][1], "  (%.0fs)" % ceilf(cd) if cd > 0.0 else ""])
	_abilities.text = "\n".join(lines)
	var shop := "[%s] Workshop" % Inputs.key_name("workshop")
	if not m.can_shop(rat):
		shop += " (at base)"
	_hint.text = "%s   [%s] Pack   [%s] Drop cheese\n[%s] Camera   [Esc] Menu" % [shop, Inputs.key_name("inventory"),
		Inputs.key_name("drop_cheese"), Inputs.key_name("camera_toggle")]
	_target.text = ""
	if not ctl.aim.is_empty() and _dialog == null:
		var id := int(ctl.aim["id"])
		var hits := int(Blocks.HITS[id])
		var extra := ""
		if id == Blocks.TNT:
			extra = "  -  hit to light the fuse"
		elif hits == 0:
			extra = "  -  indestructible"
		elif not m.free_mode:
			extra = "  -  %d / %d hits" % [int(m.world.damage.get(ctl.aim["cell"], 0)), hits]
		_target.text = Blocks.block_name(id) + extra
	if rat.carried > 0 and not m.free_mode:
		_target.text += "   |   Carrying cheese: get to your base!"
	_crosshair.visible = _dialog == null
	_update_markers()
	if _dialog_scrap != null:
		_dialog_scrap.text = "Your scrap: %d      Scrap value x%.2f" % [rat.scrap, m.multiplier()]


func _sync_cheese() -> void:
	var want := rat.capacity()
	while _cheese_row.get_child_count() > want:
		var c := _cheese_row.get_child(0)
		_cheese_row.remove_child(c)
		c.queue_free()
	while _cheese_row.get_child_count() < want:
		var icon := TextureRect.new()
		icon.texture = _cheese_tex
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_cheese_row.add_child(icon)
	for i in want:
		(_cheese_row.get_child(i) as Control).modulate = Color.WHITE if i < rat.carried else Color(0.25, 0.22, 0.2, 0.7)


func _update_markers() -> void:
	var cam := ctl.cam
	var shown := 0
	var list: Array[Dictionary] = []
	for mk in m.markers:
		if int(mk["team"]) == rat.team:
			list.append(mk)
	if not m.free_mode:
		var zone := MapGenerator.base_zone(rat.team)
		list.append({"pos": zone.position + Vector3(zone.size.x * 0.5, 4.5, zone.size.z * 0.5), "text": "Home", "team": rat.team})
	for mk in list:
		var pos: Vector3 = mk["pos"]
		if cam.is_position_behind(pos):
			continue
		if shown >= _marker_labels.size():
			var l := UiKit.label("", 14, UiKit.TEAM[rat.team].lightened(0.4))
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_constant_override("outline_size", 6)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			_root.add_child(l)
			_root.move_child(l, 0)
			_marker_labels.append(l)
		var label := _marker_labels[shown]
		label.visible = _dialog == null
		label.text = "v %s %dm" % [mk["text"], int(pos.distance_to(rat.position))]
		var screen := cam.unproject_position(pos)
		var vp := _root.size
		label.position = Vector2(clampf(screen.x - 40.0, 8.0, vp.x - 130.0), clampf(screen.y - 20.0, 60.0, vp.y - 140.0))
		shown += 1
	for i in range(shown, _marker_labels.size()):
		_marker_labels[i].visible = false


# ---------------------------------------------------------------- toasts

func _on_toast(text: String, team: int) -> void:
	if team == -1 or team == rat.team:
		_push_toast(text, UiKit.PAPER if team == -1 else UiKit.TEAM[team].lightened(0.35))


func _push_toast(text: String, color: Color) -> void:
	while _toasts.get_child_count() >= 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var l := UiKit.label(text, 16, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- dialogs

func _unhandled_input(event: InputEvent) -> void:
	if m.over:
		return
	if event.is_action_pressed("pause"):
		if _dialog != null:
			close_dialog()
		else:
			open_dialog("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("workshop"):
		_toggle("workshop")
	elif event.is_action_pressed("inventory"):
		_toggle("inventory")
	elif m.free_mode and event.is_action_pressed("save_map"):
		var ok := m.world.save_to("user://maps/free_build.bwmap")
		_push_toast("Map saved to %s" % ProjectSettings.globalize_path("user://maps/free_build.bwmap") if ok else "Map save failed - see log", UiKit.BRASS)
	elif m.free_mode and event.is_action_pressed("load_map"):
		if m.world.load_from("user://maps/free_build.bwmap"):
			m.tnt.clear()
			rat.unstick()
			_push_toast("Map loaded", UiKit.BRASS)
		else:
			_push_toast("No valid saved map found (F5 saves one)", UiKit.TEAM[1])


func _toggle(kind: String) -> void:
	if _dialog_kind == kind:
		close_dialog()
	elif kind == "workshop" and not m.can_shop(rat):
		_push_toast("The workshop is at your base. (Builders can shop anywhere.)", UiKit.PAPER)
	else:
		open_dialog(kind)


func close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
	_dialog = null
	_dialog_kind = ""
	_dialog_notice = null
	_dialog_scrap = null
	ctl.ui_open = false
	get_tree().paused = false
	if not m.over:
		_capture(true)


func open_dialog(kind: String) -> void:
	close_dialog()
	_dialog_kind = kind
	ctl.ui_open = true
	_capture(false)
	var v: VBoxContainer
	match kind:
		"workshop":
			v = UiKit.center_panel(_root, 820, 620)
			_fill_workshop(v)
		"inventory":
			v = UiKit.center_panel(_root, 560, 480)
			_fill_inventory(v)
		"pause":
			v = UiKit.center_panel(_root, 720, 640)
			_fill_pause(v)
			get_tree().paused = true
		_:
			v = UiKit.center_panel(_root, 640, 460)
			_fill_results(v)
	_dialog = v.get_meta("root")


func _dialog_header(v: VBoxContainer, title: String, close_key: String) -> void:
	var h := HBoxContainer.new()
	var t := UiKit.label(title, 26, UiKit.BRASS)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(UiKit.button("Close [%s]" % close_key, close_dialog, Vector2(140, 36)))
	v.add_child(h)


func _fill_workshop(v: VBoxContainer) -> void:
	_dialog_header(v, "The Scrapyard Workshop", Inputs.key_name("workshop"))
	_dialog_scrap = UiKit.label("", 17)
	v.add_child(_dialog_scrap)
	_dialog_notice = UiKit.label("Mine orange scrap blocks to earn scrap. Banked cheese makes it worth more.", 14, UiKit.PAPER.darkened(0.15))
	v.add_child(_dialog_notice)
	var sc := UiKit.scroll(330)
	var list: VBoxContainer = sc[1]
	v.add_child(sc[0])
	var last_cat := ""
	for item: Dictionary in ClassDefs.SHOP:
		if item["cat"] != last_cat:
			last_cat = item["cat"]
			list.add_child(UiKit.label(last_cat, 18, UiKit.BRASS))
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.add_child(UiKit.label(item["name"], 17))
		text.add_child(UiKit.wrapped(item["desc"], 13, UiKit.PAPER.darkened(0.2)))
		var price := "free" if m.free_mode else "%d scrap" % int(item["cost"])
		list.add_child(UiKit.row(text, UiKit.button("Buy  -  " + price, _buy.bind(String(item["id"])), Vector2(170, 40))))
	if not m.free_mode:
		v.add_child(UiKit.label("Change class (at base, 15 s cooldown)", 15, UiKit.BRASS))
		var classes := HBoxContainer.new()
		classes.add_theme_constant_override("separation", 6)
		for id: String in ClassDefs.ORDER:
			var b := UiKit.button(ClassDefs.CLASSES[id]["name"], _change_class.bind(id), Vector2(130, 36))
			b.tooltip_text = ClassDefs.CLASSES[id]["blurb"]
			classes.add_child(b)
		v.add_child(classes)


func _buy(item_id: String) -> void:
	var err := m.try_buy(rat, item_id)
	_say(err if err != "" else "Bought %s." % ClassDefs.shop_item(item_id)["name"], err != "")


func _change_class(id: String) -> void:
	var err := m.try_change_class(rat, id)
	_say(err if err != "" else "You are now a %s. %s" % [ClassDefs.CLASSES[id]["name"], ClassDefs.CLASSES[id]["blurb"]], err != "")


func _say(text: String, is_error: bool) -> void:
	if _dialog_notice != null:
		_dialog_notice.text = text
		_dialog_notice.add_theme_color_override("font_color", UiKit.TEAM[1].lightened(0.2) if is_error else Color(0.6, 0.95, 0.55))


func _fill_inventory(v: VBoxContainer) -> void:
	_dialog_header(v, "The Ratpack", Inputs.key_name("inventory"))
	v.add_child(UiKit.label("Click a gadget to put it in your Q slot.", 14, UiKit.PAPER.darkened(0.15)))
	var sc := UiKit.scroll(240)
	var list: VBoxContainer = sc[1]
	v.add_child(sc[0])
	var any := false
	for g: String in ClassDefs.GADGETS:
		var n := int(rat.gadgets.get(g, 0))
		if n <= 0 and not m.free_mode:
			continue
		any = true
		var item := ClassDefs.shop_item(g)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.add_child(UiKit.label("%s   %s" % [ClassDefs.GADGET_NAME[g], "unlimited" if m.free_mode else "x%d" % n], 17))
		text.add_child(UiKit.wrapped(String(item.get("desc", "")), 13, UiKit.PAPER.darkened(0.2)))
		var equipped := rat.equipped == g
		var b := UiKit.button("Equipped" if equipped else "Equip to Q", _equip.bind(g), Vector2(140, 38))
		b.disabled = equipped
		list.add_child(UiKit.row(text, b))
	if not any:
		list.add_child(UiKit.wrapped("Your pack is empty. Mine scrap, then visit the workshop (%s) at your base." % Inputs.key_name("workshop"), 15))
	var mats := PackedStringArray()
	for mat: String in ClassDefs.MATS:
		mats.append("%s x%d" % [mat.capitalize(), int(rat.mats[mat])])
	v.add_child(UiKit.label("Materials:  " + "   ".join(mats), 15))
	v.add_child(UiKit.label("Cheese carried: %d / %d      Scrap: %d" % [rat.carried, rat.capacity(), rat.scrap], 15))


func _equip(g: String) -> void:
	rat.equipped = g
	open_dialog("inventory")


func _fill_pause(v: VBoxContainer) -> void:
	_dialog_header(v, "Paused", "Esc")
	var sc := UiKit.scroll(430)
	var body: VBoxContainer = sc[1]
	v.add_child(sc[0])
	var settings := SettingsPanel.new()
	settings.changed.connect(ctl.apply_settings)
	body.add_child(settings)
	body.add_child(UiKit.label("How to play", 18, UiKit.BRASS))
	body.add_child(UiKit.wrapped(MainMenu.HELP, 14))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	h.add_child(UiKit.button("Resume", close_dialog, Vector2(200, 44)))
	h.add_child(UiKit.button("Quit to menu", _exit, Vector2(200, 44)))
	v.add_child(h)


func _exit() -> void:
	get_tree().paused = false
	exit_requested.emit()


func _on_won(team: int) -> void:
	close_dialog()
	open_dialog("results")
	get_tree().paused = false


func _fill_results(v: VBoxContainer) -> void:
	var team := m.winner
	var mine := team == rat.team
	var title := UiKit.label("%s TEAM WINS!" % Match.TEAM_NAMES[team].to_upper(), 40, UiKit.TEAM[team])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiKit.label("The golden cheese is yours. Squeak with pride!" if mine else "Out-burrowed this time. Dig faster, bonk harder!", 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var score := UiKit.label("Blue %d   -   %d Red        Match time %d:%02d        Final scrap value x%.2f" % [
		m.scores[0], m.scores[1], int(m.time) / 60, int(m.time) % 60, m.multiplier()], 16, UiKit.BRASS)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for head: String in ["Rat", "Class", "Team", "Scrap"]:
		grid.add_child(UiKit.label(head, 14, UiKit.BRASS))
	for r in m.rats:
		var c: Color = UiKit.TEAM[r.team].lightened(0.3)
		grid.add_child(UiKit.label(r.display_name, 15, c))
		grid.add_child(UiKit.label(r.cls["name"], 15, c))
		grid.add_child(UiKit.label(Match.TEAM_NAMES[r.team], 15, c))
		grid.add_child(UiKit.label(str(r.scrap), 15, c))
	v.add_child(grid)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	var again := UiKit.button("Rematch (new map)", func() -> void: rematch_requested.emit(), Vector2(220, 46))
	h.add_child(again)
	h.add_child(UiKit.button("Main menu", _exit, Vector2(200, 46)))
	v.add_child(h)
	again.grab_focus()
