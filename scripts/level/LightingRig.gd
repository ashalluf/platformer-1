class_name LightingRig
## Cinematographer in a box.
##
## A level declares a mood — time of day, sun angle, colour temperature, fog —
## and this builds the key / fill / rim setup and the Environment to match.
## Keeping it in one place is what stops World 1 drifting into five different
## looking games.

class Mood extends RefCounted:
	var sun_energy := 2.4
	var sun_color := Color(1.0, 0.86, 0.66)
	var sun_angles := Vector2(-42.0, 38.0)   ## pitch, yaw in degrees
	var sun_angular_distance := 1.1          ## soft shadow width
	var sun_fog_energy := 2.4                ## how hard the key writes into volumetrics

	var fill_energy := 0.55
	var fill_color := Color(0.42, 0.55, 0.78)
	var fill_angles := Vector2(-18.0, -140.0)

	var rim_energy := 1.5
	var rim_color := Color(0.85, 0.72, 1.0)
	var rim_angles := Vector2(-6.0, 178.0)
	## Render layers the rim may touch. The hero is on layer 2; a rim that also
	## lights the world is just a second key and it flattens everything.
	var rim_cull_mask := 0xFFFFF

	## A fill that touches only the hero layer. Lets the world sit in true
	## shadow while the character keeps a readable front value — the single
	## most useful light in a back-lit scene.
	var hero_fill_energy := 0.0
	var hero_fill_color := Color(0.78, 0.82, 0.92)
	var hero_fill_angles := Vector2(-12.0, -24.0)
	var hero_cull_mask := 2

	var sky_top := Color(0.22, 0.36, 0.62)
	var sky_horizon := Color(0.72, 0.68, 0.60)
	var ground_horizon := Color(0.38, 0.32, 0.27)
	var ground_bottom := Color(0.18, 0.14, 0.12)
	var sky_energy := 1.0
	## How fast the horizon colour gives way to the zenith colour. Low values
	## keep the warm band tight to the horizon instead of flooding the sky.
	var sky_curve := 0.15
	## Angular size of the sun disc the sky paints, in degrees.
	var sun_disc_size := 3.5
	var ground_curve := 0.2
	var volumetric_density := 0.0025

	var ambient_energy := 0.30
	var fog_color := Color(0.62, 0.58, 0.52)
	var fog_density := 0.0022
	var fog_sun_scatter := 0.35
	var fog_emission := Color(0.35, 0.30, 0.26)
	var fog_anisotropy := 0.72

	var glow_intensity := 0.55
	var glow_bloom := 0.0        ## >0 is guaranteed washout; keep it at zero
	var glow_hdr_threshold := 1.05

	var tonemap := Environment.TONE_MAPPER_AGX
	var exposure := 1.0
	var white := 6.0

	var dof_distance := 0.0
	var dof_transition := 18.0
	var dof_amount := 0.10
	var dof_near_distance := 0.0     ## 0 disables the near blur
	var dof_near_transition := 4.0

	var adjustment_saturation := 1.10
	var adjustment_contrast := 1.10
	var adjustment_brightness := 1.0


static func neutral_studio() -> Mood:
	## Greybox mood: warm key, cool fill, enough contrast to judge silhouettes.
	var m := Mood.new()
	m.sun_energy = 3.4
	m.sun_color = Color(1.0, 0.91, 0.78)
	m.sun_angles = Vector2(-38.0, 42.0)
	m.fill_color = Color(0.46, 0.58, 0.80)
	m.fill_energy = 0.45
	m.rim_color = Color(0.62, 0.78, 1.0)
	m.rim_energy = 2.6
	m.sky_top = Color(0.14, 0.26, 0.52)
	m.sky_horizon = Color(0.74, 0.72, 0.66)
	m.ground_horizon = Color(0.30, 0.27, 0.25)
	m.ground_bottom = Color(0.14, 0.13, 0.13)
	m.fog_color = Color(0.60, 0.66, 0.74)
	m.fog_density = 0.0020
	return m


static func build(parent: Node3D, mood: Mood) -> WorldEnvironment:
	var env := Environment.new()

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = mood.sky_top
	sky_mat.sky_horizon_color = mood.sky_horizon
	sky_mat.ground_horizon_color = mood.ground_horizon
	sky_mat.ground_bottom_color = mood.ground_bottom
	sky_mat.sky_energy_multiplier = mood.sky_energy
	sky_mat.sun_angle_max = mood.sun_disc_size
	sky_mat.sun_curve = 0.18
	sky_mat.sky_curve = mood.sky_curve
	sky_mat.ground_curve = mood.ground_curve
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = mood.ambient_energy

	env.tonemap_mode = mood.tonemap
	env.tonemap_exposure = mood.exposure
	env.tonemap_white = mood.white

	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.2
	env.ssao_detail = 0.6

	env.ssil_enabled = true
	env.ssil_radius = 2.2   ## the 5.0 default bleeds background onto the hero
	env.ssil_intensity = 0.9

	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.4
	env.ssr_fade_out = 2.5

	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy = 1.0

	env.glow_enabled = true
	env.glow_intensity = mood.glow_intensity
	env.glow_bloom = mood.glow_bloom
	env.glow_hdr_threshold = mood.glow_hdr_threshold
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Energy only in the wide levels — levels 1 and 2 carrying energy is the
	# cheap-bloom halo.
	env.set("glow_levels/1", 0.0)
	env.set("glow_levels/2", 0.0)
	env.set("glow_levels/3", 0.6)
	env.set("glow_levels/4", 1.0)
	env.set("glow_levels/5", 1.0)
	env.glow_strength = 1.0

	env.fog_enabled = true
	env.fog_light_color = mood.fog_color
	env.fog_density = mood.fog_density
	env.fog_sun_scatter = mood.fog_sun_scatter
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.16

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = mood.volumetric_density
	env.volumetric_fog_albedo = mood.fog_color
	env.volumetric_fog_emission = mood.fog_emission
	env.volumetric_fog_emission_energy = 0.15
	env.volumetric_fog_gi_inject = 1.0
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_detail_spread = 2.0
	# The 0.2 default means no sun shaft will ever form.
	env.volumetric_fog_anisotropy = mood.fog_anisotropy
	env.volumetric_fog_temporal_reprojection_amount = 0.68

	env.adjustment_enabled = true
	env.adjustment_saturation = mood.adjustment_saturation
	env.adjustment_contrast = mood.adjustment_contrast
	env.adjustment_brightness = mood.adjustment_brightness

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	# Depth of field lives on CameraAttributes in Godot 4, not on Environment.
	# Near blur is what turns a foreground occluder into a shape rather than an
	# object competing with the subject.
	if mood.dof_near_distance > 0.0 or mood.dof_distance > 0.0:
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_amount = mood.dof_amount
		if mood.dof_near_distance > 0.0:
			ca.dof_blur_near_enabled = true
			ca.dof_blur_near_distance = mood.dof_near_distance
			ca.dof_blur_near_transition = mood.dof_near_transition
		if mood.dof_distance > 0.0:
			ca.dof_blur_far_enabled = true
			ca.dof_blur_far_distance = mood.dof_distance
			ca.dof_blur_far_transition = mood.dof_transition
		we.camera_attributes = ca
	we.add_to_group("world_environment")
	parent.add_child(we)

	_light(parent, "Sun", mood.sun_angles, mood.sun_color, mood.sun_energy, true,
		mood.sun_angular_distance, "sun", mood.sun_fog_energy)
	_light(parent, "Fill", mood.fill_angles, mood.fill_color, mood.fill_energy, false, 4.0, "")
	var rim := _light(parent, "Rim", mood.rim_angles, mood.rim_color, mood.rim_energy, false, 2.0, "")
	rim.light_cull_mask = mood.rim_cull_mask

	if mood.hero_fill_energy > 0.0:
		var hero := _light(parent, "HeroFill", mood.hero_fill_angles, mood.hero_fill_color,
			mood.hero_fill_energy, false, 3.0, "")
		hero.light_cull_mask = mood.hero_cull_mask

	return we


static func _light(parent: Node3D, name_: String, angles: Vector2, color: Color,
		energy: float, shadows: bool, angular: float, group: String,
		fog_energy := 0.0) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = name_
	l.rotation_degrees = Vector3(angles.x, angles.y, 0.0)
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadows
	l.light_angular_distance = angular
	if not shadows:
		l.light_volumetric_fog_energy = 0.0
		# ProceduralSkyMaterial draws a disc for EVERY directional light. Fill
		# and rim lights are shaping tools, not suns, and must not paint one.
		l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	if shadows:
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		l.directional_shadow_max_distance = 160.0
		l.directional_shadow_blend_splits = true
		l.shadow_bias = 0.03
		l.shadow_normal_bias = 0.8   ## 2.0 default peter-pans small props
		l.shadow_opacity = 0.84
		l.light_volumetric_fog_energy = fog_energy
	else:
		# Fill and rim must not double-count in GI; they exist for shaping only.
		l.light_specular = 0.35 if name_ == "Fill" else 1.2
	if group != "":
		l.add_to_group(group)
	parent.add_child(l)
	return l
