class_name WanisRig extends Node3D
## Wanis's animation rig.
##
## Drives a Skeleton3D procedurally — no animation clips anywhere in this
## project. Poses are targets and every bone eases toward them, which is what
## produces overlap and follow-through for free: the chest arrives after the
## hips, the head after the chest, the robe after all of them.

const B := WanisBuilder.B

@export var outfit: WanisBuilder.Outfit = WanisBuilder.Outfit.STREET

var controller: PlayerController
var yaw: Node3D
var squash: Node3D
var skel: Skeleton3D
var body: MeshInstance3D
var chain_pivot: BoneAttachment3D

var _mats: Dictionary = {}
var _thobe_mat: ShaderMaterial
var _shemagh_mat: ShaderMaterial

# Animation state
var _cycle := 0.0
var _breath := 0.0
var _facing_yaw := PI * 0.5
var _prev_vx := 0.0
var _lean := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _idle_timer := 0.0
var _head_turn := 0.0
var _billow := 0.0
var _hip_y := 0.0
var _spin := 0.0        ## air-jump flourish


func _ready() -> void:
	_build()
	var parent := get_parent()
	if parent is PlayerController:
		bind(parent)


func bind(c: PlayerController) -> void:
	controller = c
	c.landed.connect(_on_landed)
	c.jumped.connect(_on_jumped)
	c.air_jumped.connect(_on_air_jumped)
	c.dash_started.connect(_on_dash_started)


# --- Construction -----------------------------------------------------------

func _build() -> void:
	yaw = Node3D.new()
	yaw.name = "Yaw"
	add_child(yaw)

	squash = Node3D.new()
	squash.name = "Squash"
	yaw.add_child(squash)

	skel = WanisBuilder.build_skeleton()
	squash.add_child(skel)

	_rebuild_body()

	# Gold chain, hung off the chest. Not skinned — it is rigid and it swings
	# with the bone it rides.
	chain_pivot = BoneAttachment3D.new()
	chain_pivot.name = "ChainAttach"
	skel.add_child(chain_pivot)
	chain_pivot.bone_name = "Chest"

	var chain_mesh := TorusMesh.new()
	chain_mesh.inner_radius = 0.095
	chain_mesh.outer_radius = 0.132
	chain_mesh.rings = 24
	chain_mesh.ring_segments = 8
	var chain := MeshInstance3D.new()
	chain.name = "Chain"
	chain.mesh = chain_mesh
	chain.material_override = MaterialLab.gold()
	chain.position = Vector3(0.0, -0.030, 0.222)
	chain.rotation_degrees = Vector3(74.0, 0.0, 0.0)
	chain_pivot.add_child(chain)


func _rebuild_body() -> void:
	if is_instance_valid(body):
		body.queue_free()
	var built := WanisBuilder.build_mesh(outfit)
	_mats = WanisBuilder.materials(outfit)
	_thobe_mat = _mats["thobe"]
	_shemagh_mat = _mats.get("shemagh")

	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = built["mesh"]
	skel.add_child(body)
	body.skin = skel.create_skin_from_rest_transforms()
	body.skeleton = NodePath("..")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Skinning and cloth displacement both push past the rest-pose AABB; without
	# a margin he pops out at the screen edge.
	body.extra_cull_margin = 1.5
	# Layer 2 is the hero layer: character-only rim lights cull to it.
	body.layers = 1 | 2

	var surfaces: Array = built["surfaces"]
	for i in surfaces.size():
		body.set_surface_override_material(i, _mats.get(surfaces[i]))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			var keep := arg.substr(7)
			var invis := StandardMaterial3D.new()
			invis.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			invis.albedo_color = Color(1, 1, 1, 0)
			for i in surfaces.size():
				if surfaces[i] != keep:
					body.set_surface_override_material(i, invis)
	if OS.get_cmdline_user_args().has("--debug-surfaces"):
		print("SURFACES: ", surfaces, " mesh count=", body.mesh.get_surface_count())
		var dbg := ["#ff00ff", "#00ff00", "#0088ff", "#ffff00", "#ff8800", "#00ffff", "#ff0044"]
		for i in surfaces.size():
			body.set_surface_override_material(i, MaterialLab.emissive(Color(dbg[i % dbg.size()]), 0.6))


func set_outfit(o: WanisBuilder.Outfit) -> void:
	if outfit == o:
		return
	outfit = o
	_rebuild_body()


# --- Bone helpers -----------------------------------------------------------

func _pose(bone: int, euler: Vector3, k: float) -> void:
	var target := Quaternion.from_euler(euler)
	skel.set_bone_pose_rotation(bone, skel.get_bone_pose_rotation(bone).slerp(target, k))


func _ease(delta: float, rate: float) -> float:
	return 1.0 - exp(-rate * delta)


# --- Animation --------------------------------------------------------------

func _process(delta: float) -> void:
	if controller == null:
		return
	delta = minf(delta, 1.0 / 30.0)

	var vx := controller.velocity.x
	var speed := controller.speed_ratio()
	var grounded := controller.is_on_floor()
	var accel := (vx - _prev_vx) / maxf(delta, 0.0001)
	_prev_vx = vx

	_drive_facing(delta)
	_drive_squash(delta)
	_drive_billow(delta)

	match controller.state:
		PlayerController.State.DASH:
			_pose_dash(delta)
		PlayerController.State.GLIDE:
			_pose_glide(delta)
		PlayerController.State.RISE, PlayerController.State.FALL:
			_pose_air(delta)
		PlayerController.State.RUN:
			_pose_run(delta, speed)
		_:
			_pose_idle(delta)

	_drive_torso(delta, vx, accel, grounded)
	skel.position.y = _hip_y


func _drive_facing(delta: float) -> void:
	var want := PI * 0.5 * controller.facing
	_facing_yaw = lerp_angle(_facing_yaw, want, _ease(delta, 17.0))
	# Air-jump flourish: a full rotation folded into the facing, so the double
	# jump has a read of its own instead of being a second identical hop.
	if _spin > 0.001:
		_spin = lerpf(_spin, 0.0, _ease(delta, 6.5))
	yaw.rotation.y = _facing_yaw + _spin * controller.facing


func _drive_squash(delta: float) -> void:
	_squash_vel += (-_squash * 200.0 - _squash_vel * 21.0) * delta
	_squash += _squash_vel * delta

	var stretch := 0.0
	if controller.is_airborne() and not controller.is_gliding():
		stretch = clampf(controller.velocity.y * 0.010, -0.09, 0.13)

	var s := 1.0 + _squash + stretch
	squash.scale = Vector3(1.0 / maxf(s, 0.4), s, 1.0 / maxf(s, 0.4))


func _drive_billow(delta: float) -> void:
	var want := 0.0
	if controller.is_gliding():
		want = controller.glide_blend()
	elif controller.is_dashing():
		want = 0.55
	elif controller.is_airborne():
		want = clampf(absf(controller.velocity.y) / 26.0, 0.0, 0.30)
	else:
		want = controller.speed_ratio() * 0.26
	_billow = lerpf(_billow, want, _ease(delta, 9.0))

	# Cloth streams opposite to travel, in model space: +Z is his forward, so
	# running forward drags the robe and shemagh to -Z.
	var v := controller.velocity
	var local_dir := Vector3(0.0, 0.0, -controller.facing * signf(v.x) if not is_zero_approx(v.x) else -1.0)
	local_dir.y = clampf(-v.y * 0.045, -0.7, 0.7)
	local_dir = local_dir.normalized()
	var trail := clampf(Vector2(v.x, v.y * 0.5).length() / 13.0, 0.0, 1.0)
	if controller.is_dashing():
		trail = 1.0

	for m: ShaderMaterial in [_thobe_mat, _shemagh_mat]:
		if m == null:
			continue
		m.set_shader_parameter("billow", _billow)
		m.set_shader_parameter("trail_dir", local_dir)
		m.set_shader_parameter("trail_amount", trail)


func _drive_torso(delta: float, vx: float, accel: float, grounded: bool) -> void:
	var lean_target := clampf(-accel * 0.0028, -0.30, 0.30) + clampf(vx * 0.010, -0.12, 0.12)
	if not grounded:
		lean_target = clampf(vx * 0.014, -0.18, 0.18)
	if controller.is_gliding():
		lean_target *= 0.35
	_lean = lerpf(_lean, lean_target, _ease(delta, 10.0))
	# Lean is split across the chain so the spine curves instead of hinging.
	skel.rotation.z = _lean * 0.35
	var k := _ease(delta, 14.0)
	_pose(B.HIPS, Vector3(skel.get_bone_pose_rotation(B.HIPS).get_euler().x, 0.0, _lean * 0.25), k)


func _pose_run(delta: float, speed: float) -> void:
	_cycle += delta * lerpf(6.2, 13.0, speed)
	var k := _ease(delta, 22.0)
	var amp := lerpf(0.34, 0.92, speed)
	var s := sin(_cycle)
	var c := sin(_cycle + PI)

	# Legs: thigh swings, knee folds on the recovery half of the stride.
	_pose(B.THIGH_L, Vector3(-s * amp, 0.0, 0.0), k)
	_pose(B.THIGH_R, Vector3(s * amp, 0.0, 0.0), k)
	_pose(B.SHIN_L, Vector3(maxf(s, 0.0) * amp * 1.25, 0.0, 0.0), k)
	_pose(B.SHIN_R, Vector3(maxf(-s, 0.0) * amp * 1.25, 0.0, 0.0), k)
	_pose(B.FOOT_L, Vector3(-s * 0.25, 0.0, 0.0), k)
	_pose(B.FOOT_R, Vector3(s * 0.25, 0.0, 0.0), k)

	# Arms counter-swing, elbows always carry a bend — straight arms read as a
	# doll. Sleeves are wide so the swing shows.
	_pose(B.ARM_L, Vector3(c * amp * 0.80, 0.0, 0.16), k)
	_pose(B.ARM_R, Vector3(-c * amp * 0.80, 0.0, -0.16), k)
	_pose(B.FOREARM_L, Vector3(-0.35 - maxf(c, 0.0) * 0.55, 0.0, 0.0), k)
	_pose(B.FOREARM_R, Vector3(-0.35 - maxf(-c, 0.0) * 0.55, 0.0, 0.0), k)
	_pose(B.SHOULDER_L, Vector3(0.0, 0.0, 0.10 + maxf(c, 0.0) * 0.12), k)
	_pose(B.SHOULDER_R, Vector3(0.0, 0.0, -0.10 - maxf(-c, 0.0) * 0.12), k)

	# Counter-rotation through the spine sells the weight transfer.
	_pose(B.SPINE, Vector3(-0.09 - speed * 0.16, -s * 0.11 * speed, 0.0), k)
	_pose(B.CHEST, Vector3(-0.04, s * 0.19 * speed, 0.0), k)
	_pose(B.NECK, Vector3(0.05 + speed * 0.10, 0.0, 0.0), k)
	_pose(B.HEAD, Vector3(0.04, 0.0, 0.0), k)

	# Two bounces per stride.
	_hip_y = lerpf(_hip_y, -absf(s) * lerpf(0.018, 0.070, speed), _ease(delta, 18.0))


func _pose_idle(delta: float) -> void:
	_breath += delta * 1.5
	_idle_timer += delta
	var k := _ease(delta, 7.0)
	var b := sin(_breath)

	_pose(B.THIGH_L, Vector3(0.03, 0.0, 0.0), k)
	_pose(B.THIGH_R, Vector3(-0.03, 0.0, 0.0), k)
	_pose(B.SHIN_L, Vector3(0.05, 0.0, 0.0), k)
	_pose(B.SHIN_R, Vector3(0.04, 0.0, 0.0), k)
	_pose(B.FOOT_L, Vector3(0.0, 0.0, 0.0), k)
	_pose(B.FOOT_R, Vector3(0.0, 0.0, 0.0), k)

	# Hands carried forward of the body: in profile the cuffs have to clear the
	# robe or the arms may as well not exist.
	_pose(B.ARM_L, Vector3(-0.20 + b * 0.05, 0.0, 0.18), k)
	_pose(B.ARM_R, Vector3(-0.14 - b * 0.05, 0.0, -0.18), k)
	_pose(B.FOREARM_L, Vector3(-0.52 - b * 0.05, 0.0, 0.0), k)
	_pose(B.FOREARM_R, Vector3(-0.46 + b * 0.05, 0.0, 0.0), k)
	_pose(B.SHOULDER_L, Vector3(0.0, 0.0, 0.06 + b * 0.03), k)
	_pose(B.SHOULDER_R, Vector3(0.0, 0.0, -0.06 - b * 0.03), k)

	_pose(B.SPINE, Vector3(b * 0.022 - 0.01, 0.0, 0.0), k)
	_pose(B.CHEST, Vector3(b * 0.030, 0.0, 0.0), k)

	# He does not stand still. Every few seconds he looks at something.
	if _idle_timer > 3.2:
		_idle_timer = 0.0
		_head_turn = randf_range(-0.6, 0.6)
	_head_turn = lerpf(_head_turn, 0.0, _ease(delta, 1.0))
	_pose(B.NECK, Vector3(b * 0.02, _head_turn * 0.4, 0.0), k)
	_pose(B.HEAD, Vector3(-0.03 + b * 0.02, _head_turn * 0.6, 0.0), k)

	_hip_y = lerpf(_hip_y, b * 0.010, _ease(delta, 6.0))
	_cycle = 0.0


func _pose_air(delta: float) -> void:
	var rising := controller.velocity.y > 0.0
	var k := _ease(delta, 13.0)
	if rising:
		_pose(B.THIGH_L, Vector3(-0.85, 0.0, 0.0), k)
		_pose(B.THIGH_R, Vector3(-0.40, 0.0, 0.0), k)
		_pose(B.SHIN_L, Vector3(1.05, 0.0, 0.0), k)
		_pose(B.SHIN_R, Vector3(0.55, 0.0, 0.0), k)
		_pose(B.ARM_L, Vector3(1.35, 0.0, 0.22), k)
		_pose(B.ARM_R, Vector3(1.10, 0.0, -0.22), k)
		_pose(B.FOREARM_L, Vector3(-0.55, 0.0, 0.0), k)
		_pose(B.FOREARM_R, Vector3(-0.45, 0.0, 0.0), k)
		_pose(B.SPINE, Vector3(-0.14, 0.0, 0.0), k)
		_pose(B.NECK, Vector3(-0.10, 0.0, 0.0), k)
	else:
		var t := clampf(-controller.velocity.y / 22.0, 0.0, 1.0)
		_pose(B.THIGH_L, Vector3(-0.34 - t * 0.22, 0.0, 0.0), k)
		_pose(B.THIGH_R, Vector3(0.20, 0.0, 0.0), k)
		_pose(B.SHIN_L, Vector3(0.28, 0.0, 0.0), k)
		_pose(B.SHIN_R, Vector3(0.62, 0.0, 0.0), k)
		_pose(B.ARM_L, Vector3(0.45, 0.0, 0.50 + t * 0.35), k)
		_pose(B.ARM_R, Vector3(0.30, 0.0, -0.50 - t * 0.35), k)
		_pose(B.FOREARM_L, Vector3(-0.40, 0.0, 0.0), k)
		_pose(B.FOREARM_R, Vector3(-0.35, 0.0, 0.0), k)
		_pose(B.SPINE, Vector3(0.08, 0.0, 0.0), k)
		_pose(B.NECK, Vector3(0.06, 0.0, 0.0), k)
	_pose(B.CHEST, Vector3(0.0, 0.0, 0.0), k)
	_pose(B.HEAD, Vector3(-0.05 if rising else 0.04, 0.0, 0.0), k)
	_hip_y = lerpf(_hip_y, 0.0, k)


## The glide. Arms out wide so the sleeves spread, legs trailing, chin up —
## a shape that could not be mistaken for a fall at any size on screen.
func _pose_glide(delta: float) -> void:
	var k := _ease(delta, 11.0)
	var t := controller.glide_blend()
	var flutter := sin(_breath * 6.0) * 0.05 * t
	_breath += delta * 2.2

	_pose(B.ARM_L, Vector3(0.10, 0.0, 1.18 * t + 0.2 + flutter), k)
	_pose(B.ARM_R, Vector3(0.10, 0.0, -1.18 * t - 0.2 - flutter), k)
	_pose(B.FOREARM_L, Vector3(-0.18, 0.0, 0.0), k)
	_pose(B.FOREARM_R, Vector3(-0.18, 0.0, 0.0), k)
	_pose(B.SHOULDER_L, Vector3(0.0, 0.0, 0.28 * t), k)
	_pose(B.SHOULDER_R, Vector3(0.0, 0.0, -0.28 * t), k)

	_pose(B.THIGH_L, Vector3(0.22 * t, 0.0, 0.0), k)
	_pose(B.THIGH_R, Vector3(0.30 * t, 0.0, 0.0), k)
	_pose(B.SHIN_L, Vector3(0.45 * t, 0.0, 0.0), k)
	_pose(B.SHIN_R, Vector3(0.30 * t, 0.0, 0.0), k)
	_pose(B.FOOT_L, Vector3(-0.25 * t, 0.0, 0.0), k)
	_pose(B.FOOT_R, Vector3(-0.25 * t, 0.0, 0.0), k)

	_pose(B.SPINE, Vector3(-0.16 * t, 0.0, 0.0), k)
	_pose(B.CHEST, Vector3(-0.10 * t, 0.0, 0.0), k)
	_pose(B.NECK, Vector3(-0.14 * t, 0.0, 0.0), k)
	_pose(B.HEAD, Vector3(-0.10 * t, 0.0, 0.0), k)
	_hip_y = lerpf(_hip_y, 0.02 * t, k)


func _pose_dash(delta: float) -> void:
	var k := _ease(delta, 24.0)
	_pose(B.SPINE, Vector3(-0.52, 0.0, 0.0), k)
	_pose(B.CHEST, Vector3(-0.16, 0.0, 0.0), k)
	_pose(B.NECK, Vector3(0.34, 0.0, 0.0), k)
	_pose(B.HEAD, Vector3(0.22, 0.0, 0.0), k)
	_pose(B.ARM_L, Vector3(-1.55, 0.0, 0.30), k)
	_pose(B.ARM_R, Vector3(-1.35, 0.0, -0.30), k)
	_pose(B.FOREARM_L, Vector3(-0.30, 0.0, 0.0), k)
	_pose(B.FOREARM_R, Vector3(-0.30, 0.0, 0.0), k)
	_pose(B.THIGH_L, Vector3(-0.62, 0.0, 0.0), k)
	_pose(B.THIGH_R, Vector3(0.48, 0.0, 0.0), k)
	_pose(B.SHIN_L, Vector3(0.70, 0.0, 0.0), k)
	_pose(B.SHIN_R, Vector3(0.20, 0.0, 0.0), k)
	_hip_y = lerpf(_hip_y, -0.05, k)


# --- Reactions --------------------------------------------------------------

func _on_landed(impact: float) -> void:
	_squash = -lerpf(0.09, 0.30, impact)
	_squash_vel = 0.0


func _on_jumped(_from_coyote: bool) -> void:
	_squash = 0.15
	_squash_vel = 0.0
	_cycle = 0.0


func _on_air_jumped(_index: int) -> void:
	_squash = 0.18
	_squash_vel = 0.0
	_spin = TAU


func _on_dash_started(charged: bool) -> void:
	_squash = 0.10 if charged else 0.06
	_squash_vel = 0.0
