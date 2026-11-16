class_name Blocks
## Block catalogue. One row per block type; every system (digging, meshing,
## collision, bots) reads behaviour from here instead of hard-coding ids.

enum {
	AIR, DIRT, GRASS, STONE, SCRAP, OBSIDIAN, WOOD, ICE, WATER, LAVA, CHEESE,
	BEDROCK, BASE_BLUE, BASE_RED, BRICK, LEAVES, SHROOM_CAP, SHROOM_STEM, GLOW,
	HIGHWAY, LADDER, SPRING, TNT, TRAP_BLUE, TRAP_RED,
	CONV_XP, CONV_XN, CONV_ZP, CONV_ZN, GATE_BLUE, GATE_RED, COUNT
}

# name, hits to break (0 = indestructible / not diggable), colour, solid, opaque cube,
# drop: "" | "mat:<name>" | "scrap" | "cheese" | "item:<gadget id>"
const DEFS := [
	["Air", 0, Color(0, 0, 0, 0), false, false, ""],
	["Dirt", 2, Color(0.47, 0.31, 0.20), true, true, "mat:dirt"],
	["Grass", 2, Color(0.38, 0.62, 0.27), true, true, "mat:dirt"],
	["Stone", 4, Color(0.50, 0.50, 0.54), true, true, "mat:stone"],
	["Scrap", 5, Color(0.72, 0.46, 0.22), true, true, "scrap"],
	["Obsidian", 14, Color(0.17, 0.12, 0.24), true, true, ""],
	["Wood", 3, Color(0.62, 0.44, 0.24), true, true, "mat:wood"],
	["Ice", 2, Color(0.70, 0.88, 0.96), true, true, "mat:ice"],
	["Water", 0, Color(0.25, 0.52, 0.85, 0.55), false, false, ""],
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
	["Highway", 2, Color(0.80, 0.63, 0.36), true, true, "item:highway"],
	["Ladder", 1, Color(0.70, 0.50, 0.26), false, false, "item:ladder"],
	["Spring", 2, Color(0.55, 0.78, 0.35), true, false, "item:spring"],
	["TNT", 1, Color(0.85, 0.16, 0.14), true, true, ""],
	["Mouse Trap", 1, Color(0.30, 0.50, 0.90), false, false, "item:trap"],
	["Mouse Trap", 1, Color(0.90, 0.32, 0.28), false, false, "item:trap"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Conveyor", 2, Color(0.33, 0.34, 0.38), true, true, "item:conveyor"],
	["Team Gate", 0, Color(0.30, 0.52, 0.95, 0.5), true, false, "item:gate"],
	["Team Gate", 0, Color(0.95, 0.34, 0.30, 0.5), true, false, "item:gate"],
]

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


static func solid_for(id: int, team: int) -> bool:
	## Collision rule: team gates let their own team through.
	if is_gate(id):
		return gate_team(id) != team
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
