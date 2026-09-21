class_name Enemy extends CharacterBody3D
## Base for everything that can be destroyed.
##
## World 1's prison enemies are Brega's automated security — drones, turrets and
## walkers. That is a tonal decision as much as a design one: this is an
## affectionate, larger-than-life game, and full-auto gunplay against machines
## stays playful in a way that gunplay against people would not.
##
## The contract every enemy keeps: it telegraphs before it commits, it flashes
## and recoils when hit, and it dies in a way worth watching.

signal damaged(amount: float, from: Vector3)
signal died()

@export var max_health := 3.0
@export var contact_damage := 1.0
@export var knockback := 3.0
@export var flash_time := 0.09
@export var hitstop := 0.035
@export var score_value := 1

var health: float
var facing := -1
var _flash_left := 0.0
var _dead := false
var _materials: Array[StandardMaterial3D] = []
var _base_albedo: Array[Color] = []
var _visual: Node3D


func _ready() -> void:
	health = max_health
	collision_layer = 8
	collision_mask = 1
	add_to_group("enemy")
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_visual = _build()
	_cache_materials(self)
	_setup()
	_build_hurtbox()


## Contact damage lives on an Area, not on the body, so an enemy's dangerous
## volume can differ from the shape it collides with.
func _build_hurtbox() -> void:
	if contact_damage <= 0.0:
		return
	var area := Area3D.new()
	area.name = "HurtBox"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var shape := SphereShape3D.new()
	shape.radius = 0.52
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.35, 0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_touch)


func _on_touch(body: Node3D) -> void:
	if _dead or not (body is PlayerController):
		return
	var p := body as PlayerController
	if p.has_method("take_hit"):
		p.take_hit(contact_damage, global_position)


## Override: build geometry, return its root.
func _build() -> Node3D:
	return null


## Override: per-enemy init after the body exists.
func _setup() -> void:
	pass


## Override: per-frame behaviour. Base handles flash, death and plane lock.
func _behaviour(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_behaviour(delta)
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	var t := clampf(_flash_left / maxf(flash_time, 0.001), 0.0, 1.0)
	for i in _materials.size():
		# Additive white, not a replacement: the silhouette stays readable and
		# the hit reads even on an already-bright surface.
		_materials[i].albedo_color = _base_albedo[i].lerp(Color(1, 1, 1), t)
		_materials[i].emission_enabled = true
		_materials[i].emission = Color(1, 1, 1)
		_materials[i].emission_energy_multiplier = t * 3.0
	if _flash_left <= 0.0:
		for i in _materials.size():
			_materials[i].albedo_color = _base_albedo[i]
			_materials[i].emission_energy_multiplier = 0.0


func _cache_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var m := mi.material_override
		if m is StandardMaterial3D:
			# Duplicate so flashing one enemy does not flash all of them.
			var dup := (m as StandardMaterial3D).duplicate()
			mi.material_override = dup
			_materials.append(dup)
			_base_albedo.append(dup.albedo_color)
	for c in node.get_children():
		_cache_materials(c)


func hurt(amount: float, from: Vector3, impulse := Vector3.ZERO) -> void:
	if _dead:
		return
	health -= amount
	_flash_left = flash_time
	damaged.emit(amount, from)
	FX.hitstop(hitstop)
	FX.shake(0.10)
	Audio.play("shell", global_position, -8.0, randf_range(1.3, 1.7))
	_spark(from)
	if impulse != Vector3.ZERO:
		velocity += impulse.normalized() * knockback
	if health <= 0.0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	set_collision_layer_value(4, false)
	FX.hitstop(0.055)
	FX.shake(0.30)
	Audio.play("hurt", global_position, -4.0, randf_range(1.1, 1.3))
	_debris()
	_death_animation()


## Pop up, spin out, shrink away. Cheap, readable, and it always reads as
## "destroyed" rather than "despawned".
func _death_animation() -> void:
	if _visual == null:
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3.ONE * 1.35, 0.06)
	tw.tween_property(_visual, "position:y", _visual.position.y + 0.55, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "rotation:z", randf_range(-3.0, 3.0), 0.34)
	tw.chain().tween_property(_visual, "scale", Vector3.ZERO, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _spark(from: Vector3) -> void:
	_particles(14, Color(1.0, 0.82, 0.42), 0.30, (global_position - from).normalized(), 5.0)


func _debris() -> void:
	_particles(26, Color(0.85, 0.72, 0.55), 0.75, Vector3.UP, 7.5)
	_particles(18, Color(1.0, 0.55, 0.18), 0.45, Vector3.UP, 5.0)


func _particles(count: int, color: Color, life: float, dir: Vector3, speed: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = dir
	pm.spread = 70.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -14.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.scale_curve = Collectible._shrink_curve()
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad

	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p)
	p.global_position = global_position + Vector3(0, 0.4, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)


func is_dead() -> bool:
	return _dead
