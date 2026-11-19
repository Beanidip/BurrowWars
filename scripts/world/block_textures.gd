class_name BlockTextures
## Optional pixel-art textures for blocks. A block listed in FILES whose PNG
## exists in res://assets/blocks/ is drawn with it (nearest-neighbour, one
## copy per face); everything else keeps its flat colour. Faces are still
## shaded per side and darker deeper underground, like every other block.
## Drop in a square PNG (32x32 matches the rest) to texture another block.
## tools/make_block_textures.py draws the ones the game ships with.

const DIR := "res://assets/blocks/"
const FILES := {Blocks.SCRAP: "scrap"}

static var _flags := PackedByteArray()
static var _mats: Dictionary = {}       # block id -> StandardMaterial3D


static func clear_cache() -> void:
	_mats.clear()


static func flags() -> PackedByteArray:
	## One byte per block id: 1 when that block has a texture.
	if _flags.is_empty():
		_flags.resize(256)
		for id: int in FILES:
			if ResourceLoader.exists(DIR + String(FILES[id]) + ".png"):
				_flags[id] = 1
	return _flags


static func material(id: int) -> Material:
	if not _mats.has(id):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true      # the face's shade, multiplied in
		m.albedo_texture = load(DIR + String(FILES[id]) + ".png")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mats[id] = m
	return _mats[id]
