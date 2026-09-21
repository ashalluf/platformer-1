class_name MapOverlay extends Control
## The caption over the world map.
##
## The map itself says where; this says what, and whether you are allowed in.

const STATE_LABEL := {
	"open": "READY", "cleared": "CLEARED",
	"locked": "LOCKED", "coming": "NOT BUILT YET",
}

var _font: Font
var _kufi: Font
var _naskh: Font
var _entry: World.Entry
var _state := "open"
var _t := 0.0
var _fade := 0.0
var _refuse := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_kufi = PropKit.font(PropKit.FONT_KUFI)
	_naskh = PropKit.font(PropKit.FONT_NASKH)


func set_entry(e: World.Entry, state: String) -> void:
	_entry = e
	_state = state
	_fade = 0.0


## A short red shudder when you try to enter somewhere you cannot go.
func refuse() -> void:
	_refuse = 1.0


func _process(delta: float) -> void:
	_t += delta
	_fade = minf(_fade + delta * 5.0, 1.0)
	_refuse = maxf(_refuse - delta * 2.4, 0.0)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var cx := view.x * 0.5
	var clear := Color(0.02, 0.016, 0.022, 0.0)

	# Top and bottom scrims: the map runs to the edges of the screen and the
	# type needs its own ground.
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(view.x, 0),
			Vector2(view.x, view.y * 0.24), Vector2(0, view.y * 0.24)]),
		PackedColorArray([Color(0.02, 0.016, 0.022, 0.82),
			Color(0.02, 0.016, 0.022, 0.82), clear, clear]))
	draw_polygon(
		PackedVector2Array([Vector2(0, view.y * 0.62), Vector2(view.x, view.y * 0.62),
			Vector2(view.x, view.y), Vector2(0, view.y)]),
		PackedColorArray([clear, clear, Color(0.02, 0.016, 0.022, 0.92),
			Color(0.02, 0.016, 0.022, 0.92)]))

	var hw := _kufi.get_string_size("العالم الأول", HORIZONTAL_ALIGNMENT_LEFT,
		-1, int(view.y * 0.042)).x
	draw_string(_kufi, Vector2(cx - hw * 0.5, view.y * 0.095), "العالم الأول",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(view.y * 0.042), UIKit.CREAM)
	UIKit.spaced(self, _font, Vector2(cx, view.y * 0.130), "WORLD ONE — EASTERN LIBYA",
		int(view.y * 0.021), UIKit.SAUCE_HOT, view.y * 0.008, true)

	if _entry == null:
		return

	var shake := sin(_t * 46.0) * _refuse * 7.0
	var base := view.y * 0.775 + (1.0 - _fade) * 14.0
	var col := Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, _fade)

	var aw := _naskh.get_string_size(_entry.name_ar, HORIZONTAL_ALIGNMENT_LEFT,
		-1, int(view.y * 0.040)).x
	draw_string(_naskh, Vector2(cx - aw * 0.5 + shake, base), _entry.name_ar,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(view.y * 0.040), col)
	UIKit.spaced(self, _font, Vector2(cx + shake, base + view.y * 0.042),
		_entry.name_en, int(view.y * 0.026), col, view.y * 0.007, true)
	draw_string(_font, Vector2(cx - 340.0, base + view.y * 0.078), _entry.subtitle,
		HORIZONTAL_ALIGNMENT_CENTER, 680.0, int(view.y * 0.021),
		Color(0.78, 0.74, 0.70, _fade * 0.9))

	var tint := UIKit.GOLD if _state == "cleared" else UIKit.CREAM
	if _state != "open" and _state != "cleared":
		tint = UIKit.DIM
	tint = tint.lerp(Color(1.0, 0.25, 0.18), _refuse)
	var chip := Rect2(Vector2(cx - 120.0 + shake, base + view.y * 0.098),
		Vector2(240.0, 30.0))
	var pts := UIKit.slab(self, chip, Color(0.06, 0.055, 0.065, 0.80 * _fade), 9.0, 6.0)
	UIKit.slab_outline(self, pts, Color(tint.r, tint.g, tint.b, 0.7 * _fade), 1.6)
	UIKit.spaced(self, _font, Vector2(cx + shake, chip.position.y + 20.0),
		str(STATE_LABEL.get(_state, "")), 14, Color(tint.r, tint.g, tint.b, _fade),
		3.4, true)

	var a := 0.40 + 0.30 * sin(_t * 2.0)
	UIKit.spaced(self, _font, Vector2(cx, view.y - 34.0),
		"LEFT / RIGHT TO TRAVEL    JUMP TO ENTER    DASH TO GO BACK", 13,
		Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a), 3.2, true)
