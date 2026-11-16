extends Node
func _ready() -> void:
	var m := Match.new()
	m.auto_step = false
	add_child(m)
	m.setup({"mode": "race", "seed": int(OS.get_environment("SEED")), "goal": 6}, false)
	for team in 2:
		m.spawn_rat(team, "digger", true)
		m.spawn_rat(team, "scout", true)
	var next := 0.0
	while not m.over and m.time < 900.0:
		m.step(1.0 / 30.0)
		if m.time >= next:
			next += 20.0
			var line := "t=%3d score %d-%d |" % [int(m.time), m.scores[0], m.scores[1]]
			for i in m.rats.size():
				var r := m.rats[i]
				var b := m.bots[i]
				line += " %s%d %s c%d (%d,%d,%d)->(%d,%d,%d) s%d|" % [r.class_id[0], r.team, b.mode[0], r.carried, r.position.x, r.position.y, r.position.z, b.target.x, b.target.y, b.target.z, b.stuck_count]
			print(line)
	print("END t=%d score %d-%d" % [int(m.time), m.scores[0], m.scores[1]])
	get_tree().quit()
