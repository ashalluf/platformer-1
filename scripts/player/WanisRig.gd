class_name WanisRig extends Node3D
## Wanis's animation rig.
##
## Drives a Skeleton3D procedurally — there is not one animation clip in this
## project. A pose function only ever states where a bone *wants* to be; a
## per-bone damped spring decides when it gets there. Every joint down a chain
## is tuned a little slower than its parent, so a direction change ripples up
## the body instead of snapping. That ripple — overlap and follow-through — is
## most of what separates animation from posing.
##
## Everything in here is presentation. The rig reads the controller; it never
## writes to it and never touches gameplay timing.
##
## Orientation, because every sign in this file depends on it and getting one
## wrong is invisible until it looks "off":
##   +Z is his forward — the face, the jaw and the muzzle all point that way.
##   A bone hanging down (arm, thigh) swings FORWARD on a negative X rotation.
##   The spine tips the chest forward on a POSITIVE X rotation.
##   The face looks UP on a negative neck/head X rotation.
##   The camera sits on +Z looking down -Z, so the model's X axis is screen
##   DEPTH. Rotations about Z (hip drops, shoulder tilts) barely read in
##   profile; rotations about X (swing, pitch) are the whole silhouette. Depth
##   rotations still earn their place — they separate the near arm from the
##   white thobe and they carry the beauty frames — but they can never be the
##   only thing selling a pose.

const B := WanisBuilder.B

## Metres of travel per step. PlayerController fires its footstep at exactly
## this distance, so locking the cycle to it puts the foot down on its own
## sound. Measured at a sprint, the swing carries the planted foot about 1.1 m
## of that 1.55, so roughly a quarter of each step still slips: 9.2 m/s is
## world-record pace for a body this size and no stride can honestly cover it.
## The real fixes live in files this agent does not own. A quarter is a few
## pixels a frame against a background moving ten; the half a time-driven
## cycle was producing was a moonwalk.
const STRIDE := 1.55

@export var outfit: WanisBuilder.Outfit = WanisBuilder.Outfit.STREET

## Beauty frames and the title screen swap the symmetrical gameplay idle for an
## authored contrapposto stance. See _pose_beauty.
var beauty_pose := false

var controller: PlayerController
var yaw: Node3D
var squash: Node3D
var skel: Skeleton3D
var body: MeshInstance3D
var chain_pivot: BoneAttachment3D
var weapon_mount: BoneAttachment3D
var rifle: Rifle

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
var _billow := 0.0
var _hip_y := 0.0
var _spin := 0.0        ## air-jump flourish
var _weapon_blend := 0.0
var _recoil := 0.0
var _recoil_vel := 0.0

var _springs: Dictionary = {}
var _spine_rest := Vector3.ZERO
## Counter-translation on the spine. The pelvis bobs through a stride; the head
## should not travel with it.
var _spine_shift := 0.0
var _shift_target := 0.0
## Whole-body pitch into the airflow. The glide owns this.
var _body_pitch := 0.0
var _pitch_target := 0.0
## Landing: the knee compression and, outlasting it, the weight settling.
var _land := 0.0
var _land_shift := 0.0
## Firing: a light under-damped spring the rifle kicks once per round.
var _shock := 0.0
var _shock_vel := 0.0
var _shock_side := 0.0
## Idle: which foot he is standing on, -1..1, and the look-around.
var _weight := 1.0
var _weight_target := 1.0
var _weight_timer := 2.0
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _look_hold := 1.5
## Turn: lead with the head, drag the shoulders.
var _turn_lag := 0.0
var _turn_dir := 1.0
## Seconds since he died. Drives the collapse; reset the moment he is not.
var _death_t := 0.0

## Headless pose trace. See _trace_pose at the bottom of the file.
var _trace := OS.get_cmdline_user_args().has("--rig-debug")
var _trace_frame := 0


## One damped spring per bone, integrated in euler space.
##
## Why a spring and not a lerp: a lerp has no memory, so every joint in a chain
## arrives on the same frame and the body moves as one rigid object. A
## second-order spring carries velocity — it overshoots and settles, and a
## slower child lags its parent by a few frames for free.
class BoneSpring extends RefCounted:
	var value := Vector3.ZERO
	var vel := Vector3.ZERO
	var target := Vector3.ZERO
	var freq: float          ## natural frequency in Hz; higher arrives sooner
	var zeta: float          ## damping ratio; below 1 overshoots, 1 settles dead
	var urgency := 1.0       ## per-state multiplier on freq
	var damp := 1.0          ## per-state multiplier on zeta

	func _init(f: float, z: float) -> void:
		freq = f
		zeta = z

	## Semi-implicit Euler, substepped. The substeps are not optional: a 10 Hz
	## spring integrated in one 1/30 s step is unstable and detonates the pose.
	func step(delta: float, steps: int) -> void:
		var h := delta / float(steps)
		var omega := TAU * freq * urgency
		var stiffness := omega * omega
		var drag := 2.0 * zeta * damp * omega
		for _i in steps:
			vel += ((target - value) * stiffness - vel * drag) * h
			value += vel * h


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
	c.fired.connect(_on_fired)
	c.hit.connect(_on_hit)
	c.turned.connect(_on_turned)
	c.footstep.connect(_on_footstep)
	c.rifle = rifle


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
	_spine_rest = skel.get_bone_rest(B.SPINE).origin
	_build_springs()

	_rebuild_body()
	_build_rifle()

	# Gold chain, hung off the chest. Not skinned — it is rigid and it swings
	# with the bone it rides.
	chain_pivot = BoneAttachment3D.new()
	chain_pivot.name = "ChainAttach"
	skel.add_child(chain_pivot)
	chain_pivot.bone_name = "Chest"

	var chain_mesh := TorusMesh.new()
	# Halved: at the old size it was wider than his chest and read as a hoop
	# rather than as a chain.
	chain_mesh.inner_radius = 0.052
	chain_mesh.outer_radius = 0.074
	chain_mesh.rings = 24
	chain_mesh.ring_segments = 8
	var chain := MeshInstance3D.new()
	chain.name = "Chain"
	chain.mesh = chain_mesh
	chain.material_override = MaterialLab.gold()
	chain.position = Vector3(0.0, -0.012, 0.206)
	chain.rotation_degrees = Vector3(74.0, 0.0, 0.0)
	chain_pivot.add_child(chain)


## The response curve of the whole upper body, in one table.
##
## Read it as a waterfall: the pelvis is nearly rigid, and each joint outward
## is slower than the one that drives it. At 60 fps the head lands roughly six
## frames behind the hips, the hands another two behind the forearms. Drop the
## damping below ~0.6 and a joint starts to wobble on its own; above ~0.95 it
## stops overshooting and the follow-through disappears with it.
func _build_springs() -> void:
	var rates := [
		# bone, Hz, damping ratio. Measured against a step input at 60 fps: the
		# hips are 90% there in 3 frames, the head in 6, the hands in 7, and
		# the head and hands overshoot by about a tenth before settling.
		[B.HIPS, 12.0, 1.00],        # the root of every chain; no wobble allowed
		[B.SPINE, 7.0, 0.85],
		[B.CHEST, 5.0, 0.72],
		[B.NECK, 3.9, 0.64],
		[B.HEAD, 3.1, 0.58],         # last to arrive, most overshoot
		[B.SHOULDER_L, 5.6, 0.82], [B.SHOULDER_R, 5.6, 0.82],
		[B.ARM_L, 4.3, 0.68], [B.ARM_R, 4.3, 0.68],
		[B.FOREARM_L, 3.5, 0.60], [B.FOREARM_R, 3.5, 0.60],
		[B.HAND_L, 2.8, 0.54], [B.HAND_R, 2.8, 0.54],
	]
	for r: Array in rates:
		_springs[int(r[0])] = BoneSpring.new(float(r[1]), float(r[2]))


## The rifle rides a chest attachment and slides between two poses: slung
## across the back, and up in both hands. No IK — in a side-on game the arms
## are posed to the rifle rather than the rifle solved to the arms.
## Slung: muzzle down and back over the shoulder, lying in the plane the camera
## can actually see. A rifle slung across the back is invisible in a side view.
const SLUNG_POS := Vector3(0.0, -0.16, -0.22)
const SLUNG_ROT := Vector3(2.04, 0.0, 0.0)     ## 117 degrees about X
## Ready: shouldered, muzzle forward along his facing.
const READY_POS := Vector3(0.05, -0.17, 0.17)
const READY_ROT := Vector3(0.0, 0.0, 0.0)


func _build_rifle() -> void:
	weapon_mount = BoneAttachment3D.new()
	weapon_mount.name = "WeaponMount"
	skel.add_child(weapon_mount)
	weapon_mount.bone_name = "Chest"

	rifle = Rifle.new()
	rifle.name = "Rifle"
	weapon_mount.add_child(rifle)
	rifle.position = SLUNG_POS
	rifle.rotation = SLUNG_ROT


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
	_build_rifle()


# --- Bone helpers -----------------------------------------------------------

## Direct slerp toward a pose. The legs use this: a stride has to hit its
## contact frame on time, and a spring that overshoots a knee looks broken.
func _pose(bone: int, euler: Vector3, k: float) -> void:
	var target := Quaternion.from_euler(euler)
	skel.set_bone_pose_rotation(bone, skel.get_bone_pose_rotation(bone).slerp(target, k))


func _ease(delta: float, rate: float) -> float:
	return 1.0 - exp(-rate * delta)


## Ask a sprung bone to go somewhere. Urgency scales its frequency (a dash is
## snappier than an idle); damp scales its damping (raise it when a state must
## not wobble).
func _want(bone: int, euler: Vector3, urgency := 1.0, damp := 1.0) -> void:
	var s: BoneSpring = _springs[bone]
	s.target = euler
	s.urgency = urgency
	s.damp = damp


## Add onto a target already set this frame. Used by the effects that ride on
## top of whatever the state pose asked for — lean, turn lag, recoil.
func _add(bone: int, euler: Vector3) -> void:
	var s: BoneSpring = _springs[bone]
	s.target += euler


func _apply_springs(delta: float) -> void:
	var steps := clampi(int(ceil(delta * 240.0)), 1, 8)
	for bone: int in _springs:
		var s: BoneSpring = _springs[bone]
		s.step(delta, steps)
		skel.set_bone_pose_rotation(bone, Quaternion.from_euler(s.value))


## Raised cosine, 1.0 at `center` and 0 beyond ±`width`, wrapping around the
## cycle. Events in a stride — heel strike, the knee folding, toe-off — happen
## at a phase and are over; smearing them across a sine is why procedural runs
## look like a metronome.
func _bump(p: float, center: float, width: float) -> float:
	var d := wrapf(p - center, -PI, PI)
	if absf(d) >= width:
		return 0.0
	return 0.5 + 0.5 * cos(d / width * PI)


## Model-space yaw sign that turns his face toward the camera. A dead-profile
## head is a silhouette; a few degrees of turn gives it a face.
func _cam_side() -> float:
	return -float(controller.facing)


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
	_drive_rifle(delta)
	_drive_reactions(delta)
	# Invulnerability flicker: alpha would need a transparent pass on every
	# material, so it blinks visibility instead. Faster and it reads better.
	if controller.is_invulnerable():
		body.visible = fmod(Time.get_ticks_msec() * 0.001, 0.14) < 0.08
	elif not body.visible:
		body.visible = true

	# Death outranks everything, including the rifle. The controller stops
	# ticking its weapon timer the moment he dies, so the raised-rifle blend
	# freezes wherever it was — die mid-burst and without this he holds the
	# firing stance through the entire respawn wait.
	if controller.state == PlayerController.State.DEAD:
		_pose_death(delta)
	elif _weapon_blend > 0.25 and controller.state != PlayerController.State.DASH:
		_pose_rifle(delta)
	elif beauty_pose and controller.state == PlayerController.State.IDLE:
		_pose_beauty(delta)
	else:
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
	_finish(delta)
	if _trace:
		_trace_pose(speed)


func _finish(delta: float) -> void:
	_apply_springs(delta)
	skel.position.y = _hip_y
	# Head stabilisation. The pelvis bobs through a stride; countering ~half of
	# it on the spine keeps the shoulders and head much flatter, which is the
	# single cheapest thing that makes a run read as trained rather than
	# bouncy. Counter all of it and he looks like he is on rails.
	skel.set_bone_pose_position(B.SPINE, _spine_rest + Vector3(0.0, _spine_shift, 0.0))


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


## Everything that decays on its own clock, independent of which pose is
## running: the landing, the full-auto rattle, the turn lag, and the two
## whole-body offsets that most states want at zero.
func _drive_reactions(delta: float) -> void:
	# The knee compression recovers in about a fifth of a second; the weight
	# settle takes three times as long. Two curves, not one — collapsing them
	# is exactly what makes a landing read as a bounce off a trampoline.
	_land = lerpf(_land, 0.0, _ease(delta, 7.5))
	_land_shift = lerpf(_land_shift, 0.0, _ease(delta, 3.0))
	# A quarter of a second. It used to be an eighth, which the slow springs at
	# the top of the chain could not express before it was gone — the head lead
	# has to outlive the yaw flip or nobody sees it.
	_turn_lag = lerpf(_turn_lag, 0.0, _ease(delta, 6.0))
	_shock_side = lerpf(_shock_side, 0.0, _ease(delta, 9.0))
	if controller.state != PlayerController.State.DEAD:
		_death_t = 0.0
	# Only the TARGETS reset here. Smoothing them here as well would mean two
	# lerps pulling in opposite directions every frame, and the equilibrium
	# lands at about half of whatever a pose asked for — which is exactly what
	# was quietly happening to the glide's body pitch. One integration, in
	# _drive_torso, after the pose has had its say.
	_shift_target = 0.0
	_pitch_target = 0.0

	# Full-auto. Each round adds VELOCITY to a light, under-damped spring, so a
	# held trigger builds a rattle and a single tap is one clean jolt. 7 Hz
	# against a 9.5 rps rifle means consecutive rounds land off-phase and the
	# shake never settles into a loop.
	var steps := clampi(int(ceil(delta * 240.0)), 1, 8)
	var h := delta / float(steps)
	var omega := TAU * 7.0
	for _i in steps:
		_shock_vel += (-_shock * omega * omega - _shock_vel * (2.0 * 0.30 * omega)) * h
		_shock += _shock_vel * h
	_shock = clampf(_shock, -1.6, 1.6)
	_shock_vel = clampf(_shock_vel, -90.0, 90.0)


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


func _drive_rifle(delta: float) -> void:
	_weapon_blend = lerpf(_weapon_blend, controller.weapon_blend(),
		_ease(delta, 16.0))
	# Recoil is a spring on the rifle itself, not on the whole body.
	_recoil_vel += (-_recoil * 900.0 - _recoil_vel * 42.0) * delta
	_recoil += _recoil_vel * delta

	var t := _weapon_blend
	# Aim tilts the rifle about X. The muzzle points +Z, and a positive X
	# rotation swings +Z DOWN — so aiming up is a negative rotation. It was
	# positive, which pointed the barrel at the floor while the rounds went up
	# the screen and the arms raised correctly around it.
	var aim_rot := Vector3(-controller.aim() * controller.max_aim_angle, 0.0, 0.0)
	rifle.position = SLUNG_POS.lerp(READY_POS, t) + Vector3(0.0, 0.0, -_recoil * 0.18)
	rifle.rotation = SLUNG_ROT.lerp(READY_ROT + aim_rot, t) + Vector3(-_recoil * 0.9, 0.0, 0.0)


func _drive_torso(delta: float, vx: float, accel: float, grounded: bool) -> void:
	# Weight lean. This is a PITCH, not a roll: the camera looks down the depth
	# axis, so rolling him sideways was tipping him toward the lens where
	# nobody could see it. Accelerating pitches him into the run; braking
	# pitches him back, which is the skid.
	var lean_target := clampf(accel * 0.0026, -0.26, 0.26) + clampf(vx * 0.009, -0.10, 0.10)
	if not grounded:
		lean_target = clampf(vx * 0.012, -0.16, 0.16)
	if controller.is_gliding():
		lean_target *= 0.35
	# The landing weight shift: his mass keeps going forward after his feet
	# stop, then settles back. This outlasts the knee compression on purpose.
	lean_target += _land_shift * 0.13
	_lean = lerpf(_lean, lean_target, _ease(delta, 10.0))
	_body_pitch = lerpf(_body_pitch, _pitch_target, _ease(delta, 7.0))
	_spine_shift = lerpf(_spine_shift, _shift_target, _ease(delta, 18.0))
	# Pivot is the skeleton origin, which sits between his feet — an inverted
	# pendulum about the ankles, which is how a body actually leans.
	skel.rotation.x = _lean * 0.45 + _body_pitch
	skel.rotation.z = 0.0
	# Splitting a third of the lean into the pelvis curves the spine rather
	# than hinging the whole body at the floor.
	_add(B.HIPS, Vector3(_lean * 0.30, 0.0, 0.0))

	# The hit rattle. While the rifle is up _pose_rifle drives this itself and
	# far harder, so this branch is really the flinch from taking a hit.
	if absf(_shock) > 0.002 and _weapon_blend <= 0.25:
		_add(B.SPINE, Vector3(-_shock * 0.07, 0.0, 0.0))
		_add(B.CHEST, Vector3(-_shock * 0.05, _shock_side * 0.05, 0.0))
		_add(B.NECK, Vector3(_shock * 0.06, 0.0, 0.0))
		_add(B.HEAD, Vector3(_shock * 0.04, 0.0, 0.0))

	# The turn. The yaw node has already flipped the hips; the shoulders are
	# handed the OLD direction for a few frames and the head the new one early,
	# so the read is head → hips → shoulders. The chest spring is the slowest
	# thing in the chain, which smears its recovery over another six frames.
	if _turn_lag > 0.001:
		var d := _turn_lag * _turn_dir
		_add(B.SPINE, Vector3(-_turn_lag * 0.20, -d * 0.18, 0.0))
		_add(B.CHEST, Vector3(0.0, -d * 0.62, 0.0))
		_add(B.NECK, Vector3(0.0, d * 0.58, 0.0))
		_add(B.HEAD, Vector3(0.0, d * 0.40, 0.0))
		# Both arms trail, and that does NOT depend on which way he turned: the
		# yaw node has already flipped the model, so his momentum is pointing
		# backwards in the new frame for a few frames either way.
		_add(B.ARM_L, Vector3(_turn_lag * 0.26, 0.0, 0.0))
		_add(B.ARM_R, Vector3(_turn_lag * 0.26, 0.0, 0.0))


# --- Locomotion -------------------------------------------------------------

## Advance the stride by DISTANCE, not by time. The feet stop sliding, the
## cycle stalls the instant he is blocked against a wall, and cadence falls out
## of speed instead of being a second curve to keep in sync with it.
func _advance_cycle(delta: float) -> void:
	_cycle = wrapf(_cycle + absf(controller.velocity.x) / STRIDE * PI * delta, 0.0, TAU)


## One leg, driven off its own phase. The right leg is the same call half a
## cycle later.
##
## The four poses of a run are all in here: CONTACT at p≈1.57 with the leg
## reaching and the toes up, DOWN at p≈2.25 where the knee eats the impact,
## PASSING at p≈PI, and LIFT at p≈4.45 where the ankle drives off and the heel
## snaps up behind him at p≈5.25. The big knee fold and the small one are
## nothing alike, and that asymmetry is most of the read.
func _pose_leg(thigh: int, shin: int, foot: int, p: float, amp: float,
		delta: float, crouch: float) -> void:
	var c := clampf(crouch, 0.0, 1.0)
	# Phase nudge: he is already swinging the leg back at the moment it lands,
	# which is what stops a run looking like someone stepping over puddles.
	var swing := -sin(p + 0.18) * amp
	var fold := amp * 1.70 * _bump(p, 5.25, 1.50) + amp * 0.40 * _bump(p, 2.25, 1.15)
	# The ankle scales with how hard he is running: a walk rolls through the
	# foot, a sprint snaps it. Unscaled, a slow walk looked like tiptoeing.
	var drive := lerpf(0.55, 1.0, clampf(amp / 0.98, 0.0, 1.0))
	var ankle := (-0.32 * _bump(p, 1.30, 0.95) + 0.46 * _bump(p, 4.45, 0.85)) * drive

	# A landing overrides the stride: both legs collapse into the same
	# two-footed compression, because nobody lands mid-stride and keeps going.
	swing = lerpf(swing, -0.46, c * 0.75)
	fold = lerpf(fold, 1.00, c * 0.80)
	ankle = lerpf(ankle, -0.26, c * 0.70)

	# Descending rates down the leg: the knee trails the hip, the ankle trails
	# the knee. Cheap overlap, and it keeps the foot from popping on contact.
	_pose(thigh, Vector3(swing, 0.0, 0.0), _ease(delta, 30.0))
	_pose(shin, Vector3(fold, 0.0, 0.0), _ease(delta, 23.0))
	_pose(foot, Vector3(ankle, 0.0, 0.0), _ease(delta, 17.0))


func _pose_run(delta: float, speed: float) -> void:
	_advance_cycle(delta)
	var p := _cycle
	# The stride is a fixed distance, so the amplitude cannot start tiny or the
	# feet skate at walking pace — where, being slow, skating is most visible.
	var amp := lerpf(0.42, 0.98, speed)

	_pose_leg(B.THIGH_L, B.SHIN_L, B.FOOT_L, p, amp, delta, _land)
	_pose_leg(B.THIGH_R, B.SHIN_R, B.FOOT_R, p + PI, amp, delta, _land)

	# Pelvis and ribcage fight each other. In profile this reads as the
	# shoulders narrowing and widening rather than turning, which is exactly
	# what a real run does to a silhouette.
	var s := sin(p)
	# Nine degrees of pelvis at a sprint. It reads as more than that because
	# the ribcage takes it back nearly one and a half times over, and the
	# shoulder line ends up twelve degrees the other way. Rotating the pelvis
	# harder is tempting and wrong: it hangs off the hips, so it swings both
	# legs sideways with it.
	var twist := s * lerpf(0.04, 0.16, speed)
	var lean := 0.04 + speed * 0.13

	_want(B.HIPS, Vector3(0.02 + _land * 0.12, twist, 0.0))
	_want(B.SPINE, Vector3(lean + _land * 0.34, -twist * 0.90, 0.0))
	_want(B.CHEST, Vector3(0.03, -twist * 1.40, 0.0))
	# Neck and head hand the twist back, so his face stays pointed down the
	# level while the ribcage swings under it. Same for the pitch: the chest
	# leans in, the neck lifts the chin out of it, and his eye line stays on
	# the horizon.
	_want(B.NECK, Vector3(-lean * 0.85 - _land * 0.34, twist * 1.00, 0.0))
	_want(B.HEAD, Vector3(-0.02, twist * 0.30 + _cam_side() * 0.05, 0.0))

	# Arms. Contralateral — left leg forward, RIGHT arm forward. The old cycle
	# swung them on the same side, which reads as wrong long before anyone can
	# say why.
	var sw := sin(p + 0.18)
	var f_l := maxf(-sw, 0.0)          # how far the left arm is forward, 0..1
	var f_r := maxf(sw, 0.0)
	var arm := amp * 0.78
	var flex := lerpf(0.45, 1.0, speed)
	# The Z term crosses each hand slightly toward his centre line as it comes
	# forward. It is a depth motion, so it mostly buys separation between the
	# near hand and the white thobe behind it — but a straight, flat arm swing
	# is the most robotic thing a run cycle can do.
	_want(B.ARM_L, Vector3(sw * arm, -0.10 * f_l, 0.15 + 0.26 * f_l))
	_want(B.ARM_R, Vector3(-sw * arm, 0.10 * f_r, -0.15 - 0.26 * f_r))
	_want(B.FOREARM_L, Vector3(-0.40 - 0.80 * f_l * flex, 0.0, 0.0))
	_want(B.FOREARM_R, Vector3(-0.40 - 0.80 * f_r * flex, 0.0, 0.0))
	_want(B.HAND_L, Vector3(-0.12 - 0.20 * f_l, 0.0, 0.10))
	_want(B.HAND_R, Vector3(-0.12 - 0.20 * f_r, 0.0, -0.10))
	# Shoulders protract with the arm that is travelling forward.
	_want(B.SHOULDER_L, Vector3(0.0, 0.14 * f_l - 0.06 * f_r, 0.07))
	_want(B.SHOULDER_R, Vector3(0.0, -0.14 * f_r + 0.06 * f_l, -0.07))

	# Hips are lowest just after a foot lands and highest in the float between
	# strides — one bob per step, so the period is half the cycle. The +0.45
	# re-centres it: without it the pelvis only ever travels DOWN from standing
	# height, which loses the float and drives the planted foot a couple of
	# centimetres into the floor at full compression.
	var bob := -(0.5 + 0.5 * cos(2.0 * (p - 2.25)))
	var bob_y := (bob + 0.45) * lerpf(0.020, 0.085, speed)
	_hip_y = lerpf(_hip_y, bob_y - _land * 0.10, _ease(delta, 26.0))
	_shift_target = -bob_y * 0.45


func _pose_idle(delta: float) -> void:
	_breath += delta * 1.5
	var b := sin(_breath)
	var u := 0.85                        # idle is slow; nothing here may snap

	# Weight shift. He stands on one leg for four to six seconds, then pours
	# himself onto the other over about a second. In profile the read is the
	# free knee softening and the heel lifting; the pelvis roll underneath is
	# for the perspective at the screen edges and for beauty frames.
	_weight_timer -= delta
	if _weight_timer <= 0.0:
		_weight_target = -_weight_target
		_weight_timer = randf_range(3.6, 6.4)
	var shifting := absf(_weight_target - _weight)
	_weight = lerpf(_weight, _weight_target, _ease(delta, 0.85))
	var w := _weight
	var free_l := clampf(-w, 0.0, 1.0)   # 1 when his weight is on the right leg
	var free_r := clampf(w, 0.0, 1.0)

	# The stance is deliberately asymmetric: in a dead profile two identical
	# legs occupy the same dozen pixels and he reads as one-legged. The fore/
	# aft offset is FIXED for the same reason — if the weight shift moved it,
	# the legs would line up exactly at the halfway point. What the shift
	# moves is the knee and the heel.
	var kt := _ease(delta, 6.0)
	var ks := _ease(delta, 4.5)
	_pose(B.THIGH_L, Vector3(-0.10, 0.0, 0.0), kt)
	_pose(B.THIGH_R, Vector3(0.09, 0.0, 0.0), kt)
	_pose(B.SHIN_L, Vector3(0.05 + free_l * 0.26, 0.0, 0.0), ks)
	_pose(B.SHIN_R, Vector3(0.04 + free_r * 0.26, 0.0, 0.0), ks)
	_pose(B.FOOT_L, Vector3(0.03 + free_l * 0.17, 0.0, 0.0), ks)
	_pose(B.FOOT_R, Vector3(-0.03 + free_r * 0.17, 0.0, 0.0), ks)

	_want(B.HIPS, Vector3(0.01 + _land * 0.12, w * 0.05, -w * 0.055), u)
	_want(B.SPINE, Vector3(-0.01 + b * 0.022 + _land * 0.34, -w * 0.03, w * 0.045), u)
	_want(B.CHEST, Vector3(b * 0.030, 0.0, w * 0.035), u)

	# Hands carried forward of the body: in profile the cuffs have to clear the
	# robe or the arms may as well not exist. The arm over the loaded leg hangs
	# a little further back — asymmetry is the cheapest life in the pose.
	_want(B.ARM_L, Vector3(-0.20 + b * 0.05 + w * 0.06, 0.0, 0.18), u)
	_want(B.ARM_R, Vector3(-0.14 - b * 0.05 - w * 0.06, 0.0, -0.18), u)
	_want(B.FOREARM_L, Vector3(-0.52 - b * 0.05, 0.0, 0.0), u)
	_want(B.FOREARM_R, Vector3(-0.46 + b * 0.05, 0.0, 0.0), u)
	_want(B.HAND_L, Vector3(-0.10, 0.0, 0.08), u)
	_want(B.HAND_R, Vector3(-0.08, 0.0, -0.08), u)
	# The shoulder line tilts AGAINST the pelvis — same sign on both bones,
	# because +Z drops the left shoulder and lifts the right one.
	_want(B.SHOULDER_L, Vector3(0.0, 0.0, 0.06 + b * 0.03 + w * 0.025), u)
	_want(B.SHOULDER_R, Vector3(0.0, 0.0, -0.06 - b * 0.03 + w * 0.025), u)

	# He does not stand still. Every couple of seconds he looks at something
	# and HOLDS it — a head that drifts straight back reads as a twitch, not as
	# attention. The look is biased toward the camera, because a profile with
	# no face in it is just a silhouette and he is the most expensive asset in
	# the frame.
	_look_hold -= delta
	if _look_hold <= 0.0:
		if _look_target.length() > 0.05:
			_look_target = Vector2.ZERO
			_look_hold = randf_range(2.2, 4.5)
		else:
			_look_target = Vector2(randf_range(0.14, 0.44) * _cam_side(),
				randf_range(-0.10, 0.16))
			_look_hold = randf_range(1.0, 1.9)
	_look = _look.lerp(_look_target, _ease(delta, 2.6))
	_want(B.NECK, Vector3(b * 0.02 + _look.y * 0.60 - _land * 0.34, _look.x * 0.62, 0.0), u)
	_want(B.HEAD, Vector3(-0.03 + b * 0.02 + _look.y * 0.40, _look.x * 0.38, -w * 0.03), u * 0.9)
	# The chest follows the head a beat later. Two hundredths of a radian, and
	# it is the difference between a man looking at something and a head on a
	# swivel.
	_add(B.CHEST, Vector3(0.0, _look.x * 0.12, 0.0))

	# He sinks slightly while the weight crosses between his feet.
	_hip_y = lerpf(_hip_y, b * 0.010 - shifting * 0.013 - _land * 0.10, _ease(delta, 6.0))
	# Leave the stride parked just before a contact so the first step out of
	# idle is a reach, not a mid-air passing pose.
	_cycle = 1.05


func _pose_air(delta: float) -> void:
	var vy := controller.velocity.y
	# Three shapes blended by vertical speed: drive off the ground, hang at the
	# apex, reach for the floor on the way down. The apex shape is what makes a
	# jump feel like it has a top.
	var rise := clampf(vy / 9.0, 0.0, 1.0)
	var fall := clampf(-vy / 20.0, 0.0, 1.0)
	var kt := _ease(delta, 14.0)
	var ks := _ease(delta, 11.0)
	var kf := _ease(delta, 9.0)
	var flutter := sin(_breath * 3.4) * 0.05
	_breath += delta * 2.0

	# Legs split: the lead knee comes up, the trailing leg extends. Both tuck
	# on the way up, both open on the way down.
	_pose(B.THIGH_L, Vector3(-0.34 - rise * 0.55 - fall * 0.16, 0.0, 0.0), kt)
	_pose(B.THIGH_R, Vector3(-0.06 - rise * 0.10 + fall * 0.46, 0.0, 0.0), kt)
	_pose(B.SHIN_L, Vector3(0.46 + rise * 0.62 - fall * 0.22, 0.0, 0.0), ks)
	_pose(B.SHIN_R, Vector3(0.34 + rise * 0.30 + fall * 0.26, 0.0, 0.0), ks)
	_pose(B.FOOT_L, Vector3(-0.08 + rise * 0.26 - fall * 0.20, 0.0, 0.0), kf)
	_pose(B.FOOT_R, Vector3(0.10 + rise * 0.22 + fall * 0.06, 0.0, 0.0), kf)

	# Arms trail behind the launch, then swing forward and open as he falls —
	# and never symmetrically. One high, one low.
	# The Z term OPENS as he falls rather than closing: swung forward and
	# crossed in, the two hands end up a few centimetres apart and read as him
	# clasping them. Spread, and the falling silhouette gets wider instead.
	_want(B.ARM_L, Vector3(0.30 + rise * 0.72 - fall * 0.62 + flutter, 0.0, 0.22 - fall * 0.46))
	_want(B.ARM_R, Vector3(0.18 + rise * 0.60 - fall * 0.40 - flutter, 0.0, -0.28 + fall * 0.50))
	_want(B.FOREARM_L, Vector3(-0.42 - rise * 0.24, 0.0, 0.0))
	_want(B.FOREARM_R, Vector3(-0.34 - rise * 0.18, 0.0, 0.0))
	_want(B.HAND_L, Vector3(-0.14, 0.0, 0.12))
	_want(B.HAND_R, Vector3(-0.10, 0.0, -0.12))
	_want(B.SHOULDER_L, Vector3(0.0, 0.0, 0.10 + rise * 0.10))
	_want(B.SHOULDER_R, Vector3(0.0, 0.0, -0.10 - rise * 0.10))

	_want(B.HIPS, Vector3(0.02 + fall * 0.06, 0.0, 0.0))
	_want(B.SPINE, Vector3(0.16 * rise - 0.10 * fall, 0.0, 0.0))
	_want(B.CHEST, Vector3(0.02, 0.0, 0.0))
	# Rising he looks up the arc; falling he finds the floor he is going to
	# land on. Positive pitch on the neck is chin-down.
	_want(B.NECK, Vector3(-0.16 * rise + 0.20 * fall, _cam_side() * 0.10, 0.0))
	_want(B.HEAD, Vector3(-0.08 * rise + 0.10 * fall, _cam_side() * 0.12, 0.0))

	# Mid-flourish he pulls everything in: a spin only reads if the silhouette
	# gets tighter while it happens.
	if _spin > 0.05:
		var sp := clampf(_spin / TAU, 0.0, 1.0)
		_add(B.ARM_L, Vector3(-0.55 * sp, 0.0, 0.30 * sp))
		_add(B.ARM_R, Vector3(-0.55 * sp, 0.0, -0.30 * sp))
		_add(B.FOREARM_L, Vector3(-0.70 * sp, 0.0, 0.0))
		_add(B.FOREARM_R, Vector3(-0.70 * sp, 0.0, 0.0))
		_add(B.SPINE, Vector3(0.20 * sp, 0.0, 0.0))

	_hip_y = lerpf(_hip_y, 0.0, kt)


## The glide. The thobe is a wing, and this is the signature move — it has to
## be unmistakable at any size on screen, and it must never be confused with a
## fall. Arms swept back, chest open, legs trailing, the whole body pitched a
## few degrees into the airflow.
func _pose_glide(delta: float) -> void:
	var t := controller.glide_blend()
	_breath += delta * 2.2
	# Two flutter rates on the arms: the fast one is the cloth snapping, the
	# slow one is him actually riding the air. One rate alone reads as a loop.
	var snap := sin(_breath * 5.6) * 0.07 * t
	var ride := sin(_breath * 1.9 + 0.7) * 0.09 * t
	var kt := _ease(delta, 9.0)
	var ks := _ease(delta, 7.0)

	# Arms out and BACK. This is the whole pose: on a bone that hangs down, a
	# positive X rotation sweeps it behind him, so 1.15 rad puts his arms at
	# roughly sixty degrees back — a diver, with the sleeves as the trailing
	# edge. The old glide left them hanging straight down, which from a side
	# camera is indistinguishable from falling.
	var sweep := 1.15 * t
	_want(B.ARM_L, Vector3(sweep + snap + ride, -0.14 * t, -0.34 * t + 0.10), 0.9, 0.85)
	_want(B.ARM_R, Vector3(sweep - snap - ride, 0.14 * t, 0.34 * t - 0.10), 0.9, 0.85)
	# Elbows nearly straight — a bent elbow collapses the wingspan.
	_want(B.FOREARM_L, Vector3(-0.14 - snap * 0.6, 0.0, 0.0), 0.9, 0.85)
	_want(B.FOREARM_R, Vector3(-0.14 + snap * 0.6, 0.0, 0.0), 0.9, 0.85)
	_want(B.HAND_L, Vector3(-0.18 * t, 0.0, -0.16 * t), 0.9, 0.8)
	_want(B.HAND_R, Vector3(-0.18 * t, 0.0, 0.16 * t), 0.9, 0.8)
	# Shoulders roll back and open the chest. Retraction, not elevation.
	_want(B.SHOULDER_L, Vector3(0.0, -0.26 * t, -0.10 * t), 0.9)
	_want(B.SHOULDER_R, Vector3(0.0, 0.26 * t, 0.10 * t), 0.9)

	# Legs trail, knees soft, toes pointed, and they scissor slowly — he is
	# steering, not hanging.
	var scissor := sin(_breath * 1.4) * 0.13 * t
	_pose(B.THIGH_L, Vector3(0.30 * t + scissor, 0.0, 0.0), kt)
	_pose(B.THIGH_R, Vector3(0.34 * t - scissor, 0.0, 0.0), kt)
	_pose(B.SHIN_L, Vector3(0.34 * t - scissor * 0.5, 0.0, 0.0), ks)
	_pose(B.SHIN_R, Vector3(0.26 * t + scissor * 0.5, 0.0, 0.0), ks)
	_pose(B.FOOT_L, Vector3(0.34 * t, 0.0, 0.0), ks)
	_pose(B.FOOT_R, Vector3(0.30 * t, 0.0, 0.0), ks)

	# Chest open against trailing hips: a shallow C through the spine, the
	# shape every flight pose in animation is built on.
	_want(B.HIPS, Vector3(0.10 * t, 0.0, 0.0), 0.9)
	_want(B.SPINE, Vector3(-0.26 * t, 0.0, 0.0), 0.9, 0.9)
	_want(B.CHEST, Vector3(-0.12 * t, 0.0, 0.0), 0.9, 0.9)
	# He looks where he is going — down the glide path, and turned toward the
	# lens so the signature move actually shows his face.
	_want(B.NECK, Vector3(0.20 * t, _cam_side() * 0.26 * t, 0.0), 0.95)
	_want(B.HEAD, Vector3(0.10 * t, _cam_side() * 0.20 * t, 0.0), 0.95)

	# And the whole body tips into the airflow. Eight degrees is enough to read
	# as flight; past about fifteen he looks like he is falling on his face.
	_pitch_target = 0.15 * t
	_hip_y = lerpf(_hip_y, 0.02 * t, kt)


## Death. Stage keeps him on screen for three quarters of a second before the
## respawn, and an idle breathing loop over that window is the most deflating
## thing a death can do to a player who just lost a life.
##
## Two beats, because a collapse with only one reads as fainting: the hit
## arches him back with his arms flung wide, and a sixth of a second later his
## legs give out and he goes down. The whole thing is over in half a second —
## any longer and the respawn is waiting on the animation.
func _pose_death(delta: float) -> void:
	_death_t += delta
	var hit := clampf(1.0 - _death_t / 0.22, 0.0, 1.0)
	var drop := clampf((_death_t - 0.16) / 0.34, 0.0, 1.0)
	drop = drop * drop * (3.0 - 2.0 * drop)   # eases in, so he accelerates down
	var kt := _ease(delta, 12.0)
	var u := 1.25

	_want(B.HIPS, Vector3(0.10 * hit + 0.30 * drop, 0.0, 0.0), u)
	_want(B.SPINE, Vector3(-0.38 * hit + 0.52 * drop, 0.0, 0.0), u)
	_want(B.CHEST, Vector3(-0.20 * hit + 0.26 * drop, 0.0, 0.0), u)
	# Head back on the hit, chin to the chest as he goes. The head spring is
	# the slowest in the rig, so it arrives late on both beats without being
	# asked — which is exactly the read.
	_want(B.NECK, Vector3(-0.34 * hit + 0.48 * drop, _cam_side() * 0.14, 0.0), u)
	_want(B.HEAD, Vector3(-0.22 * hit + 0.34 * drop, _cam_side() * 0.10, 0.0), u)
	_want(B.SHOULDER_L, Vector3(0.0, 0.0, -0.20 * hit + 0.16 * drop), u)
	_want(B.SHOULDER_R, Vector3(0.0, 0.0, 0.20 * hit - 0.16 * drop), u)
	_want(B.ARM_L, Vector3(-1.30 * hit + 0.18 * drop, 0.0, -0.46 * hit + 0.20 * drop), u)
	_want(B.ARM_R, Vector3(-1.10 * hit + 0.14 * drop, 0.0, 0.46 * hit - 0.20 * drop), u)
	_want(B.FOREARM_L, Vector3(-0.24 - 0.70 * drop, 0.0, 0.0), u)
	_want(B.FOREARM_R, Vector3(-0.20 - 0.60 * drop, 0.0, 0.0), u)
	_want(B.HAND_L, Vector3(-0.20 * drop, 0.0, 0.0), u)
	_want(B.HAND_R, Vector3(-0.20 * drop, 0.0, 0.0), u)

	# The legs buckle unevenly — a symmetrical collapse looks like a puppet
	# with its strings cut on both sides at once.
	_pose(B.THIGH_L, Vector3(-0.22 - 1.05 * drop, 0.0, 0.0), kt)
	_pose(B.THIGH_R, Vector3(-0.06 - 0.78 * drop, 0.0, 0.0), kt)
	_pose(B.SHIN_L, Vector3(0.30 + 1.45 * drop, 0.0, 0.0), kt)
	_pose(B.SHIN_R, Vector3(0.22 + 1.25 * drop, 0.0, 0.0), kt)
	_pose(B.FOOT_L, Vector3(0.10 + 0.30 * drop, 0.0, 0.0), kt)
	_pose(B.FOOT_R, Vector3(0.06 + 0.22 * drop, 0.0, 0.0), kt)

	# He rises a couple of centimetres on the hit before he loses the floor.
	_hip_y = lerpf(_hip_y, 0.03 * hit - 0.26 * drop, _ease(delta, 14.0))
	_cycle = 1.05


func _pose_dash(delta: float) -> void:
	var kt := _ease(delta, 26.0)
	var u := 1.9        # a dash has to be *there*, so the springs run hot
	var d := 1.25       # and tight, or the arms wobble out the far side

	# Pitched forward over a long split stride, arms swept back, head up and
	# looking down the level. The old dash leaned him backwards with his arms
	# thrown forward, which is a swan dive, not a burst.
	_want(B.HIPS, Vector3(0.10, 0.0, 0.0), u, d)
	_want(B.SPINE, Vector3(0.34, 0.0, 0.0), u, d)
	_want(B.CHEST, Vector3(0.10, 0.0, 0.0), u, d)
	_want(B.NECK, Vector3(-0.34, _cam_side() * 0.12, 0.0), u, d)
	_want(B.HEAD, Vector3(-0.22, _cam_side() * 0.14, 0.0), u, d)
	_want(B.SHOULDER_L, Vector3(0.0, -0.16, 0.12), u, d)
	_want(B.SHOULDER_R, Vector3(0.0, 0.16, -0.12), u, d)
	_want(B.ARM_L, Vector3(1.26, -0.10, -0.16), u, d)
	_want(B.ARM_R, Vector3(1.08, 0.10, 0.16), u, d)
	_want(B.FOREARM_L, Vector3(-0.34, 0.0, 0.0), u, d)
	_want(B.FOREARM_R, Vector3(-0.50, 0.0, 0.0), u, d)
	_want(B.HAND_L, Vector3(-0.20, 0.0, 0.0), u, d)
	_want(B.HAND_R, Vector3(-0.20, 0.0, 0.0), u, d)

	_pose(B.THIGH_L, Vector3(-0.66, 0.0, 0.0), kt)
	_pose(B.THIGH_R, Vector3(0.52, 0.0, 0.0), kt)
	_pose(B.SHIN_L, Vector3(0.74, 0.0, 0.0), kt)
	_pose(B.SHIN_R, Vector3(0.24, 0.0, 0.0), kt)
	_pose(B.FOOT_L, Vector3(-0.18, 0.0, 0.0), kt)
	_pose(B.FOOT_R, Vector3(0.42, 0.0, 0.0), kt)
	_hip_y = lerpf(_hip_y, -0.05, kt)


## Rifle up: both hands on it, shoulders squared, head over the sights. The
## legs keep whatever the locomotion state was doing, so he runs and guns.
func _pose_rifle(delta: float) -> void:
	var speed := controller.speed_ratio()
	var grounded := controller.is_on_floor()
	var aim := controller.aim() * controller.max_aim_angle
	# The aim itself is a cursor and must be immediate; the shake is what the
	# springs are for.
	var u := 1.9
	var sh := _shock
	var side := _shock_side

	# Arms follow the aim so the rifle stays in his hands. The right arm takes
	# most of the kick — it is the one on the grip.
	_want(B.ARM_R, Vector3(-1.35 - aim * 0.85 - sh * 0.15, 0.0, -0.30 + side * 0.06), u)
	_want(B.FOREARM_R, Vector3(-0.62 + aim * 0.18 - sh * 0.10, 0.0, 0.0), u)
	_want(B.ARM_L, Vector3(-1.05 - aim * 0.95 - sh * 0.09, 0.0, 0.46 + side * 0.04), u)
	_want(B.FOREARM_L, Vector3(-0.78 + aim * 0.22 - sh * 0.07, 0.0, 0.0), u)
	_want(B.HAND_R, Vector3(-0.10 - sh * 0.12, 0.0, 0.0), u)
	_want(B.HAND_L, Vector3(-0.08 - sh * 0.10, 0.0, 0.0), u)
	_want(B.SHOULDER_R, Vector3(0.0, sh * 0.10, -0.22 - sh * 0.14), u)
	_want(B.SHOULDER_L, Vector3(0.0, -sh * 0.06, 0.26 - sh * 0.08), u)

	# The rattle goes through the trunk, not just the arms: hips absorb a
	# little, the spine takes the most, and the chest twists off-axis so a long
	# burst never shakes along one clean line.
	_want(B.HIPS, Vector3(0.04 - sh * 0.05 + _land * 0.12, side * 0.05, 0.0), 1.4)
	_want(B.SPINE, Vector3(-0.10 - sh * 0.22 + _land * 0.30, side * 0.09, 0.0), 1.5)
	_want(B.CHEST, Vector3(-0.05 - sh * 0.12, side * 0.07, 0.0), 1.5)
	# The head is the one thing that does NOT shake. The neck rides the trunk
	# and the head counter-rotates against it, so his eye line stays welded to
	# the sights while everything under it rattles. Two numbers, and it is the
	# difference between a shooter and a man being electrocuted.
	var neck_shock := sh * 0.20
	_want(B.NECK, Vector3(0.10 - aim * 0.30 + neck_shock, side * 0.08, 0.0), 1.7)
	_want(B.HEAD, Vector3(0.05 - aim * 0.24 - neck_shock * 0.85,
		side * 0.04 + _cam_side() * 0.10, 0.0), 2.3)

	if grounded and speed > 0.08:
		_advance_cycle(delta)
		var amp := lerpf(0.28, 0.72, speed)   # shorter stride with the rifle up
		_pose_leg(B.THIGH_L, B.SHIN_L, B.FOOT_L, _cycle, amp, delta, _land)
		_pose_leg(B.THIGH_R, B.SHIN_R, B.FOOT_R, _cycle + PI, amp, delta, _land)
		var bob := -(0.5 + 0.5 * cos(2.0 * (_cycle - 2.25)))
		var bob_y := (bob + 0.45) * lerpf(0.016, 0.055, speed)
		_hip_y = lerpf(_hip_y, bob_y - _land * 0.10, _ease(delta, 26.0))
		# Sights ride the head, so the rifle stance stabilises harder than the
		# empty-handed run does.
		_shift_target = -bob_y * 0.60
	elif grounded:
		# Braced: feet apart, weight back, front knee soft. The recoil pushes
		# him down into the stance instead of moving his feet.
		var k := _ease(delta, 14.0)
		_pose(B.THIGH_L, Vector3(-0.24 - sh * 0.05, 0.0, 0.0), k)
		_pose(B.THIGH_R, Vector3(0.22, 0.0, 0.0), k)
		_pose(B.SHIN_L, Vector3(0.30 + sh * 0.08, 0.0, 0.0), k)
		_pose(B.SHIN_R, Vector3(0.14, 0.0, 0.0), k)
		_pose(B.FOOT_L, Vector3(-0.04, 0.0, 0.0), k)
		_pose(B.FOOT_R, Vector3(0.10, 0.0, 0.0), k)
		_hip_y = lerpf(_hip_y, -0.035 - sh * 0.012 - _land * 0.10, k)
	else:
		var k := _ease(delta, 12.0)
		_pose(B.THIGH_L, Vector3(-0.32, 0.0, 0.0), k)
		_pose(B.THIGH_R, Vector3(0.20, 0.0, 0.0), k)
		_pose(B.SHIN_L, Vector3(0.46, 0.0, 0.0), k)
		_pose(B.SHIN_R, Vector3(0.32, 0.0, 0.0), k)
		_pose(B.FOOT_L, Vector3(0.10, 0.0, 0.0), k)
		_pose(B.FOOT_R, Vector3(0.16, 0.0, 0.0), k)
		_hip_y = lerpf(_hip_y, 0.0, k)


## An authored stance for beauty frames and the title screen. The default idle
## is a symmetrical standing pose, which is correct for gameplay and is the
## single most amateur thing a marketing frame can contain.
##
## Contrapposto: the weight goes on the back leg, the hip on that side lifts,
## the spine counter-curves, the shoulders tilt against the hips, and the head
## turns past the shoulders. Every one of those is a small number; together
## they are the difference between a character and a mannequin.
##
## It must stay a STILL pose. The springs run slow and over-damped here so they
## settle onto the authored numbers exactly and hold — no overshoot, no drift.
func _pose_beauty(delta: float) -> void:
	_breath += delta * 1.05
	var k := _ease(delta, 5.0)
	var b := sin(_breath)
	var u := 0.75
	var d := 1.35

	# Weight on the back leg (screen-left when he faces right); the front leg
	# is relaxed, knee soft, heel lifted.
	_pose(B.THIGH_L, Vector3(0.10, 0.0, 0.0), k)
	_pose(B.SHIN_L, Vector3(0.02, 0.0, 0.0), k)
	_pose(B.FOOT_L, Vector3(-0.06, 0.0, 0.0), k)
	_pose(B.THIGH_R, Vector3(-0.30, 0.10, 0.0), k)
	_pose(B.SHIN_R, Vector3(0.34, 0.0, 0.0), k)
	_pose(B.FOOT_R, Vector3(-0.22, 0.0, 0.0), k)

	# Hips tilt toward the free leg; the spine takes it back the other way.
	_want(B.HIPS, Vector3(0.0, 0.0, -0.085), u, d)
	_want(B.SPINE, Vector3(-0.045 + b * 0.016, 0.0, 0.070), u, d)
	_want(B.CHEST, Vector3(0.030 + b * 0.022, 0.0, 0.045), u, d)

	# Near arm up on the rail: shoulder back, elbow out, forearm forward so the
	# cuff clears the robe in profile.
	_want(B.ARM_R, Vector3(-0.58 - b * 0.02, 0.0, -0.42), u, d)
	_want(B.FOREARM_R, Vector3(-0.86, 0.0, 0.10), u, d)
	_want(B.HAND_R, Vector3(-0.18, 0.0, 0.0), u, d)
	_want(B.SHOULDER_R, Vector3(0.0, 0.0, -0.16), u, d)

	# Far arm hangs, hand just off the thigh, thumb toward the robe.
	_want(B.ARM_L, Vector3(-0.06 + b * 0.03, 0.0, 0.14), u, d)
	_want(B.FOREARM_L, Vector3(-0.28 - b * 0.03, 0.0, 0.0), u, d)
	_want(B.HAND_L, Vector3(-0.08, 0.0, 0.0), u, d)
	_want(B.SHOULDER_L, Vector3(0.0, 0.0, 0.10), u, d)

	# Head turned past the shoulders and lifted a few degrees: he is looking at
	# the distance he still has to cover, which is the whole point of the shot.
	# The head tilt is the last thing added and the first thing anyone reads:
	# a level head on a tilted body is a passport photo, so it breaks the other
	# way from the shoulders by about a degree.
	_want(B.NECK, Vector3(-0.09 + b * 0.014, 0.21, 0.030), u, d)
	_want(B.HEAD, Vector3(-0.06, 0.13, -0.015), u, d)

	_hip_y = lerpf(_hip_y, -0.035 + b * 0.008, _ease(delta, 4.0))
	_cycle = 1.05
	_look = Vector2.ZERO
	_look_target = Vector2.ZERO


# --- Reactions --------------------------------------------------------------

func _on_landed(impact: float) -> void:
	# Three separate curves off one event, and they have to be three: the mesh
	# squash is over in a tenth of a second, the knees take about a fifth, and
	# the weight keeps shifting forward for most of a second afterwards. That
	# stagger is the whole difference between landing and bouncing.
	_squash = -lerpf(0.09, 0.30, impact)
	_squash_vel = 0.0
	_land = maxf(_land, lerpf(0.28, 1.0, impact))
	_land_shift = maxf(_land_shift, lerpf(0.20, 1.0, impact))
	# A hard landing rings the upper body too — same spring the rifle uses.
	if impact > 0.4:
		_shock_vel += lerpf(0.0, 14.0, inverse_lerp(0.4, 1.0, impact))
	# Land mid-stride and the next step starts from a contact, not from
	# wherever the cycle happened to be when his feet left the ground. A SNAP
	# to the nearer of the two contacts, not a reset — a reset is up to half a
	# cycle of phase and the legs visibly jump to catch it.
	_snap_cycle_to_contact()


func _on_jumped(_from_coyote: bool) -> void:
	_squash = 0.15
	_squash_vel = 0.0
	_cycle = 1.05


func _on_air_jumped(_index: int) -> void:
	_squash = 0.18
	_squash_vel = 0.0
	_spin = TAU


func _on_dash_started(charged: bool) -> void:
	_squash = 0.10 if charged else 0.06
	_squash_vel = 0.0


func _on_hit(_from: Vector3) -> void:
	_squash = -0.22
	_squash_vel = 0.0
	_shock_vel += 30.0
	_shock_side = randf_range(-1.0, 1.0)


func _on_fired() -> void:
	_recoil = 1.0
	_recoil_vel = 0.0
	_squash = maxf(_squash, 0.04)
	# An impulse, not a snapshot: rounds stack, so a held trigger rattles and a
	# single tap is one clean jolt. 40 is about one unit of shake per round.
	_shock_vel += 40.0
	# Every round shakes him off a slightly different axis. Without this, a
	# three-second burst is the same frame 28 times.
	_shock_side = clampf(_shock_side + randf_range(-0.9, 0.9), -1.2, 1.2)


func _on_turned(dir: int) -> void:
	_turn_lag = 1.0
	_turn_dir = float(dir)
	# A turn is a plant: he loads the outside foot before he goes the other
	# way, and the stride picks up from the nearest contact. Only on the
	# ground — in the air there is nothing to plant against, and stealing the
	# jump's stretch for a compression there reads as a hitch.
	if controller.is_on_floor():
		_squash = minf(_squash, -0.05)
	_snap_cycle_to_contact()


## Both contacts in the cycle are at p = PI/2 and p = 3PI/2, so wrapping the
## error over a half cycle always lands on the nearer one.
func _snap_cycle_to_contact() -> void:
	_cycle = wrapf(_cycle + wrapf(PI * 0.5 - _cycle, -PI * 0.5, PI * 0.5), 0.0, TAU)


## The controller owns the footstep beat — it fires one every STRIDE metres.
## Nudging the cycle toward the nearest contact keeps the foot landing on its
## own sound through acceleration, slopes and anything else that drifts the
## two apart. A third of the error per step is enough to stay locked and small
## enough that nobody sees the correction.
func _on_footstep(_ratio: float) -> void:
	_cycle = wrapf(_cycle + wrapf(PI * 0.5 - _cycle, -PI * 0.5, PI * 0.5) * 0.35, 0.0, TAU)


# --- Diagnostics ------------------------------------------------------------

## Pose trace, behind `--rig-debug`, in the same spirit as `--debug-surfaces`
## above.
##
## A capture needs a GPU and two minutes; this needs neither, and the numbers
## answer the questions that actually go wrong in a procedural rig — is the
## arm swing contralateral (hand z opposite foot z), does the head hold still
## while the pelvis bobs (headY range against hipY range), are the glide's
## hands behind him, how much does the planted foot slide (foot z travel
## against STRIDE). Run it as:
##
##   godot --path . --headless --fixed-fps 60 -- --capture \
##     --level=res://levels/greybox/Greybox.tscn --input=demo --frames=300 \
##     --shots=999999 --rig-debug
##
## --shots=999999 matters: headless never reaches frame_post_draw, so a due
## screenshot blocks the capture loop forever and the scripted input never
## runs. Ask for a frame that never arrives and it streams cleanly.
func _trace_pose(speed: float) -> void:
	_trace_frame += 1
	if _trace_frame % 6 != 0:
		return
	var at := func(bone: int) -> Vector3:
		return skel.get_bone_global_pose(bone).origin
	var hips: Vector3 = at.call(B.HIPS)
	var hand_l: Vector3 = at.call(B.HAND_L)
	var hand_r: Vector3 = at.call(B.HAND_R)
	var foot_l: Vector3 = at.call(B.FOOT_L)
	var foot_r: Vector3 = at.call(B.FOOT_R)
	print("RIG f=%d st=%s sp=%.2f cyc=%.2f | headY=%.3f | handL(z=%.2f,y=%.2f) handR(z=%.2f,y=%.2f) | footL(z=%.2f,y=%.2f) footR(z=%.2f,y=%.2f) | pitch=%.2f hipY=%.3f" % [
		_trace_frame, PlayerController.State.keys()[controller.state], speed, _cycle,
		(at.call(B.HEAD) as Vector3).y + _hip_y,
		hand_l.z, hand_l.y - hips.y, hand_r.z, hand_r.y - hips.y,
		foot_l.z, foot_l.y, foot_r.z, foot_r.y,
		skel.rotation.x, _hip_y])
