class_name Mutators
## Match options you can switch on for a Cheese Race or a Scrap Race, in two
## drop-downs on the setup page: EXTRAS (events that happen during the match)
## and MODIFIERS (rule changes for the whole match). A match's settings carry
## them together as "mutators": an array of ids from LIST. Add one here, give
## it a name and a line of description, and check Match.has_mutator(id) where
## it acts.

const EXTRAS := ["meteors", "lava_rise", "flash_freeze", "fungal"]
const MODIFIERS := ["super_springs", "low_gravity", "tnt_madness", "class_roulette", "scrap_rush", "fragile_world", "cheese_rain"]
const LIST := EXTRAS + MODIFIERS
const NAMES := {"meteors": "Meteor Shower", "lava_rise": "Lava Rise", "flash_freeze": "Flash Freeze", "fungal": "Fungal Outbreak",
	"super_springs": "Super Springs", "low_gravity": "Low Gravity", "tnt_madness": "TNT Madness", "class_roulette": "Class Roulette",
	"scrap_rush": "Scrap Rush", "fragile_world": "Fragile World", "cheese_rain": "Cheese Rain"}
const BLURBS := {
	"meteors": "Meteors fall at random through the match: a red ring warns where, then the blast digs a crater, bonks anyone caught in it, and leaves a chunk of scrap.",
	"lava_rise": "Lava creeps up from the bottom of the map, 5 blocks a minute from 1 minute in, until it's just under the bases.",
	"flash_freeze": "At 45 seconds a cold snap turns every drop of water on the map to ice.",
	"fungal": "Giant mushrooms sprout across the battlefield through the match: new platforms, and new obstacles.",
	"super_springs": "Springs launch rats three times higher.",
	"low_gravity": "Higher jumps, slower falls, and ridiculous siege physics.",
	"tnt_madness": "TNT and Mobile TNT cost a quarter of the usual price.",
	"class_roulette": "Every 2 minutes everyone becomes a random different class.",
	"scrap_rush": "Every scrap block is worth three times as much.",
	"fragile_world": "Every block breaks in one hit.",
	"cheese_rain": "Cheese falls from the sky at random every so often.",
}


static func clean(v: Variant) -> Array[String]:
	## Known ids only, each once, in LIST order (from settings, a save or the network).
	var out: Array[String] = []
	if v is PackedStringArray:
		v = Array(v)   # (e.g. a server's --mutators list)
	if v is Array:
		for id: String in LIST:
			if (v as Array).has(id):
				out.append(id)
	return out


static func describe(ids: Array) -> String:
	## "Meteor Shower" / "" for none.
	var names: Array[String] = []
	for id: String in clean(ids):
		names.append(String(NAMES[id]))
	return ", ".join(names)
