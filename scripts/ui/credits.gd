class_name Credits
## The Credits & Licences page: who made the game, plus every licence notice
## the shipped game must carry. Godot's own licence and the notices of the
## third-party code compiled into the engine (FreeType, ENet, mbed TLS...)
## come straight from the engine, so they always match the version we ship.
## Add a line to TEAM for each person, and to ASSETS for each art, sound or
## music source (see docs/ASSET_LICENSES.md).

const TEAM := [
	"Burrow Wars",
	"Made by the Burrow Wars team",
]

## [what, who / where, licence]
const ASSETS := [
	["Effect animations", "pixelfx by Patch and Hugo Duprez (some recoloured)", "MIT, full text below"],
	["Placeholder sounds and app icon", "made by this project's tools/ scripts", "part of the game"],
	["Music (Sneak Rat, Mr Bones, Ratcano Run, Rat Grass Valley)", "made for Burrow Wars by the Burrow Wars team", "part of the game"],
]

const PIXELFX_LICENSE := "res://assets/fx/LICENSE-pixelfx.txt"


static func text() -> String:
	var out := PackedStringArray()
	out.append("\n".join(TEAM))
	out.append("Version %s" % String(ProjectSettings.get_setting("application/config/version")))
	out.append("")
	out.append("ART, SOUND AND EFFECTS")
	for a: Array in ASSETS:
		out.append("%s: %s (%s)" % [a[0], a[1], a[2]])
	out.append("")
	out.append("MADE WITH GODOT ENGINE")
	out.append("This game uses Godot Engine %s, available under the following license:" % Engine.get_version_info()["string"])
	out.append("")
	out.append(Engine.get_license_text())
	out.append("")
	out.append("THIRD-PARTY COMPONENTS IN GODOT ENGINE")
	var used: Dictionary = {}
	for comp: Dictionary in Engine.get_copyright_info():
		out.append("")
		out.append(String(comp.get("name", "")))
		for part: Dictionary in comp.get("parts", []):
			for line: Variant in part.get("copyright", []):
				out.append("  Copyright %s" % String(line))
			var lic := String(part.get("license", ""))
			if lic != "":
				out.append("  License: %s" % lic)
				for id in lic.replace("(", " ").replace(")", " ").replace(" or ", " ").replace(" and ", " ").split(" ", false):
					used[id] = true
	var texts: Dictionary = Engine.get_license_info()
	out.append("")
	out.append("LICENSE TEXTS")
	for id: String in texts:
		if used.has(id):
			out.append("")
			out.append("---- %s ----" % id)
			out.append(String(texts[id]))
	out.append("")
	out.append("PIXELFX")
	out.append(_read(PIXELFX_LICENSE))
	return "\n".join(out)


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "(licence file missing: %s)" % path
	var t := f.get_as_text()
	f.close()
	return t
