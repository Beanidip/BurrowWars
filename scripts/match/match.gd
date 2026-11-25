class_name Match
extends Node3D
## The authority. Every rule that changes the world, a score, a wallet or an
## inventory goes through a try_* / use_* method here, which validates the
## request before applying it. Controllers (human or bot) only ever *ask*.
## This is the seam where a network layer plugs in later: clients would send
## these same requests to the host and receive the resulting signals.

signal score_changed
signal toast(text: String, team: int)          # team -1 = everyone
signal fx(kind: String, pos: Vector3, data: Variant)
signal won(team: int)
signal rat_spawned(rat: Rat)
signal windup_spawned(body: Rat)   # a Wind-up Decoy's body, for a sprite

const TEAM_NAMES := ["Blue", "Red"]
## What the results screen tallies for every rat, in the order it lists them.
const STATS := ["banked", "mined", "stolen", "bonks", "bonked", "blocks", "tnt", "traps", "scrap"]
const STAT_NAMES := {"banked": "Cheese banked", "mined": "Cheese mined", "stolen": "Cheese stolen", "bonks": "Bonks landed",
	"bonked": "Times bonked", "blocks": "Blocks broken", "tnt": "TNT set off", "traps": "Traps placed", "scrap": "Scrap earned"}
const TRAP_GADGETS := ["trap", "sticky", "pitfall", "decoy", "squeaker"]   # (and the Wind-up Decoy)
## Emotes on the results screen: one per movement key, plus jump.
const EMOTES := ["cheer", "dance", "taunt", "flop", "flip"]
const EMOTE_TIME := 1.6
const BOT_NAMES := ["Nibbles", "Gouda", "Brie", "Scrabble", "Whiskers", "Cheddar", "Pip", "Rind"]


class Pickup:
	var uid := 0
	var kind := "cheese"       # "cheese" | "stash"
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var lock_id := -1          # rat that may not collect this yet
	var lock_t := 0.0
	var mats: Dictionary = {}
	var wet := false           # in water (for splashes going in and out)
	var from_team := -1        # cheese a rat dropped: its team (the other team picking it up stole it)


var world: VoxelWorld
var settings: Dictionary = {}
var free_mode := false
var infinite := false               # nobody runs out of anything: scrap, materials, gadgets (the lobby cheat code)
var perf := [0, 0, 0]               # step() timing for server health lines: [usec total, usec worst, steps]
var infinite_next := false          # (lobby) the host entered the code: the match it starts is infinite
var lobby := false                  # the playground everyone waits in before a hosted match
var lobby_props: Dictionary = {}    # Vector3i -> true: playground fixtures nobody can break
var lobby_left := -1.0              # seconds until a server's lobby ends; -1 = when the host says
var _bull_cd: Dictionary = {}       # rat id -> seconds before it can score another bullseye
var goal := 8
var scores: Array[int] = [0, 0]
var rats: Array[Rat] = []
var bots: Array[BotBrain] = []
var pickups: Array[Pickup] = []
var markers: Array[Dictionary] = []
var tnt: Dictionary = {}        # Vector3i -> {"owner": rat id, "fuse": seconds or -1}
var gate_damage: Dictionary = {}
var trap_owner: Dictionary = {}      # Vector3i -> team that placed the trap there
var stash_hits: Dictionary = {}      # Vector3i -> TNT blasts a team stash has taken
var bubbles: Dictionary = {}         # Vector3i -> seconds before that Bubble Shoes bubble pops
var squeaks: Dictionary = {}         # Vector3i -> squeaks a Squeaker Pad has left
var squeak_rest: Dictionary = {}     # Vector3i -> seconds before that pad can squeak again
var decoys: Dictionary = {}          # Vector3i -> team of a Cheese Decoy there (bots of the other team fall for them)
# Teleporters: each rat owns at most one entrance and one exit. One way, team only, no cheese.
var tele_in: Dictionary = {}         # rat id -> cell of its entrance
var tele_out: Dictionary = {}        # rat id -> cell of its exit
var tele_owner: Dictionary = {}      # pad cell -> rat id
var tele_charge: Dictionary = {}     # entrance cell -> seconds until it can send again
var tele_net: Array = []             # replica: the pads, as the server last sent them (see tele_pads)
var _tele_wait: Dictionary = {}      # rat id -> seconds stood on a ready entrance (-1: told why not, this visit)
var guard_t: Array[float] = [0.0, 0.0]   # seconds each team has had a rat standing in its own base, without a break
## Each team's shared pool (scrap and building materials), reached at any of
## the team's stashes or at base. It survives its stashes being blown up.
var team_bank: Array[Dictionary] = [{"scrap": 0, "dirt": 0, "stone": 0, "ice": 0, "obsidian": 0},
	{"scrap": 0, "dirt": 0, "stone": 0, "ice": 0, "obsidian": 0}]
var lava: LiquidFlow
var water: LiquidFlow
var over := false
var winner := -1
var next_in := -1.0             # seconds until the server starts the next round (-1: when the host says)
var time := 0.0
var auto_step := true
var visual := true

# Networking (scripts/net). A client runs a *replica* Match: it draws the
# world and moves its own rat, but every request goes to the server through
# `remote`, and everything else arrives from the server.
var replica := false
var remote: Object = null       # NetClient on a replica, else null
var networked := false          # true on a server or a client (never pauses)

var dynamite: DynamiteSystem
var windup: WindupSystem
var siege: SiegeSystem

var _next_uid := 1
var _rng := RandomNumberGenerator.new()


func setup(match_settings: Dictionary, with_visuals := true, as_replica := false) -> void:
	settings = match_settings
	replica = as_replica
	visual = with_visuals
	lobby = settings.get("mode", "race") == "lobby"
	free_mode = settings.get("mode", "race") == "free" or lobby   # everything is free in the lobby too
	infinite = bool(settings.get("infinite", false)) and not lobby
	infinite_next = lobby and bool(settings.get("infinite", false))
	goal = int(settings.get("goal", 8))
	var map_seed := int(settings.get("seed", 1))
	_rng.seed = map_seed * 7919 + 13
	world = VoxelWorld.new()
	world.visual = with_visuals
	world.name = "World"
	add_child(world)
	dynamite = DynamiteSystem.new(self)
	windup = WindupSystem.new(self)
	siege = SiegeSystem.new(self)
	lava = LiquidFlow.lava(self)
	water = LiquidFlow.water(self)
	if not replica:   # a replica only mirrors the server's terrain changes
		world.block_changed.connect(lava.on_block_changed)
		world.block_changed.connect(water.on_block_changed)
		world.block_changed.connect(_on_block_changed)
		world.block_changed.connect(siege.on_block_changed)
	var need := 0 if free_mode else MapGenerator.min_cheese(goal)
	var map_file := String(settings.get("map_file", ""))
	var imported := false
	if map_file != "" and not replica and not lobby:
		imported = world.load_from(map_file)
		if not imported:
			Log.warn("could not load map %s; generating one instead" % map_file)
	if replica:
		pass   # an online player's world arrives whole from the server (NetClient)
	elif lobby:
		lobby_props = MapGenerator.lobby(world)
		for cell: Vector3i in MapGenerator.LOBBY_CANNONS:
			siege.add_fixed(cell, Blocks.CANNON, MapGenerator.lobby_yaw())
	elif imported:
		if not free_mode:
			MapGenerator.prepare_imported(world, map_seed, need)
		siege.from_save(world.loaded_extra.get("machines", []))
	else:
		MapGenerator.generate(world, map_seed, need)
	for cell: Vector3i in _find_blocks(Blocks.TNT):
		tnt[cell] = {"owner": -1, "fuse": -1.0}
	for cell: Vector3i in _find_blocks(Blocks.BUBBLE):
		bubbles[cell] = Config.BUBBLE_TIME     # bubbles in a loaded map still pop
	for id: int in [Blocks.DECOY_BLUE, Blocks.DECOY_RED]:
		for cell: Vector3i in _find_blocks(id):
			decoys[cell] = Blocks.trap_team(id)
	Log.info("match setup: mode=%s seed=%d goal=%d cheese_on_map=%d" % [
		settings.get("mode", "race"), map_seed, goal, world.cheese_cells.size()])


func _on_block_changed(cell: Vector3i, _old: int, new_id: int) -> void:
	# a highway is only a surface layer: it goes when the block under it goes
	var above := cell + Vector3i(0, 1, 0)
	if Blocks.SOLID[new_id] == 0 and world.get_cell(above) == Blocks.HIGHWAY:
		world.set_block(above, Blocks.AIR)
	gate_damage.erase(cell)
	trap_owner.erase(cell)
	if tele_owner.has(cell):   # a teleporter pad dug up, blown up or built over
		var owner := int(tele_owner[cell])
		tele_owner.erase(cell)
		tele_charge.erase(cell)
		if tele_in.get(owner) == cell:
			tele_in.erase(owner)
		if tele_out.get(owner) == cell:
			tele_out.erase(owner)
	stash_hits.erase(cell)
	if not Blocks.is_squeaker(new_id):
		squeaks.erase(cell)          # a new pad in this cell starts with all its squeaks
		squeak_rest.erase(cell)
	if Blocks.is_decoy(new_id):
		decoys[cell] = Blocks.trap_team(new_id)
	else:
		decoys.erase(cell)


func _find_blocks(id: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var i := world.data.find(id)
	while i >= 0:
		out.append(Vector3i(i % VoxelWorld.SX, i / (VoxelWorld.SX * VoxelWorld.SZ), (i / VoxelWorld.SX) % VoxelWorld.SZ))
		i = world.data.find(id, i + 1)
	return out


func spawn_rat(team: int, class_id: String, is_bot: bool, fixed_id := -1) -> Rat:
	var rat := Rat.new()
	var new_id := fixed_id
	if new_id < 0:
		new_id = 1
		for r in rats:
			new_id = maxi(new_id, r.id + 1)
	rat.setup(world, new_id, team, class_id, is_bot)
	var slot := 0
	for r in rats:
		if r.team == team:
			slot += 1
	rat.position = spawn_point(team, slot)
	rat.yaw = MapGenerator.lobby_yaw() if lobby else MapGenerator.spawn_yaw(team)
	rat.display_name = BOT_NAMES[(rat.id * 3 + team) % BOT_NAMES.size()] if is_bot else "You"
	rat.name = "Rat%d" % rat.id
	rat.scrap = 6
	if free_mode:
		rat.flying = false
		rat.free_build = true
	if lobby:
		rat.gear = "jetpack"     # everyone flies in the playground
	add_child(rat)
	rats.append(rat)
	if is_bot and not replica:
		bots.append(BotBrain.new(self, rat, _rng.randi()))
	rat_spawned.emit(rat)
	return rat


func make_bot(rat: Rat) -> void:
	## A rat whose player left (or a fresh seat): a bot takes over.
	rat.is_bot = true
	rat.net_peer = 0
	rat.hat = ""
	rat.display_name = BOT_NAMES[(rat.id * 3 + rat.team) % BOT_NAMES.size()]
	for b in bots:
		if b.rat == rat:
			return
	bots.append(BotBrain.new(self, rat, _rng.randi()))


func make_player(rat: Rat, peer: int, player_name: String) -> void:
	## A networked player takes over a rat (normally one a bot was driving).
	for i in range(bots.size() - 1, -1, -1):
		if bots[i].rat == rat:
			bots.remove_at(i)
	rat.is_bot = false
	rat.net_peer = peer
	rat.display_name = player_name
	rat.wish = Vector3.ZERO
	rat.jump_held = false
	rat.down_held = false


func remove_rat(rat: Rat) -> void:
	siege.release(rat)
	if rat.carried > 0:
		_drop(rat, rat.carried, 0.0)
	for i in range(bots.size() - 1, -1, -1):
		if bots[i].rat == rat:
			bots.remove_at(i)
	rats.erase(rat)
	rat.queue_free()


func rat_by_id(rat_id: int) -> Rat:
	for r in rats:
		if r.id == rat_id:
			return r
	return null


func in_base(rat: Rat, team := -1) -> bool:
	var t := rat.team if team < 0 else team
	return MapGenerator.base_zone(t).grow(0.01).has_point(rat.position + Vector3(0, 0.3, 0))


func multiplier() -> float:
	## ScrapMultiplier = 1 + (combined cheese / goal) x growth bonus.
	return 1.0 + float(scores[0] + scores[1]) / float(maxi(goal, 1)) * float(settings.get("growth", Config.GROWTH_BONUS))


# ---------------------------------------------------------------- stepping

func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(dt: float) -> void:
	## One tick of the match, timed for the server's health lines.
	var t0 := Time.get_ticks_usec()
	_tick(dt)
	var us := Time.get_ticks_usec() - t0
	perf[0] += us
	perf[1] = maxi(perf[1], us)
	perf[2] += 1


func _tick(dt: float) -> void:
	time += dt
	for r in rats:
		r.emote_t = maxf(0.0, r.emote_t - dt)
	if over and not replica:
		_bots_emote(dt)
	if replica:
		# Only our own rat is simulated here; the server sends the rest.
		for r in rats:
			if r.net_local:
				if over:
					r.wish = Vector3.ZERO
					r.jump_pressed = false
					r.dash_pressed = false
				r.step(dt)
				if remote != null:   # the server plays these for everyone
					for kind: String in _motion_fx(r):
						remote.note_fx(kind)
					if r.pounded:
						remote.act("ground_pound", [r.pound_cell])
					if r.wants_bubble:
						remote.act("place_bubble", [r.bubble_cell])
		return
	for r in rats:
		if r.net_peer != 0:
			# a remote player's own game moves this body; we keep its timers.
			# Changed since the server last agreed with their game? Then the
			# server did it between ticks (their respawn request, another
			# player's bonk): NetServer tells them.
			if not r.net_pre.is_empty() and net_state(r) != r.net_pre:
				r.net_dirty = true
			r.step_timers(dt)
			r.net_pre = net_state(r)
	if not over:
		for b in bots:
			b.think(dt)
	for r in rats:
		if over:
			r.wish = Vector3.ZERO
			r.jump_pressed = false
			r.dash_pressed = false
		if r.net_peer == 0:
			r.step(dt)
			for kind: String in _motion_fx(r):
				fx.emit(kind, r.position, null)
			if r.pounded:
				ground_pound(r, r.pound_cell)
			if r.wants_bubble:
				place_bubble(r, r.bubble_cell)
		_check_rat_hazards(r, dt)
		_tele_check(r, dt)
		_check_raid(r, dt)
	if lobby:
		_lobby_step(dt)
	for t in 2:
		var guarded := false
		for r in rats:
			if r.team == t and in_base(r, t):
				guarded = true
				break
		guard_t[t] = guard_t[t] + dt if guarded else 0.0
	_step_bubbles(dt)
	for cell: Vector3i in tele_charge.keys():
		tele_charge[cell] = maxf(0.0, float(tele_charge[cell]) - dt)
	for cell: Vector3i in squeak_rest.keys():
		squeak_rest[cell] = maxf(0.0, float(squeak_rest[cell]) - dt)
	_step_pickups(dt)
	_step_tnt(dt)
	dynamite.step(dt)
	windup.step(dt)
	_drop_crumbs()
	siege.step(dt)
	lava.step(dt)
	water.step(dt)
	for i in range(markers.size() - 1, -1, -1):
		markers[i]["ttl"] = float(markers[i]["ttl"]) - dt
		if float(markers[i]["ttl"]) <= 0.0:
			markers.remove_at(i)


static func _motion_fx(r: Rat) -> Array[String]:
	## Effects a rat's own movement set off this step (springs, jetpack, dash,
	## jumps, hard landings). Online, a player's game reports these instead.
	var out: Array[String] = []
	if r.landed_on_spring:
		out.append("spring")
	if r.gear_fired:
		out.append("jetpack")
	if r.dashed:
		out.append("dash")
	if r.jumped:
		out.append("jump")
	if r.landed_hard:
		out.append("land")
	if r.splashed_in:
		out.append("splash")
	if r.splashed_out:
		out.append("splash_out")
	if r.shield_raised:
		out.append("shield")
	return out


var _crumb_at: Dictionary = {}   # rat id (or -uid of a wind-up) -> where it last dropped a crumb


func _drop_crumbs() -> void:
	## Cheese crumbs: everyone carrying cheese leaves a trail on the ground,
	## one crumb every Config.CRUMB_EVERY blocks, that anyone can follow.
	## Wind-up Decoys leave one too. (The view draws them; they're cosmetic.)
	for r in rats:
		_crumb(r.id, r, r.carried > 0 and not r.flying)
	for w in windup.walkers:
		_crumb(-w.uid, w.body, true)


func _crumb(key: int, body: Rat, carrying: bool) -> void:
	if not carrying:
		_crumb_at.erase(key)
		return
	# only on dry ground: hold the count through jumps, falls and swims
	if body.in_water or not world.solid_point(body.position - Vector3(0, 0.12, 0)):
		return
	if not _crumb_at.has(key):
		_crumb_at[key] = body.position    # picked it up: the first crumb comes a few steps on
		return
	if body.position.distance_to(_crumb_at[key]) < Config.CRUMB_EVERY:
		return
	_crumb_at[key] = body.position
	fx.emit("crumb", body.position, null)


func raise_shield(rat: Rat) -> bool:
	## Online, a player's game says it raised its shield: the authority checks
	## the gear and cooldown, then raises it here too (bonks are judged here).
	if rat.gear != "shield" or rat.gear_cd > cd_slack(rat) + 0.3:
		return false
	rat.shield_t = Config.SHIELD_TIME
	rat.gear_cd = Config.SHIELD_TIME + Config.SHIELD_COOLDOWN
	return true


static func net_state(r: Rat) -> Array:
	## The parts of a rat that its player's game simulates. When the authority
	## changes any of them (bonk, blast, respawn, trap...) the player is told.
	return [r.position, r.vel, r.stun, r.knock, r.slow, r.stamina, r.flying]


static func wire_aim(aim: Dictionary) -> Dictionary:
	## The parts of an aim a server needs (and NetServer._aim checks).
	var out := {}
	for k: String in ["cell", "normal", "point"]:
		if aim.has(k):
			out[k] = aim[k]
	return out


func cd_slack(r: Rat) -> float:
	## Network jitter allowance on short cooldowns for remote players.
	return 0.08 if r.net_peer != 0 else 0.0


func set_equipped(rat: Rat, gadget: String) -> void:
	if remote != null:
		rat.equipped = gadget
		remote.act("set_equipped", [gadget])
		return
	if gadget == "" or ClassDefs.GADGET_NAME.has(gadget):
		rat.equipped = gadget


func _lava_touch(r: Rat) -> void:
	## Lava: the first touch bounces you out. A second touch soon after
	## bounces you again, spills what you carry right there, and sends you home.
	siege.release(r)
	var away := Vector3(r.vel.x, 0, r.vel.z)
	away = -away.normalized() * 3.0 if away.length() > 0.2 else Vector3.ZERO
	r.vel = away + Vector3(0, 11.0, 0)
	r.knock = 0.35
	r.on_floor = false
	r.lava_grace = 0.8
	fx.emit("lava", r.position, null)
	if r.lava_strikes == 0:
		r.lava_strikes = 1
		r.lava_reset = 8.0
		toast.emit("Ouch! %s bounced off the lava. Touch it again and it's back to base." % r.display_name, r.team)
		return
	r.lava_strikes = 0
	drop_everything(r)
	r.lava_home = 0.7
	toast.emit("%s got a hot tail and dropped everything!" % r.display_name, r.team)


func _check_rat_hazards(r: Rat, dt: float) -> void:
	if over:
		return
	var here := world.block_at(r.position + Vector3(0, 0.2, 0))
	if r.lava_home >= 0.0:
		r.lava_home -= dt
		if r.lava_home < 0.0:
			respawn(r)
			toast.emit("%s is back at base, nursing a hot tail." % r.display_name, r.team)
			return
	r.lava_grace = maxf(0.0, r.lava_grace - dt)
	r.lava_reset = maxf(0.0, r.lava_reset - dt)
	if r.lava_reset <= 0.0:
		r.lava_strikes = 0
	if here == Blocks.LAVA and not r.flying and r.lava_grace <= 0.0 and r.lava_home < 0.0:
		_lava_touch(r)
		return
	if r.position.y < -4.0:
		respawn(r)
		return
	if Blocks.is_squeaker(here) and not r.flying and Blocks.trap_team(here) != r.team:
		_squeak(r, Vector3i(floori(r.position.x), floori(r.position.y + 0.2), floori(r.position.z)), here)
	if Blocks.is_trap(here) and not r.flying:
		var trap_team := 0 if here == Blocks.TRAP_BLUE else 1
		if trap_team != r.team:
			world.set_block(Vector3i(floori(r.position.x), floori(r.position.y + 0.2), floori(r.position.z)), Blocks.AIR)
			r.stun = 1.5
			r.vel = Vector3(0, 4.0, 0)
			if r.carried > 0:
				_drop(r, 1, Config.BONK_PICKUP_LOCK)
			fx.emit("trap", r.position, null)
			toast.emit("SNAP! %s stepped on a mouse trap." % r.display_name, -1)
	if r.carried > 0 and not free_mode and in_base(r):
		_deposit(r)


func _check_raid(r: Rat, dt: float) -> void:
	## Vault raid: stand in the ENEMY base for RAID_TIME to lift one banked
	## cheese (their score drops, you carry it). Any defender standing in
	## their own base freezes the raid, and everyone is warned when it starts.
	## The cheese is moved, never created.
	var enemy := 1 - r.team
	if over or free_mode or scores[enemy] <= 0 or r.carried >= r.capacity() or r.stun > 0.0 or r.knock > 0.0 \
			or r.flying or not in_base(r, enemy):
		r.raid_t = 0.0
		return
	for d in rats:
		if d.team == enemy and d.stun <= 0.0 and in_base(d, enemy):
			return   # contested: progress is frozen while a defender is home
	if r.raid_t == 0.0:
		toast.emit("ALARM! %s is raiding the %s vault!" % [r.display_name, TEAM_NAMES[enemy]], -1)
		var zone := MapGenerator.base_zone(enemy)
		add_marker(zone.position + Vector3(zone.size.x * 0.5, 2.0, zone.size.z * 0.5), "RAID!", enemy, 8.0)
		fx.emit("alarm", r.position, enemy)
	r.raid_t += dt
	if r.raid_t >= Config.RAID_TIME:
		r.raid_t = 0.0
		scores[enemy] -= 1
		r.carried += 1
		tally(r, "stolen")
		score_changed.emit()
		fx.emit("pickup", r.position, r.team)
		toast.emit("%s stole a cheese from the %s vault!" % [r.display_name, TEAM_NAMES[enemy]], -1)


func _deposit(r: Rat) -> void:
	var n := r.carried
	r.carried = 0
	tally(r, "banked", n)
	scores[r.team] += n
	score_changed.emit()
	fx.emit("deposit", r.position, r.team)
	toast.emit("%s banked %d cheese for %s!  (scrap x%.2f)" % [r.display_name, n, TEAM_NAMES[r.team], multiplier()], -1)
	if scores[r.team] >= goal and not over:
		over = true
		winner = r.team
		won.emit(r.team)
		Log.info("match won by %s at t=%.1fs, score %d-%d" % [TEAM_NAMES[r.team], time, scores[0], scores[1]])


# ---------------------------------------------------------------- digging

func try_dig(rat: Rat, cell: Vector3i) -> bool:
	if over or rat.stun > 0.0 or rat.dig_cd > cd_slack(rat):
		return false
	if remote != null:
		rat.dig_cd = 1.0 / Config.DIG_RATE
		rat.play_action("dig", 0.28)
		remote.act("try_dig", [cell])
		return true
	if not VoxelWorld.in_bounds(cell):
		return false
	if (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) > Config.DIG_REACH + 1.0:
		return false
	var id := world.get_cell(cell)
	if Blocks.TARGETABLE[id] == 0:
		return false
	rat.dig_cd = 1.0 / Config.DIG_RATE
	rat.play_action("dig", 0.28)
	if lobby and lobby_props.has(cell):
		fx.emit("clang", Vector3(cell), id)   # part of the playground
		return false
	var layer := world.layered_gate(cell)
	if layer >= 0 and layer != rat.team:
		fx.emit("clang", Vector3(cell), id)   # the gadget is behind the other team's gate
		return false
	if id == Blocks.TNT:
		light_tnt(cell, 2.0)
		return true
	if Blocks.is_decoy(id):
		_dig_decoy(rat, cell, id)
		return true
	if Blocks.is_teleporter(id) and int(tele_owner.get(cell, -1)) == rat.id:
		world.set_block(cell, Blocks.AIR)    # your own pad: straight back into your pack
		_give_gadget(rat, "teleporter", 1)
		fx.emit("break", Vector3(cell), id)
		return true
	if Blocks.is_gate(id):
		if Blocks.gate_team(id) == rat.team:
			world.set_block(cell, Blocks.AIR)
			_give_gadget(rat, "gate", 1)
			fx.emit("break", Vector3(cell), id)
			return true
		fx.emit("clang", Vector3(cell), id)
		return false
	if Blocks.is_team_block(id) and not Blocks.solid_for(id, rat.team):
		fx.emit("clang", Vector3(cell), id)   # the other team's block: untouchable
		return false
	if Blocks.is_machine(id):
		var why := siege.try_pickup(rat, cell)
		if why != "":
			toast.emit(why, rat.team)
			fx.emit("clang", Vector3(cell), id)
			return false
		return true
	if Blocks.HITS[id] == 0:
		fx.emit("clang", Vector3(cell), id)
		return false
	var power := 99 if free_mode else 1
	_damage(rat, cell, power)
	_brush(rat, cell, int(rat.cls["brush"]), power)
	return true


func _brush(rat: Rat, cell: Vector3i, brush: int, power: int) -> void:
	## Wide dig around a cell. Only chews natural terrain (never gadgets or
	## cheese) and never the floor under the digger unless they aim downward.
	var feet_y := rat.feet_cell().y
	for dx in range(-brush, brush + 1):
		for dy in range(-brush, brush + 1):
			for dz in range(-brush, brush + 1):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				var c := cell + Vector3i(dx, dy, dz)
				if c.y < feet_y and cell.y >= feet_y:
					continue
				var nid := world.get_cell(c)
				if nid == Blocks.DIRT or nid == Blocks.GRASS or nid == Blocks.STONE or nid == Blocks.LEAVES:
					_damage(rat, c, power)


func _damage(rat: Rat, cell: Vector3i, power: int, quiet := false) -> bool:
	## Shared excavation rule for paws, blasts, cannonballs, cranes and blades.
	## Returns true when the block broke.
	var id := world.get_cell(cell)
	var hits := hits_for(rat, cell, id)
	if hits <= 0 or power <= 0 or not VoxelWorld.in_bounds(cell):
		return false
	if lobby and lobby_props.has(cell):
		return false   # the playground's fixtures stay put
	var layer := world.layered_gate(cell)
	if layer >= 0 and (rat == null or rat.team != layer):
		return false   # only the gate's own team can take a gadget out of it
	var total := int(world.damage.get(cell, 0)) + power
	if total < hits:
		world.damage[cell] = total
		if not quiet:
			fx.emit("hit", Vector3(cell), {"id": id, "ratio": float(total) / float(hits)})
		return false
	_break(rat, cell, id, quiet)
	return true


func _spring_beside(cell: Vector3i) -> Variant:
	## Centre of a spring in one of the 8 cells around `cell` (same level), or null.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dz != 0) and world.get_cell(cell + Vector3i(dx, 0, dz)) == Blocks.SPRING:
				return Vector3(cell + Vector3i(dx, 0, dz)) + Vector3(0.5, 0.0, 0.5)
	return null


func hits_for(rat: Rat, cell: Vector3i, id: int) -> int:
	## Dig hits a block takes from this rat (null = a blast or machine). Placed
	## traps are quick for their own team to clear and tough for everyone else.
	if Blocks.is_placed_trap(id) or Blocks.is_teleporter(id):
		var owner := int(trap_owner.get(cell, Blocks.tele_team(id) if Blocks.is_teleporter(id) else Blocks.trap_team(id)))
		return Config.TRAP_HITS_OWN if rat != null and owner >= 0 and rat.team == owner else Config.TRAP_HITS_ENEMY
	return int(Blocks.HITS[id])


func _break(rat: Rat, cell: Vector3i, id: int, quiet := false) -> void:
	# A carved block is only worth the microvoxels still in it; paint dabs in
	# it were paid in dirt and come back as dirt.
	var carved := world.micro_count(cell) if world.has_micro(cell) else -1
	var dabs := 0
	if carved >= 0:
		var mk: PackedByteArray = world.micro[cell]
		dabs = mk.size() - mk.count(0) - mk.count(1)
	world.set_block(cell, Blocks.AIR)
	tnt.erase(cell)
	if not quiet:
		fx.emit("break", Vector3(cell), id)
	var drop := Blocks.drop(id)
	tally(rat, "blocks")
	if drop == "cheese":
		spawn_pickup("cheese", Vector3(cell) + Vector3(0.5, 0.3, 0.5), Vector3(0, 2.5, 0))
		tally(rat, "mined")
	elif rat == null:
		return
	elif drop == "scrap":
		var gain := roundi(Config.BASE_SCRAP_PER_BLOCK * multiplier())
		rat.scrap += gain
		tally(rat, "scrap", gain)
		fx.emit("scrap", Vector3(cell), gain)
	elif drop.begins_with("mat:"):
		var m := drop.substr(4)
		if carved >= 0:
			_refund_micro(rat, m, carved - dabs)
			if dabs > 0:
				_refund_micro(rat, "dirt", dabs)
		else:
			rat.mats[m] = mini(int(rat.mats[m]) + 1, 99)
	elif drop.begins_with("item:"):
		_give_gadget(rat, drop.substr(5), 1)


func _give_gadget(rat: Rat, gadget: String, n: int) -> void:
	rat.gadgets[gadget] = mini(int(rat.gadgets.get(gadget, 0)) + n, Config.STACK_MAX)
	if rat.equipped == "":
		rat.equipped = gadget


# ---------------------------------------------------------------- placing

func can_place_at(rat: Rat, cell: Vector3i, block: int, reach := -1.0, replace := false) -> String:
	## Returns "" when legal, otherwise a short human-readable reason.
	## `replace` is for gadgets laid INTO an existing floor block.
	if over:
		return "Match is over"
	if not VoxelWorld.in_bounds(cell) or cell.y < 1:
		return "Out of bounds"
	if (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) > (reach if reach > 0.0 else Config.DIG_REACH + 1.5):
		return "Too far"
	var cur := world.get_cell(cell)
	if not replace and cur != Blocks.AIR and cur != Blocks.WATER and cur != Blocks.LAVA:
		return "Space is occupied"
	if MapGenerator.in_any_base(cell, 0.5):
		return "Bases are protected"
	if replace:
		return ""
	for r in rats:
		if Blocks.solid_for(block, r.team) and r.overlaps_cell(cell):
			return "A rat is in the way"
	return ""


func try_place_mat(rat: Rat, cell: Vector3i, mat: String) -> String:
	if remote != null:
		return remote.act("try_place_mat", [cell, mat])
	if not ClassDefs.MAT_BLOCK.has(mat):
		return "Unknown material"
	if not unlimited() and int(rat.mats.get(mat, 0)) <= 0:
		return "No %s left - dig some first" % mat
	var block: int = ClassDefs.MAT_BLOCK[mat]
	var why := can_place_at(rat, cell, block)
	if why != "":
		return why
	if not unlimited():
		rat.mats[mat] = int(rat.mats[mat]) - 1
	world.set_block(cell, block)
	rat.play_action("build", 0.3)
	fx.emit("place", Vector3(cell), block)
	return ""


func try_place_paint(rat: Rat, cell: Vector3i, color: int) -> String:
	## A full block in one of the palette colours (glass included). Painted
	## blocks are dyed dirt: each costs one dirt, or one stone when you have no
	## dirt, and digging one gives a dirt back.
	if remote != null:
		return remote.act("try_place_paint", [cell, color])
	if color < 0 or color >= Blocks.PALETTE_SIZE:
		return "Unknown colour"
	var pay := paint_material(rat)
	if not unlimited() and pay == "":
		return "Painted blocks are made from dirt or stone - dig some first"
	var block := Blocks.PAINT_0 + color
	var why := can_place_at(rat, cell, block)
	if why != "":
		return why
	if not unlimited():
		rat.mats[pay] = int(rat.mats[pay]) - 1
	world.set_block(cell, block)
	rat.play_action("build", 0.3)
	fx.emit("place", Vector3(cell), block)
	return ""


func try_paint_block(rat: Rat, cell: Vector3i, color: int) -> String:
	## Left click with the Paint slot: dye the block you hit. Dirt and grass
	## become a painted block (same toughness, still gives a dirt back);
	## painted blocks and glass just change colour. Free, at dig speed.
	if over or rat.stun > 0.0 or rat.dig_cd > cd_slack(rat):
		return "wait"
	if lobby and lobby_props.has(cell):
		return "That's part of the playground"
	if remote != null:
		rat.dig_cd = 1.0 / Config.DIG_RATE
		rat.play_action("build", 0.25)
		return remote.act("try_paint_block", [cell, color])
	if color < 0 or color >= Blocks.PALETTE_SIZE:
		return "Unknown colour"
	if not VoxelWorld.in_bounds(cell) or (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) > Config.DIG_REACH + 1.0:
		return "Too far"
	var id := world.get_cell(cell)
	if not paintable(cell):
		return "Only dirt and painted blocks take paint" if not world.has_micro(cell) else "Carved blocks keep their own colours - use the chisel to add paint"
	if MapGenerator.in_any_base(cell, 0.5):
		return "Bases are protected"
	if world.layered_gate(cell) >= 0:
		return "That is inside a gate"
	rat.dig_cd = 1.0 / Config.DIG_RATE
	var block := Blocks.PAINT_0 + color
	if block == id:
		return ""
	world.set_block(cell, block)
	rat.play_action("build", 0.25)
	fx.emit("place", Vector3(cell), block)
	return ""


func paintable(cell: Vector3i) -> bool:
	## Left-click paint only recolours dirt-strength blocks (dirt, grass and
	## painted blocks), so it can never make a block weaker or stronger.
	var id := world.get_cell(cell)
	return (id == Blocks.DIRT or id == Blocks.GRASS or Blocks.is_paint(id)) and not world.has_micro(cell)


func paint_material(rat: Rat, micro := 0) -> String:
	## What a painted block (or `micro` painted microvoxels) is paid with:
	## dirt first, stone when out of dirt. "" when the rat has neither.
	if micro > 0:
		if _micro_available(rat, "dirt") >= micro:
			return "dirt"
		return "stone" if _micro_available(rat, "stone") >= micro else ""
	if int(rat.mats.get("dirt", 0)) > 0:
		return "dirt"
	return "stone" if int(rat.mats.get("stone", 0)) > 0 else ""


func hit_gate(cell: Vector3i, amount: int) -> void:
	## Gates have their own toughness: Config.GATE_HP wrecking-ball hits, or two TNT blasts.
	gate_damage[cell] = int(gate_damage.get(cell, 0)) + amount
	if int(gate_damage[cell]) < Config.GATE_HP:
		var gid := world.get_cell(cell)
		fx.emit("hit", Vector3(cell), {"id": gid if Blocks.is_gate(gid) else (Blocks.GATE_BLUE if world.gate_at(cell) == 0 else Blocks.GATE_RED),
			"ratio": float(gate_damage[cell]) / float(Config.GATE_HP)})   # cracks show how close it is to breaking
	if int(gate_damage[cell]) >= Config.GATE_HP:
		gate_damage.erase(cell)
		var id := world.get_cell(cell)
		world.set_gate_layer(cell, -1)   # a broken gate takes whatever it held with it
		world.set_block(cell, Blocks.AIR)
		fx.emit("break", Vector3(cell), id)


func try_place_gadget(rat: Rat, cell: Vector3i, gadget: String = "", dir := Vector3.ZERO, reach := -1.0, replace := false,
		into_gate := false) -> String:
	## `dir` (optional) is the direction a conveyor should run; default is the
	## rat's facing. `replace` lays the gadget into the block at `cell`;
	## `into_gate` puts it inside your own team gate at `cell`.
	var g := gadget if gadget != "" else rat.equipped
	if g == "" or not ClassDefs.GADGET_NAME.has(g):
		return "Nothing equipped - buy gadgets at the workshop (B)"
	if g == "dynamite" or g == "impulse":
		return "%s is thrown, not placed" % ClassDefs.GADGET_NAME[g]
	if g == "windup":
		return "A Wind-up Decoy is set down with Q"
	if g == "teleporter":
		return _place_teleporter(rat, cell, reach)
	if not unlimited() and int(rat.gadgets.get(g, 0)) <= 0:
		return "Out of %s" % ClassDefs.GADGET_NAME[g]
	var facing := Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
	if absf(dir.x) + absf(dir.z) > 0.5:
		facing = Vector3(dir.x, 0, dir.z)
	var block := ClassDefs.gadget_block(g, rat.team, facing)
	var old := world.get_cell(cell)
	if block == Blocks.HIGHWAY and Blocks.SOLID[world.get_cell(cell + Vector3i(0, -1, 0))] == 0:
		return "A highway needs a floor to lie on"
	if replace and not _is_floor_material(cell):
		return "Can't lay that into %s" % Blocks.block_name(old)
	if into_gate:
		if not Blocks.is_gate(old) or Blocks.gate_team(old) != rat.team:
			return "Gadgets only go inside your own team's gate"
		if not ClassDefs.GATE_GADGETS.has(g):
			return "%s can't go inside a gate" % ClassDefs.GADGET_NAME[g]
	var why := can_place_at(rat, cell, block, reach, replace or into_gate)
	if why != "":
		return why
	if not unlimited():
		rat.gadgets[g] = int(rat.gadgets[g]) - 1
		if replace:   # the floor block you swapped out goes into your stash, as if dug
			var mat := Blocks.mat_of(old)
			rat.mats[mat] = mini(int(rat.mats[mat]) + 1, 99)
	if into_gate:
		world.set_gate_layer(cell, rat.team)
	world.set_block(cell, block)
	if block == Blocks.TNT:
		tnt[cell] = {"owner": rat.id, "fuse": -1.0}
	elif Blocks.is_placed_trap(block):
		trap_owner[cell] = rat.team
	if TRAP_GADGETS.has(g):
		tally(rat, "traps")
	elif Blocks.is_machine(block):
		siege.register(cell, block, rat)
	rat.play_action("build", 0.3)
	fx.emit("place", Vector3(cell), block)
	return ""


func try_use_equipped(rat: Rat, aim: Dictionary, look: Vector3, gentle: bool, dir := Vector3.ZERO) -> String:
	## The Q key: throw Mobile TNT, or place the equipped gadget at the aim.
	if remote != null:
		return remote.act("try_use_equipped", [wire_aim(aim), look, gentle, dir])
	if rat.equipped == "dynamite" or rat.equipped == "impulse":
		return dynamite.try_throw(rat, look, gentle, rat.equipped)
	if rat.equipped == "windup":
		var why := windup.try_place(rat, look)
		if why == "":
			tally(rat, "traps")
		return why
	if aim.is_empty():
		return "Aim at a surface to place a gadget"
	var aimed := Vector3i(aim["cell"])
	var normal := Vector3i(aim["normal"])
	var g := rat.equipped
	# Ladder aimed at a ladder: extend that stack, upward from its top half,
	# downward from its bottom half.
	if g == "ladder" and world.get_cell(aimed) == Blocks.LADDER:
		var up := normal.y >= 0
		if aim.has("point"):
			up = float(Vector3(aim["point"]).y) - float(aimed.y) >= 0.5
		var step := Vector3i(0, 1 if up else -1, 0)
		var cell := aimed
		var guard := 0
		while world.get_cell(cell) == Blocks.LADDER and guard < VoxelWorld.SY:
			cell += step
			guard += 1
		var why := try_place_gadget(rat, cell, g, Vector3.ZERO, 14.0)
		if why == "Space is occupied":
			return "The ladder stack is blocked %s" % ("above" if up else "below")
		return why
	# Your own team gate can hold a ladder, spring, conveyor, wall spring or
	# highway. (A highway aimed at the top of a gate lies on top of it.)
	var aimed_id := world.get_cell(aimed)
	if Blocks.is_gate(aimed_id) and Blocks.gate_team(aimed_id) == rat.team and ClassDefs.GATE_GADGETS.has(g) \
			and not (g == "highway" and normal.y == 1):
		return try_place_gadget(rat, aimed, g, dir, -1.0, false, true)
	# Conveyors are laid INTO the floor block you point at. (Highways are a
	# thin layer that lies on top of the face instead.)
	if g == "conveyor" and normal.y == 1 and _is_floor_material(aimed):
		return try_place_gadget(rat, aimed, g, dir, -1.0, true)
	return try_place_gadget(rat, aimed + normal, g, dir)


func _place_teleporter(rat: Rat, cell: Vector3i, reach := -1.0) -> String:
	## Your first pad is the entrance, the second the exit. One set per rat.
	if not unlimited() and int(rat.gadgets.get("teleporter", 0)) <= 0:
		return "Out of Teleporters"
	var exit := tele_in.has(rat.id)
	if exit and tele_out.has(rat.id):
		return "You already have a set of teleporters - dig one up to move it"
	if Blocks.SOLID[world.get_cell(cell + Vector3i(0, -1, 0))] == 0:
		return "A teleporter needs a floor to stand on"
	var block := (Blocks.TELE_OUT_BLUE if rat.team == 0 else Blocks.TELE_OUT_RED) if exit \
		else (Blocks.TELE_IN_BLUE if rat.team == 0 else Blocks.TELE_IN_RED)
	var why := can_place_at(rat, cell, block, reach)
	if why != "":
		return why
	if not unlimited():
		rat.gadgets["teleporter"] = int(rat.gadgets["teleporter"]) - 1
	world.set_block(cell, block)
	tele_owner[cell] = rat.id
	if exit:
		tele_out[rat.id] = cell
	else:
		tele_in[rat.id] = cell
		tele_charge[cell] = 0.0
	trap_owner[cell] = rat.team
	rat.play_action("build", 0.3)
	fx.emit("tele_place", Vector3(cell), "Exit" if exit else "Entrance")
	return ""


func tele_next(rat: Rat) -> String:
	## Which pad Q puts down next: "entrance", "exit" or "" (a full set is out).
	var placed_in := false
	var placed_out := false
	for p: Array in tele_pads():
		if int(p[4]) == rat.id:
			placed_in = placed_in or not bool(p[1])
			placed_out = placed_out or bool(p[1])
	if not placed_in:
		return "entrance"
	return "exit" if not placed_out else ""


func tele_pads() -> Array:
	## Every teleporter pad: [cell, is_exit, team, ready, owner id]. Online
	## players get this list in each snapshot (for the view and the HUD).
	if replica:
		return tele_net
	var out: Array = []
	for cell: Vector3i in tele_owner:
		var id := world.get_cell(cell)
		out.append([cell, not Blocks.is_tele_in(id), Blocks.tele_team(id), float(tele_charge.get(cell, 0.0)) <= 0.0,
			int(tele_owner[cell])])
	return out


func _tele_check(r: Rat, dt: float) -> void:
	## Stand still on a charged entrance of your team for Config.TELE_WAIT s
	## and you're sent to its owner's exit. One way; cheese can't come along.
	var cell := Vector3i(floori(r.position.x), floori(r.position.y + 0.2), floori(r.position.z))
	var id := world.get_cell(cell)
	if over or r.flying or not Blocks.is_tele_in(id) or Blocks.tele_team(id) != r.team or not tele_owner.has(cell):
		_tele_wait.erase(r.id)
		return
	var wait := float(_tele_wait.get(r.id, 0.0))
	if wait < 0.0:
		return            # already told why not, until they step off
	var exit: Variant = tele_out.get(int(tele_owner[cell]))
	var spot := Vector3(cell) + Vector3(0.5, 0.3, 0.5)
	var why := ""
	if exit == null:
		why = "No exit yet"
	elif r.carried > 0:
		why = "No cheese through teleporters!"
	if why != "":
		_tele_wait[r.id] = -1.0
		fx.emit("tele_no", spot, why)
		return
	if float(tele_charge.get(cell, 0.0)) > 0.0:
		return            # still recharging: wait on it
	wait += dt
	_tele_wait[r.id] = wait
	if wait < Config.TELE_WAIT:
		return
	var to := Vector3(exit) + Vector3(0.5, 0.02, 0.5)
	if r.blocked_at(to):
		_tele_wait[r.id] = -1.0
		fx.emit("tele_no", spot, "The exit is blocked")
		return
	siege.release(r)
	fx.emit("tele_go", r.position, r.team)
	r.position = to
	r.vel = Vector3.ZERO
	r.knock = 0.0
	r.on_floor = false
	tele_charge[cell] = Config.TELE_CHARGE
	_tele_wait[r.id] = -1.0          # step off and back on for the next trip
	fx.emit("tele_arrive", to, r.team)


func _is_floor_material(cell: Vector3i) -> bool:
	var id := world.get_cell(cell)
	return (id == Blocks.DIRT or id == Blocks.GRASS or id == Blocks.STONE or id == Blocks.BRICK \
		or id == Blocks.ICE) and not world.has_micro(cell)


# ---------------------------------------------------------------- chisel

func _micro_available(rat: Rat, mat: String) -> int:
	return int(rat.micro_bank.get(mat, 0)) + int(rat.mats.get(mat, 0)) * Blocks.MICRO_COUNT


func _pay_micro(rat: Rat, mat: String, n: int) -> bool:
	## Spend n microvoxels of a material, breaking whole blocks into the
	## rat's spare-change bank as needed. All or nothing.
	if unlimited():
		return true
	if _micro_available(rat, mat) < n:
		return false
	var bank := int(rat.micro_bank.get(mat, 0)) - n
	while bank < 0:
		bank += Blocks.MICRO_COUNT
		rat.mats[mat] = int(rat.mats[mat]) - 1
	rat.micro_bank[mat] = bank
	return true


func _refund_micro(rat: Rat, mat: String, n: int) -> void:
	## Exactly reverses _pay_micro, so carve / refill / re-dig loops are
	## zero-sum: 343 spare microvoxels become one block again.
	if unlimited():
		return
	var bank := int(rat.micro_bank.get(mat, 0)) + n
	while bank >= Blocks.MICRO_COUNT and int(rat.mats[mat]) < 99:
		bank -= Blocks.MICRO_COUNT
		rat.mats[mat] = int(rat.mats[mat]) + 1
	rat.micro_bank[mat] = mini(bank, Blocks.MICRO_COUNT * 2)


func _chisel_gate(rat: Rat, cell: Vector3i, mv: Vector3i) -> String:
	if over or rat.stun > 0.0:
		return "Can't chisel right now"
	if rat.chisel_cd > cd_slack(rat):
		return "wait"
	if not VoxelWorld.in_bounds(cell) or mv.x < 0 or mv.y < 0 or mv.z < 0 or mv.x >= Blocks.MICRO or mv.y >= Blocks.MICRO or mv.z >= Blocks.MICRO:
		return "Out of bounds"
	if lobby and lobby_props.has(cell):
		return "That's part of the playground"
	var p := Vector3(cell) + (Vector3(mv) + Vector3(0.5, 0.5, 0.5)) / float(Blocks.MICRO)
	if p.distance_to(rat.eye()) > Config.DIG_REACH + 0.6:
		return "Too far"
	return ""


func try_chisel_remove(rat: Rat, cell: Vector3i, mv: Vector3i) -> String:
	var why := _chisel_gate(rat, cell, mv)
	if why != "":
		return why
	if remote != null:
		rat.chisel_cd = 1.0 / Config.CHISEL_RATE
		return remote.act("try_chisel_remove", [cell, mv])
	var id := world.get_cell(cell)
	if not Blocks.CHISELABLE.has(id):
		return "%s can't be chiseled" % Blocks.block_name(id)
	if not world.micro_at(cell, mv):
		return "Nothing there to carve"
	rat.chisel_cd = 1.0 / Config.CHISEL_RATE
	# a dab of paint was paid in dirt, so it comes back as dirt
	var dab := world.has_micro(cell) and int((world.micro[cell] as PackedByteArray)[mv.x + Blocks.MICRO * (mv.z + Blocks.MICRO * mv.y)]) > 1
	world.set_micro(cell, mv, false)
	_refund_micro(rat, "dirt" if dab else Blocks.mat_of(id), 1)
	rat.play_action("build", 0.2)
	fx.emit("chip", Vector3(cell) + Vector3(mv) / float(Blocks.MICRO), id)
	return ""


func try_chisel_add(rat: Rat, cell: Vector3i, mv: Vector3i, mat: String, color := -1) -> String:
	## `color` >= 0 adds a painted microvoxel in that palette colour.
	var why := _chisel_gate(rat, cell, mv)
	if why != "":
		return why
	if remote != null:
		rat.chisel_cd = 1.0 / Config.CHISEL_RATE
		return remote.act("try_chisel_add", [cell, mv, mat, color])
	var id := world.get_cell(cell)
	var block := id
	var value := 1
	if color >= Blocks.PALETTE_SIZE:
		return "Unknown colour"
	if color >= Blocks.PALETTE_SOLID:
		return "Glass comes in whole blocks only - place it with the Paint slot"
	if color >= 0 and id != Blocks.AIR and id != Blocks.PAINT_0 + color:
		value = 2 + color      # a dab of colour on a block of another material
	if id == Blocks.AIR:
		if color >= 0:
			block = Blocks.PAINT_0 + color
		elif not ClassDefs.MAT_BLOCK.has(mat):
			return "Pick a material (1-5) first"
		else:
			block = ClassDefs.MAT_BLOCK[mat]
		if MapGenerator.in_any_base(cell, 0.5):
			return "Bases are protected"
	elif not Blocks.CHISELABLE.has(id):
		return "Can't add to %s" % Blocks.block_name(id)
	elif world.micro_at(cell, mv):
		return "That spot is already filled"
	var s := 1.0 / float(Blocks.MICRO)
	var mn := Vector3(cell) + Vector3(mv) * s
	for r in rats:
		if mn.x + s > r.position.x - Rat.RADIUS and mn.x < r.position.x + Rat.RADIUS \
				and mn.z + s > r.position.z - Rat.RADIUS and mn.z < r.position.z + Rat.RADIUS \
				and mn.y + s > r.position.y + 0.001 and mn.y < r.position.y + Rat.HEIGHT:
			return "A rat is in the way"
	var use_mat := Blocks.mat_of(block)
	if value > 1 or Blocks.is_paint(block):
		use_mat = "dirt" if unlimited() else paint_material(rat, 1)   # paint: dirt, else stone
		if use_mat == "":
			return "Paint is made from dirt or stone - dig some first"
	if not _pay_micro(rat, use_mat, 1):
		return "No %s left to chisel with" % use_mat
	rat.chisel_cd = 1.0 / Config.CHISEL_RATE
	world.set_micro(cell, mv, true, block, value)
	rat.play_action("build", 0.2)
	fx.emit("chip", mn, block)
	return ""


# ---------------------------------------------------------------- pantograph

func copy_region(rat: Rat, a: Vector3i, b: Vector3i) -> Dictionary:
	## Returns {"error": String} or {"blueprint": Blueprint}.
	var limit := Config.PANTOGRAPH_MAX
	var span := (a - b).abs() + Vector3i.ONE
	if span.x > limit or span.y > limit or span.z > limit:
		return {"error": "Selection is %dx%dx%d - the limit is %d on a side" % [span.x, span.y, span.z, limit]}
	if not VoxelWorld.in_bounds(a) or not VoxelWorld.in_bounds(b):
		return {"error": "Selection leaves the map"}
	if Vector3(a).distance_to(rat.position) > 24.0 or Vector3(b).distance_to(rat.position) > 24.0:
		return {"error": "Selection is too far away"}
	var bp := Blueprint.capture(world, a, b)
	if bp.cells.is_empty():
		return {"error": "Nothing copyable in that box (only building materials can be copied)"}
	return {"blueprint": bp}


func paste_check(rat: Rat, bp: Blueprint, origin: Vector3i) -> String:
	var bad := bp.validate()
	if bad != "":
		return bad
	if over:
		return "Match is over"
	if (Vector3(origin) + Vector3(bp.size) * 0.5).distance_to(rat.position) > 16.0:
		return "Too far away to build that"
	for e in bp.cells:
		var c := origin + Vector3i(e["o"])
		if not VoxelWorld.in_bounds(c) or c.y < 1:
			return "Blueprint would leave the map"
		if world.get_cell(c) != Blocks.AIR:
			return "Something is in the way"
		if MapGenerator.in_any_base(c, 0.5):
			return "Bases are protected"
		for r in rats:
			if r.overlaps_cell(c):
				return "A rat is in the way"
	if not unlimited():
		var need := bp.cost()
		for mat: String in need:
			if _micro_available(rat, mat) < int(need[mat]):
				return "Not enough %s: need %.1f blocks, have %.1f" % [mat, float(need[mat]) / 343.0, float(_micro_available(rat, mat)) / 343.0]
	return ""


func try_paste(rat: Rat, bp: Blueprint, origin: Vector3i) -> String:
	## All or nothing: validated in full, paid in full, then built in full.
	if remote != null:
		return remote.act("try_paste", [{"size": bp.size, "cells": bp.cells}, origin])
	var why := paste_check(rat, bp, origin)
	if why != "":
		return why
	var need := bp.cost()
	for mat: String in need:
		_pay_micro(rat, mat, int(need[mat]))
	for e in bp.cells:
		var c := origin + Vector3i(e["o"])
		if e["mask"] == null:
			world.set_block(c, int(e["id"]))
		else:
			world.set_mask(c, int(e["id"]), e["mask"])
	rat.play_action("build", 0.4)
	fx.emit("place", Vector3(origin), int(bp.cells[0]["id"]))
	return ""


# ---------------------------------------------------------------- cheese

func spawn_pickup(kind: String, pos: Vector3, vel: Vector3) -> Pickup:
	var p := Pickup.new()
	p.uid = _next_uid
	_next_uid += 1
	p.kind = kind
	p.pos = pos
	p.vel = vel
	pickups.append(p)
	return p


func take_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


func _drop(rat: Rat, count: int, lock_seconds: float) -> void:
	## Moves cheese from a rat into the world. Cheese is only ever *moved*,
	## never copied: carried decreases by exactly the number of pickups made.
	var n := mini(count, rat.carried)
	for i in n:
		rat.carried -= 1
		var ang := _rng.randf() * TAU
		var p := spawn_pickup("cheese", rat.position + Vector3(0, 0.5, 0), Vector3(cos(ang) * 2.0, 4.5, sin(ang) * 2.0))
		p.lock_id = rat.id
		p.lock_t = lock_seconds
		p.from_team = rat.team


func drop_cheese(rat: Rat, aim: Dictionary = {}, look := Vector3.ZERO) -> bool:
	## G: put one cheese down where you are looking (the open cell in front of
	## the aimed face), or toss it forward when you are not aiming at anything
	## in reach.
	if rat.carried <= 0:
		return false
	if remote != null:
		remote.act("drop_cheese", [wire_aim(aim), look])
		return true
	rat.carried -= 1
	var spot := Vector3.INF
	if aim.has("cell") and aim.has("normal"):
		var c := Vector3i(aim["cell"]) + Vector3i(aim["normal"])
		var p := Vector3(c) + Vector3(0.5, 0.3, 0.5)
		if p.distance_to(rat.eye()) <= Config.DIG_REACH + 1.0 and not world.solid_point(p) and world.get_cell(c) != Blocks.LAVA:
			spot = p
	var pk: Pickup
	if spot != Vector3.INF:
		pk = spawn_pickup("cheese", spot, Vector3.ZERO)
	else:
		var f := look if look.length() > 0.1 else Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
		f = f.normalized()
		pk = spawn_pickup("cheese", rat.eye() + f * 0.4, f * 5.0 + Vector3(0, 2.5, 0))
	pk.lock_id = rat.id
	pk.lock_t = 1.0
	pk.from_team = rat.team
	fx.emit("place", pk.pos - Vector3(0.5, 0.3, 0.5), Blocks.CHEESE)
	return true


func try_bonk(rat: Rat, target: Rat) -> bool:
	if over or rat == target or target == null:
		return false
	if (rat.team == target.team and not lobby) or rat.bonk_cd > cd_slack(rat) or rat.stun > 0.0:
		return false
	if rat.center().distance_to(target.center()) > Config.BONK_RANGE + (0.7 if rat.net_peer != 0 else 0.0):
		return false
	if remote != null:
		rat.bonk_cd = Config.BONK_COOLDOWN
		rat.dig_cd = 1.0 / Config.DIG_RATE
		rat.play_action("attack", 0.3)
		remote.act("try_bonk", [target.id])
		return true
	rat.bonk_cd = Config.BONK_COOLDOWN
	rat.dig_cd = 1.0 / Config.DIG_RATE
	rat.play_action("attack", 0.3)
	if target.shield_t > 0.0:
		fx.emit("shield_block", target.position, null)   # it bounces off the Rat Knight Shield
		return true
	var dir := target.position - rat.position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
	if not lobby:
		tally(rat, "bonks")
		tally(target, "bonked")
	target.vel = (dir * 7.0 + Vector3(0, 5.0, 0)) * launch_power()
	target.knock = 0.4
	target.on_floor = false
	if target.carried > 0:
		_drop(target, 1, Config.BONK_PICKUP_LOCK)
	fx.emit("bonk", target.position, null)
	return true


# ---------------------------------------------------------------- results screen

func tally(rat: Rat, key: String, n := 1) -> void:
	## Count something for the results screen (the authority counts; clients
	## are sent the totals when the match ends).
	if rat == null or replica or lobby or n == 0:
		return
	rat.stats[key] = int(rat.stats.get(key, 0)) + n


func stats_packed() -> PackedInt32Array:
	## Every rat's tallies, compact for the network: id, then STATS in order.
	var out := PackedInt32Array()
	for r in rats:
		out.append(r.id)
		for k: String in STATS:
			out.append(int(r.stats.get(k, 0)))
	return out


func apply_stats(p: PackedInt32Array) -> void:
	var w := STATS.size() + 1
	for i in range(0, p.size() - w + 1, w):
		var r := rat_by_id(p[i])
		if r == null:
			continue
		for j in STATS.size():
			r.stats[STATS[j]] = p[i + 1 + j]


func emote(rat: Rat, kind: String) -> bool:
	## A results-screen emote (the movement keys). Only once the match is over.
	if not over or rat == null or not EMOTES.has(kind):
		return false
	if rat.emote == kind and rat.emote_t > 0.0:
		return false   # (held down: it plays to the end, then again)
	rat.emote = kind
	rat.emote_t = EMOTE_TIME
	if remote != null:
		remote.act("emote", [kind])
	return true


func _bots_emote(dt: float) -> void:
	## Bots join in on the results screen: winners celebrate, losers mostly sulk.
	for r in rats:
		if not r.is_bot or r.emote_t > 0.0 or _rng.randf() > dt * 0.7:
			continue
		var pool := ["cheer", "dance", "flip", "taunt"] if r.team == winner else ["flop", "flop", "taunt", "dance"]
		emote(r, pool[_rng.randi() % pool.size()])


func respawn(rat: Rat) -> void:
	## Ctrl+K / hazards. Carried cheese and the material stash stay behind as
	## pickups (moved, not copied), then the rat returns to base empty-pawed.
	if remote != null:
		remote.act("respawn", [])
		return
	siege.release(rat)
	drop_everything(rat)
	var slot := rat.id % 16
	rat.position = spawn_point(rat.team, slot)
	rat.vel = Vector3.ZERO
	rat.stun = 0.0
	rat.knock = 0.0
	rat.lava_home = -1.0
	rat.lava_strikes = 0
	rat.unstick()
	fx.emit("respawn", rat.position, null)


func unlimited() -> bool:
	## Nobody runs out of scrap, materials or gadgets: Free Build, the
	## playground, and a match started with the cheat code.
	return free_mode or infinite


func cheat_infinite(by: Rat) -> String:
	## The host typed the code in the playground: the match it starts gives
	## everyone infinite resources (typed again: a normal match). Returns what
	## to tell whoever typed it.
	if not lobby:
		return ""
	if replica or remote != null:
		return "Nice try - only the host knows that one."
	infinite_next = not infinite_next
	settings["infinite"] = infinite_next
	toast.emit("CHEAT CODE! The next match gives everyone infinite resources." if infinite_next
		else "Cheat code off: the next match is a normal one.", -1)
	fx.emit("cheat", by.position if by != null else Vector3.ZERO, 1 if infinite_next else 0)
	return ""


static func lobby_settings(race: Dictionary) -> Dictionary:
	## The playground round in front of a match: same host, team and class,
	## and the cheat code's setting if the host had it on.
	var s := {"mode": "lobby", "seed": 1, "goal": 9999, "team": int(race.get("team", 0)), "class": String(race.get("class", "digger")),
		"team_size": 1, "server_name": String(race.get("server_name", "")), "infinite": bool(race.get("infinite", false))}
	if race.has("net"):
		s["net"] = race["net"]
		s["port"] = int(race.get("port", Net.DEFAULT_PORT))
	return s


func _dig_decoy(rat: Rat, cell: Vector3i, id: int) -> void:
	## Your own Cheese Decoy comes back into your pack; anyone else who digs
	## at it gets a face full of stink: dazed, and it's gone.
	world.set_block(cell, Blocks.AIR)
	if Blocks.trap_team(id) == rat.team:
		_give_gadget(rat, "decoy", 1)
		fx.emit("break", Vector3(cell), id)
		return
	rat.stun = maxf(rat.stun, Config.DECOY_STUN)
	rat.vel = Vector3(rat.vel.x * 0.2, 3.5, rat.vel.z * 0.2)
	fx.emit("decoy", Vector3(cell), null)
	toast.emit("%s dug into a Cheese Decoy. Pee-yew!" % rat.display_name, -1)


func _squeak(r: Rat, cell: Vector3i, id: int) -> void:
	## An enemy on a Squeaker Pad: a squeak everyone nearby hears, and a
	## beacon for the pad's team. Spent after Config.SQUEAKER_USES squeaks.
	if float(squeak_rest.get(cell, 0.0)) > 0.0:
		return
	var owner := Blocks.trap_team(id)
	var left := int(squeaks.get(cell, Config.SQUEAKER_USES)) - 1
	squeak_rest[cell] = Config.SQUEAKER_REST
	var spot := Vector3(cell) + Vector3(0.5, 0.2, 0.5)
	add_marker(spot, "SQUEAK! %s" % r.display_name, owner, Config.SQUEAKER_MARK)
	fx.emit("squeak", spot, owner)
	toast.emit("A squeaker pad caught %s!" % r.display_name, owner)
	if left <= 0:
		squeaks.erase(cell)
		squeak_rest.erase(cell)
		world.set_block(cell, Blocks.AIR)
		fx.emit("poof", spot, null)
	else:
		squeaks[cell] = left


func place_bubble(rat: Rat, cell: Vector3i) -> bool:
	## Bubble Shoes: a bubble block right under the rat's feet, for scrap. Online
	## the player's game asks; the cell must really be under them.
	if rat.gear != "bubbles" or over or not VoxelWorld.in_bounds(cell) or world.get_cell(cell) != Blocks.AIR:
		return false
	var top := Vector3(cell) + Vector3(0.5, 1.0, 0.5)
	if absf(top.y - rat.position.y) > 0.6 or Vector2(top.x - rat.position.x, top.z - rat.position.z).length() > 1.2:
		return false
	if MapGenerator.in_any_base(cell) and not free_mode:
		return false
	if not unlimited():
		if rat.scrap < Config.BUBBLE_COST:
			return false
		rat.scrap -= Config.BUBBLE_COST
	world.set_block(cell, Blocks.BUBBLE)
	bubbles[cell] = Config.BUBBLE_TIME
	fx.emit("bubble", Vector3(cell), null)
	return true


func _step_bubbles(dt: float) -> void:
	for cell: Vector3i in bubbles.keys():
		var t := float(bubbles[cell]) - dt
		if t > 0.0:
			bubbles[cell] = t
			continue
		bubbles.erase(cell)
		if world.get_cell(cell) == Blocks.BUBBLE:
			world.set_block(cell, Blocks.AIR)
			fx.emit("pop", Vector3(cell), null)


func ground_pound(rat: Rat, cell: Vector3i) -> void:
	## A full double jump landed flat: one dig hit to the block underfoot, by
	## the usual dig rules (TNT lights). Gates, team blocks, machines and
	## stashes shrug it off. Online the player's game reports it; the block
	## must really be under their feet.
	if over or rat.pound_cd > 0.0 or rat.stun > 0.0:
		return
	var top := Vector3(cell) + Vector3(0.5, 1.0, 0.5)
	if absf(top.y - rat.position.y) > 0.6 or Vector2(top.x - rat.position.x, top.z - rat.position.z).length() > 1.0:
		return
	rat.pound_cd = Config.POUND_COOLDOWN
	fx.emit("pound", rat.position, null)
	var id := world.get_cell(cell)
	if lobby and lobby_props.has(cell):
		return
	if id == Blocks.TNT:
		light_tnt(cell, 2.0)
		return
	if Blocks.HITS[id] == 0 or Blocks.is_gate(id) or Blocks.is_team_block(id) or Blocks.is_machine(id) or Blocks.is_stash(id):
		return
	if world.layered_gate(cell) >= 0:
		return
	_damage(rat, cell, 1)


func spawn_point(team: int, slot := 0) -> Vector3:
	return MapGenerator.lobby_spawn(team, slot) if lobby else MapGenerator.spawn_point(team, slot)


func launch_power() -> float:
	## Knockback from bonks and cannonballs: a lot more in the playground.
	return Config.LOBBY_LAUNCH if lobby else 1.0


func _lobby_step(dt: float) -> void:
	## The bullseye: fling a rat (or fire a cannonball) into the gold centre.
	var face := Vector3(MapGenerator.LOBBY_BULL) + Vector3(0.0, 0.5, 0.5)
	for r in rats:
		var cd := maxf(0.0, float(_bull_cd.get(r.id, 0.0)) - dt)
		_bull_cd[r.id] = cd
		if cd <= 0.0 and r.center().distance_to(face) < 1.3:
			bullseye(r)


func bullseye(r: Rat) -> void:
	if r != null:
		_bull_cd[r.id] = 3.0
	fx.emit("bullseye", Vector3(MapGenerator.LOBBY_BULL) + Vector3(-0.5, 0.5, 0.5), null)
	toast.emit("BULLSEYE! %s" % (r.display_name if r != null else ""), r.team if r != null else -1)


func drop_everything(rat: Rat) -> void:
	## Carried cheese and the material stash fall where the rat stands, as
	## pickups (moved, never copied).
	if rat.carried > 0:
		_drop(rat, rat.carried, 1.0)
	var any := false
	for m: String in rat.mats:
		if int(rat.mats[m]) > 0:
			any = true
	if any and not free_mode:
		var stash := spawn_pickup("stash", rat.position + Vector3(0, 0.4, 0), Vector3(0, 3.0, 0))
		stash.mats = rat.mats.duplicate()
		stash.lock_id = rat.id
		stash.lock_t = 1.0
		for m: String in rat.mats:
			rat.mats[m] = 0


func _step_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		p.lock_t = maxf(0.0, p.lock_t - dt)
		# tiny point-physics: fall, rest on solids, ride conveyors, float out of lava
		var here := world.block_at(p.pos)
		if here == Blocks.LAVA and p.vel.y < -3.0:
			fx.emit("sizzle", p.pos, 0.5)     # it lands in lava and pops back up on top
		if here == Blocks.WATER and not p.wet and p.vel.y < -3.0:
			fx.emit("splash", p.pos, 0.5)
		elif here != Blocks.WATER and p.wet and p.vel.y > 3.0:
			fx.emit("splash_out", p.pos, 0.5)
		p.wet = here == Blocks.WATER
		if here == Blocks.LAVA or world.solid_point(p.pos):
			p.pos.y = floorf(p.pos.y) + 1.15
			p.vel = Vector3.ZERO
		elif here == Blocks.WATER:
			# cheese floats: it drifts up and bobs just under the surface
			p.vel.y = move_toward(p.vel.y, 2.0, 25.0 * dt)
			p.vel.x = move_toward(p.vel.x, 0.0, 4.0 * dt)
			p.vel.z = move_toward(p.vel.z, 0.0, 4.0 * dt)
			var wp := p.pos + p.vel * dt
			if p.vel.y > 0.0 and world.block_at(wp + Vector3(0, 0.3, 0)) != Blocks.WATER:
				wp.y = p.pos.y
				p.vel.y = 0.0
			if world.solid_point(wp):
				wp = p.pos
				p.vel = Vector3.ZERO
			p.pos = wp
		else:
			p.vel.y = maxf(p.vel.y - 20.0 * dt, -20.0)
			var np := p.pos + p.vel * dt
			var below := world.block_at(Vector3(p.pos.x, np.y - 0.15, p.pos.z))
			if below == Blocks.SPRING and p.vel.y <= 0.0:
				p.vel.y = 13.0          # springs launch loose cheese too...
				if Vector2(p.vel.x, p.vel.z).length() < 1.5:
					var ang := _rng.randf() * TAU   # ...and nudge it sideways, so it hops off rather than bouncing forever
					p.vel.x = cos(ang) * 2.2
					p.vel.z = sin(ang) * 2.2
				np.y = p.pos.y
				fx.emit("spring", p.pos, null)
			elif world.solid_point(Vector3(p.pos.x, np.y - 0.15, p.pos.z)) and p.vel.y <= 0.0:
				var under := Vector3i(floori(p.pos.x), floori(np.y - 0.15), floori(p.pos.z))
				np.y = p.pos.y if world.has_micro(under) else floorf(np.y - 0.15) + 1.15
				p.vel.y = 0.0
				var grip := 0.6 if below == Blocks.ICE else 12.0   # loose things slide across ice and off its end
				p.vel.x = move_toward(p.vel.x, 0.0, grip * dt)
				p.vel.z = move_toward(p.vel.z, 0.0, grip * dt)
				if Blocks.is_conveyor(below):
					var push := Blocks.conveyor_dir(below) * 3.0 * dt
					np.x += push.x
					np.z += push.z
				# a spring right beside it flings it up and away, like it does rats
				var beside: Variant = _spring_beside(Vector3i(floori(p.pos.x), floori(np.y), floori(p.pos.z)))
				if beside != null:
					var away := Vector3(p.pos.x, 0, p.pos.z) - Vector3((beside as Vector3).x, 0, (beside as Vector3).z)
					away = away.normalized() if away.length() > 0.05 else Vector3(1, 0, 0)
					p.vel = away * 4.0 + Vector3(0, Config.SPRING_SIDE_SPEED * 0.9, 0)
					fx.emit("spring", p.pos, null)
			if world.solid_point(Vector3(np.x, np.y, p.pos.z)):
				if world.block_at(Vector3(np.x, np.y, p.pos.z)) == Blocks.WALL_SPRING:
					p.vel.x = -signf(np.x - p.pos.x) * 9.0   # wall springs bat it back
					p.vel.y = maxf(p.vel.y, 5.0)
					fx.emit("spring", p.pos, null)
				else:
					p.vel.x = 0.0
				np.x = p.pos.x
			if world.solid_point(Vector3(np.x, np.y, np.z)):
				if world.block_at(Vector3(np.x, np.y, np.z)) == Blocks.WALL_SPRING:
					p.vel.z = -signf(np.z - p.pos.z) * 9.0
					p.vel.y = maxf(p.vel.y, 5.0)
					fx.emit("spring", p.pos, null)
				else:
					p.vel.z = 0.0
				np.z = p.pos.z
			p.pos = np
		if over:
			continue
		for r in rats:
			if r.stun > 0.0 or (p.lock_id == r.id and p.lock_t > 0.0):
				continue
			if r.center().distance_to(p.pos) > 0.95:
				continue
			if p.kind == "cheese":
				if r.carried >= r.capacity():
					continue
				r.carried += 1
				if p.from_team >= 0 and p.from_team != r.team:
					tally(r, "stolen")   # one the other team dropped (a bonk, a trap...)
				fx.emit("pickup", p.pos, r.team)
			else:
				for m: String in p.mats:
					r.mats[m] = mini(int(r.mats.get(m, 0)) + int(p.mats[m]), 99)
				fx.emit("pickup_stash", p.pos, r.team)
			pickups.remove_at(i)
			break


# ---------------------------------------------------------------- TNT

func light_tnt(cell: Vector3i, fuse: float) -> void:
	if world.get_cell(cell) != Blocks.TNT:
		return
	var entry: Dictionary = tnt.get(cell, {"owner": -1, "fuse": -1.0})
	if float(entry["fuse"]) < 0.0 or float(entry["fuse"]) > fuse:
		entry["fuse"] = fuse
		tnt[cell] = entry
		fx.emit("fuse", Vector3(cell), fuse)


func _step_tnt(dt: float) -> void:
	for cell: Vector3i in tnt.keys():
		var entry: Dictionary = tnt[cell]
		if float(entry["fuse"]) < 0.0:
			continue
		entry["fuse"] = float(entry["fuse"]) - dt
		if float(entry["fuse"]) <= 0.0:
			_explode(cell)


func _explode(cell: Vector3i) -> void:
	tally(rat_by_id(int((tnt.get(cell, {}) as Dictionary).get("owner", -1))), "tnt")
	tnt.erase(cell)
	world.set_block(cell, Blocks.AIR)
	blast(Vector3(cell) + Vector3(0.5, 0.5, 0.5), Config.TNT_RADIUS, Config.TNT_POWER)


func blast(origin: Vector3, radius: float, power: float) -> void:
	## The one explosion rule, shared by stationary TNT and Mobile TNT.
	## Damage is `power` dig hits at the centre, fading to zero at `radius`,
	## and is applied through the normal durability table: dirt vanishes,
	## stone cracks at the edges, obsidian only chips. Never hurts a rat.
	fx.emit("boom", origin, radius)
	var c0 := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var ir := ceili(radius)
	for dx in range(-ir, ir + 1):
		for dy in range(-ir, ir + 1):
			for dz in range(-ir, ir + 1):
				var c := c0 + Vector3i(dx, dy, dz)
				if not VoxelWorld.in_bounds(c):
					continue
				var d := (Vector3(c) + Vector3(0.5, 0.5, 0.5)).distance_to(origin)
				if d > radius:
					continue
				var id := world.get_cell(c)
				if id == Blocks.AIR or id == Blocks.WATER or id == Blocks.LAVA:
					continue
				if id == Blocks.TNT:
					light_tnt(c, 0.25)   # chain reaction
				elif Blocks.is_stash(id):
					hit_stash(c)
				elif world.gate_at(c) >= 0:
					hit_gate(c, (Config.GATE_HP + 1) / 2)    # team gates: two blasts
				elif Blocks.is_team_block(id):
					if _damage(null, c, maxi(1, int(power * (1.0 - d / radius))), true):
						fx.emit("break", Vector3(c), id)   # team blocks: one blast, whoever's they are
				else:
					# breaking goes through set_block, which also discards any carving
					_damage(null, c, int(power * (1.0 - d / radius)), true)
	for r in rats:
		var rd := r.center() - origin
		if rd.length() < radius + 1.6:
			var push := rd.normalized() if rd.length() > 0.05 else Vector3.UP
			r.vel = push * 9.0 + Vector3(0, 6.5, 0)
			r.knock = 0.5
			r.on_floor = false
			siege.release(r)
			if r.carried > 0:
				_drop(r, 1, 1.0)
	for p in pickups:
		var pd := p.pos - origin
		if pd.length() < radius + 1.0:
			p.vel = pd.normalized() * 5.0 + Vector3(0, 5.0, 0)
	dynamite.on_blast(origin, radius)
	windup.on_blast(origin, radius)


func impulse_blast(origin: Vector3) -> void:
	## Impulse Grenade: it damages nothing at all (terrain, gadgets, TNT and
	## cheese are left alone). It only shoves: every rat near it, thrower and
	## teammates included, plus loose cheese, dynamite and wind-ups, is thrown
	## away from it, hardest right beside it. Carriers keep their cheese.
	fx.emit("impulse", origin, null)
	var radius := Config.IMPULSE_RADIUS
	for r in rats:
		if r.flying:
			continue
		var k := _impulse_k(r.center() - origin, radius)
		if k <= 0.0:
			continue
		if r.carried > 0:
			k *= Config.IMPULSE_CARRY
		r.vel = _impulse_dir(r.center() - origin) * Config.IMPULSE_PUSH * k + Vector3(0, Config.IMPULSE_LIFT * k, 0)
		r.vel.y = minf(r.vel.y, Config.IMPULSE_MAX_UP)
		r.knock = 0.45
		r.on_floor = false
		siege.release(r)
	for p in pickups:
		var k := _impulse_k(p.pos - origin, radius)
		if k > 0.0:
			p.vel = _impulse_dir(p.pos - origin) * 9.0 * k + Vector3(0, 5.0 * k, 0)
	for s in dynamite.sticks:
		var k := _impulse_k(s.pos - origin, radius)
		if k > 0.0 and not s.stuck:
			s.vel = _impulse_dir(s.pos - origin) * 11.0 * k + Vector3(0, 4.0 * k, 0)
			s.resting = false
	for w in windup.walkers:
		var k := _impulse_k(w.body.center() - origin, radius)
		if k > 0.0:
			w.body.vel = _impulse_dir(w.body.center() - origin) * 12.0 * k + Vector3(0, 6.0 * k, 0)
			w.body.knock = 0.45
			w.body.on_floor = false


static func _impulse_k(d: Vector3, radius: float) -> float:
	## Strength by distance: full right beside it, half at the edge, none past it.
	var dist := d.length()
	return 0.0 if dist > radius else 1.0 - 0.5 * dist / radius


static func _impulse_dir(d: Vector3) -> Vector3:
	return d.normalized() if d.length() > 0.05 else Vector3.UP


# ---------------------------------------------------------------- abilities

func use_ability(rat: Rat, slot: int, aim: Dictionary = {}) -> String:
	## Returns "" on success or a reason string for the HUD.
	if over or rat.stun > 0.0:
		return "Can't do that right now"
	if remote != null:
		return remote.act("use_ability", [slot, wire_aim(aim)])
	var list: Array = rat.cls["abilities"]
	if slot < 0 or slot >= list.size():
		return ""
	var ab: Array = list[slot]
	if float(rat.ability_cd[slot]) > 0.0:
		return "%s is recharging" % ab[1]
	var cost := 0.0 if free_mode else float(ab[3])
	if rat.stamina < cost:
		return "Not enough stamina"
	var err := ""
	match String(ab[0]):
		"superdig": err = _ab_superdig(rat, aim)
		"sniff": err = _ab_marker(rat, _nearest_cheese(rat.position, 30.0), "Cheese", "No cheese scent within 30 blocks")
		"beacon":
			add_marker(rat.position + Vector3(0, 1, 0), "Beacon", rat.team, 120.0)
		"patch": err = _ab_patch(rat, aim)
		"detonate": err = _ab_detonate(rat, aim)
		"plant":
			if aim.is_empty():
				err = "Aim at a surface"
			else:
				err = try_place_gadget(rat, Vector3i(aim["cell"]) + Vector3i(aim["normal"]), "tnt")
	if err != "":
		return err
	rat.stamina -= cost
	rat.ability_cd[slot] = float(ab[2])
	rat.play_action("use", 0.4)
	fx.emit("ability", rat.position, ab[0])
	return ""


func add_marker(pos: Vector3, text: String, team: int, ttl: float) -> void:
	markers.append({"pos": pos, "text": text, "team": team, "ttl": ttl})


func _ab_marker(rat: Rat, where: Variant, label: String, fail: String) -> String:
	if where == null:
		return fail
	add_marker(where, label, rat.team, 14.0)
	return ""


func _nearest_poi(from: Vector3, radius: float) -> Variant:
	var best: Variant = null
	var best_d := radius
	for p in world.points_of_interest:
		var d := p.distance_to(from)
		if d < best_d and d > 3.0:
			best_d = d
			best = p
	return best


func _nearest_cheese(from: Vector3, radius: float) -> Variant:
	var best: Variant = null
	var best_d := radius
	for c: Vector3i in world.cheese_cells:
		var p := Vector3(c) + Vector3(0.5, 0.5, 0.5)
		var d := p.distance_to(from)
		if d < best_d:
			best_d = d
			best = p
	for pk in pickups:
		if pk.kind == "cheese" and pk.pos.distance_to(from) < best_d:
			best_d = pk.pos.distance_to(from)
			best = pk.pos
	return best


func _ab_patch(rat: Rat, aim: Dictionary) -> String:
	if aim.is_empty():
		return "Aim at a surface to patch"
	var n := Vector3i(aim["normal"])
	var c := Vector3i(aim["cell"]) + n
	var placed := 0
	for a in range(-1, 2):
		for b in range(-1, 2):
			var off := Vector3i(a, b, 0)
			if n.x != 0:
				off = Vector3i(0, a, b)
			elif n.y != 0:
				off = Vector3i(a, 0, b)
			if can_place_at(rat, c + off, Blocks.DIRT) == "":
				world.set_block(c + off, Blocks.DIRT)
				placed += 1
	if placed == 0:
		return "Nothing to patch there"
	fx.emit("place", Vector3(c), Blocks.DIRT)
	return ""


func _ab_superdig(rat: Rat, aim: Dictionary) -> String:
	## Digger: one heavy swing. Double damage on the aimed block plus the
	## 3x3x3 brush around it.
	if aim.is_empty():
		return "Aim at something to Super Dig"
	var cell := Vector3i(aim["cell"])
	if (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) > Config.DIG_REACH + 1.0:
		return "Too far"
	var id := world.get_cell(cell)
	if Blocks.HITS[id] == 0 or id == Blocks.TNT or Blocks.is_gate(id) or Blocks.is_machine(id) or Blocks.is_team_block(id):
		return "Super Dig needs something diggable"
	rat.dig_cd = 1.0 / Config.DIG_RATE
	rat.play_action("dig", 0.35)
	_damage(rat, cell, 99 if free_mode else 2)
	_brush(rat, cell, 1, 99 if free_mode else 1)
	return ""


func _ab_detonate(rat: Rat, aim: Dictionary) -> String:
	var best := Vector3i.ZERO
	var best_d := 80.0
	var from := rat.position
	# Aiming at a TNT charge triggers the one nearest to the aim point.
	if not aim.is_empty():
		from = Vector3(Vector3i(aim["cell"]))
	for cell: Vector3i in tnt:
		var entry: Dictionary = tnt[cell]
		if int(entry["owner"]) != rat.id and not free_mode:
			continue
		var d := Vector3(cell).distance_to(from)
		if d < best_d:
			best_d = d
			best = cell
	if best_d >= 80.0:
		return "No TNT of yours to detonate"
	light_tnt(best, 0.3)
	return ""


# ---------------------------------------------------------------- economy

func can_shop(rat: Rat) -> bool:
	return free_mode or bool(rat.cls["remote_shop"]) or in_base(rat)


# ---------------------------------------------------------------- team stash

func near_stash(rat: Rat) -> bool:
	## Standing within reach of one of your team's stashes.
	var f := rat.feet_cell()
	var r := ceili(Config.STASH_REACH)
	var own := Blocks.STASH_BLUE if rat.team == 0 else Blocks.STASH_RED
	for dy in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := f + Vector3i(dx, dy, dz)
				if world.get_cell(c) == own and (Vector3(c) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.center()) <= Config.STASH_REACH + 0.5:
					return true
	return false


func can_use_stash(rat: Rat) -> bool:
	return not free_mode and (in_base(rat) or near_stash(rat))


func stash_move(rat: Rat, key: String, amount: int) -> String:
	## Positive amount: put that much into the team pool. Negative: take it out.
	## Only scrap and building materials; cheese never goes in a stash.
	if remote != null:
		return remote.act("stash_move", [key, amount])
	if not Config.STASH_KEYS.has(key) or amount == 0:
		return "Stashes hold scrap, dirt, stone, ice and obsidian"
	if over:
		return "Match is over"
	if not can_use_stash(rat):
		return "Stand at your base or next to one of your team stashes"
	var bank: Dictionary = team_bank[rat.team]
	var have := rat.scrap if key == "scrap" else int(rat.mats.get(key, 0))
	var n := amount
	if n > 0:
		n = mini(n, have)
		if n <= 0:
			return "You have no %s to put in" % key
	else:
		n = -mini(-n, int(bank[key]))
		if key != "scrap":
			n = -mini(-n, 99 - have)
		if n >= 0:
			return "Nothing to take" if int(bank[key]) == 0 else "Your pack is full of %s" % key
	bank[key] = int(bank[key]) + n
	if key == "scrap":
		rat.scrap -= n
	else:
		rat.mats[key] = have - n
	fx.emit("buy", rat.position, "stash")
	return ""


func hit_stash(cell: Vector3i) -> void:
	## Only explosions hurt a stash; enough of them break it. The pool is kept.
	var id := world.get_cell(cell)
	stash_hits[cell] = int(stash_hits.get(cell, 0)) + 1
	if int(stash_hits[cell]) < Config.STASH_BLASTS:
		fx.emit("hit", Vector3(cell), {"id": id, "ratio": float(stash_hits[cell]) / float(Config.STASH_BLASTS)})
		return
	world.set_block(cell, Blocks.AIR)
	fx.emit("break", Vector3(cell), id)
	toast.emit("A %s team stash was blown apart! (The team's pool is safe.)" % TEAM_NAMES[Blocks.stash_team(id)], -1)


func try_buy(rat: Rat, item_id: String) -> String:
	if remote != null:
		return remote.act("try_buy", [item_id])
	var item := ClassDefs.shop_item(item_id)
	if item.is_empty():
		return "Unknown item"
	if over:
		return "Match is over"
	if not can_shop(rat):
		return "Return to your base to use the workshop"
	var cost := ClassDefs.price(rat.cls, item_id, unlimited())
	if item_id == "teleporter" and not free_mode:
		# one set per rat: buying tops you up to a full set, at the price per missing pad
		var missing := int(item["qty"]) - int(rat.gadgets.get("teleporter", 0)) - int(tele_in.has(rat.id)) - int(tele_out.has(rat.id))
		if missing <= 0:
			return "You already have a set of teleporters"
		cost = cost * missing / int(item["qty"])
		if rat.scrap < cost:
			return "Need %d scrap (you have %d)" % [cost, rat.scrap]
		rat.scrap -= cost
		_give_gadget(rat, "teleporter", missing)
		if rat.equipped == "":
			rat.equipped = item_id
		fx.emit("buy", rat.position, item_id)
		return ""
	if rat.scrap < cost:
		return "Need %d scrap (you have %d)" % [cost, rat.scrap]
	var qty := int(item["qty"])
	if item["kind"] == "gear":
		if rat.gear == item_id:
			return "You are already wearing the %s" % item["name"]
		rat.scrap -= cost
		rat.gear = item_id     # one gear slot: a new piece replaces the old one
		rat.gear_cd = 0.0
		rat.shield_t = 0.0
		rat.bubbles_on = false
		fx.emit("buy", rat.position, item_id)
		return ""
	if item["kind"] == "gadget":
		var have := int(rat.gadgets.get(item_id, 0))
		var cap := int(item.get("max", Config.STACK_MAX))
		if have >= cap:
			return "Pack is full of %s (max %d)" % [ClassDefs.GADGET_NAME[item_id], cap]
		rat.scrap -= cost
		rat.gadgets[item_id] = mini(have + qty, cap)
		if rat.equipped == "":
			rat.equipped = item_id
	else:
		if int(rat.mats.get(item_id, 0)) >= 99:
			return "Can't carry more %s" % item_id
		rat.scrap -= cost
		rat.mats[item_id] = mini(int(rat.mats.get(item_id, 0)) + qty, 99)
	fx.emit("buy", rat.position, item_id)
	return ""


func try_change_class(rat: Rat, class_id: String) -> String:
	if remote != null:
		return remote.act("try_change_class", [class_id])
	if not ClassDefs.CLASSES.has(class_id):
		return "Unknown class"
	# Permission check: the creative class is only ever granted by the authority.
	if class_id == "maestro" and not free_mode:
		return "Chisel Maestro is only available in Free Build"
	if not free_mode and not in_base(rat):
		return "Change class at your base"
	if class_id == rat.class_id:
		return ""
	if rat.class_cd > 0.0 and not free_mode:
		return "You can switch class again in %d s" % ceili(rat.class_cd)
	rat.class_cd = 15.0
	rat.set_class(class_id, true)
	rat.ability_cd = [2.0, 2.0]
	if rat.carried > rat.capacity():
		_drop(rat, rat.carried - rat.capacity(), 0.5)
	fx.emit("ability", rat.position, "class")
	return ""
