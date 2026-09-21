class_name BregaKit
## Shared Brega environment: palette, mood, and the deep layers.
##
## The beauty benchmark and the playable level must look like the same place,
## which means they cannot each own a copy of the sky. Both call in here.
##
## Colour and lighting values come from docs/ART_DIRECTION.md, Level 1: 05:52,
## pre-dawn blue cracking into first sun, key at 3.5 degrees from behind and
## screen-right, regime green as the level-unique colour.

const YARD_Y := -6.6


static func palette() -> Dictionary:
	var p := {
		"slab": MaterialLab.plaster(Color(0.425, 0.402, 0.356), 1.0),
		"joint": MaterialLab.concrete(Color(0.170, 0.156, 0.138), 1.0),
		"dark": MaterialLab.concrete(Color(0.055, 0.050, 0.050), 0.2),
		"wall": MaterialLab.plaster(Color(0.180, 0.172, 0.162), 1.0),
		"deck": MaterialLab.concrete(Color(0.325, 0.312, 0.290), 1.0),
		"rail": MaterialLab.rusted_metal(Color(0.40, 0.235, 0.145), 0.75),
		"rebar": MaterialLab.rusted_metal(Color(0.757, 0.396, 0.165), 1.0),
		"rust": MaterialLab.rusted_metal(Color(0.243, 0.133, 0.090), 1.0),
		"tank": MaterialLab.plaster(Color(0.330, 0.316, 0.292), 1.0),
		"tank_burnt": MaterialLab.concrete(Color(0.125, 0.098, 0.086), 1.0),
		"bund": MaterialLab.concrete(Color(0.245, 0.233, 0.210), 1.0),
		"tower": MaterialLab.concrete(Color(0.300, 0.290, 0.274), 1.0),
		"steel": MaterialLab.painted_metal(Color(0.055, 0.055, 0.062), 0.9),
		"sabkha": MaterialLab.sand(Color(0.352, 0.330, 0.292)),
		"mud": MaterialLab.concrete(Color(0.190, 0.162, 0.126), 1.0),
		"sand": MaterialLab.sand(Color(0.560, 0.512, 0.420)),
		"trunk": MaterialLab.plaster(Color(0.208, 0.200, 0.184), 1.0),
		"leaf": PropKit.foliage_material(Color(0.212, 0.243, 0.180), YARD_Y, 9.0, 0.42),
		"door": MaterialLab.painted_metal(Color(0.184, 0.365, 0.275), 0.7),
		"green": MaterialLab.plaster(Color(0.185, 0.268, 0.200), 1.0),
		"shutter": MaterialLab.painted_metal(Color(0.420, 0.290, 0.196), 1.0),
		"bag": MaterialLab.cloth(Color(0.678, 0.639, 0.545), 0.95),
		"crate": MaterialLab.cloth(Color(0.44, 0.31, 0.19), 0.72),
		"corrugated": MaterialLab.corrugated(Color(0.30, 0.285, 0.265), 22.0),
	}
	# Salt spalling climbs from the yard floor, not from the gameplay plane.
	for key: String in ["slab", "wall", "deck"]:
		p[key].set_shader_parameter("grime_origin_y", YARD_Y)
		p[key].set_shader_parameter("grime_falloff", 1.9)
		p[key].set_shader_parameter("grime_color", Color(0.29, 0.25, 0.20))
		p[key].set_shader_parameter("grime_amount", 0.55)
	return p


static func mood() -> LightingRig.Mood:
	var m := LightingRig.Mood.new()

	m.sun_angles = Vector2(-3.5, 150.0)
	m.sun_color = Color(1.0, 0.565, 0.251)      # 2200 K
	m.sun_energy = 3.1
	m.sun_angular_distance = 1.1
	# 3.0 is a beauty-frame number. In gameplay the camera spends its life
	# looking along the key, and at that energy the volumetrics put a hot white
	# wash across the bottom right of every frame.
	m.sun_fog_energy = 1.3
	m.sun_disc_size = 0.34

	# Cool and weak: everything the key can reach is behind the geometry, so
	# the playing field is in shade and has to stay there. He is the brightest
	# value in the frame and that is the whole readability strategy. Matches
	# the benchmark's colour script exactly — see BregaBeauty._mood.
	m.fill_angles = Vector2(18.0, -28.0)
	m.fill_color = Color(0.475, 0.545, 0.720)
	m.fill_energy = 0.54

	m.rim_angles = Vector2(-4.0, 128.0)
	m.rim_color = Color(1.0, 0.722, 0.467)
	m.rim_energy = 8.0
	m.rim_cull_mask = 2

	# 2.5 of a cold light on a white robe turns him blue. He is meant to read
	# as warm white against a cool shadow world, not as the one cold thing in
	# a warm one.
	m.hero_fill_energy = 1.45
	m.hero_fill_color = Color(0.82, 0.83, 0.90)
	m.hero_fill_angles = Vector2(-14.0, -30.0)

	m.sky_top = Color(0.169, 0.227, 0.333)
	m.sky_horizon = Color(0.788, 0.482, 0.271)
	m.ground_horizon = Color(0.835, 0.804, 0.741)
	m.ground_bottom = Color(0.376, 0.345, 0.306)
	m.sky_energy = 1.0
	m.sky_curve = 0.11
	m.ambient_energy = 0.29

	m.fog_color = Color(0.835, 0.804, 0.741)
	m.fog_density = 0.00052
	m.fog_sun_scatter = 0.15
	m.fog_emission = Color(0.06, 0.045, 0.035)
	m.fog_anisotropy = 0.78
	m.volumetric_density = 0.00040

	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.08
	m.white = 8.5
	m.glow_intensity = 0.12
	m.glow_hdr_threshold = 2.2
	m.adjustment_saturation = 1.14
	m.adjustment_contrast = 1.06
	m.dof_near_distance = 0.0
	m.dof_distance = 0.0
	return m


## Sky band, sabkha plain, the Gulf, the tank farm and the horizon plant, laid
## out across `x_from`..`x_to` of gameplay. Layers Z -75 and beyond, so the
## parallax does the work of making a 400-unit level feel like a place.
static func deep_layers(parent: Node3D, mats: Dictionary, x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5

	var sea := MaterialLab.emissive(Color(0.310, 0.765, 0.753), 0.25)
	sea.roughness = 0.12
	sea.metallic = 0.4
	LevelKit.prop(parent, Vector3(mid, -2.0, -150.0), Vector3(span * 2.4 + 700.0, 6.0, 1.0),
		sea, "Sea")
	LevelKit.prop(parent, Vector3(mid, -9.5, -150.0),
		Vector3(span * 2.4 + 900.0, 5.0, 220.0), mats["sabkha"], "SabkhaPlain")

	var haze := MaterialLab.emissive(Color(0.835, 0.804, 0.741), 0.55)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = Color(0.835, 0.804, 0.741, 0.55)
	LevelKit.prop(parent, Vector3(mid, 14.0, -420.0),
		Vector3(span * 3.0 + 1400.0, 34.0, 1.0), haze, "DustBand")

	# Horizon plant. At Z -300 the frustum is 340 units wide, so one set of
	# towers serves a long stretch of level; a second set keeps the far end
	# from running out of skyline.
	var sets := maxi(1, int(span / 240.0) + 1)
	for i in sets:
		var base_x := x_from + span * (float(i) + 0.5) / float(sets)
		PropKit.prilling_tower(parent, Vector3(base_x + 32.0, -10.0, -300.0), 7.0, 62.0,
			mats["tower"])
		PropKit.prilling_tower(parent, Vector3(base_x + 66.0, -10.0, -305.0), 7.6, 71.0,
			mats["tower"])
		PropKit.flare_stack(parent, Vector3(base_x + 104.0, -10.0, -298.0), 58.0, 7.0,
			mats["steel"])

	PropKit.pipe_rack(parent, Vector3(x_from - 160.0, -6.0, -148.0),
		Vector3(x_to + 200.0, -5.0, -152.0), 3, mats["rust"], mats["bund"], 22.0)

	# Tank farm, spread on a 52-unit pitch across the whole run.
	var tanks := maxi(3, int(span / 52.0))
	for i in tanks:
		var tx := x_from - 30.0 + i * 52.0
		var burnt := i % 5 == 1
		var t := PropKit.storage_tank(parent, Vector3(tx, -8.0, -75.0 - float(i % 2) * 16.0),
			16.0, 21.0, mats["tank"], mats["bund"], mats["rust"], burnt, mats["tank_burnt"])
		if i % 3 == 0:
			PropKit.tank_stair(parent, t.position, 16.0, 21.0, mats["rust"])
		for k in 7:
			var a := PI * (0.10 + 0.13 * k)
			LevelKit.prop(t, Vector3(cos(a) * 16.05, 7.0, sin(a) * 16.05),
				Vector3(0.55, 14.0, 0.55), mats["rust"], "Bleed%d" % k)


## Yard floor, perimeter wall, windbreak and the second block — the layer the
## gameplay plane actually sits in front of.
static func mid_layers(parent: Node3D, mats: Dictionary, x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5

	LevelKit.prop(parent, Vector3(mid, YARD_Y - 1.2, -16.0),
		Vector3(span + 120.0, 2.4, 50.0), mats["sabkha"], "YardFloor")
	for i in int(span / 26.0) + 1:
		LevelKit.prop(parent, Vector3(x_from + i * 26.0, YARD_Y + 0.02, -18.0 + float(i % 3) * 2.4),
			Vector3(15.0, 0.06, 1.3), mats["mud"], "TyreRut%d" % i)

	# Debris on the yard floor. Without it the lower third of every frame is an
	# empty band of haze.
	for i in int(span / 11.0) + 1:
		var x := x_from + i * 11.0 + fmod(float(i) * 4.3, 6.0)
		var z := -12.0 - fmod(float(i) * 5.1, 12.0)
		match i % 4:
			0:
				var c := LevelKit.prop(parent, Vector3(x, YARD_Y + 0.55, z),
					Vector3(1.5, 1.1, 1.3), mats["crate"], "YardCrate")
				c.rotation.y = fmod(float(i) * 0.9, 1.2)
			1:
				var d := LevelKit.prop(parent, Vector3(x, YARD_Y + 0.42, z),
					Vector3(0.7, 0.9, 0.7), mats["rust"], "YardDrum")
				d.rotation.z = 1.57 if i % 8 == 1 else 0.0
			2:
				LevelKit.prop(parent, Vector3(x, YARD_Y + 0.10, z),
					Vector3(3.4, 0.18, 1.1), mats["rust"], "YardPlate")
			_:
				var p := LevelKit.prop(parent, Vector3(x, YARD_Y + 0.9, z),
					Vector3(0.24, 1.8, 0.24), mats["steel"], "YardPost")
				p.rotation.z = fmod(float(i) * 0.31, 0.5) - 0.25

	PropKit.prefab_facade(parent, x_from - 10.0, YARD_Y, span + 60.0, 8.4, -38.0,
		mats["slab"], {
			"name": "BlockTwo", "joint_mat": mats["wall"], "dark_mat": mats["wall"],
			"hole_mat": mats["wall"], "depth": 6.0, "open_holes": 0,
		})

	PropKit.perimeter_wall(parent, x_from - 45.0, YARD_Y, span + 90.0, 4.5, -16.0,
		mats["wall"], mats["joint"])

	# The pole line: the same one that walks out of the benchmark frame, run
	# the length of the level so every section has something between the yard
	# and the horizon.
	var tops: Array[Vector3] = []
	for i in int(span / 13.0) + 2:
		var px := x_from - 10.0 + i * 13.0
		var ph := 7.2 + sin(float(i) * 1.7) * 0.5
		LevelKit.prop(parent, Vector3(px, YARD_Y + ph * 0.5, -13.0),
			Vector3(0.22, ph, 0.22), mats["steel"], "Pole%d" % i)
		LevelKit.prop(parent, Vector3(px, YARD_Y + ph - 0.55, -13.0),
			Vector3(2.3, 0.14, 0.14), mats["steel"], "Crossarm%d" % i)
		tops.append(Vector3(px, YARD_Y + ph - 0.55, -13.0))
	for i in tops.size() - 1:
		for lane in 3:
			var lift := -0.02 - lane * 0.02
			PropKit.cable(parent, tops[i] + Vector3(-0.9 + lane * 0.9, lift, 0.0),
				tops[i + 1] + Vector3(-0.9 + lane * 0.9, lift, 0.0),
				0.95 + lane * 0.12, mats["dark"], 10, 0.055)
	PropKit.razor_coil(parent, Vector3(x_from - 20.0, YARD_Y + 4.7, -16.0),
		Vector3(x_to + 30.0, YARD_Y + 4.7, -16.0), 0.20,
		mats["rust"], int(span / 3.0) + 10)

	plant_band(parent, mats, x_from, x_to)
	foreground_band(parent, mats, x_from, x_to)

	for i in int(span / 9.0) + 1:
		PropKit.eucalyptus(parent, Vector3(x_from + i * 9.0 + fmod(float(i) * 3.1, 2.0),
			YARD_Y, -21.0 - fmod(float(i) * 1.7, 3.0)),
			8.6 + fmod(float(i) * 2.7, 3.0), mats["trunk"], mats["leaf"], i % 2 == 1, i)


## A band of near-black junk between the camera and the play plane. Every frame
## in World 1 was landing with an empty bottom third; a foreground silhouette
## is what gives an image a floor to stand on, and the yard of a working plant
## has plenty lying about.
##
## Sized to the near frustum, not to the world: at z = +7 the frame is about
## six units across, so these are small and there are a lot of them.
static func foreground_band(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409
	var x := x_from
	while x < x_to:
		x += rng.randf_range(6.0, 12.0)
		var z := rng.randf_range(5.2, 8.6)
		var y := YARD_Y + rng.randf_range(0.0, 0.6)
		match rng.randi() % 5:
			0:
				var t := LevelKit.prop(parent, Vector3(x, y + 0.30, z),
					Vector3(1.00, 0.36, 1.00), mats["dark"], "FgTyre")
				t.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0.0,
					rng.randf_range(-0.2, 0.2))
			1:
				var d := LevelKit.prop(parent, Vector3(x, y + 0.44, z),
					Vector3(0.62, 0.88, 0.62), mats["dark"], "FgDrum")
				d.rotation.z = 1.57 if rng.randf() < 0.4 else 0.0
			2:
				LevelKit.prop(parent, Vector3(x, y + 0.14, z),
					Vector3(2.60, 0.28, 1.20), mats["dark"], "FgPallet")
			3:
				var p := LevelKit.prop(parent, Vector3(x, y + 0.85, z),
					Vector3(0.18, 1.70, 0.18), mats["dark"], "FgPost")
				p.rotation.z = rng.randf_range(-0.42, 0.42)
			_:
				# A low kerb run: a horizontal that crosses the bottom of the
				# frame instead of another object sitting in it.
				LevelKit.prop(parent, Vector3(x + 3.0, y + 0.16, z),
					Vector3(rng.randf_range(5.0, 11.0), 0.32, 0.5),
					mats["dark"], "FgKerb")


## The working plant, behind the perimeter wall. Level 1 is a walk past a
## petrochemical complex and until now the band between the wall and the
## horizon was empty, so every gameplay frame fell into "stuff at the front,
## haze at the back" with nothing in between.
##
## Laid out on a long rhythm — a column group, then a vessel, then a gantry
## run — so the parallax never repeats within a screen.
static func plant_band(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var shell := MaterialLab.plaster(Color(0.238, 0.226, 0.208), 1.0)
	var frame: Material = mats["steel"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7723
	var x := x_from - 20.0
	var beat := 0
	while x < x_to + 20.0:
		match beat % 3:
			0:
				for i in 3:
					PropKit.column(parent,
						Vector3(x + i * 6.5, YARD_Y, -32.0 - rng.randf_range(0.0, 6.0)),
						rng.randf_range(10.0, 20.0), rng.randf_range(1.1, 1.8),
						shell, frame, rng.randi_range(3, 5))
				PropKit.drum_stack(parent, Vector3(x + 4.0, YARD_Y, -22.0),
					rng.randi_range(4, 6), rng.randi_range(2, 3), mats["rust"])
				x += 26.0
			1:
				PropKit.vessel(parent, Vector3(x + 6.0, YARD_Y + 3.0, -26.0),
					rng.randf_range(8.0, 13.0), rng.randf_range(1.1, 1.6),
					shell, mats["bund"])
				# Stair tower: diagonals against all those verticals.
				for i in 7:
					var fl := LevelKit.prop(parent,
						Vector3(x + 16.0 + (i % 2) * 2.0, YARD_Y + 0.9 + i * 1.35, -29.0),
						Vector3(2.6, 0.16, 1.5), frame, "Flight")
					fl.rotation.z = deg_to_rad(-31.0 if i % 2 == 0 else 31.0)
					LevelKit.prop(parent,
						Vector3(x + 17.0, YARD_Y + 1.6 + i * 1.35, -29.0),
						Vector3(3.6, 0.10, 1.6), frame, "Landing")
				x += 30.0
			_:
				# A conveyor gantry on legs, running out of frame both ways.
				var gy := YARD_Y + 8.7
				LevelKit.prop(parent, Vector3(x + 18.0, gy, -19.5),
					Vector3(40.0, 1.5, 2.0), mats["bund"], "ConveyorCase")
				LevelKit.prop(parent, Vector3(x + 18.0, gy + 0.85, -19.5),
					Vector3(40.0, 0.22, 2.3), frame, "ConveyorLid")
				for i in 6:
					LevelKit.prop(parent, Vector3(x + i * 7.6, YARD_Y + 3.3, -19.5),
						Vector3(0.42, 6.6, 0.42), frame, "GantryLeg")
				x += 42.0
		beat += 1
