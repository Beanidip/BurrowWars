class_name UiKit
## Shared look for every menu: wood panels, brass trim, parchment text.
## Everything is built from StyleBoxFlat so it scales cleanly at any
## resolution (the project uses canvas_items stretch with an expanding aspect).

const WOOD_DARK := Color(0.16, 0.11, 0.07)
const WOOD := Color(0.33, 0.22, 0.13)
const WOOD_LIGHT := Color(0.47, 0.32, 0.19)
const BRASS := Color(0.87, 0.66, 0.26)
const PAPER := Color(0.96, 0.90, 0.76)
const INK := Color(0.18, 0.13, 0.09)
const TEAM := [Color(0.35, 0.58, 0.98), Color(0.95, 0.38, 0.33)]

static var _theme: Theme


static func box(bg: Color, border: Color, radius := 8, width := 2, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	for type: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box(WOOD, BRASS.darkened(0.35), 8, 2, 8))
		t.set_stylebox("hover", type, box(WOOD_LIGHT, BRASS, 8, 2, 8))
		t.set_stylebox("pressed", type, box(WOOD_DARK, BRASS, 8, 3, 8))
		t.set_stylebox("disabled", type, box(WOOD_DARK.lightened(0.05), WOOD, 8, 2, 8))
		t.set_stylebox("focus", type, box(Color(0, 0, 0, 0), PAPER, 8, 2, 8))
		t.set_color("font_color", type, PAPER)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, BRASS)
		t.set_color("font_disabled_color", type, PAPER.darkened(0.5))
	t.set_stylebox("panel", "PanelContainer", box(WOOD_DARK.lerp(WOOD, 0.35), BRASS, 12, 3, 16))
	t.set_stylebox("background", "ProgressBar", box(WOOD_DARK, WOOD, 6, 2, 0))
	t.set_stylebox("fill", "ProgressBar", box(BRASS, BRASS.lightened(0.2), 6, 1, 0))
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "CheckBox", PAPER)
	t.set_stylebox("normal", "LineEdit", box(WOOD_DARK, WOOD_LIGHT, 6, 2, 6))
	t.set_color("font_color", "LineEdit", PAPER)
	_theme = t
	return t


static func label(text: String, size := 17, color := PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrapped(text: String, size := 15, color := PAPER) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, on_press: Callable, min_size := Vector2(200, 42)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = theme()
	return p


static func center_panel(parent: Control, width: float, height: float) -> VBoxContainer:
	## A centred dialog that always fits a 1280x720 logical viewport.
	## Returns the VBox to fill; the dialog root is vbox.get_meta("root").
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dim)
	var p := panel()
	p.custom_minimum_size = Vector2(minf(width, 1200.0), minf(height, 660.0))
	holder.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	parent.add_child(holder)
	v.set_meta("root", holder)
	return v


static func scroll(min_height: float) -> Array:
	## Returns [ScrollContainer, VBoxContainer inside it].
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, min_height)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return [sc, v]


static func slider(lo: float, hi: float, step: float, value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 24)
	s.value_changed.connect(on_change)
	return s


static func row(left: Control, right: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	h.add_child(right)
	return h
