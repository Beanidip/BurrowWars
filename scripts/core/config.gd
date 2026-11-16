extends Node
## Player settings (user://settings.cfg) and gameplay tuning constants.
## Tuning lives here so balance changes never require hunting through systems.

const PATH := "user://settings.cfg"

# --- gameplay tuning (authoritative rules read these) ---
const DIG_RATE := 3.0            # digging actions per second
const DIG_REACH := 4.5           # blocks
const BASE_SPEED := 5.5          # blocks / second at class speed 1.0
const CARRY_SPEED_MULT := 0.25   # movement while carrying cheese
const BONK_COOLDOWN := 2.0
const BONK_RANGE := 2.4
const BONK_PICKUP_LOCK := 2.0
const DASH_COST := 25.0
const DOUBLE_JUMP_COST := 10.0
const STAMINA_REGEN := 14.0
const BASE_SCRAP_PER_BLOCK := 2
const GROWTH_BONUS := 1.5
const STACK_MAX := 10

const DEFAULTS := {
	"mouse_sensitivity": 0.0025,
	"invert_y": false,
	"fov": 80.0,
	"master_volume": 0.8,
	"music_volume": 0.45,
	"camera_distance": 4.0,
	"goal": 8,
	"team_size": 2,
	"last_class": "digger",
	"last_team": 0,
}

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		Log.warn("settings.cfg unreadable (error %d); using defaults" % err)
		_cfg = ConfigFile.new()
	apply_audio()


func get_value(key: String) -> Variant:
	return _cfg.get_value("settings", key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_cfg.set_value("settings", key, value)


func get_key(action: String, fallback: int) -> int:
	return int(_cfg.get_value("keys", action, fallback))


func set_key(action: String, keycode: int) -> void:
	_cfg.set_value("keys", action, keycode)


func save() -> void:
	var err := _cfg.save(PATH)
	if err != OK:
		Log.warn("could not save settings (error %d)" % err)


func apply_audio() -> void:
	var v := float(get_value("master_volume"))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.001)
