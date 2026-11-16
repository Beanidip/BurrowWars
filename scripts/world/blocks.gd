class_name Blocks
## Block catalogue. One row per block type; every system (digging, meshing,
## collision, bots) reads behaviour from here instead of hard-coding ids.

enum {
	AIR, DIRT, GRASS, STONE, SCRAP, OBSIDIAN, WOOD, ICE, WATER, LAVA, CHEESE,
	BEDROCK, BASE_BLUE, BASE_RED, BRICK, LEAVES, SHROOM_CAP, SHROOM_STEM, GLOW,
	HIGHWAY, LADDER, SPRING, TNT, TRAP_BLUE, TRAP_RED,
	CONV_XP, CONV_XN, CONV_ZP, CONV_ZN, GATE_BLUE, GATE_RED,
	STICKY_BLUE, STICKY_RED, PIT_BLUE, PIT_RED, WALL_SPRING, CANNON, CRANE, DOZER, TEAM_BLUE, TEAM_RED,
	PAINT_0, PAINT_1, PAINT_2, PAINT_3, PAINT_4, PAINT_5, PAINT_6, PAINT_7, PAINT_8, PAINT_9, PAINT_10, PAINT_11, COUNT
}

const OBSIDIAN_HITS := 12   # balance knob: ordinary dig hits to break obsidian
const MICRO := 7            # microvoxels per block edge (7 x 7 x 7 = 343)
const MICRO_COUNT := 343

# name, hits to break (0 = indestructible / not diggable), colour, solid, opaque cube,
# drop: "" | "mat:<name>" | "scrap" | "cheese" | "item:<gadget id>"
const DEFS := [
	["Air", 0, Color(0, 0, 0, 0), false, false, ""],
	["Dirt", 2, Color(0.47, 0.31, 0.20), true, true, "mat:dirt"],
	["Grass", 2, Color(0.38, 0.62, 0.27), true, true, "mat:dirt"],
	["Stone", 4, Color(0.50, 0.50, 0.54), true, true, "mat:stone"],
	["Scrap", 5, Color(0.72, 0.46, 0.22), true, true, "scrap"],
	["Obsidian", OBSIDIAN_HITS, Color(0.17, 0.12, 0.24), true, true, "mat:obsidian"],
	["Wood", 3, Color(0.62, 0.44, 0.24), true, true, "mat:wood"],
	["Ice", 2, Color(0.70, 0.88, 0.96), true, true, "mat:ice"],
	["Water", 0, Color(0.22, 0.52, 0.90, 0.46), false, false, ""],
	["Lava", 0, Color(1.0, 0.42, 0.08), false, false, ""],
	["Golden Cheese", 3, Color(1.0, 0.82, 0.18), true, true, "cheese"],
	["Bedrock", 0, Color(0.14, 0.13, 0.15), true, true, ""],
	["Blue Base", 0, Color(0.24, 0.45, 0.85), true, true, ""],
	["Red Base", 0, Color(0.85, 0.27, 0.24), true, true, ""],
	["Ruin Brick", 4, Color(0.56, 0.50, 0.42), true, true, "mat:stone"],
	["Leaves", 1, Color(0.24, 0.50, 0.22), true, true, ""],
	["Mushroom Cap", 1, Color(0.82, 0.22, 0.26), true, true, ""],
	["Mushroom Stem", 1, Color(0.92, 0.88, 0.78), true, true, ""],
	["Glow Crystal", 3, Color(0.35, 0.95, 0.90), true, true, ""],
	["Highway", 2, Color(0.80, 0.63, 0.36), false, false, "item:highway"],
	["Ladder", 1, Color(0.70, 0.50, 0.26), false, false, "item:ladder"],
	["Spring", 2, Color(0.55, 0.78, 0.35), true, false, "item:spring"],
	["TNT", 1, Color(0.85, 0.16, 0.14), true, true, ""],
	["Mouse Trap", 1, Color(0.30, 0.50, 0.90), false, false, "item:trap"],
	["Mouse Trap", 1, Color(0.90, 0.32, 0.28), false, false, "item:trap"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Team Gate", 0, Color(0.30, 0.52, 0.95, 0.42), true, false, "item:gate"],
	["Team Gate", 0, Color(0.95, 0.34, 0.30, 0.42), true, false, "item:gate"],
	["Sticky Trap", 1, Color(0.35, 0.55, 0.85), false, false, "item:sticky"],
	["Sticky Trap", 1, Color(0.85, 0.42, 0.38), false, false, "item:sticky"],
	["Pitfall", 1, Color(0.36, 0.58, 0.30), false, false, "item:pitfall"],
	["Pitfall", 1, Color(0.42, 0.58, 0.26), false, false, "item:pitfall"],
	["Wall Spring", 2, Color(0.50, 0.74, 0.40), true, true, "item:wallspring"],
	["Scrap Cannon", 0, Color(0.55, 0.45, 0.30), true, false, ""],
	["Wrecking Crane", 0, Color(0.75, 0.60, 0.25), true, false, ""],
	["Bulldozer", 0, Color(0.85, 0.65, 0.20), true, false, ""],
	# Team blocks: a floor/wall only their own team can stand on or touch.
	["Team Block", 1, Color(0.42, 0.66, 1.0), false, true, ""],
	["Team Block", 1, Color(1.0, 0.50, 0.45), false, true, ""],
	# Painted blocks: dyed stone in the 12 palette colours (place with slot 6, pick with C).
	["Red Block", 4, Color(0.86, 0.22, 0.22), true, true, "mat:stone"],
	["Orange Block", 4, Color(0.95, 0.52, 0.16), true, true, "mat:stone"],
	["Yellow Block", 4, Color(0.97, 0.84, 0.25), true, true, "mat:stone"],
	["Lime Block", 4, Color(0.58, 0.85, 0.28), true, true, "mat:stone"],
	["Green Block", 4, Color(0.18, 0.58, 0.30), true, true, "mat:stone"],
	["Teal Block", 4, Color(0.15, 0.66, 0.66), true, true, "mat:stone"],
	["Sky Block", 4, Color(0.45, 0.76, 0.98), true, true, "mat:stone"],
	["Blue Block", 4, Color(0.20, 0.36, 0.86), true, true, "mat:stone"],
	["Purple Block", 4, Color(0.56, 0.32, 0.82), true, true, "mat:stone"],
	["Pink Block", 4, Color(0.96, 0.52, 0.76), true, true, "mat:stone"],
	["White Block", 4, Color(0.95, 0.95, 0.93), true, true, "mat:stone"],
	["Charcoal Block", 4, Color(0.20, 0.20, 0.23), true, true, "mat:stone"],
]

const PALETTE_SIZE := 12
const PALETTE_NAMES := ["Red", "Orange", "Yellow", "Lime", "Green", "Teal", "Sky", "Blue", "Purple", "Pink", "White", "Charcoal"]

const CHISELABLE := [DIRT, GRASS, STONE, OBSIDIAN, WOOD, ICE, BRICK,
	PAINT_0, PAINT_1, PAINT_2, PAINT_3, PAINT_4, PAINT_5, PAINT_6, PAINT_7, PAINT_8, PAINT_9, PAINT_10, PAINT_11]

static var SOLID := PackedByteArray()
static var OPAQUE := PackedByteArray()
static var TARGETABLE := PackedByteArray()
static var HITS := PackedByteArray()
static var COLOR: Array[Color] = []


static func _static_init() -> void:
	for id in COUNT:
		var d: Array = DEFS[id]
		SOLID.append(1 if d[3] else 0)
		OPAQUE.append(1 if d[4] else 0)
		TARGETABLE.append(0 if (id == AIR or id == WATER or id == LAVA) else 1)
		HITS.append(int(d[1]))
		COLOR.append(d[2])


static func block_name(id: int) -> String:
	return DEFS[id][0]


static func drop(id: int) -> String:
	return DEFS[id][5]


static func is_gate(id: int) -> bool:
	return id == GATE_BLUE or id == GATE_RED


static func gate_team(id: int) -> int:
	return 0 if id == GATE_BLUE else 1


static func is_trap(id: int) -> bool:
	return id == TRAP_BLUE or id == TRAP_RED


static func is_conveyor(id: int) -> bool:
	return id >= CONV_XP and id <= CONV_ZN


static func conveyor_dir(id: int) -> Vector3:
	match id:
		CONV_XP: return Vector3(1, 0, 0)
		CONV_XN: return Vector3(-1, 0, 0)
		CONV_ZP: return Vector3(0, 0, 1)
		CONV_ZN: return Vector3(0, 0, -1)
	return Vector3.ZERO


static func is_sticky(id: int) -> bool:
	return id == STICKY_BLUE or id == STICKY_RED


static func is_pit(id: int) -> bool:
	return id == PIT_BLUE or id == PIT_RED


static func is_machine(id: int) -> bool:
	return id == CANNON or id == CRANE or id == DOZER


static func mat_of(id: int) -> String:
	## Building material a block is made of ("" if it is not a material block).
	var d: String = DEFS[id][5]
	return d.substr(4) if d.begins_with("mat:") else ""


static func is_paint(id: int) -> bool:
	return id >= PAINT_0 and id < PAINT_0 + PALETTE_SIZE


static func paint_color(k: int) -> Color:
	return COLOR[PAINT_0 + clampi(k, 0, PALETTE_SIZE - 1)]


static func is_team_block(id: int) -> bool:
	return id == TEAM_BLUE or id == TEAM_RED


static func solid_for(id: int, team: int) -> bool:
	## Collision rule: team gates let their own team through; a pitfall is
	## solid ground for its owners and thin air for everyone else.
	if is_gate(id):
		return gate_team(id) != team
	if is_pit(id):
		return (0 if id == PIT_BLUE else 1) == team
	if is_team_block(id):
		return (0 if id == TEAM_BLUE else 1) == team
	return SOLID[id] == 1


static func mirror(id: int) -> int:
	## Block swap used when mirroring the blue half of the map onto the red half.
	match id:
		BASE_BLUE: return BASE_RED
		BASE_RED: return BASE_BLUE
		CONV_XP: return CONV_XN
		CONV_XN: return CONV_XP
		TRAP_BLUE: return TRAP_RED
		GATE_BLUE: return GATE_RED
	return id
