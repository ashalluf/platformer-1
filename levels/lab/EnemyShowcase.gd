extends Stage
## Every enemy and hazard in one frame, under neutral light.
##
## A level is the wrong place to sign off a machine: it is dark, it is hazy,
## and whatever you are looking at is thirty units away behind a pipe rack.
## This is flat ground, a grey card and a parked camera, so a silhouette can be
## judged as a silhouette.

const GROUND_Y := 0.0


func _ready() -> void:
	level_id = "enemy_showcase"
	level_title = "ENEMY SHOWCASE"
	spawn_point = Vector3(-9.0, 1.2, 0.0)
	kill_plane_y = -20.0
	show_hud = false
	super._ready()
	camera.height_offset = 1.4
	camera.distance = 15.0
	camera.base_fov = 36.0
	camera.lateral_offset = -7.5


func _mood() -> LightingRig.Mood:
	var m := LightingRig.Mood.new()
	# A three-quarter key high enough to shape a box, a cool fill, and a rim to
	# separate every silhouette from the card behind it.
	m.sun_angles = Vector2(-38.0, 36.0)
	m.sun_color = Color(1.0, 0.94, 0.86)
	m.sun_energy = 2.6
	m.sun_disc_size = 0.0
	m.fill_angles = Vector2(-16.0, -128.0)
	m.fill_color = Color(0.62, 0.70, 0.86)
	m.fill_energy = 0.55
	m.rim_angles = Vector2(-10.0, 176.0)
	m.rim_color = Color(1.0, 0.92, 0.84)
	m.rim_energy = 2.2
	m.sky_top = Color(0.235, 0.245, 0.268)
	m.sky_horizon = Color(0.330, 0.330, 0.340)
	m.ground_horizon = Color(0.200, 0.198, 0.196)
	m.ground_bottom = Color(0.120, 0.118, 0.118)
	m.ambient_energy = 0.45
	m.fog_density = 0.0
	m.volumetric_density = 0.0
	m.exposure = 1.0
	m.glow_intensity = 0.18
	m.glow_hdr_threshold = 1.6
	m.adjustment_saturation = 1.05
	m.adjustment_contrast = 1.04
	return m


func _build_level() -> void:
	var floor_mat := MaterialLab.concrete(Color(0.185, 0.182, 0.180), 0.7)
	var card := MaterialLab.plaster(Color(0.245, 0.242, 0.240), 0.3)

	LevelKit.box(geometry, Vector3(6.0, GROUND_Y - 1.0, 0.0),
		Vector3(72.0, 2.0, 6.0), floor_mat, "Floor")
	LevelKit.prop(geometry, Vector3(6.0, GROUND_Y + 7.0, -9.0),
		Vector3(72.0, 18.0, 0.6), card, "Card")

	# A metre grid on the card, so a silhouette can be measured and not just
	# admired.
	for i in 13:
		LevelKit.prop(geometry, Vector3(-12.0 + i * 3.0, GROUND_Y + 7.0, -8.66),
			Vector3(0.03, 18.0, 0.03), floor_mat, "GridV%d" % i)
	for i in 7:
		LevelKit.prop(geometry, Vector3(6.0, GROUND_Y + i * 2.0, -8.66),
			Vector3(72.0, 0.03, 0.03), floor_mat, "GridH%d" % i)

	var drone := SnitchDrone.new()
	drone.position = Vector3(-2.0, GROUND_Y + 2.6, 0.0)
	drone.patrol_span = 1.5
	geometry.add_child(drone)

	var turret := WallTurret.new()
	turret.position = Vector3(5.0, GROUND_Y + 2.4, 0.0)
	geometry.add_child(turret)
	# A post for it to be bolted to, because a turret floating in air reads as
	# a bug rather than as a turret.
	LevelKit.prop(geometry, Vector3(5.5, GROUND_Y + 1.2, 0.0),
		Vector3(0.34, 2.6, 0.34), floor_mat, "TurretPost")

	var walker := HeavyWalker.new()
	walker.position = Vector3(12.0, GROUND_Y + 0.2, 0.0)
	walker.patrol_span = 2.2
	geometry.add_child(walker)

	for i in 3:
		var v := SteamVent.new()
		v.position = Vector3(18.0 + i * 2.6, GROUND_Y + 0.05, 0.0)
		v.phase = float(i) * 0.8
		v.height = 4.0
		geometry.add_child(v)
