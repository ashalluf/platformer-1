class_name Collectible extends Area3D
## Base for everything the player picks up.
##
## Collection is two separate things and they are deliberately decoupled: the
## *rule* (what it gives you) and the *feedback* (what it does to the screen).
## Subclasses override `_on_collected`; the feel — magnet, pop, burst, hit-stop,
## camera nudge — is the same for everything, escalating only in scale.

signal collected(by: Node3D)

@export var magnet_radius := 1.9
@export var magnet_speed := 16.0
@export var collect_radius := 0.55
@export var hitstop := 0.0
@export var shake := 0.0
@export var burst_color := Color(1.0, 0.36, 0.20)
@export var burst_count := 10
@export var pop_scale := 1.55

var _taken := false
var _magnet_target: Node3D
var _visual: Node3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var shape := SphereShape3D.new()
	shape.radius = magnet_radius
	var cs := CollisionShape3D.new()
	cs.name = "MagnetShape"
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_visual = _build_visual()


## Override: build the thing's geometry and return its root.
func _build_visual() -> Node3D:
	return null


## Override: apply the rule.
func _on_collected(_by: Node3D) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is PlayerController):
		return
	_magnet_target = body


func _physics_process(delta: float) -> void:
	if _taken or _magnet_target == null:
		return
	# Magnet, not teleport: the bottle flies to him and that flight is most of
	# what makes a trail feel good to run through.
	var to := _magnet_target.global_position + Vector3(0, 0.9, 0) - global_position
	var dist := to.length()
	if dist < collect_radius:
		_collect(_magnet_target)
		return
	var pull := magnet_speed * (1.0 - clampf(dist / maxf(magnet_radius, 0.01), 0.0, 1.0))
	global_position += to.normalized() * maxf(pull, 3.0) * delta


func _collect(by: Node3D) -> void:
	if _taken:
		return
	_taken = true
	monitoring = false
	_on_collected(by)
	collected.emit(by)
	_burst()
	if hitstop > 0.0:
		FX.hitstop(hitstop)
	if shake > 0.0:
		FX.shake(shake)
	_pop_and_free()


## A short scale-up into nothing. Shrinking to zero reads as "gone"; scaling up
## first reads as "taken".
func _pop_and_free() -> void:
	if _visual == null:
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3.ONE * pop_scale, 0.07)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_visual, "scale", Vector3.ZERO, 0.09)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _burst() -> void:
	var p := GPUParticles3D.new()
	p.amount = burst_count
	p.lifetime = 0.26
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	# The old 3–7.5 threw the sparks half a metre in every direction, and
	# additive sparks on an expanding shell pile up at its rim: the burst read
	# as a white ring with a hole in it, which is not a spark burst.
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -7.0, 0)
	pm.damping_min = 8.0
	pm.damping_max = 16.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.scale_curve = _shrink_curve()
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(burst_color.r, burst_color.g, burst_color.b, 0.55)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad

	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t
