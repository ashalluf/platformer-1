class_name Rifle extends Node3D
## Wanis's rifle, as a weapon rather than as a prop.
##
## Full automatic, no magazine management — this is a platformer, and stopping
## to reload is not a mechanic anyone asked for. What it does have is recoil,
## and recoil is a movement tool: firing while airborne pushes him back, which
## makes the rifle part of the traversal kit instead of a separate system.

signal fired(muzzle_position: Vector3, direction: Vector3)

@export var rate_of_fire := 9.5          ## rounds per second
@export var muzzle_velocity := 62.0
@export var damage := 1.0
@export var range_ := 42.0
@export var recoil_impulse := 1.9        ## horizontal push per round, airborne
@export var recoil_ground_scale := 0.22  ## planted, he absorbs most of it
@export var spread_min := 0.008
@export var spread_max := 0.055
@export var bloom_per_shot := 0.09
@export var bloom_recovery := 0.55

var muzzle: Marker3D
var eject: Marker3D

var _cooldown := 0.0
var _bloom := 0.0
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_left := 0.0
var _shells: GPUParticles3D
var _tracers: TracerPool
var _model: Node3D


func _ready() -> void:
	_model = WeaponForge.build()
	add_child(_model)
	muzzle = _model.get_node("Muzzle")
	eject = _model.get_node("Eject")
	_build_flash()
	_build_shells()


func _build_flash() -> void:
	_flash = OmniLight3D.new()
	_flash.name = "MuzzleFlash"
	_flash.light_color = Color(1.0, 0.82, 0.52)
	_flash.light_energy = 0.0
	_flash.omni_range = 6.5
	_flash.light_volumetric_fog_energy = 6.0
	_flash.shadow_enabled = false
	muzzle.add_child(_flash)

	# A short cross of unshaded quads. At this scale a flash is a shape and a
	# colour for two frames; anything more detailed is wasted.
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.30, 0.16)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.86, 0.58, 0.95)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	mesh.material = mat
	_flash_mesh = MeshInstance3D.new()
	_flash_mesh.name = "FlashMesh"
	_flash_mesh.mesh = mesh
	_flash_mesh.visible = false
	_flash_mesh.position = Vector3(0, 0, 0.06)
	muzzle.add_child(_flash_mesh)

	# A second, shorter quad crossed against the first: a flash is a star, not
	# a card, and two quads is the cheapest way to say so.
	var cross := MeshInstance3D.new()
	cross.name = "FlashCross"
	var cross_mesh := QuadMesh.new()
	cross_mesh.size = Vector2(0.15, 0.15)
	cross_mesh.material = mat
	cross.mesh = cross_mesh
	_flash_mesh.add_child(cross)


## Created on the first shot, not in _ready. A pool built up front and attached
## deferred can outlive the rifle that owns it — the rifle gets freed on respawn
## before the deferred call runs, and the pool leaks. Lazily, that cannot happen.
##
## It lives at the scene root because tracers must not inherit the skeleton's
## transform, which is scaled by the squash-and-stretch node.
func _ensure_tracers() -> void:
	if is_instance_valid(_tracers) or not is_inside_tree():
		return
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	_tracers = TracerPool.new()
	_tracers.name = "TracerPool"
	root.add_child(_tracers)


func _build_shells() -> void:
	_shells = GPUParticles3D.new()
	_shells.name = "Shells"
	_shells.amount = 24
	_shells.lifetime = 1.6
	_shells.one_shot = false
	_shells.emitting = false
	_shells.explosiveness = 1.0
	_shells.local_coords = false
	_shells.visibility_aabb = AABB(Vector3(-6, -8, -3), Vector3(12, 12, 6))

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.35, 1.0, 0.0)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 3.6
	pm.gravity = Vector3(0, -26.0, 0)
	pm.angular_velocity_min = -900.0
	pm.angular_velocity_max = 900.0
	pm.scale_min = 0.9
	pm.scale_max = 1.2
	_shells.process_material = pm

	var shell := CylinderMesh.new()
	shell.top_radius = 0.008
	shell.bottom_radius = 0.010
	shell.height = 0.038
	shell.radial_segments = 6
	shell.material = MaterialLab.gold(Color(0.86, 0.66, 0.30))
	_shells.draw_pass_1 = shell
	eject.add_child(_shells)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_bloom = maxf(_bloom - bloom_recovery * delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		var t := clampf(_flash_left / 0.045, 0.0, 1.0)
		_flash.light_energy = 11.0 * t
		_flash_mesh.visible = t > 0.0
		# Collapses rather than fades: a flash that shrinks reads as faster.
		_flash_mesh.scale = Vector3(0.55 + 0.75 * t, 0.5 + 0.7 * t, 1.0)
	else:
		_flash.light_energy = 0.0
		_flash_mesh.visible = false


func can_fire() -> bool:
	return _cooldown <= 0.0


func try_fire(facing: int, grounded: bool) -> bool:
	return try_fire_dir(Vector3(facing, 0.0, 0.0), grounded)


## Returns true if a round left the barrel this call.
func try_fire_dir(aim: Vector3, _grounded: bool) -> bool:
	if not can_fire():
		return false
	_cooldown = 1.0 / rate_of_fire

	var spread := lerpf(spread_min, spread_max, clampf(_bloom, 0.0, 1.0))
	_bloom = minf(_bloom + bloom_per_shot, 1.0)

	# Spread is applied perpendicular to the aim, not as a fixed Y jitter, so
	# it stays honest when he is shooting straight up.
	var base := aim.normalized()
	var perp := Vector3(-base.y, base.x, 0.0)
	var dir := (base + perp * randf_range(-spread, spread)).normalized()
	_flash_left = 0.045
	_flash_mesh.rotation.z = randf_range(0.0, TAU)
	_shells.restart()
	_shells.emitting = true

	_ensure_tracers()
	_hitscan(muzzle.global_position, dir)
	fired.emit(muzzle.global_position, dir)
	return true


## Tracers are cosmetic; this is the shot. Raycast against the world (layer 1)
## and enemies (layer 8), stop the tracer at the hit, and spark the impact.
func _hitscan(from: Vector3, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * range_)
	q.collision_mask = 1 | 8
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	var end := from + dir * range_
	if not hit.is_empty():
		end = hit["position"]
		var body: Object = hit["collider"]
		if body is Enemy:
			(body as Enemy).hurt(damage, from, dir)
		else:
			_impact(end, hit["normal"])
	if is_instance_valid(_tracers):
		var length: float = maxf((end - from).length(), 0.4)
		_tracers.spawn(from, dir, muzzle_velocity, minf(length, 2.4), 0.035,
			minf(length / muzzle_velocity, 0.30))


## Dust puff and a couple of chips where the round lands.
func _impact(at: Vector3, normal: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 46.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, -9.0, 0)
	pm.damping_min = 4.0
	pm.damping_max = 9.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	p.process_material = pm

	p.draw_pass_1 = FXKit.sprite_pass(0.05, Color(0.85, 0.78, 0.66),
		{"alpha": 0.85, "additive": false})

	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func bloom() -> float:
	return _bloom


func _exit_tree() -> void:
	if not is_instance_valid(_tracers):
		return
	# Always deferred: during a scene teardown the pool can still have a parent
	# that is mid-removal, and free() would assert.
	_tracers.queue_free()
	_tracers = null
