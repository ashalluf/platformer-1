extends IceBonusStage
## ICE BONUS — "GLACIER RUN".
##
## A short, bright, cold place built out of one material the rest of the game
## never uses. The route reads from the first second: a rising serpentine across
## a frozen shelf, with the trail always visible one segment ahead.
##
## Exactly 100 ICE SRIRACHAS are placed. Finishing the route finishes the count.

const ICE_VARIANT := 1   ## Sriracha.Variant.ICE
const AURORA_SHADER := preload("res://shaders/aurora.gdshader")

var m := {}


func _ready() -> void:
	level_id = "ice_glacier"
	level_title = "GLACIER RUN"
	spawn_point = Vector3(-4.0, 3.0, 0.0)
	time_limit = 50.0
	music_theme = "ice"
	use_camera_bounds = true
	camera_bounds_min = Vector2(-2.0, -8.0)
	camera_bounds_max = Vector2(128.0, 30.0)
	super._ready()
	camera.height_offset = 2.6


func _mood() -> LightingRig.Mood:
	var mood := LightingRig.Mood.new()
	# Twilight over ice: a low cold key, a strong sky, and a violet fill. The
	# whole level is lit to make white read as white and ice read as deep.
	mood.sun_angles = Vector2(-8.0, 138.0)
	mood.sun_color = Color(0.76, 0.90, 1.0)
	mood.sun_energy = 2.3
	mood.sun_angular_distance = 0.9
	mood.sun_fog_energy = 2.6
	mood.sun_disc_size = 2.4

	mood.fill_angles = Vector2(22.0, -40.0)
	mood.fill_color = Color(0.46, 0.44, 0.78)
	mood.fill_energy = 0.55

	mood.rim_angles = Vector2(-6.0, 106.0)
	mood.rim_color = Color(0.70, 0.94, 1.0)
	mood.rim_energy = 5.0
	mood.rim_cull_mask = 2
	mood.hero_fill_energy = 1.7
	mood.hero_fill_color = Color(0.80, 0.86, 1.0)
	mood.hero_fill_angles = Vector2(-16.0, -34.0)

	mood.sky_top = Color(0.043, 0.055, 0.153)
	mood.sky_horizon = Color(0.302, 0.482, 0.690)
	mood.ground_horizon = Color(0.322, 0.404, 0.522)
	mood.ground_bottom = Color(0.086, 0.114, 0.184)
	mood.sky_energy = 0.9
	mood.sky_curve = 0.16
	mood.ambient_energy = 0.34

	mood.fog_color = Color(0.588, 0.729, 0.878)
	mood.fog_density = 0.0040
	mood.fog_sun_scatter = 0.55
	mood.fog_emission = Color(0.10, 0.16, 0.28)
	mood.fog_anisotropy = 0.72
	mood.volumetric_density = 0.0045

	mood.tonemap = Environment.TONE_MAPPER_ACES
	mood.exposure = 0.86
	mood.white = 7.0
	mood.glow_intensity = 0.55
	mood.glow_hdr_threshold = 1.35
	mood.adjustment_saturation = 1.14
	mood.adjustment_contrast = 1.06
	return mood


func _build_level() -> void:
	m = {
		"ice": MaterialLab.ice(1.0),
		"packed": MaterialLab.ice(0.35),
		"snow": MaterialLab.ice(0.05, Color(0.62, 0.72, 0.86)),
		"rock": MaterialLab.concrete(Color(0.145, 0.165, 0.224), 1.0),
	}
	_backdrop()
	_route()
	_atmosphere_ice()


func _backdrop() -> void:
	# The frozen sea, flat to the horizon, catching the low sun.
	var sea := MaterialLab.ice(1.0, Color(0.05, 0.20, 0.36))
	sea.set_shader_parameter("roughness_value", 0.05)
	sea.set_shader_parameter("frost_amount", 0.18)
	LevelKit.prop(geometry, Vector3(60.0, -14.0, -120.0), Vector3(900.0, 6.0, 260.0),
		sea, "FrozenSea")

	# Spires. Big, irregular, and placed so the route always has something
	# vertical behind it.
	for i in 16:
		var x := -40.0 + i * 13.0 + fmod(float(i) * 5.7, 7.0)
		var z := -26.0 - fmod(float(i) * 9.3, 52.0)
		var h := 16.0 + fmod(float(i) * 11.7, 30.0)
		var w := 3.4 + fmod(float(i) * 3.1, 3.4)
		var spire := LevelKit.prop(geometry, Vector3(x, -10.0 + h * 0.5, z),
			Vector3(w, h, w * 0.8), (m["ice"] if i % 3 == 0 else m["packed"]) as Material,
			"Spire%d" % i)
		spire.rotation = Vector3(0.0, fmod(float(i) * 0.7, TAU), fmod(float(i) * 0.11, 0.14) - 0.07)

	for i in 9:
		var x := -60.0 + i * 24.0
		var h := 34.0 + fmod(float(i) * 13.1, 26.0)
		LevelKit.prop(geometry, Vector3(x, -14.0 + h * 0.5, -150.0),
			Vector3(18.0, h, 6.0), m["snow"], "FarPeak%d" % i)

	# Aurora: three wide emissive bands at altitude, each a different hue and
	# each very slightly tilted, so they read as curtains rather than stripes.
	var hues := [Color(0.35, 1.0, 0.72), Color(0.42, 0.70, 1.0), Color(0.78, 0.48, 1.0)]
	for i in 3:
		var mat := ShaderMaterial.new()
		mat.shader = AURORA_SHADER
		mat.set_shader_parameter("tint", hues[i])
		mat.set_shader_parameter("strength", 1.0 - i * 0.22)
		mat.set_shader_parameter("noise_tex", NoiseBank.streaks(53 + i * 7))
		mat.set_shader_parameter("streak_scale", 2.4 + i * 1.1)
		mat.set_shader_parameter("drift_speed", 0.010 + i * 0.006)
		mat.set_shader_parameter("base_fade", 0.62 - i * 0.12)
		var band := LevelKit.prop(geometry,
			Vector3(50.0 + i * 14.0, 46.0 + i * 11.0, -200.0 - i * 24.0),
			Vector3(360.0, 44.0 - i * 7.0, 1.0), mat, "Aurora%d" % i)
		band.rotation.z = 0.05 - i * 0.045


## The route. Every segment has a platform under it and the next segment is
## always visible from the one before.
func _route() -> void:
	var shelf: Material = m["packed"]
	var slab: Material = m["ice"]

	# 1 — a flat run in. 12 bottles.
	LevelKit.platform(geometry, -8.0, 0.0, 26.0, shelf, 8.0, 3.4, "Shelf1")
	TrailBuilder.line(geometry, Vector3(-4.0, 1.0, 0.0), Vector3(14.0, 1.0, 0.0), 12, ICE_VARIANT)

	# 2 — a jump arc onto a higher slab. 8.
	LevelKit.platform(geometry, 22.0, 2.6, 12.0, slab, 9.0, 3.4, "Slab2")
	TrailBuilder.jump_arc(geometry, Vector3(17.0, 1.1, 0.0), 1.0, 1.0, 8, 1.0, ICE_VARIANT)

	# 3 — run along the top. 10.
	TrailBuilder.line(geometry, Vector3(24.0, 3.6, 0.0), Vector3(33.0, 3.6, 0.0), 10, ICE_VARIANT)

	# 4 — a dip across a gap. 8.
	LevelKit.platform(geometry, 38.0, 1.4, 16.0, shelf, 8.0, 3.4, "Shelf3")
	TrailBuilder.curve(geometry, Vector3(34.5, 3.6, 0.0), Vector3(40.5, 2.4, 0.0), 1.7, 8, ICE_VARIANT)

	# 5 — a reward ring over an ice arch. 9.
	_arch(Vector3(48.0, 1.4, 0.0), 7.4, 3.4)
	TrailBuilder.cluster(geometry, Vector3(48.0, 5.2, 0.0), 1.0, 8, ICE_VARIANT)

	# 6 — the long shelf. 12.
	LevelKit.platform(geometry, 56.0, 1.4, 24.0, shelf, 8.0, 3.4, "Shelf4")
	TrailBuilder.line(geometry, Vector3(60.0, 2.4, 0.0), Vector3(76.0, 2.4, 0.0), 12, ICE_VARIANT)

	# 7 — up onto a stack. 8.
	LevelKit.platform(geometry, 84.0, 3.8, 11.0, slab, 11.0, 3.4, "Slab5")
	TrailBuilder.jump_arc(geometry, Vector3(78.0, 2.4, 0.0), 1.0, 1.0, 8, 1.0, ICE_VARIANT)

	# 8 — across to the last shelf. 8.
	LevelKit.platform(geometry, 100.0, 3.0, 18.0, shelf, 10.0, 3.4, "Shelf6")
	TrailBuilder.curve(geometry, Vector3(93.0, 4.8, 0.0), Vector3(101.5, 4.0, 0.0), 1.6, 8, ICE_VARIANT)

	# 9 — the last ring. 9.
	_arch(Vector3(109.0, 3.0, 0.0), 6.4, 3.0)
	TrailBuilder.cluster(geometry, Vector3(109.0, 6.6, 0.0), 1.0, 8, ICE_VARIANT)

	# 10 — the run out. 12.
	TrailBuilder.line(geometry, Vector3(102.0, 4.0, 0.0), Vector3(113.0, 4.0, 0.0), 12, ICE_VARIANT)

	LevelKit.box(geometry, Vector3(119.4, 6.0, 0.0), Vector3(1.6, 7.0, 3.4),
		slab, "EndWall")

	# 11 — and the last four, stacked, so the hundredth is above his head.
	TrailBuilder.column(geometry, Vector3(114.0, 4.2, 0.0), 2.6, 4, ICE_VARIANT)


## A frozen arch: two legs and a span, with the reward ring sitting over it.
func _arch(base: Vector3, width: float, height: float) -> void:
	for side: float in [-1.0, 1.0]:
		var leg := LevelKit.prop(geometry,
			base + Vector3(side * width * 0.5, height * 0.5, -2.6),
			Vector3(1.3, height, 1.6), m["ice"], "ArchLeg")
		leg.rotation.z = -side * 0.09
	LevelKit.prop(geometry, base + Vector3(0.0, height + 0.5, -2.6),
		Vector3(width + 1.6, 1.1, 1.8), m["ice"], "ArchSpan")


func _atmosphere_ice() -> void:
	# Snow drifting across, plus a low mist that the spires rise out of.
	var p := GPUParticles3D.new()
	p.name = "Snow"
	p.amount = 420
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.fixed_fps = 30
	p.interpolate = true
	p.local_coords = false
	p.position = Vector3(56.0, 12.0, -6.0)
	p.visibility_aabb = AABB(Vector3(-90, -40, -30), Vector3(180, 80, 60))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(80.0, 22.0, 14.0)
	pm.direction = Vector3(-0.8, -1.0, 0.0)
	pm.spread = 24.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(-0.6, -1.6, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 1.6
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 0.075)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.86, 0.95, 1.0, 0.55)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)

	var fv := FogVolume.new()
	fv.name = "GlacierMist"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(260.0, 8.0, 70.0)
	fv.position = Vector3(56.0, -6.0, -30.0)
	var fm := FogMaterial.new()
	fm.density = 0.055
	fm.albedo = Color(0.80, 0.90, 1.0)
	fm.emission = Color(0.05, 0.10, 0.20)
	fm.height_falloff = 1.0
	fm.edge_fade = 0.4
	fv.material = fm
	add_child(fv)
