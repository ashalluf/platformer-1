class_name SnitchDrone extends Enemy
## SNITCH — a hovering camera drone on a patrol beat.
##
## The first enemy the player meets, so its whole job is to teach the two
## contracts: enemies telegraph, and enemies come apart. It bobs along a fixed
## span, sweeps a light cone, and when it sees the player it stiffens,
## brightens and charges after a visible wind-up. Two rounds kill it.
##
## Form, per the family language in Enemy.gd: a hexagonal drum rather than a
## sphere, because a six-sided drum gives every panel, vent and hatch a flat to
## sit on and reads as machined from across the yard, where a sphere reads as a
## primitive. One shrouded lift fan on the deck, two stabiliser fans on
## outriggers running along Z — into and out of the screen, where they buy
## depth without widening a silhouette that has to stay inside a 0.42 m
## hitbox. The hazard band is the rotor guard: the ring at its waist is the
## part of it that arrives first.

@export var patrol_span := 5.0
@export var patrol_speed := 2.0
@export var sight_range := 9.0
@export var alert_time := 0.55
@export var charge_speed := 9.0
@export var hover_bob := 0.18

enum Mode { PATROL, ALERT, CHARGE, RECOVER }

const OPTIC_YAW := deg_to_rad(32.0)   ## cheat toward the camera, see _aim_optic

var _mode: Mode = Mode.PATROL
var _origin: Vector3
var _timer := 0.0
var _bob := 0.0
var _optic: Enemy.Optic
var _beacon: Enemy.Beacon
var _rotor: Node3D
var _stabs: Array[Node3D] = []
var _gimbal: Node3D
var _disc_mat: StandardMaterial3D
var _accent_mat: ShaderMaterial
var _player: Node3D
var _spin_rate := 0.0
var _gimbal_lag := 0.0


func _setup() -> void:
	max_health = 2.0
	health = max_health
	_origin = global_position
	_bob = fposmod(global_position.x, TAU)
	# It is in the air, so it falls out of it: a long tip and a long sink.
	death_tip = 2.4
	death_sink = 1.6
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.30, 0)
	add_child(cs)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	add_child(root)

	var shell := Enemy.shell_material(Enemy.SHELL)
	var deck := Enemy.shell_material(Enemy.SHELL_DARK)
	var iron := Enemy.iron_material()
	var accent := Enemy.accent_material()
	_accent_mat = accent

	var drum_r := 0.30
	var drum_y := 0.30
	# Apothem of a hexagon: where its flats actually are. Every panel below is
	# placed against this number and not against the radius, which is the
	# difference between a hatch lying on a face and one floating off a corner.
	var flat := drum_r * cos(PI / 6.0)

	Enemy._part(root, "Drum", Enemy._cyl(drum_r, 0.28, 6), shell,
		Vector3(0, drum_y, 0))
	# A chamfered skirt under the drum, so the belly is not a flat disc.
	Enemy._part(root, "Skirt", Enemy._cyl(drum_r * 0.86, 0.05, 6,
		drum_r * 0.98), shell, Vector3(0, drum_y - 0.165, 0))

	# --- Deck -----------------------------------------------------------
	var deck_y := drum_y + 0.155
	Enemy._part(root, "Deck", LevelKit.chamfer_mesh(
		Vector3(0.50, 0.034, 0.44), 0.010), deck, Vector3(0, deck_y, 0))
	Enemy.bolt_row(root, Vector3(-0.21, deck_y + 0.019, -0.185),
		Vector3(0.21, deck_y + 0.019, -0.185), 5, iron, 0.010, Vector3.UP)
	Enemy.bolt_row(root, Vector3(-0.21, deck_y + 0.019, 0.185),
		Vector3(0.21, deck_y + 0.019, 0.185), 5, iron, 0.010, Vector3.UP)

	# --- Lift fan -------------------------------------------------------
	var fan_y := deck_y + 0.085
	var duct := TorusMesh.new()
	duct.inner_radius = 0.150
	duct.outer_radius = 0.205
	duct.rings = 20
	duct.ring_segments = 8
	Enemy._part(root, "Duct", duct, iron, Vector3(0, fan_y, 0))
	# Three struts across the mouth. A bare ring reads as a hole; a ring with
	# structure across it reads as a fan you are looking into.
	for i in 3:
		var a := TAU * float(i) / 3.0
		Enemy._part(root, "Strut%d" % i, LevelKit.chamfer_mesh(
			Vector3(0.38, 0.014, 0.022), 0.004), iron,
			Vector3(0, fan_y + 0.026, 0), Vector3(0, a, 0))

	_rotor = Node3D.new()
	_rotor.name = "Rotor"
	_rotor.position = Vector3(0, fan_y, 0)
	root.add_child(_rotor)
	Enemy._part(_rotor, "Hub", Enemy._cyl(0.048, 0.055, 8, 0.030), iron)
	var blades: Array[Transform3D] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		blades.append(Transform3D(
			Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, deg_to_rad(16.0)),
			Vector3(cos(a) * 0.085, 0.0, sin(a) * 0.085)))
	Enemy._batch(_rotor, "Blades", LevelKit.chamfer_mesh(
		Vector3(0.026, 0.008, 0.155), 0.003), blades, deck)

	# The rotor disc: a faint additive plate that fades in with rotor speed.
	# Five blades turning four times a second strobe badly at a fixed capture
	# rate; a disc behind them reads as motion at any frame you happen to grab.
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_disc_mat.albedo_color = Color(0.62, 0.66, 0.72, 0.0)
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_disc_mat.disable_receive_shadows = true
	var disc := Enemy._part(root, "RotorDisc",
		Enemy._cyl(0.148, 0.004, 20), _disc_mat, Vector3(0, fan_y + 0.012, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# --- Stabiliser outriggers, along Z ---------------------------------
	for s in [-1.0, 1.0]:
		var boom := Node3D.new()
		boom.name = "Outrigger"
		boom.position = Vector3(0.0, drum_y + 0.045, s * 0.30)
		root.add_child(boom)
		Enemy._part(boom, "Arm", LevelKit.chamfer_mesh(
			Vector3(0.075, 0.042, 0.20), 0.008), deck,
			Vector3(0, 0, -s * 0.08))
		var sr := TorusMesh.new()
		sr.inner_radius = 0.072
		sr.outer_radius = 0.098
		sr.rings = 14
		sr.ring_segments = 6
		Enemy._part(boom, "Shroud", sr, iron)
		var st := Node3D.new()
		st.name = "Fan"
		boom.add_child(st)
		_stabs.append(st)
		Enemy._part(st, "Hub", Enemy._cyl(0.026, 0.034, 6), iron)
		var sb: Array[Transform3D] = []
		for i in 2:
			sb.append(Transform3D(Basis(Vector3.UP, TAU * float(i) / 2.0)
				* Basis(Vector3.RIGHT, deg_to_rad(18.0)), Vector3.ZERO))
		Enemy._batch(st, "Blades", LevelKit.chamfer_mesh(
			Vector3(0.018, 0.006, 0.150), 0.003), sb, deck)

	# --- The hazard band: the rotor guard at the waist -------------------
	# One band per unit, on the part that arrives first. This ring is the
	# widest thing on the drone and it is what hits you. It sits down at the
	# skirt line rather than at mid-height: the drum is only 280 mm tall and
	# the ring stands 60 mm proud of its flats, so anywhere higher and it
	# crosses in front of the hatch and the vents.
	Enemy.chevron_ring(root, Vector3(0, drum_y - 0.125, 0), 0.318, 0.080, 10,
		accent, iron)

	# --- Surface: hatch on the camera face, vents on the shoulders -------
	Enemy.hatch(root, Vector3(0.0, drum_y + 0.045, flat + 0.004),
		Vector2(0.19, 0.12), deck, iron, accent)
	Enemy.stencil(root, "أمن 07", Vector3(0.0, drum_y - 0.075, flat + 0.012),
		0.046)
	for a in [deg_to_rad(30.0), deg_to_rad(150.0)]:
		var face := Node3D.new()
		face.name = "Face"
		face.position = Vector3(cos(a) * flat, drum_y + 0.055, sin(a) * flat)
		# +Z of the child onto the face normal.
		face.rotation.y = PI * 0.5 - a
		root.add_child(face)
		Enemy.louvre(face, Vector3.ZERO, Vector2(0.150, 0.100), 4, iron, 0.036)

	# Gravity stains: one run off the hatch hinge, one off the deck bolts.
	# They are placed, not noisy — every streak on this thing starts at a
	# fastener and ends further down than feels right.
	Enemy.rust_streak(root, Vector3(-0.088, drum_y - 0.015, flat + 0.015),
		Vector2(0.080, 0.22), 0.50)
	Enemy.rust_streak(root, Vector3(0.112, drum_y + 0.010, flat + 0.015),
		Vector2(0.060, 0.18), 0.38)

	# --- Sensor gimbal under the nose ------------------------------------
	_gimbal = Node3D.new()
	_gimbal.name = "Gimbal"
	_gimbal.position = Vector3(-0.055, drum_y - 0.175, 0.055)
	root.add_child(_gimbal)
	Enemy._part(_gimbal, "Yoke", LevelKit.chamfer_mesh(
		Vector3(0.055, 0.085, 0.175), 0.008), iron, Vector3(0.02, 0.045, 0))
	for s in [-1.0, 1.0]:
		Enemy._part(_gimbal, "Cheek", LevelKit.chamfer_mesh(
			Vector3(0.115, 0.115, 0.018), 0.005), deck,
			Vector3(-0.02, 0.0, s * 0.082))
	_optic = Enemy.optic(_gimbal, Vector3(-0.03, 0.0, 0.0), 0.078)

	# Loom from the gimbal up into the belly. Nothing on a machine this old is
	# routed inside if it could be strapped to the outside.
	Enemy.loom(root, Vector3(-0.02, drum_y - 0.135, 0.115),
		Vector3(0.08, drum_y - 0.155, 0.055), 0.035, 0.016)

	# --- Antenna and beacon ----------------------------------------------
	Enemy._part(root, "Mast", Enemy._cyl(0.011, 0.26, 6), iron,
		Vector3(0.20, deck_y + 0.13, -0.11), Vector3(0, 0, deg_to_rad(-9.0)))
	Enemy._part(root, "Whip", Enemy._cyl(0.006, 0.12, 4), iron,
		Vector3(0.235, deck_y + 0.30, -0.11), Vector3(0, 0, deg_to_rad(-16.0)))
	_beacon = Enemy.beacon(root, Vector3(-0.19, deck_y + 0.045, 0.10), 0.038)
	return root


func _behaviour(delta: float) -> void:
	_bob += delta * 2.6
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	match _mode:
		Mode.PATROL:
			_patrol(delta)
		Mode.ALERT:
			_alert(delta)
		Mode.CHARGE:
			_charge(delta)
		Mode.RECOVER:
			_recover(delta)

	_visual.position.y = sin(_bob) * hover_bob
	_mechanics(delta)


## Everything that makes it read as a machine rather than a floating prop, in
## one place: rotor speed tracking demand, the gimbal lagging behind the
## airframe, and the bank into travel.
func _mechanics(delta: float) -> void:
	# Rotors spool toward what the airframe is asking of them rather than
	# spinning at a constant rate. The wind-up before a charge is audible in
	# the rotors before it is visible anywhere else.
	var demand := 22.0 + absf(velocity.x) * 1.6 + absf(velocity.y) * 3.0
	if _mode == Mode.ALERT:
		demand += 26.0
	_spin_rate = lerpf(_spin_rate, demand, 1.0 - exp(-4.0 * delta))
	_rotor.rotation.y += delta * _spin_rate
	for i in _stabs.size():
		# Counter-rotating, because a pair that turns the same way would spin
		# the airframe, and because opposed motion reads as deliberate.
		_stabs[i].rotation.y += delta * _spin_rate * (1.7 if i == 0 else -1.7)
	_disc_mat.albedo_color.a = clampf(_spin_rate / 60.0, 0.0, 1.0) * 0.26

	# The camera is hung on a gimbal, so it lags the airframe and settles a
	# beat late. This is the single cheapest piece of secondary motion on the
	# drone and it is the one that sells the whole thing.
	_gimbal_lag = lerpf(_gimbal_lag, clampf(-velocity.y * 0.09, -0.34, 0.34),
		1.0 - exp(-9.0 * delta))
	_gimbal.rotation.z = _gimbal_lag
	_aim_optic()

	# Bank into travel. A hovering machine that translates without rolling is
	# a sprite being moved; one that rolls is a machine using its rotors.
	_visual.rotation.z = lerpf(_visual.rotation.z,
		clampf(-velocity.x * 0.052, -0.30, 0.30), 1.0 - exp(-7.0 * delta))
	# A little hum in the airframe, keyed off rotor speed. Two millimetres.
	_visual.position.x = sin(_bob * 7.3) * 0.004 * clampf(_spin_rate / 40.0, 0.0, 1.5)


## The optic aims along the way it is facing, cheated 32 degrees toward the
## camera. Dead in profile the eye is a sliver and the state colour is lost;
## cheated round it is a disc the player can read, and in a side-on game
## nobody can tell the difference.
func _aim_optic() -> void:
	_optic.pivot.rotation.y = (PI + OPTIC_YAW) if facing < 0 else -OPTIC_YAW


func _patrol(delta: float) -> void:
	_timer += delta
	var target := _origin.x + sin(_timer * patrol_speed / maxf(patrol_span, 0.1)) * patrol_span
	velocity.x = (target - global_position.x) * 2.2
	velocity.y = (_origin.y - global_position.y) * 2.0
	facing = -1 if velocity.x < 0.0 else 1
	# Idle breath on the eye. Slow, shallow, and it never stops — a machine
	# with a perfectly constant lamp is a machine that is switched off.
	var breath := 0.5 + 0.5 * sin(_bob * 1.35)
	_optic.set_state(Enemy.OPTIC_IDLE, lerpf(1.5, 2.1, breath))
	_optic.set_beam(2.6, 0.045 + 0.02 * breath, Enemy.OPTIC_IDLE)
	_beacon.set_state(Enemy.OPTIC_IDLE, 0.0)
	_set_hazard(0.0)
	if _sees_player():
		_mode = Mode.ALERT
		_timer = 0.0


## Wind-up: it stops, rises, the eye ramps to white and the beacon starts
## strobing. Four cues on four different parts of the machine, three of them
## visible from behind it, because a telegraph the player misses is a cheap
## hit. The 0.55 s is untouched — only the volume went up.
func _alert(delta: float) -> void:
	_timer += delta
	velocity = velocity.lerp(Vector3(0, 1.1, 0), 1.0 - exp(-8.0 * delta))
	var t := clampf(_timer / alert_time, 0.0, 1.0)
	var tint := Enemy.OPTIC_IDLE.lerp(Enemy.OPTIC_HOT, t)
	# The pulse tightens as it fills: the classic tell, and it still works.
	var pulse := 0.5 + 0.5 * sin(_timer * lerpf(9.0, 40.0, t))
	_optic.set_state(tint, lerpf(2.1, 7.5, t) * (0.55 + 0.45 * pulse))
	_optic.set_beam(lerpf(3.0, 7.0, t), lerpf(0.06, 0.30, t), tint)
	# A hard on/off strobe, not a fade: a beacon that ramps reads as a glow.
	_beacon.set_state(Color(1.0, 0.78, 0.30), 6.5 if pulse > 0.5 else 0.0)
	# The guard ring lights with it. Amber geometry going emissive is the
	# loudest thing this unit can do and it costs one uniform.
	_set_hazard(t * 0.85)
	_visual.scale = Vector3.ONE * (1.0 + 0.10 * sin(_timer * 46.0) * t)
	if _timer >= alert_time:
		_mode = Mode.CHARGE
		_timer = 0.0
		# It throws itself forward, and the airframe rocks back doing it.
		nudge(Vector3(signf(float(facing)) * -2.4, 0.8, 0.0), 0.0)
		if _player:
			facing = -1 if _player.global_position.x < global_position.x else 1


func _charge(delta: float) -> void:
	_timer += delta
	_visual.scale = Vector3.ONE
	if _player:
		var to := (_player.global_position + Vector3(0, 0.9, 0)) - global_position
		to.z = 0.0
		velocity = to.normalized() * charge_speed
	_optic.set_state(Enemy.OPTIC_HOT, 7.0)
	_optic.set_beam(5.0, 0.22, Enemy.OPTIC_HOT)
	_beacon.set_state(Color(1.0, 0.86, 0.50), 7.0)
	_set_hazard(0.9)
	if _timer > 0.9:
		_mode = Mode.RECOVER
		_timer = 0.0
		nudge(Vector3(signf(float(facing)) * 3.0, -1.0, 0.0), 0.0)


## Overshoot and drift: the recovery window is the player's turn, and the eye
## says so by cooling rather than by changing to some new colour it has not
## used before.
func _recover(delta: float) -> void:
	_timer += delta
	velocity = velocity.lerp(Vector3(0, 0.4, 0), 1.0 - exp(-3.0 * delta))
	var k := clampf(_timer / 0.8, 0.0, 1.0)
	_optic.set_state(Enemy.OPTIC_EMBER.lerp(Enemy.OPTIC_IDLE, k),
		lerpf(3.4, 1.5, k))
	_optic.set_beam(2.6, lerpf(0.10, 0.05, k), Enemy.OPTIC_EMBER)
	_beacon.set_state(Enemy.OPTIC_EMBER, lerpf(2.2, 0.0, k))
	_set_hazard((1.0 - k) * 0.35)
	if _timer > 0.8:
		_mode = Mode.PATROL
		_timer = 0.0
		_origin.x = global_position.x


## Drive the amber on the guard ring. Emission on a painted surface rather
## than a separate glowing part, so the stripe still reads as paint.
func _set_hazard(amount: float) -> void:
	if _accent_mat == null:
		return
	_accent_mat.set_shader_parameter("emission_color",
		Color(1.0, 0.62, 0.18))
	_accent_mat.set_shader_parameter("emission_strength", amount * 2.6)


func _sees_player() -> bool:
	if _player == null:
		return false
	var to: Vector3 = _player.global_position - global_position
	if absf(to.x) > sight_range or absf(to.y) > 4.5:
		return false
	return signf(to.x) == float(facing) or absf(to.x) < 2.0
