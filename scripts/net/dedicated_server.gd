class_name DedicatedServer
extends Node
## A headless, always-on server anyone can join: no local player, teams
## filled with bots, joining players take a bot's seat, and a new round on a
## new map starts shortly after each win. Run it with
##
##   godot --headless --path . -- --server [--port 24565] [--name "My Server"]
##         [--goal 10] [--team-size 4] [--skill 1] [--free] [--round-break 15]
##         [--mode scrap]                (Scrap Race: --goal is then the scrap goal; default 300)
##         [--mutators meteors]          (match options, comma-separated: see Mutators.LIST)
##         [--lobby 30]                  (seconds in the playground before each round; 0 = none)
##         [--map path/to/saved.bwmap]   (every round then starts on that map)
##         [--transport ws]              (WebSocket on TCP instead of ENet on UDP:
##                                        what browsers need; desktop players can join too)
##         [--tls-cert cert.pem --tls-key key.pem]   (serve wss:// directly; or put
##                                        the server behind a proxy such as Caddy instead)
##         [--status-port N]             (HTTP /status for the server list; default port + 1)
##         [--no-status]                 (no status page)
##         [--log-every S]               (seconds between health lines in the log; default 60)
##
## or, from an exported build:  BurrowWars.exe --headless -- --server
## See docs/MULTIPLAYER.md for running a public server.

const ROUND_BREAK := 15.0      # default seconds between a win and the next map
const LOBBY_TIME := 30.0       # default seconds in the playground before each round

var options: Dictionary = {}
var m: Match
var net: NetServer
var _restart_in := -1.0
var _status_t := 0.0
var status_page: StatusServer
var _started := 0
var rounds := 0                  # rounds started since the server came up
var _frames0 := 0                # physics frames at the last health line
var _warm_task := -1             # the next round's map, being generated on a worker thread
var _next_seed := 0


static func parse_args() -> Dictionary:
	## Reads `--key value` / `--flag` pairs after `--` (and, for convenience,
	## before it too).
	var out := {}
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--") and a.length() > 2:
			var key := a.substr(2)
			if key in ["server", "free", "no-status"]:
				out[key] = true
			elif key in ["mode", "mutators", "port", "name", "goal", "team-size", "skill", "seed", "round-break", "lobby", "map",
					"transport", "tls-cert", "tls-key", "status-port", "log-every"] and i + 1 < args.size():
				out[key] = args[i + 1]
				i += 1
		i += 1
	if OS.has_feature("dedicated_server"):
		out["server"] = true
	return out


func _ready() -> void:
	var port := int(options.get("port", Net.DEFAULT_PORT))
	var err := Net.host(port, {"transport": String(options.get("transport", "enet")), "max_clients": Net.MAX_CLIENTS,
		"tls_cert": String(options.get("tls-cert", "")), "tls_key": String(options.get("tls-key", ""))})
	if err != "":
		Log.warn("dedicated server: " + err)
		get_tree().quit(1)
		return
	var ws := Net.transport == Net.Transport.WEBSOCKET
	Log.info("dedicated server '%s' listening on %s %d%s" % [_server_name(), "TCP (WebSocket)" if ws else "UDP", port,
		" with TLS (wss://)" if ws and String(options.get("tls-cert", "")) != "" else ""])
	_started = Time.get_ticks_msec()
	if not bool(options.get("no-status", false)):
		var status_port := int(options.get("status-port", port + 1))
		status_page = StatusServer.new()
		status_page.name = "StatusPage"
		status_page.provider = status
		add_child(status_page)
		var serr := status_page.listen(status_port)
		if serr != "":
			Log.warn("dedicated server: %s; the server list won't show live status" % serr)
		else:
			Log.info("status page: http://<this machine>:%d/status" % status_port)
	_next()


func status() -> Dictionary:
	## What the server list shows (StatusServer serves it as JSON).
	var humans := net.player_count() if net != null else 0
	var st := {
		"game": "Burrow Wars",
		"name": _server_name(),
		"version": Net.game_version(),
		"protocol": Net.PROTOCOL,
		"transport": "ws" if Net.transport == Net.Transport.WEBSOCKET else "enet",
		"players": humans,
		"max_players": Net.MAX_CLIENTS,
		"uptime": (Time.get_ticks_msec() - _started) / 1000,
	}
	if m != null:
		st["mode"] = "lobby" if m.lobby else ("free" if m.free_mode else ("scrap" if m.scrap_race else "race"))
		st["rats"] = m.rats.size()
		st["team_size"] = int(m.settings.get("team_size", 0))
		st["goal"] = int(m.settings.get("goal", 0))
		st["score"] = [m.scores[0], m.scores[1]]
		st["mutators"] = m.mutators
		st["time"] = int(m.time)
	return st


func _lobby_time() -> float:
	if bool(options.get("free", false)):
		return 0.0     # Free Build is a sandbox already
	return clampf(float(options.get("lobby", LOBBY_TIME)), 0.0, 600.0)


func _next() -> void:
	## Between rounds: the playground (if there is one), else straight to a new map.
	if _lobby_time() > 0.0:
		_new_lobby()
	else:
		_new_round()


func _new_lobby() -> void:
	_start(Match.lobby_settings({"server_name": _server_name()}))
	_prepare_next()   # while everyone plays in the playground
	m.lobby_left = _lobby_time()
	Log.info("lobby: the next round starts %d s after someone is here" % int(m.lobby_left))


func _server_name() -> String:
	var n := Net.clean_name(options.get("name", ""))
	return n if n != "" else "Burrow Wars server"


func _mode() -> String:
	if bool(options.get("free", false)):
		return "free"
	return "scrap" if String(options.get("mode", "race")) == "scrap" else "race"


func _goal() -> int:
	match _mode():
		"free":
			return 9999
		"scrap":
			return clampi(int(options.get("goal", Config.SCRAP_GOAL)), 10, 100000)
	return clampi(int(options.get("goal", 10)), 1, 250)


func _prepare_next() -> void:
	## Generate the next round's map on a worker thread while players wait
	## (results, then the playground): building one takes over a second, and
	## doing it when the round starts froze the whole server meanwhile.
	if _warm_task != -1 or String(options.get("map", "")) != "":
		return
	_next_seed = randi_range(1, 999999)
	var need := Match.cheese_needed({"mode": _mode(), "goal": _goal()})
	_warm_task = WorkerThreadPool.add_task(MapGenerator.warm.bind(_next_seed, need), true, "next map")


func _exit_tree() -> void:
	if _warm_task != -1:
		WorkerThreadPool.wait_for_task_completion(_warm_task)
		_warm_task = -1


func _settings() -> Dictionary:
	var skill := clampi(int(options.get("skill", 1)), 0, 2)
	var seed_value := int(options.get("seed", 0)) if rounds == 0 else 0   # --seed fixes the first map only
	if seed_value <= 0 and _next_seed > 0:
		seed_value = _next_seed   # the one generated in the background
	_next_seed = 0
	return {
		"mode": _mode(),
		"mutators": Mutators.clean(String(options.get("mutators", "")).split(",", false)),
		"seed": seed_value if seed_value > 0 else randi_range(1, 999999),
		"goal": _goal(),
		"map_file": String(options.get("map", "")),
		"team_size": clampi(int(options.get("team-size", 4)), 1, 16),
		"bot_rest": [7.0, 3.0, 0.0][skill],
		"server_name": _server_name(),
	}


func _new_round() -> void:
	if _warm_task != -1:
		WorkerThreadPool.wait_for_task_completion(_warm_task)   # (normally finished long ago)
		_warm_task = -1
	var s := _settings()
	_start(s)
	rounds += 1
	if not m.free_mode:
		var size := int(s["team_size"])
		for i in size * 2:
			m.spawn_rat(i % 2, ClassDefs.ORDER[(i / 2) % 4], true)
	Log.info("new round: seed %d, goal %d, %d players connected" % [int(s["seed"]), int(s["goal"]), Net.hellos.size()])


func _start(s: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	if net != null:
		net.queue_free()
	if m != null:
		m.queue_free()
	_restart_in = -1.0
	m = Match.new()
	m.name = "Match"
	add_child(m)
	m.setup(s, false)
	m.won.connect(func(team: int) -> void:
		_restart_in = clampf(float(options.get("round-break", ROUND_BREAK)), 1.0, 300.0)
		_prepare_next()
		Log.info("round won by %s; next map in %d s" % [Match.TEAM_NAMES[team], int(_restart_in)]))
	net = NetServer.new()
	net.name = "NetServer"
	net.m = m
	net.ac.kick_out = true   # a public server removes players who keep failing the movement checks
	net.max_players = Net.MAX_CLIENTS
	add_child(net)
	Log.info("built %s in %d ms" % ["the playground" if m.lobby else "a new map", Time.get_ticks_msec() - t0])


func _process(delta: float) -> void:
	if m == null:
		return
	# nobody connected: hold the world still instead of letting bots play alone
	m.auto_step = net.player_count() > 0
	if m.lobby and net.player_count() > 0:
		m.lobby_left -= delta
		if m.lobby_left <= 0.0:
			_new_round()
			return
	if _restart_in >= 0.0:
		_restart_in -= delta
		net.next_in = maxf(0.0, _restart_in)
		if _restart_in <= 0.0:
			_next()
	_status_t += delta
	if _status_t >= clampf(float(options.get("log-every", 60.0)), 5.0, 3600.0):
		Log.info(health_line(_status_t))
		_status_t = 0.0


func health_line(seconds: float) -> String:
	## One line for the log: who's here and how the server is doing. Memory,
	## objects and nodes that keep climbing over hours mean a leak; orphan
	## nodes are nodes nobody freed. sim / net are the match's and the
	## network's time per tick (60 ticks a second: together they must stay
	## well under 16.7 ms); tps is the ticks actually run per second.
	var bots := 0
	for r in m.rats:
		bots += 1 if r.is_bot else 0
	var frames := Engine.get_physics_frames()
	var tps := float(frames - _frames0) / maxf(0.001, seconds)
	_frames0 = frames
	var sim: Array = m.perf
	var nt: Array = net.perf if net != null else [0, 0, 0]
	var line := "health: %d players, %d bots, round %d (%s, %d-%d, t=%ds), mem %.1f MB, objects %d, nodes %d, orphans %d, sim %.2f ms avg / %.1f max, net %.2f ms avg / %.1f max, tps %.1f" % [
		net.player_count(), bots, rounds, "lobby" if m.lobby else ("free" if m.free_mode else ("scrap" if m.scrap_race else "race")), m.scores[0], m.scores[1],
		int(m.time), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		float(sim[0]) / 1000.0 / maxf(1.0, float(sim[2])), float(sim[1]) / 1000.0,
		float(nt[0]) / 1000.0 / maxf(1.0, float(nt[2])), float(nt[1]) / 1000.0, tps]
	m.perf = [0, 0, 0]
	if net != null:
		net.perf = [0, 0, 0]
		var n: Dictionary = net.inputs
		line += ", reports %d ok / %d stale / %d after a server move / %d dropped / %d refused" % [n["ok"], n["stale"], n["moved"], n["dropped"], n["bad"]]
		net.inputs = {"ok": 0, "dropped": 0, "stale": 0, "moved": 0, "bad": 0}
	return line
