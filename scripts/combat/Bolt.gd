class_name Bolt extends Area3D
## A slow, visible enemy projectile.
##
## Deliberately not a hitscan. The player's own rifle is instant because it is
## his; everything shot at him travels slowly enough to be read, stepped around
## or jumped over, which is what makes a turret a platforming problem rather
## than a damage tax.

@export var speed := 13.0
@export var damage := 1.0
@export var life := 3.2
@export var tint := Color(1.0, 0.42, 0.20)

var direction := Vector3.RIGHT
var _age := 0.0
var _mesh: MeshInstance3D


static func spawn(parent: Node, from: Vector3, dir: Vector3, speed_ := 13.0,
		tint_ := Color(1.0, 0.42, 0.20)) -> Bolt:
	var b := Bolt.new()
	b.direction = dir.normalized()
	b.speed = speed_
	b.tint = tint_
	parent.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	# Layer 16 so nothing else in the project has to know about it; it looks
	# for the player (2) and the world (1).
	collision_layer = 16
	collision_mask = 1 | 2
	monitoring = true

	var shape := SphereShape3D.new()
	shape.radius = 0.16
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	_mesh = MeshInstance3D.new()
	var caps := CapsuleMesh.new()
	caps.radius = 0.055
	caps.height = 0.62
	caps.radial_segments = 8
	caps.rings = 2
	_mesh.mesh = caps
	# 3.0 tonemaps to a white pill and the round stops having a colour. Low
	# enough that the tint survives, and the omni does the "this is hot" work.
	_mesh.material_override = MaterialLab.emissive(tint, 1.3)
	# Lying along travel, which in this game is always the X axis.
	_mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(_mesh)

	var glow := OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 2.2
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	add_child(glow)

	# A soft tail, so a round reads as travelling rather than as floating.
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	var tq := QuadMesh.new()
	tq.size = Vector2(1.5, 0.30)
	tail.mesh = tq
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.albedo_color = Color(tint.r, tint.g, tint.b, 0.40)
	tm.albedo_texture = PropKit._decal_texture("radial")
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tail.material_override = tm
	tail.position = -direction * 0.6
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tail)

	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		_pop()
		return
	global_position += direction * speed * delta
	global_position.z = 0.0


func _on_body(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).take_hit(damage, global_position)
	_pop()


func _pop() -> void:
	set_physics_process(false)
	# Deferred: _pop is called from body_entered, and Godot refuses to toggle
	# monitoring while it is dispatching that signal.
	set_deferred("monitoring", false)
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.22
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.spread = 180.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -5.0, 0)
	pm.damping_min = 6.0
	pm.damping_max = 12.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(tint.r, tint.g, tint.b, 0.6)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	p.draw_pass_1 = quad
	var root := get_tree().current_scene
	if root != null:
		root.add_child(p)
		p.global_position = global_position
		p.emitting = true
		p.finished.connect(p.queue_free)
	queue_free()
