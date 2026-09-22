class_name NoiseBank
## Procedural texture supply.
##
## Every surface in this game is textured, and none of those textures ship as
## files. NoiseBank generates them once at load and hands out shared references,
## so a hundred materials cost one set of images.

static var _cache: Dictionary = {}


static func _key(parts: Array) -> String:
	return ",".join(parts.map(func(v: Variant) -> String: return str(v)))


static func noise(type: FastNoiseLite.NoiseType, frequency: float, octaves: int = 4,
		fractal: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_FBM,
		gain := 0.5, lacunarity := 2.0, seed_ := 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = frequency
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.fractal_lacunarity = lacunarity
	n.seed = seed_
	return n


static func texture(n: FastNoiseLite, size := 512, ramp: Gradient = null,
		key := "") -> NoiseTexture2D:
	if key != "" and _cache.has(key):
		return _cache[key]
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.seamless_blend_skirt = 0.18
	t.generate_mipmaps = true
	t.noise = n
	if ramp:
		t.color_ramp = ramp
	if key != "":
		_cache[key] = t
	return t


static func normal_map(n: FastNoiseLite, size := 512, bump := 1.0,
		key := "") -> NoiseTexture2D:
	if key != "" and _cache.has(key):
		return _cache[key]
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.seamless_blend_skirt = 0.18
	t.generate_mipmaps = true
	t.as_normal_map = true
	t.bump_strength = bump
	t.noise = n
	if key != "":
		_cache[key] = t
	return t


static func ramp(stops: Array) -> Gradient:
	## stops: [[offset, Color], ...]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return s[1]))
	return g


# --- Shared library ---------------------------------------------------------

## Mid-frequency blotching that breaks up tiling across a wall. Deliberately
## not low-frequency: large soft blobs read as painted-on clouds, not as a surface.
static func macro(seed_ := 11) -> NoiseTexture2D:
	return texture(noise(FastNoiseLite.TYPE_SIMPLEX, 0.016, 4, FastNoiseLite.FRACTAL_FBM,
		0.45, 2.2, seed_), 512, null, "macro%d" % seed_)


## Fine grain used as a roughness / detail mask.
static func grain(seed_ := 23) -> NoiseTexture2D:
	return texture(noise(FastNoiseLite.TYPE_VALUE_CUBIC, 0.09, 4, FastNoiseLite.FRACTAL_FBM,
		0.5, 2.3, seed_), 512, null, "grain%d" % seed_)


## Pitted, cellular surface — concrete aggregate, rust pitting, plaster.
static func pits(seed_ := 37) -> NoiseTexture2D:
	var n := noise(FastNoiseLite.TYPE_CELLULAR, 0.055, 2, FastNoiseLite.FRACTAL_FBM, 0.5, 2.0, seed_)
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	n.cellular_jitter = 1.0
	return texture(n, 512, null, "pits%d" % seed_)


## Vertical streaking — water runs, rust bleed, wall staining.
static func streaks(seed_ := 53) -> NoiseTexture2D:
	var n := noise(FastNoiseLite.TYPE_SIMPLEX, 0.03, 3, FastNoiseLite.FRACTAL_FBM, 0.5, 2.0, seed_)
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 40.0
	n.domain_warp_frequency = 0.008
	return texture(n, 512, null, "streaks%d" % seed_)


static func detail_normal(seed_ := 71, frequency := 0.12, bump := 1.6) -> NoiseTexture2D:
	return normal_map(noise(FastNoiseLite.TYPE_VALUE_CUBIC, frequency, 4,
		FastNoiseLite.FRACTAL_FBM, 0.52, 2.2, seed_), 512, bump,
		"dn%d_%.3f_%.2f" % [seed_, frequency, bump])


## Analytic corrugation: sheet-metal ridges computed exactly rather than
## approximated with noise, so the profile is a real sine and the highlight runs
## clean along the ridge. Costs two triangles instead of forty.
static func corrugation_normal(period_px := 32.0, strength := 2.2, size := 256) -> ImageTexture:
	var key := "corr_%.1f_%.2f_%d" % [period_px, strength, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var k := TAU / period_px
	for x in size:
		# h(x) = sin(kx) -> dh/dx = k cos(kx); tangent-space normal is (-dh/dx, 0, 1)
		var slope := -strength * k * cos(k * float(x)) * period_px * 0.25
		var n := Vector3(slope, 0.0, 1.0).normalized()
		var c := Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)
		for y in size:
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Flat ridge mask matching corrugation_normal — darkens the troughs.
static func corrugation_mask(period_px := 32.0, size := 256) -> ImageTexture:
	var key := "corrmask_%.1f_%d" % [period_px, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var k := TAU / period_px
	for x in size:
		var v := 0.5 + 0.5 * sin(k * float(x))
		var c := Color(0.35 + 0.65 * v, 0.35 + 0.65 * v, 0.35 + 0.65 * v)
		for y in size:
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func rough_normal(seed_ := 83, frequency := 0.045, bump := 3.2) -> NoiseTexture2D:
	return normal_map(noise(FastNoiseLite.TYPE_CELLULAR, frequency, 3,
		FastNoiseLite.FRACTAL_FBM, 0.5, 2.0, seed_), 512, bump,
		"rn%d_%.3f_%.2f" % [seed_, frequency, bump])


# --- Cache probe -------------------------------------------------------------

## Every generator below builds its key first and asks here before doing any
## work. The image-loop generators cost real milliseconds and several hundred
## materials are built during a level load, so "check the key, then build" is
## the only acceptable order.
static func _hit(key: String) -> Variant:
	return _cache.get(key, null)


# --- Extended library -------------------------------------------------------

## Paint chipping / worn-edge mask. High contrast on purpose: wear is a binary
## event (the paint is there or it isn't) and a soft gradient reads as an airbrushed
## stain instead of a chip. The ramp does the hardening, so the noise stays cheap.
static func worn_edge(seed_ := 101, bias := 0.5) -> NoiseTexture2D:
	var key := "worn%d_%.2f" % [seed_, bias]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var n := noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.035, 5, FastNoiseLite.FRACTAL_FBM,
		0.58, 2.4, seed_)
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 22.0
	n.domain_warp_frequency = 0.02
	var edge := clampf(bias, 0.08, 0.92)
	var g := ramp([
		[0.0, Color.BLACK],
		[maxf(edge - 0.06, 0.0), Color(0.06, 0.06, 0.06)],
		[minf(edge + 0.06, 1.0), Color(0.94, 0.94, 0.94)],
		[1.0, Color.WHITE],
	])
	return texture(n, 512, g, key)


## Directional streak noise — the single most useful texture in a weathered game,
## because weathering rule #1 is that everything runs downward.
##
## The stretch is done by generating a NON-SQUARE seamless texture: 512 x (512/stretch).
## Both axes still map to 0..1 in UV, so the short axis has proportionally fewer
## noise cycles and the features come out elongated along it. That costs nothing —
## the alternative (per-pixel anisotropic sampling in GDScript) costs a quarter of
## a million noise calls per texture.
static func directional(seed_ := 131, stretch := 6.0, frequency := 0.05) -> NoiseTexture2D:
	var key := "dir%d_%.2f_%.3f" % [seed_, stretch, frequency]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var h := int(clampf(512.0 / maxf(stretch, 1.0), 8.0, 512.0))
	var n := noise(FastNoiseLite.TYPE_SIMPLEX, frequency, 4, FastNoiseLite.FRACTAL_FBM,
		0.5, 2.1, seed_)
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 14.0
	n.domain_warp_frequency = 0.03
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = h
	t.seamless = true
	t.seamless_blend_skirt = 0.18
	t.generate_mipmaps = true
	t.noise = n
	_cache[key] = t
	return t


## Anisotropic scratch normal — brushed and linished metal. Same non-square trick,
## with the bump strength doing the work the geometry never will.
static func directional_normal(seed_ := 137, stretch := 24.0, bump := 0.9,
		frequency := 0.09) -> NoiseTexture2D:
	var key := "dirn%d_%.2f_%.2f_%.3f" % [seed_, stretch, bump, frequency]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var h := int(clampf(512.0 / maxf(stretch, 1.0), 4.0, 512.0))
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = h
	t.seamless = true
	t.seamless_blend_skirt = 0.12
	t.generate_mipmaps = true
	t.as_normal_map = true
	t.bump_strength = bump
	t.noise = noise(FastNoiseLite.TYPE_VALUE, frequency, 3, FastNoiseLite.FRACTAL_FBM,
		0.55, 2.6, seed_)
	_cache[key] = t
	return t


## Flat-valued Voronoi cells. RETURN_CELL_VALUE gives each cell one constant value,
## which is what spalling actually looks like — a patch of render either has let go
## or it hasn't, and the boundary is a hard edge following an aggregate line.
## Also the cheapest way to give a tiled ceramic run per-tile colour jitter.
static func cells(seed_ := 149, jitter := 0.95, frequency := 0.05) -> NoiseTexture2D:
	var key := "cells%d_%.2f_%.3f" % [seed_, jitter, frequency]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var n := noise(FastNoiseLite.TYPE_CELLULAR, frequency, 1, FastNoiseLite.FRACTAL_NONE,
		0.5, 2.0, seed_)
	n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	n.cellular_jitter = jitter
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	return texture(n, 512, null, key)


## Soft round blooms — rust breaking out from a single nucleation point, salt
## efflorescence, damp patches. Distance-from-cell-centre with a ramp that keeps
## the core solid and lets the edge dissolve, so it never reads as polka dots.
static func blooms(seed_ := 157, frequency := 0.028) -> NoiseTexture2D:
	var key := "bloom%d_%.3f" % [seed_, frequency]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var n := noise(FastNoiseLite.TYPE_CELLULAR, frequency, 3, FastNoiseLite.FRACTAL_FBM,
		0.45, 2.0, seed_)
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	n.cellular_jitter = 1.0
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 18.0
	n.domain_warp_frequency = 0.02
	var g := ramp([
		[0.0, Color.WHITE],
		[0.34, Color(0.86, 0.86, 0.86)],
		[0.72, Color(0.18, 0.18, 0.18)],
		[1.0, Color.BLACK],
	])
	return texture(n, 512, g, key)


## Crack network for failed cement render. DISTANCE2_SUB is near zero exactly on a
## cell boundary and climbs away from it, so a steep ramp turns the boundaries into
## thin dark lines — a real connected network with junctions, not scratches.
## `density` is cells per texture; low numbers give a few long structural cracks,
## high numbers give crazing.
static func cracks(seed_ := 163, density := 0.045, width := 0.09) -> NoiseTexture2D:
	var key := "crack%d_%.3f_%.3f" % [seed_, density, width]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var n := noise(FastNoiseLite.TYPE_CELLULAR, density, 1, FastNoiseLite.FRACTAL_NONE,
		0.5, 2.0, seed_)
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.cellular_jitter = 1.0
	# A crack wanders. Straight cell boundaries are the tell that this is Voronoi.
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 26.0
	n.domain_warp_frequency = 0.045
	var w := clampf(width, 0.02, 0.4)
	var g := ramp([
		[0.0, Color.BLACK],
		[w, Color(0.10, 0.10, 0.10)],
		[minf(w + 0.10, 0.98), Color.WHITE],
		[1.0, Color.WHITE],
	])
	return texture(n, 512, g, key)


## Blue-noise-ish dither tile, for breaking up gradient banding in fog cards,
## sky domes and long falloffs where 8-bit output stair-steps.
##
## This is the R2 low-discrepancy sequence, not true void-and-cluster blue noise:
## it has no low-frequency clumping (which is the property that matters for
## dithering) and it generates in a single pass instead of minutes of optimisation.
## It does not tile perfectly, but dither noise is sampled at pixel frequency where
## a seam is by definition invisible.
static func dither(size := 64) -> ImageTexture:
	var key := "dither%d" % size
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	# Plastic-constant increments: the 2D generalisation of the golden ratio.
	const A1 := 0.7548776662466927
	const A2 := 0.5698402909980532
	for y in size:
		for x in size:
			var v := fposmod(float(x) * A1 + float(y) * A2, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	# No mipmaps: averaging a dither pattern defeats the point of having one.
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Fine mineral granules — bitumen felt, sandpaper-grade roofing, grit.
static func granule(seed_ := 173) -> NoiseTexture2D:
	var key := "gran%d" % seed_
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var n := noise(FastNoiseLite.TYPE_CELLULAR, 0.34, 2, FastNoiseLite.FRACTAL_FBM,
		0.6, 2.4, seed_)
	n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	n.cellular_jitter = 1.0
	var g := ramp([
		[0.0, Color(0.22, 0.22, 0.22)],
		[0.5, Color(0.70, 0.70, 0.70)],
		[1.0, Color.WHITE],
	])
	return texture(n, 512, g, key)


# --- Analytic patterns ------------------------------------------------------
#
# Anything with a manufactured rhythm — tile courses, woven cloth — is computed
# exactly rather than approximated with noise. Noise cannot make a straight grout
# line, and a wobbly grout line is the difference between a tiled wall and a
# photograph of a tiled wall held up behind the camera.

static func _cell_hash(ix: int, iy: int, salt: int) -> float:
	var h := (ix * 374761393 + iy * 668265263 + salt * 2147483647) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


## Glazed tile field: grout lines plus per-tile value jitter (no two fired tiles
## come out of the kiln the same, and a perfectly uniform tile run is the giveaway).
static func tile_mask(cols := 8, grout := 0.055, size := 256, salt := 3) -> ImageTexture:
	var key := "tile_%d_%.3f_%d_%d" % [cols, grout, size, salt]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var c := float(maxi(cols, 1))
	for y in size:
		var v := float(y) / float(size) * c
		var iy := int(floor(v))
		var fy: float = v - float(iy)
		for x in size:
			var u := float(x) / float(size) * c
			var ix := int(floor(u))
			var fx: float = u - float(ix)
			var in_grout: bool = fx < grout or fx > 1.0 - grout or fy < grout or fy > 1.0 - grout
			var val := 0.30 if in_grout else 0.80 + 0.20 * _cell_hash(ix, iy, salt)
			img.set_pixel(x, y, Color(val, val, val))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Matching bevelled-edge normal for tile_mask. The bevel is what catches the sun
## along a tiled dado and turns a flat plane into a hundred little highlights.
static func tile_normal(cols := 8, grout := 0.055, bevel := 0.045, strength := 1.6,
		size := 256) -> ImageTexture:
	var key := "tilen_%d_%.3f_%.3f_%.2f_%d" % [cols, grout, bevel, strength, size]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var c := float(maxi(cols, 1))
	var b := maxf(bevel, 0.005)
	for y in size:
		var v := float(y) / float(size) * c
		var fy: float = v - floor(v)
		var dy := 0.0
		if fy < grout + b and fy > grout:
			dy = strength
		elif fy > 1.0 - grout - b and fy < 1.0 - grout:
			dy = -strength
		for x in size:
			var u := float(x) / float(size) * c
			var fx: float = u - floor(u)
			var dx := 0.0
			if fx < grout + b and fx > grout:
				dx = strength
			elif fx > 1.0 - grout - b and fx < 1.0 - grout:
				dx = -strength
			# Tangent-space normal from the height gradient: n = normalize(-dh/du, -dh/dv, 1)
			var n := Vector3(-dx, -dy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Over-under weave for canvas awning and jute sacking. Two phase-shifted sines
## selected by a checker — that is literally how a plain weave works, and it gives
## the correct alternating highlight that a noise texture never will.
static func weave(period_px := 14.0, size := 256, coarse := 0.0) -> ImageTexture:
	var key := "weave_%.1f_%d_%.2f" % [period_px, size, coarse]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var k := TAU / maxf(period_px, 2.0)
	for y in size:
		var sy := 0.5 + 0.5 * sin(k * float(y))
		var cy := int(floor(float(y) / period_px))
		for x in size:
			var sx := 0.5 + 0.5 * sin(k * float(x))
			var cx := int(floor(float(x) / period_px))
			# Warp over weft on alternating squares.
			var over: bool = ((cx + cy) & 1) == 0
			var v: float = sx if over else sy
			# Coarse cloth is irregular — hessian yarn is not machine-even.
			if coarse > 0.0:
				v = clampf(v + (_cell_hash(cx, cy, 7) - 0.5) * coarse, 0.0, 1.0)
			var g := 0.42 + 0.58 * v
			img.set_pixel(x, y, Color(g, g, g))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Normal map for the same weave. Slope follows the derivative of the selected
## sine, so the thread that is on top is the one that catches the light.
static func weave_normal(period_px := 14.0, strength := 1.1, size := 256) -> ImageTexture:
	var key := "weaven_%.1f_%.2f_%d" % [period_px, strength, size]
	var cached: Variant = _hit(key)
	if cached != null:
		return cached
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var k := TAU / maxf(period_px, 2.0)
	var amp := strength * k * period_px * 0.22
	for y in size:
		var cy := int(floor(float(y) / period_px))
		var dy_full := -amp * cos(k * float(y))
		for x in size:
			var cx := int(floor(float(x) / period_px))
			var over: bool = ((cx + cy) & 1) == 0
			var dx := -amp * cos(k * float(x)) if over else 0.0
			var dy := 0.0 if over else dy_full
			var n := Vector3(dx, dy, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
