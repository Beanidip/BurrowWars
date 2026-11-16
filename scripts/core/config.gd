extends Node
## Player settings (user://settings.cfg) and gameplay tuning constants.
## Tuning lives here so balance changes never require hunting through systems.

const PATH := "user://settings.cfg"

# --- gameplay tuning (authoritative rules read these) ---
const DIG_RATE := 3.0            # digging actions per second
const DIG_REACH := 4.5           # blocks
const BASE_SPEED := 5.5          # blocks / second at class speed 1.0
const CARRY_SPEED := [1.0, 0.45, 0.34, 0.25]   # speed multiplier by cheese carried (3+ uses the last)
const GATE_HP := 10              # wrecking-ball hits to break a team gate; a TNT blast counts as 5
const CRANE_MIN_SPEED := 2.4     # the ball must be moving at least this fast to count as a hit
const RAID_TIME := 3.0           # seconds inside the enemy base to lift one banked cheese
const BONK_COOLDOWN := 2.0
const BONK_RANGE := 2.4
const BONK_PICKUP_LOCK := 2.0
const DASH_COST := 25.0
const DASH_CARRY := [1.0, 0.5, 0.4, 0.3]   # dash burst by cheese carried (3+ uses the last)
const DASH_CARRY_COST := 40.0    # stamina per dash while carrying any cheese
const DOUBLE_JUMP_COST := 10.0
const STAMINA_REGEN := 14.0
const BASE_SCRAP_PER_BLOCK := 2
const GROWTH_BONUS := 1.5
const STACK_MAX := 10
const CHISEL_RATE := 9.0          # microvoxel edits per second
const TNT_RADIUS := 2.9           # stationary TNT: blocks
const TNT_POWER := 10.0           # dig hits at the centre, falling to 0 at the radius
const DYNAMITE_RADIUS := 2.4
const DYNAMITE_POWER := 6.5
const DYNAMITE_FUSE := 3.0
const DYNAMITE_THROW_SPEED := 12.0
const DYNAMITE_MAX_ACTIVE := 16
const CANNON_COOLDOWN := 2.2
const CANNON_SPEED := 24.0
const CANNON_HIT := 3             # dig hits on the struck block (neighbours take 1)
const CRANE_MAX_HIT := 4
const DOZER_COOLDOWN := 1.0
const DOZER_HIT := 2
const MACHINE_MOVE_TIME := 0.45   # seconds per block on a conveyor
const PANTOGRAPH_MAX := 9         # blueprint edge limit, blocks

const DEFAULTS := {
	"mouse_sensitivity": 0.0025,
	"invert_y": false,
	"fov": 80.0,
	"master_volume": 0.8,
	"music_volume": 0.45,
	"camera_distance": 4.0,
	"goal": 8,
	"team_size": 2,
	"bot_skill": 1,
	"last_class": "digger",
	"last_team": 0,
	"player_name": "",
	"last_address": "",
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
