class_name MatchView
extends Node3D
## Presentation layer for a Match: sounds, particles, effect sprites (FxSprite),
## cheese pickups, crack overlay, floating text. Listens to Match signals and
## reads state; it never changes gameplay. Delete this node and the match still
## plays identically.

var m: Match
var listener: Rat

var _pickups: Dictionary = {}       # uid -> MeshInstance3D
var _particle_mat: StandardMaterial3D
var _crack: MeshInstance3D
var _crack_t := 0.0
var _t := 0.0


func _ready() -> void:
	m.fx.connect(_on_fx)
	m.won.connect(func(_team: int) -> void: Sfx.play("team_victory_fanfare", 0.0, 1.0, 0.0))
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_mat.vertex_color_use_as_albedo = true
	_crack = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.02
	_crack.mesh = box
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(0, 0, 0, 0.3)
	_crack.material_override = cm
	_crack.visible = false
	add_child(_crack)


func _process(delta: float) -> void:
	_t += delta
	_crack_t -= delta
	if _crack_t <= 0.0:
		_crack.visible = false
	# sync pickup visuals with authoritative pickups
	var alive := {}
	for p in m.pickups:
		alive[p.uid] = true
		var node: MeshInstance3D = _pickups.get(p.uid)
		if node == null:
			node = _make_pickup(p.kind)
			_pickups[p.uid] = node
		node.position = p.pos + Vector3(0, 0.12 + 0.08 * sin(_t * 3.0 + p.uid), 0)
		node.rotation.y = _t * 1.5 + p.uid
	for uid: int in _pickups.keys():
		if not alive.has(uid):
			(_pickups[uid] as Node).queue_free()
			_pickups.erase(uid)


func _make_pickup(kind: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if kind == "cheese":
		var wedge := PrismMesh.new()
		wedge.size = Vector3(0.5, 0.34, 0.4)
		wedge.left_to_right = 0.0
		node.mesh = wedge
		mat.albedo_color = Color(1.0, 0.82, 0.18)
	else:
		var sack := BoxMesh.new()
		sack.size = Vector3(0.4, 0.4, 0.4)
		node.mesh = sack
		mat.albedo_color = Color(0.55, 0.4, 0.25)
	node.material_override = mat
	add_child(node)
	return node


func _volume(pos: Vector3) -> float:
	## Distance attenuation in dB; returns -100 when too far to hear.
	if listener == null:
		return 0.0
	var d := listener.position.distance_to(pos)
	return -100.0 if d > 30.0 else -d * 0.7


func _sound(sound: String, pos: Vector3, pitch := 1.0, gain := 0.0) -> void:
	var v := _volume(pos)
	if v > -50.0:
		Sfx.play(sound, v + gain, pitch)


static func _material_sound(id: int) -> String:
	match id:
		Blocks.STONE, Blocks.BRICK, Blocks.ICE, Blocks.GLOW: return "stone"
		Blocks.SCRAP, Blocks.SPRING, Blocks.CONV_XP, Blocks.CONV_XN, Blocks.CONV_ZP, Blocks.CONV_ZN: return "scrap"
		Blocks.OBSIDIAN, Blocks.BEDROCK, Blocks.BASE_BLUE, Blocks.BASE_RED, Blocks.GATE_BLUE, Blocks.GATE_RED: return "obsidian"
		Blocks.WOOD, Blocks.LADDER, Blocks.HIGHWAY, Blocks.SHROOM_STEM, Blocks.TRAP_BLUE, Blocks.TRAP_RED: return "wood"
	return "dirt"


static func break_sheet(id: int) -> String:
	## Which recoloured block-break effect suits a block.
	if id == Blocks.ICE:
		return "break_ice"
	match _material_sound(id):
		"stone": return "break_stone"
		"scrap": return "break_scrap"
		"obsidian": return "break_dark"
		"wood": return "break_wood"
	return "break_dirt"


func _sprite(fx_name: String, at: Vector3, scale_by: float, follow: Node3D = null, seconds := -1.0) -> FxSprite:
	var where := at if follow == null else follow.position + at
	if listener != null and listener.position.distance_to(where) > 45.0:
		return null
	return FxSprite.play(self, fx_name, at, scale_by, follow, seconds)


func _facing_viewer(c: Vector3, by: float) -> Vector3:
	## A point on the side of a block that faces the camera, so an effect on
	## the block is not hidden inside it.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return c
	return c + (cam.global_position - c).normalized() * by


func surface(pos: Vector3, liquid: int) -> Vector3:
	## The top of the pool of `liquid` that `pos` is in (or just above), where a
	## splash belongs. Falls back to `pos` when there is no such pool.
	if m == null or m.world == null:
		return pos
	var c := Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))
	if m.world.get_cell(c) != liquid:
		c.y -= 1
	if m.world.get_cell(c) != liquid:
		return pos
	for i in 4:
		if m.world.get_cell(c + Vector3i.UP) != liquid:
			break
		c.y += 1
	return Vector3(pos.x, c.y + 0.88, pos.z)   # liquid tops sit a little below the cell top


func _nearest_rat(pos: Vector3) -> Rat:
	var best: Rat = null
	var best_d := 2.5
	for r in m.rats:
		var d := r.position.distance_to(pos)
		if d < best_d:
			best = r
			best_d = d
	return best


func _on_fx(kind: String, pos: Vector3, data: Variant) -> void:
	var c := pos + Vector3(0.5, 0.5, 0.5)
	var size := 1.0 if data == null or not (data is float or data is int) else float(data)
	match kind:
		"hit":
			var id := int(data["id"])
			_sound("mine_" + _material_sound(id), c)
			_burst(c, Blocks.COLOR[id], 3, 2.5)
			_sprite("hit", _facing_viewer(c, 0.62), 0.3)
			_crack.visible = true
			_crack.position = c
			_crack_t = 2.5
			(_crack.material_override as StandardMaterial3D).albedo_color = Color(0, 0, 0, 0.12 + 0.45 * float(data["ratio"]))
		"break":
			var bid := int(data)
			_sound("break_" + _material_sound(bid), c)
			_burst(c, Blocks.COLOR[bid], 6, 4.0)
			_sprite(break_sheet(bid), c - Vector3(0, 0.45, 0), 0.7)
			if _crack.position.distance_to(c) < 0.1:
				_crack.visible = false
		"clang":
			_sound("mine_obsidian", c, 1.4)
		"place":
			_sound("block_place", c)
		"bonk":
			_sound("bonk", pos, 1.0, 3.0)
			_sprite("pow", pos + Vector3(0, 0.8, 0), 0.45)
			_float_text(pos + Vector3(0, 1.4, 0), "BONK!", Color(1, 0.95, 0.5))
		"trap":
			_sound("bonk", pos, 1.5, 2.0)
			_sprite("break_wood", pos, 0.6)
			_float_text(pos + Vector3(0, 1.4, 0), "SNAP!", Color(1, 0.6, 0.5))
		"quench":
			_sound("sizzle", c, 1.2, -2.0)
			_sprite("poof", c - Vector3(0, 0.3, 0), 0.5)
		"jetpack":
			_sound("jetratpack_flame", pos, 1.0, 0.0)
			var flier := _nearest_rat(pos)
			var jet := _sprite("jetpack", Vector3(0, 0.55, 0), 0.42, flier, Config.JETPACK_TIME) if flier != null else null
			if jet != null:
				jet.offset.x -= 0.22 / jet.pixel_size   # on the rat's back (rat sprites face right)
			elif flier == null:
				_burst(pos + Vector3(0, 0.2, 0), Color(1.0, 0.6, 0.15), 14, 3.0)
		"dash":
			_sprite("dust", pos, 0.45)
		"jump":
			_sprite("dust", pos, 0.3)
		"land":
			_sound("mine_dirt", pos, 0.6, -6.0)
			_sprite("dust", pos, 0.7)
		"splash":
			_sound("splash", pos, 1.0 if size >= 1.0 else 1.4, 0.0 if size >= 1.0 else -6.0)
			_sprite("splash", surface(pos, Blocks.WATER), 0.85 * size)
		"splash_out":
			_sound("splash", pos, 1.35, -5.0)
			_sprite("splash", surface(pos, Blocks.WATER), 0.55 * size)
		"lava":
			_sound("sizzle", pos, 1.0, 0.0)
			_sound("tnt_pop", pos, 1.6, -6.0)
			_sprite("splash_lava", surface(pos, Blocks.LAVA), 0.85)
			_float_text(pos + Vector3(0, 1.2, 0), "HOT!", Color(1.0, 0.55, 0.2))
		"sizzle":
			_sound("sizzle", pos, 1.3, -6.0)
			_sprite("splash_lava", surface(pos, Blocks.LAVA), 0.85 * size)
		"spring":
			_sound("block_place", pos, 1.8, 2.0)
			_float_text(pos + Vector3(0, 0.6, 0), "BOING!", Color(0.7, 1.0, 0.6))
		"pickup":
			_sound("cheese_munch", pos)
			_sprite("collect", pos, 0.55)
		"pickup_stash":
			_sound("block_place", pos, 1.3)
			_sprite("collect", pos, 0.45)
		"scrap":
			_sound("discovery_chime", c, 1.2, -4.0)
			_float_text(c + Vector3(0, 0.4, 0), "+%d scrap" % int(data), Color(1.0, 0.75, 0.4))
		"deposit":
			Sfx.play("cheese_deposit_fanfare", -2.0, 1.0, 0.0)
			_sprite("firework", pos + Vector3(0, 2.4, 0), 0.6)
			_burst(pos + Vector3(0, 1.0, 0), UiKit.TEAM[int(data)], 20, 7.0)
		"fuse":
			_sound("siege_grind", c, 1.6)
			_float_text(c + Vector3(0, 0.8, 0), "!!", Color(1, 0.3, 0.2), maxf(float(data), 0.4))
		"boom":
			_sound("tnt_pop", pos, 1.0, 6.0)
			_sound("siege_impact", pos, 1.0, 3.0)
			_burst(pos, Color(0.3, 0.28, 0.28), 16, 6.0)
			_sprite("explosion", pos - Vector3(0, 0.5, 0), clampf(size / 3.0, 0.5, 1.4))
		"chip":
			_sound("mine_" + _material_sound(int(data)), pos, 1.7, -8.0)
			_burst(pos + Vector3.ONE * 0.07, Blocks.COLOR[int(data)], 2, 1.5)
		"throw":
			_sound("block_place", pos, 1.5)
		"tick":
			_sound("mine_wood", pos, 1.9, -6.0)
		"cannon":
			_sound("siege_cannon", pos, 1.0, 4.0)
			_sprite("poof", pos - Vector3(0, 0.3, 0), 0.6)
			_smoke(pos, 1.0)
		"impact":
			_sound("siege_impact", pos, 1.1, 3.0)
			_burst(pos, Blocks.COLOR[int(data)], 12, 6.0)
			_sprite(break_sheet(int(data)), pos - Vector3(0, 0.4, 0), 0.9)
			_sprite("hit", _facing_viewer(pos, 0.3), 0.45)
		"thud":
			_sound("siege_impact", pos, 0.7, 0.0)
			_sprite("dust", pos - Vector3(0, 0.3, 0), 0.6)
		"crane", "dozer":
			_sound("siege_grind", pos, 0.9 if kind == "dozer" else 1.2, -2.0)
		"ability", "buy":
			_sound("discovery_chime", pos, 1.0, -3.0)
		"alarm":
			Sfx.play("siege_grind", -2.0, 1.9, 0.0)
		"respawn":
			_sound("block_place", pos, 0.7)
			_sprite("poof", pos, 0.7)


func _smoke(pos: Vector3, size: float) -> void:
	## A few slow grey puffs that drift up and fade.
	if listener != null and listener.position.distance_to(pos) > 45.0:
		return
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.4 * clampf(size * 0.5, 0.6, 1.6)
	mesh.material = _particle_mat
	p.mesh = mesh
	p.amount = 12
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 1.2, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.33, 0.32, 1.0))
	ramp.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	p.color_ramp = ramp
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _burst(pos: Vector3, color: Color, amount: int, speed: float) -> void:
	if listener != null and listener.position.distance_to(pos) > 45.0:
		return
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.13
	mesh.material = _particle_mat
	p.mesh = mesh
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -16, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = Color(color.r, color.g, color.b, 1.0)
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _float_text(pos: Vector3, text: String, color: Color, life := 0.9) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0016
	l.font_size = 30
	l.outline_size = 10
	l.modulate = color
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", pos + Vector3(0, 1.0, 0), life)
	tw.parallel().tween_property(l, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
