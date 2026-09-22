class_name DecalKit
## Procedural surface weathering: the layer that stops a wall being clean.
##
## `PropKit` builds the wall. This builds what fifty years of sun, salt, diesel
## and hands did to it. Nothing here ships as an image: a texture factory stamps
## falloff, branching and erosion into small `ImageTexture`s at load, and the
## placement helpers scatter quads of them with deterministic randomness, so a
## wall comes back identical every run without a single PNG in the repository.
##
## It extends the principle `PropKit._decal_texture` established — a
## one-dimensional gradient cannot fade on two axes, so a dirt run that does not
## fade sideways reads as a grey rectangle stuck to the wall — to seven more
## shapes that a gradient cannot express at all: a crack has to branch, a
## splatter has to throw satellites, a tyre tread has to repeat, a torn poster
## has to have an edge that is not a straight line.
##
## Everything obeys the weathering law in docs/ART_DIRECTION.md: gravity (every
## stain runs down, from something), aspect (sun faces bleach, sheltered faces
## keep their saturation), wind (scour and sand drift in the bottom 1.5 m) and
## occupancy (hands and tyres only reach where people and vehicles go).
##
## --- THE Z OFFSET -----------------------------------------------------------
##
## Decals are quads floating just off the surface they dirty. Two numbers:
##
##     OFFSET_FIRST = 0.015    the first decal layer off the face
##     OFFSET_STEP  = 0.004    every layer after it
##
## `PropKit.prefab_facade` already parks its own weathering at 0.008–0.014 in
## front of a wall face, so 15 mm is where this kit starts and nothing of ours
## lands coplanar with one of its streaks. Five layers at 4 mm is 31 mm of total
## stand-off: at the fixed 16-unit camera distance that is 0.3% of the visible
## frame height — far too little to read as a float — and enormously more than
## the depth buffer needs there (near = 0.5, far = 1200, so precision at 16
## units is sub-millimetre).
##
## The subtler half: alpha-blended surfaces do not write depth, so two coplanar
## decals cannot z-fight at all. They fight for *sort order* instead, and Godot
## sorts the transparent queue by `render_priority` first and object distance
## second — and a MultiMesh sorts as one object, by its whole AABB. So the layer
## index sets `render_priority` as well as the offset. That is what guarantees
## paint lands on paper, paper on grime, from every camera position, forever.
##
## --- BUDGET -----------------------------------------------------------------
##
## A decal casts no shadow, writes no depth and costs almost nothing in vertex
## work. Its entire cost is blended fragments, so the number that matters is
## screen coverage, not instance count. One screen at the gameplay plane is
## 9.78 × 17.4 world units.
##
## Sane budget for one wall — meaning the ~17 × 10 units of it on screen at once:
##
##   * 12–20 decals, of which at most THREE are larger than 4 × 3 units.
##   * No pixel under more than 3 decal layers. Overlap is both the real cost
##     and the thing that turns weathering into mud.
##   * Roughly 2.5 screens of blended coverage in total. Past that a 1080p
##     Forward+ frame starts to show it on integrated-class hardware.
##   * `scatter_on_wall` batches every small decal into one MultiMesh per shape,
##     so fifteen scuffs are one draw call. The budget above is a fill-rate
##     budget, not a draw-call budget — do not "save" by placing fewer, larger
##     decals, which is strictly worse on both counts.
##
## Posters, stencils and graffiti are authored, not scattered: one to three per
## wall, placed where the composition wants the eye. Ten of them is a mural, and
## a mural reads as clutter.
##
## Small-decal groups carry a `visibility_range_end` so they fade out entirely
## past the deep-background band, where a 20 cm scuff is sub-pixel anyway.
##
## The other budget is load time. Each image costs roughly 20–50 ms to paint in
## GDScript and is built on first use, so a level that touches all eight shapes
## on all four variants pays about half a second once. Reuse variants where the
## repeat will not show — `scatter_on_wall` already spends its variety on roll,
## scale and per-instance alpha, which are free.

const OFFSET_FIRST := 0.015
const OFFSET_STEP := 0.004

## Sort layers. Low numbers sit against the wall, high numbers on top of
## everything. Also the `render_priority`, also the z-offset index.
const LAYER_GRIME := 0   ## broad tonal dirt, sand drift, salt bloom
const LAYER_RUN := 1     ## streaks and splatters, which run over the grime
const LAYER_MARK := 2    ## cracks, scuffs, tyre tracks — damage, not dirt
const LAYER_PAPER := 3   ## posters, pasted paper
const LAYER_PAINT := 4   ## stencils, signage, graffiti

# --- Tints ------------------------------------------------------------------
#
# Weathering colour is never neutral grey and never black — see the colour
# script. These are the World 1 dirt family, and callers override per level.

const GRIME := Color(0.085, 0.068, 0.055)   ## the standard dark warm runoff
const SOOT := Color(0.062, 0.056, 0.052)    ## flare and fire staining
const DUST := Color(0.72, 0.63, 0.47)       ## pale wind-blown sand over a surface
const SALT := Color(0.80, 0.775, 0.71)      ## the damp band that eats a coastal wall
const RUST := Color(0.42, 0.19, 0.09)       ## bleed from a bolt, bracket or scupper
const OIL := Color(0.050, 0.045, 0.050)     ## diesel and gear oil on a yard floor
const MUD := Color(0.30, 0.22, 0.14)        ## wet sabkha carried on a tyre
const CRACK_INK := Color(0.14, 0.12, 0.10)  ## the dark inside a split in concrete
const PAPER := Color(0.845, 0.815, 0.735)   ## sun-yellowed newsprint
const INK := Color(0.11, 0.10, 0.10)        ## printing on it
const PAINT_WHITE := Color(0.90, 0.88, 0.81)
const PAINT_YELLOW := Color(0.86, 0.66, 0.12)  ## hazard yellow — the danger signal
const PAINT_SAGE := Color(0.37, 0.54, 0.36)
const SPRAY_BLACK := Color(0.10, 0.093, 0.090)
const SPRAY_BLUE := Color(0.21, 0.29, 0.41)
# Deliberately no spray red. Hue 340°–25° is capped at S 0.55 / V 0.72 project
# wide and reserved for Wanis's shemagh and the Sriracha; a red tag on a wall
# would be the only thing competing with him in the frame.

# --- Text banks -------------------------------------------------------------
#
# Invented but plausible, neutral, and correctly written. Arabic is cursive and
# RTL; Godot's TextServer shapes and orders it, so the strings below are written
# the way they are read. Libyan signage uses Western digits, never Eastern
# Arabic numerals. Bilingual safety signage is correct INSIDE an industrial
# plant and is the only place in this game where it is correct.

const HAZARD_AR: PackedStringArray = [
	"خطر",              # danger
	"ممنوع الاقتراب",    # do not approach
	"ممنوع التدخين",     # no smoking
	"منطقة خطرة",        # hazardous area
	"ممنوع الدخول",      # no entry
	"مخرج",             # exit
]
const HAZARD_EN: PackedStringArray = [
	"DANGER", "NO SMOKING", "NO ENTRY", "AUTHORISED PERSONNEL ONLY", "EXIT",
]
## Plant identification: unit numbers and equipment tags, the way a process
## plant actually labels itself.
const UNIT_AR: PackedStringArray = [
	"وحدة 2", "وحدة 4", "وحدة 7", "محطة الضخ", "الصيانة", "خزان 3",
]
const UNIT_TAGS: PackedStringArray = [
	"P-104", "P-207", "V-22", "TK-7", "E-311", "LP-06", "B-2",
]
## Shopfronts for the town levels — the trades a crossroads town runs on.
const SHOP_AR: PackedStringArray = [
	"مخبز",          # bakery
	"بقالة",         # grocer
	"ورشة",          # workshop
	"قطع غيار",      # spare parts
	"مطعم",          # restaurant
	"كهرباء",        # electrical
]
## Graffiti. Neutral marks only: initials, numbers, a football score, an
## invented club-style scrawl. Nothing political, religious or personal.
const TAGS: PackedStringArray = [
	"صقور", "الواحة", "2 - 1", "WNS", "84", "M A", "7",
]


# ============================================================================
#  TEXTURE FACTORY
# ============================================================================

## The eight shapes. Every one of them exists because a gradient could not do it.
const SHAPES: PackedStringArray = [
	"blob",      # soft irregular patch — broad tonal dirt
	"run",       # directional streak with internal striations
	"splatter",  # a core plus thrown satellites
	"crack",     # a branching line drawn into the image
	"tread",     # repeating tyre lug pattern
	"scuff",     # swept arcs, the mark of something dragged
	"torn",      # noise-eroded rectangle — paper
	"patch",     # lightly eroded rectangle with flake holes — paint
]

# Sizes are per shape and deliberately non-square where the shape is. A crack at
# 64 px is one aliased pixel wide; a tread strip needs resolution along its
# length and almost none across it.
const _SHAPE_SIZE := {
	"blob": Vector2i(64, 64),
	"run": Vector2i(48, 128),
	"splatter": Vector2i(96, 96),
	"crack": Vector2i(144, 144),
	"tread": Vector2i(56, 192),
	"scuff": Vector2i(128, 96),
	"torn": Vector2i(112, 112),
	"patch": Vector2i(112, 88),
}

## Four cuts of every shape. One crack image repeated twelve times on a wall is
## wallpaper, and the eye finds a repeat faster than it finds anything else.
const VARIANTS := 4

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _unit_quad_mesh: QuadMesh = null


## A generated alpha mask for one shape. Cached by shape and variant, built on
## first request — a level that never places a crack never pays for one.
static func shape_texture(shape := "blob", variant := 0) -> ImageTexture:
	var v := posmod(variant, VARIANTS)
	var key := "%s:%d" % [shape, v]
	if _tex_cache.has(key):
		return _tex_cache[key]

	var size: Vector2i = _SHAPE_SIZE.get(shape, Vector2i(64, 64))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shape) * 131 + v * 7919 + 17

	var a := PackedFloat32Array()
	a.resize(size.x * size.y)

	match shape:
		"run":
			_paint_run(a, size, rng)
		"splatter":
			_paint_splatter(a, size, rng)
		"crack":
			_paint_crack(a, size, rng)
		"tread":
			_paint_tread(a, size, rng)
		"scuff":
			_paint_scuff(a, size, rng)
		"torn":
			# A poster tears at the bottom and the corners and stays stuck along
			# the top, because that is where the paste went.
			_paint_sheet(a, size, rng, 0.075, 0.130, 0.016, rng.randi_range(2, 3), true)
		"patch":
			# Paint does not tear, it flakes: an almost-straight edge with
			# clusters of small losses through the field.
			_paint_sheet(a, size, rng, 0.018, 0.026, 0.014, rng.randi_range(6, 10))
		_:
			_paint_blob(a, size, rng)

	# Every shape fades to nothing at the image border. The material clamps
	# rather than repeats, and a decal whose alpha is non-zero at the edge shows
	# the quad's own straight edge — which is the single loudest tell there is.
	_feather_border(a, size, 1)

	var tex := _texture_from_alpha(a, size)
	_tex_cache[key] = tex
	return tex


## White RGB, coverage in alpha. The tint comes from `albedo_color`, exactly as
## `PropKit.gradient_decal` does it, so one image serves every colour of dirt.
static func _texture_from_alpha(a: PackedFloat32Array, size: Vector2i) -> ImageTexture:
	var data := PackedByteArray()
	data.resize(size.x * size.y * 4)
	for i in a.size():
		var o := i * 4
		data[o] = 255
		data[o + 1] = 255
		data[o + 2] = 255
		data[o + 3] = int(clampf(a[i], 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
	# Mipmaps are not optional here: a 160 px crack seen at fifty units without
	# them is a field of crawling white sparkles.
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _feather_border(a: PackedFloat32Array, size: Vector2i, px: int) -> void:
	for y in size.y:
		for x in size.x:
			var edge := mini(mini(x, size.x - 1 - x), mini(y, size.y - 1 - y))
			if edge < px:
				a[y * size.x + x] *= float(edge) / float(px)


# --- Shape painters ---------------------------------------------------------

## A soft irregular patch: the workhorse, used for every broad tonal stain.
##
## Three things had to be true and the first two attempts got them wrong. The
## radius is warped by noise sampled AROUND the circle (so it closes seamlessly)
## rather than by a sum of sine lobes, which produced a five-petalled flower.
## The core stays solid and only the outer 45% falls off, because a stain is a
## patch with a soft edge, not a blurred dot. And the noise eats the RIM rather
## than multiplying the whole field, which is what stopped the middle reading
## as hollow.
static func _paint_blob(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var s := rng.randi()
	# Keep the warp SMALL and sample the noise on a SMALL circle. Both matter:
	# a big circle crosses five or six lattice cells on its way round and the
	# patch comes out as a five-petalled flower, which is how the first two
	# versions of this failed. A stain is an irregular oval, not a rosette.
	var warp := rng.randf_range(0.09, 0.17)
	var squash := rng.randf_range(0.72, 1.32)
	var lean := rng.randf_range(0.0, TAU)
	for y in size.y:
		for x in size.x:
			var u := ((float(x) + 0.5) / float(size.x) - 0.5) * 2.0
			var v := ((float(y) + 0.5) / float(size.y) - 0.5) * 2.0 / squash
			var d := sqrt(u * u + v * v)
			var ang := atan2(v, u) + lean
			# Noise indexed by a point ON a circle: continuous all the way
			# round, so there is no seam where the angle wraps.
			var r := 0.98 * (1.0 - warp
				+ warp * 2.0 * _vnoise(cos(ang) * 0.8 + 8.0, sin(ang) * 0.8 + 8.0, s)
				+ warp * 0.5 * (_vnoise(cos(ang) * 1.9 + 3.0, sin(ang) * 1.9 + 3.0, s + 4) - 0.5))
			# The falloff occupies nearly the whole radius. A hard-edged patch
			# is an oil slick; broad tonal dirt is almost all gradient, with
			# only the centre near full strength.
			var t := clampf((r - d) / maxf(r * 0.92, 0.02), 0.0, 1.0)
			t = pow(t * t * (3.0 - 2.0 * t), 1.25)
			var n := _fbm(float(x) * 0.07, float(y) * 0.07, s + 9, 2)
			a[y * size.x + x] = clampf(t * (0.62 + 0.62 * n), 0.0, 1.0)


## A directional run. Real runoff is a bundle of fine streaks of different
## lengths, not one soft smear — so the length, intensity and edge of every
## column are drawn separately, and the top few percent (the source, right under
## the lip) is the darkest part of it.
static func _paint_run(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var s := rng.randi()
	for x in size.x:
		var cu := (float(x) + 0.5) / float(size.x)
		# Two scales of variation, and both are needed. The per-column hash
		# gives the fine striation; the low-frequency envelope makes the run
		# CLUMP, and without it the whole thing reads as a comb.
		var dens := clampf(1.9 * _fbm(cu * 2.8, 0.5, s + 21, 2) - 0.32, 0.0, 1.25)
		var reach := lerpf(0.12, 1.0, pow(_hash2(x, 0, s), 1.5)) * clampf(dens, 0.0, 1.2)
		var intensity := (0.45 + 0.55 * _hash2(x, 7, s)) * clampf(dens, 0.2, 1.15)
		var side := pow(sin(cu * PI), 1.1)
		for y in size.y:
			var v := (float(y) + 0.5) / float(size.y)
			var t := clampf((reach - v) / maxf(reach, 0.05), 0.0, 1.0)
			t = pow(t, 1.25)
			var n := 0.75 + 0.5 * _fbm(float(x) * 0.55, float(y) * 0.14, s + 3, 2)
			# The wash: right under the lip the streaks have not separated out
			# yet, so the top of the run is a sheet and only below it does it
			# break into fingers. Skipping this leaves a fringe of loose hairs
			# hanging off nothing.
			var wash := exp(-v * 5.5) * 0.55 * clampf(dens, 0.0, 1.0)
			a[y * size.x + x] = clampf(
				(t * intensity * n + wash) * side * 0.92, 0.0, 1.0)


## A thrown splatter: one core, satellites that get smaller the further they
## flew, and a few radial flicks. The size-versus-distance relationship is the
## whole read — uniform dots are confetti.
static func _paint_splatter(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var cx := float(size.x) * rng.randf_range(0.42, 0.58)
	var cy := float(size.y) * rng.randf_range(0.40, 0.55)
	var reach := float(size.x) * 0.44
	# The core is three overlapping discs, not one. A single disc is a dot, and
	# the eye reads a dot as deliberate.
	for _c in 3:
		_stamp(a, size, cx + rng.randf_range(-0.07, 0.07) * float(size.x),
			cy + rng.randf_range(-0.06, 0.06) * float(size.y),
			float(size.x) * rng.randf_range(0.055, 0.105), 0.62)

	for _i in rng.randi_range(22, 34):
		var ang := rng.randf() * TAU
		var dist := pow(rng.randf(), 0.6) * reach
		var r := lerpf(float(size.x) * 0.050, float(size.x) * 0.011, dist / reach)
		# Droplets that flew furthest are smaller AND fainter — that pairing is
		# what reads as thrown rather than as scattered dots.
		_stamp(a, size, cx + cos(ang) * dist, cy + sin(ang) * dist * 0.88,
			r * rng.randf_range(0.55, 1.45),
			rng.randf_range(0.30, 0.95) * (1.0 - 0.45 * dist / reach))

	# Flicks: two or three tails, short, starting at the edge of the core and
	# curving as they go. Long straight rays out of the centre make a star, and
	# a star is the single most common way a procedural splatter goes wrong.
	for _i in rng.randi_range(1, 2):
		var ang := rng.randf() * TAU
		var curl := rng.randf_range(-0.6, 0.6)
		var len_ := reach * rng.randf_range(0.20, 0.40)
		var start := float(size.x) * rng.randf_range(0.05, 0.09)
		var steps := maxi(int(len_ * 0.9), 3)
		for k in steps:
			var t := float(k) / float(steps - 1)
			var th := ang + curl * t * t
			var d := start + len_ * t
			_stamp(a, size, cx + cos(th) * d, cy + sin(th) * d,
				lerpf(float(size.x) * 0.016, 0.7, t), 0.5 * (1.0 - t * 0.85))


## A crack, walked rather than drawn. It starts at an edge, wanders toward the
## far side, tapers as it goes and throws branches — which is the only thing
## that separates a crack from a scratch. The faint wide halo under the core is
## the dust and micro-spalling that a real split always carries with it.
static func _paint_crack(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var w := float(size.x)
	var h := float(size.y)
	var start := Vector2(rng.randf_range(0.18, 0.82) * w, h * 0.02)
	var heading := PI * 0.5 + rng.randf_range(-0.45, 0.45)

	# Each entry: position, heading, remaining length, width.
	var queue: Array = [[start, heading, h * rng.randf_range(0.95, 1.20), 2.4]]
	var guard := 0
	while not queue.is_empty() and guard < 24:
		guard += 1
		var seg: Array = queue.pop_front()
		var p: Vector2 = seg[0]
		var dir: float = seg[1]
		var life: float = seg[2]
		var width: float = seg[3]
		var steps := int(life)
		for k in steps:
			var t := float(k) / float(maxi(steps - 1, 1))
			# Heading wanders, but is pulled back toward the original run so the
			# crack crosses the surface instead of curling into a ball.
			dir = lerpf(dir + rng.randf_range(-0.38, 0.38), seg[1], 0.06)
			p += Vector2(cos(dir), sin(dir))
			if p.x < -4.0 or p.x > w + 4.0 or p.y < -4.0 or p.y > h + 4.0:
				break
			var cw := maxf(width * (1.0 - t * 0.75), 0.45)
			_stamp_max(a, size, p.x, p.y, cw * 3.6, 0.10)
			_stamp(a, size, p.x, p.y, cw, 1.0)
			# Branches taper hard and never branch again past a certain width,
			# or the image fills in and stops being a line.
			if width > 0.85 and rng.randf() < 0.032:
				queue.append([p, dir + (0.7 if rng.randf() < 0.5 else -0.7),
					life * (1.0 - t) * rng.randf_range(0.35, 0.65), cw * 0.62])


## A tyre tread. Two lanes of angled lugs offset by half a pitch, a rib down the
## centre that never leaves the road, and per-lug wear. The half-pitch offset is
## what makes it read as a tyre rather than a ladder.
static func _paint_tread(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var s := rng.randi()
	var lugs := rng.randi_range(8, 12)
	var skew := rng.randf_range(0.30, 0.70)
	for y in size.y:
		var v := (float(y) + 0.5) / float(size.y)
		for x in size.x:
			var u := (float(x) + 0.5) / float(size.x)
			# Three ribs separated by circumferential grooves. The grooves are
			# the whole read: without them the lugs merge across the width and
			# the strip comes out as a zip fastener.
			var band := u * 3.0
			var bi := clampi(int(band), 0, 2)
			var bf := band - float(bi)
			var groove := smoothstep(0.0, 0.16, bf) * (1.0 - smoothstep(0.84, 1.0, bf))
			var lug := 1.0
			if bi == 1:
				# The centre rib is near-continuous — it never leaves the road
				# — but it is notched, or it reads as a solid spine.
				var notch := v * float(lugs) * 2.0
				lug = 0.42 + (0.16 if notch - floorf(notch) >= 0.45 else 0.0)
			else:
				var phase := v * float(lugs) + float(bi) * 0.5 \
					+ (bf - 0.5) * skew
				var f := phase - floorf(phase)
				lug = smoothstep(0.04, 0.20, f) * (1.0 - smoothstep(0.60, 0.78, f))
				# A chunked-out lug here and there. A perfect tread belongs on
				# a new tyre and there are none of those in this world.
				if _hash2(int(floorf(phase)), bi, s) < 0.11:
					lug *= 0.18
			var edge := 1.0 - smoothstep(0.62, 1.0, absf(u - 0.5) * 2.0)
			var wear := 0.58 + 0.66 * _fbm(float(x) * 0.26, float(y) * 0.09, s, 2)
			a[y * size.x + x] = clampf(lug * groove * edge * wear, 0.0, 1.0)


## Scuff arcs: the mark left by a door bottom, a barrow, a shoulder or a gate
## swinging on the same pivot for decades. Arcs share one centre — that shared
## centre is the entire read, and it is why scuffs cannot be scattered scratches.
static func _paint_scuff(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var w := float(size.x)
	var h := float(size.y)
	var pivot := Vector2(w * rng.randf_range(-0.35, 0.15), h * rng.randf_range(0.95, 1.5))
	# Most of the passes are BROAD and faint — a rubbed, dirty area. Only two or
	# three are sharp. Sharp strokes alone came out as a tuft of grass; the
	# smear underneath them is what makes it read as wear on a surface.
	var broad := rng.randi_range(12, 16)
	var sharp := rng.randi_range(1, 2)
	# The sweep the whole mark occupies. Every pass lives inside it, which is
	# what turns a set of strokes into one rubbed AREA.
	# ONE radius with a little jitter, not a spread. Spreading the radii drew
	# a rainbow of concentric bands; overlapping them at nearly the same radius
	# builds a single dirty sweep, which is what a scuff is.
	var base_r := pivot.distance_to(Vector2(w * rng.randf_range(0.45, 0.70),
		h * rng.randf_range(0.25, 0.50)))
	for i in broad + sharp:
		var is_broad := i < broad
		var r := base_r * rng.randf_range(0.82, 1.18)
		var a0 := rng.randf_range(-1.15, -0.55)
		var a1 := a0 + rng.randf_range(0.75, 1.25)
		var brush := rng.randf_range(4.0, 8.5) if is_broad else rng.randf_range(0.55, 1.1)
		var strength := rng.randf_range(0.035, 0.085) if is_broad \
			else rng.randf_range(0.28, 0.55)
		var steps := maxi(int(r * absf(a1 - a0) * 1.2), 3)
		for k in steps:
			var t := float(k) / float(steps - 1)
			var ang := lerpf(a0, a1, t)
			# Pressure rises and falls across the sweep; a constant-alpha arc
			# reads as a drawn line rather than as contact. The broad passes
			# keep a floor under them so they overlap into a continuous smear
			# instead of a bundle of leaf shapes.
			var press := (0.55 + 0.45 * sin(t * PI)) if is_broad else sin(t * PI)
			_stamp(a, size, pivot.x + cos(ang) * r, pivot.y + sin(ang) * r,
				brush, strength * press)


## A rectangle eroded by noise on every edge, with holes punched through it.
## `torn` and `patch` are the same generator with different amplitudes: paper
## tears in long ragged bites, paint flakes in small round ones.
static func _paint_sheet(a: PackedFloat32Array, size: Vector2i,
		rng: RandomNumberGenerator, side_amp: float, bottom_amp: float,
		top_amp: float, holes: int, tear_corner := false) -> void:
	var s := rng.randi()
	var w := size.x
	var h := size.y
	var margin := 0.035

	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(h)
	right.resize(h)
	for y in h:
		var t := float(y) / float(h)
		left[y] = margin + side_amp * _fbm(t * 6.0, 1.7, s, 3)
		right[y] = 1.0 - margin - side_amp * _fbm(t * 6.0, 9.3, s + 5, 3)

	var top := PackedFloat32Array()
	var bottom := PackedFloat32Array()
	top.resize(w)
	bottom.resize(w)
	for x in w:
		var t := float(x) / float(w)
		top[x] = margin + top_amp * _fbm(t * 5.0, 3.1, s + 11, 3)
		bottom[x] = 1.0 - margin - bottom_amp * _fbm(t * 7.0, 5.9, s + 17, 3)

	for y in h:
		var v := (float(y) + 0.5) / float(h)
		for x in w:
			var u := (float(x) + 0.5) / float(w)
			var d := minf(minf(u - left[y], right[y] - u),
				minf(v - top[x], bottom[x] - v))
			var al := clampf(d * float(w) * 0.9, 0.0, 1.0)
			a[y * w + x] = al * (0.86 + 0.14 * _vnoise(float(x) * 0.13, float(y) * 0.13, s + 23))

	# Bites out of the field, weighted low — gravity and hands both work from
	# the bottom of a sheet upward. Never a single disc: a perfect circular
	# hole reads as a punch card, and neither paper nor paint fails that way.
	# Losses cluster. Paint does not flake in evenly spaced spots and paper does
	# not get bitten in a grid, so pick two or three places and work there.
	var clusters := maxi(1, holes / 3)
	for _c in clusters:
		var ox := rng.randf_range(0.08, 0.92) * float(w)
		var oy := pow(rng.randf(), 0.55) * float(h)
		for _i in int(ceil(float(holes) / float(clusters))):
			_bite(a, size,
				ox + rng.randf_range(-0.10, 0.10) * float(w),
				oy + rng.randf_range(-0.10, 0.10) * float(h),
				float(w) * rng.randf_range(0.018, 0.055), rng)

	# The torn corner: a wobbly diagonal wedge missing off one corner. It is the
	# one shape that says "paper" before the eye has resolved anything else on
	# the wall, so it is cut explicitly rather than left to the edge noise.
	if tear_corner:
		var at_right := rng.randf() < 0.5
		var low := rng.randf() < 0.75
		var rx := maxi(int(float(w) * rng.randf_range(0.18, 0.34)), 2)
		var ry := maxi(int(float(h) * rng.randf_range(0.18, 0.34)), 2)
		var jit := rng.randi()
		for y in h:
			var dy := (h - 1 - y) if low else y
			if dy > ry:
				continue
			for x in w:
				var dx := (w - 1 - x) if at_right else x
				if dx > rx:
					continue
				var line := 1.0 - float(dy) / float(ry)
				var wob := (_vnoise(float(dx) * 0.11, float(dy) * 0.11, jit) - 0.5) * 0.40
				if float(dx) / float(rx) < line + wob:
					a[y * w + x] = 0.0


## An irregular hole: three or four overlapping erases walked a short way, so
## the missing piece has a shape instead of a radius.
static func _bite(a: PackedFloat32Array, size: Vector2i, cx: float, cy: float,
		r: float, rng: RandomNumberGenerator) -> void:
	var ang := rng.randf() * TAU
	var p := Vector2(cx, cy)
	for k in rng.randi_range(3, 5):
		_stamp_erase(a, size, p.x, p.y, r * rng.randf_range(0.55, 1.15))
		ang += rng.randf_range(-0.9, 0.9)
		p += Vector2(cos(ang), sin(ang)) * r * rng.randf_range(0.5, 0.95)


# --- Stamping and noise -----------------------------------------------------

static func _stamp(a: PackedFloat32Array, size: Vector2i, cx: float, cy: float,
		r: float, strength: float) -> void:
	if r <= 0.0:
		return
	var x0 := maxi(int(cx - r) - 1, 0)
	var x1 := mini(int(cx + r) + 1, size.x - 1)
	var y0 := maxi(int(cy - r) - 1, 0)
	var y1 := mini(int(cy + r) + 1, size.y - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length() / r
			if d >= 1.0:
				continue
			var f := 1.0 - d
			var i := y * size.x + x
			a[i] = minf(1.0, a[i] + f * f * (3.0 - 2.0 * f) * strength)


## Same brush, but takes the maximum. Used for haloes: an additive halo stamped
## once per pixel of a crack saturates into a solid smear within ten steps.
static func _stamp_max(a: PackedFloat32Array, size: Vector2i, cx: float, cy: float,
		r: float, strength: float) -> void:
	if r <= 0.0:
		return
	var x0 := maxi(int(cx - r) - 1, 0)
	var x1 := mini(int(cx + r) + 1, size.x - 1)
	var y0 := maxi(int(cy - r) - 1, 0)
	var y1 := mini(int(cy + r) + 1, size.y - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length() / r
			if d >= 1.0:
				continue
			var f := 1.0 - d
			var i := y * size.x + x
			a[i] = maxf(a[i], f * f * strength)


static func _stamp_erase(a: PackedFloat32Array, size: Vector2i, cx: float, cy: float,
		r: float) -> void:
	if r <= 0.0:
		return
	var x0 := maxi(int(cx - r) - 1, 0)
	var x1 := mini(int(cx + r) + 1, size.x - 1)
	var y0 := maxi(int(cy - r) - 1, 0)
	var y1 := mini(int(cy + r) + 1, size.y - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length() / r
			if d >= 1.0:
				continue
			var f := smoothstep(0.55, 1.0, d)
			var i := y * size.x + x
			a[i] = minf(a[i], f)


static func _hash2(x: int, y: int, s: int) -> float:
	var h := x * 374761393 + y * 668265263 + s * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFFFF) / float(0xFFFFFF)


static func _vnoise(x: float, y: float, s: int) -> float:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	var xf := x - floorf(x)
	var yf := y - floorf(y)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	return lerpf(
		lerpf(_hash2(xi, yi, s), _hash2(xi + 1, yi, s), u),
		lerpf(_hash2(xi, yi + 1, s), _hash2(xi + 1, yi + 1, s), u), v)


static func _fbm(x: float, y: float, s: int, octaves := 3) -> float:
	var sum := 0.0
	var amp := 0.5
	var total := 0.0
	for o in octaves:
		sum += _vnoise(x, y, s + o * 37) * amp
		total += amp
		x *= 2.03
		y *= 2.03
		amp *= 0.5
	return sum / maxf(total, 0.0001)


## Seamless value noise, for the one texture that has to tile: paint wear
## applied through world-space triplanar UVs across lettering.
static func _vnoise_tile(x: float, y: float, period: int, s: int) -> float:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	var xf := x - floorf(x)
	var yf := y - floorf(y)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var x0 := posmod(xi, period)
	var x1 := posmod(xi + 1, period)
	var y0 := posmod(yi, period)
	var y1 := posmod(yi + 1, period)
	return lerpf(
		lerpf(_hash2(x0, y0, s), _hash2(x1, y0, s), u),
		lerpf(_hash2(x0, y1, s), _hash2(x1, y1, s), u), v)


## A tiling alpha mask for flaked paint. Applied to lettering in world triplanar
## space so the wear pattern crosses the glyphs instead of following them —
## paint does not flake per letter.
static func wear_texture(seed_ := 0, coverage := 0.72) -> ImageTexture:
	var key := "wear:%d:%.2f" % [seed_, coverage]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var size := Vector2i(128, 128)
	var a := PackedFloat32Array()
	a.resize(size.x * size.y)
	var s := seed_ * 2311 + 71
	for y in size.y:
		for x in size.x:
			var n := 0.0
			var amp := 0.5
			var total := 0.0
			var freq := 8.0
			for o in 3:
				n += _vnoise_tile(float(x) / float(size.x) * freq,
					float(y) / float(size.y) * freq, int(freq), s + o * 53) * amp
				total += amp
				freq *= 2.0
				amp *= 0.5
			n /= maxf(total, 0.0001)
			a[y * size.x + x] = smoothstep(1.0 - coverage - 0.14,
				1.0 - coverage + 0.14, n)
	var tex := _texture_from_alpha(a, size)
	_tex_cache[key] = tex
	return tex


# ============================================================================
#  MATERIALS
# ============================================================================

## A decal material. `strength` is the alpha the shape's coverage is multiplied
## by, so the same texture serves a whisper of dust and a black diesel stain.
##
## opts: variant (int), layer (int), unshaded (bool), roughness, metallic,
##       fade_begin/fade_end (floats, distance fade), cache (bool, default true)
##
## Lit by default. An unshaded dirt streak on a wall that is in shadow glows,
## which is the fastest way to make a decal look pasted on; `unshaded` exists
## for painted signage that has to hold its value inside deep shade, and for
## light cards, and nothing else.
static func decal_material(shape: String, tint: Color, strength := 0.6,
		opts := {}) -> StandardMaterial3D:
	# Normalised here as well as in the factory, so callers can pass a raw
	# random int and still share one material with the next wall that lands on
	# the same cut of the shape.
	var variant := posmod(int(opts.get("variant", 0)), VARIANTS)
	var layer: int = opts.get("layer", LAYER_GRIME)
	var unshaded: bool = opts.get("unshaded", false)
	var roughness: float = opts.get("roughness", 0.92)
	var metallic: float = opts.get("metallic", 0.0)
	var fade_begin: float = opts.get("fade_begin", 0.0)
	var fade_end: float = opts.get("fade_end", 0.0)

	var key := ""
	if opts.get("cache", true):
		key = "%s:%d:%d:%d:%.3f:%.3f:%.3f:%.3f:%.2f:%.2f:%.1f:%.1f" % [
			shape, variant, layer, int(unshaded), tint.r, tint.g, tint.b,
			strength, roughness, metallic, fade_begin, fade_end]
		if _mat_cache.has(key):
			return _mat_cache[key]

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint.r, tint.g, tint.b, clampf(strength, 0.0, 1.0))
	m.albedo_texture = shape_texture(shape, variant)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Transparent materials do not write depth anyway; saying so explicitly
	# stops a future edit flipping it and punching holes in the wall behind.
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# CLAMP, not repeat: every shape fades out at its border and a repeat would
	# wrap that falloff around to the far side of the quad.
	m.texture_repeat = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# MultiMesh instance colours ride in through here, which is how fifteen
	# scuffs sharing one material end up fifteen different values of dirty.
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded \
		else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.30  # project-wide dielectric value
	m.render_priority = clampi(layer, -100, 100)
	if fade_end > 0.0:
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = fade_begin
		m.distance_fade_max_distance = fade_end
	if key != "":
		_mat_cache[key] = m
	return m


## Paint on a surface: stencils, signage, graffiti. Flat, chalky, and worn
## through by default so the lettering is partly missing — sun-perished paint on
## a wall in this world is never a clean fill.
##
## opts: wear (0 = untouched, 1 = barely there), wear_seed, roughness,
##       unshaded (bool), layer (int), scale (float, world size of the wear)
static func paint_material(tint: Color, opts := {}) -> StandardMaterial3D:
	var wear: float = opts.get("wear", 0.28)
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = opts.get("roughness", 0.86)
	m.metallic = 0.0
	m.metallic_specular = 0.30
	m.render_priority = clampi(opts.get("layer", LAYER_PAINT), -100, 100)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if wear > 0.01:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_texture = wear_texture(opts.get("wear_seed", 3),
			clampf(1.0 - wear, 0.25, 0.98))
		# World triplanar: the wear pattern belongs to the wall, not to the
		# glyph. Mapping it per-letter makes every letter flake identically,
		# which is instantly readable as a texture rather than as decay.
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 5.0
		var sc: float = opts.get("scale", 2.4)
		m.uv1_scale = Vector3(sc, sc, sc)
	return m


# ============================================================================
#  PRIMITIVES
# ============================================================================

static func _unit_quad() -> QuadMesh:
	if _unit_quad_mesh == null:
		_unit_quad_mesh = QuadMesh.new()
		_unit_quad_mesh.size = Vector2.ONE
	return _unit_quad_mesh


## How far off the surface a given layer sits. See the header.
static func offset_for(layer: int) -> float:
	return OFFSET_FIRST + OFFSET_STEP * float(maxi(layer, 0))


static func _offset_vector(face: String, layer: int) -> Vector3:
	var d := offset_for(layer)
	match face:
		"floor":
			return Vector3(0.0, d, 0.0)
		"ceiling":
			return Vector3(0.0, -d, 0.0)
		"back":
			return Vector3(0.0, 0.0, -d)
		_:
			return Vector3(0.0, 0.0, d)


## A QuadMesh faces +Z. These rotations turn it to face the surface's normal.
static func _face_basis(face: String) -> Basis:
	match face:
		"floor":
			return Basis(Vector3.RIGHT, -PI * 0.5)
		"ceiling":
			return Basis(Vector3.RIGHT, PI * 0.5)
		"back":
			return Basis(Vector3.UP, PI)
		_:
			return Basis.IDENTITY


## Rotation is applied about the decal's own facing axis first, then the facing
## rotation, so `roll` always means "turn it in its own plane" regardless of
## which way the surface points. Scale is local, hence the explicit multiply —
## `Basis.scaled()` scales in parent space and would shear a rolled decal.
static func _xform(face: String, roll: float, size: Vector2, pos: Vector3) -> Transform3D:
	var b := _face_basis(face) * Basis(Vector3.BACK, roll) \
		* Basis.from_scale(Vector3(size.x, size.y, 1.0))
	return Transform3D(b, pos)


## Flags every decal instance needs. A transparent quad that casts a shadow
## casts the shadow of its *rectangle*, which is the ugliest bug in the kit; and
## a transparent quad baked into VoxelGI darkens the wall as though it were a
## solid slab bolted to the front of it.
static func _decal_flags(gi: GeometryInstance3D, opts := {}) -> void:
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Godot measures the visibility range to the instance's AABB CENTRE, not to
	# its nearest point. A forty-metre wall batch would therefore fade out while
	# the near end of it was still in frame, so callers only pass `visible_to`
	# for groups short enough for a centre measurement to be honest.
	var fade_end: float = opts.get("visible_to", 0.0)
	if fade_end > 0.0:
		gi.visibility_range_end = fade_end
		gi.visibility_range_end_margin = opts.get("visible_margin", 15.0)
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## One decal quad. `pos` is the point ON the surface; the layer offset is added.
##
## opts: face ("wall" | "back" | "floor" | "ceiling"), layer (int), roll (float),
##       visible_to (float)
static func quad(parent: Node3D, name_: String, pos: Vector3, size: Vector2,
		mat: Material, opts := {}) -> MeshInstance3D:
	var face: String = opts.get("face", "wall")
	var layer: int = opts.get("layer", LAYER_GRIME)
	var mi := MeshInstance3D.new()
	mi.name = name_
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos + _offset_vector(face, layer)
	mi.basis = _face_basis(face) * Basis(Vector3.BACK, opts.get("roll", 0.0))
	_decal_flags(mi, opts)
	parent.add_child(mi)
	return mi


## A batch of one shape. Everything scattered goes through here: one draw call,
## one material, per-instance colour so they are not fifteen copies of one mark.
static func batch(parent: Node3D, name_: String, mat: Material,
		xforms: Array[Transform3D], colours: PackedColorArray,
		opts := {}) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	# transform_format and use_colors must both be set BEFORE instance_count or
	# the buffer is allocated without room for them.
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _unit_quad()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colours[i] if i < colours.size() else Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = mm
	node.material_override = mat
	_decal_flags(node, opts)
	parent.add_child(node)
	return node


# ============================================================================
#  WALL PLACEMENT
# ============================================================================

## Per-10-m-of-wall counts and colours by location. A prison yard, a town street
## and a plant interior are dirty in genuinely different ways, and the difference
## is mostly about what reaches the wall: sand and sun outside, hands and damp in.
static func _preset(name_: String) -> Dictionary:
	match name_:
		"town":
			# Rendered plaster on a street. Less soot, more sand at the base,
			# more hands at shoulder height, and paper on it.
			return {
				"runs": 1.8, "blobs": 2.4, "cracks": 1.5, "scuffs": 2.6,
				"splatters": 0.9, "posters": 0.35, "graffiti": 0.30,
				"grime": Color(0.20, 0.165, 0.125), "dust": DUST,
				"drift": true, "hand_height": 1.9,
			}
		"interior":
			# A cell block. No sand, no sun: damp from above, hands and trolleys
			# below, and a hard scuff line where every shoulder has been.
			return {
				"runs": 2.4, "blobs": 2.0, "cracks": 1.8, "scuffs": 3.4,
				"splatters": 0.4, "posters": 0.0, "graffiti": 0.45,
				"grime": Color(0.10, 0.10, 0.095), "dust": Color(0.52, 0.52, 0.50),
				"drift": false, "hand_height": 1.7,
			}
		"road":
			# A boundary wall beside a carriageway: splash-back is the story and
			# it stops dead at about a metre.
			return {
				"runs": 1.4, "blobs": 1.8, "cracks": 1.0, "scuffs": 0.8,
				"splatters": 2.6, "posters": 0.12, "graffiti": 0.20,
				"grime": Color(0.13, 0.115, 0.095), "dust": Color(0.70, 0.62, 0.48),
				"drift": true, "hand_height": 1.2,
			}
		_:
			# "plant" — the Brega default. Everything runs, everything rusts, and
			# the bottom metre is eaten by salt.
			return {
				"runs": 3.0, "blobs": 2.2, "cracks": 1.2, "scuffs": 1.6,
				"splatters": 1.0, "posters": 0.10, "graffiti": 0.18,
				"grime": GRIME, "dust": DUST,
				"drift": true, "hand_height": 1.6,
			}


## Counts are fractional per 10 m of wall, so a 4 m wall gets a *chance* of a
## crack rather than always one or always none.
static func _count(rate: float, per10: float, density: float,
		rng: RandomNumberGenerator) -> int:
	var f := rate * per10 * density
	var n := int(f)
	if rng.randf() < f - floorf(f):
		n += 1
	return n


## Dirty a wall. Deterministic: the same arguments give the same wall every run,
## and two walls in one level are never the same wall.
##
## `left_x`, `base_y` and `z` are the wall's front face in world space, exactly
## as `PropKit.prefab_facade` and `perimeter_wall` take them; `z` is the face
## itself, not the wall's centre.
##
## spec keys, all optional:
##   preset      "plant" | "town" | "interior" | "road"
##   density     multiplier on every count (default 1.0)
##   runs / blobs / cracks / scuffs / splatters / posters / graffiti
##               per-10-m rates, overriding the preset
##   grime/dust  Colors
##   wind        +1 or -1: which way the sand drifts and which face is scoured
##   drift       bool, the sand ramp along the base
##   face        "wall" (default) or "back"
##   name        node name
##   visible_to  distance at which the small stuff fades out (default 90)
static func scatter_on_wall(parent: Node3D, left_x: float, base_y: float,
		width: float, height: float, z: float, spec := {}, seed_ := 0) -> Node3D:
	var root := Node3D.new()
	root.name = str(spec.get("name", "WallDecals"))
	parent.add_child(root)

	var p := _preset(str(spec.get("preset", "plant")))
	for k in spec:
		p[k] = spec[k]

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ if seed_ != 0 else int(absf(left_x) * 811.0 + width * 43.0
		+ height * 7.0 + absf(z) * 13.0)

	var per10 := maxf(width / 10.0, 0.25)
	var density: float = p.get("density", 1.0)
	var face: String = p.get("face", "wall")
	var wind: float = p.get("wind", 1.0)
	var grime: Color = p.get("grime", GRIME)
	var dust: Color = p.get("dust", DUST)
	var hand: float = p.get("hand_height", 1.6)
	var visible_to: float = p.get("visible_to", 90.0 if width <= 40.0 else 0.0)
	var batch_opts := {"visible_to": visible_to}
	var right_x := left_x + width
	var top_y := base_y + height

	# --- Broad tonal grime --------------------------------------------------
	# Low and in the corners. Rain splash, sand and exhaust all work from the
	# ground up, and a wall dirtied evenly reads as a tinted wall, not a dirty
	# one. The pow() biases y hard toward the base.
	var blob_xf: Array[Transform3D] = []
	var blob_col := PackedColorArray()
	for _i in _count(p.get("blobs", 2.2), per10, density, rng):
		var bw := rng.randf_range(1.6, 4.6)
		var bh := rng.randf_range(1.2, minf(height * 0.8, 4.0))
		var bx := rng.randf_range(left_x, right_x)
		var by := base_y + pow(rng.randf(), 2.1) * height
		blob_xf.append(_xform(face, rng.randf_range(0.0, TAU), Vector2(bw, bh),
			Vector3(bx, by, z) + _offset_vector(face, LAYER_GRIME)))
		blob_col.append(Color(1.0, 1.0, 1.0, rng.randf_range(0.45, 1.0)))
	if not blob_xf.is_empty():
		batch(root, "Grime", decal_material("blob", grime, 0.34,
			{"variant": rng.randi(), "layer": LAYER_GRIME}),
			blob_xf, blob_col, batch_opts)

	# --- Sand drift along the base ------------------------------------------
	# Sand never lies evenly: it ramps up where the wind dumps it and scours the
	# windward end back to bare render. Sizes fall off against the wind, which
	# is what makes one end of the wall look lived-with and the other blasted.
	if p.get("drift", true):
		var drift_xf: Array[Transform3D] = []
		var drift_col := PackedColorArray()
		var lobes := maxi(2, int(width / 7.0))
		for i in lobes:
			var t := (float(i) + 0.5) / float(lobes)
			var lee := t if wind > 0.0 else 1.0 - t
			var dw := lerpf(2.2, 7.0, lee) * rng.randf_range(0.8, 1.2)
			var dh := lerpf(0.35, 1.5, lee) * rng.randf_range(0.8, 1.2)
			drift_xf.append(_xform(face, rng.randf_range(-0.06, 0.06),
				Vector2(dw, dh),
				Vector3(left_x + t * width, base_y + dh * 0.30, z)
					+ _offset_vector(face, LAYER_GRIME)))
			drift_col.append(Color(1.0, 1.0, 1.0, lerpf(0.35, 1.0, lee)))
		batch(root, "SandDrift", decal_material("blob", dust, 0.46,
			{"variant": rng.randi(), "layer": LAYER_GRIME}),
			drift_xf, drift_col, batch_opts)

	# --- Runs ---------------------------------------------------------------
	# Half of them come off the top edge, because that is where the water goes
	# first; the rest hang off whatever is bolted to the wall further down.
	var run_xf: Array[Transform3D] = []
	var run_col := PackedColorArray()
	for i in _count(p.get("runs", 3.0), per10, density, rng):
		var from_top := i % 2 == 0
		var ry := top_y if from_top else base_y + rng.randf_range(0.35, 0.92) * height
		var rl := rng.randf_range(0.5, 1.0) * (height * (0.55 if from_top else 0.35))
		var rw := rng.randf_range(0.12, 0.42)
		run_xf.append(_xform(face, rng.randf_range(-0.03, 0.03), Vector2(rw, rl),
			Vector3(rng.randf_range(left_x, right_x), ry - rl * 0.5, z)
				+ _offset_vector(face, LAYER_RUN)))
		run_col.append(Color(1.0, 1.0, 1.0, rng.randf_range(0.55, 1.0)))
	if not run_xf.is_empty():
		batch(root, "Runs", decal_material("run", grime, 0.58,
			{"variant": rng.randi(), "layer": LAYER_RUN}),
			run_xf, run_col, batch_opts)

	# --- Splash-back --------------------------------------------------------
	# Never above about a metre. Splatter that reaches head height is a crime
	# scene, not weather.
	var splat_xf: Array[Transform3D] = []
	var splat_col := PackedColorArray()
	for _i in _count(p.get("splatters", 1.0), per10, density, rng):
		var sw := rng.randf_range(0.7, 1.9)
		splat_xf.append(_xform(face, rng.randf_range(0.0, TAU),
			Vector2(sw, sw * rng.randf_range(0.7, 1.1)),
			Vector3(rng.randf_range(left_x, right_x),
				base_y + pow(rng.randf(), 1.7) * 1.0, z)
				+ _offset_vector(face, LAYER_RUN)))
		splat_col.append(Color(1.0, 1.0, 1.0, rng.randf_range(0.4, 0.9)))
	if not splat_xf.is_empty():
		batch(root, "Splatter", decal_material("splatter", MUD, 0.52,
			{"variant": rng.randi(), "layer": LAYER_RUN}),
			splat_xf, splat_col, batch_opts)

	# --- Cracks -------------------------------------------------------------
	# Biased low, where settlement cracks a panel, and never long enough to
	# cross the whole wall — a crack that spans a facade reads as a modelling
	# mistake rather than as damage.
	var crack_xf: Array[Transform3D] = []
	var crack_col := PackedColorArray()
	for _i in _count(p.get("cracks", 1.2), per10, density, rng):
		var cl := rng.randf_range(0.9, minf(height * 0.55, 3.0))
		crack_xf.append(_xform(face, rng.randf_range(-0.55, 0.55),
			Vector2(cl * rng.randf_range(0.55, 0.9), cl),
			Vector3(rng.randf_range(left_x, right_x),
				base_y + pow(rng.randf(), 1.5) * height * 0.8, z)
				+ _offset_vector(face, LAYER_MARK)))
		crack_col.append(Color(1.0, 1.0, 1.0, rng.randf_range(0.55, 1.0)))
	# Cracks go out in two batches on two different cuts of the shape. Every
	# other scatter here is a soft blob that a random roll disguises; a crack
	# has structure, and five copies of one crack on one wall is the kind of
	# repeat the eye finds before it finds anything else in the frame.
	if not crack_xf.is_empty():
		var cv := rng.randi()
		var half_a: Array[Transform3D] = []
		var half_b: Array[Transform3D] = []
		var col_a := PackedColorArray()
		var col_b := PackedColorArray()
		for i in crack_xf.size():
			if i % 2 == 0:
				half_a.append(crack_xf[i])
				col_a.append(crack_col[i])
			else:
				half_b.append(crack_xf[i])
				col_b.append(crack_col[i])
		batch(root, "CracksA", decal_material("crack", CRACK_INK, 0.70,
			{"variant": cv, "layer": LAYER_MARK, "roughness": 0.96}),
			half_a, col_a, batch_opts)
		if not half_b.is_empty():
			batch(root, "CracksB", decal_material("crack", CRACK_INK, 0.70,
				{"variant": cv + 1, "layer": LAYER_MARK, "roughness": 0.96}),
				half_b, col_b, batch_opts)

	# --- Scuffs -------------------------------------------------------------
	# Occupancy: scuffs only exist where a person, a barrow or a bumper reaches.
	# Their upper limit is the single most convincing weathering cue available.
	var scuff_xf: Array[Transform3D] = []
	var scuff_col := PackedColorArray()
	for _i in _count(p.get("scuffs", 1.6), per10, density, rng):
		var sw2 := rng.randf_range(0.7, 1.8)
		scuff_xf.append(_xform(face, rng.randf_range(-0.25, 0.25),
			Vector2(sw2, sw2 * rng.randf_range(0.45, 0.8)),
			Vector3(rng.randf_range(left_x, right_x),
				base_y + rng.randf_range(0.15, hand), z)
				+ _offset_vector(face, LAYER_MARK)))
		scuff_col.append(Color(1.0, 1.0, 1.0, rng.randf_range(0.3, 0.8)))
	if not scuff_xf.is_empty():
		batch(root, "Scuffs", decal_material("scuff", grime, 0.36,
			{"variant": rng.randi(), "layer": LAYER_MARK}),
			scuff_xf, scuff_col, batch_opts)

	# --- Paper and paint ----------------------------------------------------
	# Authored things, so they are placed one at a time rather than batched, and
	# they are rare on purpose: see the budget note in the header.
	for i in _count(p.get("posters", 0.1), per10, density, rng):
		var pw := rng.randf_range(0.5, 0.86)
		poster(root, Vector3(rng.randf_range(left_x + 0.6, right_x - 0.6),
			base_y + rng.randf_range(1.3, 2.1), z),
			Vector2(pw, pw * rng.randf_range(1.25, 1.55)),
			{"face": face, "seed": rng.randi(), "visible_to": visible_to,
				"name": "Poster%d" % i})

	for i in _count(p.get("graffiti", 0.18), per10, density, rng):
		graffiti(root, Vector3(rng.randf_range(left_x + 1.0, right_x - 1.0),
			base_y + rng.randf_range(0.9, 1.9), z),
			rng.randf_range(0.30, 0.52),
			{"face": face, "visible_to": visible_to, "name": "Tag%d" % i},
			rng.randi())

	return root


## Streaks hanging off a lip: a coping, a cornice, a window sill, the underside
## of a walkway. Water does not run evenly off an edge, it finds two or three
## paths and stays with them, so most of the runs cluster and a few stragglers
## do not.
##
## opts: tint, strength, length (max drop), min_length, width, clusters,
##       count, face, visible_to
static func run_off(parent: Node3D, left_x: float, top_y: float, width: float,
		z: float, opts := {}, seed_ := 0) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ if seed_ != 0 else int(absf(left_x) * 613.0 + width * 29.0 + top_y)

	var face: String = opts.get("face", "wall")
	var max_len: float = opts.get("length", 2.2)
	var min_len: float = opts.get("min_length", 0.35)
	var base_w: float = opts.get("width", 0.26)
	var count: int = opts.get("count", maxi(2, int(width / 1.3)))
	var clusters: int = opts.get("clusters", maxi(1, int(width / 5.0)))

	var centres := PackedFloat32Array()
	for _c in clusters:
		centres.append(rng.randf_range(left_x + 0.2, left_x + width - 0.2))

	var xf: Array[Transform3D] = []
	var col := PackedColorArray()
	for i in count:
		var x := 0.0
		if rng.randf() < 0.68 and centres.size() > 0:
			# Around a damaged spot on the lip, with a tight spread.
			x = centres[rng.randi() % centres.size()] + rng.randf_range(-0.55, 0.55)
		else:
			x = rng.randf_range(left_x, left_x + width)
		x = clampf(x, left_x, left_x + width)
		var l := lerpf(min_len, max_len, pow(rng.randf(), 1.6))
		var w := base_w * rng.randf_range(0.45, 1.5)
		xf.append(_xform(face, rng.randf_range(-0.025, 0.025), Vector2(w, l),
			Vector3(x, top_y - l * 0.5, z) + _offset_vector(face, LAYER_RUN)))
		col.append(Color(1.0, 1.0, 1.0, rng.randf_range(0.45, 1.0)))

	return batch(parent, str(opts.get("name", "RunOff")),
		decal_material("run", opts.get("tint", GRIME), opts.get("strength", 0.62),
			{"variant": rng.randi(), "layer": LAYER_RUN}),
		xf, col, {"visible_to": opts.get("visible_to", 90.0 if width <= 40.0 else 0.0)})


# ============================================================================
#  FLOOR PLACEMENT
# ============================================================================

## Standing water, or the salt ring where it used to stand. Two quads: a damp
## halo and the water itself. A puddle with a hard edge is a sticker — the
## ground around real standing water is dark long before the water starts.
##
## The water is smooth (roughness 0.10), which is the entire point: in a level
## lit by a 2° sun, one small smooth horizontal surface throws the only
## specular the yard has.
##
## opts: dry (bool), tint, halo_tint, strength, roll, visible_to
static func puddle(parent: Node3D, center: Vector3, radius: float,
		opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = str(opts.get("name", "Puddle"))
	root.position = center
	parent.add_child(root)

	var dry: bool = opts.get("dry", false)
	var roll: float = opts.get("roll", 0.0)
	var variant: int = opts.get("variant", 1)
	var vis := {"face": "floor", "visible_to": opts.get("visible_to", 70.0)}

	var halo_tint: Color = opts.get("halo_tint",
		SALT if dry else Color(0.20, 0.175, 0.14))
	quad(root, "Damp", Vector3.ZERO,
		Vector2(radius * 2.7, radius * 2.35),
		decal_material("blob", halo_tint, 0.34 if dry else 0.42,
			{"variant": variant + 2, "layer": LAYER_GRIME}),
		{"face": "floor", "layer": LAYER_GRIME, "roll": roll + 0.4,
			"visible_to": vis["visible_to"]})

	if dry:
		# A dried sabkha puddle is the inverse of a wet one: pale salt bloom on
		# the outside, dark cracked mud in the middle.
		quad(root, "SaltCrust", Vector3.ZERO, Vector2(radius * 1.9, radius * 1.6),
			decal_material("crack", Color(0.42, 0.36, 0.28), 0.5,
				{"variant": variant, "layer": LAYER_MARK, "roughness": 0.95}),
			{"face": "floor", "layer": LAYER_MARK, "roll": roll,
				"visible_to": vis["visible_to"]})
	else:
		quad(root, "Water", Vector3.ZERO, Vector2(radius * 2.0, radius * 1.7),
			decal_material("blob", opts.get("tint", Color(0.14, 0.135, 0.125)),
				opts.get("strength", 0.88),
				{"variant": variant, "layer": LAYER_RUN, "roughness": 0.10,
					"metallic": 0.0}),
			{"face": "floor", "layer": LAYER_RUN, "roll": roll,
				"visible_to": vis["visible_to"]})
	return root


## A stain on the floor: diesel under a generator, gear oil under a truck, a
## paint spill. `oil` gives it the faint greasy sheen that separates a spill
## from a shadow.
##
## opts: shape ("blob" | "splatter"), tint, strength, oil (bool), roll, variant
static func stain(parent: Node3D, center: Vector3, size: Vector2,
		opts := {}) -> MeshInstance3D:
	var oily: bool = opts.get("oil", true)
	var mat := decal_material(str(opts.get("shape", "blob")),
		opts.get("tint", OIL), opts.get("strength", 0.72),
		{"variant": opts.get("variant", 0), "layer": LAYER_RUN,
			"roughness": 0.34 if oily else 0.92,
			"metallic": 0.14 if oily else 0.0})
	return quad(parent, str(opts.get("name", "Stain")), center, size, mat,
		{"face": opts.get("face", "floor"), "layer": LAYER_RUN,
			"roll": opts.get("roll", 0.0),
			"visible_to": opts.get("visible_to", 70.0)})


## Tyre tracks across a road or a yard.
##
## Two ruts at an axle's spacing, broken into segments whose strength decays
## along the run — because tracks do not stop, they fade out as the tyre dries.
## Both ruts use the same tread variant (it is one vehicle) but different
## per-segment wear, and the whole run drifts sideways, because nobody drives in
## a straight line across a yard.
##
## opts: track (axle width), width (rut width), tint, strength, drift,
##       segment (length), fade ("out" | "in" | "none"), variant, visible_to
static func tyre_tracks(parent: Node3D, from_x: float, to_x: float, y: float,
		z: float, opts := {}, seed_ := 0) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ if seed_ != 0 else int(absf(from_x) * 397.0 + absf(to_x) * 71.0)

	var track: float = opts.get("track", 1.55)
	var rut_w: float = opts.get("width", 0.26)
	var seg_len: float = opts.get("segment", 1.7)
	var drift: float = opts.get("drift", 0.35)
	var fade: String = str(opts.get("fade", "out"))
	var variant: int = opts.get("variant", rng.randi() % VARIANTS)

	var length := to_x - from_x
	var dir := signf(length)
	var count := maxi(1, int(absf(length) / seg_len))

	var xf: Array[Transform3D] = []
	var col := PackedColorArray()
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var sx := from_x + length * t
		# The lateral wander is one smooth curve, not per-segment noise: a rut
		# that jitters reads as a dashed line.
		var wander := sin(t * PI * 1.3 + float(seed_ % 7)) * drift
		var strength := 1.0
		match fade:
			"out":
				strength = pow(1.0 - t, 1.3)
			"in":
				strength = pow(t, 1.3)
			_:
				strength = 1.0
		strength = clampf(strength * rng.randf_range(0.75, 1.1), 0.05, 1.0)
		for side: float in [-1.0, 1.0]:
			var pos := Vector3(sx, y, z + side * track * 0.5 + wander)
			# Rolled a quarter turn so the tread pattern runs along X, the way
			# the wheel rolled, with a touch of yaw following the wander.
			var roll := PI * 0.5 * dir + sin(t * PI * 1.3) * 0.05
			xf.append(_xform("floor", roll,
				Vector2(rut_w, seg_len * 1.04),
				pos + _offset_vector("floor", LAYER_MARK)))
			col.append(Color(1.0, 1.0, 1.0, strength))

	return batch(parent, str(opts.get("name", "TyreTracks")),
		decal_material("tread", opts.get("tint", MUD), opts.get("strength", 0.60),
			{"variant": variant, "layer": LAYER_MARK, "roughness": 0.88}),
		xf, col, {"visible_to":
			opts.get("visible_to", 80.0 if absf(length) <= 40.0 else 0.0)})


# ============================================================================
#  PAPER, PAINT AND SPRAY
# ============================================================================

## Latin text. `PropKit.sign` always assigns an Arabic face, which is right for
## Arabic and wrong for the bilingual safety signage a petrochemical plant
## carries; a TextMesh with no font falls back to the project default, which has
## the Latin glyphs and the digits.
static func _latin(parent: Node3D, text: String, pos: Vector3, height: float,
		mat: Material, depth := 0.004) -> MeshInstance3D:
	var tm := TextMesh.new()
	tm.text = text
	tm.font_size = 96
	tm.pixel_size = height / 96.0
	tm.depth = depth
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.name = "Latin"
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	_decal_flags(mi)
	parent.add_child(mi)
	return mi


## A torn paper poster. Pasted, sun-bleached, and never square to the wall —
## the small tilt is doing as much work as the ragged edge.
##
## opts: text (Arabic headline), sub (second line), font (path), ink (Color),
##       tint (paper Color), tilt, dirt (bool), face, seed, visible_to
static func poster(parent: Node3D, pos: Vector3, size: Vector2,
		opts := {}) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 17)) * 3301 + 29

	var face: String = opts.get("face", "wall")
	var tilt: float = opts.get("tilt", rng.randf_range(-0.07, 0.07))
	var visible_to: float = opts.get("visible_to", 80.0)

	var root := Node3D.new()
	root.name = str(opts.get("name", "Poster"))
	root.position = pos
	parent.add_child(root)

	# The grime under the bottom edge. A transparent quad receives no contact
	# shadow and no SSAO — it has nothing to occlude with — so without this the
	# paper floats however good the lighting is.
	if opts.get("dirt", true):
		quad(root, "PasteDirt", Vector3(0.0, -size.y * 0.42, 0.0),
			Vector2(size.x * 1.25, size.y * 0.55),
			decal_material("blob", GRIME, 0.26,
				{"variant": rng.randi(), "layer": LAYER_RUN}),
			{"face": face, "layer": LAYER_RUN, "roll": tilt,
				"visible_to": visible_to})

	var paper := quad(root, "Paper", Vector3.ZERO, size,
		decal_material("torn", opts.get("tint", PAPER), 0.97,
			{"variant": rng.randi(), "layer": LAYER_PAPER, "roughness": 0.80}),
		{"face": face, "layer": LAYER_PAPER, "roll": tilt,
			"visible_to": visible_to})

	var ink: Color = opts.get("ink", INK)
	var ink_mat := paint_material(ink, {"wear": 0.18, "wear_seed": rng.randi() % 6,
		"scale": 6.0, "layer": LAYER_PAINT})
	var font: String = str(opts.get("font", PropKit.FONT_NASKH))
	var head: String = str(opts.get("text", ""))
	if head != "":
		# Parented to the paper so the headline tilts with the sheet. Nothing
		# betrays a pasted-on decal faster than level type on crooked paper.
		_decal_flags(PropKit.sign(paper, head, Vector3(0.0, size.y * 0.20, 0.004),
			size.y * 0.17, ink_mat, font, 0.002))
	var sub: String = str(opts.get("sub", ""))
	if sub != "":
		_decal_flags(PropKit.sign(paper, sub, Vector3(0.0, -size.y * 0.06, 0.004),
			size.y * 0.10, ink_mat, font, 0.002))
	return root


## Stencilled or painted lettering on a surface: plant unit numbers, hazard
## text, a shop fascia.
##
## Arabic goes through `PropKit.sign`, which hands the string to the TextServer
## and gets correct cursive joining and RTL ordering back. Do not try to place
## Arabic glyphs individually — disconnected letterforms are the most visible
## possible failure in this game's world.
##
## opts: font (path; Naskh for official, Kufi for monumental), latin (String,
##       drawn under the Arabic as plant safety signage), tint, wear, plate
##       (bool) + plate_tint, layer, face, visible_to
static func stencil(parent: Node3D, text: String, pos: Vector3, height: float,
		opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = str(opts.get("name", "Stencil"))
	root.position = pos
	parent.add_child(root)

	var face: String = opts.get("face", "wall")
	var layer: int = opts.get("layer", LAYER_PAINT)
	var visible_to: float = opts.get("visible_to", 90.0)
	var tint: Color = opts.get("tint", PAINT_WHITE)
	var wear: float = opts.get("wear", 0.30)
	var font: String = str(opts.get("font", PropKit.FONT_NASKH))

	# The painted field behind the lettering, if this is a plate rather than
	# bare text straight onto the wall.
	if opts.get("plate", false):
		var pw: float = opts.get("plate_width", height * maxf(float(text.length()) * 0.62, 2.2))
		var ph: float = opts.get("plate_height", height * 2.1)
		quad(root, "Plate", Vector3.ZERO, Vector2(pw, ph),
			decal_material("patch", opts.get("plate_tint", PAINT_YELLOW), 0.92,
				{"variant": 2, "layer": layer - 1, "roughness": 0.82}),
			{"face": face, "layer": maxi(layer - 1, 0),
				"roll": opts.get("roll", 0.0), "visible_to": visible_to})

	var mat := paint_material(tint, {"wear": wear, "layer": layer,
		"wear_seed": opts.get("wear_seed", 5), "scale": opts.get("wear_scale", 2.4)})
	var body := Node3D.new()
	body.name = "Text"
	body.position = _offset_vector(face, layer)
	body.basis = _face_basis(face) * Basis(Vector3.BACK, opts.get("roll", 0.0))
	root.add_child(body)

	var latin: String = str(opts.get("latin", ""))
	var lift := height * 0.55 if latin != "" else 0.0
	_decal_flags(PropKit.sign(body, text, Vector3(0.0, lift, 0.0), height, mat, font, 0.003))
	if latin != "":
		# Bilingual is correct inside the plant and nowhere else in this game.
		_latin(body, latin, Vector3(0.0, -height * 0.60, 0.0), height * 0.68, mat)
	return root


## Spray paint. Neutral marks only — initials, numbers, a football score, an
## invented club scrawl. The overspray halo behind the letters is what makes it
## read as spray rather than as a decal: an aerosol always puts more paint
## around the stroke than on it.
##
## opts: text, tint, font, face, roll, halo (bool), swipe (bool), visible_to
static func graffiti(parent: Node3D, pos: Vector3, height: float,
		opts := {}, seed_ := 0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ if seed_ != 0 else 4409

	var root := Node3D.new()
	root.name = str(opts.get("name", "Graffiti"))
	root.position = pos
	parent.add_child(root)

	var face: String = opts.get("face", "wall")
	var visible_to: float = opts.get("visible_to", 80.0)
	var text: String = str(opts.get("text", TAGS[rng.randi() % TAGS.size()]))
	var tint: Color = opts.get("tint",
		SPRAY_BLACK if rng.randf() < 0.6 else SPRAY_BLUE)
	var roll: float = opts.get("roll", rng.randf_range(-0.10, 0.10))
	# Width is estimated, not measured: the halo is a soft blob and a few
	# centimetres either way is invisible, while forcing the mesh to build just
	# to read its AABB is not.
	var est_w := height * 0.66 * float(maxi(text.length(), 2))

	if opts.get("halo", true):
		quad(root, "Overspray", Vector3.ZERO,
			Vector2(est_w * 1.22, height * 2.3),
			decal_material("blob", tint, 0.16,
				{"variant": rng.randi(), "layer": LAYER_RUN}),
			{"face": face, "layer": LAYER_RUN, "roll": roll,
				"visible_to": visible_to})

	var body := Node3D.new()
	body.name = "Tag"
	body.position = _offset_vector(face, LAYER_PAINT)
	body.basis = _face_basis(face) * Basis(Vector3.BACK, roll)
	root.add_child(body)

	var mat := paint_material(tint, {"wear": 0.22, "layer": LAYER_PAINT,
		"wear_seed": rng.randi() % 6, "scale": 3.2})
	if _has_arabic(text):
		_decal_flags(PropKit.sign(body, text, Vector3.ZERO, height, mat,
			PropKit.FONT_NASKH, 0.003))
	else:
		_latin(body, text, Vector3.ZERO, height, mat)

	# The swipe under a tag: the can held sideways and dragged. Cheap, and it is
	# what stops a tag reading as a word someone typed onto the wall.
	if opts.get("swipe", true) and rng.randf() < 0.65:
		quad(root, "Swipe", Vector3(rng.randf_range(-0.1, 0.1), -height * 0.85, 0.0),
			Vector2(est_w * rng.randf_range(0.8, 1.15), height * 0.30),
			decal_material("scuff", tint, 0.55,
				{"variant": rng.randi(), "layer": LAYER_PAINT}),
			{"face": face, "layer": LAYER_PAINT, "roll": roll + rng.randf_range(-0.06, 0.06),
				"visible_to": visible_to})
	return root


static func _has_arabic(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		# Arabic, Arabic Supplement, Arabic Extended-A and the presentation
		# forms. Anything in here has to go through the shaper.
		if (c >= 0x0600 and c <= 0x08FF) or (c >= 0xFB50 and c <= 0xFEFF):
			return true
	return false
