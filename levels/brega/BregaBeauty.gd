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
## ---------------------------------------------------------------------------
## RECORDED ART-DIRECTOR DEVIATIONS FROM THE WRITTEN BRIEF
##
## 1. The brief has the cell block running the full frame width at Z = -5. At
##    that distance a 10 m block subtends more of the frame than a 71 m tower at
##    Z = -300, so it would bury every layer behind it. The block therefore runs
##    the left 55% and STOPS just past him. The left of frame is the prison he
##    is leaving; the right is the distance he has to cover.
##
## 2. The sun is IN frame, at screen x 0.88, cut into fragments by the lattice
##    of the one live flare. Previously the key sat 30 degrees off-axis, outside
##    the right edge, and all the eye got was an undifferentiated hot smear that
##    said nothing. A sun needs an occluder or it is a blob. Putting the dead
##    plant's own steelwork across it is the whole thesis of the level in one
##    object, and it costs eight degrees of azimuth.
##
## 3. There is a dark plant bank on the horizon at Z = -190 that the brief does
##    not call for. The brief's aerial perspective is correct for a side-lit
##    scene and wrong for this one: a complex backlit at 200 m reads NEAR-BLACK,
##    not pale straw. Without it the right half had no horizon line, no darkest
##    value, and nothing for the sun to rise out of.
##
## 4. The tank farm moved from Z = -75 to Z = -120 and slid right. At -75 the
##    21 m tank roofs floated over the cell block's roofline as bare grey
##    ellipses — flying saucers. They now sit under the horizon on the right,
##    which is where the frame was empty.
##
## 5. The four-layer wall is fragmented into three patches and moved off the
##    hero. As one 8.6 m saturated green rectangle directly behind his head it
##    was the second-loudest thing in the image and it fought him. Archaeology
##    is patchy by definition; a clean rectangle is a decal.
## ---------------------------------------------------------------------------
##
## Depth layers, front to back:
##   +9  razor wire, fence breach, beam    +5  chain-link fence
##    0  walkway, rail, door, sriracha     -5  cell block facade
##  -11  water tower, pole line, gantry   -14  yard floor, perimeter, windbreak
##  -20  pipe rack        -26 to -40  the plant, the live flare
## -120  tank farm       -190  the dark plant bank, the horizon line
## -300  prilling towers, dead flare stack        sky

const YARD_Y := -6.6
const DECK_Y := 0.0

## The block's front face plane. Everything bolted to the wall is referenced to
## this rather than to a magic number, because the whole left third of the frame
## is built in the 60 mm in front of it.
const FACE_Z := -2.44

var mats := {}
## Everything from the perimeter wall backwards. It is parented separately so
## the whole band can be taken out of the shadow pass in one call — see
## `_cull_background_shadows`.
var deep: Node3D


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
	# The written brief calls for authored contrapposto with the head turned
	# past the shoulders. The gameplay idle is symmetrical, which is right in
	# play and is a mannequin in a marketing frame.
	var rig := player.get_node_or_null("Rig") as WanisRig
	if rig != null:
		rig.beauty_pose = true


func _mood() -> LightingRig.Mood:
	var m := LightingRig.Mood.new()

	# Key: altitude 3.5 deg, behind and screen-right. He is back-lit for the
	# whole level and the rim is the only reason he reads at all.
	#
	# Azimuth 157.5 puts the disc 22 degrees off the view axis — screen x 0.88,
	# which is exactly where the live flare's lattice stands. The sun therefore
	# arrives broken into pieces by the plant that killed this town, instead of
	# arriving as a smear off the right edge. See deviation 2 in the header.
	m.sun_angles = Vector2(42.0, 28.0)
	m.sun_color = Color(1.0, 0.945, 0.860)      # ~5200 K, mid-morning
	m.sun_energy = 3.1
	m.sun_angular_distance = 1.1
	# A disc you can actually see is the point now that something is standing in
	# front of it. 0.34 deg was 9 px at 900 and read as a stuck highlight.
	m.sun_disc_size = 0.5
	# 3.0 with the key this close to the view axis turned the whole right half
	# into forward-scattered soup. The shafts now come from placed FogVolumes,
	# which can be aimed; a global scatter term cannot.
	m.sun_fog_energy = 0.55

	# Fill: the sabkha bounce from below-front. Cool, and deliberately weak —
	# the front of the block is in shade and it has to STAY in shade, because
	# the hero is a white thobe and he only reads if the wall behind him is a
	# value he can beat. Warm light and cool shadow is also the only thing
	# stopping this frame being one orange, and at 0.54 it was losing that
	# argument: every pixel in the first capture was the same hue. Up to 0.76
	# and pushed bluer, so the shaded wall reads COOL grey against a warm sky.
	m.fill_angles = Vector2(18.0, -28.0)
	m.fill_color = Color(0.560, 0.640, 0.800)
	m.fill_energy = 0.76

	# Rim: hero layer only. Swung round to sit with the new key azimuth, or the
	# rim lands on the wrong edge of him and reads as a second light.
	m.rim_angles = Vector2(36.0, 36.0)
	m.rim_color = Color(1.0, 0.930, 0.820)
	m.rim_energy = 9.0
	m.rim_cull_mask = 2

	m.hero_fill_energy = 2.5
	m.hero_fill_color = Color(0.72, 0.78, 0.94)
	m.hero_fill_angles = Vector2(-14.0, -30.0)

	# Near DOF in Godot blurs by distance from the camera, and the whole
	# gameplay plane sits inside any radius large enough to soften the
	# foreground. Foreground separation is done with value and scale instead.
	m.dof_near_distance = 0.0
	m.dof_distance = 0.0

	m.sky_top = Color(0.086, 0.325, 0.760)      # colder zenith; see fill note
	m.sky_horizon = Color(0.690, 0.845, 0.930)  # #C97B45
	m.ground_horizon = Color(0.780, 0.835, 0.820)
	m.ground_bottom = Color(0.300, 0.368, 0.330)
	m.sky_energy = 1.08
	m.sky_curve = 0.11
	# Halved. Volumetric density is a global and it was doing the job of eight
	# local volumes badly — everything past 30 units went to one value.
	m.volumetric_density = 0.00034
	m.ambient_energy = 0.60

	m.fog_color = Color(0.835, 0.804, 0.741)
	m.fog_density = 0.00026
	# 0.35 puts a hot bloom on everything within 40 degrees of the key and the
	# whole right of frame goes to white paper.
	m.fog_sun_scatter = 0.10
	m.fog_emission = Color(0.06, 0.045, 0.035)
	# 0.78 forward-scatters almost everything straight down the lens at this
	# key azimuth. 0.70 still forms shafts and stops the glare.
	m.fog_anisotropy = 0.70

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
	m.adjustment_saturation = 1.40
	m.adjustment_contrast = 1.10
	return m


## The benchmark frame is 40% sky. A ProceduralSkyMaterial gradient is the one
## thing in it that could never pass as a photograph of that coast.
## SkyForge reads the scene's own key light, so the disc, the warm band round
## it and the aerial haze all land wherever the rig aimed the sun — the sky and
## the lighting cannot drift apart.
func _sky_preset() -> String:
	return "brega_morning"


func _build_level() -> void:
	_palette()
	_grade()
	deep = Node3D.new()
	deep.name = "Background"
	geometry.add_child(deep)
	_layer_sky_and_sea()
	_layer_far_bank()
	_layer_horizon()
	_layer_tank_farm()
	_layer_mid_yard()
	_layer_pipe_rack()
	_layer_bridge()
	_layer_plant()
	_layer_flare()
	_layer_facade()
	_layer_gameplay()
	_layer_foreground()
	_atmosphere()
	_practicals()
	_cull_background_shadows(deep)


## The key sits at 3.5 degrees, so every background object throws a shadow more
## than a hundred metres long toward camera-left — and every one of those
## shadows lands inside the cell block's own, because the block is 10 m of solid
## concrete between the sun and everything in front of it. They are invisible
## and they are the largest single item in the frame's cost. Off.
##
## Shadow casting stays ON for the block, the walkway and the foreground, which
## are the three things whose shadows the camera can actually see.
func _cull_background_shadows(node: Node) -> void:
	var gi := node as GeometryInstance3D
	if gi != null:
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_cull_background_shadows(child)


## Grade knobs LightingRig.Mood does not expose. Stage builds the environment
## before _build_level, so this runs on a live Environment.
func _grade() -> void:
	var env := world_env.environment
	# One blown pixel on the sun disc flooding the glow buffer is the single
	# fastest way to lose a backlit frame. The default cap is 12.
	env.glow_hdr_luminance_cap = 4.0
	# Aerial perspective tints geometry toward the sky. At 0.16 the far bank
	# still reads dark; above about 0.3 the horizon dissolves again.
	env.fog_aerial_perspective = 0.18
	# SSAO at 2.2 was painting dirt into every corner of a scene that is
	# already almost all shadow. Contact darkening only.
	env.ssao_intensity = 1.5
	env.ssao_horizon = 0.10
	# SSIL bounces the orange sky onto the shaded wall, which is exactly the
	# warm/cool split this frame is built on — but at 0.9 it was neutralising
	# the cool fill faster than the fill could put it there.
	env.ssil_intensity = 0.55


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
		# Fire: the only near-black albedo allowed on the wall. It is the
		# block's one large-scale value incident and it has to hold up against
		# a wall that the cool fill is lifting.
		"scorch": MaterialLab.concrete(Color(0.042, 0.036, 0.034), 1.0),
		# The dark plant bank on the horizon. Not black: after 200 units of
		# depth fog it lands around 25% value, which is the darkest thing in
		# the right half and therefore the thing that makes the rest read.
		"bank": MaterialLab.plaster(Color(0.098, 0.092, 0.090), 1.0),
		# Prison bedding. Pale enough to read as cloth against a shaded wall,
		# nowhere near the thobe once the hero fill and rim are on him.
		"sheet": MaterialLab.cloth(Color(0.600, 0.575, 0.520), 0.95),
	}
	# Salt spalling: grime creeps up from the yard floor, not from y=0.
	for key: String in ["slab", "wall", "deck"]:
		mats[key].set_shader_parameter("grime_origin_y", YARD_Y)
		mats[key].set_shader_parameter("grime_falloff", 1.9)
		mats[key].set_shader_parameter("grime_color", Color(0.29, 0.25, 0.20))
		mats[key].set_shader_parameter("grime_amount", 0.55)


## A cylinder. PropKit keeps its own private one; this file needs enough of
## them (stacks, cowls, tank legs, rope knots) to be worth two lines.
func _tube(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material, name_ := "Tube", top_radius := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = 14
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Layer 0-2: sky, sea, horizon ------------------------------------------

func _layer_sky_and_sea() -> void:
	# The Gulf of Sidra, a thin band in the gap between the towers. Flat coast:
	# no cliffs, no hills, and that flatness is the point.
	var sea := MaterialLab.emissive(Color(0.180, 0.620, 0.820), 0.30)
	sea.roughness = 0.12
	sea.metallic = 0.4
	LevelKit.prop(geometry, Vector3(120.0, -2.0, -150.0), Vector3(700.0, 6.0, 1.0),
		sea, "Sea")
	# Sabkha plain running flat to the horizon, blinding pale.
	LevelKit.prop(geometry, Vector3(40.0, -9.5, -150.0), Vector3(900.0, 5.0, 220.0),
		mats["sabkha"], "SabkhaPlain")
	# The bleached straw aerosol band above the horizon glow — Saharan dust,
	# thicker than any temperate sky would carry. Pulled down and thinned: at
	# 34 units tall it was a grey ceiling over the top third of the sky and it
	# was the reason the zenith never read as pre-dawn blue.
	var haze := MaterialLab.emissive(Color(0.870, 0.925, 0.960), 0.45)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = Color(0.870, 0.925, 0.960, 0.28)
	LevelKit.prop(geometry, Vector3(60.0, 9.0, -420.0), Vector3(1400.0, 20.0, 1.0),
		haze, "DustBand")

	# A thin cloud deck catching the first light, well above the dust band. Two
	# long shallow slabs at different heights, so the sky is not a bare ramp —
	# an empty gradient is what makes a sky read as a Godot default.
	var cloud := MaterialLab.emissive(Color(0.99, 0.99, 1.00), 0.70)
	cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud.albedo_color = Color(0.99, 0.99, 1.00, 0.34)
	for spec: Array in [[40.0, 58.0, 380.0, 6.0], [200.0, 84.0, 300.0, 4.2],
			[-140.0, 44.0, 260.0, 3.4]]:
		LevelKit.prop(geometry, Vector3(spec[0], spec[1], -430.0),
			Vector3(spec[2], spec[3], 1.0), cloud, "CloudDeck")


## The horizon itself: the fertiliser complex as one long dark bank at Z -190.
##
## The frame had no horizon line at all. Everything past the perimeter wall was
## the same warm value, the sun had nothing to rise out of, and the right half
## had no darkest note — so it had no value structure, only a hue. This bank is
## the darkest thing on the right, it puts a hard edge under the sun, and it is
## the line the hero's head is supposed to break.
func _layer_far_bank() -> void:
	var z := -190.0
	# Sheds and process halls, a skyline of stepped rectangles. Widths and
	# heights deliberately irregular: an even rhythm at this scale reads as a
	# fence, and the eye is very good at spotting a repeat on a horizon.
	var spec := [
		[-30.0, 34.0, 7.0], [10.0, 22.0, 11.5], [36.0, 40.0, 8.0],
		[80.0, 18.0, 13.0], [102.0, 30.0, 9.0], [138.0, 26.0, 15.0],
		[170.0, 44.0, 7.5], [220.0, 30.0, 11.0], [258.0, 52.0, 8.5],
	]
	for s: Array in spec:
		var x: float = s[0]
		var w: float = s[1]
		var h: float = s[2]
		var b := LevelKit.prop(geometry, Vector3(x + w * 0.5, -6.0 + h * 0.5, z),
			Vector3(w, h, 3.0), mats["bank"], "BankHall")
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Stacks and columns rising out of it. A flat-topped bank is a wall; the
	# verticals are what make it a plant, and they are what the pale sky gets
	# to cut into.
	for s: Array in [[-14.0, 26.0, 1.5], [24.0, 34.0, 1.1], [52.0, 21.0, 1.6],
			[92.0, 30.0, 1.2], [118.0, 24.0, 1.8], [156.0, 38.0, 1.3],
			[198.0, 27.0, 1.5], [244.0, 33.0, 1.1]]:
		var t := _tube(geometry, Vector3(s[0], -6.0 + float(s[1]) * 0.5, z),
			s[2], s[1], mats["bank"], "BankStack", float(s[2]) * 0.78)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A cooling-tower hyperboloid, because every big plant has one and it is the
	# only curved silhouette on an otherwise orthogonal skyline.
	for i in 3:
		var ct := _tube(geometry, Vector3(64.0, -6.0 + 7.0 - i * 3.0, z - 4.0),
			9.0 - i * 2.4, 7.0, mats["bank"], "CoolingTower", 6.2 - i * 1.4)
		ct.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	# Pushed from Z -75 to -120 and started at x = 6. See deviation 4: at -75
	# the roofs read as bare ellipses floating above the cell block, and they
	# were the first thing in the top-left corner. They now sit low and right,
	# under the horizon bank, which is where the frame needed mass.
	var xs := [6.0, 44.0, 82.0, 120.0, 158.0, 196.0]
	for i in xs.size():
		var burnt := i == 1   # the burnt tank sits near the golden section
		var t := PropKit.storage_tank(geometry,
			Vector3(xs[i], -8.0, -120.0 - (i % 2) * 18.0), 16.0, 21.0,
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

	# The opposite block, partly hidden behind the near one. Its own value step,
	# darker than the tank farm behind it — it is the mid tone that the eye
	# needs between the near-black cell block and the lit plain.
	PropKit.prefab_facade(geometry, 13.0, YARD_Y, 72.0, 8.4, -32.0,
		MaterialLab.plaster(Color(0.235, 0.222, 0.200), 1.0), {
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

	# EVIDENCE: a ladder left against the perimeter wall, half a metre short of
	# the top. Somebody already tried this and it did not work. It is a 23 px
	# diagonal at 32 units and it is the cheapest story beat in the frame.
	var ladder := Node3D.new()
	ladder.name = "FailedLadder"
	ladder.position = Vector3(16.5, YARD_Y, -15.2)
	ladder.rotation.z = deg_to_rad(11.0)
	geometry.add_child(ladder)
	for side: float in [-0.20, 0.20]:
		LevelKit.prop(ladder, Vector3(side, 1.85, 0.0), Vector3(0.07, 3.7, 0.07),
			mats["rust"], "Stile")
	for i in 8:
		LevelKit.prop(ladder, Vector3(0.0, 0.35 + i * 0.44, 0.0),
			Vector3(0.42, 0.045, 0.045), mats["rust"], "Rung%d" % i)

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
	# that says this is a prison and not a works yard. Its cab was painted in
	# mats["wall"] and read as the same value as the haze behind it; on a
	# back-lit object at 34 units the only honest value is near-black.
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
		mats["dark"], "TowerCab")
	LevelKit.prop(geometry, Vector3(tx, YARD_Y + 8.2, tz + 1.36), Vector3(2.3, 0.75, 0.06),
		mats["dark"], "TowerGlass")
	var roof := LevelKit.prop(geometry, Vector3(tx, YARD_Y + 8.7, tz),
		Vector3(3.6, 0.12, 3.6), MaterialLab.corrugated(Color(0.13, 0.125, 0.118), 18.0),
		"TowerRoof")
	roof.rotation.x = 0.05
	# A searchlight on the cab corner, dead, aimed at nothing.
	_tube(geometry, Vector3(tx + 1.5, YARD_Y + 8.4, tz + 0.6), 0.34, 0.5,
		mats["dark"], "Searchlight").rotation = Vector3(deg_to_rad(74.0), 0.0, 0.0)

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


## Enters upper-right and runs down-left on a shallow diagonal, pointing at him.
##
## PropKit.pipe_rack drops its sleepers 1.2 m below the run, which is right for
## a rack lying on the ground and leaves them hanging in mid-air for an elevated
## one — the first capture had a row of blocks floating in the sky. This builds
## the elevated version with real trestles standing on the yard floor, and
## carries three pipes rather than five, because five parallel bars across the
## top-right corner were the loudest graphic in the image.
func _layer_pipe_rack() -> void:
	# Z -26, entering at the right edge around screen y 0.07 and running down to
	# (0.74, 0.27). The canon asks for a 14 degree diagonal pointing at him and
	# that is what this is; at Z -20 it crossed the entire sky instead and was
	# the loudest graphic in the picture.
	var z := -26.0
	var from := Vector3(56.0, 26.0, z)
	var to := Vector3(16.0, 9.5, z)
	var root := Node3D.new()
	root.name = "ElevatedRack"
	geometry.add_child(root)

	var delta := to - from
	var length := delta.length()
	var dir := delta / length
	var ang := atan2(dir.y, dir.x)
	for i in 3:
		var off := Vector3(0.0, 0.30 + i * 0.34, (float(i) - 1.0) * 0.55)
		var pipe := _tube(root, (from + to) * 0.5 + off, 0.15 + 0.04 * (i % 2),
			length, mats["rust"], "Pipe%d" % i)
		pipe.rotation.z = ang - PI * 0.5
	# The walkway grating alongside the pipes, dark, so the run reads as a
	# structure with a top and a bottom rather than as three drawn lines.
	var walk := LevelKit.prop(root, (from + to) * 0.5 + Vector3(0.0, -0.22, 0.0),
		Vector3(length, 0.14, 2.2), mats["steel"], "RackGrating")
	walk.rotation.z = ang

	# The transfer tower the run terminates in. Pipes have to arrive somewhere;
	# a diagonal that stops in mid-air is a drawn line, and this also gives the
	# right half one more slender dark vertical to step down through.
	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		LevelKit.prop(root, Vector3(to.x + sx * 1.1, YARD_Y + 8.8,
			z + sz * 1.1), Vector3(0.22, 17.6, 0.22), mats["steel"], "TransferLeg%d" % i)
	for i in 6:
		LevelKit.prop(root, Vector3(to.x, YARD_Y + 1.2 + i * 1.95, z),
			Vector3(2.4, 0.13, 2.4), mats["steel"], "TransferBand%d" % i)
	LevelKit.prop(root, Vector3(to.x, YARD_Y + 17.9, z), Vector3(3.2, 0.9, 3.0),
		mats["bund"], "TransferHead")

	# Trestles down to the yard. The verticals are what break the three bars up
	# and what tie the rack to the ground instead of letting it float.
	var bays := 5
	for i in bays:   ## the last bay lands inside the transfer tower
		var t := float(i) / float(bays)
		var p := from + delta * t
		var drop := p.y - YARD_Y
		for side: float in [-0.9, 0.9]:
			LevelKit.prop(root, Vector3(p.x + side * 0.3, YARD_Y + drop * 0.5, z + side),
				Vector3(0.20, drop, 0.20), mats["steel"], "Trestle")
		LevelKit.prop(root, Vector3(p.x, YARD_Y + drop - 0.5, z),
			Vector3(2.4, 0.16, 0.16), mats["steel"], "TrestleCap")
		# Cross brace, so the trestle is a frame and not two sticks.
		var br := LevelKit.prop(root, Vector3(p.x, YARD_Y + drop * 0.5, z),
			Vector3(0.10, sqrt(drop * drop + 2.2 * 2.2), 0.10), mats["steel"], "Brace")
		br.rotation.z = atan2(1.9, drop)


# --- Layer 5: the cell block facade ----------------------------------------

## Layer -26 to -40: the plant itself.
##
## Two fifths of this frame was empty haze with a sun in it. This is what fills
## it: columns with platform rings and caged ladders, a horizontal vessel on
## saddles, and drum stacks on the yard floor. Distance is carried by value
## steps between the layers, not by piling on more fog — fog flattens
## everything to the same paper white, which is exactly what it had done.
func _layer_plant() -> void:
	# Its own value step, darker than the tank farm behind it. Layer separation
	# in a backlit frame comes from the materials, not from more fog — fog puts
	# every layer on the same sheet of paper. Driven a further 30% down after
	# the first capture, where this band was indistinguishable from the haze.
	var shell := MaterialLab.plaster(Color(0.168, 0.160, 0.148), 1.0)
	var frame: Material = mats["steel"]

	PropKit.column(geometry, Vector3(19.0, YARD_Y, -33.0), 15.5, 1.5,
		shell, frame, 4)
	PropKit.column(geometry, Vector3(26.5, YARD_Y, -36.0), 20.5, 1.8,
		shell, frame, 5)
	PropKit.column(geometry, Vector3(32.0, YARD_Y, -31.0), 11.0, 1.2,
		shell, frame, 3)
	PropKit.column(geometry, Vector3(44.0, YARD_Y, -38.0), 17.0, 1.6,
		shell, frame, 4)

	PropKit.vessel(geometry, Vector3(13.0, YARD_Y + 3.2, -27.0), 11.0, 1.5,
		shell, mats["bund"])
	PropKit.vessel(geometry, Vector3(37.0, YARD_Y + 2.6, -25.0), 8.0, 1.2,
		shell, mats["bund"])

	# A stair tower: diagonals against all those verticals.
	var tz := -29.0
	for i in 8:
		LevelKit.prop(geometry, Vector3(8.4 + (i % 2) * 2.0, YARD_Y + 0.9 + i * 1.35, tz),
			Vector3(2.6, 0.16, 1.5), frame, "Flight%d" % i).rotation.z = \
			deg_to_rad(-31.0 if i % 2 == 0 else 31.0)
		LevelKit.prop(geometry, Vector3(9.4, YARD_Y + 1.6 + i * 1.35, tz),
			Vector3(3.6, 0.10, 1.6), frame, "Landing%d" % i)
	for i in 4:
		LevelKit.prop(geometry, Vector3(7.7 + (i % 2) * 3.4, YARD_Y + 5.6, tz + (i / 2) * 1.4),
			Vector3(0.20, 11.2, 0.20), frame, "TowerLegB%d" % i)

	PropKit.drum_stack(geometry, Vector3(15.0, YARD_Y, -21.0), 6, 3, mats["rust"])
	PropKit.drum_stack(geometry, Vector3(30.0, YARD_Y, -19.5), 4, 2, mats["rust"])
	PropKit.drum_stack(geometry, Vector3(40.5, YARD_Y, -23.0), 5, 3, mats["rust"])

	# Pipe runs on sleepers, walking off to the right along the ground.
	for i in 3:
		LevelKit.prop(geometry, Vector3(34.0, YARD_Y + 0.9 + i * 0.42, -20.0),
			Vector3(52.0, 0.26, 0.26), frame, "GroundPipe%d" % i)
	for i in 9:
		LevelKit.prop(geometry, Vector3(10.0 + i * 5.6, YARD_Y + 0.45, -20.0),
			Vector3(0.7, 0.9, 1.4), mats["bund"], "Sleeper%d" % i)


## The one thing burning in a plant that stopped running, and now also the thing
## standing in front of the sun.
##
## Moved from Z -52 to -30 so its lattice lands on the sun's screen position at
## x 0.88. The bands sit 1.4 m apart, which at 46 units is one hard dark line
## across a 32 px disc — a sun with a girder through it, not a smear. Height is
## set by where the flame tip has to land: 20 m puts it at screen y 0.08, inside
## the top edge; at 26 m the one thing burning in this frame was cropped off.
##
## The glow that went with it was an OmniLight at energy 28 with a volumetric
## term of 4.0 injecting into a 90-unit fog volume — that single light was the
## "bright blob" that owned the whole right half of the first capture. A flare
## tip is small and hot, not large and soft.
func _layer_flare() -> void:
	var base := Vector3(22.2, YARD_Y - 1.0, -30.0)
	PropKit.flare_stack(geometry, base, 20.0, 4.4, mats["steel"])

	var tip := base + Vector3(0.0, 20.2, 0.0)
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
	glow.light_energy = 6.5
	glow.omni_range = 14.0
	glow.light_volumetric_fog_energy = 1.0
	glow.shadow_enabled = false
	glow.position = tip + Vector3(0.0, 1.6, 0.0)
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
	# Darkened: the plume now passes directly across the sun, and at the old
	# alpha it was a grey veil over the one bright thing in the frame.
	ramp.set_color(0, Color(0.22, 0.15, 0.12, 0.52))
	ramp.set_color(1, Color(0.26, 0.22, 0.21, 0.0))
	ramp.add_point(0.16, Color(0.28, 0.19, 0.14, 0.46))
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


## Layer -11 to -17: the middle ground.
##
## The recorded failure of this frame was that it split into a dark building on
## the left and a bright haze on the right with nothing between them. This is
## the between: a pole line and a conveyor gantry that both start behind the
## block and walk out into the light, plus — new after the first capture — a
## water tower standing at screen x 0.71 whose head reaches almost to the cell
## block's roofline. The seam at x 0.58 was still an edge because nothing tall
## stood on the bright side of it. Now something does, and the eye steps across
## on it instead of falling off it.
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

	_water_tower()


## The bridge across the value seam. A four-leg lattice tower at x 10, Z -11:
## on screen it stands at x 0.71 and its head reaches y 0.38, which is within a
## few percent of the cell block's roofline. That parity is the whole point —
## the left mass now has an answering vertical on the bright side, and the
## horizon line runs between the two instead of stopping dead at the block.
func _water_tower() -> void:
	var root := Node3D.new()
	root.name = "WaterTower"
	root.position = Vector3(10.0, YARD_Y, -11.0)
	geometry.add_child(root)
	var steel: Material = mats["steel"]

	var h := 8.6   # to the underside of the tank
	for i in 4:
		var sx := -1.25 if i < 2 else 1.25
		var sz := -1.25 if i % 2 == 0 else 1.25
		var leg := LevelKit.prop(root, Vector3(sx * 0.72, h * 0.5, sz),
			Vector3(0.19, h, 0.19), steel, "Leg%d" % i)
		# Legs splay: a four-post tower with parallel legs reads as a table.
		leg.rotation.z = -sign(sx) * 0.055
	for i in 3:
		var ly := 2.2 + i * 2.4
		LevelKit.prop(root, Vector3(0.0, ly, -1.25), Vector3(3.0, 0.11, 0.11),
			steel, "Girt%d" % i)
		for d: float in [-1.0, 1.0]:
			var br := LevelKit.prop(root, Vector3(0.0, ly + 1.2, -1.25),
				Vector3(0.09, 3.1, 0.09), steel, "XBrace")
			br.rotation.z = d * 0.72
	# Tank: a cylinder with a conical bottom, which is what makes it a water
	# tower rather than a drum on stilts.
	_tube(root, Vector3(0.0, h + 0.55, 0.0), 0.85, 1.1, mats["dark"], "TankCone", 1.9)
	_tube(root, Vector3(0.0, h + 2.0, 0.0), 1.9, 1.9, mats["dark"], "TankShell")
	_tube(root, Vector3(0.0, h + 3.1, 0.0), 1.95, 0.4, mats["dark"], "TankRoof", 0.55)
	LevelKit.prop(root, Vector3(0.0, h + 3.6, 0.0), Vector3(0.09, 0.9, 0.09),
		steel, "Vent")
	# Caged ladder up one leg — the detail that gives a distant silhouette scale.
	for i in 11:
		LevelKit.prop(root, Vector3(0.95, 0.6 + i * 0.8, 1.2),
			Vector3(0.36, 0.05, 0.05), steel, "Rung%d" % i)
	# The riser, and a delivery main running off toward the block, so the tower
	# belongs to something instead of standing on its own.
	LevelKit.prop(root, Vector3(1.05, h * 0.5, 1.1), Vector3(0.13, h, 0.13),
		steel, "Riser")
	LevelKit.prop(root, Vector3(-6.0, 0.9, 1.1), Vector3(13.0, 0.17, 0.17),
		mats["rust"], "Main")


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
	bounce.position = Vector3(-28.5, YARD_Y + 2.7, FACE_Z)
	facade.add_child(bounce)

	var skylit := MeshInstance3D.new()
	skylit.name = "SkyBounce"
	var sq := QuadMesh.new()
	sq.size = Vector2(67.0, 4.6)
	skylit.mesh = sq
	skylit.material_override = PropKit.gradient_decal(
		Color(0.30, 0.42, 0.70), 0.34, "streak")
	skylit.position = Vector3(-28.5, YARD_Y + 8.3, FACE_Z)
	facade.add_child(skylit)

	# Everything bolted to the front of a wall that has been in use for fifty
	# years. The face is in shade, so none of its detail can come from light —
	# it all has to stand off the wall and read as silhouette.
	PropKit.wall_services(facade, -60.0, YARD_Y, 64.0, 10.4, -2.46,
		mats["rust"], mats["steel"], 5)

	_facade_massing(facade)
	_service_tower(facade)
	_scorched_bay(facade)
	_collapsed_corner(facade)
	_roofline(facade)

	# Four lights still on in a block that is supposed to be empty. They are
	# the only warm accent the shadow side of this building gets, and the only
	# thing in frame that says somebody is awake at this hour. Sizes and
	# energies deliberately unequal — three identical glowing tiles read as a
	# texture, four unequal ones read as rooms.
	for spec: Array in [
			[-5.6, YARD_Y + 8.55, Vector2(0.66, 0.92), 1.7],
			[2.35, YARD_Y + 8.55, Vector2(0.66, 0.92), 1.1],
			[-15.2, YARD_Y + 5.15, Vector2(0.62, 0.86), 1.5],
			[-2.9, YARD_Y + 5.15, Vector2(0.58, 0.74), 0.7],
		]:
		PropKit.lit_window(facade, Vector3(spec[0], spec[1], -2.40), spec[2],
			mats["joint"], Color(1.0, 0.68, 0.32), spec[3])

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

	_four_layer_wall(facade)
	_bedsheet_rope(facade)

	# A water-stained panel run directly behind him. Local contrast, placed:
	# staggered across three panels of different ages so it does not read as one
	# rectangle, and kept to the 1.6 m either side of him that his silhouette
	# actually crosses.
	var stain_spec := [
		[-1.1, 6.6, 2.6, Color(0.268, 0.249, 0.219)],
		[0.6, 7.4, 3.2, Color(0.232, 0.216, 0.190)],
		[-2.6, 6.2, 2.2, Color(0.296, 0.277, 0.246)],
	]
	for spec: Array in stain_spec:
		LevelKit.prop(facade, Vector3(spec[0], YARD_Y + spec[1], -2.42),
			Vector3(2.10, spec[2], 0.05), MaterialLab.plaster(spec[3], 1.0), "Stain")
	for i in 6:
		LevelKit.prop(facade, Vector3(-2.6 + i * 1.42, YARD_Y + 5.6 + fmod(float(i) * 1.7, 1.4),
			-2.40), Vector3(0.16, 2.0 + fmod(float(i) * 2.3, 1.8), 0.05),
			mats["rust"], "RustBleed%d" % i)

	_ground_floor(facade)


## Massing: the horizontal bands that stop 11 m of prefab wall being one plane.
##
## Two string courses and a cornice, each a few centimetres of projection, each
## buying a hard shadow line the full width of the block. At this distance that
## is worth more than any amount of surface texture, and it is what splits the
## wall into three stacked bands the eye can measure the building by.
func _facade_massing(facade: Node3D) -> void:
	for spec: Array in [[3.9, 0.22, 0.30], [7.2, 0.16, 0.22]]:
		LevelKit.prop(facade, Vector3(-28.5, YARD_Y + float(spec[0]), FACE_Z + 0.08),
			Vector3(67.0, spec[1], spec[2]), mats["joint"], "StringCourse")
	# Cornice: the deepest projection on the building and the one that separates
	# roof from wall.
	LevelKit.prop(facade, Vector3(-28.5, YARD_Y + 10.35, FACE_Z + 0.22),
		Vector3(67.2, 0.26, 0.52), mats["joint"], "Cornice")
	# Plinth: the block stands on something. Without it the wall grows out of
	# the ground like a card pushed into sand.
	LevelKit.prop(facade, Vector3(-28.5, YARD_Y + 0.34, FACE_Z + 0.18),
		Vector3(67.3, 0.68, 0.40), mats["joint"], "Plinth")


## The projecting service and stair bay at the far left of the visible wall,
## screen x 0.00–0.08.
##
## The left edge of the frame was a flat plane running off the side of the
## image with nothing to stop it. This is the stop: a 1.7 m bay standing 0.9 m
## proud of the face, running past the parapet and carrying a louvred extract
## head. It is the tallest thing on the block, it closes the left edge, and its
## return catches the cool fill at a different angle to the main face — which is
## the only way a wall in permanent shade gets two values out of one light.
func _service_tower(facade: Node3D) -> void:
	var x := -6.0
	var w := 1.7
	var front := FACE_Z + 0.9
	LevelKit.prop(facade, Vector3(x, YARD_Y + 6.4, front - 0.45),
		Vector3(w, 12.8, 1.9), mats["slab"], "ServiceBay")
	LevelKit.prop(facade, Vector3(x, YARD_Y + 12.95, front - 0.45),
		Vector3(w + 0.34, 0.30, 2.2), mats["joint"], "ServiceCap")
	# Louvred extract head: six blades, because a plain box on top is a chimney
	# and the blades are what say "plant room".
	for i in 6:
		LevelKit.prop(facade, Vector3(x, YARD_Y + 11.3 + i * 0.26, front + 0.52),
			Vector3(w - 0.3, 0.11, 0.10), mats["steel"], "Louvre%d" % i)
	# A vertical conduit bundle up the return face, so the bay's edge is not a
	# clean line — nothing on this block is a clean line.
	for i in 2:
		LevelKit.prop(facade, Vector3(x + w * 0.5 + 0.06, YARD_Y + 6.0, front + 0.1 - i * 0.24),
			Vector3(0.10, 11.4, 0.10), mats["rust"], "BayConduit%d" % i)
	# EVIDENCE OF LIFE: washing on a line strung off the top of the bay. It goes
	# on the ROOF, not on the wall — up there it is cloth silhouetted against
	# the one bright surface in the left half of the frame, which is worth far
	# more than the same cloth lost against a wall in shade, and it breaks the
	# roofline a third time. Muted on purpose: the chroma law gives the
	# saturated end of the palette to the hero and the Sriracha.
	PropKit.laundry_line(facade, Vector3(x + 0.85, YARD_Y + 12.4, FACE_Z - 0.9),
		Vector3(x + 2.9, YARD_Y + 12.1, FACE_Z - 0.9), 0.30, mats["dark"],
		[Color(0.30, 0.36, 0.43), Color(0.55, 0.52, 0.45), Color(0.46, 0.35, 0.22)], 17)


## THE FIRE. Screen x 0.36–0.50, running from just above the walkway to the
## roofline — the block's one large-scale value incident.
##
## At this distance the cell block was a single mid-grey rectangle with a green
## sign on it. Nothing on a wall in permanent shade can be brightened without
## lying about where the key is, so the incident has to go the other way: a bay
## burnt out to near-black, the parapet gone over it, one window blown and a
## soot fan above it. It reads at 25% scale, it reads in a thumbnail, and it
## puts the darkest value in the left half immediately beside the brightest
## thing in the frame.
func _scorched_bay(facade: Node3D) -> void:
	var x0 := 1.2
	var w := 2.3
	var cx := x0 + w * 0.5
	# The burnt face itself, standing 30 mm proud so it casts its own edge.
	LevelKit.prop(facade, Vector3(cx, YARD_Y + 6.6, FACE_Z + 0.03),
		Vector3(w, 7.4, 0.06), mats["scorch"], "BurntFace")
	# Soot does not stop at the panel joint. A soft fan spreading up and out of
	# the bay is what makes it read as fire damage rather than as paint.
	var fan := MeshInstance3D.new()
	fan.name = "SootFan"
	var fq := QuadMesh.new()
	fq.size = Vector2(w + 3.4, 5.2)
	fan.mesh = fq
	fan.material_override = PropKit.gradient_decal(Color(0.03, 0.026, 0.024), 0.92, "band")
	# Clear of the burnt slab's own 60 mm, or the two z-fight.
	fan.position = Vector3(cx, YARD_Y + 7.4, FACE_Z + 0.12)
	facade.add_child(fan)

	# The blown window: no glass, no shutter, a void with a heat-buckled frame
	# hanging off one hinge. The one hard-edged hole in the wall.
	LevelKit.prop(facade, Vector3(cx, YARD_Y + 5.2, FACE_Z + 0.02),
		Vector3(1.15, 1.45, 0.05), mats["dark"], "BlownVoid")
	LevelKit.prop(facade, Vector3(cx, YARD_Y + 5.98, FACE_Z + 0.16),
		Vector3(1.55, 0.14, 0.30), mats["steel"], "BlownLintel")
	var flap := LevelKit.prop(facade, Vector3(cx + 0.95, YARD_Y + 5.0, FACE_Z + 0.22),
		Vector3(0.55, 1.30, 0.04), mats["scorch"], "BuckledShutter")
	flap.rotation = Vector3(0.0, -1.15, 0.13)

	# Fire follows the openings upward. A second, smaller void above, and the
	# streaks off both of them.
	LevelKit.prop(facade, Vector3(cx - 0.3, YARD_Y + 8.0, FACE_Z + 0.02),
		Vector3(0.95, 1.15, 0.05), mats["dark"], "BlownVoidUpper")
	for i in 5:
		LevelKit.prop(facade, Vector3(x0 + 0.3 + i * 0.45,
			YARD_Y + 9.2 + fmod(float(i) * 1.9, 0.9), FACE_Z + 0.07),
			Vector3(0.20, 1.8 + fmod(float(i) * 2.7, 1.2), 0.04),
			mats["scorch"], "SootRun%d" % i)


## Where the block stops, and it stops badly. Screen x 0.50–0.585.
##
## The composition note has the eye running along the rail, falling off the
## broken post and out into the yard. That beat needs the building to end on a
## broken edge rather than a square corner, or the eye hits a vertical and stops
## dead. Two panel rows are gone, the floor slabs behind them have pancaked, and
## the rebar that used to tie them together is hanging out of the break.
func _collapsed_corner(facade: Node3D) -> void:
	# The bite out of the top corner: a near-black wedge where the panels went.
	# It reads as absence because everything around it carries the cornice line
	# and it does not.
	LevelKit.prop(facade, Vector3(4.05, YARD_Y + 9.55, FACE_Z - 0.12),
		Vector3(2.0, 2.3, 0.55), mats["scorch"], "CornerVoid")
	# Pancaked floor slabs inside the break, each one tilted a little further.
	for i in 3:
		var s := LevelKit.prop(facade, Vector3(4.2 - i * 0.18,
			YARD_Y + 8.75 + i * 0.62, FACE_Z - 0.35),
			Vector3(1.9 - i * 0.22, 0.20, 1.4), mats["joint"], "PancakedSlab%d" % i)
		s.rotation.z = deg_to_rad(-6.0 - i * 4.5)
	# Rebar hanging out of the break, bent down by its own weight.
	for i in 6:
		var bar := LevelKit.prop(facade, Vector3(3.3 + i * 0.30,
			YARD_Y + 10.0 - fmod(float(i) * 0.37, 0.5), FACE_Z + 0.05),
			Vector3(0.035, 1.0 + fmod(float(i) * 0.53, 0.8), 0.035),
			mats["rebar"], "HangingRebar%d" % i)
		bar.rotation.z = deg_to_rad(18.0 + fmod(float(i) * 23.0, 40.0))
	# What came down is still at the foot of the wall. Rubble under a break is
	# the difference between damage and a drawn shape.
	for i in 7:
		var r := LevelKit.prop(facade, Vector3(3.0 + fmod(float(i) * 1.7, 2.6),
			YARD_Y + 0.22 + fmod(float(i) * 0.9, 0.55), FACE_Z + 0.55 + fmod(float(i) * 0.4, 0.7)),
			Vector3(0.9 + fmod(float(i) * 0.7, 0.8), 0.32, 0.8), mats["joint"], "Rubble%d" % i)
		r.rotation = Vector3(0.0, fmod(float(i) * 1.1, 1.4), deg_to_rad(fmod(float(i) * 31.0, 22.0) - 11.0))


## The roofline. It was a dead-straight horizontal running the full left half of
## the frame, which is the single clearest tell that a building is a box.
##
## A parapet run with two deliberate notches in it — one over the fire, one
## where the corner came down — plus a stair head, an extract stack and the
## service bay above, gives the top edge four different heights. That stepped
## edge is what the pale sky gets to cut into, and it is free.
func _roofline(facade: Node3D) -> void:
	var top := YARD_Y + 10.6
	# Parapet in segments. The gaps are the point.
	for seg: Array in [[-62.0, 55.0], [-6.6, 7.6], [1.1, 0.0], [3.4, 0.9]]:
		var w: float = seg[1]
		if w <= 0.0:
			continue
		LevelKit.prop(facade, Vector3(float(seg[0]) + w * 0.5, top + 0.30, FACE_Z - 0.05),
			Vector3(w, 0.60, 0.42), mats["slab"], "Parapet")
		LevelKit.prop(facade, Vector3(float(seg[0]) + w * 0.5, top + 0.64, FACE_Z - 0.05),
			Vector3(w, 0.10, 0.56), mats["joint"], "ParapetCap")

	# The stair head: the one person-sized object on a roof, and therefore the
	# thing that tells you how big everything else is.
	PropKit.stair_head(facade, Vector3(-1.4, top, -4.4),
		mats["slab"], mats["door"], mats["joint"])
	# Extract stack with a cowl, breaking the sky at a third height. It stands
	# over the burnt bay, which is where the fire went out through the roof.
	_tube(facade, Vector3(1.9, top + 1.3, -4.0), 0.28, 2.6, mats["dark"], "ExtractStack")
	_tube(facade, Vector3(1.9, top + 2.75, -4.0), 0.50, 0.30, mats["dark"], "Cowl", 0.28)
	# A guy wire off the stack. One catenary crossing the sky is what stops the
	# top of the frame being four unrelated objects on a flat line.
	PropKit.cable(facade, Vector3(1.9, top + 2.5, -4.0),
		Vector3(-4.6, top + 0.5, -3.4), 0.55, mats["dark"], 10, 0.045)
	# Roof tanks and aerials behind the parapet.
	PropKit.roof_clutter(facade, -60.0, top + 0.10, 64.0, -4.6, mats["dark"], 13)
	# Split sandbags on the parapet, where somebody stood watch.
	PropKit.sandbag_row(facade, -12.0, top + 0.62, 9.0, -3.2, mats["bag"], 2)


## The four-layer wall: regime green, a slogan, a crossing-out, a tricolour.
##
## Three fragments, not one field. As a single 8.6 m rectangle directly behind
## his head it was the second-loudest thing in the frame and it fought the hero
## for the eye. Archaeology is patchy by definition — the green survives where
## the render is sound and has gone where it is not — and the patchiness is what
## makes it read as forty years of weather rather than as a decal. This colour
## appears in this level and nowhere else.
func _four_layer_wall(facade: Node3D) -> void:
	var y := YARD_Y + 9.55
	# The surviving green, in three unequal pieces with the wall showing between.
	for p: Array in [[-5.05, 1.95, 1.50], [-2.85, 1.30, 1.72], [-1.15, 0.85, 1.05]]:
		LevelKit.prop(facade, Vector3(float(p[0]), y + (1.72 - float(p[2])) * 0.25, FACE_Z + 0.02),
			Vector3(p[1], p[2], 0.05), mats["green"], "RegimeGreen")
	# An invented institutional slogan, not a quotation: "progress for all",
	# painted in Naskh and long since crossed out. Sits across the gaps, so it
	# is legible where the green survives and gone where it does not.
	var white := MaterialLab.plaster(Color(0.58, 0.56, 0.52), 1.0)
	PropKit.sign(facade, "التقدم للجميع", Vector3(-3.2, y + 0.18, FACE_Z + 0.06), 0.50,
		white, PropKit.FONT_NASKH_BOLD)
	# The crossing-out: one hard stroke, slightly off level, because it was done
	# fast and from a ladder.
	var cross := LevelKit.prop(facade, Vector3(-3.2, y + 0.05, FACE_Z + 0.09),
		Vector3(5.1, 0.15, 0.04), MaterialLab.plaster(Color(0.07, 0.065, 0.062), 1.0),
		"CrossOut")
	cross.rotation.z = deg_to_rad(-1.6)
	# The tricolour over the top of all of it, sprayed small and fast.
	var tri := [Color(0.400, 0.145, 0.125), Color(0.105, 0.098, 0.090), Color(0.165, 0.318, 0.212)]
	for i in 3:
		LevelKit.prop(facade, Vector3(-4.6, y - 0.62 + i * 0.30, FACE_Z + 0.12),
			Vector3(2.1, 0.28, 0.04), MaterialLab.plaster(tri[i], 1.0), "Tricolour%d" % i)


## THE STORY BEAT. Screen x 0.10, hanging from a knocked-through crane hole.
##
## Abu Salim's prefab panels carry a lifting hole at the top of every slab, and
## inmates reopened them to talk through the walls. One of them has been opened
## the rest of the way and a rope of tied bedding is coming out of it. Somebody
## went out this way before he did — which is the only line of story in the
## frame that does not need a caption, and it rhymes with what he is about to do.
##
## Pale cloth on a wall in permanent shade is also a value incident in its own
## right, and it is the DRAPE element the left of frame was missing.
func _bedsheet_rope(facade: Node3D) -> void:
	var x := -4.65
	var hole_y := YARD_Y + 8.3
	# The hole, opened out: a ragged rectangle rather than the neat 110 mm
	# casting, with the concrete broken back around it.
	LevelKit.prop(facade, Vector3(x, hole_y, FACE_Z + 0.01),
		Vector3(0.58, 0.52, 0.05), mats["dark"], "OpenedHole")
	for i in 4:
		LevelKit.prop(facade, Vector3(x - 0.34 + i * 0.23, hole_y + 0.33,
			FACE_Z + 0.04), Vector3(0.18, 0.13, 0.06), mats["joint"], "BreakOut%d" % i)

	# The rope. Two nested Sways so the lower half whips a beat behind the top —
	# one rigid pendulum for a 3 m hanging object reads as a signboard.
	var upper := Sway.new()
	upper.name = "SheetRopeUpper"
	upper.position = Vector3(x, hole_y - 0.1, FACE_Z + 0.16)
	upper.axis = Vector3(0.25, 0.0, 1.0)
	upper.amplitude = 0.055
	upper.speed = 0.74
	upper.gust_amplitude = 0.035
	facade.add_child(upper)

	var lower := Sway.new()
	lower.name = "SheetRopeLower"
	lower.position = Vector3(0.0, -1.35, 0.0)
	lower.axis = Vector3(0.2, 0.0, 1.0)
	lower.amplitude = 0.075
	lower.speed = 1.05
	lower.gust_amplitude = 0.05
	upper.add_child(lower)

	# Four lengths of sheet with a knot between each. The knots are what make it
	# a rope of bedding instead of a strip of cloth.
	for i in 2:
		LevelKit.prop(upper, Vector3(0.0, -0.36 - i * 0.68, 0.0),
			Vector3(0.24, 0.64, 0.05), mats["sheet"], "SheetUpper%d" % i)
		LevelKit.prop(upper, Vector3(0.0, -0.70 - i * 0.68, 0.0),
			Vector3(0.33, 0.15, 0.10), mats["sheet"], "KnotUpper%d" % i)
	for i in 2:
		LevelKit.prop(lower, Vector3(0.0, -0.36 - i * 0.68, 0.0),
			Vector3(0.24, 0.64, 0.05), mats["sheet"], "SheetLower%d" % i)
		LevelKit.prop(lower, Vector3(0.0, -0.70 - i * 0.68, 0.0),
			Vector3(0.33, 0.15, 0.10), mats["sheet"], "KnotLower%d" % i)
	# It does not reach the ground, and the frayed end is where it tore.
	LevelKit.prop(lower, Vector3(0.05, -1.82, 0.0), Vector3(0.17, 0.42, 0.04),
		mats["sheet"], "FrayedEnd").rotation.z = 0.22


## Everything between the yard floor and the walkway. Without this the lower
## third of the frame is one flat slab, and a flat slab is not architecture.
func _ground_floor(facade: Node3D) -> void:
	var corrugated := MaterialLab.corrugated(Color(0.148, 0.140, 0.130), 22.0)
	var conduit := MaterialLab.rusted_metal(Color(0.26, 0.22, 0.19), 0.6)

	# Roller shutter into the block, with a bent steel awning over it. The
	# awning was 4.2 m of pale corrugated at a 13 degree tilt and read as an
	# escalator crossing the bottom-left of the image; it is now 2.6 m, darker
	# than the wall, and nearly flat.
	LevelKit.prop(facade, Vector3(-1.4, YARD_Y + 1.75, FACE_Z), Vector3(2.6, 3.5, 0.12),
		corrugated, "RollerShutter")
	LevelKit.prop(facade, Vector3(-1.4, YARD_Y + 3.62, FACE_Z + 0.16),
		Vector3(3.0, 0.14, 0.42), mats["rust"], "ShutterHead")
	var awning := LevelKit.prop(facade, Vector3(-1.4, YARD_Y + 4.14, FACE_Z + 0.42),
		Vector3(3.1, 0.09, 0.90), corrugated, "Awning")
	awning.rotation.x = 0.13
	PropKit.sign(facade, "مخزن ٣", Vector3(-1.4, YARD_Y + 3.95, FACE_Z + 0.04), 0.30,
		MaterialLab.plaster(Color(0.50, 0.48, 0.44), 1.0), PropKit.FONT_KUFI)

	# Service run: pipes and conduit banded along the wall at head height.
	for i in 3:
		LevelKit.prop(facade, Vector3(-28.8, YARD_Y + 4.9 + i * 0.26, FACE_Z + 0.10),
			Vector3(66.0, 0.11, 0.18), conduit, "Conduit%d" % i)
	for i in 9:
		LevelKit.prop(facade, Vector3(-52.0 + i * 7.0, YARD_Y + 4.9, FACE_Z + 0.20),
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
	LevelKit.prop(facade, Vector3(-28.5, YARD_Y + 0.9, FACE_Z + 0.14), Vector3(67.0, 1.8, 0.10),
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
	LevelKit.prop(geometry, Vector3(-3.6, DECK_Y + 1.05, -2.35),
		Vector3(1.25, 2.30, 0.28), mats["joint"], "DoorJamb")
	var door := LevelKit.prop(geometry, Vector3(-3.6, DECK_Y + 1.02, -2.10),
		Vector3(0.96, 2.06, 0.06), mats["door"], "GreenDoor")
	door.position += Vector3(0.42, 0.0, 0.30)
	door.rotation.y = -1.05

	# The door sat 1.2 m off the back edge of the walkway with nothing under it
	# — he came out of a door onto thin air. This is the landing slab that ties
	# the threshold to the deck, and its nosing is the horizontal that carries
	# the eye from the door to him.
	LevelKit.prop(geometry, Vector3(-3.4, DECK_Y - 0.18, -1.30),
		Vector3(3.2, 0.32, 1.90), mats["deck"], "DoorLanding")
	LevelKit.prop(geometry, Vector3(-3.4, DECK_Y - 0.40, -0.42),
		Vector3(3.2, 0.20, 0.16), mats["joint"], "LandingNosing")
	# Sand drifted across the threshold, with a clean swept arc where it swung.
	# Pulled forward onto the landing; at z -1.55 it was floating behind the
	# deck edge and reading as a white plank in mid-air.
	LevelKit.prop(geometry, Vector3(-3.3, DECK_Y + 0.02, -1.20), Vector3(2.1, 0.06, 1.5),
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
	var beam := LevelKit.prop(geometry, Vector3(0.9, -0.62, 9.5),
		Vector3(5.4, 0.46, 0.46), mats["dark"], "FallenBeam")
	beam.rotation.z = deg_to_rad(15.0)
	# It broke, rather than being put there. Web plates and a torn end turn a
	# black parallelogram into a girder.
	for i in 5:
		LevelKit.prop(geometry, Vector3(-1.2 + i * 1.05, -0.62 + (-1.2 + i * 1.05) * 0.27,
			9.5), Vector3(0.12, 0.78, 0.40), mats["dark"], "BeamWeb%d" % i)
	LevelKit.prop(geometry, Vector3(-0.5, 0.15, 9.5), Vector3(0.34, 2.0, 0.34),
		mats["dark"], "BeamStub").rotation.z = deg_to_rad(-11.0)

	_fence_breach()

	# Razor wire across the top-left corner, heavy near-DOF, reading as a shape.
	# It was at x -7.6, which at this depth is two units outside the left edge
	# of the frustum — the corner it was supposed to close was empty.
	PropKit.razor_coil(geometry, Vector3(-0.7, 3.85, 9.0), Vector3(1.05, 3.05, 9.0),
		0.34, mats["dark"], 9, "RazorCoilForeground")
	# A dead casuarina closing the right edge, silvered bone-white.
	PropKit.eucalyptus(geometry, Vector3(7.4, -5.4, 8.6), 13.0,
		mats["dark"], mats["dark"], false, 91)


## THE BOTTOM-LEFT CORNER. It was dead — flat mid-grey wall running off the
## bottom of the frame with nothing in front of it, so the image had no anchor
## on the side the eye enters from.
##
## What goes there is also the last piece of evidence: the fence has been cut
## and rolled back, and the bolt-cut section is lying on the rubble under his
## walkway with rebar coming up through it. Somebody has been through here. It
## is near-black, it is sized to the near frustum, and its rebar spikes break
## the corner's edge so the frame does not end on a straight line.
func _fence_breach() -> void:
	var root := Node3D.new()
	root.name = "FenceBreach"
	root.position = Vector3(0.35, -1.55, 7.2)
	geometry.add_child(root)

	# Rubble mound. Three overlapping masses at different angles — one box is a
	# crate, three at odd angles is spoil.
	for s: Array in [[-0.85, 0.20, 2.3, 0.95, -0.14], [0.55, 0.05, 2.0, 0.75, 0.09],
			[1.55, 0.34, 1.4, 1.15, -0.22]]:
		var m := LevelKit.prop(root, Vector3(s[0], s[1], 0.0),
			Vector3(s[2], s[3], 1.3), mats["dark"], "Spoil")
		m.rotation.z = s[4]
	# The cut panel of chain-link, peeled back and lying over the spoil.
	var link := PropKit.chainlink_material(0.55, 14.0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.9, 1.7)
	var mi := MeshInstance3D.new()
	mi.name = "CutPanel"
	mi.mesh = mesh
	mi.material_override = link
	mi.position = Vector3(0.1, 0.62, 0.45)
	mi.rotation = Vector3(deg_to_rad(-58.0), 0.0, deg_to_rad(21.0))
	root.add_child(mi)
	# Rebar and a bent post coming up out of it. These are the shapes that break
	# the corner; at this distance they are 60-80 mm and they still read,
	# because nothing behind them is darker than the sky.
	for s: Array in [[-1.10, 1.15, 14.0], [-0.45, 0.85, -21.0], [0.30, 1.45, 8.0],
			[0.95, 0.70, 27.0], [1.70, 1.25, -12.0]]:
		var bar := LevelKit.prop(root, Vector3(s[0], float(s[1]) * 0.5 + 0.25, 0.1),
			Vector3(0.075, s[1], 0.075), mats["dark"], "BreachRebar")
		bar.rotation.z = deg_to_rad(s[2])
	var post := LevelKit.prop(root, Vector3(-1.75, 1.05, 0.3),
		Vector3(0.14, 2.5, 0.14), mats["dark"], "BentPost")
	post.rotation.z = deg_to_rad(34.0)
	# The cut ends of the wire, curled. One small curl is what says "cut" rather
	# than "fell down".
	for i in 3:
		var curl := LevelKit.prop(root, Vector3(-0.6 + i * 0.5, 1.35 + i * 0.12, 0.55),
			Vector3(0.42, 0.06, 0.06), mats["dark"], "CutWire%d" % i)
		curl.rotation.z = deg_to_rad(-40.0 + i * 38.0)


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
	# why no shaft ever formed. Now that the global volumetric density is half
	# what it was, these carry the shafts on their own and can be pushed harder.
	var shafts := _fog_volume(Vector3(16.0, 6.0, -15.0), Vector3(56.0, 17.0, 22.0),
		0.0075, "PipeRackShafts")
	(shafts.material as FogMaterial).height_falloff = 0.0
	(shafts.material as FogMaterial).edge_fade = 0.30
	(shafts.material as FogMaterial).albedo = Color(1.0, 0.90, 0.76)

	# A second, tighter one in the near yard, cut by the walkway and its legs.
	var near := _fog_volume(Vector3(6.0, -2.4, -5.0), Vector3(26.0, 9.0, 12.0),
		0.006, "YardShafts")
	(near.material as FogMaterial).height_falloff = 0.0
	(near.material as FogMaterial).edge_fade = 0.35

	# A cool pocket over the left third. The block is in permanent shade and the
	# one thing that can put cool air in front of it — rather than a cool light
	# on it, which would be a lie about where the key is — is fog with a blue
	# albedo and almost no emission.
	var cool := _fog_volume(Vector3(-8.0, 1.0, -4.0), Vector3(22.0, 16.0, 8.0),
		0.010, "ShadeSideAir")
	(cool.material as FogMaterial).albedo = Color(0.52, 0.62, 0.84)
	(cool.material as FogMaterial).emission = Color(0.012, 0.016, 0.028)
	(cool.material as FogMaterial).height_falloff = 0.0
	(cool.material as FogMaterial).edge_fade = 0.55

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

	# A second negative on the burnt bay. SSIL and sky ambient both lift a large
	# near-black surface back toward mid grey, and the whole point of the fire
	# is that it is the darkest thing in the left half. This holds it down
	# without touching anything else.
	var burn_neg := OmniLight3D.new()
	burn_neg.name = "BurntBayNegative"
	burn_neg.position = Vector3(2.35, YARD_Y + 6.8, -1.6)
	burn_neg.light_negative = true
	burn_neg.light_energy = 0.55
	burn_neg.omni_range = 4.6
	add_child(burn_neg)
