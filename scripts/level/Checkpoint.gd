class_name Checkpoint extends Area3D
## A checkpoint, as an object rather than a coordinate.
##
## A flagpole with a shemagh-red banner that hangs slack and snaps taut when
## reached. Reading a checkpoint at a glance matters more than the geometry:
## slack and grey means not yet, taut and lit means safe.

signal reached(index: int)

@export var index := 0
@export var respawn_offset := Vector3(0.0, 0.5, 0.0)

var _lit := false
var _banner: MeshInstance3D
var _lamp: OmniLight3D
var _sway: Sway


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 4.0, 2.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 2.0, 0.0)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_build()


func _build() -> void:
	var pole_mat := MaterialLab.rusted_metal(Color(0.26, 0.20, 0.16), 0.8)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.075
	pole.height = 4.2
	pole.radial_segments = 10
	var pm := MeshInstance3D.new()
	pm.name = "Pole"
	pm.mesh = pole
	pm.material_override = pole_mat
	pm.position = Vector3(0.0, 2.1, 0.0)
	add_child(pm)

	var base := LevelKit.material(Color(0.20, 0.19, 0.18), 0.9)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.26
	foot.bottom_radius = 0.34
	foot.height = 0.22
	foot.radial_segments = 12
	var fm := MeshInstance3D.new()
	fm.name = "Foot"
	fm.mesh = foot
	fm.material_override = base
	fm.position = Vector3(0.0, 0.11, 0.0)
	add_child(fm)

	_sway = Sway.new()
	_sway.name = "BannerSway"
	_sway.position = Vector3(0.0, 3.95, 0.0)
	_sway.axis = Vector3(0.0, 0.0, 1.0)
	_sway.amplitude = 0.10
	_sway.speed = 1.3
	_sway.gust_amplitude = 0.07
	add_child(_sway)

	var banner := QuadMesh.new()
	banner.size = Vector2(1.15, 0.78)
	var mat := MaterialLab.cloth(Color(0.32, 0.30, 0.29), 0.9)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_banner = MeshInstance3D.new()
	_banner.name = "Banner"
	_banner.mesh = banner
	_banner.material_override = mat
	_banner.position = Vector3(0.58, -0.44, 0.0)
	_sway.add_child(_banner)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.42, 0.22)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 5.0
	_lamp.light_volumetric_fog_energy = 3.0
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, 3.9, 0.3)
	add_child(_lamp)


func _on_body_entered(body: Node3D) -> void:
	if _lit or not (body is PlayerController):
		return
	light()


func light() -> void:
	if _lit:
		return
	_lit = true
	reached.emit(index)
	Audio.play_2d("life", -9.0, 1.35)
	FX.shake(0.14)

	var mat := _banner.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color", Color(0.72, 0.14, 0.11), 0.22)
	tw.tween_property(_lamp, "light_energy", 3.4, 0.28)
	# Snaps taut, then settles — the difference between a flag and a rag.
	tw.tween_property(_sway, "amplitude", 0.34, 0.10)
	tw.chain().tween_property(_sway, "amplitude", 0.16, 0.6)
	tw.chain().tween_property(_banner, "scale", Vector3(1.12, 1.0, 1.0), 0.18)


func is_lit() -> bool:
	return _lit
