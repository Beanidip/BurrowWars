class_name GameSession
extends Node
## Composes one playable session: Match (rules) + MatchView (juice) +
## PlayerController (input/camera) + Hud (interface) + environment.

signal exit_requested
signal rematch_requested

var settings: Dictionary = {}
var net_info: Dictionary = {}   # online client: the server's welcome
var m: Match
var net: Node                   # NetServer when hosting, NetClient when joined
var player: Rat
var ctl: PlayerController
var hud: Hud


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.56, 0.78, 0.93)
	e.fog_enabled = true
	e.fog_light_color = Color(0.56, 0.78, 0.93)
	e.fog_density = 0.006
	env.environment = e
	add_child(env)

	# a calm sea around the island so the world edge never shows a void
	# (a frame around the island, not a sheet through it: underground you
	# must never see the sea surface cutting across your tunnels)
	var sea := MeshInstance3D.new()
	var sv := PackedVector3Array()
	var far := 450.0
	var sx := float(VoxelWorld.SX) * 0.5
	var sz := float(VoxelWorld.SZ) * 0.5
	for r: Array in [[-far, -far, far, -sz], [-far, sz, far, far], [-far, -sz, -sx, sz], [sx, -sz, far, sz]]:
		var a := Vector3(r[0], 0, r[1])
		var b := Vector3(r[2], 0, r[1])
		var c := Vector3(r[2], 0, r[3])
		var d := Vector3(r[0], 0, r[3])
		sv.append_array([a, b, c, a, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sv
	var plane := ArrayMesh.new()
	plane.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	sea.mesh = plane
	var sea_mat := StandardMaterial3D.new()
	sea_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sea_mat.albedo_color = Color(0.22, 0.47, 0.72)
	sea_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sea.material_override = sea_mat
	sea.position = Vector3(VoxelWorld.SX * 0.5, MapGenerator.GROUND - 3.4, VoxelWorld.SZ * 0.5)
	add_child(sea)

	m = Match.new()
	m.name = "Match"
	add_child(m)
	var online_client := String(settings.get("net", "")) == "client"
	m.setup(settings, true, online_client)
	m.rat_spawned.connect(_attach_sprite)
	if online_client:
		var nc := NetClient.new(m, net_info)
		nc.name = "NetClient"
		net = nc
		add_child(nc)
		player = nc.me()
		player.net_local = true
	else:
		var team := int(settings.get("team", 0))
		player = m.spawn_rat(team, String(settings.get("class", "digger")), false)
		if not m.free_mode:
			var size := int(settings.get("team_size", 2))
			var pick := 1
			for i in size - 1:
				m.spawn_rat(team, ClassDefs.ORDER[pick % 4], true)
				pick += 1
			for i in size:
				m.spawn_rat(1 - team, ClassDefs.ORDER[(pick + i) % 4], true)
		if String(settings.get("net", "")) == "host":
			if Net.player_name != "":
				player.display_name = Net.player_name
			var ns := NetServer.new()
			ns.name = "NetServer"
			ns.m = m
			net = ns
			add_child(ns)

	ctl = PlayerController.new()
	ctl.m = m
	ctl.rat = player
	add_child(ctl)

	var view := MatchView.new()
	view.m = m
	view.listener = player
	add_child(view)

	var toys := ContraptionView.new()
	toys.m = m
	toys.ctl = ctl
	add_child(toys)

	hud = Hud.new()
	hud.m = m
	hud.rat = player
	hud.ctl = ctl
	add_child(hud)
	if net is NetClient:
		(net as NetClient).notice.connect(func(text: String) -> void: ctl.notice.emit(text))
	hud.exit_requested.connect(func() -> void: exit_requested.emit())
	hud.rematch_requested.connect(func() -> void: rematch_requested.emit())
	m.won.connect(_celebrate)
	m.world.rebuild_near(player.position, 56.0)   # the rest of this big map streams in over the next frames


func _attach_sprite(rat: Rat) -> void:
	var sprite := RatSprite.new()
	sprite.name = "Sprite"
	sprite.rat = rat
	rat.add_child(sprite)


func _celebrate(team: int) -> void:
	for r in m.rats:
		var s := r.get_node_or_null("Sprite") as RatSprite
		if s != null and r.team == team:
			s.celebrate = true


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
