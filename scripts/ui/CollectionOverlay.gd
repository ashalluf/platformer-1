class_name CollectionOverlay extends Control
## The type over the chain room.
##
## Deliberately sparse: the chains are the content, and everything drawn here
## is a caption for the one you are looking at. Same grid, same header shape,
## same caption stack and the same state chip as the world map — the two
## screens are the same screen with a different subject, and should read that
## way when you move between them.

const U := 24.0
const HEAD_AR := "السلاسل"
const HEAD_EN := "THE CHAINS"

var _kufi: Font
var _naskh: Font
var _latin: Font
var _entry: World.Entry
var _earned := false
var _count := 0
var _t := 0.0
var _life := 0.0     ## since the screen opened — drives the header
var _fade := 0.0     ## since the selection changed — drives the caption


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kufi = UIKit.kufi()
	_naskh = UIKit.naskh()
	_latin = UIKit.latin(0.0)


func set_entry(e: World.Entry, earned: bool, count: int) -> void:
	_entry = e
	_earned = earned
	_count = count
	_fade = 0.0


func _process(delta: float) -> void:
	_t += delta
	_life = minf(_life + delta, 4.0)
	_fade = minf(_fade + delta, 4.0)
	queue_redraw()


func _draw() -> void:
	var g := TitleOverlay.Grid.new(self)
	var view := get_viewport_rect().size
	var cx := g.px(g.cx())

	var head_end := _header_bottom(g)
	var block := _caption_metrics(g)

	# The caption block needs its own dark, because the room behind it changes
	# brightness as you earn chains and lights the floor it stands on. Both
	# scrims are cut to the type they carry, not to a round fraction.
	var clear := Color(0.02, 0.016, 0.022, 0.0)
	UIKit.scrim(self, Rect2(Vector2.ZERO, Vector2(view.x, head_end + g.px(U * 1.5))),
		Color(0.02, 0.016, 0.022, 0.80), clear, false)
	var bt: float = block["top"] - g.px(U * 2.0)
	UIKit.scrim(self, Rect2(Vector2(0.0, bt), Vector2(view.x, view.y - bt)),
		clear, Color(0.02, 0.016, 0.022, 0.94), false)

	_header(g, cx)
	_caption(g, block, cx)

	UIKit.hints(self, Vector2(cx, g.px(g.bottom() - U * 0.95)),
		[["LEFT / RIGHT", "BROWSE"], ["DASH", "BACK"]],
		g.px(U * 0.95), true, 0.55 + 0.20 * sin(_t * 2.0))

	UIKit.overlay(self, Rect2(Vector2.ZERO, view), 0.0, 0.34, 0.028, _t)


# --- Header -----------------------------------------------------------------

## Where the header block ends, so the scrim can be cut to it. Kept separate
## from the drawing because the scrim goes down first and the type on top.
func _header_bottom(g: TitleOverlay.Grid) -> float:
	var size := int(UIKit.type_size(self, UIKit.HEAD) * UIKit.ARABIC_RATIO)
	var y := g.px(TitleOverlay.Grid.MARGIN) + _kufi.get_ascent(size)
	var en_y := y + _kufi.get_descent(size) + g.px(U * 0.5)
	return en_y + g.px(U * 0.8) + g.px(U * 1.3)


func _header(g: TitleOverlay.Grid, cx: float) -> void:
	# UIKit.title_block draws this shape, but takes no alpha, and this header
	# fades in — so it is composed by hand from the same primitives and the
	# same metrics, and stays identical to the map's.
	var a := UIKit.out_quint(TitleOverlay.Grid.stage(_life, 0.05, 0.55))
	var rise := (1.0 - UIKit.out_cubic(TitleOverlay.Grid.stage(_life, 0.05, 0.7))) \
		* g.px(U * 0.5)
	var size := int(UIKit.type_size(self, UIKit.HEAD) * UIKit.ARABIC_RATIO)
	var y := g.px(TitleOverlay.Grid.MARGIN) + _kufi.get_ascent(size) - rise
	var box := g.px(TitleOverlay.Grid.MEASURE)
	UIKit.arabic(self, Vector2(cx - box * 0.5, y), HEAD_AR, size,
		Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a),
		HORIZONTAL_ALIGNMENT_CENTER, box, true, 0.6)

	var en_size := UIKit.type_size(self, UIKit.LABEL)
	var en_y := y + _kufi.get_descent(size) + g.px(U * 0.5)
	var w := UIKit.spaced(self, UIKit.latin(0.25), Vector2(cx, en_y), HEAD_EN,
		en_size, Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, a),
		UIKit.type_track(self, UIKit.LABEL), true)

	var rp := UIKit.out_quint(TitleOverlay.Grid.stage(_life, 0.35, 0.5))
	var ry := en_y + g.px(U * 0.8)
	UIKit.rule(self, Vector2(cx - w * 0.5 * rp, ry), Vector2(cx + w * 0.5 * rp, ry),
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, 0.5),
		maxf(1.0, g.px(2.0)))

	# The count is pips, not a number: five settings, filled or empty. It says
	# how many and how many are left in one glance, without reading.
	var pr := g.px(U * 0.36)
	var gap := g.px(U * 1.15)
	var pa := UIKit.out_quint(TitleOverlay.Grid.stage(_life, 0.5, 0.5))
	if pa > 0.01:
		TitleOverlay.pip_row(self, Vector2(cx - gap * 2.0, ry + g.px(U * 1.05)),
			_count, 5, pr * (0.7 + 0.3 * pa), gap, pa)


# --- Caption ----------------------------------------------------------------

## Solved bottom-up from the hint row, exactly as the map's is, so a chain and
## a level caption sit on the same lines.
func _caption_metrics(g: TitleOverlay.Grid) -> Dictionary:
	var ar_size := int(UIKit.type_size(self, UIKit.TITLE) * UIKit.ARABIC_RATIO)
	var en_size := UIKit.type_size(self, UIKit.HEAD)
	var sub_size := UIKit.type_size(self, UIKit.BODY)
	var meas := g.px(TitleOverlay.Grid.MEASURE)
	var sub := _entry.subtitle if _entry != null else ""

	var lines := 1
	if _latin.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x > meas:
		lines = 2
	var line_h := _latin.get_height(sub_size)

	var d_en := _naskh.get_descent(ar_size) + g.px(U * 0.55)
	var d_sub := d_en + g.px(U * 1.35)
	var d_chip := d_sub + line_h * (lines - 1) + g.px(U * 0.95)
	var chip_h := g.px(U * 1.5)

	var chip_bottom := g.px(g.bottom() - U * 0.95) - g.px(U * 1.5)
	var ar_y := chip_bottom - chip_h - d_chip

	return {
		"ar": ar_size, "en": en_size, "sub": sub_size, "meas": meas,
		"lines": lines, "chip_h": chip_h,
		"ar_y": ar_y, "en_y": ar_y + d_en, "sub_y": ar_y + d_sub,
		"chip_y": ar_y + d_chip,
		"top": ar_y - _naskh.get_ascent(ar_size),
	}


func _caption(g: TitleOverlay.Grid, m: Dictionary, cx: float) -> void:
	if _entry == null:
		return
	var meas: float = m["meas"]

	var a1 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.0, 0.26))
	var r1 := (1.0 - UIKit.out_back(TitleOverlay.Grid.stage(_fade, 0.0, 0.42), 1.1)) \
		* g.px(U * 0.55)
	UIKit.arabic(self, Vector2(cx - meas * 0.5, m["ar_y"] + r1), _entry.name_ar,
		m["ar"], Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a1),
		HORIZONTAL_ALIGNMENT_CENTER, meas)

	var a2 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.06, 0.26))
	var r2 := (1.0 - UIKit.out_cubic(TitleOverlay.Grid.stage(_fade, 0.06, 0.4))) \
		* g.px(U * 0.45)
	UIKit.spaced(self, _latin, Vector2(cx, m["en_y"] + r2), _entry.name_en, m["en"],
		Color(0.80, 0.77, 0.73, a2), UIKit.type_track(self, UIKit.HEAD), true)

	var a3 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.12, 0.3))
	draw_multiline_string(_latin, Vector2(cx - meas * 0.5, m["sub_y"]),
		_entry.subtitle, HORIZONTAL_ALIGNMENT_CENTER, meas, m["sub"], m["lines"],
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, a3 * 0.95))

	# Three states, three marks: a cut gem you hold, an empty setting you have
	# not filled, a padlock on a level that does not exist yet.
	var label := "EARNED"
	var mark := "gem"
	var tint := UIKit.GOLD
	if not _earned:
		var built := _entry.built()
		label = "NOT YET EARNED" if built else "LOCKED"
		mark = "gem_empty" if built else "lock"
		tint = UIKit.CREAM if built else UIKit.DIM
	var a4 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.20, 0.3))
	MapOverlay.state_chip(self, g, Vector2(cx, m["chip_y"]), m["chip_h"], label,
		mark, tint, a4)
