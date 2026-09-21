class_name CollectionOverlay extends Control
## The type over the chain room.
##
## Deliberately sparse: the chains are the content, and everything drawn here
## is a caption for the one you are looking at.

var _font: Font
var _kufi: Font
var _naskh: Font
var _entry: World.Entry
var _earned := false
var _count := 0
var _t := 0.0
var _fade := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_kufi = PropKit.font(PropKit.FONT_KUFI)
	_naskh = PropKit.font(PropKit.FONT_NASKH)


func set_entry(e: World.Entry, earned: bool, count: int) -> void:
	_entry = e
	_earned = earned
	_count = count
	_fade = 0.0


func _process(delta: float) -> void:
	_t += delta
	_fade = minf(_fade + delta * 5.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var cx := view.x * 0.5

	# The caption block needs its own dark, because the room behind it changes
	# brightness as you earn chains and lights the floor it sits on.
	var clear := Color(0.02, 0.016, 0.022, 0.0)
	var dark := Color(0.02, 0.016, 0.022, 0.92)
	var top := view.y * 0.56
	draw_polygon(
		PackedVector2Array([Vector2(0, top), Vector2(view.x, top),
			Vector2(view.x, view.y), Vector2(0, view.y)]),
		PackedColorArray([clear, clear, dark, dark]))

	# Header: the screen's own name, Arabic first.
	var head := int(view.y * 0.050)
	var hw := _kufi.get_string_size("السلاسل", HORIZONTAL_ALIGNMENT_LEFT, -1, head).x
	draw_string(_kufi, Vector2(cx - hw * 0.5, view.y * 0.115), "السلاسل",
		HORIZONTAL_ALIGNMENT_LEFT, -1, head, UIKit.CREAM)
	UIKit.spaced(self, _font, Vector2(cx, view.y * 0.152), "THE CHAINS",
		int(view.y * 0.024), UIKit.SAUCE_HOT, view.y * 0.010, true)

	UIKit.spaced(self, _font, Vector2(cx, view.y * 0.196),
		"%d OF %d" % [_count, 5], int(view.y * 0.020), UIKit.DIM, 3.4, true)

	if _entry == null:
		return

	# Caption block, bottom centre, sliding up as it fades in.
	var rise := (1.0 - _fade) * 14.0
	var base := view.y * 0.775 + rise
	var col := Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, _fade)

	var aw := _naskh.get_string_size(_entry.name_ar, HORIZONTAL_ALIGNMENT_LEFT,
		-1, int(view.y * 0.040)).x
	draw_string(_naskh, Vector2(cx - aw * 0.5, base), _entry.name_ar,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(view.y * 0.040), col)
	UIKit.spaced(self, _font, Vector2(cx, base + view.y * 0.042), _entry.name_en,
		int(view.y * 0.026), col, view.y * 0.007, true)

	var sub := Color(0.78, 0.74, 0.70, _fade * 0.9)
	draw_string(_font, Vector2(cx - 340.0, base + view.y * 0.078), _entry.subtitle,
		HORIZONTAL_ALIGNMENT_CENTER, 680.0, int(view.y * 0.021), sub)

	# Status chip, under the caption.
	var label := "EARNED"
	var tint := UIKit.GOLD
	if not _earned:
		label = "LOCKED" if not _entry.built() else "NOT YET EARNED"
		tint = UIKit.DIM
	var chip_w := 220.0
	var chip := Rect2(Vector2(cx - chip_w * 0.5, base + view.y * 0.098),
		Vector2(chip_w, 30.0))
	var pts := UIKit.slab(self, chip, Color(0.06, 0.055, 0.065, 0.80 * _fade), 9.0, 6.0)
	UIKit.slab_outline(self, pts, Color(tint.r, tint.g, tint.b, 0.65 * _fade), 1.6)
	UIKit.spaced(self, _font, Vector2(cx, chip.position.y + 20.0), label,
		14, Color(tint.r, tint.g, tint.b, _fade), 3.4, true)

	# Footer prompt.
	var a := 0.40 + 0.30 * sin(_t * 2.0)
	UIKit.spaced(self, _font, Vector2(cx, view.y - 34.0),
		"LEFT / RIGHT TO BROWSE    DASH TO GO BACK", 13,
		Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a), 3.4, true)
