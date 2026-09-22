class_name IceHUD extends Control
## The bonus-level HUD: two rings and a number.
##
## Inside an ICE level there are exactly two facts — how many of the hundred you
## have, and how long is left — so they get one composed instrument instead of
## two widgets in two corners. Outer ring is the clock, draining clockwise from
## twelve; inner ring is the haul, filling the same way; the count sits in the
## middle, the largest type on the screen. A ring reads as a closing window
## without a label; a bar would need one.
##
## URGENCY IS NEVER JUST COLOUR. As the clock runs down it shifts ice → amber →
## hot, but it also loses tick marks (the scale is countable), the ring pulses
## once per second under ten seconds, and the caption plate swaps from the
## label to a plain seconds readout. Any one of those carries the state on its
## own, which is the test.
##
## READABILITY: an ice level is the brightest environment in the game — white
## ground, white walls, bloom on everything — so light type alone would die on
## it. The instrument sits on a soft dark halo (layered discs rather than a
## hard-edged plate, so it never reads as a box over the world), every stroke
## has a warm shadow under it, and the caption sits on a proper UIKit slab.
##
## Everything is authored in 720p design units and multiplied by
## UIKit.ui_scale(), so the instrument is the same size on screen at 720p and 4K.

const ICE := Color(0.62, 0.90, 1.0)
const ICE_DEEP := Color(0.07, 0.18, 0.34)
const AMBER := Color(1.0, 0.74, 0.30)
const HOT := Color(1.0, 0.40, 0.22)
const FLARE := Color(0.92, 0.99, 1.0)

## Layout in 720p design units.
const RADIUS := 56.0
const CENTER_Y := 104.0
const CELEBRATE_TIME := 2.2

var _count := 0
var _shown := 0.0
var _target := 100
var _time := 0.0
var _limit := 1.0
var _pop := 0.0
var _celebrate := 0.0
var _tick := 0.0
var _jolt := 0.0
var _last_sec := -1
var _in := 0.0
var _t := 0.0
var _cells := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_state(count: int, target: int, time_left: float, limit: float) -> void:
	if count != _count:
		_pop = 1.0
	_count = count
	_target = target
	_time = time_left
	_limit = maxf(limit, 0.001)


func celebrate() -> void:
	_celebrate = CELEBRATE_TIME
	_jolt = 1.0


func _process(delta: float) -> void:
	_t += delta
	# The instrument arrives with the player. A bonus level opens on a warp, and
	# a HUD that is simply already there undercuts the entrance.
	_in = minf(_in + delta * 2.2, 1.0)
	modulate.a = UIKit.out_cubic(_in)
	_pop = maxf(_pop - delta * 3.4, 0.0)
	_celebrate = maxf(_celebrate - delta, 0.0)
	_tick = maxf(_tick - delta * 2.6, 0.0)
	_jolt = maxf(_jolt - delta * 2.2, 0.0)

	# The count climbs rather than snapping, but never lags far enough behind to
	# lie about the score — a floor of 30 a second keeps a +10 pickup honest.
	if absf(float(_count) - _shown) < 0.51:
		_shown = float(_count)
	else:
		_shown = move_toward(_shown, float(_count),
			maxf(absf(float(_count) - _shown) * 8.0, 30.0) * delta)

	# One pulse per second in the last ten: the clock acquires a heartbeat
	# exactly when it starts to matter.
	var sec := int(ceil(_time))
	if sec != _last_sec:
		if _time > 0.0 and _time <= 10.0:
			_tick = 1.0
		_last_sec = sec

	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var s := UIKit.ui_scale(self)
	var shake := clampf(float(Gx.get_setting("screen_shake", 1.0)), 0.0, 1.0)
	var c := Vector2(view.x * 0.5, CENTER_Y * s) \
		+ Vector2(sin(_t * 51.0), cos(_t * 43.0)) * (_jolt * _jolt * 5.0 * s * shake)

	var frac := clampf(_time / _limit, 0.0, 1.0)
	var urgent := _time <= 10.0 and _celebrate <= 0.0
	var won := _celebrate > 0.0
	var k := _celebrate / CELEBRATE_TIME
	# The heartbeat scales the whole instrument; at screen_shake 0 it still
	# changes colour, ticks and caption, so nothing is lost by turning it down.
	var r := RADIUS * s * (1.0 + _tick * 0.045 * maxf(shake, 0.35) + k * 0.06) \
		* (0.82 + 0.18 * UIKit.out_back(_in))

	_halo(c, r)
	_time_ring(c, r, s, frac, urgent, won)
	_haul_ring(c, r, s, won, k)
	if won:
		_burst(c, r, s, k)
	_count_text(c, r, s, won, k)
	_caption(c, r, s, urgent, won, k)

	if won:
		# The white-out is held to a tint: this is a reward, not a camera flash,
		# and the player still has to see the level they are standing in.
		draw_rect(Rect2(Vector2.ZERO, view), FLARE * Color(1, 1, 1, k * k * 0.26))


# --- Instrument -------------------------------------------------------------

## Layered discs rather than one hard-edged plate: a dark disc over a white ice
## level would read as a UI panel sitting on the world, a falloff reads as shade.
func _halo(c: Vector2, r: float) -> void:
	for i in 8:
		var t := float(i) / 7.0
		draw_circle(c, r * (2.05 - t * 0.95),
			Color(ICE_DEEP.r, ICE_DEEP.g, ICE_DEEP.b, 0.055 + t * 0.055))


func _time_ring(c: Vector2, r: float, s: float, frac: float, urgent: bool,
		won: bool) -> void:
	var col := ICE
	if won:
		col = UIKit.GOLD
	else:
		col = ICE.lerp(AMBER, clampf(inverse_lerp(0.45, 0.18, frac), 0.0, 1.0))
		col = col.lerp(HOT, clampf(inverse_lerp(0.18, 0.04, frac), 0.0, 1.0))
		if urgent:
			col = col.lerp(FLARE, _tick * 0.6)

	var track := 9.0 * s
	draw_arc(c, r, 0.0, TAU, 64, UIKit.SHADOW * Color(1, 1, 1, 0.55), track * 1.5, true)
	draw_arc(c, r, 0.0, TAU, 64, Color(ICE_DEEP.r, ICE_DEEP.g, ICE_DEEP.b, 0.85),
		track, true)

	var sweep := TAU * (1.0 if won else frac)
	if sweep > 0.001:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + sweep, 96, col, track * 0.66, true)
		# A lit inner lip, so the arc has a thickness instead of a flat stroke.
		draw_arc(c, r - track * 0.28, -PI * 0.5, -PI * 0.5 + sweep, 96,
			col.lerp(FLARE, 0.5) * Color(1, 1, 1, 0.5), track * 0.16, true)

	# The scale: minute-hand ticks that go out as the time goes. Countable, so
	# the state does not depend on reading a hue.
	var n := clampi(int(round(_limit / 4.0)), 8, 24)
	for i in n:
		var a := -PI * 0.5 + TAU * (float(i) / n)
		var dir := Vector2(cos(a), sin(a))
		var lit := (float(i) / n) < frac or won
		var inner := r + track * 0.75
		var outer := inner + (7.0 if lit else 3.5) * s
		var tc := col * Color(1, 1, 1, 0.95) if lit else \
			UIKit.CREAM * Color(1, 1, 1, 0.18)
		if lit and urgent and _tick > 0.0 and i == int(frac * n):
			tc = FLARE
		draw_line(c + dir * inner, c + dir * outer, tc, 2.2 * s, true)

	# The head of the arc: a bright notch that owns the current value.
	if not won and frac > 0.001:
		var ha := -PI * 0.5 + sweep
		var hd := Vector2(cos(ha), sin(ha))
		draw_line(c + hd * (r - track * 0.7), c + hd * (r + track * 0.7),
			FLARE * Color(1, 1, 1, 0.9), 2.6 * s, true)


## The haul, inside the clock: fills as the clock empties, and turns gold as it
## approaches the hundred so the two rings are never confused for each other.
func _haul_ring(c: Vector2, r: float, s: float, won: bool, k: float) -> void:
	var rr := r * 0.74
	var w := 6.0 * s
	var p := clampf(_shown / maxf(float(_target), 1.0), 0.0, 1.0)
	draw_arc(c, rr, 0.0, TAU, 56, Color(ICE_DEEP.r, ICE_DEEP.g, ICE_DEEP.b, 0.7), w, true)
	if p > 0.001:
		var col := ICE.lerp(UIKit.GOLD, p * p)
		if won:
			col = UIKit.GOLD.lerp(FLARE, 0.4 + 0.4 * sin(_t * 11.0))
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * p, 72, col, w * (1.0 + _pop * 0.4), true)
	if won:
		draw_arc(c, rr * (1.0 + (1.0 - k) * 0.5), 0.0, TAU, 64,
			UIKit.GOLD * Color(1, 1, 1, k * 0.7), 2.0 * s, true)


func _count_text(c: Vector2, r: float, s: float, won: bool, k: float) -> void:
	var base := UIKit.type_size(self, UIKit.TITLE)
	var size := int(base * (1.22 + _pop * _pop * 0.22 + k * 0.18))
	var tint := UIKit.CREAM.lerp(FLARE, _pop * 0.6)
	if won:
		tint = UIKit.GOLD.lerp(FLARE, 0.5 + 0.5 * sin(_t * 13.0))
	var text := "%d" % int(round(_shown))
	var w := _digits_width(text, size, 2.0 * s)
	_digits(c + Vector2(-w * 0.5, size * 0.36), text, size, 2.0 * s, tint)

	var sub := "/ %d" % _target
	var sub_size := UIKit.type_size(self, UIKit.MICRO)
	var sw := UIKit.spaced_width(UIKit.latin(0.0), sub, sub_size, 2.0 * s)
	UIKit.spaced(self, UIKit.latin(0.0), c + Vector2(-sw * 0.5, r * 0.62), sub,
		sub_size, ICE * Color(1, 1, 1, 0.85), 2.0 * s)


## The hundred. Rays and an expanding shock, because collecting all of them is
## the rarest thing a player does in a level and it should not pass quietly.
func _burst(c: Vector2, r: float, s: float, k: float) -> void:
	for i in 20:
		var a := TAU * i / 20.0 + _t * 0.5
		var dir := Vector2(cos(a), sin(a))
		var len := r * (1.25 + (1.0 - k) * (1.4 + 0.5 * sin(i * 2.1)))
		draw_line(c + dir * r * 1.15, c + dir * len,
			UIKit.GOLD * Color(1, 1, 1, k * k * 0.8), 2.4 * s, true)
	for i in 2:
		var ring := r * (1.0 + (1.0 - k) * (2.2 + i * 0.9))
		draw_arc(c, ring, 0.0, TAU, 48,
			FLARE * Color(1, 1, 1, k * k * (0.5 - i * 0.2)), (3.0 - i) * s, true)


func _caption(c: Vector2, r: float, s: float, urgent: bool, won: bool, k: float) -> void:
	var latin_line := "ICE SRIRACHA"
	var col := ICE * Color(1, 1, 1, 0.9)
	if urgent:
		latin_line = "%d SEC" % int(ceil(_time))
		col = HOT.lerp(FLARE, _tick * 0.7)
	if won:
		latin_line = "CHAIN EARNED"
		col = UIKit.GOLD

	var size := UIKit.type_size(self, UIKit.MICRO)
	var track := UIKit.type_track(self, UIKit.MICRO)
	var text_w := UIKit.spaced_width(UIKit.latin(0.3), latin_line, size, track)
	var plate := Rect2(Vector2(c.x - text_w * 0.5 - 20.0 * s, c.y + r + 14.0 * s),
		Vector2(text_w + 40.0 * s, 26.0 * s))
	var pts := UIKit.slab(self, plate,
		Color(ICE_DEEP.r, ICE_DEEP.g, ICE_DEEP.b, 0.62), 9.0 * s, 5.0 * s)
	UIKit.slab_outline(self, pts, col * Color(1, 1, 1, 0.45), 1.2 * s)
	UIKit.spaced(self, UIKit.latin(0.3),
		Vector2(c.x + 2.5 * s, plate.position.y + 18.0 * s), latin_line, size, col,
		track, true)

	if won:
		# Arabic leads on the reward line, Latin already sits beneath it on the
		# plate. One call — Arabic is cursive and must not be letterspaced.
		var asize := int(UIKit.type_size(self, UIKit.LABEL) * UIKit.ARABIC_RATIO)
		var aw := UIKit.kufi().get_string_size("سلسلة", HORIZONTAL_ALIGNMENT_LEFT,
			-1, asize).x
		UIKit.arabic(self, Vector2(c.x - aw * 0.5, plate.position.y - 8.0 * s),
			"سلسلة", asize, UIKit.GOLD * Color(1, 1, 1, clampf(k * 1.6, 0.0, 1.0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)


# --- Primitives -------------------------------------------------------------

## Fixed-advance numerals, so a count that changes every half second does not
## shuffle its own layout under the player's eye. Same rule as the main HUD;
## UIKit has no numeral setter and it is not mine to extend.
func _digits(at: Vector2, text: String, size: int, track: float, tint: Color) -> void:
	var font := UIKit.latin(0.35)
	var cell := _cell_w(size) + track
	var off := Vector2(1.0, 1.5) * maxf(1.0, size * 0.06)
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var cx := x + (cell - track - cw) * 0.5
		draw_string(font, Vector2(cx, at.y) + off, ch, HORIZONTAL_ALIGNMENT_LEFT,
			-1, size, UIKit.SHADOW * Color(1, 1, 1, 0.7 * tint.a))
		draw_string(font, Vector2(cx, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, tint)
		x += cell


func _digits_width(text: String, size: int, track: float) -> float:
	return maxf(text.length() * (_cell_w(size) + track) - track, 0.0)


func _cell_w(size: int) -> float:
	if _cells.has(size):
		return float(_cells[size])
	var font := UIKit.latin(0.35)
	var w := 0.0
	for d in 10:
		w = maxf(w, font.get_string_size(str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	_cells[size] = w
	return w
