class_name NetClient
extends Node
## A player's side of a networked match. The session's Match is a replica:
## this node fills it from what the server sends, forwards every gameplay
## request to the server (Match calls `act` instead of applying rules), and
## reports where our own rat is. Our own rat moves locally for instant
## response; the server corrects it when the authority moves it ("kick").

signal notice(text: String)

const INPUT_EVERY := 2         # physics frames between movement reports (30 Hz)

var m: Match
var my_id := -1
var _kick := 0
var _targets: Dictionary = {}  # rat id -> [pos, vel, yaw]
var _frame := 0
var _fire_t := 0
var _aim_t := 0
var _sent_action_t := 0.0
var _fx_notes: Dictionary = {}   # effects our own rat caused since the last report


func _init(p_match: Match, info: Dictionary) -> void:
	m = p_match
	my_id = int(info["rat"])
	_kick = int(info.get("kick", 0))
	m.remote = self
	m.networked = true
	if not m.world.apply_snapshot(info["world"]):
		Log.warn("net: the server sent a world snapshot we could not read")
	on_snap(info["snap"])
	on_private(info["private"])


func _ready() -> void:
	process_physics_priority = 10   # after the local rat has moved this frame
	Net.client = self


func _exit_tree() -> void:
	if Net.client == self:
		Net.client = null
	if m != null and m.remote == self:
		m.remote = null


func me() -> Rat:
	return m.rat_by_id(my_id)


# ---------------------------------------------------------------- outgoing

func act(method: String, args: Array) -> String:
	## Ask the server to do something. Its answer, if it is a refusal, comes
	## back as a notice; locally there is nothing to report yet.
	if method == "fire":
		var now := Time.get_ticks_msec()
		var r := me()
		var mc := m.siege.by_uid(r.operating) if r != null and r.operating != -1 else null
		if now - _fire_t < 100 or (mc != null and mc.cd > 0.05):
			return "wait"
		_fire_t = now
	if Net.role == Net.Role.CLIENT:
		Net._c_act.rpc_id(1, method, args)
	return ""


func note_fx(kind: String) -> void:
	## Our rat bounced off a spring or fired its jetpack; the server plays the
	## effect for everyone when our next movement report arrives.
	_fx_notes[kind] = true

func aim_machine(yaw: float, pitch: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _aim_t < 50 or Net.role != Net.Role.CLIENT:
		return
	_aim_t = now
	Net._c_aim.rpc_id(1, yaw, pitch)


func _physics_process(_delta: float) -> void:
	_frame += 1
	var r := me()
	if r == null or Net.role != Net.Role.CLIENT or _frame % INPUT_EVERY != 0:
		return
	var f := (1 if r.on_floor else 0) | (2 if r.on_ladder else 0) | (4 if r.in_water else 0) | (8 if r.flying else 0)
	var pkt := {"k": _kick, "p": r.position, "v": r.vel, "y": r.yaw, "f": f, "s": r.stamina}
	# share a freshly started swing / build animation so others see it
	if r.anim_action_t > _sent_action_t + 0.01:
		pkt["a"] = r.anim_action
	_sent_action_t = r.anim_action_t
	if not _fx_notes.is_empty():
		pkt["fx"] = _fx_notes.keys()
		_fx_notes.clear()
	Net._c_input.rpc_id(1, pkt)


func _process(delta: float) -> void:
	# other rats glide toward where the server last saw them
	var k := 1.0 - exp(-delta * 14.0)
	for r in m.rats:
		if r.id == my_id or not _targets.has(r.id):
			continue
		var t: Array = _targets[r.id]
		var to: Vector3 = t[0]
		if r.position.distance_to(to) > 4.0:
			r.position = to
		else:
			r.position = r.position.lerp(to + (t[1] as Vector3) * 0.05, k)
		r.yaw = lerp_angle(r.yaw, float(t[2]), k)


# ---------------------------------------------------------------- incoming

func on_snap(s: Dictionary) -> void:
	m.time = float(s.get("t", m.time))
	var sc: Array = s.get("sc", [0, 0])
	if int(sc[0]) != m.scores[0] or int(sc[1]) != m.scores[1]:
		m.scores[0] = int(sc[0])
		m.scores[1] = int(sc[1])
		m.score_changed.emit()
	m.winner = int(s.get("w", -1))
	if bool(s.get("o", false)) and not m.over:
		m.over = true
		m.won.emit(m.winner)
	_apply_rats(s.get("r", []))
	_apply_pickups(s.get("p", []))
	m.markers.clear()
	for mk: Variant in s.get("mk", []):
		if mk is Dictionary:
			m.markers.append(mk)
	_apply_machines(s.get("mc", []))
	_apply_shots(s.get("sh", []))
	_apply_sticks(s.get("st", []))


func _apply_rats(list: Array) -> void:
	var seen := {}
	for e: Array in list:
		var id := int(e[0])
		seen[id] = true
		var r := m.rat_by_id(id)
		var flags := int(e[4])
		if r == null:
			r = m.spawn_rat(int(e[1]), String(e[2]), (flags & 16) != 0, id)
			r.position = e[5]
			r.net_local = id == my_id
		if r.class_id != String(e[2]):
			r.set_class(String(e[2]), false)
		r.team = int(e[1])
		r.display_name = String(e[3])
		r.is_bot = (flags & 16) != 0
		r.carried = int(e[10])
		if id == my_id:
			continue   # our own body is ours to move; corrections arrive as kicks
		_targets[id] = [e[5], e[6], e[7]]
		r.vel = e[6]
		r.on_floor = (flags & 1) != 0
		r.on_ladder = (flags & 2) != 0
		r.in_water = (flags & 4) != 0
		r.flying = (flags & 8) != 0
		if String(e[8]) != "" and float(e[9]) > r.anim_action_t:
			r.play_action(String(e[8]), float(e[9]))
		r.stun = float(e[11])
		r.knock = float(e[12])
		r.operating = int(e[13])
	for r in m.rats.duplicate():
		if not seen.has(r.id):
			m.rats.erase(r)
			_targets.erase(r.id)
			r.queue_free()


func _apply_pickups(list: Array) -> void:
	var by_uid := {}
	for p in m.pickups:
		by_uid[p.uid] = p
	var out: Array[Match.Pickup] = []
	for e: Array in list:
		var p: Match.Pickup = by_uid.get(int(e[0]))
		if p == null:
			p = Match.Pickup.new()
			p.uid = int(e[0])
			p.kind = String(e[1])
		p.pos = e[2]
		out.append(p)
	m.pickups = out


func _apply_machines(list: Array) -> void:
	var by_uid := {}
	for mc: SiegeSystem.Machine in m.siege.machines.values():
		by_uid[mc.uid] = mc
	var out := {}
	for e: Array in list:
		var mc: SiegeSystem.Machine = by_uid.get(int(e[0]))
		if mc == null:
			mc = SiegeSystem.Machine.new()
			mc.uid = int(e[0])
		mc.kind = int(e[1])
		mc.cell = e[2]
		mc.team = int(e[3])
		mc.owner = int(e[4])
		mc.yaw = float(e[5])
		mc.pitch = float(e[6])
		mc.operator = int(e[7])
		mc.cd = float(e[8])
		mc.theta = float(e[9])
		mc.omega = float(e[10])
		mc.recoil = float(e[11])
		mc.under = int(e[12])
		out[mc.cell] = mc
	m.siege.machines = out


func _apply_shots(list: Array) -> void:
	var out: Array[SiegeSystem.Shot] = []
	for e: Array in list:
		var s := SiegeSystem.Shot.new()
		s.uid = int(e[0])
		s.pos = e[1]
		s.vel = e[2]
		s.team = int(e[3])
		out.append(s)
	m.siege.shots = out


func _apply_sticks(list: Array) -> void:
	var out: Array[DynamiteSystem.Stick] = []
	for e: Array in list:
		var s := DynamiteSystem.Stick.new()
		s.uid = int(e[0])
		s.pos = e[1]
		s.vel = e[2]
		s.fuse = float(e[3])
		s.resting = bool(e[4])
		out.append(s)
	m.dynamite.sticks = out


func on_events(e: Dictionary) -> void:
	var b: PackedInt32Array = e.get("b", PackedInt32Array())
	for i in range(0, b.size() - 3, 4):
		m.world.set_block(Vector3i(b[i], b[i + 1], b[i + 2]), b[i + 3])
	for entry: Array in e.get("mi", []):
		var cell: Vector3i = entry[0]
		if entry[2] is PackedByteArray:
			m.world.set_mask(cell, int(entry[1]), entry[2])
		else:
			m.world.set_block(cell, int(entry[1]))
	for g: Array in e.get("g", []):
		m.world.set_gate_layer(g[0], int(g[1]))
	for f: Array in e.get("fx", []):
		m.fx.emit(String(f[0]), f[1], f[2])
	for t: Array in e.get("to", []):
		m.toast.emit(String(t[0]), int(t[1]))
	var won := int(e.get("won", -1))
	if won >= 0 and not m.over:
		m.over = true
		m.winner = won
		m.won.emit(won)


func on_private(p: Dictionary) -> void:
	var r := me()
	if r == null:
		return
	if String(p.get("cls", r.class_id)) != r.class_id:
		r.set_class(String(p["cls"]), false)
	r.mats = p.get("mats", r.mats)
	r.gadgets = p.get("gadgets", r.gadgets)
	r.scrap = int(p.get("scrap", r.scrap))
	r.equipped = String(p.get("eq", r.equipped))
	r.micro_bank = p.get("mb", r.micro_bank)
	var acd: Array = p.get("acd", r.ability_cd)
	r.ability_cd = [float(acd[0]), float(acd[1])]
	r.class_cd = float(p.get("ccd", r.class_cd))
	r.operating = int(p.get("op", r.operating))
	r.carried = int(p.get("ca", r.carried))
	r.raid_t = float(p.get("raid", r.raid_t))
	r.gear = String(p.get("gear", r.gear))
	if p.get("bank") is Dictionary:
		m.team_bank[r.team] = p["bank"]


func on_kick(k: Dictionary) -> void:
	var r := me()
	if r == null:
		return
	_kick = int(k["k"])
	r.position = k["p"]
	r.vel = k["v"]
	r.stun = float(k["st"])
	r.knock = float(k["kn"])
	r.slow = float(k["sl"])
	r.stamina = float(k["sa"])
	r.flying = bool(k["fl"])
	if r.knock > 0.0 or r.stun > 0.0:
		r.on_floor = false


func on_notice(text: String) -> void:
	notice.emit(text)
