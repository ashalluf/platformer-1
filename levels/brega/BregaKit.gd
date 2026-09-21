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
		"slab": MaterialLab.plaster(Color(0.545, 0.518, 0.455), 1.0),
		"joint": MaterialLab.concrete(Color(0.235, 0.215, 0.185), 1.0),
		"dark": MaterialLab.concrete(Color(0.055, 0.050, 0.050), 0.2),
		"wall": MaterialLab.plaster(Color(0.255, 0.243, 0.224), 1.0),
		"deck": MaterialLab.concrete(Color(0.40, 0.385, 0.355), 1.0),
		"rail": MaterialLab.rusted_metal(Color(0.40, 0.235, 0.145), 0.75),
		"rebar": MaterialLab.rusted_metal(Color(0.757, 0.396, 0.165), 1.0),
		"rust": MaterialLab.rusted_metal(Color(0.243, 0.133, 0.090), 1.0),
		"tank": MaterialLab.plaster(Color(0.612, 0.592, 0.545), 1.0),
		"tank_burnt": MaterialLab.concrete(Color(0.125, 0.098, 0.086), 1.0),
		"bund": MaterialLab.concrete(Color(0.345, 0.329, 0.294), 1.0),
		"tower": MaterialLab.concrete(Color(0.490, 0.475, 0.447), 1.0),
		"steel": MaterialLab.painted_metal(Color(0.055, 0.055, 0.062), 0.9),
		"sabkha": MaterialLab.sand(Color(0.576, 0.553, 0.502)),
		"mud": MaterialLab.concrete(Color(0.271, 0.231, 0.180), 1.0),
		"sand": MaterialLab.sand(Color(0.867, 0.796, 0.651)),
		"trunk": MaterialLab.plaster(Color(0.208, 0.200, 0.184), 1.0),
		"leaf": PropKit.foliage_material(Color(0.212, 0.243, 0.180), YARD_Y, 9.0, 0.42),
		"door": MaterialLab.painted_metal(Color(0.184, 0.365, 0.275), 0.7),
		"green": MaterialLab.plaster(Color(0.259, 0.376, 0.278), 1.0),
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
	m.sun_fog_energy = 1.9
	m.sun_disc_size = 3.2

	m.fill_angles = Vector2(18.0, -28.0)
	m.fill_color = Color(0.722, 0.690, 0.627)
	m.fill_energy = 0.62

	m.rim_angles = Vector2(-4.0, 128.0)
	m.rim_color = Color(1.0, 0.722, 0.467)
	m.rim_energy = 5.5
	m.rim_cull_mask = 2

	m.hero_fill_energy = 2.1
	m.hero_fill_color = Color(0.72, 0.78, 0.94)
	m.hero_fill_angles = Vector2(-14.0, -30.0)

	m.sky_top = Color(0.169, 0.227, 0.333)
	m.sky_horizon = Color(0.788, 0.482, 0.271)
	m.ground_horizon = Color(0.835, 0.804, 0.741)
	m.ground_bottom = Color(0.376, 0.345, 0.306)
	m.sky_energy = 1.0
	m.sky_curve = 0.11
	m.ambient_energy = 0.34

	m.fog_color = Color(0.835, 0.804, 0.741)
	m.fog_density = 0.0013
	m.fog_sun_scatter = 0.35
	m.fog_emission = Color(0.06, 0.045, 0.035)
	m.fog_anisotropy = 0.78
	m.volumetric_density = 0.0014

	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.14
	m.white = 8.0
	m.glow_intensity = 0.30
	m.glow_hdr_threshold = 1.45
	m.adjustment_saturation = 1.08
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

	PropKit.prefab_facade(parent, x_from - 10.0, YARD_Y, span + 60.0, 8.4, -38.0,
		mats["slab"], {
			"name": "BlockTwo", "joint_mat": mats["wall"], "dark_mat": mats["wall"],
			"hole_mat": mats["wall"], "depth": 6.0, "open_holes": 0,
		})

	LevelKit.prop(parent, Vector3(mid, YARD_Y + 2.25, -16.0),
		Vector3(span + 90.0, 4.5, 0.9), mats["wall"], "PerimeterWall")
	PropKit.razor_coil(parent, Vector3(x_from - 20.0, YARD_Y + 4.7, -16.0),
		Vector3(x_to + 30.0, YARD_Y + 4.7, -16.0), 0.20,
		mats["rust"], int(span / 3.0) + 10)

	for i in int(span / 5.4) + 1:
		PropKit.eucalyptus(parent, Vector3(x_from + i * 5.4, YARD_Y, -21.0),
			8.2 + fmod(float(i) * 2.7, 2.4), mats["trunk"], mats["leaf"], i % 3 == 2, i)
