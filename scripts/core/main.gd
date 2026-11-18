extends Node
## Application root: owns scene transitions between the menu and a session,
## and between rounds of an online game. Started with `-- --server` it runs a
## headless dedicated server instead (see DedicatedServer).

var menu: MainMenu
var session: GameSession
var dedicated: DedicatedServer
var _last_settings: Dictionary = {}
var _pending: Dictionary = {}    # the match a hosted lobby is waiting to start


func _ready() -> void:
	Log.info("Burrow Wars: Jam Edition %s on Godot %s" % [
		ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"]])
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_net_problem)
	Net.disconnected.connect(_on_net_problem)
	var args := DedicatedServer.parse_args()
	if args.has("server"):
		dedicated = DedicatedServer.new()
		dedicated.options = args
		add_child(dedicated)
		return
	Sfx.play_music("res://assets/music/clockwork_colony.wav")
	show_menu()


func show_menu(message := "") -> void:
	_clear()
	if Net.is_online():
		Net.close()
	menu = MainMenu.new()
	menu.start_requested.connect(start_match)
	add_child(menu)
	if message != "":
		menu.show_message(message)


func start_match(settings: Dictionary) -> void:
	if String(settings.get("net", "")) == "host" and Net.role != Net.Role.SERVER:
		var err := Net.host(int(settings.get("port", Net.DEFAULT_PORT)))
		if err != "":
			show_menu(err)
			return
	_last_settings = settings
	if String(settings.get("net", "")) == "host" and bool(settings.get("lobby", false)):
		# everyone gathers in the playground until the host starts the match
		_pending = settings
		_launch(Match.lobby_settings(settings))
	else:
		_pending = {}
		_launch(settings)


func _launch(settings: Dictionary) -> void:
	_clear()
	session = GameSession.new()
	session.settings = settings
	session.exit_requested.connect(show_menu.bind(""), CONNECT_DEFERRED)
	session.rematch_requested.connect(_rematch, CONNECT_DEFERRED)
	session.start_requested.connect(_start_pending, CONNECT_DEFERRED)
	add_child(session)


func _start_pending() -> void:
	## The host pressed start in the lobby: the real match begins for everyone.
	if _pending.is_empty():
		return
	var s := _pending
	_pending = {}
	_launch(s)


func _on_joined(info: Dictionary) -> void:
	## The server seated us: a fresh session for the first round and every round after.
	var s: Dictionary = (info.get("settings", {}) as Dictionary).duplicate()
	s["net"] = "client"
	_clear()
	session = GameSession.new()
	session.settings = s
	session.net_info = info
	session.exit_requested.connect(show_menu.bind(""), CONNECT_DEFERRED)
	add_child(session)


func _on_net_problem(reason: String) -> void:
	if dedicated != null:
		return
	show_menu(reason)


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
