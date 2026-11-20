class_name DedicatedServer
extends Node
## A headless, always-on server anyone can join: no local player, teams
## filled with bots, joining players take a bot's seat, and a new round on a
## new map starts shortly after each win. Run it with
##
##   godot --headless --path . -- --server [--port 24565] [--name "My Server"]
##         [--goal 10] [--team-size 4] [--skill 1] [--free] [--round-break 15]
##         [--lobby 30]                  (seconds in the playground before each round; 0 = none)
##         [--map path/to/saved.bwmap]   (every round then starts on that map)
##         [--transport ws]              (WebSocket on TCP instead of ENet on UDP:
##                                        what browsers need; desktop players can join too)
##         [--tls-cert cert.pem --tls-key key.pem]   (serve wss:// directly; or put
##                                        the server behind a proxy such as Caddy instead)
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
			if key in ["server", "free"]:
				out[key] = true
			elif key in ["port", "name", "goal", "team-size", "skill", "seed", "round-break", "lobby", "map",
					"transport", "tls-cert", "tls-key"] and i + 1 < args.size():
				out[key] = args[i + 1]
				i += 1
		i += 1
	if OS.has_feature("dedicated_server"):
		out["server"] = true
	return out


func _ready() -> void:
	var port := int(options.get("port", Net.DEFAULT_PORT))
	var err := Net.host(port, {"transport": String(options.get("transport", "enet")),
		"tls_cert": String(options.get("tls-cert", "")), "tls_key": String(options.get("tls-key", ""))})
	if err != "":
		Log.warn("dedicated server: " + err)
		get_tree().quit(1)
		return
	var ws := Net.transport == Net.Transport.WEBSOCKET
	Log.info("dedicated server '%s' listening on %s %d%s" % [_server_name(), "TCP (WebSocket)" if ws else "UDP", port,
		" with TLS (wss://)" if ws and String(options.get("tls-cert", "")) != "" else ""])
	_next()


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
	m.lobby_left = _lobby_time()
	Log.info("lobby: the next round starts %d s after someone is here" % int(m.lobby_left))


func _server_name() -> String:
	var n := Net.clean_name(options.get("name", ""))
	return n if n != "" else "Burrow Wars server"


func _settings() -> Dictionary:
	var free := bool(options.get("free", false))
	var skill := clampi(int(options.get("skill", 1)), 0, 2)
	var seed_value := int(options.get("seed", 0))
	return {
		"mode": "free" if free else "race",
		"seed": seed_value if seed_value > 0 else randi_range(1, 999999),
		"goal": 9999 if free else clampi(int(options.get("goal", 10)), 1, 250),
		"map_file": String(options.get("map", "")),
		"team_size": clampi(int(options.get("team-size", 4)), 1, 8),
		"bot_rest": [7.0, 3.0, 0.0][skill],
		"server_name": _server_name(),
	}


func _new_round() -> void:
	var s := _settings()
	_start(s)
	if not m.free_mode:
		var size := int(s["team_size"])
		for i in size * 2:
			m.spawn_rat(i % 2, ClassDefs.ORDER[(i / 2) % 4], true)
	Log.info("new round: seed %d, goal %d, %d players connected" % [int(s["seed"]), int(s["goal"]), Net.hellos.size()])


func _start(s: Dictionary) -> void:
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
		Log.info("round won by %s; next map in %d s" % [Match.TEAM_NAMES[team], int(_restart_in)]))
	net = NetServer.new()
	net.name = "NetServer"
	net.m = m
	add_child(net)


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
		if _restart_in <= 0.0:
			_next()
	_status_t += delta
	if _status_t >= 60.0:
		_status_t = 0.0
		Log.info("status: %d players, score %d-%d, t=%ds" % [net.player_count(), m.scores[0], m.scores[1], int(m.time)])
