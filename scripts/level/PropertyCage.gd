class_name PropertyCage extends Area3D
## The confiscated-property cage: Level 1's unforgettable moment.
##
## Wanis breaks it open and gets his own clothes back. It is a costume change
## and a mechanic unlock in one beat — he walks in wearing prison grey and walks
## out in the white thobe, with the chain, the shemagh and the rifle.
##
## The beat is built to be felt: hit-stop, a bloom of light, a slow-motion
## window, and the camera pushing in. It should be the loudest thing in the
## level so far, because everything after it is a different game.

signal opened()

@export var auto_open := true

var _opened := false
var _door: Node3D
var _lamp: OmniLight3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 3.2, 2.2)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 1.6, 0.0)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_build()


func _build() -> void:
	var bars := MaterialLab.rusted_metal(Color(0.24, 0.15, 0.11), 0.9)
	var frame := MaterialLab.painted_metal(Color(0.16, 0.17, 0.18), 0.9)

	LevelKit.prop(self, Vector3(0.0, 1.7, -1.35), Vector3(4.2, 3.4, 0.3), frame, "CageBack")
	for side: float in [-1.0, 1.0]:
		LevelKit.prop(self, Vector3(side * 2.0, 1.7, -0.9), Vector3(0.24, 3.4, 1.1),
			frame, "CageSide")
	LevelKit.prop(self, Vector3(0.0, 3.5, -0.9), Vector3(4.2, 0.26, 1.1), frame, "CageTop")

	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(-1.85, 0.0, -0.38)
	add_child(_door)
	for i in 8:
		var bar := CylinderMesh.new()
		bar.top_radius = 0.045
		bar.bottom_radius = 0.045
		bar.height = 3.2
		bar.radial_segments = 8
		var bm := MeshInstance3D.new()
		bm.mesh = bar
		bm.material_override = bars
		bm.position = Vector3(0.22 + i * 0.49, 1.7, 0.0)
		_door.add_child(bm)
	for i in 2:
		var rail := BoxMesh.new()
		rail.size = Vector3(3.9, 0.10, 0.10)
		var rm := MeshInstance3D.new()
		rm.mesh = rail
		rm.material_override = bars
		rm.position = Vector3(2.0, 0.5 + i * 2.4, 0.0)
		_door.add_child(rm)

	# What is inside, visible through the bars: his own things on a shelf.
	var shelf := LevelKit.material(Color(0.32, 0.24, 0.16), 0.8)
	LevelKit.prop(self, Vector3(0.0, 1.05, -0.9), Vector3(3.4, 0.10, 0.8), shelf, "Shelf")
	var cloth := MaterialLab.cloth(Color(0.92, 0.90, 0.86), 0.9)
	LevelKit.prop(self, Vector3(-0.7, 1.35, -0.9), Vector3(1.0, 0.5, 0.5), cloth, "FoldedThobe")
	var red := MaterialLab.cloth(Color(0.60, 0.115, 0.085), 0.85)
	LevelKit.prop(self, Vector3(0.45, 1.28, -0.9), Vector3(0.7, 0.36, 0.45), red, "FoldedShemagh")

	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.86, 0.60)
	_lamp.light_energy = 0.9
	_lamp.omni_range = 4.0
	_lamp.shadow_enabled = false
	_lamp.light_volumetric_fog_energy = 2.5
	_lamp.position = Vector3(0.0, 1.9, -0.7)
	add_child(_lamp)


func _on_body_entered(body: Node3D) -> void:
	if _opened or not auto_open or not (body is PlayerController):
		return
	open(body as PlayerController)


func open(player: PlayerController) -> void:
	if _opened:
		return
	_opened = true

	# Stop the world for a beat, then let it run slow while he changes.
	FX.hitstop(0.09)
	FX.shake(0.7, Vector2(0.0, 1.0))
	FX.zoom_punch(-6.0, 0.55)
	FX.timewarp(0.35, 0.55)
	Audio.play_2d("life", -2.0, 0.85)
	Audio.play("dash_charged", global_position, 0.0, 0.8)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_door, "rotation:y", -2.1, 0.30)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lamp, "light_energy", 9.0, 0.16)
	tw.chain().tween_property(_lamp, "light_energy", 1.6, 0.9)

	_burst()
	# The swap lands on the flash, not before it.
	get_tree().create_timer(0.14, true, false, true).timeout.connect(
		func() -> void: _equip(player))
	opened.emit()


func _equip(player: PlayerController) -> void:
	if not is_instance_valid(player):
		return
	var rig := player.get_node_or_null("Rig")
	if rig and rig.has_method("set_outfit"):
		rig.set_outfit(WanisBuilder.Outfit.STREET)
	for n: Node in [get_node_or_null("FoldedThobe"), get_node_or_null("FoldedShemagh")]:
		if n:
			n.queue_free()


func _burst() -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 5.0
	pm.scale_min = 0.6
	pm.scale_max = 2.0
	pm.scale_curve = Collectible._shrink_curve()
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.10)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.86, 0.58, 0.9)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad

	add_child(p)
	p.position = Vector3(0, 1.6, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)
