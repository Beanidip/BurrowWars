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

const TEAM_NAMES := ["Blue", "Red"]
const BOT_NAMES := ["Nibbles", "Gouda", "Brie", "Scrabble", "Whiskers", "Cheddar", "Pip", "Rind"]


class Pickup:
	var uid := 0
	var kind := "cheese"       # "cheese" | "stash"
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var lock_id := -1          # rat that may not collect this yet
	var lock_t := 0.0
	var mats: Dictionary = {}


var world: VoxelWorld
var settings: Dictionary = {}
var free_mode := false
var goal := 8
var scores: Array[int] = [0, 0]
var rats: Array[Rat] = []
var bots: Array[BotBrain] = []
var pickups: Array[Pickup] = []
var markers: Array[Dictionary] = []
var tnt: Dictionary = {}        # Vector3i -> {"owner": rat id, "fuse": seconds or -1}
var gate_damage: Dictionary = {}
var lava: LavaFlow
var over := false
var winner := -1
var time := 0.0
var auto_step := true
var visual := true

var dynamite: DynamiteSystem
var siege: SiegeSystem

var _next_uid := 1
var _rng := RandomNumberGenerator.new()


func setup(match_settings: Dictionary, with_visuals := true) -> void:
	settings = match_settings
	visual = with_visuals
	free_mode = settings.get("mode", "race") == "free"
	goal = int(settings.get("goal", 8))
	var map_seed := int(settings.get("seed", 1))
	_rng.seed = map_seed * 7919 + 13
	world = VoxelWorld.new()
	world.visual = with_visuals
	world.name = "World"
	add_child(world)
	dynamite = DynamiteSystem.new(self)
	siege = SiegeSystem.new(self)
	lava = LavaFlow.new(self)
	world.block_changed.connect(lava.on_block_changed)
	lava.wake_all()
	world.block_changed.connect(_on_block_changed)
	world.block_changed.connect(siege.on_block_changed)
	MapGenerator.generate(world, map_seed)
	for cell: Vector3i in _find_blocks(Blocks.TNT):
		tnt[cell] = {"owner": -1, "fuse": -1.0}
	Log.info("match setup: mode=%s seed=%d goal=%d cheese_on_map=%d" % [
		settings.get("mode", "race"), map_seed, goal, world.cheese_cells.size()])


func _on_block_changed(cell: Vector3i, _old: int, new_id: int) -> void:
	# a highway is only a surface layer: it goes when the block under it goes
	var above := cell + Vector3i(0, 1, 0)
	if Blocks.SOLID[new_id] == 0 and world.get_cell(above) == Blocks.HIGHWAY:
		world.set_block(above, Blocks.AIR)
	gate_damage.erase(cell)


func _find_blocks(id: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var i := world.data.find(id)
	while i >= 0:
		out.append(Vector3i(i % VoxelWorld.SX, i / (VoxelWorld.SX * VoxelWorld.SZ), (i / VoxelWorld.SX) % VoxelWorld.SZ))
		i = world.data.find(id, i + 1)
	return out


func spawn_rat(team: int, class_id: String, is_bot: bool) -> Rat:
	var rat := Rat.new()
	rat.setup(world, rats.size() + 1, team, class_id, is_bot)
	var slot := 0
	for r in rats:
		if r.team == team:
			slot += 1
	rat.position = MapGenerator.spawn_point(team, slot)
	rat.yaw = -PI / 2.0 if team == 0 else PI / 2.0
	rat.display_name = BOT_NAMES[(rat.id * 3 + team) % BOT_NAMES.size()] if is_bot else "You"
	rat.name = "Rat%d" % rat.id
	rat.scrap = 6
	if free_mode:
		rat.flying = false
	add_child(rat)
	rats.append(rat)
	if is_bot:
		bots.append(BotBrain.new(self, rat, _rng.randi()))
	rat_spawned.emit(rat)
	return rat


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
	time += dt
	if not over:
		for b in bots:
			b.think(dt)
	for r in rats:
		if over:
			r.wish = Vector3.ZERO
			r.jump_pressed = false
			r.dash_pressed = false
		r.step(dt)
		if r.landed_on_spring:
			fx.emit("spring", r.position, null)
		_check_rat_hazards(r)
		_check_raid(r, dt)
	_step_pickups(dt)
	_step_tnt(dt)
	dynamite.step(dt)
	siege.step(dt)
	lava.step(dt)
	for i in range(markers.size() - 1, -1, -1):
		markers[i]["ttl"] = float(markers[i]["ttl"]) - dt
		if float(markers[i]["ttl"]) <= 0.0:
			markers.remove_at(i)


func _check_rat_hazards(r: Rat) -> void:
	if over:
		return
	var here := world.block_at(r.position + Vector3(0, 0.2, 0))
	if here == Blocks.LAVA and not r.flying:
		toast.emit("%s got a hot tail! Back to base." % r.display_name, r.team)
		respawn(r)
		return
	if r.position.y < -4.0:
		respawn(r)
		return
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
	if Blocks.is_sticky(here) and (0 if here == Blocks.STICKY_BLUE else 1) != r.team and not r.flying:
		r.slow = maxf(r.slow, 1.2)
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
		score_changed.emit()
		fx.emit("pickup", r.position, r.team)
		toast.emit("%s stole a cheese from the %s vault!" % [r.display_name, TEAM_NAMES[enemy]], -1)


func _deposit(r: Rat) -> void:
	var n := r.carried
	r.carried = 0
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
	if over or rat.stun > 0.0 or rat.dig_cd > 0.0:
		return false
	if not VoxelWorld.in_bounds(cell):
		return false
	if (Vector3(cell) + Vector3(0.5, 0.5, 0.5)).distance_to(rat.eye()) > Config.DIG_REACH + 1.0:
		return false
	var id := world.get_cell(cell)
	if Blocks.TARGETABLE[id] == 0:
		return false
	rat.dig_cd = 1.0 / Config.DIG_RATE
	rat.play_action("dig", 0.28)
	if id == Blocks.TNT:
		light_tnt(cell, 2.0)
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
	var hits := int(Blocks.HITS[id])
	if hits <= 0 or power <= 0 or not VoxelWorld.in_bounds(cell):
		return false
	var total := int(world.damage.get(cell, 0)) + power
	if total < hits:
		world.damage[cell] = total
		if not quiet:
			fx.emit("hit", Vector3(cell), {"id": id, "ratio": float(total) / float(hits)})
		return false
	_break(rat, cell, id, quiet)
	return true


func _break(rat: Rat, cell: Vector3i, id: int, quiet := false) -> void:
	# A carved block is only worth the microvoxels still in it.
	var carved := world.micro_count(cell) if world.has_micro(cell) else -1
	world.set_block(cell, Blocks.AIR)
	tnt.erase(cell)
	if not quiet:
		fx.emit("break", Vector3(cell), id)
	var drop := Blocks.drop(id)
	if drop == "cheese":
		spawn_pickup("cheese", Vector3(cell) + Vector3(0.5, 0.3, 0.5), Vector3(0, 2.5, 0))
	elif rat == null:
		return
	elif drop == "scrap":
		var gain := roundi(Config.BASE_SCRAP_PER_BLOCK * multiplier())
		rat.scrap += gain
		fx.emit("scrap", Vector3(cell), gain)
	elif drop.begins_with("mat:"):
		var m := drop.substr(4)
		if carved >= 0:
			_refund_micro(rat, m, carved)
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
	for t in 2:
		if MapGenerator.base_zone(t).grow(0.5).has_point(Vector3(cell) + Vector3(0.5, 0.5, 0.5)):
			return "Bases are protected"
	if replace:
		return ""
	for r in rats:
		if Blocks.solid_for(block, r.team) and r.overlaps_cell(cell):
			return "A rat is in the way"
	return ""


func try_place_mat(rat: Rat, cell: Vector3i, mat: String) -> String:
	if not ClassDefs.MAT_BLOCK.has(mat):
		return "Unknown material"
	if not free_mode and int(rat.mats.get(mat, 0)) <= 0:
		return "No %s left - dig some first" % mat
	var block: int = ClassDefs.MAT_BLOCK[mat]
	var why := can_place_at(rat, cell, block)
	if why != "":
		return why
	if not free_mode:
		rat.mats[mat] = int(rat.mats[mat]) - 1
	world.set_block(cell, block)
	rat.play_action("build", 0.3)
	fx.emit("place", Vector3(cell), block)
	return ""


func try_place_paint(rat: Rat, cell: Vector3i, color: int) -> String:
	## A full block in one of the palette colours. Painted blocks are dyed
	## stone: each costs one stone, and gives it back when dug.
	if color < 0 or color >= Blocks.PALETTE_SIZE:
		return "Unknown colour"
	if not free_mode and int(rat.mats["stone"]) <= 0:
		return "Painted blocks are made from stone - dig some first"
	var block := Blocks.PAINT_0 + color
	var why := can_place_at(rat, cell, block)
	if why != "":
		return why
	if not free_mode:
		rat.mats["stone"] = int(rat.mats["stone"]) - 1
	world.set_block(cell, block)
	rat.play_action("build", 0.3)
	fx.emit("place", Vector3(cell), block)
	return ""


func hit_gate(cell: Vector3i, amount: int) -> void:
	## Gates have their own toughness: Config.GATE_HP wrecking-ball hits, or two TNT blasts.
	gate_damage[cell] = int(gate_damage.get(cell, 0)) + amount
	if int(gate_damage[cell]) >= Config.GATE_HP:
		gate_damage.erase(cell)
		var id := world.get_cell(cell)
		world.set_block(cell, Blocks.AIR)
		fx.emit("break", Vector3(cell), id)


func try_place_gadget(rat: Rat, cell: Vector3i, gadget: String = "", dir := Vector3.ZERO, reach := -1.0, replace := false) -> String:
	## `dir` (optional) is the direction a conveyor should run; default is the
	## rat's facing. `replace` lays the gadget into the block at `cell`.
	var g := gadget if gadget != "" else rat.equipped
	if g == "" or not ClassDefs.GADGET_NAME.has(g):
		return "Nothing equipped - buy gadgets at the workshop (B)"
	if g == "dynamite":
		return "Mobile TNT is thrown, not placed"
	if not free_mode and int(rat.gadgets.get(g, 0)) <= 0:
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
	var why := can_place_at(rat, cell, block, reach, replace)
	if why != "":
		return why
	if not free_mode:
		rat.gadgets[g] = int(rat.gadgets[g]) - 1
		if replace:   # the floor block you swapped out goes into your stash, as if dug
			var mat := Blocks.mat_of(old)
			rat.mats[mat] = mini(int(rat.mats[mat]) + 1, 99)
	world.set_block(cell, block)
	if block == Blocks.TNT:
		tnt[cell] = {"owner": rat.id, "fuse": -1.0}
	elif Blocks.is_machine(block):
		siege.register(cell, block, rat)
	rat.play_action("build", 0.3)
	fx.emit("place", Vector3(cell), block)
	return ""


func try_use_equipped(rat: Rat, aim: Dictionary, look: Vector3, gentle: bool, dir := Vector3.ZERO) -> String:
	## The Q key: throw Mobile TNT, or place the equipped gadget at the aim.
	if rat.equipped == "dynamite":
		return dynamite.try_throw(rat, look, gentle)
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
	# Conveyors are laid INTO the floor block you point at. (Highways are a
	# thin layer that lies on top of the face instead.)
	if g == "conveyor" and normal.y == 1 and _is_floor_material(aimed):
		return try_place_gadget(rat, aimed, g, dir, -1.0, true)
	return try_place_gadget(rat, aimed + normal, g, dir)


func _is_floor_material(cell: Vector3i) -> bool:
	var id := world.get_cell(cell)
	return (id == Blocks.DIRT or id == Blocks.GRASS or id == Blocks.STONE or id == Blocks.WOOD or id == Blocks.BRICK \
		or id == Blocks.ICE) and not world.has_micro(cell)


# ---------------------------------------------------------------- chisel

func _micro_available(rat: Rat, mat: String) -> int:
	return int(rat.micro_bank.get(mat, 0)) + int(rat.mats.get(mat, 0)) * Blocks.MICRO_COUNT


func _pay_micro(rat: Rat, mat: String, n: int) -> bool:
	## Spend n microvoxels of a material, breaking whole blocks into the
	## rat's spare-change bank as needed. All or nothing.
	if free_mode:
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
	if free_mode:
		return
	var bank := int(rat.micro_bank.get(mat, 0)) + n
	while bank >= Blocks.MICRO_COUNT and int(rat.mats[mat]) < 99:
		bank -= Blocks.MICRO_COUNT
		rat.mats[mat] = int(rat.mats[mat]) + 1
	rat.micro_bank[mat] = mini(bank, Blocks.MICRO_COUNT * 2)


func _chisel_gate(rat: Rat, cell: Vector3i, mv: Vector3i) -> String:
	if over or rat.stun > 0.0:
		return "Can't chisel right now"
	if rat.chisel_cd > 0.0:
		return "wait"
	if not VoxelWorld.in_bounds(cell) or mv.x < 0 or mv.y < 0 or mv.z < 0 or mv.x >= Blocks.MICRO or mv.y >= Blocks.MICRO or mv.z >= Blocks.MICRO:
		return "Out of bounds"
	var p := Vector3(cell) + (Vector3(mv) + Vector3(0.5, 0.5, 0.5)) / float(Blocks.MICRO)
	if p.distance_to(rat.eye()) > Config.DIG_REACH + 0.6:
		return "Too far"
	return ""


func try_chisel_remove(rat: Rat, cell: Vector3i, mv: Vector3i) -> String:
	var why := _chisel_gate(rat, cell, mv)
	if why != "":
		return why
	var id := world.get_cell(cell)
	if not Blocks.CHISELABLE.has(id):
		return "%s can't be chiseled" % Blocks.block_name(id)
	if not world.micro_at(cell, mv):
		return "Nothing there to carve"
	rat.chisel_cd = 1.0 / Config.CHISEL_RATE
	world.set_micro(cell, mv, false)
	_refund_micro(rat, Blocks.mat_of(id), 1)
	rat.play_action("build", 0.2)
	fx.emit("chip", Vector3(cell) + Vector3(mv) / float(Blocks.MICRO), id)
	return ""


func try_chisel_add(rat: Rat, cell: Vector3i, mv: Vector3i, mat: String, color := -1) -> String:
	## `color` >= 0 adds a painted microvoxel in that palette colour.
	var why := _chisel_gate(rat, cell, mv)
	if why != "":
		return why
	var id := world.get_cell(cell)
	var block := id
	var value := 1
	if color >= Blocks.PALETTE_SIZE:
		return "Unknown colour"
	if color >= 0 and id != Blocks.AIR and id != Blocks.PAINT_0 + color:
		value = 2 + color      # a dab of colour on a block of another material
	if id == Blocks.AIR:
		if color >= 0:
			block = Blocks.PAINT_0 + color
		elif not ClassDefs.MAT_BLOCK.has(mat):
			return "Pick a material (1-6) first"
		else:
			block = ClassDefs.MAT_BLOCK[mat]
		for t in 2:
			if MapGenerator.base_zone(t).grow(0.5).has_point(Vector3(cell) + Vector3(0.5, 0.5, 0.5)):
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
		for t in 2:
			if MapGenerator.base_zone(t).grow(0.5).has_point(Vector3(c) + Vector3(0.5, 0.5, 0.5)):
				return "Bases are protected"
		for r in rats:
			if r.overlaps_cell(c):
				return "A rat is in the way"
	if not free_mode:
		var need := bp.cost()
		for mat: String in need:
			if _micro_available(rat, mat) < int(need[mat]):
				return "Not enough %s: need %.1f blocks, have %.1f" % [mat, float(need[mat]) / 343.0, float(_micro_available(rat, mat)) / 343.0]
	return ""


func try_paste(rat: Rat, bp: Blueprint, origin: Vector3i) -> String:
	## All or nothing: validated in full, paid in full, then built in full.
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


func drop_cheese(rat: Rat) -> bool:
	if rat.carried <= 0:
		return false
	_drop(rat, 1, 1.0)
	return true


func try_bonk(rat: Rat, target: Rat) -> bool:
	if over or rat == target or target == null:
		return false
	if rat.team == target.team or rat.bonk_cd > 0.0 or rat.stun > 0.0:
		return false
	if rat.center().distance_to(target.center()) > Config.BONK_RANGE:
		return false
	rat.bonk_cd = Config.BONK_COOLDOWN
	rat.dig_cd = 1.0 / Config.DIG_RATE
	rat.play_action("attack", 0.3)
	var dir := target.position - rat.position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
	target.vel = dir * 7.0 + Vector3(0, 5.0, 0)
	target.knock = 0.4
	target.on_floor = false
	if target.carried > 0:
		_drop(target, 1, Config.BONK_PICKUP_LOCK)
	fx.emit("bonk", target.position, null)
	return true


func respawn(rat: Rat) -> void:
	## Ctrl+K / hazards. Carried cheese and the material stash stay behind as
	## pickups (moved, not copied), then the rat returns to base empty-pawed.
	siege.release(rat)
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
	var slot := rat.id % 4
	rat.position = MapGenerator.spawn_point(rat.team, slot)
	rat.vel = Vector3.ZERO
	rat.stun = 0.0
	rat.knock = 0.0
	rat.unstick()
	fx.emit("respawn", rat.position, null)


func _step_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		p.lock_t = maxf(0.0, p.lock_t - dt)
		# tiny point-physics: fall, rest on solids, ride conveyors, float out of lava
		var here := world.block_at(p.pos)
		if here == Blocks.LAVA or world.solid_point(p.pos):
			p.pos.y = floorf(p.pos.y) + 1.15
			p.vel = Vector3.ZERO
		else:
			p.vel.y = maxf(p.vel.y - 20.0 * dt, -20.0)
			var np := p.pos + p.vel * dt
			var below := world.block_at(Vector3(p.pos.x, np.y - 0.15, p.pos.z))
			if world.solid_point(Vector3(p.pos.x, np.y - 0.15, p.pos.z)) and p.vel.y <= 0.0:
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
			if world.solid_point(Vector3(np.x, np.y, p.pos.z)):
				np.x = p.pos.x
				p.vel.x = 0.0
			if world.solid_point(Vector3(np.x, np.y, np.z)):
				np.z = p.pos.z
				p.vel.z = 0.0
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
				elif Blocks.is_gate(id):
					hit_gate(c, (Config.GATE_HP + 1) / 2)
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


# ---------------------------------------------------------------- abilities

func use_ability(rat: Rat, slot: int, aim: Dictionary = {}) -> String:
	## Returns "" on success or a reason string for the HUD.
	if over or rat.stun > 0.0:
		return "Can't do that right now"
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
		"teamblock": err = _ab_teamblock(rat, aim)
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


func _ab_teamblock(rat: Rat, aim: Dictionary) -> String:
	## Builder: a block in team colours that only teammates can stand on or
	## remove. Enemies (and loose objects) pass straight through it.
	if aim.is_empty():
		return "Aim at a surface to place a Team Block"
	var cell := Vector3i(aim["cell"]) + Vector3i(aim["normal"])
	var block := Blocks.TEAM_BLUE if rat.team == 0 else Blocks.TEAM_RED
	var why := can_place_at(rat, cell, block)
	if why != "":
		return why
	world.set_block(cell, block)
	fx.emit("place", Vector3(cell), block)
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


func try_buy(rat: Rat, item_id: String) -> String:
	var item := ClassDefs.shop_item(item_id)
	if item.is_empty():
		return "Unknown item"
	if over:
		return "Match is over"
	if not can_shop(rat):
		return "Return to your base to use the workshop"
	var cost := 0 if (free_mode or (rat.cls.get("free_items", []) as Array).has(item_id)) else int(item["cost"])
	if rat.scrap < cost:
		return "Need %d scrap (you have %d)" % [cost, rat.scrap]
	var qty := int(item["qty"])
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
