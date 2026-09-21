extends Stage
## BREGA PRISON BREAKOUT — beauty benchmark: "FIRST LIGHT, EXERCISE YARD".
##
## One screen at final shippable quality, built to docs/ART_DIRECTION.md.
## Every later level has to match or beat this frame.
##
## The read: Wanis on the raised walkway above the exercise yard, back-lit by a
## sun two minutes from clearing the horizon behind a dead fertiliser plant. He
## has stopped, because he can see the way out and it is a long way off.
##
## Composition note (art-director call, deviating from the written brief): the
## brief has the cell block running the full frame width at Z = -5. At that
## distance a 10 m block subtends more of the frame than a 71 m tower at Z = -300,
## so it would bury every layer behind it. The block therefore runs the left 55%
## and STOPS just past him. The left of frame is the prison he is leaving; the
## right is the distance he has to cover. The rail ending at a broken post and
## the eye falling off into the yard is the same beat, better served.
##
## Depth layers, front to back:
##   +9  razor wire, dead casuarina        +5  chain-link fence
##    0  walkway, rail, door, sriracha     -5  cell block facade
##  -14  yard floor, perimeter, windbreak -22  pipe rack
##  -75  tank farm                       -140  sabkha plain, the sea
## -300  prilling towers, flare stack     sky

const YARD_Y := -6.6
const DECK_Y := 0.0

var mats := {}


func _ready() -> void:
	level_id = "brega_beauty"
	level_title = "BREGA — FIRST LIGHT"
	show_hud = false   ## it is a beauty frame; the HUD is signed off elsewhere
	spawn_point = Vector3(0.0, 1.2, 0.0)
	kill_plane_y = -40.0
	super._ready()
	# Beauty framing: lower than gameplay, so the horizon sits high and the
	# distance he has to cover fills two thirds of the frame.
	camera.height_offset = 1.25
	# He sits at a third from the left, so two thirds of the frame is the
	# distance he still has to cover.
	camera.lateral_offset = 3.3
	camera.distance = 16.0
	camera.base_fov = 34.0


func _mood() -> LightingRig.Mood:
	var m := LightingRig.Mood.new()

	# Key: altitude 3.5 deg, behind and screen-right. He is back-lit for the
	# whole level and the rim is the only reason he reads at all.
	m.sun_angles = Vector2(-3.5, 150.0)
	m.sun_color = Color(1.0, 0.565, 0.251)      # 2200 K
	m.sun_energy = 3.1
	m.sun_angular_distance = 1.1
	m.sun_disc_size = 0.34   ## a smaller disc; the glow was owning the frame
	m.sun_fog_energy = 3.0

	# Fill: the sabkha bounce from below-front. Cool, and deliberately weak —
	# the front of the block is in shade and it has to STAY in shade, because
	# the hero is a white thobe and he only reads if the wall behind him is a
	# value he can beat. Warm light and cool shadow is also the only thing
	# stopping this frame being one orange.
	m.fill_angles = Vector2(18.0, -28.0)
	m.fill_color = Color(0.475, 0.545, 0.720)
	m.fill_energy = 0.54

	# Rim: hero layer only.
	m.rim_angles = Vector2(-4.0, 128.0)
	m.rim_color = Color(1.0, 0.722, 0.467)
	m.rim_energy = 8.0
	m.rim_cull_mask = 2

	m.hero_fill_energy = 2.5
	m.hero_fill_color = Color(0.72, 0.78, 0.94)
	m.hero_fill_angles = Vector2(-14.0, -30.0)

	# Near DOF in Godot blurs by distance from the camera, and the whole
	# gameplay plane sits inside any radius large enough to soften the
	# foreground. Foreground separation is done with value and scale instead.
	m.dof_near_distance = 0.0
	m.dof_distance = 0.0

	m.sky_top = Color(0.169, 0.227, 0.333)      # #2B3A55
	m.sky_horizon = Color(0.788, 0.482, 0.271)  # #C97B45
	m.ground_horizon = Color(0.835, 0.804, 0.741)
	m.ground_bottom = Color(0.376, 0.345, 0.306)
	m.sky_energy = 1.0
	m.sky_curve = 0.11
	m.volumetric_density = 0.0010
	m.ambient_energy = 0.29

	m.fog_color = Color(0.835, 0.804, 0.741)
	m.fog_density = 0.0009
	# 0.35 puts a hot bloom on everything within 40 degrees of the key and the
	# whole right of frame goes to white paper.
	m.fog_sun_scatter = 0.15
	m.fog_emission = Color(0.06, 0.045, 0.035)
	m.fog_anisotropy = 0.78

	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.08
	m.white = 8.5
	m.glow_intensity = 0.17
	m.glow_hdr_threshold = 1.85
	m.adjustment_saturation = 1.14
	m.adjustment_contrast = 1.06
	return m


func _build_level() -> void:
	_palette()
	_layer_sky_and_sea()
	_layer_horizon()
	_layer_tank_farm()
	_layer_mid_yard()
	_layer_pipe_rack()
	_layer_bridge()
	_layer_flare()
	_layer_facade()
	_layer_gameplay()
	_layer_foreground()
	_atmosphere()
	_practicals()


func _palette() -> void:
	mats = {
		# Prefab slab beige, salt-fretted at the base.
		"slab": MaterialLab.plaster(Color(0.425, 0.402, 0.356), 1.0),
		"joint": MaterialLab.concrete(Color(0.170, 0.156, 0.138), 1.0),
		"dark": MaterialLab.concrete(Color(0.055, 0.050, 0.050), 0.2),
		"wall": MaterialLab.plaster(Color(0.180, 0.172, 0.162), 1.0),
		"deck": MaterialLab.concrete(Color(0.325, 0.312, 0.290), 1.0),
		"rail": MaterialLab.rusted_metal(Color(0.40, 0.235, 0.145), 0.75),
		"rebar": MaterialLab.rusted_metal(Color(0.757, 0.396, 0.165), 1.0),
		"rust": MaterialLab.rusted_metal(Color(0.243, 0.133, 0.090), 1.0),
		"tank": MaterialLab.plaster(Color(0.415, 0.398, 0.366), 1.0),
		"tank_burnt": MaterialLab.concrete(Color(0.125, 0.098, 0.086), 1.0),
		"bund": MaterialLab.concrete(Color(0.245, 0.233, 0.210), 1.0),
		"tower": MaterialLab.concrete(Color(0.300, 0.290, 0.274), 1.0),
		"steel": MaterialLab.painted_metal(Color(0.055, 0.055, 0.062), 0.9),
		"sabkha": MaterialLab.sand(Color(0.576, 0.553, 0.502)),
		"mud": MaterialLab.concrete(Color(0.271, 0.231, 0.180), 1.0),
		"sand": MaterialLab.sand(Color(0.867, 0.796, 0.651)),
		"trunk": MaterialLab.plaster(Color(0.208, 0.200, 0.184), 1.0),
		"leaf": PropKit.foliage_material(Color(0.212, 0.243, 0.180), YARD_Y, 9.0, 0.42),
		"door": MaterialLab.painted_metal(Color(0.184, 0.365, 0.275), 0.7),
		"green": MaterialLab.plaster(Color(0.185, 0.268, 0.200), 1.0),
		"shutter": MaterialLab.painted_metal(Color(0.420, 0.290, 0.196), 1.0),
		"bag": MaterialLab.cloth(Color(0.678, 0.639, 0.545), 0.95),
	}
	# Salt spalling: grime creeps up from the yard floor, not from y=0.
	for key: String in ["slab", "wall", "deck"]:
		mats[key].set_shader_parameter("grime_origin_y", YARD_Y)
		mats[key].set_shader_parameter("grime_falloff", 1.9)
		mats[key].set_shader_parameter("grime_color", Color(0.29, 0.25, 0.20))
		mats[key].set_shader_parameter("grime_amount", 0.55)


# --- Layer 0-2: sky, sea, horizon ------------------------------------------

func _layer_sky_and_sea() -> void:
	# The Gulf of Sidra, a thin band in the gap between the towers. Flat coast:
	# no cliffs, no hills, and that flatness is the point.
	var sea := MaterialLab.emissive(Color(0.310, 0.765, 0.753), 0.25)
	sea.roughness = 0.12
	sea.metallic = 0.4
	LevelKit.prop(geometry, Vector3(120.0, -2.0, -150.0), Vector3(700.0, 6.0, 1.0),
		sea, "Sea")
	# Sabkha plain running flat to the horizon, blinding pale.
	LevelKit.prop(geometry, Vector3(40.0, -9.5, -150.0), Vector3(900.0, 5.0, 220.0),
		mats["sabkha"], "SabkhaPlain")
	# The bleached straw aerosol band above the horizon glow — Saharan dust,
	# thicker than any temperate sky would carry.
	var haze := MaterialLab.emissive(Color(0.835, 0.804, 0.741), 0.55)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = Color(0.835, 0.804, 0.741, 0.55)
	LevelKit.prop(geometry, Vector3(60.0, 14.0, -420.0), Vector3(1400.0, 34.0, 1.0),
		haze, "DustBand")


func _layer_horizon() -> void:
	# Two urea prilling towers and the dead flare stack. The flare is the most
	# eloquent object in the shot: nothing is burning on it.
	PropKit.prilling_tower(geometry, Vector3(62.0, -10.0, -300.0), 7.0, 62.0, mats["tower"])
	PropKit.prilling_tower(geometry, Vector3(96.0, -10.0, -305.0), 7.6, 71.0, mats["tower"])
	PropKit.flare_stack(geometry, Vector3(134.0, -10.0, -298.0), 58.0, 7.0, mats["steel"])
	# Pipe corridor crossing the plain on concrete sleepers.
	PropKit.pipe_rack(geometry, Vector3(-140.0, -6.0, -148.0), Vector3(300.0, -5.0, -152.0),
		3, mats["rust"], mats["bund"], 22.0)


func _layer_tank_farm() -> void:
	var xs := [-28.0, 8.0, 44.0, 80.0, 116.0, 152.0]
	for i in xs.size():
		var burnt := i == 1   # the burnt tank sits near the golden section
		var t := PropKit.storage_tank(geometry,
			Vector3(xs[i], -8.0, -75.0 - (i % 2) * 16.0), 16.0, 21.0,
			mats["tank"], mats["bund"], mats["rust"], burnt, mats["tank_burnt"])
		if i == 0 or i == 3:
			PropKit.tank_stair(geometry, t.position, 16.0, 21.0, mats["rust"])
		for k in 7:
			var a := PI * (0.10 + 0.13 * k)
			LevelKit.prop(t, Vector3(cos(a) * 16.05, 7.0, sin(a) * 16.05),
				Vector3(0.55, 14.0, 0.55), mats["rust"], "Bleed%d" % k)


# --- Layer 4: mid background -----------------------------------------------

func _layer_mid_yard() -> void:
	# Yard floor: cracked concrete going to sabkha crust, tyre ruts cutting
	# through to dark mud.
	LevelKit.prop(geometry, Vector3(20.0, YARD_Y - 1.2, -16.0), Vector3(320.0, 2.4, 50.0),
		mats["sabkha"], "YardFloor")
	for i in 5:
		LevelKit.prop(geometry, Vector3(9.0 + i * 9.0, YARD_Y + 0.02, -18.0 + i * 2.4),
			Vector3(14.0, 0.06, 1.3), mats["mud"], "TyreRut%d" % i)

	# The opposite block, partly hidden behind the near one.
	PropKit.prefab_facade(geometry, 13.0, YARD_Y, 72.0, 8.4, -32.0, mats["slab"], {
		"name": "BlockTwo", "joint_mat": mats["joint"], "dark_mat": mats["dark"],
		"hole_mat": mats["joint"], "depth": 6.0, "open_holes": 2,
	})

	# Perimeter wall, 4.5 m, razor wire along the top, running to the right edge.
	LevelKit.prop(geometry, Vector3(30.0, YARD_Y + 2.25, -16.0), Vector3(90.0, 4.5, 0.9),
		mats["wall"], "PerimeterWall")
	PropKit.sign(geometry, "ممنوع الاقتراب", Vector3(8.4, YARD_Y + 2.9, -15.4), 0.46,
		MaterialLab.plaster(Color(0.58, 0.55, 0.50), 1.0), PropKit.FONT_KUFI)
	PropKit.razor_coil(geometry, Vector3(-10.0, YARD_Y + 4.7, -16.0),
		Vector3(74.0, YARD_Y + 4.7, -16.0), 0.20, mats["rust"], 56)

	_yard_furniture()

	# Dead eucalyptus windbreak: seven trunks in a dead-straight planted line.
	# The straightness is what says someone put these here.
	for i in 9:
		PropKit.eucalyptus(geometry, Vector3(4.0 + i * 4.6, YARD_Y, -21.0),
			8.2 + fmod(float(i) * 2.7, 2.4), mats["trunk"], mats["leaf"], i >= 6, i)


## A guard tower, a gate and two dead vehicles. Without these the yard is a
## bright void and the composition has nothing to travel across.
func _yard_furniture() -> void:
	# Guard tower: the strongest silhouette in the mid ground, and the thing
	# that says this is a prison and not a works yard.
	var tx := 13.2
	var tz := -18.0
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		LevelKit.prop(geometry, Vector3(tx + sx * 0.85, YARD_Y + 3.2, tz + sz * 0.85),
			Vector3(0.22, 6.4, 0.22), mats["steel"], "TowerLeg%d" % i)
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 6.6, tz), Vector3(3.0, 0.3, 3.0),
		mats["steel"], "TowerDeck")
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 7.6, tz), Vector3(2.7, 1.7, 2.7),
		mats["wall"], "TowerCab")
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 8.2, tz + 1.36), Vector3(2.3, 0.75, 0.06),
		mats["dark"], "TowerGlass")
	var roof := LevelKit.prop(geometry, Vector3(tx, YARD_Y + 8.7, tz),
		Vector3(3.6, 0.12, 3.6), MaterialLab.corrugated(Color(0.30, 0.285, 0.26), 18.0),
		"TowerRoof")
	roof.rotation.x = 0.05

	# Gate in the perimeter wall, chained shut.
	LevelKit.prop(geometry, Vector3(24.0, YARD_Y + 1.9, -15.7), Vector3(5.6, 3.8, 0.10),
		mats["rust"], "Gate")
	for i in 9:
		LevelKit.prop(geometry, Vector3(21.4 + i * 0.62, YARD_Y + 1.9, -15.62),
			Vector3(0.09, 3.7, 0.08), mats["steel"], "GateBar%d" % i)

	# Two dead vehicles: a flatbed and a pickup, stripped and sanded in.
	for spec: Array in [[18.5, -12.0, 5.2, 1.9], [30.0, -13.5, 4.4, 1.6]]:
		var x: float = spec[0]
		var z: float = spec[1]
		var l: float = spec[2]
		var h: float = spec[3]
		LevelKit.prop(geometry, Vector3(x, YARD_Y + h * 0.42, z), Vector3(l, h * 0.55, 2.0),
			mats["rust"], "VehicleBody")
		LevelKit.prop(geometry, Vector3(x - l * 0.28, YARD_Y + h * 0.80, z),
			Vector3(l * 0.40, h * 0.46, 1.9), mats["rust"], "VehicleCab")
		for w: int in [-1, 1]:
			LevelKit.prop(geometry, Vector3(x + w * l * 0.32, YARD_Y + 0.28, z + 0.95),
				Vector3(0.62, 0.56, 0.26), mats["dark"], "Wheel")


func _layer_pipe_rack() -> void:
	# Enters upper-right and runs down-left on a shallow diagonal, pointing at him.
	PropKit.pipe_rack(geometry, Vector3(46.0, 22.0, -26.0), Vector3(9.5, 4.6, -26.0),
		5, mats["rust"], mats["bund"], 9.0)


# --- Layer 5: the cell block facade ----------------------------------------

## The one thing burning in a plant that stopped running: a flare with a live
## tip and a plume that drifts across the empty half of the frame. It is the
## focal point the right of the image did not have, and the only motion in the
## composition big enough to read at this distance.
func _layer_flare() -> void:
	var base := Vector3(22.0, YARD_Y - 1.0, -52.0)
	PropKit.flare_stack(geometry, base, 21.0, 4.4, mats["steel"])

	var tip := base + Vector3(0.0, 21.2, 0.0)
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 0.78
	cone.height = 3.4
	cone.radial_segments = 12
	flame.mesh = cone
	# Additive at high energy goes white and the flare stops being fire. Keep
	# the energy low and let the colour carry it.
	var fire := MaterialLab.emissive(Color(1.0, 0.36, 0.07), 1.1)
	fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.albedo_color = Color(1.0, 0.42, 0.10, 0.75)
	flame.material_override = fire
	flame.position = tip + Vector3(0.45, 1.7, 0.0)
	flame.rotation_degrees = Vector3(0.0, 0.0, -14.0)
	geometry.add_child(flame)

	var glow := OmniLight3D.new()
	glow.name = "FlareGlow"
	glow.light_color = Color(1.0, 0.60, 0.22)
	glow.light_energy = 28.0
	glow.omni_range = 34.0
	glow.light_volumetric_fog_energy = 4.0
	glow.shadow_enabled = false
	glow.position = tip + Vector3(0.0, 2.0, 0.0)
	geometry.add_child(glow)

	_plume(tip + Vector3(1.0, 3.2, 0.0))


## The plume. Big, slow, and leaning downwind, which at this distance is the
## only movement in frame that the eye can actually see.
func _plume(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "FlarePlume"
	p.position = at
	p.amount = 170
	p.lifetime = 26.0
	p.preprocess = 24.0
	p.fixed_fps = 24
	p.interpolate = true
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -6, -20), Vector3(140, 90, 40))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.1
	# Downwind, not straight up: a vertical plume leaves the frame in two
	# seconds, and a plume that lies over on the wind is what a flare in an
	# onshore breeze actually does.
	pm.direction = Vector3(1.0, 0.30, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 3.6
	pm.gravity = Vector3(0.75, 0.02, 0.0)
	pm.scale_min = 4.0
	pm.scale_max = 11.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 0.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.30, 0.20, 0.16, 0.62))
	ramp.set_color(1, Color(0.34, 0.29, 0.28, 0.0))
	ramp.add_point(0.16, Color(0.38, 0.26, 0.19, 0.55))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1, 1, 1, 1)
	sm.albedo_texture = PropKit._decal_texture("radial")
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.disable_receive_shadows = true
	quad.material = sm
	p.draw_pass_1 = quad
	geometry.add_child(p)


## Layer -13: the middle ground.
##
## The recorded failure of this frame was that it split into a dark building on
## the left and a bright haze on the right with nothing between them. This is
## the between: a pole line and a conveyor gantry that both start behind the
## block and walk out into the light, so the eye has a way across.
func _layer_bridge() -> void:
	var z := -13.0
	var steel: Material = mats["steel"]

	# Pole line. The poles march out of the block's shadow into the sun, which
	# is the transition the frame was missing.
	var tops: Array[Vector3] = []
	for i in 7:
		var x := -6.0 + i * 7.4
		var h := 7.2 + sin(float(i) * 1.7) * 0.5
		LevelKit.prop(geometry, Vector3(x, YARD_Y + h * 0.5, z),
			Vector3(0.22, h, 0.22), steel, "Pole%d" % i)
		# Crossarm, so the pole is a shape and not a stick.
		LevelKit.prop(geometry, Vector3(x, YARD_Y + h - 0.55, z),
			Vector3(2.3, 0.14, 0.14), steel, "Crossarm%d" % i)
		tops.append(Vector3(x, YARD_Y + h - 0.55, z))
	for i in tops.size() - 1:
		for lane in 3:
			var off := Vector3(0.0, 0.0, 0.0)
			var lift := -0.02 - lane * 0.02
			PropKit.cable(geometry, tops[i] + Vector3(-0.9 + lane * 0.9, lift, 0.0),
				tops[i + 1] + Vector3(-0.9 + lane * 0.9, lift, 0.0),
				0.95 + lane * 0.12, mats["dark"], 12, 0.058)

	# A conveyor gantry running out of the block toward the plant, on legs.
	var gz := -17.5
	var gantry := Node3D.new()
	gantry.name = "Conveyor"
	geometry.add_child(gantry)
	var y0 := YARD_Y + 6.6
	LevelKit.prop(gantry, Vector3(14.0, y0 + 2.1, gz), Vector3(46.0, 1.5, 2.0),
		mats["bund"], "ConveyorCase")
	LevelKit.prop(gantry, Vector3(14.0, y0 + 2.95, gz), Vector3(46.0, 0.22, 2.3),
		steel, "ConveyorLid")
	for i in 6:
		var lx := -4.0 + i * 8.0
		LevelKit.prop(gantry, Vector3(lx, YARD_Y + 3.3, gz),
			Vector3(0.42, 6.6, 0.42), steel, "GantryLeg%d" % i)
		LevelKit.prop(gantry, Vector3(lx + 1.6, YARD_Y + 4.6, gz),
			Vector3(3.4, 0.16, 0.16), steel, "GantryBrace%d" % i)

	# A header tank on a frame, out in the light: the one bright silhouette in
	# the middle distance, so the eye has somewhere to land between the two
	# halves of the frame.
	var tz := -11.0
	for i in 4:
		LevelKit.prop(geometry, Vector3(9.4 + (i % 2) * 2.6, YARD_Y + 2.6, tz + (i / 2) * 2.2),
			Vector3(0.24, 5.2, 0.24), steel, "TowerLeg%d" % i)
	LevelKit.prop(geometry, Vector3(10.7, YARD_Y + 5.6, tz + 1.1),
		Vector3(4.2, 1.0, 3.4), mats["tank"], "HeaderTank")
	LevelKit.prop(geometry, Vector3(10.7, YARD_Y + 6.3, tz + 1.1),
		Vector3(3.4, 0.5, 2.8), mats["tank"], "HeaderTankCap")


func _layer_facade() -> void:
	var facade := PropKit.prefab_facade(geometry, -62.0, YARD_Y, 67.0, 10.6, -5.0,
		mats["slab"], {
			"name": "CellBlock", "joint_mat": mats["joint"], "dark_mat": mats["dark"],
			"hole_mat": mats["joint"], "depth": 5.0, "open_holes": 3,
		})
	# The block's end wall, catching the key edge-on — it is what makes the
	# building read as a solid and not as a painted flat.
	LevelKit.prop(facade, Vector3(5.0, YARD_Y + 5.3, -5.0), Vector3(0.5, 10.6, 5.2),
		mats["joint"], "BlockEndWall")

	# The whole front of this wall is in shade — the key is behind the building
	# — so everything that stops it reading as one flat grey has to come from
	# bounce. Warm off the yard floor along the bottom, cool sky down the top.
	var bounce := MeshInstance3D.new()
	bounce.name = "YardBounce"
	var bq := QuadMesh.new()
	bq.size = Vector2(67.0, 5.4)
	bounce.mesh = bq
	bounce.material_override = PropKit.gradient_decal(
		Color(0.74, 0.40, 0.17), 0.46, "band")
	bounce.position = Vector3(-28.5, YARD_Y + 2.7, -2.44)
	facade.add_child(bounce)

	var skylit := MeshInstance3D.new()
	skylit.name = "SkyBounce"
	var sq := QuadMesh.new()
	sq.size = Vector2(67.0, 4.6)
	skylit.mesh = sq
	skylit.material_override = PropKit.gradient_decal(
		Color(0.36, 0.44, 0.66), 0.30, "streak")
	skylit.position = Vector3(-28.5, YARD_Y + 8.3, -2.44)
	facade.add_child(skylit)

	# Everything bolted to the front of a wall that has been in use for fifty
	# years. The face is in shade, so none of its detail can come from light —
	# it all has to stand off the wall and read as silhouette.
	PropKit.wall_services(facade, -60.0, YARD_Y, 64.0, 10.4, -2.46,
		mats["rust"], mats["steel"], 5)

	# The roofline is where this building gets to be lived in: aerials, dishes
	# all pointed the same way, header tanks. Silhouette against a bright sky
	# costs nothing and is most of what separates a set from a box.
	PropKit.roof_clutter(facade, -60.0, YARD_Y + 10.75, 64.0, -4.6,
		mats["dark"], 13)
	# A service drop off the parapet to the first pole, sagging across the gap.
	PropKit.cable(facade, Vector3(4.2, YARD_Y + 10.5, -3.0),
		Vector3(-6.0, YARD_Y + 6.6, -13.0), 1.1, mats["dark"], 14, 0.060)
	PropKit.cable(facade, Vector3(4.2, YARD_Y + 10.2, -3.0),
		Vector3(-6.0, YARD_Y + 6.3, -13.0), 1.35, mats["dark"], 14, 0.060)

	# Salt has fretted the bottom half-metre back to blockwork.
	LevelKit.prop(facade, Vector3(-28.5, YARD_Y + 0.25, -2.2), Vector3(67.0, 0.5, 0.22),
		mats["joint"], "SaltFret")

	# Small deep-set windows on a 3 m rhythm, half with bent louvred shutters.
	for i in 14:
		var x := -56.0 + i * 4.4
		var y := YARD_Y + (7.9 if i % 3 != 1 else 9.6)
		PropKit.window(facade, Vector3(x, y, -2.46), Vector2(0.84, 1.15), 0.36,
			mats["joint"], mats["dark"], mats["shutter"] if i % 2 == 0 else null,
			-0.9 if i % 5 == 0 else -0.25)

	# The four-layer wall: regime green, a slogan, a crossing-out, a tricolour.
	# The point is that all four are faded by the same sun over the same years —
	# archaeology, not a decal stack. This colour appears in this level and nowhere else.
	var gx := -0.6
	LevelKit.prop(facade, Vector3(gx, YARD_Y + 9.6, -2.46), Vector3(8.6, 1.9, 0.10),
		mats["green"], "RegimeGreenField")
	var white := MaterialLab.plaster(Color(0.62, 0.60, 0.56), 1.0)
	# An invented institutional slogan, not a quotation: "progress for all",
	# painted in Naskh and long since crossed out.
	PropKit.sign(facade, "التقدم للجميع", Vector3(gx, YARD_Y + 9.95, -2.40), 0.62,
		white, PropKit.FONT_NASKH_BOLD)
	var black := MaterialLab.plaster(Color(0.09, 0.085, 0.08), 1.0)
	LevelKit.prop(facade, Vector3(gx, YARD_Y + 9.7, -2.36), Vector3(8.2, 0.17, 0.06),
		black, "CrossOut")
	var tri := [Color(0.400, 0.145, 0.125), Color(0.105, 0.098, 0.090), Color(0.165, 0.318, 0.212)]
	for i in 3:
		LevelKit.prop(facade, Vector3(gx + 1.4, YARD_Y + 8.85 + i * 0.40, -2.32),
			Vector3(3.4, 0.38, 0.05), MaterialLab.plaster(tri[i], 1.0), "Tricolour%d" % i)

	# A water-stained panel run directly behind him. Local contrast, placed.
	# Water staining down three panels behind him, each a different age. Local
	# contrast, but staggered, so it does not read as one placed rectangle.
	var stain_spec := [
		[-1.6, 6.6, 2.6, Color(0.300, 0.279, 0.246)],
		[1.3, 7.4, 3.2, Color(0.258, 0.240, 0.210)],
		[4.2, 6.2, 2.2, Color(0.330, 0.309, 0.274)],
	]
	for spec: Array in stain_spec:
		LevelKit.prop(facade, Vector3(spec[0], YARD_Y + spec[1], -2.42),
			Vector3(2.90, spec[2], 0.05), MaterialLab.plaster(spec[3], 1.0), "Stain")
	for i in 6:
		LevelKit.prop(facade, Vector3(-2.6 + i * 1.42, YARD_Y + 5.6 + fmod(float(i) * 1.7, 1.4),
			-2.40), Vector3(0.16, 2.0 + fmod(float(i) * 2.3, 1.8), 0.05),
			mats["rust"], "RustBleed%d" % i)

	_ground_floor(facade)

	# Split sandbags on the roof parapet.
	PropKit.sandbag_row(facade, -12.0, YARD_Y + 10.6, 16.0, -3.6, mats["bag"], 2)


## Everything between the yard floor and the walkway. Without this the lower
## third of the frame is one flat slab, and a flat slab is not architecture.
func _ground_floor(facade: Node3D) -> void:
	var corrugated := MaterialLab.corrugated(Color(0.30, 0.285, 0.265), 22.0)
	var conduit := MaterialLab.rusted_metal(Color(0.26, 0.22, 0.19), 0.6)

	# Roller shutter into the block, with a bent steel awning over it.
	LevelKit.prop(facade, Vector3(-1.4, YARD_Y + 1.75, -2.44), Vector3(3.4, 3.5, 0.12),
		corrugated, "RollerShutter")
	LevelKit.prop(facade, Vector3(-1.4, YARD_Y + 3.62, -2.28), Vector3(3.9, 0.14, 0.42),
		mats["rust"], "ShutterHead")
	var awning := LevelKit.prop(facade, Vector3(-1.4, YARD_Y + 4.25, -2.10),
		Vector3(4.2, 0.10, 1.35), corrugated, "Awning")
	awning.rotation.x = 0.22
	PropKit.sign(facade, "مخزن ٣", Vector3(-1.4, YARD_Y + 3.95, -2.40), 0.34,
		MaterialLab.plaster(Color(0.58, 0.56, 0.52), 1.0), PropKit.FONT_KUFI)

	# Service run: pipes and conduit banded along the wall at head height.
	for i in 3:
		LevelKit.prop(facade, Vector3(-28.8, YARD_Y + 4.9 + i * 0.26, -2.34),
			Vector3(66.0, 0.11, 0.18), conduit, "Conduit%d" % i)
	for i in 9:
		LevelKit.prop(facade, Vector3(-52.0 + i * 7.0, YARD_Y + 4.9, -2.24),
			Vector3(0.16, 0.90, 0.26), conduit, "ConduitBracket%d" % i)

	# A fallen pallet stack and two drums — the yard is used, not a set.
	for i in 4:
		var p := LevelKit.prop(facade, Vector3(3.2 - i * 0.12, YARD_Y + 0.14 + i * 0.16, -1.60),
			Vector3(1.25, 0.16, 1.05), mats["shutter"], "Pallet%d" % i)
		p.rotation.y = 0.08 * i
	for i in 2:
		LevelKit.prop(facade, Vector3(-5.4 - i * 0.95, YARD_Y + 0.44, -1.70),
			Vector3(0.66, 0.88, 0.66), mats["rust"], "Drum%d" % i)

	# The base is where salt has done the most damage; drive it darker still.
	LevelKit.prop(facade, Vector3(-28.5, YARD_Y + 0.9, -2.30), Vector3(67.0, 1.8, 0.10),
		mats["joint"], "BaseStain")


# --- Layer 6: the gameplay plane -------------------------------------------

func _layer_gameplay() -> void:
	PropKit.walkway(geometry, -34.0, DECK_Y, 38.0, 0.0,
		mats["deck"], mats["rail"], mats["rebar"], [3, 4, 9])
	# The rail stops at a broken post and the eye falls off the end of it.
	LevelKit.prop(geometry, Vector3(3.6, DECK_Y + 0.42, 0.55), Vector3(0.07, 0.84, 0.07),
		mats["rail"], "BrokenPost")

	# The green steel door he just came through, standing half open. The only
	# saturated non-hero colour in the left third.
	var jamb := LevelKit.prop(geometry, Vector3(-3.6, DECK_Y + 1.05, -2.35),
		Vector3(1.25, 2.30, 0.28), mats["joint"], "DoorJamb")
	var door := LevelKit.prop(geometry, Vector3(-3.6, DECK_Y + 1.02, -2.10),
		Vector3(0.96, 2.06, 0.06), mats["door"], "GreenDoor")
	door.position += Vector3(0.42, 0.0, 0.30)
	door.rotation.y = -1.05
	# Sand drifted across the threshold, with a clean swept arc where it swung.
	LevelKit.prop(geometry, Vector3(-3.2, DECK_Y + 0.03, -1.55), Vector3(2.1, 0.06, 1.3),
		mats["sand"], "ThresholdDrift")

	LevelKit.box(geometry, Vector3(-34.0, DECK_Y - 3.0, -1.4), Vector3(3.0, 6.0, 3.0),
		mats["deck"], "StairBlock")

	var plate := MaterialLab.painted_metal(Color(0.62, 0.48, 0.12), 0.9)
	LevelKit.prop(geometry, Vector3(-2.1, DECK_Y + 1.62, -2.43), Vector3(0.62, 0.46, 0.04),
		plate, "DangerPlate")
	PropKit.sign(geometry, "خطر", Vector3(-2.1, DECK_Y + 1.60, -2.38), 0.22,
		MaterialLab.plaster(Color(0.10, 0.09, 0.08), 1.0), PropKit.FONT_KUFI)

	# The first two bottles of the game, starting the trail that leads him out.
	for x: float in [1.6, 2.9]:
		var bottle := Sriracha.new()
		bottle.position = Vector3(x, DECK_Y + 0.42, 0.0)
		geometry.add_child(bottle)


# --- Layers 7-8: foreground -------------------------------------------------

func _layer_foreground() -> void:
	var link := PropKit.chainlink_material(0.42, 30.0)
	PropKit.chainlink(geometry, -18.0, -2.3, 16.0, 3.4, 5.0, link, mats["rust"])
	LevelKit.prop(geometry, Vector3(-10.0, -2.1, 5.0), Vector3(16.0, 0.6, 0.9),
		mats["sand"], "FenceDrift")
	# Plastic bags snagged in the mesh. They move; see _atmosphere.
	for i in 3:
		var pivot := Sway.new()
		pivot.name = "BagSway%d" % i
		pivot.position = Vector3(-15.0 + i * 4.6, -0.5 + i * 0.4, 5.1)
		pivot.amplitude = 0.55 + i * 0.12
		pivot.speed = 1.1 + i * 0.3
		pivot.gust_amplitude = 0.38
		pivot.axis = Vector3(0.35, 0.2, 1.0)
		geometry.add_child(pivot)
		var bag := LevelKit.prop(pivot, Vector3(0.0, -0.34, 0.0),
			Vector3(0.42, 0.58, 0.05), mats["bag"], "SnaggedBag%d" % i)
		bag.rotation.z = 0.2 - i * 0.2

	# A fallen conveyor beam across the bottom-left corner. Every frame needs
	# one near-black shape in front of everything, or the image has no floor.
	# Sized to the near frustum, not to the world: at this depth the frame is
	# only about seven units across, so a beam the length of the walkway would
	# black out the whole image.
	LevelKit.prop(geometry, Vector3(0.9, -0.62, 9.5), Vector3(5.4, 0.46, 0.46),
		mats["dark"], "FallenBeam").rotation.z = deg_to_rad(15.0)
	LevelKit.prop(geometry, Vector3(-0.5, 0.15, 9.5), Vector3(0.34, 2.0, 0.34),
		mats["dark"], "BeamStub").rotation.z = deg_to_rad(-11.0)

	# Razor wire across the top-left corner, heavy near-DOF, reading as a shape.
	PropKit.razor_coil(geometry, Vector3(-7.6, 3.0, 9.0), Vector3(-2.6, 1.9, 9.0),
		0.30, mats["dark"], 10, "RazorCoilForeground")
	# A dead casuarina closing the right edge, silvered bone-white.
	PropKit.eucalyptus(geometry, Vector3(9.6, -5.4, 8.6), 13.0,
		mats["dark"], mats["dark"], false, 91)


# --- Atmosphere -------------------------------------------------------------

func _atmosphere() -> void:
	# Ground mist in the low yard: the sabkha is damp before sunrise, and this is
	# what makes the eucalyptus row read as depth.
	_fog_volume(Vector3(20.0, YARD_Y + 1.6, -18.0), Vector3(180.0, 4.2, 40.0), 0.055, "YardMist")
	# Hero pocket: negative density so he does not wash out inside the volumetrics.
	var pocket := _fog_volume(Vector3(0.0, 1.0, 0.0), Vector3(13.0, 9.0, 9.0), -0.9, "HeroPocket")
	pocket.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID

	# Light shafts only exist on the camera side of whatever is cutting them.
	# The key travels toward +z and -x, so the volume has to sit between the
	# pipe rack and the lens, not behind it — which is where it used to be, and
	# why no shaft ever formed.
	var shafts := _fog_volume(Vector3(14.0, 6.5, -13.0), Vector3(52.0, 15.0, 20.0),
		0.020, "PipeRackShafts")
	(shafts.material as FogMaterial).height_falloff = 0.0
	(shafts.material as FogMaterial).edge_fade = 0.30
	(shafts.material as FogMaterial).albedo = Color(1.0, 0.90, 0.76)

	# A second, tighter one in the near yard, cut by the walkway and its legs.
	var near := _fog_volume(Vector3(6.0, -2.4, -5.0), Vector3(26.0, 9.0, 12.0),
		0.016, "YardShafts")
	(near.material as FogMaterial).height_falloff = 0.0
	(near.material as FogMaterial).edge_fade = 0.35

	_dust(Vector3(10.0, -1.0, -12.0), Vector3(60.0, 14.0, 10.0), 340, 0.042)
	_dust(Vector3(40.0, -2.0, -28.0), Vector3(130.0, 28.0, 18.0), 460, 0.10)


func _fog_volume(pos: Vector3, size: Vector3, density: float, name_: String) -> FogVolume:
	var fv := FogVolume.new()
	fv.name = name_
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = size
	fv.position = pos
	var fm := FogMaterial.new()
	fm.density = density
	fm.albedo = Color(1.0, 0.93, 0.82)
	fm.emission = Color(0.06, 0.045, 0.035)
	fm.height_falloff = 1.2
	fm.edge_fade = 0.5
	fv.material = fm
	add_child(fv)
	return fv


## Drifting dust. These catch the key, and they are what makes the sun shafts
## through the pipe rack visible at all.
func _dust(pos: Vector3, extents: Vector3, amount: int, scale_: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.position = pos
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 12.0
	p.fixed_fps = 30
	p.interpolate = true
	p.local_coords = false
	p.visibility_aabb = AABB(-extents, extents * 2.0)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents * 0.5
	pm.direction = Vector3(1.0, 0.12, 0.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.22
	pm.initial_velocity_max = 0.48
	pm.gravity = Vector3(0.0, -0.02, 0.0)
	pm.scale_min = 0.55
	pm.scale_max = 1.7
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.14
	pm.turbulence_noise_scale = 2.2
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(scale_, scale_)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.86, 0.68, 0.22)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.proximity_fade_enabled = true
	dm.proximity_fade_distance = 1.4
	dm.disable_receive_shadows = true
	quad.material = dm
	p.draw_pass_1 = quad
	add_child(p)
	return p


# --- Practical lights -------------------------------------------------------

func _practicals() -> void:
	# A failing corridor strip behind the green door: a warm slab on the deck and
	# an edge on his left shoulder.
	var door_light := SpotLight3D.new()
	door_light.name = "DoorPractical"
	door_light.position = Vector3(-3.6, DECK_Y + 1.30, -2.55)
	door_light.rotation_degrees = Vector3(-8.0, 24.0, 0.0)
	door_light.light_color = Color(1.0, 0.722, 0.467)
	door_light.light_energy = 6.5
	door_light.spot_range = 9.0
	door_light.spot_angle = 52.0
	door_light.spot_angle_attenuation = 1.4
	door_light.shadow_enabled = true
	door_light.light_volumetric_fog_energy = 2.2
	add_child(door_light)

	# Sodium lamp still burning at dawn because nobody turned it off.
	var pole := LevelKit.prop(geometry, Vector3(15.0, YARD_Y + 4.0, -17.0),
		Vector3(0.20, 8.0, 0.20), mats["steel"], "LampPole")
	pole.add_to_group("sodium_pole")
	var sodium := OmniLight3D.new()
	sodium.name = "SodiumPractical"
	sodium.position = Vector3(15.0, YARD_Y + 8.1, -17.0)
	sodium.light_color = Color(1.0, 0.631, 0.231)
	sodium.light_energy = 7.0
	sodium.omni_range = 16.0
	sodium.light_volumetric_fog_energy = 5.0
	add_child(sodium)

	# Negative light under the walkway, to sink the deck's underside into dark.
	var neg := OmniLight3D.new()
	neg.name = "UnderDeckNegative"
	neg.position = Vector3(-2.0, DECK_Y - 1.4, 0.0)
	neg.light_negative = true
	neg.light_energy = 0.7
	neg.omni_range = 8.0
	add_child(neg)
