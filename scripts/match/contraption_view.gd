class_name ContraptionView
extends Node3D
## Presentation for the moving toys: siege machines, cannonballs, Mobile TNT,
## the cannon's aiming arc and the bulldozer's blade footprint. Reads
## SiegeSystem / DynamiteSystem state every frame; changes nothing.

const WOOD := Color(0.55, 0.38, 0.22)
const IRON := Color(0.25, 0.25, 0.29)
const BRASS := Color(0.85, 0.65, 0.25)
const HAZARD := Color(0.95, 0.75, 0.15)

var m: Match
var ctl: PlayerController

var _mat: StandardMaterial3D
var _machines: Dictionary = {}   # uid -> {root, turret, barrel, cable, ball, blade}
var _sticks: Dictionary = {}     # uid -> Node3D
var _shots: Dictionary = {}      # uid -> MeshInstance3D
var _dots: Array[MeshInstance3D] = []
var _blade_cells: Array[MeshInstance3D] = []
var _t := 0.0


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	var dot_mat := PlayerController._clear_mat(Color(1, 1, 1, 0.75))
	for i in 16:
		var d := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		d.mesh = sphere
		d.material_override = dot_mat
		d.visible = false
		add_child(d)
		_dots.append(d)
	var blade_mat := PlayerController._clear_mat(Color(1.0, 0.7, 0.1, 0.3))
	for i in 6:
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 1.02
		b.mesh = box
		b.material_override = blade_mat
		b.visible = false
		add_child(b)
		_blade_cells.append(b)


func _part(boxes: Array) -> MeshInstance3D:
	## Builds one mesh from [min, max, colour] box triples.
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for b: Array in boxes:
		ChunkMesher._box(v, c, b[0], b[1], b[2])
	var mesh := ArrayMesh.new()
	ChunkMesher._commit(mesh, v, c, _mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _build(mc: SiegeSystem.Machine) -> Dictionary:
	var team: Color = UiKit.TEAM[mc.team]
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(mc.cell)
	var parts := {"root": root}
	match mc.kind:
		Blocks.CANNON:
			root.add_child(_part([
				[Vector3(0.08, 0, 0.08), Vector3(0.92, 0.45, 0.92), WOOD],
				[Vector3(0.0, 0.05, 0.2), Vector3(0.08, 0.6, 0.8), IRON], [Vector3(0.92, 0.05, 0.2), Vector3(1.0, 0.6, 0.8), IRON],
				[Vector3(0.2, 0.45, 0.2), Vector3(0.8, 0.55, 0.8), team]]))
			var turret := Node3D.new()
			turret.position = Vector3(0.5, 0.55, 0.5)
			root.add_child(turret)
			turret.add_child(_part([[Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.5, 0.3), BRASS]]))
			var barrel := _part([
				[Vector3(-0.2, -0.2, -1.25), Vector3(0.2, 0.2, 0.35), IRON],
				[Vector3(-0.26, -0.26, -1.3), Vector3(0.26, 0.26, -1.05), BRASS]])
			barrel.position = Vector3(0, 0.7, 0)
			turret.add_child(barrel)
			parts["turret"] = turret
			parts["barrel"] = barrel
		Blocks.CRANE:
			root.add_child(_part([
				[Vector3(0.05, 0, 0.05), Vector3(0.95, 0.5, 0.95), HAZARD],
				[Vector3(0.36, 0.5, 0.36), Vector3(0.64, SiegeSystem.CRANE_MAST, 0.64), IRON],
				[Vector3(0.2, 0.5, 0.2), Vector3(0.8, 0.62, 0.8), team]]))
			var top := Node3D.new()
			top.position = Vector3(0.5, SiegeSystem.CRANE_MAST, 0.5)
			root.add_child(top)
			top.add_child(_part([
				[Vector3(-0.12, -0.1, -SiegeSystem.CRANE_REACH), Vector3(0.12, 0.12, 0.9), HAZARD],
				[Vector3(-0.3, -0.35, 0.5), Vector3(0.3, 0.2, 1.0), IRON]]))
			parts["turret"] = top
			var cable := _part([[Vector3(-0.03, -0.5, -0.03), Vector3(0.03, 0.5, 0.03), IRON]])
			add_child(cable)
			parts["cable"] = cable
			var ball := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = SiegeSystem.BALL_RADIUS
			sphere.height = SiegeSystem.BALL_RADIUS * 2.0
			ball.mesh = sphere
			var bm := StandardMaterial3D.new()
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.albedo_color = IRON.lerp(team, 0.25)
			ball.material_override = bm
			add_child(ball)
			parts["ball"] = ball
		_:
			root.add_child(_part([[Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.18, 1.0), IRON]]))
			var body := Node3D.new()
			body.position = Vector3(0.5, 0, 0.5)
			root.add_child(body)
			body.add_child(_part([
				[Vector3(-0.42, 0.18, -0.3), Vector3(0.42, 0.75, 0.46), HAZARD],
				[Vector3(-0.3, 0.75, 0.0), Vector3(0.3, 1.2, 0.42), team],
				[Vector3(-0.1, 0.3, -0.5), Vector3(0.1, 0.5, -0.3), IRON]]))
			var blade := _part([
				[Vector3(-1.48, 0.02, -0.14), Vector3(1.48, 1.7, 0.0), Color(0.72, 0.74, 0.78)],
				[Vector3(-1.48, 0.02, -0.26), Vector3(1.48, 0.3, -0.14), Color(0.55, 0.57, 0.62)]])
			blade.position = Vector3(0, 0, -0.5)
			body.add_child(blade)
			parts["turret"] = body
			parts["blade"] = blade
	return parts


func _process(delta: float) -> void:
	_t += delta
	var alive := {}
	for mc: SiegeSystem.Machine in m.siege.machines.values():
		alive[mc.uid] = true
		if not _machines.has(mc.uid):
			_machines[mc.uid] = _build(mc)
		var p: Dictionary = _machines[mc.uid]
		var root: Node3D = p["root"]
		var target := Vector3(mc.cell)
		# glide between cells instead of snapping (conveyors move a block at a time)
		if root.position.distance_to(target) > 2.5:
			root.position = target
		else:
			root.position = root.position.move_toward(target, delta * (9.0 if absf(target.y - root.position.y) > 0.01 else 1.0 / Config.MACHINE_MOVE_TIME))
		var lag := root.position - target
		match mc.kind:
			Blocks.CANNON:
				(p["turret"] as Node3D).rotation.y = mc.yaw
				(p["barrel"] as Node3D).rotation.x = mc.pitch
				(p["barrel"] as Node3D).position.z = mc.recoil * 0.25
			Blocks.CRANE:
				(p["turret"] as Node3D).rotation.y = mc.yaw
				var fwd := Vector3(-sin(mc.yaw), 0, -cos(mc.yaw))
				var tip := Vector3(mc.cell) + Vector3(0.5, SiegeSystem.CRANE_MAST, 0.5) + fwd * SiegeSystem.CRANE_REACH + lag
				var ball := SiegeSystem.ball_pos(mc) + lag
				(p["ball"] as Node3D).position = ball
				var cable: Node3D = p["cable"]
				cable.position = (tip + ball) * 0.5
				cable.scale = Vector3(1, tip.distance_to(ball), 1)
				cable.rotation = Vector3(-mc.theta, mc.yaw, 0)
			Blocks.DOZER:
				var f := SiegeSystem.facing(mc)
				var body: Node3D = p["turret"]
				# swing round to the new heading rather than snapping
				body.rotation.y = lerp_angle(body.rotation.y, atan2(-float(f.x), -float(f.z)), minf(1.0, delta * 12.0))
				(p["blade"] as Node3D).position.z = -0.5 - mc.recoil * 0.45
	for uid: int in _machines.keys():
		if not alive.has(uid):
			for node: Variant in (_machines[uid] as Dictionary).values():
				if is_instance_valid(node) and not (node as Node).is_queued_for_deletion() and (node as Node).get_parent() == self:
					(node as Node).queue_free()
			_machines.erase(uid)
	_sync_shots()
	_sync_sticks(delta)
	_previews()


func _sync_shots() -> void:
	var alive := {}
	for s in m.siege.shots:
		alive[s.uid] = true
		var node: MeshInstance3D = _shots.get(s.uid)
		if node == null:
			node = MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			node.mesh = sphere
			var sm := StandardMaterial3D.new()
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.albedo_color = Color(0.2, 0.18, 0.18)
			node.material_override = sm
			add_child(node)
			_shots[s.uid] = node
		node.position = s.pos
	for uid: int in _shots.keys():
		if not alive.has(uid):
			(_shots[uid] as Node).queue_free()
			_shots.erase(uid)


func _sync_sticks(delta: float) -> void:
	var alive := {}
	for s in m.dynamite.sticks:
		alive[s.uid] = true
		var node: Node3D = _sticks.get(s.uid)
		if node == null and s.impulse:
			# an Impulse Grenade: a blue puck with a bright band and a light on top
			node = _part([
				[Vector3(-0.12, -0.09, -0.12), Vector3(0.12, 0.09, 0.12), Color(0.2, 0.42, 0.95)],
				[Vector3(-0.13, -0.025, -0.13), Vector3(0.13, 0.025, 0.13), Color(0.75, 0.95, 1.0)]])
			var light := _part([[Vector3(-0.045, 0.09, -0.045), Vector3(0.045, 0.15, 0.045), Color(0.85, 1.0, 1.0)]])
			light.name = "Spark"
			node.add_child(light)
			add_child(node)
			_sticks[s.uid] = node
		elif node == null:
			node = _part([
				[Vector3(-0.07, -0.17, -0.07), Vector3(0.07, 0.17, 0.07), Color(0.9, 0.14, 0.12)],
				[Vector3(-0.075, -0.05, -0.075), Vector3(0.075, 0.05, 0.075), Color(0.98, 0.9, 0.75)],
				[Vector3(-0.015, 0.17, -0.015), Vector3(0.015, 0.27, 0.015), Color(0.3, 0.25, 0.2)]])
			var spark := _part([[Vector3(-0.05, 0.25, -0.05), Vector3(0.05, 0.35, 0.05), Color(1.0, 0.9, 0.3)]])
			spark.name = "Spark"
			node.add_child(spark)
			add_child(node)
			_sticks[s.uid] = node
		node.position = s.pos + Vector3(0, 0.05, 0)
		if s.impulse:
			node.position = s.pos
			if not s.stuck:
				node.rotation += Vector3(s.vel.z, 0, -s.vel.x) * delta * 2.2
			var blink := 30.0 if s.stuck else 8.0     # stuck: about to go
			(node.get_node("Spark") as Node3D).scale = Vector3.ONE * (0.5 + 1.0 * absf(sin(_t * blink)))
			continue
		# tumble with speed; a resting stick lies on its side
		var spin := Vector3(s.vel.z, 0, -s.vel.x) * delta * 2.2
		node.rotation += spin
		if s.resting and s.vel.length() < 0.3:
			node.rotation.z = lerp_angle(node.rotation.z, PI / 2.0, 0.2)
		# animated fuse: blinks faster as it runs out
		var rate := 6.0 + 30.0 * (1.0 - clampf(s.fuse / Config.DYNAMITE_FUSE, 0.0, 1.0))
		var spark_node := node.get_node("Spark") as Node3D
		spark_node.scale = Vector3.ONE * (0.6 + 0.9 * absf(sin(_t * rate)))
	for uid: int in _sticks.keys():
		if not alive.has(uid):
			(_sticks[uid] as Node).queue_free()
			_sticks.erase(uid)


func _previews() -> void:
	var mc: SiegeSystem.Machine = ctl.machine() if ctl != null else null
	var arc: Array[Vector3] = []
	var cells: Array[Vector3i] = []
	if mc != null and mc.kind == Blocks.CANNON:
		arc = m.siege.predict(mc, _dots.size())
	elif mc != null and mc.kind == Blocks.DOZER:
		cells = SiegeSystem.dozer_cells(mc)
	for i in _dots.size():
		_dots[i].visible = i < arc.size()
		if i < arc.size():
			_dots[i].position = arc[i]
			_dots[i].scale = Vector3.ONE * (2.2 if i == arc.size() - 1 else 1.0)
	for i in _blade_cells.size():
		_blade_cells[i].visible = i < cells.size()
		if i < cells.size():
			_blade_cells[i].position = Vector3(cells[i]) + Vector3(0.5, 0.5, 0.5)
