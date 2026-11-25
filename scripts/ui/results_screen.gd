class_name ResultsScreen
extends Control
## The end-of-match screen: who won, the score, and every rat standing in a
## line-up with its tallies underneath (cheese banked, mined and stolen,
## bonks, blocks, TNT, traps, scrap). The best at each one is picked out in
## gold, and the match's MVP gets a badge.
##
## Everyone can emote with the movement keys (or the left stick) while it is
## up; the emotes go over the network, so each player sees the others'. Bots
## join in.
##
## What happens next depends on who you are:
##  - offline: play again on a new map, the main menu, or quit;
##  - the host of an online game: the next game, back to the lobby, the main
##    menu (which ends it for everyone) or quit;
##  - a player on someone else's game: it waits for the host (or counts down
##    to a dedicated server's next round), and you can leave.

signal next_game           # a new map, straight in (offline or the host)
signal to_lobby            # the host: everyone back to the playground
signal leave               # back to the main menu

const CARD_W := 142
const PIC := 120
const SIDE_BY_SIDE := 4      # teams this small stand side by side; bigger ones one above the other
const EMOTE_KEYS := {"move_forward": "cheer", "move_left": "dance", "move_right": "taunt", "move_back": "flop", "jump": "flip"}
const PAD_FLIP := "gear"   # Y on a gamepad (A presses the buttons)
const EMOTE_NAMES := {"cheer": "cheer", "dance": "dance", "taunt": "taunt", "flop": "flop", "flip": "flip"}

var m: Match
var me: Rat
var _cards: Dictionary = {}      # rat id -> {"rat", "pic", "values": {stat: Label}, "t"}
var _status: Label
var _hint: Label
var _first: Button
var _quit: Button
var _refresh_t := 0.0
var _scroll: ScrollContainer
var _my_card: Control
var _shown_sig := ""             # the tallies last drawn (they can arrive after the screen opens)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.035, 0.02, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	var team := maxi(m.winner, 0)
	var title := UiKit.label("%s TEAM WINS!" % Match.TEAM_NAMES[team].to_upper(), 42, UiKit.TEAM[team])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	v.add_child(title)
	var mine := me != null and me.team == m.winner
	var cheer := "The scrap heap is yours. Squeak with pride!" if m.scrap_race else "The golden cheese is yours. Squeak with pride!"
	var sub := UiKit.label(cheer if mine else "Out-burrowed this time. Dig faster, bonk harder!", 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var line := "Blue %d  -  %d Red        Match time %d:%02d        Final scrap value x%.2f" % [
		m.scores[0], m.scores[1], int(m.time) / 60, int(m.time) % 60, m.multiplier()]
	if m.scrap_race:
		line = "SCRAP RACE   Blue %d  -  %d Red scrap        Cheese banked %d - %d (scrap value x%.2f / x%.2f)        Match time %d:%02d" % [
			m.scores[0], m.scores[1], m.vault[0], m.vault[1], m.multiplier(0), m.multiplier(1), int(m.time) / 60, int(m.time) % 60]
	var score := UiKit.label(line, 15, UiKit.BRASS)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score)

	var sc := ScrollContainer.new()
	_scroll = sc
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var biggest := 0
	for t in 2:
		biggest = maxi(biggest, sorted_team(m.rats, t).size())
	var teams: BoxContainer = HBoxContainer.new() if biggest <= SIDE_BY_SIDE else VBoxContainer.new()
	teams.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams.add_theme_constant_override("separation", 24 if teams is HBoxContainer else 10)
	sc.add_child(teams)
	for t: int in [team, 1 - team]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		teams.add_child(col)
		_team_row(col, t, t == team)

	_hint = UiKit.label("", 15, UiKit.PAPER.darkened(0.1))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	_status = UiKit.label("", 16, UiKit.BRASS)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	_buttons(h)
	_refresh(true)
	_show_mine.call_deferred()


func _show_mine() -> void:
	## A big game's line-up scrolls: start with your own card in view.
	await get_tree().process_frame
	if is_instance_valid(_my_card) and is_instance_valid(_scroll):
		_scroll.ensure_control_visible(_my_card)


func host_role() -> String:
	## "offline", "host" or "client": who decides what comes next.
	if m.replica:
		return "client"
	return "host" if m.networked else "offline"


func _buttons(h: HBoxContainer) -> void:
	match host_role():
		"offline":
			_first = UiKit.button("Play again (new map)", func() -> void: next_game.emit(), Vector2(240, 46))
			h.add_child(_first)
			h.add_child(UiKit.button("Main menu", func() -> void: leave.emit(), Vector2(180, 46)))
		"host":
			_first = UiKit.button("Next game (new map)", func() -> void: next_game.emit(), Vector2(240, 46))
			h.add_child(_first)
			h.add_child(UiKit.button("Back to the lobby", func() -> void: to_lobby.emit(), Vector2(220, 46)))
			h.add_child(UiKit.button("Main menu (ends the game)", func() -> void: leave.emit(), Vector2(260, 46)))
		_:
			_first = UiKit.button("Leave to the menu", func() -> void: leave.emit(), Vector2(220, 46))
			h.add_child(_first)
	if not OS.has_feature("web"):
		_quit = UiKit.button("Quit game", _quit_pressed, Vector2(150, 46))
		h.add_child(_quit)


func _quit_pressed() -> void:
	## Asks once: the first press arms it, the second quits to the desktop.
	if _quit.text != "Really quit?":
		_quit.text = "Really quit?"
		return
	get_tree().paused = false
	get_tree().quit()


func first_button() -> Button:
	return _first


# ---------------------------------------------------------------- line-up

static func sorted_team(rats: Array[Rat], team: int) -> Array[Rat]:
	## A team's rats, best haul first.
	var out: Array[Rat] = []
	for r in rats:
		if r.team == team:
			out.append(r)
	out.sort_custom(func(a: Rat, b: Rat) -> bool: return mvp_score(a) > mvp_score(b))
	return out


static func mvp_score(r: Rat) -> int:
	var s := r.stats
	return int(s.get("scrapbank", 0)) / 5 + int(s.get("banked", 0)) * 10 + int(s.get("stolen", 0)) * 6 + int(s.get("mined", 0)) * 4 \
		+ int(s.get("bonks", 0)) * 2 + int(s.get("tnt", 0)) + int(s.get("traps", 0)) + int(s.get("blocks", 0)) / 20


static func mvp(rats: Array[Rat], team: int) -> Rat:
	## The winning team's standout (null if nobody did anything).
	var best: Rat = null
	for r in rats:
		if r.team == team and mvp_score(r) > 0 and (best == null or mvp_score(r) > mvp_score(best)):
			best = r
	return best


static func leaders(rats: Array[Rat]) -> Dictionary:
	## stat -> the top value anyone reached (0 when nobody did it).
	var out := {}
	for k: String in Match.STATS:
		var top := 0
		for r in rats:
			top = maxi(top, int(r.stats.get(k, 0)))
		out[k] = top
	return out


func _team_row(parent: VBoxContainer, team: int, winners: bool) -> void:
	var head := UiKit.label("%s  -  %s" % [Match.TEAM_NAMES[team].to_upper(), "WINNERS" if winners else "Better luck next time"],
		20 if winners else 17, UiKit.TEAM[team].lightened(0.25))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(head)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(flow)
	for r in sorted_team(m.rats, team):
		flow.add_child(_card(r, winners))


func _card(r: Rat, winners: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var edge: Color = UiKit.TEAM[r.team]
	if r == me:
		edge = UiKit.BRASS
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0.14, 0.1, 0.07, 0.92), edge, 8, 3 if r == me else 2, 6))
	if r == me:
		_my_card = card
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)
	var badge := UiKit.label("", 13, UiKit.BRASS)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(badge)
	# the rat itself, big, facing you
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(CARD_W - 12, PIC - 14 + (12 if r.hat != "" else 0))   # (the art has space above the ears; a hat needs some)
	stage.clip_contents = false
	v.add_child(stage)
	var pic := TextureRect.new()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(PIC, PIC * RatSprite.CELL_H / RatSprite.CELL)   # (frames have room for a hat on top)
	pic.pivot_offset = pic.size * 0.5
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(pic)
	var name_l := UiKit.label(r.display_name, 15, UiKit.TEAM[r.team].lightened(0.35))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	var sub := "%s%s" % [r.cls.get("name", r.class_id), "  (you)" if r == me else ("  (bot)" if r.is_bot else "")]
	var cls_l := UiKit.label(sub, 12, UiKit.PAPER.darkened(0.25))
	cls_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cls_l)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	v.add_child(grid)
	var values := {}
	for k: String in Match.STATS:
		if Match.SCRAP_RACE_ONLY.has(k) and not m.scrap_race:
			continue
		var n := UiKit.label(String(Match.STAT_NAMES[k]), 12, UiKit.PAPER.darkened(0.15))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(n)
		var val := UiKit.label("0", 13, UiKit.PAPER)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		values[k] = val
	_cards[r.id] = {"rat": r, "pic": pic, "stage": stage, "values": values, "badge": badge, "winners": winners, "t": randf() * 3.0}
	return card


func _refresh(force := false) -> void:
	## Redraw the tallies (an online player may get them a moment after the
	## win) and the leaders in gold.
	var sig := ""
	for r in m.rats:
		sig += "%d:%s|" % [r.id, str(r.stats)]
	if sig == _shown_sig and not force:
		return
	_shown_sig = sig
	var top := leaders(m.rats)
	var best := mvp(m.rats, m.winner)
	for id: int in _cards:
		var c: Dictionary = _cards[id]
		var r: Rat = c["rat"]
		if not is_instance_valid(r):
			continue
		for k: String in Match.STATS:
			if not (c["values"] as Dictionary).has(k):
				continue
			var n := int(r.stats.get(k, 0))
			var l: Label = c["values"][k]
			l.text = str(n)
			var lead := n > 0 and n == int(top[k]) and k != "bonked"
			l.add_theme_color_override("font_color", UiKit.BRASS if lead else (UiKit.PAPER if n > 0 else UiKit.PAPER.darkened(0.45)))
		(c["badge"] as Label).text = "MVP" if r == best else ("" if r != me else "YOU")


# ---------------------------------------------------------------- emotes

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or me == null:
		return
	var kind := emote_for(event)
	if kind == "":
		return
	get_viewport().set_input_as_handled()   # (so the stick or Space doesn't also move the button focus or press one)
	m.emote(me, kind)


static func emote_for(event: InputEvent) -> String:
	## Which emote an input asks for: the movement keys and the left stick,
	## jump (Space) on a keyboard, and Y on a gamepad. "" for anything else.
	if event is InputEventKey and (event.echo or not event.pressed):
		return ""
	if event is InputEventMouse:
		return ""
	for action: String in EMOTE_KEYS:
		if event.is_action_pressed(action):
			if action == "jump" and event is InputEventJoypadButton:
				return ""   # A presses the buttons on a gamepad
			return EMOTE_KEYS[action]
	if event is InputEventJoypadButton and event.is_action_pressed(PAD_FLIP):
		return "flip"
	return ""


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		_refresh()
		_status.text = status_text()
		_hint.text = emote_hint()
	for id: int in _cards:
		_animate(_cards[id], delta)
	# a controller scrolls the line-up with the right stick (the left one emotes)
	var look := Input.get_axis("look_up", "look_down")
	if absf(look) > 0.2 and _scroll != null:
		_scroll.scroll_vertical += int(look * 900.0 * delta)


func status_text() -> String:
	match host_role():
		"host":
			return "You're the host: start the next game, or take everyone back to the lobby."
		"client":
			if m.next_in >= 0.0:
				return "Next round in %d s" % ceili(m.next_in)
			return "Waiting for the host to start the next game..."
	return ""


func emote_hint() -> String:
	if Inputs.using_pad:
		return "Emote: push the left stick any way, %s to flip" % Inputs.button_name(JOY_BUTTON_Y)
	return "Emote:  %s cheer   %s dance   %s taunt   %s flop   %s flip" % [
		Inputs.key_name("move_forward"), Inputs.key_name("move_left"), Inputs.key_name("move_right"),
		Inputs.key_name("move_back"), Inputs.key_name("jump")]


func _animate(c: Dictionary, delta: float) -> void:
	## The rat on its card: idle (winners bounce), or the emote it is playing.
	var r: Rat = c["rat"]
	if not is_instance_valid(r):
		return
	c["t"] = float(c["t"]) + delta
	var t := float(c["t"])
	var pic: TextureRect = c["pic"]
	var stage: Control = c["stage"]
	var anim := "idle"
	var off := Vector2.ZERO
	var spin := 0.0
	var flip := false
	var squash := Vector2.ONE
	if r.emote_t > 0.0:
		var e := Match.EMOTE_TIME - r.emote_t   # seconds into it
		match r.emote:
			"cheer":
				anim = "jump"
				off.y = -absf(sin(e * 8.0)) * 20.0
			"dance":
				anim = "run"
				flip = int(e / 0.2) % 2 == 1
				off.x = sin(e * 10.0) * 9.0
			"taunt":
				anim = "attack"
				squash = Vector2.ONE * (1.0 + 0.1 * absf(sin(e * 9.0)))
			"flop":
				anim = "down"
			"flip":
				anim = "jump"
				var k := clampf(e / 0.7, 0.0, 1.0)
				spin = k * TAU
				off.y = -sin(k * PI) * 30.0
	elif bool(c["winners"]):
		anim = "idle"
		off.y = -absf(sin(t * 3.0)) * 5.0
	var frames := int(RatSprite.FRAMES[anim])
	var frame := int(t * float(RatSprite.FPS[anim])) % frames
	if anim == "down" and r.emote_t > 0.0:
		frame = mini(int((Match.EMOTE_TIME - r.emote_t) * float(RatSprite.FPS[anim])), frames - 1)   # flop over and stay down
	var tex := RatSprite._frame(r.class_id, r.team, anim, frame, "front", r.hat)
	var side := tex == null
	if side:
		tex = RatSprite._frame(r.class_id, r.team, anim, frame, "side", r.hat)
	pic.texture = tex
	pic.flip_h = flip
	pic.rotation = spin
	pic.scale = squash
	var room := float(Hats.ROOM) * PIC / RatSprite.CELL
	pic.position = Vector2((stage.size.x - PIC) * 0.5, stage.size.y - (PIC - 14) - 16.0 - room) + off
