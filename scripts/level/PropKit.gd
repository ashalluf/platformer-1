class_name PropKit
## The World 1 prop library.
##
## Industrial and vernacular forms built from code: prefab wall panels with
## crane holes, storage tanks, prilling towers, flare lattices, fences,
## windbreaks, pipe racks, walkways. Brega needs all of them and Ajdabiya,
## Garyounis and Benghazi reuse most of them.
##
## Everything here is decorative unless a function says otherwise. Collision is
## the level builder's business.

const CHAINLINK_SHADER := preload("res://shaders/chainlink.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/foliage_wind.gdshader")

const FONT_NASKH := "res://assets/fonts/NotoNaskhArabic-Regular.ttf"
const FONT_NASKH_BOLD := "res://assets/fonts/NotoNaskhArabic-Bold.ttf"
const FONT_KUFI := "res://assets/fonts/NotoKufiArabic-Regular.ttf"

static var _fonts: Dictionary = {}


static func font(path := FONT_NASKH) -> FontFile:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


## Painted or applied lettering on a surface. Godot's TextServer does the Arabic
## shaping and bidi, so the strings here are written the way they are read.
static func sign(parent: Node3D, text: String, pos: Vector3, height: float,
		mat: Material, font_path := FONT_NASKH, depth := 0.012) -> MeshInstance3D:
	var tm := TextMesh.new()
	tm.text = text
	tm.font = font(font_path)
	tm.font_size = 96
	# pixel_size converts font units to world units; height is the cap height
	# the caller wants on the wall.
	tm.pixel_size = height / 96.0
	tm.depth = depth
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return _mi(parent, "Sign", tm, mat, pos)


static func _mi(parent: Node3D, name_: String, mesh: Mesh, mat: Material,
		pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Chamfered, like everything else. A hard ninety-degree edge is the loudest
## blockout signal there is, and PropKit builds most of the world.
static func _box(size: Vector3) -> Mesh:
	return LevelKit.chamfer_mesh(size)


static func _cyl(radius: float, height: float, sides := 24, top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


# --- Prefab concrete facade -------------------------------------------------

## The eastern Libyan prefab block: 3.0 m x 1.2 m slabs with a circular crane
## hole at the centre of every panel, most mortared shut. Reading those holes is
## how you know the building is prefab and not rendered blockwork.
static func prefab_facade(parent: Node3D, left_x: float, base_y: float, width: float,
		height: float, z: float, mat: Material, opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = str(opts.get("name", "Facade"))
	parent.add_child(root)

	var depth: float = opts.get("depth", 2.2)
	_mi(root, "Mass", _box(Vector3(width, height, depth)), mat,
		Vector3(left_x + width * 0.5, base_y + height * 0.5, z))

	var joint: Material = opts.get("joint_mat", mat)
	var dark: Material = opts.get("dark_mat", joint)
	var front := z + depth * 0.5
	# A stable per-facade seed, so the same wall comes back identical every run
	# but two walls in one level are not the same wall.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", int(absf(left_x) * 977.0 + width * 31.0)))

	# --- Bays ---------------------------------------------------------------
	# Real prefab blocks are cast from a handful of panel widths, not one. Walk
	# the wall laying bays down until it is covered; the last one is trimmed.
	var bay_widths := [3.0, 3.0, 3.0, 2.4, 3.6]
	var bays: Array[float] = []
	var x := 0.0
	while x < width - 0.05:
		var w: float = bay_widths[rng.randi() % bay_widths.size()]
		w = minf(w, width - x)
		bays.append(w)
		x += w

	var panel_h := 1.2
	var rows := int(ceil(height / panel_h))

	# --- Joints -------------------------------------------------------------
	var vert_mm := _joint_multimesh(_box(Vector3(0.022, height, 0.03)))
	var verts: Array[Transform3D] = []
	var bay_x := 0.0
	for w: float in bays:
		verts.append(Transform3D(Basis.IDENTITY,
			Vector3(left_x + bay_x, base_y + height * 0.5, front)))
		bay_x += w
	verts.append(Transform3D(Basis.IDENTITY,
		Vector3(left_x + width, base_y + height * 0.5, front)))
	_fill_multimesh(vert_mm, verts)
	_mm_node(root, "JointsV", vert_mm, joint)

	# --- Relief -------------------------------------------------------------
	#
	# Everything above this point draws the wall as a flat slab with joint
	# lines 0.03 deep — i.e. painted on. Measured across a Brega frame, every
	# horizontal band of the image came back between 0.70 and 0.74 luminance:
	# sky, wall, walkway and ground were the same value, because the largest
	# surface in the level had nothing on it that could catch the light at a
	# different angle from anything else.
	#
	# A precast panel wall is not flat. The ribs between bays stand proud, the
	# plinth steps out, and the coping oversails. Those three things are what
	# give a concrete facade its value structure, and they cost almost nothing
	# here because each is one MultiMesh.
	#
	# Proud, not recessed, on purpose: a rib standing out shows the camera two
	# faces the flat wall does not have — a right cheek turned toward the key
	# and a left cheek turned away from it.
	#
	# The depth matters more than it looks. Brega's key runs (-0.53, -0.11,
	# -0.84): mostly INTO the wall rather than along it, so a rib's cast shadow
	# only reaches about 0.63 of its own projection and a shallow rib produces
	# a shadow a few centimetres wide. What reads at this sun angle is the side
	# cheeks themselves, and at 0.085 proud those are a couple of pixels tall.
	# 0.16 — a 32 cm rib on a heavy precast block, which is honest — makes them
	# a band you can actually see.
	var relief: float = opts.get("relief", 0.16)
	if relief > 0.001:
		# Bay ribs, full height.
		var rib_mm := _joint_multimesh(
			_box(Vector3(0.14, height, relief * 2.0)))
		var ribs: Array[Transform3D] = []
		var rib_x := 0.0
		for w: float in bays:
			ribs.append(Transform3D(Basis.IDENTITY,
				Vector3(left_x + rib_x, base_y + height * 0.5, front)))
			rib_x += w
		ribs.append(Transform3D(Basis.IDENTITY,
			Vector3(left_x + width, base_y + height * 0.5, front)))
		_fill_multimesh(rib_mm, ribs)
		_mm_node(root, "Ribs", rib_mm, mat)

		# Floor bands every third panel course. A wall this tall needs a
		# horizontal to break it as much as it needs verticals.
		var band_mm := _joint_multimesh(
			_box(Vector3(width, 0.26, relief * 1.5)))
		var bands: Array[Transform3D] = []
		var course := 3
		var r := course
		while float(r) * panel_h < height - 0.4:
			bands.append(Transform3D(Basis.IDENTITY,
				Vector3(left_x + width * 0.5, base_y + float(r) * panel_h, front)))
			r += course
		if not bands.is_empty():
			_fill_multimesh(band_mm, bands)
			_mm_node(root, "Bands", band_mm, mat)

		# The plinth. A wall that meets the ground with no step reads as a
		# cardboard flat pushed into the dirt, and this is also the shadow that
		# separates the wall from whatever is standing in front of it.
		_mi(root, "Plinth", _box(Vector3(width, 0.95, relief * 3.2)), mat,
			Vector3(left_x + width * 0.5, base_y + 0.46, front))

		# The coping, oversailing both ends. Its shadow is the darkest line on
		# the whole facade and it lands right where the wall meets the sky,
		# which is the edge the eye reads first.
		_mi(root, "Coping", _box(Vector3(width + 0.5, 0.34, relief * 4.0)), mat,
			Vector3(left_x + width * 0.5, base_y + height - 0.10, front))

	# --- Panel tone ---------------------------------------------------------
	#
	# Precast panels are cast in batches, months apart, from whatever sand and
	# cement the yard had that week, and they do not match. On a real block you
	# can read the pour sequence off the wall.
	#
	# This is also the only thing that gives a facade this size a value
	# structure. Measured on a Brega frame, every horizontal band of the image
	# came back between 0.70 and 0.74 — sky, wall, walkway and ground at one
	# value — because a 74-metre wall drawn in a single material cannot have
	# one. Relief alone does not fix it: at a key that runs mostly INTO the
	# wall, a rib and the panel beside it are lit almost identically.
	#
	# Thin slabs proud of the face rather than a second mass, so they cost one
	# MultiMesh and cannot z-fight with the wall behind them.
	var pours: Array = opts.get("tone_mats", [])
	if not pours.is_empty():
		var tone_ratio: float = opts.get("tone_ratio", 0.34)
		var per_pour: Array[Array] = []
		for _t in pours.size():
			per_pour.append([] as Array[Transform3D])
		var course_h := panel_h * 2.0
		var courses := maxi(1, int(height / course_h))
		var tx := 0.0
		for bi in bays.size():
			var bw: float = bays[bi]
			for c in courses:
				if rng.randf() > tone_ratio:
					continue
				var ch := minf(course_h, height - float(c) * course_h)
				if ch < 0.3:
					continue
				var ti := rng.randi() % pours.size()
				# Inset from the bay edges so the rib and the joint still read
				# as the module; a tone that runs edge to edge erases them.
				var xf := Transform3D(
					Basis.IDENTITY.scaled(Vector3((bw - 0.22) / 1.0, ch - 0.10, 1.0)),
					Vector3(left_x + tx + bw * 0.5,
						base_y + float(c) * course_h + ch * 0.5,
						front + relief * 2.0 + 0.012))
				(per_pour[ti] as Array[Transform3D]).append(xf)
			tx += bw
		for ti in pours.size():
			var list: Array[Transform3D] = per_pour[ti]
			if list.is_empty():
				continue
			var tm := _joint_multimesh(_box(Vector3(1.0, 1.0, 0.02)))
			_fill_multimesh(tm, list)
			_mm_node(root, "PanelTone%d" % ti, tm, pours[ti])

	var horiz_mm := _joint_multimesh(_box(Vector3(width, 0.022, 0.03)))
	var horiz: Array[Transform3D] = []
	for r in rows + 1:
		var jy := base_y + r * panel_h
		if jy > base_y + height:
			break
		horiz.append(Transform3D(Basis.IDENTITY,
			Vector3(left_x + width * 0.5, jy, front)))
	_fill_multimesh(horiz_mm, horiz)
	_mm_node(root, "JointsH", horiz_mm, joint)

	# --- Lifting holes ------------------------------------------------------
	# Two per panel, near its top corners, which is where a crane actually
	# takes a slab — and most of them have been grouted up since. Only the
	# unpatched ones read, and they are the ones that stain.
	var open_count: int = opts.get("open_holes", 3)
	var patched: Array[Transform3D] = []
	var open_holes: Array[Transform3D] = []
	var stains: Array[Transform3D] = []
	bay_x = 0.0
	for bi in bays.size():
		var w: float = bays[bi]
		for r in rows:
			var hy := base_y + (r + 1) * panel_h - 0.26
			if hy > base_y + height - 0.2:
				continue
			for side in 2:
				var hx := left_x + bay_x + (0.42 if side == 0 else w - 0.42)
				var basis := Basis(Vector3.RIGHT, PI * 0.5).scaled(
					Vector3(1.0, 0.55, 1.0))
				var open_hole := rng.randf() < (float(open_count) / 14.0)
				if open_hole:
					open_holes.append(Transform3D(
						Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.9, 1.0)),
						Vector3(hx, hy, front - 0.05)))
					stains.append(Transform3D(
						Basis.IDENTITY.scaled(Vector3(0.20,
							rng.randf_range(0.55, 1.35), 1.0)),
						Vector3(hx, hy - 0.42, front + 0.014)))
				else:
					patched.append(Transform3D(basis, Vector3(hx, hy, front + 0.014)))
		bay_x += w

	var hole_mesh := _cyl(0.055, 0.05, 10)
	if not patched.is_empty():
		var pm := _joint_multimesh(hole_mesh)
		_fill_multimesh(pm, patched)
		_mm_node(root, "HolesPatched", pm, opts.get("hole_mat", joint))
	if not open_holes.is_empty():
		var om := _joint_multimesh(hole_mesh)
		_fill_multimesh(om, open_holes)
		_mm_node(root, "HolesOpen", om, dark)

	# --- Weathering ---------------------------------------------------------
	# Streaks under the horizontal joints are the single most recognisable
	# thing about a concrete panel wall, and they are what stops the grid
	# reading as graph paper.
	var streaks: Array[Transform3D] = []
	bay_x = 0.0
	for bi in bays.size():
		var w: float = bays[bi]
		for r in rows:
			var jy := base_y + (r + 1) * panel_h
			if jy > base_y + height:
				continue
			var count := rng.randi_range(1, 3)
			for _i in count:
				var sx := left_x + bay_x + rng.randf_range(0.25, w - 0.25)
				var sh := rng.randf_range(0.35, 1.05)
				var sw := rng.randf_range(0.10, 0.34)
				streaks.append(Transform3D(
					Basis.IDENTITY.scaled(Vector3(sw, sh, 1.0)),
					Vector3(sx, jy - sh * 0.5, front + 0.012)))
		bay_x += w
	if not streaks.is_empty():
		var sm := _joint_multimesh(_unit_quad())
		_fill_multimesh(sm, streaks)
		_mm_node(root, "Streaks", sm,
			gradient_decal(Color(0.085, 0.068, 0.055), 0.62, "streak"))

	# Stains under the open holes, darker and narrower than the joint runs.
	if not stains.is_empty():
		var stm := _joint_multimesh(_unit_quad())
		_fill_multimesh(stm, stains)
		_mm_node(root, "HoleStains", stm,
			gradient_decal(Color(0.065, 0.050, 0.040), 0.85, "streak"))

	# Salt fretting: the pale damp band that eats the bottom metre of every
	# wall on this coast.
	var salt := MeshInstance3D.new()
	salt.name = "SaltBand"
	var sq := QuadMesh.new()
	sq.size = Vector2(width, 1.6)
	salt.mesh = sq
	salt.material_override = gradient_decal(Color(0.80, 0.775, 0.710), 0.58, "band")
	salt.position = Vector3(left_x + width * 0.5, base_y + 0.8, front + 0.010)
	root.add_child(salt)

	# Big, soft tonal patches: no two panels came out of the mould the same
	# colour, and at gameplay distance that variation is the only material
	# detail that survives.
	var tones: Array[Transform3D] = []
	for _i in maxi(4, int(width / 6.0)):
		var tw := rng.randf_range(3.0, 9.0)
		var th := rng.randf_range(2.0, height * 0.9)
		tones.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(tw, th, 1.0)),
			Vector3(left_x + rng.randf_range(0.0, width),
				base_y + rng.randf_range(0.0, height), front + 0.008)))
	var tm := _joint_multimesh(_unit_quad())
	_fill_multimesh(tm, tones)
	_mm_node(root, "Tones", tm,
		gradient_decal(Color(0.30, 0.255, 0.195), 0.34, "radial"))
	return root


## A 1x1 quad with its origin at the centre, for decals scaled by transform.
static func _unit_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return q


static func _joint_multimesh(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	return mm


static func _fill_multimesh(mm: MultiMesh, xforms: Array[Transform3D]) -> void:
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])


static func _mm_node(parent: Node3D, name_: String, mm: MultiMesh,
		mat: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = mm
	node.material_override = mat
	parent.add_child(node)
	return node


## A soft-edged decal on a flat surface, generated rather than authored, so
## weathering costs a 64px image instead of a texture in the repository.
##
## `mode` is "streak" (strong at the top, running down, soft at both sides),
## "radial" (a soft blob) or "band" (strong at the bottom, fading up).
static func gradient_decal(tint: Color, strength: float,
		mode := "radial") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint.r, tint.g, tint.b, strength)
	m.albedo_texture = _decal_texture(mode)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.95
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static var _decal_cache := {}

## A single-channel falloff in alpha. A one-dimensional gradient cannot do
## this: a dirt run needs to fade down AND off both sides, or it reads as a
## grey rectangle stuck to the wall.
static func _decal_texture(mode: String) -> ImageTexture:
	if _decal_cache.has(mode):
		return _decal_cache[mode]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size)
			# QuadMesh UVs put v = 0 at the top, which is where a run starts.
			var v := (float(y) + 0.5) / float(size)
			var a := 0.0
			match mode:
				"streak":
					a = pow(1.0 - v, 1.45) * pow(sin(u * PI), 1.1)
				"band":
					a = pow(v, 1.7) * clampf(minf(u, 1.0 - u) * 7.0, 0.0, 1.0)
				_:
					var d := Vector2(u - 0.5, v - 0.5).length() * 2.0
					a = clampf(1.0 - d, 0.0, 1.0)
					a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var tex := ImageTexture.create_from_image(img)
	_decal_cache[mode] = tex
	return tex


## A slack cable between two points. Catenary, not a straight line: a straight
## cable is the single fastest way to make a skyline look untouched by gravity.
static func cable(parent: Node3D, from: Vector3, to: Vector3, sag: float,
		mat: Material, segments := 14, thickness := 0.035) -> MultiMeshInstance3D:
	var pts: Array[Vector3] = []
	for i in segments + 1:
		var t := float(i) / float(segments)
		var p := from.lerp(to, t)
		p.y -= sag * sin(t * PI)
		pts.append(p)

	var mm := _joint_multimesh(_box(Vector3(1.0, thickness, thickness)))
	var xf: Array[Transform3D] = []
	for i in segments:
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var dir := (b - a)
		var basis := Basis.IDENTITY.scaled(Vector3(dir.length(), 1.0, 1.0))
		# Aim the segment down the run: yaw then pitch, which is enough for a
		# cable that never rolls.
		var yaw := atan2(-dir.z, dir.x)
		var pitch := asin(clampf(dir.normalized().y, -1.0, 1.0))
		basis = Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), pitch) * basis
		xf.append(Transform3D(basis, mid))
	_fill_multimesh(mm, xf)
	return _mm_node(parent, "Cable", mm, mat)


## Roof clutter: aerials, a dish, a header tank. Silhouette against the sky is
## what makes a roofline read as lived on rather than as the top of a box.
static func roof_clutter(parent: Node3D, left_x: float, top_y: float, width: float,
		z: float, mat: Material, seed_ := 7) -> Node3D:
	var root := Node3D.new()
	root.name = "RoofClutter"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_

	var count := maxi(3, int(width / 9.0))
	for i in count:
		var x := left_x + (float(i) + rng.randf_range(0.15, 0.85)) * (width / float(count))
		match rng.randi() % 3:
			0:
				# Television aerial: a mast with a ladder of elements.
				# Thick on purpose: at gameplay distance anything under about
				# 70 mm disappears into the sky and the roofline goes bald.
				var h := rng.randf_range(1.6, 2.8)
				_mi(root, "Mast%d" % i, _box(Vector3(0.085, h, 0.085)), mat,
					Vector3(x, top_y + h * 0.5, z))
				for e in rng.randi_range(3, 6):
					var ey := top_y + h * (0.42 + 0.11 * e)
					var ew: float = 1.25 - 0.13 * e
					_mi(root, "Element%d_%d" % [i, e],
						_box(Vector3(ew, 0.065, 0.065)), mat, Vector3(x, ey, z))
			1:
				# Satellite dish on a stub pole, all of them facing the same way
				# because they are all pointed at the same satellite.
				var ph := rng.randf_range(0.7, 1.2)
				_mi(root, "DishPole%d" % i, _box(Vector3(0.095, ph, 0.095)), mat,
					Vector3(x, top_y + ph * 0.5, z))
				var dish := _mi(root, "Dish%d" % i, _cyl(0.58, 0.09, 16), mat,
					Vector3(x, top_y + ph + 0.38, z + 0.18),
					Vector3(deg_to_rad(66.0), 0.0, 0.0))
				dish.scale = Vector3(1.0, 1.0, 0.85)
			_:
				# Header tank on legs: every roof on this coast has one.
				var tw := rng.randf_range(0.7, 1.1)
				_mi(root, "TankLegs%d" % i, _box(Vector3(tw * 0.8, 0.34, 0.6)), mat,
					Vector3(x, top_y + 0.17, z))
				_mi(root, "HeaderTank%d" % i,
					_cyl(tw * 0.5, tw * 0.72, 14), mat,
					Vector3(x, top_y + 0.34 + tw * 0.36, z))
	return root


## Everything bolted to the front of a lived-in block: downpipes, conduit runs,
## split-unit condensers, a washing line. A shadowed wall has no light to give
## it structure, so all of its detail has to be silhouette standing off the
## face — which is also exactly what a real one looks like.
static func wall_services(parent: Node3D, left_x: float, base_y: float,
		width: float, height: float, z: float, pipe_mat: Material,
		box_mat: Material, seed_ := 3) -> Node3D:
	var root := Node3D.new()
	root.name = "WallServices"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_

	# Downpipes: full height, standing 120 mm off the face, with brackets.
	var drops := maxi(3, int(width / 6.5))
	for i in drops:
		var x := left_x + (float(i) + rng.randf_range(0.2, 0.8)) * (width / float(drops))
		var r := rng.randf_range(0.075, 0.105)
		_mi(root, "Downpipe%d" % i, _cyl(r, height, 8), pipe_mat,
			Vector3(x, base_y + height * 0.5, z + 0.12))
		# The shoe at the bottom, kicking the water out into the yard.
		_mi(root, "Shoe%d" % i, _cyl(r, 0.5, 8), pipe_mat,
			Vector3(x, base_y + 0.28, z + 0.34), Vector3(deg_to_rad(38.0), 0, 0))
		for b in int(height / 2.2):
			_mi(root, "Bracket%d_%d" % [i, b], _box(Vector3(0.05, 0.05, 0.26)),
				pipe_mat, Vector3(x, base_y + 0.9 + b * 2.2, z + 0.06))

	# Horizontal conduit runs: the wiring someone added later, going round
	# whatever was already there.
	var runs := maxi(3, int(width / 9.0))
	for i in runs:
		var y := base_y + rng.randf_range(height * 0.25, height * 0.8)
		var x0 := left_x + rng.randf_range(0.0, width * 0.4)
		var w := rng.randf_range(width * 0.25, width * 0.55)
		_mi(root, "Conduit%d" % i, _box(Vector3(w, 0.07, 0.07)), pipe_mat,
			Vector3(x0 + w * 0.5, y, z + 0.09))
		# A drop off the end into a junction box.
		var dh := rng.randf_range(0.8, 2.4)
		_mi(root, "ConduitDrop%d" % i, _box(Vector3(0.07, dh, 0.07)), pipe_mat,
			Vector3(x0 + w, y - dh * 0.5, z + 0.09))
		_mi(root, "Junction%d" % i, _box(Vector3(0.22, 0.30, 0.16)), box_mat,
			Vector3(x0 + w, y - dh, z + 0.12))

	# Split-unit condensers on brackets, all at about the same height because
	# they all went in the same year.
	var units := maxi(3, int(width / 7.5))
	for i in units:
		var x := left_x + (float(i) + rng.randf_range(0.25, 0.75)) * (width / float(units))
		var y := base_y + height * rng.randf_range(0.55, 0.72)
		_mi(root, "AC%d" % i, _box(Vector3(1.15, 0.74, 0.44)), box_mat,
			Vector3(x, y, z + 0.20))
		_mi(root, "ACBracket%d" % i, _box(Vector3(1.25, 0.08, 0.40)), pipe_mat,
			Vector3(x, y - 0.41, z + 0.22))
		_mi(root, "ACPipe%d" % i, _box(Vector3(0.06, 1.1, 0.06)), pipe_mat,
			Vector3(x + 0.34, y - 0.85, z + 0.10))
	return root


## A distillation column: a tall cylinder with platform rings, a caged ladder
## running the whole way up one side, and a head at the top. Read at distance
## it is a vertical with rungs in it, which is the only thing that separates a
## refinery from a row of chimneys.
static func column(parent: Node3D, base: Vector3, height: float, radius: float,
		mat: Material, platform_mat: Material, platforms := 4) -> Node3D:
	var root := Node3D.new()
	root.name = "Column"
	root.position = base
	parent.add_child(root)

	_mi(root, "Shell", _cyl(radius, height, 16), mat, Vector3(0, height * 0.5, 0))
	_mi(root, "Head", _cyl(radius, radius * 1.1, 16, radius * 0.35), mat,
		Vector3(0, height + radius * 0.5, 0))
	_mi(root, "Skirt", _cyl(radius * 1.12, 1.2, 16), mat, Vector3(0, 0.6, 0))

	for i in platforms:
		var y := height * (0.22 + 0.74 * float(i) / float(maxi(platforms - 1, 1)))
		_mi(root, "Platform%d" % i, _cyl(radius * 1.7, 0.10, 16), platform_mat,
			Vector3(0, y, 0))
		_mi(root, "Handrail%d" % i, _cyl(radius * 1.7, 0.05, 16), platform_mat,
			Vector3(0, y + 0.95, 0))
	# Caged ladder up the near face.
	_mi(root, "Ladder", _box(Vector3(0.5, height, 0.10)), platform_mat,
		Vector3(0, height * 0.5, radius + 0.1))
	for r in int(height / 1.4):
		_mi(root, "Rung%d" % r, _box(Vector3(0.62, 0.06, 0.06)), platform_mat,
			Vector3(0, 0.8 + r * 1.4, radius + 0.24))
	return root


## A horizontal pressure vessel on saddles. Its dished ends are what say
## "pressure" rather than "tank".
static func vessel(parent: Node3D, at: Vector3, length: float, radius: float,
		mat: Material, saddle_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Vessel"
	root.position = at
	parent.add_child(root)
	_mi(root, "Shell", _cyl(radius, length, 16), mat, Vector3.ZERO,
		Vector3(0, 0, PI * 0.5))
	for side: float in [-1.0, 1.0]:
		var cap := _mi(root, "Cap%s" % ("A" if side < 0.0 else "B"),
			_cyl(radius * 0.99, radius * 0.7, 16, radius * 0.45), mat,
			Vector3(side * (length * 0.5 + radius * 0.35), 0, 0),
			Vector3(0, 0, side * PI * 0.5))
		cap.scale = Vector3(1.0, 1.0, 1.0)
	for i in 2:
		var x := (-0.28 + 0.56 * i) * length
		_mi(root, "Saddle%d" % i, _box(Vector3(radius * 0.9, radius * 1.5, radius * 2.1)),
			saddle_mat, Vector3(x, -radius * 1.05, 0))
	return root


## A stacked bank of oil drums. Cheap silhouette, and it says what the yard was
## for better than any label.
static func drum_stack(parent: Node3D, at: Vector3, cols: int, rows: int,
		mat: Material) -> MultiMeshInstance3D:
	var mm := _joint_multimesh(_cyl(0.30, 0.88, 12))
	var xf: Array[Transform3D] = []
	for r in rows:
		for c in cols - r:
			xf.append(Transform3D(Basis.IDENTITY,
				at + Vector3(c * 0.66 + r * 0.33, 0.44 + r * 0.9, sin(c * 3.1 + r) * 0.2)))
	_fill_multimesh(mm, xf)
	return _mm_node(parent, "DrumStack", mm, mat)


## A washing line between two points with cloth pegged along it. In a frame
## whose subject is a dark building, three squares of colour on a wire are
## worth more than any amount of surface detail — they say the place is lived
## in, and they are the only saturated thing allowed on that wall.
static func laundry_line(parent: Node3D, from: Vector3, to: Vector3, sag: float,
		wire_mat: Material, colours: Array, seed_ := 11) -> Node3D:
	var root := Node3D.new()
	root.name = "LaundryLine"
	parent.add_child(root)
	cable(root, from, to, sag, wire_mat, 10, 0.022)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var count := rng.randi_range(3, 5)
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var p := from.lerp(to, t)
		p.y -= sag * sin(t * PI)
		var w := rng.randf_range(0.46, 0.80)
		var h := rng.randf_range(0.58, 1.10)
		var cloth := MaterialLab.cloth(colours[rng.randi() % colours.size()], 0.92)
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := _mi(root, "Cloth%d" % i, _box(Vector3(w, h, 0.02)), cloth,
			p + Vector3(0.0, -h * 0.5 - 0.02, 0.02))
		mi.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.09, 0.09))
	return root


## A window with a light on behind it. The single cheapest way to make a dark
## mass read as a building with people in it, and in a backlit frame it is the
## only warm accent the shadow side gets.
static func lit_window(parent: Node3D, pos: Vector3, size: Vector2,
		frame_mat: Material, tint := Color(1.0, 0.72, 0.36),
		energy := 2.4) -> Node3D:
	var root := Node3D.new()
	root.name = "LitWindow"
	root.position = pos
	parent.add_child(root)

	_mi(root, "Reveal", _box(Vector3(size.x + 0.16, size.y + 0.16, 0.18)),
		frame_mat, Vector3(0, 0, -0.06))
	var pane := _mi(root, "Pane", _box(Vector3(size.x, size.y, 0.04)),
		MaterialLab.emissive(tint, energy), Vector3(0, 0, 0.02))
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A mullion, so the pane is a window and not a glowing tile.
	_mi(root, "Mullion", _box(Vector3(0.05, size.y, 0.06)), frame_mat,
		Vector3(0, 0, 0.05))

	var spill := OmniLight3D.new()
	spill.name = "Spill"
	spill.light_color = tint
	spill.light_energy = energy * 0.5
	spill.omni_range = 3.4
	spill.shadow_enabled = false
	spill.position = Vector3(0, 0, 0.5)
	root.add_child(spill)
	return root


## A precast perimeter wall: panels between piers, a coping band along the top,
## salt fretting at the base and dirt running off the coping. A plain box of
## one colour is the fastest way to make the middle distance look unfinished,
## and this is the shape that band of every frame in World 1 is made of.
static func perimeter_wall(parent: Node3D, left_x: float, base_y: float,
		width: float, height: float, z: float, panel_mat: Material,
		pier_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "PerimeterWall"
	parent.add_child(root)

	_mi(root, "Panels", _box(Vector3(width, height, 0.7)), panel_mat,
		Vector3(left_x + width * 0.5, base_y + height * 0.5, z))
	# Coping: the lip along the top that every runoff streak starts from.
	_mi(root, "Coping", _box(Vector3(width, 0.22, 1.0)), pier_mat,
		Vector3(left_x + width * 0.5, base_y + height + 0.05, z))

	var pitch := 4.2
	var piers := maxi(2, int(width / pitch))
	var pier_mm := _joint_multimesh(_box(Vector3(0.45, height + 0.3, 1.0)))
	var pier_xf: Array[Transform3D] = []
	for i in piers + 1:
		pier_xf.append(Transform3D(Basis.IDENTITY,
			Vector3(left_x + width * float(i) / float(piers),
				base_y + (height + 0.3) * 0.5, z)))
	_fill_multimesh(pier_mm, pier_xf)
	_mm_node(root, "Piers", pier_mm, pier_mat)

	# Runoff off the coping, one or two per bay.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(left_x) * 613.0 + width)
	var streaks: Array[Transform3D] = []
	for i in piers:
		for _k in rng.randi_range(1, 2):
			var sx := left_x + width * (float(i) + rng.randf_range(0.2, 0.8)) / float(piers)
			var sh := rng.randf_range(height * 0.35, height * 0.85)
			streaks.append(Transform3D(
				Basis.IDENTITY.scaled(Vector3(rng.randf_range(0.18, 0.5), sh, 1.0)),
				Vector3(sx, base_y + height - sh * 0.5, z + 0.36)))
	var sm := _joint_multimesh(_unit_quad())
	_fill_multimesh(sm, streaks)
	_mm_node(root, "WallStreaks", sm,
		gradient_decal(Color(0.085, 0.068, 0.055), 0.55, "streak"))

	var salt := MeshInstance3D.new()
	salt.name = "WallSalt"
	var sq := QuadMesh.new()
	sq.size = Vector2(width, height * 0.55)
	salt.mesh = sq
	salt.material_override = gradient_decal(Color(0.78, 0.755, 0.695), 0.46, "band")
	salt.position = Vector3(left_x + width * 0.5, base_y + height * 0.275, z + 0.37)
	root.add_child(salt)
	return root


## A date palm. Not the eucalyptus builder with green on it: a palm is a bare
## fibrous column and a crown of long fronds that arch and droop, and the arch
## is the entire silhouette.
static func palm(parent: Node3D, base: Vector3, height: float,
		trunk_mat: Material, frond_mat: Material, seed_ := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Palm"
	root.position = base
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 4703 + 29

	# Trunk in segments, leaning and tapering: the old frond bases are what
	# make a palm trunk read as a palm trunk.
	var segs := maxi(6, int(height / 0.75))
	var lean := rng.randf_range(-0.10, 0.10)
	for i in segs:
		var t := float(i) / float(segs)
		var r := lerpf(height * 0.036, height * 0.024, t)
		var seg := _mi(root, "Trunk%d" % i, _cyl(r, height / float(segs) * 1.12, 8),
			trunk_mat, Vector3(lean * height * t * t, height * (t + 0.5 / segs), 0.0))
		seg.rotation.z = -lean * 0.8
		# Frond-base collar every other segment.
		if i % 2 == 0:
			_mi(root, "Collar%d" % i, _box(Vector3(r * 2.5, 0.10, r * 2.4)),
				trunk_mat, Vector3(lean * height * t * t,
					height * (t + 0.5 / segs), 0.0))

	var top := Vector3(lean * height, height, 0.0)
	var fronds := rng.randi_range(9, 12)
	for i in fronds:
		var a := TAU * float(i) / float(fronds) + rng.randf_range(-0.1, 0.1)
		var pivot := Node3D.new()
		pivot.name = "Frond%d" % i
		pivot.position = top
		pivot.rotation = Vector3(0.0, a, 0.0)
		root.add_child(pivot)
		# The frond is a chain of flattened boxes bending over and down.
		var len_ := height * rng.randf_range(0.30, 0.44)
		var links := 5
		var droop := rng.randf_range(0.30, 0.55)
		for k in links:
			var t := (float(k) + 0.5) / float(links)
			var leaf := _mi(pivot, "Leaf%d" % k,
				_box(Vector3(len_ / float(links) * 1.15,
					0.05, lerpf(0.42, 0.14, t) * height * 0.10)),
				frond_mat,
				Vector3(len_ * t, -droop * t * t * height * 0.22, 0.0))
			leaf.rotation.z = -droop * t * 1.5
	# A cluster of dates under the crown, which is the only warm note on it.
	for i in 3:
		var d := _mi(root, "Dates%d" % i, _cyl(height * 0.030, height * 0.09, 7),
			frond_mat, top + Vector3(rng.randf_range(-0.25, 0.25), -height * 0.06,
				rng.randf_range(-0.2, 0.2)))
		d.rotation.z = rng.randf_range(-0.3, 0.3)
	return root


## Massing: the projections that stop a building being a rectangle.
##
## A wall is never a single plane. It has a plinth it stands on, a string
## course at every floor line, a cornice before the parapet, and at least one
## bay that steps forward off the rest. Each of these is a few centimetres of
## geometry and each one buys a hard shadow line across the whole facade, which
## at gameplay distance is worth more than any amount of texture.
static func building_massing(parent: Node3D, left_x: float, base_y: float,
		width: float, height: float, z: float, wall_mat: Material,
		trim_mat: Material, floors := 0, seed_ := 1) -> Node3D:
	var root := Node3D.new()
	root.name = "Massing"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 1259 + 41
	var storeys := floors if floors > 0 else maxi(1, int(height / 3.2))

	# Plinth: the base course, stepped out and usually a different material.
	_mi(root, "Plinth", _box(Vector3(width + 0.34, 0.62, 0.34)), trim_mat,
		Vector3(left_x + width * 0.5, base_y + 0.31, z + 0.17))

	# String courses at the floor lines.
	for i in range(1, storeys):
		var y := base_y + height * float(i) / float(storeys)
		_mi(root, "String%d" % i, _box(Vector3(width + 0.20, 0.16, 0.22)),
			trim_mat, Vector3(left_x + width * 0.5, y, z + 0.11))

	# Cornice under the parapet: the deepest projection on the building, and
	# the one that throws the shadow that separates roof from wall.
	_mi(root, "Cornice", _box(Vector3(width + 0.46, 0.26, 0.46)), trim_mat,
		Vector3(left_x + width * 0.5, base_y + height - 0.13, z + 0.23))

	# One or two bays stepping forward off the rest of the front.
	var bays := rng.randi_range(1, 2)
	for i in bays:
		var bw := rng.randf_range(width * 0.18, width * 0.34)
		var bx := left_x + rng.randf_range(0.1, 0.9) * (width - bw) + bw * 0.5
		var bh := height * rng.randf_range(0.55, 0.92)
		var out := rng.randf_range(0.28, 0.5)
		_mi(root, "Bay%d" % i, _box(Vector3(bw, bh, out * 2.0)), wall_mat,
			Vector3(bx, base_y + bh * 0.5, z + out))
		# The bay gets its own little cornice, or it reads as a pasted slab.
		_mi(root, "BayCap%d" % i, _box(Vector3(bw + 0.24, 0.18, out * 2.0 + 0.24)),
			trim_mat, Vector3(bx, base_y + bh + 0.09, z + out))
	return root


## The enclosed stairwell that comes up onto every flat roof, with its door and
## its little parapet. It is the one thing on a roofline that is person-sized,
## which is what gives the rest of the roof its scale.
static func stair_head(parent: Node3D, at: Vector3, wall_mat: Material,
		door_mat: Material, trim_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "StairHead"
	root.position = at
	parent.add_child(root)
	_mi(root, "Box", _box(Vector3(2.4, 2.4, 2.2)), wall_mat, Vector3(0, 1.2, 0))
	_mi(root, "Cap", _box(Vector3(2.7, 0.22, 2.5)), trim_mat, Vector3(0, 2.45, 0))
	_mi(root, "Door", _box(Vector3(0.9, 1.9, 0.12)), door_mat,
		Vector3(0.0, 0.95, 1.12))
	_mi(root, "Lintel", _box(Vector3(1.15, 0.16, 0.22)), trim_mat,
		Vector3(0.0, 1.98, 1.16))
	return root


# --- Town: market street, shopfronts, roofs -------------------------------

## A market stall: four poles, a sagging awning in striped cloth, a counter and
## crates under it. The awning is the point — it is the one place in this game
## where saturated colour is allowed to sit in the gameplay band, because a
## market without it is a row of tables.
static func market_stall(parent: Node3D, at: Vector3, width: float,
		frame_mat: Material, awning_a: Color, awning_b: Color,
		crate_mat: Material, seed_ := 5) -> Node3D:
	var root := Node3D.new()
	root.name = "MarketStall"
	root.position = at
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 31 + 7

	var h := rng.randf_range(2.05, 2.35)
	var depth := 1.5
	for i in 4:
		var sx := (-0.5 + float(i % 2)) * width
		var sz := (-0.5 + float(i / 2)) * depth
		_mi(root, "Pole%d" % i, _cyl(0.035, h, 6), frame_mat,
			Vector3(sx, h * 0.5, sz))

	# Awning: two slabs meeting at a ridge, sagging between the poles.
	var strips := maxi(4, int(width / 0.42))
	var mm := _joint_multimesh(_box(Vector3(width / float(strips), 0.035, depth * 1.35)))
	var xf: Array[Transform3D] = []
	var colours := PackedColorArray()
	for i in strips:
		var t := (float(i) + 0.5) / float(strips)
		var sag := -sin(t * PI) * 0.09
		xf.append(Transform3D(Basis(Vector3.RIGHT, 0.10),
			Vector3((t - 0.5) * width, h + 0.10 + sag, 0.0)))
		colours.append(awning_a if i % 2 == 0 else awning_b)
	mm.use_colors = true
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, colours[i])
	var cloth := MaterialLab.cloth(Color.WHITE, 0.95)
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mm_node(root, "Awning", mm, cloth)

	# Counter and produce crates.
	_mi(root, "Counter", _box(Vector3(width * 0.96, 0.10, depth * 0.8)),
		crate_mat, Vector3(0, 0.92, 0))
	_mi(root, "CounterLeg", _box(Vector3(width * 0.9, 0.86, 0.10)),
		crate_mat, Vector3(0, 0.46, -0.28))
	for i in rng.randi_range(2, 4):
		var cw := rng.randf_range(0.42, 0.62)
		_mi(root, "Crate%d" % i, _box(Vector3(cw, 0.30, 0.44)), crate_mat,
			Vector3(rng.randf_range(-0.4, 0.4) * width, 1.12, rng.randf_range(-0.2, 0.2)))
	return root


## A shopfront bay: a roller shutter, a lintel, a painted sign board and the
## step up off the street. Repeated along a wall it is most of a market street.
static func shopfront(parent: Node3D, at: Vector3, width: float, height: float,
		wall_mat: Material, shutter_mat: Material, sign_mat: Material,
		open_ := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Shopfront"
	root.position = at
	parent.add_child(root)

	# The opening itself is a recess, so the bay has depth in a side view.
	_mi(root, "Recess", _box(Vector3(width * 0.86, height * 0.72, 0.50)),
		wall_mat, Vector3(0, height * 0.36, -0.30))
	_mi(root, "Lintel", _box(Vector3(width, 0.26, 0.62)), wall_mat,
		Vector3(0, height * 0.72 + 0.13, 0.0))
	_mi(root, "Step", _box(Vector3(width * 0.94, 0.16, 0.7)), wall_mat,
		Vector3(0, 0.08, 0.30))

	# Shutter: down to the lintel when open, most of the way when shut.
	var drop := height * 0.18 if open_ else height * 0.68
	_mi(root, "Shutter", _box(Vector3(width * 0.84, drop, 0.08)), shutter_mat,
		Vector3(0, height * 0.72 - drop * 0.5, 0.05))

	_mi(root, "SignBoard", _box(Vector3(width * 0.92, 0.42, 0.10)), sign_mat,
		Vector3(0, height * 0.72 + 0.44, 0.10))
	return root


## Everything that lives on a Libyan roof: a parapet, black water tanks on
## stands, a dish, and a run of reinforcement bar left sticking out of the
## columns because the next storey is always going to get built.
static func roof_kit(parent: Node3D, left_x: float, top_y: float, width: float,
		z: float, wall_mat: Material, tank_mat: Material, rebar_mat: Material,
		seed_ := 9) -> Node3D:
	var root := Node3D.new()
	root.name = "RoofKit"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 101 + 3

	_mi(root, "Parapet", _box(Vector3(width, 0.52, 0.30)), wall_mat,
		Vector3(left_x + width * 0.5, top_y + 0.26, z + 0.55))
	_mi(root, "ParapetCap", _box(Vector3(width, 0.09, 0.42)), wall_mat,
		Vector3(left_x + width * 0.5, top_y + 0.54, z + 0.55))

	for i in maxi(1, int(width / 7.0)):
		var x := left_x + (float(i) + rng.randf_range(0.2, 0.8)) * (width / maxf(float(int(width / 7.0)), 1.0))
		# Stand, then tank: a tank sitting flat on a roof reads as a barrel.
		_mi(root, "TankStand%d" % i, _box(Vector3(0.9, 0.42, 0.7)), rebar_mat,
			Vector3(x, top_y + 0.21, z))
		var t := _mi(root, "RoofTank%d" % i, _cyl(0.42, 0.90, 14), tank_mat,
			Vector3(x, top_y + 0.87, z))
		t.rotation.y = rng.randf_range(0.0, TAU)

	# Rebar stubs: the storey that was always going to be added.
	for i in maxi(2, int(width / 3.5)):
		var rx := left_x + (float(i) + 0.5) * (width / maxf(float(int(width / 3.5)), 1.0))
		var rh := rng.randf_range(0.35, 0.8)
		var bar := _mi(root, "Rebar%d" % i, _cyl(0.022, rh, 5), rebar_mat,
			Vector3(rx, top_y + rh * 0.5, z - 0.35))
		bar.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0.0,
			rng.randf_range(-0.16, 0.16))
	return root


## Deep-set window with a bent louvred shutter. Placed on a rhythm by the caller.
static func window(parent: Node3D, pos: Vector3, size: Vector2, reveal: float,
		frame_mat: Material, dark_mat: Material, shutter_mat: Material,
		shutter_angle := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Window"
	root.position = pos
	parent.add_child(root)
	# The void reads as depth only because the reveal casts into it.
	_mi(root, "Void", _box(Vector3(size.x, size.y, 0.05)), dark_mat, Vector3(0, 0, 0.012))
	# The reveal protrudes toward the camera and casts into the void; that cast
	# is the only thing that makes a flat panel read as a hole.
	_mi(root, "RevealTop", _box(Vector3(size.x + 0.16, 0.07, reveal)), frame_mat,
		Vector3(0, size.y * 0.5 + 0.035, reveal * 0.5))
	_mi(root, "RevealBottom", _box(Vector3(size.x + 0.20, 0.09, reveal + 0.05)), frame_mat,
		Vector3(0, -size.y * 0.5 - 0.045, reveal * 0.5))
	for side: float in [-1.0, 1.0]:
		_mi(root, "RevealSide", _box(Vector3(0.07, size.y + 0.14, reveal)), frame_mat,
			Vector3(side * (size.x * 0.5 + 0.035), 0, reveal * 0.5))
	if shutter_mat:
		var s := _mi(root, "Shutter", _box(Vector3(size.x * 0.52, size.y * 0.94, 0.035)),
			shutter_mat, Vector3(-size.x * 0.26, 0, reveal + 0.02))
		s.rotation.y = shutter_angle
		for i in 7:
			_mi(s, "Louvre%d" % i, _box(Vector3(size.x * 0.50, 0.018, 0.05)), shutter_mat,
				Vector3(0, size.y * (0.40 - i * 0.135), 0.022))
	return root


# --- Tank farm --------------------------------------------------------------

## Storage tank in its bund. `burnt` collapses the roof and scorches the shell.
static func storage_tank(parent: Node3D, center: Vector3, radius: float, height: float,
		shell_mat: Material, bund_mat: Material, rust_mat: Material,
		burnt := false, burnt_mat: Material = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Tank"
	root.position = center
	parent.add_child(root)

	var body_mat: Material = burnt_mat if burnt and burnt_mat else shell_mat
	_mi(root, "Shell", _cyl(radius, height, 28), body_mat, Vector3(0, height * 0.5, 0))

	if burnt:
		# Collapsed roof: a shallow inverted cone sunk into the shell.
		var roof := _cyl(radius * 0.96, height * 0.14, 24, radius * 0.25)
		_mi(root, "RoofCollapsed", roof, body_mat, Vector3(0, height * 0.94, 0),
			Vector3(PI, 0, 0))
	else:
		var roof := _cyl(radius * 0.99, height * 0.08, 28, radius * 0.86)
		_mi(root, "Roof", roof, shell_mat, Vector3(0, height + height * 0.04, 0))

	# The bottom metre exfoliates: a separate band carries the rust.
	_mi(root, "RustBand", _cyl(radius * 1.004, height * 0.09, 28), rust_mat,
		Vector3(0, height * 0.045, 0))
	# Bund wall, a third the tank's height.
	_mi(root, "Bund", _cyl(radius * 1.55, height * 0.33, 24), bund_mat,
		Vector3(0, height * 0.165, 0))

	# Shell courses: a tank is welded up from plate about 2.4 m tall, and the
	# horizontal line at every course is the thing that says "storage tank"
	# rather than "cylinder" at any distance.
	var courses := maxi(2, int(height / 2.4))
	var course_mm := _joint_multimesh(_cyl(radius * 1.006, 0.06, 28))
	var course_xf: Array[Transform3D] = []
	for i in range(1, courses):
		course_xf.append(Transform3D(Basis.IDENTITY,
			Vector3(0, height * float(i) / float(courses), 0)))
	_fill_multimesh(course_mm, course_xf)
	_mm_node(root, "Courses", course_mm, rust_mat)

	# Wind girder near the top, and a handrail ring on the roof.
	_mi(root, "WindGirder", _cyl(radius * 1.05, 0.16, 28), rust_mat,
		Vector3(0, height * 0.82, 0))
	_mi(root, "RoofRail", _cyl(radius * 0.94, 0.05, 28), rust_mat,
		Vector3(0, height + height * 0.09 + 0.9, 0))
	for i in 10:
		var ra := TAU * float(i) / 10.0
		_mi(root, "RoofPost%d" % i, _box(Vector3(0.07, 0.95, 0.07)), rust_mat,
			Vector3(cos(ra) * radius * 0.94, height + height * 0.09 + 0.45,
				sin(ra) * radius * 0.94))

	# Rust running off the brackets, on the camera-facing side only. The shell
	# is a cylinder and a decal cannot wrap it, but in a side-on game the far
	# half is never seen.
	var streaks: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(center.x) * 131.0 + radius * 17.0)
	for i in maxi(4, int(radius)):
		var sx := rng.randf_range(-0.82, 0.82) * radius
		var sh := rng.randf_range(height * 0.25, height * 0.7)
		var top := height * rng.randf_range(0.45, 0.95)
		streaks.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(rng.randf_range(0.3, 0.9), sh, 1.0)),
			Vector3(sx, top - sh * 0.5,
				sqrt(maxf(radius * radius - sx * sx, 0.01)) + 0.04)))
	var sm := _joint_multimesh(_unit_quad())
	_fill_multimesh(sm, streaks)
	_mm_node(root, "ShellStreaks", sm,
		gradient_decal(Color(0.20, 0.105, 0.065), 0.62, "streak"))

	# Ladder brackets — the source of every one of those streaks.
	for i in 6:
		var a := TAU * float(i) / 6.0
		_mi(root, "Bracket%d" % i, _box(Vector3(0.22, 0.10, 0.10)), rust_mat,
			Vector3(cos(a) * radius, height * (0.25 + 0.12 * i), sin(a) * radius),
			Vector3(0, -a, 0))
	return root


## Spiral staircase wrapping a tank. Cheap: steps as a MultiMesh.
static func tank_stair(parent: Node3D, center: Vector3, radius: float, height: float,
		mat: Material, turns := 1.15, steps := 54) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box(Vector3(1.05, 0.06, 0.30))
	mm.instance_count = steps
	for i in steps:
		var t := float(i) / float(steps - 1)
		var a := t * TAU * turns
		var r := radius + 0.55
		var xf := Transform3D(Basis(Vector3.UP, -a + PI * 0.5),
			Vector3(cos(a) * r, t * height, sin(a) * r))
		mm.set_instance_transform(i, xf)
	var node := MultiMeshInstance3D.new()
	node.name = "TankStair"
	node.multimesh = mm
	node.material_override = mat
	node.position = center
	parent.add_child(node)
	return node


## Plain windowless concrete shaft — the urea prilling towers on the horizon.
static func prilling_tower(parent: Node3D, base: Vector3, radius: float, height: float,
		mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "PrillingTower"
	root.position = base
	parent.add_child(root)
	_mi(root, "Shaft", _cyl(radius, height, 20, radius * 0.88), mat, Vector3(0, height * 0.5, 0))
	_mi(root, "Head", _cyl(radius * 1.12, height * 0.07, 20), mat, Vector3(0, height * 1.02, 0))
	# Vertical streaking is geometry here, not texture — it survives the fog.
	for i in 9:
		var a := PI * (0.15 + 0.09 * i)
		_mi(root, "Streak%d" % i, _box(Vector3(0.10, height * 0.82, 0.06)), mat,
			Vector3(cos(a) * radius * 0.99, height * 0.48, sin(a) * radius * 0.99))
	return root


## Cold black steel lattice with nothing burning on it.
static func flare_stack(parent: Node3D, base: Vector3, height: float, width: float,
		mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "FlareStack"
	root.position = base
	parent.add_child(root)
	var legs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in legs.size():
		var l: Vector2 = legs[i]
		var lean := width * 0.5
		_mi(root, "Leg%d" % i, _box(Vector3(0.16, height, 0.16)), mat,
			Vector3(l.x * lean * 0.55, height * 0.5, l.y * lean * 0.55),
			Vector3(l.y * 0.018, 0.0, -l.x * 0.018))
	var bands := 14
	for i in bands:
		var y := height * (float(i) + 0.5) / float(bands)
		var w := width * (1.0 - 0.45 * (y / height))
		_mi(root, "Band%d" % i, _box(Vector3(w, 0.09, w)), mat, Vector3(0, y, 0))
		_mi(root, "BraceA%d" % i, _box(Vector3(w * 1.35, 0.07, 0.07)), mat,
			Vector3(0, y + height / bands * 0.5, w * 0.5), Vector3(0, 0, 0.62))
	_mi(root, "Tip", _cyl(0.30, height * 0.045, 12), mat, Vector3(0, height, 0))
	return root


# --- Fences, wire, windbreaks ----------------------------------------------

## Wind-driven foliage. `base_y` and `anchor_height` tell the shader where the
## plant is rooted, so trunks stay planted while canopies travel.
static func foliage_material(tint: Color, base_y: float, anchor_height: float,
		strength := 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("base_y", base_y)
	m.set_shader_parameter("anchor_height", anchor_height)
	m.set_shader_parameter("wind_strength", strength)
	m.set_shader_parameter("detail", NoiseBank.grain(19))
	return m


static func chainlink_material(rust := 0.35, cells := 26.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CHAINLINK_SHADER
	m.set_shader_parameter("cells", cells)
	m.set_shader_parameter("rust", rust)
	m.set_shader_parameter("rust_noise", NoiseBank.macro(5))
	return m


static func chainlink(parent: Node3D, left_x: float, base_y: float, width: float,
		height: float, z: float, mat: ShaderMaterial, post_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "ChainLink"
	parent.add_child(root)
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	_mi(root, "Mesh", quad, mat, Vector3(left_x + width * 0.5, base_y + height * 0.5, z))
	var posts := int(width / 3.0) + 1
	for i in posts + 1:
		var x := left_x + i * (width / float(posts))
		_mi(root, "Post%d" % i, _cyl(0.045, height + 0.2, 8), post_mat,
			Vector3(x, base_y + height * 0.5, z))
	_mi(root, "Rail", _cyl(0.038, width, 8), post_mat,
		Vector3(left_x + width * 0.5, base_y + height, z), Vector3(0, 0, PI * 0.5))
	return root


## Razor wire as a coil of tori. Out of focus in the foreground it needs to read
## as a shape, not as wire, so the segment count stays low on purpose.
static func razor_coil(parent: Node3D, from: Vector3, to: Vector3, radius: float,
		mat: Material, coils := 12, name_ := "RazorCoil") -> Node3D:
	var root := Node3D.new()
	root.name = name_
	parent.add_child(root)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.02
	torus.outer_radius = radius
	torus.rings = 14
	torus.ring_segments = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = torus
	mm.instance_count = coils
	var axis := (to - from)
	for i in coils:
		var t := float(i) / float(maxi(coils - 1, 1))
		var p := from + axis * t
		var basis := Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, sin(t * 9.0) * 0.22)
		mm.set_instance_transform(i, Transform3D(basis.scaled(
			Vector3(1.0, 1.0, 0.82 + 0.3 * sin(t * 12.0))), p))
	var node := MultiMeshInstance3D.new()
	node.name = "Coils"
	node.multimesh = mm
	node.material_override = mat
	root.add_child(node)
	return root


## Dead or dying eucalyptus. The windbreak rows are planted dead straight, and
## that straightness is what says "someone put these here" rather than "desert".
##
## Canopies are elongated and drooping, never spherical: a eucalyptus reads by
## its hanging strands, and a ball on a stick reads as a lollipop.
static func eucalyptus(parent: Node3D, base: Vector3, height: float,
		trunk_mat: Material, foliage_mat: Material, alive := false,
		seed_ := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Eucalyptus"
	root.position = base
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 7919 + 13

	# Trunk tapers hard and leans a little — a straight cylinder reads as a pole.
	var trunk := _cyl(height * 0.032, height, 8, height * 0.011)
	var tm := _mi(root, "Trunk", trunk, trunk_mat, Vector3(0, height * 0.5, 0),
		Vector3(0, rng.randf_range(0.0, TAU), rng.randf_range(-0.035, 0.035)))
	tm.rotation.z += rng.randf_range(-0.02, 0.02)

	# Branches sweep up and out, thinning as they go.
	var branches := 6 if alive else 5
	for i in branches:
		var t := 0.42 + 0.11 * i
		var side := 1.0 if i % 2 == 0 else -1.0
		var len_ := height * rng.randf_range(0.15, 0.26) * (1.0 - t * 0.35)
		var b := _mi(root, "Branch%d" % i,
			_cyl(height * 0.011, len_, 5, height * 0.004), trunk_mat,
			Vector3(0, height * t, 0))
		b.rotation = Vector3(0.0, rng.randf_range(-0.5, 0.5), side * rng.randf_range(0.55, 0.95))
		b.position += Vector3(side * 0.35, 0.0, 0.0) * len_ * 0.5

		if not alive:
			continue
		# Four hanging strands per branch, squashed flat in Z so they read as
		# foliage from the side rather than as beads. Two was too few: the
		# canopy came out as a handful of separate dark ellipses on a stick.
		for k in 4:
			var hang := SphereMesh.new()
			hang.radius = height * rng.randf_range(0.022, 0.036)
			hang.height = hang.radius * rng.randf_range(3.8, 6.0)
			hang.radial_segments = 7
			hang.rings = 4
			var f := _mi(root, "Strand%d_%d" % [i, k], hang, foliage_mat,
				Vector3(side * len_ * rng.randf_range(0.7, 1.05),
					height * (t + 0.06) - hang.height * 0.35,
					rng.randf_range(-0.25, 0.25)))
			f.rotation.z = side * rng.randf_range(0.1, 0.32)
			f.scale = Vector3(1.0, 1.0, 0.55)

	if alive:
		# Three overlapping crown masses rather than one. A single ellipsoid on
		# top of a stick is a lollipop; three that interpenetrate are a canopy.
		for c in 3:
			var crown := SphereMesh.new()
			crown.radius = height * rng.randf_range(0.055, 0.080)
			crown.height = crown.radius * rng.randf_range(2.6, 3.8)
			crown.radial_segments = 9
			crown.rings = 5
			var cm := _mi(root, "Crown%d" % c, crown, foliage_mat,
				Vector3(rng.randf_range(-0.5, 0.5),
					height * rng.randf_range(0.84, 0.99),
					rng.randf_range(-0.3, 0.3)))
			cm.scale = Vector3(1.0, 1.0, 0.6)
	return root


## Industrial catwalk: deck, a front edge beam, legs down to the ground, and
## diagonal braces that actually connect the two. The braces are what stop a
## platform reading as a floating slab.
##
## `floor_y` is where the legs land, so a level passes its ground height once
## instead of computing a drop per platform and getting it wrong.
static func deck(parent: Node3D, left_x: float, top_y: float, width: float, z: float,
		deck_mat: Material, beam_mat: Material, floor_y := -7.8,
		name_ := "Deck") -> StaticBody3D:
	var body := LevelKit.platform(parent, left_x, top_y, width, deck_mat, 0.55, 3.2, name_)
	var cx := left_x + width * 0.5
	var under := top_y - 0.55

	_mi(parent, name_ + "Beam", _box(Vector3(width, 0.24, 0.18)), beam_mat,
		Vector3(cx, under + 0.06, z + 1.62))
	_mi(parent, name_ + "Kick", _box(Vector3(width, 0.16, 0.10)), beam_mat,
		Vector3(cx, top_y + 0.08, z + 1.60))

	var drop := under - floor_y
	if drop <= 0.6:
		return body

	var legs := maxi(2, int(width / 5.5))
	for i in legs:
		var lx := left_x + width * (float(i) + 0.5) / float(legs)
		_mi(parent, name_ + "Leg%d" % i, _box(Vector3(0.22, drop, 0.22)), beam_mat,
			Vector3(lx, under - drop * 0.5, z - 0.6))

		# Brace: from the leg, `run` across and `rise` up, so it meets the deck
		# underside. Length and angle both come from those two numbers.
		var run := minf(width * 0.22, 2.2)
		var rise := minf(drop * 0.6, 3.2)
		if rise < 0.5:
			continue
		for dir: float in [-1.0, 1.0]:
			var length := sqrt(run * run + rise * rise)
			var brace := _mi(parent, name_ + "Brace%d" % i,
				_box(Vector3(0.13, length, 0.13)), beam_mat,
				Vector3(lx + dir * run * 0.5, under - rise * 0.5, z - 0.6))
			brace.rotation.z = dir * atan2(run, rise)
	return body


# --- Industrial run ---------------------------------------------------------

## Pipe rack on concrete sleepers. Diagonals through a frame are the cheapest
## way to make an industrial scene read as designed rather than scattered.
static func pipe_rack(parent: Node3D, from: Vector3, to: Vector3, pipes := 4,
		pipe_mat: Material = null, support_mat: Material = null,
		spacing := 6.0) -> Node3D:
	var root := Node3D.new()
	root.name = "PipeRack"
	parent.add_child(root)
	var delta := to - from
	var length := delta.length()
	var dir := delta / maxf(length, 0.001)
	var mid := (from + to) * 0.5
	var basis := Basis()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.BACK
	basis.y = dir
	basis.x = up.cross(dir).normalized()
	basis.z = basis.x.cross(basis.y).normalized()

	for i in pipes:
		var off := Vector3(0.0, 0.0, (float(i) - (pipes - 1) * 0.5) * 0.46)
		var radius := 0.14 if i % 2 == 0 else 0.20
		var mi := _mi(root, "Pipe%d" % i, _cyl(radius, length, 12), pipe_mat, Vector3.ZERO)
		mi.transform = Transform3D(basis, mid + basis * off)

	var count := maxi(int(length / spacing), 1)
	for i in count + 1:
		var t := float(i) / float(count)
		var p := from + delta * t
		_mi(root, "Sleeper%d" % i, _box(Vector3(0.36, 2.4, pipes * 0.5 + 0.5)),
			support_mat, p + Vector3(0, -1.2, 0))
	return root


## Precast walkway deck with an outboard rail and missing balusters.
static func walkway(parent: Node3D, left_x: float, top_y: float, width: float, z: float,
		deck_mat: Material, rail_mat: Material, rebar_mat: Material,
		missing := [3, 4, 9]) -> StaticBody3D:
	var body := LevelKit.box(parent,
		Vector3(left_x + width * 0.5, top_y - 0.16, z), Vector3(width, 0.32, 1.2),
		deck_mat, "Walkway")

	# An industrial handrail is stanchions on a wide pitch carrying a top rail,
	# a mid rail and a toe plate — NOT balusters every 900 mm. At gameplay
	# distance a picket fence is a smear of thin sticks with no shape; two long
	# horizontals and a few uprights is a silhouette you can read.
	var pitch := 1.85
	var n := maxi(2, int(width / pitch))
	for i in n:
		if missing.has(i):
			continue
		var sx := -width * 0.5 + width * (float(i) + 0.5) / float(n)
		_mi(body, "Stanchion%d" % i, _box(Vector3(0.075, 1.12, 0.075)), rail_mat,
			Vector3(sx, 0.72, 0.55))
		# Knee brace back to the deck: the diagonal is most of the character.
		var brace := _mi(body, "Brace%d" % i, _box(Vector3(0.05, 0.50, 0.05)),
			rail_mat, Vector3(sx + 0.14, 0.34, 0.44))
		brace.rotation = Vector3(0.52, 0.0, 0.36)

	_mi(body, "RailTop", _cyl(0.048, width, 8), rail_mat, Vector3(0, 1.26, 0.55),
		Vector3(0, 0, PI * 0.5))
	_mi(body, "RailMid", _cyl(0.036, width, 8), rail_mat, Vector3(0, 0.74, 0.55),
		Vector3(0, 0, PI * 0.5))
	# Toe plate: the solid band along the deck edge that stops a dropped
	# spanner, and the one continuous dark line the whole run needs.
	_mi(body, "ToePlate", _box(Vector3(width, 0.16, 0.05)), rail_mat,
		Vector3(0, 0.24, 0.57))

	# Spalled leading edge with two exposed rebars and a rust halo under it.
	_mi(body, "Spall", _box(Vector3(0.40, 0.14, 1.1)), rebar_mat,
		Vector3(width * 0.5 - 0.20, 0.09, 0.0))
	for i in 2:
		_mi(body, "Rebar%d" % i, _cyl(0.014, 0.44, 6), rebar_mat,
			Vector3(width * 0.5 - 0.18, 0.05, -0.2 + i * 0.4), Vector3(0, 0, PI * 0.5))
	return body


static func sandbag_row(parent: Node3D, left_x: float, y: float, width: float, z: float,
		mat: Material, rows := 2) -> MultiMeshInstance3D:
	var bag := SphereMesh.new()
	bag.radius = 0.19
	bag.height = 0.26
	bag.radial_segments = 8
	bag.rings = 4
	var per := int(width / 0.36)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bag
	mm.instance_count = per * rows
	var i := 0
	for r in rows:
		for c in per:
			var jitter := sin(float(i) * 2.399) * 0.04
			var xf := Transform3D(
				Basis(Vector3.UP, sin(float(i) * 1.7) * 0.35).scaled(
					Vector3(1.6, 0.8 + jitter, 1.0)),
				Vector3(left_x + (c + 0.5 + r * 0.5) * 0.36, y + r * 0.20 + jitter, z))
			mm.set_instance_transform(i, xf)
			i += 1
	var node := MultiMeshInstance3D.new()
	node.name = "Sandbags"
	node.multimesh = mm
	node.material_override = mat
	parent.add_child(node)
	return node
