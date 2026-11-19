class_name TeleporterView
extends Node3D
## Teleporter pads, live: a charged entrance glows with rings rising off it
## in its team's colour (pixelfx scifi/teleporter-pad); while it recharges
## it goes dark. Exits glow faintly all the time. The pads themselves are
## blocks (ChunkMesher); this only adds the light show. Reads Match.tele_pads(),
## which online players get in each snapshot. Presentation only.

const ENTRANCE_SCALE := 0.8
const EXIT_SCALE := 0.5

var m: Match
var _glow: Dictionary = {}     # pad cell -> FxSprite
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or m == null:
		return
	_t = 0.15
	var want := {}
	for p: Array in m.tele_pads():
		var cell: Vector3i = p[0]
		var is_exit := bool(p[1])
		if is_exit or bool(p[3]):
			want[cell] = p
	for cell: Vector3i in _glow.keys():
		if not want.has(cell) or not is_instance_valid(_glow[cell]):
			if is_instance_valid(_glow[cell]):
				(_glow[cell] as Node).queue_free()
			_glow.erase(cell)
	for cell: Vector3i in want:
		if _glow.has(cell):
			continue
		var p: Array = want[cell]
		var team := clampi(int(p[2]), 0, 1)
		var s := FxSprite.play(self, "tele_pad", Vector3(cell) + Vector3(0.5, 0.12, 0.5),
			EXIT_SCALE if bool(p[1]) else ENTRANCE_SCALE, null, 1.0e9, UiKit.TEAM[team], false, false, 0.85)
		if s != null:
			_glow[cell] = s


func glowing(cell: Vector3i) -> bool:
	return _glow.has(cell) and is_instance_valid(_glow[cell])
