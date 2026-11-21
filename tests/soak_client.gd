extends Node
## Soak test player: joins a server, plays like a busy (honest) player -
## walks, turns, jumps, digs, places, bonks - for a random while, leaves,
## waits, and joins again, until BW_SOAK_SECONDS have passed. Run several at
## once against one server (tools/soak_test.sh does). Everything goes through
## the real game: the menu-less join, the replica match, the network.
##   BW_URL=ws://127.0.0.1:24580 BW_SOAK_ID=1 BW_SOAK_SECONDS=1800 \
##     godot --headless --path . res://tests/soak_client.tscn
## Prints a "soak:" line per session and a final summary; exit code 1 if the
## server ever removed it, refused it, or the game hit a script error.

var main: Node
var _id := 1
var _url := ""
var _rng := RandomNumberGenerator.new()
var _stats := {"sessions": 0, "join_fail": 0, "lost": 0, "removed": 0, "refused": 0, "digs": 0, "places": 0,
	"bonks": 0, "corrections": 0}
var _last_reason := ""


func _ready() -> void:
	_id = OS.get_environment("BW_SOAK_ID").to_int() if OS.get_environment("BW_SOAK_ID").is_valid_int() else 1
	_url = OS.get_environment("BW_URL")
	_rng.seed = 1000 + _id
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Net.join_failed.connect(func(reason: String) -> void:
		_last_reason = reason
		if reason.begins_with("Removed by the server"):
			_stats["removed"] += 1
		elif not reason.begins_with("Could not reach"):
			_stats["refused"] += 1)
	Net.disconnected.connect(func(reason: String) -> void:
		_last_reason = reason
		_stats["lost"] += 1)
	_run.call_deferred()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func session() -> GameSession:
	var s: GameSession = main.session
	return s if s != null and is_instance_valid(s) and s.m != null and s.player != null else null


func _run() -> void:
	var total := float(OS.get_environment("BW_SOAK_SECONDS")) if OS.get_environment("BW_SOAK_SECONDS").is_valid_float() else 600.0
	var t0 := Time.get_ticks_msec()
	await wait(_rng.randf_range(0.5, 6.0))   # don't all arrive at once
	while (Time.get_ticks_msec() - t0) / 1000.0 < total:
		var stay := _rng.randf_range(30.0, 150.0)
		if await _join():
			_stats["sessions"] += 1
			await _play(minf(stay, total - (Time.get_ticks_msec() - t0) / 1000.0))
			_report("left")
			main.show_menu()   # leave, as the pause menu's Quit to menu does
		else:
			_stats["join_fail"] += 1
			_report("join failed (%s)" % _last_reason)
		await wait(_rng.randf_range(3.0, 15.0))
	var bad := int(_stats["removed"]) + int(_stats["refused"])
	print("soak-summary: client %d %s %s" % [_id, "OK" if bad == 0 else "PROBLEMS", JSON.stringify(_stats)])
	get_tree().quit(1 if bad > 0 else 0)


func _join() -> bool:
	_last_reason = ""
	Net.join(_url, 0, {"name": "Soak%d" % _id, "team": _id % 2, "class": ClassDefs.ORDER[_id % 4]})
	var t := 0.0
	while t < 60.0:
		var s := session()
		if s != null and s.loaded:
			return true
		if _last_reason != "":
			return false
		await wait(0.25)
		t += 0.25
	return false


func _play(seconds: float) -> void:
	var t := 0.0
	var seen: GameSession = null
	var kick_was := 0
	while t < seconds:
		var s := session()
		if s == null:
			return   # dropped (counted by the signals)
		var me := s.player
		# the server moved us (bonks, blasts, respawns, or a failed check); a new round starts a new count
		if s.net is NetClient:
			var k := (s.net as NetClient)._kick
			if s == seen:
				_stats["corrections"] += maxi(0, k - kick_was)
			seen = s
			kick_was = k
		var ctl := s.ctl
		var roll := _rng.randf()
		# wander: turn now and then, walk most of the time
		if roll < 0.25:
			ctl.yaw += _rng.randf_range(-1.2, 1.2)
		ctl.pitch = clampf(ctl.pitch + _rng.randf_range(-0.3, 0.3), -0.9, 0.4)
		if _rng.randf() < 0.75:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		if _rng.randf() < 0.15:
			me.jump_pressed = true
		if _rng.randf() < 0.05:
			me.dash_pressed = true
		# dig what we look at; sometimes build
		if not ctl.aim.is_empty() and ctl.aim.has("cell"):
			if _rng.randf() < 0.6:
				me.dig_cd = 0.0
				s.m.try_dig(me, ctl.aim["cell"])
				_stats["digs"] += 1
			elif _rng.randf() < 0.3 and int(me.mats.get("dirt", 0)) > 0:
				var c: Vector3i = Vector3i(ctl.aim["cell"]) + Vector3i(ctl.aim.get("normal", Vector3i.UP))
				s.m.try_place_mat(me, c, "dirt")
				_stats["places"] += 1
		# bonk anyone close
		for r in s.m.rats:
			if r != me and r.team != me.team and r.center().distance_to(me.center()) < Config.BONK_RANGE:
				s.m.try_bonk(me, r)
				_stats["bonks"] += 1
				break
		await wait(0.25)
		t += 0.25
	Input.action_release("move_forward")


func _report(what: String) -> void:
	print("soak: client %d session %d %s - mem %.1f MB, objects %d, nodes %d, orphans %d" % [
		_id, int(_stats["sessions"]), what, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
