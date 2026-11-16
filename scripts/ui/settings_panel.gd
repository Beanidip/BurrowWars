class_name SettingsPanel
extends VBoxContainer
## Settings + key rebinding, shared by the main menu and the pause menu.

signal changed

var _waiting_action := ""
var _waiting_button: Button
var _notice: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_slider_row("Mouse sensitivity", "mouse_sensitivity", 0.0005, 0.008, 0.0001)
	_slider_row("Field of view", "fov", 60.0, 110.0, 1.0)
	_slider_row("Third-person camera distance", "camera_distance", 2.0, 7.0, 0.1)
	_slider_row("Master volume", "master_volume", 0.0, 1.0, 0.01)
	_slider_row("Music volume", "music_volume", 0.0, 1.0, 0.01)
	var inv := CheckBox.new()
	inv.text = "Invert mouse Y"
	inv.button_pressed = bool(Config.get_value("invert_y"))
	inv.toggled.connect(func(on: bool) -> void: _store("invert_y", on))
	add_child(inv)
	add_child(UiKit.label("Controls  (click a key, then press the new one)", 18, UiKit.BRASS))
	_notice = UiKit.label("", 14, UiKit.TEAM[1])
	add_child(_notice)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	add_child(grid)
	for action: String in Inputs.KEYS:
		var l := UiKit.label(Inputs.KEYS[action][1], 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.text = Inputs.key_name(action)
		b.custom_minimum_size = Vector2(130, 30)
		b.pressed.connect(_begin_rebind.bind(action, b))
		grid.add_child(b)
	grid.add_child(UiKit.label("Dig / bonk", 15))
	grid.add_child(UiKit.label("Left mouse", 15, UiKit.BRASS))
	grid.add_child(UiKit.label("Place selected material", 15))
	grid.add_child(UiKit.label("Right mouse", 15, UiKit.BRASS))


func _slider_row(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var s := UiKit.slider(lo, hi, step, float(Config.get_value(key)), func(v: float) -> void: _store(key, v))
	add_child(UiKit.row(UiKit.label(text, 15), s))


func _store(key: String, value: Variant) -> void:
	Config.set_value(key, value)
	Config.save()
	Config.apply_audio()
	if key == "music_volume":
		Sfx.set_music_volume(float(value))
	changed.emit()


func _begin_rebind(action: String, button: Button) -> void:
	_waiting_action = action
	_waiting_button = button
	button.text = "press a key..."
	_notice.text = ""


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).physical_keycode
	var action := _waiting_action
	_waiting_action = ""
	if key != KEY_ESCAPE or action == "pause":
		var clash := Inputs.rebind(action, key)
		if clash != "":
			_notice.text = "%s is already used by \"%s\"" % [OS.get_keycode_string(key), clash]
	_waiting_button.text = Inputs.key_name(action)
	changed.emit()
