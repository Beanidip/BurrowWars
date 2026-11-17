class_name ClassDefs
## Data-driven class and workshop definitions. Balance lives in these tables.

const ORDER := ["digger", "scout", "builder", "saboteur"]

# speed: multiplier on Config.BASE_SPEED. brush: dig radius in blocks (0 = single block).
# power: dig hits per swing on the aimed block (default 1; brush neighbours always take 1).
# abilities: [id, label, cooldown seconds, stamina cost]
const CLASSES := {
	"digger": {
		"name": "Digger", "speed": 0.85, "stamina": 150.0, "carry": 3, "brush": 0, "water": 0.5,
		"remote_shop": false, "fly": false,
		"blurb": "Hauls 3 cheese. Super Dig smashes the aimed block twice as hard and chews the 3x3x3 around it.",
		"abilities": [["superdig", "Super Dig", 4.0, 12.0]],
		"kit": {},
	},
	"scout": {
		"name": "Scout", "speed": 1.25, "stamina": 100.0, "carry": 2, "brush": 0, "water": 1.0,
		"remote_shop": false, "fly": false,
		"blurb": "Fast, swims at full speed, sniffs out cheese and drops team beacons.",
		"abilities": [["sniff", "Sniff", 6.0, 15.0], ["beacon", "Beacon", 10.0, 10.0]],
		"kit": {},
	},
	"builder": {
		"name": "Builder", "speed": 1.0, "stamina": 100.0, "carry": 2, "brush": 0, "water": 0.5,
		"remote_shop": true, "fly": false,
		"blurb": "Patches walls, starts with team blocks, buys team gates cheap and shops from anywhere.",
		"abilities": [["patch", "Patch 3x3", 5.0, 25.0]],
		"discount": {"gate": 3},
		"kit": {"ladder": 6, "spring": 1, "gate": 4, "teamblock": 6},
	},
	"saboteur": {
		"name": "Saboteur", "speed": 1.05, "stamina": 100.0, "carry": 2, "brush": 0, "water": 0.5,
		"remote_shop": false, "fly": false,
		"blurb": "Plants TNT and mouse traps, then sets the whole chain off remotely.",
		"abilities": [["detonate", "Detonate", 1.0, 0.0], ["plant", "Plant TNT", 0.5, 0.0]],
		"kit": {"tnt": 3, "trap": 2, "dynamite": 2},
	},
	# Free Build only: handed out by the host/authority, never selectable by a client.
	"maestro": {
		"name": "Chisel Maestro", "speed": 1.3, "stamina": 1000.0, "carry": 6, "brush": 0, "water": 1.0,
		"remote_shop": true, "fly": true,
		"blurb": "Creative class: flight, unlimited materials and gadgets.",
		"abilities": [["detonate", "Detonate", 0.5, 0.0], ["patch", "Patch 3x3", 0.5, 0.0]],
		"kit": {},
	},
}

# Workshop stock. kind "gadget" goes to the Q slot inventory, "mat" to materials.
const SHOP := [
	{"id": "ladder", "name": "Ladder x3", "kind": "gadget", "qty": 3, "cost": 4, "cat": "Mobility",
		"desc": "Climb with Space, descend with Ctrl. Aim at a ladder's top or bottom half and press Q to extend the stack that way."},
	{"id": "spring", "name": "Spring", "kind": "gadget", "qty": 1, "cost": 6, "cat": "Mobility",
		"desc": "Trampoline. Launches anything that lands on it - friend or foe."},
	{"id": "highway", "name": "Highway x4", "kind": "gadget", "qty": 4, "cost": 5, "cat": "Mobility",
		"desc": "Plank road, laid into the floor you aim at. Rats run 60% faster on it, even hauling cheese."},
	{"id": "conveyor", "name": "Conveyor x3", "kind": "gadget", "qty": 3, "cost": 6, "cat": "Mobility",
		"desc": "Laid into the floor you aim at. Runs toward the bright edge of your target square."},
	{"id": "trap", "name": "Mouse Trap", "kind": "gadget", "qty": 1, "cost": 5, "cat": "Traps",
		"desc": "Snaps on enemy rats: short stun and they drop a cheese."},
	{"id": "tnt", "name": "TNT", "kind": "gadget", "qty": 1, "cost": 8, "cat": "Traps",
		"desc": "Hit it to light a 2 s fuse. Saboteurs detonate remotely. Chains."},
	{"id": "teamblock", "name": "Team Block x4", "kind": "gadget", "qty": 4, "cost": 4, "cat": "Construction",
		"desc": "A block in team colours: solid floor or wall for your team, thin air for enemies (and nothing they can dig). Dig it to take it back."},
	{"id": "stash", "name": "Team Stash", "kind": "gadget", "qty": 1, "cost": 12, "max": 2, "cat": "Construction",
		"desc": "Place it anywhere outside the bases. Your team deposits and takes scrap, dirt, stone, ice and obsidian here (or at base) with B. Only 5 TNT blasts break it - and the shared pool survives."},
	{"id": "gate", "name": "Team Gate", "kind": "gadget", "qty": 1, "cost": 7, "cat": "Construction",
		"desc": "See-through door. Your team walks through; enemies need two TNT blasts. Free for Builders."},
	{"id": "dynamite", "name": "Mobile TNT x2", "kind": "gadget", "qty": 2, "cost": 7, "cat": "Traps",
		"desc": "Bouncy dynamite stick, 3 s fuse. Q throws it, Ctrl+Q sets it down gently. Springs launch it, conveyors carry it, ice lets it slide."},
	{"id": "sticky", "name": "Sticky Trap x2", "kind": "gadget", "qty": 2, "cost": 4, "cat": "Traps",
		"desc": "Glue pad. Enemy rats wade through at half speed; rolling dynamite stops dead."},
	{"id": "pitfall", "name": "Pitfall x2", "kind": "gadget", "qty": 2, "cost": 5, "cat": "Traps",
		"desc": "Fake turf. Solid for your team, a hole for everyone and everything else."},
	{"id": "wallspring", "name": "Wall Spring", "kind": "gadget", "qty": 1, "cost": 6, "cat": "Traps",
		"desc": "Sideways bumper block. Flings back any rat or dynamite that runs into it."},
	{"id": "cannon", "name": "Scrap Cannon", "kind": "gadget", "qty": 1, "cost": 26, "max": 2, "cat": "Siege",
		"desc": "T to pilot it, mouse to aim, left mouse to fire. Hits one block for 3 dig hits and chips the four around it."},
	{"id": "crane", "name": "Wrecking Crane", "kind": "gadget", "qty": 1, "cost": 30, "max": 2, "cat": "Siege",
		"desc": "T to pilot it, mouse to turn, left mouse to pump the swing. The faster the ball, the harder it hits."},
	{"id": "dozer", "name": "Bulldozer", "kind": "gadget", "qty": 1, "cost": 28, "max": 2, "cat": "Siege",
		"desc": "T to pilot it, left mouse to ram the blade: 3 wide, 2 high. Has no engine - feed it conveyors."},
	{"id": "ice", "name": "Ice x4", "kind": "mat", "qty": 4, "cost": 3, "cat": "Construction",
		"desc": "Slippery block. Slot 3, place with right mouse."},
	{"id": "jetpack", "name": "Jetpack", "kind": "gear", "qty": 1, "cost": 14, "cat": "Gear",
		"desc": "Wear it in your gear slot and press J: a burst of thrust lifts you over trenches and up cliffs. 5 s to cool down after each burst. One piece of gear at a time."},
]

const MATS := ["dirt", "stone", "ice", "obsidian"]
const MAT_BLOCK := {"dirt": Blocks.DIRT, "stone": Blocks.STONE, "ice": Blocks.ICE, "obsidian": Blocks.OBSIDIAN}
## Gadgets that can go inside your own team gate (see Blocks.GATE_GADGETS).
const GATE_GADGETS := ["ladder", "spring", "highway", "conveyor", "wallspring"]
const GADGETS := ["ladder", "spring", "highway", "conveyor", "trap", "tnt", "dynamite", "sticky", "pitfall", "wallspring", "gate", "teamblock", "stash", "cannon", "crane", "dozer"]
const GADGET_NAME := {
	"ladder": "Ladder", "spring": "Spring", "highway": "Highway", "conveyor": "Conveyor",
	"trap": "Mouse Trap", "tnt": "TNT", "gate": "Team Gate",
	"dynamite": "Mobile TNT", "sticky": "Sticky Trap", "pitfall": "Pitfall", "wallspring": "Wall Spring",
	"cannon": "Scrap Cannon", "crane": "Wrecking Crane", "dozer": "Bulldozer", "teamblock": "Team Block", "stash": "Team Stash",
}


## Gear: one piece worn at a time in the gear slot (J uses it).
const GEAR := {"jetpack": "Jetpack"}


static func price(cls: Dictionary, item_id: String, free_mode: bool) -> int:
	## What this class pays for an item (Builders get team gates cheap).
	if free_mode:
		return 0
	var discount: Dictionary = cls.get("discount", {})
	if discount.has(item_id):
		return int(discount[item_id])
	return int(shop_item(item_id).get("cost", 0))


static func shop_item(id: String) -> Dictionary:
	for item: Dictionary in SHOP:
		if item["id"] == id:
			return item
	return {}


static func gadget_block(id: String, team: int, facing: Vector3) -> int:
	match id:
		"ladder": return Blocks.LADDER
		"spring": return Blocks.SPRING
		"highway": return Blocks.HIGHWAY
		"tnt": return Blocks.TNT
		"trap": return Blocks.TRAP_BLUE if team == 0 else Blocks.TRAP_RED
		"gate": return Blocks.GATE_BLUE if team == 0 else Blocks.GATE_RED
		"teamblock": return Blocks.TEAM_BLUE if team == 0 else Blocks.TEAM_RED
		"stash": return Blocks.STASH_BLUE if team == 0 else Blocks.STASH_RED
		"sticky": return Blocks.STICKY_BLUE if team == 0 else Blocks.STICKY_RED
		"pitfall": return Blocks.PIT_BLUE if team == 0 else Blocks.PIT_RED
		"wallspring": return Blocks.WALL_SPRING
		"cannon": return Blocks.CANNON
		"crane": return Blocks.CRANE
		"dozer": return Blocks.DOZER
		"conveyor":
			if absf(facing.x) >= absf(facing.z):
				return Blocks.CONV_XP if facing.x >= 0.0 else Blocks.CONV_XN
			return Blocks.CONV_ZP if facing.z >= 0.0 else Blocks.CONV_ZN
	return Blocks.AIR
