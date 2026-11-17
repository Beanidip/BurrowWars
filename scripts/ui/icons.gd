class_name Icons
## Little pixel-art icons for gadgets, traps, siege machines, gear, materials,
## tools, abilities and menu buttons. Each is a PNG in res://assets/icons/
## named after the item or ability id (e.g. "ladder", "jetpack", "superdig"),
## drawn by tools/make_icons.py. Replace any PNG with your own art and the
## game uses it; a missing icon just shows nothing.

const DIR := "res://assets/icons/"
static var _cache: Dictionary = {}


static func tex(id: String) -> Texture2D:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	for path: String in [DIR + id + ".png", "res://assets/ui/burrow_%s_small.png" % id]:
		if ResourceLoader.exists(path):
			t = load(path)
			break
	_cache[id] = t
	return t


static func class_tex(class_id: String) -> Texture2D:
	## A class's portrait: the first idle frame of its (blue) rat.
	var art := class_id if class_id != "maestro" else "builder"
	var key := "class:" + art
	if not _cache.has(key):
		var path := "res://assets/rats/%s_0_idle_0.png" % art
		var portrait: AtlasTexture = null
		if ResourceLoader.exists(path):
			# the rat fills the middle of its 72x72 frame: crop to it
			portrait = AtlasTexture.new()
			portrait.atlas = load(path)
			portrait.region = Rect2(12, 10, 48, 48)
		_cache[key] = portrait
	return _cache[key]


static func rect(id: String, size := 24.0) -> TextureRect:
	## A crisp (nearest-filtered) icon of a fixed size, ready to put in a row.
	var r := TextureRect.new()
	r.texture = tex(id)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func with_icon(id: String, content: Control, size := 24.0) -> HBoxContainer:
	## [icon] content, side by side.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rect(id, size))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(content)
	return h


static func on_button(b: Button, id: String, class_portrait := false, size := 26) -> Button:
	b.icon = class_tex(id) if class_portrait else tex(id)
	b.expand_icon = true                       # scale small pixel icons up (crisp: nearest filter)...
	b.add_theme_constant_override("icon_max_width", size)   # ...to this width
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b
