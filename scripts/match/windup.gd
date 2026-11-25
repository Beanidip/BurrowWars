class_name WindupSystem
extends RefCounted
## Wind-up Decoys: clockwork rats in their owner's colours with a Golden
## Cheese held high and the owner's name over their heads. To the other team
## they look like someone running off with the cheese. Each one marches the
## way it was set down, hops up single steps, turns at walls and drops a
## crumb trail like a real carrier. An enemy who bonks one sets it off like
## TNT (bots fall for it too). Left alone it goes off after
## Config.WINDUP_FUSE seconds, and other blasts, lava or an enemy mouse trap
## set it off early.
##
## The body is an ordinary Rat that never joins Match.rats, so it moves by
## exactly the same rules (springs, conveyors, ice, team blocks, gates) but
## never scores, raids, picks anything up or takes a player's seat. The
## authority simulates it; online players get it in each snapshot.

const BLINK := 1.5        # seconds before going off by itself: it shows "!!"


class Walker:
	var uid := 0
	var team := 0
	var owner := -1
	var fuse := Config.WINDUP_FUSE
	var body: Rat
	var dir := Vector3(0, 0, -1)
	var stuck := 0.0
	var hop := false          # jump next step (blocked by a step)
	var hopped := false       # already tried a jump against this wall
	var turns := 0
	var warned := false
	var net_pos := Vector3.ZERO   # replica: where the server last saw it


var m: Match
var walkers: Array[Walker] = []


func _init(p_match: Match) -> void:
	m = p_match


func by_uid(uid: int) -> Walker:
	for w in walkers:
		if w.uid == uid:
			return w
	return null


func try_place(rat: Rat, look: Vector3) -> String:
	## Q with the Wind-up Decoy equipped: set it down in front of you, facing
	## the way you look, and off it goes.
	if m.over or rat.stun > 0.0:
		return "Can't wind it up right now"
	if rat.throw_cd > 0.0:
		return "wait"
	if not m.unlimited() and int(rat.gadgets.get("windup", 0)) <= 0:
		return "Out of Wind-up Decoys"
	if walkers.size() >= Config.WINDUP_MAX_ACTIVE:
		return "Too many wind-ups marching already"
	var dir := Vector3(look.x, 0, look.z)
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
	var w := spawn(rat.team, rat.id, rat.class_id, rat.display_name, rat.position, dir)
	var ahead := rat.position + dir * 0.7
	if not w.body.blocked_at(ahead):
		w.body.position = ahead
	if not m.unlimited():
		rat.gadgets["windup"] = int(rat.gadgets["windup"]) - 1
	rat.throw_cd = 0.5
	rat.play_action("build", 0.3)
	m.fx.emit("windup", w.body.position, null)
	return ""


func spawn(team: int, owner_id: int, class_id: String, shown_name: String, at: Vector3, dir: Vector3, uid := -1) -> Walker:
	var w := Walker.new()
	w.uid = m.take_uid() if uid < 0 else uid
	w.team = team
	w.owner = owner_id
	w.dir = dir
	var b := Rat.new()
	b.setup(m.world, -w.uid, team, class_id, true)
	m.apply_modifiers(b)
	var owner := m.rat_by_id(owner_id)
	if owner != null:
		b.hat = owner.hat   # (it passes for its owner: same hat)
	b.display_name = shown_name
	b.carried = 1               # the cheese it shows off (its speed is a carrier's, too)
	b.position = at
	b.yaw = atan2(-dir.x, -dir.z)
	b.name = "Windup%d" % w.uid
	w.body = b
	w.net_pos = at
	m.add_child(b)
	walkers.append(w)
	m.windup_spawned.emit(b)
	return w


func remove(w: Walker) -> void:
	walkers.erase(w)
	if is_instance_valid(w.body):
		w.body.queue_free()


func try_bonk(rat: Rat, w: Walker) -> bool:
	## A bonk from the other team sets it off. (Your own team's bonks pass
	## through it, except in the lobby, where anything goes.)
	if m.over or w == null or rat.stun > 0.0 or rat.bonk_cd > m.cd_slack(rat):
		return false
	if w.team == rat.team and not m.lobby:
		return false
	if rat.center().distance_to(w.body.center()) > Config.BONK_RANGE + (0.7 if rat.net_peer != 0 else 0.0):
		return false
	rat.bonk_cd = Config.BONK_COOLDOWN
	rat.dig_cd = 1.0 / Config.DIG_RATE
	rat.play_action("attack", 0.3)
	if m.remote != null:
		m.remote.act("bonk_windup", [w.uid])
		return true
	explode(w)
	return true


func explode(w: Walker) -> void:
	if not walkers.has(w):
		return
	var at := w.body.center()
	remove(w)
	m.blast(at, Config.TNT_RADIUS, Config.TNT_POWER)


func on_blast(origin: Vector3, radius: float) -> void:
	## Wind-ups caught in a blast go off a moment later: chain reactions.
	for w in walkers:
		if w.body.center().distance_to(origin) < radius + 0.8:
			w.fuse = minf(w.fuse, 0.2 + 0.05 * float(w.uid % 4))


func step(dt: float) -> void:
	var due: Array[Walker] = []
	var lost: Array[Walker] = []
	for w in walkers:
		w.fuse -= dt
		if w.fuse <= BLINK and not w.warned:
			w.warned = true
			m.fx.emit("windup_warn", w.body.position, w.fuse)
		_march(w, dt)
		var b := w.body
		var feet := m.world.block_at(b.position + Vector3(0, 0.2, 0))
		if b.position.y < -6.0:
			lost.append(w)
		elif w.fuse <= 0.0 or feet == Blocks.LAVA or m.world.block_at(b.center()) == Blocks.LAVA:
			due.append(w)
		elif Blocks.is_trap(feet) and Blocks.trap_team(feet) != w.team:
			m.world.set_block(Vector3i(floori(b.position.x), floori(b.position.y + 0.2), floori(b.position.z)), Blocks.AIR)
			m.fx.emit("trap", b.position, null)
			due.append(w)       # snap, then boom
	for w in lost:
		remove(w)
	for w in due:
		explode(w)


func _march(w: Walker, dt: float) -> void:
	var b := w.body
	b.wish = w.dir
	b.jump_held = b.in_water       # paddle along the surface
	if w.hop:
		b.jump_pressed = true
		w.hop = false
	var before := b.position
	b.step(dt)
	b.yaw = atan2(-w.dir.x, -w.dir.z)
	if b.knock > 0.0 or not (b.on_floor or b.in_water):
		return
	var moved := Vector2(b.position.x - before.x, b.position.z - before.z).length()
	if moved > b.move_speed() * dt * 0.3:
		w.stuck = 0.0
		w.hopped = false
		return
	w.stuck += dt
	if w.stuck > 0.1 and not w.hopped:
		w.hop = true                # a step in the way: hop up it
		w.hopped = true
	elif w.stuck > 0.5:
		_turn(w)


func _turn(w: Walker) -> void:
	## A wall: turn to whichever side is open (alternating when both are),
	## or about, when it is boxed in.
	var b := w.body
	var left := Vector3(w.dir.z, 0, -w.dir.x)
	var right := -left
	var open_l := not b.blocked_at(b.position + left * 0.6)
	var open_r := not b.blocked_at(b.position + right * 0.6)
	w.turns += 1
	if open_l and open_r:
		w.dir = left if (w.turns + w.uid) % 2 == 0 else right
	elif open_l:
		w.dir = left
	elif open_r:
		w.dir = right
	else:
		w.dir = -w.dir
	w.stuck = 0.0
	w.hopped = false


# ---------------------------------------------------------------- online

func snapshot() -> Array:
	var out: Array = []
	for w in walkers:
		var b := w.body
		out.append([w.uid, w.team, b.class_id, b.display_name, b.position, b.vel, b.yaw,
			(1 if b.on_floor else 0) | (4 if b.in_water else 0), b.hat])
	return out


func apply(list: Array) -> void:
	## Replica: mirror the server's wind-ups (NetClient glides them along).
	var seen := {}
	for e: Array in list:
		var uid := int(e[0])
		seen[uid] = true
		var w := by_uid(uid)
		if w == null:
			var yaw := float(e[6])
			w = spawn(int(e[1]), -1, String(e[2]), String(e[3]), e[4], Vector3(-sin(yaw), 0, -cos(yaw)), uid)
		var b := w.body
		b.display_name = String(e[3])
		w.net_pos = e[4]
		b.vel = e[5]
		b.yaw = float(e[6])
		b.on_floor = (int(e[7]) & 1) != 0
		b.in_water = (int(e[7]) & 4) != 0
		if e.size() > 8:
			b.hat = Hats.clean(e[8])
	for w in walkers.duplicate():
		if not seen.has(w.uid):
			remove(w)


func glide(delta: float) -> void:
	## Replica: ease each body toward where the server last saw it.
	var k := 1.0 - exp(-delta * 14.0)
	for w in walkers:
		var b := w.body
		if b.position.distance_to(w.net_pos) > 4.0:
			b.position = w.net_pos
		else:
			b.position = b.position.lerp(w.net_pos + b.vel * 0.05, k)
