class_name TutorialGuide
extends CanvasLayer
## Learn to Play: a short guided first match. A quiet goal-1 game with no bots
## playing, a practice rat standing outside your base and a cheese buried just
## past it. A panel walks you through moving, the workshop, digging, building,
## bonking, finding cheese and bringing it home; each step ticks off when you
## have done it. Banking the cheese wins the match, which ends the tutorial.
## Key names come from Inputs, so they follow the player's own bindings.

signal finished

const STEPS := ["move", "shop", "dig", "place", "bonk", "cheese", "home"]
const MARK_TTL := 1.0e9

var m: Match
var rat: Rat
var step := 0
var dummy: Rat
var cheese_cell := Vector3i(-1, -1, -1)
var _start := Vector3.ZERO
var _scrap0 := 0
var _mats0 := 0
var _placed := 0
var _bonked := false
var _poll_t := 0.0
var _title: Label
var _text: Label
var _done := false


func setup() -> void:
	## Make the map tutorial-friendly. Call once, before the world is meshed.
	m.bots.clear()   # nobody else plays: the rats just stand where they are
	var front := MapGenerator.approach_point(rat.team)
	var out := Vector3(signf(front.x - rat.position.x), 0, signf(front.z - rat.position.z))
	for r in m.rats:
		if r.team != rat.team and dummy == null:
			dummy = r
	if dummy != null:
		var at := Vector3i(floori(front.x + out.x * 3.0), 0, floori(front.z + 2.0))
		dummy.position = Vector3(at.x + 0.5, m.world.surface_y(at.x, at.z), at.z + 0.5)
		dummy.display_name = "Practice Rat"
	var c := Vector3i(floori(front.x + out.x * 7.0), 0, floori(front.z - 2.0))
	cheese_cell = Vector3i(c.x, m.world.surface_y(c.x, c.z) - 2, c.z)   # one block of ground over it
	m.world.set_block(cheese_cell, Blocks.CHEESE)
	_begin(0)


func _ready() -> void:
	layer = 5
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.08, 0.05, 0.88), UiKit.BRASS, 10, 2, 12))
	panel.position = Vector2(16, 110)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_title = UiKit.label("", 17, UiKit.BRASS)
	v.add_child(_title)
	_text = UiKit.wrapped("", 16)
	_text.custom_minimum_size = Vector2(340, 0)
	v.add_child(_text)
	_refresh()


func text_for(i: int) -> String:
	var k := func(action: String) -> String: return Inputs.key_name(action)
	match STEPS[clampi(i, 0, STEPS.size() - 1)]:
		"move":
			if Inputs.using_pad:
				return "Walk with the left stick and look around with the right stick. %s jumps; press it again in the air to double jump." % k.call("jump")
			return "Look around with the mouse and walk with %s %s %s %s. %s jumps; press it again in the air to double jump." % [
				k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right"), k.call("jump")]
		"shop":
			return "Back on your base, press %s to open the workshop and buy something - try Ladders. You start with a little scrap; mining orange scrap blocks earns more." % k.call("workshop")
		"dig":
			return "Hold %s on the ground to dig. Dig 3 blocks: the dirt and stone go into your pack." % k.call("dig")
		"place":
			var pick := "%s / %s pick the material" % [k.call("prev_slot"), k.call("next_slot")] if Inputs.using_pad \
				else "%s-%s pick the material" % [k.call("slot_1"), k.call("slot_4")]
			return "%s places what you dug (%s). Place 2 blocks - handy for climbing out of holes." % [k.call("place"), pick]
		"bonk":
			return "A Practice Rat is waiting outside your base (marked). Walk up to it and press %s to bonk it. A bonked rat drops a cheese if it carries one." % k.call("dig")
		"cheese":
			return "Golden cheese is buried just outside your base (marked). Dig down to it and walk into it to pick it up."
		"home":
			return "Carry it home! Cheese slows you down, so keep away from enemies. Step onto your base to bank it and win."
	return ""


func _begin(i: int) -> void:
	step = i
	_start = rat.position
	_scrap0 = rat.scrap
	_mats0 = _mat_total()
	_placed = 0
	_bonked = false
	_clear_markers()
	match STEPS[clampi(step, 0, STEPS.size() - 1)]:
		"bonk":
			if dummy != null:
				m.add_marker(dummy.position + Vector3(0, 1.2, 0), "Practice Rat", rat.team, MARK_TTL)
		"cheese":
			m.add_marker(Vector3(cheese_cell) + Vector3(0.5, 1.5, 0.5), "Cheese here", rat.team, MARK_TTL)
		"home":
			var zone := MapGenerator.base_zone(rat.team)
			m.add_marker(zone.get_center() + Vector3(0, 1.0, 0), "Home", rat.team, MARK_TTL)
	_refresh()


func _clear_markers() -> void:
	for i in range(m.markers.size() - 1, -1, -1):
		if float(m.markers[i]["ttl"]) > MARK_TTL * 0.5:
			m.markers.remove_at(i)


func _mat_total() -> int:
	var n := 0
	for k: String in rat.mats:
		n += int(rat.mats[k])
	return n


func _refresh() -> void:
	if _title == null:
		return
	if _done:
		_title.text = "Learn to Play - done!"
		_text.text = "You banked your first cheese. In a real match the first team to the goal wins. %s > Quit to menu, then try a Cheese Race against bots." % Inputs.key_name("pause")
		return
	_title.text = "Learn to Play  -  step %d of %d" % [step + 1, STEPS.size()]
	_text.text = text_for(step)


func on_fx(kind: String, pos: Vector3, _data: Variant) -> void:
	## Placing and bonking are seen through the match's effect events.
	if kind == "place" and (pos + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) < 8.0:
		_placed += 1
	elif kind == "bonk" and dummy != null and pos.distance_to(dummy.position) < 2.5:
		_bonked = true


func poll() -> void:
	## Has the current step been done? (Called a few times a second.)
	if _done:
		return
	var ok := false
	match STEPS[step]:
		"move":
			ok = Vector2(rat.position.x - _start.x, rat.position.z - _start.z).length() > 3.0
		"shop":
			ok = rat.scrap < _scrap0
		"dig":
			ok = _mat_total() >= _mats0 + 3
		"place":
			ok = _placed >= 2
		"bonk":
			ok = _bonked
		"cheese":
			ok = rat.carried > 0
		"home":
			if m.scores[rat.team] >= 1:
				ok = true
			elif rat.carried == 0:
				_begin(STEPS.find("cheese"))   # dropped it: go and get it again
				return
	if not ok:
		return
	if step + 1 >= STEPS.size():
		_done = true
		_clear_markers()
		Config.set_value("tutorial_done", true)
		Config.save()
		_refresh()
		finished.emit()
	else:
		Sfx.play("discovery_chime", -6.0, 1.2, 0.0)
		_begin(step + 1)


func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t <= 0.0 and m != null and rat != null:
		_poll_t = 0.2
		poll()
