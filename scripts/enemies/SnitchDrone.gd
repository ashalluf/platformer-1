class_name SnitchDrone extends Enemy
## SNITCH — a hovering camera drone on a patrol beat.
##
## The first enemy the player meets, so its whole job is to teach the two
## contracts: enemies telegraph, and enemies pop. It bobs along a fixed span,
## sweeps a light cone, and when it sees the player it stiffens, brightens and
## charges after a visible wind-up. Two rounds kill it.

@export var patrol_span := 5.0
@export var patrol_speed := 2.0
@export var sight_range := 9.0
@export var alert_time := 0.55
@export var charge_speed := 9.0
@export var hover_bob := 0.18

enum Mode { PATROL, ALERT, CHARGE, RECOVER }

var _mode: Mode = Mode.PATROL
var _origin: Vector3
var _timer := 0.0
var _bob := 0.0
var _eye: OmniLight3D
var _eye_mesh: MeshInstance3D
var _rotor: Node3D
var _player: Node3D


func _setup() -> void:
	max_health = 2.0
	health = max_health
	_origin = global_position
	_bob = fposmod(global_position.x, TAU)
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

	var shell := MaterialLab.painted_metal(Color(0.105, 0.115, 0.130), 0.9)
	var trim := MaterialLab.painted_metal(Color(0.86, 0.62, 0.10), 0.4)
	var lens := MaterialLab.emissive(Color(1.0, 0.30, 0.16), 5.0)

	var body := SphereMesh.new()
	body.radius = 0.33
	body.height = 0.52
	body.radial_segments = 16
	body.rings = 8
	var bm := MeshInstance3D.new()
	bm.name = "Body"
	bm.mesh = body
	bm.material_override = shell
	bm.position = Vector3(0, 0.30, 0)
	root.add_child(bm)

	# Lens on a stalk: the eye has to be the readable part, because everything
	# the player needs to know is expressed through it.
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.145
	lens_mesh.bottom_radius = 0.172
	lens_mesh.height = 0.13
	lens_mesh.radial_segments = 14
	_eye_mesh = MeshInstance3D.new()
	_eye_mesh.name = "Lens"
	_eye_mesh.mesh = lens_mesh
	_eye_mesh.material_override = lens
	_eye_mesh.position = Vector3(0, 0.30, 0.30)
	_eye_mesh.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(_eye_mesh)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.33
	ring.outer_radius = 0.40
	ring.rings = 18
	ring.ring_segments = 6
	var rm := MeshInstance3D.new()
	rm.name = "Ring"
	rm.mesh = ring
	rm.material_override = trim
	rm.position = Vector3(0, 0.30, 0)
	root.add_child(rm)

	# Hazard stripes on the ring: the one piece of high-frequency detail, and
	# the thing that says "machine, and it means it".
	for i in 8:
		var a := TAU * float(i) / 8.0
		var tick := LevelKit.chamfer_mesh(Vector3(0.05, 0.085, 0.085))
		var tm := MeshInstance3D.new()
		tm.mesh = tick
		tm.material_override = shell
		tm.position = Vector3(cos(a) * 0.365, 0.30, sin(a) * 0.365)
		tm.rotation.y = -a
		root.add_child(tm)

	# Rotors: four stubs that spin. At this size the spin is the life.
	_rotor = Node3D.new()
	_rotor.name = "Rotors"
	_rotor.position = Vector3(0, 0.60, 0)
	root.add_child(_rotor)
	for i in 4:
		var a := TAU * float(i) / 4.0
		var blade := LevelKit.chamfer_mesh(Vector3(0.40, 0.014, 0.07))
		var bl := MeshInstance3D.new()
		bl.mesh = blade
		bl.material_override = shell
		bl.position = Vector3(cos(a) * 0.22, 0.0, sin(a) * 0.22)
		bl.rotation.y = -a
		_rotor.add_child(bl)

	_eye = OmniLight3D.new()
	_eye.light_color = Color(1.0, 0.36, 0.20)
	_eye.light_energy = 2.2
	_eye.omni_range = 4.4
	_eye.shadow_enabled = false
	_eye.light_volumetric_fog_energy = 2.0
	_eye.position = Vector3(0, 0.30, 0.40)
	root.add_child(_eye)
	return root


func _behaviour(delta: float) -> void:
	_bob += delta * 2.6
	_rotor.rotation.y += delta * 26.0
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
	_eye_mesh.rotation.y = 0.0 if facing < 0 else PI


func _patrol(delta: float) -> void:
	_timer += delta
	var target := _origin.x + sin(_timer * patrol_speed / maxf(patrol_span, 0.1)) * patrol_span
	velocity.x = (target - global_position.x) * 2.2
	velocity.y = (_origin.y - global_position.y) * 2.0
	facing = -1 if velocity.x < 0.0 else 1
	_tint(Color(1.0, 0.36, 0.20), 2.2)
	if _sees_player():
		_mode = Mode.ALERT
		_timer = 0.0


## Wind-up: it stops, brightens to white, and rises. Every one of those is a
## separate cue, because a telegraph the player misses is a cheap hit.
func _alert(delta: float) -> void:
	_timer += delta
	velocity = velocity.lerp(Vector3(0, 1.1, 0), 1.0 - exp(-8.0 * delta))
	var t := clampf(_timer / alert_time, 0.0, 1.0)
	_tint(Color(1.0, 0.36, 0.20).lerp(Color(1, 1, 1), t), lerpf(2.2, 7.0, t))
	_visual.scale = Vector3.ONE * (1.0 + 0.10 * sin(_timer * 46.0) * t)
	if _timer >= alert_time:
		_mode = Mode.CHARGE
		_timer = 0.0
		if _player:
			facing = -1 if _player.global_position.x < global_position.x else 1


func _charge(delta: float) -> void:
	_timer += delta
	_visual.scale = Vector3.ONE
	if _player:
		var to := (_player.global_position + Vector3(0, 0.9, 0)) - global_position
		to.z = 0.0
		velocity = to.normalized() * charge_speed
	_tint(Color(1, 0.85, 0.85), 6.0)
	if _timer > 0.9:
		_mode = Mode.RECOVER
		_timer = 0.0


## Overshoot and drift: the recovery window is the player's turn.
func _recover(delta: float) -> void:
	_timer += delta
	velocity = velocity.lerp(Vector3(0, 0.4, 0), 1.0 - exp(-3.0 * delta))
	_tint(Color(0.5, 0.6, 0.9), 1.2)
	if _timer > 0.8:
		_mode = Mode.PATROL
		_timer = 0.0
		_origin.x = global_position.x


func _sees_player() -> bool:
	if _player == null:
		return false
	var to: Vector3 = _player.global_position - global_position
	if absf(to.x) > sight_range or absf(to.y) > 4.5:
		return false
	return signf(to.x) == float(facing) or absf(to.x) < 2.0


func _tint(c: Color, energy: float) -> void:
	_eye.light_color = c
	_eye.light_energy = energy
	var m := _eye_mesh.material_override as StandardMaterial3D
	if m:
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = energy * 0.6
