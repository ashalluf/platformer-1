class_name ChainForge
## Builds the chains — the trophy the whole game is about.
##
## A chain is a rope of interlocking OVAL links hanging in a catenary with a
## medallion at the low point. The oval is the whole read: a real link is
## elongated along the rope so the next one can lie inside it, and consecutive
## links turn ninety degrees about the rope. Round links spaced evenly in `t`
## are a string of beads, which is what this used to be.
##
## Medallions are turned on a lathe — outer bead, bevel, recessed enamel field —
## and then dressed with a stud border, a hallmark and a stepped emblem, because
## a trophy that is one flat disc with a decal on it is a coin.

## How far the rope sags, as a fraction of its span. Callers vary it per chain:
## five identical curves in a row is the tell that nobody hung them by hand.
const SAG := 0.42

## Canon order, here only so a medallion can stamp its own number.
const ORDER := ["brega", "ajdabiya", "highway", "garyounis", "benghazi"]
const ARABIC_DIGITS := ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]

## Meshes are shared across every chain in the row: five chains of the same
## span want the same link, and a MultiMesh only ever needs one copy.
static var _mesh_cache: Dictionary = {}


# --- Metals -----------------------------------------------------------------

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


## Case furniture: rail collars, frames, engraved tags. Deliberately duller and
## browner than the trophy gold — the fittings hold the trophies, they do not
## compete with them.
static func brass(tint := Color(0.58, 0.44, 0.21)) -> StandardMaterial3D:
	var m := MaterialLab.gold(tint)
	m.roughness = 0.44
	m.metallic = 0.62
	m.metallic_specular = 0.75
	return m


## Enamel: the dark field the emblem sits on. A metal emblem on a metal disc
## is two of the same value and reads as a scratch; the field has to drop away.
static func enamel(earned: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.135, 0.028, 0.020) if earned else Color(0.045, 0.048, 0.058)
	m.roughness = 0.42
	m.metallic = 0.0
	m.metallic_specular = 0.6
	return m


## The number stamped on a medallion's bevel, in Eastern Arabic numerals.
static func hallmark_of(chain_id: String) -> String:
	var i: int = ORDER.find(chain_id)
	return ARABIC_DIGITS[i + 1] if i >= 0 and i < 9 else ""


# --- The rope ---------------------------------------------------------------

## One link: round wire swept round an oval. Authored with the hole along local
## +Y and the long axis along local +X, so `rope` can map +X onto the curve
## tangent and +Y onto whichever way this link is turned.
static func link_mesh(long_r: float, short_r: float, wire_r: float,
		seg := 26, sides := 7) -> ArrayMesh:
	var key := "link_%.4f_%.4f_%.4f" % [long_r, short_r, wire_r]
	if _mesh_cache.has(key):
		return _mesh_cache[key]

	var up := Vector3(0.0, 1.0, 0.0)
	var centres: Array[Vector3] = []
	var outs: Array[Vector3] = []
	for i in seg + 1:
		var a := TAU * float(i) / float(seg)
		centres.append(Vector3(cos(a) * long_r, 0.0, sin(a) * short_r))
		var tang := Vector3(-sin(a) * long_r, 0.0, cos(a) * short_r).normalized()
		# up x tangent, not the other way round: this one points away from the
		# oval's centre, which is what "outward" has to mean for the normals.
		outs.append(up.cross(tang).normalized())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		for b in sides:
			var b2 := (b + 1) % sides
			var ring := [[i, b], [i + 1, b], [i + 1, b2], [i, b2]]
			# Godot's front face is CLOCKWISE seen from the outside, so this
			# order is the one whose right-hand normal points INTO the wire.
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				for k: int in tri:
					var pair: Array = ring[k]
					var ci: int = pair[0]
					var th := TAU * float(pair[1]) / float(sides)
					var nrm: Vector3 = outs[ci] * cos(th) + up * sin(th)
					st.set_normal(nrm)
					st.set_uv(Vector2(float(ci) / seg, float(pair[1]) / sides))
					st.add_vertex(centres[ci] + nrm * wire_r)

	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## The rope. `span` is end-to-end width; the ends sit at y = 0 and the low
## point hangs at y = -span * sag.
static func rope(parent: Node3D, span: float, link_r: float, mat: Material,
		sag := SAG) -> MultiMeshInstance3D:
	var long_r := link_r * 1.38
	var short_r := link_r * 0.76
	var wire_r := link_r * 0.30

	# Links are placed by ARC LENGTH, not by an even split of the curve
	# parameter. A catenary is steeper at the ends than in the middle, so an
	# even split in t crowds the links together at the low point and stretches
	# them apart at the rail — which is exactly backwards.
	var table := _arc_table(span, sag)
	var total: float = table[table.size() - 1]
	# A real chain advances by roughly its inner length each link. Any looser
	# and the links stop touching; any tighter and the rope turns into a tube.
	var pitch := (long_r - wire_r) * 1.66
	var count := maxi(int(round(total / pitch)), 8)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link_mesh(long_r, short_r, wire_r)
	mm.instance_count = count

	for i in count:
		var s := total * float(i) / float(count - 1)
		var t := _t_at(table, s)
		var p := _catenary(t, span, sag)
		# Tangent by difference, so the links lie along the curve without
		# anyone having to differentiate a cosh by hand.
		var h := 0.5 / float(count)
		var tangent := (_catenary(minf(t + h, 1.0), span, sag)
			- _catenary(maxf(t - h, 0.0), span, sag)).normalized()
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


const _ARC_SAMPLES := 160


## Cumulative arc length along the catenary, sampled in t.
static func _arc_table(span: float, sag: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append(0.0)
	var prev := _catenary(0.0, span, sag)
	for i in range(1, _ARC_SAMPLES + 1):
		var p := _catenary(float(i) / float(_ARC_SAMPLES), span, sag)
		out.append(out[i - 1] + p.distance_to(prev))
		prev = p
	return out


## Invert the arc table: which t is `s` metres along the rope.
static func _t_at(table: PackedFloat32Array, s: float) -> float:
	var n := table.size() - 1
	for i in n:
		if table[i + 1] >= s:
			var seg := table[i + 1] - table[i]
			var f := 0.0 if seg <= 0.0 else (s - table[i]) / seg
			return (float(i) + f) / float(n)
	return 1.0


static func _catenary(t: float, span: float, sag := SAG) -> Vector3:
	var u := (t - 0.5) * 2.0
	var c := 1.75
	var drop := span * sag
	var y := -drop * (1.0 - (cosh(c * u) - 1.0) / (cosh(c) - 1.0))
	return Vector3(u * span * 0.5, y, 0.0)


## The clasp, up near the right-hand end where a real one would sit. Nobody
## will read it as a lobster claw at this size — what it does is break the
## perfect symmetry of the two ends, which is what stops the chain looking
## like a decal.
static func _clasp(parent: Node3D, span: float, link_r: float, mat: Material,
		sag: float) -> void:
	var t := 0.915
	var p := _catenary(t, span, sag)
	var tangent := (_catenary(t + 0.01, span, sag)
		- _catenary(t - 0.01, span, sag)).normalized()

	var barrel := MeshInstance3D.new()
	barrel.name = "Clasp"
	var cyl := CylinderMesh.new()
	cyl.top_radius = link_r * 0.52
	cyl.bottom_radius = link_r * 0.52
	cyl.height = link_r * 2.9
	cyl.radial_segments = 12
	cyl.rings = 1
	barrel.mesh = cyl
	barrel.material_override = mat
	# CylinderMesh stands on Y; lie it along the rope.
	barrel.basis = Basis(tangent.cross(Vector3.FORWARD).normalized(), tangent,
		Vector3.FORWARD)
	barrel.position = p
	parent.add_child(barrel)

	var collar := MeshInstance3D.new()
	collar.name = "ClaspRing"
	var tor := TorusMesh.new()
	tor.inner_radius = link_r * 0.56
	tor.outer_radius = link_r * 0.82
	tor.rings = 16
	tor.ring_segments = 6
	collar.mesh = tor
	collar.material_override = mat
	collar.basis = barrel.basis
	collar.position = p + tangent * link_r * 1.15
	parent.add_child(collar)


## The whole trophy: rope, clasp, bail and medallion, built around the origin
## with the rope's ends at y = 0. Everything below the rope's low point hangs
## off a `Sway` pivot, so the medallion is never quite still.
static func chain(chain_id: String, span := 1.6, earned := true,
		sag := SAG) -> Node3D:
	var root := Node3D.new()
	root.name = "Chain_" + chain_id
	var mat: Material = trophy_gold() if earned else ghost_metal()
	var link_r := span * 0.042

	rope(root, span, link_r, mat, sag)
	_clasp(root, span, link_r, mat, sag)

	# The pendulum. A chain draped over a rail does not swing as a whole — the
	# rope is pinned at both ends and only the weight underneath moves.
	var pivot := Sway.new()
	pivot.name = "Pendulum"
	pivot.axis = Vector3(0.0, 0.0, 1.0)
	pivot.amplitude = 0.046
	pivot.speed = 0.44
	pivot.gust_amplitude = 0.017
	pivot.gust_speed = 1.31
	pivot.position = _catenary(0.5, span, sag)
	root.add_child(pivot)

	# Bail: the ring the medallion hangs from, turned face-on to the camera.
	var bail := MeshInstance3D.new()
	bail.name = "Bail"
	var bt := TorusMesh.new()
	bt.inner_radius = span * 0.030
	bt.outer_radius = span * 0.055
	bt.rings = 20
	bt.ring_segments = 8
	bail.mesh = bt
	bail.material_override = mat
	bail.rotation_degrees = Vector3(90, 0, 0)
	bail.position = Vector3(0.0, -span * 0.045, 0.0)
	pivot.add_child(bail)

	# The medallion's own loop, so the disc is attached to the bail rather than
	# floating under it.
	var loop := MeshInstance3D.new()
	loop.name = "Loop"
	var lt := TorusMesh.new()
	lt.inner_radius = span * 0.018
	lt.outer_radius = span * 0.038
	lt.rings = 16
	lt.ring_segments = 6
	loop.mesh = lt
	loop.material_override = mat
	loop.rotation_degrees = Vector3(90, 0, 0)
	loop.position = Vector3(0.0, -span * 0.098, 0.0)
	pivot.add_child(loop)

	var med := medallion(chain_id, span * 0.50, mat, earned,
		hallmark_of(chain_id))
	med.position = Vector3(0.0, -span * 0.34, 0.0)
	pivot.add_child(med)
	return root


# --- The medallion ----------------------------------------------------------

## The medallion body, as a profile turned on a lathe: back, chamfer, outer
## edge, bead, bevel, and a field recessed well below all of it. Radii are in
## half-diameters, depths in the same unit, so the whole thing scales with
## `size`. A stack of cylinders cannot do the bead, and the bead is where the
## key light lands.
## (a static var rather than a const: a PackedVector2Array literal is not a
## constant expression to the parser.)
static var _MEDAL_PROFILE := PackedVector2Array([
	Vector2(0.000, -0.115), Vector2(0.720, -0.115), Vector2(0.880, -0.095),
	Vector2(0.970, -0.045), Vector2(1.000, 0.010), Vector2(0.985, 0.075),
	Vector2(0.925, 0.112), Vector2(0.855, 0.098), Vector2(0.815, 0.050),
	Vector2(0.790, 0.010), Vector2(0.785, -0.030), Vector2(0.000, -0.030),
])


## A disc with a raised emblem standing proud of it. `size` is the diameter.
static func medallion(chain_id: String, size: float, mat: Material,
		earned := true, hallmark := "") -> Node3D:
	var root := Node3D.new()
	root.name = "Medallion"
	var field := enamel(earned)
	var radius := size * 0.5

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _lathe(_MEDAL_PROFILE, radius)
	body.material_override = mat
	root.add_child(body)

	# The enamel, laid into the recess so its rim is a real step rather than a
	# change of colour.
	var disc := MeshInstance3D.new()
	disc.name = "Field"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.775
	cyl.bottom_radius = radius * 0.775
	cyl.height = size * 0.012
	cyl.radial_segments = 44
	cyl.rings = 1
	disc.mesh = cyl
	disc.material_override = field
	disc.rotation_degrees = Vector3(90, 0, 0)
	disc.position = Vector3(0.0, 0.0, -radius * 0.012)
	root.add_child(disc)

	_stud_border(root, radius, mat)

	var emblem := MeshInstance3D.new()
	emblem.name = "Emblem"
	# Relief, not a flat cut-out: a base plus an inset upper plate, so the key
	# gets two different surfaces to land on and the emblem casts onto itself.
	emblem.mesh = relief(_emblem_points(chain_id), 0.090, 0.042)
	# Two-sided on purpose. The emblems are authored as flat outlines and the
	# triangulator can come back either way round on the self-touching ones;
	# with culling off the shape is there whichever way it is wound.
	var emb_mat: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
	emb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	emblem.material_override = emb_mat
	emblem.scale = Vector3.ONE * size * 0.72
	emblem.position = Vector3(0.0, 0.0, -radius * 0.022)
	root.add_child(emblem)

	if hallmark != "":
		_hallmark(root, radius, hallmark, earned)

	return root


## The border. Thirty little pyramid studs standing in the channel between the
## bevel and the bead — one MultiMesh, so the whole ring costs one draw.
static func _stud_border(root: Node3D, radius: float, mat: Material) -> void:
	var count := 30
	var stud_r := radius * 0.062
	var key := "stud_%.4f" % stud_r
	var mesh: Mesh
	if _mesh_cache.has(key):
		mesh = _mesh_cache[key]
	else:
		var sphere := SphereMesh.new()
		# Four segments and two rings is a bipyramid, which is a cut stone seen
		# from the front. A round bead at this size is a dot.
		sphere.radial_segments = 4
		sphere.rings = 2
		sphere.radius = stud_r
		sphere.height = stud_r * 1.9
		mesh = sphere
		_mesh_cache[key] = mesh

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var a := TAU * float(i) / float(count)
		var p := Vector3(cos(a) * radius * 0.858, sin(a) * radius * 0.858,
			radius * 0.100)
		# SphereMesh stands on Y; tip the point at the camera. Z is X cross Y
		# and nothing else — a left-handed basis mirrors the stud inside out.
		mm.set_instance_transform(i, Transform3D(
			Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), p))

	var node := MultiMeshInstance3D.new()
	node.name = "Studs"
	node.multimesh = mm
	node.material_override = mat
	root.add_child(node)


## A maker's mark on the lower bevel. It is four pixels tall on screen and that
## is the point: real trophies carry marks nobody reads, and their absence is
## one of the things that makes a rendered object look printed.
static func _hallmark(root: Node3D, radius: float, text: String,
		earned: bool) -> void:
	var tm := TextMesh.new()
	tm.text = text
	tm.font = PropKit.font(PropKit.FONT_KUFI)
	tm.font_size = 96
	tm.pixel_size = radius * 0.115 / 96.0
	tm.depth = radius * 0.012
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var mi := MeshInstance3D.new()
	mi.name = "Hallmark"
	mi.mesh = tm
	var stamp := enamel(earned)
	stamp.albedo_color = stamp.albedo_color.darkened(0.45)
	stamp.roughness = 0.30
	mi.material_override = stamp
	mi.position = Vector3(0.0, -radius * 0.905, radius * 0.045)
	root.add_child(mi)


# --- Geometry helpers -------------------------------------------------------

## A surface of revolution about the local Z axis. `profile` is (radius, z) in
## units of `scale_`, walked from the back centre outward, over the rim and
## back in to the front centre. Normals come out of the profile tangent and are
## averaged across each joint, so a bevel shades as a bevel and not as a facet.
static func _lathe(profile: PackedVector2Array, scale_: float,
		segments := 48) -> ArrayMesh:
	var key := "lathe_%.4f_%d" % [scale_, profile.size()]
	if _mesh_cache.has(key):
		return _mesh_cache[key]

	var n := profile.size()
	var pn := PackedVector2Array()
	for k in n:
		var acc := Vector2.ZERO
		if k > 0:
			var d := profile[k] - profile[k - 1]
			if d.length() > 0.0001:
				acc += Vector2(d.y, -d.x).normalized()
		if k < n - 1:
			var d2 := profile[k + 1] - profile[k]
			if d2.length() > 0.0001:
				acc += Vector2(d2.y, -d2.x).normalized()
		pn.append(acc.normalized() if acc.length() > 0.0001 else Vector2(0.0, 1.0))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n - 1:
		for s in segments:
			var a0 := TAU * float(s) / float(segments)
			var a1 := TAU * float(s + 1) / float(segments)
			var quad := [[k, a0], [k + 1, a0], [k + 1, a1], [k, a1]]
			# Same rule as everywhere else: right-hand normal points inward, so
			# the face Godot keeps is the one facing out.
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				for j: int in tri:
					var kk: int = quad[j][0]
					var aa: float = quad[j][1]
					var r: float = profile[kk].x * scale_
					st.set_normal(Vector3(pn[kk].x * cos(aa), pn[kk].x * sin(aa),
						pn[kk].y))
					st.set_uv(Vector2(aa / TAU, float(kk) / float(n - 1)))
					st.add_vertex(Vector3(r * cos(aa), r * sin(aa),
						profile[kk].y * scale_))

	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A flat outline pushed out to a solid with a stepped top: the base carries
## the silhouette, the inset plate on top carries a second highlight. Used for
## the emblems and, by the map, for its inlays.
static func relief(source: PackedVector2Array, depth: float,
		inset: float) -> ArrayMesh:
	var points := _wound_ccw(source)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_extrude_into(st, points, 0.0, depth * 0.58)
	# Offset rather than scale. The arch emblem is a ring, and scaling a ring
	# about its centre closes the hole it is made of.
	for poly: PackedVector2Array in _inset_polygon(points, inset):
		_extrude_into(st, _wound_ccw(poly), depth * 0.52, depth)
	return st.commit()


## Shrink a polygon by `inset`. Which sign of delta shrinks depends on the
## winding Clipper decides the polygon has, so try one and check the area
## rather than trusting it; a result that is not plausibly a smaller version of
## the input is thrown away and the emblem just stays a single step.
static func _inset_polygon(points: PackedVector2Array,
		inset: float) -> Array[PackedVector2Array]:
	var source_area := absf(_signed_area(points))
	var out: Array[PackedVector2Array] = []
	for delta: float in [-inset, inset]:
		var tried := Geometry2D.offset_polygon(points, delta, Geometry2D.JOIN_MITER)
		var area := 0.0
		for poly: PackedVector2Array in tried:
			if poly.size() >= 3:
				area += absf(_signed_area(poly))
		if area > source_area * 0.30 and area < source_area * 0.94:
			for poly: PackedVector2Array in tried:
				if poly.size() >= 3:
					out.append(poly)
			return out
	return out


## Front face, back face and the wall between them, between two z planes.
static func _extrude_into(st: SurfaceTool, points: PackedVector2Array,
		z0: float, z1: float) -> void:
	var idx := Geometry2D.triangulate_polygon(points)
	if idx.is_empty():
		return
	var n := points.size()

	for face in 2:
		var z := z1 if face == 0 else z0
		var normal := Vector3(0, 0, 1) if face == 0 else Vector3(0, 0, -1)
		var i := 0
		while i < idx.size():
			var tri := [idx[i], idx[i + 1], idx[i + 2]]
			# The points are wound counter-clockwise, so the front face has to
			# be reversed to be clockwise-from-the-front the way Godot wants.
			if face == 0:
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
			Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(b.x, b.y, z0),
			Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z0), Vector3(a.x, a.y, z0),
		]
		for v: Vector3 in quad:
			st.set_normal(nrm)
			st.set_uv(Vector2(v.x + 0.5, 0.5 - v.y))
			st.add_vertex(v)


static func _wound_ccw(source: PackedVector2Array) -> PackedVector2Array:
	if _signed_area(source) >= 0.0:
		return source
	var flipped := PackedVector2Array()
	for i in source.size():
		flipped.append(source[source.size() - 1 - i])
	return flipped


## Shoelace. Positive is counter-clockwise with y up.
static func _signed_area(points: PackedVector2Array) -> float:
	var a := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


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
