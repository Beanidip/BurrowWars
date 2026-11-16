extends Node
## Tiny logging autoload. Never swallows errors: everything goes to stdout
## and the last lines are kept for the pause-menu debug view.

const MAX_LINES := 200
var lines: PackedStringArray = []


func info(msg: String) -> void:
	_write("INFO", msg)


func warn(msg: String) -> void:
	_write("WARN", msg)
	push_warning(msg)


func error(msg: String) -> void:
	_write("ERROR", msg)
	push_error(msg)


func _write(level: String, msg: String) -> void:
	var line := "[%8.2f] %-5s %s" % [Time.get_ticks_msec() / 1000.0, level, msg]
	print(line)
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.remove_at(0)
