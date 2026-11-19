class_name RatSprite
extends Sprite3D
## Presentation only: a billboarded storybook sprite that reads its Rat's
## state and picks an animation. Never writes gameplay state.

## Rat art: one sprite sheet per class, e.g. res://assets/rats/digger.png:
## 72x72 cells, one row per animation in ANIMS order, frames left to right
## (see tools/rat_sheets.py and docs/rat_sheet_layout.png). Change a frame
## count here and in that tool.
##
## Facing: <class>.png is the SIDE view (the rat turned to the right; it is
## mirrored when the rat faces left on screen). <class>_front.png and
## <class>_back.png, in the same layout, are drawn facing the camera and facing
## away (tools/rat_views.py), so you can tell at a glance whether a rat is
## looking at you. An empty cell in those sheets falls back to the side view
## (rats show their side while digging, bonking and so on).
##
## Team colour: anything painted MAGENTA (hue roughly 275-325 degrees, any
## shade) is team colour. When a sheet is first needed the game makes a Blue
## and a Red copy by swapping that hue for the team's (UiKit.TEAM), keeping
## every pixel's shading. Keep other parts of the rat out of that hue range.
const CELL := 72
const ANIMS := ["idle", "run", "jump", "dig", "attack", "hurt", "build", "use", "down"]
const KEY_HUE_MIN := 0.76
const KEY_HUE_MAX := 0.90
const FRAMES := {"idle": 2, "run": 4, "jump": 3, "dig": 3, "attack": 2, "hurt": 2, "build": 3, "use": 3, "down": 4}
const FPS := {"idle": 2.5, "run": 10.0, "jump": 6.0, "dig": 12.0, "attack": 10.0, "hurt": 6.0, "build": 10.0, "use": 8.0, "down": 5.0}

const VIEWS := ["side", "front", "back"]
const FRONT_COS := 0.6           # facing within ~53 degrees of the camera: the front view
const HYSTERESIS := 0.1          # (a little slack either side, so it doesn't flicker on the edge)

static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}   # "path:team" -> team-coloured sheet
static var _filled: Dictionary = {}   # path -> {Vector2i(column, row): true} for cells with something drawn


static func clear_caches() -> void:
	_cache.clear()
	_sheets.clear()
	_filled.clear()

var rat: Rat
var celebrate := false
var tag_shown := true            # the session hides enemy names you cannot see
var tag_text := ""               # shown instead of the rat's name (a Wind-up Decoy, to its own team)
var view := "side"               # which way we see it: side, front or back
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
	_face_camera()
	var tex: Texture2D = null
	if view != "side":
		tex = _frame(rat.class_id, rat.team, a, frame, view)
	var side := tex == null
	if side:
		tex = _frame(rat.class_id, rat.team, a, frame)
	texture = tex
	flip_h = _flip and side
	for i in _cheese.size():
		_cheese[i].visible = i < rat.carried
	_tag.text = tag_text if tag_text != "" else rat.display_name
	_tag.visible = tag_shown
	_tag.modulate = Color(0.55, 0.75, 1.0) if rat.team == 0 else Color(1.0, 0.6, 0.55)


var _flip := false


func _face_camera() -> void:
	## Pick the view from where the rat faces, seen from the current camera.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length() < 0.05:
		return
	var face := Vector3(-sin(rat.yaw), 0, -cos(rat.yaw))
	view = pick_view(face, to_cam.normalized(), view)
	# the side art faces right: mirror it when the rat faces left on screen
	var across := face.dot(cam.global_transform.basis.x)
	if absf(across) > 0.05:
		_flip = across < 0.0


static func pick_view(face: Vector3, to_cam: Vector3, current: String) -> String:
	## front / side / back from the angle between the rat's facing and the
	## way to the camera, holding the current view near the boundaries.
	var c := face.dot(to_cam)
	var front_at := FRONT_COS - (HYSTERESIS if current == "front" else 0.0)
	var back_at := -FRONT_COS + (HYSTERESIS if current == "back" else 0.0)
	if current == "side":
		front_at += HYSTERESIS * 0.5
		back_at -= HYSTERESIS * 0.5
	if c >= front_at:
		return "front"
	if c <= back_at:
		return "back"
	return "side"


static func sheet_path(class_id: String, v := "side") -> String:
	var art := class_id if class_id != "maestro" else "builder"
	if v != "side":
		art += "_" + v
	return "res://assets/rats/%s.png" % art


static func sheet_texture(class_id: String, team: int, v := "side") -> Texture2D:
	## A class's sheet in a team's colours (made once, then cached).
	var path := sheet_path(class_id, v)
	var key := "%s:%d" % [path, team]
	if _sheets.has(key):
		return _sheets[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var img := (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if not _filled.has(path):
			var cells := {}
			for row in img.get_height() / CELL:
				for col in img.get_width() / CELL:
					if not img.get_region(Rect2i(col * CELL, row * CELL, CELL, CELL)).is_invisible():
						cells[Vector2i(col, row)] = true
			_filled[path] = cells
		tex = ImageTexture.create_from_image(tint(img, (UiKit.TEAM[clampi(team, 0, 1)] as Color).h))
	elif v == "side":
		Log.warn("missing rat sprite sheet: " + path)
	_sheets[key] = tex
	return tex


static func tint(img: Image, hue: float) -> Image:
	## Swap the magenta team-colour hue for `hue`, keeping saturation and shade.
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		if data[i + 3] == 0:
			continue
		var r := data[i]
		var g := data[i + 1]
		var b := data[i + 2]
		if g >= r or g >= b:
			continue   # magenta has more red and more blue than green
		var c := Color8(r, g, b)
		if c.h < KEY_HUE_MIN or c.h > KEY_HUE_MAX or c.s < 0.2 or c.v < 0.08:
			continue
		var t := Color.from_hsv(hue, c.s, c.v)
		data[i] = t.r8
		data[i + 1] = t.g8
		data[i + 2] = t.b8
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


static func _frame(class_id: String, team: int, anim: String, frame: int, v := "side") -> Texture2D:
	## One cell of a class's team-coloured sheet, cut out once and cached.
	## null for a front or back cell that was left empty.
	var key := "%s:%d:%s:%d:%s" % [class_id, team, anim, frame, v]
	if _cache.has(key):
		return _cache[key]
	var sheet := sheet_texture(class_id, team, v)
	var tex: AtlasTexture = null
	var cell := Vector2i(frame, ANIMS.find(anim))
	if sheet != null and (v == "side" or (_filled.get(sheet_path(class_id, v), {}) as Dictionary).has(cell)):
		tex = AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(cell.x * CELL, cell.y * CELL, CELL, CELL)
	_cache[key] = tex
	return tex
