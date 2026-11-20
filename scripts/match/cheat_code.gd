class_name CheatCode
extends RefCounted
## The classic code from Contra: Up Up Down Down Left Right Left Right B A,
## on the keyboard's arrow keys and B / A, or a controller's D-pad and B / A.
## Feed it every input event; it says how far along the code the player is.
## Other keys in between don't break it; a pause of more than GAP seconds does.

const CODE := ["u", "u", "d", "d", "l", "r", "l", "r", "b", "a"]
const GAP := 2.5

var _seq: Array = []
var _last := -1000.0


static func token(event: InputEvent) -> String:
	## "u" "d" "l" "r" "b" "a" for a fresh press of a code key, else "".
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_UP: return "u"
			KEY_DOWN: return "d"
			KEY_LEFT: return "l"
			KEY_RIGHT: return "r"
			KEY_B: return "b"
			KEY_A: return "a"
	elif event is InputEventJoypadButton and event.is_pressed():
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP: return "u"
			JOY_BUTTON_DPAD_DOWN: return "d"
			JOY_BUTTON_DPAD_LEFT: return "l"
			JOY_BUTTON_DPAD_RIGHT: return "r"
			JOY_BUTTON_B: return "b"
			JOY_BUTTON_A: return "a"
	return ""


func feed(tok: String, now: float) -> int:
	## How many presses of the code the latest ones make up (0..10). 10 means
	## it's complete, and it starts over.
	if tok == "":
		return 0
	if now - _last > GAP:
		_seq.clear()
	_last = now
	_seq.append(tok)
	if _seq.size() > CODE.size():
		_seq.remove_at(0)
	for k in range(_seq.size(), 0, -1):
		if _seq.slice(_seq.size() - k) == CODE.slice(0, k):
			if k == CODE.size():
				_seq.clear()
			return k
	return 0
