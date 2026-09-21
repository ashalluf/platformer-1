class_name PlayerRig extends Node3D
## Procedural animation rig for Wanis.
##
## Builds a readable greybox proxy and animates it entirely in code: run cycle,
## breathing idle, anticipation, squash/stretch, lean, follow-through and a
## verlet sash. When the sculpted model lands, `_build_proxy()` is the only
## function that gets replaced — every driver below reads from the controller,
## not from the geometry.

@export var body_color := Color(0.86, 0.84, 0.80)
@export var accent_color := Color(0.85, 0.20, 0.12)
@export var dark_color := Color(0.14, 0.13, 0.15)

var controller: PlayerController

# Rig nodes
var yaw: Node3D
var squash: Node3D
var hips: Node3D
var torso: Node3D
var chest: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var sash: VerletChain

# Animation state
var _cycle := 0.0
var _lean := 0.0
var _squash_amount := 0.0
var _squash_vel := 0.0
var _breath := 0.0
var _facing_yaw := 0.0
var _prev_vx := 0.0
var _airtime := 0.0
var _idle_timer := 0.0
var _head_turn := 0.0

const HIP_HEIGHT := 0.90


func _ready() -> void:
	_build_proxy()
	_facing_yaw = PI * 0.5
	var parent := get_parent()
	if parent is PlayerController:
		bind(parent)


func bind(c: PlayerController) -> void:
	controller = c
	c.landed.connect(_on_landed)
	c.jumped.connect(_on_jumped)
	c.dash_started.connect(_on_dash_started)


# --- Construction -----------------------------------------------------------

func _mat(color: Color, rough := 0.62, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _piece(parent: Node3D, name_: String, mesh: Mesh, mat: Material, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = pos
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = mat
	pivot.add_child(mi)
	return pivot


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(height, radius * 2.001)
	c.radial_segments = 16
	c.rings = 6
	return c


func _build_proxy() -> void:
	var skin := _mat(Color(0.78, 0.56, 0.38), 0.55)
	var cloth := _mat(accent_color, 0.70)
	var shirt := _mat(body_color, 0.78)
	var dark := _mat(dark_color, 0.5)
	var gold := _mat(Color(0.95, 0.74, 0.26), 0.20, 1.0)

	yaw = Node3D.new()
	yaw.name = "Yaw"
	add_child(yaw)

	squash = Node3D.new()
	squash.name = "Squash"
	yaw.add_child(squash)

	hips = Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, HIP_HEIGHT, 0.0)
	squash.add_child(hips)

	# Torso tapers: narrow waist, broad shoulders. The shoulder block is what
	# makes the silhouette read as a person and not a bean.
	torso = _piece(hips, "Torso", _capsule(0.215, 0.58), shirt, Vector3(0, 0.16, 0))
	chest = Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 0.30, 0)
	torso.add_child(chest)

	var jacket := BoxMesh.new()
	jacket.size = Vector3(0.60, 0.42, 0.34)
	var jacket_node := _piece(chest, "Jacket", jacket, cloth, Vector3(0, -0.04, 0))
	(jacket_node.get_node("Mesh") as MeshInstance3D).mesh = jacket

	var neck := _capsule(0.085, 0.16)
	_piece(chest, "Neck", neck, skin, Vector3(0, 0.20, 0))

	head = _piece(chest, "Head", _capsule(0.185, 0.42), skin, Vector3(0, 0.44, 0.01))
	var hair := SphereMesh.new()
	hair.radius = 0.215
	hair.height = 0.34
	hair.radial_segments = 18
	hair.rings = 9
	_piece(head, "Hair", hair, dark, Vector3(0, 0.09, -0.025))
	var beard := SphereMesh.new()
	beard.radius = 0.15
	beard.height = 0.20
	beard.radial_segments = 14
	beard.rings = 7
	_piece(head, "Beard", beard, dark, Vector3(0, -0.10, 0.045))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.34, 0.07, 0.06)
	_piece(head, "Shades", visor, dark, Vector3(0, 0.13, 0.155))

	var chain := TorusMesh.new()
	chain.inner_radius = 0.115
	chain.outer_radius = 0.155
	chain.rings = 18
	chain.ring_segments = 8
	var chain_node := _piece(chest, "Chain", chain, gold, Vector3(0, 0.04, 0.155))
	chain_node.rotation_degrees = Vector3(76, 0, 0)

	arm_l = _piece(chest, "ArmL", _capsule(0.072, 0.50), skin, Vector3(-0.285, 0.06, 0.0))
	arm_r = _piece(chest, "ArmR", _capsule(0.072, 0.50), skin, Vector3(0.285, 0.06, 0.0))
	for arm: Node3D in [arm_l, arm_r]:
		(arm.get_node("Mesh") as Node3D).position = Vector3(0, -0.24, 0)
		var sleeve := _capsule(0.092, 0.22)
		_piece(arm, "Sleeve", sleeve, cloth, Vector3(0, -0.07, 0))
		var hand := SphereMesh.new()
		hand.radius = 0.082
		hand.height = 0.164
		hand.radial_segments = 12
		hand.rings = 6
		_piece(arm, "Hand", hand, skin, Vector3(0, -0.47, 0))

	leg_l = _piece(hips, "LegL", _capsule(0.10, 0.72), dark, Vector3(-0.125, -0.06, 0.0))
	leg_r = _piece(hips, "LegR", _capsule(0.10, 0.72), dark, Vector3(0.125, -0.06, 0.0))
	for leg: Node3D in [leg_l, leg_r]:
		(leg.get_node("Mesh") as Node3D).position = Vector3(0, -0.36, 0)
		# Sandals — the most Libyan detail available on a greybox.
		var sandal := BoxMesh.new()
		sandal.size = Vector3(0.17, 0.07, 0.30)
		_piece(leg, "Sandal", sandal, _mat(Color(0.32, 0.22, 0.14), 0.55), Vector3(0, -0.72, 0.05))

	var sash_anchor := Node3D.new()
	sash_anchor.name = "SashAnchor"
	sash_anchor.position = Vector3(0.0, 0.04, -0.16)
	hips.add_child(sash_anchor)

	sash = VerletChain.new()
	sash.name = "Sash"
	sash.segments = 10
	sash.segment_length = 0.13
	sash.thickness = 0.22
	sash.taper = 0.42
	sash.gravity = 11.0
	sash.inertia = 1.6
	var sash_mat := _mat(Color(0.90, 0.86, 0.78), 0.85)
	sash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sash.chain_material = sash_mat
	sash_anchor.add_child(sash)


# --- Animation --------------------------------------------------------------

func _process(delta: float) -> void:
	if controller == null:
		return
	delta = minf(delta, 1.0 / 30.0)

	var vx := controller.velocity.x
	var speed_ratio := controller.speed_ratio()
	var grounded := controller.is_on_floor()
	var accel := (vx - _prev_vx) / maxf(delta, 0.0001)
	_prev_vx = vx

	_airtime = 0.0 if grounded else _airtime + delta
	_drive_facing(delta)
	_drive_squash(delta)

	match controller.state:
		PlayerController.State.DASH:
			_pose_dash(delta)
		PlayerController.State.RISE, PlayerController.State.FALL:
			_pose_air(delta)
		PlayerController.State.RUN:
			_pose_run(delta, speed_ratio, accel)
		_:
			_pose_idle(delta)

	# Lean reads acceleration, not velocity: the body tips into a change of
	# direction and settles once the speed is constant.
	var lean_target := clampf(-accel * 0.0035, -0.34, 0.34) + clampf(vx * 0.012, -0.14, 0.14)
	if not grounded:
		lean_target = clampf(vx * 0.018, -0.22, 0.22)
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-11.0 * delta))
	hips.rotation.z = _lean
	chest.rotation.z = _lean * 0.45


func _drive_facing(delta: float) -> void:
	var want := PI * 0.5 * controller.facing
	_facing_yaw = lerp_angle(_facing_yaw, want, 1.0 - exp(-18.0 * delta))
	yaw.rotation.y = _facing_yaw


func _drive_squash(delta: float) -> void:
	# Critically damped spring back to neutral — gives pop without jitter.
	var stiffness := 210.0
	var damp := 22.0
	_squash_vel += (-_squash_amount * stiffness - _squash_vel * damp) * delta
	_squash_amount += _squash_vel * delta

	var stretch := 0.0
	if controller.is_airborne():
		stretch = clampf(controller.velocity.y * 0.012, -0.10, 0.14)

	var s := 1.0 + _squash_amount + stretch
	squash.scale = Vector3(1.0 / maxf(s, 0.35), s, 1.0 / maxf(s, 0.35))


func _pose_run(delta: float, speed_ratio: float, _accel: float) -> void:
	_cycle += delta * lerpf(6.0, 13.5, speed_ratio)
	var swing := sin(_cycle) * lerpf(0.35, 0.95, speed_ratio)
	var counter := sin(_cycle + PI) * lerpf(0.30, 0.80, speed_ratio)

	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	arm_l.rotation.x = counter * 0.9
	arm_r.rotation.x = -counter * 0.9
	arm_l.rotation.z = 0.12
	arm_r.rotation.z = -0.12

	# Two bounces per stride, plus a shoulder counter-rotation.
	var bob := absf(sin(_cycle)) * lerpf(0.02, 0.075, speed_ratio)
	hips.position.y = HIP_HEIGHT - bob
	chest.rotation.y = sin(_cycle) * 0.16 * speed_ratio
	hips.rotation.y = -sin(_cycle) * 0.10 * speed_ratio
	head.rotation.x = lerpf(head.rotation.x, -0.06 - speed_ratio * 0.10, 1.0 - exp(-10.0 * delta))
	torso.rotation.x = lerpf(torso.rotation.x, -0.10 - speed_ratio * 0.20, 1.0 - exp(-10.0 * delta))


func _pose_idle(delta: float) -> void:
	_breath += delta * 1.6
	_idle_timer += delta
	var b := sin(_breath)
	hips.position.y = lerpf(hips.position.y, HIP_HEIGHT + b * 0.012, 1.0 - exp(-9.0 * delta))
	chest.rotation.x = lerpf(chest.rotation.x, b * 0.035 - 0.02, 1.0 - exp(-9.0 * delta))
	torso.rotation.x = lerpf(torso.rotation.x, 0.0, 1.0 - exp(-9.0 * delta))

	# Personality: he glances around every few seconds instead of standing still.
	if _idle_timer > 3.4:
		_idle_timer = 0.0
		_head_turn = randf_range(-0.55, 0.55)
	_head_turn = lerpf(_head_turn, 0.0, 1.0 - exp(-1.1 * delta))
	head.rotation.y = lerpf(head.rotation.y, _head_turn, 1.0 - exp(-7.0 * delta))
	head.rotation.x = lerpf(head.rotation.x, b * 0.02, 1.0 - exp(-7.0 * delta))

	var sway := sin(_breath * 0.5) * 0.05
	leg_l.rotation.x = lerpf(leg_l.rotation.x, sway * 0.3, 1.0 - exp(-8.0 * delta))
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -sway * 0.3, 1.0 - exp(-8.0 * delta))
	arm_l.rotation.x = lerpf(arm_l.rotation.x, sway, 1.0 - exp(-8.0 * delta))
	arm_r.rotation.x = lerpf(arm_r.rotation.x, -sway, 1.0 - exp(-8.0 * delta))
	arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.16, 1.0 - exp(-8.0 * delta))
	arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.16, 1.0 - exp(-8.0 * delta))
	_cycle = 0.0


func _pose_air(delta: float) -> void:
	var rising := controller.velocity.y > 0.0
	var k := 1.0 - exp(-13.0 * delta)
	if rising:
		# Tuck on the way up: knees gather, arms drive upward.
		leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.72, k)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -0.34, k)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -1.5, k)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -1.25, k)
		torso.rotation.x = lerpf(torso.rotation.x, -0.16, k)
	else:
		# Reach on the way down: legs extend for the landing, arms spread.
		var t := clampf(-controller.velocity.y / 22.0, 0.0, 1.0)
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.30 + t * 0.20, k)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -0.16, k)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.55, k)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.30, k)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.55 + t * 0.35, k)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.55 - t * 0.35, k)
		torso.rotation.x = lerpf(torso.rotation.x, 0.10, k)
	hips.position.y = lerpf(hips.position.y, HIP_HEIGHT, k)


func _pose_dash(delta: float) -> void:
	var k := 1.0 - exp(-24.0 * delta)
	torso.rotation.x = lerpf(torso.rotation.x, -0.62, k)
	head.rotation.x = lerpf(head.rotation.x, 0.30, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, 1.8, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, 1.55, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.2, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.2, k)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.55, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.45, k)
	hips.position.y = lerpf(hips.position.y, HIP_HEIGHT - 0.06, k)


# --- Reactions --------------------------------------------------------------

func _on_landed(impact: float) -> void:
	_squash_amount = -lerpf(0.10, 0.32, impact)
	_squash_vel = 0.0


func _on_jumped(_from_coyote: bool) -> void:
	_squash_amount = 0.16
	_squash_vel = 0.0
	_cycle = 0.0


func _on_dash_started(charged: bool) -> void:
	_squash_amount = 0.10 if charged else 0.06
	_squash_vel = 0.0
