class_name TracerPool extends Node3D
## Tracer rounds, pooled and simulated explicitly.
##
## GPU particles were the obvious choice and the wrong one: emitting from a
## marker buried under a scaled skeleton produced garbage transforms. Tracers
## are few, short-lived and need exact placement, so they are simple nodes that
## this pool moves itself.

const POOL_SIZE := 24

class Tracer extends RefCounted:
	var node: MeshInstance3D
	var velocity: Vector3
	var life := 0.0
	var max_life := 0.0

var _pool: Array[Tracer] = []
var _mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = Color(1.0, 0.80, 0.45, 0.95)
	_mat.disable_receive_shadows = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	for i in POOL_SIZE:
		var t := Tracer.new()
		t.node = MeshInstance3D.new()
		t.node.name = "Tracer%d" % i
		t.node.mesh = quad
		t.node.material_override = _mat
		t.node.visible = false
		t.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(t.node)
		_pool.append(t)


func spawn(from: Vector3, dir: Vector3, speed: float, length := 1.9,
		width := 0.035, life := 0.30) -> void:
	for t in _pool:
		if t.life > 0.0:
			continue
		t.velocity = dir.normalized() * speed
		t.life = life
		t.max_life = life
		t.node.visible = true
		t.node.global_position = from
		# Lie the quad along the flight direction, facing the camera plane.
		t.node.global_basis = Basis(
			dir.normalized(),
			Vector3.BACK.cross(dir.normalized()).normalized(),
			Vector3.BACK
		).scaled(Vector3(length, width, 1.0))
		return


func _process(delta: float) -> void:
	for t in _pool:
		if t.life <= 0.0:
			continue
		t.life -= delta
		if t.life <= 0.0:
			t.node.visible = false
			continue
		t.node.global_position += t.velocity * delta
		# Stretch on the way out, fade on the way in.
		var k := t.life / t.max_life
		var m := t.node.material_override as StandardMaterial3D
		t.node.scale.x = 1.0 + (1.0 - k) * 0.4
		t.node.transparency = 1.0 - clampf(k * 1.6, 0.0, 1.0)
