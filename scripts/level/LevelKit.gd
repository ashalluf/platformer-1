class_name LevelKit
## Static helpers for building level geometry from code.
##
## Every scene in this project is authored by a GDScript builder rather than a
## hand-edited .tscn: it keeps levels diffable, parameterised and fast to
## iterate. These helpers are the vocabulary those builders speak.

static func material(color: Color, roughness := 0.75, metallic := 0.0,
		uv_scale := Vector3.ONE, triplanar := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_scale = uv_scale
	if triplanar:
		m.uv1_triplanar = true
	return m


## Solid box with matching collision. `size` is full extents, `center` is world
## centre of the box.
static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material,
		body_name := "Block") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = center
	parent.add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	body.add_child(cs)
	return body


## A platform expressed in gameplay terms: left edge, top surface, width, depth.
static func platform(parent: Node3D, left_x: float, top_y: float, width: float,
		mat: Material, thickness := 1.2, depth := 3.0, name_ := "Platform") -> StaticBody3D:
	return box(parent,
		Vector3(left_x + width * 0.5, top_y - thickness * 0.5, 0.0),
		Vector3(width, thickness, depth), mat, name_)


## Ramp built from a rotated box, so the collision surface matches the visual.
static func ramp(parent: Node3D, start: Vector2, end: Vector2, width_z: float,
		mat: Material, thickness := 1.0, name_ := "Ramp") -> StaticBody3D:
	var delta := end - start
	var length := delta.length()
	var mid := (start + end) * 0.5
	var angle := delta.angle()
	var body := box(parent, Vector3(mid.x, mid.y - thickness * 0.5, 0.0),
		Vector3(length, thickness, width_z), mat, name_)
	body.rotation.z = angle
	return body


## Non-colliding decorative box (backgrounds, silhouettes, set dressing).
static func prop(parent: Node3D, center: Vector3, size: Vector3, mat: Material,
		name_ := "Prop") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi
