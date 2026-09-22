class_name AjdabiyaKit
## Shared material palette, colour script and backdrop for Level 2.
##
## AJDABIYA CROSSROADS is the counterweight to Brega. Brega is a dead plant at
## first light: cold shadow, warm key, no people, almost no colour, and the key
## deliberately behind the geometry so the level is a silhouette problem.
## Ajdabiya is the same coast two hours later and forty kilometres east, and it
## is a TOWN — the sun is up and in FRONT, the street is lit, the shadows are
## short and hard blue, and colour is everywhere because people put it there.
##
## The rule that carries over: he is still the brightest thing in the frame.
## Here that is harder, so the town's saturation is spent on mid values and the
## whites are kept for him.
##
##
## ═══ THE AJDABIYA PALETTE RULE ═══════════════════════════════════════════
##
## Authored albedo, three value bands, and every hue is legal in exactly one
## of them. This is enforced by eye on every capture; if something in this
## level reads loud, it has broken one of these three lines.
##
##   HIGH   V 0.50–0.70, S ≤ 0.35   The field, and it is all one hue family:
##                                  warm straw, 30–45°. Sun-bleached lime
##                                  render, salt bloom, kerbstone, awning
##                                  canvas, painted lettering. Saturation up
##                                  here is allowed only as the WARMTH of the
##                                  render, never as a colour decision — there
##                                  is no blue wall and no green wall in this
##                                  town. Above V 0.70 there is exactly one
##                                  object in the level and it is his thobe.
##
##   MID    V 0.18–0.50, S ≤ 0.70   ALL of the town's colour lives here and
##                                  nowhere else: shutters, painted fascias,
##                                  awning stripes, laundry, crates, produce,
##                                  plastic chairs, gas bottles, bougainvillea,
##                                  the repainted bus. Saturation in the mids
##                                  reads as PAINT; the same saturation in the
##                                  highs reads as PLASTIC, and it steals the
##                                  eye off the hero.
##                                  Extra cap in the red sector (hue 340–25°):
##                                  V stops at 0.46, a full stop under his
##                                  jacket, so no shutter, awning or tomato in
##                                  this level can be mistaken for a sriracha.
##
##   LOW    V 0.04–0.20, S ≤ 0.25   Shadow, shop interiors, asphalt, steel,
##                                  tyres, roof tanks, window voids. Never
##                                  pure black — the fill is a hard sky blue
##                                  and it lands in every one of these.
##
## Hue budget, per screen: warm straw is the field, and the accents are
## TEAL-BLUE (195–215°), SHUTTER GREEN (140–160°) and OXIDE RED (10–20°).
## Never more than two accent hues fighting in one frame; the third is always
## the smaller note. Yellow-orange (35–55°) is permitted only as awning stripe
## and gas bottle and site plant — a skip, a compressor — never as a wall.
##
## Off-budget, deliberately, and in exactly these places:
##   · BOUGAINVILLEA MAGENTA (330°) over a courtyard wall, once. A real one is
##     always there and nothing else in World 1 is that hue.
##   · SABKHA TERRA ROSSA (16°, V 0.42), the red interior sand lying in tongues
##     across the asphalt and drifted against the far kerb. This is the level's
##     canon-unique colour per docs/ART_DIRECTION.md and it lives on the
##     GROUND, where it cannot compete with anything vertical.
##   · RUST, which ART_DIRECTION specifies at S 0.78 and which is over every
##     cap here — and is only ever a bracket, a bar, a rail or a bleed streak,
##     never an area.
##
## Hard ceiling, project-wide: nothing in hue 340–25° may exceed S 0.55 /
## V 0.72. That band belongs to Wanis and the sriracha.
## ═════════════════════════════════════════════════════════════════════════

const STREET_Y := 0.0

## The nominal far-side building line. Individual plots step in front of and
## behind it — a terrace whose frontage is one plane is a wall, not a street.
const FAR_FRONT := -17.9

## Ordinary shops, invented, of the kind that are actually on this road: name,
## font (0 Naskh, 1 Naskh bold, 2 Kufi) and the trade, which decides what
## spills out onto the pavement in front of it. Nothing political, nothing
## religious, no real business. Signage in Libya is Arabic-only with Western
## digits, so the phone numbers under the names use 0123456789.
const TRADES := [
	["خضار وفواكه", 1, "produce"],
	["مخبز الواحة", 2, "bakery"],
	["حلاق الشباب", 0, "barber"],
	["بنشر وإطارات", 2, "tyres"],
	["ستالايت ودش", 1, "satellite"],
	["مقهى الميدان", 0, "cafe"],
	["لحوم طازجة", 1, "butcher"],
	["سجاد وموكيت", 2, "carpets"],
	["غاز وأسطوانات", 0, "gas"],
	["مواد بناء", 2, "builders"],
	["أدوات صحية", 0, "hardware"],
	["بقالة الميدان", 1, "grocer"],
	["صيانة هواتف", 2, "phones"],
	["ملابس الأناقة", 0, "clothes"],
]

const PHONES := ["091 3624180", "092 5517403", "094 4180962", "091 7702345"]


# --- Palette ----------------------------------------------------------------

static func palette() -> Dictionary:
	var mats := {
		# ── HIGH band. The field. Six renders, all within S 0.12, separated by
		# hue and by a little value, because a terrace painted one colour is a
		# wall no matter how much geometry is bolted to it.
		"render": MaterialLab.plaster(Color(0.520, 0.470, 0.392), 1.0),
		"render_b": MaterialLab.plaster(Color(0.430, 0.398, 0.352), 1.0),
		"render_c": MaterialLab.plaster(Color(0.560, 0.500, 0.404), 1.0),
		"render_pale": MaterialLab.plaster(Color(0.612, 0.572, 0.492), 0.7),
		"render_warm": MaterialLab.plaster(Color(0.548, 0.462, 0.360), 1.0),
		"render_cool": MaterialLab.plaster(Color(0.428, 0.442, 0.404), 1.0),
		"render_rose": MaterialLab.plaster(Color(0.505, 0.418, 0.372), 1.0),
		# Bare block: the buildings nobody rendered. Its job is VALUE, not hue —
		# it is the dark step in the terrace that stops the row being one tone.
		"block": MaterialLab.concrete(Color(0.330, 0.310, 0.282), 1.0),
		"block_raw": MaterialLab.concrete(Color(0.288, 0.272, 0.252), 1.0),
		"shade": MaterialLab.concrete(Color(0.150, 0.140, 0.132), 0.8),
		"dark": MaterialLab.concrete(Color(0.058, 0.054, 0.056), 0.2),
		"kerb": MaterialLab.concrete(Color(0.390, 0.375, 0.352), 1.0),
		"road": MaterialLab.asphalt(Color(0.128, 0.126, 0.130)),
		"dust": MaterialLab.sand(Color(0.430, 0.388, 0.312)),
		# The one earth-red in the game: interior sand blown across the tarmac.
		"heix": MaterialLab.sand(Color(0.420, 0.258, 0.196)),

		# ── MID band. Every saturated thing in the level is in this block and
		# there is nothing saturated outside it.
		"shutter_blue": MaterialLab.painted_metal(Color(0.118, 0.278, 0.352), 0.8),
		"shutter_green": MaterialLab.painted_metal(Color(0.132, 0.288, 0.212), 0.8),
		"shutter_red": MaterialLab.painted_metal(Color(0.400, 0.200, 0.180), 0.8),
		"paint_teal": MaterialLab.painted_metal(Color(0.098, 0.246, 0.302), 0.55),
		"paint_green": MaterialLab.painted_metal(Color(0.140, 0.300, 0.196), 0.55),
		"paint_red": MaterialLab.painted_metal(Color(0.420, 0.212, 0.190), 0.55),
		"paint_ochre": MaterialLab.painted_metal(Color(0.480, 0.352, 0.118), 0.6),
		"sign": MaterialLab.painted_metal(Color(0.176, 0.212, 0.268), 0.55),
		"steel": MaterialLab.painted_metal(Color(0.075, 0.074, 0.080), 0.9),
		"rust": MaterialLab.rusted_metal(Color(0.268, 0.146, 0.098), 1.0),
		"rebar": MaterialLab.rusted_metal(Color(0.560, 0.300, 0.128), 1.0),
		"tank": MaterialLab.painted_metal(Color(0.055, 0.052, 0.054), 0.85),
		"tyre": MaterialLab.painted_metal(Color(0.052, 0.050, 0.052), 1.0),
		"crate": MaterialLab.cloth(Color(0.392, 0.268, 0.152), 0.92),
		"cloth": MaterialLab.cloth(Color(0.640, 0.600, 0.540), 0.95),
		"canvas": MaterialLab.cloth(Color(0.582, 0.540, 0.470), 0.95),
		"hessian": MaterialLab.cloth(Color(0.412, 0.358, 0.252), 0.95),
		# Painted lettering. Capped at V 0.70: the brightest paint in the town
		# still sits under the thobe.
		"letter_pale": MaterialLab.plaster(Color(0.700, 0.678, 0.618), 0.4),
		"letter_dark": MaterialLab.plaster(Color(0.088, 0.086, 0.092), 0.4),

		# ── Planting. Wind lives in the shader; the anchor heights differ per
		# species so a palm crown travels and a wall creeper barely moves.
		"palm": PropKit.foliage_material(Color(0.196, 0.238, 0.148), STREET_Y, 7.0, 0.5),
		"ficus": PropKit.foliage_material(Color(0.148, 0.212, 0.132), STREET_Y, 4.5, 0.32),
		"bougain": PropKit.foliage_material(Color(0.392, 0.108, 0.232), STREET_Y + 2.2, 1.2, 0.30),
		"trunk": MaterialLab.plaster(Color(0.268, 0.236, 0.196), 1.0),

		# ── Practicals. At mid-morning the only lights that matter are the ones
		# INSIDE, because every opening on a sunlit street is otherwise a black
		# hole punched in the facade.
		"bulb": MaterialLab.emissive(Color(1.0, 0.760, 0.470), 2.2),
		"strip": MaterialLab.emissive(Color(0.840, 0.930, 0.900), 2.6),
	}
	# Grime creeps up from the street, not from y = 0 in some other level.
	for key: String in ["render", "render_b", "render_c", "render_pale",
			"render_warm", "render_cool", "render_rose", "block", "block_raw", "kerb"]:
		mats[key].set_shader_parameter("grime_origin_y", STREET_Y)
		mats[key].set_shader_parameter("grime_falloff", 2.1)
		mats[key].set_shader_parameter("grime_color", Color(0.26, 0.22, 0.17))
		mats[key].set_shader_parameter("grime_amount", 0.48)
	return mats


## Mid-morning, high and hard. Everything the benchmark learned still applies:
## the key is real, the shadow is the complement, and the value range is kept
## low enough that a white thobe owns the frame.
static func mood() -> LightingRig.Mood:
	var m := LightingRig.Mood.new()

	# Front-three-quarter, deliberately unlike Brega. Brega's key is behind the
	# geometry because a dead plant at first light should be a silhouette
	# problem; a town at mid-morning is the opposite, so the sun comes over the
	# player's shoulder, the street is lit, and the shadows fall away to the
	# left across everything he has to read.
	m.sun_angles = Vector2(-47.0, 38.0)
	m.sun_color = Color(1.0, 0.925, 0.815)     # ~4800 K, two hours after dawn
	m.sun_energy = 2.3
	m.sun_angular_distance = 0.6
	m.sun_disc_size = 0.30
	m.sun_fog_energy = 0.9

	# Sky bounce into the shadows, which at this hour is the whole shadow.
	# Sky into the shadow side, which at this hour is a hard blue.
	m.fill_angles = Vector2(-26.0, -168.0)
	m.fill_color = Color(0.360, 0.500, 0.780)
	m.fill_energy = 0.80

	m.rim_angles = Vector2(-14.0, 196.0)
	m.rim_color = Color(1.0, 0.880, 0.720)
	m.rim_energy = 2.6
	m.rim_cull_mask = 2

	m.hero_fill_energy = 1.1
	m.hero_fill_color = Color(0.86, 0.88, 0.94)
	m.hero_fill_angles = Vector2(-18.0, -36.0)

	# A real daylight sky, not a dawn gradient — but the horizon band is
	# bleached straw, not grey-blue. Aerial perspective in World 1 is always
	# WARM: this is a Saharan dust load, not temperate haze, and it is the most
	# location-specific lighting fact in the game. The town bands have to sit
	# back into something the colour of the dust they stand on.
	m.sky_top = Color(0.190, 0.320, 0.530)
	m.sky_horizon = Color(0.700, 0.662, 0.572)
	m.ground_horizon = Color(0.520, 0.470, 0.396)
	m.ground_bottom = Color(0.270, 0.240, 0.205)
	m.sky_energy = 1.0
	m.sky_curve = 0.20
	m.ambient_energy = 0.42

	# Depth fog carries the four town bands apart. At 0.00055 they all sat on
	# the same plane and the skyline read as a decal; this is still gentle
	# (about a third of the way to the fog colour at the far ridge) but it is
	# the difference between a backdrop and a distance.
	m.fog_color = Color(0.762, 0.700, 0.588)
	m.fog_density = 0.0016
	m.fog_sun_scatter = 0.10
	m.fog_emission = Color(0.05, 0.05, 0.055)
	m.fog_anisotropy = 0.55
	m.volumetric_density = 0.00060

	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.0
	m.white = 9.0

	# AgX ignores `white`, so the 9.0 above was doing nothing and the frame ran
	# on the engine's 16.29. Mid-morning at 4.2 put every render face on the far
	# end of that shoulder, which is why a town with nine albedo values on
	# screen rendered as three.
	m.agx_white = 9.5
	m.agx_contrast = 1.45
	# A white-rendered street at ten in the morning throws a lot of light back
	# up. Without the bounce the undersides of the awnings and the stall tops go
	# to a flat shadow value and the hero reads as a sticker on the frame.
	m.bounce_energy = 0.34
	m.bounce_color = Color(0.96, 0.88, 0.74)

	# The daytime level takes the grade further than Brega does: this is the one
	# frame in World 1 with real sky in it, and the sky is the only cool thing
	# available to put into the shadows.
	m.grade_shadow_tint = Color(0.38, 0.46, 0.66)
	m.grade_highlight_tint = Color(0.58, 0.53, 0.45)
	m.grade_strength = 0.85
	m.glow_intensity = 0.10
	m.glow_hdr_threshold = 2.4
	# The town now supplies its own colour in the mids, so the global boost
	# comes down — it was pushing the sky before it pushed the shutters.
	m.adjustment_saturation = 1.06
	m.adjustment_contrast = 1.12
	m.dof_near_distance = 0.0
	m.dof_distance = 0.0
	return m


# --- Backdrop ---------------------------------------------------------------

## The town behind the street: four bands of flat-roofed housing stepping back
## into the dust haze, then the ridge and the sky.
##
## Four, not two, and each one further back is lower, paler and more broken
## up — that is the whole trick. A skyline is not a row of blocks, it is a
## rhythm of heights with holes in it that you can see the next rhythm through.
## Roughly one block in five is turned a few degrees off the street grid so a
## lit return face shows; that single change is what stops a band reading as
## one flat-fronted wall.
##
## The minaret is skyline only. It is never a platform, never a target and
## nothing is ever placed on it — it is there because it is there in every
## town on this coast, and it is treated with the respect that implies.
static func deep_layers(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5

	LevelKit.prop(parent, Vector3(mid, STREET_Y - 26.0, -220.0),
		Vector3(span * 2.6 + 900.0, 40.0, 180.0), mats["dust"], "Plain")

	var rng := RandomNumberGenerator.new()
	rng.seed = 5501

	# z, base drop, height range, gap range. The near band is the one seen down
	# the alleys, so it keeps full height and full detail; the rest get wider
	# blocks and bigger holes, which is both cheaper and more truthful — you do
	# not read individual houses at a hundred metres, you read a rhythm.
	var bands := [
		{"z": -34.0, "drop": 0.6, "lo": 5.0, "hi": 9.0, "gap": Vector2(3.0, 9.0),
			"w": Vector2(12.0, 26.0)},
		{"z": -62.0, "drop": 1.6, "lo": 6.0, "hi": 12.5, "gap": Vector2(5.0, 18.0),
			"w": Vector2(16.0, 34.0)},
		{"z": -108.0, "drop": 3.4, "lo": 4.5, "hi": 9.5, "gap": Vector2(9.0, 30.0),
			"w": Vector2(22.0, 46.0)},
	]
	var tones := ["render", "render_b", "render_c", "render_warm", "render_cool",
		"render_pale", "render_rose", "block"]

	for band_i in bands.size():
		var band: Dictionary = bands[band_i]
		var z0: float = band["z"]
		var base: float = STREET_Y - 1.0 - float(band["drop"])
		var gap: Vector2 = band["gap"]
		var wr: Vector2 = band["w"]
		var x := x_from - 120.0
		var step := 0
		while x < x_to + 120.0:
			var w := rng.randf_range(wr.x, wr.y)
			# Height walks rather than being drawn fresh each time, so a run of
			# blocks steps up and back down like a real street instead of
			# jittering. Every eighth block is a tower and it punctuates.
			var h := lerpf(float(band["lo"]), float(band["hi"]),
				0.5 + 0.5 * sin(float(step) * 0.9 + float(band_i)))
			if step % 8 == 3:
				h = float(band["hi"]) * rng.randf_range(1.35, 1.75)
			var zz := z0 + rng.randf_range(-5.0, 5.0)
			var tone: Material = mats[tones[(step * 3 + band_i) % tones.size()]]

			var body := LevelKit.prop(parent, Vector3(x + w * 0.5, base + h * 0.5, zz),
				Vector3(w, h, 10.0), tone, "TownBlock")
			# The turned corner. A few degrees is all it takes: the return face
			# picks up a different amount of key and the band stops being flat.
			if step % 5 == 2:
				body.rotation.y = rng.randf_range(-0.30, 0.30)
			var parapet := LevelKit.prop(parent,
				Vector3(x + w * 0.5, base + h + 0.28, zz - 0.3),
				Vector3(w * 1.01, 0.56, 10.2), mats["block"], "TownParapet")
			var cornice := LevelKit.prop(parent,
				Vector3(x + w * 0.5, base + h - 0.16, zz + 5.2),
				Vector3(w + 0.5, 0.28, 0.5), mats["block"], "TownCornice")
			# Nothing in the backdrop casts. It is thirty-four to a hundred and
			# forty metres behind the play line, every one of its shadows lands
			# on something the camera cannot see, and four cascades of it is the
			# most expensive nothing in the level.
			for n: GeometryInstance3D in [body, parapet, cornice]:
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			# Openings. At this distance a facade is a grid of dark holes and
			# nothing else, and without them a block is a coloured slab. One
			# MultiMesh per block, so a whole band is a handful of draw calls.
			if band_i < 2:
				_window_grid(parent, x + 0.8, base + 1.2, w - 1.6, h - 2.4,
					zz + 5.05, mats["dark"], rng, Vector2(0.80, 1.10))
			if band_i == 0 and rng.randf() < 0.5:
				PropKit.roof_kit(parent, x + 0.6, base + h, w - 1.2, zz + 4.6,
					mats["block"], mats["tank"], mats["rebar"], int(x))
			elif rng.randf() < 0.4:
				# Further back, the roofline detail is two tanks and a parapet
				# step. Anything more is invisible and costs the same.
				_mi(parent, "FarTank", _cyl(0.45, 0.95, 8), mats["tank"],
					Vector3(x + w * 0.35, base + h + 0.9, zz + 2.0)).cast_shadow = \
						GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# An added storey set back off the frontage, on the near band. It is
			# the single most Libyan roofline there is.
			if band_i == 0 and step % 3 == 1:
				var aw := w * rng.randf_range(0.40, 0.65)
				var ah := rng.randf_range(2.6, 3.4)
				var added := LevelKit.prop(parent,
					Vector3(x + w * 0.5, base + h + ah * 0.5, zz - 1.4),
					Vector3(aw, ah, 7.0), tone, "AddedStorey")
				added.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			x += w + rng.randf_range(gap.x, gap.y)
			step += 1

	_skyline_landmarks(parent, mats, mid)


## Three landmarks, all far behind the play line and all untouchable. A town
## skyline needs verticals that are not housing or it reads as a suburb, and a
## crossroads town on this coast has exactly these three.
static func _skyline_landmarks(parent: Node3D, mats: Dictionary, mid: float) -> void:
	# The minaret. Skyline only: no platform, no target, nothing placed on it.
	var mx := mid + 64.0
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 11.0, -150.0),
		Vector3(4.2, 26.0, 4.2), mats["render_pale"], "MinaretShaft")
	for i in 3:
		LevelKit.prop(parent, Vector3(mx, STREET_Y + 6.0 + i * 6.0, -147.8),
			Vector3(4.5, 0.30, 4.5), mats["render_c"], "MinaretBand%d" % i)
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 24.4, -150.0),
		Vector3(5.4, 0.9, 5.4), mats["block"], "MinaretGallery")
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 25.2, -150.0),
		Vector3(5.8, 0.22, 5.8), mats["render_c"], "MinaretGalleryCap")
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 27.2, -150.0),
		Vector3(3.2, 4.2, 3.2), mats["render_pale"], "MinaretLantern")
	_mi(parent, "MinaretCap",
		_cyl(1.5, 2.2, 10, 0.05), mats["render_c"],
		Vector3(mx, STREET_Y + 30.4, -150.0))

	# The water tower: a mushroom on four legs, on the other side of the frame
	# so the two verticals never stack.
	var wx := mid - 92.0
	for i in 4:
		var leg := _mi(parent, "TowerLeg%d" % i, _cyl(0.34, 17.0, 6), mats["block"],
			Vector3(wx + (-1.0 if i % 2 == 0 else 1.0) * 2.4,
				STREET_Y + 8.5, -168.0 + (-2.4 if i < 2 else 2.4)))
		leg.rotation.z = (0.035 if i % 2 == 0 else -0.035)
	_mi(parent, "TowerBowl", _cyl(5.4, 4.6, 14, 2.4), mats["render_pale"],
		Vector3(wx, STREET_Y + 19.0, -168.0))
	_mi(parent, "TowerCap", _cyl(2.6, 1.4, 14, 1.2), mats["block"],
		Vector3(wx, STREET_Y + 21.9, -168.0))

	# A lattice comms mast, because every Libyan town has one and a lattice is
	# free silhouette against a pale sky.
	var cx := mid + 158.0
	for i in 3:
		var leg2 := _mi(parent, "MastLeg%d" % i, _cyl(0.16, 30.0, 5), mats["steel"],
			Vector3(cx + sin(TAU * i / 3.0) * 1.1, STREET_Y + 15.0,
				-196.0 + cos(TAU * i / 3.0) * 1.1))
		leg2.rotation.z = sin(TAU * i / 3.0) * 0.02
	var braces: Array[Transform3D] = []
	for i in 14:
		braces.append(Transform3D(Basis(Vector3(0, 0, 1), 0.7 if i % 2 == 0 else -0.7),
			Vector3(cx, STREET_Y + 1.5 + i * 2.1, -196.0)))
	_mm(parent, "MastBraces", LevelKit.chamfer_mesh(Vector3(2.6, 0.10, 0.10)),
		mats["steel"], braces)
	for i in 3:
		LevelKit.prop(parent, Vector3(cx, STREET_Y + 24.0 + i * 2.2, -195.4),
			Vector3(1.9, 0.5, 0.35), mats["steel"], "MastPanel%d" % i)


# --- The far side of the street ---------------------------------------------

## The far terrace: what the player sees across the road, and the only thing in
## the level that can give the town depth rather than length.
##
## It is authored as a SEQUENCE OF PLOTS, not a run of blocks. The critique
## that produced this was correct and blunt: a continuous row of boxes with
## different widths is still a wall. So the frontage is broken by things that
## are not buildings — an alley you can see all the way down, a walled
## courtyard with a tree in it, a mosque courtyard wall, a tyre yard set back
## off the road — and between them the terrace itself steps in height, in
## depth and in colour, and turns a corner wherever the building line moves.
##
## Everything here is decoration. Nothing on the far side has collision and
## nothing on it is reachable; the far side is the picture, the near side is
## the game.
static func far_terrace(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991

	# Runs and features alternate. Features are what buy the depth, so they are
	# frequent — roughly one every thirty-five metres, which means the wide
	# open frames at the crossroads always contain at least one.
	var features := ["alley", "courtyard", "alley", "mosque", "alley",
		"yard", "courtyard", "alley"]
	var fi := 0
	var x := x_from - 34.0
	var plot := 0
	while x < x_to + 34.0:
		if plot % 2 == 0:
			x = _far_run(parent, mats, x, rng, plot)
		else:
			match features[fi % features.size()]:
				"alley": x = _alley(parent, mats, x, rng, plot)
				"courtyard": x = _courtyard(parent, mats, x, rng, plot)
				"mosque": x = _mosque_court(parent, mats, x, rng, plot)
				_: x = _repair_yard(parent, mats, x, rng, plot)
			fi += 1
		plot += 1


## One run of far terrace: two to four units that step. The step is the point —
## height, frontage depth and render tone all change at every party wall, and
## where the frontage moves the corner is turned with a real return wall so you
## can see that the building has a side.
static func _far_run(parent: Node3D, mats: Dictionary, x: float,
		rng: RandomNumberGenerator, seed_: int) -> float:
	var units := rng.randi_range(2, 3)
	# A run starts at a height and walks; the walk is what a terrace does.
	var h := rng.randf_range(5.6, 10.0)
	var zf := FAR_FRONT + rng.randf_range(-1.2, 1.2)
	var tone_i := seed_ * 3
	for _u in units:
		var w := rng.randf_range(7.5, 14.0)
		var new_zf := zf
		if rng.randf() < 0.40:
			new_zf = clampf(zf + rng.randf_range(-2.6, 2.6), FAR_FRONT - 3.4, FAR_FRONT + 1.6)
		# Turn the corner before moving the building line, or the two blocks
		# just intersect and the step reads as a modelling mistake.
		if absf(new_zf - zf) > 0.4:
			_return_wall(parent, mats, x, minf(zf, new_zf), maxf(zf, new_zf) + 0.4,
				STREET_Y, h + rng.randf_range(-0.6, 0.6), tone_i)
		zf = new_zf

		var bare := rng.randf() < 0.28
		var tone: Material = mats["block_raw"] if bare else _render_tone(mats, tone_i)
		LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + h * 0.5, zf - 4.0),
			Vector3(w, h, 8.0), tone, "FarBlock")
		PropKit.building_massing(parent, x, STREET_Y, w, h, zf,
			mats["render_c"] if not bare else mats["block"], mats["block"], 0, int(x))
		PropKit.roof_kit(parent, x + 0.8, STREET_Y + h, w - 1.6, zf - 0.4,
			mats["block"], mats["tank"], mats["rebar"], int(x) + 41)
		if rng.randf() < 0.6:
			PropKit.stair_head(parent,
				Vector3(x + w * 0.5 + rng.randf_range(-3.0, 3.0), STREET_Y + h, zf - 2.4),
				mats["render_b"], mats["shutter_green"], mats["block"])
		# Downpipes, conduit and condensers. On a sunlit wall this is what a
		# facade is made of: every one of them throws a hard vertical shadow.
		if bare:
			_unfinished(parent, mats, x, w, h, zf, rng)
		else:
			town_facade(parent, mats, x + 0.6, STREET_Y + 3.9, w - 1.2, h - 4.4,
				zf + 0.04, int(x) + 17)

		# Every unit steps. Down more often than up, so a run reads as falling
		# away toward the next hole in the frontage.
		h = clampf(h + rng.randf_range(-2.4, 1.8), 4.6, 12.5)
		tone_i += 1
		x += w + rng.randf_range(0.0, 0.8)
	return x


## The block that never got finished: bare blockwork, an open ground floor of
## columns with a dark void behind it, and the rebar of the storey that was
## always going to be added standing up off the roof.
static func _unfinished(parent: Node3D, mats: Dictionary, x: float, w: float,
		h: float, zf: float, rng: RandomNumberGenerator) -> void:
	var cols := maxi(3, int(w / 3.4))
	for i in cols + 1:
		var cx := x + float(i) * (w / float(cols))
		LevelKit.prop(parent, Vector3(cx, STREET_Y + 1.7, zf - 0.1),
			Vector3(0.42, 3.4, 0.5), mats["block"], "Column%d" % i)
	# The void between the columns. A dark plane set back is worth more than a
	# painted-on shadow: the columns cast into it.
	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + 1.7, zf - 1.5),
		Vector3(w - 0.6, 3.4, 0.4), mats["dark"], "GroundVoid")
	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + 3.55, zf - 0.2),
		Vector3(w, 0.3, 1.0), mats["block"], "SlabEdge")
	# Rebar cages off the roof, tall and thin and bent over at the top.
	var bars: Array[Transform3D] = []
	for i in int(w / 1.1):
		for k in 4:
			var bx := x + 0.8 + float(i) * 1.1 + (0.0 if k % 2 == 0 else 0.16)
			var bz := zf - 0.6 - (0.0 if k < 2 else 0.24)
			bars.append(Transform3D(
				Basis(Vector3(0, 0, 1), rng.randf_range(-0.14, 0.14)),
				Vector3(bx, STREET_Y + h + rng.randf_range(0.35, 0.95), bz)))
	_mm(parent, "RebarForest", LevelKit.chamfer_mesh(Vector3(0.035, 1.5, 0.035)),
		mats["rebar"], bars)
	# The floors above are shell only: openings punched, never glazed.
	_window_grid(parent, x + 0.8, STREET_Y + 4.2, w - 1.6, h - 5.0, zf + 0.06,
		mats["dark"], rng, Vector2(0.86, 1.20))
	# Shuttering timber left stacked on the roof.
	for i in 3:
		var p := LevelKit.prop(parent,
			Vector3(x + w * 0.4 + i * 0.4, STREET_Y + h + 0.2 + i * 0.16, zf - 3.2),
			Vector3(3.2, 0.14, 0.9), mats["crate"], "Shutter%d" % i)
		p.rotation.y = rng.randf_range(-0.2, 0.2)


## A return wall: the side of a building, standing where the frontage steps.
## Corners are the cheapest depth in the world and this level had none.
static func _return_wall(parent: Node3D, mats: Dictionary, x: float,
		z_from: float, z_to: float, base_y: float, height: float,
		tone_i: int) -> void:
	var d := maxf(0.8, z_to - z_from)
	var zc := (z_from + z_to) * 0.5
	LevelKit.prop(parent, Vector3(x, base_y + height * 0.5, zc),
		Vector3(0.55, height, d), _render_tone(mats, tone_i + 2), "Return")
	LevelKit.prop(parent, Vector3(x, base_y + height - 0.13, zc),
		Vector3(0.80, 0.26, d + 0.3), mats["block"], "ReturnCornice")
	# Two openings in the flank, placed down the depth rather than the width.
	var rows := maxi(1, int(height / 3.2))
	for r in rows:
		LevelKit.prop(parent,
			Vector3(x + 0.30, base_y + 1.8 + float(r) * 3.0, zc + d * 0.15),
			Vector3(0.14, 1.05, 0.72), mats["dark"], "ReturnWindow%d" % r)


## THE ALLEY MOUTH. The single highest-value object in this level: a gap you
## can see sixteen metres down, with a lit back wall at the end of it, laundry
## and cable crossing it at four heights and an outside stair climbing one
## side. The whole reason the far terrace stopped reading as a wall.
static func _alley(parent: Node3D, mats: Dictionary, x: float,
		rng: RandomNumberGenerator, seed_: int) -> float:
	var gw := rng.randf_range(5.4, 7.6)
	var zf := FAR_FRONT
	var h := rng.randf_range(7.0, 10.0)

	# Both flanks, facing each other. These are what make the gap a corridor
	# instead of a hole.
	for side in 2:
		var sx := x + (0.0 if side == 0 else gw)
		LevelKit.prop(parent, Vector3(sx, STREET_Y + h * 0.5, zf - 8.5),
			Vector3(0.6, h, 17.0), _render_tone(mats, seed_ + side), "AlleyFlank%d" % side)
		LevelKit.prop(parent, Vector3(sx, STREET_Y + h - 0.14, zf - 8.5),
			Vector3(0.9, 0.28, 17.2), mats["block"], "AlleyCornice%d" % side)
		for r in maxi(1, int(h / 3.1)):
			for k in 4:
				LevelKit.prop(parent,
					Vector3(sx + (0.28 if side == 0 else -0.28),
						STREET_Y + 2.0 + float(r) * 3.0, zf - 2.0 - float(k) * 3.6),
					Vector3(0.14, 1.05, 0.70), mats["dark"], "AlleyWin")
		# A downpipe running the full height, standing off the flank.
		_mi(parent, "AlleyDrop%d" % side, _cyl(0.085, h, 7), mats["rust"],
			Vector3(sx + (0.34 if side == 0 else -0.34), STREET_Y + h * 0.5, zf - 5.4))

	# Floor and the sunlit wedge on it. The sun is high and to the right, so
	# exactly one triangle of this floor is lit and the rest is sky-blue fill.
	LevelKit.prop(parent, Vector3(x + gw * 0.5, STREET_Y + 0.04, zf - 8.5),
		Vector3(gw, 0.08, 17.0), mats["kerb"], "AlleyFloor")
	var wedge := _mi(parent, "AlleyLight", _quad(gw * 0.5, 9.0),
		PropKit.gradient_decal(Color(1.0, 0.94, 0.80), 0.55, "radial"),
		Vector3(x + gw * 0.78, STREET_Y + 0.10, zf - 5.0),
		Vector3(-PI * 0.5, 0.0, 0.0))
	wedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Everything past the mouth goes in one group and comes out of the shadow
	# pass. The slot is already in full shade — the right-hand flank puts it
	# there — so nothing down it is casting anything the camera can resolve.
	var deep := _group(parent, "AlleyDeep")

	# The back of the alley: a lower cross block, so the top of it catches the
	# key and the eye is pulled all the way down the slot.
	var bh := rng.randf_range(4.4, 6.2)
	LevelKit.prop(deep, Vector3(x + gw * 0.5, STREET_Y + bh * 0.5, zf - 18.0),
		Vector3(gw + 5.0, bh, 5.0), mats["render_pale"], "AlleyBack")
	LevelKit.prop(deep, Vector3(x + gw * 0.5, STREET_Y + bh + 0.22, zf - 18.0),
		Vector3(gw + 5.2, 0.44, 5.2), mats["block"], "AlleyBackParapet")
	_window_grid(deep, x + 0.4, STREET_Y + 1.0, gw - 0.8, bh - 2.0, zf - 15.45,
		mats["dark"], rng, Vector2(0.75, 1.05))

	# The outside stair. A diagonal in a frame of verticals, and it is the one
	# shape that says "people go up there".
	var steps: Array[Transform3D] = []
	for i in 14:
		steps.append(Transform3D(Basis.IDENTITY,
			Vector3(x + 0.95, STREET_Y + 0.22 + float(i) * 0.30, zf - 12.4 + float(i) * 0.42)))
	_mm(deep, "AlleyStair", LevelKit.chamfer_mesh(Vector3(1.5, 0.16, 0.44)),
		mats["block"], steps)
	var stair_rail := LevelKit.prop(deep, Vector3(x + 1.7, STREET_Y + 2.6, zf - 9.6),
		Vector3(0.06, 0.06, 6.6), mats["rust"], "AlleyStairRail")
	stair_rail.rotation.x = -0.62

	# Drape: laundry and cable crossing the slot at four heights. This is the
	# level's anti-deadness rule paid in full — nothing else in the frame moves.
	var colours := [Color(0.55, 0.252, 0.248), Color(0.18, 0.36, 0.48),
		Color(0.64, 0.60, 0.53), Color(0.24, 0.42, 0.28), Color(0.52, 0.40, 0.16)]
	for i in 3:
		var ly := STREET_Y + 3.4 + float(i) * 1.9
		PropKit.laundry_line(deep,
			Vector3(x + 0.6, ly, zf - 3.4 - float(i) * 4.2),
			Vector3(x + gw - 0.6, ly - 0.15, zf - 3.4 - float(i) * 4.2), 0.26,
			mats["rust"], colours, seed_ * 13 + i)
	for i in 4:
		PropKit.cable(deep,
			Vector3(x - 0.2, STREET_Y + 4.6 + float(i) * 1.1, zf - 1.5 - float(i) * 3.8),
			Vector3(x + gw + 0.2, STREET_Y + 5.0 + float(i) * 1.0, zf - 2.2 - float(i) * 3.8),
			0.38, mats["steel"], 8)

	# A lit doorway in the back wall, sixteen metres down. This is the payoff
	# for the whole slot: the eye runs down a dark corridor and lands on a warm
	# rectangle, and that single light is what turns a gap between two blocks
	# into a place that continues past the frame.
	_interior(deep, mats, Vector3(x + gw * 0.5, STREET_Y, zf - 15.45),
		2.2, 2.35, mats["strip"], 1.6, true)
	_crate_pile(deep, mats, Vector3(x + 0.9, STREET_Y + 0.08, zf - 2.2), 4, rng)
	# A skip, because every alley has one and it blocks the bottom of the slot.
	LevelKit.prop(deep, Vector3(x + gw * 0.55, STREET_Y + 0.65, zf - 7.4),
		Vector3(2.6, 1.3, 1.5), mats["paint_ochre"], "Skip")
	LevelKit.prop(deep, Vector3(x + gw * 0.55, STREET_Y + 1.34, zf - 7.4),
		Vector3(2.8, 0.14, 1.7), mats["rust"], "SkipRim")
	_no_shadows(deep)
	return x + gw


## A walled courtyard: wall, gate, a tree behind it, and a bougainvillea over
## the coping. The brief asked for "a gap with a wall and a tree behind it" and
## this is that, plus the one magenta in the level.
static func _courtyard(parent: Node3D, mats: Dictionary, x: float,
		rng: RandomNumberGenerator, seed_: int) -> float:
	var w := rng.randf_range(15.0, 20.0)
	var zf := FAR_FRONT + 0.6
	PropKit.perimeter_wall(parent, x, STREET_Y, w, 2.9, zf,
		mats["render_warm"], mats["render_c"])

	# The gate: two piers and a steel leaf standing ajar, so the courtyard is
	# not sealed. A sliver of bright paving behind it does more for depth than
	# the whole wall does.
	var gx := x + w * rng.randf_range(0.32, 0.62)
	for side in 2:
		LevelKit.prop(parent, Vector3(gx + (-1.6 if side == 0 else 1.6),
			STREET_Y + 1.85, zf), Vector3(0.6, 3.7, 1.0), mats["render_c"], "GatePier%d" % side)
	LevelKit.prop(parent, Vector3(gx, STREET_Y + 3.75, zf),
		Vector3(3.9, 0.3, 1.1), mats["block"], "GateHead")
	var leaf := LevelKit.prop(parent, Vector3(gx - 0.7, STREET_Y + 1.5, zf + 0.5),
		Vector3(1.4, 3.0, 0.08), mats["paint_green"], "GateLeaf")
	leaf.rotation.y = -0.55
	LevelKit.prop(parent, Vector3(gx + 0.6, STREET_Y + 1.5, zf - 0.2),
		Vector3(1.5, 3.0, 0.3), mats["dark"], "GateVoid")
	LevelKit.prop(parent, Vector3(gx, STREET_Y + 0.05, zf - 4.0),
		Vector3(3.2, 0.10, 8.0), mats["render_pale"], "CourtPaving")

	# The house inside, the planting and the paving all sit behind a 2.9 m
	# wall, so nothing they throw clears it. One group, no shadow pass.
	var behind := _group(parent, "CourtyardBehind")
	var hh := rng.randf_range(6.0, 7.8)
	LevelKit.prop(behind, Vector3(x + w * 0.5, STREET_Y + hh * 0.5, zf - 11.0),
		Vector3(w * 0.72, hh, 9.0), _render_tone(mats, seed_ + 4), "Villa")
	LevelKit.prop(behind, Vector3(x + w * 0.5, STREET_Y + hh + 0.26, zf - 11.0),
		Vector3(w * 0.74, 0.52, 9.2), mats["block"], "VillaParapet")
	_window_grid(behind, x + w * 0.18, STREET_Y + 1.4, w * 0.64, hh - 2.6,
		zf - 6.45, mats["dark"], rng, Vector2(0.85, 1.20))
	LevelKit.prop(behind, Vector3(x + w * 0.5, STREET_Y + 3.6, zf - 6.1),
		Vector3(w * 0.5, 0.14, 1.4), mats["block"], "VillaBalcony")
	LevelKit.prop(behind, Vector3(x + w * 0.5, STREET_Y + 4.15, zf - 5.5),
		Vector3(w * 0.5, 0.06, 0.06), mats["rust"], "VillaRail")
	PropKit.roof_kit(behind, x + w * 0.2, STREET_Y + hh, w * 0.5, zf - 7.4,
		mats["block"], mats["tank"], mats["rebar"], seed_ * 5)

	# The tree. A ficus, not a palm — the palms are on the kerb and two
	# identical crowns in one frame is a repeat the eye catches instantly.
	_ficus(behind, mats, Vector3(x + w * 0.18, STREET_Y, zf - 4.4),
		rng.randf_range(5.2, 6.6), rng)
	PropKit.palm(behind, Vector3(x + w * 0.84, STREET_Y, zf - 5.0),
		rng.randf_range(7.0, 9.0), mats["trunk"], mats["palm"], seed_ * 11)

	# Bougainvillea over the coping. Off-budget magenta, once, exactly where a
	# real one is. It is the only thing in the level allowed this hue.
	var vine: Array[Transform3D] = []
	for i in 9:
		var t := float(i) / 8.0
		vine.append(Transform3D(
			Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
				Vector3.ONE * rng.randf_range(0.8, 1.35)),
			Vector3(x + w * (0.58 + t * 0.34), STREET_Y + 2.85 + sin(t * PI) * 0.55,
				zf + rng.randf_range(-0.2, 0.3))))
	_mm(parent, "Bougainvillea", LevelKit.chamfer_mesh(Vector3(1.05, 0.62, 0.95)),
		mats["bougain"], vine)
	_no_shadows(behind)
	return x + w


## A mosque courtyard wall. The wall and its arcade only: the minaret is on the
## far skyline where it belongs. Nothing is stacked against this wall, nothing
## hangs on it, nothing is painted on it and nothing in the level uses it as a
## platform — it is the one clean, swept, undressed surface in the town and
## that restraint is what makes it read as what it is.
static func _mosque_court(parent: Node3D, mats: Dictionary, x: float,
		rng: RandomNumberGenerator, seed_: int) -> float:
	var w := rng.randf_range(24.0, 30.0)
	var zf := FAR_FRONT + 1.0
	var h := 3.9

	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + h * 0.5, zf),
		Vector3(w, h, 0.9), mats["render_pale"], "CourtWall")
	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + h + 0.10, zf),
		Vector3(w + 0.3, 0.26, 1.25), mats["render_c"], "CourtCoping")
	# Stepped merlons along the coping: the one piece of ornament, and it is
	# what a flat coping is missing when it reads as a fence.
	var merlons: Array[Transform3D] = []
	var mcount := int(w / 1.4)
	for i in mcount:
		merlons.append(Transform3D(Basis.IDENTITY,
			Vector3(x + 0.7 + float(i) * (w / float(mcount)),
				STREET_Y + h + 0.42, zf)))
	_mm(parent, "Merlons", LevelKit.chamfer_mesh(Vector3(0.52, 0.42, 1.0)),
		mats["render_c"], merlons)

	# A blind arcade along the wall. Recess first, then the arch ring in front
	# of it, so the arch casts into its own niche.
	var niches := int(w / 3.4)
	var voussoirs: Array[Transform3D] = []
	for i in niches:
		var nx := x + (float(i) + 0.5) * (w / float(niches))
		LevelKit.prop(parent, Vector3(nx, STREET_Y + 1.35, zf + 0.30),
			Vector3(1.55, 2.2, 0.22), mats["shade"], "Niche%d" % i)
		var r := 0.86
		for k in 9:
			var a := PI * (float(k) + 0.5) / 9.0
			voussoirs.append(Transform3D(
				Basis(Vector3(0, 0, 1), a - PI * 0.5),
				Vector3(nx - cos(a) * r, STREET_Y + 2.45 + sin(a) * r, zf + 0.42)))
	_mm(parent, "Voussoirs", LevelKit.chamfer_mesh(Vector3(0.34, 0.24, 0.26)),
		mats["render_c"], voussoirs)

	# The gate, and behind it sunlit paving — an opening onto brightness, not
	# another black hole in a wall.
	var gx := x + w * 0.5
	LevelKit.prop(parent, Vector3(gx, STREET_Y + 1.9, zf + 0.2),
		Vector3(3.4, 3.8, 0.4), mats["render_c"], "MosqueGateSurround")
	LevelKit.prop(parent, Vector3(gx, STREET_Y + 1.5, zf - 0.25),
		Vector3(2.5, 3.0, 0.3), mats["shade"], "MosqueGateVoid")
	LevelKit.prop(parent, Vector3(gx, STREET_Y + 0.06, zf - 6.0),
		Vector3(9.0, 0.12, 11.0), mats["render_pale"], "MosqueCourtPaving")

	# The prayer hall behind the wall: a low mass, a shallow dome, nothing on
	# either of them. All of it stands behind a four-metre wall, so like the
	# courtyard it throws nothing the camera sees.
	var behind := _group(parent, "MosqueBehind")
	LevelKit.prop(behind, Vector3(x + w * 0.5, STREET_Y + 3.4, zf - 15.0),
		Vector3(w * 0.66, 6.8, 11.0), mats["render_pale"], "Hall")
	LevelKit.prop(behind, Vector3(x + w * 0.5, STREET_Y + 7.0, zf - 15.0),
		Vector3(w * 0.68, 0.46, 11.2), mats["render_c"], "HallCornice")
	var dome := SphereMesh.new()
	dome.radius = 3.6
	dome.height = 7.2
	dome.radial_segments = 20
	dome.rings = 10
	dome.is_hemisphere = true
	_mi(behind, "Dome", dome, mats["render_c"],
		Vector3(x + w * 0.5, STREET_Y + 7.2, zf - 15.0))
	_mi(behind, "DomeDrum", _cyl(3.8, 1.0, 20),
		mats["render_pale"], Vector3(x + w * 0.5, STREET_Y + 7.0, zf - 15.0))

	# Two cypresses in the courtyard, tall and narrow, breaking the horizontal.
	for i in 2:
		var cx := x + w * (0.22 + 0.56 * float(i))
		_mi(behind, "CypressTrunk%d" % i, _cyl(0.16, 3.0, 6), mats["trunk"],
			Vector3(cx, STREET_Y + 1.5, zf - 5.0))
		for k in 5:
			var t := float(k) / 4.0
			_mi(behind, "CypressTier%d_%d" % [i, k],
				_cyl(lerpf(1.25, 0.25, t), 1.8, 9), mats["ficus"],
				Vector3(cx, STREET_Y + 2.6 + t * 4.4, zf - 5.0))
	_no_shadows(behind)
	return x + w


## The tyre place. Every crossroads town in Libya has one every few hundred
## metres and the word on the wall is always the same one. It is set back off
## the road behind its own forecourt, which is the other way to put space into
## a frontage: not a hole, a setback.
static func _repair_yard(parent: Node3D, mats: Dictionary, x: float,
		rng: RandomNumberGenerator, seed_: int) -> float:
	var w := rng.randf_range(17.0, 22.0)
	var zf := FAR_FRONT - 5.2

	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + 0.05, zf + 3.2),
		Vector3(w, 0.10, 7.0), mats["dust"], "Forecourt")
	# The workshop: one low box, one wide dark opening, one strip light.
	var h := 4.6
	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + h * 0.5, zf - 4.0),
		Vector3(w, h, 9.0), mats["block_raw"], "Workshop")
	LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + h + 0.24, zf - 4.0),
		Vector3(w + 0.4, 0.48, 9.2), mats["block"], "WorkshopParapet")
	# The workshop block's front face is at zf + 0.5, and everything on it hangs
	# off that number: an opening sunk into a wall instead of cut through it is
	# the single easiest thing to get silently wrong in a code-built level.
	var face := zf + 0.5
	_interior(parent, mats, Vector3(x + w * 0.42, STREET_Y, face + 0.02),
		w * 0.36, 3.5, mats["strip"], 2.2, true)
	# The shutter, rolled up in its drum over the opening.
	_mi(parent, "RollerDrum", _cyl(0.26, w * 0.40, 10), mats["rust"],
		Vector3(x + w * 0.42, STREET_Y + 3.72, face + 0.12), Vector3(0, 0, PI * 0.5))
	LevelKit.prop(parent, Vector3(x + w * 0.42, STREET_Y + 4.05, face + 0.06),
		Vector3(w * 0.46, 0.22, 0.34), mats["block"], "RollerLintel")

	# Hand-painted straight onto the render, which is how these are signed.
	PropKit.sign(parent, "بنشر", Vector3(x + w * 0.76, STREET_Y + 3.4, face + 0.06),
		0.95, mats["letter_dark"], PropKit.FONT_KUFI)
	PropKit.sign(parent, "تصليح إطارات",
		Vector3(x + w * 0.76, STREET_Y + 2.55, face + 0.06), 0.34,
		mats["letter_dark"], PropKit.FONT_NASKH)

	# Yard dressing. Tyres in stacks and leaning, a drum, a compressor, and a
	# car up on a stand with a wheel off — the shape that says what happens here.
	for i in 3:
		_tyre_stack(parent, mats, Vector3(x + 1.6 + float(i) * 1.5, STREET_Y + 0.08,
			zf + rng.randf_range(1.0, 3.6)), rng.randi_range(3, 6), rng)
	for i in 4:
		_mi(parent, "TyreLean%d" % i, _torus(0.20, 0.34), mats["tyre"],
			Vector3(x + w - 2.2 - float(i) * 0.42, STREET_Y + 0.36, zf + 1.4),
			Vector3(deg_to_rad(74.0), 0.0, rng.randf_range(-0.2, 0.2)))
	LevelKit.prop(parent, Vector3(x + w * 0.16, STREET_Y + 0.44, zf + 4.2),
		Vector3(0.62, 0.88, 0.62), mats["paint_teal"], "Drum")
	LevelKit.prop(parent, Vector3(x + w * 0.26, STREET_Y + 0.35, zf + 4.4),
		Vector3(1.1, 0.7, 0.6), mats["paint_ochre"], "Compressor")
	_mi(parent, "AirTank", _cyl(0.24, 1.1, 10), mats["steel"],
		Vector3(x + w * 0.26, STREET_Y + 0.82, zf + 4.4), Vector3(0, 0, PI * 0.5))

	var car := LevelKit.prop(parent, Vector3(x + w * 0.70, STREET_Y + 0.80, zf + 3.4),
		Vector3(4.2, 0.92, 1.8), MaterialLab.painted_metal(Color(0.38, 0.40, 0.36), 0.8), "JackedCar")
	LevelKit.prop(car, Vector3(-0.15, 0.60, 0.0), Vector3(2.4, 0.66, 1.66),
		MaterialLab.painted_metal(Color(0.38, 0.40, 0.36), 0.8), "Cabin")
	LevelKit.prop(car, Vector3(-0.15, 0.60, 0.84), Vector3(2.2, 0.48, 0.05),
		mats["dark"], "Glass")
	_mi(car, "Wheel0", _torus(0.18, 0.34), mats["tyre"], Vector3(1.3, -0.44, 0.86),
		Vector3(PI * 0.5, 0.0, 0.0))
	LevelKit.prop(car, Vector3(-1.35, -0.62, 0.0), Vector3(0.35, 0.36, 0.9),
		mats["steel"], "AxleStand")
	return x + w


# --- The street frontage ----------------------------------------------------

## The street frontage of a Libyan town block, ground floor and up: the shop
## fascia with its painted name, the pavement, whatever that trade leaves out
## on it overnight, and above it the window rhythm, the balconies, the air
## conditioners, the laundry and the runoff streaks.
##
## Called for the near terrace by the level and for every far-side unit by
## `_far_run`, which is why the ground-floor dressing scales with |z|: the near
## frontage is four metres from the camera and every crate on it is read, the
## far one is eighteen and only the silhouette survives.
##
## A blank tan rectangle with one dark line on it is not a building, and it was
## what the first pass of this level was made of.
static func town_facade(parent: Node3D, mats: Dictionary, left_x: float,
		base_y: float, width: float, height: float, z: float,
		seed_ := 1, dress := true) -> Node3D:
	var root := Node3D.new()
	root.name = "TownFacade"
	parent.add_child(root)
	if width < 2.0:
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 373 + 11
	var near := z > -10.0

	if dress:
		_frontage(root, mats, left_x, width, z, rng, seed_, near)
	if height < 2.0:
		return root

	var floors := maxi(1, int(height / 3.0))
	var bays := maxi(2, int(width / 3.2))
	# Laundry, and it is capped hard. A sheet on a line at V 0.82 was the
	# brightest object in the level, which is the one job the thobe has.
	var colours := [
		Color(0.56, 0.256, 0.252), Color(0.20, 0.38, 0.50), Color(0.66, 0.62, 0.54),
		Color(0.26, 0.42, 0.28), Color(0.50, 0.385, 0.145),
	]
	# One building in three has a continuous first-floor balcony instead of a
	# bay-by-bay one. It is a single strong horizontal and it is the fastest
	# way to make two neighbouring blocks read as two different buildings.
	var run_balcony := seed_ % 3 == 0 and floors >= 2

	if run_balcony:
		var by := base_y + height / float(floors) - 0.72
		LevelKit.prop(root, Vector3(left_x + width * 0.5, by, z + 0.52),
			Vector3(width, 0.16, 1.10), mats["block"], "BalconyRun")
		LevelKit.prop(root, Vector3(left_x + width * 0.5, by + 0.52, z + 1.00),
			Vector3(width, 0.08, 0.08), mats["rust"], "BalconyRunRail")
		var balusters: Array[Transform3D] = []
		for i in int(width / 0.28):
			balusters.append(Transform3D(Basis.IDENTITY,
				Vector3(left_x + 0.14 + float(i) * 0.28, by + 0.27, z + 1.00)))
		_mm(root, "RunBalusters", LevelKit.chamfer_mesh(Vector3(0.04, 0.52, 0.04)),
			mats["rust"], balusters)
		PropKit.laundry_line(root,
			Vector3(left_x + width * 0.18, by + 0.62, z + 0.98),
			Vector3(left_x + width * 0.72, by + 0.60, z + 0.98), 0.10,
			mats["rust"], colours, seed_ * 7 + 5)

	if not near:
		# ACROSS THE ROAD. At eighteen metres a deep-set window with a louvred
		# shutter costs fifteen meshes and reads as a dark rectangle, so the
		# far side gets the dark rectangle: one MultiMesh of openings for the
		# whole block, two condensers, and the laundry — which is the only
		# thing up there the eye actually stops on.
		_window_grid(root, left_x, base_y - 0.4, width, height + 0.6, z + 0.03,
			mats["shade"], rng, Vector2(0.86, 1.22))
		for i in 2:
			var ax := left_x + width * (0.28 + 0.44 * float(i))
			LevelKit.prop(root, Vector3(ax, base_y + height * 0.55, z + 0.26),
				Vector3(0.66, 0.44, 0.38), mats["steel"], "AC%d" % i)
		# Three downpipes, and they are worth more than everything else on this
		# wall put together: a sunlit facade at eighteen metres is a flat plane
		# with a grid of holes in it, and a 75 mm pipe standing 140 mm off it
		# draws a hard black vertical the full height of the building.
		for i in 3:
			_mi(root, "FarDrop%d" % i, _cyl(0.075, height + 0.9, 6), mats["rust"],
				Vector3(left_x + width * (0.17 + 0.33 * float(i)),
					base_y + height * 0.5 - 0.25, z + 0.14))
		if not run_balcony and floors >= 2:
			var fy := base_y + height * 0.42
			LevelKit.prop(root, Vector3(left_x + width * 0.42, fy, z + 0.46),
				Vector3(width * 0.44, 0.14, 0.95), mats["block"], "FarBalcony")
			LevelKit.prop(root, Vector3(left_x + width * 0.42, fy + 0.5, z + 0.88),
				Vector3(width * 0.44, 0.34, 0.06), mats["rust"], "FarBalconyRail")
			PropKit.laundry_line(root,
				Vector3(left_x + width * 0.24, fy + 0.62, z + 0.86),
				Vector3(left_x + width * 0.60, fy + 0.60, z + 0.86), 0.10,
				mats["rust"], colours, seed_ * 9 + 2)
		return root

	for f in floors:
		var y := base_y + (float(f) + 0.5) * (height / float(floors))
		for b in bays:
			var x := left_x + (float(b) + 0.5) * (width / float(bays))
			PropKit.window(root, Vector3(x, y, z), Vector2(0.82, 1.15), 0.26,
				mats["render_b"], mats["shade"],
				mats["shutter_blue"] if (seed_ + b + f) % 3 == 0 else null,
				-0.55 if (seed_ + b) % 4 == 0 else -0.15)
			if (seed_ + b + f) % 2 != 0 or (run_balcony and f == 0):
				# An air conditioner and its bracket under the sill, and the
				# stain it has been dripping down the render since it went in.
				LevelKit.prop(root, Vector3(x + 0.62, y - 0.74, z + 0.26),
					Vector3(0.66, 0.44, 0.38), mats["steel"], "AC")
				LevelKit.prop(root, Vector3(x + 0.62, y - 0.98, z + 0.24),
					Vector3(0.74, 0.06, 0.34), mats["rust"], "ACBracket")
				if rng.randf() < 0.5:
					_streak(root, Vector3(x + 0.62, y - 1.85, z + 0.05), 0.5, 1.7, 0.34)
				continue

			# Balcony: slab, rail, balusters, and the line across it.
			var bw: float = width / float(bays) - 0.35
			LevelKit.prop(root, Vector3(x, y - 0.66, z + 0.46),
				Vector3(bw, 0.14, 0.95), mats["block"], "BalconySlab")
			LevelKit.prop(root, Vector3(x, y - 0.14, z + 0.90),
				Vector3(bw, 0.07, 0.07), mats["rust"], "BalconyRail")
			for i in 5:
				LevelKit.prop(root,
					Vector3(x - bw * 0.4 + i * bw * 0.2, y - 0.38, z + 0.90),
					Vector3(0.045, 0.52, 0.045), mats["rust"], "Baluster%d" % i)
			if rng.randf() < 0.7:
				PropKit.laundry_line(root,
					Vector3(x - bw * 0.42, y - 0.06, z + 0.88),
					Vector3(x + bw * 0.42, y - 0.06, z + 0.88), 0.09,
					mats["rust"], colours, seed_ * 7 + f * 3 + b)
			elif rng.randf() < 0.5:
				# A dish on the balcony rail. Half the dishes in the country
				# are mounted on something that was not meant to hold one.
				var dish := _mi(root, "Dish", _cyl(0.34, 0.09, 12, 0.30),
					mats["cloth"], Vector3(x + bw * 0.3, y + 0.10, z + 0.92),
					Vector3(deg_to_rad(66.0), 0.0, 0.0))
				dish.rotation.y = rng.randf_range(-0.3, 0.3)

	# Downpipes at the party walls, standing off the face. Vertical shadow on a
	# sunlit wall is worth more than any amount of surface detail.
	for i in maxi(2, int(width / 8.0)):
		var px := left_x + (float(i) + 0.5) * (width / maxf(float(int(width / 8.0)), 1.0))
		_mi(root, "Downpipe%d" % i, _cyl(0.085, height + 0.6, 7), mats["rust"],
			Vector3(px, base_y + height * 0.5, z + 0.16))
		_streak(root, Vector3(px + 0.22, base_y + height * 0.35, z + 0.05),
			0.6, height * 0.7, 0.22)
	# Runoff off the cornice, always downward. Gravity is the first weathering
	# law and a rendered wall without runs on it is unfinished.
	for i in 2:
		_streak(root, Vector3(left_x + width * rng.randf_range(0.1, 0.9),
			base_y + height * 0.55, z + 0.05), rng.randf_range(0.7, 1.6),
			height * 0.85, 0.26)
	return root


## The ground floor: pavement, fascia, the painted name, the shutter-line
## awning on the far side, the light on inside, and the trade's goods out on
## the pavement. Everything here is a prop — the street is the level's, not
## the kit's.
static func _frontage(root: Node3D, mats: Dictionary, left_x: float,
		width: float, z: float, rng: RandomNumberGenerator, seed_: int,
		near: bool) -> void:
	var cx := left_x + width * 0.5

	# The pavement. A shopfront that opens straight onto asphalt has no section
	# and the street has no edge; 120 mm of kerbstone fixes both.
	LevelKit.prop(root, Vector3(cx, STREET_Y + 0.06, z + 1.30),
		Vector3(width + 0.5, 0.12, 2.40), mats["kerb"], "Pavement")
	LevelKit.prop(root, Vector3(cx, STREET_Y + 0.05, z + 2.48),
		Vector3(width + 0.5, 0.14, 0.18), mats["block"], "PavementEdge")

	# The fascia band the signs are painted on, running the full frontage and
	# stepping forward off the render.
	var fy := STREET_Y + 3.24
	LevelKit.prop(root, Vector3(cx, fy, z + 0.30),
		Vector3(width + 0.24, 0.56, 0.26), mats["render_b"], "Fascia")
	LevelKit.prop(root, Vector3(cx, fy + 0.31, z + 0.34),
		Vector3(width + 0.34, 0.10, 0.36), mats["block"], "FasciaCap")

	# One shop per six metres of frontage. The level's own shopfront run is on
	# a 4.6 m module, so a sign sits roughly one per bay and a bit — which is
	# what a real terrace looks like anyway, because shops knock through.
	# Tighter than this and a ninety-metre run costs twenty dressed bays for a
	# street the camera only ever sees thirty metres of at a time.
	var shops := clampi(int(width / 6.2), 1, 14)
	var boards := [mats["paint_teal"], mats["paint_green"], mats["paint_red"],
		mats["paint_ochre"], mats["render_pale"]]
	var shutters := [mats["shutter_blue"], mats["shutter_green"], mats["shutter_red"]]
	for s in shops:
		var sw := width / float(shops)
		var sx := left_x + (float(s) + 0.5) * sw
		var trade: Array = TRADES[(seed_ * 5 + s * 3) % TRADES.size()]
		var board: Material = boards[(seed_ + s) % boards.size()]
		var pale_board: bool = board == mats["render_pale"]
		var open_shop := rng.randf() < 0.55

		# The far side has no shopfronts of its own — the level only builds the
		# near terrace's — so its openings are made here. The near side's are
		# already there and adding a second set would double the geometry.
		if not near:
			PropKit.shopfront(root, Vector3(sx, STREET_Y, z + 0.02),
				sw - 0.35, 3.0, mats["render_b"],
				shutters[(seed_ + s) % shutters.size()], mats["sign"], open_shop)

		# Painted board on the fascia. Some shops paint the board, some paint
		# straight onto the render and let it fade — both are true and the mix
		# is what stops a terrace of signs looking like a signwriting job.
		if rng.randf() < 0.72:
			LevelKit.prop(root, Vector3(sx, fy, z + 0.44),
				Vector3(sw * 0.90, 0.46, 0.08), board, "SignBoard%d" % s)
		var ink: Material = mats["letter_dark"] if pale_board else mats["letter_pale"]
		if rng.randf() < (0.55 if near else 0.45):
			# Lettering is out of the shadow pass: twelve millimetres of
			# extrusion throws a ragged shadow that only muddies the board.
			PropKit.sign(root, str(trade[0]), Vector3(sx, fy - 0.10, z + 0.50),
				0.30, ink, _font_for(int(trade[1]))).cast_shadow = \
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if near and rng.randf() < 0.4:
				PropKit.sign(root, PHONES[(seed_ + s) % PHONES.size()],
					Vector3(sx, fy - 0.36, z + 0.50), 0.13, ink,
					PropKit.FONT_KUFI).cast_shadow = \
						GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# The light on inside. At mid-morning the shop is the darkest thing on a
		# lit street, and a shutter that is up over an unlit void is a black
		# hole punched in a sunlit wall. Only the open ones get one, because a
		# closed shutter would hide it and the geometry would be wasted.
		if open_shop and rng.randf() < 0.75:
			_interior(root, mats, Vector3(sx, STREET_Y + 0.12, z + 0.04),
				sw * 0.55, 1.62, mats["bulb"], 0.9, near and s % 4 == 0)

		# An awning on the far side only — the near terrace's awnings are placed
		# by the level so the shadows on the play line stay authored.
		if not near and rng.randf() < 0.6:
			var a := LevelKit.prop(root, Vector3(sx, STREET_Y + 2.92, z + 1.20),
				Vector3(sw * 0.88, 0.08, 1.90),
				MaterialLab.cloth(_awning_colour(seed_ + s), 0.95), "Awning%d" % s)
			a.rotation.x = -0.17
			for k in 2:
				var st := LevelKit.prop(root,
					Vector3(sx + (-0.5 + float(k)) * sw * 0.80, STREET_Y + 2.60, z + 1.60),
					Vector3(0.05, 1.0, 0.05), mats["steel"], "AwningStay%d_%d" % [s, k])
				st.rotation.x = 0.5

		if rng.randf() < (0.62 if near else 0.45):
			_shop_goods(root, mats, str(trade[2]), Vector3(sx, STREET_Y + 0.12, z + 1.25),
				sw, rng, near)


## What each trade leaves out on the pavement. The point is not the objects:
## it is that the goods TELL you what the sign says, so the street has content
## even at the distance where the lettering is one pale smear.
static func _shop_goods(parent: Node3D, mats: Dictionary, kind: String, at: Vector3,
		sw: float, rng: RandomNumberGenerator, near: bool) -> void:
	var root := _group(parent, "Goods")
	match kind:
		"produce":
			var tints := [Color(0.44, 0.206, 0.198), Color(0.30, 0.34, 0.12),
				Color(0.50, 0.335, 0.140), Color(0.22, 0.30, 0.16)]
			for i in 4:
				var bx := at.x + (float(i) - 1.5) * 0.72
				LevelKit.prop(root, Vector3(bx, at.y + 0.22, at.z + 0.1),
					Vector3(0.66, 0.34, 0.50), mats["crate"], "Crate%d" % i)
				LevelKit.prop(root, Vector3(bx, at.y + 0.44, at.z + 0.1),
					Vector3(0.58, 0.16, 0.42),
					MaterialLab.cloth(tints[i % tints.size()], 0.9), "Produce%d" % i)
				if i % 2 == 0:
					LevelKit.prop(root, Vector3(bx, at.y + 0.68, at.z + 0.1),
						Vector3(0.60, 0.30, 0.46), mats["crate"], "CrateTop%d" % i)
			if near:
				# Far side keeps the silhouette and drops the small stuff: at
				# eighteen metres a sack is four pixels and a draw call.
				_sacks(root, mats, Vector3(at.x + sw * 0.34, at.y, at.z + 0.3), 3, rng)
		"bakery":
			# A bread rack: three shelves of trays, wheeled out in the morning.
			for i in 3:
				LevelKit.prop(root, Vector3(at.x, at.y + 0.35 + float(i) * 0.42, at.z),
					Vector3(1.5, 0.05, 0.60), mats["steel"], "Shelf%d" % i)
				LevelKit.prop(root, Vector3(at.x, at.y + 0.44 + float(i) * 0.42, at.z),
					Vector3(1.35, 0.12, 0.50),
					MaterialLab.cloth(Color(0.48, 0.36, 0.20), 0.9), "Bread%d" % i)
			for k in 2:
				LevelKit.prop(root, Vector3(at.x + (-0.7 + float(k) * 1.4), at.y + 0.62,
					at.z), Vector3(0.05, 1.25, 0.05), mats["steel"], "RackLeg%d" % k)
		"barber":
			# The pole: alternating discs, which at this size reads better than
			# any attempt at a helix.
			for i in 7:
				LevelKit.prop(root, Vector3(at.x - sw * 0.34, at.y + 0.9 + float(i) * 0.14,
					at.z - 0.55), Vector3(0.20, 0.14, 0.20),
					[mats["paint_red"], mats["letter_pale"], mats["paint_teal"]][i % 3],
					"PoleBand%d" % i)
			_chairs(root, mats, Vector3(at.x + 0.5, at.y, at.z + 0.2), 2, rng)
		"tyres":
			_tyre_stack(root, mats, Vector3(at.x - 0.6, at.y, at.z), 4, rng)
			_tyre_stack(root, mats, Vector3(at.x + 0.7, at.y, at.z + 0.25), 3, rng)
		"satellite":
			for i in 3:
				_mi(root, "StockDish%d" % i, _cyl(0.42, 0.10, 12, 0.38),
					mats["cloth"], Vector3(at.x + (float(i) - 1.0) * 0.55,
						at.y + 0.44, at.z - 0.28),
					Vector3(deg_to_rad(80.0), rng.randf_range(-0.3, 0.3), 0.0))
			_crate_pile(root, mats, Vector3(at.x + sw * 0.3, at.y, at.z + 0.2), 3, rng)
		"cafe":
			_cafe_set(root, mats, at, sw, rng)
		"butcher":
			# The rail and its hooks, under the awning line where the shade is.
			LevelKit.prop(root, Vector3(at.x, at.y + 2.05, at.z - 0.1),
				Vector3(sw * 0.7, 0.06, 0.06), mats["steel"], "Rail")
			for k in 2:
				LevelKit.prop(root, Vector3(at.x + (-0.5 + float(k)) * sw * 0.7,
					at.y + 1.6, at.z - 0.1), Vector3(0.05, 0.95, 0.05),
					mats["steel"], "RailPost%d" % k)
			for i in 3:
				var hx := at.x + (float(i) - 1.0) * 0.5
				LevelKit.prop(root, Vector3(hx, at.y + 1.92, at.z - 0.1),
					Vector3(0.04, 0.22, 0.04), mats["steel"], "Hook%d" % i)
				LevelKit.prop(root, Vector3(hx, at.y + 1.52, at.z - 0.1),
					Vector3(0.24, 0.62, 0.22),
					MaterialLab.cloth(Color(0.40, 0.185, 0.180), 0.88), "Cut%d" % i)
			LevelKit.prop(root, Vector3(at.x + sw * 0.28, at.y + 0.30, at.z + 0.1),
				Vector3(0.55, 0.60, 0.55), mats["crate"], "Block")
		"carpets":
			# Hung off the fascia, three deep, overlapping. Big flat areas of
			# mid-value colour and the best thing a shopfront can wear.
			for i in 3:
				var cxp := at.x + (float(i) - 1.0) * (sw * 0.28)
				var ch := rng.randf_range(1.7, 2.3)
				LevelKit.prop(root, Vector3(cxp, at.y + 2.85 - ch * 0.5, at.z - 0.18 + float(i) * 0.05),
					Vector3(sw * 0.30, ch, 0.05),
					MaterialLab.cloth(_carpet_colour(i + int(at.x)), 0.93), "Carpet%d" % i)
				LevelKit.prop(root, Vector3(cxp, at.y + 2.85 - ch, at.z - 0.16 + float(i) * 0.05),
					Vector3(sw * 0.30, 0.14, 0.055),
					MaterialLab.cloth(Color(0.52, 0.42, 0.22), 0.93), "CarpetEnd%d" % i)
			var roll := LevelKit.prop(root, Vector3(at.x + sw * 0.34, at.y + 0.85, at.z + 0.1),
				Vector3(0.34, 1.7, 0.34),
				MaterialLab.cloth(_carpet_colour(int(at.x) + 7), 0.93), "Roll")
			roll.rotation.z = 0.16
		"gas":
			var bottles: Array[Transform3D] = []
			for i in 8:
				bottles.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)),
					Vector3(at.x + (float(i % 4) - 1.5) * 0.36, at.y + 0.33,
						at.z + (0.0 if i < 4 else -0.36))))
			_mm(root, "Bottles", _cyl(0.16, 0.62, 9), mats["paint_ochre"], bottles)
			LevelKit.prop(root, Vector3(at.x, at.y + 0.04, at.z - 0.18),
				Vector3(1.7, 0.10, 0.9), mats["crate"], "Pallet")
		"builders":
			for i in 5:
				var p := LevelKit.prop(root, Vector3(at.x + (float(i % 3) - 1.0) * 0.52,
					at.y + 0.14 + float(i / 3) * 0.26, at.z),
					Vector3(0.62, 0.24, 0.42), mats["hessian"], "Cement%d" % i)
				p.rotation.y = rng.randf_range(-0.25, 0.25)
			var blocks: Array[Transform3D] = []
			for i in 9:
				blocks.append(Transform3D(Basis.IDENTITY,
					Vector3(at.x + sw * 0.32 + float(i % 3) * 0.42, at.y + 0.11 + float(i / 3) * 0.22,
						at.z + 0.1)))
			_mm(root, "Blocks", LevelKit.chamfer_mesh(Vector3(0.40, 0.20, 0.20)),
				mats["block"], blocks)
		"hardware":
			var pails: Array[Transform3D] = []
			for i in 6:
				pails.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)),
					Vector3(at.x + (float(i % 3) - 1.0) * 0.40, at.y + 0.16 + float(i / 3) * 0.30,
						at.z)))
			_mm(root, "Pails", _cyl(0.17, 0.30, 10, 0.20), mats["paint_teal"], pails)
			if near:
				for i in 3:
					var br := LevelKit.prop(root, Vector3(at.x + sw * 0.3 + float(i) * 0.08,
						at.y + 0.72, at.z - 0.3), Vector3(0.04, 1.45, 0.04),
						mats["crate"], "Broom%d" % i)
					br.rotation.z = 0.12 + float(i) * 0.03
		"clothes":
			LevelKit.prop(root, Vector3(at.x, at.y + 1.75, at.z + 0.1),
				Vector3(sw * 0.75, 0.05, 0.05), mats["steel"], "ClothesRail")
			for i in 6:
				LevelKit.prop(root, Vector3(at.x + (float(i) - 2.5) * (sw * 0.12),
					at.y + 1.30, at.z + 0.1), Vector3(sw * 0.10, 0.85, 0.10),
					MaterialLab.cloth(_garment_colour(i + int(at.x)), 0.9), "Garment%d" % i)
			for k in 2:
				LevelKit.prop(root, Vector3(at.x + (-0.5 + float(k)) * sw * 0.75,
					at.y + 0.88, at.z + 0.1), Vector3(0.05, 1.75, 0.05),
					mats["steel"], "RailLeg%d" % k)
		_:
			# Grocer, phones and everything else: a freezer, a crate, a chair.
			LevelKit.prop(root, Vector3(at.x - sw * 0.2, at.y + 0.42, at.z),
				Vector3(1.3, 0.84, 0.66), mats["cloth"], "Freezer")
			LevelKit.prop(root, Vector3(at.x - sw * 0.2, at.y + 0.86, at.z),
				Vector3(1.24, 0.06, 0.60), mats["dark"], "FreezerLid")
			_crate_pile(root, mats, Vector3(at.x + sw * 0.26, at.y, at.z + 0.15), 3, rng)
			_chairs(root, mats, Vector3(at.x + sw * 0.05, at.y, at.z + 0.35), 1, rng)
	if not near:
		# Across the road these are half-metre objects on a lit pavement at
		# eighteen metres. Their shadows are a pixel each and the cascades are
		# not, so the far side's goods are silhouette only.
		_no_shadows(root)


# --- The street itself ------------------------------------------------------

## Everything between the two terraces: the road surface and its history, the
## far kerb's palms and parked cars, the foreground clutter on the near kerb,
## and the overhead cable, which is the single cheapest thing in this file and
## the one that most makes the frame read as a town.
static func street_dressing(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var paint := MaterialLab.painted_metal(Color(0.72, 0.68, 0.58), 0.9)
	var body_colours := [
		Color(0.62, 0.60, 0.56), Color(0.24, 0.30, 0.38),
		Color(0.48, 0.36, 0.22), Color(0.32, 0.40, 0.30),
	]

	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5

	# THE NEAR PAVEMENT, and it is fixing a real hole rather than dressing one.
	# There has always been a kerb at z = +2.6 with nothing behind it, and the
	# road slab stops at z = +3. With the camera sixteen metres out at eye
	# height, the bottom edge of every street-level frame lands on ground at
	# about z = +8 — so the lower fifth of the screen has been showing the
	# sky's ground colour through a hole in the world. Two bands, because one
	# flat slab across the bottom of the frame is its own kind of dead: the
	# paved walk the arcade stands on, then the unmade dust verge beyond it
	# where the town stopped bothering.
	LevelKit.prop(parent, Vector3(mid, STREET_Y + 0.055, 3.75),
		Vector3(span + 80.0, 0.11, 3.7), mats["kerb"], "NearPavement")
	LevelKit.prop(parent, Vector3(mid, STREET_Y + 0.045, 8.05),
		Vector3(span + 80.0, 0.09, 4.9), mats["dust"], "NearVerge")
	# Slab joints. A paved band with no module on it is a painted plane, and
	# the module is also the only thing in the foreground with a rhythm.
	var joints: Array[Transform3D] = []
	var jx := x_from - 40.0
	while jx < x_to + 40.0:
		joints.append(Transform3D(Basis.IDENTITY, Vector3(jx, STREET_Y + 0.115, 3.75)))
		jx += 1.35
	_no_shadows(_mm(parent, "PavingJoints",
		LevelKit.chamfer_mesh(Vector3(0.05, 0.02, 3.7)), mats["shade"], joints))

	# Centre line, dashed.
	for i in int(span / 4.0):
		LevelKit.prop(parent, Vector3(x_from + i * 4.0, STREET_Y + 0.02, -6.0),
			Vector3(2.0, 0.04, 0.22), paint, "Dash%d" % i)

	# Bollards, planters and the low clutter on the near kerb: the bottom of
	# every frame in this level is road, and road with nothing on it is a grey
	# band. Everything here stays under a metre so it frames the player from
	# below rather than crossing him.
	var bx := x_from
	var clutter := 0
	while bx < x_to:
		bx += rng.randf_range(3.0, 5.0)
		var roll := rng.randf()
		if roll < 0.20:
			LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.42, 3.1),
				Vector3(1.6, 0.84, 0.9), mats["kerb"], "Planter")
			LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.92, 3.1),
				Vector3(1.3, 0.30, 0.7), mats["palm"], "PlanterShrub")
		elif roll < 0.30:
			# Foreground: pallets, a dumped tyre, a heap of sand. Out of focus
			# at the bottom of the frame, they are pure depth cue.
			match clutter % 3:
				0:
					for k in 3:
						LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.08 + float(k) * 0.14, 3.4),
							Vector3(1.15, 0.12, 0.85), mats["crate"], "Pallet%d" % k)
				1:
					_tyre_stack(parent, mats, Vector3(bx, STREET_Y, 3.5), 2, rng)
				_:
					LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.18, 3.5),
						Vector3(2.2, 0.36, 1.3), mats["heix"], "SandHeap")
			clutter += 1
		elif roll < 0.36:
			# Weeds at the kerb line: separated low mounds, never a carpet.
			for k in 2:
				LevelKit.prop(parent, Vector3(bx + float(k) * 0.7, STREET_Y + 0.14, 2.9),
					Vector3(0.36, 0.28, 0.30), mats["ficus"], "Weed%d" % k)
		else:
			LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.34, 3.1),
				Vector3(0.22, 0.68, 0.22), mats["steel"], "Bollard")

	# Patches and covers, so the tarmac is a surface and not a colour.
	for i in int(span / 9.0):
		var px := x_from + i * 9.0 + rng.randf_range(-2.0, 2.0)
		LevelKit.prop(parent, Vector3(px, STREET_Y + 0.015,
			-2.0 - rng.randf_range(0.0, 8.0)),
			Vector3(rng.randf_range(1.6, 4.0), 0.03, rng.randf_range(1.2, 2.6)),
			mats["shade"], "RoadPatch%d" % i)
		if i % 3 == 0:
			LevelKit.prop(parent, Vector3(px + 3.0, STREET_Y + 0.02, -8.0),
				Vector3(0.7, 0.04, 0.7), mats["rust"], "Cover%d" % i)
		# Terra rossa: tongues of red interior sand blown across the asphalt,
		# and a drift line where they pile against the far kerb. This is the
		# level's one canon-unique hue and it lives on the ground.
		if i % 2 == 0:
			var t := LevelKit.prop(parent, Vector3(px + 5.0, STREET_Y + 0.025,
				-4.0 - rng.randf_range(0.0, 7.0)),
				Vector3(rng.randf_range(3.0, 7.0), 0.05, rng.randf_range(1.0, 2.2)),
				mats["heix"], "SandTongue%d" % i)
			t.rotation.y = rng.randf_range(-0.16, 0.16)
	for i in int(span / 14.0):
		LevelKit.prop(parent, Vector3(x_from + float(i) * 14.0 + rng.randf_range(-3.0, 3.0),
			STREET_Y + 0.10, -13.7), Vector3(rng.randf_range(4.0, 9.0), 0.22, 0.9),
			mats["heix"], "KerbDrift%d" % i)

	var x := x_from - 10.0
	var kiosk_due := 0
	while x < x_to + 10.0:
		x += rng.randf_range(16.0, 30.0)
		var pick := rng.randf()
		if pick < 0.45:
			# A palm on the far kerb, well clear of the play line.
			PropKit.palm(parent, Vector3(x, STREET_Y, -13.4),
				rng.randf_range(6.5, 9.5), mats["trunk"], mats["palm"], int(x))
		elif pick < 0.80:
			# A parked car, long side to camera, wheels tucked under.
			var c: Color = body_colours[rng.randi() % body_colours.size()]
			var paintwork := MaterialLab.painted_metal(c, 0.75)
			var body := LevelKit.prop(parent,
				Vector3(x, STREET_Y + 0.62, -12.2), Vector3(4.3, 0.90, 1.8),
				paintwork, "Car")
			LevelKit.prop(body, Vector3(-0.15, 0.62, 0.0), Vector3(2.5, 0.68, 1.65),
				paintwork, "CarCabin")
			LevelKit.prop(body, Vector3(-0.15, 0.62, 0.84), Vector3(2.3, 0.50, 0.05),
				mats["dark"], "CarGlass")
			for w in 2:
				LevelKit.prop(body, Vector3(-1.35 + w * 2.7, -0.42, 0.88),
					Vector3(0.62, 0.62, 0.12), mats["dark"], "CarWheel%d" % w)
		else:
			# A kiosk or a handcart on the far pavement, alternating.
			if kiosk_due % 2 == 0:
				_kiosk(parent, mats, Vector3(x, STREET_Y, -15.2), rng)
			else:
				_handcart(parent, mats, Vector3(x, STREET_Y, -14.9), rng)
			kiosk_due += 1

	# FOREGROUND PALMS. Five and a half metres in front of the play line, which
	# at a sixteen-metre camera means only the trunk and the lowest fronds ever
	# cross the frame — a dark vertical sliding past at twice the parallax of
	# anything else on screen. It is the cheapest depth in the level and the
	# only thing here that is in front of the hero, so they are spaced far
	# enough apart that one is never over him for more than a stride.
	var fx := x_from + 24.0
	var fi := 0
	# Its own material, two stops under the street's. A foreground occluder that
	# renders at the same value as the buildings behind it stops being a layer
	# and becomes a pole standing in the middle of the frame — which is exactly
	# what the first capture of this street caught it doing.
	var fg_trunk := MaterialLab.plaster(Color(0.268, 0.236, 0.196), 1.0, -0.85)
	var fg_frond := PropKit.foliage_material(Color(0.088, 0.112, 0.070), STREET_Y, 7.0, 0.5)
	while fx < x_to:
		# Short enough that the lowest fronds enter the top of the frame. At 9.5
		# to 12.5 metres the crown cleared the camera entirely and what crossed
		# the screen was a bare pole — the comment above claimed fronds, the
		# geometry delivered a post.
		PropKit.palm(parent, Vector3(fx, STREET_Y + 0.11, 4.9),
			rng.randf_range(6.6, 8.1), fg_trunk, fg_frond, 900 + fi)
		# A ring of kerb round the base, because a palm growing straight out of
		# a pavement slab is a detail everyone gets wrong.
		LevelKit.prop(parent, Vector3(fx, STREET_Y + 0.20, 4.9),
			Vector3(1.5, 0.22, 1.5), mats["block"], "PalmKerb%d" % fi)
		LevelKit.prop(parent, Vector3(fx, STREET_Y + 0.16, 4.9),
			Vector3(1.2, 0.20, 1.2), mats["dust"], "PalmSoil%d" % fi)
		fx += rng.randf_range(58.0, 74.0)
		fi += 1

	_overhead(parent, mats, x_from, x_to, rng)


## THE CABLES. A Libyan street corner is a knot of overhead line and nothing
## else in this file buys as much silhouette per vertex.
##
## Three depths, and the heights are chosen against the play space rather than
## against the reference: the far spans sit at six to eight metres on the far
## pavement where the player never is; the street crossings sit at five, which
## is above his head on the road and below the parapet when he is on the roofs,
## so a cable never crosses the character. Cables that cut across the hero are
## the one way this idea fails, and it fails badly.
static func _overhead(parent: Node3D, mats: Dictionary, x_from: float,
		x_to: float, rng: RandomNumberGenerator) -> void:
	var pitch := 24.0
	var count := int((x_to - x_from) / pitch) + 2
	var near_poles: Array[Vector3] = []
	var far_poles: Array[Vector3] = []

	for i in count:
		# Near pole. It stands out on the verge at z = +7, NOT on the kerb
		# line: the level's arcade colonnade already owns z = +2.3 and a utility
		# pole a metre in front of a stone pier reads as a modelling accident.
		# Out here it is its own foreground layer, and short enough (five
		# metres at nine metres from the camera) to keep its head in frame
		# instead of running off the top as a bar.
		var nx := x_from + 11.0 + float(i) * pitch
		_pole(parent, mats, Vector3(nx, STREET_Y + 0.09, 7.0), 5.0, rng)
		near_poles.append(Vector3(nx, STREET_Y + 4.6, 7.0))
		# Far pole, on the far pavement.
		var fx := x_from + float(i) * pitch
		_pole(parent, mats, Vector3(fx, STREET_Y, -15.4), 8.6, rng)
		far_poles.append(Vector3(fx, STREET_Y + 8.1, -15.4))

	for i in count - 1:
		# Far-side trunk: three conductors at three heights and three sags, so
		# the run reads as a bundle rather than a drawn line.
		for k in 3:
			PropKit.cable(parent,
				far_poles[i] + Vector3(0.0, -0.32 * k, -0.22 * k),
				far_poles[i + 1] + Vector3(0.0, -0.32 * k, -0.22 * k),
				1.05 + 0.22 * k, mats["steel"], 12, 0.036)
		# Near-side run. Five and a half metres: above his head on the street,
		# above the highest balcony rung in the market, and still a good metre
		# under the parapet he runs along. The one way this idea fails is a
		# wire crossing the hero, so every near-side height is chosen against
		# the play space rather than against the reference.
		for k in 2:
			PropKit.cable(parent,
				near_poles[i] + Vector3(0.0, -0.40 - 0.24 * k, 0.0),
				near_poles[i + 1] + Vector3(0.0, -0.40 - 0.24 * k, 0.0),
				0.55 + 0.15 * k, mats["steel"], 12, 0.030)

		# The crossings. These are the ones that do the work: they run back in
		# depth, so they read as diagonals in a frame made of horizontals.
		if i % 2 == 0:
			PropKit.cable(parent, near_poles[i] + Vector3(0.0, -1.0, 0.0),
				far_poles[i] + Vector3(0.6, -1.8, 0.0), 1.1, mats["steel"], 14, 0.030)
		if i % 3 == 1:
			PropKit.cable(parent, near_poles[i] + Vector3(0.0, -1.2, 0.0),
				Vector3(near_poles[i].x + 9.0, STREET_Y + 5.1, -4.6), 0.55,
				mats["steel"], 12, 0.028)

		# Service drops into the far terrace, fanning off one pole.
		for k in 4:
			PropKit.cable(parent, far_poles[i] + Vector3(0.0, -0.5 - 0.35 * k, 0.0),
				Vector3(far_poles[i].x + rng.randf_range(-7.0, 7.0),
					STREET_Y + rng.randf_range(4.0, 6.6), FAR_FRONT + 0.2),
				0.45, mats["steel"], 9, 0.024)

		# A bag snagged on a wire. One DRAPE element per screen is the
		# anti-deadness rule; this one is free.
		if i % 4 == 2:
			var bag := LevelKit.prop(parent,
				far_poles[i] + Vector3(6.0, -2.1, 0.0), Vector3(0.34, 0.46, 0.05),
				MaterialLab.cloth(Color(0.60, 0.58, 0.54), 0.95), "SnaggedBag")
			bag.rotation.z = 0.35


## A service pole: a concrete stick with two cross-arms, a fistful of
## insulators and the tangle of slack somebody left wrapped round the top.
static func _pole(parent: Node3D, mats: Dictionary, base: Vector3, height: float,
		rng: RandomNumberGenerator) -> void:
	var p := _mi(parent, "Pole", _cyl(0.13, height, 8, 0.10), mats["kerb"],
		base + Vector3(0.0, height * 0.5, 0.0))
	p.rotation.z = rng.randf_range(-0.02, 0.02)
	for k in 2:
		var arm := LevelKit.prop(parent,
			base + Vector3(0.0, height - 0.45 - float(k) * 0.55, 0.0),
			Vector3(0.08, 0.08, 1.5 - float(k) * 0.35), mats["steel"], "CrossArm%d" % k)
		arm.rotation.x = rng.randf_range(-0.03, 0.03)
		for s in 2:
			_mi(parent, "Insulator%d_%d" % [k, s], _cyl(0.055, 0.14, 7),
				mats["cloth"],
				base + Vector3(0.0, height - 0.32 - float(k) * 0.55,
					(-0.6 + 1.2 * float(s)) * (1.0 - 0.24 * float(k))))
	# Slack coiled at the top. It is a tiny detail and it is the difference
	# between a utility pole and a stick.
	var coil: Array[Transform3D] = []
	for i in 5:
		coil.append(Transform3D(
			Basis(Vector3(1, 0, 0), float(i) * 0.5).scaled(Vector3.ONE * (1.0 - 0.06 * i)),
			base + Vector3(0.0, height - 1.9 - float(i) * 0.07, 0.0)))
	_mm(parent, "PoleCoil", _torus(0.03, 0.26), mats["steel"], coil)


# --- Small pieces -----------------------------------------------------------

## A cigarette and phone-credit kiosk: a painted box with a hatch, a shade and
## a stool. It is person-sized, which is what gives the far pavement its scale.
static func _kiosk(parent: Node3D, mats: Dictionary, at: Vector3,
		rng: RandomNumberGenerator) -> void:
	LevelKit.prop(parent, at + Vector3(0.0, 1.15, 0.0), Vector3(1.7, 2.3, 1.5),
		mats["paint_teal"], "Kiosk")
	LevelKit.prop(parent, at + Vector3(0.0, 2.38, 0.0), Vector3(2.0, 0.16, 1.8),
		mats["block"], "KioskCap")
	LevelKit.prop(parent, at + Vector3(0.0, 1.35, 0.78), Vector3(1.25, 0.85, 0.06),
		mats["dark"], "KioskHatch")
	var shade := LevelKit.prop(parent, at + Vector3(0.0, 2.05, 1.35),
		Vector3(1.9, 0.06, 1.2),
		MaterialLab.cloth(_awning_colour(int(at.x)), 0.95), "KioskShade")
	shade.rotation.x = -0.22
	LevelKit.prop(parent, at + Vector3(0.0, 0.95, 0.80), Vector3(1.5, 0.10, 0.34),
		mats["crate"], "KioskCounter")
	_mi(parent, "KioskStool", _cyl(0.17, 0.46, 8), mats["paint_red"],
		at + Vector3(rng.randf_range(0.9, 1.3), 0.23, 0.5))
	# A single bulb in the hatch, which is the only reason a two-metre box does
	# not read as a solid black slot from across the road.
	_interior(parent, mats, at + Vector3(0.0, 0.0, 0.82), 1.2, 1.9,
		mats["bulb"], 0.6, false)


## A wooden handcart with its shafts down. It is a diagonal at ground level and
## nothing else on the pavement is.
static func _handcart(parent: Node3D, mats: Dictionary, at: Vector3,
		rng: RandomNumberGenerator) -> void:
	var bed := LevelKit.prop(parent, at + Vector3(0.0, 0.74, 0.0),
		Vector3(2.3, 0.14, 1.1), mats["crate"], "Handcart")
	for s in 2:
		LevelKit.prop(bed, Vector3(0.0, 0.24, -0.5 + float(s)), Vector3(2.3, 0.34, 0.07),
			mats["crate"], "CartSide%d" % s)
	for w in 2:
		_mi(bed, "CartWheel%d" % w, _torus(0.06, 0.36), mats["tyre"],
			Vector3(0.3, -0.38, -0.5 + float(w) * 1.0), Vector3(PI * 0.5, 0.0, 0.0))
	for s2 in 2:
		var shaft := LevelKit.prop(bed, Vector3(-1.5, -0.32, -0.36 + float(s2) * 0.72),
			Vector3(1.5, 0.07, 0.07), mats["crate"], "Shaft%d" % s2)
		shaft.rotation.z = -0.42
	var tints := [Color(0.44, 0.206, 0.198), Color(0.30, 0.34, 0.12), Color(0.50, 0.335, 0.140)]
	for i in 3:
		LevelKit.prop(bed, Vector3(-0.6 + float(i) * 0.62, 0.26, 0.0),
			Vector3(0.55, 0.26, 0.55), mats["crate"], "CartCrate%d" % i)
		LevelKit.prop(bed, Vector3(-0.6 + float(i) * 0.62, 0.44, 0.0),
			Vector3(0.48, 0.14, 0.48),
			MaterialLab.cloth(tints[i], 0.9), "CartGoods%d" % i)
	bed.rotation.y = rng.randf_range(-0.12, 0.12)


## The café: a parasol, two tables and four plastic chairs. Plastic chairs are
## the most honest street-furniture object on this coast and they are also the
## level's licence to put a saturated mid-value red and blue at ground level.
static func _cafe_set(parent: Node3D, mats: Dictionary, at: Vector3, sw: float,
		rng: RandomNumberGenerator) -> void:
	_mi(parent, "ParasolPole", _cyl(0.04, 2.3, 7), mats["steel"],
		at + Vector3(0.0, 1.15, 0.5))
	_mi(parent, "Parasol", _cyl(1.45, 0.42, 8, 0.05),
		MaterialLab.cloth(_awning_colour(int(at.x) + 3), 0.95),
		at + Vector3(0.0, 2.32, 0.5))
	for t in 2:
		var tx := at.x + (float(t) - 0.5) * sw * 0.42
		_mi(parent, "Table%d" % t, _cyl(0.42, 0.05, 12), mats["cloth"],
			Vector3(tx, at.y + 0.72, at.z + 0.45))
		_mi(parent, "TableLeg%d" % t, _cyl(0.05, 0.72, 6), mats["steel"],
			Vector3(tx, at.y + 0.36, at.z + 0.45))
		_chairs(parent, mats, Vector3(tx, at.y, at.z + 0.45), 2, rng)
	# The tea tray, because it is always there.
	LevelKit.prop(parent, Vector3(at.x - sw * 0.21, at.y + 0.76, at.z + 0.45),
		Vector3(0.30, 0.03, 0.22), mats["steel"], "Tray")


static func _chairs(parent: Node3D, mats: Dictionary, at: Vector3, n: int,
		rng: RandomNumberGenerator) -> void:
	var tints := [mats["paint_teal"], mats["paint_red"], mats["paint_green"]]
	for i in n:
		var seat := LevelKit.prop(parent,
			at + Vector3((float(i) - 0.5 * float(n - 1)) * 0.72, 0.42, 0.0),
			Vector3(0.44, 0.06, 0.44), tints[(i + int(at.x)) % 3], "Chair%d" % i)
		seat.rotation.y = rng.randf_range(-0.8, 0.8)
		LevelKit.prop(seat, Vector3(0.0, 0.28, -0.20), Vector3(0.44, 0.52, 0.05),
			tints[(i + int(at.x)) % 3], "Back")
		for k in 4:
			LevelKit.prop(seat, Vector3(-0.17 + float(k % 2) * 0.34, -0.21,
				-0.17 + float(k / 2) * 0.34), Vector3(0.04, 0.40, 0.04),
				tints[(i + int(at.x)) % 3], "Leg%d" % k)


static func _crate_pile(parent: Node3D, mats: Dictionary, at: Vector3, n: int,
		rng: RandomNumberGenerator) -> void:
	for i in n:
		var c := LevelKit.prop(parent,
			at + Vector3(rng.randf_range(-0.12, 0.12), 0.20 + float(i) * 0.38,
				rng.randf_range(-0.10, 0.10)),
			Vector3(0.66, 0.36, 0.50), mats["crate"], "Crate%d" % i)
		c.rotation.y = rng.randf_range(-0.22, 0.22)


static func _sacks(parent: Node3D, mats: Dictionary, at: Vector3, n: int,
		rng: RandomNumberGenerator) -> void:
	for i in n:
		var s := LevelKit.prop(parent,
			at + Vector3(float(i) * 0.42, 0.28 + float(i % 2) * 0.05, rng.randf_range(-0.1, 0.1)),
			Vector3(0.44, 0.56, 0.40), mats["hessian"], "Sack%d" % i)
		s.rotation = Vector3(0.0, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.12, 0.12))
		# The open top, rolled down, with grain showing.
		LevelKit.prop(s, Vector3(0.0, 0.30, 0.0), Vector3(0.34, 0.10, 0.30),
			MaterialLab.cloth(Color(0.50, 0.42, 0.26), 0.92), "Grain")


static func _tyre_stack(parent: Node3D, mats: Dictionary, at: Vector3, n: int,
		rng: RandomNumberGenerator) -> void:
	var xf: Array[Transform3D] = []
	for i in n:
		xf.append(Transform3D(
			Basis(Vector3.UP, rng.randf_range(0.0, TAU)),
			at + Vector3(rng.randf_range(-0.05, 0.05), 0.11 + float(i) * 0.20,
				rng.randf_range(-0.05, 0.05))))
	_mm(parent, "TyreStack", _torus(0.19, 0.34), mats["tyre"], xf)


## A ficus: a short thick trunk and a mass of overlapping crowns. Never one
## sphere — a ball on a stick is the lollipop tree everyone recognises as
## programmer planting.
static func _ficus(parent: Node3D, mats: Dictionary, base: Vector3, height: float,
		rng: RandomNumberGenerator) -> void:
	_mi(parent, "FicusTrunk", _cyl(height * 0.055, height * 0.45, 7),
		mats["trunk"], base + Vector3(0.0, height * 0.22, 0.0))
	for i in 3:
		var limb := _mi(parent, "FicusLimb%d" % i, _cyl(height * 0.028, height * 0.35, 6),
			mats["trunk"], base + Vector3(sin(TAU * i / 3.0) * height * 0.08,
				height * 0.5, cos(TAU * i / 3.0) * height * 0.08))
		limb.rotation.z = sin(TAU * i / 3.0) * 0.3
	var crowns: Array[Transform3D] = []
	for i in 7:
		var a := TAU * float(i) / 7.0
		var r := height * rng.randf_range(0.12, 0.26)
		crowns.append(Transform3D(
			Basis(Vector3.UP, a).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25)),
			base + Vector3(cos(a) * r, height * rng.randf_range(0.66, 0.92),
				sin(a) * r * 0.8)))
	_mm(parent, "FicusCrown",
		LevelKit.chamfer_mesh(Vector3(height * 0.34, height * 0.24, height * 0.30)),
		mats["ficus"], crowns)


## A lit interior behind an opening. The emissive plane does the reading; the
## omni is only added where it will actually be seen, because thirty of them
## down a street is a light bill nobody needs to pay.
static func _interior(parent: Node3D, mats: Dictionary, at: Vector3, width: float,
		height: float, glow: Material, energy: float, with_light: bool) -> void:
	# `at` is the FRONT face of the opening at street level, so the caller can
	# slot this into an existing recess without guessing at its depth.
	LevelKit.prop(parent, at + Vector3(0.0, height * 0.5, -0.17),
		Vector3(width + 0.5, height, 0.34), mats["dark"], "Interior")
	var lamp := LevelKit.prop(parent, at + Vector3(0.0, height * 0.80, 0.03),
		Vector3(minf(width * 0.62, 1.4), 0.09, 0.10), glow, "Lamp")
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not with_light:
		return
	var omni := OmniLight3D.new()
	omni.name = "InteriorLight"
	omni.light_color = Color(1.0, 0.82, 0.60)
	omni.light_energy = energy
	omni.omni_range = 3.4
	omni.shadow_enabled = false
	omni.position = at + Vector3(0.0, height * 0.55, 0.30)
	parent.add_child(omni)


## A runoff streak. Gravity is the first weathering law: every bracket, sill,
## scupper and AC unit on a rendered wall has a hard-edged run below it, and it
## is always longer than feels right.
static func _streak(parent: Node3D, at: Vector3, w: float, h: float,
		strength: float) -> void:
	var mi := _mi(parent, "Streak", _quad(w, h),
		PropKit.gradient_decal(Color(0.22, 0.18, 0.13), strength, "streak"), at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A grid of dark openings as one MultiMesh. At background distance a facade is
## a rhythm of holes and nothing else, and one draw call per block keeps four
## bands of town affordable.
static func _window_grid(parent: Node3D, left_x: float, base_y: float, width: float,
		height: float, z: float, mat: Material, rng: RandomNumberGenerator,
		size := Vector2(0.80, 1.10)) -> void:
	if width < 1.5 or height < 1.5:
		return
	var cols := maxi(1, int(width / 2.9))
	var rows := maxi(1, int(height / 3.0))
	var xf: Array[Transform3D] = []
	for r in rows:
		for c in cols:
			if rng.randf() < 0.12:
				continue  # blocked up, or never glazed in the first place
			xf.append(Transform3D(Basis.IDENTITY, Vector3(
				left_x + (float(c) + 0.5) * (width / float(cols)),
				base_y + (float(r) + 0.55) * (height / float(rows)), z)))
	var node := _mm(parent, "Openings",
		LevelKit.chamfer_mesh(Vector3(size.x, size.y, 0.16)), mat, xf)
	if node:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Colour helpers ---------------------------------------------------------

## The render walk. Consecutive buildings never share a tone and the sequence
## alternates warm and cool so a terrace has a beat rather than a gradient.
static func _render_tone(mats: Dictionary, i: int) -> Material:
	var order := ["render", "render_pale", "render_warm", "render_b",
		"render_cool", "render_c", "render_rose"]
	return mats[order[posmod(i, order.size())]]


## Awning stripes: the one place yellow-orange is legal, and it is legal here
## because it is cloth in the mid band with the sun behind it.
static func _awning_colour(i: int) -> Color:
	var set_ := [Color(0.44, 0.206, 0.198), Color(0.14, 0.31, 0.40),
		Color(0.19, 0.36, 0.24), Color(0.48, 0.34, 0.14)]
	return set_[posmod(i, set_.size())]


static func _carpet_colour(i: int) -> Color:
	var set_ := [Color(0.38, 0.175, 0.171), Color(0.13, 0.24, 0.32),
		Color(0.33, 0.200, 0.215), Color(0.20, 0.26, 0.17)]
	return set_[posmod(i, set_.size())]


static func _garment_colour(i: int) -> Color:
	var set_ := [Color(0.42, 0.44, 0.48), Color(0.16, 0.28, 0.36),
		Color(0.46, 0.40, 0.30), Color(0.34, 0.16, 0.16), Color(0.24, 0.34, 0.26)]
	return set_[posmod(i, set_.size())]


static func _font_for(id: int) -> String:
	match id:
		1: return PropKit.FONT_NASKH_BOLD
		2: return PropKit.FONT_KUFI
		_: return PropKit.FONT_NASKH


# --- Mesh helpers -----------------------------------------------------------

## Kills shadow casting on a whole subtree.
##
## The key here is front-three-quarter — it comes over the player's shoulder
## and travels away from the camera — so everything a building throws lands
## BEHIND it, out of frame. The shadows that are actually seen are the
## self-shadows of things that stand off a wall: awnings, balconies, cornices,
## downpipes. Those stay. Anything deeper than the frontage, and everything
## small enough that its shadow is two pixels, comes out of the shadow pass,
## because a cascade drawn over scenery whose shadow nobody can see is the
## most expensive nothing in a level.
static func _no_shadows(node: Node) -> Node:
	if node == null:
		return null   # _mm returns null for an empty batch; callers chain onto it
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadows(child)
	return node


## A child container, so a caller can build a group of props and then treat
## them as one thing — usually to take them out of the shadow pass.
static func _group(parent: Node3D, name_: String) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	parent.add_child(n)
	return n


static func _mi(parent: Node3D, name_: String, mesh: Mesh, mat: Material,
		pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## One draw call for a swarm of identical parts. Order matters: the colour
## format has to be declared before the instance count or the server refuses it.
static func _mm(parent: Node3D, name_: String, mesh: Mesh, mat: Material,
		xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = mm
	node.material_override = mat
	parent.add_child(node)
	return node


static var _cyl_cache: Dictionary = {}

static func _cyl(radius: float, height: float, sides := 12, top_radius := -1.0) -> CylinderMesh:
	var key := "%.3f_%.3f_%d_%.3f" % [radius, height, sides, top_radius]
	if _cyl_cache.has(key):
		return _cyl_cache[key]
	var m := CylinderMesh.new()
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	_cyl_cache[key] = m
	return m


static var _torus_cache: Dictionary = {}

static func _torus(inner: float, outer: float) -> TorusMesh:
	var key := "%.3f_%.3f" % [inner, outer]
	if _torus_cache.has(key):
		return _torus_cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 10
	t.ring_segments = 6
	_torus_cache[key] = t
	return t


static var _quad_cache: Dictionary = {}

static func _quad(w: float, h: float) -> QuadMesh:
	var key := "%.3f_%.3f" % [w, h]
	if _quad_cache.has(key):
		return _quad_cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	_quad_cache[key] = q
	return q
