class_name IceHUD extends Control
## The bonus-level HUD: a count and a clock, and nothing else.
##
## Drawn like the main HUD. The ring is the timer because a bar would need a
## label to say what it measures, and a closing ring does not.

const ICE := Color(0.58, 0.90, 1.0)
const DEEP := Color(0.06, 0.16, 0.30, 0.70)
const WARN := Color(1.0, 0.44, 0.24)
const CREAM := Color(0.96, 0.98, 1.0)

var _count := 0
var _target := 100
var _time := 0.0
var _limit := 1.0
var _pop := 0.0
var _celebrate := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func set_state(count: int, target: int, time_left: float, limit: float) -> void:
	if count != _count:
		_pop = 1.0
	_count = count
	_target = target
	_time = time_left
	_limit = maxf(limit, 0.001)


func celebrate() -> void:
	_celebrate = 2.2


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 3.6, 0.0)
	_celebrate = maxf(_celebrate - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var c := Vector2(view.x * 0.5, 66.0)
	var t := clampf(_time / _limit, 0.0, 1.0)
	var urgent := t < 0.25

	# Timer ring, closing anticlockwise.
	var r := 42.0
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU, 48, DEEP, 7.0, true)
	var col := WARN if urgent else ICE
	if urgent:
		col = col.lerp(CREAM, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * t, 48, col, 5.0, true)

	# Count, big, in the middle.
	var scale_ := 1.0 + _pop * 0.18 + _celebrate * 0.12
	var text := str(_count)
	var s := 40.0 * scale_
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x
	draw_string(_font, c + Vector2(-w * 0.5 + 2.0, s * 0.36 + 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(s), Color(0, 0, 0, 0.55))
	draw_string(_font, c + Vector2(-w * 0.5, s * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(s), CREAM)

	var sub := "/ %d" % _target
	var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(_font, c + Vector2(-sw * 0.5, r + 22.0), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ICE)

	if _celebrate > 0.0:
		var flash := clampf(_celebrate / 2.2, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.85, 0.96, 1.0, flash * 0.30))
