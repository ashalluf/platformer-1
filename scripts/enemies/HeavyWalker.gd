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
var _lamp: OmniLight3D
var _lamp_mesh: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _shield: Node3D


func _setup() -> void:
	max_health = 9.0
	health = max_health
	contact_damage = 1.0
	knockback = 1.1
	hitstop = 0.05
	_origin = global_position
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.05, 1.5, 0.9)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.78, 0)
	add_child(cs)


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	add_child(root)

	var plate := MaterialLab.painted_metal(Color(0.145, 0.150, 0.158), 0.9)
	var joint := MaterialLab.chrome(Color(0.085, 0.082, 0.088), 0.5)
	var hazard := MaterialLab.cloth(Color(0.82, 0.56, 0.09), 0.72)

	# Legs first, so the chassis draws over the hips.
	for side in 2:
		var leg := Node3D.new()
		leg.name = "Leg%d" % side
		leg.position = Vector3(0.0, 1.02, -0.22 + side * 0.44)
		root.add_child(leg)
		_legs.append(leg)

		var thigh := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.24, 0.56, 0.24)
		thigh.mesh = tm
		thigh.material_override = joint
		thigh.position = Vector3(0, -0.28, 0)
		leg.add_child(thigh)

		var shin := Node3D.new()
		shin.name = "Shin"
		shin.position = Vector3(0, -0.56, 0)
		leg.add_child(shin)
		_shins.append(shin)

		var shin_mesh := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.20, 0.50, 0.20)
		shin_mesh.mesh = sm
		shin_mesh.material_override = joint
		shin_mesh.position = Vector3(0, -0.25, 0)
		shin.add_child(shin_mesh)

		var foot := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.52, 0.16, 0.30)
		foot.mesh = fm
		foot.material_override = plate
		foot.position = Vector3(0.06, -0.52, 0)
		shin.add_child(foot)

	_chassis = Node3D.new()
	_chassis.name = "Chassis"
	_chassis.position = Vector3(0, 1.10, 0)
	root.add_child(_chassis)

	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(1.00, 0.62, 0.86)
	hull.mesh = hm
	hull.material_override = plate
	_chassis.add_child(hull)

	# A hazard chevron band along the top, the only saturated thing on it.
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.86, 0.10, 0.88)
	band.mesh = bm
	band.material_override = hazard
	band.position = Vector3(0, 0.30, 0)
	_chassis.add_child(band)

	# The shield: a raked plate on the leading face. It is deliberately the
	# biggest, flattest, most obvious thing on the model.
	_shield = Node3D.new()
	_shield.name = "Shield"
	_shield.position = Vector3(-0.52, -0.02, 0)
	_chassis.add_child(_shield)
	var sp := MeshInstance3D.new()
	var spm := BoxMesh.new()
	spm.size = Vector3(0.16, 0.92, 0.94)
	sp.mesh = spm
	sp.material_override = plate
	sp.rotation_degrees = Vector3(0, 0, -11.0)
	_shield.add_child(sp)
	for i in 3:
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, 0.86, 0.07)
		rib.mesh = rm
		rib.material_override = joint
		rib.position = Vector3(-0.10, 0.0, -0.30 + i * 0.30)
		rib.rotation_degrees = Vector3(0, 0, -11.0)
		_shield.add_child(rib)

	# Sensor head on the back of the hull — the unarmoured part, and the part
	# that tells you what it is about to do.
	var head := MeshInstance3D.new()
	var hd := BoxMesh.new()
	hd.size = Vector3(0.34, 0.26, 0.40)
	head.mesh = hd
	head.material_override = joint
	head.position = Vector3(0.44, 0.30, 0)
	_chassis.add_child(head)

	_lamp_mesh = MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.11
	lm.height = 0.20
	lm.radial_segments = 10
	lm.rings = 5
	_lamp_mesh.mesh = lm
	_lamp_mat = MaterialLab.emissive(Color(0.40, 0.90, 0.60), 1.0)
	_lamp_mesh.material_override = _lamp_mat
	_lamp_mesh.position = Vector3(0.56, 0.32, 0)
	_chassis.add_child(_lamp_mesh)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(0.40, 0.90, 0.60)
	_lamp.light_energy = 1.1
	_lamp.omni_range = 2.6
	_lamp.shadow_enabled = false
	_lamp_mesh.add_child(_lamp)
	return root


## The shield only soaks what hits it. `from` is the world position the damage
## came from, so the test is simply which side of the chassis it is on.
func hurt(amount: float, from: Vector3, impulse := Vector3.ZERO) -> void:
	var front := signf(float(facing))
	var side := signf(from.x - global_position.x)
	if side == front:
		amount *= shield_soak
		Audio.play("shell", global_position, -4.0, randf_range(0.55, 0.65))
		_clang()
	super.hurt(amount, from, impulse)


## A visible ring-off, so soaking is information rather than a silent nerf.
func _clang() -> void:
	if _shield == null:
		return
	var tw := create_tween()
	tw.tween_property(_shield, "position:x", -0.62, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_shield, "position:x", -0.52, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _behaviour(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_timer += delta
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	else:
		velocity.y = 0.0

	var to_player := 0.0
	var sees := false
	if _player != null and is_instance_valid(_player):
		var d := (_player as Node3D).global_position - global_position
		to_player = d.x
		sees = absf(d.x) < sight_range and absf(d.y) < 3.2

	match _mode:
		Mode.PATROL:
			_set_lamp(Color(0.40, 0.90, 0.60), 1.1)
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
			# Planted, lamp going red, and a two-beat rock backwards. Long
			# enough to dash through it, which is the intended answer.
			velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
			var t := clampf(_timer / wind_up, 0.0, 1.0)
			_set_lamp(Color(0.40, 0.90, 0.60).lerp(Color(1.0, 0.22, 0.14), t),
				lerpf(1.1, 5.5, t))
			_chassis.position.x = lerpf(0.0, 0.16 * float(facing) * -1.0, t)
			_chassis.rotation.z = lerpf(0.0, 0.10 * float(facing), t)
			if _timer >= wind_up:
				_mode = Mode.CHARGE
				_timer = 0.0
				Audio.play("land", global_position, -4.0, 0.7)
		Mode.CHARGE:
			_set_lamp(Color(1.0, 0.26, 0.16), 6.0)
			# It will not run itself off a ledge; it plants instead, which also
			# happens to be the moment the player wants to be behind it.
			velocity.x = charge_speed * facing if _floor_ahead(1.35) else 0.0
			_chassis.position.x = 0.10 * float(facing)
			_chassis.rotation.z = -0.06 * float(facing)
			if _timer >= charge_time or is_on_wall() or not _floor_ahead(1.35):
				_mode = Mode.RECOVER
				_timer = 0.0
		Mode.RECOVER:
			# Stopped, plate down, lamp amber. This is the window.
			velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
			_set_lamp(Color(1.0, 0.62, 0.20),
				lerpf(4.0, 1.1, clampf(_timer / recover_time, 0.0, 1.0)))
			_chassis.position.x = lerpf(_chassis.position.x, 0.0,
				1.0 - exp(-7.0 * delta))
			_chassis.rotation.z = lerpf(_chassis.rotation.z, 0.0,
				1.0 - exp(-7.0 * delta))
			if _timer >= recover_time:
				_mode = Mode.PATROL
				_timer = 0.0

	_walk(delta)


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
func _walk(delta: float) -> void:
	var speed := absf(velocity.x)
	_cycle += delta * (2.6 + speed * 1.15)
	for i in _legs.size():
		var phase := _cycle + PI * float(i)
		var lift := maxf(sin(phase), 0.0)
		_legs[i].rotation.z = cos(phase) * 0.34 * clampf(speed / 3.0, 0.15, 1.0)
		_shins[i].rotation.z = -lift * 0.42
		_legs[i].position.y = 1.02 + lift * 0.05
	# The body drops on each footfall, which is where the weight comes from.
	if _chassis != null:
		_chassis.position.y = 1.10 - absf(sin(_cycle)) * 0.035


func _set_lamp(tint: Color, energy: float) -> void:
	_lamp_mat.emission = tint
	_lamp_mat.emission_energy_multiplier = energy
	_lamp_mat.albedo_color = tint
	_lamp.light_color = tint
	_lamp.light_energy = energy
