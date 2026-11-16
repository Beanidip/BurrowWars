extends Node
## End-to-end network test, the hosting half: the real app hosts a Cheese Race
## from the menu flow (a player's game acting as the server) and waits for
## tests/net_client_test.tscn to join, walk and leave. See tools/net_check.sh.

var _fails := 0
var main: Node


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func wait_for(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(0.1, true, true).timeout
		t += 0.1
	return bool(cond.call())


func _run() -> void:
	var port := OS.get_environment("BW_PORT").to_int() if OS.get_environment("BW_PORT").is_valid_int() else 24598
	Net.player_name = "Hosty"
	main.start_match({"mode": "race", "seed": 777, "goal": 3, "team": 0, "class": "scout", "team_size": 2,
		"bot_rest": 3.0, "net": "host", "port": port})
	await get_tree().process_frame
	var s: GameSession = main.session
	check(s != null and Net.role == Net.Role.SERVER and s.net is NetServer, "hosting from a normal game session")
	check(s.player.display_name == "Hosty", "the host's rat carries the host's name")
	var joined := await wait_for(func() -> bool: return (s.net as NetServer).player_count() > 0, 30.0)
	check(joined, "a remote player joined the hosted game")
	if joined:
		var remote: Rat = (s.net as NetServer).seats.values()[0]
		check(remote.team == 1 and not remote.is_bot and remote.display_name == "Tester", "they took a bot's seat on their team")
		var start := remote.position
		var walked := await wait_for(func() -> bool: return is_instance_valid(remote) and remote.position.distance_to(start) > 4.0, 20.0)
		check(walked, "the host sees the remote player move")
		check(s.player.net_peer == 0 and s.m.rats.size() == 4, "the host still plays locally; no extra rats")
		var left := await wait_for(func() -> bool: return (s.net as NetServer).player_count() == 0, 40.0)
		check(left, "the remote player left")
		await wait_for(func() -> bool: return (s.net as NetServer).player_count() > 0, 15.0)   # their rejoin
		await wait_for(func() -> bool: return (s.net as NetServer).player_count() == 0, 15.0)
		var bots := 0
		for r in s.m.rats:
			bots += 1 if r.is_bot else 0
		check(bots == 3, "their seat went back to a bot (%d bots)" % bots)
	Net.close()
	print("---- net host: %d failed ----" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
