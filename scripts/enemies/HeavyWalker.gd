class_name HeavyWalker extends Enemy
## HARRAS — the heavy. A two-legged armoured patrol unit.
##
## The drone teaches that enemies telegraph. The turret teaches that the
## telegraph is the fight. This one teaches that where you stand decides what
## your bullets are worth: it carries a shield plate on the face it walks
## toward, and shots into that plate do a quarter damage and ring off it. The
## answer is to get behind it, and the whole design exists to make the player
## want to dash through a thing rather than back away from it.
##
## It is slow on purpose. Nothing about it is a reaction test.
##
## Form, per the family language in Enemy.gd. The shape has one job the other
## two do not: the player has to be able to tell, in one glance and from any
## distance, which end is the shield. So the two halves are built as opposites.
## The FRONT is closed — a raked plate, ribs, the hazard chevrons, no openings
## at all. The BACK is open and busy — the exhaust stack, the junction box, the
## loom, the sensor mast, the hatch. Armour looks like armour because it is the
## only part of the machine with nothing hanging off it, and that difference
## reads at a hundred pixels where a colour difference would not.

@export var patrol_span := 7.0
@export var walk_speed := 2.1
@export var sight_range := 11.0
@export var wind_up := 0.7
@export var charge_speed := 9.5
@export var charge_time := 0.85
@export var recover_time := 1.1
@export var shield_soak := 0.25       ## damage multiplier through the plate

enum Mode { PATROL, ALERT, CHARGE, RECOVER }

var _mode: Mode = Mode.PATROL
var _origin: Vector3
var _timer := 0.0
var _cycle := 0.0
var _player: Node3D
var _chassis: Node3D
var _legs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _rams: Array[Node3D] = []
var _optic: Enemy.Optic
var _beacon: Enemy.Beacon
var _accent_mat: ShaderMaterial
var _shield: Node3D
var _mast: Node3D
var _exhaust: GPUParticles3D
var _mast_lag := 0.0
var _last_grounded := true


func _setup() -> void:
	max_health = 9.0
	health = max_health
	contact_damage = 1.0
	knockback = 1.1
	hitstop = 0.05
	_origin = global_position
	# Two tonnes of it: it goes down hard and it does not roll far.
	death_tip = 0.95
	death_sink = 1.15
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.20, 2.10, 1.00)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 1.05, 0)
	add_child(cs)


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	add_child(root)

	var shell := Enemy.shell_material(Enemy.SHELL)
	var plate := Enemy.shell_material(Enemy.SHELL_DARK)
	var iron := Enemy.iron_material()
	var accent := Enemy.accent_material()
	var rubber := Enemy.rubber_material()
	_accent_mat = accent

	# --- Legs ------------------------------------------------------------
	# Built first so the chassis draws over the hips. Each leg is a thigh
	# plate, a hydraulic ram alongside it, a shin with a fin stack on the
	# outside and a foot with a rubber pad — the ram is what makes it a
	# machine walking rather than two boxes hinging.
	for side in 2:
		var s := -1.0 if side == 0 else 1.0
		var leg := Node3D.new()
		leg.name = "Leg%d" % side
		leg.position = Vector3(0.0, 1.32, -0.26 + side * 0.52)
		root.add_child(leg)
		_legs.append(leg)

		Enemy._part(leg, "HipBoss", Enemy._cyl(0.115, 0.13, 10), iron,
			Vector3(0, 0, 0), Vector3(PI * 0.5, 0, 0))
		Enemy.bolt_ring(leg, Vector3(0, 0, s * 0.07), 0.075, 6, iron, 0.011,
			Vector3(0, 0, s))
		Enemy._part(leg, "Thigh", LevelKit.chamfer_mesh(
			Vector3(0.30, 0.62, 0.30), 0.024), plate, Vector3(0, -0.33, 0))
		Enemy._part(leg, "ThighRib", LevelKit.chamfer_mesh(
			Vector3(0.075, 0.52, 0.34), 0.010), iron, Vector3(-0.13, -0.33, 0))

		# Hydraulic ram: a cylinder body on the thigh with a bright rod
		# telescoping out of it into the shin. The rod is the one polished
		# thing on the unit and it is the part the eye follows when it walks.
		var ram := Node3D.new()
		ram.name = "Ram"
		ram.position = Vector3(0.15, -0.18, s * 0.17)
		leg.add_child(ram)
		_rams.append(ram)
		Enemy._part(ram, "Body", Enemy._cyl(0.040, 0.26, 8), iron)
		Enemy._part(ram, "Rod", Enemy._cyl(0.020, 0.30, 8),
			MaterialLab.brushed_aluminium(Color(0.66, 0.665, 0.67), 0.24),
			Vector3(0, -0.24, 0))

		var shin := Node3D.new()
		shin.name = "Shin"
		shin.position = Vector3(0, -0.66, 0)
		leg.add_child(shin)
		_shins.append(shin)

		Enemy._part(shin, "Knee", Enemy._cyl(0.095, 0.30, 8), iron,
			Vector3(0, 0, 0), Vector3(PI * 0.5, 0, 0))
		Enemy._part(shin, "Shin", LevelKit.chamfer_mesh(
			Vector3(0.25, 0.56, 0.24), 0.020), plate, Vector3(0, -0.29, 0))
		Enemy.fin_stack(shin, Vector3(0.0, -0.30, s * 0.135), 4,
			Vector3(0.20, 0.012, 0.055), 0.048, iron)
		Enemy._part(shin, "Ankle", Enemy._cyl(0.062, 0.22, 8), iron,
			Vector3(0.0, -0.56, 0.0), Vector3(PI * 0.5, 0, 0))
		Enemy._part(shin, "Foot", LevelKit.chamfer_mesh(
			Vector3(0.62, 0.15, 0.36), 0.022), plate, Vector3(0.07, -0.63, 0))
		# Rubber pad under the foot. It is 40 mm of geometry and it is the
		# reason the feet stop looking like they are made of the same stuff as
		# the armour.
		Enemy._part(shin, "Pad", LevelKit.chamfer_mesh(
			Vector3(0.58, 0.045, 0.32), 0.010), rubber,
			Vector3(0.07, -0.716, 0))
		Enemy._part(shin, "Toe", LevelKit.chamfer_mesh(
			Vector3(0.14, 0.11, 0.34), 0.016), iron, Vector3(-0.26, -0.62, 0))

	# --- Chassis ---------------------------------------------------------
	_chassis = Node3D.new()
	_chassis.name = "Chassis"
	_chassis.position = Vector3(0, 1.62, 0)
	root.add_child(_chassis)

	# A hip block, so the legs hang off something instead of out of a box.
	Enemy._part(_chassis, "Hips", LevelKit.chamfer_mesh(
		Vector3(0.70, 0.34, 1.16), 0.028), iron, Vector3(0.0, -0.46, 0.0))
	Enemy._part(_chassis, "Hull", LevelKit.chamfer_mesh(
		Vector3(1.22, 0.78, 1.00), 0.038), shell)
	# Sponsons along the flanks: the step that stops the hull being one box.
	for s in [-1.0, 1.0]:
		Enemy._part(_chassis, "Sponson", LevelKit.chamfer_mesh(
			Vector3(1.02, 0.20, 0.10), 0.018), plate,
			Vector3(0.02, -0.20, s * 0.50))
	# Deck plate, proud, with a bolt row down each side.
	Enemy._part(_chassis, "Deck", LevelKit.chamfer_mesh(
		Vector3(1.04, 0.045, 0.84), 0.012), plate, Vector3(0.0, 0.405, 0.0))
	for s in [-1.0, 1.0]:
		Enemy.bolt_row(_chassis, Vector3(-0.44, 0.432, s * 0.36),
			Vector3(0.44, 0.432, s * 0.36), 6, iron, 0.013, Vector3.UP)

	# The camera-side flank: a proud panel, a louvred vent, the access hatch
	# and the unit number. Everything the player can actually see lives here,
	# because in a side-on game the +Z face is the only face there is.
	Enemy.panel(_chassis, Vector3(0.18, 0.20, 0.505), Vector2(0.54, 0.22),
		plate, 6, iron)
	Enemy.louvre(_chassis, Vector3(0.20, -0.06, 0.505), Vector2(0.46, 0.17),
		5, iron, 0.055)
	Enemy.hatch(_chassis, Vector3(-0.30, 0.03, 0.505), Vector2(0.36, 0.40),
		plate, iron, accent)
	Enemy.stencil(_chassis, "أمن 03", Vector3(0.30, -0.28, 0.525), 0.085)
	# Stains sit at z 0.565, not on the hull face at 0.50: the sponsons stand
	# out to 0.55 and a decal quad behind them intersects them instead of
	# running over them.
	Enemy.rust_streak(_chassis, Vector3(-0.30, -0.24, 0.565),
		Vector2(0.30, 0.52), 0.52)
	Enemy.rust_streak(_chassis, Vector3(0.44, -0.22, 0.565),
		Vector2(0.12, 0.40), 0.40)
	# The dirt line where the hull sits on the hips.
	Enemy.dirt_band(_chassis, Vector3(0.0, -0.36, 0.565), Vector2(1.06, 0.28),
		0.58)

	# --- The shield: the closed face -------------------------------------
	# Deliberately the biggest, flattest, most obvious thing on the model, and
	# the only part with nothing bolted to it.
	_shield = Node3D.new()
	_shield.name = "Shield"
	_shield.position = Vector3(-0.66, -0.06, 0)
	_chassis.add_child(_shield)
	# The rake lives on one node that everything else hangs off, rather than on
	# each mesh. Rotating the parts individually means every child position has
	# to be worked out in the rotated frame by hand, and the first version of
	# this had the hazard band buried inside the ribs because of exactly that.
	var face := Node3D.new()
	face.name = "Rake"
	face.rotation.z = deg_to_rad(-15.0)
	_shield.add_child(face)

	Enemy._part(face, "Plate", LevelKit.chamfer_mesh(
		Vector3(0.18, 1.26, 1.10), 0.034), plate)
	for i in 3:
		Enemy._part(face, "Rib%d" % i, LevelKit.chamfer_mesh(
			Vector3(0.085, 1.16, 0.10), 0.014), iron,
			Vector3(-0.115, 0.0, -0.36 + i * 0.36))
	# Bolt rows down the outer ribs: the shield is a bolted-on plate, not part
	# of the hull, and the bolts are what say so.
	for i in [0, 2]:
		Enemy.bolt_row(face, Vector3(-0.165, -0.48, -0.36 + i * 0.36),
			Vector3(-0.165, 0.50, -0.36 + i * 0.36), 6, iron, 0.014,
			Vector3.LEFT)
	# THE hazard band, along the shield's leading edge — the part of the
	# machine that arrives first. One band per unit. It is built in the band's
	# own frame (runs along X, faces +Z) and yawed a quarter turn so it runs
	# across the shield and faces the way the unit walks.
	var band := Enemy.chevron_band(face, Vector3(-0.185, -0.50, 0.0), 1.16,
		0.15, 6, accent, iron)
	band.rotation = Vector3(0, -PI * 0.5, 0)
	# Battle scars: this is the face that has been shot at for twenty years.
	Enemy.rust_streak(face, Vector3(-0.16, 0.28, 0.58), Vector2(0.22, 0.46),
		0.42)

	# --- The open face: everything hangs off the back --------------------
	var stack := Node3D.new()
	stack.name = "Exhaust"
	stack.position = Vector3(0.50, 0.30, -0.24)
	_chassis.add_child(stack)
	Enemy._part(stack, "Riser", Enemy._cyl(0.075, 0.46, 10), iron,
		Vector3(0, 0.12, 0))
	Enemy.fin_stack(stack, Vector3(0, 0.10, 0), 5,
		Vector3(0.24, 0.014, 0.24), 0.052, iron)
	Enemy._part(stack, "Cowl", Enemy._cyl(0.095, 0.10, 10, 0.115), iron,
		Vector3(0, 0.38, 0))
	Enemy._part(stack, "Soot", Enemy._cyl(0.088, 0.03, 10),
		Enemy.recess_material(), Vector3(0, 0.425, 0))

	DetailKit.junction_box(_chassis, Vector3(0.46, -0.05, -0.36),
		Vector3(0.26, 0.32, 0.14), plate,
		{"conduits": [Vector3.DOWN], "stub_len": 0.22, "glands": 2,
		"gland_mat": iron, "lid_mat": shell, "label": false, "name": "Loom"})

	# --- Sensor mast -----------------------------------------------------
	# On the back of the hull: the unarmoured part, and the part that tells you
	# what it is about to do. If you can see the eye, you are behind it, and
	# behind it is where your bullets are worth four times as much.
	_mast = Node3D.new()
	_mast.name = "Mast"
	_mast.position = Vector3(0.44, 0.40, 0.0)
	_chassis.add_child(_mast)
	Enemy._part(_mast, "Post", LevelKit.chamfer_mesh(
		Vector3(0.13, 0.34, 0.13), 0.016), iron, Vector3(0, 0.15, 0))
	Enemy._part(_mast, "Collar", Enemy._cyl(0.085, 0.06, 8), iron,
		Vector3(0, 0.02, 0))
	Enemy._part(_mast, "Head", LevelKit.chamfer_mesh(
		Vector3(0.40, 0.30, 0.46), 0.024), shell, Vector3(0, 0.46, 0))
	Enemy.louvre(_mast, Vector3(0.02, 0.46, 0.235), Vector2(0.24, 0.10), 3,
		iron, 0.030)
	_optic = Enemy.optic(_mast, Vector3(-0.17, 0.48, 0.10), 0.095)
	# Aimed the way it walks, cheated toward the camera. Same cheat as the
	# drone and the turret: dead in profile an eye is a sliver.
	_optic.pivot.rotation.y = PI + deg_to_rad(30.0)
	_beacon = Enemy.beacon(_mast, Vector3(0.10, 0.62, -0.11), 0.050)
	# Loom from the head down the mast into the junction box.
	Enemy.loom(_chassis, Vector3(0.50, 0.44, -0.18),
		Vector3(0.46, 0.09, -0.29), 0.05, 0.026)

	_build_exhaust(stack)
	return root


## A thin heat shimmer out of the stack while it idles, and a hard black pulse
## when it commits. The stack is behind it, which means the player sees the
## exhaust before the unit turns round — a telegraph that arrives from the
## direction they are standing in.
func _build_exhaust(stack: Node3D) -> void:
	_exhaust = GPUParticles3D.new()
	_exhaust.name = "Smoke"
	_exhaust.amount = 12
	_exhaust.lifetime = 1.5
	_exhaust.local_coords = false
	_exhaust.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.55
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, 0.5, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.4
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(1.0, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(0.20, 0.18, 0.17, 0.42))
	g.set_color(1, Color(0.38, 0.35, 0.32, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_exhaust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.30)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.albedo_texture = PropKit._decal_texture("radial")
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	_exhaust.draw_pass_1 = quad
	_exhaust.position = Vector3(0, 0.45, 0)
	_exhaust.emitting = true
	stack.add_child(_exhaust)


## The shield only soaks what hits it. `from` is the world position the damage
## came from, so the test is simply which side of the chassis it is on.
func hurt(amount: float, from: Vector3, impulse := Vector3.ZERO) -> void:
	var front := signf(float(facing))
	var side := signf(from.x - global_position.x)
	if side == front:
		amount *= shield_soak
		Audio.play("shell", global_position, -4.0, randf_range(0.55, 0.65))
		_clang(from)
	super.hurt(amount, from, impulse)


## A visible ring-off, so soaking is information rather than a silent nerf.
## Three cues, because a quarter-damage hit has to feel different from a full
## one inside a single frame: the plate strokes on its mounts, a hard white
## spark ricochets off it, and the chevrons flash.
func _clang(from: Vector3) -> void:
	if _shield == null:
		return
	var tw := create_tween()
	tw.tween_property(_shield, "position:x", -0.62, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_shield, "position:x", -0.66, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A ricochet, thrown back the way the round came and upward. A spark that
	# sprays evenly reads as penetration; one that all goes one way reads as a
	# deflection, which is exactly the information the player needs.
	var away := (from - global_position)
	away.y = 0.8
	away.z = 0.0
	_particles(16, Color(1.0, 0.93, 0.78), 0.34, away.normalized(), 7.5)
	if _accent_mat != null:
		_accent_mat.set_shader_parameter("emission_color", Color(1, 1, 1))
		_accent_mat.set_shader_parameter("emission_strength", 3.2)


func _behaviour(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_timer += delta
	var grounded := is_on_floor()
	if not grounded:
		velocity.y -= 26.0 * delta
	else:
		if not _last_grounded:
			# It landed. Two tonnes arriving is worth a shake and a settle.
			nudge(Vector3(0, -4.0, 0), 0.0)
			FX.shake(0.10)
		velocity.y = 0.0
	_last_grounded = grounded

	var to_player := 0.0
	var sees := false
	if _player != null and is_instance_valid(_player):
		var d := (_player as Node3D).global_position - global_position
		to_player = d.x
		sees = absf(d.x) < sight_range and absf(d.y) < 3.2

	match _mode:
		Mode.PATROL:
			# Idle breath on the eye, beacon dark, chevrons unlit.
			_optic.set_state(Enemy.OPTIC_IDLE, 1.5 + 0.35 * sin(_cycle * 0.7))
			_optic.set_beam(3.4, 0.05, Enemy.OPTIC_IDLE)
			_beacon.set_state(Enemy.OPTIC_IDLE, 0.0)
			_set_hazard(0.0)
			_exhaust.amount_ratio = 0.5
			velocity.x = walk_speed * facing
			# Turn at the end of the beat OR at the edge of whatever it is
			# standing on. Without the edge test a patrol on a deck walks off
			# it on its first pass and the encounter never happens.
			if absf(global_position.x - _origin.x) > patrol_span or not _floor_ahead():
				facing = -facing
				velocity.x = walk_speed * facing
			if sees:
				_mode = Mode.ALERT
				_timer = 0.0
				facing = int(signf(to_player)) if to_player != 0.0 else facing
		Mode.ALERT:
			# Planted, eye going white, and a two-beat rock backwards. Long
			# enough to dash through it, which is the intended answer. The
			# 0.7 s is untouched; what changed is how loudly it is said.
			velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
			var t := clampf(_timer / wind_up, 0.0, 1.0)
			var pulse := 0.5 + 0.5 * sin(_timer * lerpf(9.0, 36.0, t))
			var tint := Enemy.OPTIC_IDLE.lerp(Enemy.OPTIC_HOT, t)
			_optic.set_state(tint, lerpf(1.5, 7.0, t) * (0.6 + 0.4 * pulse))
			_optic.set_beam(lerpf(3.4, 8.0, t), lerpf(0.06, 0.34, t), tint)
			_beacon.set_state(Color(1.0, 0.80, 0.34),
				7.0 if pulse > 0.55 else 0.0)
			# The chevrons on the shield light up. It is the biggest amber
			# surface on any unit in the game and it is pointed at the player.
			_set_hazard(t)
			# It revs before it goes. The stack is on the back, so a player
			# standing behind it — the safe side — sees the charge coming.
			_exhaust.amount_ratio = lerpf(0.5, 1.0, t)
			_chassis.position.x = lerpf(0.0, 0.16 * float(facing) * -1.0, t)
			_chassis.rotation.z = lerpf(0.0, 0.10 * float(facing), t)
			if _timer >= wind_up:
				_mode = Mode.CHARGE
				_timer = 0.0
				Audio.play("land_1.00", global_position, -4.0, 0.62)
				nudge(Vector3(signf(float(facing)) * -3.0, 1.0, 0.0), 0.0)
		Mode.CHARGE:
			_optic.set_state(Enemy.OPTIC_HOT, 7.5)
			_optic.set_beam(6.0, 0.26, Enemy.OPTIC_HOT)
			_beacon.set_state(Color(1.0, 0.88, 0.60), 7.5)
			_set_hazard(1.0)
			_exhaust.amount_ratio = 1.0
			# It will not run itself off a ledge; it plants instead, which also
			# happens to be the moment the player wants to be behind it.
			velocity.x = charge_speed * facing if _floor_ahead(1.35) else 0.0
			_chassis.position.x = 0.10 * float(facing)
			_chassis.rotation.z = -0.06 * float(facing)
			if _timer >= charge_time or is_on_wall() or not _floor_ahead(1.35):
				_mode = Mode.RECOVER
				_timer = 0.0
				# It stops the way a heavy thing stops: everything on it keeps
				# going for a moment.
				nudge(Vector3(signf(float(facing)) * 5.0, 0.0, 0.0),
					-signf(float(facing)) * 5.0)
		Mode.RECOVER:
			# Stopped, plate down, eye cooling. This is the window, and it now
			# says so in the same language as the other two units.
			velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
			var k := clampf(_timer / recover_time, 0.0, 1.0)
			_optic.set_state(Enemy.OPTIC_EMBER.lerp(Enemy.OPTIC_IDLE, k),
				lerpf(4.5, 1.5, k))
			_optic.set_beam(3.0, lerpf(0.12, 0.05, k), Enemy.OPTIC_EMBER)
			_beacon.set_state(Enemy.OPTIC_EMBER, lerpf(2.2, 0.0, k))
			_set_hazard((1.0 - k) * 0.4)
			_exhaust.amount_ratio = lerpf(1.0, 0.5, k)
			_chassis.position.x = lerpf(_chassis.position.x, 0.0,
				1.0 - exp(-7.0 * delta))
			_chassis.rotation.z = lerpf(_chassis.rotation.z, 0.0,
				1.0 - exp(-7.0 * delta))
			if _timer >= recover_time:
				_mode = Mode.PATROL
				_timer = 0.0

	_walk(delta)
	_mast_settle(delta)


func _set_hazard(amount: float) -> void:
	if _accent_mat == null:
		return
	_accent_mat.set_shader_parameter("emission_color", Color(1.0, 0.62, 0.18))
	_accent_mat.set_shader_parameter("emission_strength", amount * 3.0)


## Is there floor under the next step? Probes from knee height down past the
## feet, which also copes with the shallow steps the decks are made of.
func _floor_ahead(reach := 0.95) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(reach * float(facing), 0.6, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.2, 0))
	q.exclude = [get_rid()]
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


## A two-beat walk. No blending, no curves: a heavy machine's legs are levers
## and the readable thing is the stomp, not the arc.
##
## What is new is what hangs off it. The hydraulic rams extend and retract with
## the knee, the feet stay flat through the stance phase, and the whole hull
## drops on each footfall. A leg that swings without anything else on the
## machine acknowledging it is a leg on a puppet.
func _walk(delta: float) -> void:
	var speed := absf(velocity.x)
	_cycle += delta * (2.6 + speed * 1.15)
	for i in _legs.size():
		var phase := _cycle + PI * float(i)
		var lift := maxf(sin(phase), 0.0)
		var gait := clampf(speed / 3.0, 0.15, 1.0)
		_legs[i].rotation.z = cos(phase) * 0.34 * gait
		_shins[i].rotation.z = -lift * 0.42
		_legs[i].position.y = 1.32 + lift * 0.06
		# The ram extends as the knee closes. Opposed to the shin angle, which
		# is what a real actuator does and what makes it read as driving the
		# joint instead of riding on it.
		_rams[i].scale.y = 1.0 - lift * 0.22
		_rams[i].rotation.z = -lift * 0.14
	# The body drops on each footfall, which is where the weight comes from.
	if _chassis != null:
		_chassis.position.y = 1.62 - absf(sin(_cycle)) * 0.045


## The mast is the lightest thing on the machine and it is on the end of a
## lever, so it is the part that never quite catches up. Drive it off the
## hull's own acceleration rather than off a timer: it then leans back when it
## sets off, whips forward when it stops, and shivers on every footfall,
## without a single keyframe.
func _mast_settle(delta: float) -> void:
	if _mast == null:
		return
	var target := clampf(-velocity.x * 0.030, -0.16, 0.16)
	_mast_lag = lerpf(_mast_lag, target, 1.0 - exp(-7.0 * delta))
	_mast.rotation.z = _mast_lag + sin(_cycle * 2.0) * 0.012
	_optic.pivot.rotation.y = (PI + deg_to_rad(30.0)) if facing < 0 \
		else -deg_to_rad(30.0)
