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


func until_loaded() -> GameSession:
	await wait_for(func() -> bool: return main.session != null and is_instance_valid(main.session) and main.session.loaded, 60.0)
	return main.session


func _run() -> void:
	if OS.get_environment("BW_NET_TEST") == "lobby":
		await _run_lobby()
		return
	var port := OS.get_environment("BW_PORT").to_int() if OS.get_environment("BW_PORT").is_valid_int() else 24598
	Net.player_name = "Hosty"
	main.start_match({"mode": "race", "seed": 777, "goal": 3, "team": 0, "class": "scout", "team_size": 2,
		"bot_rest": 3.0, "net": "host", "port": port})
	var s: GameSession = await until_loaded()
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


func _run_lobby() -> void:
	## Hosting with the lobby on: everyone waits in the playground until the
	## host starts, then the match begins for all of them.
	var port := OS.get_environment("BW_PORT").to_int() if OS.get_environment("BW_PORT").is_valid_int() else 24596
	Net.player_name = "Hosty"
	main.start_match({"mode": "race", "seed": 777, "goal": 3, "team": 0, "class": "scout", "team_size": 2,
		"bot_rest": 3.0, "net": "host", "port": port, "lobby": true})
	var s: GameSession = await until_loaded()
	check(s != null and s.m.lobby and s.net is NetServer, "hosting opens the playground lobby")
	check(s.m.bots.is_empty() and s.m.rats.size() <= 2 and s.player.gear == "jetpack", "no bots in the lobby; the host wears a jetpack")
	check(s.hud.lobby_text().contains(Inputs.key_name("start_match")), "the host is told how to start (%s)" % s.hud.lobby_text())
	var joined := await wait_for(func() -> bool: return (s.net as NetServer).player_count() > 0, 30.0)
	check(joined, "a friend joined the lobby")
	if joined:
		var friend: Rat = (s.net as NetServer).seats.values()[0]
		check(friend.team == 1 and friend.class_id == "digger" and friend.gear == "jetpack", "in their team and class, with a jetpack")
		await wait_for(func() -> bool: return s.m.time > 6.0, 10.0)
		check(is_instance_valid(s) and main.session == s and s.m.lobby, "nothing starts by itself")
		check(not s.m.infinite_next, "the friend's attempt at the cheat code changed nothing here")
		await type_contra_code()
		check(s.m.infinite_next and s.hud.lobby_text().contains("CHEAT"), "the host's Up Up Down Down Left Right Left Right B A turns on infinite resources (%s)" % s.hud.lobby_text())
		check(s.hud._dialog == null, "and its B didn't open the workshop")
		await get_tree().create_timer(2.0).timeout   # (the friend's banner shows it too)
		s.start_requested.emit()     # the host presses start
		var lobby_id := s.get_instance_id()   # (the lobby session is freed once the match starts)
		var started := await wait_for(func() -> bool: return main.session != null and main.session.get_instance_id() != lobby_id \
				and is_instance_valid(main.session) and main.session.m != null and not main.session.m.lobby, 10.0)
		check(started, "the host starts the match")
		if started:
			var race: GameSession = main.session
			var seated := await wait_for(func() -> bool: return (race.net as NetServer).player_count() > 0, 10.0)
			var bots := 0
			for r in race.m.rats:
				bots += 1 if r.is_bot else 0
			check(seated and race.m.rats.size() == 4 and bots == 2, "everyone is carried into the match; bots fill the rest (%d rats, %d bots)" % [race.m.rats.size(), bots])
			check(race.player.gear == "" and race.player.display_name == "Hosty", "lobby jetpacks stay in the lobby")
			check(race.m.infinite and not race.m.free_mode, "the match is a Cheese Race with infinite resources")
			var scrap := race.player.scrap
			var springs := int(race.player.gadgets.get("spring", 0))
			check(race.m.try_buy(race.player, "spring") == "" and race.player.scrap == scrap and int(race.player.gadgets["spring"]) > springs,
				"the host's workshop costs nothing")
			await _results_flow(race)
	Net.close()
	print("---- net lobby host: %d failed ----" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _win(s: GameSession) -> void:
	await get_tree().create_timer(1.0).timeout
	s.player.carried = s.m.goal
	s.m._deposit(s.player)


func _button(rs: ResultsScreen, text: String) -> Button:
	for b in rs.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _results_flow(race: GameSession) -> void:
	## The host wins: the results screen with the host's choices. Back to the
	## lobby, start again, win again, then Next game - the friend comes along.
	var ns := race.net as NetServer
	var friend: Rat = ns.seats.values()[0] if not ns.seats.is_empty() else null
	await _win(race)
	var rs := race.hud.results
	check(race.m.over and rs != null and rs.host_role() == "host", "the host wins: the results screen opens")
	if rs == null:
		return
	check(_button(rs, "Next game (new map)") != null and _button(rs, "Back to the lobby") != null and _button(rs, "Main menu (ends the game)") != null,
		"the host can start the next game, go back to the lobby, or end it")
	check(int(race.player.stats.get("banked", 0)) == race.m.goal, "the host's tally: %d cheese banked" % int(race.player.stats.get("banked", 0)))
	var emoted := await wait_for(func() -> bool: return friend != null and is_instance_valid(friend) and friend.emote == "cheer", 15.0)
	check(emoted, "the friend's emote reaches the host")
	var bots_emote := await wait_for(func() -> bool:
		for r in race.m.rats:
			if r.is_bot and r.emote_t > 0.0:
				return true
		return false, 10.0)
	check(bots_emote, "bots emote too")
	var race_id := race.get_instance_id()
	_button(rs, "Back to the lobby").pressed.emit()
	var lob_ok := await wait_for(func() -> bool: return main.session != null and is_instance_valid(main.session) and main.session.get_instance_id() != race_id \
			and main.session.loaded and main.session.m.lobby and (main.session.net as NetServer).player_count() > 0, 30.0)
	check(lob_ok, "Back to the lobby: everyone is in the playground again")
	if not lob_ok:
		return
	var lob: GameSession = main.session
	await get_tree().create_timer(1.0).timeout
	lob.start_requested.emit()
	var lob_id := lob.get_instance_id()
	var r2_ok := await wait_for(func() -> bool: return main.session != null and is_instance_valid(main.session) and main.session.get_instance_id() != lob_id \
			and main.session.loaded and not main.session.m.lobby and (main.session.net as NetServer).player_count() > 0, 30.0)
	check(r2_ok, "and the host starts another match")
	if not r2_ok:
		return
	var r2: GameSession = main.session
	await _win(r2)
	var r2_id := r2.get_instance_id()
	check(r2.hud.results != null, "won again")
	if r2.hud.results == null:
		return
	r2.hud.results.first_button().pressed.emit()   # Next game (new map)
	var r3_ok := await wait_for(func() -> bool: return main.session != null and is_instance_valid(main.session) and main.session.get_instance_id() != r2_id \
			and main.session.loaded and not main.session.m.lobby and not main.session.m.over and (main.session.net as NetServer).player_count() > 0, 30.0)
	check(r3_ok, "Next game: straight into a new match, the friend with us")
	if r3_ok:
		await wait_for(func() -> bool: return (main.session.net as NetServer).player_count() == 0, 30.0)


func type_contra_code() -> void:
	## Up Up Down Down Left Right Left Right B A, as real key presses.
	for k: int in [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]:
		var e := InputEventKey.new()
		e.keycode = k as Key
		e.physical_keycode = k as Key
		e.pressed = true
		Input.parse_input_event(e)
		await get_tree().process_frame
		await get_tree().process_frame
		var u := InputEventKey.new()
		u.keycode = k as Key
		u.physical_keycode = k as Key
		u.pressed = false
		Input.parse_input_event(u)
		await get_tree().process_frame


func toast_says(hud: Hud, text: String) -> bool:
	for c in hud._toasts.get_children():
		if c is Label and (c as Label).text.contains(text):
			return true
	return false
