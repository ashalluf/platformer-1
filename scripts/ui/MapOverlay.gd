class_name MapOverlay extends Control
## The caption over the world map.
##
## The map itself says where; this says what, and whether you are allowed in.
##
## It also owns the state chip, which the collection screen borrows: one chip,
## drawn one way, so "you may go here" and "you have this" are the same object
## in two places. A chip states itself with a MARK and a WORD before it states
## itself with a colour — colour is the third signal, never the only one.

const U := 24.0

const STATE_LABEL := {
	"open": "READY", "cleared": "CLEARED",
	"locked": "LOCKED", "coming": "NOT BUILT YET",
}
## Mark per state. See `state_chip`.
const STATE_MARK := {
	"open": "chevron", "cleared": "gem", "locked": "lock", "coming": "dots",
}

var _kufi: Font
var _naskh: Font
var _latin: Font
var _entry: World.Entry
var _state := "open"
var _t := 0.0
var _life := 0.0     ## since the screen opened — drives the header
var _fade := 0.0     ## since the selection changed — drives the caption
var _refuse := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kufi = UIKit.kufi()
	_naskh = UIKit.naskh()
	_latin = UIKit.latin(0.0)


func set_entry(e: World.Entry, state: String) -> void:
	_entry = e
	_state = state
	_fade = 0.0


## A short red shudder when you try to enter somewhere you cannot go.
func refuse() -> void:
	_refuse = 1.0


func _process(delta: float) -> void:
	_t += delta
	_life = minf(_life + delta, 4.0)
	_fade = minf(_fade + delta, 4.0)
	_refuse = maxf(_refuse - delta * 2.4, 0.0)
	queue_redraw()


func _draw() -> void:
	var g := TitleOverlay.Grid.new(self)
	var view := get_viewport_rect().size
	var cx := g.px(g.cx())

	var head := _header(g, cx)
	var block := _caption_metrics(g)

	# Scrims are cut to the type, not to round fractions of the screen. The map
	# runs to all four edges and the captions need their own ground; anything
	# more than that would turn the screen into a panel.
	var clear := Color(0.02, 0.016, 0.022, 0.0)
	UIKit.scrim(self, Rect2(Vector2.ZERO, Vector2(view.x, head + g.px(U * 1.5))),
		Color(0.02, 0.016, 0.022, 0.86), clear, false)
	var bt: float = block["top"] - g.px(U * 2.0)
	UIKit.scrim(self, Rect2(Vector2(0.0, bt), Vector2(view.x, view.y - bt)),
		clear, Color(0.02, 0.016, 0.022, 0.94), false)

	_header_draw(g, cx)
	_caption(g, block, cx)

	UIKit.hints(self, Vector2(cx, g.px(g.bottom() - U * 0.95)),
		[["LEFT / RIGHT", "TRAVEL"], ["JUMP", "ENTER"], ["DASH", "BACK"]],
		g.px(U * 0.95), true, 0.55 + 0.20 * sin(_t * 2.0))

	UIKit.overlay(self, Rect2(Vector2.ZERO, view), 0.0, 0.34, 0.028, _t)


# --- Header -----------------------------------------------------------------

## Returns the y the header block ends at, so the scrim can be cut to it.
## Drawn separately from the measurement because the scrim has to go down
## first and the type has to go on top of it.
func _header(g: TitleOverlay.Grid, _cx: float) -> float:
	var size := int(UIKit.type_size(self, UIKit.HEAD) * UIKit.ARABIC_RATIO)
	var y := g.px(TitleOverlay.Grid.MARGIN) + _kufi.get_ascent(size)
	var en_y := y + _kufi.get_descent(size) + g.px(U * 0.5)
	return en_y + g.px(U * 0.8)


func _header_draw(g: TitleOverlay.Grid, cx: float) -> void:
	# UIKit.title_block draws exactly this, but with no alpha — and every
	# screen here fades its header in, so the block is composed by hand from
	# the same primitives and the same metrics.
	var a := UIKit.out_quint(TitleOverlay.Grid.stage(_life, 0.05, 0.55))
	var rise := (1.0 - UIKit.out_cubic(TitleOverlay.Grid.stage(_life, 0.05, 0.7))) \
		* g.px(U * 0.5)
	var size := int(UIKit.type_size(self, UIKit.HEAD) * UIKit.ARABIC_RATIO)
	var y := g.px(TitleOverlay.Grid.MARGIN) + _kufi.get_ascent(size) - rise
	var box := g.px(TitleOverlay.Grid.MEASURE)
	UIKit.arabic(self, Vector2(cx - box * 0.5, y), "العالم الأول", size,
		Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a),
		HORIZONTAL_ALIGNMENT_CENTER, box, true, 0.6)

	var en_size := UIKit.type_size(self, UIKit.LABEL)
	var en_y := y + _kufi.get_descent(size) + g.px(U * 0.5)
	var track := UIKit.type_track(self, UIKit.LABEL)
	var w := UIKit.spaced(self, UIKit.latin(0.25), Vector2(cx, en_y),
		"WORLD ONE — EASTERN LIBYA", en_size,
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, a), track, true)

	var rp := UIKit.out_quint(TitleOverlay.Grid.stage(_life, 0.35, 0.5))
	var ry := en_y + g.px(U * 0.8)
	var half := w * 0.5 * rp
	UIKit.rule(self, Vector2(cx - half, ry), Vector2(cx + half, ry),
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, 0.5),
		maxf(1.0, g.px(2.0)))


# --- Caption ----------------------------------------------------------------

## Solve the caption block bottom-up: the chip sits a fixed step above the
## hint row, and the type stacks up from there. Measured from the fonts, so a
## two-line subtitle pushes the name up instead of colliding with the chip.
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

	# Offsets relative to the Arabic baseline.
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
	# The shudder is applied to the whole caption block, not to each line, so
	# the block stays a block while it is refusing you.
	var shake := sin(_t * 46.0) * _refuse * g.px(U * 0.3)
	var meas: float = m["meas"]

	var a1 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.0, 0.26))
	var r1 := (1.0 - UIKit.out_back(TitleOverlay.Grid.stage(_fade, 0.0, 0.42), 1.1)) \
		* g.px(U * 0.55)
	UIKit.arabic(self, Vector2(cx - meas * 0.5 + shake, m["ar_y"] + r1),
		_entry.name_ar, m["ar"],
		Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, a1),
		HORIZONTAL_ALIGNMENT_CENTER, meas)

	var a2 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.06, 0.26))
	var r2 := (1.0 - UIKit.out_cubic(TitleOverlay.Grid.stage(_fade, 0.06, 0.4))) \
		* g.px(U * 0.45)
	UIKit.spaced(self, _latin, Vector2(cx + shake, m["en_y"] + r2), _entry.name_en,
		m["en"], Color(0.80, 0.77, 0.73, a2), UIKit.type_track(self, UIKit.HEAD), true)

	var a3 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.12, 0.3))
	draw_multiline_string(_latin, Vector2(cx - meas * 0.5 + shake, m["sub_y"]),
		_entry.subtitle, HORIZONTAL_ALIGNMENT_CENTER, meas, m["sub"], m["lines"],
		Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, a3 * 0.95))

	var a4 := UIKit.out_quint(TitleOverlay.Grid.stage(_fade, 0.20, 0.3))
	var tint := UIKit.GOLD if _state == "cleared" else UIKit.CREAM
	if _state != "open" and _state != "cleared":
		tint = UIKit.DIM
	state_chip(self, g, Vector2(cx + shake, m["chip_y"]), m["chip_h"],
		str(STATE_LABEL.get(_state, "")), str(STATE_MARK.get(_state, "dots")),
		tint, a4, _refuse)


# --- The state chip ---------------------------------------------------------

## One chip, shared with the collection screen. `mark` is the shape that
## carries the state when colour cannot: a chevron for somewhere you may go, a
## cut gem for something you hold, a padlock for something shut, an ellipsis
## for something not built. Shut states are hatched as well, which is the same
## strike-through MenuList puts on a row you cannot pick.
static func state_chip(ci: CanvasItem, g: TitleOverlay.Grid, center: Vector2,
		h: float, label: String, mark: String, tint: Color, alpha: float,
		stress := 0.0) -> void:
	if alpha <= 0.004:
		return
	var col := tint.lerp(Color(1.0, 0.25, 0.18), stress)
	var f := UIKit.latin(0.2)
	var size := UIKit.type_size(ci, UIKit.LABEL)
	var track := UIKit.type_track(ci, UIKit.LABEL)
	var lw := UIKit.spaced_width(f, label, size, track)
	var mw := h * 0.46
	var pad := h * 0.62
	var gap := h * 0.40
	var w := pad * 2.0 + mw + gap + lw
	# A refused chip swells for an instant. Scale is read faster than colour.
	var swell := 1.0 + 0.055 * stress
	w *= swell
	h *= swell

	var skew := h * 0.16
	var rect := Rect2(Vector2(center.x - w * 0.5 - skew * 0.5, center.y),
		Vector2(w, h))
	var pts := UIKit.slab(ci, rect,
		Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, 0.84 * alpha), h * 0.28, skew)
	var shut := mark == "lock" or mark == "dots"
	if shut:
		UIKit.hatch(ci, pts, Color(col.r, col.g, col.b, 0.14 * alpha),
			g.px(9.0), g.px(1.4))
	UIKit.slab_outline(ci, pts, Color(col.r, col.g, col.b,
		(0.95 if stress > 0.01 else 0.72) * alpha),
		maxf(1.2, g.px(1.8) * (1.0 + stress)))

	var mid := rect.position.y + h * 0.5
	var mx := rect.position.x + pad + mw * 0.5
	_mark(ci, mark, Vector2(mx, mid), mw * 0.5, Color(col.r, col.g, col.b, alpha))
	UIKit.spaced(ci, f, Vector2(rect.position.x + pad + mw + gap,
		mid + size * 0.36), label, size, Color(col.r, col.g, col.b, alpha), track)


static func _mark(ci: CanvasItem, kind: String, at: Vector2, r: float,
		col: Color) -> void:
	match kind:
		"chevron":
			UIKit.chevron(ci, at + Vector2(-r * 0.2, 0.0), r * 0.95, col)
		"gem":
			TitleOverlay.gem(ci, at, r * 0.95, true, col)
		"gem_empty":
			TitleOverlay.gem(ci, at, r * 0.95, false, col)
		"lock":
			# Drawn, not a glyph: the fallback face has no padlock and a tofu
			# box in a status chip is worse than no mark at all.
			var body := Rect2(at + Vector2(-r * 0.78, -r * 0.05),
				Vector2(r * 1.56, r * 1.05))
			ci.draw_rect(body, Color(col.r, col.g, col.b, 0.9))
			ci.draw_arc(at + Vector2(0.0, -r * 0.05), r * 0.52, PI, TAU, 12,
				Color(col.r, col.g, col.b, 0.9), maxf(1.2, r * 0.3), true)
		_:
			for i in 3:
				ci.draw_circle(at + Vector2((i - 1) * r * 0.82, 0.0),
					maxf(1.0, r * 0.22), Color(col.r, col.g, col.b, 0.85))
