class_name LoadingScreen
extends CanvasLayer
## The cover while a match is being built (map generated on a worker thread,
## the world meshed on every core): a spinning golden cheese, a progress bar
## and a tip. Main puts it up; GameSession lifts it once the world is ready.

const TIPS := [
	"Bonk a rat carrying cheese and it drops one.",
	"A full double jump landed flat thumps the block under you.",
	"Cheese Decoys look exactly like the real thing to the other team.",
	"Bubble Shoes catch you when you step off an edge - 2 scrap a bubble.",
	"Raise the Rat Knight Shield (J) and bonks bounce off.",
	"Two TNT blasts break a Team Gate. One blows up a Team Block.",
	"The deep caves hold most of the cheese - and the lava.",
	"Highways make you 60% faster, even hauling cheese.",
	"Stand in the enemy base for 3 seconds to raid their vault.",
	"Squeaker Pads tell your team when someone sneaks past.",
	"Carrying cheese leaves a crumb trail. Follow the crumbs!",
	"That carrier might be a Wind-up Decoy. Bonk it and find out...",
]

var progress := 0.0              # 0..1
var _root: Control
var _cheese: TextureRect
var _bar: ProgressBar
var _title: Label
var _t := 0.0
var _closing := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = UiKit.WOOD_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)
	# the cheese spins about its upright axis inside a fixed box, so nothing else moves
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(150, 132)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(holder)
	_cheese = TextureRect.new()
	var art := "res://assets/ui/burrow_cheese.png"
	_cheese.texture = load(art) if ResourceLoader.exists(art) else Icons.tex("cheese")
	_cheese.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cheese.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cheese.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cheese.size = Vector2(112, 112)
	_cheese.position = Vector2(19, 10)
	_cheese.pivot_offset = Vector2(56, 56)
	holder.add_child(_cheese)
	_title = UiKit.label("Digging out the burrows", 24, UiKit.BRASS)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(420, 0)
	col.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(360, 16)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", UiKit.box(Color(0, 0, 0, 0.35), UiKit.WOOD_LIGHT, 6, 1, 0))
	_bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.BRASS, UiKit.BRASS.lightened(0.3), 6, 1, 0))
	col.add_child(_bar)
	var tip := UiKit.label("Tip: " + String(TIPS[randi() % TIPS.size()]), 15, UiKit.PAPER.darkened(0.15))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tip)


func _process(delta: float) -> void:
	_t += delta
	# turning on its upright axis: the width swings through zero and back, mirrored on the far side
	var turn := cos(_t * 3.4)
	_cheese.scale = Vector2(signf(turn) * maxf(absf(turn), 0.06), 1.0)
	_cheese.position.y = 10.0 + sin(_t * 2.2) * 4.0
	_title.text = "Digging out the burrows" + ".".repeat(int(_t * 2.5) % 4)
	_bar.value = lerpf(_bar.value, clampf(progress, 0.0, 1.0) * 100.0, minf(1.0, delta * 10.0))


func finish() -> void:
	## Fade out, then go.
	if _closing:
		return
	_closing = true
	_bar.value = 100.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
