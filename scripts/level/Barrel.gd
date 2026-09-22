class_name Barrel
extends CharacterBody3D
## A barrel: pick it up, throw it, break it. And the cannon variant that fires
## the player across a gap.
##
## Two behaviours, one prop, because in the games this is built after they are
## visually the same object and the player learns them as one vocabulary. Which
## one you get is `mode`.
##
##   THROWN   carried over the head, thrown along the ground, breaks on contact
##            and kills what it hits. The answer to an enemy you cannot reach.
##   CANNON   bolted in place, aims, and fires the player along its barrel when
##            they enter it. The set-piece traversal verb.

enum Mode { THROWN, CANNON }

signal broke(at: Vector3)
signal fired(direction: Vector3)

@export var mode: Mode = Mode.THROWN
@export var throw_speed := 15.0
@export var roll_speed := 11.0
@export var gravity := 26.0
@export var radius := 0.42
@export var height := 0.92
## CANNON: direction in degrees, measured from +X, counter-clockwise.
@export var aim_deg := 60.0
@export var launch_speed := 22.0
## CANNON: an auto barrel fires the moment it catches the player; otherwise it
## holds them until they press jump, which is the version that can be aimed.
@export var auto_fire := false

var _thrown := false
var _broken := false
var _carrier: Node3D = null
var _held_rider: Node3D = null
var _spin := 0.0
var _visual: Node3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	_visual = _build_visual()
	add_child(_visual)
	_build_area()
	set_physics_process(mode == Mode.THROWN)


# --- Thrown -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _broken:
		return
	if _carrier != null:
		# Carried: sits over the head and stays there. No physics.
		global_position = _carrier.global_position + Vector3(0.0, 1.55, 0.0)
		velocity = Vector3.ZERO
		return
	velocity.y -= gravity * delta
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

	if _thrown:
		_spin += delta * signf(velocity.x) * 15.0
		_visual.rotation.z = -_spin
		# A thrown barrel that hits anything stops being a barrel.
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if absf(c.get_normal().y) < 0.7:
				_break()
				return
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
			if absf(velocity.x) < 0.6:
				_break()


func _on_contact(body: Node3D) -> void:
	if _broken or mode != Mode.THROWN:
		return
	if _thrown:
		# In flight: anything that can be hurt, is. This is the whole point of
		# a throwable -- the answer to an enemy the player cannot safely land on.
		if body.has_method("hurt"):
			body.call("hurt", 999.0, global_position, Vector3.ZERO)
			_break()
		return
	if body.has_method("try_carry"):
		body.call("try_carry", self)


func pick_up(by: Node3D) -> bool:
	if _broken or _thrown or mode != Mode.THROWN or _carrier != null:
		return false
	_carrier = by
	return true


func throw(dir: float) -> void:
	if _carrier == null:
		return
	_carrier = null
	_thrown = true
	velocity = Vector3(signf(dir) * throw_speed, 2.4, 0.0)
	Audio.play("dash", global_position, -4.0, randf_range(0.9, 1.05))


func _break() -> void:
	if _broken:
		return
	_broken = true
	FX.hitstop(0.05)
	FX.shake(0.30)
	Audio.play("shell", global_position, -3.0, randf_range(0.8, 0.95))
	broke.emit(global_position)
	_burst()
	queue_free()


## Staves fly apart. Cheap, and the difference between a prop vanishing and a
## prop being destroyed.
func _burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 71.0) + 13
	for i in 7:
		var stave := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.07, height * 0.44, 0.09)
		stave.mesh = box
		stave.material_override = _stave_material()
		stave.global_position = global_position
		parent.add_child(stave)
		var away := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.0), 0.0)
		var tw := stave.create_tween().set_parallel()
		tw.tween_property(stave, "global_position",
			global_position + away * rng.randf_range(1.4, 3.0), 0.55)
		tw.tween_property(stave, "rotation",
			Vector3(0.0, 0.0, rng.randf_range(-7.0, 7.0)), 0.55)
		tw.chain().tween_callback(stave.queue_free)


# --- Cannon -----------------------------------------------------------------

func aim_direction() -> Vector3:
	var a := deg_to_rad(aim_deg)
	return Vector3(cos(a), sin(a), 0.0)


func _catch(body: Node3D) -> void:
	if _broken or mode != Mode.CANNON or _held_rider != null:
		return
	if not body.has_method("enter_barrel"):
		return
	if not body.call("enter_barrel", self):
		return
	_held_rider = body
	Audio.play("ui", global_position, -6.0, 0.7)
	if auto_fire:
		await get_tree().create_timer(0.22, true, false, true).timeout
		fire()


## Called by the rider pressing jump, or by auto_fire.
func fire() -> void:
	if _held_rider == null:
		return
	var rider := _held_rider
	_held_rider = null
	var dir := aim_direction()
	if rider.has_method("launch_from_barrel"):
		rider.call("launch_from_barrel", dir * launch_speed)
	FX.shake(0.45)
	FX.camera_zoom_punch.emit(-6.0, 0.22)
	Audio.play("dash_charged", global_position, -2.0, randf_range(0.95, 1.08))
	fired.emit(dir)


func rider_position() -> Vector3:
	return global_position


# --- Build ------------------------------------------------------------------

func _build_area() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	var area := Area3D.new()
	area.name = "Trigger"
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape3D.new()
	var asphere := SphereShape3D.new()
	asphere.radius = radius + 0.30
	acs.shape = asphere
	area.add_child(acs)
	add_child(area)
	if mode == Mode.CANNON:
		area.body_entered.connect(_catch)
	else:
		# A thrown barrel hunts enemies; a resting one offers itself to be
		# carried. Same volume, and which it does depends on whether it is
		# already in the air.
		area.collision_mask = 2 | 4
		area.body_entered.connect(_on_contact)


func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "BarrelVisual"
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.88
	cyl.bottom_radius = radius * 0.88
	cyl.height = height
	cyl.radial_segments = 12
	body.mesh = cyl
	body.material_override = _stave_material()
	root.add_child(body)

	# Two iron hoops. They are what make a cylinder read as a barrel.
	for y in [height * 0.29, -height * 0.29]:
		var hoop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.86
		torus.outer_radius = radius * 0.99
		torus.rings = 12
		hoop.mesh = torus
		hoop.rotation.x = PI * 0.5
		hoop.position.y = y
		hoop.material_override = _hoop_material()
		root.add_child(hoop)

	if mode == Mode.CANNON:
		root.rotation.z = deg_to_rad(aim_deg) - PI * 0.5
	return root


func _stave_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = MaterialLab.world_tint(
		Color(0.560, 0.300, 0.140) if mode == Mode.THROWN
		else Color(0.620, 0.230, 0.180))
	m.roughness = 0.86
	return m


func _hoop_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = MaterialLab.world_tint(Color(0.260, 0.255, 0.245))
	m.metallic = 0.85
	m.roughness = 0.42
	return m
