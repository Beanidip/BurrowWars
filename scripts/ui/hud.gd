class_name Hud
extends CanvasLayer
## In-match interface: scoreboard, stamina, hotbar, ability cards, toasts,
## world markers, plus the workshop / inventory / pause / results dialogs.
## Reads match state every frame; all purchases and class changes go through
## the Match authority.

signal exit_requested
signal rematch_requested(to_lobby: bool)   # the results screen: the next game (or the host: back to the lobby)
signal start_requested       # the host pressed Start in the lobby

const MAT_SHORT := ["Dirt", "Stone", "Ice", "Obsid."]

var m: Match
var rat: Rat
var ctl: PlayerController

var _root: Control
var _score_labels: Array[Label] = []
var _score_bars: Array[ProgressBar] = []
var _mult: Label
var _lobby_banner: Label
var _stamina: ProgressBar
var _stamina_text: Label
var _slots: Array[PanelContainer] = []
var _slot_counts: Array[Label] = []
var _tool_slots: Array[PanelContainer] = []
var _q_name: Label
var _gear_name: Label
var _q_icon: TextureRect
var _gear_icon: TextureRect
var _ability_box: VBoxContainer
var _ability_ids: Array = []
var _gear_state: Label
var _stash_labels: Dictionary = {}   # resource -> Label in the stash section
var _q_count: Label
var _status: Label
var _cheese_row: HBoxContainer
var _bottom: VBoxContainer      # target line, stamina and the hotbar, centred at the bottom
var _hotbar: HBoxContainer
var _side_panels: Array[Control] = []   # the corner panels; lifted above the hotbar when it would run under them
var _hint: Label
var _target: Label
var _toasts: VBoxContainer
var _marker_labels: Array[Label] = []
var _paint_chip: ColorRect
var _dialog: Control
var results: ResultsScreen      # the end-of-match screen, once it is up
var _dialog_kind := ""
var _dialog_notice: Label
var _dialog_scrap: Label
var _owned_labels: Array[Label] = []
var _crosshair: Control
var _style_slot: StyleBoxFlat
var _style_slot_on: StyleBoxFlat
var _cheese_tex: Texture2D
var _focus_pick: Control        # where a controller's focus starts in the open dialog
var _want_capture := false      # play is on: the mouse should be captured
var _had_capture := false       # (browser) we had it, so losing it means Esc was pressed
var _click_hint: Label          # (browser) "Click to play" while the page has the mouse
var _code := CheatCode.new()    # Up Up Down Down Left Right Left Right B A, in the playground

## Workshop, pack and paint pots are tabs of one dialog, so a controller can
## reach all three (LB / RB switch between them).
const TABS := ["workshop", "inventory", "colors"]


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
	if OS.has_feature("web"):
		_click_hint = UiKit.label("Click to play", 28, UiKit.PAPER)
		_click_hint.add_theme_stylebox_override("normal", UiKit.box(Color(0.1, 0.07, 0.05, 0.85), UiKit.BRASS, 10, 2, 14))
		_click_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_click_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_click_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
		_click_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_click_hint.visible = false
		_root.add_child(_click_hint)
	m.toast.connect(_on_toast)
	m.won.connect(_on_won)
	ctl.notice.connect(func(text: String) -> void: _push_toast(text, UiKit.PAPER))
	_capture(true)
	if m.lobby:
		_push_toast("The playground! Everything is free and you wear a jetpack (%s). Man a cannon (%s) and fling your friends at the bullseye." % [
			Inputs.key_name("gear"), Inputs.key_name("interact")], UiKit.BRASS)
	elif m.free_mode:
		_push_toast("Free Build: N toggles flight, F5 saves the map, F9 loads it. Everything is free.", UiKit.BRASS)
	else:
		_push_toast("Dig for golden cheese and carry it back to your base. First to %d wins!" % m.goal, UiKit.BRASS)
	if m.infinite:
		_push_toast("CHEAT CODE: infinite scrap, materials and gadgets for everyone this match!", Color(1.0, 0.85, 0.3))


func _capture(on: bool) -> void:
	_want_capture = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _web_capture() -> void:
	## In a browser the page owns the mouse: Esc takes it back before the game
	## hears the key, and capturing it again needs a click. So: losing it
	## mid-play pauses, and without it a "Click to play" prompt shows.
	if _click_hint == null:
		return
	var playing := _want_capture and _dialog == null and not m.over
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if playing and captured:
		_had_capture = true
	elif playing and _had_capture:
		_had_capture = false
		open_dialog("pause")
		playing = false
	_click_hint.visible = playing and not captured


func _input(event: InputEvent) -> void:
	# the playground's cheat code: once it's under way, its keys and buttons
	# do nothing else (so B doesn't open the workshop, A doesn't jump)
	if m.lobby and _dialog == null:
		var got := _code.feed(CheatCode.token(event), Time.get_ticks_msec() / 1000.0)
		if got >= 2:
			get_viewport().set_input_as_handled()
		if got == CheatCode.CODE.size():
			var said := m.cheat_infinite(rat)
			if said != "":
				_push_toast(said, UiKit.PAPER)
			return
	# (browser) the click that takes the mouse back is not a dig
	if _click_hint != null and _click_hint.visible and event is InputEventMouseButton and event.is_pressed():
		get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	if m.lobby:
		var banner := UiKit.panel()
		banner.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.BRASS, 10, 2, 8))
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
		banner.position.y = 8
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lobby_banner = UiKit.label("", 22, UiKit.BRASS)
		_lobby_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_child(_lobby_banner)
		_root.add_child(banner)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.position.y = 70
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toasts)


func _build_bottom() -> void:
	var bottom := VBoxContainer.new()
	_bottom = bottom
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
	_hotbar = bar
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	bottom.add_child(bar)
	# Q gadget slot
	var q := PanelContainer.new()
	q.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.BRASS, 8, 2, 6))
	q.custom_minimum_size = Vector2(SLOT_WIDE, 62)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 0)
	qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_q_icon = Icons.rect("", 24)
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 4)
	qh.add_child(_q_icon)
	qh.add_child(qv)
	q.add_child(qh)
	qv.add_child(UiKit.label("Q  gadget", 12, UiKit.BRASS))
	_q_name = _fitted(UiKit.label("-", 15))
	_q_count = _fitted(UiKit.label("", 13, UiKit.PAPER.darkened(0.15)))
	qv.add_child(_q_name)
	qv.add_child(_q_count)
	bar.add_child(q)
	var gear := PanelContainer.new()
	gear.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.BRASS, 8, 2, 6))
	gear.custom_minimum_size = Vector2(SLOT_WIDE, 62)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 0)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_icon = Icons.rect("", 24)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 4)
	gh.add_child(_gear_icon)
	gh.add_child(gv)
	gear.add_child(gh)
	gv.add_child(UiKit.label("%s  gear" % Inputs.key_name("gear"), 12, UiKit.BRASS))
	_gear_name = _fitted(UiKit.label("-", 15))
	_gear_state = _fitted(UiKit.label("", 13, UiKit.PAPER.darkened(0.15)))
	gv.add_child(_gear_name)
	gv.add_child(_gear_state)
	bar.add_child(gear)
	for i in ClassDefs.MATS.size() + 1:
		var paint := i == ClassDefs.MATS.size()
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(58, 62)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		slot.add_child(v)
		var head := HBoxContainer.new()
		head.add_child(UiKit.label(Inputs.key_name("slot_%d" % (i + 1)), 12, UiKit.BRASS))
		head.add_theme_constant_override("separation", 3)
		head.add_child(Icons.rect("paint" if paint else String(ClassDefs.MATS[i]), 18))
		if paint:
			var chip := ColorRect.new()
			chip.color = Blocks.paint_color(0)
			_paint_chip = chip
			chip.custom_minimum_size = Vector2(10, 18)
			head.add_child(chip)
		v.add_child(head)
		v.add_child(UiKit.label("Paint" if paint else MAT_SHORT[i], 14))
		var count := UiKit.label("0", 13, UiKit.PAPER.darkened(0.15))
		v.add_child(count)
		_slots.append(slot)
		_slot_counts.append(count)
		bar.add_child(slot)
	# tool slots: 9 chisel, 0 pantograph
	for info: Array in [["chisel", "Chisel", "carve"], ["pantograph", "Pantograph", "copy"]]:
		var ts := PanelContainer.new()
		ts.custom_minimum_size = Vector2(72, 62)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		ts.add_child(tv)
		var th := HBoxContainer.new()
		th.add_theme_constant_override("separation", 4)
		th.add_child(UiKit.label(Inputs.key_name(info[0]), 12, UiKit.BRASS))
		th.add_child(Icons.rect(String(info[0]), 18))
		tv.add_child(th)
		tv.add_child(UiKit.label(info[1], 13))
		tv.add_child(UiKit.label(info[2], 13, UiKit.PAPER.darkened(0.15)))
		_tool_slots.append(ts)
		bar.add_child(ts)
	# left: identity, scrap, cheese
	var left := UiKit.panel()
	left.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.TEAM[rat.team], 10, 2, 10))
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.position = Vector2(12, -12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(left)
	_side_panels.append(left)
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
	right.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.85), UiKit.WOOD_LIGHT, 8, 2, 7))
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-12, -12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	_side_panels.append(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	right.add_child(rv)
	_ability_box = VBoxContainer.new()
	_ability_box.add_theme_constant_override("separation", 2)
	rv.add_child(_ability_box)
	_hint = UiKit.label("", 12, UiKit.PAPER.darkened(0.2))
	rv.add_child(_hint)


const SLOT_WIDE := 128.0         # the Q gadget and gear slots: a fixed width, so the hotbar never grows


static func _fitted(l: Label) -> Label:
	## A label that keeps to its slot: too long a name ends in "..." instead of widening the hotbar.
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(SLOT_WIDE - 40.0, 0)
	return l


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

func _fit_side_panels() -> void:
	## The hotbar grows with long gadget and gear names; on a narrow window it
	## would run under the corner panels. Any panel it would overlap sits just
	## above the bottom bar instead (and drops back down when there's room).
	if _hotbar == null or _bottom == null:
		return
	var bar := _hotbar.get_global_rect()
	for p in _side_panels:
		var r := p.get_global_rect()
		var clash := r.position.x < bar.end.x + 8.0 and r.end.x > bar.position.x - 8.0
		var want := -12.0 - (_bottom.size.y + 6.0 if clash else 0.0)
		if not is_equal_approx(p.offset_bottom, want):
			var h := p.size.y
			p.offset_bottom = want
			p.offset_top = want - h


func lobby_text() -> String:
	var here := "%d %s here" % [m.rats.size(), "rat" if m.rats.size() == 1 else "rats"]
	if m.infinite_next:
		here += "  -  CHEAT: infinite resources"
	if m.lobby_left >= 0.0:
		return "PLAYGROUND  -  %s  -  the match starts in %d s" % [here, ceili(m.lobby_left)]
	if not m.replica:
		return "PLAYGROUND  -  %s  -  press %s to start the match" % [here, Inputs.key_name("start_match")]
	return "PLAYGROUND  -  %s  -  waiting for the host to start the match" % here


func _process(_delta: float) -> void:
	if rat == null:
		return
	_web_capture()
	if _lobby_banner != null:
		_lobby_banner.text = lobby_text()
	_fit_side_panels()
	for t in 2:
		_score_labels[t].text = "%s  %d / %d" % [Match.TEAM_NAMES[t], m.scores[t], m.goal] if t == 0 else "%d / %d  %s" % [m.scores[t], m.goal, Match.TEAM_NAMES[t]]
		_score_bars[t].max_value = m.goal
		_score_bars[t].value = m.scores[t]
	_mult.text = "Scrap value x%.2f" % m.multiplier()
	_stamina.max_value = rat.max_stamina()
	_stamina.value = rat.stamina
	_stamina_text.text = "Stamina %d / %d" % [int(rat.stamina), int(rat.max_stamina())]
	for i in _tool_slots.size():
		_tool_slots[i].add_theme_stylebox_override("panel", _style_slot_on if int(ctl.tool) == i + 1 else _style_slot)
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override("panel", _style_slot_on if (i == ctl.selected_mat and ctl.tool != PlayerController.Tool.PANTOGRAPH) else _style_slot)
		if i >= ClassDefs.MATS.size():
			_paint_chip.color = Blocks.paint_color(ctl.selected_color)
			_slot_counts[i].text = ("%s: colour" % Inputs.key_name("workshop")) if Inputs.using_pad else ("[%s] colour" % Inputs.key_name("color_picker"))
		else:
			_slot_counts[i].text = "inf" if m.unlimited() else "x%d" % int(rat.mats[ClassDefs.MATS[i]])
	if rat.equipped != "":
		_q_name.text = ClassDefs.GADGET_NAME[rat.equipped]
		_q_count.text = "unlimited" if m.unlimited() else "x%d   (%s: next)" % [int(rat.gadgets.get(rat.equipped, 0)), Inputs.key_name("cycle_gadget")]
		if rat.equipped == "teleporter":
			var nxt := m.tele_next(rat)
			_q_count.text = "Q: %s" % nxt if nxt != "" else "set is out"
	else:
		_q_name.text = "empty"
		_q_count.text = "buy: %s" % Inputs.key_name("workshop")
	_status.text = "%s  -  %s team\nScrap: %d" % [rat.cls["name"], Match.TEAM_NAMES[rat.team], rat.scrap]
	_q_icon.texture = Icons.tex(rat.equipped)
	_gear_icon.texture = Icons.tex(rat.gear)
	if rat.gear == "":
		_gear_name.text = "none"
		_gear_state.text = "buy: %s" % Inputs.key_name("workshop")
	else:
		_gear_name.text = String(ClassDefs.GEAR.get(rat.gear, rat.gear))
		if rat.shield_t > 0.0:
			_gear_state.text = "raised %.0f s" % ceilf(rat.shield_t)
		elif rat.gear == "bubbles":
			_gear_state.text = "on" if rat.bubbles_on else "off"
		else:
			_gear_state.text = ("%.0f s" % ceilf(rat.gear_cd)) if rat.gear_cd > 0.0 else "ready"
	_sync_cheese()
	var keys := ["ability_1", "ability_2"]
	var list: Array = rat.cls["abilities"]
	var ids: Array = []
	for ab: Array in list:
		ids.append(ab[0])
	if ids != _ability_ids:      # class changed: one row (icon + text) per ability
		_ability_ids = ids
		for c in _ability_box.get_children():
			c.queue_free()
		for id: String in ids:
			_ability_box.add_child(Icons.with_icon(id, UiKit.label("", 13), 18))
	for i in list.size():
		var cd := float(rat.ability_cd[i])
		var row := _ability_box.get_child(i) as HBoxContainer
		if row != null and not row.is_queued_for_deletion():
			(row.get_child(1) as Label).text = "[%s] %s%s" % [Inputs.key_name(keys[i]), list[i][1], "  (%.0fs)" % ceilf(cd) if cd > 0.0 else ""]
	var shop := "[%s] Workshop" % Inputs.key_name("workshop")
	if not m.can_shop(rat):
		shop = "[%s] Team stash" % Inputs.key_name("workshop") if m.can_use_stash(rat) else shop + " (at base)"
	var pack := "[%s] Pack" % Inputs.key_name("inventory")
	if Inputs.using_pad:
		pack = "[%s] Pack (away from base)" % Inputs.key_name("workshop")
	_hint.text = "%s\n%s   [%s] Drop cheese\n[%s] Machine   [%s] Camera   [%s] Menu" % [shop, pack,
		Inputs.key_name("drop_cheese"), Inputs.key_name("interact"), Inputs.key_name("camera_toggle"), Inputs.key_name("pause")]
	_target.text = ""
	if ctl.tool_text != "" and _dialog == null:
		_target.text = ctl.tool_text
	elif not ctl.aim.is_empty() and _dialog == null:
		var id := int(ctl.aim["id"])
		var hits := int(Blocks.HITS[id])
		var extra := ""
		if id == Blocks.TNT:
			extra = "  -  hit to light the fuse"
		elif Blocks.is_machine(id):
			extra = "  -  [%s] operate   (dig it to pack it up)" % Inputs.key_name("interact")
		elif hits == 0:
			extra = "  -  indestructible"
		elif not m.free_mode:
			extra = "  -  %d / %d hits" % [int(m.world.damage.get(ctl.aim["cell"], 0)), hits]
		var shown := Blocks.block_name(id)
		if Blocks.is_teleporter(id):
			for p: Array in m.tele_pads():
				if p[0] == ctl.aim["cell"]:
					var mine := int(p[4]) == rat.id
					shown = ("Your " if mine else "") + shown
					if not bool(p[1]) and not bool(p[3]):
						shown += " (recharging)"
					if mine:
						extra = "  -  dig it to pick it up"
		if Blocks.is_decoy(id):
			if Blocks.trap_team(id) == rat.team:
				shown = "Your Cheese Decoy"
				extra = "  -  dig it to take it back"
			else:
				shown = Blocks.block_name(Blocks.CHEESE)      # the other team sees Golden Cheese
				extra = "  -  %d / %d hits" % [0, int(Blocks.HITS[Blocks.CHEESE])] if not m.free_mode else ""
		_target.text = shown + extra
	if rat.carried > 0 and not m.free_mode:
		_target.text += "   |   Carrying cheese: get to your base!"
	if rat.raid_t > 0.0:
		_target.text = "Raiding the vault...  %d%%" % int(100.0 * rat.raid_t / Config.RAID_TIME)
	elif not m.free_mode and m.in_base(rat, 1 - rat.team) and m.scores[1 - rat.team] > 0 and rat.carried < rat.capacity():
		_target.text = "A defender is home - the vault is locked while they stand in it"
	_crosshair.visible = _dialog == null
	_update_markers()
	for ol in _owned_labels:
		var it: Dictionary = ol.get_meta("item")
		ol.text = "%s      owned: %s" % [it["name"], "unlimited" if m.unlimited() else str(_owned(it))]
	var bank: Dictionary = m.team_bank[rat.team]
	for key: String in _stash_labels:
		var have := rat.scrap if key == "scrap" else int(rat.mats.get(key, 0))
		(_stash_labels[key] as Label).text = "%s:  you %d   |   stash %d" % [key.capitalize(), have, int(bank.get(key, 0))]
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
	elif _dialog != null and event.is_action_pressed("ui_cancel"):
		close_dialog()       # B on a gamepad backs out of any dialog
		get_viewport().set_input_as_handled()
	elif TABS.has(_dialog_kind) and event is InputEventJoypadButton \
			and (event.is_action_pressed("cycle_gadget") or event.is_action_pressed("gadget")):
		get_viewport().set_input_as_handled()
		cycle_tab(-1 if event.is_action_pressed("cycle_gadget") else 1)
	elif _dialog != null and UiKit.is_pad_nav(event) and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()   # a controller picked up mid-dialog: land on a button
		UiKit.focus_first(_dialog, _focus_pick)
	elif event.is_action_pressed("workshop"):
		# on a gamepad the one View button opens your pack wherever there's no workshop
		var pad := event is InputEventJoypadButton
		if pad and _dialog_kind == "" and not m.can_shop(rat) and not m.can_use_stash(rat):
			_toggle("inventory")
		else:
			_toggle("workshop")
	elif event.is_action_pressed("inventory"):
		_toggle("inventory")
	elif event.is_action_pressed("color_picker"):
		_toggle("colors")
	elif m.lobby and not m.replica and m.lobby_left < 0.0 and _dialog == null and event.is_action_pressed("start_match"):
		get_viewport().set_input_as_handled()
		start_requested.emit()
	elif m.free_mode and not m.lobby and event.is_action_pressed("save_map"):
		quick_save()
	elif m.free_mode and not m.lobby and event.is_action_pressed("load_map"):
		quick_load()


func quick_save() -> void:
	## Free Build: F5, or the pause menu.
	var ok := m.world.save_to(VoxelWorld.MAPS_DIR + "/free_build.bwmap", {"machines": m.siege.to_save()})
	_push_toast("Map saved to %s" % ProjectSettings.globalize_path("user://maps/free_build.bwmap") if ok else "Map save failed - see log", UiKit.BRASS)


func quick_load() -> void:
	## Free Build: F9, or the pause menu.
	if m.networked:
		_push_toast("Loading a map is only possible offline", UiKit.PAPER)
	elif m.world.load_from("user://maps/free_build.bwmap"):
		m.tnt.clear()
		m.siege.from_save(m.world.loaded_extra.get("machines", []))
		rat.unstick()
		_push_toast("Map loaded", UiKit.BRASS)
	else:
		_push_toast("No valid saved map found (%s saves one)" % Inputs.key_name("save_map"), UiKit.TEAM[1])


func cycle_tab(step: int) -> void:
	## LB / RB in the workshop, pack and paint pots: the next tab along.
	var tabs := _tab_kinds()
	var i := tabs.find(_dialog_kind)
	if i >= 0:
		open_dialog(tabs[(i + step + tabs.size()) % tabs.size()])


func _tab_kinds() -> Array:
	## The workshop tab only shows where you can shop or reach a stash.
	if m.can_shop(rat) or m.can_use_stash(rat):
		return TABS
	return TABS.slice(1)


func _toggle(kind: String) -> void:
	if _dialog_kind == kind:
		close_dialog()
	elif kind == "workshop" and not m.can_shop(rat) and not m.can_use_stash(rat):
		_push_toast("The workshop is at your base (Builders can shop anywhere); your team stash works beside any stash you placed.", UiKit.PAPER)
	else:
		open_dialog(kind)


func close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
	_dialog = null
	_dialog_kind = ""
	_dialog_notice = null
	_dialog_scrap = null
	_focus_pick = null
	_owned_labels.clear()
	_stash_labels.clear()
	ctl.ui_open = false
	get_viewport().gui_release_focus()   # so the gamepad's A jumps again instead of pressing a button
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
		"colors":
			v = UiKit.center_panel(_root, 600, 450)
			_fill_colors(v)
		"pause":
			v = UiKit.center_panel(_root, 720, 640)
			_fill_pause(v)
			get_tree().paused = not m.networked   # an online match never stops for one player
		_:
			_show_results()
			return
	_dialog = v.get_meta("root")
	if Inputs.using_pad:
		UiKit.focus_first(_dialog, _focus_pick)   # (with a mouse, nothing is pre-selected)


func _dialog_header(v: VBoxContainer, title: String, close_key: String) -> void:
	if TABS.has(_dialog_kind):
		_dialog_tabs(v)
	var h := HBoxContainer.new()
	var t := UiKit.label(title, 26, UiKit.BRASS)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(UiKit.button("Close [%s]" % (Inputs.back_name() if Inputs.using_pad else close_key), close_dialog, Vector2(140, 36)))
	v.add_child(h)


func _dialog_tabs(v: VBoxContainer) -> void:
	var names := {"workshop": "Workshop" if m.can_shop(rat) else "Team Stash", "inventory": "Pack", "colors": "Colours"}
	var keys := {"workshop": "workshop", "inventory": "inventory", "colors": "color_picker"}
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for kind: String in _tab_kinds():
		var label := String(names[kind])
		if not Inputs.using_pad:
			label += "  [%s]" % Inputs.key_name(keys[kind])
		var b := UiKit.button(label, func() -> void:
			if _dialog_kind != kind:
				open_dialog(kind), Vector2(150, 34))
		b.toggle_mode = true
		b.button_pressed = kind == _dialog_kind
		b.set_meta("tab", kind)
		h.add_child(b)
	if Inputs.using_pad:
		h.add_child(UiKit.label("  %s / %s switch" % [Inputs.button_name(JOY_BUTTON_LEFT_SHOULDER), Inputs.button_name(JOY_BUTTON_RIGHT_SHOULDER)], 14, UiKit.PAPER.darkened(0.2)))
	v.add_child(h)


func _fill_workshop(v: VBoxContainer) -> void:
	var shopping := m.can_shop(rat)
	_dialog_header(v, "The Scrapyard Workshop" if shopping else "Team Stash", Inputs.key_name("workshop"))
	_dialog_scrap = UiKit.label("", 17)
	v.add_child(_dialog_scrap)
	_dialog_notice = UiKit.label("Mine orange scrap blocks to earn scrap. Banked cheese makes it worth more." if shopping \
		else "Your team's shared pool. Anyone on your team can take from it here or at base.", 14, UiKit.PAPER.darkened(0.15))
	v.add_child(_dialog_notice)
	var sc := UiKit.scroll(330)
	var list: VBoxContainer = sc[1]
	v.add_child(sc[0])
	_stash_labels.clear()
	if m.can_use_stash(rat):
		list.add_child(UiKit.label("Team stash  (shared with your team; cheese can't go in)", 18, UiKit.BRASS))
		for key: String in Config.STASH_KEYS:
			var lbl := UiKit.label("", 16)
			_stash_labels[key] = lbl
			var btns := HBoxContainer.new()
			btns.add_theme_constant_override("separation", 4)
			var put := UiKit.button("Put 10", _stash.bind(key, 10), Vector2(80, 34))
			if _focus_pick == null:
				_focus_pick = put
			btns.add_child(put)
			btns.add_child(UiKit.button("Put all", _stash.bind(key, 9999), Vector2(80, 34)))
			btns.add_child(UiKit.button("Take 10", _stash.bind(key, -10), Vector2(84, 34)))
			btns.add_child(UiKit.button("Take all", _stash.bind(key, -9999), Vector2(88, 34)))
			list.add_child(UiKit.row(Icons.with_icon(key, lbl, 24), btns))
	var last_cat := ""
	for item: Dictionary in (ClassDefs.shop_in_order() if shopping else []):
		if item["cat"] != last_cat:
			last_cat = item["cat"]
			list.add_child(UiKit.label(last_cat, 18, UiKit.BRASS))
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		var own := _owned(item)
		var own_label := UiKit.label("%s      owned: %d" % [item["name"], own], 17)
		own_label.set_meta("item", item)
		_owned_labels.append(own_label)
		text.add_child(own_label)
		text.add_child(UiKit.wrapped(item["desc"], 13, UiKit.PAPER.darkened(0.2)))
		var cost := ClassDefs.price(rat.cls, String(item["id"]), m.unlimited())
		var price := "free" if cost == 0 else "%d scrap" % cost
		var buy := UiKit.button("Buy  -  " + price, _buy.bind(String(item["id"])), Vector2(170, 40))
		if _focus_pick == null:
			_focus_pick = buy
		list.add_child(UiKit.row(Icons.with_icon(String(item["id"]), text, 32), buy))
	if not m.free_mode and shopping:
		v.add_child(UiKit.label("Change class (at base, 15 s cooldown)", 15, UiKit.BRASS))
		var classes := HBoxContainer.new()
		classes.add_theme_constant_override("separation", 6)
		for id: String in ClassDefs.ORDER:
			var b := Icons.on_button(UiKit.button(ClassDefs.CLASSES[id]["name"], _change_class.bind(id), Vector2(140, 36)), id, true)
			b.tooltip_text = ClassDefs.CLASSES[id]["blurb"]
			classes.add_child(b)
		v.add_child(classes)


func _owned(item: Dictionary) -> int:
	match String(item["kind"]):
		"gadget": return int(rat.gadgets.get(item["id"], 0))
		"gear": return 1 if rat.gear == item["id"] else 0
	return int(rat.mats.get(item["id"], 0))


func _stash(key: String, amount: int) -> void:
	var err := m.stash_move(rat, key, amount)
	if err != "":
		_say(err, true)


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


func _fill_colors(v: VBoxContainer) -> void:
	_dialog_header(v, "Paint Pots", Inputs.key_name("color_picker"))
	var paint_text := "Pick a colour, then slot %s places painted blocks with right mouse (one dirt each, or stone when you have no dirt). With the chisel (%s) right mouse adds painted microvoxels. The bottom row is see-through glass (whole blocks only)." % [
		Inputs.key_name("slot_%d" % (ClassDefs.MATS.size() + 1)), Inputs.key_name("chisel")]
	if Inputs.using_pad:
		paint_text = "Pick a colour, then %s places painted blocks (one dirt each, or stone when you have no dirt). With the chisel (%s / %s past the paint slot) %s adds painted microvoxels. The bottom row is see-through glass (whole blocks only)." % [
			Inputs.key_name("place"), Inputs.key_name("prev_slot"), Inputs.key_name("next_slot"), Inputs.key_name("place")]
	v.add_child(UiKit.wrapped(paint_text, 14, UiKit.PAPER.darkened(0.15)))
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var order: Array[int] = []
	for k in Blocks.PALETTE_SOLID:
		order.append(k)
	while order.size() % 10 != 0:
		order.append(-1)   # glass starts on its own row
	for k in range(Blocks.PALETTE_SOLID, Blocks.PALETTE_SIZE):
		order.append(k)
	for k in order:
		if k < 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(46, 46)
			grid.add_child(gap)
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.tooltip_text = Blocks.PALETTE_NAMES[k]
		var col := Blocks.paint_color(k)
		if k >= Blocks.PALETTE_SOLID:
			b.text = "glass"
			b.add_theme_font_size_override("font_size", 12)
			b.add_theme_color_override("font_color", UiKit.INK)
			col = Color(col.r, col.g, col.b, 0.55)
		var chosen := k == ctl.selected_color
		if chosen:
			_focus_pick = b
		b.add_theme_stylebox_override("normal", UiKit.box(col, UiKit.PAPER if chosen else UiKit.WOOD_DARK, 10, 5 if chosen else 2, 4))
		b.add_theme_stylebox_override("hover", UiKit.box(col.lightened(0.15), UiKit.BRASS, 10, 4, 4))
		b.add_theme_stylebox_override("pressed", UiKit.box(col.darkened(0.15), UiKit.BRASS, 10, 5, 4))
		b.pressed.connect(pick_color.bind(k))
		grid.add_child(b)
	v.add_child(grid)
	var name_label := UiKit.label("Current: %s" % Blocks.PALETTE_NAMES[ctl.selected_color], 16, UiKit.BRASS)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)


func pick_color(k: int) -> void:
	ctl.selected_color = clampi(k, 0, Blocks.PALETTE_SIZE - 1)
	ctl.selected_mat = ClassDefs.MATS.size()      # switch the build slot to Paint
	if ctl.tool == PlayerController.Tool.PANTOGRAPH:
		ctl.tool = PlayerController.Tool.DIG
	close_dialog()
	_push_toast("Painting in %s: right mouse places a block; with the chisel it adds a microvoxel" % Blocks.PALETTE_NAMES[k], Blocks.paint_color(k).lightened(0.2))


func _fill_inventory(v: VBoxContainer) -> void:
	_dialog_header(v, "The Ratpack", Inputs.key_name("inventory"))
	v.add_child(UiKit.label("Pick a gadget for your %s slot." % Inputs.key_name("gadget"), 14, UiKit.PAPER.darkened(0.15)))
	var sc := UiKit.scroll(240)
	var list: VBoxContainer = sc[1]
	v.add_child(sc[0])
	var any := false
	for g: String in ClassDefs.GADGETS:
		var n := int(rat.gadgets.get(g, 0))
		if n <= 0 and not m.unlimited():
			continue
		any = true
		var item := ClassDefs.shop_item(g)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.add_child(UiKit.label("%s   %s" % [ClassDefs.GADGET_NAME[g], "unlimited" if m.unlimited() else "x%d" % n], 17))
		text.add_child(UiKit.wrapped(String(item.get("desc", "")), 13, UiKit.PAPER.darkened(0.2)))
		var equipped := rat.equipped == g
		var b := UiKit.button("Equipped" if equipped else "Equip to Q", _equip.bind(g), Vector2(140, 38))
		b.disabled = equipped
		if _focus_pick == null and not equipped:
			_focus_pick = b
		list.add_child(UiKit.row(Icons.with_icon(g, text, 32), b))
	if not any:
		list.add_child(UiKit.wrapped("Your pack is empty. Mine scrap, then visit the workshop (%s) at your base." % Inputs.key_name("workshop"), 15))
	var mats := HBoxContainer.new()
	mats.add_theme_constant_override("separation", 14)
	mats.add_child(UiKit.label("Materials:", 15))
	for mat: String in ClassDefs.MATS:
		mats.add_child(Icons.with_icon(mat, UiKit.label("x%d" % int(rat.mats[mat]), 15), 20))
	mats.add_child(Icons.with_icon("scrap", UiKit.label("x%d" % rat.scrap, 15), 20))
	v.add_child(mats)
	if rat.gear != "":
		v.add_child(Icons.with_icon(rat.gear, UiKit.label("Gear: %s  (%s to use)" % [ClassDefs.GEAR.get(rat.gear, rat.gear), Inputs.key_name("gear")], 15), 22))
	v.add_child(UiKit.label("Cheese carried: %d / %d      Scrap: %d" % [rat.carried, rat.capacity(), rat.scrap], 15))


func _equip(g: String) -> void:
	m.set_equipped(rat, g)
	open_dialog("inventory")


func _fill_pause(v: VBoxContainer) -> void:
	_dialog_header(v, "Paused" if not m.networked else "Menu (the online game keeps going)", Inputs.key_name("pause"))
	# the two volumes people reach for most, at the top (the same settings as
	# Audio below, which they keep in step)
	var settings := SettingsPanel.new()
	settings.changed.connect(ctl.apply_settings)
	for row: Array in [["Music volume", "music_volume"], ["Effects volume", "sfx_volume"]]:
		var key: String = row[1]
		var title: String = row[0]
		var label := UiKit.label("%s  %d%%" % [title, roundi(float(Config.get_value(key)) * 100.0)], 17, UiKit.BRASS)
		var slider := UiKit.slider(0.0, 1.0, 0.05, float(Config.get_value(key)), func(value: float) -> void:
			settings._store(key, value)
			label.text = "%s  %d%%" % [title, roundi(value * 100.0)]
			var twin: HSlider = settings.sliders.get(key)
			if twin != null:
				twin.set_value_no_signal(value))
		slider.custom_minimum_size = Vector2(300, 0)
		slider.set_meta("volume", key)
		v.add_child(UiKit.row(label, slider))
	var sc := UiKit.scroll(360)
	var body: VBoxContainer = sc[1]
	v.add_child(sc[0])
	body.add_child(settings)
	body.add_child(UiKit.label("How to play", 18, UiKit.BRASS))
	var pad := UiKit.wrapped(Inputs.pad_help(), 14, UiKit.BRASS.lightened(0.3))
	if Inputs.using_pad:
		body.add_child(pad)
	body.add_child(UiKit.wrapped(MainMenu.HELP, 14))
	if not Inputs.using_pad:
		body.add_child(pad)
	# things a keyboard does with a key of their own, as buttons for a controller
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 10)
	if m.lobby and not m.replica and m.lobby_left < 0.0:
		acts.add_child(UiKit.button("Start the match", func() -> void:
			close_dialog()
			start_requested.emit(), Vector2(170, 40)))
	if not m.lobby:
		var respawn := UiKit.button("Respawn at base", func() -> void: pass, Vector2(170, 40))
		respawn.pressed.connect(pause_respawn.bind(respawn))
		acts.add_child(respawn)
	if bool(rat.cls["fly"]):
		acts.add_child(UiKit.button("Flight on / off", func() -> void:
			rat.flying = not rat.flying
			close_dialog()
			_push_toast("Flight ON" if rat.flying else "Flight off", UiKit.BRASS), Vector2(170, 40)))
	if m.free_mode and not m.lobby:
		acts.add_child(UiKit.button("Quick save", func() -> void:
			close_dialog()
			quick_save(), Vector2(150, 40)))
		if not m.networked:
			acts.add_child(UiKit.button("Quick load", func() -> void:
				close_dialog()
				quick_load(), Vector2(150, 40)))
	if acts.get_child_count() > 0:
		v.add_child(acts)
		(sc[0] as Control).custom_minimum_size.y = 310   # room for the extra row
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	var resume := UiKit.button("Resume", close_dialog, Vector2(180, 44))
	_focus_pick = resume
	h.add_child(resume)
	if not m.replica:   # offline or hosting: you hold the real map
		h.add_child(UiKit.button("Export map", export_map, Vector2(180, 44)))
	h.add_child(UiKit.button("Quit to menu", _exit, Vector2(180, 44)))
	if not OS.has_feature("web"):   # (a browser tab has no desktop to quit to)
		var quit := UiKit.button("Quit game", func() -> void: pass, Vector2(180, 44))
		quit.pressed.connect(_quit_pressed.bind(quit))
		h.add_child(quit)
	v.add_child(h)


func pause_respawn(button: Button = null) -> void:
	## Ctrl+K on a keyboard. Asks once first, as it leaves your cheese and
	## materials behind.
	if button != null and button.text != "Really respawn?":
		button.text = "Really respawn?"
		return
	close_dialog()
	m.respawn(rat)
	_push_toast("Back at base. Your cheese and materials stayed behind.", UiKit.PAPER)


func _quit_pressed(button: Button) -> void:
	## Asks once: the first press arms it, the second quits to the desktop.
	if button.text != "Really quit?":
		button.text = "Really quit?"
		return
	get_tree().paused = false
	get_tree().quit()


func export_map() -> String:
	## Saves a copy of the current map (carvings, gate layers and siege
	## machines included) that the setup screens can load again.
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/%s_%s.bwmap" % [VoxelWorld.MAPS_DIR, "freebuild" if m.free_mode else "map", stamp]
	var ok := m.world.save_to(path, {"machines": m.siege.to_save()})
	if ok and OS.has_feature("web"):
		# a browser keeps its files out of sight: hand the map over as a download too
		JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), path.get_file(), "application/octet-stream")
		_push_toast("Exported %s - it's in your downloads, and under Map when you set up a game" % path.get_file(), UiKit.BRASS)
		return path
	_push_toast(("Exported %s - pick it under Map when you set up a game" % path.get_file()) if ok else "Export failed - see the log", UiKit.BRASS)
	return path if ok else ""


func _exit() -> void:
	get_tree().paused = false
	exit_requested.emit()


func _on_won(team: int) -> void:
	close_dialog()
	open_dialog("results")
	get_tree().paused = false


func _show_results() -> void:
	## The end-of-match screen (ResultsScreen) fills the whole view.
	var r := ResultsScreen.new()
	r.m = m
	r.me = rat
	r.next_game.connect(func() -> void: rematch_requested.emit(false))
	r.to_lobby.connect(func() -> void: rematch_requested.emit(true))
	r.leave.connect(_exit)
	for c in _root.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false   # the hotbar, score and the rest: the results screen replaces them
	_root.add_child(r)
	_dialog = r
	results = r
	r.first_button().grab_focus()
