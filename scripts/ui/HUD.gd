class_name HUD extends Control
## The in-game HUD.
##
## Drawn, not assembled from engine widgets — a StyleBox with rounded corners is
## exactly the default look the brief forbids. Everything here is polygons and
## arcs, so it carries the same hand-made quality as the rest of the game and
## costs nothing to restyle per level.
##
## It stays minimal during play: counts sit in the top-left, the HEAT gauge only
## asserts itself as it fills, and the chain row appears only once a chain exists.

const SAUCE := Color(0.86, 0.14, 0.09)
const SAUCE_HOT := Color(1.0, 0.44, 0.16)
const CREAM := Color(0.96, 0.93, 0.86)
const INK := Color(0.09, 0.08, 0.09, 0.62)
const ICE := Color(0.52, 0.88, 1.0)
const GOLD := Color(1.0, 0.80, 0.32)

@export var margin := Vector2(34.0, 26.0)

var _sriracha := 0
var _lives := 3
var _heat := 0.0
var _heat_display := 0.0
var _chains := 0
var _ice := -1
var _pop := 0.0
var _life_pop := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font

	_sriracha = Gx.sriracha
	_lives = Gx.lives
	_heat = Gx.heat_ratio()
	_heat_display = _heat
	_chains = Gx.chain_count()

	Gx.sriracha_changed.connect(_on_sriracha)
	Gx.lives_changed.connect(_on_lives)
	Gx.heat_changed.connect(_on_heat)
	Gx.chain_awarded.connect(func(_id: String, total: int) -> void: _chains = total)
	Gx.ice_sriracha_changed.connect(_on_ice)


func _on_sriracha(count: int, _delta: int) -> void:
	_sriracha = count
	_pop = 1.0


func _on_lives(lives: int) -> void:
	_lives = lives
	_life_pop = 1.0


func _on_heat(_heat_value: float) -> void:
	_heat = Gx.heat_ratio()


func _on_ice(count: int, _needed: int) -> void:
	_ice = count


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 3.4, 0.0)
	_life_pop = maxf(_life_pop - delta * 2.4, 0.0)
	_heat_display = lerpf(_heat_display, _heat, 1.0 - exp(-9.0 * delta))
	queue_redraw()


func _draw() -> void:
	var o := margin
	_draw_sriracha(o)
	_draw_lives(o + Vector2(2.0, 54.0))
	_draw_heat(o + Vector2(0.0, 92.0))
	if _chains > 0:
		_draw_chains(o + Vector2(0.0, 126.0))
	if _ice >= 0:
		_draw_ice(Vector2(size.x * 0.5, 38.0))


# --- Elements ---------------------------------------------------------------

func _draw_sriracha(at: Vector2) -> void:
	var pop := 1.0 + _pop * 0.22
	_bottle_glyph(at + Vector2(14.0, 18.0), 17.0 * pop, SAUCE)
	_number(at + Vector2(38.0, 4.0), str(_sriracha), 30.0 * pop, CREAM)


func _draw_lives(at: Vector2) -> void:
	var pop := 1.0 + _life_pop * 0.3
	for i in mini(_lives, 5):
		_sandwich_glyph(at + Vector2(12.0 + i * 28.0, 8.0), 8.0 * (pop if i == _lives - 1 else 1.0))
	if _lives > 5:
		_number(at + Vector2(12.0 + 5 * 28.0, -4.0), "x%d" % _lives, 17.0, CREAM)


## The HEAT gauge: a slot that fills, and shouts once it is full. It is the
## only element allowed to draw attention during normal play.
func _draw_heat(at: Vector2) -> void:
	var w := 116.0
	var h := 9.0
	var full := _heat_display >= 0.999
	var slot := PackedVector2Array([
		at + Vector2(6.0, 0.0), at + Vector2(w, 0.0),
		at + Vector2(w - 6.0, h), at + Vector2(0.0, h),
	])
	draw_colored_polygon(slot, INK)

	if _heat_display > 0.001:
		var fw := w * _heat_display
		var fill := PackedVector2Array([
			at + Vector2(6.0, 0.0), at + Vector2(fw, 0.0),
			at + Vector2(fw - 6.0, h), at + Vector2(0.0, h),
		])
		var c := SAUCE.lerp(SAUCE_HOT, _heat_display)
		draw_colored_polygon(fill, c)
		if full:
			# Pulse and a hot outline, so "you have a Blaze Dash" is unmissable
			# without a single word of text.
			var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.009)
			draw_polyline(_close(slot), SAUCE_HOT * Color(1, 1, 1, pulse), 2.4, true)

	draw_polyline(_close(slot), CREAM * Color(1, 1, 1, 0.30), 1.0, true)


func _draw_chains(at: Vector2) -> void:
	for i in _chains:
		_diamond_glyph(at + Vector2(10.0 + i * 17.0, 8.0), 7.0)


## Ice bonus counter, centred, because inside a bonus level it is the only
## thing that matters.
func _draw_ice(at: Vector2) -> void:
	var text := "%d / %d" % [_ice, Gx.ICE_SRIRACHA_TARGET]
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_bottle_glyph(at + Vector2(-w * 0.5 - 20.0, 14.0), 15.0, ICE)
	_number(at + Vector2(-w * 0.5, 0.0), text, 26.0, ICE.lerp(CREAM, 0.4))


# --- Glyphs -----------------------------------------------------------------

## A bottle, drawn: squat body, shoulder, neck, cap. Sixteen points and it is
## unmistakably the collectible.
func _bottle_glyph(center: Vector2, h: float, tint: Color) -> void:
	var w := h * 0.52
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.62, h * 0.50),
		center + Vector2(-w * 0.70, h * 0.10),
		center + Vector2(-w * 0.66, -h * 0.18),
		center + Vector2(-w * 0.34, -h * 0.36),
		center + Vector2(-w * 0.30, -h * 0.52),
		center + Vector2(w * 0.30, -h * 0.52),
		center + Vector2(w * 0.34, -h * 0.36),
		center + Vector2(w * 0.66, -h * 0.18),
		center + Vector2(w * 0.70, h * 0.10),
		center + Vector2(w * 0.62, h * 0.50),
	])
	draw_colored_polygon(_offset(pts, Vector2(0, 2)), INK)
	draw_colored_polygon(pts, tint)
	# Label band and cap.
	draw_rect(Rect2(center + Vector2(-w * 0.70, -h * 0.02), Vector2(w * 1.40, h * 0.22)),
		CREAM * Color(1, 1, 1, 0.88))
	draw_rect(Rect2(center + Vector2(-w * 0.32, -h * 0.66), Vector2(w * 0.64, h * 0.16)),
		tint.darkened(0.45))


func _sandwich_glyph(center: Vector2, r: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-r * 1.5, r * 0.5), center + Vector2(-r * 1.2, -r * 0.6),
		center + Vector2(0.0, -r * 0.95), center + Vector2(r * 1.2, -r * 0.6),
		center + Vector2(r * 1.5, r * 0.5), center + Vector2(0.0, r * 0.85),
	])
	draw_colored_polygon(_offset(pts, Vector2(0, 2)), INK)
	draw_colored_polygon(pts, Color(0.86, 0.66, 0.36))
	draw_line(center + Vector2(-r * 1.25, r * 0.06), center + Vector2(r * 1.25, r * 0.06),
		SAUCE, 2.0)


func _diamond_glyph(center: Vector2, r: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0.0, -r), center + Vector2(r * 0.82, -r * 0.1),
		center + Vector2(0.0, r), center + Vector2(-r * 0.82, -r * 0.1),
	])
	draw_colored_polygon(_offset(pts, Vector2(0, 2)), INK)
	draw_colored_polygon(pts, GOLD)
	draw_line(center + Vector2(-r * 0.82, -r * 0.1), center + Vector2(r * 0.82, -r * 0.1),
		Color(1, 1, 1, 0.75), 1.0)


## Numbers get a hard drop shadow rather than an outline: at gameplay speed a
## shadow separates from any background, an outline only thickens the glyph.
func _number(at: Vector2, text: String, s: float, tint: Color) -> void:
	draw_string(_font, at + Vector2(2.0, s + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(s), INK)
	draw_string(_font, at + Vector2(0.0, s), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(s), tint)


func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


func _close(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
