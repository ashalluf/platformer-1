class_name MenuList extends Control
## A keyboard/controller menu, drawn.
##
## No Button nodes: a focused Button draws a themed rectangle and that is the
## exact default look this project is not allowed to have. This owns its own
## selection, input and drawing, and reports which row was chosen.

signal chosen(index: int, id: String)
signal changed(index: int, id: String)

class Row extends RefCounted:
	var id := ""
	var label := ""
	var arabic := ""
	var enabled := true
	var value := ""     ## right-aligned, for settings rows

var rows: Array[Row] = []
var selected := 0
var row_height := 54.0
var origin := Vector2(120.0, 320.0)
var width := 420.0
var font: Font
var arabic_font: Font
var accept_input := true

var _pulse := 0.0
var _slide := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	arabic_font = PropKit.font(PropKit.FONT_NASKH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_row(id: String, label: String, arabic := "", enabled := true, value := "") -> Row:
	var r := Row.new()
	r.id = id
	r.label = label
	r.arabic = arabic
	r.enabled = enabled
	r.value = value
	rows.append(r)
	return r


func current() -> Row:
	return rows[selected] if selected >= 0 and selected < rows.size() else null


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.2, TAU)
	_slide = lerpf(_slide, float(selected), 1.0 - exp(-18.0 * delta))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not accept_input or rows.is_empty():
		return
	if event.is_action_pressed("move_up", true):
		_step(-1)
	elif event.is_action_pressed("move_down", true):
		_step(1)
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		var r := current()
		if r and r.enabled:
			Audio.play_2d("ui", -4.0, 1.25, "UI")
			chosen.emit(selected, r.id)


func _step(dir: int) -> void:
	var start := selected
	for i in rows.size():
		selected = wrapi(selected + dir, 0, rows.size())
		if rows[selected].enabled:
			break
	if selected != start:
		Audio.play_2d("ui", -10.0, 0.95, "UI")
		changed.emit(selected, rows[selected].id)


func _draw() -> void:
	for i in rows.size():
		var r: Row = rows[i]
		var y := origin.y + i * row_height
		var active := i == selected
		var rect := Rect2(Vector2(origin.x, y), Vector2(width, row_height - 10.0))

		var fill := UIKit.INK
		fill.a = 0.72 if active else 0.42
		var pts := UIKit.slab(self, rect, fill, 12.0, 7.0)
		if active:
			var glow := UIKit.SAUCE_HOT.lerp(UIKit.CREAM, 0.35 + 0.35 * sin(_pulse))
			UIKit.slab_outline(self, pts, glow, 2.4)

		var text_col := UIKit.CREAM if r.enabled else UIKit.DIM * Color(1, 1, 1, 0.6)
		if active:
			text_col = UIKit.CREAM
		UIKit.spaced(self, font, Vector2(origin.x + 34.0, y + row_height * 0.58),
			r.label, 22, text_col, 3.2)

		if r.arabic != "":
			# Right-aligned inside the slab: draw_string lays the box out from
			# pos, so the box start is the slab's right edge minus its width.
			draw_string(arabic_font,
				Vector2(origin.x + width - 202.0, y + row_height * 0.52),
				r.arabic, HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 19,
				UIKit.DIM if not active else UIKit.SAUCE_HOT)
		elif r.value != "":
			draw_string(font, Vector2(origin.x + width - 150.0, y + row_height * 0.58),
				r.value, HORIZONTAL_ALIGNMENT_RIGHT, 140.0, 20, text_col)

	# The chevron slides between rows rather than snapping.
	var cy := origin.y + _slide * row_height + (row_height - 10.0) * 0.5
	UIKit.chevron(self, Vector2(origin.x - 22.0 + sin(_pulse) * 3.0, cy), 10.0,
		UIKit.SAUCE_HOT)
