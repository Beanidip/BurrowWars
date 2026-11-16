class_name RatSprite
extends Sprite3D
## Presentation only: a billboarded storybook sprite that reads its Rat's
## state and picks an animation. Never writes gameplay state.

const FRAMES := {"idle": 2, "run": 4, "jump": 3, "dig": 3, "attack": 2, "hurt": 2, "build": 3, "use": 3, "down": 4}
const FPS := {"idle": 2.5, "run": 10.0, "jump": 6.0, "dig": 12.0, "attack": 10.0, "hurt": 6.0, "build": 10.0, "use": 8.0, "down": 5.0}

static var _cache: Dictionary = {}

var rat: Rat
var celebrate := false
var _t := 0.0
var _anim := "idle"
var _cheese: Array[MeshInstance3D] = []
var _tag: Label3D


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	pixel_size = 1.25 / 72.0
	centered = true
	offset = Vector2(0, 30)
	for i in 6:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.26, 0.2, 0.26)
		m.mesh = box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.82, 0.18)
		m.material_override = mat
		m.position = Vector3(0, 1.15 + 0.22 * i, 0)
		m.visible = false
		add_child(m)
		_cheese.append(m)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0011
	_tag.font_size = 22
	_tag.outline_size = 8
	_tag.position = Vector3(0, 1.05, 0)
	add_child(_tag)


func _process(delta: float) -> void:
	if rat == null:
		return
	var a := "idle"
	if celebrate:
		a = "jump"
	elif rat.stun > 0.0:
		a = "down"
	elif rat.knock > 0.0:
		a = "hurt"
	elif rat.anim_action_t > 0.0 and FRAMES.has(rat.anim_action):
		a = rat.anim_action
	elif not rat.on_floor and not rat.on_ladder and not rat.in_water:
		a = "jump"
	elif Vector2(rat.vel.x, rat.vel.z).length() > 0.6:
		a = "run"
	if a != _anim:
		_anim = a
		_t = 0.0
	_t += delta
	var frame := int(_t * float(FPS[a])) % int(FRAMES[a])
	texture = _frame(rat.class_id, rat.team, a, frame)
	for i in _cheese.size():
		_cheese[i].visible = i < rat.carried
	_tag.text = rat.display_name
	_tag.modulate = Color(0.55, 0.75, 1.0) if rat.team == 0 else Color(1.0, 0.6, 0.55)


static func _frame(class_id: String, team: int, anim: String, frame: int) -> Texture2D:
	var art := class_id if class_id != "maestro" else "builder"
	var path := "res://assets/rats/%s_%d_%s_%d.png" % [art, team, anim, frame]
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		Log.warn("missing rat sprite: " + path)
	_cache[path] = tex
	return tex
