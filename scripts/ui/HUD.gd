class_name HUD extends Control
## The in-game HUD: one composed corner plate, drawn.
##
## Nothing here is a themed Control. Every pixel comes out of `_draw`, built
## from the house shapes in UIKit — the cut-corner skewed slab, the instrument
## meter, letterspaced micro type, chevrons, a tapered rule and chain pips — so
## the HUD is visibly the same product as the pause card and the map.
##
## HIERARCHY, because a HUD that weights everything the same reads as a debug
## overlay:
##   1. SRIRACHA — the primary read. Title-rank numerals, fixed advance, counts
##      up, kicks and flashes on pickup.
##   2. LIVES — half that size. Sandwiches animate into and out of five slots;
##      empty slots stay on as outlines so "how many did I lose" is a shape.
##   3. HEAT — the UIKit instrument meter: engraved groove, tick scale, fill,
##      machined head. It only raises its voice when it is full, which is the
##      one moment it has something to say.
##   4. CHAINS — five pips, unfilled until earned. Quiet, and permanent.
##
## READABILITY OVER ANY BACKGROUND — the actual hard problem, since Brega runs
## from near-black cell block to blown-out dawn haze inside a single level and
## no single trick survives both. Four layers, deliberately failing in opposite
## directions:
##   1. UIKit.slab's warm drop shadow and top-lit body gradient: on a bright
##      frame the plate is the dark ground the light type needs.
##   2. A cream hairline on the plate silhouette plus the sauce accent down the
##      cut edge: against near-black the plate still has an edge, where a dark
##      scrim alone would simply disappear.
##   3. A hard warm offset shadow under every numeral and glyph, so type still
##      reads where it overhangs the transparent bottom of the plate.
##   4. The body is translucent and bottom-fading rather than a solid box —
##      an opaque panel would read as a sticker pasted over the game, and the
##      point of the shadow-plus-hairline pair is that it does not need to be
##      opaque to stay legible.
## Scrim alone was tried in the previous version and it reads as a black box on
## the dawn frames; an outline alone shimmers at gameplay speed. All four are
## cheap; together they are background-independent.
##
## Every dimension below is a 720p design unit multiplied by UIKit.ui_scale(),
## which is derived from the viewport. Nothing here is a screen pixel.
##
## The ICE bonus counter deliberately lives in IceHUD, not here: IceBonusStage
## sets `show_hud = false`, so this HUD does not exist during an ice run, and a
## second ice readout in this file would be dead weight pretending to be a
## feature.

const BREAD := Color(0.90, 0.73, 0.45)
const BREAD_DARK := Color(0.70, 0.50, 0.28)
const TUNA := Color(0.86, 0.46, 0.34)
const HEAT_HOT := Color(1.0, 0.62, 0.20)
const HEAT_FLARE := Color(1.0, 0.93, 0.76)

## Layout, in 720p design units. Read every number below as "pixels at 720p".
const PLATE := Vector2(250.0, 148.0)
const LIFE_SLOTS := 5
const CHAIN_TOTAL := 5
const LIFE_STEP := 26.0
const PIP_GAP := 16.0

@export var margin := Vector2(28.0, 22.0)

var _sriracha := 0
var _shown := 0.0
var _gain := 0
var _gain_life := 0.0
var _pop := 0.0

var _lives := 3
var _slot := PackedFloat32Array()
var _slot_pop := PackedFloat32Array()
var _lost_slot := -1
var _lost_flash := 0.0

var _heat := 0.0
var _heat_display := 0.0
var _ghost := 0.0
var _ghost_life := 0.0
var _full_flash := 0.0

var _chains := 0
var _chain_flash := 0.0

var _jolt := 0.0
var _t := 0.0
var _in := 0.0
var _cells := {}

var _preview := false
var _pv_t := 0.0
var _pv_next := 0.0
var _pv_spend := -9.0
var _pv_bunch := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot.resize(LIFE_SLOTS)
	_slot_pop.resize(LIFE_SLOTS)

	_preview = OS.get_cmdline_user_args().has("--hud-preview")
	if _preview:
		_preview_seed()
		return

	_sriracha = Gx.sriracha
	_shown = float(_sriracha)
	_lives = Gx.lives
	_heat = Gx.heat_ratio()
	_heat_display = _heat
	_chains = Gx.chain_count()
	for i in LIFE_SLOTS:
		_slot[i] = 1.0 if i < _lives else 0.0

	Gx.sriracha_changed.connect(_on_sriracha)
	Gx.lives_changed.connect(_on_lives)
	Gx.heat_changed.connect(_on_heat)
	Gx.heat_full.connect(_on_heat_full)
	Gx.chain_awarded.connect(_on_chain)


# --- State ------------------------------------------------------------------

func _on_sriracha(count: int, delta: int) -> void:
	_sriracha = count
	_pop = 1.0
	# The floating "+N" is reserved for a cluster or a bonus. A player picks up
	# single bottles constantly; a +1 flying off the counter every third of a
	# second is noise, and noise is what makes a HUD feel cheap.
	if delta > 1:
		_gain = delta
		_gain_life = 1.0


func _on_lives(lives: int) -> void:
	if lives < _lives:
		# Remember which slot emptied, so it flashes and shrinks out instead of
		# blinking off. A life is expensive; losing one should be seen.
		_lost_slot = clampi(lives, 0, LIFE_SLOTS - 1)
		_lost_flash = 1.0
		_jolt = maxf(_jolt, 0.55)
	elif lives > _lives:
		_slot_pop[clampi(lives - 1, 0, LIFE_SLOTS - 1)] = 1.0
	_lives = lives


func _on_heat(_value: float) -> void:
	_set_heat(Gx.heat_ratio())


func _on_heat_full() -> void:
	_full_flash = 1.0


func _on_chain(_level_id: String, total: int) -> void:
	_chains = total
	_chain_flash = 1.0
	_jolt = maxf(_jolt, 1.0)


## A drop bigger than a single bottle's worth means the Heat Dash was spent, and
## spending has to be visible or the gauge looks like it emptied itself.
func _set_heat(ratio: float) -> void:
	if ratio < _heat - 0.02:
		_ghost = maxf(_heat_display, ratio)
		_ghost_life = 1.0
		_jolt = maxf(_jolt, 0.5)
	if ratio >= 0.999 and _heat < 0.999:
		_full_flash = 1.0
	_heat = clampf(ratio, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _preview:
		_preview_step(delta)

	# Counters ease rather than snap, but a long climb must not crawl: the rate
	# scales with the distance left, so +1 is a tick and +50 is a run that still
	# lands inside half a second.
	var target := float(_sriracha)
	if absf(target - _shown) < 0.51:
		_shown = target
	else:
		_shown = move_toward(_shown, target,
			maxf(absf(target - _shown) * 9.0, 14.0) * delta)

	_pop = maxf(_pop - delta * 3.2, 0.0)
	_gain_life = maxf(_gain_life - delta * 1.3, 0.0)
	_lost_flash = maxf(_lost_flash - delta * 1.7, 0.0)
	_full_flash = maxf(_full_flash - delta * 1.5, 0.0)
	_chain_flash = maxf(_chain_flash - delta * 0.5, 0.0)
	_ghost_life = maxf(_ghost_life - delta * 1.5, 0.0)
	_jolt = maxf(_jolt - delta * 2.6, 0.0)
	_heat_display = UIKit.damp(_heat_display, _heat, 10.0, delta)
	_in = minf(_in + delta * 1.9, 1.0)
	# The plate arrives rather than appearing. modulate is a CanvasItem property,
	# not a theme, so the fade costs nothing and touches no drawing code.
	modulate.a = UIKit.out_cubic(_in)

	for i in LIFE_SLOTS:
		_slot[i] = move_toward(_slot[i], 1.0 if i < _lives else 0.0, delta * 5.0)
		_slot_pop[i] = maxf(_slot_pop[i] - delta * 2.4, 0.0)

	queue_redraw()


# --- Draw -------------------------------------------------------------------

func _draw() -> void:
	var s := UIKit.ui_scale(self)

	# HUD jolt is motion, so it obeys the screen-shake slider exactly as the
	# camera does. Scale pops, flashes and colour shifts are not shake and stay
	# on at zero — they are the state feedback itself, and switching them off
	# would cost information rather than comfort.
	var shake := clampf(float(Gx.get_setting("screen_shake", 1.0)), 0.0, 1.0)
	var jolt := Vector2(sin(_t * 47.0), cos(_t * 39.0)) * (_jolt * _jolt * 4.0 * s * shake)
	# Slides in along its own cut edge on level entry — the same diagonal the
	# slab is built on, so the entrance is part of the shape language.
	var entry := Vector2(-1.0, -0.35) * (1.0 - UIKit.out_quint(_in)) * 40.0 * s
	var p := (margin * s).round() + jolt + entry

	_draw_plate(p, s)
	_draw_count(p, s)
	_draw_lives(p, s)
	_draw_chains(p, s)
	_draw_heat(p, s)
	_draw_caption(p, s)


func _draw_plate(p: Vector2, s: float) -> void:
	var rect := Rect2(p, PLATE * s)
	var cut := 18.0 * s
	var skew := 9.0 * s
	# UIKit.slab already lays down the warm shadow, the top-lit gradient, the
	# printed tooth and the bevels — layers 1 and 4 of the readability stack.
	var pts := UIKit.slab(self, rect,
		Color(UIKit.INK.r, UIKit.INK.g, UIKit.INK.b, 0.60), cut, skew)

	var edge := UIKit.CREAM * Color(1, 1, 1, 0.22)
	if _chain_flash > 0.0:
		edge = UIKit.GOLD * Color(1, 1, 1, 0.22 + _chain_flash * 0.65)
	UIKit.slab_outline(self, pts, edge, 1.3 * s)

	# The sauce accent down the cut edge is the plate's only colour at rest, and
	# it is what makes the shape read as this game's furniture and not a panel.
	var accent := UIKit.SAUCE.lerp(UIKit.GOLD, _chain_flash)
	draw_line(pts[4], pts[5], accent, 3.2 * s, true)
	draw_line(pts[4], pts[5], HEAT_FLARE * Color(1, 1, 1, 0.25), 1.1 * s, true)

	if _chain_flash > 0.0:
		_sweep(pts, _chain_flash)


## A gold band crossing the plate. The chain is the rarest thing in the game;
## the HUD should behave as though it noticed. Clipped to the slab so it stops
## at the cut corners instead of leaking into the level.
func _sweep(pts: PackedVector2Array, k: float) -> void:
	var box := Rect2(pts[4], Vector2.ZERO)
	for v in pts:
		box = box.expand(v)
	var head := box.position.x - box.size.y + box.size.x * (1.35 - k) * 1.1
	for i in 3:
		var w := box.size.x * (0.13 - i * 0.035)
		var band := PackedVector2Array([
			Vector2(head + i * 5.0, box.position.y),
			Vector2(head + i * 5.0 + w, box.position.y),
			Vector2(head + i * 5.0 + w - box.size.y, box.end.y),
			Vector2(head + i * 5.0 - box.size.y, box.end.y)])
		for piece in Geometry2D.intersect_polygons(band, pts):
			draw_colored_polygon(piece, UIKit.GOLD * Color(1, 1, 1, k * k * (0.08 + i * 0.05)))


func _draw_count(p: Vector2, s: float) -> void:
	_bottle(p + Vector2(42.0, 42.0) * s, 44.0 * s * (1.0 + _pop * _pop * 0.14),
		UIKit.SAUCE)

	# Type is scaled numerically, never by a canvas transform: a transformed
	# glyph is a resampled glyph, and at 4K that is the whole point of 4K.
	var base := UIKit.type_size(self, UIKit.TITLE)
	var size := int(base * (1.0 + _pop * _pop * 0.26))
	var track := UIKit.type_track(self, UIKit.TITLE) * 0.55
	var tint := UIKit.CREAM.lerp(Color(1.0, 0.99, 0.94), _pop)
	var baseline := p + Vector2(72.0, 57.0) * s + Vector2(0.0, (base - size) * 0.5)
	var w := _digits(baseline, "%d" % int(round(_shown)), size, track, tint)

	if _gain_life > 0.0:
		var ease := 1.0 - UIKit.out_cubic(1.0 - _gain_life)
		var at := baseline + Vector2(w + 8.0 * s, -14.0 * s - (1.0 - _gain_life) * 16.0 * s)
		UIKit.shadowed(self, UIKit.latin(0.3), at, "+%d" % _gain,
			UIKit.type_size(self, UIKit.LABEL),
			HEAT_FLARE * Color(1, 1, 1, ease), UIKit.SHADOW * Color(1, 1, 1, 0.6),
			Vector2(1.0, 1.4) * s)

	# The rule under the count is not decoration: it is the run towards the next
	# free life. A hundred bottles buys a sandwich, and a player who cannot see
	# that coming experiences it as a random noise instead of a reward.
	var a := p + Vector2(26.0, 70.0) * s
	var b := p + Vector2(PLATE.x - 26.0, 70.0) * s
	UIKit.rule(self, a, b, UIKit.CREAM * Color(1, 1, 1, 0.14), 1.6 * s)
	var prog := _life_progress()
	if prog > 0.004:
		var head := a.lerp(b, prog)
		UIKit.rule(self, a, head, UIKit.SAUCE.lerp(UIKit.GOLD, prog * prog)
			* Color(1, 1, 1, 0.75), 2.0 * s)
		draw_line(head + Vector2(0.0, -2.5 * s), head + Vector2(0.0, 2.5 * s),
			UIKit.CREAM * Color(1, 1, 1, 0.55), 1.4 * s, true)


## How far this run is towards the next free life. Gx owns the counter; the HUD
## only reports it.
func _life_progress() -> float:
	if _preview:
		return fposmod(_shown, 100.0) / 100.0
	return clampf(float(Gx.run_sriracha_since_life) / float(Gx.SRIRACHA_PER_LIFE),
		0.0, 1.0)


## Lives read as filled slots out of five. The empty slots stay on as outlines,
## so the state is a countable shape rather than a colour, and so losing one is
## a visible subtraction instead of a glyph quietly going missing.
func _draw_lives(p: Vector2, s: float) -> void:
	var y := p.y + 86.0 * s
	for i in LIFE_SLOTS:
		var c := Vector2(p.x + (32.0 + i * LIFE_STEP) * s, y)
		var r := 9.0 * s
		_sandwich_outline(c, r)
		var v := _slot[i]
		if v <= 0.002:
			continue
		# out_back on the way in: it arrives past the mark and settles, which is
		# what makes a pickup feel physical rather than switched on.
		var grow := UIKit.out_back(v) if v < 1.0 else 1.0
		var pop := 1.0 + _slot_pop[i] * _slot_pop[i] * 0.45
		var flash := _lost_flash if i == _lost_slot else 0.0
		_sandwich(c, r * pop * clampf(grow, 0.15, 1.35), minf(v * 1.6, 1.0), flash)

	if _lives > LIFE_SLOTS:
		UIKit.shadowed(self, UIKit.latin(0.3),
			Vector2(p.x + (32.0 + LIFE_SLOTS * LIFE_STEP - 6.0) * s, y + 6.0 * s),
			"x%d" % _lives, UIKit.type_size(self, UIKit.LABEL),
			UIKit.CREAM * Color(1, 1, 1, 0.9), UIKit.SHADOW * Color(1, 1, 1, 0.6),
			Vector2(1.0, 1.4) * s)


func _draw_chains(p: Vector2, s: float) -> void:
	var gap := PIP_GAP * s
	var at := Vector2(p.x + (PLATE.x - 26.0) * s - (CHAIN_TOTAL - 1) * gap,
		p.y + 86.0 * s)
	UIKit.pips(self, at, _chains, CHAIN_TOTAL, 5.5 * s, gap)

	if _chain_flash > 0.0 and _chains > 0:
		var c := at + Vector2((_chains - 1) * gap, 0.0)
		var k := _chain_flash
		var r := 5.5 * s
		draw_arc(c, r * (1.6 + (1.0 - k) * 3.2), 0.0, TAU, 28,
			UIKit.GOLD * Color(1, 1, 1, k * 0.85), 1.8 * s, true)
		for i in 8:
			var a := TAU * i / 8.0 + _t * 1.1
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * r * 1.7, c + dir * r * (2.4 + k * 2.8),
				UIKit.GOLD * Color(1, 1, 1, k), 1.5 * s, true)


## HEAT. The UIKit instrument meter does the groove, the tick scale, the fill
## and the head; this adds the three things that are HUD-specific — the charge
## moving inside the fill, the spend being paid for in white, and a full state
## that changes SHAPE (chevrons, hot frame, label swap) as well as colour, so
## "you have a Heat Dash" survives a colour-blind read and a greyscale capture.
func _draw_heat(p: Vector2, s: float) -> void:
	var rect := Rect2(p + Vector2(26.0, 100.0) * s, Vector2(PLATE.x - 52.0, 16.0) * s)
	var full := _heat_display >= 0.995
	var accent := UIKit.SAUCE.lerp(HEAT_HOT, _heat_display)
	if full:
		accent = accent.lerp(HEAT_FLARE, 0.25 + 0.25 * sin(_t * 9.0))

	UIKit.meter(self, rect, _heat_display, accent, _heat_display > 0.02, 10)
	_energy(rect, _heat_display, s, full)

	if _ghost_life > 0.0 and _ghost > _heat_display:
		# What was just spent, collapsing away in white. The dash costs
		# something and the gauge should be seen paying it.
		var a := rect.position.x + rect.size.x * _heat_display
		var b := rect.position.x + rect.size.x * _ghost
		var band := Rect2(Vector2(a, rect.position.y + rect.size.y * 0.30),
			Vector2(b - a, rect.size.y * 0.40))
		draw_rect(band, HEAT_FLARE * Color(1, 1, 1, _ghost_life * _ghost_life * 0.55))
		draw_line(Vector2(b, rect.position.y), Vector2(b, rect.end.y),
			HEAT_FLARE * Color(1, 1, 1, _ghost_life), 1.6 * s, true)

	if full or _full_flash > 0.0:
		var pulse := 0.5 + 0.5 * sin(_t * 8.0)
		# Inset kept tight: the frame must not reach down into the caption line.
		var frame := Rect2(rect.position - Vector2(4.0, 4.0) * s,
			rect.size + Vector2(8.0, 8.0) * s)
		var fpts := PackedVector2Array([
			frame.position + Vector2(6.0 * s, 0.0),
			frame.position + Vector2(frame.size.x, 0.0),
			frame.end, frame.position + Vector2(6.0 * s, frame.size.y),
			frame.position + Vector2(0.0, frame.size.y - 6.0 * s),
			frame.position + Vector2(0.0, 6.0 * s)])
		UIKit.slab_outline(self, fpts,
			HEAT_HOT * Color(1, 1, 1, (0.45 + 0.35 * pulse) * (1.0 if full else _full_flash)),
			(1.2 + _full_flash * 2.5) * s)

	if full:
		for i in 2:
			var cx := rect.end.x + (8.0 + i * 8.0) * s
			var a := 0.9 - i * 0.3 + 0.12 * sin(_t * 8.0 - i)
			UIKit.chevron(self, Vector2(cx, rect.position.y + rect.size.y * 0.5),
				5.0 * s, HEAT_HOT * Color(1, 1, 1, a))


## The charge moving inside the fill: diagonal bars scrolling towards the head,
## clipped to the filled span. A gauge that only changes length reads as a
## loading bar; one with something alive inside it reads as stored energy.
func _energy(rect: Rect2, v: float, s: float, full: bool) -> void:
	if v <= 0.02:
		return
	var box := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.30),
		Vector2(rect.size.x * v, rect.size.y * 0.40))
	var step := 13.0 * s
	var slant := box.size.y
	var x := box.position.x - slant + fmod(_t * (78.0 if full else 42.0) * s, step)
	var col := UIKit.CREAM * Color(1, 1, 1, 0.16 if full else 0.10)
	while x < box.end.x:
		var quad := PackedVector2Array([
			Vector2(x, box.end.y), Vector2(x + slant, box.position.y),
			Vector2(x + slant + 2.0 * s, box.position.y), Vector2(x + 2.0 * s, box.end.y)])
		for piece in UIKit.clip_polygon(quad, box):
			draw_colored_polygon(piece, col)
		x += step


func _draw_caption(p: Vector2, s: float) -> void:
	var y := p.y + 136.0 * s
	var full := _heat_display >= 0.995
	var col := UIKit.DIM * Color(1, 1, 1, 0.9)
	if full:
		col = HEAT_HOT.lerp(UIKit.CREAM, 0.35 + 0.35 * sin(_t * 9.0))

	UIKit.text(self, Vector2(p.x + 26.0 * s, y), "READY" if full else "HEAT",
		UIKit.MICRO, col)

	# Arabic goes through UIKit.arabic in one call — it is cursive, and slicing
	# it for letterspacing severs the joins.
	var asize := int(UIKit.type_size(self, UIKit.MICRO) * UIKit.ARABIC_RATIO)
	var ar := "جاهز" if full else "حرارة"
	var aw := UIKit.naskh().get_string_size(ar, HORIZONTAL_ALIGNMENT_LEFT, -1, asize).x
	UIKit.arabic(self, Vector2(p.x + (PLATE.x - 26.0) * s - aw, y), ar, asize,
		col * Color(1, 1, 1, 0.85))


# --- Glyphs -----------------------------------------------------------------

## The bottle: squat body, shoulder, neck, cap, label band. Drawn with an ink
## understroke and a warm drop, so it survives being held over a bright sky.
func _bottle(center: Vector2, h: float, tint: Color) -> void:
	var w := h * 0.50
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.62, h * 0.46),
		center + Vector2(-w * 0.70, h * 0.08),
		center + Vector2(-w * 0.66, -h * 0.18),
		center + Vector2(-w * 0.34, -h * 0.34),
		center + Vector2(-w * 0.30, -h * 0.50),
		center + Vector2(w * 0.30, -h * 0.50),
		center + Vector2(w * 0.34, -h * 0.34),
		center + Vector2(w * 0.66, -h * 0.18),
		center + Vector2(w * 0.70, h * 0.08),
		center + Vector2(w * 0.62, h * 0.46),
	])
	draw_colored_polygon(_offset(pts, Vector2(h * 0.03, h * 0.06)),
		UIKit.SHADOW * Color(1, 1, 1, 0.55))
	_gradient_poly(pts, tint.lightened(0.16), tint.darkened(0.38))
	UIKit.slab_outline(self, pts, UIKit.SHADOW * Color(1, 1, 1, 0.55), h * 0.035)

	draw_rect(Rect2(center + Vector2(-w * 0.70, -h * 0.04), Vector2(w * 1.40, h * 0.21)),
		UIKit.CREAM * Color(1, 1, 1, 0.92))
	draw_rect(Rect2(center + Vector2(-w * 0.15, h * 0.005), Vector2(w * 0.30, h * 0.13)),
		tint.darkened(0.10))
	draw_rect(Rect2(center + Vector2(-w * 0.30, -h * 0.64), Vector2(w * 0.60, h * 0.15)),
		tint.darkened(0.52))
	# One specular sliver, and the bottle stops reading as a flat cutout.
	draw_line(center + Vector2(-w * 0.44, -h * 0.12), center + Vector2(-w * 0.44, h * 0.30),
		Color(1, 1, 1, 0.32), h * 0.055, true)


func _sandwich(center: Vector2, r: float, alpha: float, flash: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-r * 1.25, r * 0.62),
		center + Vector2(r * 1.25, r * 0.62),
		center + Vector2(0.0, -r * 0.95),
	])
	draw_colored_polygon(_offset(pts, Vector2(r * 0.10, r * 0.20)),
		UIKit.SHADOW * Color(1, 1, 1, 0.45 * alpha))
	var top := BREAD.lerp(UIKit.CREAM, flash)
	var bot := BREAD_DARK.lerp(UIKit.CREAM, flash)
	_gradient_poly(pts, top * Color(1, 1, 1, alpha), bot * Color(1, 1, 1, alpha))
	draw_line(center + Vector2(-r * 0.92, r * 0.20), center + Vector2(r * 0.92, r * 0.20),
		TUNA.lerp(UIKit.CREAM, flash) * Color(1, 1, 1, alpha), r * 0.30, true)
	UIKit.slab_outline(self, pts, UIKit.SHADOW * Color(1, 1, 1, 0.5 * alpha), r * 0.13)


func _sandwich_outline(center: Vector2, r: float) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-r * 1.25, r * 0.62),
		center + Vector2(r * 1.25, r * 0.62),
		center + Vector2(0.0, -r * 0.95),
	])
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, UIKit.SHADOW * Color(1, 1, 1, 0.35), r * 0.22, true)
	draw_polyline(closed, UIKit.DIM * Color(1, 1, 1, 0.34), r * 0.11, true)


# --- Primitives -------------------------------------------------------------

## Fixed-advance numerals: every digit is centred in a cell as wide as the
## widest digit plus tracking, so a counting number never shuffles its own
## layout while it climbs. Returns the width drawn.
func _digits(at: Vector2, text: String, size: int, track: float, tint: Color) -> float:
	var cell := _cell_w(size) + track
	var font := UIKit.latin(0.35)
	var off := Vector2(1.0, 1.4) * maxf(1.0, size * 0.06)
	var x := at.x
	for i in text.length():
		var ch := text[i]
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var cx := x + (cell - track - cw) * 0.5
		draw_string(font, Vector2(cx, at.y) + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, UIKit.SHADOW * Color(1, 1, 1, 0.75 * tint.a))
		draw_string(font, Vector2(cx, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, tint)
		x += cell
	return maxf(x - at.x - track, 0.0)


func _cell_w(size: int) -> float:
	if _cells.has(size):
		return float(_cells[size])
	var font := UIKit.latin(0.35)
	var w := 0.0
	for d in 10:
		w = maxf(w, font.get_string_size(str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	_cells[size] = w
	return w


## UIKit has no gradient fill for arbitrary glyph polygons and it is not mine to
## extend, so this is the local version: per-vertex colours down the bounding box.
func _gradient_poly(pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var min_y := pts[0].y
	var max_y := pts[0].y
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var span := maxf(max_y - min_y, 0.001)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - min_y) / span))
	draw_polygon(pts, cols)


func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


# --- Preview ----------------------------------------------------------------
#
# `--hud-preview` on the command line drives the HUD from a scripted sweep
# instead of Gx, so one capture can shoot the counter kicking, the gauge
# draining and a chain landing without playing a level to the point where those
# happen. It writes only this node's own display state, never Gx, and it is
# inert in a normal run.

func _preview_seed() -> void:
	_sriracha = 137
	_shown = 118.0
	_lives = 3
	_chains = 2
	_heat = 0.86
	_heat_display = 0.62
	for i in LIFE_SLOTS:
		_slot[i] = 1.0 if i < _lives else 0.0


## A compressed sweep: full gauge, a life arriving, the dash being spent and a
## chain landing, all inside the first second, so a short capture sees every
## state instead of only the resting one.
func _preview_step(delta: float) -> void:
	# Four times real speed: a capture on a loaded build machine can only afford
	# a handful of frames, and every state has to have happened by then.
	_pv_t += delta * 4.0
	if _pv_t >= _pv_next:
		_pv_next = _pv_t + 0.06
		# Mostly singles, with a cluster every third of a second, so the sweep
		# exercises both the tick and the "+N" path.
		var n := 1
		if int(_pv_t / 0.30) > _pv_bunch:
			_pv_bunch = int(_pv_t / 0.30)
			n = 5
		_on_sriracha(_sriracha + n, n)
		_set_heat(minf(_heat + float(n) / 30.0, 1.0))
	if _pv_t > 0.40 and _lives == 3:
		_on_lives(4)
	if _pv_t > 0.55 and _pv_spend < 0.0:
		_pv_spend = _pv_t
		_set_heat(0.08)
	if _pv_t > 0.58 and _chains < 3:
		_on_chain("preview", 3)
	if _pv_t > 2.4 and _lives == 4:
		_on_lives(3)
	if _heat >= 0.999 and _pv_spend > 0.0 and _pv_t - _pv_spend > 1.4:
		_pv_spend = _pv_t
		_set_heat(0.08)
