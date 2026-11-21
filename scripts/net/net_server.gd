class_name NetServer
extends Node
## The authority's side of a networked match. Lives next to the real Match
## (in a host's GameSession or in a DedicatedServer) and:
##  - seats joining players in a rat (taking over a bot), and hands the rat
##    back to a bot when they leave;
##  - executes their requests through the normal validated Match methods;
##  - accepts their own rat's movement, within a speed limit and the
##    physics checks in AntiCheat (no noclip, flying or hovering), and rate
##    limits everything a player sends;
##  - streams terrain changes, effects and toasts (reliable), a 20 Hz
##    snapshot of everything that moves (unreliable), and each player's
##    private inventory (reliable, 4 Hz);
##  - tells a player whenever the authority itself moved their rat
##    (bonk, blast, trap, respawn...), so their game follows.

const SNAP_EVERY := 3          # physics frames per snapshot (60 Hz / 3 = 20 Hz)
const PRIVATE_EVERY := 15      # 4 Hz
const MAX_SPEED := 40.0        # blocks/s a rat may legitimately cover (springs, dashes, falls)
const MAX_RATS := 32           # 16v16

var m: Match
var seats: Dictionary = {}     # peer id -> Rat
var _blocks := PackedInt32Array()
var _micro: Dictionary = {}    # Vector3i -> true
var _gates: Dictionary = {}    # Vector3i -> true (gate layers that changed)
var _fx: Array = []
var _toasts: Array = []
var _won := -1
var _frame := 0
var _last_input: Dictionary = {}   # peer id -> msec of the last accepted input
var _dirty_private: Dictionary = {}
var _fx_t: Dictionary = {}         # "peer:kind" -> msec of the last effect that peer reported
var ac := AntiCheat.new()          # movement checks, rate limits and strikes
var perf := [0, 0, 0]              # _physics_process timing (corrections, events, snapshots): [usec total, worst, ticks]
var inputs := {"ok": 0, "dropped": 0, "stale": 0, "moved": 0, "bad": 0}   # movement reports, for health lines
var max_players := Net.HOST_MAX_CLIENTS   # connected players (a dedicated server raises it to Net.MAX_CLIENTS)
var _roster_sig := ""              # rats' names as last sent
var _roster_left := 0              # snapshots that still carry the names after a change
var _snaps := 0
const CLIENT_FX := ["spring", "jetpack", "dash", "jump", "land", "splash", "splash_out", "shield"]


func _ready() -> void:
	process_physics_priority = 10   # after Match.step in the same frame
	m.networked = true
	m.world.block_changed.connect(_on_block)
	m.world.block_changed.connect(func(cell: Vector3i, _old: int, new_id: int) -> void: ac.note_block(cell, new_id))
	m.world.micro_changed.connect(_on_micro)
	m.world.gate_layer_changed.connect(func(c: Vector3i) -> void: _gates[c] = true)
	m.fx.connect(func(kind: String, pos: Vector3, data: Variant) -> void: _fx.append([kind, pos, data]))
	m.toast.connect(func(text: String, team: int) -> void: _toasts.append([text, team]))
	m.won.connect(func(team: int) -> void: _won = team)
	Net.server = self
	# a new round: everyone already connected gets a seat in the new match
	for id: int in Net.hellos.keys():
		on_hello(id, Net.hellos[id])


func _exit_tree() -> void:
	if Net.server == self:
		Net.server = null


func player_count() -> int:
	return seats.size()


# ---------------------------------------------------------------- seating

func on_hello(id: int, hello: Dictionary) -> void:
	if seats.has(id):
		return
	if seats.size() >= max_players:
		if Net.connected(id):
			Net._s_refuse.rpc_id(id, "The server is full (%d players)." % max_players)
		return
	var pname := Net.clean_name(hello.get("name", ""))
	if pname == "":
		pname = "Rat %d" % (id % 1000)
	pname = _unique(pname)
	var want := int(hello.get("team", -1))
	if want != 0 and want != 1:
		want = _smaller_team()
	var cls := String(hello.get("class", "digger"))
	if m.free_mode and not m.lobby:
		cls = "maestro"
	elif not ClassDefs.ORDER.has(cls):
		cls = "digger"
	var rat := _free_bot(want)
	if rat == null and not m.free_mode:
		rat = _free_bot(1 - want)
	if rat == null:
		if m.rats.size() >= MAX_RATS:
			if Net.connected(id):
				Net._s_refuse.rpc_id(id, "The server is full.")
			return
		rat = m.spawn_rat(want if m.lobby or not m.free_mode else 0, cls, false)
	m.make_player(rat, id, pname)
	if rat.class_id != cls:
		rat.set_class(cls, true)
	if m.lobby:
		rat.gear = "jetpack"
	if not m.in_base(rat) and not m.free_mode:
		m.respawn(rat)   # take over the seat at home, not wherever the bot was
	# each seat counts its corrections from a fresh random number, so reports
	# a player's game sent in the previous round (or the lobby) are stale here
	rat.net_kick = randi_range(1, 1 << 30)
	rat.net_pre = Match.net_state(rat)
	seats[id] = rat
	_last_input[id] = Time.get_ticks_msec()
	ac.forget(id)
	ac.reset(id, rat)
	Net.send_welcome(id, {
		"settings": m.settings,
		"rat": rat.id,
		"snap": _snapshot(true),
		"private": _private(rat),
		"kick": rat.net_kick,
		"server": String(m.settings.get("server_name", "")),
	}, m.world.snapshot())
	m.toast.emit("%s joined the %s team" % [pname, Match.TEAM_NAMES[rat.team]], -1)
	Log.info("net: peer %d seated as %s (rat %d, team %d)" % [id, pname, rat.id, rat.team])


func on_peer_left(id: int) -> void:
	var rat: Rat = seats.get(id)
	seats.erase(id)
	_last_input.erase(id)
	ac.forget(id)
	for k: String in CLIENT_FX:
		_fx_t.erase("%d:%s" % [id, k])
	if rat == null or not is_instance_valid(rat):
		return
	var who := rat.display_name
	m.siege.release(rat)
	if m.free_mode:
		m.remove_rat(rat)
	else:
		m.make_bot(rat)
	m.toast.emit("%s left. %s" % [who, "" if m.free_mode else "A bot takes their place."], -1)


func _free_bot(team: int) -> Rat:
	for r in m.rats:
		if r.is_bot and r.team == team:
			return r
	return null


func _smaller_team() -> int:
	var humans := [0, 0]
	for r in m.rats:
		if not r.is_bot:
			humans[r.team] += 1
	return 0 if humans[0] <= humans[1] else 1


func _unique(pname: String) -> String:
	var taken := {}
	for r in m.rats:
		taken[r.display_name] = true
	var out := pname
	var n := 2
	while taken.has(out):
		out = "%s %d" % [pname.substr(0, Net.NAME_MAX - 3), n]
		n += 1
	return out


# ---------------------------------------------------------------- movement

func on_input(id: int, pkt: Dictionary) -> void:
	var rat: Rat = seats.get(id)
	if rat == null:
		return
	if not ac.allow(id, "input"):
		inputs["dropped"] += 1
		return
	if int(pkt.get("k", -1)) != rat.net_kick:
		inputs["stale"] += 1
		return   # sent before the player saw our last correction: stale
	if rat.net_dirty or Match.net_state(rat) != rat.net_pre:
		inputs["moved"] += 1
		return   # the server moved the rat since (a respawn, a bonk...): its correction goes out next tick
	var p: Variant = pkt.get("p")
	var v: Variant = pkt.get("v")
	if not (p is Vector3) or not (v is Vector3) or not (pkt.get("y") is float):
		return
	var pos: Vector3 = p
	if not pos.is_finite() or not (v as Vector3).is_finite():
		return
	var now := Time.get_ticks_msec()
	var dt := clampf(float(now - int(_last_input.get(id, now))) / 1000.0, 0.0, 1.0)
	_last_input[id] = now
	if _lifted_out(rat, pos):
		ac.moved_by_world(id, rat, pos, now)   # (the ground filled in under it: the same way out the server would take)
	else:
		var limit := MAX_SPEED * dt + 1.5
		if pos.distance_to(rat.position) > limit or pos.y < -6.0 or pos.x < -2.0 or pos.z < -2.0 \
				or pos.x > VoxelWorld.SX + 2.0 or pos.z > VoxelWorld.SZ + 2.0 or pos.y > VoxelWorld.SY + 30.0:
			_correct(id, rat, "moved %.1f blocks in %.2f s" % [pos.distance_to(rat.position), dt], pos)   # too far, too fast
			inputs["bad"] += 1
			return
		var bad := ac.check_move(id, rat, pos, now)
		if bad != "":
			_correct(id, rat, bad, pos)
			inputs["bad"] += 1
			return
	inputs["ok"] += 1
	var regen := Config.STAMINA_REGEN * dt + 2.0   # stamina refills no faster than it does
	rat.stamina = clampf(float(pkt.get("s", rat.stamina)), 0.0, minf(rat.max_stamina(), rat.stamina + regen)) \
		if pkt.get("s") is float else rat.stamina
	rat.position = pos
	rat.vel = (v as Vector3).limit_length(60.0)
	rat.yaw = float(pkt["y"])
	var f := int(pkt.get("f", 0))
	rat.on_floor = (f & 1) != 0
	rat.on_ladder = (f & 2) != 0
	rat.in_water = (f & 4) != 0
	rat.flying = (f & 8) != 0 and bool(rat.cls["fly"])
	if pkt.get("a") is String and String(pkt["a"]) != "":
		rat.play_action(String(pkt["a"]), 0.3)
	if pkt.get("fx") is Array:
		for kind: Variant in pkt["fx"]:
			var key := "%d:%s" % [id, kind]
			if kind is String and CLIENT_FX.has(kind) and now - int(_fx_t.get(key, 0)) > 150:
				_fx_t[key] = now      # at most a few per second, whatever a client claims
				if kind == "shield" and not m.raise_shield(rat):
					continue          # no shield, or not ready: nothing to show
				m.fx.emit(String(kind), rat.position, null)
	rat.net_pre = Match.net_state(rat)


func on_aim(id: int, yaw: float, pitch: float) -> void:
	var rat: Rat = seats.get(id)
	if rat != null and is_finite(yaw) and is_finite(pitch) and ac.allow(id, "aim"):
		m.siege.aim(rat, yaw, pitch)


func _send_kick(id: int, rat: Rat) -> void:
	rat.net_kick += 1
	rat.net_pre = Match.net_state(rat)
	ac.reset(id, rat)   # wherever the server put the rat is legal, at the speed it gave it
	if Net.connected(id):
		Net._s_kick.rpc_id(id, {"k": rat.net_kick, "p": rat.position, "v": rat.vel, "st": rat.stun, "kn": rat.knock,
			"sl": rat.slow, "sa": rat.stamina, "fl": rat.flying})


static func _lifted_out(rat: Rat, pos: Vector3) -> bool:
	## Was this report the rat's game stepping it out of ground that filled in
	## where the server last had it? (Rat.unstick from there, run here on the
	## server's own copy of the world, lands on the same spot.)
	if not rat.blocked_at(rat.position):
		return false
	var keep := rat.position
	rat.unstick()
	var way_out := rat.position
	rat.position = keep
	return way_out.distance_to(pos) < 0.75


static func _v(p: Vector3) -> String:
	return "-" if not p.is_finite() else "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _correct(id: int, rat: Rat, reason: String, reported := Vector3.INF) -> void:
	## A move the rat couldn't have made: back to where it last was legally.
	var to := ac.good_position(id, rat)
	var detail := "%s (reported %s, server had %s, put back to %s)" % [reason, _v(reported), _v(rat.position), _v(to)]
	rat.position = to
	if rat.blocked_at(rat.position):
		rat.unstick()   # the ground there was filled in since: never put a rat back inside it
	rat.vel = Vector3.ZERO
	_send_kick(id, rat)
	if ac.strike(id, detail):
		Log.warn("anti-cheat: removing peer %d (%s): %s" % [id, rat.display_name, ", ".join(ac.recent(id))])
		Net.drop_peer(id, "Removed by the server: your game kept making moves that aren't possible here (%s). If you're not cheating, check your connection and join again." % reason)


# ---------------------------------------------------------------- requests

static func _ok(a: Array, types: Array) -> bool:
	if a.size() != types.size():
		return false
	for i in types.size():
		if typeof(a[i]) != int(types[i]):
			return false
	return true


static func _aim(raw: Variant) -> Variant:
	## A client's aim dictionary, or null if it is malformed.
	if not (raw is Dictionary):
		return null
	var d: Dictionary = raw
	if d.is_empty():
		return {}
	if not (d.get("cell") is Vector3i) or not (d.get("normal") is Vector3i):
		return null
	var n: Vector3i = d["normal"]
	if absi(n.x) + absi(n.y) + absi(n.z) != 1:
		return null
	var out := {"cell": d["cell"], "normal": n}
	if d.get("point") is Vector3 and (d["point"] as Vector3).is_finite():
		out["point"] = d["point"]
	return out


func on_act(id: int, method: String, a: Array) -> void:
	var rat: Rat = seats.get(id)
	if rat == null or not is_instance_valid(rat) or not ac.allow(id, "act"):
		return
	var res: Variant = null
	match method:
		"try_dig":
			if _ok(a, [TYPE_VECTOR3I]):
				m.try_dig(rat, a[0])
		"ground_pound":
			if _ok(a, [TYPE_VECTOR3I]):
				m.ground_pound(rat, a[0])
		"place_bubble":
			if _ok(a, [TYPE_VECTOR3I]):
				m.place_bubble(rat, a[0])
		"try_bonk":
			if _ok(a, [TYPE_INT]):
				var target := m.rat_by_id(a[0])
				if target != null:
					m.try_bonk(rat, target)
		"bonk_windup":
			if _ok(a, [TYPE_INT]):
				var w := m.windup.by_uid(a[0])
				if w != null:
					m.windup.try_bonk(rat, w)
		"try_place_mat":
			if _ok(a, [TYPE_VECTOR3I, TYPE_STRING]):
				res = m.try_place_mat(rat, a[0], a[1])
		"try_paint_block":
			if _ok(a, [TYPE_VECTOR3I, TYPE_INT]):
				res = m.try_paint_block(rat, a[0], a[1])
		"try_place_paint":
			if _ok(a, [TYPE_VECTOR3I, TYPE_INT]):
				res = m.try_place_paint(rat, a[0], a[1])
		"try_use_equipped":
			if _ok(a, [TYPE_DICTIONARY, TYPE_VECTOR3, TYPE_BOOL, TYPE_VECTOR3]):
				var aim: Variant = _aim(a[0])
				var look: Vector3 = a[1]
				if aim != null and look.is_finite() and look.length() > 0.01 and (a[3] as Vector3).is_finite():
					res = m.try_use_equipped(rat, aim, look.normalized(), a[2], a[3])
		"try_chisel_remove":
			if _ok(a, [TYPE_VECTOR3I, TYPE_VECTOR3I]):
				res = m.try_chisel_remove(rat, a[0], a[1])
		"try_chisel_add":
			if _ok(a, [TYPE_VECTOR3I, TYPE_VECTOR3I, TYPE_STRING, TYPE_INT]):
				res = m.try_chisel_add(rat, a[0], a[1], a[2], a[3])
		"try_paste":
			if _ok(a, [TYPE_DICTIONARY, TYPE_VECTOR3I]):
				var raw: Dictionary = a[0]
				if raw.get("size") is Vector3i and raw.get("cells") is Array and (raw["cells"] as Array).size() <= 729:
					var bp := Blueprint.new()
					bp.size = raw["size"]
					for e: Variant in raw["cells"]:
						if not (e is Dictionary):
							bp.cells.clear()
							break
						bp.cells.append(e)
					res = m.try_paste(rat, bp, a[1])
		"drop_cheese":
			if _ok(a, [TYPE_DICTIONARY, TYPE_VECTOR3]):
				var aim: Variant = _aim(a[0])
				if aim != null and (a[1] as Vector3).is_finite():
					m.drop_cheese(rat, aim, a[1])
		"respawn":
			m.respawn(rat)
		"use_ability":
			if _ok(a, [TYPE_INT, TYPE_DICTIONARY]):
				var aim: Variant = _aim(a[1])
				if aim != null:
					res = m.use_ability(rat, a[0], aim)
		"try_buy":
			if _ok(a, [TYPE_STRING]):
				res = m.try_buy(rat, a[0])
		"try_change_class":
			if _ok(a, [TYPE_STRING]):
				res = m.try_change_class(rat, a[0])
		"stash_move":
			if _ok(a, [TYPE_STRING, TYPE_INT]):
				res = m.stash_move(rat, a[0], clampi(a[1], -9999, 9999))
		"set_equipped":
			if _ok(a, [TYPE_STRING]):
				m.set_equipped(rat, a[0])
		"operate":
			if _ok(a, [TYPE_VECTOR3I]):
				res = m.siege.try_operate(rat, a[0])
		"release":
			m.siege.release(rat)
		"turn_machine":
			if _ok(a, [TYPE_INT]):
				res = m.siege.turn(rat, clampi(a[0], -1, 1))
		"fire":
			res = m.siege.fire(rat)
	if res is String and res != "" and res != "wait" and Net.connected(id):
		Net._s_notice.rpc_id(id, res)
	_dirty_private[id] = true


# ---------------------------------------------------------------- streaming

func _on_block(cell: Vector3i, _old: int, new_id: int) -> void:
	_blocks.append_array([cell.x, cell.y, cell.z, new_id])


func _on_micro(cell: Vector3i) -> void:
	_micro[cell] = true


func _physics_process(_delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_send_tick()
	var us := Time.get_ticks_usec() - t0
	perf[0] += us
	perf[1] = maxi(perf[1], us)
	perf[2] += 1


func _send_tick() -> void:
	_frame += 1
	# corrections first, so they are on the wire before the next snapshot
	for id: int in seats:
		var rat: Rat = seats[id]
		if is_instance_valid(rat) and (rat.net_dirty or Match.net_state(rat) != rat.net_pre):
			rat.net_dirty = false
			_send_kick(id, rat)
	var peers := Net.sendable()   # once per tick: connected, and (WebSocket) not closing
	if not seats.is_empty():
		_flush_events(peers)
		if _frame % SNAP_EVERY == 0:
			var snap := var_to_bytes(_snapshot())   # encoded once, sent to every seat as-is
			for id: int in seats:
				if peers.has(id) and Net.is_open(id) and not Net.backed_up(id):   # (a backed-up WebSocket skips one; the next replaces it)
					Net._s_snap.rpc_id(id, snap)
		for id: int in seats:
			if (_frame % PRIVATE_EVERY == 0 or _dirty_private.has(id)) and peers.has(id) and Net.is_open(id):
				Net._s_private.rpc_id(id, _private(seats[id]))
		_dirty_private.clear()
	else:
		_clear_events()


func _clear_events() -> void:
	_blocks = PackedInt32Array()
	_micro.clear()
	_gates.clear()
	_fx.clear()
	_toasts.clear()
	_won = -1


func _flush_events(peers: Dictionary) -> void:
	if _blocks.is_empty() and _micro.is_empty() and _gates.is_empty() and _fx.is_empty() and _toasts.is_empty() and _won < 0:
		return
	var mi: Array = []
	for c: Vector3i in _micro:
		mi.append([c, m.world.get_cell(c), m.world.micro_mask(c)])
	var gl: Array = []
	for c: Vector3i in _gates:
		gl.append([c, m.world.layered_gate(c)])
	var pkt := var_to_bytes({"b": _blocks, "mi": mi, "g": gl, "fx": _fx, "to": _toasts, "won": _won})
	for id: int in seats:
		if peers.has(id) and Net.is_open(id):   # (it may have closed during this tick)
			Net._s_events.rpc_id(id, pkt)
	_blocks = PackedInt32Array()
	_micro = {}
	_gates = {}
	_fx = []
	_toasts = []
	_won = -1


func roster() -> Dictionary:
	var names := {}
	for r in m.rats:
		names[r.id] = r.display_name
	return names


func _snapshot(with_names := false) -> Dictionary:
	## Rats go as compact binary records (NetCodec); their names only when
	## they change (then in the next 20 snapshots, as some may be lost) and
	## once a second.
	_snaps += 1
	var sig := ""
	for r in m.rats:
		sig += "%d:%s|" % [r.id, r.display_name]
	if sig != _roster_sig:
		_roster_sig = sig
		_roster_left = 20
	var send_names := with_names or _roster_left > 0 or _snaps % 20 == 0
	_roster_left = maxi(0, _roster_left - 1)
	var picks: Array = []
	for p in m.pickups:
		picks.append([p.uid, p.kind, p.pos])
	var machines: Array = []
	for mc: SiegeSystem.Machine in m.siege.machines.values():
		machines.append([mc.uid, mc.kind, mc.cell, mc.team, mc.owner, mc.yaw, mc.pitch, mc.operator, mc.cd, mc.theta,
			mc.omega, mc.recoil, mc.under])
	var shots: Array = []
	for s in m.siege.shots:
		shots.append([s.uid, s.pos, s.vel, s.team])
	var sticks: Array = []
	for s in m.dynamite.sticks:
		sticks.append([s.uid, s.pos, s.vel, s.fuse, s.resting, s.impulse, s.stuck])
	var snap := {"t": m.time, "sc": [m.scores[0], m.scores[1]], "o": m.over, "w": m.winner, "r": NetCodec.encode_rats(m.rats), "p": picks,
		"mk": m.markers, "mc": machines, "sh": shots, "st": sticks, "wd": m.windup.snapshot(), "tp": m.tele_pads(), "lt": m.lobby_left}
	if send_names:
		snap["ro"] = roster()
	if m.lobby:
		snap["ix"] = m.infinite_next   # the cheat code, so everyone's banner shows it
	return snap


func _private(r: Rat) -> Dictionary:
	return {"mats": r.mats, "gadgets": r.gadgets, "scrap": r.scrap, "eq": r.equipped, "mb": r.micro_bank,
		"acd": r.ability_cd, "ccd": r.class_cd, "cls": r.class_id, "op": r.operating, "ca": r.carried, "raid": r.raid_t,
		"gear": r.gear, "bank": m.team_bank[r.team]}
