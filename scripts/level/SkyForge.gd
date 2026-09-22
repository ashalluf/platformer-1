class_name SkyForge
## The procedural sky.
##
## A level adopts it in one line, straight after LightingRig has built the rig:
## [codeblock]
## var we := LightingRig.build(self, mood)
## SkyForge.apply(we.environment, "brega_gold")
## [/codeblock]
## That swaps out the [ProceduralSkyMaterial] LightingRig installs and points
## the Environment's ambient and reflections at the new sky. Nothing else needs
## changing: the shader reads the scene's own shadow-casting DirectionalLight
## for the sun, so the disc always lands where the key actually is and the two
## can never drift apart.
##
## Presets: [code]brega_gold[/code], [code]ajdabiya_morning[/code],
## [code]ice_twilight[/code], [code]studio[/code]. Use [method material] instead
## of [method apply] when a level wants to tune a knob on top of a preset.

const SKY_SHADER := preload("res://shaders/sky.gdshader")


## Builds a tuned [ShaderMaterial] for [Sky.sky_material]. Always a fresh
## instance — levels dial these by eye and a shared material would leak the
## tuning of one level into the next.
static func material(preset: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKY_SHADER
	var values := _preset(preset)
	for key in values:
		m.set_shader_parameter(key, values[key])
	return m


## One-line adoption. Builds the Sky resource, assigns the preset and puts the
## Environment on sky-sourced ambient and reflections.
static func apply(env: Environment, preset: String) -> void:
	if env == null:
		push_warning("SkyForge.apply: no Environment; preset '%s' ignored." % preset)
		return

	var sky := env.sky
	if sky == null:
		sky = Sky.new()
		env.sky = sky
	sky.sky_material = material(preset)
	# The cloud decks drift, so the radiance cubemap has to follow or the
	# ambient term freezes on the first frame. REALTIME re-renders every frame
	# for a sky that changes over minutes; INCREMENTAL spreads one full update
	# across several frames for a fraction of the cost and nobody can tell.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0


## Converts a LightingRig-style (pitch, yaw) light rotation into the direction
## pointing TOWARD the sun, which is what the shader wants. Pitch is negative
## above the horizon, matching [code]DirectionalLight3D.rotation_degrees[/code],
## so a mood's [code]sun_angles[/code] can be handed straight in.
static func sun_direction(pitch_deg: float, yaw_deg: float) -> Vector3:
	var p := deg_to_rad(pitch_deg)
	var y := deg_to_rad(yaw_deg)
	return Vector3(cos(p) * sin(y), -sin(p), cos(p) * cos(y)).normalized()


static func _preset(name_: String) -> Dictionary:
	match name_:
		"brega_gold":
			return _brega_gold()
		"ajdabiya_morning":
			return _ajdabiya_morning()
		"ice_twilight":
			return _ice_twilight()
		"studio":
			return _studio()
	push_warning("SkyForge: unknown preset '%s'; using 'studio'." % name_)
	return _studio()


## Level 1, 05:52. Pre-dawn blue cracking into first sun, with the last stars
## still up and a high cirrus deck already catching light the ground has not
## seen yet. The warm band is tight and low because the sun has not cleared the
## horizon — it is a glow behind the prilling towers, not a light source.
static func _brega_gold() -> Dictionary:
	return {
		# Level 1, 09:30. The brief asked for bright, colourful and lush, and a
		# dawn cannot be any of those: a sky whose only light is a 2200 K glow
		# below the horizon gives the whole frame one hue to work with. This is
		# the same coast three hours later -- a real blue zenith, big white
		# cumulus with genuine shadow sides, and the sun up and out of shot.
		"zenith_color": Color("#4f7bb0"),
		"mid_color": Color("#c9a68f"),
		"horizon_color": Color("#ffdfb4"),
		"ground_color": Color("#6a6250"),
		"horizon_falloff": 0.18,
		"zenith_compression": 1.05,
		"ground_falloff": 0.32,
		"sky_energy": 1.15,

		"band_color": Color("#ffeccb"),
		"band_strength": 0.22,
		"band_height": 0.055,
		"dust_color": Color("#e8c9a4"),
		"dust": 0.12,
		"dust_height": 0.18,

		# Matched to the rig key. A sky sun and a scene key that disagree is the
		# one error this whole class exists to make impossible.
		"sun_direction": sun_direction(26.0, 32.0),
		"sun_color": Color("#fff0cf"),
		"sun_intensity": 3.2,
		"sun_angular_radius": 0.55,
		"sun_edge_softness": 0.14,
		"sun_limb_darkening": 0.55,
		# The old glow was 2.2 of #ff8a2e, which is what burned a hole through
		# the right third of every Brega frame.
		"sun_glow_color": Color("#ffdca6"),
		"sun_glow_strength": 0.85,
		"sun_glow_falloff": 640.0,
		"sun_halo_color": Color("#dceaf6"),
		"sun_halo_strength": 0.14,
		"sun_halo_falloff": 6.5,
		"sun_horizon_spread": 0.28,
		"sun_haze_extinction": 1.0,

		# Real cumulus is the cheapest colour in any outdoor frame: a white top
		# and a blue-grey underside give the sky its own value range, so it
		# stops being a gradient behind the level and becomes part of the shot.
		"wind_direction": 0.55,
		"cloud_horizon_fade": 0.10,
		"cirrus_color": Color("#ffdcb4"),
		"cirrus_shadow_color": Color("#94879f"),
		"cirrus_opacity": 0.55,
		"cirrus_coverage": 0.48,
		"cirrus_scale": 0.45,
		"cirrus_stretch": 5.5,
		"cirrus_angle": 0.42,
		"cirrus_speed": 0.016,
		"cirrus_height": 3.0,
		"cirrus_horizon_fade": 0.20,
		"cumulus_color": Color("#fff0d8"),
		"cumulus_shadow_color": Color("#7d7f9c"),
		"cumulus_opacity": 0.95,
		"cumulus_coverage": 0.54,
		"cumulus_softness": 0.20,
		"cumulus_scale": 0.42,
		"cumulus_height": 0.80,
		"cumulus_speed": 0.030,
		"cumulus_detail": 0.72,
		"cumulus_silver": 4.1,
		"cumulus_light_step": 0.30,

		# Daylight: no stars.
		"star_color": Color("#b9c6e8"),
		"star_strength": 0.0,
		"star_density": 170.0,
		"star_threshold": 0.962,
		"star_twinkle": 0.35,
		"star_horizon_fade": 0.30,
		"aurora_strength": 0.0,
	}


## Level 2, 09:10. Clear mid-morning. The zenith is the only genuinely blue
## thing in World 1 and the haze is the heaviest of the daytime presets — this
## coast is milky by mid-morning and pretending otherwise reads as Spain.
static func _ajdabiya_morning() -> Dictionary:
	return {
		"zenith_color": Color("#3a72a2"),
		"mid_color": Color("#82a7c2"),
		"horizon_color": Color("#d5cdbd"),
		"ground_color": Color("#c0b49c"),
		"horizon_falloff": 0.15,
		"zenith_compression": 1.00,
		"ground_falloff": 0.35,
		"sky_energy": 1.0,

		"band_color": Color("#e4dac6"),
		"band_strength": 0.48,
		"band_height": 0.13,
		"dust_color": Color("#cbbb9e"),
		"dust": 0.44,
		"dust_height": 0.22,

		"sun_direction": sun_direction(-34.0, 125.0),
		"sun_color": Color("#ffdabb"),
		"sun_intensity": 12.0,
		"sun_angular_radius": 0.95,
		"sun_edge_softness": 0.10,
		"sun_limb_darkening": 0.58,
		"sun_glow_color": Color("#ffd0a0"),
		"sun_glow_strength": 2.0,
		"sun_glow_falloff": 700.0,
		"sun_halo_color": Color("#ffe0c0"),
		"sun_halo_strength": 0.35,
		"sun_halo_falloff": 4.2,
		"sun_horizon_spread": 0.90,
		"sun_haze_extinction": 0.90,

		"wind_direction": 0.60,
		"cloud_horizon_fade": 0.12,
		"cirrus_color": Color("#f6ece0"),
		"cirrus_shadow_color": Color("#9aa6b2"),
		"cirrus_opacity": 0.32,
		"cirrus_coverage": 0.30,
		"cirrus_scale": 0.60,
		"cirrus_stretch": 5.0,
		"cirrus_angle": 0.30,
		"cirrus_speed": 0.008,
		"cirrus_height": 2.8,
		"cirrus_horizon_fade": 0.18,
		"cumulus_color": Color("#f7f4ec"),
		"cumulus_shadow_color": Color("#9aa0a8"),
		"cumulus_opacity": 0.88,
		"cumulus_coverage": 0.38,
		"cumulus_softness": 0.13,
		"cumulus_scale": 0.50,
		"cumulus_height": 0.60,
		"cumulus_speed": 0.014,
		"cumulus_detail": 0.42,
		"cumulus_silver": 3.0,
		"cumulus_light_step": 0.32,

		"star_strength": 0.0,
		"aurora_strength": 0.0,
	}


## Ice bonus world, twilight. Sun just on the horizon behind camera-left, clean
## cold air (almost no aerosol, so the band stays thin and the gradient keeps
## its contrast), full stars and an aurora ribbon high in the dome.
static func _ice_twilight() -> Dictionary:
	return {
		"zenith_color": Color("#131a3f"),
		"mid_color": Color("#2e4c7c"),
		"horizon_color": Color("#7fa8c4"),
		"ground_color": Color("#253247"),
		"horizon_falloff": 0.11,
		"zenith_compression": 1.35,
		"ground_falloff": 0.28,
		"sky_energy": 1.0,

		"band_color": Color("#cfe2ec"),
		"band_strength": 0.24,
		"band_height": 0.050,
		"dust_color": Color("#93a9bd"),
		"dust": 0.12,
		"dust_height": 0.16,

		"sun_direction": sun_direction(-1.5, -132.0),
		"sun_color": Color("#ffb894"),
		"sun_intensity": 4.0,
		"sun_angular_radius": 1.30,
		"sun_edge_softness": 0.25,
		"sun_limb_darkening": 0.72,
		"sun_glow_color": Color("#ff9a78"),
		"sun_glow_strength": 2.2,
		"sun_glow_falloff": 260.0,
		"sun_halo_color": Color("#b98cc0"),
		"sun_halo_strength": 0.60,
		"sun_halo_falloff": 2.4,
		"sun_horizon_spread": 1.20,
		"sun_haze_extinction": 1.00,

		"wind_direction": -0.40,
		"cloud_horizon_fade": 0.08,
		"cirrus_color": Color("#dbe8fa"),
		"cirrus_shadow_color": Color("#3c4a73"),
		"cirrus_opacity": 0.34,
		"cirrus_coverage": 0.44,
		"cirrus_scale": 0.55,
		"cirrus_stretch": 6.0,
		"cirrus_angle": -0.50,
		"cirrus_speed": 0.010,
		"cirrus_height": 3.20,
		"cirrus_horizon_fade": 0.18,
		"cumulus_color": Color("#9fb6d8"),
		"cumulus_shadow_color": Color("#26304f"),
		"cumulus_opacity": 0.50,
		"cumulus_coverage": 0.16,
		"cumulus_softness": 0.24,
		"cumulus_scale": 0.50,
		"cumulus_height": 0.70,
		"cumulus_speed": 0.012,
		"cumulus_detail": 0.40,
		"cumulus_silver": 2.0,
		"cumulus_light_step": 0.30,

		"star_color": Color("#dce8ff"),
		"star_strength": 2.20,
		"star_density": 165.0,
		"star_threshold": 0.940,
		"star_twinkle": 0.55,
		"star_horizon_fade": 0.22,
		"aurora_low_color": Color("#59ffb8"),
		"aurora_high_color": Color("#8c6cff"),
		"aurora_strength": 1.35,
		"aurora_altitude": 0.34,
		"aurora_thickness": 0.15,
		"aurora_wave": 0.18,
		"aurora_streak": 9.0,
		"aurora_speed": 0.05,
	}


## Greybox / lookdev. Neutral enough to judge a silhouette against, with real
## clouds so a capture of an unfinished level is still read as a sky and not as
## a backdrop. Sun matches LightingRig.neutral_studio's key.
static func _studio() -> Dictionary:
	return {
		"zenith_color": Color("#2a4a80"),
		"mid_color": Color("#7193b4"),
		"horizon_color": Color("#c2c2ba"),
		"ground_color": Color("#4a463f"),
		"horizon_falloff": 0.18,
		"zenith_compression": 1.05,
		"ground_falloff": 0.40,
		"sky_energy": 1.0,

		"band_color": Color("#d8d6ce"),
		"band_strength": 0.35,
		"band_height": 0.09,
		"dust_color": Color("#b8b6ac"),
		"dust": 0.20,
		"dust_height": 0.20,

		"sun_direction": sun_direction(-38.0, 42.0),
		"sun_color": Color("#ffe8cc"),
		"sun_intensity": 11.0,
		"sun_angular_radius": 1.00,
		"sun_edge_softness": 0.12,
		"sun_limb_darkening": 0.60,
		"sun_glow_color": Color("#ffd8b4"),
		"sun_glow_strength": 1.80,
		"sun_glow_falloff": 620.0,
		"sun_halo_color": Color("#ffe6cc"),
		"sun_halo_strength": 0.35,
		"sun_halo_falloff": 4.00,
		"sun_horizon_spread": 0.70,
		"sun_haze_extinction": 0.70,

		"wind_direction": 0.45,
		"cloud_horizon_fade": 0.11,
		"cirrus_color": Color("#f2f0ea"),
		"cirrus_shadow_color": Color("#98a2ac"),
		"cirrus_opacity": 0.30,
		"cirrus_coverage": 0.34,
		"cirrus_scale": 0.60,
		"cirrus_stretch": 5.0,
		"cirrus_angle": 0.35,
		"cirrus_speed": 0.008,
		"cirrus_height": 2.60,
		"cirrus_horizon_fade": 0.16,
		"cumulus_color": Color("#fbfaf6"),
		"cumulus_shadow_color": Color("#939aa4"),
		"cumulus_opacity": 0.90,
		"cumulus_coverage": 0.34,
		"cumulus_softness": 0.15,
		"cumulus_scale": 0.52,
		"cumulus_height": 0.70,
		"cumulus_speed": 0.012,
		"cumulus_detail": 0.40,
		"cumulus_silver": 2.40,
		"cumulus_light_step": 0.32,

		"star_strength": 0.0,
		"aurora_strength": 0.0,
	}
