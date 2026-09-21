class_name ChainForge
## Builds the chains — the trophy the whole game is about.
##
## A chain is a rope of interlocking links hanging in a catenary with a
## medallion at the low point. Consecutive links rotate 90 degrees about the
## rope, which is the only thing that makes a chain read as a chain rather than
## as a string of doughnuts.
##
## Medallion emblems are extruded 2D polygons, one per level, drawn as
## silhouettes because at trophy size a silhouette is all that survives.

## How far the rope sags, as a fraction of its span.
const SAG := 0.42


## Gold with a little more fire in it than the walking-around chain. This is
## the one that sits under a spotlight.
static func trophy_gold() -> StandardMaterial3D:
	var m := MaterialLab.gold(Color(1.0, 0.80, 0.33))
	# Polished gold is a mirror, and a mirror in a dark room is black. This is
	# brushed rather than polished: rough enough that the key spreads into a
	# broad sheen across the face, and metallic well under 1 so there is real
	# diffuse under the sheen. Physically it is a compromise; on screen it is
	# the only version that reads as gold.
	m.roughness = 0.38
	m.metallic = 0.50
	m.metallic_specular = 0.95
	m.emission_enabled = true
	m.emission = Color(0.90, 0.55, 0.14)
	m.emission_energy_multiplier = 0.55
	return m


## Unearned: the same shape in cold dead metal, so the slot reads as a chain
## you have not got rather than as an empty hole.
static func ghost_metal() -> StandardMaterial3D:
	var m := MaterialLab.chrome(Color(0.285, 0.290, 0.315), 0.70)
	m.metallic = 0.22
	m.metallic_specular = 0.30
	return m


## The rope. `span` is end-to-end width; the ends sit at y = 0 and the low
## point hangs at y = -span * SAG.
static func rope(parent: Node3D, span: float, links: int, link_r: float,
		mat: Material) -> MultiMeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = link_r * 0.62
	torus.outer_radius = link_r
	torus.rings = 18
	torus.ring_segments = 7

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = torus
	mm.instance_count = links

	for i in links:
		var t := float(i) / float(maxi(links - 1, 1))
		var p := _catenary(t, span)
		# Tangent by difference, so the links lie along the curve without
		# anyone having to differentiate a cosh by hand.
		var h := 0.5 / float(links)
		var tangent := (_catenary(minf(t + h, 1.0), span)
			- _catenary(maxf(t - h, 0.0), span)).normalized()
		# Every other link turns a quarter turn about the rope. That alternation
		# is the whole read.
		var axis := Vector3(0, 0, 1) if i % 2 == 0 \
			else Vector3(-tangent.y, tangent.x, 0.0).normalized()
		var side := tangent.cross(axis).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(tangent, axis, side), p))

	var node := MultiMeshInstance3D.new()
	node.name = "Links"
	node.multimesh = mm
	node.material_override = mat
	parent.add_child(node)
	return node


static func _catenary(t: float, span: float) -> Vector3:
	var u := (t - 0.5) * 2.0
	var c := 1.75
	var drop := span * SAG
	var y := -drop * (1.0 - (cosh(c * u) - 1.0) / (cosh(c) - 1.0))
	return Vector3(u * span * 0.5, y, 0.0)


## The whole trophy: rope, bail and medallion, built around the origin with the
## rope's ends at y = 0.
static func chain(chain_id: String, span := 1.6, earned := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Chain_" + chain_id
	var mat: Material = trophy_gold() if earned else ghost_metal()

	rope(root, span, 34, span * 0.052, mat)

	var low := _catenary(0.5, span)
	# Bail: the little ring the medallion hangs from.
	var bail := MeshInstance3D.new()
	bail.name = "Bail"
	var bt := TorusMesh.new()
	bt.inner_radius = span * 0.030
	bt.outer_radius = span * 0.055
	bt.rings = 18
	bt.ring_segments = 7
	bail.mesh = bt
	bail.material_override = mat
	bail.rotation_degrees = Vector3(90, 0, 0)
	bail.position = low + Vector3(0.0, -span * 0.045, 0.0)
	root.add_child(bail)

	var med := medallion(chain_id, span * 0.50, mat, earned)
	med.position = low + Vector3(0.0, -span * 0.09 - span * 0.25, 0.0)
	root.add_child(med)
	return root


## Enamel: the dark field the emblem sits on. A metal emblem on a metal disc
## is two of the same value and reads as a scratch; the field has to drop away.
static func enamel(earned: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.135, 0.028, 0.020) if earned else Color(0.045, 0.048, 0.058)
	m.roughness = 0.42
	m.metallic = 0.0
	m.metallic_specular = 0.6
	return m


## A disc with a raised emblem standing proud of it.
static func medallion(chain_id: String, size: float, mat: Material,
		earned := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Medallion"
	var field := enamel(earned)

	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var cyl := CylinderMesh.new()
	cyl.top_radius = size * 0.5
	cyl.bottom_radius = size * 0.5
	cyl.height = size * 0.10
	cyl.radial_segments = 40
	cyl.rings = 1
	disc.mesh = cyl
	disc.material_override = field
	disc.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(disc)

	# A raised rim, so the disc catches a highlight at its edge.
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rt := TorusMesh.new()
	rt.inner_radius = size * 0.455
	rt.outer_radius = size * 0.50
	rt.rings = 40
	rt.ring_segments = 8
	rim.mesh = rt
	rim.material_override = mat
	rim.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(rim)

	var emblem := MeshInstance3D.new()
	emblem.name = "Emblem"
	emblem.mesh = _extrude(_emblem_points(chain_id), size * 0.14)
	# Two-sided on purpose. The emblems are authored as flat outlines and a
	# triangulation can come back either way round; with culling off the shape
	# is there whichever way it is wound, and Godot flips the normal on the
	# back face so it still shades correctly.
	var emb_mat: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
	emb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	emblem.material_override = emb_mat
	emblem.scale = Vector3.ONE * size * 0.76
	# Standing proud of the face by half its own thickness, so the key throws a
	# hard shadow off it and the emblem reads as a shape rather than a scratch.
	emblem.position = Vector3(0.0, 0.0, size * 0.085)
	root.add_child(emblem)
	return root


## Emblems are drawn in a unit box centred on the origin, y up.
static func _emblem_points(chain_id: String) -> PackedVector2Array:
	match chain_id:
		"brega":
			# A flare-stack flame: the thing you can see from the coast road.
			# Deliberately lopsided — a symmetric flame reads as a teardrop.
			return PackedVector2Array([
				Vector2(0.04, 0.56), Vector2(0.10, 0.20), Vector2(0.05, 0.02),
				Vector2(0.22, -0.14), Vector2(0.17, -0.36), Vector2(0.00, -0.45),
				Vector2(-0.17, -0.36), Vector2(-0.22, -0.14), Vector2(-0.06, 0.02),
				Vector2(-0.09, 0.22),
			])
		"ajdabiya":
			# A waypoint star: the junction every road east goes through.
			var star := PackedVector2Array()
			for i in 16:
				var th: float = TAU * float(i) / 16.0 + PI * 0.5
				var r: float = 0.48 if i % 2 == 0 else 0.185
				star.append(Vector2(cos(th) * r, sin(th) * r))
			return star
		"highway":
			# A road chevron, the way the coast road is signed.
			return PackedVector2Array([
				Vector2(-0.10, 0.46), Vector2(0.34, 0.0), Vector2(-0.10, -0.46),
				Vector2(-0.34, -0.46), Vector2(0.10, 0.0), Vector2(-0.34, 0.46),
			])
		"garyounis":
			# A horseshoe arch out of the colonnade.
			var pts := PackedVector2Array()
			pts.append(Vector2(-0.30, -0.46))
			pts.append(Vector2(-0.30, 0.02))
			for i in 17:
				var th: float = PI * float(i) / 16.0
				pts.append(Vector2(-cos(th) * 0.30, 0.02 + sin(th) * 0.36))
			pts.append(Vector2(0.30, -0.46))
			pts.append(Vector2(0.16, -0.46))
			pts.append(Vector2(0.16, 0.02))
			for i in 17:
				var th2: float = PI * float(16 - i) / 16.0
				pts.append(Vector2(-cos(th2) * 0.16, 0.02 + sin(th2) * 0.22))
			pts.append(Vector2(-0.16, -0.46))
			return pts
		_:
			# Benghazi: the lighthouse on the harbour mole.
			return PackedVector2Array([
				Vector2(-0.05, 0.54), Vector2(0.05, 0.54), Vector2(0.05, 0.46),
				Vector2(0.25, 0.41), Vector2(0.19, 0.31), Vector2(0.07, 0.26),
				Vector2(0.19, -0.30), Vector2(0.32, -0.38), Vector2(0.32, -0.48),
				Vector2(-0.32, -0.48), Vector2(-0.32, -0.38), Vector2(-0.19, -0.30),
				Vector2(-0.07, 0.26), Vector2(-0.19, 0.31), Vector2(-0.25, 0.41),
				Vector2(-0.05, 0.46),
			])


## A flat polygon pushed out to a solid: front face, back face and a wall
## between them. Triangulation is the engine's, so concave emblems are fine.
static func _extrude(source: PackedVector2Array, depth: float) -> ArrayMesh:
	# Godot's front faces are counter-clockwise. The emblems are authored the
	# way you would draw them, which is clockwise, so a raw triangulation
	# renders every face inside-out and all you see is the edge wall.
	var points := source
	if _signed_area(points) < 0.0:
		var flipped := PackedVector2Array()
		for i in points.size():
			flipped.append(points[points.size() - 1 - i])
		points = flipped
	var idx := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := depth * 0.5
	var n := points.size()

	for face in 2:
		var z := half if face == 0 else -half
		var normal := Vector3(0, 0, 1) if face == 0 else Vector3(0, 0, -1)
		var i := 0
		while i < idx.size():
			var tri := [idx[i], idx[i + 1], idx[i + 2]]
			if face == 1:
				tri.reverse()
			for k: int in tri:
				var p: Vector2 = points[k]
				st.set_normal(normal)
				st.set_uv(Vector2(p.x + 0.5, 0.5 - p.y))
				st.add_vertex(Vector3(p.x, p.y, z))
			i += 3

	for i in n:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % n]
		var edge := (b - a).normalized()
		var nrm := Vector3(edge.y, -edge.x, 0.0)
		var quad := [
			Vector3(a.x, a.y, half), Vector3(b.x, b.y, half),
			Vector3(b.x, b.y, -half), Vector3(a.x, a.y, half),
			Vector3(b.x, b.y, -half), Vector3(a.x, a.y, -half),
		]
		for v: Vector3 in quad:
			st.set_normal(nrm)
			st.set_uv(Vector2(v.x + 0.5, 0.5 - v.y))
			st.add_vertex(v)

	return st.commit()


## Shoelace. Positive is counter-clockwise with y up.
static func _signed_area(points: PackedVector2Array) -> float:
	var a := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
