class_name GameSession
extends Node
## Composes one playable session: Match (rules) + MatchView (juice) +
## PlayerController (input/camera) + Hud (interface) + environment.

signal exit_requested
signal rematch_requested
signal start_requested          # the host ends the lobby: start the match

var settings: Dictionary = {}
var net_info: Dictionary = {}   # online client: the server's welcome
var loading: LoadingScreen      # Main's loading screen, lifted once the world is meshed (null: mesh near the player now)
var loaded := false             # the world is meshed and the match running
var _built_at := 0             # msec the session started building (for the log)
var m: Match
var net: Node                   # NetServer when hosting, NetClient when joined
var player: Rat
var ctl: PlayerController
var hud: Hud


func _ready() -> void:
	_built_at = Time.get_ticks_msec()
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
	m.windup_spawned.connect(_attach_windup)
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
	view.ctl = ctl
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
	hud.start_requested.connect(func() -> void: start_requested.emit())
	m.won.connect(_celebrate)
	if bool(settings.get("tutorial", false)) and not online_client:
		var guide := TutorialGuide.new()
		guide.name = "Tutorial"
		guide.m = m
		guide.rat = player
		add_child(guide)
		guide.setup()
		m.fx.connect(guide.on_fx)
	if loading != null:
		# behind the loading screen: the match waits while every core meshes the world
		m.auto_step = false
		m.world.prebuilt.connect(_on_prebuilt, CONNECT_ONE_SHOT)
		m.world.start_prebuild(player.position)
	else:
		m.world.rebuild_near(player.position, 56.0)   # the rest of this big map streams in over the next frames
		loaded = true


func _on_prebuilt() -> void:
	m.auto_step = true
	loaded = true
	Log.info("match ready: %s, %d rats, map built in %d ms" % [String(settings.get("mode", "race")), m.rats.size(), Time.get_ticks_msec() - _built_at])
	if loading != null and is_instance_valid(loading):
		loading.finish()
	loading = null


var _tag_t := 0.0


func _process(delta: float) -> void:
	if loading != null and is_instance_valid(loading) and m != null:
		loading.progress = 0.3 + 0.7 * m.world.prebuild_progress
	_tag_t -= delta
	if _tag_t > 0.0 or player == null or ctl == null or ctl.cam == null:
		return
	_tag_t = 0.1
	var eye := ctl.cam.global_position
	for r in m.rats:
		var s := r.get_node_or_null("Sprite") as RatSprite
		if s != null:
			s.tag_shown = name_visible(m.world, eye, player.team, r)
	for w in m.windup.walkers:
		var s := w.body.get_node_or_null("Sprite") as RatSprite
		if s != null:
			s.tag_shown = name_visible(m.world, eye, player.team, w.body)


static func name_visible(world: VoxelWorld, eye: Vector3, viewer_team: int, r: Rat) -> bool:
	## Teammates' names always show; an enemy's only while you can see them
	## (their head or their middle), so names never give away hidden rats.
	if r.team == viewer_team:
		return true
	return world.line_of_sight(eye, r.position + Vector3(0, Rat.HEIGHT * 0.9, 0)) or world.line_of_sight(eye, r.center())


func _attach_sprite(rat: Rat) -> void:
	var sprite := RatSprite.new()
	sprite.name = "Sprite"
	sprite.rat = rat
	rat.add_child(sprite)


func _attach_windup(body: Rat) -> void:
	## A Wind-up Decoy wears an ordinary rat sprite, so it passes for one.
	## Its own team sees it for what it is.
	var sprite := RatSprite.new()
	sprite.name = "Sprite"
	sprite.rat = body
	if player != null and body.team == player.team:
		sprite.tag_text = "Wind-up Decoy"
	body.add_child(sprite)


func _celebrate(team: int) -> void:
	for r in m.rats:
		var s := r.get_node_or_null("Sprite") as RatSprite
		if s != null and r.team == team:
			s.celebrate = true


func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
