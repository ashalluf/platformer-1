class_name SwingRope
extends Node3D
## A rope you grab, swing on, and let go of at the top of the arc.
##
## The rope owns the pendulum, not the player. It is the thing that knows its
## own anchor and length, so the maths stays in one place and the controller
## only has to feed it steering and read back where the hands are.
##
## The physics is a damped driven pendulum, which is the right model and also
## the one that feels correct: a swing has to be PUMPED. Holding a direction
## adds energy at the bottom of the arc and bleeds it at the top, exactly like
## a child on a playground swing, so crossing a wide gap is a skill rather than
## a button press. Damping means a rope left alone settles, which stops a player
## parking on one forever.

const SEGMENTS := 10

@export var length := 5.0
## Where the rope hangs when nothing is riding it, in degrees from straight down.
@export var rest_angle_deg := 0.0
## Starting swing, so a rope is already moving when the player arrives.
@export var start_angle_deg := 22.0
@export var damping := 0.42
## How hard the rider can pump. Too high and the arc goes vertical in a second.
@export var steer_power := 5.2
@export var max_angle_deg := 78.0
@export var thickness := 0.055
@export var vine := true          ## a green vine, or a steel-grey rope

var angle := 0.0
var ang_vel := 0.0

var _rider: Node3D = null
var _grab: Area3D
var _links: Array[MeshInstance3D] = []
var _mat: Material


func _ready() -> void:
	angle = deg_to_rad(start_angle_deg)
	_mat = _rope_material()
	_build_rope()
	_build_grab_area()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	# Pendulum: a = -(g / L) sin(theta), damped. Gravity here is the player's
	# own, so a rope reads at the same weight as a jump does.
	var g := 26.0
	var accel := -(g / maxf(length, 0.5)) * sin(angle)
	accel -= damping * ang_vel
	if _rider == null:
		# Empty ropes ease back to rest rather than swinging forever.
		accel += (deg_to_rad(rest_angle_deg) - angle) * 1.4
	ang_vel += accel * delta
	angle += ang_vel * delta

	var lim := deg_to_rad(max_angle_deg)
	if absf(angle) > lim:
		angle = clampf(angle, -lim, lim)
		ang_vel *= -0.25          # it hits the end of its travel and rebounds
	_place_links()


## Called by the rider each frame. Pumping only works near the bottom of the
## arc -- push at the top and you are fighting the rope, which is true of every
## real swing and is what makes timing matter.
func steer(input: float, delta: float) -> void:
	if is_zero_approx(input):
		return
	var pump := cos(angle)        # 1 at the bottom, 0 at the extremes
	ang_vel += input * steer_power * pump * delta


## Where the rider's hands are: the tip of the rope.
func hand_position() -> Vector3:
	return global_position + _tip_offset()


## Unit vector along the direction of travel at the current angle.
func tangent() -> Vector3:
	var dir := Vector3(cos(angle), sin(angle), 0.0)
	return dir * signf(ang_vel) if not is_zero_approx(ang_vel) else dir


## What the rider leaves with. Tangential speed is angular speed times radius,
## so letting go at the bottom of a fast arc throws hardest -- and letting go at
## the top throws highest but slowest, which is the choice worth having.
func release_velocity() -> Vector3:
	var speed := ang_vel * length
	return Vector3(cos(angle) * speed, sin(angle) * speed, 0.0)


func _tip_offset() -> Vector3:
	return Vector3(sin(angle) * length, -cos(angle) * length, 0.0)


func _build_rope() -> void:
	for i in SEGMENTS:
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = thickness
		cyl.bottom_radius = thickness * (1.0 if vine else 0.94)
		cyl.height = length / float(SEGMENTS)
		cyl.radial_segments = 6
		seg.mesh = cyl
		seg.material_override = _mat
		add_child(seg)
		_links.append(seg)
	# A knot at the bottom: something to aim at, and it reads as grabbable.
	var knot := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = thickness * 2.6
	s.height = thickness * 5.2
	s.radial_segments = 8
	s.rings = 4
	knot.mesh = s
	knot.material_override = _mat
	add_child(knot)
	_links.append(knot)
	_place_links()


func _place_links() -> void:
	if _links.is_empty():
		return
	var step := length / float(SEGMENTS)
	var dir := Vector3(sin(angle), -cos(angle), 0.0)
	for i in SEGMENTS:
		var seg := _links[i]
		seg.position = dir * (step * (float(i) + 0.5))
		seg.rotation = Vector3(0.0, 0.0, angle)
	_links[SEGMENTS].position = dir * length
	if _grab:
		_grab.position = dir * (length * 0.86)


func _build_grab_area() -> void:
	_grab = Area3D.new()
	_grab.name = "Grab"
	_grab.collision_layer = 0
	_grab.collision_mask = 2
	var shape := CapsuleShape3D.new()
	shape.radius = 0.62
	shape.height = maxf(length * 0.42, 1.2)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_grab.add_child(cs)
	add_child(_grab)
	_grab.body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if _rider != null or not body.has_method("grab_rope"):
		return
	if not body.call("grab_rope", self):
		return
	_rider = body
	# The rider's momentum goes into the rope. Arriving fast from the left
	# means the rope is already moving left when it takes the weight.
	var v: Vector3 = body.get("velocity")
	if v != null:
		ang_vel += clampf(v.x / maxf(length, 0.5), -3.2, 3.2)
	if body.has_signal("stomped"):
		pass
	_watch_rider()


func _watch_rider() -> void:
	set_process(true)


func _process(_d: float) -> void:
	if _rider == null:
		set_process(false)
		return
	# The controller clears its own rope reference on release, on being hit, and
	# on death. Reading it back is how the rope hears about all three without
	# needing a signal for each.
	if not is_instance_valid(_rider) or _rider.get("_rope") != self:
		_rider = null
		set_process(false)


## Vine or rope. Both are chroma-clamped world surfaces like everything else.
func _rope_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if vine:
		m.albedo_color = MaterialLab.world_tint(Color(0.220, 0.500, 0.230))
		m.roughness = 0.88
	else:
		m.albedo_color = MaterialLab.world_tint(Color(0.470, 0.420, 0.330))
		m.roughness = 0.95
	m.metallic = 0.0
	return m
