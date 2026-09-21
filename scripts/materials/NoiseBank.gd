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
