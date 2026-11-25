class_name Mutators
## Match options ("Extras" on the setup page): twists you can switch on for
## a Cheese Race or a Scrap Race. A match's settings carry them as
## "mutators": an array of ids from LIST. Add one here, give it a name and a
## line of description, and check Match.has_mutator(id) where it acts.

const LIST := ["meteors"]
const NAMES := {"meteors": "Meteor Shower"}
const BLURBS := {
	"meteors": "Meteors fall at random through the match: a red ring warns where, then the blast digs a crater, bonks anyone caught in it, and leaves a chunk of scrap.",
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
