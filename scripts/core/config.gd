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
const LOBBY_LAUNCH := 2.0          # bonks and cannonballs fling rats this much harder in the lobby playground
const BONK_PICKUP_LOCK := 2.0
const DASH_COST := 25.0
const DASH_CARRY := [1.0, 0.5, 0.4, 0.3]   # dash burst by cheese carried (3+ uses the last)
const DASH_CARRY_COST := 40.0    # stamina per dash while carrying any cheese
const TRAP_HITS_OWN := 5          # digs for a team to clear its own placed trap
const TRAP_HITS_ENEMY := 15       # ... and for the other team (or a blast)
const STASH_BLASTS := 5           # TNT blasts that break a team stash
const STASH_REACH := 3.5          # how close to a stash you must stand to use it
const STASH_KEYS := ["scrap", "dirt", "stone", "ice", "obsidian"]
const SPRING_SIDE_SPEED := 12.0   # springs also fling anything right next to them
const WALL_SPRING_SPEED := 13.0   # a wall spring shoves anyone within a block of it this hard
const BOT_RAID_GUARDED := 20.0    # bots give up raiding a base its team has stood guard in this long
const JETPACK_TIME := 1.1         # seconds of thrust per use
const JETPACK_LIFT := 9.0         # upward speed while thrusting
const JETPACK_COOLDOWN := 5.0     # seconds after the thrust ends
const JETPACK_CARRY := 0.5        # lift while carrying cheese (half as strong)
const SHIELD_TIME := 5.0          # seconds the Rat Knight Shield stays raised
const SHIELD_COOLDOWN := 8.0      # seconds after it drops before it can be raised again
const SHIELD_CARRY_SPEED := 0.75  # speed while it is raised and you carry cheese (a quarter slower)
const BUBBLE_COST := 2            # scrap per Bubble Shoes bubble
const BUBBLE_TIME := 10.0         # seconds a bubble lasts before it pops
const DECOY_STUN := 1.5           # seconds an enemy is dazed after digging a Cheese Decoy
const SQUEAKER_USES := 3          # squeaks before a Squeaker Pad is spent
const SQUEAKER_REST := 2.0        # seconds between squeaks from one pad
const SQUEAKER_MARK := 8.0        # seconds the beacon it drops for its team lasts
const TELE_WAIT := 0.5            # seconds standing on a charged teleporter entrance before it sends you
const TELE_CHARGE := 6.0          # seconds an entrance recharges after each trip
const CRUMB_EVERY := 1.4          # blocks a cheese carrier covers between the crumbs it drops
const CRUMB_TIME := 25.0          # seconds a crumb lies on the ground
const WINDUP_FUSE := 20.0         # seconds a Wind-up Decoy marches before it goes off by itself
const WINDUP_MAX_ACTIVE := 8      # wind-ups marching at once, both teams together
const WINDUP_CHASE := 10.0        # bots run after a cheese carrier (or what looks like one) this close
const POUND_HEIGHT := 0.85        # a double jump this close to its full height, landed flat, thumps the block below
const POUND_COOLDOWN := 0.6
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
const DYNAMITE_MAX_ACTIVE := 16    # sticks and impulse grenades in the air at once
const IMPULSE_FUSE := 0.4         # seconds after an Impulse Grenade sticks before it goes off
const IMPULSE_FLIGHT := 2.5       # it goes off in mid-air after this long if it hits nothing
const IMPULSE_RADIUS := 4.0       # blocks it pushes things within
const IMPULSE_PUSH := 13.0       # speed it throws a rat at, right beside it (half at the edge)
const IMPULSE_LIFT := 8.0        # extra upward speed, scaled the same way
const IMPULSE_MAX_UP := 14.0     # but never faster upward than this (about 4 blocks of height)
const IMPULSE_CARRY := 0.6        # a rat hauling cheese is heavier: pushed this much as hard
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
	"sfx_volume": 0.9,
	"window_mode": "fullscreen",     # windowed | fullscreen (borderless) | exclusive
	"vsync": true,
	"max_fps": 0,                    # 0 = no cap
	"render_scale": 1.0,             # 3D resolution, 0.5..1.0 (the HUD stays sharp)
	"camera_distance": 4.0,
	"goal": 8,
	"team_size": 2,
	"bot_skill": 1,
	"last_class": "digger",
	"last_team": 0,
	"player_name": "",
	"last_address": "",
	"host_lobby": true,
}

const WINDOW_MODES := ["windowed", "fullscreen", "exclusive"]
const FPS_CAPS := [0, 30, 60, 90, 120, 144, 165, 240]
const AUDIO_BUSES := ["Music", "SFX"]

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		Log.warn("settings.cfg unreadable (error %d); using defaults" % err)
		_cfg = ConfigFile.new()
	apply_audio()
	apply_display()


func _input(event: InputEvent) -> void:
	# Alt+Enter or F11: fullscreen <-> window, remembered like the setting
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not display_supported():
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		get_viewport().set_input_as_handled()
		set_value("window_mode", "windowed" if String(get_value("window_mode")) != "windowed" else "fullscreen")
		save()
		apply_display()


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
	## Master, Music and SFX buses (Sfx routes its players to the last two).
	for bus: String in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	_set_bus("Master", float(get_value("master_volume")))
	_set_bus("Music", float(get_value("music_volume")))
	_set_bus("SFX", float(get_value("sfx_volume")))


static func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)


static func display_supported() -> bool:
	## Window mode and v-sync are the platform's business on the web and
	## meaningless headless.
	return DisplayServer.get_name() != "headless" and not OS.has_feature("web")


func apply_display() -> void:
	Engine.max_fps = maxi(0, int(get_value("max_fps")))
	if is_inside_tree():
		get_tree().root.scaling_3d_scale = clampf(float(get_value("render_scale")), 0.5, 1.0)
	if not display_supported():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
	var mode := String(get_value("window_mode"))
	var want := DisplayServer.WINDOW_MODE_WINDOWED
	if mode == "fullscreen":
		want = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif mode == "exclusive":
		want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() == want:
		return
	DisplayServer.window_set_mode(want)
	if want == DisplayServer.WINDOW_MODE_WINDOWED:
		# back to a window: a comfortable size, centred on the screen it's on
		var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var size := Vector2i(1280, 720) if screen.size.x < 2400 else Vector2i(1920, 1080)
		size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
