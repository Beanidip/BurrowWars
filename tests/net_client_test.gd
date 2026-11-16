extends Node
## End-to-end network test, the client half. Needs a dedicated server running:
##   godot --headless --path . -- --server --port 24599 --seed 777 --goal 3 --team-size 2
##   BW_PORT=24599 godot --headless --path . res://tests/net_client_test.tscn
## tools/check.sh starts both. Exit code 0 = every check passed.
## Drives the real application (main.tscn): join from the menu flow, play
## through the replica Match, and verify the server's answers come back.

var _fails := 0
var main: Node
var _notices: Array[String] = []


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func wait_for(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await wait(0.05)
		t += 0.05
	return bool(cond.call())


func port() -> int:
	var p := OS.get_environment("BW_PORT")
	return p.to_int() if p.is_valid_int() else 24599


func join_server() -> GameSession:
	for attempt in 20:
		var failed := [false]
		var on_fail := func(_r: String) -> void: failed[0] = true
		Net.join_failed.connect(on_fail)
		Net.join("127.0.0.1", port(), {"name": "Tester", "team": 1, "class": "digger"})
		await wait_for(func() -> bool: return failed[0] or (main.session != null and is_instance_valid(main.session) and main.session.m != null), 6.0)
		Net.join_failed.disconnect(on_fail)
		if main.session != null and is_instance_valid(main.session) and main.session.player != null:
			return main.session
		await wait(0.5)
	return null


func _run() -> void:
	if OS.get_environment("BW_NET_TEST") == "round":
		await _run_round()
		return
	var s := await join_server()
	check(s != null, "joined the dedicated server and got a session")
	if s == null:
		get_tree().quit(1)
		return
	var m := s.m
	var me := s.player
	s.net.notice.connect(func(t: String) -> void: _notices.append(t))
	check(m.replica and m.remote != null, "the client runs a replica Match that forwards requests")
	check(me.display_name == "Tester" and me.team == 1 and not me.is_bot, "seated on the requested team under our name")
	check(m.rats.size() == 4, "the server's 2v2 rats are all present (%d)" % m.rats.size())
	var bots := 0
	for r in m.rats:
		if r.is_bot:
			bots += 1
	var want_bots := 3 if OS.get_environment("BW_EXPECT_BOTS") == "" else OS.get_environment("BW_EXPECT_BOTS").to_int()
	check(bots == want_bots, "the other seats are bots (%d, expected %d)" % [bots, want_bots])
	var ref := VoxelWorld.new()
	ref.visual = false
	MapGenerator.generate(ref, int(m.settings["seed"]))
	if OS.get_environment("BW_EXPECT_BOTS") == "":
		check(m.world.data == ref.data, "the world snapshot matches the seed's map")
	else:
		# a hosted game was already being played (bots dig) before we joined
		var diff := 0
		for i in m.world.data.size():
			if m.world.data[i] != ref.data[i]:
				diff += 1
		check(diff > 0 and diff < 2000, "the world snapshot is the seed's map plus the host's digging (%d cells changed)" % diff)
	ref.free()

	# the server steps the match once a player is in: bots move
	var before := {}
	for r in m.rats:
		before[r.id] = r.position
	await wait(3.0)
	var moved := 0
	for r in m.rats:
		if r != me and r.position.distance_to(before[r.id]) > 1.0:
			moved += 1
	check(moved >= 1, "other rats move on our screen (%d of 3)" % moved)

	# cheating is corrected: a 30-block teleport is put back by the server
	await wait_for(func() -> bool: return me.on_floor, 3.0)
	var home := me.position
	me.position += Vector3(0, 0, 30)
	var corrected := await wait_for(func() -> bool: return me.position.distance_to(home) < 3.0, 3.0)
	check(corrected, "an impossible jump is snapped back by the authority")

	# walk out of the base toward the middle of the map
	var start := me.position
	var to_mid := Vector3(VoxelWorld.SX * 0.5, start.y, VoxelWorld.SZ * 0.5) - start
	s.ctl.yaw = atan2(-to_mid.x, -to_mid.z)
	Input.action_press("move_forward")
	await wait(2.0)
	Input.action_release("move_forward")
	await wait(0.4)
	check(me.position.distance_to(start) > 4.0, "our rat walks locally (%.1f blocks)" % me.position.distance_to(start))

	# dig a block the server can only reach if it accepted our movement
	var target := Vector3i(-1, -1, -1)
	var eye := me.eye()
	var best := 99.0
	for dx in range(-3, 4):
		for dy in range(-2, 3):
			for dz in range(-3, 4):
				var c := Vector3i(floori(eye.x) + dx, floori(eye.y) + dy, floori(eye.z) + dz)
				var id := m.world.get_cell(c)
				if id != Blocks.DIRT and id != Blocks.GRASS:
					continue
				var d := (Vector3(c) + Vector3(0.5, 0.5, 0.5)).distance_to(eye)
				var from_start := (Vector3(c) + Vector3(0.5, 0.5, 0.5)).distance_to(start + Vector3(0, 0.7, 0))
				if d < 3.2 and from_start > Config.DIG_REACH + 1.2 and d < best:
					best = d
					target = c
	check(target.x >= 0, "found dirt next to us that is out of reach from the spawn")
	if target.x >= 0:
		var dirt_before := int(me.mats["dirt"])
		var dug := false
		for i in 120:
			if me.dig_cd <= 0.0:
				m.try_dig(me, target)
			await wait(0.05)
			if m.world.get_cell(target) == Blocks.AIR:
				dug = true
				break
		check(dug, "digging through the server removes the block on our screen")
		await wait_for(func() -> bool: return int(me.mats["dirt"]) > dirt_before, 2.0)
		check(int(me.mats["dirt"]) > dirt_before, "the dug dirt arrives in our stash (%d -> %d)" % [dirt_before, int(me.mats["dirt"])])
		check(m.try_place_mat(me, target, "dirt") == "", "placing is forwarded")
		var placed := await wait_for(func() -> bool: return m.world.get_cell(target) == Blocks.DIRT, 2.0)
		check(placed, "the placed block appears")
	m.try_place_mat(me, Vector3i(2, 30, 2), "dirt")
	var refused := await wait_for(func() -> bool: return _notices.size() > 0, 2.0)
	check(refused and _notices[-1] == "Too far", "a refused request comes back as a notice (%s)" % str(_notices))

	# authority-side moves reach us: Ctrl+K respawn puts us back in base
	m.respawn(me)
	var home_again := await wait_for(func() -> bool: return m.in_base(me), 3.0)
	check(home_again, "a server-side respawn moves our rat home")

	# leave and come back: a bot held the seat, nobody duplicated
	Net.close()
	main.show_menu()
	await wait(1.0)
	s = await join_server()
	check(s != null, "rejoined")
	if s != null:
		check(s.m.rats.size() == 4, "rejoining reuses a seat instead of adding a rat (%d)" % s.m.rats.size())
		check(s.player.display_name == "Tester", "and keeps our name")
	Net.close()
	print("---- net: %d failed ----" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _run_round() -> void:
	## Dedicated server with a 1-cheese goal: when a team wins, the server
	## starts a new map and carries every connected player into it.
	var s := await join_server()
	check(s != null, "joined")
	if s == null:
		get_tree().quit(1)
		return
	var first_seed := int(s.m.settings["seed"])
	var won := await wait_for(func() -> bool: return is_instance_valid(s) and s.m.over, 120.0)
	check(won, "the round ends with a winner on our screen")
	var next := await wait_for(func() -> bool: return main.session != null and is_instance_valid(main.session) \
			and main.session != s and main.session.player != null, 40.0)
	check(next, "the server moves us into the next round")
	if next:
		var s2: GameSession = main.session
		check(int(s2.m.settings["seed"]) != first_seed, "on a new map (seed %d -> %d)" % [first_seed, int(s2.m.settings["seed"])])
		check(s2.player.display_name == "Tester" and not s2.m.over and s2.m.scores == [0, 0], "fresh scores, same player")
	Net.close()
	print("---- net round: %d failed ----" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
