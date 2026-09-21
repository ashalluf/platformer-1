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


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


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

	var panel_w := 3.0
	var panel_h := 1.2
	var cols := int(ceil(width / panel_w))
	var rows := int(ceil(height / panel_h))
	var joint: Material = opts.get("joint_mat", mat)
	var hole_mat: Material = opts.get("hole_mat", mat)
	var front := z + depth * 0.5

	# Joint lines: 12 mm reveals, cut as thin dark strips rather than geometry.
	for c in cols + 1:
		var jx := left_x + c * panel_w
		if jx > left_x + width:
			break
		_mi(root, "JointV%d" % c, _box(Vector3(0.028, height, 0.03)), joint,
			Vector3(jx, base_y + height * 0.5, front))
	for r in rows + 1:
		var jy := base_y + r * panel_h
		if jy > base_y + height:
			break
		_mi(root, "JointH%d" % r, _box(Vector3(width, 0.028, 0.03)), joint,
			Vector3(left_x + width * 0.5, jy, front))

	# Crane holes, one per panel centre. `open_holes` many are knocked through.
	var open_count: int = opts.get("open_holes", 3)
	var idx := 0
	for c in cols:
		for r in rows:
			var hx := left_x + (c + 0.5) * panel_w
			var hy := base_y + (r + 0.5) * panel_h
			if hy > base_y + height - 0.3:
				continue
			idx += 1
			var open_hole := (idx * 7) % 23 < open_count
			var m := _cyl(0.062, 0.05, 12)
			var node := _mi(root, "Hole%d_%d" % [c, r],
				m, hole_mat if not open_hole else opts.get("dark_mat", hole_mat),
				Vector3(hx, hy, front + 0.016), Vector3(PI * 0.5, 0.0, 0.0))
			node.scale = Vector3(1.0, 0.6, 1.0)
			if open_hole:
				node.position.z = front - 0.06
				node.scale = Vector3(1.15, 2.4, 1.15)
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

	# Ladder brackets — the source of every vertical rust streak on the shell.
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
		mat: Material, coils := 12) -> Node3D:
	var root := Node3D.new()
	root.name = "RazorCoil"
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
## `foliage_mat` is expected to be a wind material from `foliage_material()`
## configured for this plant's base height.
static func eucalyptus(parent: Node3D, base: Vector3, height: float,
		trunk_mat: Material, foliage_mat: Material, alive := false,
		seed_ := 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Eucalyptus"
	root.position = base
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 7919 + 13

	_mi(root, "Trunk", _cyl(height * 0.035, height, 10, height * 0.016), trunk_mat,
		Vector3(0, height * 0.5, 0), Vector3(0, 0, rng.randf_range(-0.03, 0.03)))
	var branches := 5 if alive else 4
	for i in branches:
		var t := 0.45 + 0.13 * i
		var a := rng.randf_range(0.0, TAU)
		var len_ := height * rng.randf_range(0.16, 0.30)
		var b := _mi(root, "Branch%d" % i, _cyl(height * 0.012, len_, 6, height * 0.004),
			trunk_mat, Vector3(0, height * t, 0))
		b.rotation = Vector3(0, a, rng.randf_range(0.5, 1.0))
		b.position += Vector3(cos(a), 0.0, sin(a)) * len_ * 0.30
		if alive:
			var s := SphereMesh.new()
			s.radius = height * rng.randf_range(0.055, 0.085)
			s.height = s.radius * 1.7
			s.radial_segments = 8
			s.rings = 5
			_mi(root, "Canopy%d" % i, s, foliage_mat,
				Vector3(cos(a), 0.0, sin(a)) * len_ * 0.75 + Vector3(0, height * (t + 0.10), 0))
	return root


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
	var n := int(width / 0.9)
	for i in n:
		if missing.has(i):
			continue
		_mi(body, "Baluster%d" % i, _box(Vector3(0.06, 0.95, 0.06)), rail_mat,
			Vector3(-width * 0.5 + 0.45 + i * 0.9, 0.64, 0.55))
	_mi(body, "Rail", _cyl(0.045, width, 8), rail_mat, Vector3(0, 1.12, 0.55),
		Vector3(0, 0, PI * 0.5))
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
