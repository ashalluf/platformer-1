class_name BregaKit
## Shared Brega environment: palette, mood, and every backdrop band.
##
## The beauty benchmark and the playable level must look like the same place,
## which means they cannot each own a copy of the sky. Both call in here.
##
## Colour and lighting values come from docs/ART_DIRECTION.md, Level 1: 05:52,
## pre-dawn blue cracking into first sun, key 3.5 degrees BELOW the horizon at
## azimuth 150 — behind the geometry, so the whole playing field is in shade
## and the white thobe is the brightest value in the frame. Regime green is the
## level-unique colour.
##
## The backdrop is authored as value-stepped depth bands rather than as one
## pile of scenery. Separation comes from albedo, never from more fog: fog puts
## every band on the same sheet of paper, which is exactly what the first pass
## of this level did. See `palette` for the ladder.

const YARD_Y := -6.6


# --- The navigational spine -------------------------------------------------
#
# A 400-unit level with one skyline is a treadmill: the player runs, nothing
# behind them changes, and they stop believing they are moving. These are six
# structures that exist exactly once, each readable from a long way off. They
# all sit in the z -58 .. -120 band, where parallax is fast enough (three to
# five screen-widths of travel across the level) that passing one is an event,
# but slow enough that it is visible for a minute before and after.
#
# Section they mark, in order: the end of the walkway, the yard, the pipe rack,
# the property cage, the tank farm, the way out.
const LM_GATEHOUSE := 38.0
const LM_COOLING_TOWER := 96.0
const LM_LIVE_FLARE := 152.0
const LM_GANTRY_CRANE := 208.0
const LM_SPHERES := 268.0
const LM_JETTY := 334.0
## Skyline only. Never a platform, never a target, nothing is placed on it.
const LM_MINARET := 352.0


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

		# --- The value ladder -------------------------------------------------
		# Front to back, every band steps up in albedo. This is the whole reason
		# a flat coast with no hills on it reads as deep:
		#
		#   +5..+10  foreground junk      0.055   "dark"
		#   -16      perimeter wall       0.180   "wall"
		#   -20..-44 the plant band       0.225   "plant"
		#   -70..-100 tank farm, landmarks 0.330  "tank"
		#   -100..-190 dunes, jetty, ship  0.430  "far_mid"
		#   -150     the sabkha plain      0.545  "plain"   (ground: catches sky)
		#   -240..-340 the horizon plant   0.560  "far_deep"
		#   -400..-560 dust band, cloud     0.835  additive cards
		"plant": MaterialLab.plaster(Color(0.238, 0.226, 0.208), 1.0),
		"far_mid": MaterialLab.concrete(Color(0.430, 0.415, 0.386), 1.0),
		"far_deep": MaterialLab.concrete(Color(0.560, 0.542, 0.508), 1.0),
		"plain": MaterialLab.sand(Color(0.545, 0.520, 0.468)),
		"dune": MaterialLab.sand(Color(0.478, 0.450, 0.398)),
		# The one deliberate break in the ladder. A steel lattice on the
		# horizon is allowed to stay dark, because the dead flare stack is
		# supposed to be the blackest shape on the skyline — it is what says
		# the plant stopped and nobody is coming. Lifted off the foreground's
		# 0.055 so it still sits behind it.
		"far_steel": MaterialLab.painted_metal(Color(0.130, 0.128, 0.134), 0.9),

		# Faded blue polythene tarpaulin. It is on every building site and every
		# yard on this coast, it is the one cool note in a warm frame, and it is
		# the cheapest big thing that can be made to move.
		"tarp": MaterialLab.cloth(Color(0.196, 0.253, 0.286), 0.92),
		"burnt": MaterialLab.concrete(Color(0.082, 0.070, 0.064), 1.0),
		"ballast": MaterialLab.concrete(Color(0.145, 0.136, 0.124), 1.0),
		"sodium": MaterialLab.emissive(Color(1.0, 0.631, 0.231), 3.4),
	}
	# Salt spalling climbs from the yard floor, not from the gameplay plane.
	for key: String in ["slab", "wall", "deck", "plant"]:
		p[key].set_shader_parameter("grime_origin_y", YARD_Y)
		p[key].set_shader_parameter("grime_falloff", 1.9)
		p[key].set_shader_parameter("grime_color", Color(0.29, 0.25, 0.20))
		p[key].set_shader_parameter("grime_amount", 0.55)
	return p


static func mood() -> LightingRig.Mood:
	var m := LightingRig.Mood.new()

	m.sun_angles = Vector2(42.0, 28.0)
	m.sun_color = Color(1.0, 0.945, 0.860)      # ~5200 K, mid-morning
	m.sun_energy = 3.1
	m.sun_angular_distance = 1.1
	# 3.0 is a beauty-frame number. In gameplay the camera spends its life
	# looking along the key, and at that energy the volumetrics put a hot white
	# wash across the bottom right of every frame.
	m.sun_fog_energy = 0.55
	m.sun_disc_size = 0.5

	# Cool and weak: everything the key can reach is behind the geometry, so
	# the playing field is in shade and has to stay there. He is the brightest
	# value in the frame and that is the whole readability strategy. Matches
	# the benchmark's colour script exactly — see BregaBeauty._mood.
	m.fill_angles = Vector2(18.0, -28.0)
	m.fill_color = Color(0.580, 0.655, 0.800)
	m.fill_energy = 0.54

	m.rim_angles = Vector2(36.0, 36.0)
	m.rim_color = Color(1.0, 0.930, 0.820)
	m.rim_energy = 8.0
	m.rim_cull_mask = 2

	# 2.5 of a cold light on a white robe turns him blue. He is meant to read
	# as warm white against a cool shadow world, not as the one cold thing in
	# a warm one.
	m.hero_fill_energy = 1.45
	m.hero_fill_color = Color(0.82, 0.83, 0.90)
	m.hero_fill_angles = Vector2(-14.0, -30.0)

	m.sky_top = Color(0.086, 0.325, 0.760)
	m.sky_horizon = Color(0.690, 0.845, 0.930)
	m.ground_horizon = Color(0.780, 0.835, 0.820)
	m.ground_bottom = Color(0.300, 0.368, 0.330)
	m.sky_energy = 1.08
	m.sky_curve = 0.11
	m.ambient_energy = 0.58

	m.fog_color = Color(0.835, 0.804, 0.741)
	m.fog_density = 0.00034
	m.fog_sun_scatter = 0.15
	m.fog_emission = Color(0.06, 0.045, 0.035)
	m.fog_anisotropy = 0.78
	m.volumetric_density = 0.00040

	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.08
	m.white = 8.5

	# --- The grade ------------------------------------------------------------
	#
	# AgX ignores `white` entirely, so the 8.5 above was doing nothing and the
	# frame was running on the engine's 16.29 — a shoulder so long that a
	# two-stop-hot key put the pale ground and the white thobe on the same part
	# of it. He could not separate from the floor by value because he WAS the
	# floor's value.
	#
	# 9.5 pulls the shoulder in, 1.45 puts the contrast back, and the key comes
	# down to meet the exposure reference instead of fighting it. The difference
	# is made up with bounce, which is light that has been somewhere first.
	m.agx_white = 9.5
	m.agx_contrast = 1.45
	m.bounce_energy = 0.46
	m.bounce_color = Color(0.98, 0.80, 0.62)

	# Cool the shadows, keep the highlights warm. This is the one lever that
	# stops five levels sliding into a single orange, and it is the lever
	# `adjustment_saturation` structurally cannot pull: saturation scales what
	# is already there, it cannot put blue into a shadow that has none.
	m.grade_shadow_tint = Color(0.44, 0.54, 0.72)
	m.grade_highlight_tint = Color(0.74, 0.64, 0.46)
	m.grade_strength = 0.80
	m.glow_intensity = 0.12
	m.glow_hdr_threshold = 2.2
	m.adjustment_saturation = 1.34
	m.adjustment_contrast = 1.06
	m.dof_near_distance = 0.0
	m.dof_distance = 0.0
	return m


# ============================================================================
# DEEP LAYERS — sky, Gulf, plain, skyline, tank farm, landmarks
# ============================================================================

## Everything from z -70 outward, laid out across `x_from`..`x_to` of gameplay.
## The parallax out here is slow (one to three screen-widths across the whole
## level), so the job of this band is not motion — it is silhouette variety and
## the value ladder.
static func deep_layers(parent: Node3D, mats: Dictionary, x_from: float, x_to: float) -> void:
	_sky_band(parent, x_from, x_to)
	_gulf_and_plain(parent, mats, x_from, x_to)
	_horizon_skyline(parent, mats, x_from, x_to)
	_pylon_lines(parent, mats)
	_tank_farm(parent, mats, x_from, x_to)
	_landmarks_deep(parent, mats)


## Sky: the Saharan aerosol band, a denser bar sitting on the horizon line, and
## a high cloud deck catching light from a sun that has not cleared the horizon.
##
## Every card up here is ADDITIVE and unshaded. Additive is order-independent,
## which means a dozen overlapping soft cloud blobs can never sort wrong as the
## camera slides sideways — and sorting pops in the sky are the kind of bug
## that only shows up in a capture, after the level is finished.
static func _sky_band(parent: Node3D, x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5
	var width := span * 3.0 + 1400.0

	var haze := MaterialLab.emissive(Color(0.835, 0.804, 0.741), 0.55)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = Color(0.835, 0.804, 0.741, 0.55)
	LevelKit.prop(parent, Vector3(mid, 14.0, -420.0), Vector3(width, 34.0, 1.0),
		haze, "DustBand")

	# A second, denser bar right on the horizon line. This is the single most
	# location-specific decision in the level: on this coast the sky does not
	# go blue at the horizon, it goes bleached straw, and it is thicker than a
	# temperate sky would ever be.
	var low := MaterialLab.emissive(Color(0.870, 0.812, 0.718), 0.62)
	low.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	low.albedo_color = Color(0.870, 0.812, 0.718, 0.42)
	LevelKit.prop(parent, Vector3(mid, 0.0, -402.0), Vector3(width, 11.0, 1.0),
		low, "HorizonBand")

	# Cloud deck. Low cards are close to the sun point and run warm; high cards
	# are up in the cold zenith and run mauve. Soft-edged, so nothing up here is
	# ever a rectangle.
	var rng := RandomNumberGenerator.new()
	rng.seed = 30211
	var warm := _sky_card(Color(1.00, 0.97, 0.92), 0.26)
	var cool := _sky_card(Color(0.62, 0.78, 0.92), 0.20)
	var pale := _sky_card(Color(0.90, 0.95, 0.99), 0.18)
	var x := x_from - span * 1.2
	while x < x_to + span * 1.2:
		x += rng.randf_range(58.0, 132.0)
		var tier := rng.randi() % 3
		var y: float = [20.0, 34.0, 52.0][tier] + rng.randf_range(-5.0, 6.0)
		var z := -440.0 - float(tier) * 42.0
		var mat: Material = [warm, pale, cool][tier]
		# Each cloud is three to five overlapping soft blobs, never one card:
		# a single quad with a radial falloff on it is a smudge, and three
		# offset ones are weather.
		for _k in rng.randi_range(3, 5):
			var w := rng.randf_range(70.0, 190.0)
			_card(parent, mat,
				Vector3(x + rng.randf_range(-60.0, 60.0),
					y + rng.randf_range(-4.0, 4.0), z + rng.randf_range(-14.0, 14.0)),
				Vector2(w, w * rng.randf_range(0.14, 0.26)), "Cloud")


## The Gulf of Sidra, the sabkha plain, the foredune ridge, and the export
## jetty with a tanker alongside.
static func _gulf_and_plain(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5

	# Clear pale water over white sand, then a hard shelf line to lapis. Not a
	# gradient — the transition on this coast is a line you can see from shore.
	var sea := MaterialLab.emissive(Color(0.310, 0.765, 0.753), 0.25)
	sea.roughness = 0.12
	sea.metallic = 0.4
	LevelKit.prop(parent, Vector3(mid, -2.4, -150.0), Vector3(span * 2.4 + 700.0, 5.4, 1.0),
		sea, "Sea")
	var deep := MaterialLab.emissive(Color(0.118, 0.318, 0.455), 0.20)
	deep.roughness = 0.10
	deep.metallic = 0.5
	LevelKit.prop(parent, Vector3(mid, 0.75, -151.0), Vector3(span * 2.4 + 700.0, 1.3, 1.0),
		deep, "SeaShelf")

	LevelKit.prop(parent, Vector3(mid, -9.5, -150.0),
		Vector3(span * 2.4 + 900.0, 5.0, 220.0), mats["plain"], "SabkhaPlain")

	# The crust band. The yard floor stops at z -41 and the plain starts at
	# -40, and a 0.35 ground meeting a 0.55 ground puts a hard albedo line
	# straight across the middle distance. One intermediate step at the seam is
	# what turns that line into distance.
	LevelKit.prop(parent, Vector3(mid, YARD_Y - 1.3, -52.0),
		Vector3(span * 1.6 + 300.0, 2.4, 26.0), mats["dune"], "CrustBand")

	# Foredune ridge. Broken, not continuous: the sea has to show through it,
	# and a continuous ridge would be a second horizon line.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5507
	var x := x_from - span * 0.9
	while x < x_to + span * 0.9:
		x += rng.randf_range(38.0, 74.0)
		if absf(x - LM_JETTY) < 62.0:
			continue    # keep the jetty corridor and the ship clear
		if rng.randf() < 0.22:
			continue    # gaps, so the Gulf reads between the dunes
		_dune(parent, Vector3(x, -7.2, rng.randf_range(-138.0, -102.0)),
			rng.randf_range(26.0, 54.0), rng.randf_range(2.6, 5.4),
			mats["dune"], rng.randi())

	PropKit.pipe_rack(parent, Vector3(x_from - 160.0, -6.0, -148.0),
		Vector3(x_to + 200.0, -5.0, -152.0), 3, mats["rust"], mats["bund"], 22.0)

	_jetty(parent, mats)


## A dune has a long windward back and a short, sharp slipface, and the sharp
## edge is the whole read at this distance. Built from squashed spheres with a
## ridge box along the crest, because a smooth blob is a hill and this coast
## does not have hills.
static func _dune(parent: Node3D, at: Vector3, length: float, height: float,
		mat: Material, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 97 + 5
	var root := Node3D.new()
	root.name = "Dune"
	root.position = at
	parent.add_child(root)

	var body := MeshInstance3D.new()
	body.name = "Back"
	body.mesh = _ball(1.0, 14, 7)
	body.material_override = mat
	body.scale = Vector3(length * 0.5, height, 22.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)

	var crest := MeshInstance3D.new()
	crest.name = "Crest"
	crest.mesh = _ball(1.0, 12, 6)
	crest.material_override = mat
	crest.position = Vector3(length * rng.randf_range(0.18, 0.30), height * 0.28, 4.0)
	crest.scale = Vector3(length * 0.26, height * 0.82, 13.0)
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(crest)

	# The slipface: one hard line, tilted at the angle of repose.
	var face := LevelKit.prop(root,
		Vector3(length * 0.30, height * 0.72, 5.0),
		Vector3(length * 0.34, 0.22, 16.0), mat, "Slipface")
	face.rotation.z = deg_to_rad(-34.0)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The export jetty and the tanker alongside it. A trestle marching straight
## away from the camera is the strongest perspective cue available in a
## side-scroller — everything else out here is parallel to the screen — and it
## is also literally what Brega is: a terminal that stopped exporting.
static func _jetty(parent: Node3D, mats: Dictionary) -> void:
	var far_mid: Material = mats["far_mid"]
	var steel: Material = mats["steel"]
	var root := Node3D.new()
	root.name = "ExportJetty"
	parent.add_child(root)

	var z0 := -46.0
	var z1 := -148.0
	var deck_y := 0.6
	LevelKit.prop(root, Vector3(LM_JETTY, deck_y, (z0 + z1) * 0.5),
		Vector3(3.4, 0.5, z0 - z1), far_mid, "JettyDeck")
	LevelKit.prop(root, Vector3(LM_JETTY, deck_y + 0.55, (z0 + z1) * 0.5),
		Vector3(3.9, 0.14, z0 - z1), steel, "JettyKerb")
	# Two product lines running out to the loading arms.
	for i in 2:
		var pipe := MeshInstance3D.new()
		pipe.name = "JettyLine%d" % i
		pipe.mesh = _cyl(0.34, z0 - z1, 10)
		pipe.material_override = mats["rust"]
		pipe.position = Vector3(LM_JETTY - 0.8 + i * 1.6, deck_y + 0.95,
			(z0 + z1) * 0.5)
		pipe.rotation.x = PI * 0.5
		root.add_child(pipe)

	var bents := 13
	for i in bents:
		var t := float(i) / float(bents - 1)
		var z := lerpf(z0, z1, t)
		for s: float in [-1.0, 1.0]:
			LevelKit.prop(root, Vector3(LM_JETTY + s * 1.5, deck_y - 2.4, z),
				Vector3(0.42, 5.0, 0.42), far_mid, "Pile")
		LevelKit.prop(root, Vector3(LM_JETTY, deck_y - 0.55, z),
			Vector3(3.6, 0.3, 0.42), far_mid, "PileCap")
		if i % 3 == 0:
			LevelKit.prop(root, Vector3(LM_JETTY, deck_y + 1.9, z),
				Vector3(0.16, 2.4, 0.16), steel, "JettyPost")

	# Loading arms at the head: the one place on the jetty with a vertical.
	for i in 3:
		var az := z1 + 6.0 + i * 5.0
		LevelKit.prop(root, Vector3(LM_JETTY + 1.3, deck_y + 3.0, az),
			Vector3(0.32, 5.4, 0.32), steel, "LoadingArm")
		var jib := LevelKit.prop(root, Vector3(LM_JETTY + 3.0, deck_y + 5.2, az),
			Vector3(4.0, 0.26, 0.26), steel, "ArmJib")
		jib.rotation.z = deg_to_rad(-22.0)

	# In FRONT of the sea card, not behind it: the Gulf is an opaque strip at
	# z -150 and anything beyond it loses its hull. Sat so the boot-topping
	# lands on the strip's top edge, which is the waterline from here.
	_ship(root, mats, Vector3(LM_JETTY + 46.0, 1.4, -146.0))


## A product tanker lying alongside, dead in the water with her deck lights
## still on. At 170 units she is 40 pixels tall — so she reads by her stepped
## profile and by four warm dots, and by nothing else.
static func _ship(parent: Node3D, mats: Dictionary, at: Vector3) -> void:
	var hull_mat: Material = mats["far_mid"]
	var root := Node3D.new()
	root.name = "Tanker"
	root.position = at
	# Six and a half to one. Built square and then squashed, because a ship
	# modelled at the proportions that feel right in the editor always comes
	# out as a barge.
	root.scale = Vector3(1.3, 0.8, 1.0)
	parent.add_child(root)

	LevelKit.prop(root, Vector3(0, 0, 0), Vector3(58.0, 3.6, 8.0), hull_mat, "Hull")
	# The boot-topping: the dark band at the waterline that stops a ship
	# reading as a floating brick.
	LevelKit.prop(root, Vector3(0, -1.5, 0.2), Vector3(58.2, 1.1, 8.2),
		mats["tank"], "BootTopping")
	# Bow: a wedge stepping forward and up.
	LevelKit.prop(root, Vector3(30.5, 0.6, 0), Vector3(5.6, 4.6, 6.0), hull_mat, "Bow")
	# Accommodation block aft, stepped, with the funnel behind it.
	LevelKit.prop(root, Vector3(-21.0, 3.6, 0), Vector3(9.0, 4.0, 7.0), hull_mat, "House")
	LevelKit.prop(root, Vector3(-21.0, 6.4, 0), Vector3(6.4, 2.0, 6.2), hull_mat, "Bridge")
	LevelKit.prop(root, Vector3(-25.5, 7.4, 0), Vector3(2.8, 4.2, 3.4),
		mats["tank"], "Funnel")
	LevelKit.prop(root, Vector3(-21.0, 10.2, 0), Vector3(0.22, 5.0, 0.22),
		mats["steel"], "Mast")
	# Manifold king posts along the deck: the rhythm that says tanker.
	for i in 5:
		LevelKit.prop(root, Vector3(-8.0 + i * 8.0, 3.4, 0.0),
			Vector3(0.5, 3.2, 0.5), hull_mat, "KingPost%d" % i)
	# Deck lights. Emissive only — at this range an omni contributes nothing
	# but cost, and the dots are the whole point.
	var lamp: Material = mats["sodium"]
	for i in 4:
		LevelKit.prop(root, Vector3(-19.0 + i * 11.0, 4.2, 4.1),
			Vector3(0.7, 0.5, 0.2), lamp, "DeckLight%d" % i)
	LevelKit.prop(root, Vector3(-21.0, 12.7, 0.0), Vector3(0.45, 0.45, 0.45),
		lamp, "MastHead")


## The horizon plant, z -240 .. -340. Seven structure types on an irregular
## pitch, so the skyline never repeats inside a screen and never phases with
## the camera. Plus, once, the town: a low block silhouette and one minaret.
static func _horizon_skyline(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91733
	var deep: Material = mats["far_deep"]
	var mid: Material = mats["far_mid"]
	var x := x_from - 260.0
	var beat := 0
	while x < x_to + 300.0:
		var z := rng.randf_range(-336.0, -248.0)
		# Two value steps inside the skyline itself, so even the horizon has
		# depth in it rather than being one cut-out.
		var mat: Material = deep if z < -292.0 else mid
		match beat % 7:
			0:
				PropKit.prilling_tower(parent, Vector3(x, -10.0, z), 7.0, 62.0, mat)
				PropKit.prilling_tower(parent, Vector3(x + 34.0, -10.0, z - 6.0),
					7.6, 71.0, mat)
				x += 96.0
			1:
				_chimney(parent, mats, Vector3(x, -10.0, z), 3.0, 54.0, mat)
				x += 52.0
			2:
				_cooling_tower(parent, Vector3(x, -10.0, z), 13.0, 34.0, mat)
				x += 78.0
			3:
				_gantry_crane(parent, mats, Vector3(x, -10.0, z), 22.0, 30.0, mat)
				x += 80.0
			4:
				PropKit.flare_stack(parent, Vector3(x, -10.0, z), 52.0, 6.4,
					mats["far_steel"])
				x += 58.0
			5:
				_sphere_farm(parent, Vector3(x, -10.0, z), 5.0, 3, mat)
				x += 66.0
			_:
				# A long process block. The skyline needs horizontals or it
				# turns into a row of sticks.
				LevelKit.prop(parent, Vector3(x, 0.0, z), Vector3(46.0, 20.0, 18.0),
					mat, "ProcessHall")
				for i in 4:
					LevelKit.prop(parent, Vector3(x - 16.0 + i * 11.0, 16.0, z),
						Vector3(2.2, 12.0, 2.2), mat, "HallStack%d" % i)
				LevelKit.prop(parent, Vector3(x, 11.0, z + 9.0),
					Vector3(46.0, 1.4, 1.4), mats["steel"], "HallBeam")
				x += 74.0
		beat += 1

	_town(parent, mats)


## Brega town on the horizon: a low, dense block silhouette with one minaret
## standing out of it, lit before fajr. The plant is taller than the mosque and
## that hierarchy is the whole location — a fertiliser complex is the skyline
## here. The minaret is scenery and nothing else: nothing stands on it.
static func _town(parent: Node3D, mats: Dictionary) -> void:
	var mat: Material = mats["far_deep"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021
	for i in 26:
		var x := LM_MINARET - 90.0 + i * 7.4 + rng.randf_range(-2.0, 2.0)
		var h := rng.randf_range(5.0, 11.0)
		LevelKit.prop(parent, Vector3(x, -10.0 + h * 0.5, -318.0 - rng.randf_range(0.0, 16.0)),
			Vector3(rng.randf_range(6.0, 11.0), h, 8.0), mat, "TownBlock%d" % i)

	var base := Vector3(LM_MINARET, -10.0, -316.0)
	LevelKit.prop(parent, base + Vector3(0.0, 13.0, 0.0), Vector3(4.2, 26.0, 4.2),
		mat, "MinaretShaft")
	LevelKit.prop(parent, base + Vector3(0.0, 26.4, 0.0), Vector3(5.6, 0.8, 5.6),
		mat, "MinaretGallery")
	LevelKit.prop(parent, base + Vector3(0.0, 29.0, 0.0), Vector3(3.4, 4.6, 3.4),
		mat, "MinaretLantern")
	var cap := MeshInstance3D.new()
	cap.name = "MinaretCap"
	cap.mesh = _cyl(2.2, 3.4, 12, 0.05)
	cap.material_override = mat
	cap.position = base + Vector3(0.0, 33.0, 0.0)
	parent.add_child(cap)
	# The gallery lamps. Warm, small, and the only lit thing on the far horizon.
	LevelKit.prop(parent, base + Vector3(0.0, 27.4, 1.9), Vector3(3.6, 0.5, 0.3),
		mats["sodium"], "MinaretLamps")
	LevelKit.prop(parent, base + Vector3(0.0, 30.4, 1.6), Vector3(2.2, 2.6, 0.3),
		mats["sodium"], "MinaretLanternGlow")


## Transmission lines walking away from the camera into the plain. Same job as
## the jetty: the only two things in this level that recede, and therefore the
## only two that can state how far away the horizon is.
static func _pylon_lines(parent: Node3D, mats: Dictionary) -> void:
	# Both start in a gap in the tank farm's 52-unit pitch and march apart, so
	# they never cross each other and never spear a tank.
	_pylon_line(parent, mats, 88.0, -92.0, 22.0, -34.0, 6)
	_pylon_line(parent, mats, 300.0, -84.0, -18.0, -30.0, 5)


static func _pylon_line(parent: Node3D, mats: Dictionary, x0: float, z0: float,
		dx: float, dz: float, steps: int) -> void:
	var root := Node3D.new()
	root.name = "PylonLine"
	parent.add_child(root)
	var tops: Array[Vector3] = []
	for i in steps:
		var p := Vector3(x0 + dx * i, -7.2, z0 + dz * i)
		# One step darker than the band they stand in: a lattice painted the
		# same value as the haze behind it disappears completely.
		var mat: Material = mats["far_mid"] if p.z < -190.0 else mats["tank"]
		tops.append(_pylon(root, p, 15.0, mat))
	for i in tops.size() - 1:
		for lane in 3:
			var off := Vector3(-2.6 + lane * 2.6, 0.0, 0.0)
			PropKit.cable(root, tops[i] + off, tops[i + 1] + off,
				2.2 + lane * 0.3, mats["dark"], 8, 0.09)


static func _pylon(parent: Node3D, base: Vector3, height: float, mat: Material) -> Vector3:
	var root := Node3D.new()
	root.name = "Pylon"
	root.position = base
	parent.add_child(root)
	# Legs lean in; two waist bands hold them. Four boxes and three bands is
	# enough lattice at this distance, and more would just alias.
	for s: float in [-1.0, 1.0]:
		var leg := LevelKit.prop(root, Vector3(s * 1.5, height * 0.34, 0.0),
			Vector3(0.28, height * 0.72, 0.28), mat, "Leg")
		leg.rotation.z = s * deg_to_rad(6.0)
	for i in 3:
		var y := height * (0.12 + 0.22 * i)
		var w := 3.6 - i * 0.9
		LevelKit.prop(root, Vector3(0.0, y, 0.0), Vector3(w, 0.16, 0.16), mat, "Band%d" % i)
		var br := LevelKit.prop(root, Vector3(0.0, y + height * 0.11, 0.0),
			Vector3(w * 1.2, 0.10, 0.10), mat, "Brace%d" % i)
		br.rotation.z = 0.5 if i % 2 == 0 else -0.5
	LevelKit.prop(root, Vector3(0.0, height * 0.78, 0.0), Vector3(0.9, height * 0.4, 0.9),
		mat, "Mast")
	for i in 2:
		var ay := height * (0.80 + 0.14 * i)
		LevelKit.prop(root, Vector3(0.0, ay, 0.0), Vector3(7.4 - i * 2.2, 0.20, 0.20),
			mat, "Crossarm%d" % i)
		for s2: float in [-1.0, 1.0]:
			LevelKit.prop(root, Vector3(s2 * (3.5 - i * 1.1), ay - 0.55, 0.0),
				Vector3(0.14, 1.0, 0.14), mat, "Insulator")
	return base + Vector3(0.0, height * 0.94, 0.0)


## The tank farm, z -70 .. -100. Spread on an irregular pitch and in two rows,
## with the jetty corridor kept clear so the trestle has somewhere to go.
static func _tank_farm(parent: Node3D, mats: Dictionary, x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var rng := RandomNumberGenerator.new()
	rng.seed = 2213
	var tanks := maxi(3, int(span / 52.0))
	for i in tanks:
		var tx := x_from - 30.0 + i * 52.0 + rng.randf_range(-7.0, 7.0)
		if absf(tx - LM_JETTY) < 30.0:
			continue
		var burnt := i % 5 == 1
		var r := rng.randf_range(13.0, 17.0)
		var h := rng.randf_range(16.0, 23.0)
		var t := PropKit.storage_tank(parent,
			Vector3(tx, -8.0, -74.0 - float(i % 3) * 12.0), r, h,
			mats["tank"], mats["bund"], mats["rust"], burnt, mats["tank_burnt"])
		if i % 3 == 0:
			PropKit.tank_stair(parent, t.position, r, h, mats["rust"])
		for k in 7:
			var a := PI * (0.10 + 0.13 * k)
			LevelKit.prop(t, Vector3(cos(a) * (r + 0.05), h * 0.34, sin(a) * (r + 0.05)),
				Vector3(0.55, h * 0.66, 0.55), mats["rust"], "Bleed%d" % k)
		# A pump house against every third bund — scale reference, and the
		# thing that stops a tank reading as a cylinder standing in nothing.
		if i % 3 == 1:
			LevelKit.prop(parent, Vector3(tx + r + 5.0, -5.4, -62.0),
				Vector3(7.0, 4.4, 6.0), mats["plant"], "PumpHouse")
			LevelKit.prop(parent, Vector3(tx + r + 5.0, -3.0, -62.0),
				Vector3(7.6, 0.5, 6.6), mats["bund"], "PumpHouseCap")


## The four deep landmarks. Each exists once in the level.
static func _landmarks_deep(parent: Node3D, mats: Dictionary) -> void:
	_cooling_tower(parent, Vector3(LM_COOLING_TOWER, -7.6, -112.0), 14.0, 36.0,
		mats["far_mid"])
	_gantry_crane(parent, mats, Vector3(LM_GANTRY_CRANE, -7.2, -58.0), 20.0, 26.0,
		mats["tank"])
	_sphere_farm(parent, Vector3(LM_SPHERES, -7.2, -96.0), 6.0, 3, mats["tank"])
	_live_flare(parent, mats, Vector3(LM_LIVE_FLARE, -7.2, -64.0))


## Natural-draft cooling tower: two truncated cones meeting at a waist, on a
## colonnade. The hyperbolic profile is one of the few silhouettes an audience
## reads instantly at any distance, which is exactly what a landmark needs.
static func _cooling_tower(parent: Node3D, base: Vector3, radius: float,
		height: float, mat: Material) -> void:
	var root := Node3D.new()
	root.name = "CoolingTower"
	root.position = base
	parent.add_child(root)
	var waist := radius * 0.56
	var lower := MeshInstance3D.new()
	lower.name = "Lower"
	lower.mesh = _cyl(radius, height * 0.70, 22, waist)
	lower.material_override = mat
	lower.position = Vector3(0, height * 0.35, 0)
	root.add_child(lower)
	var upper := MeshInstance3D.new()
	upper.name = "Upper"
	upper.mesh = _cyl(waist, height * 0.30, 22, radius * 0.72)
	upper.material_override = mat
	upper.position = Vector3(0, height * 0.85, 0)
	root.add_child(upper)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = _cyl(radius * 0.76, height * 0.02, 22)
	rim.material_override = mat
	rim.position = Vector3(0, height, 0)
	root.add_child(rim)
	# The air inlet: legs round the bottom, and the dark gap between them is
	# what makes the whole thing read as a shell and not a solid.
	for i in 9:
		var a := PI * (0.06 + 0.11 * i)
		var leg := LevelKit.prop(root,
			Vector3(cos(a) * radius * 0.95, height * 0.045, sin(a) * radius * 0.95),
			Vector3(0.8, height * 0.09, 0.8), mat, "Inlet%d" % i)
		leg.rotation.z = (0.16 if cos(a) > 0.0 else -0.16)


## Portal crane on rails. Reads as one tall vertical, one long horizontal and a
## hook hanging in the middle of the frame — the most legible man-made shape
## there is, and it hangs something that moves.
static func _gantry_crane(parent: Node3D, mats: Dictionary, base: Vector3,
		height: float, boom: float, mat: Material) -> void:
	var steel: Material = mats["steel"]
	var root := Node3D.new()
	root.name = "GantryCrane"
	root.position = base
	parent.add_child(root)

	# A-frame legs: one pair vertical, one pair raked.
	for s: float in [-1.0, 1.0]:
		LevelKit.prop(root, Vector3(s * 3.4, height * 0.5, -1.6),
			Vector3(0.9, height, 0.9), mat, "Leg")
		var rake := LevelKit.prop(root, Vector3(s * 4.6, height * 0.5, 1.6),
			Vector3(0.7, height * 1.02, 0.7), mat, "RakedLeg")
		rake.rotation.z = -s * deg_to_rad(7.0)
		LevelKit.prop(root, Vector3(s * 3.4, 0.5, 0.0), Vector3(2.6, 1.0, 5.4),
			mat, "Bogie")
	for i in 3:
		LevelKit.prop(root, Vector3(0.0, height * (0.28 + 0.24 * i), 0.0),
			Vector3(9.0, 0.34, 0.34), mat, "LegTie%d" % i)

	# The girder, cantilevered further one way than the other.
	LevelKit.prop(root, Vector3(boom * 0.18, height + 1.1, 0.0),
		Vector3(boom, 2.0, 2.4), mat, "Girder")
	LevelKit.prop(root, Vector3(boom * 0.18, height + 2.4, 0.0),
		Vector3(boom, 0.30, 2.8), steel, "GirderWalk")
	# Stay cables from the apex out to both ends: the diagonals are what make
	# a crane read as engineered rather than as a T.
	var apex := Vector3(0.0, height + 6.6, 0.0)
	LevelKit.prop(root, Vector3(0.0, height + 3.8, 0.0), Vector3(1.2, 5.6, 1.2),
		mat, "Apex")
	for s2: float in [-1.0, 1.0]:
		var end := Vector3(boom * (0.18 + s2 * 0.5), height + 2.1, 0.0)
		var d := end - apex
		var stay := LevelKit.prop(root, (apex + end) * 0.5,
			Vector3(d.length(), 0.18, 0.18), steel, "Stay")
		stay.rotation.z = atan2(d.y, d.x)

	# Trolley and hook, hanging and swinging. It is the only moving thing in
	# this half of the frame and it is 26 units up, so it has to be big.
	var trolley := LevelKit.prop(root, Vector3(boom * 0.34, height + 0.2, 0.0),
		Vector3(3.0, 1.6, 2.2), steel, "Trolley")
	var sway := Sway.new()
	sway.name = "HookSway"
	sway.position = trolley.position + Vector3(0.0, -0.8, 0.0)
	sway.axis = Vector3(0.0, 0.0, 1.0)
	sway.amplitude = 0.06
	sway.speed = 0.55
	sway.gust_amplitude = 0.025
	sway.gust_speed = 1.3
	root.add_child(sway)
	LevelKit.prop(sway, Vector3(0.0, -4.6, 0.0), Vector3(0.14, 9.2, 0.14),
		steel, "HoistRope")
	LevelKit.prop(sway, Vector3(0.0, -9.6, 0.0), Vector3(1.8, 1.4, 1.2),
		mats["rust"], "Hook")


## A row of gas-holder spheres on legs. Nothing else in an industrial skyline
## is round, so three of them at one x is unmistakable from anywhere.
static func _sphere_farm(parent: Node3D, base: Vector3, radius: float,
		count: int, mat: Material) -> void:
	var root := Node3D.new()
	root.name = "SphereFarm"
	root.position = base
	parent.add_child(root)
	for i in count:
		var cx := (float(i) - (count - 1) * 0.5) * radius * 2.9
		var cz := float(i % 2) * -5.0
		var ball := MeshInstance3D.new()
		ball.name = "Sphere%d" % i
		ball.mesh = _ball(radius, 18, 10)
		ball.material_override = mat
		ball.position = Vector3(cx, radius + 6.0, cz)
		root.add_child(ball)
		LevelKit.prop(root, Vector3(cx, radius + 6.0, cz),
			Vector3(radius * 2.06, 0.22, radius * 0.4), mat, "Equator%d" % i)
		for k in 6:
			var a := TAU * float(k) / 6.0
			var leg := LevelKit.prop(root,
				Vector3(cx + cos(a) * radius * 0.72, 3.2, cz + sin(a) * radius * 0.72),
				Vector3(0.44, 6.6, 0.44), mat, "SphereLeg")
			leg.rotation.z = cos(a) * 0.07
		# Ladder up one flank, so the eye has something to measure it against.
		LevelKit.prop(root, Vector3(cx + radius * 0.98, radius + 4.0, cz + 0.4),
			Vector3(0.3, radius * 1.6, 0.3), mat, "SphereLadder%d" % i)


## The one thing burning in a plant that stopped running. It is the level's
## only large warm accent outside the sun itself, it throws light into the
## volumetrics, and its plume is the biggest slow-moving shape in the frame.
static func _live_flare(parent: Node3D, mats: Dictionary, base: Vector3) -> void:
	PropKit.flare_stack(parent, base, 30.0, 5.2, mats["steel"])
	var tip := base + Vector3(0.0, 30.4, 0.0)

	var flame := MeshInstance3D.new()
	flame.name = "FlareFlame"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 1.05
	cone.height = 4.6
	cone.radial_segments = 12
	flame.mesh = cone
	# Additive above about 1.5 energy tonemaps to white and stops being fire.
	# Keep the energy low and let the colour carry it.
	var fire := MaterialLab.emissive(Color(1.0, 0.36, 0.07), 1.1)
	fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.albedo_color = Color(1.0, 0.42, 0.10, 0.72)
	flame.material_override = fire
	flame.position = tip + Vector3(0.7, 2.3, 0.0)
	flame.rotation_degrees = Vector3(0.0, 0.0, -16.0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flame)

	var glow := OmniLight3D.new()
	glow.name = "FlareGlow"
	glow.light_color = Color(1.0, 0.60, 0.22)
	glow.light_energy = 22.0
	glow.omni_range = 40.0
	glow.light_volumetric_fog_energy = 4.0
	glow.shadow_enabled = false
	glow.position = tip + Vector3(0.0, 2.6, 0.0)
	parent.add_child(glow)

	var p := GPUParticles3D.new()
	p.name = "FlarePlume"
	p.position = tip + Vector3(1.4, 4.0, 0.0)
	p.amount = 150
	p.lifetime = 28.0
	p.preprocess = 26.0
	p.fixed_fps = 24
	p.interpolate = true
	p.local_coords = false
	# The 8-unit default AABB makes particles vanish mid-effect the moment the
	# camera scrolls. This one has to cover the whole downwind drift.
	p.visibility_aabb = AABB(Vector3(-24, -8, -30), Vector3(170, 100, 60))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.3
	pm.direction = Vector3(1.0, 0.34, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.4
	pm.initial_velocity_max = 3.8
	pm.gravity = Vector3(0.8, 0.02, 0.0)
	pm.scale_min = 5.0
	pm.scale_max = 13.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 0.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.30, 0.20, 0.16, 0.58))
	ramp.set_color(1, Color(0.34, 0.29, 0.28, 0.0))
	ramp.add_point(0.16, Color(0.38, 0.26, 0.19, 0.52))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1, 1, 1, 1)
	sm.albedo_texture = _soft_tex()
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.disable_receive_shadows = true
	quad.material = sm
	p.draw_pass_1 = quad
	parent.add_child(p)


# ============================================================================
# MID LAYERS — the yard, the wall, the plant band, the foreground
# ============================================================================

## Everything from the second block at z -40 forward to the junk at z +9: the
## band the gameplay plane actually sits in front of, and the band where the
## parallax is fast enough for the player to feel their own speed.
static func mid_layers(parent: Node3D, mats: Dictionary, x_from: float, x_to: float) -> void:
	_second_block(parent, mats, x_from, x_to)
	plant_band(parent, mats, x_from, x_to)
	_yard_floor(parent, mats, x_from, x_to)
	_bunds_and_kerbs(parent, mats, x_from, x_to)
	_rail_spur(parent, mats, x_from, x_to)
	_perimeter(parent, mats, x_from, x_to)
	_yard_furniture(parent, mats, x_from, x_to)
	_pole_line(parent, mats, x_from, x_to)
	_pipe_bridge(parent, mats, 68.0, YARD_Y + 12.6)
	_pipe_bridge(parent, mats, 248.0, YARD_Y + 15.2)
	_windbreak(parent, mats, x_from, x_to)
	_wind_and_life(parent, mats, x_from, x_to)
	foreground_band(parent, mats, x_from, x_to)


## The block opposite, z -33 .. -44. Built as four segments at different depths
## and heights rather than one 450-unit wall: a single continuous facade back
## there is a grey bar across every frame in the level and it hides the plant
## behind it. The gaps are where the plant band shows through, and they are
## placed at the landmarks so the landmark has a hole to be seen in.
static func _second_block(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	# Authored, not derived. This wall is what decides where the player can see
	# the Gulf, the plain and the base of each landmark, so the windows between
	# the segments are composition and get placed by hand:
	#
	#   48 .. 72    the yard opens onto the tank farm and the dunes
	#  134 .. 158   the live flare, base and all
	#  218 .. 236   a glimpse through, behind the property cage
	#  288 .. on    the plant ends and the level opens onto the sea and the
	#               jetty for the whole run to the gate
	#
	# left, width, z, height
	var plan := [
		[-26.0, 74.0, -34.0, 9.0],
		[72.0, 62.0, -41.0, 7.6],
		[158.0, 60.0, -34.0, 10.4],
		[236.0, 52.0, -44.0, 8.2],
	]
	for i in plan.size():
		var left: float = plan[i][0]
		var w: float = plan[i][1]
		var z: float = plan[i][2]
		var h: float = plan[i][3]
		if left > x_to + 40.0 or left + w < x_from - 60.0:
			continue
		var block := PropKit.prefab_facade(parent, left, YARD_Y, w, h, z,
			mats["slab"], {
				"name": "BlockTwo%d" % i, "joint_mat": mats["wall"],
				"dark_mat": mats["wall"], "hole_mat": mats["wall"],
				"depth": 6.0, "open_holes": 1, "seed": 300 + i * 17,
			})
		# A roofline with things on it is the difference between a building and
		# a box, and at this distance it is all silhouette against bright sky.
		PropKit.roof_clutter(block, left + 2.0, YARD_Y + h, w - 4.0, z - 1.0,
			mats["wall"], 41 + i * 9)
		PropKit.stair_head(block, Vector3(left + w * 0.7, YARD_Y + h, z - 1.0),
			mats["wall"], mats["door"], mats["joint"])
		# End walls catch the key edge-on: they are what make the segment read
		# as a solid with a far side rather than as a painted flat.
		for s: float in [0.0, 1.0]:
			LevelKit.prop(parent, Vector3(left + w * s, YARD_Y + h * 0.5, z + 2.6),
				Vector3(0.6, h, 6.2), mats["joint"], "BlockTwoEnd")
		# Two lights still on per segment. The whole face is in shade; these
		# are the only warm accents this band gets.
		for k in 2:
			PropKit.lit_window(block,
				Vector3(left + w * (0.26 + 0.42 * k), YARD_Y + h * 0.62, z + 3.1),
				Vector2(0.9, 1.25), mats["joint"], Color(1.0, 0.66, 0.30), 1.4)


## Yard floor, tyre ruts and the junk lying on it.
static func _yard_floor(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var mid := (x_from + x_to) * 0.5

	LevelKit.prop(parent, Vector3(mid, YARD_Y - 1.2, -16.0),
		Vector3(span + 120.0, 2.4, 50.0), mats["sabkha"], "YardFloor")
	for i in int(span / 26.0) + 1:
		LevelKit.prop(parent, Vector3(x_from + i * 26.0, YARD_Y + 0.02,
			-18.0 + float(i % 3) * 2.4), Vector3(15.0, 0.06, 1.3),
			mats["mud"], "TyreRut%d" % i)

	# Debris on the yard floor. Without it the lower third of every frame is an
	# empty band of haze.
	for i in int(span / 11.0) + 1:
		var x := x_from + i * 11.0 + fmod(float(i) * 4.3, 6.0)
		var z := -12.0 - fmod(float(i) * 5.1, 12.0)
		match i % 5:
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
			3:
				var p := LevelKit.prop(parent, Vector3(x, YARD_Y + 0.9, z),
					Vector3(0.24, 1.8, 0.24), mats["steel"], "YardPost")
				p.rotation.z = fmod(float(i) * 0.31, 0.5) - 0.25
			_:
				# A cable drum on its side. Round, so it breaks a yard made
				# entirely of boxes.
				var drum := MeshInstance3D.new()
				drum.name = "CableDrum"
				drum.mesh = _cyl(1.05, 1.3, 12)
				drum.material_override = mats["crate"]
				drum.position = Vector3(x, YARD_Y + 1.05, z)
				drum.rotation.z = PI * 0.5
				parent.add_child(drum)
				LevelKit.prop(parent, Vector3(x, YARD_Y + 1.05, z),
					Vector3(1.15, 1.45, 1.45), mats["dark"], "DrumCore")


## Bund walls and spill kerbs. Every one of the kerbs runs in Z rather than in
## X: a line that converges toward the vanishing point is the only depth cue
## available on dead-flat ground, and this level is built on a salt pan.
static func _bunds_and_kerbs(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var bund: Material = mats["bund"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1187

	for i in int(span / 74.0) + 1:
		var x := x_from + 18.0 + i * 74.0
		var w := rng.randf_range(16.0, 26.0)
		var z_far := -26.0 - rng.randf_range(0.0, 4.0)
		var z_near := -9.0
		# Three sides of a rectangle, open to camera: a closed one would just
		# be a box, and the open side lets the stained floor inside read.
		LevelKit.prop(parent, Vector3(x + w * 0.5, YARD_Y + 0.45, z_far),
			Vector3(w, 0.9, 0.5), bund, "BundBack")
		for s: float in [0.0, 1.0]:
			LevelKit.prop(parent, Vector3(x + w * s, YARD_Y + 0.45,
				(z_far + z_near) * 0.5), Vector3(0.5, 0.9, z_near - z_far),
				bund, "BundSide")
		LevelKit.prop(parent, Vector3(x + w * 0.5, YARD_Y + 0.05,
			(z_far + z_near) * 0.5), Vector3(w - 1.0, 0.1, z_near - z_far - 1.0),
			mats["mud"], "BundFloor")
		for k in 3:
			LevelKit.prop(parent,
				Vector3(x + 2.0 + k * 2.2, YARD_Y + 0.5, z_far + 2.4),
				Vector3(0.68, 0.9, 0.68), mats["rust"], "BundDrum%d" % k)

	for i in int(span / 46.0) + 1:
		var kx := x_from + 34.0 + i * 46.0 + rng.randf_range(-6.0, 6.0)
		var far := -8.0 - rng.randf_range(10.0, 20.0)
		var near := -6.0
		LevelKit.prop(parent, Vector3(kx, YARD_Y + 0.14, (far + near) * 0.5),
			Vector3(0.44, 0.28, near - far), bund, "SpillKerb%d" % i)


## The rail spur. A dead-straight horizontal running the length of the level at
## z -11.5: it is the one continuous line in the mid band, it states the ground
## plane, and the two derelict wagons on it are landmarks you can see coming.
static func _rail_spur(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from + 120.0
	var left := x_from - 60.0
	var z := -11.5
	var y := YARD_Y

	LevelKit.prop(parent, Vector3(left + span * 0.5, y + 0.16, z),
		Vector3(span, 0.32, 3.4), mats["ballast"], "Ballast")

	# Sleepers as one instanced mesh per chunk. Six hundred of them is nothing
	# on the GPU and six hundred nodes is not free on the CPU.
	var sleepers: Array[Transform3D] = []
	var n := int(span / 0.78)
	for i in n:
		sleepers.append(Transform3D(Basis.IDENTITY,
			Vector3(left + i * 0.78, y + 0.36, z)))
	_scatter(parent, "Sleepers", LevelKit.chamfer_mesh(Vector3(0.24, 0.16, 2.6)),
		mats["trunk"], sleepers, 96.0)

	for s: float in [-0.72, 0.72]:
		LevelKit.prop(parent, Vector3(left + span * 0.5, y + 0.50, z + s),
			Vector3(span, 0.14, 0.11), mats["rebar"], "Rail")

	# Buffer stop: the spur has to end somewhere, and an end is a landmark.
	var bx := x_to + 24.0
	LevelKit.prop(parent, Vector3(bx, y + 0.9, z), Vector3(1.0, 1.4, 3.2),
		mats["rust"], "BufferStop")
	for s2: float in [-0.72, 0.72]:
		var br := LevelKit.prop(parent, Vector3(bx - 2.0, y + 0.8, z + s2),
			Vector3(4.2, 0.16, 0.16), mats["rust"], "BufferBrace")
		br.rotation.z = deg_to_rad(18.0)

	_wagon(parent, mats, Vector3(88.0, y, z), true)
	_wagon(parent, mats, Vector3(246.0, y, z), false)


## A wagon left on the spur. `tank` picks the rail tanker; the other is a flat
## with a stake side. Both are chest-high horizontals that cut the yard band.
static func _wagon(parent: Node3D, mats: Dictionary, at: Vector3, tank: bool) -> void:
	var root := Node3D.new()
	root.name = "RailWagon"
	root.position = at
	parent.add_child(root)
	LevelKit.prop(root, Vector3(0, 0.95, 0), Vector3(11.0, 0.55, 2.7),
		mats["rust"], "Underframe")
	for s: float in [-1.0, 1.0]:
		LevelKit.prop(root, Vector3(s * 3.6, 0.55, 0), Vector3(2.4, 0.7, 2.4),
			mats["dark"], "Bogie")
		LevelKit.prop(root, Vector3(s * 5.6, 1.05, 0), Vector3(0.5, 0.5, 2.9),
			mats["rust"], "Headstock")
	if tank:
		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel"
		barrel.mesh = _cyl(1.35, 9.2, 16)
		barrel.material_override = mats["tank"]
		barrel.position = Vector3(0, 2.6, 0)
		barrel.rotation.z = PI * 0.5
		root.add_child(barrel)
		LevelKit.prop(root, Vector3(0, 4.1, 0), Vector3(1.1, 0.7, 1.1),
			mats["rust"], "Dome")
		var ladder := LevelKit.prop(root, Vector3(3.0, 2.6, 1.4),
			Vector3(0.1, 2.6, 0.5), mats["rust"], "WagonLadder")
		ladder.rotation.z = 0.1
	else:
		LevelKit.prop(root, Vector3(0, 1.35, 0), Vector3(10.4, 0.25, 2.5),
			mats["trunk"], "FlatDeck")
		for i in 6:
			LevelKit.prop(root, Vector3(-4.4 + i * 1.8, 2.0, -1.15),
				Vector3(0.16, 1.4, 0.16), mats["rust"], "Stake%d" % i)
		for i in 3:
			LevelKit.prop(root, Vector3(-2.2 + i * 2.4, 1.95, 0.2),
				Vector3(1.9, 1.0, 1.7), mats["crate"], "WagonLoad%d" % i)


## The perimeter wall, in three runs at slightly different heights with two
## breaches between them. A 450-unit unbroken wall at one height puts a dead
## horizontal across the middle of every frame in the level; breaking it is
## worth more than any amount of detail on it.
static func _perimeter(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var z := -16.0
	var breaches := [148.0, 290.0]
	var edges := [x_from - 45.0, 148.0, 290.0, x_to + 45.0]
	var heights := [4.5, 4.2, 4.8]
	for i in 3:
		var left: float = edges[i] + (0.0 if i == 0 else 9.0)
		var right: float = edges[i + 1]
		var h: float = heights[i]
		PropKit.perimeter_wall(parent, left, YARD_Y, right - left, h, z,
			mats["wall"], mats["joint"])
		PropKit.razor_coil(parent, Vector3(left, YARD_Y + h + 0.2, z),
			Vector3(right, YARD_Y + h + 0.2, z), 0.20,
			mats["rust"], int((right - left) / 3.0) + 4)

	_breach(parent, mats, breaches[0], z, 4.5)
	_vehicle_gate(parent, mats, breaches[1], z, 4.8)

	# Warning boards along the wall, sparse and Arabic-only.
	var white := MaterialLab.plaster(Color(0.58, 0.55, 0.50), 1.0)
	for i in int((x_to - x_from) / 120.0) + 1:
		var sx := x_from + 52.0 + i * 120.0
		LevelKit.prop(parent, Vector3(sx, YARD_Y + 2.9, z + 0.40),
			Vector3(4.0, 1.0, 0.08), mats["bund"], "SignBoard%d" % i)
		PropKit.sign(parent, "ممنوع الاقتراب", Vector3(sx, YARD_Y + 2.72, z + 0.46),
			0.46, white, PropKit.FONT_NASKH)


## A collapsed section: two panels down on their faces, rebar combed out of the
## break, and sand drifted through the gap. What matters is that you can see
## the plant band through it — a hole in a wall is only worth building if there
## is something behind the wall.
static func _breach(parent: Node3D, mats: Dictionary, x: float, z: float,
		h: float) -> void:
	var root := Node3D.new()
	root.name = "WallBreach"
	parent.add_child(root)

	var a := LevelKit.prop(root, Vector3(x + 1.4, YARD_Y + 1.5, z + 1.1),
		Vector3(3.4, h * 0.8, 0.6), mats["wall"], "FallenPanelA")
	a.rotation.z = deg_to_rad(-64.0)
	var b := LevelKit.prop(root, Vector3(x + 5.8, YARD_Y + 0.45, z + 2.2),
		Vector3(3.6, 0.55, 3.2), mats["wall"], "FallenPanelB")
	b.rotation = Vector3(deg_to_rad(6.0), deg_to_rad(9.0), deg_to_rad(-4.0))
	# The stub the panel tore off, still standing, with its reinforcement
	# combed out of the break. Every spall in this level is at an edge.
	LevelKit.prop(root, Vector3(x - 0.2, YARD_Y + h * 0.35, z),
		Vector3(1.2, h * 0.7, 0.7), mats["wall"], "BreachStubA")
	LevelKit.prop(root, Vector3(x + 8.6, YARD_Y + h * 0.5, z),
		Vector3(1.0, h, 0.7), mats["wall"], "BreachStubB")
	for i in 7:
		var r := LevelKit.prop(root,
			Vector3(x + 0.3 + fmod(float(i) * 0.43, 0.9),
				YARD_Y + h * 0.7 + float(i % 3) * 0.3, z - 0.2 + float(i % 4) * 0.18),
			Vector3(0.05, 1.4 + float(i % 3) * 0.4, 0.05), mats["rebar"], "Rebar%d" % i)
		r.rotation.z = deg_to_rad(-60.0 + i * 17.0)
	for i in 6:
		LevelKit.prop(root, Vector3(x + 1.0 + i * 1.3, YARD_Y + 0.22,
			z + 0.6 + fmod(float(i) * 0.7, 1.4)),
			Vector3(0.9, 0.44, 0.8), mats["wall"], "Rubble%d" % i)
	# Sand has come through the gap and fanned out into the yard.
	LevelKit.prop(root, Vector3(x + 4.4, YARD_Y + 0.12, z + 3.6),
		Vector3(9.0, 0.3, 6.0), mats["sand"], "BreachDrift")


## The vehicle gate: two chained leaves and a guard hut, in the second gap.
static func _vehicle_gate(parent: Node3D, mats: Dictionary, x: float, z: float,
		h: float) -> void:
	var root := Node3D.new()
	root.name = "VehicleGate"
	parent.add_child(root)
	for s in 2:
		var lx := x + 2.3 + s * 4.5
		LevelKit.prop(root, Vector3(lx, YARD_Y + 1.8, z), Vector3(4.3, 3.6, 0.14),
			mats["rust"], "GateLeaf%d" % s)
		for i in 7:
			LevelKit.prop(root, Vector3(lx - 1.8 + i * 0.6, YARD_Y + 1.8, z + 0.08),
				Vector3(0.08, 3.4, 0.07), mats["steel"], "GateBar")
	for s2: float in [0.0, 9.0]:
		LevelKit.prop(root, Vector3(x + s2, YARD_Y + h * 0.55, z),
			Vector3(0.7, h * 1.1, 0.9), mats["joint"], "GatePier")
	LevelKit.prop(root, Vector3(x + 4.5, YARD_Y + 4.3, z), Vector3(9.4, 0.5, 0.6),
		mats["joint"], "GateLintel")
	_lamp(root, mats, Vector3(x - 1.6, YARD_Y, z + 1.2), 7.4, true)
	PropKit.sandbag_row(root, x + 10.4, YARD_Y, 5.0, z + 1.6, mats["bag"], 3)


## Guard towers, the gatehouse and the wrecks: the things in the yard that give
## the middle distance scale and say this is a prison, not a works yard.
static func _yard_furniture(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	for x: float in [44.0, 108.0, 196.0, 288.0, 366.0]:
		_watchtower(parent, mats, x, -19.5)
	_gatehouse(parent, mats)

	_wreck(parent, mats, Vector3(62.0, YARD_Y, -12.4), "flatbed", 3)
	_wreck(parent, mats, Vector3(124.0, YARD_Y, -13.6), "bus", 7)
	_wreck(parent, mats, Vector3(238.0, YARD_Y, -11.2), "tipped", 11)
	_wreck(parent, mats, Vector3(312.0, YARD_Y, -13.0), "pickup", 5)

	# Sodium lamps still burning at dawn because nobody turned them off. Only
	# every other one carries a real light; the rest are silhouette.
	var span := x_to - x_from
	for i in int(span / 58.0) + 1:
		_lamp(parent, mats, Vector3(x_from + 22.0 + i * 58.0, YARD_Y, -17.4),
			8.2, i % 2 == 0)


static func _watchtower(parent: Node3D, mats: Dictionary, x: float, z: float) -> void:
	var root := Node3D.new()
	root.name = "Watchtower"
	parent.add_child(root)
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		var leg := LevelKit.prop(root, Vector3(x + sx * 1.0, YARD_Y + 4.0, z + sz * 1.0),
			Vector3(0.24, 8.0, 0.24), mats["steel"], "TowerLeg%d" % i)
		leg.rotation.z = -sx * 0.02
	for i in 3:
		LevelKit.prop(root, Vector3(x, YARD_Y + 1.6 + i * 2.2, z - 1.0),
			Vector3(2.3, 0.12, 0.12), mats["steel"], "TowerTie%d" % i)
		var br := LevelKit.prop(root, Vector3(x, YARD_Y + 2.7 + i * 2.2, z - 1.0),
			Vector3(2.9, 0.09, 0.09), mats["steel"], "TowerBrace%d" % i)
		br.rotation.z = 0.7 if i % 2 == 0 else -0.7
	LevelKit.prop(root, Vector3(x, YARD_Y + 8.1, z), Vector3(3.4, 0.3, 3.4),
		mats["steel"], "TowerDeck")
	LevelKit.prop(root, Vector3(x, YARD_Y + 9.2, z), Vector3(2.9, 1.9, 2.9),
		mats["wall"], "TowerCab")
	LevelKit.prop(root, Vector3(x, YARD_Y + 9.7, z + 1.48), Vector3(2.5, 0.85, 0.06),
		mats["dark"], "TowerGlass")
	var roof := LevelKit.prop(root, Vector3(x, YARD_Y + 10.35, z),
		Vector3(4.0, 0.12, 4.0), mats["corrugated"], "TowerRoof")
	roof.rotation.x = 0.06
	# A searchlight on the rail, pointed at nothing.
	LevelKit.prop(root, Vector3(x + 1.5, YARD_Y + 8.6, z + 1.2),
		Vector3(0.6, 0.6, 0.8), mats["rust"], "Searchlight")
	PropKit.sandbag_row(root, x - 2.4, YARD_Y, 5.0, z + 1.9, mats["bag"], 2)


## The gatehouse: the one building in the yard that somebody still lives in,
## and it is stated entirely through occupancy — a swept step, a light on, and
## washing on a line. No NPC required.
static func _gatehouse(parent: Node3D, mats: Dictionary) -> void:
	var x := LM_GATEHOUSE
	var z := -19.0
	var root := Node3D.new()
	root.name = "Gatehouse"
	parent.add_child(root)

	PropKit.building_massing(root, x - 3.6, YARD_Y, 7.2, 4.2, z + 2.6,
		mats["slab"], mats["joint"], 1, 8)
	LevelKit.prop(root, Vector3(x, YARD_Y + 2.1, z), Vector3(7.2, 4.2, 5.6),
		mats["slab"], "GatehouseBody")
	LevelKit.prop(root, Vector3(x, YARD_Y + 4.35, z), Vector3(7.9, 0.3, 6.2),
		mats["joint"], "GatehouseCap")
	PropKit.roof_clutter(root, x - 3.0, YARD_Y + 4.5, 6.0, z - 0.4, mats["dark"], 23)
	PropKit.lit_window(root, Vector3(x - 1.6, YARD_Y + 2.6, z + 2.86),
		Vector2(1.1, 1.0), mats["joint"], Color(1.0, 0.70, 0.34), 2.2)
	LevelKit.prop(root, Vector3(x + 2.0, YARD_Y + 1.05, z + 2.84),
		Vector3(0.95, 2.1, 0.08), mats["door"], "GatehouseDoor")
	# The swept step. Sand depth on a threshold is the abandonment map, and
	# this is the one doorway in the level that somebody still uses.
	LevelKit.prop(root, Vector3(x + 2.0, YARD_Y + 0.08, z + 3.5),
		Vector3(1.8, 0.16, 1.2), mats["joint"], "GatehouseStep")
	LevelKit.prop(root, Vector3(x + 4.4, YARD_Y + 0.12, z + 3.2),
		Vector3(2.6, 0.22, 2.0), mats["sand"], "DoorDrift")

	# The boom, up, because nothing has come through in years.
	LevelKit.prop(root, Vector3(x + 5.4, YARD_Y + 0.6, z + 3.2),
		Vector3(0.36, 1.2, 0.36), mats["steel"], "BoomPost")
	var boom := LevelKit.prop(root, Vector3(x + 6.6, YARD_Y + 2.6, z + 3.2),
		Vector3(5.6, 0.2, 0.2), mats["bund"], "Boom")
	boom.rotation.z = deg_to_rad(52.0)
	for i in 5:
		LevelKit.prop(root, Vector3(x + 5.9 + i * 0.86, YARD_Y + 1.5 + i * 1.1, z + 3.24),
			Vector3(0.44, 0.22, 0.22), mats["dark"], "BoomStripe%d" % i)

	PropKit.laundry_line(root, Vector3(x - 3.4, YARD_Y + 3.4, z + 2.9),
		Vector3(x + 6.2, YARD_Y + 2.7, z + 4.6), 0.55, mats["dark"],
		[Color(0.52, 0.50, 0.46), Color(0.30, 0.36, 0.40), Color(0.58, 0.54, 0.44)], 17)
	_lamp(root, mats, Vector3(x - 5.2, YARD_Y, z + 3.0), 6.6, true)

	# A hanging plant sign on a bracket, swinging.
	var sway := Sway.new()
	sway.name = "GateSignSway"
	sway.position = Vector3(x + 3.9, YARD_Y + 3.9, z + 2.9)
	sway.axis = Vector3(0.0, 0.0, 1.0)
	sway.amplitude = 0.16
	sway.speed = 0.9
	sway.gust_amplitude = 0.10
	root.add_child(sway)
	LevelKit.prop(sway, Vector3(0.9, -0.05, 0.0), Vector3(1.9, 0.08, 0.08),
		mats["steel"], "SignBracket")
	LevelKit.prop(sway, Vector3(1.6, -0.75, 0.0), Vector3(2.2, 1.3, 0.07),
		mats["bund"], "SignPlate")
	PropKit.sign(sway, "بوابة ٢", Vector3(1.6, -0.82, 0.06), 0.36,
		MaterialLab.plaster(Color(0.60, 0.58, 0.54), 1.0), PropKit.FONT_KUFI)


## Dead vehicles. Stripped and sanded in, never a weapon in the bed.
static func _wreck(parent: Node3D, mats: Dictionary, at: Vector3, kind: String,
		seed_: int) -> void:
	var root := Node3D.new()
	root.name = "Wreck"
	root.position = at
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 331 + 7
	var body: Material = mats["burnt"] if kind == "bus" else mats["rust"]

	match kind:
		"bus":
			LevelKit.prop(root, Vector3(0, 1.5, 0), Vector3(10.6, 2.3, 2.6),
				body, "BusBody")
			LevelKit.prop(root, Vector3(0, 2.15, 0.02), Vector3(9.6, 0.95, 2.72),
				mats["dark"], "BusGlazing")
			LevelKit.prop(root, Vector3(0, 2.78, 0), Vector3(10.2, 0.22, 2.7),
				mats["corrugated"], "BusRoof")
			LevelKit.prop(root, Vector3(-5.0, 1.4, 0), Vector3(0.7, 2.0, 2.5),
				body, "BusFront")
			# It sits on the rims on one side, so it leans.
			root.rotation.z = deg_to_rad(-2.6)
			for w: int in [-1, 1]:
				LevelKit.prop(root, Vector3(w * 3.6, 0.40, 1.35),
					Vector3(0.9, 0.8, 0.3), mats["dark"], "BusWheel")
		"flatbed":
			LevelKit.prop(root, Vector3(0, 1.0, 0), Vector3(7.4, 0.6, 2.3),
				body, "Chassis")
			LevelKit.prop(root, Vector3(-2.4, 1.9, 0), Vector3(2.4, 1.6, 2.2),
				body, "Cab")
			LevelKit.prop(root, Vector3(-2.4, 2.1, 1.12), Vector3(1.9, 0.75, 0.06),
				mats["dark"], "CabGlass")
			for i in 5:
				LevelKit.prop(root, Vector3(0.4 + i * 1.1, 1.9, -1.1),
					Vector3(0.14, 1.2, 0.14), body, "Stake%d" % i)
			for w2: int in [-1, 1]:
				LevelKit.prop(root, Vector3(w2 * 2.4, 0.42, 1.0),
					Vector3(0.8, 0.76, 0.28), mats["dark"], "Wheel")
		"tipped":
			LevelKit.prop(root, Vector3(0, 1.1, 0), Vector3(5.0, 1.0, 2.1),
				body, "Body")
			LevelKit.prop(root, Vector3(-1.2, 2.1, 0), Vector3(2.2, 1.1, 2.0),
				body, "Cab")
			root.rotation.z = deg_to_rad(74.0)
			root.position += Vector3(0.0, 0.4, 0.0)
		_:
			LevelKit.prop(root, Vector3(0, 0.9, 0), Vector3(4.8, 0.9, 2.0),
				body, "Body")
			LevelKit.prop(root, Vector3(-0.7, 1.7, 0), Vector3(2.0, 0.9, 1.9),
				body, "Cab")
			LevelKit.prop(root, Vector3(1.5, 1.5, 0), Vector3(2.0, 0.35, 1.9),
				body, "Bed")
			for w3: int in [-1, 1]:
				LevelKit.prop(root, Vector3(w3 * 1.6, 0.36, 0.9),
					Vector3(0.72, 0.68, 0.26), mats["dark"], "Wheel")

	# Sand has piled on the leeward side of everything out here.
	LevelKit.prop(root, Vector3(rng.randf_range(-2.0, 2.0), 0.16, -1.4),
		Vector3(rng.randf_range(3.0, 5.5), 0.34, 1.8), mats["sand"], "WreckDrift")


## The pole line: the same one that walks out of the benchmark frame, run the
## length of the level so every section has something between the yard and the
## horizon.
static func _pole_line(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var tops: Array[Vector3] = []
	for i in int(span / 13.0) + 2:
		var px := x_from - 10.0 + i * 13.0
		var ph := 7.2 + sin(float(i) * 1.7) * 0.5
		LevelKit.prop(parent, Vector3(px, YARD_Y + ph * 0.5, -13.0),
			Vector3(0.22, ph, 0.22), mats["steel"], "Pole%d" % i)
		LevelKit.prop(parent, Vector3(px, YARD_Y + ph - 0.55, -13.0),
			Vector3(2.3, 0.14, 0.14), mats["steel"], "Crossarm%d" % i)
		# Insulators: three white dots on a black bar, which is the only thing
		# that separates a pole from a stick at this distance.
		for k in 3:
			LevelKit.prop(parent, Vector3(px - 0.9 + k * 0.9, YARD_Y + ph - 0.40, -13.0),
				Vector3(0.14, 0.22, 0.14), mats["bund"], "Insulator")
		tops.append(Vector3(px, YARD_Y + ph - 0.55, -13.0))
	for i in tops.size() - 1:
		for lane in 3:
			var lift := -0.02 - lane * 0.02
			PropKit.cable(parent, tops[i] + Vector3(-0.9 + lane * 0.9, lift, 0.0),
				tops[i + 1] + Vector3(-0.9 + lane * 0.9, lift, 0.0),
				0.95 + lane * 0.12, mats["dark"], 10, 0.055)


## A pipe bridge crossing the frame in Z, sheared off over the yard. It is the
## one piece of geometry in the level that travels toward the camera, so it is
## the one that makes the backdrop feel like a place with a behind and a front
## rather than a set of painted flats.
static func _pipe_bridge(parent: Node3D, mats: Dictionary, x: float, y: float) -> void:
	var steel: Material = mats["steel"]
	var root := Node3D.new()
	root.name = "PipeBridge"
	parent.add_child(root)
	var z_far := -38.0
	# Stops five units short of the gameplay plane. Any closer and a
	# background girder starts to read as something you could stand on.
	var z_near := -5.0
	var length := z_near - z_far

	LevelKit.prop(root, Vector3(x, y, (z_far + z_near) * 0.5),
		Vector3(2.6, 1.6, length), mats["bund"], "BridgeCase")
	LevelKit.prop(root, Vector3(x, y + 1.0, (z_far + z_near) * 0.5),
		Vector3(3.0, 0.24, length), steel, "BridgeLid")
	for i in 4:
		var pipe := MeshInstance3D.new()
		pipe.name = "BridgePipe%d" % i
		pipe.mesh = _cyl(0.26 if i % 2 == 0 else 0.36, length, 10)
		pipe.material_override = mats["rust"]
		pipe.position = Vector3(x - 0.9 + i * 0.6, y + 1.5, (z_far + z_near) * 0.5)
		pipe.rotation.x = PI * 0.5
		root.add_child(pipe)

	for tz: float in [z_far + 5.0, z_far + 19.0]:
		for s: float in [-1.0, 1.0]:
			LevelKit.prop(root, Vector3(x + s * 1.1, (y + YARD_Y) * 0.5, tz),
				Vector3(0.46, y - YARD_Y, 0.46), steel, "BridgeLeg")
		for k in 3:
			var br := LevelKit.prop(root,
				Vector3(x, YARD_Y + 1.4 + k * (y - YARD_Y - 2.0) / 3.0, tz),
				Vector3(2.8, 0.14, 0.14), steel, "BridgeBrace")
			br.rotation.z = 0.62 if k % 2 == 0 else -0.62

	# The sheared end: plate torn back and three pipes drooping out of it.
	var torn := LevelKit.prop(root, Vector3(x, y + 0.4, z_near - 0.5),
		Vector3(2.9, 2.2, 0.16), mats["rust"], "TornPlate")
	torn.rotation = Vector3(deg_to_rad(28.0), 0.0, deg_to_rad(11.0))
	for i in 3:
		var droop := LevelKit.prop(root,
			Vector3(x - 0.7 + i * 0.7, y - 0.6, z_near - 1.9),
			Vector3(0.3, 3.4, 0.3), mats["rust"], "DroopPipe%d" % i)
		droop.rotation.x = deg_to_rad(52.0 + i * 9.0)

	_tarp(root, mats, Vector3(x + 1.8, y - 0.4, z_far + 12.0),
		Vector2(2.6, 3.0), 0.26, 909)


## The windbreak. Planted dead straight by the oil company, irrigation stopped,
## failing back to desert in visible rows — a dead tree in a straight line is
## unmistakably planted, and that is the storytelling. Clumped with gaps and
## fallen trunks, because a perfectly even row is a fence.
static func _windbreak(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from
	var rng := RandomNumberGenerator.new()
	rng.seed = 8813
	for i in int(span / 8.4) + 1:
		var x := x_from + i * 8.4 + rng.randf_range(-1.4, 1.4)
		var z := -21.0 - rng.randf_range(0.0, 3.4)
		var roll := rng.randf()
		if roll < 0.16:
			continue                       # a gap where one died and blew away
		if roll < 0.24:
			# A fallen trunk, still in the line. Horizontals in a row of
			# verticals is what stops a windbreak reading as a comb.
			var t := LevelKit.prop(parent, Vector3(x, YARD_Y + 0.35, z),
				Vector3(6.4, 0.5, 0.5), mats["trunk"], "FallenTrunk")
			t.rotation = Vector3(0.0, rng.randf_range(-0.5, 0.5),
				rng.randf_range(-0.12, 0.12))
			continue
		PropKit.eucalyptus(parent, Vector3(x, YARD_Y, z),
			8.0 + rng.randf_range(0.0, 3.4), mats["trunk"], mats["leaf"],
			roll > 0.72, i)

	# Two planted palms at the gatehouse: the avenue somebody laid out when
	# this was a working plant with an office in it.
	for s: float in [-1.0, 1.0]:
		PropKit.palm(parent, Vector3(LM_GATEHOUSE + s * 7.0, YARD_Y, -23.5),
			9.4 + s * 0.8, mats["trunk"], mats["leaf"], int(31 + s * 3.0))


## Everything that moves. At these distances only big things read: a tarpaulin,
## a fan, a flock. A leaf rustling at z -30 is two pixels of nothing.
static func _wind_and_life(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var span := x_to - x_from

	# Tarpaulins lashed over things and coming loose. One every ~70 units, so
	# there is never a screen without a DRAPE element moving in it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6101
	for i in int(span / 70.0) + 2:
		var x := x_from + 26.0 + i * 70.0 + rng.randf_range(-12.0, 12.0)
		match i % 3:
			0:
				# Hung over the wall coping and flogging in the onshore wind.
				_tarp(parent, mats, Vector3(x, YARD_Y + 3.2, -15.4),
					Vector2(3.4, 2.8), 0.30, 200 + i)
			1:
				# Lashed over a stack of crates in the yard.
				for k in 3:
					LevelKit.prop(parent, Vector3(x - 1.0 + k * 1.1, YARD_Y + 0.55,
						-13.2), Vector3(1.5, 1.1, 1.3), mats["crate"], "TarpCrate")
				_tarp(parent, mats, Vector3(x, YARD_Y + 1.6, -12.4),
					Vector2(4.2, 2.2), 0.22, 300 + i)
			_:
				# Snagged on the pole line and streaming sideways.
				_tarp(parent, mats, Vector3(x, YARD_Y + 5.2, -12.8),
					Vector2(2.2, 3.2), 0.42, 400 + i)

	# Roof extractors on the plant halls, turning slowly. Big enough to read at
	# thirty units, which means industrial-sized, which is also what is real.
	_fan(parent, mats, Vector3(x_from + 96.0, YARD_Y + 6.2, -29.4), 1.5, 0.75)
	_fan(parent, mats, Vector3(x_from + 214.0, YARD_Y + 5.6, -29.4), 1.3, -0.55)
	_fan(parent, mats, Vector3(x_from + 322.0, YARD_Y + 6.8, -29.4), 1.7, 0.42)

	# Birds. Two loose flocks crossing the empty upper half of the frame, which
	# is otherwise the one part of the image with nothing happening in it.
	_flock(parent, mats, Vector3(x_from + 40.0, YARD_Y + 22.0, -62.0), 7, 2.6, 260.0)
	_flock(parent, mats, Vector3(x_from + 180.0, YARD_Y + 31.0, -118.0), 9, 3.4, 340.0)


# ============================================================================
# THE PLANT BAND — z -18 .. -44
# ============================================================================

## The working plant, behind the perimeter wall. Level 1 is a walk past a
## petrochemical complex, and this band is what the gameplay plane is read
## against: it sits one clear value step darker than the tank farm behind it.
##
## Seven beats on an irregular pitch (26 to 46 units), so the rhythm never
## phases with the screen width and no two screens in a 400-unit level carry
## the same arrangement. Every third beat gets a light left on.
static func plant_band(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var shell: Material = mats["plant"]
	var frame: Material = mats["steel"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7723
	var x := x_from - 30.0
	var beat := 0
	while x < x_to + 30.0:
		match beat % 7:
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
			2:
				# A conveyor gantry on legs, running out of frame both ways.
				var gy := YARD_Y + 8.7
				LevelKit.prop(parent, Vector3(x + 18.0, gy, -19.5),
					Vector3(40.0, 1.5, 2.0), mats["bund"], "ConveyorCase")
				LevelKit.prop(parent, Vector3(x + 18.0, gy + 0.85, -19.5),
					Vector3(40.0, 0.22, 2.3), frame, "ConveyorLid")
				for i in 6:
					LevelKit.prop(parent, Vector3(x + i * 7.6, YARD_Y + 3.3, -19.5),
						Vector3(0.42, 6.6, 0.42), frame, "GantryLeg")
					var kn := LevelKit.prop(parent,
						Vector3(x + i * 7.6 + 1.5, YARD_Y + 5.4, -19.5),
						Vector3(3.2, 0.16, 0.16), frame, "GantryKnee")
					kn.rotation.z = 0.62
				x += 42.0
			3:
				# A process hall: a real building in among the plant, with a
				# roofline and lights on. It is the horizontal the band needs.
				var hw := rng.randf_range(20.0, 30.0)
				# The hall's front face lands at z -27.9; the massing has to
				# stand proud of THAT, not of the box's centre line, or every
				# string course and cornice is buried inside the building.
				PropKit.building_massing(parent, x, YARD_Y, hw, 9.0, -27.9,
					shell, mats["bund"], 3, beat)
				LevelKit.prop(parent, Vector3(x + hw * 0.5, YARD_Y + 4.5, -31.4),
					Vector3(hw, 9.0, 7.0), shell, "PlantHall")
				LevelKit.prop(parent, Vector3(x + hw * 0.5, YARD_Y + 9.2, -31.4),
					Vector3(hw + 0.8, 0.4, 7.6), mats["bund"], "HallParapet")
				PropKit.roof_clutter(parent, x + 2.0, YARD_Y + 9.4, hw - 4.0, -31.0,
					mats["plant"], 61 + beat)
				for k in 4:
					LevelKit.prop(parent,
						Vector3(x + hw * (0.16 + 0.22 * k), YARD_Y + 5.4, -27.8),
						Vector3(1.6, 2.6, 0.3), mats["dark"], "HallGlazing%d" % k)
				# Three lights left on in the hall. They go on a real wall, so
				# they read as windows rather than as glowing boxes hanging in
				# the haze.
				for k in 3:
					PropKit.lit_window(parent,
						Vector3(x + hw * (0.24 + 0.26 * k), YARD_Y + 2.4, -27.75),
						Vector2(0.9, 1.2), mats["joint"], Color(1.0, 0.64, 0.28), 1.6)
				x += 34.0
			4:
				# Fin-fan cooler bank on a steel table: a long low horizontal of
				# repeated cells, and nothing else in the plant looks like it.
				for i in 6:
					LevelKit.prop(parent, Vector3(x + i * 3.4, YARD_Y + 5.4, -24.0),
						Vector3(3.1, 0.9, 3.4), mats["bund"], "FinFan%d" % i)
					LevelKit.prop(parent, Vector3(x + i * 3.4, YARD_Y + 6.05, -24.0),
						Vector3(2.6, 0.4, 2.8), frame, "FanCowl%d" % i)
				for i in 5:
					LevelKit.prop(parent, Vector3(x + i * 4.2, YARD_Y + 2.4, -24.0),
						Vector3(0.34, 5.0, 0.34), frame, "CoolerLeg%d" % i)
				LevelKit.prop(parent, Vector3(x + 8.5, YARD_Y + 4.8, -24.0),
					Vector3(21.0, 0.3, 4.0), frame, "CoolerTable")
				x += 28.0
			5:
				# Knock-out drum and manifold: a squat horizontal vessel with a
				# forest of small pipework off it.
				PropKit.vessel(parent, Vector3(x + 5.0, YARD_Y + 2.2, -22.5),
					7.0, 2.1, shell, mats["bund"])
				for i in 8:
					LevelKit.prop(parent, Vector3(x + 1.0 + i * 1.3, YARD_Y + 5.0, -21.0),
						Vector3(0.22, 4.2, 0.22), mats["rust"], "Riser%d" % i)
				LevelKit.prop(parent, Vector3(x + 5.5, YARD_Y + 7.0, -21.0),
					Vector3(11.0, 0.34, 0.34), mats["rust"], "Header")
				_lamp(parent, mats, Vector3(x + 12.0, YARD_Y, -23.0), 9.0, false)
				x += 32.0
			_:
				# Two tall columns tied together with a pipe bridge at height —
				# the beat that gives this band a skyline of its own.
				PropKit.column(parent, Vector3(x, YARD_Y, -34.0), 22.0, 1.7,
					shell, frame, 5)
				PropKit.column(parent, Vector3(x + 13.0, YARD_Y, -36.0), 18.0, 1.4,
					shell, frame, 4)
				LevelKit.prop(parent, Vector3(x + 6.5, YARD_Y + 15.0, -35.0),
					Vector3(13.5, 0.6, 1.2), frame, "ColumnTie")
				for i in 4:
					LevelKit.prop(parent, Vector3(x + 6.5, YARD_Y + 15.8 + i * 0.36, -35.0),
						Vector3(13.5, 0.22, 0.22), mats["rust"], "TiePipe%d" % i)
				x += 38.0
		# A lamp somebody never came back to switch off, on every other beat.
		# These are most of the warm accents the shadow half of the frame gets,
		# and only half of them carry a real light — the rest are silhouette
		# with a hot lens, which costs nothing.
		if beat % 2 == 0:
			_lamp(parent, mats, Vector3(x - 9.0, YARD_Y, -21.5), 8.6, beat % 4 == 0)
		beat += 1


# ============================================================================
# THE FOREGROUND BAND — z +4 .. +10
# ============================================================================

## A band of near-black junk between the camera and the play plane. Every frame
## in World 1 was landing with an empty bottom third; a foreground silhouette
## is what gives an image a floor to stand on, and the yard of a working plant
## has plenty lying about.
##
## Sized to the NEAR FRUSTUM, not to the world. At z = +9 the camera is 7 units
## away and the frame is about six world units across, so a crate that would be
## unremarkable on the gameplay plane blacks out a quarter of the image. Every
## size here is scaled by depth, and the closer a thing is the smaller it gets.
## Every ~46 units one element runs the full frame height to close an edge.
static func foreground_band(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	# The junk below sits on the yard floor, which is fine in the yard and
	# useless everywhere else: the gameplay plane runs up to fourteen units
	# above YARD_Y, and at z +7 the frame is only three units tall either side
	# of the camera. Anything lying on the ground is off the bottom of the
	# image for most of the level. These two carry the foreground at every
	# camera height instead.
	_fg_poles(parent, mats, x_from, x_to)
	_near_frame(parent, mats)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4409
	var dark: Material = mats["dark"]
	var x := x_from
	var since_tall := 0.0
	while x < x_to:
		var step := rng.randf_range(5.0, 10.0)
		x += step
		since_tall += step
		var z := rng.randf_range(4.2, 9.4)
		var y := YARD_Y + rng.randf_range(0.0, 0.6)
		# 1.0 at the far edge of the band, 0.45 at the near edge.
		var k := clampf(remap(z, 4.2, 9.4, 1.0, 0.45), 0.45, 1.0)

		if since_tall > 46.0:
			since_tall = 0.0
			match rng.randi() % 3:
				0:
					# A dead casuarina closing a frame edge, silvered to black.
					PropKit.eucalyptus(parent, Vector3(x, y - 4.0, minf(z, 7.0)),
						13.0, dark, dark, false, rng.randi())
				1:
					# A stanchion running out of the top of the frame, with the
					# stub of whatever it used to carry.
					var st := LevelKit.prop(parent, Vector3(x, y + 3.4 * k, z),
						Vector3(0.30 * k, 8.0 * k, 0.30 * k), dark, "FgStanchion")
					st.rotation.z = rng.randf_range(-0.05, 0.05)
					LevelKit.prop(parent, Vector3(x + 0.6 * k, y + 5.6 * k, z),
						Vector3(1.5 * k, 0.22 * k, 0.22 * k), dark, "FgStub")
				_:
					# A ladder against something off-frame.
					var lad := LevelKit.prop(parent, Vector3(x, y + 3.0 * k, z),
						Vector3(0.7 * k, 7.0 * k, 0.12 * k), dark, "FgLadder")
					lad.rotation.z = deg_to_rad(-9.0)
					for r in 7:
						LevelKit.prop(parent,
							Vector3(x + 0.1 * r * k, y + 0.4 * k + r * 0.9 * k, z),
							Vector3(0.7 * k, 0.07 * k, 0.09 * k), dark, "FgRung%d" % r)
			continue

		match rng.randi() % 10:
			0:
				var t := LevelKit.prop(parent, Vector3(x, y + 0.30 * k, z),
					Vector3(1.00 * k, 0.36 * k, 1.00 * k), dark, "FgTyre")
				t.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0.0,
					rng.randf_range(-0.2, 0.2))
			1:
				var d := LevelKit.prop(parent, Vector3(x, y + 0.44 * k, z),
					Vector3(0.62 * k, 0.88 * k, 0.62 * k), dark, "FgDrum")
				d.rotation.z = 1.57 if rng.randf() < 0.4 else 0.0
			2:
				LevelKit.prop(parent, Vector3(x, y + 0.14 * k, z),
					Vector3(2.60 * k, 0.28 * k, 1.20 * k), dark, "FgPallet")
			3:
				var p := LevelKit.prop(parent, Vector3(x, y + 0.85 * k, z),
					Vector3(0.18 * k, 1.70 * k, 0.18 * k), dark, "FgPost")
				p.rotation.z = rng.randf_range(-0.42, 0.42)
			4:
				# A low kerb run: a horizontal that crosses the bottom of the
				# frame instead of another object sitting in it.
				LevelKit.prop(parent, Vector3(x + 3.0 * k, y + 0.16 * k, z),
					Vector3(rng.randf_range(5.0, 11.0) * k, 0.32 * k, 0.5 * k),
					dark, "FgKerb")
			5:
				# A cable drum. The only circle in a band made of boxes, and
				# the shape the eye finds first.
				var spool := MeshInstance3D.new()
				spool.name = "FgSpool"
				spool.mesh = _cyl(0.85 * k, 1.0 * k, 14)
				spool.material_override = dark
				spool.position = Vector3(x, y + 0.85 * k, z)
				spool.rotation.z = PI * 0.5
				parent.add_child(spool)
				LevelKit.prop(parent, Vector3(x, y + 0.85 * k, z),
					Vector3(1.1 * k, 1.15 * k, 1.15 * k), dark, "FgSpoolCore")
			6:
				# A leaning panel of chain-link off its posts.
				var panel := LevelKit.prop(parent, Vector3(x, y + 0.95 * k, z),
					Vector3(2.8 * k, 2.0 * k, 0.07 * k), dark, "FgFencePanel")
				panel.rotation = Vector3(0.0, rng.randf_range(-0.4, 0.4),
					deg_to_rad(rng.randf_range(-22.0, -8.0)))
				for i in 3:
					LevelKit.prop(parent,
						Vector3(x - 1.1 * k + i * 1.1 * k, y + 1.0 * k, z),
						Vector3(0.09 * k, 2.2 * k, 0.09 * k), dark, "FgFencePost")
			7:
				# Scrub: a low separated mound with bare ground round it. Wild
				# growth here is never continuous cover.
				for _i in 3:
					var bush := MeshInstance3D.new()
					bush.name = "FgScrub"
					bush.mesh = _ball(rng.randf_range(0.28, 0.52) * k, 8, 5)
					bush.material_override = dark
					bush.position = Vector3(x + rng.randf_range(-0.9, 0.9) * k,
						y + 0.18 * k, z + rng.randf_range(-0.5, 0.5))
					bush.scale = Vector3(1.4, 0.7, 1.0)
					parent.add_child(bush)
			8:
				# A bent pipe elbow half buried: two boxes and a corner.
				LevelKit.prop(parent, Vector3(x, y + 0.20 * k, z),
					Vector3(2.2 * k, 0.34 * k, 0.34 * k), dark, "FgPipe")
				var ell := LevelKit.prop(parent,
					Vector3(x + 1.1 * k, y + 0.7 * k, z),
					Vector3(0.34 * k, 1.2 * k, 0.34 * k), dark, "FgElbow")
				ell.rotation.z = deg_to_rad(-24.0)
			_:
				# A tarpaulin over something, moving. Even down here the DRAPE
				# rule applies, and a near-black cloth that flexes is the
				# cheapest life in the frame.
				_tarp(parent, mats, Vector3(x, y + 1.1 * k, z),
					Vector2(1.9 * k, 1.5 * k), 0.16, rng.randi(), dark)


## Tall near-black verticals running the full frame height, every twenty units
## or so. A vertical at the edge of frame is the one foreground device that
## works no matter where the camera is in Y — it closes the composition, it
## never crosses the middle of the image, and it costs two boxes.
##
## Roughly half the frames in the level carry one, which is the ratio that
## reads as a place rather than as a colonnade.
static func _fg_poles(parent: Node3D, mats: Dictionary,
		x_from: float, x_to: float) -> void:
	var dark: Material = mats["dark"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var tops: Array[Vector3] = []
	var x := x_from - 8.0
	while x < x_to + 8.0:
		x += rng.randf_range(15.0, 24.0)
		var z := rng.randf_range(4.8, 6.8)
		# One in four is snapped off, so the run is not a metronome.
		var broken := rng.randf() < 0.26
		var h := rng.randf_range(8.0, 12.0) if broken else rng.randf_range(16.0, 20.0)
		var base := YARD_Y - 0.5
		var pole := LevelKit.prop(parent, Vector3(x, base + h * 0.5, z),
			Vector3(0.34, h, 0.34), dark, "FgPole")
		pole.rotation.z = rng.randf_range(-0.035, 0.035)
		# A bracket off the side at a random height: the thing that stops it
		# reading as a scratch on the lens.
		var by := base + h * rng.randf_range(0.45, 0.85)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		LevelKit.prop(parent, Vector3(x + side * 0.55, by, z),
			Vector3(1.3, 0.16, 0.16), dark, "FgBracket")
		LevelKit.prop(parent, Vector3(x + side * 1.1, by - 0.45, z),
			Vector3(0.16, 0.9, 0.16), dark, "FgHanger")
		if not broken:
			tops.append(Vector3(x, base + h - 0.4, z))

	# One cable lane along the tops. It only crosses the image when the camera
	# is high — the pipe rack and the catwalks — which is exactly where the
	# frame has nothing in the upper half.
	for i in tops.size() - 1:
		if tops[i + 1].x - tops[i].x > 48.0:
			continue
		PropKit.cable(parent, tops[i], tops[i + 1], 1.8, dark, 8, 0.075)


## Authored near-frame fragments, placed against the section heights in
## Brega.gd: a handrail or a fallen beam that crosses the bottom of the frame
## while the player is on a deck ten units above the yard.
##
## These are hand-placed rather than scattered, because a foreground element
## only works when it is at the height the camera will actually be, and only
## the level knows that. x, y above YARD_Y, length, degrees.
static func _near_frame(parent: Node3D, mats: Dictionary) -> void:
	var dark: Material = mats["dark"]
	# The second column is the deck height Brega.gd puts the player on, plus
	# 0.9: that lands the beam a little over two units below the camera, which
	# is the lower third of the frame at this depth. Any higher and it crosses
	# him; any lower and it is off the bottom of the image.
	var plan := [
		[16.0, 7.5, 6.5, 6.0],       # the walkway, out past the broken post
		[60.0, 2.1, 6.0, -9.0],      # the first yard deck
		[92.0, 3.5, 5.2, 14.0],      # the yard ledge
		[108.0, 5.3, 5.6, -11.0],    # the high yard step
		[128.0, 7.9, 6.4, -7.0],     # climbing the pipe rack sleepers
		[152.0, 13.3, 7.0, 5.0],     # the rack top, before the glide
		[176.0, 5.5, 6.2, -12.0],    # the glide landing
		[200.0, 5.5, 6.8, 8.0],      # the property cage approach
		[232.0, 5.5, 5.8, -6.0],     # tank farm A
		[258.0, 7.1, 6.6, 11.0],     # tank farm B
		[296.0, 7.7, 6.0, -8.0],     # the catwalk and the secret
		[334.0, 8.1, 7.0, 7.0],      # the fence run
		[366.0, 7.3, 5.8, -5.0],     # the gate
	]
	for i in plan.size():
		var x: float = plan[i][0]
		var y: float = YARD_Y + plan[i][1]
		var l: float = plan[i][2]
		var deg: float = plan[i][3]
		var z := 4.6 + fmod(float(i) * 0.7, 1.2)
		var beam := LevelKit.prop(parent, Vector3(x, y, z),
			Vector3(l, 0.34, 0.34), dark, "FgBeam%d" % i)
		beam.rotation.z = deg_to_rad(deg)
		# A stanchion off one end, so the beam is attached to the world.
		var end := x + (l * 0.5 - 0.6) * (1.0 if i % 2 == 0 else -1.0)
		var post := LevelKit.prop(parent, Vector3(end, y - 1.1, z),
			Vector3(0.22, 2.2, 0.22), dark, "FgBeamPost%d" % i)
		post.rotation.z = deg_to_rad(deg * 0.4)
		# And a mid rail under it: two horizontals read as a guard rail, one
		# reads as a stick.
		LevelKit.prop(parent, Vector3(x, y - 0.62, z),
			Vector3(l * 0.9, 0.16, 0.16), dark, "FgBeamRail%d" % i)


# ============================================================================
# Local builders
# ============================================================================

## Continuous rotation. `Sway` covers everything that hangs, but a fan has to
## go round, and a fan that oscillates reads as broken rather than running.
class Spinner extends Node3D:
	var speed := 0.8

	func _process(delta: float) -> void:
		rotation.z += speed * delta


## A loose flock crossing the sky. At sixty units a bird is four pixels, so
## what has to read is the drift and the beat, not the shape.
class Flock extends Node3D:
	var speed := 2.6
	var span := 260.0
	var _birds: Array[Node3D] = []
	var _base_y: Array[float] = []
	var _x0 := 0.0
	var _t := 0.0
	var _travel := 0.0

	func _ready() -> void:
		_x0 = position.x
		for c in get_children():
			if c is Node3D:
				_birds.append(c as Node3D)
				_base_y.append((c as Node3D).position.y)

	func _process(delta: float) -> void:
		_t += delta
		_travel += speed * delta
		position.x = _x0 + fmod(_travel, span)
		for i in _birds.size():
			var b := _birds[i]
			var f := sin(_t * 5.2 + float(i) * 1.7) * 0.55
			b.position.y = _base_y[i] + sin(_t * 0.9 + float(i) * 0.6) * 0.45
			var k := 0
			for w in b.get_children():
				(w as Node3D).rotation.z = f if k == 0 else -f
				k += 1


static func _flock(parent: Node3D, mats: Dictionary, at: Vector3, count: int,
		speed: float, span: float) -> void:
	var flock := Flock.new()
	flock.name = "Flock"
	flock.position = at
	flock.speed = speed
	flock.span = span
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(at.x) * 31.0 + count)
	for i in count:
		var bird := Node3D.new()
		bird.name = "Bird%d" % i
		# A ragged V, not a formation: they are gulls, not geese.
		bird.position = Vector3(-float(i) * rng.randf_range(1.6, 3.4),
			rng.randf_range(-2.6, 2.6), rng.randf_range(-6.0, 6.0))
		flock.add_child(bird)
		for s: float in [-1.0, 1.0]:
			var wing := LevelKit.prop(bird, Vector3(s * 0.38, 0.0, 0.0),
				Vector3(0.76, 0.07, 0.16), mats["dark"], "Wing")
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flock)


## An industrial extractor on a wall, turning. Two and a half units across,
## because at thirty units anything smaller is a smudge that does not read as
## rotating at all.
static func _fan(parent: Node3D, mats: Dictionary, at: Vector3, radius: float,
		speed: float) -> void:
	# Its own house, carried all the way down to the yard floor. Whatever the
	# plant band's rhythm happened to put at this x, the fan is mounted on
	# something and that something is standing on the ground.
	var top := at.y + radius * 1.45
	var house_h := top - YARD_Y
	LevelKit.prop(parent, Vector3(at.x, YARD_Y + house_h * 0.5, at.z - 0.9),
		Vector3(radius * 2.9, house_h, 1.8), mats["plant"], "FanHouse")
	LevelKit.prop(parent, Vector3(at.x, top + 0.13, at.z - 0.9),
		Vector3(radius * 3.2, 0.26, 2.0), mats["bund"], "FanHouseCap")

	var cowl := MeshInstance3D.new()
	cowl.name = "FanCowl"
	cowl.mesh = _cyl(radius * 1.15, 0.5, 14)
	cowl.material_override = mats["bund"]
	cowl.position = at
	cowl.rotation.x = PI * 0.5
	parent.add_child(cowl)

	var spin := Spinner.new()
	spin.name = "Fan"
	spin.speed = speed
	spin.position = at + Vector3(0.0, 0.0, 0.34)
	parent.add_child(spin)
	var hub := MeshInstance3D.new()
	hub.name = "Hub"
	hub.mesh = _cyl(radius * 0.18, 0.3, 8)
	hub.material_override = mats["dark"]
	hub.rotation.x = PI * 0.5
	spin.add_child(hub)
	for i in 4:
		var blade := LevelKit.prop(spin, Vector3.ZERO,
			Vector3(radius * 1.9, radius * 0.42, 0.08), mats["dark"], "Blade%d" % i)
		blade.rotation.z = TAU * float(i) / 4.0
		blade.position = Vector3(cos(blade.rotation.z), sin(blade.rotation.z), 0.0) \
			* radius * 0.5


## A tarpaulin lashed at the top and loose at the bottom. Two panels on
## separate phases: one sheet swinging as a rigid board is a signboard, and the
## second panel with a different period is what makes it read as cloth.
static func _tarp(parent: Node3D, mats: Dictionary, at: Vector3, size: Vector2,
		amplitude: float, seed_: int, override_mat: Material = null) -> void:
	var mat: Material = override_mat if override_mat != null else mats["tarp"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 733 + 3

	var sway := Sway.new()
	sway.name = "Tarp"
	sway.position = at
	sway.axis = Vector3(0.22, 1.0, 0.55)
	sway.amplitude = amplitude
	sway.speed = rng.randf_range(0.8, 1.35)
	sway.gust_amplitude = amplitude * 0.7
	sway.gust_speed = rng.randf_range(2.6, 4.2)
	parent.add_child(sway)

	var sheet := LevelKit.prop(sway, Vector3(0.0, -size.y * 0.5, 0.0),
		Vector3(size.x, size.y, 0.04), mat, "TarpSheet")
	sheet.rotation.z = rng.randf_range(-0.10, 0.10)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var flap := Sway.new()
	flap.name = "TarpFlap"
	flap.position = Vector3(size.x * 0.42, -size.y * 0.8, 0.0)
	flap.axis = Vector3(0.0, 0.7, 1.0)
	flap.amplitude = amplitude * 2.1
	flap.speed = rng.randf_range(1.6, 2.4)
	flap.gust_amplitude = amplitude * 1.4
	sway.add_child(flap)
	var torn := LevelKit.prop(flap, Vector3(size.x * 0.16, -size.y * 0.18, 0.0),
		Vector3(size.x * 0.42, size.y * 0.46, 0.03), mat, "TarpTorn")
	torn.rotation.z = rng.randf_range(-0.5, -0.15)
	torn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A sodium lamp on a bracketed pole. The bracket is the point: a head kicked
## out over the road is a street lamp, a dot on top of a stick is a post.
static func _lamp(parent: Node3D, mats: Dictionary, at: Vector3, height: float,
		with_light: bool) -> void:
	var steel: Material = mats["steel"]
	LevelKit.prop(parent, at + Vector3(0.0, height * 0.5, 0.0),
		Vector3(0.20, height, 0.20), steel, "LampPole")
	var arm := LevelKit.prop(parent, at + Vector3(0.62, height - 0.20, 0.0),
		Vector3(1.4, 0.13, 0.13), steel, "LampArm")
	arm.rotation.z = deg_to_rad(9.0)
	LevelKit.prop(parent, at + Vector3(1.30, height - 0.10, 0.0),
		Vector3(0.95, 0.24, 0.5), steel, "LampHead")
	LevelKit.prop(parent, at + Vector3(1.30, height - 0.26, 0.0),
		Vector3(0.72, 0.07, 0.38), mats["sodium"], "LampLens")
	if not with_light:
		return
	var o := OmniLight3D.new()
	o.name = "SodiumPractical"
	o.position = at + Vector3(1.30, height - 0.40, 0.0)
	o.light_color = Color(1.0, 0.631, 0.231)
	o.light_energy = 6.0
	o.omni_range = 15.0
	# The cone through the mist is most of what this light is for.
	o.light_volumetric_fog_energy = 4.5
	o.shadow_enabled = false
	parent.add_child(o)


## A chimney with its bands and its lamps. Bands are geometry, not texture:
## a painted stripe on a shaft at three hundred units is one pixel of nothing,
## and a 200 mm ring that breaks the silhouette survives the fog.
static func _chimney(parent: Node3D, mats: Dictionary, base: Vector3,
		radius: float, height: float, mat: Material) -> void:
	var root := Node3D.new()
	root.name = "Chimney"
	root.position = base
	parent.add_child(root)
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = _cyl(radius, height, 16, radius * 0.62)
	shaft.material_override = mat
	shaft.position = Vector3(0, height * 0.5, 0)
	root.add_child(shaft)
	for i in 4:
		var band := MeshInstance3D.new()
		band.name = "Band%d" % i
		var t := 0.28 + 0.22 * i
		band.mesh = _cyl(lerpf(radius, radius * 0.62, t) * 1.09, 1.1, 16)
		band.material_override = mats["bund"]
		band.position = Vector3(0, height * t, 0)
		root.add_child(band)
	LevelKit.prop(root, Vector3(0.0, height - 1.0, radius * 0.6),
		Vector3(0.5, 0.4, 0.3), mats["sodium"], "AviationLamp")


## Soft-edged additive sky card. Unshaded and order-independent, so no cloud
## can ever sort wrong against another as the camera slides.
static func _sky_card(tint: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.albedo_texture = _soft_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


static func _card(parent: Node3D, mat: Material, at: Vector3, size: Vector2,
		name_: String) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = q
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static var _soft_cache: ImageTexture = null

## A radial falloff in alpha, generated rather than shipped. One 64 px image
## covers every cloud and every smoke puff in the level.
static func _soft_tex() -> ImageTexture:
	if _soft_cache != null:
		return _soft_cache
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size) - 0.5
			var v := (float(y) + 0.5) / float(size) - 0.5
			var d := clampf(1.0 - Vector2(u, v).length() * 2.0, 0.0, 1.0)
			# Smoothstep twice: a linear falloff still shows its circular edge.
			d = d * d * (3.0 - 2.0 * d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, d * d))
	_soft_cache = ImageTexture.create_from_image(img)
	return _soft_cache


## Instanced scatter, chunked on X. MultiMesh has no per-instance frustum
## culling — "always or never drawn" — so a single 460-unit strip of sleepers
## would render in full behind the camera. One chunk per 96 units with an
## explicit AABB gets the culling back.
static func _scatter(parent: Node3D, name_: String, mesh: Mesh, mat: Material,
		xforms: Array[Transform3D], chunk: float) -> void:
	var groups := {}
	for xf: Transform3D in xforms:
		var key := int(floor(xf.origin.x / chunk))
		if not groups.has(key):
			var fresh: Array[Transform3D] = []
			groups[key] = fresh
		groups[key].append(xf)
	for key: int in groups:
		var list: Array[Transform3D] = groups[key]
		var mm := MultiMesh.new()
		# transform_format MUST be set before instance_count.
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		var lo := list[0].origin
		var hi := lo
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			var o := list[i].origin
			lo = Vector3(minf(lo.x, o.x), minf(lo.y, o.y), minf(lo.z, o.z))
			hi = Vector3(maxf(hi.x, o.x), maxf(hi.y, o.y), maxf(hi.z, o.z))
		var node := MultiMeshInstance3D.new()
		node.name = "%s%d" % [name_, key]
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(lo - Vector3(2, 2, 2), hi - lo + Vector3(4, 4, 4))
		parent.add_child(node)


static func _cyl(radius: float, height: float, sides := 16,
		top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


static func _ball(radius: float, segs := 12, rings := 7) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = rings
	return m
