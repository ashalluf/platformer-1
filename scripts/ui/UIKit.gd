class_name UIKit
## Shared drawing for the game's interface.
##
## Everything is drawn. A StyleBox with rounded corners is the default engine
## look the brief forbids, and it would fight the hand-made quality of the rest
## of the game. These are the shapes the whole UI is built from: a cut-corner
## slab, a chevron, letterspaced type, rules, meters, chain pips.
##
## The language: hard-edged, slightly skewed, cut corners on the leading edge —
## painted signage and screen-printed card, not glass.
##
## Three rules hold the whole kit together:
##
## 1. NOTHING IS A THEMED CONTROL. Every pixel here comes out of `_draw`.
## 2. NOTHING IS A HARD-CODED PIXEL. Sizes are authored in a 720-tall design
##    space and multiplied by `ui_scale()`, so the same layout is correct from
##    720p to 4K. Text sizes are scaled *numerically* rather than by a canvas
##    transform, because a transformed glyph is a resampled glyph and the whole
##    point of 4K is that type is crisp.
## 3. NOTHING IS FLAT. Every slab has a shadow, a bevel and a printed tooth;
##    every rule tapers; every transition is eased. A bevel and a drop shadow
##    cost one extra draw call each and buy more perceived quality than any
##    amount of layout fiddling.

# --- Palette ----------------------------------------------------------------
# Fixed by ART_DIRECTION. Cream is paper, ink is the printing plate, sauce is
# the only saturated thing allowed on screen, gold is reward-only.

const CREAM := Color(0.96, 0.93, 0.86)
const INK := Color(0.07, 0.065, 0.075)
const SAUCE := Color(0.82, 0.13, 0.09)
const SAUCE_HOT := Color(1.0, 0.44, 0.16)
const GOLD := Color(1.0, 0.80, 0.32)
const DIM := Color(0.62, 0.60, 0.56)

## Shadow is never neutral black — the world's shadows are warm ochre-violet and
## the interface follows the same law, or the UI reads as a separate product.
const SHADOW := Color(0.035, 0.026, 0.038)


# --- Scale ------------------------------------------------------------------
# Everything in the kit and in the screens is authored against a 720-tall
# design space. `ui_scale()` is the only place resolution is allowed to enter.

const REF_H := 720.0


static func ui_scale(ci: CanvasItem) -> float:
	return maxf(ci.get_viewport_rect().size.y / REF_H, 0.35)


## Design units -> screen pixels.
static func px(ci: CanvasItem, design: float) -> float:
	return design * ui_scale(ci)


## The viewport expressed in design units: always 720 tall, width follows the
## real aspect. Lay screens out in this and they are correct at every size, and
## ultrawide gets more room rather than stretched type.
static func design_rect(ci: CanvasItem) -> Rect2:
	var v := ci.get_viewport_rect().size
	var s := ui_scale(ci)
	return Rect2(Vector2.ZERO, v / s)


# --- Type -------------------------------------------------------------------
# One hierarchy, six steps, used everywhere. The steps are far enough apart to
# read as different ranks at a glance; two sizes three pixels apart just look
# like a mistake.
#
# TRACKING RULE: letterspacing is specified in em and *shrinks as size grows*.
# Big type is already open, so a display line needs a tenth of an em; a 12px
# all-caps micro label needs a third of an em before it reads as a label rather
# than as a word. This is optical compensation, not decoration.
#
# ARABIC IS NEVER LETTERSPACED. Arabic is cursive: the glyphs are joined, and
# inserting space between them severs the joins and produces the broken
# disconnected-glyph look ART_DIRECTION rejects on sight. Arabic goes through
# `arabic()`, which hands the whole string to the TextServer in one call so
## shaping and bidi are done properly. Latin goes through `spaced()`.
#
# PAIRING RULE: Arabic leads, Latin follows. Arabic is set ~1.18x the optical
# size of the Latin line beneath it (Naskh/Kufi have a smaller apparent
# x-height than the Latin face) and sits on the line above. Latin beneath it is
# always a transliteration or translation in a lighter colour — never the same
# weight, or the two scripts fight for the same rank.

const DISPLAY := 0
const TITLE := 1
const HEAD := 2
const BODY := 3
const LABEL := 4
const MICRO := 5

## Design-space point sizes for the six ranks.
const TYPE_PX: Array = [78.0, 34.0, 26.0, 20.0, 15.0, 12.0]
## Tracking in em for each rank.
const TYPE_EM: Array = [0.10, 0.20, 0.17, 0.12, 0.24, 0.30]
## Arabic runs slightly larger than the Latin of the same rank; see PAIRING.
const ARABIC_RATIO := 1.18

static var _fonts: Dictionary = {}


static func type_size(ci: CanvasItem, kind: int) -> int:
	return int(maxf(9.0, TYPE_PX[kind] * ui_scale(ci)))


static func type_track(ci: CanvasItem, kind: int) -> float:
	return TYPE_PX[kind] * TYPE_EM[kind] * ui_scale(ci)


## The Latin face, optionally emboldened. FontVariation synthesises weight, so
## a display line can be heavier than body copy without shipping a second file.
static func latin(weight := 0.0) -> Font:
	var key := "latin:%.2f" % weight
	if not _fonts.has(key):
		if is_zero_approx(weight):
			_fonts[key] = ThemeDB.fallback_font
		else:
			var fv := FontVariation.new()
			fv.base_font = ThemeDB.fallback_font
			fv.variation_embolden = weight
			_fonts[key] = fv
	return _fonts[key]


## Naskh — official and state voice. Menu translations, signage, values.
static func naskh(bold := false) -> Font:
	return PropKit.font(PropKit.FONT_NASKH_BOLD if bold else PropKit.FONT_NASKH)


## Kufi — monumental and institutional. Titles and the logotype only.
static func kufi() -> Font:
	return PropKit.font(PropKit.FONT_KUFI)


## Arabic text. One draw_string call, no per-character loop: the TextServer
## does the shaping, the joins and the bidi, and slicing the string would undo
## all three. `box` is the layout width used for alignment (-1 = natural).
static func arabic(ci: CanvasItem, at: Vector2, text: String, size: int,
		color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, box := -1.0,
		monumental := false, shadow_alpha := 0.5) -> float:
	var f := kufi() if monumental else naskh()
	var off := maxf(1.0, size * 0.055)
	if shadow_alpha > 0.0 and color.a > 0.01:
		ci.draw_string(f, at + Vector2(off, off), text, align, box, size,
			Color(SHADOW.r, SHADOW.g, SHADOW.b, shadow_alpha * color.a))
	ci.draw_string(f, at, text, align, box, size, color)
	return f.get_string_size(text, align, box, size).x


## Letterspaced Latin with a hard offset shadow. Godot cannot letterspace a
## draw_string, and tight default spacing is most of what makes engine UI look
## like engine UI. The shadow is warm and offset rather than an outline: an
## outline only thickens the glyph, a shadow lifts it off the background.
static func spaced(ci: CanvasItem, font: Font, at: Vector2, text: String,
		size: int, color: Color, tracking := 3.0,
		align_center := false, weight := 0.0, shadow_alpha := 0.55) -> float:
	var f := font
	if not is_zero_approx(weight):
		f = latin(weight)
	var total := 0.0
	for i in text.length():
		total += f.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + tracking
	total -= tracking

	var shadow := Color(SHADOW.r, SHADOW.g, SHADOW.b, shadow_alpha * color.a)
	var off := Vector2(1.0, 1.0) * maxf(1.0, size * 0.055)
	var draw_shadow := shadow.a > 0.01

	var x := at.x - (total * 0.5 if align_center else 0.0)
	for i in text.length():
		var ch := text[i]
		if draw_shadow:
			ci.draw_string(f, Vector2(x, at.y) + off, ch, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size, shadow)
		ci.draw_string(f, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + tracking
	return total


## Measure a letterspaced run without drawing it — for right-aligned columns.
static func spaced_width(font: Font, text: String, size: int, tracking: float) -> float:
	var total := 0.0
	for i in text.length():
		total += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + tracking
	return maxf(0.0, total - tracking)


## The one-liner for a ranked Latin line: picks size and tracking from the
## hierarchy so a caller never invents its own.
static func text(ci: CanvasItem, at: Vector2, body: String, kind: int,
		color: Color, center := false, weight := 0.0) -> float:
	return spaced(ci, latin(weight), at, body, type_size(ci, kind), color,
		type_track(ci, kind), center, 0.0)


## Text with a hard offset shadow, unspaced. Kept for callers that need the
## font's own metrics (numerals in a column, mostly).
static func shadowed(ci: CanvasItem, font: Font, at: Vector2, text: String,
		size: int, color: Color, shadow := Color(0, 0, 0, 0.6),
		offset := Vector2(2.0, 3.0), center := false) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5 if center else 0.0, 0.0)
	ci.draw_string(font, p + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(shadow.r, shadow.g, shadow.b, shadow.a * color.a))
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# --- Generated material -----------------------------------------------------
# Two tiles, built once at first use, never shipped as files. One is the tooth
# of the printed card the slabs are cut from; the other is screen grain. Both
# are deterministic (fixed seed) so captures are reproducible.

static var _print_tex: Texture2D = null
static var _grain_tex: Texture2D = null
static var _vig_tex: Texture2D = null

const PRINT_TILE := 96.0


## Mottled ink tooth: a coarse blotch layer for the uneven pull of a squeegee,
## plus fine speckle for paper grain. Mostly transparent — it is a tint, not a
## texture map.
static func print_texture() -> Texture2D:
	if _print_tex != null:
		return _print_tex
	var n := 96
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1B7A
	# Coarse lattice, bilinearly sampled, gives the blotch.
	var c := 12
	var lat := PackedFloat32Array()
	lat.resize(c * c)
	for i in c * c:
		lat[i] = rng.randf()
	# Filled as raw bytes rather than set_pixel: this runs on the first frame a
	# menu is drawn, and 9k scripted set_pixel calls is a visible hitch.
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var k := 0
	for y in n:
		for x in n:
			var fx := float(x) / n * c
			var fy := float(y) / n * c
			var x0 := int(fx)
			var y0 := int(fy)
			var tx := smoothstep(0.0, 1.0, fx - x0)
			var ty := smoothstep(0.0, 1.0, fy - y0)
			var a00: float = lat[(y0 % c) * c + (x0 % c)]
			var a10: float = lat[(y0 % c) * c + ((x0 + 1) % c)]
			var a01: float = lat[((y0 + 1) % c) * c + (x0 % c)]
			var a11: float = lat[((y0 + 1) % c) * c + ((x0 + 1) % c)]
			var blotch: float = lerpf(lerpf(a00, a10, tx), lerpf(a01, a11, tx), ty)
			# A faint horizontal drag, so the tooth has a direction.
			var drag := 0.5 + 0.5 * sin(float(y) * 0.42 + blotch * 3.0)
			var v: float = blotch * 0.62 + rng.randf() * 0.24 + drag * 0.14
			var d: float = (v - 0.5) * 2.0
			var col := CREAM if d > 0.0 else SHADOW
			data[k] = int(col.r * 255.0)
			data[k + 1] = int(col.g * 255.0)
			data[k + 2] = int(col.b * 255.0)
			data[k + 3] = int(clampf(pow(absf(d), 1.7) * 0.42, 0.0, 1.0) * 255.0)
			k += 4
	_print_tex = ImageTexture.create_from_image(
		Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))
	return _print_tex


## Fine screen grain. Higher contrast and per-pixel, so it survives on top of a
## smooth gradient — which is the whole reason it exists.
static func grain_texture() -> Texture2D:
	if _grain_tex != null:
		return _grain_tex
	var n := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51CE
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var k := 0
	for i in n * n:
		var d := rng.randf() - 0.5
		var col := CREAM if d > 0.0 else SHADOW
		data[k] = int(col.r * 255.0)
		data[k + 1] = int(col.g * 255.0)
		data[k + 2] = int(col.b * 255.0)
		data[k + 3] = int(clampf(pow(absf(d) * 2.0, 2.0), 0.0, 1.0) * 255.0)
		k += 4
	_grain_tex = ImageTexture.create_from_image(
		Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))
	return _grain_tex


static func _vignette_texture() -> Texture2D:
	if _vig_tex != null:
		return _vig_tex
	# 96 is plenty: it is a smooth radial ramp and it is drawn stretched over
	# the whole frame, so the bilinear filter does the rest.
	var n := 96
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var k := 0
	for y in n:
		for x in n:
			var u := Vector2(float(x) / (n - 1), float(y) / (n - 1)) * 2.0 - Vector2.ONE
			var r: float = clampf(u.length() / 1.414, 0.0, 1.0)
			data[k] = 255
			data[k + 1] = 255
			data[k + 2] = 255
			data[k + 3] = int(pow(r, 2.3) * 255.0)
			k += 4
	_vig_tex = ImageTexture.create_from_image(
		Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))
	return _vig_tex


## draw_polygon with UVs > 1 needs repeat turned on for the whole CanvasItem.
## Guarded, because the setter queues a redraw and these screens redraw every
## frame anyway — it flips once on the first draw and never again.
static func _ensure_repeat(ci: CanvasItem) -> void:
	if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


# --- Slabs ------------------------------------------------------------------

## A slab with its leading corners cut. `skew` shears the top edge right.
##
## Five passes, in the order a printer would lay them down: a warm drop shadow,
## the ink body with a vertical value gradient, the printed tooth, a lit top and
## leading edge, a shaded bottom edge. The shadow and the bevel are what stop
## this reading as a translucent rectangle.
## `elevation` lifts the slab off the page: it scales the drop distance and the
## shadow's weight, so a focused row can physically rise without changing shape.
static func slab(ci: CanvasItem, rect: Rect2, fill: Color, cut := 14.0,
		skew := 8.0, elevation := 1.0) -> PackedVector2Array:
	var p := PackedVector2Array([
		rect.position + Vector2(cut + skew, 0.0),
		rect.position + Vector2(rect.size.x + skew, 0.0),
		rect.position + Vector2(rect.size.x, rect.size.y),
		rect.position + Vector2(cut, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - cut),
		rect.position + Vector2(skew, cut),
	])
	var s := ui_scale(ci)
	var solidity: float = clampf(fill.a * 1.25, 0.0, 1.0)

	# 1. Shadow. Offset down-right, matching the UI's single light from top-left.
	if solidity > 0.05:
		var drop := Vector2(3.0, 5.0) * s * elevation
		var shadow_pts := PackedVector2Array()
		for v in p:
			shadow_pts.append(v + drop)
		ci.draw_colored_polygon(shadow_pts,
			Color(SHADOW.r, SHADOW.g, SHADOW.b,
				clampf(0.42 * solidity * (0.75 + 0.25 * elevation), 0.0, 0.8)))

	# 2. Body, with a top-lit vertical gradient across the six vertices.
	var cols := PackedColorArray()
	for v in p:
		var t: float = clampf((v.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
		cols.append(fill.lerp(Color(fill.r, fill.g, fill.b, fill.a) * Color(1.34, 1.30, 1.30, 1.0), 1.0 - t)
			.lerp(fill * Color(0.72, 0.70, 0.74, 1.0), t * 0.55))
	ci.draw_polygon(p, cols)

	# 3. Printed tooth, at a constant physical scale so a big panel is not a
	#    blown-up version of a small chip.
	if solidity > 0.25:
		_ensure_repeat(ci)
		var tile := PRINT_TILE * s
		var uvs := PackedVector2Array()
		for v in p:
			uvs.append((v - rect.position) / tile)
		var tint := Color(1, 1, 1, 0.55 * solidity)
		var tcols := PackedColorArray()
		for _i in p.size():
			tcols.append(tint)
		ci.draw_polygon(p, tcols, uvs, print_texture())

	# 4. Lit edge: the top run and the cut, which is the face that catches light.
	var lw := maxf(1.0, 1.4 * s)
	var lit := Color(CREAM.r, CREAM.g, CREAM.b, 0.20 * solidity)
	ci.draw_polyline(PackedVector2Array([p[4], p[5], p[0], p[1]]), lit, lw, true)
	ci.draw_line(p[4], p[5], Color(CREAM.r, CREAM.g, CREAM.b, 0.34 * solidity),
		lw * 1.4, true)
	# 5. Shaded bottom, one pixel of thickness.
	ci.draw_polyline(PackedVector2Array([p[1], p[2], p[3], p[4]]),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.45 * solidity), lw, true)
	return p


static func slab_outline(ci: CanvasItem, pts: PackedVector2Array, color: Color,
		width := 2.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	# A dark line under the bright one: the outline then has a thickness and an
	# edge instead of reading as a sticker cut from the background.
	ci.draw_polyline(closed, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.5 * color.a),
		width * 2.0, true)
	ci.draw_polyline(closed, color, width, true)
	ci.draw_polyline(closed, Color(1, 1, 1, 0.22 * color.a), width * 0.4, true)


## Clip a polygon to a rect. Used for fill sweeps and hatching, so a highlight
## can run inside a cut-corner shape without leaking past the cut.
static func clip_polygon(pts: PackedVector2Array, box: Rect2) -> Array[PackedVector2Array]:
	var b := PackedVector2Array([
		box.position, box.position + Vector2(box.size.x, 0.0),
		box.position + box.size, box.position + Vector2(0.0, box.size.y)])
	return Geometry2D.intersect_polygons(pts, b)


## The selection fill: colour wipes in from the leading edge and eases to a
## stop. `amount` is 0..1 of the slab's width.
static func sweep_fill(ci: CanvasItem, pts: PackedVector2Array, amount: float,
		color: Color) -> void:
	if amount <= 0.001:
		return
	var box := _bounds(pts)
	var w: float = box.size.x * clampf(amount, 0.0, 1.0)
	for piece in clip_polygon(pts, Rect2(box.position - Vector2(2, 2),
			Vector2(w + 2.0, box.size.y + 4.0))):
		var cols := PackedColorArray()
		for v in piece:
			# Densest at the leading edge, thinning as it runs out — a wipe,
			# not a block of colour.
			var t: float = clampf((v.x - box.position.x) / maxf(w, 1.0), 0.0, 1.0)
			cols.append(Color(color.r, color.g, color.b,
				color.a * (1.0 - t * 0.72)))
		ci.draw_polygon(piece, cols)


## Diagonal hatch, clipped to the slab. This is how a disabled row says it is
## disabled: struck through on purpose, not merely faded out and ambiguous.
static func hatch(ci: CanvasItem, pts: PackedVector2Array, color: Color,
		step := 11.0, width := 1.5) -> void:
	var box := _bounds(pts)
	var x := box.position.x - box.size.y
	while x < box.position.x + box.size.x:
		var quad := PackedVector2Array([
			Vector2(x, box.position.y + box.size.y),
			Vector2(x + box.size.y, box.position.y),
			Vector2(x + box.size.y + width, box.position.y),
			Vector2(x + width, box.position.y + box.size.y)])
		for piece in Geometry2D.intersect_polygons(pts, quad):
			ci.draw_colored_polygon(piece, color)
		x += step


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for v in pts:
		r = r.expand(v)
	return r


# --- Marks ------------------------------------------------------------------

## The selection marker: a solid chevron pointing at the active row, with a
## ghost behind it so a fast move reads as motion rather than as a teleport.
static func chevron(ci: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var shape := func(o: Vector2, k: float) -> PackedVector2Array:
		return PackedVector2Array([
			o + Vector2(0.0, -size * k),
			o + Vector2(size * 1.15 * k, 0.0),
			o + Vector2(0.0, size * k),
			o + Vector2(size * 0.35 * k, 0.0),
		])
	ci.draw_colored_polygon(shape.call(at + Vector2(size * 0.22, size * 0.28), 1.0),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.5 * color.a))
	ci.draw_colored_polygon(shape.call(at - Vector2(size * 0.55, 0.0), 0.86),
		Color(color.r, color.g, color.b, 0.28 * color.a))
	ci.draw_colored_polygon(shape.call(at, 1.0), color)
	# A hot inner spark, so the mark has a light source of its own.
	ci.draw_colored_polygon(shape.call(at + Vector2(size * 0.12, 0.0), 0.42),
		Color(1.0, 0.92, 0.78, 0.85 * color.a))


## A tapered rule. Hard-ended lines look like a debug gizmo; a rule that fades
## at both ends looks drawn.
static func rule(ci: CanvasItem, from: Vector2, to: Vector2, color: Color,
		width := 2.0) -> void:
	var dir := (to - from)
	var n := Vector2(-dir.y, dir.x).normalized() * width * 0.5
	var fade := Color(color.r, color.g, color.b, 0.0)
	# Solid middle, transparent ends: three bands.
	var a := from.lerp(to, 0.12)
	var b := from.lerp(to, 0.88)
	ci.draw_polygon(PackedVector2Array([from + n, a + n, a - n, from - n]),
		PackedColorArray([fade, color, color, fade]))
	ci.draw_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]),
		PackedColorArray([color, color, color, color]))
	ci.draw_polygon(PackedVector2Array([b + n, to + n, to - n, b - n]),
		PackedColorArray([color, fade, fade, color]))
	# A dark hairline under it, for the same reason slabs have shadows.
	var d := Vector2(0.0, width * 0.85)
	ci.draw_line(a + d, b + d, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.35 * color.a),
		width * 0.5, true)


## A row of diamond pips — chains earned out of a total. Earned pips are cut
## gems: a facet highlight and a halo. Unearned ones are an empty setting.
static func pips(ci: CanvasItem, at: Vector2, filled: int, total: int,
		r := 8.0, gap := 22.0) -> void:
	for i in total:
		var c := at + Vector2(i * gap, 0.0)
		var d := PackedVector2Array([
			c + Vector2(0.0, -r), c + Vector2(r * 0.8, 0.0),
			c + Vector2(0.0, r), c + Vector2(-r * 0.8, 0.0),
		])
		if i < filled:
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -r * 1.5), c + Vector2(r * 1.2, 0.0),
				c + Vector2(0.0, r * 1.5), c + Vector2(-r * 1.2, 0.0)]),
				Color(GOLD.r, GOLD.g, GOLD.b, 0.16))
			ci.draw_colored_polygon(d, GOLD)
			# Table facet: the top-left half lifted, which is all a gem needs.
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -r), c + Vector2(r * 0.38, -r * 0.3),
				c + Vector2(0.0, 0.0), c + Vector2(-r * 0.38, -r * 0.3)]),
				Color(1.0, 0.98, 0.88, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, r), c + Vector2(r * 0.44, r * 0.1),
				c + Vector2(0.0, r * 0.16)]), Color(0.75, 0.46, 0.10, 0.75))
		else:
			var closed := d.duplicate()
			closed.append(d[0])
			ci.draw_polyline(closed, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.45),
				2.6, true)
			ci.draw_polyline(closed, DIM * Color(1, 1, 1, 0.55), 1.6, true)


# --- Instruments ------------------------------------------------------------

## A value meter that reads as an instrument, not a progress bar: an engraved
## groove, a tick scale it is measured against, a filled span and a machined
## head that sits at the value. The ticks are the difference — a bar without a
## scale is a loading screen.
static func meter(ci: CanvasItem, rect: Rect2, value: float, accent: Color,
		active := false, ticks := 10) -> void:
	var v: float = clampf(value, 0.0, 1.0)
	var mid := rect.position.y + rect.size.y * 0.5
	var s := maxf(rect.size.y / 14.0, 0.5)

	# Groove: dark channel with a lit bottom lip, so it reads as cut in.
	ci.draw_line(Vector2(rect.position.x, mid),
		Vector2(rect.position.x + rect.size.x, mid),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.75), rect.size.y * 0.34, true)
	ci.draw_line(Vector2(rect.position.x, mid + rect.size.y * 0.2),
		Vector2(rect.position.x + rect.size.x, mid + rect.size.y * 0.2),
		Color(CREAM.r, CREAM.g, CREAM.b, 0.10), maxf(1.0, s), true)

	# Scale.
	for i in ticks + 1:
		var t := float(i) / ticks
		var x := rect.position.x + rect.size.x * t
		var major := i == 0 or i == ticks or i * 2 == ticks
		var h := rect.size.y * (0.62 if major else 0.34)
		var lit := t <= v + 0.001
		var col := accent if lit and active else (
			Color(CREAM.r, CREAM.g, CREAM.b, 0.34) if lit
			else Color(CREAM.r, CREAM.g, CREAM.b, 0.16))
		ci.draw_line(Vector2(x, mid - h * 0.5), Vector2(x, mid + h * 0.5),
			col, maxf(1.0, s * (1.3 if major else 0.8)), true)

	# The filled span, brighter towards the head.
	if v > 0.001:
		var w := rect.size.x * v
		var top := mid - rect.size.y * 0.16
		var bot := mid + rect.size.y * 0.16
		var cold := Color(accent.r, accent.g, accent.b, 0.55)
		var hot := Color(accent.r, accent.g, accent.b, 1.0) if active else Color(
			accent.r * 0.85, accent.g * 0.85, accent.b * 0.85, 0.85)
		ci.draw_polygon(PackedVector2Array([
				Vector2(rect.position.x, top), Vector2(rect.position.x + w, top),
				Vector2(rect.position.x + w, bot), Vector2(rect.position.x, bot)]),
			PackedColorArray([cold, hot, hot, cold]))

	# Head: a machined wedge that owns the value.
	var hx := rect.position.x + rect.size.x * v
	var hh := rect.size.y * (0.92 if active else 0.74)
	var head := PackedVector2Array([
		Vector2(hx - s * 2.2, mid - hh * 0.5), Vector2(hx + s * 2.2, mid - hh * 0.5),
		Vector2(hx + s * 3.4, mid), Vector2(hx + s * 2.2, mid + hh * 0.5),
		Vector2(hx - s * 2.2, mid + hh * 0.5), Vector2(hx - s * 3.4, mid)])
	var shadow_head := PackedVector2Array()
	for p in head:
		shadow_head.append(p + Vector2(s, s * 1.6))
	ci.draw_colored_polygon(shadow_head, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.5))
	ci.draw_colored_polygon(head, accent if active else CREAM.lerp(accent, 0.35))
	ci.draw_line(Vector2(hx, mid - hh * 0.36), Vector2(hx, mid + hh * 0.36),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.55), maxf(1.0, s), true)


# --- Blocks -----------------------------------------------------------------

## The standard title block: Arabic first in Kufi, Latin transliteration under
## it, a rule to close. Every screen in the game opens with this, which is most
## of what makes six screens look like one product.
## Returns the block's height in pixels so the caller can lay out beneath it.
static func title_block(ci: CanvasItem, at: Vector2, ar: String, en: String,
		accent := SAUCE_HOT, rule_width := 0.0, center := false,
		rank := TITLE) -> float:
	var s := ui_scale(ci)
	var ar_size := int(type_size(ci, rank) * ARABIC_RATIO)
	var f := kufi()
	var ar_w := f.get_string_size(ar, HORIZONTAL_ALIGNMENT_LEFT, -1, ar_size).x
	var ar_at := Vector2(at.x - (ar_w * 0.5 if center else 0.0), at.y)
	# The accent's alpha drives the whole block, so a screen can fade its title
	# in with one number instead of threading opacity through four calls.
	var a := accent.a
	# A warm offset behind the Arabic does the work of a bevel at title size.
	ci.draw_string(f, ar_at + Vector2(1.0, 1.0) * maxf(2.0, ar_size * 0.055), ar,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ar_size, Color(0.42, 0.07, 0.03, 0.85 * a))
	ci.draw_string(f, ar_at, ar, HORIZONTAL_ALIGNMENT_LEFT, -1, ar_size,
		Color(CREAM.r, CREAM.g, CREAM.b, a))

	var lat_y := at.y + ar_size * 0.86
	var sub_rank: int = mini(rank + 2, MICRO)
	spaced(ci, latin(0.25), Vector2(at.x, lat_y), en, type_size(ci, sub_rank),
		accent, type_track(ci, sub_rank), center)

	var ry := lat_y + 14.0 * s
	var w := rule_width if rule_width > 0.0 else maxf(ar_w, 220.0 * s)
	if center:
		rule(ci, Vector2(at.x - w * 0.5, ry), Vector2(at.x + w * 0.5, ry),
			Color(accent.r, accent.g, accent.b, 0.55 * a), 2.0 * s)
	else:
		rule(ci, Vector2(at.x, ry), Vector2(at.x + w, ry),
			Color(accent.r, accent.g, accent.b, 0.55 * a), 2.0 * s)
	return (ry + 8.0 * s) - at.y


## A key cap: a small cut-corner slab with the key on it. Returns its width, so
## a caller can lay a row of them out without measuring twice.
static func keycap(ci: CanvasItem, at: Vector2, key: String, h: float,
		tint := CREAM) -> float:
	var f := latin(0.2)
	var size := int(h * 0.52)
	var tw := spaced_width(f, key, size, h * 0.08)
	var w := maxf(h * 0.92, tw + h * 0.52)
	var box := Rect2(at, Vector2(w, h))
	var pts := slab(ci, box, Color(INK.r, INK.g, INK.b, 0.72), h * 0.26, h * 0.12)
	slab_outline(ci, pts, Color(tint.r, tint.g, tint.b, 0.35), maxf(1.0, h * 0.04))
	spaced(ci, f, Vector2(at.x + w * 0.5 + h * 0.06, at.y + h * 0.7), key, size,
		Color(tint.r, tint.g, tint.b, 0.92), h * 0.08, true)
	return w


## A footer of contextual hints: [[key, label], ...]. This is where a premium
## UI puts its instructions — never as a sentence floating in the middle of the
## screen. Returns the total width drawn.
static func hints(ci: CanvasItem, at: Vector2, items: Array, h := 0.0,
		center := false, alpha := 1.0) -> float:
	var s := ui_scale(ci)
	var cap_h := h if h > 0.0 else 22.0 * s
	var f := latin(0.0)
	# Keys are measured in the same face keycap() draws them in, or a centred
	# hint row drifts off centre by a few pixels per cap.
	var kf := latin(0.2)
	var lab_size := type_size(ci, MICRO)
	var track := type_track(ci, MICRO)
	var gap := cap_h * 0.5
	var pad := cap_h * 1.15

	var total := 0.0
	for item: Array in items:
		var key: String = item[0]
		var label_text: String = item[1]
		total += maxf(cap_h * 0.92,
			spaced_width(kf, key, int(cap_h * 0.52), cap_h * 0.08) + cap_h * 0.52)
		total += gap + spaced_width(f, label_text, lab_size, track) + pad
	total -= pad

	var x := at.x - (total * 0.5 if center else 0.0)
	for item: Array in items:
		var key: String = item[0]
		var label_text: String = item[1]
		x += keycap(ci, Vector2(x, at.y), key, cap_h,
			Color(CREAM.r, CREAM.g, CREAM.b, alpha))
		x += gap
		spaced(ci, f, Vector2(x, at.y + cap_h * 0.72), label_text, lab_size,
			Color(DIM.r, DIM.g, DIM.b, alpha), track)
		x += spaced_width(f, label_text, lab_size, track) + pad
	return total


# --- Overlays ---------------------------------------------------------------

## The atmosphere pass every screen drops on last: a dim, a vignette and grain,
## in that order. UI must never sit on a clean gradient — a clean gradient is
## the single loudest tell that something was assembled rather than printed.
## `t` advances the grain in steps so it shimmers like film rather than crawling.
static func overlay(ci: CanvasItem, rect: Rect2, dim := 0.0, vignette_amount := 0.45,
		grain_amount := 0.05, t := 0.0, tint := SHADOW) -> void:
	if dim > 0.001:
		ci.draw_rect(rect, Color(tint.r, tint.g, tint.b, dim))
	if vignette_amount > 0.001:
		ci.draw_texture_rect(_vignette_texture(), rect, false,
			Color(tint.r, tint.g, tint.b, vignette_amount))
	if grain_amount > 0.001:
		_ensure_repeat(ci)
		# 12 steps a second: fast enough to live, slow enough not to buzz.
		var step := floor(t * 12.0)
		var jitter := Vector2(fmod(step * 37.0, 128.0), fmod(step * 61.0, 128.0))
		var g := grain_texture()
		var tile := Rect2(rect.position - jitter, rect.size + jitter)
		ci.draw_texture_rect(g, tile, true, Color(1, 1, 1, grain_amount))


## A directional scrim: a soft wedge of shade a screen can lay under its type
## without turning into a panel.
static func scrim(ci: CanvasItem, rect: Rect2, near: Color, far: Color,
		horizontal := true) -> void:
	var p := PackedVector2Array([
		rect.position, rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size, rect.position + Vector2(0.0, rect.size.y)])
	var c := PackedColorArray([near, far, far, near]) if horizontal \
		else PackedColorArray([near, near, far, far])
	ci.draw_polygon(p, c)


# --- Easing -----------------------------------------------------------------
# Nothing in this interface moves linearly. Linear motion is the other half of
# why default UI feels cheap; these are the four curves the screens use.

static func out_cubic(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func out_quint(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 5.0)


## Overshoot and settle. This is the chevron's curve: it arrives past the mark
## and comes back, which is what makes a selection feel physical.
static func out_back(t: float, overshoot := 1.9) -> float:
	var x: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (overshoot + 1.0) * pow(x, 3.0) + overshoot * pow(x, 2.0)


## Framerate-independent exponential smoothing. `speed` is roughly "how many
## e-folds a second", so 18 is snappy and 6 is a drift.
static func damp(current: float, target: float, speed: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))
