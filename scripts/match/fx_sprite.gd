class_name FxSprite
extends Sprite3D
## Plays one pixel-art effect sprite sheet (res://assets/fx/<name>.png, described
## in FxSheets) as a billboard in the world, then frees itself. One-shots end on
## their last frame; loops (the jetpack) run for `duration` seconds. With
## `follow`, the effect rides along with a node (a rat), drawn behind it (or,
## with `front`, in front of it: a raised shield). `flip` mirrors it left-right.
##
## With a `tint` colour the effect is recoloured towards it (fx_hue.gdshader):
## hit sparks take the colour of the block being hit.
##
## Scale: the effects are drawn for a 38-pixel-tall character, and a rat is
## 0.9 blocks tall, so one effect pixel is 0.9 / 38 blocks at scale 1.

const PX := 0.9 / 38.0
const HUE_SHADER := preload("res://assets/shaders/fx_hue.gdshader")
static var _tex: Dictionary = {}


static func clear_cache() -> void:
	_tex.clear()

var sheet: Dictionary
var follow: Node3D
var follow_offset := Vector3.ZERO
var front := false
var duration := -1.0
var _t := 0.0
var _frame := -1


static func play(parent: Node, fx_name: String, at: Vector3, scale_by := 1.0, follow_node: Node3D = null, seconds := -1.0,
		tint := Color(0, 0, 0, 0), flip := false, in_front := false, colorize := 0.0, shade := Vector2(0.45, 1.3)) -> FxSprite:
	if not FxSheets.SHEETS.has(fx_name) or parent == null or not parent.is_inside_tree():
		return null
	var base := _texture(fx_name)
	if base == null:
		return null
	var s := FxSprite.new()
	s.sheet = FxSheets.SHEETS[fx_name]
	s.texture = base
	s.region_enabled = true
	if tint.a > 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = HUE_SHADER
		mat.set_shader_parameter("tex", base)
		mat.set_shader_parameter("hue", tint.h)
		mat.set_shader_parameter("sat", tint.s)
		mat.set_shader_parameter("block_rgb", Vector3(tint.r, tint.g, tint.b))
		mat.set_shader_parameter("colorize", colorize)
		mat.set_shader_parameter("shade", shade)
		s.material_override = mat
	s.pixel_size = PX * scale_by
	s.duration = seconds
	s.follow = follow_node
	var w := float(s.sheet["w"])
	var h := float(s.sheet["h"])
	var pivot: Vector2 = s.sheet["pivot"]
	s.offset = Vector2(w * 0.5 - pivot.x, pivot.y - h * 0.5)   # the pivot sits on the position
	if flip:
		s.flip_h = true
		s.offset.x = -s.offset.x
	s.front = in_front
	if follow_node != null:
		# A billboard's depth comes from its node's origin, and the camera looks
		# down on the rats: an origin raised up the rat would count as nearer
		# than the rat itself. So the node stays level with the rat's feet and
		# the picture is lifted within the sprite instead.
		s.follow_offset = Vector3(at.x, 0.0, at.z)
		s.offset.y += at.y / s.pixel_size
		at = s.follow_offset
	parent.add_child(s)
	s.global_position = at if follow_node == null else follow_node.global_position + at
	s._show(0)
	return s


static func _texture(fx_name: String) -> Texture2D:
	if not _tex.has(fx_name):
		var path := "res://assets/fx/%s.png" % fx_name
		_tex[fx_name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[fx_name]


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	transparent = true
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _show(i: int) -> void:
	if i == _frame:
		return
	_frame = i
	var cols := int(sheet["cols"])
	region_rect = Rect2((i % cols) * int(sheet["w"]), (i / cols) * int(sheet["h"]), int(sheet["w"]), int(sheet["h"]))


func _process(delta: float) -> void:
	_t += delta
	if follow != null:
		if not is_instance_valid(follow):
			queue_free()
			return
		var p := follow.global_position + follow_offset
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			p += (p - cam.global_position).normalized() * (-0.15 if front else 0.15)   # just behind (or in front of) the rat, as seen
		global_position = p
	var n := int(sheet["frames"])
	var i := int(_t * float(sheet["fps"]))
	if bool(sheet["loop"]):
		if duration >= 0.0 and _t >= duration:
			queue_free()
			return
		_show(i % n)
	elif i >= n:
		queue_free()
	else:
		_show(i)
