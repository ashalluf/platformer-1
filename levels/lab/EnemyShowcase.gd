extends Stage
## Every enemy and hazard in one frame, under neutral light.
##
## A level is the wrong place to sign off a machine: it is dark, it is hazy,
## and whatever you are looking at is thirty units away behind a pipe rack.
## This is flat ground, a grey card and a parked camera, so a silhouette can be
## judged as a silhouette.
##
## It is laid out as two bays, because half of what these units are is what
## they do when they have seen you:
##
##   REST  (x 3 .. 20)   far enough from the spawn that nothing has noticed
##                       the player. This is the silhouette and surface bay.
##   ALERT (x -16 .. -1) inside every sight range, so the units here are
##                       genuinely telegraphing — no state is forced from
##                       outside, because a forced state proves nothing about
##                       whether the state machine actually reaches it.
##
## One spare unit in the alert bay is destroyed on a timer, so the death beats
## can be signed off in a capture too, and the steam vents are phased so that
## one is idle, one is warning and one is blasting: all three states of the
## hazard in a single frame.
##
## Both of those are timed against SHOT_AT rather than against a wall clock.
## A capture of this scene costs real minutes on a loaded machine, so the
## interesting half-second is brought forward to the front of the run instead
## of the run being made long enough to reach it.

const GROUND_Y := 0.0

## The moment every staged state is tuned to land on, in seconds after load.
## warmup + shot frame, over 60.
const SHOT_AT := 0.57

## Seconds after load that the demonstration unit is destroyed: far enough
## before SHOT_AT that the capture lands on the blow-out and the debris rather
## than on the first white frame.
const DEATH_DEMO_AT := SHOT_AT - 0.15

var _demo_unit: Enemy


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

	LevelKit.box(geometry, Vector3(2.0, GROUND_Y - 1.0, 0.0),
		Vector3(96.0, 2.0, 6.0), floor_mat, "Floor")
	LevelKit.prop(geometry, Vector3(2.0, GROUND_Y + 7.0, -9.0),
		Vector3(96.0, 18.0, 0.6), card, "Card")

	# A metre grid on the card, so a silhouette can be measured and not just
	# admired.
	for i in 25:
		LevelKit.prop(geometry, Vector3(-22.0 + i * 3.0, GROUND_Y + 7.0, -8.66),
			Vector3(0.03, 18.0, 0.03), floor_mat, "GridV%d" % i)
	for i in 7:
		LevelKit.prop(geometry, Vector3(2.0, GROUND_Y + i * 2.0, -8.66),
			Vector3(96.0, 0.03, 0.03), floor_mat, "GridH%d" % i)

	_rest_bay()
	_alert_bay()


## Nothing here has seen the player. Framed by the standard sign-off capture:
## camera 9.5,1.9,11 looking at 10,1.6,0 at 36 degrees, which puts x 3 to 17
## across the frame.
func _rest_bay() -> void:
	var drone := SnitchDrone.new()
	drone.position = Vector3(4.2, GROUND_Y + 2.7, 0.0)
	drone.patrol_span = 1.2
	geometry.add_child(drone)
	_label("الواشي 07", 4.2, 5.6)

	var turret := WallTurret.new()
	turret.position = Vector3(8.6, GROUND_Y + 2.5, 0.0)
	geometry.add_child(turret)
	# A post for it to be bolted to, because a turret floating in air reads as
	# a bug rather than as a turret — and because the bracket, the dirt line
	# under it and the rust off its bolts only mean anything against a mount.
	var post_mat := MaterialLab.concrete(Color(0.225, 0.220, 0.215), 0.9)
	LevelKit.box(geometry, Vector3(9.14, GROUND_Y + 1.25, 0.0),
		Vector3(0.42, 2.5, 0.52), post_mat, "TurretPost")
	LevelKit.box(geometry, Vector3(9.14, GROUND_Y + 0.09, 0.0),
		Vector3(0.66, 0.18, 0.76), post_mat, "TurretFoot")
	_label("الحارس 12", 8.6, 5.6)

	var walker := HeavyWalker.new()
	walker.position = Vector3(12.8, GROUND_Y + 0.2, 0.0)
	walker.patrol_span = 2.2
	geometry.add_child(walker)
	_label("الهرّاس 03", 12.8, 5.6)

	# Phased so that the capture catches one of each state. `phase` is
	# subtracted from the cycle clock, so a negative phase starts a vent
	# part-way through its interval: idle, then warning, then blasting.
	var phases := [-0.3, -2.55, -3.3]
	for i in 3:
		var v := SteamVent.new()
		v.position = Vector3(15.6 + i * 1.7, GROUND_Y + 0.05, 0.0)
		v.phase = phases[i]
		v.height = 4.0
		geometry.add_child(v)
	_label("بخار", 17.3, 5.6)


## Everything in this bay is inside its own sight range of the spawn point, so
## it is telegraphing for real.
func _alert_bay() -> void:
	var turret := WallTurret.new()
	turret.position = Vector3(-4.0, GROUND_Y + 2.5, 0.0)
	geometry.add_child(turret)
	var post_mat := MaterialLab.concrete(Color(0.225, 0.220, 0.215), 0.9)
	LevelKit.box(geometry, Vector3(-3.46, GROUND_Y + 1.25, 0.0),
		Vector3(0.42, 2.5, 0.52), post_mat, "AlertPost")

	# To the far side of the player, so it charges back into frame instead of
	# out of it.
	var walker := HeavyWalker.new()
	walker.position = Vector3(-14.5, GROUND_Y + 0.2, 0.0)
	walker.patrol_span = 1.5
	geometry.add_child(walker)

	var drone := SnitchDrone.new()
	drone.position = Vector3(-12.0, GROUND_Y + 3.0, 0.0)
	drone.patrol_span = 1.0
	geometry.add_child(drone)

	# The demonstration unit. It is parked clear of the others so the debris,
	# the scorch and the smoke can be read on their own.
	_demo_unit = SnitchDrone.new()
	_demo_unit.position = Vector3(-1.6, GROUND_Y + 2.4, 0.0)
	_demo_unit.patrol_span = 0.3
	geometry.add_child(_demo_unit)
	var t := get_tree().create_timer(DEATH_DEMO_AT, true, false, true)
	t.timeout.connect(_kill_demo)


func _kill_demo() -> void:
	if is_instance_valid(_demo_unit) and not _demo_unit.is_dead():
		_demo_unit.die()


## Arabic plant designations on the card. Western digits, never Eastern Arabic
## numerals — that is how Libyan signage actually sets numbers, and it is the
## same convention as the stencil on the unit itself.
func _label(text: String, x: float, y: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.45, 0.43)
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.metallic_specular = 0.30
	PropKit.sign(geometry, text, Vector3(x, GROUND_Y + y, -8.55), 0.34, mat)
