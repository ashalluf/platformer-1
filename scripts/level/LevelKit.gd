class_name LevelKit
## Static helpers for building level geometry from code.
##
## Every scene in this project is authored by a GDScript builder rather than a
## hand-edited .tscn: it keeps levels diffable, parameterised and fast to
## iterate. These helpers are the vocabulary those builders speak.

## --- The chamfered box ------------------------------------------------------
##
## Everything in this game that is not a character is a box, and a box with
## perfect ninety-degree edges is the single loudest "this is a blockout" signal
## there is. Real edges are never sharp: they are cast, chipped, rendered over,
## or simply small enough that light wraps them. That wrap is what an edge
## highlight IS, and without it a wall has no edge at all — it has a place where
## two flat values meet.
##
## So the project has no BoxMesh in it any more. Every box is chamfered, the
## bevel scales with the object (a crate gets 12 mm, a building gets 80 mm), and
## the meshes are cached by size so a thousand identical blocks share one.
## Collision stays a plain box: the chamfer is centimetres and must not change
## where anything stands.

static var _chamfer_cache: Dictionary = {}


## Default bevel for a box of this size: proportional, clamped to a range that
## reads at gameplay distance without eating small props.
static func bevel_for(size: Vector3) -> float:
	var smallest := minf(size.x, minf(size.y, size.z))
	return clampf(smallest * 0.07, 0.014, 0.085)


static func chamfer_mesh(size: Vector3, bevel := -1.0) -> Mesh:
	var b := bevel if bevel > 0.0 else bevel_for(size)
	b = minf(b, minf(size.x, minf(size.y, size.z)) * 0.32)
	var key: String = "%.3f_%.3f_%.3f_%.4f" % [size.x, size.y, size.z, b]
	if _chamfer_cache.has(key):
		return _chamfer_cache[key]

	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The point of corner (sx, sy, sz) that lies on the face of axis `a`.
	var point := func(a: int, sx: float, sy: float, sz: float) -> Vector3:
		var p := Vector3(sx * (h.x - b), sy * (h.y - b), sz * (h.z - b))
		match a:
			0: p.x = sx * h.x
			1: p.y = sy * h.y
			_: p.z = sz * h.z
		return p

	var signs := [-1.0, 1.0]

	# Six inset faces.
	for a in 3:
		var u := (a + 1) % 3
		var v := (a + 2) % 3
		for s: float in signs:
			var quad: Array[Vector3] = []
			for pair: Array in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var sg := [0.0, 0.0, 0.0]
				sg[a] = s
				sg[u] = pair[0]
				sg[v] = pair[1]
				quad.append(point.call(a, sg[0], sg[1], sg[2]))
			_emit_quad(st, quad)

	# Twelve bevel strips, one per original edge.
	for a in 3:
		for bx in range(a + 1, 3):
			var c := 3 - a - bx
			for sa: float in signs:
				for sb: float in signs:
					var quad: Array[Vector3] = []
					for sc: float in signs:
						var sg := [0.0, 0.0, 0.0]
						sg[a] = sa
						sg[bx] = sb
						sg[c] = sc
						quad.append(point.call(a, sg[0], sg[1], sg[2]))
					for sc2: float in [1.0, -1.0]:
						var sg2 := [0.0, 0.0, 0.0]
						sg2[a] = sa
						sg2[bx] = sb
						sg2[c] = sc2
						quad.append(point.call(bx, sg2[0], sg2[1], sg2[2]))
					_emit_quad(st, quad)

	# Eight corner triangles.
	for sx: float in signs:
		for sy: float in signs:
			for sz: float in signs:
				_emit_tri(st, [
					point.call(0, sx, sy, sz),
					point.call(1, sx, sy, sz),
					point.call(2, sx, sy, sz),
				], Vector3(sx, sy, sz))

	var mesh: ArrayMesh = st.commit()
	_chamfer_cache[key] = mesh
	return mesh


## Emits a quad wound so its normal points away from the origin, with a flat
## normal. Faceted on purpose — a chamfer that is smooth-shaded into its faces
## stops being an edge highlight and becomes a gradient.
static func _emit_quad(st: SurfaceTool, q: Array[Vector3]) -> void:
	var centre := (q[0] + q[1] + q[2] + q[3]) * 0.25
	var n := (q[1] - q[0]).cross(q[2] - q[0])
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Godot winds FRONT faces clockwise. Emitting the counter-clockwise order
	# here hid every outward face and left the inside of the box visible — and
	# the inside of a backlit wall faces the sun, which is why the first
	# version of this lit the whole level up like noon.
	var order := [0, 2, 1, 0, 3, 2]
	if n.dot(centre) < 0.0:
		n = -n
		order = [0, 1, 2, 0, 2, 3]
	for i: int in order:
		st.set_normal(n)
		st.set_uv(_planar_uv(q[i], n))
		st.add_vertex(q[i])


## Planar UV from the two axes the face does NOT point down. Mapping every
## face with the same formula gave the top and bottom faces a constant V, which
## is a degenerate UV chart: tangent generation returns garbage for it, and the
## garbage is enough to make the renderer light a back-facing wall as though it
## faced the sun.
static func _planar_uv(p: Vector3, n: Vector3) -> Vector2:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ax >= ay and ax >= az:
		return Vector2(p.z, -p.y)
	if ay >= az:
		return Vector2(p.x, p.z)
	return Vector2(p.x, -p.y)


static func _emit_tri(st: SurfaceTool, t: Array, outward: Vector3) -> void:
	var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var order := [0, 2, 1]
	if n.dot(outward) < 0.0:
		n = -n
		order = [0, 1, 2]
	for i: int in order:
		var p: Vector3 = t[i]
		st.set_normal(n)
		st.set_uv(_planar_uv(p, n))
		st.add_vertex(p)


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

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = chamfer_mesh(size)
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
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = chamfer_mesh(size)
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi
