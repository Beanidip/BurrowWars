class_name GameSession
extends Node
## Composes one playable session: Match (rules) + MatchView (juice) +
## PlayerController (input/camera) + Hud (interface) + environment.

signal exit_requested
signal rematch_requested

var settings: Dictionary = {}
var m: Match
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
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	sea.mesh = plane
	var sea_mat := StandardMaterial3D.new()
	sea_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sea_mat.albedo_color = Color(0.22, 0.47, 0.72)
	sea.material_override = sea_mat
	sea.position = Vector3(VoxelWorld.SX * 0.5, MapGenerator.GROUND - 3.4, VoxelWorld.SZ * 0.5)
	add_child(sea)

	m = Match.new()
	m.name = "Match"
	add_child(m)
	m.setup(settings, true)
	m.rat_spawned.connect(_attach_sprite)
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
	hud.exit_requested.connect(func() -> void: exit_requested.emit())
	hud.rematch_requested.connect(func() -> void: rematch_requested.emit())
	m.won.connect(_celebrate)
	m.world.rebuild_dirty(9999)   # build every chunk before the first frame


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
