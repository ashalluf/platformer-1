class_name MaterialLab
## The project's material library.
##
## Every surface comes from here. Presets are tuned by eye against capture
## screenshots, not by guessing at physical values, and they all share one
## weathering shader so a wall in Brega and a wall in Benghazi are the same
## material family with different inputs.
##
## Three conventions hold across the whole file:
##
## 1. A preset's FIRST parameter is always its tint. Call sites all over the
##    project pass it positionally, so it never changes meaning.
## 2. Anything that belongs to the world runs its tint through `world_tint()`.
##    See "The chroma law" below.
## 3. `tone` is the level author's one dial for making a surface darker, lighter
##    or dirtier without inventing a new colour by hand. Hand-picked albedos are
##    how five levels drift apart; one shared curve is how they don't.

const SURFACE_SHADER := preload("res://shaders/surface_weathered.gdshader")
const ICE_SHADER := preload("res://shaders/ice.gdshader")

static var _cache: Dictionary = {}


# --- The chroma law ---------------------------------------------------------
#
# ART_DIRECTION.md, pillar five: Wanis is the only saturated thing in the frame,
# and the hue band 340deg-25deg is RESERVED for his red shemagh and jacket and for
# the Sriracha bottles. That rule does more for readability than every
# post-process in the engine combined, and it is worth exactly nothing as a
# sentence in a document — a level author in a hurry will type a punchy red for a
# shutter and never think about it again. So it is enforced here, in the one
# place every world surface has to pass through.
#
# Deliberate exceptions, and they are the ONLY ones:
#   * `cloth()` and `skin()` — Wanis's costume and the Sriracha's cap and band
#     are built from them, and they are precisely what the band is reserved for.
#   * `emissive()` and `ice()` — those are light and fantasy, not albedo. The
#     law is about what a surface reflects.
# Everything else in the world goes through `world_tint()`.

## HSV saturation ceiling for world albedo outside the reserved band.
##
## This was 0.58, and it was the single reason the game looked dusty. A cap that
## low means no wall, no shutter, no leaf and no tile can ever be a colour --
## everything resolves to the same sun-bleached ochre, and no amount of lighting
## or grading gets it back, because the albedo it is working from was already
## flattened. The direction is now a bright, saturated, green-mountain Libya, so
## the ceiling goes up to where paint and foliage can actually sing.
##
## Hero readability does not come from holding the world down. It comes from
## value separation and the rim light, both of which LightingRig already does on
## every scene, and from the reserved red band below, which is still reserved.
const WORLD_CHROMA_CAP := 0.88
## Inside the reserved band the hero still gets first claim on red, but the old
## numbers pushed every oxide and terracotta surface into mud to get there.
const HERO_BAND_CAP_S := 0.62
const HERO_BAND_CAP_V := 0.82
const HERO_BAND_LO := 340.0
const HERO_BAND_HI := 25.0
## Feathered rather than a hard sector test. Iron oxide lands at hue ~23deg, one
## degree inside the band: a hard edge there would either wash every rust run in
## Brega into mud or leave a crimson wall legal at 26deg. The ramp lets oxide
## orange keep its punch while true reds are held down hard.
const HERO_BAND_FEATHER := 10.0


## Clamp a tint so it cannot out-shout the hero. Idempotent, and a no-op for the
## browns, greys and sun-bleached pastels that most of the world is made of.
static func world_tint(c: Color) -> Color:
	var h := c.h * 360.0
	var inside := 0.0
	if h >= HERO_BAND_LO or h <= HERO_BAND_HI:
		var d_lo := h - HERO_BAND_LO if h >= HERO_BAND_LO else h + 360.0 - HERO_BAND_LO
		var d_hi := HERO_BAND_HI - h if h <= HERO_BAND_HI else HERO_BAND_HI + 360.0 - h
		inside = clampf(minf(d_lo, d_hi) / HERO_BAND_FEATHER, 0.0, 1.0)
	var cap_s := lerpf(WORLD_CHROMA_CAP, HERO_BAND_CAP_S, inside)
	var cap_v := lerpf(1.0, HERO_BAND_CAP_V, inside)
	if c.s <= cap_s and c.v <= cap_v:
		return c
	return Color.from_hsv(c.h, minf(c.s, cap_s), minf(c.v, cap_v), c.a)


# --- Tone -------------------------------------------------------------------

## The shared darker/lighter/dirtier curve. `tone` runs -1 to +1:
##
##   +1  full sun-bleach — the south and west faces, chalked render, salt-burnt
##       paint. Value up, saturation way down, per the weathering law's aspect rule.
##    0  the preset as authored.
##   -1  deep shade, soot, damp, the underside of a canopy.
##
## Negative tone does NOT simply multiply toward grey. A neutral-multiplied
## shadow is the single most common tell of a hobby scene; ART_DIRECTION.md's
## rule is that shadow is never neutral and never black, so the dark end drops
## blue fastest and then leans into a warm soot.
static func toned(c: Color, tone: float) -> Color:
	if absf(tone) < 0.001:
		return c
	var t := clampf(tone, -1.0, 1.0)
	if t > 0.0:
		# The document's chalking figure is +12% value / -30% saturation on a
		# fully weathered face. +1 here means the most bleached thing in World 1,
		# so it reaches a bit past that.
		return Color.from_hsv(c.h, c.s * (1.0 - 0.55 * t),
			clampf(c.v * (1.0 + 0.26 * t), 0.0, 1.0), c.a)
	var k := -t
	var shaded := Color(c.r * (1.0 - 0.50 * k), c.g * (1.0 - 0.54 * k), c.b * (1.0 - 0.60 * k), c.a)
	return shaded.lerp(Color(0.135, 0.112, 0.100, c.a), 0.20 * k)


## World tint + tone in the order the presets always want them: tone is an
## authoring move, the chroma clamp is the law, and the law goes last.
static func _wt(c: Color, tone := 0.0) -> Color:
	return world_tint(toned(c, tone))


## Dust and grime multipliers derived from the tone dial, so one number moves the
## colour and the dirt together. Bleached surfaces are wind-scoured and dusty;
## shaded surfaces are damp and hold grime.
static func _dust_gain(tone: float) -> float:
	return 1.0 + 0.55 * maxf(tone, 0.0)


static func _grime_gain(tone: float) -> float:
	return 1.0 + 0.70 * maxf(-tone, 0.0)


# --- Core factory -----------------------------------------------------------

## Every preset below is a call to this with different numbers.
##
## Note what is NOT set unconditionally: the shader has grown a second macro
## tone, edge wear, run-off streaking, parallax and specular controls, and every
## one of those ships with a tuned default. Setting them from here by default
## would quietly overwrite that tuning, so they are opt-in — a preset that has an
## opinion states it, and everything else inherits the shader's own look.
static func surface(p: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER

	var base: Color = p.get("color", Color(0.6, 0.58, 0.54))
	var varia: Color = p.get("variation", _shade(base, 0.88))
	# Opt out only for something that is provably not world geometry.
	if not p.get("hero", false):
		base = world_tint(base)
		varia = world_tint(varia)

	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("variation_color", varia)
	m.set_shader_parameter("variation_strength", p.get("variation_strength", 0.45))
	m.set_shader_parameter("metallic_value", p.get("metallic", 0.0))
	m.set_shader_parameter("roughness_min", p.get("roughness_min", 0.55))
	m.set_shader_parameter("roughness_max", p.get("roughness_max", 0.92))
	m.set_shader_parameter("emission_color", p.get("emission", Color.BLACK))
	m.set_shader_parameter("emission_strength", p.get("emission_strength", 0.0))

	m.set_shader_parameter("macro_noise", p.get("macro", NoiseBank.macro(p.get("seed", 11))))
	m.set_shader_parameter("detail_mask", p.get("mask", NoiseBank.grain(p.get("seed", 11) + 12)))
	m.set_shader_parameter("detail_normal", p.get("normal",
		NoiseBank.detail_normal(p.get("seed", 11) + 60, p.get("normal_freq", 0.12), p.get("bump", 1.6))))
	m.set_shader_parameter("macro_scale", p.get("macro_scale", 0.09))
	m.set_shader_parameter("detail_scale", p.get("detail_scale", 0.85))
	m.set_shader_parameter("normal_strength", p.get("normal_strength", 1.0))
	m.set_shader_parameter("triplanar_sharpness", p.get("sharpness", 5.0))
	m.set_shader_parameter("detail_fade_start", p.get("fade_start", 26.0))
	m.set_shader_parameter("detail_fade_end", p.get("fade_end", 70.0))

	m.set_shader_parameter("dust_color", p.get("dust_color", Color(0.66, 0.58, 0.43)))
	m.set_shader_parameter("dust_amount", p.get("dust", 0.28))
	m.set_shader_parameter("dust_sharpness", p.get("dust_sharpness", 3.0))
	m.set_shader_parameter("grime_color", p.get("grime_color", Color(0.15, 0.13, 0.11)))
	m.set_shader_parameter("grime_amount", p.get("grime", 0.30))
	m.set_shader_parameter("grime_origin_y", p.get("grime_origin", 0.0))
	m.set_shader_parameter("grime_falloff", p.get("grime_falloff", 2.2))
	m.set_shader_parameter("ao_strength", p.get("ao", 0.45))

	# Opt-in extensions. Key on the left, shader uniform on the right.
	#
	# variation_color_b and wear_color use alpha-as-a-flag in the shader: zero
	# means "derive it yourself". A caller that bothered to name a colour always
	# means "use this one", so force the flag here rather than making every
	# preset remember to write a 1.0 it has no other use for.
	if p.has("variation_b"):
		m.set_shader_parameter("variation_color_b", _tone_b(p["variation_b"]))
	if p.has("wear_color"):
		m.set_shader_parameter("wear_color", _tone_b(p["wear_color"]))
	_opt(m, p, "variation_b_strength", "variation_b_strength")
	_opt(m, p, "macro_scale_b", "macro_scale_b")
	_opt(m, p, "parallax", "parallax_depth")
	_opt(m, p, "edge_wear", "edge_wear")
	_opt(m, p, "edge_lift", "edge_wear_lift")
	_opt(m, p, "edge_rough", "edge_wear_rough")
	_opt(m, p, "curvature", "curvature_gain")
	_opt(m, p, "dust_cavity", "dust_cavity")
	_opt(m, p, "dust_wash", "dust_wash")
	_opt(m, p, "dust_variation", "dust_color_variation")
	_opt(m, p, "grime_streak", "grime_streak")
	_opt(m, p, "streak_scale", "streak_scale")
	_opt(m, p, "streak_stretch", "streak_stretch")
	_opt(m, p, "roughness_contrast", "roughness_contrast")
	_opt(m, p, "roughness_macro", "roughness_macro")
	_opt(m, p, "polish", "aniso_polish")

	# Escape hatch. The shader is being extended in parallel with this file;
	# anything it grows can be driven from a call site without waiting for a
	# preset. ShaderMaterial ignores unknown uniform names, so this cannot break.
	var extra: Dictionary = p.get("params", {})
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


static func _opt(m: ShaderMaterial, p: Dictionary, key: String, uniform: String) -> void:
	if p.has(key):
		m.set_shader_parameter(uniform, p[key])


## The second macro tone wants its alpha set to 1 — in the shader, alpha on that
## uniform is a "use my rgb verbatim" flag, not an opacity.
static func _tone_b(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 1.0)


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


static func _cached(key: String, factory: Callable) -> ShaderMaterial:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key]


## Dielectric F0. ART_DIRECTION.md is blunt about this: the 0.5 default is the
## plasticky-sheen tell, and 0.30 is the house number for every non-metal.
const DIELECTRIC_SPECULAR := 0.30


# --- Presets: the originals -------------------------------------------------
#
# Signatures are append-only. The first parameter is always the tint and the
# second always means what it meant the day the call site was written, because
# a few hundred of them pass positionally.

## Poured concrete: prison walls, sea defences, road structures.
static func concrete(tint := Color(0.52, 0.51, 0.48), wear := 1.0, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.80),
		"variation_strength": 0.55,
		"roughness_min": 0.62, "roughness_max": 0.95,
		"mask": NoiseBank.pits(37),
		"normal": NoiseBank.rough_normal(83, 0.05, 2.4),
		"detail_scale": 0.55, "macro_scale": 0.11,
		"normal_strength": 0.9,
		# Slab edges spall — it is the one place raw concrete reliably shows a
		# paler, sharper break, and the art direction asks for exposed rebar there.
		"edge_wear": 0.66,
		"dust": 0.22 * wear * _dust_gain(tone),
		"grime": 0.50 * wear * _grime_gain(tone), "grime_falloff": 2.4,
		"ao": 0.55,
	})


## Painted lime plaster — the ubiquitous Libyan wall. Chalky, sun-bleached,
## stained dark where it meets the ground.
static func plaster(tint := Color(0.86, 0.80, 0.68), wear := 1.0, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.89),
		"variation_strength": 0.50,
		"roughness_min": 0.72, "roughness_max": 0.98,
		"mask": NoiseBank.streaks(53),
		"normal": NoiseBank.detail_normal(71, 0.09, 1.1),
		"detail_scale": 0.42, "macro_scale": 0.07,
		"normal_strength": 0.55,
		"dust": 0.18 * wear * _dust_gain(tone),
		"grime": 0.58 * wear * _grime_gain(tone), "grime_falloff": 1.8,
		"grime_color": Color(0.30, 0.25, 0.19),
		"ao": 0.40,
	})


## Rusted steel: bars, pipework, tank shells, anything by the sea in Brega.
static func rusted_metal(tint := Color(0.42, 0.22, 0.13), rust := 1.0, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": world_tint(Color(0.28, 0.22, 0.17).lerp(c, 0.35)),
		"variation_strength": 0.70,
		# Iron oxide is a dielectric; bare steel is a conductor. There is no
		# physical state in between, so this is a switch and not a lerp. Past
		# the point where scale covers the surface the specular comes entirely
		# from roughness, which is why heavy rust reads matte and chalky and the
		# old half-metallic version read like painted plastic.
		"metallic": 0.0 if rust >= 0.35 else 1.0,
		"roughness_min": 0.38, "roughness_max": 0.92,
		"mask": NoiseBank.blooms(157),
		"normal": NoiseBank.rough_normal(91, 0.09, 2.8),
		"detail_scale": 0.9, "macro_scale": 0.16,
		"normal_strength": 1.1,
		# Knocked edges on rusted stock go back to bright steel before they go
		# back to rust, so the wear colour is stated rather than derived.
		# edge_wear_rough is a POSITIVE gain in the shader, so zero is as smooth
		# as a worn edge can be asked to go — bright steel should not also get
		# the chalky roughness bump that a rubbed painted edge gets.
		"edge_wear": 0.55, "wear_color": Color(0.46, 0.44, 0.42, 1.0),
		"edge_rough": 0.0,
		"dust": 0.18 * _dust_gain(tone),
		"grime": 0.35 * rust * _grime_gain(tone), "grime_color": Color(0.20, 0.10, 0.06),
		"ao": 0.5,
	})


## Painted sheet metal: doors, gates, signage backs, vehicle panels.
static func painted_metal(tint := Color(0.18, 0.32, 0.42), wear := 0.6, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.80),
		"variation_strength": 0.40,
		# Paint is a dielectric film. The steel under it is a conductor, but the
		# player never sees the steel — they see the binder. 0.15 was a fudge for
		# "it should look a bit metal", and it bought a grey sheen over every
		# colour in the level instead.
		"metallic": 0.0,
		"roughness_min": 0.26, "roughness_max": 0.60,
		"mask": NoiseBank.worn_edge(103, 0.52),
		"normal": NoiseBank.detail_normal(67, 0.16, 0.8),
		"detail_scale": 1.2, "macro_scale": 0.12,
		"normal_strength": 0.45,
		# Chipped paint shows a pale primer or bright steel at every knocked
		# corner. Pushed above the shader default because sheet metal takes more
		# knocks than anything else in a prison yard, but held short of 1.0 —
		# a fully worn edge on a dark door reads as chalk, not as wear.
		"edge_wear": 0.40 + 0.35 * wear,
		"dust": 0.22 * wear * _dust_gain(tone),
		"grime": 0.28 * wear * _grime_gain(tone),
		"ao": 0.3,
	})


## Corrugated steel roofing and fencing — the ridges come from the normal map,
## not from geometry, so a wall of it costs two triangles.
static func corrugated(tint := Color(0.46, 0.45, 0.43), period := 26.0, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.76),
		"variation_strength": 0.5,
		# Bare mill sheet is a conductor: metallic 1.0, and the darkness comes
		# from the tint, not from pretending it is a third metal. The payoff is
		# a sky gradient running along every ridge, which is the whole reason
		# corrugated roofing reads as corrugated at a hundred metres. Dust and
		# grime already knock metallic back where they land.
		"metallic": 1.0,
		"roughness_min": 0.42, "roughness_max": 0.86,
		"mask": NoiseBank.corrugation_mask(period),
		"normal": NoiseBank.corrugation_normal(period, 2.6),
		"detail_scale": 1.0, "macro_scale": 0.12,
		"normal_strength": 1.3, "sharpness": 8.0,
		# No offset mapping: the ridge profile is an exact sine and a one-step
		# parallax probe against it just makes the ridge line wobble.
		"parallax": 0.0,
		"dust": 0.35 * _dust_gain(tone), "grime": 0.25 * _grime_gain(tone),
		"ao": 0.35,
	})


## Drifted sand and dry ground.
static func sand(tint := Color(0.78, 0.68, 0.50), tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		# Derived from the tint, not fixed: a fixed bright variation colour means
		# a dark sand still comes out with bright patches in it, which is what
		# was keeping the yard floor the lightest thing in every frame.
		"variation": c.lightened(0.14),
		"variation_strength": 0.45,
		"roughness_min": 0.85, "roughness_max": 1.0,
		"mask": NoiseBank.grain(19),
		"normal": NoiseBank.detail_normal(77, 0.42, 0.45),
		"detail_scale": 3.2, "macro_scale": 0.16,
		"normal_strength": 0.7,
		# Sand has no edges to rub bright. Leaving the shader's default edge wear
		# on it puts a pale rim around every chamfered ground block in the level.
		"edge_wear": 0.08,
		"dust": 0.0, "grime": 0.10 * _grime_gain(tone), "ao": 0.30,
	})


## Asphalt and worn road surface.
static func asphalt(tint := Color(0.20, 0.20, 0.21), tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": c.lightened(0.10),
		"variation_strength": 0.6,
		"roughness_min": 0.55, "roughness_max": 0.90,
		"mask": NoiseBank.pits(43),
		"normal": NoiseBank.rough_normal(89, 0.20, 1.4),
		"detail_scale": 1.5, "macro_scale": 0.13,
		"normal_strength": 0.8,
		# Kerb noses and pothole lips polish pale under tyres. This is the one
		# ground material that genuinely wants edge wear.
		"edge_wear": 0.70, "edge_lift": 0.45,
		"dust": 0.30 * _dust_gain(tone), "grime": 0.12 * _grime_gain(tone), "ao": 0.45,
	})


# --- Presets: the built world -----------------------------------------------
#
# Everything a Libyan street is actually made of, which is not concrete and rust
# alone. All of these take `tone` and all of them go through the chroma clamp.

## Painted timber: shutters, doors, market stall frames, cart boards.
## The paint sits on a surface that moves, so it crazes and lets go along the
## grain long before it fades, and the rubbed edges go back to bare silvered wood.
static func painted_wood(tint := Color(0.34, 0.42, 0.44), wear := 0.7, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.82),
		"variation_strength": 0.38,
		"metallic": 0.0,
		"roughness_min": 0.34, "roughness_max": 0.78,
		# Grain direction is the whole read on painted timber. A stretched
		# lookup gives long parallel runs instead of a felt-like grain field.
		"mask": NoiseBank.directional(181, 7.0, 0.055),
		"normal": NoiseBank.directional_normal(183, 9.0, 1.05, 0.07),
		"detail_scale": 0.7, "macro_scale": 0.10,
		"normal_strength": 0.7,
		# Sun-silvered timber, not a lighter version of the paint.
		"edge_wear": 0.40 + 0.45 * wear,
		"wear_color": Color(0.52, 0.48, 0.42, 1.0),
		"edge_rough": 0.40,
		"dust": 0.20 * wear * _dust_gain(tone),
		"grime": 0.34 * wear * _grime_gain(tone),
		"ao": 0.42,
	})


## Glazed ceramic tile — stair risers, dados, mosque and villa entrances, the
## splashback of every café in Ajdabiya.
##
## The read is almost entirely specular: glossy tile faces against matte grout,
## with a bevel catching the sun along every course. `cols` is tiles per texture
## repeat, and at the default detail scale the texture repeats every two metres —
## so the default of 8 gives 25 cm tiles, which is what a Libyan dado actually is.
static func ceramic_tile(tint := Color(0.46, 0.54, 0.54), cols := 8, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		# Per-tile kiln variation. Fired tile is never one colour across a run,
		# and a perfectly uniform tiled wall is the giveaway that it is a texture.
		"variation": world_tint(c.lightened(0.12)),
		"variation_strength": 0.30,
		# Cell frequency tracks the tile count so a patch of kiln variation is
		# roughly one tile wide. Finer than that and the mottling reads as dirt
		# inside a single tile instead of as a batch that fired differently.
		"macro": NoiseBank.cells(149, 0.95, float(cols) / 512.0),
		"macro_scale": 0.5,
		# Glaze is a fired silicate — a dielectric, however wet it looks.
		"metallic": 0.0,
		"roughness_min": 0.09, "roughness_max": 0.82,
		"mask": NoiseBank.tile_mask(cols, 0.055),
		"normal": NoiseBank.tile_normal(cols, 0.055, 0.05, 1.7),
		"detail_scale": 0.5,
		"normal_strength": 1.15,
		# The mask doubles as the height field, so the grout genuinely sits below
		# the glaze instead of being painted on.
		"parallax": 0.045,
		# Hard split between glaze and grout rather than a roll-off.
		"roughness_contrast": 3.2, "roughness_macro": 0.03,
		"edge_wear": 0.30,
		"dust": 0.10 * _dust_gain(tone),
		"grime": 0.40 * _grime_gain(tone), "grime_falloff": 1.2,
		"ao": 0.5,
	})


## Fired terracotta: roof pantiles, pots, drainage ware, unglazed floor tile.
## Porous, so it drinks water and holds a tide mark, and it chalks pale where the
## sun hits it squarely.
static func terracotta(tint := Color(0.48, 0.29, 0.19), tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": world_tint(c.lerp(Color(0.56, 0.44, 0.34), 0.35)),
		"variation_strength": 0.55,
		"metallic": 0.0,
		"roughness_min": 0.60, "roughness_max": 0.95,
		"mask": NoiseBank.pits(191),
		"normal": NoiseBank.detail_normal(193, 0.16, 1.3),
		"detail_scale": 0.9, "macro_scale": 0.13,
		"normal_strength": 0.8,
		"edge_wear": 0.55, "edge_lift": 0.30,
		"dust": 0.30 * _dust_gain(tone),
		"grime": 0.42 * _grime_gain(tone),
		# Lime bloom, not soot: water leaving a porous clay deposits pale salts.
		"grime_color": Color(0.34, 0.28, 0.23),
		"ao": 0.48,
	})


## Lime wash over blockwork — the cheapest wall finish in Libya and the most
## common. Thin enough that the block coursing ghosts through, and it crazes into
## a crack network everywhere the block behind it moves.
static func limewash(tint := Color(0.80, 0.78, 0.72), wear := 1.0, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.90),
		"variation_strength": 0.45,
		"metallic": 0.0,
		"roughness_min": 0.78, "roughness_max": 1.0,
		"mask": NoiseBank.cracks(163, 0.05, 0.085),
		"normal": NoiseBank.detail_normal(197, 0.07, 0.9),
		"detail_scale": 0.30, "macro_scale": 0.06,
		"normal_strength": 0.5,
		# Cracks are thin and dark: give them a little depth and a lot of
		# roughness contrast so they read as openings, not pencil lines.
		"parallax": 0.030, "roughness_contrast": 2.8,
		"edge_wear": 0.70, "edge_lift": 0.22,
		"dust": 0.16 * wear * _dust_gain(tone),
		"grime": 0.60 * wear * _grime_gain(tone), "grime_falloff": 1.6,
		"grime_color": Color(0.32, 0.27, 0.21),
		"ao": 0.42,
	})


## Bitumen roofing felt — flat roofs, stair-head huts, patched parapets.
## Mineral-granule surface, almost no specular, and it never stops being black,
## so it is the darkest value available for composition.
static func bitumen(tint := Color(0.135, 0.128, 0.126), tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		# Sun-blasted felt goes grey-green at the granules, never blue.
		"variation": c.lerp(Color(0.30, 0.29, 0.26), 0.42),
		"variation_strength": 0.55,
		"metallic": 0.0,
		"roughness_min": 0.68, "roughness_max": 0.98,
		"mask": NoiseBank.granule(173),
		"normal": NoiseBank.detail_normal(199, 0.55, 0.8),
		"detail_scale": 2.4, "macro_scale": 0.09,
		"normal_strength": 0.75,
		# Laid flat and walked on; there is nothing here to rub bright.
		"edge_wear": 0.10,
		"dust": 0.45 * _dust_gain(tone), "dust_sharpness": 2.0,
		"grime": 0.10 * _grime_gain(tone),
		"ao": 0.40,
	})


## Galvanised steel — water tanks, gate frames, ducting, balustrade tube.
## `age` 0 is a fresh spangled sheet, 1 is the white powdery carbonate stage that
## every roof tank in Libya reaches within two summers.
static func galvanised(tint := Color(0.58, 0.59, 0.60), age := 0.6, tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint.lerp(Color(0.70, 0.70, 0.68), 0.35 * age), tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.84),
		"variation_strength": 0.50,
		# Same switch as rust, same reason. Zinc carbonate bloom is a chalky
		# dielectric; the bright sheet under it is a conductor. Halfway between
		# gives a grey that is neither, which is exactly what galvanised must
		# not look like.
		"metallic": 1.0 if age < 0.4 else 0.0,
		"roughness_min": lerpf(0.22, 0.62, age), "roughness_max": lerpf(0.55, 0.95, age),
		"mask": NoiseBank.blooms(211, 0.05),
		"normal": NoiseBank.detail_normal(213, 0.30, 0.6),
		"detail_scale": 1.6, "macro_scale": 0.14,
		"normal_strength": 0.5,
		"edge_wear": 0.40, "wear_color": Color(0.64, 0.65, 0.66, 1.0),
		"dust": 0.26 * _dust_gain(tone),
		# Galvanising fails at the cut edges first and bleeds orange downward.
		"grime": (0.14 + 0.30 * age) * _grime_gain(tone),
		"grime_color": Color(0.34, 0.20, 0.11), "grime_falloff": 2.6,
		"ao": 0.40,
	})


## Packed earth and compacted track — yards, verges, unmade roads, the ground
## between the tarmac and the sand.
static func packed_earth(tint := Color(0.44, 0.38, 0.30), tone := 0.0) -> ShaderMaterial:
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		"variation": c.lightened(0.10),
		"variation_strength": 0.50,
		"metallic": 0.0,
		"roughness_min": 0.82, "roughness_max": 1.0,
		"mask": NoiseBank.cracks(217, 0.09, 0.12),
		"normal": NoiseBank.rough_normal(219, 0.26, 1.1),
		"detail_scale": 1.1, "macro_scale": 0.12,
		"normal_strength": 0.7,
		"edge_wear": 0.06,
		# It is already dust; a dust layer on top just flattens it.
		"dust": 0.0,
		"grime": 0.14 * _grime_gain(tone),
		"ao": 0.38,
	})


## Wet concrete — hosed yards, the shaded side of a water tank, sea spray on the
## quay, the first thirty seconds after a pipe bursts.
##
## Water does two things and this does both: it darkens albedo (the film fills
## the pores and kills the diffuse bounce) and it collapses roughness on the
## up-facing planes where it pools. Darkening alone reads as dirt, not water.
static func wet_concrete(tint := Color(0.40, 0.39, 0.37), wetness := 1.0, tone := 0.0) -> ShaderMaterial:
	var w := clampf(wetness, 0.0, 1.0)
	var c := _wt(_shade(tint, lerpf(1.0, 0.46, w)), tone)
	return surface({
		"color": c,
		"variation": _shade(c, 0.82),
		"variation_strength": 0.50,
		"metallic": 0.0,
		"roughness_min": lerpf(0.62, 0.06, w), "roughness_max": lerpf(0.95, 0.42, w),
		"mask": NoiseBank.pits(37),
		"normal": NoiseBank.rough_normal(83, 0.05, 2.4),
		"detail_scale": 0.55, "macro_scale": 0.11,
		# A film of water floods the surface relief; it does not sharpen it.
		"normal_strength": lerpf(0.9, 0.35, w),
		"polish": 0.35 + 0.55 * w,
		"roughness_contrast": 1.6,
		"edge_wear": 0.30,
		"dust": 0.0,
		"grime": 0.45 * _grime_gain(tone), "grime_falloff": 2.8,
		"grime_color": Color(0.10, 0.10, 0.10),
		"ao": 0.55,
	})


## Salt-crusted masonry — the bottom two metres of everything within a hundred
## metres of the Gulf of Sidra. Rising damp carries salt up through the block, it
## crystallises at the surface, and the render spalls off in plates.
##
## `salt` drives how far the bloom has got: 0 is a clean wall, 1 is a wall losing
## its face. This is the material that makes Brega read as a coastal town.
static func salt_masonry(tint := Color(0.58, 0.56, 0.51), salt := 0.7, tone := 0.0) -> ShaderMaterial:
	var s := clampf(salt, 0.0, 1.0)
	var c := _wt(tint, tone)
	return surface({
		"color": c,
		# Efflorescence is white and it is FLAT — no sheen at all, which is what
		# separates it from a paint blotch.
		"variation": world_tint(c.lerp(Color(0.90, 0.89, 0.86), 0.45 + 0.35 * s)),
		"variation_strength": 0.35 + 0.45 * s,
		"metallic": 0.0,
		"roughness_min": 0.74, "roughness_max": 1.0,
		# Flat-valued cells: a plate of render has either let go or it has not.
		"macro": NoiseBank.cells(223, 0.95, 0.045),
		"macro_scale": 0.16,
		"mask": NoiseBank.blooms(227, 0.04),
		"normal": NoiseBank.rough_normal(229, 0.09, 2.2),
		"detail_scale": 0.8,
		"normal_strength": 0.85 + 0.45 * s,
		"parallax": 0.020 + 0.030 * s,
		# Spalled plate edges are the sharpest highlight on the wall.
		"edge_wear": 0.55 + 0.35 * s, "edge_lift": 0.42, "curvature": 2.2,
		"dust": 0.14 * _dust_gain(tone),
		# Salt rises from the ground, so the bloom obeys the same height falloff
		# as grime but deposits pale instead of dark.
		"grime": 0.30 * _grime_gain(tone), "grime_falloff": 1.5,
		"grime_color": Color(0.36, 0.33, 0.28),
		"ao": 0.50,
	})


# --- Non-weathering materials (StandardMaterial3D) --------------------------
#
# These exist for the things the triplanar weathering shader cannot express:
# subsurface scattering, backlighting, clearcoat, transparency and anisotropy.
#
# One caveat that bit us before and will again: a tangent-space normal map needs
# a TANGENT array. LevelKit's chamfered boxes do not have one (its planar UV
# chart is deliberately not tangent-generated), so a normal map here degrades to
# the geometric normal on kit geometry and only does its job on primitive meshes
# and anything committed with generate_tangents(). Use these on props, not walls.

## Skin, with subsurface scattering. Characters only — no chroma clamp, because
## the hero is the exception the clamp exists to protect.
static func skin(tint := Color(0.78, 0.56, 0.38), tone := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = toned(tint, tone)
	m.roughness = 0.48
	m.metallic = 0.0
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.28
	m.subsurf_scatter_skin_mode = true
	m.rim_enabled = true
	m.rim = 0.45
	m.rim_tint = 0.3
	m.metallic_specular = 0.4
	return m


## Cloth with a soft sheen and no metallic component.
##
## Deliberately NOT chroma-clamped: this preset builds Wanis's shemagh and
## jacket and the Sriracha's cap and band, and those are the two things the
## reserved hue band exists for. World fabric — awnings, sacks, tarpaulins —
## uses canvas() and sacking() below, which are clamped.
static func cloth(tint := Color(0.78, 0.22, 0.14), rough := 0.78, tone := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = toned(tint, tone)
	m.roughness = rough
	m.metallic = 0.0
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.55
	m.metallic_specular = 0.25
	return m


## Canvas awning and shade cloth — café frontage, market stall, scaffold sheet.
## Thin enough that the sun comes through it, which is the entire effect: a
## backlit awning throws a coloured pool of light onto the wall behind it and is
## the cheapest beautiful thing you can put in a Libyan street.
static func canvas(tint := Color(0.78, 0.73, 0.62), tone := 0.0) -> StandardMaterial3D:
	var c := _wt(tint, tone)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.0
	m.metallic_specular = DIELECTRIC_SPECULAR
	m.roughness = 0.84
	m.roughness_texture = NoiseBank.weave(12.0, 256, 0.10)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = NoiseBank.weave_normal(12.0, 0.9)
	m.normal_scale = 0.7
	m.backlight_enabled = true
	# Warm, and darker than the albedo: light that has been through one layer of
	# cotton and lost its blue. ART_DIRECTION.md's number for perished cloth.
	m.backlight = Color(0.25, 0.22, 0.16)
	m.rim_enabled = true
	m.rim = 0.30
	m.rim_tint = 0.5
	m.uv1_scale = Vector3(2.5, 2.5, 2.5)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Woven sacking — hessian, jute, the feed and cement sacks stacked against every
## yard wall. Coarser weave, irregular yarn, no sheen whatsoever.
static func sacking(tint := Color(0.60, 0.53, 0.40), tone := 0.0) -> StandardMaterial3D:
	var c := _wt(tint, tone)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.0
	m.metallic_specular = DIELECTRIC_SPECULAR
	m.roughness = 0.95
	m.roughness_texture = NoiseBank.weave(22.0, 256, 0.45)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_enabled = true
	m.ao_texture = NoiseBank.weave(22.0, 256, 0.45)
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.4
	m.normal_enabled = true
	m.normal_texture = NoiseBank.weave_normal(22.0, 1.5)
	m.normal_scale = 1.2
	m.backlight_enabled = true
	m.backlight = Color(0.20, 0.17, 0.12)
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return m


## Automotive paint. The car is the third character in Highway to Benghazi, and
## a car reads as a car because of its clearcoat: two specular lobes, a tight
## bright one from the lacquer and a broad soft one from the basecoat under it.
##
## `flake` 0 is solid paint (a white taxi, a works pickup), 1 is metallic.
## Metallic stays 0.0 at both ends and that is not a compromise: an automotive
## basecoat is a dielectric binder, and the aluminium flakes suspended in it are
## far below a pixel. Raising METALLIC to fake them tints every reflection with
## the paint colour and turns a blue car into blue chrome.
static func auto_paint(tint := Color(0.24, 0.28, 0.34), flake := 0.0, tone := 0.0) -> StandardMaterial3D:
	var f := clampf(flake, 0.0, 1.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = _wt(tint, tone)
	m.metallic = 0.0
	m.metallic_specular = DIELECTRIC_SPECULAR
	# Flake scatters the basecoat lobe; solid paint under lacquer is near-mirror.
	m.roughness = lerpf(0.16, 0.38, f)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.04
	m.normal_enabled = true
	# Orange peel. Every mass-production paint job has it, nobody notices it, and
	# a car without it looks like a rendering of a car.
	m.normal_texture = NoiseBank.detail_normal(233, 0.55, 0.35)
	m.normal_scale = 0.35
	m.uv1_scale = Vector3(4.0, 4.0, 4.0)
	return m


## Polished gold — the chain, and later the Iced Out set dressing.
static func gold(tint := Color(1.0, 0.78, 0.30)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 1.0
	m.metallic_specular = 0.85
	m.roughness = 0.16
	return m


static func chrome(tint := Color(0.88, 0.90, 0.93), rough := 0.10) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 1.0
	m.roughness = rough
	return m


## Brushed and linished aluminium — kitchen fronts, tea trays, window sections,
## truck tanks, the alla set. Directional scratches, so the highlight smears
## along the grain instead of sitting as a point.
##
## Anisotropy and the scratch normal both read off the tangent frame, so this
## wants a mesh that has one: primitives are fine, LevelKit boxes are not.
static func brushed_aluminium(tint := Color(0.76, 0.775, 0.79), rough := 0.30) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	# Aluminium is a conductor. No art call needed and none taken.
	m.metallic = 1.0
	m.roughness = rough
	m.roughness_texture = NoiseBank.directional(239, 18.0, 0.12)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = NoiseBank.directional_normal(241, 26.0, 0.8, 0.10)
	m.normal_scale = 0.55
	m.anisotropy_enabled = true
	m.anisotropy = 0.7
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return m


## Clean glass. Dielectric: F0 for glass is about 0.04-0.05, which is what
## metallic_specular 0.5 encodes. The old metallic 0.25 was tinting the
## reflection with the glass colour, which is a thing only metals do.
static func glass(tint := Color(0.55, 0.68, 0.72, 0.30)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.0
	m.metallic_specular = 0.5
	m.roughness = 0.06
	m.refraction_enabled = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Dusty glass — which in this world is nearly all of it. Windows in Brega are
## sandblasted opaque at the bottom and filmed over at the top, and the film is
## what makes a window read as abandoned without boarding it up.
##
## `dust` 0 is a cleaned pane; 1 is scoured translucent. As the film builds it
## takes opacity, roughness and a warm cast together — a dusty pane that is still
## mirror-smooth reads as a mistake.
static func dusty_glass(tint := Color(0.52, 0.58, 0.58), dust := 0.5) -> StandardMaterial3D:
	var d := clampf(dust, 0.0, 1.0)
	var base := _wt(tint.lerp(Color(0.72, 0.68, 0.58), 0.55 * d), 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(base.r, base.g, base.b, lerpf(0.28, 0.88, d))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.0
	m.metallic_specular = 0.5
	m.roughness = lerpf(0.06, 0.62, d)
	m.roughness_texture = NoiseBank.directional(251, 9.0, 0.06)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Ice. `clarity` 0 is packed snow, 1 is a clean block you can see into.
## Not chroma-clamped: the ice levels are a deliberate break from the world
## palette and the whole point of them is that they glitter.
static func ice(clarity := 1.0, tint := Color(0.10, 0.34, 0.52)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ICE_SHADER
	m.set_shader_parameter("ice_deep", tint)
	m.set_shader_parameter("ice_bright", Color(0.46, 0.76, 0.94))
	m.set_shader_parameter("depth_gain", lerpf(0.6, 1.9, clarity))
	m.set_shader_parameter("roughness_value", lerpf(0.55, 0.08, clarity))
	m.set_shader_parameter("internal_glow", lerpf(0.04, 0.22, clarity))
	m.set_shader_parameter("frost_amount", lerpf(0.95, 0.42, clarity))
	m.set_shader_parameter("frost_noise", NoiseBank.grain(61))
	m.set_shader_parameter("sparkle_amount", lerpf(0.8, 3.2, clarity))
	return m


## Emission is light, not albedo, so the chroma law does not apply here.
static func emissive(tint: Color, energy := 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = tint
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m
