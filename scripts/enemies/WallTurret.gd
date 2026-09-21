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
var _lens: MeshInstance3D
var _lens_mat: StandardMaterial3D
var _lens_light: OmniLight3D
var _muzzle: Marker3D
var _player: Node3D
var _aim := 0.0


func _setup() -> void:
	max_health = 4.0
	health = max_health
	contact_damage = 0.0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
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

	var housing := MaterialLab.chrome(Color(0.125, 0.122, 0.128), 0.55)
	housing.metallic = 0.6
	var hazard := MaterialLab.cloth(Color(0.86, 0.62, 0.10), 0.7)

	# Wall bracket: it has to look bolted to something.
	var plate := MeshInstance3D.new()
	plate.name = "Bracket"
	var pb := BoxMesh.new()
	pb.size = Vector3(0.22, 0.78, 0.78)
	plate.mesh = pb
	plate.material_override = housing
	plate.position = Vector3(0.30, 0.0, 0.0)
	root.add_child(plate)

	_yoke = Node3D.new()
	_yoke.name = "Yoke"
	root.add_child(_yoke)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var bm := SphereMesh.new()
	bm.radius = 0.28
	bm.height = 0.50
	bm.radial_segments = 14
	bm.rings = 7
	body.mesh = bm
	body.material_override = housing
	_yoke.add_child(body)

	# Hazard band: the one saturated colour on it, so it reads as a machine
	# that is meant to be dangerous rather than as another lump of grey.
	var band := MeshInstance3D.new()
	band.name = "Band"
	var bnd := TorusMesh.new()
	bnd.inner_radius = 0.235
	bnd.outer_radius = 0.285
	bnd.rings = 16
	bnd.ring_segments = 6
	band.mesh = bnd
	band.material_override = hazard
	band.rotation_degrees = Vector3(0, 0, 90)
	_yoke.add_child(band)

	# Twin barrels, because one barrel reads as a pipe.
	for i in 2:
		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.055
		cyl.height = 0.62
		cyl.radial_segments = 8
		barrel.mesh = cyl
		barrel.material_override = housing
		barrel.position = Vector3(-0.34, -0.09 + i * 0.18, 0.0)
		barrel.rotation_degrees = Vector3(0, 0, 90)
		_yoke.add_child(barrel)

	_lens = MeshInstance3D.new()
	_lens.name = "Lens"
	var lm := SphereMesh.new()
	lm.radius = 0.11
	lm.height = 0.18
	lm.radial_segments = 10
	lm.rings = 5
	_lens.mesh = lm
	_lens_mat = MaterialLab.emissive(Color(1.0, 0.38, 0.22), 1.2)
	_lens.material_override = _lens_mat
	_lens.position = Vector3(-0.22, 0.0, 0.0)
	_yoke.add_child(_lens)

	_lens_light = OmniLight3D.new()
	_lens_light.light_color = Color(1.0, 0.40, 0.22)
	_lens_light.light_energy = 1.2
	_lens_light.omni_range = 3.0
	_lens_light.shadow_enabled = false
	_lens.add_child(_lens_light)

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
			_set_lens(1.0, Color(1.0, 0.40, 0.22))
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
			_set_lens(lerpf(1.6, 5.0, t) * (0.6 + 0.4 * pulse),
				Color(1.0, 0.30, 0.16).lerp(Color(1.0, 0.92, 0.72), t))
			if not in_range:
				_mode = Mode.SWEEP
				_timer = 0.0
			elif _timer >= lock_time:
				_mode = Mode.FIRE
				_timer = 0.0
				_shots = 0
		Mode.FIRE:
			_set_lens(5.5, Color(1.0, 0.86, 0.60))
			if _timer >= burst_gap:
				_timer = 0.0
				_fire()
				_shots += 1
				if _shots >= burst:
					_mode = Mode.COOL
		Mode.COOL:
			_set_lens(lerpf(4.0, 1.0, clampf(_timer / cooldown, 0.0, 1.0)),
				Color(0.55, 0.32, 0.26))
			if _timer >= cooldown:
				_mode = Mode.SWEEP
				_timer = 0.0

	_yoke.rotation.z = _aim


func _set_lens(energy: float, tint: Color) -> void:
	_lens_mat.emission = tint
	_lens_mat.emission_energy_multiplier = energy
	_lens_mat.albedo_color = tint
	_lens_light.light_color = tint
	_lens_light.light_energy = energy * 0.8


func _fire() -> void:
	var dir := Vector3(-cos(_aim), sin(_aim), 0.0)
	var root := get_tree().current_scene
	if root == null:
		return
	Bolt.spawn(root, _muzzle.global_position + dir * 0.2, dir, muzzle_speed,
		Color(1.0, 0.50, 0.22))
	Audio.play("gunshot", global_position, -12.0, randf_range(0.7, 0.8))
	# A short kick back into the bracket, so firing costs it something.
	_yoke.position = dir * -0.06
	var tw := create_tween()
	tw.tween_property(_yoke, "position", Vector3.ZERO, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
