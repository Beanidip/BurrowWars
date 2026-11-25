extends Node
## Application root: owns scene transitions between the menu and a session,
## and between rounds of an online game. Started with `-- --server` it runs a
## headless dedicated server instead (see DedicatedServer).

var menu: MainMenu
var session: GameSession
var dedicated: DedicatedServer
var _last_settings: Dictionary = {}
var _pending: Dictionary = {}    # the match a hosted lobby is waiting to start
var _cover: LoadingScreen        # the loading screen while a session is being built
var _launches := 0               # a newer launch supersedes one still loading


func _ready() -> void:
	Log.info("Burrow Wars %s on Godot %s" % [
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
	show_menu()


func _exit_tree() -> void:
	# The game is closing: let go of the shared texture and map caches, so the
	# engine shuts down cleanly instead of reporting them as leaked.
	RatSprite.clear_caches()
	Icons.clear_cache()
	FxSprite.clear_cache()
	BlockTextures.clear_cache()
	UiKit.clear_cache()
	MapGenerator.clear_cache()


func show_menu(message := "") -> void:
	_clear()
	if Net.is_online():
		Net.close()
	Sfx.title_theme()
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
	## Put up the loading screen, generate the map on a worker thread (so the
	## cheese keeps spinning), then build the session behind the screen.
	_clear()
	Sfx.game_music()   # (from the loading screen on)
	var me := _launches
	var cover := _show_cover()
	await get_tree().process_frame
	await get_tree().process_frame
	await _warm_map(settings, cover)
	if me != _launches:
		return                # something newer started (or we went back to the menu) meanwhile
	session = GameSession.new()
	session.settings = settings
	session.loading = cover
	session.exit_requested.connect(show_menu.bind(""), CONNECT_DEFERRED)
	session.rematch_requested.connect(_rematch, CONNECT_DEFERRED)
	session.start_requested.connect(_start_pending, CONNECT_DEFERRED)
	add_child(session)
	_cover = null             # the session owns it now and lifts it when the world is ready


func _show_cover() -> LoadingScreen:
	var cover := LoadingScreen.new()
	add_child(cover)
	_cover = cover
	return cover


func _warm_map(settings: Dictionary, cover: LoadingScreen) -> void:
	## A generated map is made on a worker thread into the generator's cache.
	var mode := String(settings.get("mode", "race"))
	if mode == "lobby" or String(settings.get("net", "")) == "client" or String(settings.get("map_file", "")) != "":
		return
	var need := Match.cheese_needed(settings)
	var task := WorkerThreadPool.add_task(MapGenerator.warm.bind(int(settings.get("seed", 1)), need), true)
	var t := 0.0
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
		t += get_process_delta_time()
		if is_instance_valid(cover):
			cover.progress = 0.3 * (1.0 - exp(-t * 1.5))
	WorkerThreadPool.wait_for_task_completion(task)


func _start_pending() -> void:
	## The host pressed start in the lobby: the real match begins for everyone.
	if _pending.is_empty():
		return
	var s := _pending
	_pending = {}
	if session != null and is_instance_valid(session) and session.m != null and session.m.lobby:
		s["infinite"] = session.m.infinite_next   # the cheat code typed in the playground
		_last_settings["infinite"] = s["infinite"]  # (and the next lobby remembers it)
	_launch(s)


func _on_joined(info: Dictionary) -> void:
	## The server seated us: a fresh session for the first round and every round after.
	var s: Dictionary = (info.get("settings", {}) as Dictionary).duplicate()
	s["net"] = "client"
	_clear()
	Sfx.game_music()
	session = GameSession.new()
	session.settings = s
	session.net_info = info
	session.loading = _show_cover()
	_cover = null
	session.exit_requested.connect(show_menu.bind(""), CONNECT_DEFERRED)
	add_child(session)


func _on_net_problem(reason: String) -> void:
	if dedicated != null:
		return
	show_menu(reason)


func _rematch(to_lobby := false) -> void:
	## The results screen: the next game on a new map, or (an online host)
	## everyone back to the playground first. Players stay connected either way.
	var s := _last_settings.duplicate()
	s["seed"] = randi_range(1, 999999)
	if String(s.get("net", "")) == "host":
		s["lobby"] = to_lobby
	start_match(s)


func _clear() -> void:
	_launches += 1           # any launch still loading is now out of date
	get_tree().paused = false
	if menu != null:
		menu.queue_free()
		menu = null
	if session != null:
		if session.loading != null and is_instance_valid(session.loading):
			session.loading.queue_free()
		session.queue_free()
		session = null
	if _cover != null and is_instance_valid(_cover):
		_cover.queue_free()
	_cover = null
