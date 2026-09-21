extends IceBonusStage
## ICE BONUS — "THE SHAFT".
##
## Glacier Run is a run. This one is a climb: a frozen chimney with the sky at
## the top of it and the route spiralling up the walls, so the whole level is
## read vertically and the double jump is the verb instead of the dash.
##
## The bottom is deep blue and almost dark; the top is white and blown out.
## That gradient is the level — you can see how far you have left by how bright
## it is around you.
##
## Exactly 100 ICE SRIRACHAS.

const ICE_VARIANT := 1   ## Sriracha.Variant.ICE

var m := {}


func _ready() -> void:
	level_id = "ice_shaft"
	level_title = "THE SHAFT"
	spawn_point = Vector3(0.0, 2.0, 0.0)
	time_limit = 52.0
	music_theme = "ice"
	use_camera_bounds = true
	camera_bounds_min = Vector2(-9.0, -2.0)
	camera_bounds_max = Vector2(9.0, 86.0)
	super._ready()
	camera.height_offset = 2.2
	camera.distance = 17.0


func _mood() -> LightingRig.Mood:
	var mood := LightingRig.Mood.new()
	# The key comes straight down the shaft. Everything else is bounce off blue
	# ice, which is why the walls go violet as they recede.
	mood.sun_angles = Vector2(-78.0, 20.0)
	mood.sun_color = Color(0.92, 0.97, 1.0)
	mood.sun_energy = 3.4
	mood.sun_angular_distance = 0.5
	mood.sun_fog_energy = 4.5
	mood.sun_disc_size = 0.0

	mood.fill_angles = Vector2(12.0, -150.0)
	mood.fill_color = Color(0.30, 0.38, 0.78)
	mood.fill_energy = 0.60

	mood.rim_angles = Vector2(-4.0, 152.0)
	mood.rim_color = Color(0.72, 0.92, 1.0)
	mood.rim_energy = 4.4
	mood.rim_cull_mask = 2
	mood.hero_fill_energy = 1.5
	mood.hero_fill_color = Color(0.82, 0.88, 1.0)
	mood.hero_fill_angles = Vector2(-20.0, -30.0)

	mood.sky_top = Color(0.780, 0.880, 0.980)
	mood.sky_horizon = Color(0.420, 0.560, 0.780)
	mood.ground_horizon = Color(0.120, 0.170, 0.300)
	mood.ground_bottom = Color(0.030, 0.045, 0.100)
	mood.sky_energy = 1.3
	mood.sky_curve = 0.30
	mood.ambient_energy = 0.36

	mood.fog_color = Color(0.480, 0.620, 0.840)
	mood.fog_density = 0.0055
	mood.fog_sun_scatter = 0.40
	mood.fog_emission = Color(0.06, 0.10, 0.22)
	mood.fog_anisotropy = 0.70
	mood.volumetric_density = 0.0070

	mood.tonemap = Environment.TONE_MAPPER_ACES
	mood.exposure = 0.90
	mood.white = 7.0
	mood.glow_intensity = 0.50
	mood.glow_hdr_threshold = 1.30
	mood.adjustment_saturation = 1.12
	mood.adjustment_contrast = 1.05
	return mood


func _build_level() -> void:
	m = {
		"ice": MaterialLab.ice(1.0),
		"packed": MaterialLab.ice(0.35),
		"deep": MaterialLab.ice(1.0, Color(0.020, 0.075, 0.190)),
		"snow": MaterialLab.ice(0.05, Color(0.76, 0.85, 0.96)),
		"lip": MaterialLab.plaster(Color(0.94, 0.96, 1.0), 0.12),
	}
	_walls()
	_route()
	_atmosphere_shaft()


## The chimney. Two walls of stacked ice blocks with a rhythm to them, so the
## climb has a measurable height rather than sliding past a smooth tube.
func _walls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8821
	for side: float in [-1.0, 1.0]:
		var y := -4.0
		while y < 88.0:
			var h := rng.randf_range(2.6, 5.4)
			var d := rng.randf_range(0.0, 1.4)
			LevelKit.prop(geometry,
				Vector3(side * (9.6 + d * 0.5), y + h * 0.5, -7.0),
				Vector3(6.0 + d, h, 12.0),
				# Mostly deep: the wall has to sit well below the shelves in
				# value or the player cannot tell what is standable, and in a
				# climb that is not a style note, it is the whole level.
				m["deep"] if rng.randf() < 0.75 else m["ice"], "Wall")
			y += h
	# The floor of the shaft, far below, so a fall reads as a fall.
	LevelKit.prop(geometry, Vector3(0.0, -9.0, -6.0), Vector3(30.0, 4.0, 18.0),
		m["deep"], "ShaftFloor")


## The climb: eight turns of a spiral, alternating sides, each landing visible
## from the one below it. 100 bottles exactly.
func _route() -> void:
	# 0 — the floor of the shaft. 10.
	LevelKit.platform(geometry, -6.0, 0.0, 12.0, m["snow"], 8.0, 3.4, "Base")
	TrailBuilder.line(geometry, Vector3(-4.0, 1.0, 0.0), Vector3(4.0, 1.0, 0.0),
		10, ICE_VARIANT)

	# 1..8 — the spiral. Each rung is a shelf off one wall with a cluster over
	# it; the count per rung is tuned so the total lands on 100.
	var rungs := [
		[-4.6, 4.4, 5.0, 9], [3.8, 8.2, 5.0, 9], [-4.2, 12.4, 5.4, 9],
		[3.6, 16.6, 5.0, 9], [-4.6, 21.0, 5.4, 9], [3.8, 25.4, 5.0, 9],
		[-4.2, 30.0, 5.4, 9], [3.6, 34.6, 5.0, 9],
	]
	var prev := Vector3(0.0, 1.0, 0.0)
	for i in rungs.size():
		var r: Array = rungs[i]
		var left: float = r[0] - r[2] * 0.5
		LevelKit.platform(geometry, left, r[1], r[2], m["snow"], 7.0, 3.4,
			"Rung%d" % i)
		# A lip of fresh snow along the front edge: the brightest line in the
		# level, and the thing the eye lands on when looking for the next hold.
		LevelKit.prop(geometry, Vector3(r[0], r[1] + 0.10, 1.55),
			Vector3(r[2] + 0.4, 0.22, 0.5), m["lip"], "RungLip%d" % i)
		var over := Vector3(r[0], r[1] + 2.3, 0.0)
		TrailBuilder.curve(geometry, prev + Vector3(0.0, 0.4, 0.0), over, 1.5,
			int(r[3]), ICE_VARIANT)
		prev = over

	# 9 — the last stretch is a straight column of bottles up the middle, which
	# is the one moment the level asks for the double jump twice in a row. 18.
	LevelKit.platform(geometry, -2.2, 39.6, 4.4, m["snow"], 7.0, 3.4, "Ledge")
	LevelKit.prop(geometry, Vector3(0.0, 39.7, 1.55), Vector3(4.8, 0.22, 0.5),
		m["lip"], "LedgeLip")
	TrailBuilder.column(geometry, Vector3(0.0, 41.0, 0.0), 9.0, 18, ICE_VARIANT)

	# 10 — the lip, in daylight. 4.
	LevelKit.platform(geometry, -5.0, 51.0, 10.0, m["snow"], 9.0, 3.6, "Lip")
	TrailBuilder.line(geometry, Vector3(-3.0, 52.0, 0.0), Vector3(2.0, 52.0, 0.0),
		4, ICE_VARIANT)


func _atmosphere_shaft() -> void:
	# A column of light down the middle of the shaft, and spindrift falling
	# through it. Both exist to make the vertical readable.
	var fv := FogVolume.new()
	fv.name = "ShaftLight"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(14.0, 70.0, 12.0)
	fv.position = Vector3(0.0, 26.0, -3.0)
	var fm := FogMaterial.new()
	fm.density = 0.030
	fm.albedo = Color(0.88, 0.95, 1.0)
	fm.emission = Color(0.04, 0.07, 0.14)
	fm.height_falloff = 0.0
	fm.edge_fade = 0.35
	fv.material = fm
	add_child(fv)

	var p := GPUParticles3D.new()
	p.name = "Spindrift"
	p.amount = 340
	p.lifetime = 11.0
	p.preprocess = 10.0
	p.fixed_fps = 30
	p.local_coords = false
	p.position = Vector3(0.0, 56.0, -2.0)
	p.visibility_aabb = AABB(Vector3(-16, -70, -16), Vector3(32, 80, 32))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(8.0, 1.0, 5.0)
	pm.direction = Vector3(0.1, -1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0.2, -1.2, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 1.4
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.92, 0.97, 1.0, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true
