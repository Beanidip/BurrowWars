extends Node
## Application root: owns scene transitions between the menu and a session.

var menu: MainMenu
var session: GameSession
var _last_settings: Dictionary = {}


func _ready() -> void:
	Log.info("Burrow Wars: Jam Edition %s on Godot %s" % [
		ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"]])
	Sfx.play_music("res://assets/music/clockwork_colony.wav")
	show_menu()


func show_menu() -> void:
	_clear()
	menu = MainMenu.new()
	menu.start_requested.connect(start_match)
	add_child(menu)


func start_match(settings: Dictionary) -> void:
	_clear()
	_last_settings = settings
	session = GameSession.new()
	session.settings = settings
	session.exit_requested.connect(show_menu, CONNECT_DEFERRED)
	session.rematch_requested.connect(_rematch, CONNECT_DEFERRED)
	add_child(session)


func _rematch() -> void:
	var s := _last_settings.duplicate()
	s["seed"] = randi_range(1, 999999)
	start_match(s)


func _clear() -> void:
	get_tree().paused = false
	if menu != null:
		menu.queue_free()
		menu = null
	if session != null:
		session.queue_free()
		session = null
