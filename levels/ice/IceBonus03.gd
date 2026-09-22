extends IceBonusStage
## ICE BONUS — "THE CREVASSE".
##
## Glacier Run is a run. The Shaft is a climb. This one is a FALL, and it is the
## only level in the game built around the thobe glide.
##
## You step off the lip at the top and the level happens on the way down: the
## crevasse is wide at the surface and closes to a slot at the bottom, the
## route zig-zags between shelves cantilevered off alternating walls, and the
## only way to make the next shelf is to hold jump and let the wind take the
## thobe. Let go and you drop straight past the trail. Hold it the whole way and
## you float, and floating is too slow for the clock.
##
## That tension is the level. Everything else serves it.
##
## Exactly 100 ICE SRIRACHAS: six in the column at the lip, eight in each of the
## ten glide arcs, and a fourteen-bottle cluster over the meltwater at the floor.
##
## THE READ, because a fall gives you less time to parse a frame than a climb:
##
##   1. Standable is SNOW and nothing else is. Every shelf is a dark ice body
##      with a bright snow cap and a lip proud of its leading edge, and the lip
##      is the brightest value in its neighbourhood by a wide margin.
##   2. The walls DARKEN as you descend, so how deep you are is legible without
##      a HUD, and so a shelf near the bottom has a darker ground to stand out
##      against exactly when you are moving fastest.
##   3. Everything hanging — icicles, curtains, the fluted wall relief — points
##      DOWN. In a level read vertically at speed, the direction the detail
##      runs is the direction the player reads the frame.

const ICE_VARIANT := 1   ## Sriracha.Variant.ICE

const TOP_Y := 4.0
const FLOOR_Y := -106.0
const WALL_Z := -5.4
const SLOT_HALF_TOP := 11.0    ## Half-width of the crevasse at the surface.
const SLOT_HALF_BOTTOM := 5.2  ## ...and at the floor. It closes on you.

## The route, top to bottom. Each entry is the centre of a landing shelf; the
## glide arcs are drawn between consecutive entries, so moving a number here
## moves the shelf, the trail and the camera work together.
const ROUTE := [
	Vector2(0.0, 2.0),
	Vector2(-5.4, -8.5),
	Vector2(5.2, -19.0),
	Vector2(-4.8, -29.5),
	Vector2(5.6, -40.0),
	Vector2(-5.2, -50.5),
	Vector2(4.9, -61.0),
	Vector2(-5.4, -71.5),
	Vector2(5.1, -82.0),
	Vector2(-4.6, -92.0),
	Vector2(0.0, -101.5),
]

var _rng := RandomNumberGenerator.new()
var _mats := {}


func _ready() -> void:
	level_id = "ice_crevasse"
	level_title = "THE CREVASSE"
	spawn_point = Vector3(0.0, TOP_Y, 0.0)
	# A glide from the lip to the floor is about forty seconds if you never
	# waste one. The margin is deliberately thin: the level is a commitment.
	time_limit = 56.0
	music_theme = ""   # no score: the game runs on ambience and SFX alone
	use_camera_bounds = true
	camera_bounds_min = Vector2(-10.0, FLOOR_Y - 2.0)
	camera_bounds_max = Vector2(10.0, TOP_Y + 6.0)
	super._ready()

	# IceBonusStage pins the kill plane at -26 for levels that live near zero.
	# This one ends at -106, so it has to be re-set after the base class has
	# had its say — and the player has already been spawned with the old value,
	# so it needs the same correction.
	kill_plane_y = FLOOR_Y - 14.0
	if is_instance_valid(player):
		player.terminal_fall_y = kill_plane_y

	camera.height_offset = 1.4
	camera.distance = 18.0


## Twilight, and the sun is behind the lip — you are looking up out of a hole.
func _sky_preset() -> String:
	return "ice_twilight"


func _mood() -> LightingRig.Mood:
	var mood := LightingRig.Mood.new()
	# The key rakes in over the lip from behind camera-left, so the top few
	# metres of wall are lit and everything below is bounce. Two stops of
	# separation between the first shelf and the last, for free.
	mood.sun_angles = Vector2(-58.0, 34.0)

	# --- contrast budget (see LightingRig.Mood.set_contrast) ---
	# The dimmest of the three by design — but 1.1:1 is not dim, it is flat.
	# 3.0:1 at a lower key keeps it the coldest and softest of the set.
	mood.set_contrast(2.6, 3.0, 0.8)
	mood.sun_color = Color(0.96, 0.94, 1.0)
	mood.sun_angular_distance = 0.7
	mood.sun_fog_energy = 3.2
	mood.sun_disc_size = 0.0

	# Fill is the colour of the ice itself. In a real crevasse the light that
	# reaches you has been through several metres of glacier, and it comes out
	# that impossible cyan.
	mood.fill_angles = Vector2(20.0, -140.0)
	mood.fill_color = Color(0.26, 0.52, 0.86)
	mood.bounce_energy = 0.28
	mood.bounce_color = Color(0.46, 0.66, 0.92)

	mood.rim_angles = Vector2(-8.0, 158.0)
	mood.rim_color = Color(0.78, 0.94, 1.0)
	mood.rim_energy = 3.6
	mood.rim_cull_mask = 2
	mood.hero_fill_energy = 1.3
	mood.hero_fill_color = Color(0.86, 0.92, 1.0)
	mood.hero_fill_angles = Vector2(-16.0, -34.0)

	mood.sky_top = Color(0.18, 0.30, 0.56)
	mood.sky_horizon = Color(0.62, 0.74, 0.92)
	mood.ground_horizon = Color(0.10, 0.20, 0.38)
	mood.ground_bottom = Color(0.015, 0.035, 0.085)
	mood.sky_curve = 0.26
	# Ambient is the enemy of a slot canyon: it is the one light with no
	# direction, and a place defined entirely by how deep you are needs every
	# light in it to fall off.

	# Fog is charged per unit of DEPTH, and this level is a hundred and ten
	# units deep. The first pass ran 0.0075 / 0.030 — Brega's numbers multiplied
	# up rather than divided down — and the whole crevasse rendered as one sheet
	# of pale blue with a hero stencilled on it. Depth this large wants LESS fog
	# per unit, not more: the distance does the work.
	mood.fog_color = Color(0.30, 0.46, 0.72)
	mood.fog_density = 0.0016
	mood.fog_sun_scatter = 0.22
	mood.volumetric_density = 0.0014
	mood.fog_anisotropy = 0.62

	mood.glow_intensity = 1.10
	mood.glow_bloom = 0.16
	mood.glow_hdr_threshold = 1.5

	mood.agx_white = 9.5
	mood.agx_contrast = 1.45
	# Cool the shadows further and keep the one warm thing — the sky over the
	# lip — warm, so the top of the frame never joins the blue.
	mood.grade_shadow_tint = Color(0.40, 0.48, 0.66)
	mood.grade_highlight_tint = Color(0.56, 0.52, 0.46)
	mood.grade_strength = 0.70
	return mood


func _build_level() -> void:
	_rng.seed = 0x1CE03
	_build_materials()
	_build_walls()
	_build_shelves()
	_build_floor()
	_build_trail()
	_build_atmosphere()


## Depth as a number from 0 (the lip) to 1 (the floor). Everything that reads as
## wall is coloured from this, which is what makes "how deep am I" a thing you
## can see rather than a thing you have to remember.
func _depth(y: float) -> float:
	return clampf(inverse_lerp(TOP_Y, FLOOR_Y, y), 0.0, 1.0)


## Half-width of the crevasse at a given height.
func _half_width(y: float) -> float:
	# Eased rather than linear: the walls hang almost vertical for the first
	# third and then lean in, which is how a crevasse actually closes and which
	# puts the squeeze exactly where the player is going fastest.
	var t := _depth(y)
	return lerpf(SLOT_HALF_TOP, SLOT_HALF_BOTTOM, t * t * (3.0 - 2.0 * t))


func _build_materials() -> void:
	_mats = {
		# The snow cap. The brightest thing in the level and the only material
		# allowed up here, because it is the standing contract.
		"snow": MaterialLab.plaster(Color(0.93, 0.955, 0.985), 0.35),
		"lip": MaterialLab.plaster(Color(0.98, 0.99, 1.0), 0.15),
		"shelf_body": MaterialLab.ice(0.55, Color(0.10, 0.28, 0.46)),
		"pool": MaterialLab.ice(1.0, Color(0.06, 0.24, 0.42)),
	}


## One wall slab. Cached per (depth-band, side) so a hundred-metre wall is a
## handful of materials rather than a hundred.
func _wall_material(t: float) -> Material:
	var band := roundi(t * 8.0)
	var key := "wall_%d" % band
	if _mats.has(key):
		return _mats[key]
	var f := float(band) / 8.0
	# Pale glacier blue at the lip, near-black indigo at the floor.
	# Starts at a mid value, not a bright one. The snow shelves are the only
	# thing in this level allowed near the top of the range, and a wall that
	# competes with them is a wall the player tries to stand on.
	var c := Color(0.20, 0.34, 0.54).lerp(Color(0.018, 0.034, 0.082), f * f)
	# Low clarity on purpose. Glacier ice a metre thick is not a window: the
	# light that gets through has scattered, and a wall built out of a clear
	# refractive material lights itself from behind and joins the snow at the
	# top of the value range, which is the one thing the read forbids.
	var m := MaterialLab.ice(lerpf(0.16, 0.06, f), c)
	_mats[key] = m
	return m


func _build_walls() -> void:
	# Both walls are built as a stack of flutes: tall thin slabs at slightly
	# different depths and widths. A crevasse wall is not a plane, it is a run
	# of vertical scallops cut by meltwater, and the scallops are what catch the
	# rim light in a line that runs the way the player is reading.
	var y := TOP_Y + 4.0
	while y > FLOOR_Y - 3.0:
		var h := _rng.randf_range(5.0, 9.5)
		var t := _depth(y - h * 0.5)
		for side: float in [-1.0, 1.0]:
			var hw := _half_width(y - h * 0.5)
			var flutes := 4
			for i in flutes:
				var w := _rng.randf_range(1.5, 3.1)
				var depth := _rng.randf_range(1.6, 4.4)
				var x := side * (hw + w * 0.5 - _rng.randf_range(0.0, 0.55))
				var z := WALL_Z + _rng.randf_range(-1.2, 2.6) - i * 1.35
				LevelKit.prop(geometry, Vector3(x, y - h * 0.5, z),
					Vector3(w, h, depth), _wall_material(t), "Flute")
			# A solid backing slab behind the flutes so no gap ever shows sky
			# through the side of the level.
			LevelKit.prop(geometry, Vector3(side * (hw + 3.4), y - h * 0.5, WALL_Z - 4.0),
				Vector3(7.0, h + 0.4, 5.0), _wall_material(minf(t + 0.24, 1.0)), "Backing")
		y -= h

	# The far wall. Kept a value darker than the side flutes at the same depth
	# so the side walls read as nearer, which is the only depth cue a slot
	# canyon has.
	var yy := TOP_Y + 4.0
	while yy > FLOOR_Y - 3.0:
		var h2 := 8.0
		var t2 := _depth(yy - h2 * 0.5)
		LevelKit.prop(geometry, Vector3(0.0, yy - h2 * 0.5, WALL_Z - 7.5),
			Vector3(30.0, h2 + 0.3, 3.0), _wall_material(minf(t2 + 0.40, 1.0)), "FarWall")
		yy -= h2

	_hang_icicles()


## Icicle curtains along both lips, thickest at the top where the melt is.
## They are props, not hazards: in a fall the player has no time to distinguish
## a decorative spike from a lethal one, so none of them are lethal.
func _hang_icicles() -> void:
	var mesh_cache := {}
	var by_material: Dictionary = {}
	for i in 180:
		var y := _rng.randf_range(FLOOR_Y + 6.0, TOP_Y + 2.0)
		var t := _depth(y)
		# Three times as many near the lip: melt needs sun.
		if _rng.randf() > lerpf(1.0, 0.28, t):
			continue
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var hw := _half_width(y)
		var length := _rng.randf_range(0.8, 3.4) * lerpf(1.0, 0.55, t)
		var radius := length * _rng.randf_range(0.055, 0.105)
		var key := "%.2f_%.3f" % [length, radius]
		if not mesh_cache.has(key):
			var cone := CylinderMesh.new()
			cone.top_radius = radius
			cone.bottom_radius = 0.0
			cone.height = length
			cone.radial_segments = 6
			cone.rings = 1
			mesh_cache[key] = cone
		var mat := _wall_material(maxf(t - 0.22, 0.0))
		var bucket_key := "%s|%d" % [key, mat.get_instance_id()]
		if not by_material.has(bucket_key):
			by_material[bucket_key] = [mesh_cache[key], mat, [] as Array[Transform3D]]
		var xf := Transform3D(Basis.IDENTITY,
			Vector3(side * (hw - _rng.randf_range(0.1, 1.4)), y - length * 0.5,
				WALL_Z + _rng.randf_range(0.5, 3.5)))
		by_material[bucket_key][2].append(xf)

	for bucket: Array in by_material.values():
		var xforms: Array = bucket[2]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bucket[0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Icicles"
		mi.multimesh = mm
		mi.material_override = bucket[1]
		geometry.add_child(mi)


## Every entry in ROUTE gets a shelf. The last one is the floor and is built
## separately, because standing on it ends the level rather than continuing it.
func _build_shelves() -> void:
	for i in ROUTE.size() - 1:
		var p: Vector2 = ROUTE[i]
		var width := 4.6 if i > 0 else 7.0
		var from_left := p.x < 0.0

		# The body: dark ice, wedge-shaped, cantilevered out of the wall. A
		# shelf that is a slab of snow all the way down reads as a wall.
		LevelKit.box(geometry,
			Vector3(p.x + (0.9 if from_left else -0.9), p.y - 1.35, 0.0),
			Vector3(width + 1.8, 2.3, 3.6), _mats["shelf_body"], "ShelfBody%d" % i)

		# The cap: snow, thin, and the only standable-coloured thing here.
		var body := LevelKit.platform(geometry, p.x - width * 0.5, p.y, width,
			_mats["snow"], 0.62, 3.9, "Shelf%d" % i)
		body.add_to_group("ice_shelf")

		# The lip: fresh snow proud of the leading edge, with the body's own
		# shadow immediately under it. Bright line over dark line is an edge,
		# and an edge is the difference between landing and guessing.
		var lip_x := p.x + (width * 0.5 if not from_left else -width * 0.5)
		LevelKit.prop(geometry, Vector3(lip_x, p.y + 0.06, 0.38),
			Vector3(0.9, 0.34, 4.5), _mats["lip"], "Lip%d" % i)

		# A darker patch of wall staged directly behind every shelf, so the
		# contrast does not depend on the camera finding a good angle.
		LevelKit.prop(geometry, Vector3(p.x, p.y - 1.0, WALL_Z + 0.9),
			Vector3(width + 5.0, 6.0, 0.7),
			_wall_material(minf(_depth(p.y) + 0.34, 1.0)), "ShelfBack%d" % i)

		# One cold practical under each shelf. It is not motivated by anything
		# in the fiction and does not need to be: it is the light that stops a
		# hundred metres of blue from flattening into one value.
		var glow := OmniLight3D.new()
		glow.name = "ShelfGlow%d" % i
		glow.light_color = Color(0.58, 0.82, 1.0)
		glow.light_energy = 2.4
		glow.omni_range = 9.0
		glow.omni_attenuation = 2.0
		glow.light_volumetric_fog_energy = 2.6
		glow.shadow_enabled = false
		glow.position = Vector3(p.x, p.y - 2.6, 1.2)
		geometry.add_child(glow)


func _build_floor() -> void:
	var p: Vector2 = ROUTE[ROUTE.size() - 1]
	LevelKit.box(geometry, Vector3(p.x, p.y - 1.4, 0.0),
		Vector3(26.0, 2.8, 8.0), _mats["snow"], "Floor")

	# Meltwater, frozen over. The one horizontal mirror in a level made
	# entirely of vertical lines, and it catches the sky at the top of the
	# crevasse — which is the payoff for having fallen the whole way.
	var pool := MeshInstance3D.new()
	pool.name = "Meltwater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(15.0, 6.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 10
	pool.mesh = plane
	pool.material_override = _mats["pool"]
	pool.position = Vector3(p.x, p.y + 0.02, -0.4)
	geometry.add_child(pool)

	# The walls stop here. A hard snow bank across the back closes the level so
	# the far wall does not run past the floor into nothing.
	LevelKit.prop(geometry, Vector3(0.0, p.y + 2.2, WALL_Z - 2.0),
		Vector3(30.0, 7.0, 3.0), _wall_material(1.0), "FloorBank")


## Exactly 100. Counted in the comments because a bonus level that hands out 99
## is not a bonus level, it is a bug with a timer.
func _build_trail() -> void:
	var total := 0

	# 6 — the column off the lip. It is the tutorial: the bottles hang in the
	# air past the edge, so the first thing the level asks you to do is step
	# off, and the only way to reach the sixth is to already be gliding.
	total += TrailBuilder.column(geometry,
		Vector3(1.6, TOP_Y - 4.6, 0.0), 4.2, 6, ICE_VARIANT).size()

	# 10 arcs × 8 = 80. Bulged AWAY from the wall the player is leaving, so the
	# trail shows the drift a glide actually has rather than a straight line
	# nobody can fly.
	for i in ROUTE.size() - 1:
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i + 1]
		var from := Vector3(a.x + signf(b.x - a.x) * 1.4, a.y + 0.6, 0.0)
		var to := Vector3(b.x - signf(b.x - a.x) * 1.2, b.y + 1.5, 0.0)
		# Negative bulge: the path sags, because this is a fall.
		total += TrailBuilder.curve(geometry, from, to, -1.9, 8, ICE_VARIANT).size()

	# 14 — the payoff, hanging over the meltwater. cluster() returns count + 1.
	var floor_p: Vector2 = ROUTE[ROUTE.size() - 1]
	total += TrailBuilder.cluster(geometry,
		Vector3(floor_p.x, floor_p.y + 3.4, 0.0), 1.5, 13, ICE_VARIANT).size()

	assert(total == IceBonusStage.TARGET,
		"THE CREVASSE placed %d ICE SRIRACHAS, needs %d" % [total, IceBonusStage.TARGET])


func _build_atmosphere() -> void:
	# Spindrift: snow coming off the lip and falling the whole depth of the
	# level. It is the only thing in frame that is not ice, and it gives the
	# fall a speed reference — without it a slot canyon of repeating blue
	# gives the eye nothing to measure descent against.
	var p := GPUParticles3D.new()
	p.name = "Spindrift"
	p.amount = 420
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-16.0, FLOOR_Y - 4.0, -12.0),
		Vector3(32.0, TOP_Y - FLOOR_Y + 12.0, 20.0))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11.0, 1.0, 5.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0.6, -3.0, 0.0)
	pm.damping_min = 0.2
	pm.damping_max = 1.2
	pm.scale_min = 0.25
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 2.4
	p.process_material = pm

	p.draw_pass_1 = FXKit.sprite_pass(0.045, Color(0.92, 0.97, 1.0),
		{"alpha": 0.55, "additive": false})
	p.position = Vector3(0.0, TOP_Y + 3.0, 0.0)
	geometry.add_child(p)
	p.emitting = true
