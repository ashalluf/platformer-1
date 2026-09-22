class_name TitleOverlay extends Control
## The game's face — and the page grid the four overlay screens share.
##
## Arabic-first logotype: the name set large in Kufi, with the Latin
## transliteration letterspaced underneath. That order is the point — this is a
## love letter to a place, and the place's script leads.
##
## Everything is anchored to the left column, because the frame behind it is
## the beauty benchmark and the right two thirds of that frame is the distance
## Wanis has to cover. Type does not get to stand in front of it.

const LOGO_AR := "ليبيان غانغستاز"
const LOGO_EN := "LIBYAN GANGSTAS"
const TAGLINE := "شرق ليبيا"
const CHAINS_AR := "السلاسل"


## The page grid, in UIKit's 720-tall design space.
##
## UIKit owns the type ranks, the palette and the scale; this owns where things
## sit on the page. It lives in this file because UIKit is the HUD's as well and
## is being edited in parallel — fold it in there once ownership settles.
##
## The system, stated once and used by all four overlay screens:
##
##   UNIT      24 design units. Chosen because MenuList is already placed on
##             it — TitleScreen puts the menu at (96, 336), which is exactly
##             (4U, 14U). The whole product was one number away from a grid.
##   MARGIN    4U = 96. Page margin, both axes, every screen.
##   GUTTER    2U = 48. Between blocks.
##   MEASURE   21U = 504. Body copy never runs wider; long centred lines are
##             the fastest way to make a caption look like a log file.
##   RHYTHM    Vertical steps are whole or half units. Nothing lands on a
##             number somebody typed because it looked about right.
##
## Type comes from UIKit's ranks (DISPLAY/TITLE/HEAD/BODY/LABEL/MICRO) so the
## overlays and the HUD agree. Arabic goes through `UIKit.arabic` — one call,
## never letterspaced, because the glyphs join. Latin display and labels are
## letterspaced by rank. Arabic leads and Latin sits under it at ARABIC_RATIO.
class Grid extends RefCounted:
	const U := 24.0
	const MARGIN := 96.0
	const GUTTER := 48.0
	const MEASURE := 504.0

	var s := 1.0        ## design units -> screen pixels
	var w := 1280.0     ## design-space width (720-tall space, real aspect)
	var h := 720.0

	func _init(ci: CanvasItem) -> void:
		var r := UIKit.design_rect(ci)
		s = UIKit.ui_scale(ci)
		w = r.size.x
		h = r.size.y

	## Design units -> pixels. Every number in these screens is a design unit
	## and passes through here exactly once.
	func px(d: float) -> float:
		return d * s

	func at(x: float, y: float) -> Vector2:
		return Vector2(x, y) * s

	func cx() -> float:
		return w * 0.5

	func left() -> float:
		return MARGIN

	func right() -> float:
		return w - MARGIN

	func bottom() -> float:
		return h - MARGIN

	## Linear 0..1 progress of one staggered element. Every entrance in these
	## screens is built out of this plus a UIKit easing curve.
	static func stage(t: float, delay: float, dur: float) -> float:
		return clampf((t - delay) / maxf(dur, 0.0001), 0.0, 1.0)

	## Sum of per-glyph advances — matches how UIKit.spaced measures, which a
	## single get_string_size does not once kerning is involved.
	static func natural(font: Font, text: String, size: int) -> float:
		var total := 0.0
		for i in text.length():
			total += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		return total

	## Solve a size and an exact tracking so `text` fills `meas` at roughly
	## `em` letterspacing. This is what turns three stacked strings into a
	## lockup: the Latin is justified to the measure the Arabic sets instead of
	## being handed a point size and left to end wherever it ends.
	## Returns (size, tracking).
	static func justify(font: Font, text: String, meas: float, em := 0.34,
			lo := 8, hi := 400) -> Vector2:
		var n := text.length()
		if n < 2:
			return Vector2(float(lo), 0.0)
		var w100 := natural(font, text, 100)
		var guess := meas / maxf(w100 / 100.0 + em * float(n - 1), 0.001)
		var size := clampi(int(round(guess)), lo, hi)
		# Re-solve tracking at the integer size, so the fit is exact rather
		# than off by whatever the rounding cost.
		return Vector2(float(size), (meas - natural(font, text, size)) / float(n - 1))


## MenuList is placed by TitleScreen at design (96, 336) — 4U across, 14U down.
## The type hangs off the same two numbers, which is the whole reason the left
## column reads as a column. If the menu moves, move these with it.
const MENU_X := 96.0
const MENU_TOP := 336.0
## How far across the frame the shaded wedge reaches. The logotype measure is
## clamped to it, so the mark can never stray onto lit sky.
const SCRIM_W := 0.56

var _t := 0.0
var _kufi: Font
var _naskh: Font
var _latin: Font
var _chains := 0

# Cached lockup metrics, in pixels. Fitting the mark costs a couple of dozen
# font measurements and nothing about it changes until the viewport does.
var _fitted := Vector2.ZERO
var _col := 0.0
var _meas := 0.0
var _ar_size := 1
var _ar_y := 0.0
var _rule_y := 0.0
var _en_size := 1
var _en_track := 0.0
var _base_y := 0.0
var _tag_size := 1
var _tag_w := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kufi = UIKit.kufi()
	_naskh = UIKit.naskh()
	_latin = UIKit.latin(0.0)
	_chains = Gx.chain_count()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var g := Grid.new(self)
	if _fitted != view:
		_fit(g)
		_fitted = view

	_scrim(g)
	_logotype(g)
	_tray(g)
	_prompt(g)

	# A whisper of vignette and grain over the whole frame, last. It ties the
	# drawn type to the rendered scene — without it the UI reads as a layer
	# sitting on a photograph instead of as part of the poster.
	UIKit.overlay(self, Rect2(Vector2.ZERO, view), 0.0, 0.20, 0.022, _t)


# --- Lockup -----------------------------------------------------------------

## Fit the mark to a measure rather than handing it a point size. The measure
## is the constraint that actually matters — it has to stay inside the shaded
## wedge and above the first menu slab — so the size falls out of it, and the
## rule and the Latin are then justified to whatever it came to.
func _fit(g: Grid) -> void:
	_col = g.px(MENU_X)

	var target := minf(g.px(g.w * 0.44), g.px(g.w * SCRIM_W) - _col)
	target = minf(target, g.px(g.w - MENU_X - Grid.MARGIN))
	var w100 := _kufi.get_string_size(LOGO_AR, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var floor_size := int(g.px(Grid.U * 1.6))
	_ar_size = clampi(int(round(100.0 * target / maxf(w100, 1.0))),
		floor_size, int(g.px(Grid.U * 4.4)))

	# The band the lockup lives in: page top down to a unit and a half above
	# the menu. If the mark does not clear the top margin, shrink and measure
	# again — that loop is what keeps the screen honest on a short band.
	var band_bot := g.px(MENU_TOP - Grid.U * 1.5)
	for _i in 16:
		_measure(g, band_bot)
		if _ar_y - _kufi.get_ascent(_ar_size) >= g.px(Grid.MARGIN) \
				or _ar_size <= floor_size:
			break
		_ar_size = maxi(_ar_size - maxi(1, int(g.px(4.0))), floor_size)


func _measure(g: Grid, band_bot: float) -> void:
	_meas = _kufi.get_string_size(LOGO_AR, HORIZONTAL_ALIGNMENT_LEFT, -1, _ar_size).x

	# The tagline shares the bottom line with the Latin and is set hard to the
	# right end of the measure. Arabic reads right to left, so the measure's
	# right edge is where it wants to begin, and the two together bracket the
	# line the way a masthead does.
	_tag_size = maxi(int(g.px(Grid.U * 0.75)), 9)
	_tag_w = _naskh.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_size).x

	var en_meas := maxf(_meas - _tag_w - g.px(Grid.U * 1.5), g.px(Grid.U * 6.0))
	var fit := Grid.justify(_latin, LOGO_EN, en_meas, 0.40,
		int(g.px(Grid.U * 0.6)), int(g.px(Grid.U * 2.0)))
	_en_size = int(fit.x)
	_en_track = fit.y

	_base_y = band_bot
	var line_asc := maxf(_latin.get_ascent(_en_size), _naskh.get_ascent(_tag_size))
	_rule_y = _base_y - line_asc - g.px(Grid.U * 0.6)
	_ar_y = _rule_y - g.px(Grid.U * 0.6) - _kufi.get_descent(_ar_size)


func _logotype(g: Grid) -> void:
	# Arabic: rises and settles. Three passes do the work of a bevel on a
	# painted sign — a dark drop for the cut, a warm one for the light
	# bouncing back into it, then the face.
	var ap := Grid.stage(_t, 0.30, 0.95)
	var aa := UIKit.out_quint(Grid.stage(_t, 0.30, 0.7))
	var y := _ar_y + (1.0 - UIKit.out_back(ap, 1.1)) * g.px(Grid.U * 0.9)
	var off := maxf(2.0, _ar_size * 0.05)
	draw_string(_kufi, Vector2(_col + off * 2.0, y + off * 2.0), LOGO_AR,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _ar_size,
		Color(UIKit.SHADOW.r, UIKit.SHADOW.g, UIKit.SHADOW.b, 0.62 * aa))
	draw_string(_kufi, Vector2(_col + off, y + off), LOGO_AR,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _ar_size, Color(0.42, 0.07, 0.03, 0.92 * aa))
	draw_string(_kufi, Vector2(_col, y), LOGO_AR, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_ar_size, Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, aa))

	# The rule wipes out from the column rather than fading in, so it reads as
	# drawn. Two-tone: a short heavy sauce tab, then a thin cream line. The tab
	# is the only piece of pure chroma in the lockup.
	var rp := UIKit.out_quint(Grid.stage(_t, 0.72, 0.55))
	var tab := minf(g.px(Grid.U * 2.4), _meas)
	var end_x := _col + _meas * rp
	if end_x > _col:
		UIKit.rule(self, Vector2(_col, _rule_y), Vector2(minf(end_x, _col + tab),
			_rule_y), UIKit.SAUCE_HOT, maxf(2.0, g.px(6.0)))
	if end_x > _col + tab:
		UIKit.rule(self, Vector2(_col + tab, _rule_y), Vector2(end_x, _rule_y),
			Color(UIKit.CREAM.r, UIKit.CREAM.g, UIKit.CREAM.b, 0.45),
			maxf(1.0, g.px(2.0)))

	# Latin, justified to the Arabic's measure, arriving letter by letter.
	_cascade(g, Vector2(_col, _base_y), LOGO_EN, _en_size, UIKit.CREAM, _en_track,
		0.86, 0.028)

	# Tagline hard right on the same baseline. Never letterspaced.
	var tp := UIKit.out_quint(Grid.stage(_t, 1.12, 0.6))
	UIKit.arabic(self, Vector2(_col + _meas - _tag_w, _base_y), TAGLINE, _tag_size,
		Color(UIKit.SAUCE_HOT.r, UIKit.SAUCE_HOT.g, UIKit.SAUCE_HOT.b, 0.90 * tp))


## Letterspaced Latin where each glyph arrives on its own beat. Worth the hand
## loop here and nowhere else: this is the one piece of type in the game anyone
## will look at for more than a second. Safe on Latin — it does not join.
func _cascade(g: Grid, at: Vector2, text: String, size: int, color: Color,
		tracking: float, delay: float, per: float) -> void:
	var rise := g.px(Grid.U * 0.6)
	var off := Vector2(1.0, 1.0) * maxf(1.0, size * 0.055)
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var adv := _latin.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if ch != " ":
			var p := Grid.stage(_t, delay + float(i) * per, 0.45)
			var a := UIKit.out_quint(p)
			var pos := Vector2(x, at.y + (1.0 - UIKit.out_cubic(p)) * rise)
			draw_string(_latin, pos + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(UIKit.SHADOW.r, UIKit.SHADOW.g, UIKit.SHADOW.b, 0.55 * a))
			draw_string(_latin, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(color.r, color.g, color.b, color.a * a))
		x += adv + tracking


# --- Chain tray -------------------------------------------------------------

## Chains earned, hung off the bottom-right corner of the page grid — the only
## progress the title screen shows. It sits over lit walkway, so it carries its
## own slab. Filled versus hollow pips, never two colours: the count has to
## read without relying on hue.
func _tray(g: Grid) -> void:
	var p := Grid.stage(_t, 1.30, 0.8)
	if p <= 0.0:
		return
	var a := UIKit.out_quint(Grid.stage(_t, 1.30, 0.55))
	var slide := (1.0 - UIKit.out_back(p, 1.2)) * g.px(Grid.U * 1.8)

	var lab_size := UIKit.type_size(self, UIKit.LABEL)
	var ar_size := int(lab_size * UIKit.ARABIC_RATIO)
	var lab_w := _naskh.get_string_size(CHAINS_AR, HORIZONTAL_ALIGNMENT_LEFT, -1,
		ar_size).x
	var pip_r := g.px(Grid.U * 0.34)
	var pip_gap := g.px(Grid.U * 1.05)
	var pad := g.px(Grid.U * 0.7)
	var tray_w := pad * 2.0 + lab_w + g.px(Grid.U) + pip_gap * 4.0 + pip_r * 2.0
	var tray_h := g.px(Grid.U * 1.7)
	var skew := g.px(Grid.U * 0.3)

	# slab() shears the top edge right by `skew`, so the optical right edge is
	# x + width + skew. Park that on the margin, not the raw rect.
	var rect := Rect2(Vector2(g.px(g.right()) - tray_w - skew + slide,
		g.px(g.bottom()) - tray_h), Vector2(tray_w, tray_h))
	var pts := UIKit.slab(self, rect, Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b,
		0.68 * a), g.px(Grid.U * 0.45), skew)
	UIKit.slab_outline(self, pts, Color(UIKit.CREAM.r, UIKit.CREAM.g,
		UIKit.CREAM.b, 0.16 * a), maxf(1.0, g.px(1.4)))

	var mid := rect.position.y + tray_h * 0.5
	UIKit.arabic(self, Vector2(rect.position.x + pad, mid + ar_size * 0.34),
		CHAINS_AR, ar_size, Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, a),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, false, 0.5)
	pip_row(self, Vector2(rect.position.x + pad + lab_w + g.px(Grid.U) + pip_r,
		mid), _chains, 5, pip_r, pip_gap, a)


## The prompt sits on the bottom margin line, on the same column as the mark,
## and holds a slow breath so the screen is never completely static.
func _prompt(g: Grid) -> void:
	var a := UIKit.out_quint(Grid.stage(_t, 1.55, 0.6)) * (0.42 + 0.30 * sin(_t * 2.0))
	UIKit.hints(self, g.at(g.left(), g.bottom() - Grid.U * 0.95),
		[["JUMP", "SELECT"]], g.px(Grid.U * 0.95), false, a)


# --- Scrim ------------------------------------------------------------------

## A soft wedge of shade down the left column. Not a panel — the dawn has to
## keep coming through it; it only has to drop the value enough for cream type
## to sit on a lit concrete wall. It ramps in with the type, so the first
## frames of the game are the photograph, unmarked.
func _scrim(g: Grid) -> void:
	var a := UIKit.out_cubic(Grid.stage(_t, 0.0, 0.85))
	var view := g.px(g.w)
	var vh := g.px(g.h)
	var clear := Color(0.035, 0.030, 0.045, 0.0)
	UIKit.scrim(self, Rect2(Vector2.ZERO, Vector2(view * SCRIM_W, vh)),
		Color(0.035, 0.030, 0.045, 0.62 * a), clear)
	# A second, tighter pass keyed to the lockup measure, so the mark never
	# fights a bright patch of sky however the fit came out.
	var w2 := minf(_col + _meas + g.px(Grid.U * 2.0), view * SCRIM_W)
	UIKit.scrim(self, Rect2(Vector2.ZERO, Vector2(w2, vh * 0.78)),
		Color(0.02, 0.02, 0.03, 0.34 * a), clear)


# --- Gems -------------------------------------------------------------------
# UIKit.pips draws the same cut gem, but takes no alpha — which is fine for a
# HUD that is always on and wrong for four screens that all fade their content
# in. These mirror its construction exactly and honour the colour's alpha, so a
# chain pip on the title tray, in the chain-room header, in a state chip and in
# the result ledger are one object. Fold them back into UIKit if `pips` ever
# grows an alpha.

## One diamond. `col.a` carries the fade; `filled` carries the state, which is
## what has to read when the colour is taken away.
static func gem(ci: CanvasItem, at: Vector2, r: float, filled: bool,
		col: Color) -> void:
	if col.a <= 0.004:
		return
	var d := PackedVector2Array([
		at + Vector2(0.0, -r), at + Vector2(r * 0.8, 0.0),
		at + Vector2(0.0, r), at + Vector2(-r * 0.8, 0.0)])
	if filled:
		ci.draw_colored_polygon(PackedVector2Array([
			at + Vector2(0.0, -r * 1.5), at + Vector2(r * 1.2, 0.0),
			at + Vector2(0.0, r * 1.5), at + Vector2(-r * 1.2, 0.0)]),
			Color(col.r, col.g, col.b, 0.16 * col.a))
		ci.draw_colored_polygon(d, col)
		# Table facet: the top-left half lifted, which is all a gem needs.
		ci.draw_colored_polygon(PackedVector2Array([
			at + Vector2(0.0, -r), at + Vector2(r * 0.38, -r * 0.3),
			at, at + Vector2(-r * 0.38, -r * 0.3)]),
			Color(1.0, 0.98, 0.88, 0.85 * col.a))
		ci.draw_colored_polygon(PackedVector2Array([
			at + Vector2(0.0, r), at + Vector2(r * 0.44, r * 0.1),
			at + Vector2(0.0, r * 0.16)]), Color(0.75, 0.46, 0.10, 0.75 * col.a))
	else:
		var closed := d.duplicate()
		closed.append(d[0])
		ci.draw_polyline(closed, Color(UIKit.SHADOW.r, UIKit.SHADOW.g,
			UIKit.SHADOW.b, 0.45 * col.a), maxf(1.4, r * 0.33), true)
		ci.draw_polyline(closed, Color(col.r, col.g, col.b, 0.55 * col.a),
			maxf(1.0, r * 0.2), true)


## A row of them — earned out of a total. Filled versus an empty setting, never
## two colours.
static func pip_row(ci: CanvasItem, at: Vector2, filled: int, total: int,
		r: float, gap: float, alpha := 1.0) -> void:
	for i in total:
		gem(ci, at + Vector2(i * gap, 0.0), r, i < filled,
			Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, alpha) if i < filled
			else Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, alpha))
