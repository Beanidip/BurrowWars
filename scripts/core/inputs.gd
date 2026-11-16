extends Node
## Centralized input-action registry. Every binding in the game is declared
## here exactly once, so two unrelated behaviours can never share a key by
## accident. Keys are remappable (pause menu -> Controls) and persisted.

# action -> [default physical keycode, label]. Mouse actions are listed below.
const KEYS := {
	"move_forward": [KEY_W, "Move forward"],
	"move_back": [KEY_S, "Move back"],
	"move_left": [KEY_A, "Move left"],
	"move_right": [KEY_D, "Move right"],
	"jump": [KEY_SPACE, "Jump / climb up / swim up"],
	"descend": [KEY_CTRL, "Climb down"],
	"dash": [KEY_SHIFT, "Dash"],
	"camera_toggle": [KEY_V, "First / third person"],
	"slot_1": [KEY_1, "Material: dirt"],
	"slot_2": [KEY_2, "Material: stone"],
	"slot_3": [KEY_3, "Material: ice"],
	"slot_4": [KEY_4, "Material: obsidian"],
	"slot_5": [KEY_5, "Painted block / glass (colour)"],
	"color_picker": [KEY_C, "Colour picker"],
	"chisel": [KEY_9, "Chisel (microvoxel carving)"],
	"pantograph": [KEY_0, "Pantograph (copy / paste)"],
	"rotate_blueprint": [KEY_X, "Pantograph: rotate blueprint"],
	"mirror_blueprint": [KEY_Z, "Pantograph: mirror blueprint (left-right)"],
	"flip_blueprint": [KEY_Y, "Pantograph: flip blueprint (upside down)"],
	"invert_blueprint": [KEY_U, "Pantograph: invert blueprint (filled <-> empty)"],
	"interact": [KEY_T, "Pilot / leave siege machine"],
	"gadget": [KEY_Q, "Place equipped gadget"],
	"ability_1": [KEY_E, "Class ability 1"],
	"ability_2": [KEY_F, "Class ability 2"],
	"cycle_gadget": [KEY_R, "Change Q slot gadget"],
	"drop_cheese": [KEY_G, "Drop one cheese"],
	"workshop": [KEY_B, "Workshop"],
	"inventory": [KEY_I, "Inventory"],
	"respawn": [KEY_K, "Respawn at base (with Ctrl)"],
	"fly": [KEY_N, "Free Build: toggle flight"],
	"save_map": [KEY_F5, "Free Build: save map"],
	"load_map": [KEY_F9, "Free Build: load map"],
	"pause": [KEY_ESCAPE, "Pause"],
}

const MOUSE := {
	"dig": MOUSE_BUTTON_LEFT,
	"place": MOUSE_BUTTON_RIGHT,
}


func _ready() -> void:
	for action: String in KEYS:
		_bind_key(action, Config.get_key(action, KEYS[action][0]))
	for action: String in MOUSE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE[action]
		InputMap.action_add_event(action, ev)


func _bind_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)


func rebind(action: String, keycode: int) -> String:
	## Returns "" on success, or the label of the conflicting action.
	for other: String in KEYS:
		if other != action and key_of(other) == keycode:
			return KEYS[other][1]
	_bind_key(action, keycode)
	Config.set_key(action, keycode)
	Config.save()
	return ""


func key_of(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return 0


func key_name(action: String) -> String:
	if MOUSE.has(action):
		return "LMB" if MOUSE[action] == MOUSE_BUTTON_LEFT else "RMB"
	return OS.get_keycode_string(key_of(action))
