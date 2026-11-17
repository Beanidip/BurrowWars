class_name Icons
## Little pixel-art icons for gadgets, traps, siege machines, gear, materials,
## tools, abilities and menu buttons, by item or ability id ("ladder",
## "jetpack", "superdig"...). They all live in one sprite sheet,
## res://assets/icons/icons.png (16x16 cells; IconSheet says which id is in
## which cell; docs/icon_sheet_layout.png shows it). A separate
## res://assets/icons/<id>.png, if present, overrides that one icon. A
## missing icon just shows nothing.

const DIR := "res://assets/icons/"
const SHEET := "res://assets/icons/icons.png"
static var _cache: Dictionary = {}


static func tex(id: String) -> Texture2D:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	var cell := IconSheet.IDS.find(id)
	if ResourceLoader.exists(DIR + id + ".png"):
		t = load(DIR + id + ".png")                     # a single-icon override
	elif cell >= 0 and ResourceLoader.exists(SHEET):
		var a := AtlasTexture.new()
		a.atlas = load(SHEET)
		a.region = Rect2((cell % IconSheet.COLS) * IconSheet.CELL, (cell / IconSheet.COLS) * IconSheet.CELL, IconSheet.CELL, IconSheet.CELL)
		t = a
	elif ResourceLoader.exists("res://assets/ui/burrow_%s_small.png" % id):
		t = load("res://assets/ui/burrow_%s_small.png" % id)   # the older UI icons (hammer, gear...)
	_cache[id] = t
	return t


static func class_tex(class_id: String) -> Texture2D:
	## A class's portrait: the first idle frame of its (blue) rat.
	var key := "class:" + RatSprite.sheet_path(class_id)
	if not _cache.has(key):
		var portrait: AtlasTexture = null
		var sheet := RatSprite.sheet_texture(class_id, 0)
		if sheet != null:
			# the first idle frame (top-left cell, in Blue), cropped to the rat itself
			portrait = AtlasTexture.new()
			portrait.atlas = sheet
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
