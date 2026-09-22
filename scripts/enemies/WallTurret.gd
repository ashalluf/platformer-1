class_name WallTurret extends Enemy
## SENTRY — a wall-mounted automated turret.
##
## The drone teaches that enemies telegraph. The turret teaches that the
## telegraph is the whole fight: it sweeps a lazy arc, locks on with a light
## you can see from across the yard, holds for long enough to get behind
## something, then fires three slow bolts you can walk between.
##
## It cannot move and it cannot follow you past its arc, so the answer is
## always position, never damage racing.
##
## Form, per the family language in Enemy.gd: a bolted wall bracket, a trunnion
## arm, and a rectangular breech box slung in a two-cheek yoke — not a sphere.
## A sphere has no face to bolt a panel to and no top to stand a fin stack on,
## and it was the single thing keeping this unit reading as a lump with tubes
## in it. Twin barrels in a slotted shroud, an ammunition can slung underneath
## with a flexible link chute into the breech, and the hazard band on the yoke
## cheek — the part that swings toward you.

@export var sight_range := 16.0
@export var lock_time := 0.85
@export var burst := 3
@export var burst_gap := 0.16
@export var cooldown := 1.9
@export var sweep_speed := 0.55
@export var sweep_arc := 0.55        ## radians either side of rest
@export var muzzle_speed := 12.0

enum Mode { SWEEP, LOCK, FIRE, COOL }

var _mode: Mode = Mode.SWEEP
var _timer := 0.0
var _shots := 0
var _yoke: Node3D
var _optic: Enemy.Optic
var _beacon: Enemy.Beacon
var _accent_mat: ShaderMaterial
var _barrels: Node3D
var _muzzle: Marker3D
var _player: Node3D
var _aim := 0.0
var _barrel_back := 0.0
var _heat := 0.0
var _barrel_mat: ShaderMaterial


func _setup() -> void:
	max_health = 4.0
	health = max_health
	contact_damage = 0.0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Bolted to a wall: it sags on its bracket rather than falling over.
	death_tip = 0.75
	death_sink = 0.22
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.7, 0.7)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.1, 0)
	add_child(cs)


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	add_child(root)

	var shell := Enemy.shell_material(Enemy.SHELL)
	var plate := Enemy.shell_material(Enemy.SHELL_DARK)
	var iron := Enemy.iron_material()
	var accent := Enemy.accent_material()
	_accent_mat = accent

	# --- Wall bracket ----------------------------------------------------
	# It has to look bolted to something, and the bolts have to be the first
	# thing you see: this is the only part of the unit that is not going to
	# move, so it is where all the weight lives.
	var bracket := Node3D.new()
	bracket.name = "Bracket"
	bracket.position = Vector3(0.315, 0.0, 0.0)
	root.add_child(bracket)
	Enemy._part(bracket, "BasePlate", LevelKit.chamfer_mesh(
		Vector3(0.10, 0.80, 0.72), 0.016), plate)
	# Heads on the gun side of the plate: that is the side the player sees, and
	# a fastener you cannot see is a fastener that did not need modelling.
	Enemy.bolt_ring(bracket, Vector3(-0.052, 0.0, 0.0), 0.29, 6, iron, 0.022,
		Vector3.LEFT)
	# A gusset either side, so the arm is braced rather than cantilevered off
	# a flat plate.
	for s in [-1.0, 1.0]:
		Enemy._part(bracket, "Gusset", LevelKit.chamfer_mesh(
			Vector3(0.22, 0.30, 0.026), 0.006), iron,
			Vector3(-0.11, -0.12, s * 0.115), Vector3(0, 0, deg_to_rad(-26.0)))
	Enemy._part(bracket, "Arm", LevelKit.chamfer_mesh(
		Vector3(0.20, 0.20, 0.22), 0.012), iron, Vector3(-0.12, 0.0, 0.0))
	# Cable gland and loom dropping out of the bracket, terminated in a box.
	DetailKit.junction_box(bracket, Vector3(0.02, -0.34, 0.16),
		Vector3(0.17, 0.20, 0.10), plate,
		{"conduits": [Vector3.UP], "stub_len": 0.16, "glands": 1,
		"gland_mat": iron, "lid_mat": shell, "label": false,
		"name": "Terminal"})
	Enemy.loom(bracket, Vector3(-0.02, -0.20, 0.16),
		Vector3(-0.16, -0.04, 0.10), 0.06, 0.020)
	# The dirt line where the bracket meets the wall, and the rust running off
	# its bolts. This pair is most of what makes it read as bolted down.
	Enemy.dirt_band(bracket, Vector3(-0.02, -0.30, 0.365), Vector2(0.62, 0.46),
		0.60)
	Enemy.rust_streak(bracket, Vector3(-0.19, -0.10, 0.366),
		Vector2(0.10, 0.44), 0.55)
	Enemy.rust_streak(bracket, Vector3(0.14, -0.14, 0.366),
		Vector2(0.075, 0.34), 0.40)

	# --- Yoke ------------------------------------------------------------
	_yoke = Node3D.new()
	_yoke.name = "Yoke"
	root.add_child(_yoke)

	for s in [-1.0, 1.0]:
		var cheek := Node3D.new()
		cheek.name = "Cheek"
		cheek.position = Vector3(0.0, 0.0, s * 0.215)
		_yoke.add_child(cheek)
		Enemy._part(cheek, "Plate", LevelKit.chamfer_mesh(
			Vector3(0.46, 0.34, 0.030), 0.008), plate)
		Enemy._part(cheek, "Boss", Enemy._cyl(0.070, 0.055, 10), iron,
			Vector3(0.16, 0.0, s * 0.028), Vector3(PI * 0.5, 0, 0))
		Enemy.bolt_ring(cheek, Vector3(0.16, 0.0, s * 0.050), 0.045, 5, iron,
			0.010, Vector3(0.0, 0.0, s))

	# THE hazard band, on the cheek that swings toward the player. One per
	# unit; wherever the chevrons are is the end that will hurt you.
	Enemy.chevron_band(_yoke, Vector3(-0.09, -0.135, 0.233), 0.26, 0.105, 4,
		accent, iron)

	# --- Breech ----------------------------------------------------------
	var breech := Node3D.new()
	breech.name = "Breech"
	_yoke.add_child(breech)
	Enemy._part(breech, "Housing", LevelKit.chamfer_mesh(
		Vector3(0.44, 0.30, 0.38), 0.018), shell)
	# A proud panel with a bolt row on the camera face: the shadow line under
	# it is the only surface detail that survives at gameplay distance.
	Enemy.panel(breech, Vector3(-0.02, 0.028, 0.196), Vector2(0.30, 0.13),
		plate, 5, iron)
	Enemy.louvre(breech, Vector3(-0.02, -0.095, 0.196), Vector2(0.26, 0.085),
		4, iron, 0.036)
	Enemy.stencil(breech, "أمن 12", Vector3(0.14, 0.028, 0.212), 0.050)
	# Cooling fins across the top. It fires three rounds and then stands there
	# cooling for two seconds, so it had better look like it has somewhere to
	# put the heat.
	Enemy.fin_stack(breech, Vector3(-0.03, 0.175, 0.0), 5,
		Vector3(0.34, 0.012, 0.34), 0.026, iron)
	Enemy.rust_streak(breech, Vector3(0.12, -0.20, 0.200),
		Vector2(0.07, 0.26), 0.45)

	# --- Barrels ---------------------------------------------------------
	# They sit on their own node so the recoil stroke is the barrels moving in
	# the housing, not the whole gun jumping.
	_barrels = Node3D.new()
	_barrels.name = "Barrels"
	_barrels.position = Vector3(-0.20, 0.0, 0.0)
	breech.add_child(_barrels)
	# A slotted shroud around them, which is what turns two tubes into a gun.
	Enemy._part(_barrels, "Shroud", LevelKit.chamfer_mesh(
		Vector3(0.30, 0.16, 0.19), 0.012), iron, Vector3(-0.12, 0.0, 0.0))
	var slots: Array[Transform3D] = []
	for i in 4:
		slots.append(Transform3D(Basis.IDENTITY,
			Vector3(-0.21 + i * 0.058, 0.0, 0.098)))
	Enemy._batch(_barrels, "Slots", LevelKit.chamfer_mesh(
		Vector3(0.020, 0.105, 0.014), 0.003), slots, Enemy.recess_material())
	# The barrels get their own material so they can glow after a burst
	# without taking the rest of the iron on the unit with them.
	_barrel_mat = Enemy.iron_material()
	for i in 2:
		var y := -0.048 + i * 0.096
		Enemy._part(_barrels, "Barrel%d" % i, Enemy._cyl(0.030, 0.52, 10,
			0.025), _barrel_mat, Vector3(-0.30, y, 0.0), Vector3(0, 0, PI * 0.5))
		# A muzzle brake on the end. Nothing in this game is allowed to stop
		# in mid-air, least of all a barrel.
		Enemy._part(_barrels, "Brake%d" % i, Enemy._cyl(0.046, 0.075, 8),
			iron, Vector3(-0.545, y, 0.0), Vector3(0, 0, PI * 0.5))
		Enemy.bolt_ring(_barrels, Vector3(-0.115, y, 0.0), 0.040, 4, iron,
			0.009, Vector3.LEFT)

	# --- Ammunition can and link chute -----------------------------------
	# The chute is the cable run the brief asked for and it earns its place
	# twice: it ties two assemblies together and it tells the player where the
	# three rounds come from.
	var can := Node3D.new()
	can.name = "AmmoCan"
	can.position = Vector3(0.10, -0.26, -0.02)
	_yoke.add_child(can)
	Enemy._part(can, "Body", LevelKit.chamfer_mesh(
		Vector3(0.26, 0.20, 0.28), 0.014), plate)
	Enemy._part(can, "Lid", LevelKit.chamfer_mesh(
		Vector3(0.24, 0.030, 0.26), 0.006), shell, Vector3(0.0, 0.112, 0.0))
	Enemy.bolt_row(can, Vector3(-0.09, 0.128, 0.0), Vector3(0.09, 0.128, 0.0),
		3, iron, 0.010, Vector3.UP)
	Enemy._part(can, "Handle", LevelKit.chamfer_mesh(
		Vector3(0.10, 0.018, 0.018), 0.004), iron, Vector3(0.0, 0.150, 0.0))
	Enemy.loom(_yoke, Vector3(0.06, -0.15, 0.10), Vector3(-0.04, -0.08, 0.10),
		0.045, 0.026)

	_optic = Enemy.optic(breech, Vector3(-0.19, 0.145, 0.10), 0.085)
	# Aimed down the barrels, cheated toward the camera so the state colour
	# reads as a disc instead of as a sliver. Same cheat as the drone.
	_optic.pivot.rotation.y = PI + deg_to_rad(28.0)
	_beacon = Enemy.beacon(breech, Vector3(0.155, 0.235, -0.09), 0.044)

	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(-0.70, 0.0, 0.0)
	_yoke.add_child(_muzzle)
	return root


func _behaviour(delta: float) -> void:
	velocity = Vector3.ZERO
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_timer += delta

	var to_player := Vector3.ZERO
	var in_range := false
	if _player != null and is_instance_valid(_player):
		to_player = (_player as Node3D).global_position + Vector3(0, 0.9, 0) \
			- _muzzle.global_position
		in_range = to_player.length() < sight_range and to_player.x < 0.6

	match _mode:
		Mode.SWEEP:
			_aim = sin(_timer * sweep_speed) * sweep_arc
			_optic.set_state(Enemy.OPTIC_IDLE,
				1.5 + 0.35 * sin(_timer * 1.7))
			_optic.set_beam(3.0, 0.04, Enemy.OPTIC_IDLE)
			_beacon.set_state(Enemy.OPTIC_IDLE, 0.0)
			_set_hazard(0.0)
			if in_range:
				_mode = Mode.LOCK
				_timer = 0.0
		Mode.LOCK:
			# Track while charging, so the lock reads as a decision being made.
			if in_range:
				_aim = lerpf(_aim, atan2(to_player.y, -to_player.x),
					1.0 - exp(-9.0 * delta))
			var t := clampf(_timer / lock_time, 0.0, 1.0)
			# Pulsing faster as it fills: the classic tell, and it works.
			var pulse := 0.5 + 0.5 * sin(_timer * lerpf(8.0, 34.0, t))
			var tint := Enemy.OPTIC_IDLE.lerp(Enemy.OPTIC_HOT, t)
			_optic.set_state(tint, lerpf(1.8, 7.0, t) * (0.6 + 0.4 * pulse))
			# THE change to this unit. The lock now draws a sight line the
			# whole length of the shot, growing to reach the player as the
			# timer fills. You can see which way it is pointing from the far
			# side of the yard, and you have the full 0.85 s to be somewhere
			# else — which was always the design, and was previously conveyed
			# by a lamp four pixels across.
			_optic.set_beam(lerpf(3.0, minf(to_player.length(), sight_range), t),
				lerpf(0.10, 0.42, t) * (0.65 + 0.35 * pulse), tint)
			_beacon.set_state(Color(1.0, 0.80, 0.34),
				7.0 if pulse > 0.55 else 0.0)
			_set_hazard(t * 0.9)
			if not in_range:
				_mode = Mode.SWEEP
				_timer = 0.0
			elif _timer >= lock_time:
				_mode = Mode.FIRE
				_timer = 0.0
				_shots = 0
		Mode.FIRE:
			_optic.set_state(Enemy.OPTIC_HOT, 7.5)
			_optic.set_beam(minf(to_player.length(), sight_range), 0.30,
				Enemy.OPTIC_HOT)
			_beacon.set_state(Color(1.0, 0.88, 0.60), 7.5)
			_set_hazard(1.0)
			if _timer >= burst_gap:
				_timer = 0.0
				_fire()
				_shots += 1
				if _shots >= burst:
					_mode = Mode.COOL
		Mode.COOL:
			var k := clampf(_timer / cooldown, 0.0, 1.0)
			_optic.set_state(Enemy.OPTIC_EMBER.lerp(Enemy.OPTIC_IDLE, k),
				lerpf(4.0, 1.4, k))
			_optic.set_beam(2.4, lerpf(0.10, 0.04, k), Enemy.OPTIC_EMBER)
			_beacon.set_state(Enemy.OPTIC_EMBER, lerpf(2.0, 0.0, k))
			_set_hazard((1.0 - k) * 0.4)
			if _timer >= cooldown:
				_mode = Mode.SWEEP
				_timer = 0.0

	_mechanics(delta)


## The yoke does not snap to its aim and the barrels do not snap back into the
## breech. Both run through a first-order lag with a deliberate overshoot, and
## the heat glow bleeds off on its own clock.
func _mechanics(delta: float) -> void:
	# Servo lag on the yoke: it arrives late and overshoots by a few degrees.
	# The aim value itself is untouched — the gun still points where the code
	# says it points on the frame it fires.
	var target := _aim
	var err := target - _yoke.rotation.z
	_yoke.rotation.z += err * (1.0 - exp(-14.0 * delta)) \
		+ sin(_timer * 26.0) * 0.0016
	# Barrel recoil stroke, spring-returned.
	_barrel_back = lerpf(_barrel_back, 0.0, 1.0 - exp(-11.0 * delta))
	_barrels.position.x = -0.20 + _barrel_back
	# Barrels glow after a burst. Heat is the one thing a machine can show
	# that says "that cost me something", and it decays on its own timer —
	# which means the player can look at a turret and know whether it has just
	# fired without having watched it fire.
	_heat = maxf(_heat - delta * 0.55, 0.0)
	if _barrel_mat != null:
		_barrel_mat.set_shader_parameter("emission_color",
			Color(1.0, 0.34, 0.10))
		_barrel_mat.set_shader_parameter("emission_strength",
			_heat * _heat * 1.6)


func _set_hazard(amount: float) -> void:
	if _accent_mat == null:
		return
	_accent_mat.set_shader_parameter("emission_color", Color(1.0, 0.62, 0.18))
	_accent_mat.set_shader_parameter("emission_strength", amount * 2.8)


func _fire() -> void:
	var dir := Vector3(-cos(_aim), sin(_aim), 0.0)
	var root := get_tree().current_scene
	if root == null:
		return
	Bolt.spawn(root, _muzzle.global_position + dir * 0.2, dir, muzzle_speed,
		Color(1.0, 0.50, 0.22))
	Audio.play("shot_%d" % (randi() % 4), global_position, -12.0,
		randf_range(0.66, 0.76))
	_heat = minf(_heat + 0.45, 1.0)
	# Three things move on every round: the barrels stroke back in the
	# housing, the whole gun kicks on its bracket, and the mount rings. The
	# old version moved one, and a gun that fires without costing itself
	# anything reads as a spawner.
	_barrel_back = 0.075
	nudge(-dir * 2.6, signf(dir.x) * 2.2)
	FX.shake(0.05)
	_muzzle_flash(dir)


## A two-frame flash at the brake, plus a cloud of unburnt propellant that
## hangs for a moment. Cheap, and it is the difference between a bolt
## appearing and a gun firing.
func _muzzle_flash(dir: Vector3) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var at := _muzzle.global_position + dir * 0.05
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.80, 0.48)
	l.light_energy = 7.5
	l.omni_range = 4.2
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 5.0
	root.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.07)
	tw.tween_callback(l.queue_free)

	var p := GPUParticles3D.new()
	p.amount = 9
	p.lifetime = 0.30
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = dir
	pm.spread = 22.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, 1.2, 0)
	pm.damping_min = 7.0
	pm.damping_max = 13.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.58, 0.55))
	g.set_color(1, Color(0.42, 0.38, 0.34, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.albedo_texture = PropKit._decal_texture("radial")
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
