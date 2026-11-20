class_name AntiCheat
extends RefCounted
## Server-side checks on what a player's game reports, for public servers.
##
## A player's own rat moves on their machine (so it feels instant) and the
## server is told where it went. These checks make sure those moves could have
## happened under the game's own physics:
##  - no standing inside solid ground, and no passing through it between two
##    reports (noclip);
##  - no rising higher than jumps, double jumps, springs, a jetpack or a blast
##    could carry you, and no hanging in the air longer than a fall allows
##    (fly and hover hacks);
##  - stamina only refills as fast as it really does;
##  - requests and movement reports are rate limited (token buckets), so a
##    flood is dropped instead of slowing the server.
## A failed check puts the rat back where the server last saw it legally and
## costs a strike. Strikes fade (one every STRIKE_FADE seconds); a player who
## piles up STRIKE_LIMIT is removed, if `kick_out` is on (dedicated servers).
## The thresholds are generous on purpose: lag and edge cases must never cost
## an honest player more than a rare correction.

const STRIKE_LIMIT := 8.0
const STRIKE_FADE := 30.0          # seconds per strike forgiven
const INSIDE_GRACE := 0.2          # seconds a rat may report itself inside a block (someone just built there)
const TUNNEL_RUN := 0.45           # blocks of solid ground a move may cut through before it's noclip
const LAG_GRACE := 0.75            # seconds of extra air time, for reports that arrive in a bunch
const RISE_SLACK := 0.8            # blocks
const JUMP_RISE := 3.4             # jump + double jump + a ledge step
const SPRING_RISE := 6.8           # a spring, then a double jump
const JET_RISE := 11.8             # a jetpack's thrust and what it carries you after
const SUPPORT_PROBE := 0.15
# token buckets: [per second, burst]
const RATES := {"act": [30.0, 60.0], "input": [45.0, 90.0], "aim": [45.0, 90.0]}
const FLOOD_STRIKE := 60           # dropped messages per strike

var kick_out := false              # remove players who reach STRIKE_LIMIT (dedicated servers)
var log_violations := true
var _peers: Dictionary = {}        # peer id -> state Dictionary


func _state(id: int, rat: Rat, now: int) -> Dictionary:
	if not _peers.has(id):
		_peers[id] = {"good": rat.position, "inside": 0.0, "last": now, "strikes": 0.0, "struck": now,
			"base_y": rat.position.y, "base_t": now, "allow": JUMP_RISE, "jet": 0.0, "dropped": 0,
			"buckets": {}, "log": []}
	return _peers[id]


func forget(id: int) -> void:
	_peers.erase(id)


func strikes(id: int) -> float:
	return float(_peers[id]["strikes"]) if _peers.has(id) else 0.0


func good_position(id: int, rat: Rat) -> Vector3:
	## Where the rat last was legally (where a correction puts it back).
	if _peers.has(id) and not _peers[id].has("fresh"):
		return _peers[id]["good"]
	return rat.position


func recent(id: int) -> Array:
	## The last few violations, newest last (for logs and tests).
	return _peers[id]["log"] if _peers.has(id) else []


# ---------------------------------------------------------------- rate limits

func allow(id: int, kind: String, now: int = -1) -> bool:
	## Takes a token for one message of this kind; false = drop the message.
	if now < 0:
		now = Time.get_ticks_msec()
	if not _peers.has(id):
		_peers[id] = {"good": Vector3.ZERO, "inside": 0.0, "last": now, "strikes": 0.0, "struck": now,
			"base_y": 0.0, "base_t": now, "allow": JUMP_RISE, "jet": 0.0, "dropped": 0, "buckets": {}, "log": [], "fresh": true}
	var st: Dictionary = _peers[id]
	var rate: Array = RATES.get(kind, [30.0, 60.0])
	var b: Array = st["buckets"].get(kind, [float(rate[1]), now])
	var tokens := minf(float(rate[1]), float(b[0]) + float(rate[0]) * float(now - int(b[1])) / 1000.0)
	if tokens < 1.0:
		st["buckets"][kind] = [tokens, now]
		st["dropped"] = int(st["dropped"]) + 1
		if int(st["dropped"]) % FLOOD_STRIKE == 0:
			strike(id, "flooding the server with %s messages" % kind, 1.0, now)
		return false
	st["buckets"][kind] = [tokens - 1.0, now]
	return true


# ---------------------------------------------------------------- strikes

func strike(id: int, reason: String, weight: float = 1.0, now: int = -1) -> bool:
	## Records a violation. Returns true when the player should be removed.
	if now < 0:
		now = Time.get_ticks_msec()
	if not _peers.has(id):
		return false
	var st: Dictionary = _peers[id]
	var faded := float(now - int(st["struck"])) / 1000.0 / STRIKE_FADE
	st["strikes"] = maxf(0.0, float(st["strikes"]) - faded) + weight
	st["struck"] = now
	var lg: Array = st["log"]
	lg.append(reason)
	if lg.size() > 8:
		lg.remove_at(0)
	if log_violations:
		Log.info("anti-cheat: peer %d: %s (%.1f strikes)" % [id, reason, float(st["strikes"])])
	return kick_out and float(st["strikes"]) >= STRIKE_LIMIT


# ---------------------------------------------------------------- movement

func reset(id: int, rat: Rat, now: int = -1) -> void:
	## The server itself just put the rat somewhere (spawn, respawn, teleport,
	## knockback...): that is the new legal position, and it may fly as high
	## as the velocity the server gave it allows.
	if now < 0:
		now = Time.get_ticks_msec()
	var st := _state(id, rat, now)
	if st.has("fresh"):
		st.erase("fresh")
	st["good"] = rat.position
	st["inside"] = 0.0
	var up := maxf(0.0, rat.vel.y)
	_support(st, rat, rat.position, now, up * up / (2.0 * Rat.GRAVITY) + JUMP_RISE)


func _support(st: Dictionary, rat: Rat, pos: Vector3, now: int, allow: float) -> void:
	st["base_y"] = pos.y
	st["base_t"] = now
	var jet := rat.gear == "jetpack"
	st["allow"] = allow + (JET_RISE if jet else 0.0)
	st["jet"] = Config.JETPACK_TIME if jet else 0.0


func check_move(id: int, rat: Rat, pos: Vector3, now: int = -1) -> String:
	## "" when `pos` is a move the rat could have made since its last report,
	## else what was wrong with it (the caller puts the rat back).
	if now < 0:
		now = Time.get_ticks_msec()
	var st := _state(id, rat, now)
	if st.has("fresh"):   # rate-limit state came first: start from where the server has the rat
		st.erase("fresh")
		st["good"] = rat.position
		_support(st, rat, rat.position, now, JUMP_RISE)
	var dt := clampf(float(now - int(st["last"])) / 1000.0, 0.0, 1.0)
	st["last"] = now
	if rat.operating != -1:
		st["good"] = pos
		_support(st, rat, pos, now, JUMP_RISE)
		return ""
	# -- solid ground --------------------------------------------------
	if rat.blocked_at(pos):
		st["inside"] = float(st["inside"]) + dt
		if float(st["inside"]) > INSIDE_GRACE:
			return "inside solid ground for %.1f s" % float(st["inside"])
		return ""   # for a moment: someone may just have built there
	var good: Vector3 = st["good"]
	var run := solid_run(rat, good, pos)
	if run > TUNNEL_RUN:
		return "moved through %.1f blocks of solid ground" % run
	st["inside"] = 0.0
	# -- height --------------------------------------------------------
	if bool(rat.cls["fly"]):
		st["good"] = pos
		_support(st, rat, pos, now, JUMP_RISE)
		return ""
	var boost := _boost_near(rat, pos)
	if boost > 0.0:
		_support(st, rat, pos, now, boost)
	elif _supported(rat, pos):
		_support(st, rat, pos, now, JUMP_RISE)
	else:
		var top := ceiling(st, now)
		if pos.y > top:
			return "%.1f blocks higher than a rat can get there" % (pos.y - top)
	st["good"] = pos
	return ""


func ceiling(st: Dictionary, now: int) -> float:
	## The highest a rat can be, `now`, since it last stood on something:
	## up to its allowance while it could still be rising, then falling.
	var allow := float(st["allow"])
	var t := float(now - int(st["base_t"])) / 1000.0 - LAG_GRACE
	var t_up := sqrt(2.0 * allow / Rat.GRAVITY) * 1.5 + float(st["jet"]) + 0.3
	var top := float(st["base_y"]) + allow + RISE_SLACK
	if t > t_up:
		top -= 0.5 * Rat.GRAVITY * (t - t_up) * (t - t_up)
	return top


func _supported(rat: Rat, pos: Vector3) -> bool:
	## Standing on something, climbing or swimming.
	if rat.blocked_at(pos - Vector3(0, SUPPORT_PROBE, 0)):
		return true
	var w: VoxelWorld = rat._world
	for p: Vector3 in [pos + Vector3(0, 0.1, 0), pos + Vector3(0, Rat.HEIGHT * 0.5, 0), pos - Vector3(0, 0.1, 0)]:
		var id := w.block_at(p)
		if id == Blocks.LADDER or id == Blocks.WATER or id == Blocks.LAVA:
			return true
	return false


func _boost_near(rat: Rat, pos: Vector3) -> float:
	## A spring or wall spring right by the rat: it may be flung up from here.
	var w: VoxelWorld = rat._world
	var f := Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))
	var best := 0.0
	for dy in range(-2, 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var id := w.get_cell(f + Vector3i(dx, dy, dz))
				if id == Blocks.SPRING:
					return SPRING_RISE
				if id == Blocks.WALL_SPRING:
					best = JUMP_RISE + 1.0
	return best


static func solid_run(rat: Rat, from: Vector3, to: Vector3) -> float:
	## How much of the straight line from `from` to `to` (at knee and chest
	## height) runs through ground solid for this rat, in blocks. A real move
	## between two reports only ever grazes a corner.
	var d := from.distance_to(to)
	if d < 0.05:
		return 0.0
	var steps := ceili(d / 0.1)
	var worst := 0.0
	for h: float in [0.25, Rat.HEIGHT * 0.75]:
		var run := 0.0
		var best := 0.0
		for i in range(1, steps):
			var p := from.lerp(to, float(i) / float(steps)) + Vector3(0, h, 0)
			if _solid_point(rat, p):
				run += d / float(steps)
				best = maxf(best, run)
			else:
				run = 0.0
		worst = maxf(worst, best)
	return worst


static func _solid_point(rat: Rat, p: Vector3) -> bool:
	var w: VoxelWorld = rat._world
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	if not w.in_bounds(c):
		return false
	if not w.gates.is_empty() and int(w.gates.get(c, rat.team)) != rat.team:
		return true
	if not Blocks.solid_for(w.get_cell(c), rat.team):
		return false
	if not w.has_micro(c):
		return true
	var e := Vector3(0.02, 0.02, 0.02)
	return w.micro_box_hit(c, p - e, p + e)
