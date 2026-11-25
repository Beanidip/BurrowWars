class_name Hats
## Cosmetic hats: chosen under Customize Rat in the main menu, worn in every
## match (online, everyone sees yours). Purely cosmetic.
##
## Art: assets/hats/<id>.png (tools/make_hats.py draws the placeholders),
## drawn facing you, any size up to 24 x 22. Its bottom row is where it sits.
## MAGENTA parts take the wearer's team colour, as on the rats.
##
## How it is worn: when a rat sheet is first needed, every frame gets ROOM
## empty pixels above it (so tall hats fit), and the hat is drawn onto each
## frame at the top of the head - found from the frame itself (the middle of
## the head, at the highest pixel there), so it follows every bob, crouch and
## turn of the animation, front, side and back. The side view is mirrored
## with the rat when it faces left.

const ROOM := 16      # pixels of space added above every frame for a hat
const SINK := 3       # how far a hat sits down onto the head
## In the order the menu lists them. "" is no hat.
const LIST := ["", "party", "tophat", "crown", "cheese", "beanie", "viking", "chef", "propeller", "wizard", "flower", "cowboy", "pirate"]
const NAMES := {"": "No hat", "party": "Party Hat", "tophat": "Top Hat", "crown": "Crown", "cheese": "Cheese Wedge",
	"beanie": "Bobble Beanie", "viking": "Viking Helmet", "chef": "Chef's Toque", "propeller": "Propeller Cap",
	"wizard": "Wizard Hat", "flower": "Daisy", "cowboy": "Cowboy Hat", "pirate": "Pirate Hat"}

static var _images: Dictionary = {}    # id -> Image (RGBA8)
static var _icons: Dictionary = {}     # "id:team" -> the hat in a team's colours
static var _anchors: Dictionary = {}   # sheet path -> {Vector2i(col, row): Vector2i(x, y) in the cell}


static func clear_cache() -> void:
	_images.clear()
	_anchors.clear()
	_icons.clear()


static func clean(id: Variant) -> String:
	## A hat id from a save or a player's game: a known one, else none.
	return String(id) if id is String and LIST.has(id) else ""


static func path(id: String) -> String:
	return "res://assets/hats/%s.png" % id


static func texture(id: String) -> Texture2D:
	## The hat on its own (menus).
	return load(path(id)) if id != "" and ResourceLoader.exists(path(id)) else null


static func icon(id: String, team := 0) -> Texture2D:
	## The hat on its own in a team's colours (menus).
	var key := "%s:%d" % [id, team]
	if not _icons.has(key):
		var img := image(id)
		_icons[key] = null if img == null else ImageTexture.create_from_image(
			RatSprite.tint(img, (UiKit.TEAM[clampi(team, 0, 1)] as Color).h))
	return _icons[key]


static func image(id: String) -> Image:
	if _images.has(id):
		return _images[id]
	var img: Image = null
	var tex := texture(id)
	if tex != null:
		img = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
	_images[id] = img
	return img


static func dress(sheet: Image, hat: String, cell: int, sheet_path := "") -> Image:
	## The sheet with ROOM free pixels above every frame, and the hat (if any)
	## on every frame that has a rat in it. Frames become cell x (cell + ROOM).
	var cols := sheet.get_width() / cell
	var rows := sheet.get_height() / cell
	var tall := cell + ROOM
	var out := Image.create(cols * cell, rows * tall, false, Image.FORMAT_RGBA8)
	var hat_img := image(hat) if hat != "" else null
	var anchors := anchors_of(sheet, cell, sheet_path)
	for row in rows:
		for col in cols:
			var at := Vector2i(col, row)
			if not anchors.has(at):
				continue   # an empty cell
			var top := Vector2i(col * cell, row * tall + ROOM)
			out.blit_rect(sheet, Rect2i(col * cell, row * cell, cell, cell), top)
			if hat_img != null:
				var a: Vector2i = anchors[at]
				var hw := hat_img.get_width()
				var hh := hat_img.get_height()
				var x := clampi(a.x - hw / 2, 0, cell - hw)   # (never into the next frame)
				out.blend_rect(hat_img, Rect2i(0, 0, hw, hh), top + Vector2i(x, a.y - hh + SINK))
	return out


static func anchors_of(sheet: Image, cell: int, sheet_path := "") -> Dictionary:
	## Where a hat goes in each drawn frame (cached per sheet).
	if sheet_path != "" and _anchors.has(sheet_path):
		return _anchors[sheet_path]
	var out := {}
	var data := sheet.get_data()
	var w := sheet.get_width()
	for row in sheet.get_height() / cell:
		for col in w / cell:
			var a := anchor(data, w, col * cell, row * cell, cell)
			if a.x >= 0:
				out[Vector2i(col, row)] = a
	if sheet_path != "":
		_anchors[sheet_path] = out
	return out


static func anchor(data: PackedByteArray, width: int, ox: int, oy: int, cell: int) -> Vector2i:
	## The top of the head in one frame: the middle of the highest 12 rows of
	## the drawing, at the highest pixel within 3 of that middle. (-1, -1) if
	## the frame is empty.
	var top := -1
	for y in cell:
		for x in cell:
			if data[((oy + y) * width + ox + x) * 4 + 3] > 0:
				top = y
				break
		if top >= 0:
			break
	if top < 0:
		return Vector2i(-1, -1)
	var sum := 0
	var n := 0
	for y in range(top, mini(cell, top + 12)):
		for x in cell:
			if data[((oy + y) * width + ox + x) * 4 + 3] > 0:
				sum += x
				n += 1
	var cx := roundi(float(sum) / float(maxi(n, 1)))
	for y in cell:
		for x in range(maxi(0, cx - 3), mini(cell, cx + 4)):
			if data[((oy + y) * width + ox + x) * 4 + 3] > 0:
				return Vector2i(cx, y)
	return Vector2i(cx, top)
