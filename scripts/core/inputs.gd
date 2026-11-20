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
	"slot_5": [KEY_8, "Painted block / glass (colour)"],
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
	"gear": [KEY_J, "Use gear (jetpack)"],
	"workshop": [KEY_B, "Workshop"],
	"inventory": [KEY_I, "Inventory"],
	"respawn": [KEY_K, "Respawn at base (with Ctrl)"],
	"fly": [KEY_N, "Free Build: toggle flight"],
	"save_map": [KEY_F5, "Free Build: save map"],
	"load_map": [KEY_F9, "Free Build: load map"],
	"start_match": [KEY_ENTER, "Lobby: start the match (host)"],
	"pause": [KEY_ESCAPE, "Pause"],
}

const MOUSE := {
	"dig": MOUSE_BUTTON_LEFT,
	"place": MOUSE_BUTTON_RIGHT,
}

## Gamepad layout (Xbox names; the Steam Deck's buttons are labelled the same).
## Each entry: ["b", button] or ["a", axis, direction]. Actions that exist
## only on a gamepad (look, next/previous slot) are added here as well.
const PAD := {
	"move_forward": [["a", JOY_AXIS_LEFT_Y, -1]],
	"move_back": [["a", JOY_AXIS_LEFT_Y, 1]],
	"move_left": [["a", JOY_AXIS_LEFT_X, -1]],
	"move_right": [["a", JOY_AXIS_LEFT_X, 1]],
	"look_left": [["a", JOY_AXIS_RIGHT_X, -1]],
	"look_right": [["a", JOY_AXIS_RIGHT_X, 1]],
	"look_up": [["a", JOY_AXIS_RIGHT_Y, -1]],
	"look_down": [["a", JOY_AXIS_RIGHT_Y, 1]],
	"jump": [["b", JOY_BUTTON_A]],
	"dash": [["b", JOY_BUTTON_B]],
	"descend": [["b", JOY_BUTTON_B]],          # held: climb down / swim down / fly down
	"interact": [["b", JOY_BUTTON_X]],
	"gear": [["b", JOY_BUTTON_Y]],
	"gadget": [["b", JOY_BUTTON_RIGHT_SHOULDER]],
	"cycle_gadget": [["b", JOY_BUTTON_LEFT_SHOULDER]],
	"dig": [["a", JOY_AXIS_TRIGGER_RIGHT, 1]],
	"place": [["a", JOY_AXIS_TRIGGER_LEFT, 1]],
	"next_slot": [["b", JOY_BUTTON_DPAD_RIGHT]],
	"prev_slot": [["b", JOY_BUTTON_DPAD_LEFT]],
	"ability_1": [["b", JOY_BUTTON_DPAD_UP]],
	"ability_2": [["b", JOY_BUTTON_DPAD_DOWN]],
	"drop_cheese": [["b", JOY_BUTTON_LEFT_STICK]],
	"camera_toggle": [["b", JOY_BUTTON_RIGHT_STICK]],
	"pause": [["b", JOY_BUTTON_START]],
	"workshop": [["b", JOY_BUTTON_BACK]],
}
const PAD_DEADZONE := 0.2
const PAD_LABELS := {"move_forward": "Move", "look_left": "Look", "jump": "Jump", "dash": "Dash (climb down on ladders, in water or flying)",
	"interact": "Pilot a machine", "gear": "Use gear", "gadget": "Use the Q gadget (hold B as well to set it down gently)",
	"cycle_gadget": "Next gadget", "dig": "Dig / bonk", "place": "Place", "next_slot": "Next material or tool",
	"prev_slot": "Previous material or tool", "ability_1": "Class ability 1 (rotate a blueprint)",
	"ability_2": "Class ability 2 (mirror a blueprint)", "drop_cheese": "Drop one cheese", "camera_toggle": "First / third person",
	"pause": "Menu", "workshop": "Workshop (your pack when away from base)"}

signal device_changed(pad: bool)

var using_pad := false          # the last thing the player touched was a gamepad
var pad_device := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in KEYS:
		_bind_key(action, Config.get_key(action, KEYS[action][0]))
	for action: String in MOUSE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE[action]
		InputMap.action_add_event(action, ev)
	_bind_pad()


func _bind_pad() -> void:
	for action: String in PAD:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, PAD_DEADZONE)
		for spec: Array in PAD[action]:
			InputMap.action_add_event(action, _pad_event(spec))
	# menus: A confirms, B goes back (directions already include the D-pad and stick)
	for pair: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ev := InputEventJoypadButton.new()
		ev.device = -1
		ev.button_index = pair[1]
		InputMap.action_add_event(pair[0], ev)


static func _pad_event(spec: Array) -> InputEvent:
	if spec[0] == "b":
		var b := InputEventJoypadButton.new()
		b.device = -1          # any controller
		b.button_index = spec[1]
		return b
	var a := InputEventJoypadMotion.new()
	a.device = -1
	a.axis = spec[1]
	a.axis_value = float(spec[2])
	return a


func _input(event: InputEvent) -> void:
	# Prompts follow whatever the player last touched.
	var pad := using_pad
	if event is InputEventJoypadButton and event.is_pressed():
		pad = true
		pad_device = event.device
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		pad = true
		pad_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 6.0:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(pad)


func rumble(weak: float, strong: float, seconds: float) -> void:
	## A short buzz on the controller in use (if the player allows it).
	if using_pad and bool(Config.get_value("vibration")):
		Input.start_joy_vibration(pad_device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)


func pad_name(action: String) -> String:
	## The controller button for an action, by the controller's own labels.
	if not PAD.has(action):
		return ""
	var spec: Array = PAD[action][0]
	var sony := _is_sony()
	if spec[0] == "a":
		match int(spec[1]):
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "Left stick"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "Right stick"
			JOY_AXIS_TRIGGER_LEFT:
				return "L2" if sony else "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "R2" if sony else "RT"
		return "Stick"
	match int(spec[1]):
		JOY_BUTTON_A: return "Cross" if sony else "A"
		JOY_BUTTON_B: return "Circle" if sony else "B"
		JOY_BUTTON_X: return "Square" if sony else "X"
		JOY_BUTTON_Y: return "Triangle" if sony else "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "L1" if sony else "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1" if sony else "RB"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_START: return "Options" if sony else "Menu"
		JOY_BUTTON_BACK: return "Create" if sony else "View"
		JOY_BUTTON_DPAD_UP: return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad Right"
	return "Button %d" % int(spec[1])


func _is_sony() -> bool:
	var n := Input.get_joy_name(pad_device).to_lower()
	return n.contains("ps4") or n.contains("ps5") or n.contains("dualsense") or n.contains("dualshock") \
		or n.contains("sony") or n.contains("playstation")


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
	## What to press, on the device the player is using right now.
	if using_pad and PAD.has(action):
		return pad_name(action)
	if MOUSE.has(action):
		return "LMB" if MOUSE[action] == MOUSE_BUTTON_LEFT else "RMB"
	return OS.get_keycode_string(key_of(action))
