class_name DetailKit
## The small-and-medium industrial and civic detail library.
##
## PropKit builds the big forms — facades, tanks, towers, perimeter walls. This
## file is everything that hangs off them: pipework with real ends on it, cable
## trays, ladders, grating, handrails, signage, switchgear, drainage, rubble and
## scaffold. It is the difference between a massing model and a plant someone
## used to work in.
##
## Three rules govern everything here.
##
## ONE — IT IS READ IN PROFILE. The camera sits side-on at z ~ +16 looking down
## -Z and gameplay is on the XY plane, so an object's silhouette in X and Y is
## all the player ever gets. Anything whose character lives in plan — a flange
## bolt ring, a hand-wheel, a ladder cage hoop — is tilted, stood off the wall
## or oversized until it reads as a shape instead of a line.
##
## TWO — 70 mm IS THE FLOOR. At 10–40 world units a member thinner than about
## 70 mm falls between pixels and the object goes bald. Every tube, rail, rung
## and bar in this file is built two to three times heavier than the real
## component on purpose. Where that is a big lie the comment says so.
##
## THREE — NOTHING ENDS IN MID-AIR. A pipe stops at a flange, a blank or a
## valve. A rail stops at a return or a post. A conduit stops in a box. An
## unterminated run is the loudest greybox tell there is, which is why half of
## this file is ends.
##
## Everything here is decorative. Collision is the level builder's business,
## exactly as in PropKit.
##
## Determinism: every builder that randomises seeds its RNG from its own world
## position, so a level rebuilds pixel-identical every run while two copies of
## the same prop in one level are still different objects.


# --- Shared plumbing --------------------------------------------------------

static func _mi(parent: Node3D, name_: String, mesh: Mesh, mat: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Chamfered, always. There is no BoxMesh in this project: a hard ninety-degree
## edge has no highlight on it, and an edge highlight is how a shape survives
## being small and in shade.
static func _box(size: Vector3) -> Mesh:
	return LevelKit.chamfer_mesh(size)


static func _cyl(radius: float, height: float, sides := 10, top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


static func _mm(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	return mm


static func _fill(mm: MultiMesh, xforms: Array[Transform3D]) -> void:
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])


static func _mm_node(parent: Node3D, name_: String, mm: MultiMesh,
		mat: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = mm
	if mat:
		node.material_override = mat
	parent.add_child(node)
	return node


static func _root(parent: Node3D, name_: String, at := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = at
	parent.add_child(n)
	return n


## A basis whose local +Y runs down `dir` — the axis a CylinderMesh is built on.
## The other two axes are arbitrary but stable, which is all a tube needs.
static func _basis_from_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	if y.length_squared() < 0.5:
		return Basis.IDENTITY
	var ref := Vector3.BACK if absf(y.dot(Vector3.UP)) > 0.985 else Vector3.UP
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## A basis with local +X along `along` and local +Y as close to `up` as it can
## get. Used by anything that has both a run direction and an up — a valve body,
## a cable tray, a drain.
static func _basis_frame(along: Vector3, up := Vector3.UP) -> Basis:
	var x := along.normalized()
	if x.length_squared() < 0.5:
		return Basis.IDENTITY
	var y := up.normalized()
	if absf(y.dot(x)) > 0.985:
		y = Vector3.BACK if absf(x.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	y = (y - x * y.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


## Deterministic per-position RNG. Quantised to 1/8 of a unit so a caller that
## recomputes the same position by a slightly different floating-point route
## still lands on the same seed and the level does not shimmer between runs.
static func _rng(at: Vector3, salt := 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var k := Vector3i(roundi(at.x * 8.0), roundi(at.y * 8.0), roundi(at.z * 8.0))
	rng.seed = absi(hash(k) + salt * 7919)
	return rng


## A cylinder spanning two points. The workhorse: nearly every tube in this file
## is one of these.
static func _segment(parent: Node3D, name_: String, from: Vector3, to: Vector3,
		radius: float, mat: Material, sides := 10) -> MeshInstance3D:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return null
	var mi := _mi(parent, name_, _cyl(radius, length, sides), mat)
	mi.transform = Transform3D(_basis_from_y(delta), (from + to) * 0.5)
	return mi


## A flat plate spanning two points, standing `height` in the plane that
## contains the run and world up. Toe plates, kick rails, fascias.
static func _plate_between(parent: Node3D, name_: String, from: Vector3, to: Vector3,
		height: float, thickness: float, mat: Material) -> MeshInstance3D:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return null
	var mi := _mi(parent, name_, _box(Vector3(thickness, length, height)), mat)
	mi.transform = Transform3D(_basis_from_y(delta), (from + to) * 0.5)
	return mi


## A ring of bolt heads in the local XZ plane, poking proud of both faces.
## `count` is almost always 8 or more, so it is a MultiMesh.
static func _bolt_ring(parent: Node3D, ring_r: float, count: int, mat: Material,
		bolt_r := 0.045, bolt_h := 0.22, name_ := "Bolts") -> MultiMeshInstance3D:
	var mm := _mm(_cyl(bolt_r, bolt_h, 6))
	var xf: Array[Transform3D] = []
	for i in maxi(count, 3):
		var a := TAU * float(i) / float(maxi(count, 3))
		xf.append(Transform3D(Basis.IDENTITY,
			Vector3(cos(a) * ring_r, 0.0, sin(a) * ring_r)))
	_fill(mm, xf)
	return _mm_node(parent, name_, mm, mat)


# --- Pipework ---------------------------------------------------------------

## A bolted flange: plate, hub and bolt ring, built around `axis`.
##
## 90 mm of plate on a 150 mm pipe is about twice a real raised-face flange, and
## the bolt heads are nearer M36 than M16. It is deliberate. A flange is the one
## piece of detail that turns a cylinder into pipework, and at gameplay distance
## the correct one is a faint dark line.
static func flange(parent: Node3D, at: Vector3, radius: float, mat: Material,
		axis := Vector3.RIGHT, bolts := 8, name_ := "Flange") -> Node3D:
	var root := _root(parent, name_)
	root.transform = Transform3D(_basis_from_y(axis), at)
	var face_r := radius * 1.5 + 0.06
	_mi(root, "Plate", _cyl(face_r, 0.09, 14), mat)
	_mi(root, "Hub", _cyl(radius * 1.2, 0.20, 12), mat)
	_bolt_ring(root, face_r * 0.76, bolts, mat)
	return root


## A blanked-off end: flange plus the disc bolted to it. This is how a dead run
## is allowed to stop.
static func pipe_blank(parent: Node3D, at: Vector3, radius: float, mat: Material,
		axis := Vector3.RIGHT) -> Node3D:
	var root := flange(parent, at, radius, mat, axis, 8, "Blank")
	_mi(root, "Disc", _cyl(radius * 1.5 + 0.06, 0.10, 14), mat, Vector3(0.0, 0.10, 0.0))
	return root


## A straight pipe with ends on it, and optionally lagging, mid-run flanged
## joints and shoe supports.
##
## opts: flanges (bool, default true), bolts (int), joints (int, intermediate
## flanged joints), sides (int), lagged (bool, aluminium jacketing with bands),
## lag_mat (Material), supports (int), support_mat (Material),
## support_to_y (float — legs drop to this height), name (String).
static func pipe_run(parent: Node3D, from: Vector3, to: Vector3, radius: float,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "PipeRun")))
	var delta := to - from
	var length := delta.length()
	if length < 0.01:
		return root
	var dir := delta / length
	var sides: int = int(opts.get("sides", 12))
	var pipe := _mi(root, "Pipe", _cyl(radius, length, sides), mat)
	pipe.transform = Transform3D(_basis_from_y(dir), (from + to) * 0.5)

	# Lagging: mineral wool under dented aluminium, banded every metre. Bands
	# are the read — a smooth fat cylinder is just a fatter pipe.
	if bool(opts.get("lagged", false)):
		var lag_mat: Material = opts.get("lag_mat", mat)
		var lag := _mi(root, "Lagging", _cyl(radius * 1.45, length * 0.92, sides), lag_mat)
		lag.transform = Transform3D(_basis_from_y(dir), (from + to) * 0.5)
		var bands := maxi(2, int(length / 1.1))
		var band_mm := _mm(_cyl(radius * 1.52, 0.07, sides))
		var band_xf: Array[Transform3D] = []
		var band_basis := _basis_from_y(dir)
		for i in bands:
			var t := (float(i) + 0.5) / float(bands)
			band_xf.append(Transform3D(band_basis, from + delta * t))
		_fill(band_mm, band_xf)
		_mm_node(root, "LagBands", band_mm, mat)

	var bolts: int = int(opts.get("bolts", 8))
	if bool(opts.get("flanges", true)):
		flange(root, from + dir * 0.07, radius, mat, dir, bolts, "FlangeA")
		flange(root, to - dir * 0.07, radius, mat, dir, bolts, "FlangeB")

	# Mid-run joints: pipe arrives on site in spools and every spool end is a
	# pair of flanges bolted face to face.
	var joints: int = int(opts.get("joints", 0))
	for i in joints:
		var t := float(i + 1) / float(joints + 1)
		var p := from + delta * t
		flange(root, p - dir * 0.07, radius, mat, dir, bolts, "Joint%dA" % i)
		flange(root, p + dir * 0.07, radius, mat, dir, bolts, "Joint%dB" % i)

	var supports: int = int(opts.get("supports", 0))
	if supports > 0:
		var smat: Material = opts.get("support_mat", mat)
		var has_floor: bool = opts.has("support_to_y")
		var floor_y: float = float(opts.get("support_to_y", 0.0))
		for i in supports:
			var t := (float(i) + 0.5) / float(supports)
			var p := from + delta * t
			# The shoe: the welded saddle the pipe actually sits on. Without it
			# the pipe floats through its support.
			_mi(root, "Shoe%d" % i, _box(Vector3(radius * 1.9, 0.14, radius * 2.6)),
				smat, p - Vector3(0.0, radius + 0.06, 0.0))
			if not has_floor:
				continue
			var drop := (p.y - radius - 0.13) - floor_y
			if drop <= 0.2:
				continue
			_mi(root, "Stand%d" % i, _box(Vector3(0.16, drop, 0.16)), smat,
				Vector3(p.x, floor_y + drop * 0.5, p.z))
			_mi(root, "Pad%d" % i, _box(Vector3(0.44, 0.12, 0.44)), smat,
				Vector3(p.x, floor_y + 0.06, p.z))
	return root


## A mitred bend. Real large-bore elbows are pressed, but a mitre — short
## straights welded at an angle, each weld a visible bead — is what an
## as-built plant is full of, and it is cheaper geometry as well.
##
## opts: bend_radius (float), segments (int, default 4), flanges (bool),
## welds (bool).
static func pipe_elbow(parent: Node3D, at: Vector3, radius: float, mat: Material,
		in_dir: Vector3, out_dir: Vector3, opts := {}) -> Node3D:
	var root := _root(parent, "PipeElbow")
	var a := in_dir.normalized()
	var b := out_dir.normalized()
	var axis := a.cross(b)
	if axis.length_squared() < 1.0e-6:
		# Straight through, or a reversal we cannot bend. Give the caller a
		# sleeve rather than nothing, so a bad polyline never leaves a gap.
		_segment(root, "Sleeve", at - a * radius * 1.6, at + b * radius * 1.6,
			radius * 1.08, mat, 12)
		return root
	axis = axis.normalized()
	var theta := acos(clampf(a.dot(b), -1.0, 1.0))
	var bend_r: float = float(opts.get("bend_radius", radius * 2.0))
	var segs: int = maxi(2, int(opts.get("segments", 4)))
	var tangent := bend_r * tan(theta * 0.5)
	var chord := 2.0 * bend_r * sin(theta / (2.0 * float(segs)))

	var p := at - a * tangent
	var start := p
	for i in segs:
		var d := a.rotated(axis, theta * (float(i) + 0.5) / float(segs))
		var q := p + d * chord
		_segment(root, "Mitre%d" % i, p, q, radius, mat, 12)
		if i > 0 and bool(opts.get("welds", true)):
			# The weld bead at each mitre joint. Two centimetres of proud ring
			# per joint is what separates a bend from a bent noodle.
			var weld := _mi(root, "Weld%d" % i, _cyl(radius * 1.10, 0.10, 12), mat)
			weld.transform = Transform3D(_basis_from_y(d), p)
		p = q
	if bool(opts.get("flanges", false)):
		flange(root, start - a * 0.07, radius, mat, a, 8, "ElbowFlangeA")
		flange(root, p + b * 0.07, radius, mat, b, 8, "ElbowFlangeB")
	return root


## A pipe polyline: straights, mitred bends at every interior vertex, and a
## chosen termination at each free end. THIS is the function a level builder
## should reach for. A pipe that just stops is the thing that says greybox, and
## the only way to stop that happening everywhere is to make the terminated
## version the easy one to call.
##
## opts: bend_radius, sides, lagged, lag_mat, supports_per_run (int),
## support_mat, support_to_y, start_cap / end_cap in {"flange", "blank",
## "none"}, name.
static func pipe_path(parent: Node3D, points: Array, radius: float,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "PipePath")))
	if points.size() < 2:
		return root

	var pts: Array[Vector3] = []
	for p: Vector3 in points:
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.01:
			pts.append(p)
	if pts.size() < 2:
		return root

	var bend_r: float = float(opts.get("bend_radius", radius * 2.0))
	# Tangent length eaten by the bend at each interior vertex, clamped so a
	# tight corner between two short runs cannot eat more pipe than there is.
	var tan_len: Array[float] = []
	tan_len.resize(pts.size())
	for i in pts.size():
		tan_len[i] = 0.0
	for i in range(1, pts.size() - 1):
		var a := (pts[i] - pts[i - 1]).normalized()
		var b := (pts[i + 1] - pts[i]).normalized()
		var theta := acos(clampf(a.dot(b), -1.0, 1.0))
		if theta < 0.02:
			continue
		var t := bend_r * tan(minf(theta, 2.7) * 0.5)
		var room := minf(pts[i].distance_to(pts[i - 1]), pts[i].distance_to(pts[i + 1])) * 0.45
		tan_len[i] = minf(t, room)

	var run_opts := {
		"flanges": false,
		"sides": opts.get("sides", 12),
		"lagged": opts.get("lagged", false),
		"lag_mat": opts.get("lag_mat", mat),
		"supports": opts.get("supports_per_run", 0),
		"support_mat": opts.get("support_mat", mat),
	}
	if opts.has("support_to_y"):
		run_opts["support_to_y"] = opts["support_to_y"]

	for i in pts.size() - 1:
		var d := (pts[i + 1] - pts[i]).normalized()
		var a := pts[i] + d * tan_len[i]
		var b := pts[i + 1] - d * tan_len[i + 1]
		if a.distance_to(b) < 0.02:
			continue
		run_opts["name"] = "Run%d" % i
		pipe_run(root, a, b, radius, mat, run_opts)

	for i in range(1, pts.size() - 1):
		if tan_len[i] <= 0.0:
			continue
		pipe_elbow(root, pts[i], radius, mat,
			(pts[i] - pts[i - 1]).normalized(), (pts[i + 1] - pts[i]).normalized(),
			{"bend_radius": bend_r})

	var first_dir := (pts[1] - pts[0]).normalized()
	var last_dir := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	_terminate(root, pts[0], radius, mat, -first_dir, str(opts.get("start_cap", "flange")))
	_terminate(root, pts[pts.size() - 1], radius, mat, last_dir,
		str(opts.get("end_cap", "flange")))
	return root


static func _terminate(root: Node3D, at: Vector3, radius: float, mat: Material,
		outward: Vector3, kind: String) -> void:
	match kind:
		"blank":
			pipe_blank(root, at - outward * 0.07, radius, mat, outward)
		"none":
			pass
		_:
			flange(root, at - outward * 0.07, radius, mat, outward, 8, "EndFlange")


## An equal tee: the run sleeve, a branch, a weld collar and a blank on the
## branch unless the caller is taking it somewhere.
##
## opts: branch_radius (float), open (bool — leave the branch unblanked),
## sides (int).
static func pipe_tee(parent: Node3D, at: Vector3, radius: float, mat: Material,
		run_dir := Vector3.RIGHT, branch_dir := Vector3.UP, branch_len := 1.2,
		opts := {}) -> Node3D:
	var root := _root(parent, "PipeTee")
	var rd := run_dir.normalized()
	var bd := branch_dir.normalized()
	var br: float = float(opts.get("branch_radius", radius * 0.78))
	var sides: int = int(opts.get("sides", 12))

	_segment(root, "Sleeve", at - rd * radius * 1.7, at + rd * radius * 1.7,
		radius * 1.09, mat, sides)
	_segment(root, "Branch", at, at + bd * branch_len, br, mat, sides)
	# The set-on weld collar where the branch meets the header.
	var collar := _mi(root, "Collar", _cyl(br * 1.6, 0.12, 12), mat)
	collar.transform = Transform3D(_basis_from_y(bd), at + bd * (radius * 0.9))
	if not bool(opts.get("open", false)):
		pipe_blank(root, at + bd * (branch_len + 0.07), br, mat, bd)
	return root


## A hand-operated valve: body, bonnet, stem, hand-wheel and end flanges.
##
## The wheel is tilted. A hand-wheel on a vertical stem is dead flat in the
## world and therefore a one-pixel line in a side-on camera. Twenty degrees of
## tilt costs nothing, buys an ellipse with spokes in it, and reads instantly as
## a valve. It is a cheat and it is worth it.
##
## opts: axis (Vector3 flow direction), stem (Vector3), wheel_radius (float),
## wheel_tilt (float radians), stem_height (float), tag (bool), gearbox (bool).
static func valve(parent: Node3D, at: Vector3, radius: float, body_mat: Material,
		wheel_mat: Material, opts := {}) -> Node3D:
	var axis: Vector3 = opts.get("axis", Vector3.RIGHT)
	var stem: Vector3 = opts.get("stem", Vector3.UP)
	var root := _root(parent, "Valve")
	root.transform = Transform3D(_basis_frame(axis, stem), at)

	_mi(root, "Body", _box(Vector3(radius * 2.4, radius * 2.3, radius * 2.5)), body_mat)
	_mi(root, "Belly", _cyl(radius * 1.35, radius * 2.2, 12), body_mat,
		Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5))
	flange(root, Vector3(radius * 1.45, 0.0, 0.0), radius, body_mat, Vector3.RIGHT, 8, "EndA")
	flange(root, Vector3(-radius * 1.45, 0.0, 0.0), radius, body_mat, Vector3.LEFT, 8, "EndB")

	var stem_h: float = float(opts.get("stem_height", radius * 3.2 + 0.35))
	_mi(root, "Bonnet", _cyl(radius * 0.95, radius * 1.5, 12), body_mat,
		Vector3(0.0, radius * 1.7, 0.0))
	flange(root, Vector3(0.0, radius * 2.4, 0.0), radius * 0.75, body_mat,
		Vector3.UP, 6, "BonnetFlange")
	# 90 mm of stem is about three times a real one. Below 70 mm it vanishes.
	_mi(root, "Stem", _cyl(0.045, stem_h, 8), wheel_mat,
		Vector3(0.0, radius * 1.4 + stem_h * 0.5, 0.0))

	if bool(opts.get("gearbox", false)):
		_mi(root, "Gearbox", _box(Vector3(radius * 1.5, radius * 1.2, radius * 1.4)),
			body_mat, Vector3(0.0, radius * 1.4 + stem_h, 0.0))

	var wheel_r: float = float(opts.get("wheel_radius", maxf(radius * 2.4, 0.40)))
	var tilt: float = float(opts.get("wheel_tilt", 0.34))
	var wheel := _root(root, "Wheel", Vector3(0.0, radius * 1.4 + stem_h + 0.08, 0.0))
	wheel.rotation = Vector3(tilt, 0.0, 0.10)
	var rim := TorusMesh.new()
	rim.inner_radius = wheel_r - 0.055
	rim.outer_radius = wheel_r
	rim.rings = 18
	rim.ring_segments = 5
	_mi(wheel, "Rim", rim, wheel_mat)
	_mi(wheel, "Hub", _cyl(0.10, 0.10, 8), wheel_mat)
	for i in 4:
		var a := PI * float(i) / 4.0
		_mi(wheel, "Spoke%d" % i, _box(Vector3(wheel_r * 2.0, 0.045, 0.055)),
			wheel_mat, Vector3.ZERO, Vector3(0.0, a, 0.0))

	if bool(opts.get("tag", true)):
		# The stamped identification tag wired to the bonnet. Two hundred of
		# these across a plant is most of what makes it look administered.
		var tag := _mi(root, "Tag", _box(Vector3(0.20, 0.13, 0.012)), wheel_mat,
			Vector3(radius * 0.9, radius * 2.0, radius * 1.1))
		tag.rotation = Vector3(0.0, 0.0, 0.22)
	return root


## A pedestal hand-wheel: the reach rod and stand that operates a valve down in
## a pit. Person-height, so it gives a pipe run its scale.
static func handwheel_stand(parent: Node3D, base: Vector3, height: float,
		mat: Material, wheel_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "HandwheelStand", base)
	_mi(root, "Pad", _box(Vector3(0.52, 0.14, 0.52)), mat, Vector3(0.0, 0.07, 0.0))
	_mi(root, "Post", _cyl(0.075, height, 10), mat, Vector3(0.0, height * 0.5, 0.0))
	_mi(root, "Collar", _cyl(0.11, 0.14, 10), mat, Vector3(0.0, height - 0.22, 0.0))
	# Reach rod continuing down past the pad into the pit: the stand is only
	# believable if the thing it operates is implied below it.
	_mi(root, "ReachRod", _cyl(0.04, 0.9, 8), wheel_mat, Vector3(0.0, -0.35, 0.0))

	var wheel_r: float = float(opts.get("wheel_radius", 0.34))
	var wheel := _root(root, "Wheel", Vector3(0.0, height + 0.06, 0.0))
	wheel.rotation = Vector3(float(opts.get("wheel_tilt", 0.38)), 0.0, -0.08)
	var rim := TorusMesh.new()
	rim.inner_radius = wheel_r - 0.05
	rim.outer_radius = wheel_r
	rim.rings = 16
	rim.ring_segments = 5
	_mi(wheel, "Rim", rim, wheel_mat)
	_mi(wheel, "Hub", _cyl(0.085, 0.10, 8), wheel_mat)
	for i in 3:
		_mi(wheel, "Spoke%d" % i, _box(Vector3(wheel_r * 2.0, 0.04, 0.05)),
			wheel_mat, Vector3.ZERO, Vector3(0.0, PI * float(i) / 3.0, 0.0))
	return root


## A stencilled pipe identification band: the colour band, its two edge bands
## and a flow arrow on the camera side.
##
## opts: width (float), edge_mat (Material), arrow_mat (Material),
## reverse (bool — arrow points back down the axis), text (String),
## text_mat (Material), font (String path).
static func pipe_label(parent: Node3D, at: Vector3, radius: float, axis: Vector3,
		band_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "PipeLabel")
	root.transform = Transform3D(_basis_from_y(axis), at)
	var w: float = float(opts.get("width", 0.46))
	_mi(root, "Band", _cyl(radius * 1.08, w, 14), band_mat)
	var edge_mat: Material = opts.get("edge_mat", band_mat)
	for s: float in [-1.0, 1.0]:
		_mi(root, "Edge%s" % ("A" if s < 0.0 else "B"),
			_cyl(radius * 1.10, 0.05, 14), edge_mat, Vector3(0.0, s * w * 0.5, 0.0))

	# The arrow sits on the camera-facing side of the pipe as a flat chevron.
	# Wrapping it round the cylinder would be correct and invisible.
	var arrow_mat: Material = opts.get("arrow_mat", edge_mat)
	var sign_dir := -1.0 if bool(opts.get("reverse", false)) else 1.0
	var a_root := _root(root, "Arrow")
	# Put the chevron on whichever local axis is closest to the camera (+Z in
	# world), resolved through the root's own basis.
	var camera_local := root.transform.basis.inverse() * Vector3.BACK
	camera_local.y = 0.0
	if camera_local.length_squared() < 0.001:
		camera_local = Vector3.BACK
	camera_local = camera_local.normalized()
	a_root.transform = Transform3D(Basis(Vector3.UP,
		atan2(camera_local.x, camera_local.z)), camera_local * radius * 1.12)
	for s: float in [-1.0, 1.0]:
		var v := _mi(a_root, "Vane%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(0.22, 0.20, 0.02)), arrow_mat,
			Vector3(0.0, sign_dir * 0.08, 0.0))
		v.rotation = Vector3(0.0, 0.0, s * sign_dir * 0.78)
		v.position.x = s * 0.09

	if opts.has("text"):
		var tm: Material = opts.get("text_mat", arrow_mat)
		var sign_node := PropKit.sign(a_root, str(opts["text"]),
			Vector3(0.0, -0.26, 0.02), 0.13, tm,
			str(opts.get("font", PropKit.FONT_NASKH)), 0.008)
		sign_node.name = "LabelText"
	return root


# --- Cable management -------------------------------------------------------

## A cable tray on cantilever brackets, with cables lying in it.
##
## In profile the tray is a long horizontal band with a row of brackets ticking
## along underneath it — one of the best free rhythms available on a blank wall.
## The rungs barely read; the side rail and the brackets are the whole shape.
##
## opts: bracket_pitch (float), bracket_dir (Vector3, default into the wall at
## -Z), bracket_len (float), cables (int), cable_mat (Material), covered (bool),
## rung_pitch (float), name (String).
static func cable_tray(parent: Node3D, from: Vector3, to: Vector3, width: float,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "CableTray")))
	var delta := to - from
	var length := delta.length()
	if length < 0.05:
		return root
	var dir := delta / length
	var frame := _basis_frame(dir, Vector3.UP)
	var mid := (from + to) * 0.5
	root.transform = Transform3D(frame, mid)
	# From here on everything is in tray space: +X down the run, +Y up,
	# +Z across the tray toward the camera side.

	# Side rails. 140 mm deep, which is honest for a heavy-duty tray and also
	# happens to be exactly the depth that survives at forty units.
	for s: float in [-1.0, 1.0]:
		_mi(root, "Rail%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(length, 0.14, 0.075)), mat,
			Vector3(0.0, 0.0, s * width * 0.5))

	var rung_pitch: float = float(opts.get("rung_pitch", 0.42))
	var rungs := maxi(2, int(length / rung_pitch))
	var rung_mm := _mm(_box(Vector3(0.075, 0.05, width)))
	var rung_xf: Array[Transform3D] = []
	for i in rungs:
		rung_xf.append(Transform3D(Basis.IDENTITY,
			Vector3(-length * 0.5 + length * (float(i) + 0.5) / float(rungs), -0.05, 0.0)))
	_fill(rung_mm, rung_xf)
	_mm_node(root, "Rungs", rung_mm, mat)

	# Cables: fat, few, and sitting proud of the rail so the run has a lumpy
	# top edge instead of a machined one.
	var cable_count: int = int(opts.get("cables", 4))
	var cable_mat: Material = opts.get("cable_mat", mat)
	var rng := _rng(from, 17)
	for i in cable_count:
		var r := rng.randf_range(0.055, 0.095)
		var z := -width * 0.42 + width * 0.84 * (float(i) + 0.5) / float(maxi(cable_count, 1))
		_mi(root, "Cable%d" % i, _cyl(r, length, 8), cable_mat,
			Vector3(0.0, r - 0.02 + rng.randf_range(0.0, 0.03), z),
			Vector3(0.0, 0.0, PI * 0.5))

	if bool(opts.get("covered", false)):
		_mi(root, "Cover", _box(Vector3(length, 0.05, width + 0.14)), mat,
			Vector3(0.0, 0.14, 0.0))

	# Brackets. These are drawn in tray space too, so a tray on a sloping run
	# still gets brackets square to it.
	var b_dir: Vector3 = opts.get("bracket_dir", Vector3.FORWARD)
	var b_local := (frame.inverse() * b_dir).normalized()
	var b_len: float = float(opts.get("bracket_len", 0.55))
	var pitch: float = float(opts.get("bracket_pitch", 2.6))
	var count := maxi(2, int(length / pitch))
	for i in count + 1:
		var x := -length * 0.5 + length * float(i) / float(count)
		var arm := _root(root, "Bracket%d" % i, Vector3(x, -0.12, 0.0))
		var end := b_local * b_len
		_mi(arm, "Arm", _box(Vector3(0.09, 0.09, b_len)), mat, end * 0.5,
			Vector3(0.0, atan2(b_local.x, b_local.z), 0.0))
		# The gusset back up to the wall plate is the diagonal that makes a
		# bracket look carried rather than glued.
		var gusset := _mi(arm, "Gusset", _box(Vector3(0.06, b_len * 1.15, 0.06)), mat,
			end * 0.5 + Vector3(0.0, -0.18, 0.0))
		gusset.transform = Transform3D(
			_basis_from_y((end + Vector3(0.0, 0.42, 0.0)).normalized()),
			end * 0.45 + Vector3(0.0, -0.18, 0.0))
		_mi(arm, "Plate", _box(Vector3(0.16, 0.34, 0.06)), mat, end,
			Vector3(0.0, atan2(b_local.x, b_local.z), 0.0))
	return root


## A bank of parallel conduits stacked up a wall. Read in profile it is a set of
## close horizontals — the cheapest way to give a blank elevation a datum line.
##
## opts: pitch (float, vertical spacing), radius (float), strap_pitch (float),
## strap_mat (Material), end_box (bool), box_mat (Material), name (String).
static func conduit_bank(parent: Node3D, from: Vector3, to: Vector3, count: int,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "ConduitBank")))
	var delta := to - from
	var length := delta.length()
	if length < 0.05 or count <= 0:
		return root
	var dir := delta / length
	var frame := _basis_frame(dir, Vector3.UP)
	root.transform = Transform3D(frame, (from + to) * 0.5)

	# 110 mm outside diameter. A 20 mm conduit is correct and invisible; the
	# bank only works because the individual tubes are legible.
	var r: float = float(opts.get("radius", 0.055))
	var pitch: float = float(opts.get("pitch", 0.165))
	var span := pitch * float(count - 1)
	for i in count:
		var y := -span * 0.5 + pitch * float(i)
		_mi(root, "Conduit%d" % i, _cyl(r, length, 8), mat, Vector3(0.0, y, 0.0),
			Vector3(0.0, 0.0, PI * 0.5))

	var strap_mat: Material = opts.get("strap_mat", mat)
	var strap_pitch: float = float(opts.get("strap_pitch", 1.9))
	var straps := maxi(2, int(length / strap_pitch))
	var strap_mm := _mm(_box(Vector3(0.07, span + r * 3.0, r * 3.2)))
	var strap_xf: Array[Transform3D] = []
	for i in straps:
		strap_xf.append(Transform3D(Basis.IDENTITY,
			Vector3(-length * 0.5 + length * (float(i) + 0.5) / float(straps), 0.0, -r * 0.6)))
	_fill(strap_mm, strap_xf)
	_mm_node(root, "Straps", strap_mm, strap_mat)

	# A conduit bank that stops in mid-air is a fault. It ends in a box.
	if bool(opts.get("end_box", true)):
		var bmat: Material = opts.get("box_mat", mat)
		# Parented to the run's own root and expressed in run space, so freeing
		# the returned node takes the box with it.
		junction_box(root, Vector3(length * 0.5 + 0.26, 0.0, 0.0),
			Vector3(0.40, span + 0.34, 0.20), bmat,
			{"conduits": [Vector3.LEFT], "stub_len": 0.30, "gland_mat": mat,
			"glands": mini(count, 4)})
	return root


## A wall box with conduit entering it through glands. Terminates conduit runs,
## and on its own it is the single most useful piece of clutter in the kit.
##
## opts: conduits (Array[Vector3] of directions the conduit leaves in),
## stub_len (float), glands (int), gland_mat (Material), lid_mat (Material),
## label (bool), name (String).
static func junction_box(parent: Node3D, at: Vector3, size: Vector3, mat: Material,
		opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "JunctionBox")), at)
	var rng := _rng(at, 23)
	# Nothing bolted to a wall by hand is plumb. Two degrees is enough.
	root.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.035, 0.035))

	_mi(root, "Body", _box(size), mat)
	var lid_mat: Material = opts.get("lid_mat", mat)
	_mi(root, "Lid", _box(Vector3(size.x * 0.94, size.y * 0.94, 0.045)), lid_mat,
		Vector3(0.0, 0.0, size.z * 0.5 + 0.02))
	for i in 4:
		var sx := (-1.0 if i % 2 == 0 else 1.0) * size.x * 0.38
		var sy := (-1.0 if i < 2 else 1.0) * size.y * 0.38
		_mi(root, "Screw%d" % i, _cyl(0.028, 0.06, 6), mat,
			Vector3(sx, sy, size.z * 0.5 + 0.05), Vector3(PI * 0.5, 0.0, 0.0))

	var gland_mat: Material = opts.get("gland_mat", mat)
	var dirs: Array = opts.get("conduits", [Vector3.DOWN])
	var glands: int = int(opts.get("glands", 2))
	var stub: float = float(opts.get("stub_len", 0.35))
	for di in dirs.size():
		var d: Vector3 = (dirs[di] as Vector3).normalized()
		var face := Vector3(d.x * size.x, d.y * size.y, d.z * size.z) * 0.5
		for g in glands:
			var off := (float(g) - float(glands - 1) * 0.5) * 0.13
			var across := Vector3(-d.y, d.x, 0.0)
			if across.length_squared() < 0.01:
				across = Vector3.RIGHT
			var p := face + across.normalized() * off
			var gl := _mi(root, "Gland%d_%d" % [di, g], _cyl(0.055, 0.10, 8), gland_mat, p)
			gl.transform = Transform3D(_basis_from_y(d), p)
			_segment(root, "Stub%d_%d" % [di, g], p + d * 0.05, p + d * stub,
				0.042, gland_mat, 8)

	if bool(opts.get("label", true)):
		_mi(root, "Label", _box(Vector3(size.x * 0.5, 0.07, 0.012)), gland_mat,
			Vector3(0.0, -size.y * 0.5 + 0.10, size.z * 0.5 + 0.05))
	return root


# --- Electrical -------------------------------------------------------------

## A distribution board: back box, hinged door, rain canopy, gland plate and the
## conduits dropping out of it. Chest-to-head height, so it also scales the wall
## it is bolted to.
##
## opts: size (Vector3), canopy (bool), conduits (int), conduit_mat (Material),
## lamp (bool — a pilot lamp with a real OmniLight; off by default because
## fifty of them is fifty lights), lamp_color (Color), padlock (bool).
static func distribution_board(parent: Node3D, at: Vector3, mat: Material,
		door_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "DistBoard", at)
	var size: Vector3 = opts.get("size", Vector3(0.78, 1.05, 0.26))
	var rng := _rng(at, 31)
	root.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.02, 0.02))

	_mi(root, "Box", _box(size), mat)
	# The door stands proud of the box and is hung a couple of degrees open on
	# about half of them. A shut flush door is a rectangle; a door with a gap
	# down one edge is a door.
	var ajar := rng.randf() < 0.45
	var hinge := _root(root, "DoorHinge",
		Vector3(-size.x * 0.5, 0.0, size.z * 0.5))
	hinge.rotation.y = rng.randf_range(0.10, 0.30) if ajar else 0.0
	_mi(hinge, "Door", _box(Vector3(size.x * 0.96, size.y * 0.94, 0.05)), door_mat,
		Vector3(size.x * 0.48, 0.0, 0.03))
	_mi(hinge, "Handle", _box(Vector3(0.05, 0.17, 0.07)), mat,
		Vector3(size.x * 0.90, 0.0, 0.08))
	for i in 2:
		_mi(root, "Hinge%d" % i, _cyl(0.028, 0.12, 6), mat,
			Vector3(-size.x * 0.5 - 0.02, (-0.3 + 0.6 * i) * size.y, size.z * 0.5))

	if bool(opts.get("canopy", true)):
		var canopy := _mi(root, "Canopy", _box(Vector3(size.x + 0.22, 0.05, size.z + 0.24)),
			mat, Vector3(0.0, size.y * 0.5 + 0.10, size.z * 0.22))
		canopy.rotation.x = -0.14
		for s: float in [-1.0, 1.0]:
			_mi(root, "CanopyStay%s" % ("A" if s < 0.0 else "B"),
				_box(Vector3(0.05, 0.30, 0.05)), mat,
				Vector3(s * size.x * 0.42, size.y * 0.5 - 0.05, size.z * 0.42),
				Vector3(0.5, 0.0, 0.0))

	# Gland plate and the conduits leaving the bottom. A board with no cable
	# going into it is a locker.
	_mi(root, "GlandPlate", _box(Vector3(size.x * 0.8, 0.05, size.z * 0.8)), mat,
		Vector3(0.0, -size.y * 0.5 - 0.02, 0.0))
	var c_mat: Material = opts.get("conduit_mat", mat)
	var conduits: int = int(opts.get("conduits", 3))
	for i in conduits:
		var x := (float(i) - float(conduits - 1) * 0.5) * 0.16
		var drop := rng.randf_range(0.45, 0.95)
		_mi(root, "Gland%d" % i, _cyl(0.05, 0.09, 8), c_mat,
			Vector3(x, -size.y * 0.5 - 0.06, 0.0))
		_mi(root, "Drop%d" % i, _cyl(0.038, drop, 8), c_mat,
			Vector3(x, -size.y * 0.5 - 0.06 - drop * 0.5, 0.0))

	if bool(opts.get("padlock", true)):
		_mi(root, "Hasp", _box(Vector3(0.10, 0.06, 0.055)), mat,
			Vector3(size.x * 0.42, -0.02, size.z * 0.5 + 0.09))

	if bool(opts.get("lamp", false)):
		var tint: Color = opts.get("lamp_color", Color(1.0, 0.62, 0.20))
		var lens := _mi(root, "PilotLamp", _cyl(0.035, 0.05, 8),
			MaterialLab.emissive(tint, 5.0),
			Vector3(size.x * 0.28, size.y * 0.34, size.z * 0.5 + 0.07),
			Vector3(PI * 0.5, 0.0, 0.0))
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var omni := OmniLight3D.new()
		omni.name = "LampSpill"
		omni.light_color = tint
		omni.light_energy = 1.1
		omni.omni_range = 1.4
		omni.shadow_enabled = false
		omni.position = Vector3(size.x * 0.28, size.y * 0.34, size.z * 0.5 + 0.18)
		root.add_child(omni)
	return root


## A rotary isolator: the little box with the lever on it next to every motor.
## Small, repeated, and it makes a wall look wired rather than decorated.
static func isolator(parent: Node3D, at: Vector3, mat: Material,
		handle_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "Isolator", at)
	var size: Vector3 = opts.get("size", Vector3(0.24, 0.30, 0.16))
	var rng := _rng(at, 41)
	root.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.04, 0.04))

	_mi(root, "Body", _box(size), mat)
	_mi(root, "Boss", _cyl(0.06, 0.06, 10), handle_mat,
		Vector3(0.0, 0.02, size.z * 0.5 + 0.03), Vector3(PI * 0.5, 0.0, 0.0))
	# The lever is left wherever it was left. Half of them are off.
	var lever := _mi(root, "Lever", _box(Vector3(0.075, 0.17, 0.05)), handle_mat,
		Vector3(0.0, 0.08, size.z * 0.5 + 0.07))
	lever.rotation.z = -PI * 0.5 if rng.randf() < 0.5 else 0.0
	_mi(root, "Gland", _cyl(0.042, 0.08, 8), mat,
		Vector3(0.0, -size.y * 0.5 - 0.04, 0.0))
	_mi(root, "Stub", _cyl(0.034, 0.34, 8), mat,
		Vector3(0.0, -size.y * 0.5 - 0.22, 0.0))
	_mi(root, "Plate", _box(Vector3(size.x * 0.6, 0.055, 0.012)), handle_mat,
		Vector3(0.0, -size.y * 0.32, size.z * 0.5 + 0.03))
	return root


## A bulkhead light fitting with a wire guard over the lens.
##
## The guard is the point. A glowing disc on a wall is a decal; a glowing disc
## behind five bars throws a caged shadow across the wall, and that shadow is
## one of the best-value pieces of lighting detail in the whole kit.
##
## opts: radius (float), tint (Color), energy (float), light (bool — adds a
## real OmniLight), range (float), bracket (bool), lit (bool — an unlit fitting
## is a dead plant's default state).
static func bulkhead_light(parent: Node3D, at: Vector3, mat: Material,
		opts := {}) -> Node3D:
	var root := _root(parent, "BulkheadLight", at)
	var r: float = float(opts.get("radius", 0.18))
	var lit: bool = bool(opts.get("lit", true))
	var tint: Color = opts.get("tint", Color(1.0, 0.78, 0.45))
	var energy: float = float(opts.get("energy", 3.2))

	_mi(root, "Back", _box(Vector3(r * 2.3, r * 2.3, 0.12)), mat, Vector3(0.0, 0.0, -0.02))
	_mi(root, "Body", _cyl(r * 1.08, 0.13, 12), mat, Vector3(0.0, 0.0, 0.07),
		Vector3(PI * 0.5, 0.0, 0.0))
	var lens_mat: Material = MaterialLab.emissive(tint, energy) if lit else mat
	var lens := _mi(root, "Lens", _cyl(r, 0.08, 12), lens_mat, Vector3(0.0, 0.0, 0.14),
		Vector3(PI * 0.5, 0.0, 0.0))
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Guard: a rim plus five bars. 55 mm bar is far too heavy for a light guard
	# and is exactly what makes the cage read at distance.
	var rim := TorusMesh.new()
	rim.inner_radius = r * 1.02
	rim.outer_radius = r * 1.02 + 0.055
	rim.rings = 14
	rim.ring_segments = 4
	_mi(root, "GuardRim", rim, mat, Vector3(0.0, 0.0, 0.20), Vector3(PI * 0.5, 0.0, 0.0))
	for i in 5:
		var a := PI * float(i) / 5.0
		_mi(root, "GuardBar%d" % i, _box(Vector3(r * 2.1, 0.05, 0.05)), mat,
			Vector3(0.0, 0.0, 0.20), Vector3(0.0, 0.0, a))

	if bool(opts.get("bracket", true)):
		_mi(root, "Bracket", _box(Vector3(0.08, 0.26, 0.08)), mat,
			Vector3(0.0, r * 1.6, -0.02))
		_mi(root, "Conduit", _cyl(0.035, 0.42, 8), mat, Vector3(0.0, r * 2.4, -0.04))

	if lit and bool(opts.get("light", false)):
		var omni := OmniLight3D.new()
		omni.name = "Spill"
		omni.light_color = tint
		omni.light_energy = energy * 0.55
		omni.omni_range = float(opts.get("range", 4.2))
		omni.shadow_enabled = false
		omni.position = Vector3(0.0, 0.0, 0.34)
		root.add_child(omni)
	return root


# --- Access: ladders, grating, handrail -------------------------------------

## A caged ladder with rails, rungs, stand-off brackets and an optional landing.
##
## Built in the XY plane with the rungs running along X and the whole thing
## stood off the wall in +Z, which is the only orientation that reads in a
## side-on camera: rungs along Z would be edge-on and the ladder would be one
## vertical stick.
##
## opts: width (float), standoff (float), rung_pitch (float), cage (bool),
## cage_start (float, height the hoops begin), landing (bool), landing_mat
## (Material), extension (float — rails continuing above the top), pad (bool).
static func ladder(parent: Node3D, base: Vector3, height: float, mat: Material,
		opts := {}) -> Node3D:
	var root := _root(parent, "Ladder", base)
	var w: float = float(opts.get("width", 0.62))
	var standoff: float = float(opts.get("standoff", 0.22))
	var ext: float = float(opts.get("extension", 1.05))

	# Rails run past the top by a metre: the grab extension you pull yourself up
	# on. A ladder that stops level with its landing is a drawing, not a ladder.
	var rail_h := height + ext
	for s: float in [-1.0, 1.0]:
		_mi(root, "Rail%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(0.075, rail_h, 0.12)), mat,
			Vector3(s * w * 0.5, rail_h * 0.5, standoff))

	var pitch: float = float(opts.get("rung_pitch", 0.30))
	var rungs := maxi(2, int(height / pitch))
	var rung_mm := _mm(_box(Vector3(w, 0.07, 0.07)))
	var rung_xf: Array[Transform3D] = []
	for i in rungs:
		rung_xf.append(Transform3D(Basis.IDENTITY,
			Vector3(0.0, pitch * (float(i) + 1.0), standoff)))
	_fill(rung_mm, rung_xf)
	_mm_node(root, "Rungs", rung_mm, mat)

	# Stand-off brackets back to the wall.
	var brackets := maxi(2, int(height / 1.7))
	var br_mm := _mm(_box(Vector3(0.07, 0.07, standoff + 0.12)))
	var br_xf: Array[Transform3D] = []
	for i in brackets:
		var y := 0.5 + (height - 0.8) * float(i) / float(maxi(brackets - 1, 1))
		for s: float in [-1.0, 1.0]:
			br_xf.append(Transform3D(Basis.IDENTITY,
				Vector3(s * w * 0.5, y, standoff * 0.5 - 0.06)))
	_fill(br_mm, br_xf)
	_mm_node(root, "Brackets", br_mm, mat)

	if bool(opts.get("cage", true)):
		var cage_start: float = float(opts.get("cage_start", 2.35))
		if height > cage_start + 0.8:
			var hoop_pitch := 0.78
			var hoops := maxi(2, int((height - cage_start) / hoop_pitch))
			var hoop := TorusMesh.new()
			hoop.inner_radius = 0.38
			hoop.outer_radius = 0.46
			hoop.rings = 12
			hoop.ring_segments = 4
			var hoop_mm := _mm(hoop)
			var hoop_xf: Array[Transform3D] = []
			for i in hoops:
				var y := cage_start + (height - cage_start) * float(i) / float(maxi(hoops - 1, 1))
				# A real hoop is open on the wall side. A closed one costs the
				# same, reads the same in profile, and never shows its gap.
				hoop_xf.append(Transform3D(Basis.IDENTITY, Vector3(0.0, y, standoff + 0.30)))
			_fill(hoop_mm, hoop_xf)
			_mm_node(root, "CageHoops", hoop_mm, mat)

			# Stringers tying the hoops together: the front one and the two
			# sides. In profile the front stringer is the cage's outline.
			var cage_h := height - cage_start
			var stringers := [
				Vector3(0.0, 0.0, standoff + 0.72),
				Vector3(0.42, 0.0, standoff + 0.30),
				Vector3(-0.42, 0.0, standoff + 0.30),
			]
			for si in stringers.size():
				var off: Vector3 = stringers[si]
				_mi(root, "Stringer%d" % si, _box(Vector3(0.06, cage_h, 0.06)), mat,
					Vector3(off.x, cage_start + cage_h * 0.5, off.z))

	if bool(opts.get("pad", true)):
		_mi(root, "Footing", _box(Vector3(w + 0.3, 0.16, standoff + 0.5)), mat,
			Vector3(0.0, 0.08, standoff * 0.5 + 0.1))

	if bool(opts.get("landing", false)):
		var lmat: Material = opts.get("landing_mat", mat)
		var lw: float = float(opts.get("landing_width", 1.8))
		var ld: float = float(opts.get("landing_depth", 1.3))
		var ly := height
		grating_panel(root, Vector3(lw * 0.5 - w * 0.5, ly, standoff + 0.1),
			Vector3(lw, 0.08, ld), lmat, {"kick": true})
		handrail(root,
			Vector3(-w * 0.5, ly, standoff + 0.1 + ld * 0.5),
			Vector3(lw - w * 0.5, ly, standoff + 0.1 + ld * 0.5), lmat,
			{"kick": false})
	return root


## A grating walkway panel: binding frame, bearer bars, cross rods and a kick
## rail on the open edge.
##
## `size` is (width X, thickness Y, depth Z) and `center` sits on the panel's
## TOP SURFACE, matching LevelKit.platform's `top_y` — a walkway is placed at
## the height it is walked on, not at the middle of its own thickness. The bearer bars are the payoff: at a raking sun they
## stripe whatever is underneath, which is the most expensive-looking free
## shadow in the game.
##
## opts: kick (bool), kick_side (float, +1 toward the camera), bar_pitch
## (float), missing (Array of bar indices to drop — a hole in a walkway is a
## story and a hazard), rods (bool), frame (bool).
static func grating_panel(parent: Node3D, center: Vector3, size: Vector3,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "Grating", center)
	var th := maxf(size.y, 0.05)

	if bool(opts.get("frame", true)):
		for s: float in [-1.0, 1.0]:
			_mi(root, "FrameX%s" % ("A" if s < 0.0 else "B"),
				_box(Vector3(size.x, th, 0.07)), mat,
				Vector3(0.0, -th * 0.5, s * (size.z * 0.5 - 0.035)))
			_mi(root, "FrameZ%s" % ("A" if s < 0.0 else "B"),
				_box(Vector3(0.07, th, size.z)), mat,
				Vector3(s * (size.x * 0.5 - 0.035), -th * 0.5, 0.0))

	var pitch: float = float(opts.get("bar_pitch", 0.09))
	var bars := maxi(3, int((size.z - 0.14) / pitch))
	var missing: Array = opts.get("missing", [])
	var bar_mm := _mm(_box(Vector3(size.x - 0.09, th * 0.92, 0.032)))
	var bar_xf: Array[Transform3D] = []
	for i in bars:
		if missing.has(i):
			continue
		var z := -size.z * 0.5 + 0.07 + (size.z - 0.14) * (float(i) + 0.5) / float(bars)
		bar_xf.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -th * 0.5, z)))
	_fill(bar_mm, bar_xf)
	_mm_node(root, "Bearers", bar_mm, mat)

	if bool(opts.get("rods", true)):
		var rods := maxi(2, int(size.x / 0.55))
		var rod_mm := _mm(_box(Vector3(0.028, th * 0.45, size.z - 0.1)))
		var rod_xf: Array[Transform3D] = []
		for i in rods:
			var x := -size.x * 0.5 + size.x * (float(i) + 0.5) / float(rods)
			rod_xf.append(Transform3D(Basis.IDENTITY, Vector3(x, -th * 0.3, 0.0)))
		_fill(rod_mm, rod_xf)
		_mm_node(root, "CrossRods", rod_mm, mat)

	if bool(opts.get("kick", true)):
		var side: float = float(opts.get("kick_side", 1.0))
		_mi(root, "KickRail", _box(Vector3(size.x, 0.15, 0.05)), mat,
			Vector3(0.0, 0.075, side * (size.z * 0.5 - 0.02)))
	return root


## A checker-plate panel: the plate, its raised tread pattern and a turned-down
## front lip. `center` sits on the top surface, as with `grating_panel`.
##
## The lozenges only read close to the camera and at a grazing angle, so
## `pattern` should be switched off for anything in the mid ground — it is a
## foreground material, not a background one.
##
## opts: pattern (bool), pitch (float), lip (bool), lip_depth (float).
static func checker_plate(parent: Node3D, center: Vector3, size: Vector3,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "CheckerPlate", center)
	var th := maxf(size.y, 0.05)
	_mi(root, "Plate", _box(Vector3(size.x, th, size.z)), mat, Vector3(0.0, -th * 0.5, 0.0))

	if bool(opts.get("pattern", true)):
		var pitch: float = float(opts.get("pitch", 0.19))
		var cols := maxi(2, int(size.x / pitch))
		var rows := maxi(2, int(size.z / pitch))
		var mm := _mm(_box(Vector3(0.105, 0.022, 0.032)))
		var xf: Array[Transform3D] = []
		for r in rows:
			for c in cols:
				var x := -size.x * 0.5 + size.x * (float(c) + 0.5) / float(cols)
				var z := -size.z * 0.5 + size.z * (float(r) + 0.5) / float(rows)
				# Alternating pairs at opposing angles: that is what the real
				# rolled pattern does and it is why it glitters under a low sun.
				var a := 0.72 if (r + c) % 2 == 0 else -0.72
				xf.append(Transform3D(Basis(Vector3.UP, a), Vector3(x, 0.008, z)))
		_fill(mm, xf)
		_mm_node(root, "Tread", mm, mat)

	if bool(opts.get("lip", true)):
		var d: float = float(opts.get("lip_depth", 0.16))
		_mi(root, "Lip", _box(Vector3(size.x, d, 0.05)), mat,
			Vector3(0.0, -d * 0.45, size.z * 0.5 + 0.02))
	return root


## An industrial handrail run that can follow a slope: stanchions, top rail,
## mid rail, toe plate and end returns.
##
## `from` and `to` are on the walking surface, so a stair rail is just a run
## whose ends are at different heights. The stanchions stay plumb and the rails
## rake — which is how a real stair rail is built, and the difference is
## obvious the moment you see the wrong version.
##
## opts: height (float), mid (float), pitch (float, stanchion spacing), kick
## (bool), toe_height (float), missing (Array of stanchion indices), returns
## (bool), name (String).
static func handrail(parent: Node3D, from: Vector3, to: Vector3, mat: Material,
		opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "Handrail")))
	var delta := to - from
	var length := delta.length()
	if length < 0.2:
		return root
	var dir := delta / length
	var h: float = float(opts.get("height", 1.06))
	var mid_h: float = float(opts.get("mid", 0.54))
	var up := Vector3.UP

	_segment(root, "RailTop", from + up * h, to + up * h, 0.048, mat, 8)
	_segment(root, "RailMid", from + up * mid_h, to + up * mid_h, 0.038, mat, 8)

	var pitch: float = float(opts.get("pitch", 1.85))
	var n := maxi(2, int(length / pitch) + 1)
	var missing: Array = opts.get("missing", [])
	for i in n:
		if missing.has(i):
			continue
		var t := float(i) / float(n - 1)
		var p := from + delta * t
		# End posts are heavier than the intermediates, because they carry the
		# whole run and because a run needs a full stop at each end.
		var thick := 0.095 if (i == 0 or i == n - 1) else 0.075
		_mi(root, "Stanchion%d" % i, _box(Vector3(thick, h, thick)), mat,
			p + up * (h * 0.5))
		if i > 0 and i < n - 1:
			var brace := _mi(root, "Knee%d" % i, _box(Vector3(0.05, 0.46, 0.05)), mat,
				p + up * 0.28 + dir * 0.12)
			brace.transform = Transform3D(
				_basis_from_y((up * 0.8 + dir * 0.6).normalized()),
				p + up * 0.30 + dir * 0.14)

	if bool(opts.get("kick", true)):
		var toe: float = float(opts.get("toe_height", 0.17))
		_plate_between(root, "ToePlate", from + up * (toe * 0.5 + 0.02),
			to + up * (toe * 0.5 + 0.02), toe, 0.05, mat)

	# Returns: the top rail curls down to the post at each end instead of
	# stopping in the air. It is two short tubes and it is the single clearest
	# "this was detailed" signal on a walkway.
	if bool(opts.get("returns", true)):
		_segment(root, "ReturnA", from + up * h, from + up * (h - 0.32) - dir * 0.26,
			0.045, mat, 8)
		_segment(root, "ReturnB", to + up * h, to + up * (h - 0.32) + dir * 0.26,
			0.045, mat, 8)
	return root


# --- Signage ----------------------------------------------------------------

## A bracketed hazard plate: the plate, its two stand-off brackets, an optional
## chevron band and optional text.
##
## Bilingual safety signage belongs INSIDE the plant and nowhere else in World 1
## — Libyan road and street signage is Arabic only. Pass `text` for the Arabic
## line and `text_en` for the English one beneath it.
##
## opts: standoff (float), chevrons (bool), chevron_a/chevron_b (Color),
## border_mat (Material), text (String), text_en (String), text_mat (Material),
## font (String), tilt (float — overrides the automatic crookedness).
static func hazard_plate(parent: Node3D, at: Vector3, size: Vector2,
		plate_mat: Material, bracket_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "HazardPlate", at)
	var rng := _rng(at, 53)
	# Nothing on a wall is level. A plate that is dead square to the world is
	# the fastest way to make a sign look like UI stuck on the geometry.
	root.rotation = Vector3(0.0, 0.0, float(opts.get("tilt", rng.randf_range(-0.045, 0.045))))

	var standoff: float = float(opts.get("standoff", 0.13))
	_mi(root, "Plate", _box(Vector3(size.x, size.y, 0.05)), plate_mat,
		Vector3(0.0, 0.0, standoff))
	for s: float in [-1.0, 1.0]:
		_mi(root, "Bracket%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(0.06, size.y * 0.8, standoff)), bracket_mat,
			Vector3(s * size.x * 0.34, 0.0, standoff * 0.5))

	var border_mat: Material = opts.get("border_mat", bracket_mat)
	if bool(opts.get("chevrons", true)):
		var band_h := size.y * 0.24
		var band_y := -size.y * 0.5 + band_h * 0.5 + 0.02
		var stripes := maxi(4, int(size.x / 0.14))
		var mm := _mm(_box(Vector3(0.085, band_h * 2.0, 0.018)))
		mm.use_colors = true
		mm.instance_count = stripes
		var a_col: Color = opts.get("chevron_a", Color(0.86, 0.68, 0.10))
		var b_col: Color = opts.get("chevron_b", Color(0.07, 0.07, 0.08))
		for i in stripes:
			var x := -size.x * 0.5 + size.x * (float(i) + 0.5) / float(stripes)
			mm.set_instance_transform(i, Transform3D(
				Basis(Vector3(0.0, 0.0, 1.0), 0.72),
				Vector3(x, band_y, standoff + 0.035)))
			mm.set_instance_color(i, a_col if i % 2 == 0 else b_col)
		var stripe_mat := StandardMaterial3D.new()
		stripe_mat.vertex_color_use_as_albedo = true
		stripe_mat.roughness = 0.72
		stripe_mat.metallic_specular = 0.3
		_mm_node(root, "Chevrons", mm, stripe_mat)
		# The stripes are cut at 45 degrees and overrun the ends of the band, so
		# the ends are covered by two proud caps in the plate colour. That is
		# what you would do on a real model and it costs two boxes.
		for s: float in [-1.0, 1.0]:
			_mi(root, "BandCap%s" % ("A" if s < 0.0 else "B"),
				_box(Vector3(0.055, band_h + 0.05, 0.022)), plate_mat,
				Vector3(s * (size.x * 0.5 - 0.018), band_y, standoff + 0.046))
		_mi(root, "BandEdge", _box(Vector3(size.x, 0.03, 0.022)), border_mat,
			Vector3(0.0, band_y + band_h * 0.5 + 0.015, standoff + 0.046))

	if opts.has("text"):
		var tmat: Material = opts.get("text_mat", border_mat)
		var s1 := PropKit.sign(root, str(opts["text"]),
			Vector3(0.0, size.y * 0.22, standoff + 0.032), size.y * 0.20, tmat,
			str(opts.get("font", PropKit.FONT_NASKH)), 0.01)
		s1.name = "TextAr"
	if opts.has("text_en"):
		var tmat2: Material = opts.get("text_mat", border_mat)
		var s2 := PropKit.sign(root, str(opts["text_en"]),
			Vector3(0.0, -size.y * 0.04, standoff + 0.032), size.y * 0.13, tmat2,
			str(opts.get("font", PropKit.FONT_NASKH)), 0.01)
		s2.name = "TextEn"
	return root


## A bolted-on nameplate: a thin plate held off the surface on four bolts, with
## optional stamped text and a tag number under it.
##
## opts: standoff (float), bolt_r (float), text (String), tag (String),
## text_mat (Material), font (String).
static func nameplate(parent: Node3D, at: Vector3, size: Vector2,
		plate_mat: Material, bolt_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "Nameplate", at)
	var rng := _rng(at, 59)
	root.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.03, 0.03))
	var standoff: float = float(opts.get("standoff", 0.035))

	_mi(root, "Plate", _box(Vector3(size.x, size.y, 0.025)), plate_mat,
		Vector3(0.0, 0.0, standoff))
	var br: float = float(opts.get("bolt_r", 0.026))
	for i in 4:
		var sx := (-1.0 if i % 2 == 0 else 1.0) * (size.x * 0.5 - 0.06)
		var sy := (-1.0 if i < 2 else 1.0) * (size.y * 0.5 - 0.05)
		_mi(root, "Bolt%d" % i, _cyl(br, standoff + 0.05, 6), bolt_mat,
			Vector3(sx, sy, standoff * 0.5 + 0.02), Vector3(PI * 0.5, 0.0, 0.0))

	if opts.has("text"):
		var tmat: Material = opts.get("text_mat", bolt_mat)
		var t := PropKit.sign(root, str(opts["text"]),
			Vector3(0.0, size.y * 0.12, standoff + 0.016), size.y * 0.30, tmat,
			str(opts.get("font", PropKit.FONT_NASKH)), 0.006)
		t.name = "PlateText"
	if opts.has("tag"):
		var tmat2: Material = opts.get("text_mat", bolt_mat)
		var t2 := PropKit.sign(root, str(opts["tag"]),
			Vector3(0.0, -size.y * 0.22, standoff + 0.016), size.y * 0.20, tmat2,
			str(opts.get("font", PropKit.FONT_NASKH)), 0.006)
		t2.name = "TagText"
	return root


# --- Drainage ---------------------------------------------------------------

## A surface drainage channel with a bar grate over it.
##
## Runs along the ground at the bottom of the frame where it costs nothing and
## buys a strong horizontal. `missing` lifts bars out — a channel with two bars
## gone reads as neglected and as somewhere you should not put your foot.
##
## opts: bar_pitch (float), missing (Array), depth (float), kerb_mat
## (Material), silt (bool), name (String).
static func drain_channel(parent: Node3D, from: Vector3, to: Vector3, width: float,
		mat: Material, grate_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "DrainChannel")))
	var delta := to - from
	var length := delta.length()
	if length < 0.1:
		return root
	root.transform = Transform3D(_basis_frame(delta.normalized(), Vector3.UP),
		(from + to) * 0.5)

	var depth: float = float(opts.get("depth", 0.34))
	var kerb_mat: Material = opts.get("kerb_mat", mat)
	# The two edge kerbs. They are the only part of a channel that catches the
	# sun, which is why a drain reads as two bright lines with a dark gap.
	for s: float in [-1.0, 1.0]:
		_mi(root, "Kerb%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(length, 0.14, 0.12)), kerb_mat,
			Vector3(0.0, -0.07, s * (width * 0.5 + 0.06)))
	_mi(root, "Invert", _box(Vector3(length, 0.10, width)), mat,
		Vector3(0.0, -depth, 0.0))
	for s: float in [-1.0, 1.0]:
		_mi(root, "Cheek%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(length, depth, 0.07)), mat,
			Vector3(0.0, -depth * 0.5, s * width * 0.5))

	var pitch: float = float(opts.get("bar_pitch", 0.15))
	var bars := maxi(3, int(length / pitch))
	var missing: Array = opts.get("missing", [])
	var rng := _rng(from, 67)
	var mm := _mm(_box(Vector3(0.065, 0.06, width + 0.08)))
	var xf: Array[Transform3D] = []
	for i in bars:
		if missing.has(i):
			continue
		var x := -length * 0.5 + length * (float(i) + 0.5) / float(bars)
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.02, 0.02)),
			Vector3(x, -0.03, 0.0)))
	_fill(mm, xf)
	_mm_node(root, "Grate", mm, grate_mat)

	if bool(opts.get("silt", true)):
		# Sand and fines banked along the upwind kerb. A clean drain in Brega
		# would be the least believable object in the level.
		var silt := MeshInstance3D.new()
		silt.name = "Silt"
		var q := QuadMesh.new()
		q.size = Vector2(length, width * 2.2)
		silt.mesh = q
		silt.material_override = PropKit.gradient_decal(
			Color(0.42, 0.36, 0.26), 0.55, "radial")
		silt.position = Vector3(0.0, 0.035, 0.0)
		silt.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		root.add_child(silt)
	return root


## The bottom of a downpipe: the swan neck, the splash block it discharges onto,
## and the staining both of them have earned.
##
## opts: stain (bool), block (bool), out (Vector3 — direction it kicks out in),
## ground_y (float).
static func downpipe_shoe(parent: Node3D, at: Vector3, radius: float,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "DownpipeShoe", at)
	var out: Vector3 = opts.get("out", Vector3(0.0, 0.0, 1.0))
	out = out.normalized()
	var ground_y: float = float(opts.get("ground_y", -0.55))

	# Swan neck: down, out, then down again. A single angled stub is the shape
	# every blockout uses and it is the one that looks wrong.
	var p0 := Vector3.ZERO
	var p1 := p0 + Vector3(0.0, -0.22, 0.0) + out * 0.10
	var p2 := p1 + out * 0.30 + Vector3(0.0, -0.16, 0.0)
	var p3 := p2 + Vector3(0.0, ground_y + 0.34, 0.0)
	_segment(root, "NeckA", p0, p1, radius, mat, 8)
	_segment(root, "NeckB", p1, p2, radius, mat, 8)
	_segment(root, "NeckC", p2, p3, radius, mat, 8)
	_mi(root, "Collar", _cyl(radius * 1.25, 0.06, 8), mat, p0)
	_mi(root, "Clip", _box(Vector3(radius * 3.2, 0.06, 0.16)), mat,
		p0 + Vector3(0.0, -0.05, -0.08))

	if bool(opts.get("block", true)):
		var block := _mi(root, "SplashBlock",
			_box(Vector3(0.52, 0.12, 0.74)), mat,
			Vector3(out.x * 0.30, ground_y + 0.06, out.z * 0.30))
		block.rotation.x = -0.09 * signf(out.z if absf(out.z) > 0.01 else 1.0)

	if bool(opts.get("stain", true)):
		# Gravity law: everything that discharges leaves a run below it, and the
		# run is always longer than feels right.
		var wall := MeshInstance3D.new()
		wall.name = "WallStain"
		var wq := QuadMesh.new()
		wq.size = Vector2(radius * 5.0, 1.7)
		wall.mesh = wq
		wall.material_override = PropKit.gradient_decal(
			Color(0.075, 0.060, 0.048), 0.62, "streak")
		wall.position = Vector3(0.0, 0.62, -radius - 0.05)
		root.add_child(wall)

		var pool := MeshInstance3D.new()
		pool.name = "GroundStain"
		var pq := QuadMesh.new()
		pq.size = Vector2(1.25, 1.25)
		pool.mesh = pq
		pool.material_override = PropKit.gradient_decal(
			Color(0.10, 0.085, 0.070), 0.55, "radial")
		pool.position = Vector3(out.x * 0.38, ground_y + 0.14, out.z * 0.38)
		pool.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		root.add_child(pool)
	return root


## A manhole cover in its frame, with a raised pattern and a lifting slot.
##
## `ajar` sets it skewed across the opening with the void showing — a small,
## free piece of environmental storytelling and a legible hazard at the bottom
## of the frame.
##
## opts: ajar (bool), pattern (bool), void_mat (Material), seed (int).
static func manhole_cover(parent: Node3D, at: Vector3, radius: float,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "Manhole", at)
	var rng := _rng(at, 71)

	_mi(root, "Frame", _cyl(radius * 1.2, 0.12, 20), mat, Vector3(0.0, -0.04, 0.0))
	_mi(root, "FrameRing", _cyl(radius * 1.22, 0.05, 20), mat, Vector3(0.0, 0.02, 0.0))

	var ajar: bool = bool(opts.get("ajar", false))
	if ajar:
		var void_mat: Material = opts.get("void_mat", mat)
		var hole := _mi(root, "Void", _cyl(radius * 1.02, 0.40, 18), void_mat,
			Vector3(0.0, -0.24, 0.0))
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var cover := _root(root, "Cover")
	if ajar:
		cover.position = Vector3(radius * rng.randf_range(0.30, 0.55), 0.035,
			radius * rng.randf_range(-0.22, 0.22))
		cover.rotation = Vector3(rng.randf_range(0.05, 0.13), rng.randf_range(0.0, TAU),
			rng.randf_range(-0.11, -0.04))
	else:
		cover.position = Vector3(0.0, 0.035, 0.0)
		cover.rotation.y = rng.randf_range(0.0, TAU)
	_mi(cover, "Plate", _cyl(radius, 0.08, 20), mat)

	if bool(opts.get("pattern", true)):
		# Concentric rings of raised lugs. Polar, not a grid: a cast cover is
		# turned, and the ring layout is what makes the read unmistakable.
		var mm := _mm(_box(Vector3(0.085, 0.022, 0.085)))
		var xf: Array[Transform3D] = []
		for ring in 3:
			var rr := radius * (0.34 + 0.24 * float(ring))
			var n := 6 + ring * 7
			for i in n:
				var a := TAU * float(i) / float(n) + float(ring) * 0.2
				xf.append(Transform3D(Basis(Vector3.UP, a + 0.6),
					Vector3(cos(a) * rr, 0.05, sin(a) * rr)))
		_fill(mm, xf)
		_mm_node(cover, "Lugs", mm, mat)

	# Lifting slots, both sides. They are the two dark marks that say cast iron.
	for s: float in [-1.0, 1.0]:
		_mi(cover, "Slot%s" % ("A" if s < 0.0 else "B"),
			_box(Vector3(0.24, 0.05, 0.075)), mat,
			Vector3(s * radius * 0.62, 0.055, 0.0))
	return root


# --- Rubble and spoil -------------------------------------------------------

## A pile of broken concrete: a MultiMesh of irregular chunks, a few large
## hero fragments, bent reinforcement coming out of it and a skirt of fines
## bedding it into the ground.
##
## Three things make a pile read as demolished concrete rather than as gravel.
## It is SORTED — the heavy pieces are at the bottom and the pile tapers. It
## contains SLABS, not cubes, because concrete fails in sheets. And it has
## REBAR standing out of it, which nothing else in the world does.
##
## opts: chunks (int), rebar (bool), rebar_mat (Material), hero (int), fines
## (bool), fines_mat (Material), z_spread (float — keep it tight so the pile
## stays near the gameplay plane), seed (int).
static func rubble_pile(parent: Node3D, at: Vector3, radius: float, height: float,
		mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "RubblePile", at)
	var rng := _rng(at, int(opts.get("seed", 3)))
	var z_spread: float = float(opts.get("z_spread", radius * 0.55))

	var count: int = int(opts.get("chunks", 34))
	var chunk := _box(Vector3(0.46, 0.30, 0.40))
	var mm := _mm(chunk)
	var xf: Array[Transform3D] = []
	for i in count:
		# Height biased hard toward the bottom, and the footprint closes in as
		# it rises. That falloff IS the pile; a uniform scatter is a spill.
		var t := pow(rng.randf(), 2.1)
		var y := height * t
		var ring := radius * sqrt(rng.randf()) * (1.0 - t * 0.78)
		var a := rng.randf() * TAU
		var s := lerpf(1.35, 0.42, t) * rng.randf_range(0.72, 1.35)
		var basis := Basis.from_euler(Vector3(
			rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		basis = basis.scaled(Vector3(s * rng.randf_range(0.8, 1.5), s * 0.72, s))
		xf.append(Transform3D(basis, Vector3(
			cos(a) * ring, y + 0.06, clampf(sin(a) * ring, -z_spread, z_spread))))
	_fill(mm, xf)
	_mm_node(root, "Chunks", mm, mat)

	# Hero slabs: a handful of large flat fragments leaning on the pile. These
	# carry the silhouette; the MultiMesh is only texture around them.
	var hero: int = int(opts.get("hero", 3))
	for i in hero:
		var w := radius * rng.randf_range(0.55, 1.0)
		var d := radius * rng.randf_range(0.35, 0.7)
		var slab := _mi(root, "Slab%d" % i,
			_box(Vector3(w, rng.randf_range(0.16, 0.26), d)), mat,
			Vector3(rng.randf_range(-0.8, 0.8) * radius,
				height * rng.randf_range(0.12, 0.55),
				clampf(rng.randf_range(-1.0, 1.0) * radius * 0.5, -z_spread, z_spread)))
		slab.rotation = Vector3(rng.randf_range(-0.5, 0.5),
			rng.randf() * TAU, rng.randf_range(-0.9, 0.9))

	if bool(opts.get("rebar", true)):
		var rmat: Material = opts.get("rebar_mat", mat)
		for i in 3:
			var base := Vector3(rng.randf_range(-0.6, 0.6) * radius,
				height * rng.randf_range(0.25, 0.6),
				clampf(rng.randf_range(-0.6, 0.6) * radius, -z_spread, z_spread))
			var d := Vector3(rng.randf_range(-0.6, 0.6), 1.0,
				rng.randf_range(-0.2, 0.2)).normalized()
			var p := base
			# Three segments with an increasing curl: a bar that has been bent
			# by a collapse never comes out straight.
			for k in 3:
				var seg := rng.randf_range(0.35, 0.6)
				var q := p + d * seg
				# 70 mm of bar: three times a real 20 mm starter, and the
				# minimum that survives being backlit against a bright sky.
				_segment(root, "Rebar%d_%d" % [i, k], p, q, 0.035, rmat, 6)
				p = q
				d = d.rotated(Vector3.BACK, rng.randf_range(0.25, 0.55) *
					(1.0 if rng.randf() < 0.5 else -1.0)).normalized()

	if bool(opts.get("fines", true)):
		var fmat: Material = opts.get("fines_mat", mat)
		var skirt := _mi(root, "Fines", _cyl(radius * 1.35, 0.14, 14, radius * 1.1),
			fmat, Vector3(0.0, 0.06, 0.0))
		skirt.scale = Vector3(1.0, 1.0, clampf(z_spread / maxf(radius, 0.01), 0.35, 1.0))
		var dust := MeshInstance3D.new()
		dust.name = "DustRing"
		var q := QuadMesh.new()
		q.size = Vector2(radius * 3.4, radius * 2.2)
		dust.mesh = q
		dust.material_override = PropKit.gradient_decal(
			Color(0.52, 0.47, 0.38), 0.45, "radial")
		dust.position = Vector3(0.0, 0.02, 0.0)
		dust.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		root.add_child(dust)
	return root


## A run of precast kerb with pieces tilted, sunk, shoved out of line and
## missing. Precast kerbs are all the same 900 mm unit, so this is one
## MultiMesh — the variation is entirely in the transforms, which is the whole
## trick: identical parts, individual history.
##
## opts: section (float length), height (float), width (float), missing (Array
## of indices), chaos (float 0..1), tumbled (bool — drop the missing sections
## on the ground nearby), name (String).
static func broken_kerb(parent: Node3D, from: Vector3, to: Vector3, mat: Material,
		opts := {}) -> Node3D:
	var root := _root(parent, str(opts.get("name", "BrokenKerb")))
	var delta := to - from
	var length := delta.length()
	if length < 0.2:
		return root
	root.transform = Transform3D(_basis_frame(delta.normalized(), Vector3.UP),
		(from + to) * 0.5)

	var sec: float = float(opts.get("section", 0.9))
	var kh: float = float(opts.get("height", 0.30))
	var kw: float = float(opts.get("width", 0.17))
	var chaos: float = clampf(float(opts.get("chaos", 0.5)), 0.0, 1.0)
	var count := maxi(1, int(length / sec))
	var missing: Array = opts.get("missing", [])
	var rng := _rng(from, 79)

	var mm := _mm(_box(Vector3(sec * 0.97, kh, kw)))
	var xf: Array[Transform3D] = []
	var gone: Array[int] = []
	for i in count:
		var x := -length * 0.5 + length * (float(i) + 0.5) / float(count)
		if missing.has(i) or rng.randf() < 0.07 * chaos:
			gone.append(i)
			continue
		var sink := rng.randf_range(-0.09, 0.02) * chaos
		var basis := Basis.from_euler(Vector3(
			rng.randf_range(-0.05, 0.05) * chaos,
			rng.randf_range(-0.06, 0.06) * chaos,
			rng.randf_range(-0.07, 0.07) * chaos))
		xf.append(Transform3D(basis, Vector3(x, kh * 0.5 + sink,
			rng.randf_range(-0.07, 0.07) * chaos)))
	_fill(mm, xf)
	_mm_node(root, "Sections", mm, mat)

	if bool(opts.get("tumbled", true)):
		for i in gone:
			var x := -length * 0.5 + length * (float(i) + 0.5) / float(count)
			var t := _mi(root, "Tumbled%d" % i, _box(Vector3(sec * 0.62, kh, kw)), mat,
				Vector3(x + rng.randf_range(-0.3, 0.3), kw * 0.5,
					rng.randf_range(0.25, 0.7)))
			t.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.6, 0.6),
				PI * 0.5 + rng.randf_range(-0.25, 0.25))
	return root


## A signpost that has been hit and never straightened: plumb to the knee, bent
## from there, plate still on it and still readable.
##
## A post bends where it was struck, not evenly along its length, and the plate
## keeps its own angle to the post. Get those two things right and it reads as
## damage; get them wrong and it reads as a modelling error.
##
## opts: lean (float radians), lean_dir (float, -1 or +1 along X), kink (float
## height), plate_size (Vector2), ring (bool — the red regulatory ring),
## ring_mat (Material), text (String), text_mat (Material), font (String),
## haunch (bool).
static func bent_signpost(parent: Node3D, base: Vector3, height: float,
		post_mat: Material, plate_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "BentSignpost", base)
	var rng := _rng(base, 83)
	var kink: float = float(opts.get("kink", 0.58))
	var lean: float = float(opts.get("lean", rng.randf_range(0.30, 0.62)))
	var lean_dir: float = float(opts.get("lean_dir", 1.0 if rng.randf() < 0.5 else -1.0))
	var upper := maxf(height - kink, 0.4)

	if bool(opts.get("haunch", true)):
		_mi(root, "Haunch", _box(Vector3(0.44, 0.22, 0.44)), post_mat,
			Vector3(0.0, 0.11, 0.0))
	_mi(root, "PostLower", _box(Vector3(0.09, kink, 0.09)), post_mat,
		Vector3(0.0, kink * 0.5, 0.0))
	# The crimp at the bend. A tube that folds always flattens, and that little
	# squashed block is what sells the whole prop.
	_mi(root, "Crimp", _box(Vector3(0.115, 0.13, 0.075)), post_mat,
		Vector3(0.0, kink, 0.0), Vector3(0.0, 0.0, lean_dir * lean * 0.5))

	var arm := _root(root, "Upper", Vector3(0.0, kink, 0.0))
	arm.rotation.z = -lean_dir * lean
	_mi(arm, "PostUpper", _box(Vector3(0.085, upper, 0.085)), post_mat,
		Vector3(0.0, upper * 0.5, 0.0))

	var psize: Vector2 = opts.get("plate_size", Vector2(0.9, 0.66))
	var head := _root(arm, "Head", Vector3(0.0, upper - psize.y * 0.45, 0.0))
	# The plate keeps a little of its own droop relative to the post.
	head.rotation = Vector3(0.0, rng.randf_range(-0.16, 0.16),
		lean_dir * lean * 0.35 + rng.randf_range(-0.06, 0.06))
	_mi(head, "Plate", _box(Vector3(psize.x, psize.y, 0.04)), plate_mat,
		Vector3(0.0, 0.0, 0.07))
	for i in 2:
		_mi(head, "Clamp%d" % i, _box(Vector3(0.14, 0.07, 0.13)), post_mat,
			Vector3(0.0, (-0.28 + 0.56 * float(i)) * psize.y, 0.03))

	if bool(opts.get("ring", false)):
		var ring_mat: Material = opts.get("ring_mat", plate_mat)
		var ring := TorusMesh.new()
		ring.inner_radius = psize.y * 0.36
		ring.outer_radius = psize.y * 0.46
		ring.rings = 22
		ring.ring_segments = 5
		_mi(head, "Ring", ring, ring_mat, Vector3(0.0, 0.0, 0.10),
			Vector3(PI * 0.5, 0.0, 0.0))

	if opts.has("text"):
		var tmat: Material = opts.get("text_mat", post_mat)
		var t := PropKit.sign(head, str(opts["text"]), Vector3(0.0, -0.03, 0.10),
			psize.y * 0.34, tmat, str(opts.get("font", PropKit.FONT_NASKH)), 0.008)
		t.name = "SignText"
	return root


# --- Scaffold ---------------------------------------------------------------

## A bay of tube-and-fitting scaffold: standards, ledgers, transoms, boards,
## face braces, couplers, guard rails, toe board and ties.
##
## `size` is (bay length X, TOTAL height Y, bay depth Z) and `lifts` divides the
## height. The standards run 1.05 m past the top lift because that is where the
## guard rail goes, and a scaffold whose uprights stop level with its top deck
## is the giveaway that nobody looked at a real one.
##
## Tubes are 100 mm outside diameter against a real 48 mm. Doubling it is the
## only way the lattice survives at range, and the lattice is the entire point
## of scaffold as set dressing.
##
## opts: boards (bool), boarded_lifts (Array of lift indices), braces (bool),
## couplers (bool), guard (bool), ties (Vector3 direction to the wall),
## netting (bool), net_mat (Material), ladder (bool), seed (int).
static func scaffold_bay(parent: Node3D, at: Vector3, size: Vector3, lifts: int,
		tube_mat: Material, board_mat: Material, opts := {}) -> Node3D:
	var root := _root(parent, "ScaffoldBay", at)
	var rng := _rng(at, int(opts.get("seed", 5)))
	lifts = maxi(1, lifts)
	var lift_h := size.y / float(lifts)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var tube_r := 0.05
	var guard_h := 1.05

	var corners := [
		Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	for i in corners.size():
		var c: Vector2 = corners[i]
		_mi(root, "Standard%d" % i, _cyl(tube_r, size.y + guard_h, 8),
			tube_mat, Vector3(c.x, (size.y + guard_h) * 0.5, c.y))
		# Base plate on a sole board. Scaffold never stands on bare ground.
		_mi(root, "BasePlate%d" % i, _box(Vector3(0.18, 0.05, 0.18)), tube_mat,
			Vector3(c.x, 0.025, c.y))
		_mi(root, "SoleBoard%d" % i, _box(Vector3(0.34, 0.045, 0.30)), board_mat,
			Vector3(c.x, 0.0, c.y))

	var coupler_xf: Array[Transform3D] = []
	var levels: Array[float] = []
	for l in range(1, lifts + 1):
		levels.append(lift_h * float(l))
	levels.append(size.y + guard_h * 0.55)
	levels.append(size.y + guard_h)

	for li in levels.size():
		var y: float = levels[li]
		# Ledgers run the length of the bay on both faces.
		for s: float in [-1.0, 1.0]:
			_mi(root, "Ledger%d_%s" % [li, "A" if s < 0.0 else "B"],
				_cyl(tube_r, size.x, 8), tube_mat, Vector3(0.0, y, s * hz),
				Vector3(0.0, 0.0, PI * 0.5))
			for c: Vector2 in corners:
				coupler_xf.append(Transform3D(Basis.IDENTITY, Vector3(c.x, y, c.y)))
		# Transoms tie the two faces together. Only on the working lifts —
		# the guard rail levels do not get them, which is correct and also
		# stops the top of the bay reading as a solid block.
		if li < lifts:
			var trans := 3
			for t in trans:
				var x := -hx + size.x * (float(t) + 0.5) / float(trans)
				_mi(root, "Transom%d_%d" % [li, t], _cyl(tube_r * 0.95, size.z, 8),
					tube_mat, Vector3(x, y + 0.055, 0.0), Vector3(PI * 0.5, 0.0, 0.0))

	# Boards. One board always overhangs the end of the bay, because one always
	# does, and that overhang is the most recognisable thing about scaffold.
	if bool(opts.get("boards", true)):
		var boarded: Array = opts.get("boarded_lifts", [lifts - 1])
		for l: int in boarded:
			var y := lift_h * float(l + 1) + 0.09
			var n := maxi(3, int(size.z / 0.26))
			for b in n:
				var z := -hz + size.z * (float(b) + 0.5) / float(n)
				var over := 0.0
				if b == n - 2:
					over = rng.randf_range(0.30, 0.55)
				_mi(root, "Board%d_%d" % [l, b],
					_box(Vector3(size.x + over, 0.045, size.z / float(n) - 0.025)),
					board_mat, Vector3(over * 0.5, y, z))
			_mi(root, "ToeBoard%d" % l, _box(Vector3(size.x, 0.16, 0.035)), board_mat,
				Vector3(0.0, y + 0.10, hz))

	# Face braces in the XY plane — the plane the camera actually sees. A
	# scaffold without its diagonals is a grid and reads as scaffolding-shaped
	# fencing.
	if bool(opts.get("braces", true)):
		var dir := 1.0
		for l in lifts:
			var y0 := lift_h * float(l)
			var y1 := lift_h * float(l + 1)
			var a := Vector3(-hx * dir, y0, hz)
			var b := Vector3(hx * dir, y1, hz)
			_segment(root, "Brace%d" % l, a, b, tube_r * 0.92, tube_mat, 8)
			coupler_xf.append(Transform3D(Basis.IDENTITY, a))
			coupler_xf.append(Transform3D(Basis.IDENTITY, b))
			dir = -dir

	if opts.has("ties"):
		var tie_dir: Vector3 = (opts["ties"] as Vector3).normalized()
		for l in maxi(1, lifts / 2):
			var y := lift_h * float(l * 2 + 1)
			var p := Vector3(-hx + size.x * 0.25, y, 0.0)
			_segment(root, "Tie%d" % l, p, p + tie_dir * 0.9, tube_r * 0.9, tube_mat, 8)
			_mi(root, "TiePlate%d" % l, _box(Vector3(0.16, 0.22, 0.06)), tube_mat,
				p + tie_dir * 0.95)

	if bool(opts.get("couplers", true)):
		# Right-angle couplers at every junction. Individually they are noise;
		# fifty of them are what make the tubes look joined rather than crossed.
		var mm := _mm(_cyl(tube_r * 1.75, 0.16, 8))
		var seen: Array[Transform3D] = []
		for xf in coupler_xf:
			seen.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), xf.origin))
		_fill(mm, seen)
		_mm_node(root, "Couplers", mm, tube_mat)

	if bool(opts.get("netting", false)):
		# Debris netting on the open face: the bay's DRAPE element, sagging
		# between its ties. Every screen needs one thing that hangs.
		var net_mat: Material = opts.get("net_mat", MaterialLab.cloth(
			Color(0.62, 0.60, 0.52), 0.94))
		var strips := 7
		for i in strips:
			var t := (float(i) + 0.5) / float(strips)
			var sag := sin(t * PI) * 0.22
			var panel := _mi(root, "Net%d" % i,
				_box(Vector3(size.x / float(strips) * 1.04, size.y * 0.82, 0.02)),
				net_mat,
				Vector3(-hx + size.x * t, size.y * 0.45, hz + 0.10 + sag))
			panel.rotation = Vector3(0.0, rng.randf_range(-0.05, 0.05),
				rng.randf_range(-0.02, 0.02))

	if bool(opts.get("ladder", false)):
		ladder(root, Vector3(hx * 0.45, 0.0, -hz + 0.35), size.y,
			tube_mat, {"cage": false, "width": 0.5, "standoff": 0.18, "extension": 0.9})
	return root
