class_name AjdabiyaKit
## Shared material palette, colour script and backdrop for Level 2.
##
## AJDABIYA CROSSROADS is the counterweight to Brega. Brega is a dead plant at
## first light: cold shadow, warm key, no people, almost no colour. Ajdabiya is
## the same coast two hours later and forty kilometres east, and it is a town —
## the sun is up, the light is high and hard, the shadows are short and blue,
## and colour is everywhere because people put it there. Awnings, painted
## shutters, produce, laundry, a repainted bus.
##
## The rule that carries over: he is still the brightest thing in the frame.
## Here that is harder, so the town's saturation is spent on mid values and the
## whites are kept for him.

const STREET_Y := 0.0


static func palette() -> Dictionary:
	var mats := {
		# Sun-bleached lime render over block. The town's base note.
		"render": MaterialLab.plaster(Color(0.520, 0.470, 0.392), 1.0),
		"render_b": MaterialLab.plaster(Color(0.430, 0.398, 0.352), 1.0),
		"render_c": MaterialLab.plaster(Color(0.560, 0.500, 0.404), 1.0),
		"block": MaterialLab.concrete(Color(0.330, 0.310, 0.282), 1.0),
		"shade": MaterialLab.concrete(Color(0.150, 0.140, 0.132), 0.8),
		"dark": MaterialLab.concrete(Color(0.058, 0.054, 0.056), 0.2),
		"kerb": MaterialLab.concrete(Color(0.390, 0.375, 0.352), 1.0),
		"road": MaterialLab.asphalt(Color(0.128, 0.126, 0.130)),
		"dust": MaterialLab.sand(Color(0.430, 0.388, 0.312)),
		# Painted metal: shutters and doors, the town's saturated mid tones.
		"shutter_blue": MaterialLab.painted_metal(Color(0.118, 0.278, 0.352), 0.8),
		"shutter_green": MaterialLab.painted_metal(Color(0.132, 0.288, 0.212), 0.8),
		"shutter_red": MaterialLab.painted_metal(Color(0.400, 0.148, 0.112), 0.8),
		"sign": MaterialLab.painted_metal(Color(0.176, 0.212, 0.268), 0.55),
		"steel": MaterialLab.painted_metal(Color(0.075, 0.074, 0.080), 0.9),
		"rust": MaterialLab.rusted_metal(Color(0.268, 0.146, 0.098), 1.0),
		"rebar": MaterialLab.rusted_metal(Color(0.560, 0.300, 0.128), 1.0),
		"tank": MaterialLab.painted_metal(Color(0.055, 0.052, 0.054), 0.85),
		"crate": MaterialLab.cloth(Color(0.392, 0.268, 0.152), 0.92),
		"cloth": MaterialLab.cloth(Color(0.640, 0.600, 0.540), 0.95),
		"palm": PropKit.foliage_material(Color(0.196, 0.238, 0.148), STREET_Y, 7.0, 0.5),
		"trunk": MaterialLab.plaster(Color(0.268, 0.236, 0.196), 1.0),
	}
	# Grime creeps up from the street, not from y = 0 in some other level.
	for key: String in ["render", "render_b", "render_c", "block", "kerb"]:
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
	m.sun_energy = 4.2
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

	# A real daylight sky, not a dawn gradient.
	m.sky_top = Color(0.185, 0.330, 0.560)
	m.sky_horizon = Color(0.640, 0.700, 0.760)
	m.ground_horizon = Color(0.520, 0.470, 0.396)
	m.ground_bottom = Color(0.270, 0.240, 0.205)
	m.sky_energy = 1.0
	m.sky_curve = 0.22
	m.ambient_energy = 0.42

	m.fog_color = Color(0.700, 0.715, 0.720)
	m.fog_density = 0.00055
	m.fog_sun_scatter = 0.10
	m.fog_emission = Color(0.05, 0.05, 0.055)
	m.fog_anisotropy = 0.55
	m.volumetric_density = 0.00035

	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.0
	m.white = 9.0
	m.glow_intensity = 0.10
	m.glow_hdr_threshold = 2.4
	m.adjustment_saturation = 1.10
	m.adjustment_contrast = 1.12
	m.dof_near_distance = 0.0
	m.dof_distance = 0.0
	return m


## The town behind the street: blocks of flat-roofed housing stepping back,
## then the low ridge and the sky.
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
	# Two bands of town, so the skyline has a near and a far.
	for band in 2:
		var z := -52.0 - band * 46.0
		var base := STREET_Y - 1.0 - band * 1.6
		var x := x_from - 80.0
		while x < x_to + 80.0:
			var w := rng.randf_range(9.0, 22.0)
			var h := rng.randf_range(5.0, 11.0) - band * 0.8
			var tone: Material = [mats["render"], mats["render_b"], mats["render_c"]][rng.randi() % 3]
			LevelKit.prop(parent, Vector3(x + w * 0.5, base + h * 0.5, z),
				Vector3(w, h, 10.0), tone, "TownBlock")
			LevelKit.prop(parent, Vector3(x + w * 0.5, base + h + 0.28, z - 0.3),
				Vector3(w * 1.01, 0.56, 10.2), mats["block"], "TownParapet")
			if rng.randf() < 0.55:
				PropKit.roof_kit(parent, x + 0.6, base + h, w - 1.2, z + 4.6,
					mats["block"], mats["tank"], mats["rebar"], int(x))
			x += w + rng.randf_range(1.5, 5.0)

	# The one minaret on the skyline, far back and well off the play line.
	var mx := mid + 64.0
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 11.0, -150.0),
		Vector3(4.2, 26.0, 4.2), mats["render_c"], "MinaretShaft")
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 24.4, -150.0),
		Vector3(5.4, 0.9, 5.4), mats["block"], "MinaretGallery")
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 27.0, -150.0),
		Vector3(3.2, 4.2, 3.2), mats["render_c"], "MinaretLantern")
	LevelKit.prop(parent, Vector3(mx, STREET_Y + 30.0, -150.0),
		Vector3(2.0, 2.0, 2.0), mats["render_c"], "MinaretCap")


## The far side of the street: a facing terrace of shopfronts, seen across the
## road. It is what stops the street reading as one wall and a void.
static func far_terrace(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var shutters := [mats["shutter_blue"], mats["shutter_green"], mats["shutter_red"]]
	var x := x_from - 20.0
	while x < x_to + 20.0:
		var w := rng.randf_range(10.0, 18.0)
		var h := rng.randf_range(6.0, 10.5)
		var tone: Material = [mats["render"], mats["render_b"], mats["render_c"]][rng.randi() % 3]
		LevelKit.prop(parent, Vector3(x + w * 0.5, STREET_Y + h * 0.5, -22.0),
			Vector3(w, h, 8.0), tone, "FarBlock")
		PropKit.roof_kit(parent, x + 0.8, STREET_Y + h, w - 1.6, -21.6,
			mats["block"], mats["tank"], mats["rebar"], int(x) + 41)
		town_facade(parent, mats, x + 0.6, STREET_Y + 3.9, w - 1.2, h - 4.4,
			-17.96, int(x) + 17)
		var bays := maxi(2, int(w / 4.2))
		for i in bays:
			PropKit.shopfront(parent,
				Vector3(x + (float(i) + 0.5) * (w / float(bays)), STREET_Y, -17.86),
				w / float(bays) - 0.4, 3.6, tone,
				shutters[rng.randi() % shutters.size()], mats["sign"],
				rng.randf() < 0.4)
		x += w + rng.randf_range(0.0, 2.0)


## The upper floors of a Libyan town block: window openings with reveals, a
## balcony on every other bay with its rail and its washing line, an air
## conditioner on the ones without, and the laundry as the only saturated
## colour above street level.
##
## A blank tan rectangle with one dark line on it is not a building, and it was
## what the first pass of this level was made of.
static func town_facade(parent: Node3D, mats: Dictionary, left_x: float,
		base_y: float, width: float, height: float, z: float,
		seed_ := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "TownFacade"
	parent.add_child(root)
	if height < 2.0 or width < 2.0:
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 373 + 11

	var floors := maxi(1, int(height / 3.0))
	var bays := maxi(2, int(width / 3.2))
	var colours := [
		Color(0.72, 0.26, 0.20), Color(0.20, 0.38, 0.50), Color(0.82, 0.74, 0.58),
		Color(0.26, 0.42, 0.28), Color(0.78, 0.60, 0.22),
	]

	for f in floors:
		var y := base_y + (float(f) + 0.5) * (height / float(floors))
		for b in bays:
			var x := left_x + (float(b) + 0.5) * (width / float(bays))
			PropKit.window(root, Vector3(x, y, z), Vector2(0.82, 1.15), 0.26,
				mats["render_b"], mats["shade"],
				mats["shutter_blue"] if (seed_ + b + f) % 3 == 0 else null,
				-0.55 if (seed_ + b) % 4 == 0 else -0.15)
			if (seed_ + b + f) % 2 != 0:
				# An air conditioner and its bracket under the sill.
				LevelKit.prop(root, Vector3(x + 0.62, y - 0.74, z + 0.26),
					Vector3(0.66, 0.44, 0.38), mats["steel"], "AC")
				LevelKit.prop(root, Vector3(x + 0.62, y - 0.98, z + 0.24),
					Vector3(0.74, 0.06, 0.34), mats["rust"], "ACBracket")
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
	return root


## Street furniture on the far kerb: palms, parked vehicles and the painted
## centre line. It is what stops the road reading as an empty light band across
## the bottom of every frame.
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
	# Centre line, dashed.
	for i in int(span / 4.0):
		LevelKit.prop(parent, Vector3(x_from + i * 4.0, STREET_Y + 0.02, -6.0),
			Vector3(2.0, 0.04, 0.22), paint, "Dash%d" % i)

	# Bollards and a planter run along the near kerb: the bottom of every frame
	# in this level is road, and road with nothing on it is a grey band.
	var bx := x_from
	while bx < x_to:
		bx += rng.randf_range(3.0, 5.0)
		if rng.randf() < 0.22:
			LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.42, 3.1),
				Vector3(1.6, 0.84, 0.9), mats["kerb"], "Planter")
			LevelKit.prop(parent, Vector3(bx, STREET_Y + 0.92, 3.1),
				Vector3(1.3, 0.30, 0.7), mats["palm"], "PlanterShrub")
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

	var x := x_from - 10.0
	while x < x_to + 10.0:
		x += rng.randf_range(16.0, 30.0)
		if rng.randf() < 0.55:
			# A palm on the far kerb, well clear of the play line.
			PropKit.palm(parent, Vector3(x, STREET_Y, -13.4),
				rng.randf_range(6.5, 9.5), mats["trunk"], mats["palm"], int(x))
		else:
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
