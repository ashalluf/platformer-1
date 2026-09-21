extends Stage
## Character sign-off stand.
##
## Wanis on a plinth under a three-point setup, framed tight. This is where the
## silhouette gets judged before he goes anywhere near a level.


func _ready() -> void:
	level_id = "char_lab"
	level_title = "CHARACTER"
	spawn_point = Vector3(0.0, 1.2, 0.0)
	kill_plane_y = -20.0
	super._ready()
	camera.distance = 4.2
	camera.base_fov = 30.0
	camera.height_offset = 0.95
	camera.look_ahead = 0.0
	camera.speed_fov_gain = 0.0


func _mood() -> LightingRig.Mood:
	var m := LightingRig.neutral_studio()
	m.sun_energy = 3.6
	m.sun_color = Color(1.0, 0.90, 0.76)
	m.sun_angles = Vector2(-28.0, 46.0)
	m.sun_angular_distance = 0.8
	m.fill_energy = 0.55
	m.fill_color = Color(0.40, 0.55, 0.85)
	m.fill_angles = Vector2(-10.0, -128.0)
	m.rim_energy = 3.2
	m.rim_color = Color(0.70, 0.82, 1.0)
	m.rim_angles = Vector2(2.0, 186.0)
	m.ambient_energy = 0.28
	m.fog_density = 0.004
	m.sky_top = Color(0.10, 0.17, 0.34)
	m.sky_horizon = Color(0.52, 0.55, 0.58)
	m.ground_horizon = Color(0.26, 0.23, 0.21)
	m.adjustment_contrast = 1.12
	return m


func _build_level() -> void:
	var plinth := MaterialLab.concrete(Color(0.34, 0.34, 0.35), 0.8)
	LevelKit.box(geometry, Vector3(0.0, -0.30, 0.0), Vector3(6.0, 0.6, 4.0), plinth, "Plinth")
	# Backdrop far enough away to go soft, so he separates cleanly.
	LevelKit.prop(geometry, Vector3(0.0, 4.0, -7.0), Vector3(24.0, 14.0, 0.5),
		MaterialLab.plaster(Color(0.40, 0.40, 0.42), 0.6), "Backdrop")
