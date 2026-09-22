class_name FoliageKit
## The World 1 planting library.
##
## Everything that grows, built from code, batched into MultiMeshes and driven
## by one wind shader. It replaces PropKit's `palm`, `eucalyptus` and
## `foliage_material`, which were spheres and boxes on sticks.
##
## Two rules run through all of it:
##
## 1. SILHOUETTE. These plants are read in profile from z = +16 against a bright
##    sky, so the outline is the whole asset. A canopy that reads as one solid
##    dark blob at thirty units has failed — every crown here is built from
##    separated masses with deliberate sky holes between them, and every arch is
##    modelled rather than implied by a sphere.
## 2. NOTHING THINNER THAN ABOUT 70 mm SURVIVES. At gameplay distance a wire
##    disappears and takes the plant's mass with it. So a "leaflet" here is a
##    strip standing in for a group of real leaflets, never a single leaf and
##    never a cylinder pretending to be a twig.
##
## Cost control: plants do not own their meshes. A row opens one `Grove`, every
## plant appends instances to it, and the grove flushes into one
## MultiMeshInstance3D per (mesh, material) pair — a fifteen-palm avenue costs
## six or seven draw calls, not fifteen hundred.
##
## Everything is deterministic: the RNG is seeded from the plant's position, so
## a level rebuilds identically every run and a screenshot can be compared with
## last week's.

const SHADER := preload("res://shaders/foliage_kit.gdshader")

# Palette straight out of docs/ART_DIRECTION.md. Nothing here may exceed the
# red-sector chroma cap; the bougainvillea sits at hue ~325 (magenta), which is
# outside the reserved 340-25 band, and it is the one saturated thing allowed in
# an Ajdabiya frame.
const FROND := Color(0.420, 0.557, 0.306)        # #6B8E4E date/fan palm
const FROND_TIP := Color(0.560, 0.580, 0.330)    # sun-bleached frond tips
const FICUS := Color(0.173, 0.290, 0.180)        # #2C4A2E street ficus
const FICUS_TIP := Color(0.290, 0.400, 0.220)
const EUCALYPT := Color(0.490, 0.545, 0.416)     # #7D8B6A half-dead eucalyptus
const TAMARISK := Color(0.541, 0.588, 0.514)     # #8A9683
const HALOPHYTE := Color(0.561, 0.628, 0.549)    # #8FA08C
const DRY_STRAW := Color(0.620, 0.545, 0.365)    # dead everything
const BARK := Color(0.355, 0.310, 0.255)
const BARK_PALE := Color(0.560, 0.530, 0.470)    # whitewashed / silvered
const BOUGAINVILLEA := Color(0.745, 0.180, 0.490)
const DATE_FRUIT := Color(0.620, 0.360, 0.150)

## Per-species wind. Different plants have different natural frequencies and it
## is the fastest way to tell two green masses apart in motion: a palm crown is
## a slow heavy swing, a eucalyptus strand is a fast light chatter, dry grass is
## a blur. Same shader, four numbers.
const SPECIES := {
	"palm":       {"speed": 0.62, "strength": 0.30, "flutter": 0.9, "gust": 1.8},
	"eucalyptus": {"speed": 0.98, "strength": 0.17, "flutter": 1.7, "gust": 1.5},
	"ficus":      {"speed": 0.76, "strength": 0.11, "flutter": 0.8, "gust": 1.2},
	"scrub":      {"speed": 1.35, "strength": 0.10, "flutter": 1.9, "gust": 1.4},
	"grass":      {"speed": 1.95, "strength": 0.06, "flutter": 2.6, "gust": 1.8},
	"bloom":      {"speed": 1.10, "strength": 0.09, "flutter": 1.4, "gust": 1.3},
	"bark":       {"speed": 0.55, "strength": 0.06, "flutter": 0.2, "gust": 1.1},
	"fruit":      {"speed": 0.70, "strength": 0.12, "flutter": 0.6, "gust": 1.4},
}

const GOLDEN := 2.3999632297   # 137.5 degrees: the angle real crowns spiral on

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


# --- Materials --------------------------------------------------------------

## The wind material. `species` picks the frequency band; everything else is an
## override. One of these can drive every plant of that family in a level, at
## any ground height and any plant height, because the rooting is per instance.
static func wind_material(p := {}) -> ShaderMaterial:
	var species := str(p.get("species", "ficus"))
	var s: Dictionary = SPECIES.get(species, SPECIES["ficus"])
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var tint: Color = p.get("color", FROND)
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("tip_albedo", p.get("tip_color", _lift(tint, 1.24)))
	m.set_shader_parameter("dead_albedo", p.get("dead_color", DRY_STRAW))
	m.set_shader_parameter("roughness_value", p.get("roughness", 0.72))
	m.set_shader_parameter("backlight_tint", p.get("backlight", Color(0.22, 0.26, 0.12)))
	m.set_shader_parameter("rim_strength", p.get("rim", 0.8))
	m.set_shader_parameter("rim_tint", p.get("rim_tint", Color(1.0, 0.84, 0.62)))
	m.set_shader_parameter("detail", p.get("detail", NoiseBank.macro(int(p.get("seed", 19)))))
	m.set_shader_parameter("detail_scale", p.get("detail_scale", 0.22))
	m.set_shader_parameter("detail_amount", p.get("detail_amount", 0.26))
	# The ghibli runs roughly west to east across World 1; a little Z keeps the
	# motion from being perfectly flat on screen.
	m.set_shader_parameter("wind_dir", p.get("wind_dir", Vector3(1.0, 0.0, 0.18)))
	m.set_shader_parameter("wind_strength", p.get("strength", s["strength"]))
	m.set_shader_parameter("wind_speed", p.get("speed", s["speed"]))
	m.set_shader_parameter("gust_speed", p.get("gust_speed", 1.35))
	m.set_shader_parameter("gust_strength", p.get("gust", s["gust"]))
	m.set_shader_parameter("gust_wavelength", p.get("gust_wavelength", 26.0))
	m.set_shader_parameter("flutter_strength", p.get("flutter", 0.035 * float(s["flutter"])))
	m.set_shader_parameter("instanced", p.get("instanced", true))
	m.set_shader_parameter("base_y", p.get("base_y", 0.0))
	m.set_shader_parameter("anchor_height", p.get("anchor_height", 6.0))
	return m


## Default material per layer family, cached so a whole level shares them.
static func _default_material(key: String, opts: Dictionary) -> ShaderMaterial:
	var wind: Variant = opts.get("wind_dir", Vector3(1.0, 0.0, 0.18))
	var cache_key := "%s|%.2f|%.2f" % [key, opts.get("wind_scale", 1.0), opts.get("dry", 0.0)]
	if _mat_cache.has(cache_key):
		return _mat_cache[cache_key]
	var p := {"wind_dir": wind}
	match key:
		"bark":
			p.merge({"species": "bark", "color": BARK, "tip_color": _lift(BARK, 1.18),
				"dead_color": BARK_PALE, "roughness": 0.88,
				"backlight": Color(0.05, 0.04, 0.03), "rim": 0.55, "detail_scale": 0.9,
				"detail_amount": 0.34})
		"frond":
			p.merge({"species": "palm", "color": FROND, "tip_color": FROND_TIP,
				"backlight": Color(0.26, 0.30, 0.13), "rim": 1.0})
		"leaf":
			p.merge({"species": "ficus", "color": FICUS, "tip_color": FICUS_TIP,
				"backlight": Color(0.18, 0.24, 0.10)})
		"strand":
			p.merge({"species": "eucalyptus", "color": EUCALYPT,
				"tip_color": _lift(EUCALYPT, 1.16), "backlight": Color(0.22, 0.25, 0.14),
				"rim": 1.1})
		"scrub":
			p.merge({"species": "scrub", "color": TAMARISK,
				"tip_color": _lift(TAMARISK, 1.15), "backlight": Color(0.20, 0.22, 0.14)})
		"grass":
			p.merge({"species": "grass", "color": DRY_STRAW,
				"tip_color": _lift(DRY_STRAW, 1.20), "dead_color": _lift(DRY_STRAW, 0.92),
				"backlight": Color(0.30, 0.26, 0.14), "rim": 1.3, "roughness": 0.86})
		"succulent":
			p.merge({"species": "scrub", "color": HALOPHYTE,
				"tip_color": _lift(HALOPHYTE, 1.12), "roughness": 0.55,
				"backlight": Color(0.16, 0.22, 0.14), "strength": 0.03})
		"bloom":
			p.merge({"species": "bloom", "color": BOUGAINVILLEA,
				"tip_color": _lift(BOUGAINVILLEA, 1.15), "dead_color": Color(0.58, 0.40, 0.42),
				"backlight": Color(0.38, 0.10, 0.24), "rim": 1.4, "roughness": 0.62})
		"fruit":
			p.merge({"species": "fruit", "color": DATE_FRUIT,
				"tip_color": _lift(DATE_FRUIT, 1.25), "roughness": 0.58,
				"backlight": Color(0.24, 0.12, 0.05), "rim": 1.1})
		_:
			p.merge({"species": "ficus", "color": FICUS})
	var m := wind_material(p)
	_mat_cache[cache_key] = m
	return m


static func _lift(c: Color, f: float) -> Color:
	return Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0), minf(c.b * f, 1.0), c.a)


# --- Batching ---------------------------------------------------------------

## A batch of planting. Open one, plant into it, flush it once.
##
## Layers are keyed by (mesh, material family), which is exactly the granularity
## a MultiMesh works at, so the number of draw calls a grove costs is the number
## of distinct plant parts in it and has nothing to do with how many plants
## there are.
class Grove extends RefCounted:
	var opts: Dictionary = {}
	var _layers: Dictionary = {}
	var _order: Array[String] = []

	func _init(o := {}) -> void:
		opts = o

	func material(key: String) -> Material:
		if opts.has(key + "_mat"):
			return opts[key + "_mat"]
		return FoliageKit._default_material(key, opts)

	## `lever` is how freely this element swings, 0 for something bolted to the
	## ground and 1 for a crown tip; `span` is its length in metres, which the
	## shader uses for the gradient from its socket to its tip.
	func add(layer: String, mesh: Mesh, mat_key: String, xf: Transform3D,
			lever: float, span: float, phase: float, tint := Color.WHITE,
			life := 1.0, flutter := 1.0) -> void:
		if not _layers.has(layer):
			var xs: Array[Transform3D] = []
			var cs: Array[Color] = []
			var ts: Array[Color] = []
			_layers[layer] = {"mesh": mesh, "mat": mat_key,
				"xf": xs, "cd": cs, "tint": ts}
			_order.append(layer)
		var l: Dictionary = _layers[layer]
		l["xf"].append(xf)
		l["cd"].append(Color(phase, clampf(lever, 0.0, 1.6), maxf(span, 0.02), flutter))
		l["tint"].append(Color(tint.r, tint.g, tint.b, life))

	func count() -> int:
		var n := 0
		for k: String in _order:
			n += (_layers[k]["xf"] as Array).size()
		return n

	func flush(parent: Node3D, name_ := "Foliage") -> Node3D:
		var root := Node3D.new()
		root.name = name_
		parent.add_child(root)
		var shadows: bool = opts.get("shadows", true)
		var far: float = opts.get("visibility_end", 0.0)
		for key: String in _order:
			var l: Dictionary = _layers[key]
			var xf: Array = l["xf"]
			if xf.is_empty():
				continue
			var mm := MultiMesh.new()
			# Format and buffer flags must all be set BEFORE instance_count or
			# the buffer is allocated without them and every write is dropped.
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = l["mesh"]
			mm.instance_count = xf.size()
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
				mm.set_instance_color(i, l["tint"][i])
				mm.set_instance_custom_data(i, l["cd"][i])
			var node := MultiMeshInstance3D.new()
			node.name = key
			node.multimesh = mm
			node.material_override = material(l["mat"])
			# Foliage animates in the vertex shader, so baking it into a VoxelGI
			# leaves a ghost canopy hanging where the tree was at bake time.
			node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if far > 0.0:
				node.visibility_range_end = far
				node.visibility_range_end_margin = far * 0.12
			root.add_child(node)
		return root


## Open a batch. `opts` is passed to every plant added to it and carries the
## material overrides (`bark_mat`, `frond_mat`, `leaf_mat`, ...), `wind_dir`,
## `shadows` and `visibility_end`.
static func grove(opts := {}) -> Grove:
	return Grove.new(opts)


# --- Determinism ------------------------------------------------------------

## Seeded from the plant's position, quantised to a centimetre so a float
## epsilon in the level builder cannot reshuffle a whole avenue.
static func _rng_for(pos: Vector3, salt := 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var q := Vector3i(roundi(pos.x * 100.0), roundi(pos.y * 100.0), roundi(pos.z * 100.0))
	rng.seed = hash(q) ^ (salt * 2654435761)
	return rng


## Pull a yaw toward the screen plane. A frond aimed at the camera is a stub,
## and on a date palm the arch IS the silhouette, so a crown spiralling on a
## true 137.5 degree phyllotaxis throws away most of its shape in a side view.
## A light bias keeps the spiral's irregularity and puts more of the arches
## where the camera can see them.
static func _bias_to_screen(yaw: float, amount: float) -> float:
	var w := wrapf(yaw, -PI, PI)
	var target := 0.0
	if absf(w) >= PI * 0.5:
		target = PI if w > 0.0 else -PI
	return lerpf(w, target, amount)


## How freely something attached at `y` metres above the root may swing.
## Squared, because a cantilever's deflection is not linear in its length and
## because a linear falloff makes trunks look rubbery.
static func _lever(y: float, plant_height: float, flex := 1.0) -> float:
	var u := clampf(y / maxf(plant_height, 0.001), 0.0, 1.0)
	return u * u * flex


# --- Geometry primitives ----------------------------------------------------
#
# Godot winds FRONT faces CLOCKWISE. Every emitter below takes an `up` hint —
# the side the face is meant to be lit from — and flips the winding and the
# normal to match, which is the only way to stay sane when the same strip
# helper builds a leaflet pointing up and its mirror pointing down.

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		up: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var v := [a, b, c, d]
	var order := [0, 2, 1, 0, 3, 2]
	if n.dot(up) < 0.0:
		n = -n
		order = [0, 1, 2, 0, 2, 3]
	for i: int in order:
		var p: Vector3 = v[i]
		st.set_normal(n)
		st.set_uv(Vector2(p.x, -p.y))
		st.add_vertex(p)


## Same, but carrying per-vertex normals — for anything that should read as
## round on a low segment count, which is every trunk in the game.
static func _quad_smooth(st: SurfaceTool, v: Array, nrm: Array, up: Vector3) -> void:
	var n: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	if n.length_squared() < 1e-14:
		return
	var order := [0, 2, 1, 0, 3, 2]
	if n.normalized().dot(up) < 0.0:
		order = [0, 1, 2, 0, 2, 3]
	for i: int in order:
		var p: Vector3 = v[i]
		st.set_normal(nrm[i])
		st.set_uv(Vector2(p.x, -p.y))
		st.add_vertex(p)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, up: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var v := [a, b, c]
	var order := [0, 2, 1]
	if n.dot(up) < 0.0:
		n = -n
		order = [0, 1, 2]
	for i: int in order:
		var p: Vector3 = v[i]
		st.set_normal(n)
		st.set_uv(Vector2(p.x, -p.y))
		st.add_vertex(p)


static func _strip(st: SurfaceTool, rail_a: Array[Vector3], rail_b: Array[Vector3],
		up: Vector3) -> void:
	for i in rail_a.size() - 1:
		_quad(st, rail_a[i], rail_b[i], rail_b[i + 1], rail_a[i + 1], up)


## The atom of this whole library: a tapering strip that runs down the
## transform's +X, is `w` wide along its Z, droops in -Y, and is creased along
## its midrib so it catches the key on one half and shades on the other.
##
## The crease is what separates this from a flat card. A card lit from the side
## is one flat value and reads as paper; a folded strip has a highlight running
## down it, which at gameplay distance is the entire difference between foliage
## and cardboard.
static func _blade(st: SurfaceTool, xf: Transform3D, length: float, w_base: float,
		w_tip: float, droop: float, segs := 2, fold := 0.0) -> void:
	var centre: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var hw := lerpf(w_base, w_tip, t) * 0.5
		# Quadratic droop: stiff at the socket, giving at the tip.
		var y := -droop * t * t
		var f := fold * (1.0 - t * 0.7)
		var x := length * t
		centre.append(xf * Vector3(x, y + f, 0.0))
		left.append(xf * Vector3(x, y, hw))
		right.append(xf * Vector3(x, y, -hw))
	var up := xf.basis.y
	_strip(st, centre, left, up)
	_strip(st, right, centre, up)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# --- Mesh library -----------------------------------------------------------
#
# Every mesh is unit-sized and cached; instances scale it. Nothing here is
# rebuilt per plant.

## An open-ended drum, radius 0.5, height 1, centred. Trunks, limbs and frond
## collars are all stacks of this. No caps: they are always buried, and the top
## of a trunk is always under a crown.
static func _mesh_drum(sides := 8, top_scale := 1.0) -> Mesh:
	var key := "drum%d_%.3f" % [sides, top_scale]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var v := [
			d0 * 0.5 + Vector3(0.0, -0.5, 0.0),
			d1 * 0.5 + Vector3(0.0, -0.5, 0.0),
			d1 * 0.5 * top_scale + Vector3(0.0, 0.5, 0.0),
			d0 * 0.5 * top_scale + Vector3(0.0, 0.5, 0.0),
		]
		_quad_smooth(st, v, [d0, d1, d1, d0], (d0 + d1) * 0.5)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A date palm frond at unit arc length: a rachis that leaves the crown pointing
## up, arches over and hangs at the tip, carrying leaflet groups down both
## sides. The arch is integrated from a tangent angle rather than faked with a
## sine, because what sells a palm is that the bend is nearly all in the outer
## third — a symmetric arc reads as a croquet hoop.
##
## Variants: 0 the signature arching frond, 1 a younger, stiffer, near-straight
## one for the top of the crown, 2 a sparse short one for dead fronds and for
## palms in the deep layers.
static func _mesh_frond(variant := 0) -> Mesh:
	var key := "frond%d" % variant
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var stations: int = [14, 11, 8][variant]
	var a0: float = [0.95, 1.18, 0.80][variant]     # launch angle, radians up
	var a1: float = [1.35, 0.80, 1.55][variant]     # tip angle, radians down
	var bend: float = [1.75, 2.30, 1.45][variant]   # where the bend happens
	var leaf_len: float = [0.140, 0.120, 0.105][variant]

	var segs := 12
	var st := _begin()
	var path: Array[Vector3] = []
	var tangent: Array[Vector3] = []
	var p := Vector3.ZERO
	for i in segs + 1:
		var t := float(i) / float(segs)
		var ang := lerpf(a0, -a1, pow(t, bend))
		path.append(p)
		tangent.append(Vector3(cos(ang), sin(ang), 0.0))
		p += tangent[i] * (1.0 / float(segs))

	# Rachis: creased, tapering, and thick enough at the base to survive the
	# distance. A date frond's rachis is 60-80 mm across where it leaves the
	# crown and that is exactly at the readability floor.
	var centre: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var hw := lerpf(0.026, 0.005, t)
		centre.append(path[i] + Vector3(0.0, hw * 0.85, 0.0))
		left.append(path[i] + Vector3(0.0, 0.0, hw))
		right.append(path[i] + Vector3(0.0, 0.0, -hw))
	_strip(st, centre, left, Vector3.UP)
	_strip(st, right, centre, Vector3.UP)

	# Leaflets. Each strip stands in for a group of three or four real leaflets:
	# a single one is 20 mm across and would vanish, and a palm with a hundred
	# and twenty invisible leaflets is a bare stick.
	for i in stations:
		var t := lerpf(0.09, 0.97, float(i) / float(maxi(stations - 1, 1)))
		var idx := clampi(int(t * float(segs)), 0, segs - 1)
		var base_pt: Vector3 = path[idx]
		var tg: Vector3 = tangent[idx]
		# Longest around 40% of the way out, short at both ends.
		var plen := leaf_len * (0.42 + 0.58 * sin(pow(t, 0.72) * PI))
		var spread := lerpf(0.95, 0.42, t)
		var keel := lerpf(0.62, 0.05, t)
		var alt := 1.0 if i % 2 == 0 else -1.0
		for s: float in [1.0, -1.0]:
			var dir := (tg * cos(spread) + Vector3(0.0, 0.0, s * sin(spread))).normalized()
			# Leaflets alternate above and below the rachis plane. That zig-zag
			# is the one thing that tells a date palm from a coconut at range.
			dir = (dir + Vector3.UP * sin(keel) * alt).normalized()
			var zax := dir.cross(Vector3.UP)
			if zax.length_squared() < 1e-6:
				zax = Vector3.BACK
			zax = zax.normalized()
			var yax := zax.cross(dir)
			_blade(st, Transform3D(Basis(dir, yax, zax), base_pt), plen,
				0.030, 0.010, plen * lerpf(0.10, 0.80, t), 2, 0.005)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A Washingtonia leaf: a bare petiole and then a palmate fan whose segments
## split and hang at the tips. Unit length 1 along +X.
static func _mesh_fan_leaf() -> Mesh:
	var key := "fan"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	var stalk := 0.40
	_blade(st, Transform3D(Basis.IDENTITY, Vector3.ZERO), stalk, 0.036, 0.026, 0.02, 2, 0.006)
	var hub := Vector3(stalk, 0.0, 0.0)
	var blades := 11
	for i in blades:
		var f := float(i) / float(blades - 1) * 2.0 - 1.0   # -1 .. 1 across the fan
		var yaw := f * 1.32
		# The outer segments are shorter, hang further, and splay out of plane,
		# so the fan is a ragged disc and not a paper doily.
		var len_ := lerpf(0.62, 0.40, absf(f))
		var dir := Vector3(cos(yaw), -0.12 - 0.22 * absf(f), sin(yaw)).normalized()
		var zax := dir.cross(Vector3.UP)
		if zax.length_squared() < 1e-6:
			zax = Vector3.BACK
		zax = zax.normalized()
		var yax := zax.cross(dir)
		_blade(st, Transform3D(Basis(dir, yax, zax), hub), len_,
			0.075, 0.022, len_ * lerpf(0.30, 0.62, absf(f)), 3, 0.010)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A lumpy leaf mass, unit diameter 1, for building a ficus canopy out of many
## interpenetrating masses. Blades sit on a shell, not through the volume: the
## inside of a canopy is never seen and filling it is pure cost. The shell is
## also what leaves the gaps that let sky through.
static func _mesh_clump(variant := 0) -> Mesh:
	var key := "clump%d" % variant
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	var blades := 13
	for i in blades:
		var t := (float(i) + 0.5) / float(blades)
		var phi := acos(clampf(1.0 - 1.85 * t, -1.0, 1.0))
		var theta := float(i) * GOLDEN + float(variant) * 1.13
		var dir := Vector3(sin(phi) * cos(theta), cos(phi) * 0.78,
			sin(phi) * sin(theta)).normalized()
		var wobble := 0.78 + 0.34 * sin(float(i) * 3.77 + float(variant) * 2.1)
		var zax := dir.cross(Vector3.UP)
		if zax.length_squared() < 1e-6:
			zax = Vector3.BACK
		zax = zax.normalized()
		var yax := zax.cross(dir)
		_blade(st, Transform3D(Basis(dir, yax, zax), dir * 0.13), 0.44 * wobble,
			0.30, 0.13, 0.09, 2, 0.02)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A hanging foliage strand, unit length 1 along +X with a heavy droop: the
## eucalyptus and casuarina read. Variant 1 is the casuarina — longer, finer,
## almost all strand and barely any leaf.
static func _mesh_strand(variant := 0) -> Mesh:
	var key := "strand%d" % variant
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	var leaves := 9 if variant == 0 else 13
	var droop := 0.55 if variant == 0 else 0.70
	_blade(st, Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.0, 0.040, 0.014,
		droop, 5, 0.008)
	for i in leaves:
		var t := lerpf(0.16, 0.99, float(i) / float(leaves - 1))
		var at := Vector3(t, -droop * t * t, 0.0)
		var s := 1.0 if i % 2 == 0 else -1.0
		var dir := Vector3(0.35, -0.86, s * 0.36).normalized()
		var zax := dir.cross(Vector3.UP).normalized()
		var yax := zax.cross(dir)
		var len_ := (0.20 if variant == 0 else 0.30) * lerpf(1.15, 0.70, t)
		_blade(st, Transform3D(Basis(dir, yax, zax), at), len_,
			0.050 if variant == 0 else 0.034, 0.016, len_ * 0.22, 1, 0.004)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## One prickly pear pad: unit height 1, rooted at the origin, thick enough to
## hold an edge when the camera's perspective catches it side-on.
static func _mesh_pad() -> Mesh:
	var key := "pad"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	var n := 11
	var half := 0.05
	var rim: Array[Vector3] = []
	for i in n:
		var a := TAU * float(i) / float(n) - PI * 0.5
		# Pinched at the base where it joins the pad below it.
		var pinch := 0.42 + 0.58 * clampf((sin(a) + 1.0) * 0.8, 0.0, 1.0)
		rim.append(Vector3(cos(a) * 0.34 * pinch, 0.5 + sin(a) * 0.5, 0.0))
	var hub := Vector3(0.0, 0.52, 0.0)
	for i in n:
		var a: Vector3 = rim[i]
		var b: Vector3 = rim[(i + 1) % n]
		var af := a.lerp(hub, 0.14) + Vector3(0.0, 0.0, half)
		var bf := b.lerp(hub, 0.14) + Vector3(0.0, 0.0, half)
		var ab := a.lerp(hub, 0.14) - Vector3(0.0, 0.0, half)
		var bb := b.lerp(hub, 0.14) - Vector3(0.0, 0.0, half)
		_tri(st, hub + Vector3(0.0, 0.0, half), af, bf, Vector3.BACK)
		_tri(st, hub - Vector3(0.0, 0.0, half), bb, ab, Vector3.FORWARD)
		_quad(st, af, a, b, bf, (af - hub).normalized())
		_quad(st, ab, a, b, bb, (ab - hub).normalized())
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A tuft of dry grass, unit height 1, rooted at the origin.
static func _mesh_tuft(variant := 0) -> Mesh:
	var key := "tuft%d" % variant
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	var blades := 9
	for i in blades:
		var yaw := float(i) * GOLDEN + float(variant) * 0.9
		var tilt := 0.30 + 0.55 * fmod(float(i) * 0.37 + float(variant) * 0.21, 1.0)
		var dir := Vector3(sin(tilt) * cos(yaw), cos(tilt), sin(tilt) * sin(yaw)).normalized()
		var zax := dir.cross(Vector3.UP)
		if zax.length_squared() < 1e-6:
			zax = Vector3.BACK
		zax = zax.normalized()
		var yax := zax.cross(dir)
		var len_ := lerpf(0.62, 1.0, fmod(float(i) * 0.61 + 0.2, 1.0))
		_blade(st, Transform3D(Basis(dir, yax, zax), Vector3.ZERO), len_,
			0.070, 0.016, len_ * 0.55, 3, 0.012)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A tamarisk branchlet spray — feathery, drooping, grey-green. Unit length 1
## along +X.
static func _mesh_plume() -> Mesh:
	var key := "plume"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	for i in 5:
		var f := float(i) / 4.0 * 2.0 - 1.0
		var dir := Vector3(cos(f * 0.42), -0.22 - 0.2 * absf(f), sin(f * 0.42)).normalized()
		var zax := dir.cross(Vector3.UP).normalized()
		var yax := zax.cross(dir)
		var len_ := lerpf(1.0, 0.62, absf(f))
		_blade(st, Transform3D(Basis(dir, yax, zax), Vector3.ZERO), len_,
			0.055, 0.018, len_ * 0.42, 3, 0.008)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A bougainvillea flower cluster: papery bracts in threes, unit size 1. A
## single bract is 40 mm and invisible; a cluster is 200 mm and is the only
## saturated thing in an Ajdabiya frame.
static func _mesh_bracts() -> Mesh:
	var key := "bracts"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	for i in 7:
		var yaw := float(i) * GOLDEN
		var tilt := 0.55 + 0.5 * fmod(float(i) * 0.41, 1.0)
		var dir := Vector3(sin(tilt) * cos(yaw), cos(tilt) * 0.6, sin(tilt) * sin(yaw)).normalized()
		var zax := dir.cross(Vector3.UP)
		if zax.length_squared() < 1e-6:
			zax = Vector3.BACK
		zax = zax.normalized()
		var yax := zax.cross(dir)
		_blade(st, Transform3D(Basis(dir, yax, zax), dir * 0.08), 0.46,
			0.34, 0.06, 0.05, 1, 0.03)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A hanging bunch of dates, unit length 1 downward from the socket. The only
## warm note on a palm, and the reason a date palm in a Libyan street does not
## read as a hotel palm.
static func _mesh_dates() -> Mesh:
	var key := "dates"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	for i in 9:
		var yaw := float(i) * GOLDEN
		var spread := 0.22 + 0.26 * fmod(float(i) * 0.53, 1.0)
		var dir := Vector3(sin(spread) * cos(yaw), -cos(spread), sin(spread) * sin(yaw)).normalized()
		var zax := dir.cross(Vector3.UP)
		if zax.length_squared() < 1e-6:
			zax = Vector3.BACK
		zax = zax.normalized()
		var yax := zax.cross(dir)
		var len_ := lerpf(0.68, 1.0, fmod(float(i) * 0.37 + 0.1, 1.0))
		_blade(st, Transform3D(Basis(dir, yax, zax), Vector3.ZERO), len_,
			0.115, 0.045, len_ * 0.18, 2, 0.045)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## A strip of shed bark hanging off a eucalyptus, unit length 1 along +X.
static func _mesh_ribbon() -> Mesh:
	var key := "ribbon"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := _begin()
	_blade(st, Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.0, 0.11, 0.03, 0.18, 4, 0.03)
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


# --- Woody structure --------------------------------------------------------

## Lay a run of drums along a path: trunks, limbs, branches, whitewash collars.
## Everything woody in the kit goes through here, so it all lands in one
## MultiMesh and a fifteen-tree row still costs one draw call of bark.
static func _limb(g: Grove, layer: String, mat_key: String, path: Array[Vector3],
		radii: Array[float], phase: float, plant_h: float, root_y: float,
		flex: float, tint := Color.WHITE, life := 1.0) -> void:
	var mesh := _mesh_drum(8, 0.9)
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var d := b - a
		var len_ := d.length()
		if len_ < 0.001:
			continue
		var dir := d / len_
		var basis := Basis.IDENTITY
		var axis := Vector3.UP.cross(dir)
		if axis.length_squared() > 1e-10:
			basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
		elif dir.y < 0.0:
			basis = Basis(Vector3.RIGHT, PI)
		var r: float = (radii[i] + radii[i + 1]) * 0.5
		# 1.06 on the length so consecutive drums overlap: a visible gap between
		# two trunk segments is the loudest possible "this is a stack of
		# cylinders" tell.
		basis = basis * Basis.IDENTITY.scaled(Vector3(r * 2.0, len_ * 1.06, r * 2.0))
		var mid := (a + b) * 0.5
		g.add(layer, mesh, mat_key, Transform3D(basis, mid),
			_lever(mid.y - root_y, plant_h, flex), maxf(len_, 0.2), phase, tint, life, 0.3)


## One wider, shorter drum — a frond-base collar, a whitewash band, a graft
## swelling. Same mesh and material as the trunk, so it is free.
static func _collar(g: Grove, layer: String, mat_key: String, at: Vector3,
		radius: float, thickness: float, yaw: float, phase: float,
		plant_h: float, root_y: float, flex: float, tint := Color.WHITE,
		life := 1.0) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis.IDENTITY.scaled(
		Vector3(radius * 2.0, thickness, radius * 2.0))
	g.add(layer, _mesh_drum(8, 0.9), mat_key, Transform3D(basis, at),
		_lever(at.y - root_y, plant_h, flex), maxf(thickness, 0.2), phase, tint, life, 0.3)


## Aim an element: yaw around the trunk, pitch up from horizontal, uniform
## scale. Every frond, fan, strand and plume in the kit is placed with this.
static func _aim(yaw: float, pitch: float, scale_: float, roll := 0.0) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, 1.0), pitch) \
		* Basis(Vector3(1.0, 0.0, 0.0), roll) * Basis.IDENTITY.scaled(Vector3.ONE * scale_)


# --- Species ----------------------------------------------------------------

## Date palm. A fibrous column and a crown of long arching fronds — and the
## arch is the entire silhouette, so the crown gets three tiers (young spears
## standing up, the signature arches, old fronds hanging) rather than one ring
## of identical leaves. Dead fronds hang down the trunk because nobody has
## pruned this one, and the date bunches are the only warm note on it.
static func _plant_date_palm(g: Grove, base: Vector3, height: float, opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 11)
	var phase := rng.randf() * TAU
	var trunk_h := height * 0.84
	var lean := rng.randf_range(-0.13, 0.13)
	var bow := rng.randf_range(-0.06, 0.06)
	var bark_tint := Color(1.0, 1.0, 1.0).lerp(Color(0.86, 0.82, 0.74), rng.randf())

	var segs := maxi(9, int(trunk_h / 0.42))
	var path: Array[Vector3] = []
	var radii: Array[float] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		# Leans from the base and straightens toward the crown, with a slight
		# bow. A dead-straight palm reads as a lamp post with a hat on.
		var off := lean * trunk_h * t * t * 0.55 + bow * trunk_h * sin(t * PI) * 0.30
		path.append(base + Vector3(off, trunk_h * t, off * 0.30))
		radii.append(lerpf(height * 0.028, height * 0.020, t))
	_limb(g, "Trunk", "bark", path, radii, phase, height, base.y, 0.07, bark_tint)

	# Old frond bases: the stepped diamond collar pattern that makes a palm
	# trunk read as a palm trunk and not as a concrete pile.
	for i in range(1, segs, 2):
		_collar(g, "Trunk", "bark", path[i], radii[i] * 1.26, height * 0.045,
			PI * 0.25 * float(i % 2) + rng.randf_range(-0.12, 0.12), phase,
			height, base.y, 0.07, bark_tint.darkened(0.08))

	var crown: Vector3 = path[segs]
	var frond_len := height * rng.randf_range(0.42, 0.50)
	var live := rng.randi_range(11, 14)
	var screen_bias: float = opts.get("screen_bias", 0.26)
	for i in live:
		var tier := i % 3
		var yaw := _bias_to_screen(float(i) * GOLDEN + phase, screen_bias)
		var pitch := 0.0
		var len_ := frond_len
		var variant := 0
		match tier:
			0:
				pitch = deg_to_rad(rng.randf_range(46.0, 74.0))
				len_ *= rng.randf_range(0.66, 0.82)
				variant = 1
			1:
				pitch = deg_to_rad(rng.randf_range(4.0, 30.0))
			_:
				pitch = deg_to_rad(rng.randf_range(-40.0, -12.0))
				len_ *= rng.randf_range(0.94, 1.06)
		# Sockets spread over the head so the crown has a centre with volume
		# instead of every frond radiating from one point.
		var socket := crown + Vector3(cos(yaw) * radii[segs] * 0.6,
			rng.randf_range(-0.22, 0.30) * (height * 0.05),
			sin(yaw) * radii[segs] * 0.6)
		var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.82, 0.90, 0.72), rng.randf() * 0.8)
		g.add("Frond%d" % variant, _mesh_frond(variant), "frond",
			Transform3D(_aim(yaw, pitch, len_, rng.randf_range(-0.22, 0.22)), socket),
			1.0, len_, phase + float(i) * 0.31, tint,
			rng.randf_range(0.82, 1.0), 1.0)

	# The skirt of dead fronds nobody has cut off.
	var dead := rng.randi_range(4, 7)
	for i in dead:
		var yaw := _bias_to_screen(float(i) * GOLDEN * 1.7 + phase * 0.5, screen_bias * 0.7)
		var pitch := deg_to_rad(rng.randf_range(-86.0, -58.0))
		var len_ := frond_len * rng.randf_range(0.62, 0.80)
		g.add("Frond2", _mesh_frond(2), "frond",
			Transform3D(_aim(yaw, pitch, len_, rng.randf_range(-0.3, 0.3)),
				crown + Vector3(0.0, -height * 0.035, 0.0)),
			0.55, len_, phase + float(i) * 0.7,
			Color(1.0, 0.96, 0.88), rng.randf_range(0.0, 0.12), 0.6)

	if rng.randf() < float(opts.get("fruit_chance", 0.7)):
		for i in rng.randi_range(2, 3):
			var yaw := _bias_to_screen(rng.randf_range(0.0, TAU), 0.45)
			var len_ := height * rng.randf_range(0.13, 0.19)
			g.add("Dates", _mesh_dates(), "fruit",
				Transform3D(_aim(yaw, deg_to_rad(rng.randf_range(-78.0, -50.0)), len_),
					crown + Vector3(0.0, -height * 0.02, 0.0)),
				0.85, len_, phase + float(i), Color.WHITE, 1.0, 0.7)


## Washingtonia. The second species on a street, so a row is not a clone line:
## a fatter trunk, a denser crown of fan leaves, and the dead skirt hanging off
## it that nobody is allowed to burn any more. The skirt is the whole read.
static func _plant_fan_palm(g: Grove, base: Vector3, height: float, opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 23)
	var phase := rng.randf() * TAU
	var trunk_h := height * 0.80
	var lean := rng.randf_range(-0.09, 0.09)
	var bark_tint := Color(0.94, 0.92, 0.88).lerp(Color(0.80, 0.76, 0.70), rng.randf())

	var segs := maxi(8, int(trunk_h / 0.5))
	var path: Array[Vector3] = []
	var radii: Array[float] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var off := lean * trunk_h * t * t * 0.5
		path.append(base + Vector3(off, trunk_h * t, off * 0.25))
		# Washingtonias are near-columnar and thicker than a date palm, with a
		# swollen foot.
		radii.append(lerpf(height * 0.040, height * 0.028, pow(t, 0.55)))
	_limb(g, "Trunk", "bark", path, radii, phase, height, base.y, 0.05, bark_tint)
	for i in range(2, segs, 3):
		_collar(g, "Trunk", "bark", path[i], radii[i] * 1.12, height * 0.03,
			rng.randf_range(0.0, TAU), phase, height, base.y, 0.05, bark_tint)

	var crown: Vector3 = path[segs]
	var leaf_len := height * rng.randf_range(0.24, 0.30)
	var live := rng.randi_range(13, 17)
	for i in live:
		var yaw := _bias_to_screen(float(i) * GOLDEN + phase, 0.22)
		var pitch := deg_to_rad(lerpf(78.0, 4.0, float(i) / float(live - 1))
			+ rng.randf_range(-9.0, 9.0))
		var len_ := leaf_len * rng.randf_range(0.86, 1.12)
		g.add("Fan", _mesh_fan_leaf(), "frond",
			Transform3D(_aim(yaw, pitch, len_, rng.randf_range(-0.35, 0.35)), crown),
			1.0, len_, phase + float(i) * 0.27,
			Color(1.0, 1.0, 1.0).lerp(Color(0.88, 0.94, 0.78), rng.randf()),
			rng.randf_range(0.80, 1.0))

	# The skirt: dead leaves folded back against the trunk, thickest right
	# under the crown and thinning downward.
	var skirt := rng.randi_range(14, 20)
	for i in skirt:
		var t := float(i) / float(skirt - 1)
		var yaw := float(i) * GOLDEN * 1.31 + phase
		var drop := crown - Vector3(0.0, t * height * 0.16, 0.0)
		var len_ := leaf_len * lerpf(0.9, 0.55, t)
		g.add("Fan", _mesh_fan_leaf(), "frond",
			Transform3D(_aim(yaw, deg_to_rad(rng.randf_range(-88.0, -64.0)), len_,
				rng.randf_range(-0.4, 0.4)), drop),
			0.30 * (1.0 - t * 0.6), len_, phase + float(i) * 0.9,
			Color(1.0, 0.97, 0.90), rng.randf_range(0.0, 0.10), 0.5)


## Eucalyptus / casuarina: the Brega windbreak. Hard-tapering leaning trunk,
## sparse branches sweeping up and out, long drooping leaf strands hanging off
## their ends. `dead` gives the silvered bare version — half of any real
## windbreak on this coast is one, and a dead tree standing in a straight line
## is unmistakably planted.
static func _plant_eucalyptus(g: Grove, base: Vector3, height: float, opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 37)
	var phase := rng.randf() * TAU
	var dead: bool = opts.get("dead", false)
	var casuarina: bool = opts.get("casuarina", false)
	var lean := rng.randf_range(-0.22, 0.22)
	var kink := rng.randf_range(-0.10, 0.10)
	var bark_life := 0.0 if dead else rng.randf_range(0.35, 0.85)

	var segs := maxi(8, int(height / 1.0))
	var path: Array[Vector3] = []
	var radii: Array[float] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var off := lean * height * t * t * 0.32 + kink * height * sin(t * PI * 1.6) * 0.12
		path.append(base + Vector3(off, height * t, off * 0.4))
		# Hard taper: a eucalyptus loses most of its diameter in the first third.
		radii.append(lerpf(height * 0.030, height * 0.006, pow(t, 0.62)))
	_limb(g, "Trunk", "bark", path, radii, phase, height, base.y, 0.22,
		Color.WHITE, bark_life)

	var branches := rng.randi_range(5, 8)
	for i in branches:
		var t := lerpf(0.42, 0.94, float(i) / float(branches - 1)) + rng.randf_range(-0.04, 0.04)
		var idx := clampi(int(t * float(segs)), 1, segs)
		var socket: Vector3 = path[idx]
		var side := 1.0 if i % 2 == 0 else -1.0
		var yaw := _bias_to_screen(rng.randf_range(0.0, TAU), 0.55)
		if side < 0.0:
			yaw = _bias_to_screen(yaw + PI, 0.55)
		var blen := height * rng.randf_range(0.16, 0.30) * (1.0 - t * 0.35)
		# Branches leave the trunk steeply and flatten as they go: that upward
		# sweep and then the hang off the end is the eucalyptus gesture.
		var bpath: Array[Vector3] = []
		var brad: Array[float] = []
		var pitch0 := deg_to_rad(rng.randf_range(48.0, 72.0))
		var p := socket
		for k in 4:
			var u := float(k) / 3.0
			var ang := lerpf(pitch0, pitch0 * 0.15 - 0.12, u)
			bpath.append(p)
			brad.append(lerpf(radii[idx] * 0.62, radii[idx] * 0.16, u))
			p += Vector3(cos(ang) * cos(yaw), sin(ang), cos(ang) * sin(yaw)) * (blen / 3.0)
		bpath.append(p)
		brad.append(radii[idx] * 0.12)
		_limb(g, "Trunk", "bark", bpath, brad, phase + float(i) * 0.4, height,
			base.y, 0.55, Color.WHITE, bark_life)

		if dead:
			continue
		# Strands hang off the outer half of every branch.
		var strands := rng.randi_range(3, 6)
		for k in strands:
			var u := rng.randf_range(0.45, 1.0)
			var at: Vector3 = bpath[0].lerp(p, u)
			var slen := height * rng.randf_range(0.12, 0.22)
			g.add("Strand", _mesh_strand(1 if casuarina else 0), "strand",
				Transform3D(_aim(yaw + rng.randf_range(-0.9, 0.9),
					deg_to_rad(rng.randf_range(-40.0, 12.0)), slen,
					rng.randf_range(-0.5, 0.5)), at),
				_lever(at.y - base.y, height, 1.0), slen,
				phase + float(k) * 0.53,
				Color(1.0, 1.0, 1.0).lerp(Color(0.86, 0.92, 0.80), rng.randf()),
				rng.randf_range(0.7, 1.0))

	# Shed bark hanging off the trunk. Cheap, and it is the detail that says
	# eucalyptus rather than "tree".
	for i in rng.randi_range(2, 4):
		var t := rng.randf_range(0.30, 0.72)
		var idx := clampi(int(t * float(segs)), 1, segs)
		var rlen := height * rng.randf_range(0.08, 0.16)
		g.add("Ribbon", _mesh_ribbon(), "bark",
			Transform3D(_aim(rng.randf_range(0.0, TAU),
				deg_to_rad(rng.randf_range(-92.0, -66.0)), rlen), path[idx]),
			_lever(path[idx].y - base.y, height, 0.9), rlen, phase + float(i),
			Color.WHITE, maxf(bark_life - 0.2, 0.0), 1.4)

	if dead:
		# Broken stubs where the crown used to be: the last read a dead tree has.
		for i in rng.randi_range(2, 3):
			var yaw := _bias_to_screen(rng.randf_range(0.0, TAU), 0.6)
			var slen := height * rng.randf_range(0.06, 0.12)
			var tip: Vector3 = path[segs] + Vector3(cos(yaw), 0.55, sin(yaw)) * slen
			_limb(g, "Trunk", "bark", _v3a([path[segs], tip]),
				_fa([radii[segs] * 0.8, radii[segs] * 0.3]),
				phase, height, base.y, 0.7, Color.WHITE, 0.0)


## Ficus street tree: a short stout bole, a few heavy limbs, and a canopy built
## from a dozen interpenetrating masses at three radii. A single ellipsoid is a
## lollipop; a lumpy layered mass with two deliberate voids in it reads as a
## tree and lets sky through, which is the only thing that keeps it from going
## to a black blob against a bright morning.
static func _plant_ficus(g: Grove, base: Vector3, height: float, opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 53)
	var phase := rng.randf() * TAU
	var bole := height * rng.randf_range(0.28, 0.36)
	var lean := rng.randf_range(-0.10, 0.10)

	var segs := 4
	var path: Array[Vector3] = []
	var radii: Array[float] = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		path.append(base + Vector3(lean * bole * t * t, bole * t, 0.0))
		radii.append(lerpf(height * 0.052, height * 0.034, t))
	_limb(g, "Trunk", "bark", path, radii, phase, height, base.y, 0.10)

	var crown_y := base.y + height * rng.randf_range(0.60, 0.68)
	var spread := height * rng.randf_range(0.34, 0.44)
	var limbs := rng.randi_range(4, 6)
	for i in limbs:
		var yaw := _bias_to_screen(float(i) * GOLDEN + phase, 0.35)
		var reach := spread * rng.randf_range(0.55, 0.95)
		var tip := Vector3(base.x + cos(yaw) * reach, crown_y + rng.randf_range(-0.4, 0.5),
			base.z + sin(yaw) * reach * 0.6)
		var mid := path[segs].lerp(tip, 0.5) + Vector3(0.0, reach * 0.22, 0.0)
		_limb(g, "Trunk", "bark", _v3a([path[segs], mid, tip]),
			_fa([radii[segs] * 0.8, radii[segs] * 0.5, radii[segs] * 0.26]),
			phase + float(i) * 0.3, height, base.y, 0.30)

	# Canopy. Masses at three radii, with two angular voids cut out of them.
	var void_a := rng.randf_range(0.0, TAU)
	var void_b := void_a + rng.randf_range(1.8, 3.4)
	var masses := rng.randi_range(27, 34)
	for i in masses:
		var yaw := float(i) * GOLDEN + phase
		if absf(angle_difference(yaw, void_a)) < 0.42 or absf(angle_difference(yaw, void_b)) < 0.33:
			continue
		var shell := fmod(float(i) * 0.37, 1.0)
		var r := spread * lerpf(0.30, 1.0, shell)
		var y := crown_y + height * (0.04 + 0.16 * sin(float(i) * 1.7 + phase)) \
			+ height * 0.10 * (1.0 - shell)
		var at := Vector3(base.x + cos(yaw) * r, y, base.z + sin(yaw) * r * 0.62)
		var size := height * rng.randf_range(0.15, 0.24)
		# Masses buried inside the canopy get a baked darkening: the cheapest
		# possible ambient occlusion, and the thing that gives a canopy depth
		# rather than a flat green wall.
		var occ := lerpf(0.55, 1.0, shell)
		g.add("Clump%d" % (i % 3), _mesh_clump(i % 3), "leaf",
			Transform3D(_aim(yaw * 1.7, rng.randf_range(-0.4, 0.4), size,
				rng.randf_range(0.0, TAU)), at),
			_lever(y - base.y, height, 0.85), size * 0.5, phase + float(i) * 0.21,
			Color(occ, occ, occ).lerp(Color(occ * 1.06, occ * 1.02, occ * 0.9), rng.randf()),
			rng.randf_range(0.86, 1.0))


## Prickly pear: a proper pad stack. Pads bud from the rim of the pad below at
## an angle, and they all grow in roughly one plane — which is lucky, because
## that plane faces the camera and gives the clearest silhouette of anything in
## the kit.
static func _plant_prickly_pear(g: Grove, base: Vector3, height: float,
		opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 67)
	var phase := rng.randf() * TAU
	var pad := height * rng.randf_range(0.34, 0.44)
	var plane := rng.randf_range(-0.5, 0.5)   # the plane the clump grows in
	var fruit_mesh := _mesh_drum(8, 0.82)

	# Breadth-first so the stack builds bottom-up, deterministically.
	var queue: Array = []
	for i in rng.randi_range(2, 3):
		queue.append([base + Vector3(rng.randf_range(-0.2, 0.2), 0.0,
			rng.randf_range(-0.15, 0.15)),
			PI * 0.5 + rng.randf_range(-0.45, 0.45), pad * rng.randf_range(0.85, 1.15), 0])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var at: Vector3 = item[0]
		var ang: float = item[1]
		var size: float = item[2]
		var depth: int = item[3]
		var basis := Basis(Vector3.UP, plane + rng.randf_range(-0.22, 0.22)) \
			* Basis(Vector3(0.0, 0.0, 1.0), ang - PI * 0.5) \
			* Basis.IDENTITY.scaled(Vector3.ONE * size)
		g.add("Pad", _mesh_pad(), "succulent", Transform3D(basis, at),
			_lever(at.y - base.y, height, 0.35), size, phase + float(depth) * 0.6,
			Color(1.0, 1.0, 1.0).lerp(Color(0.88, 0.95, 0.86), rng.randf()),
			1.0, 0.2)
		var tip := at + Vector3(cos(ang), sin(ang), 0.0).rotated(Vector3.UP, plane) * size * 0.88
		if depth >= 2:
			# Fruit ride the top rim of the outermost pads.
			if rng.randf() < 0.55:
				for f in rng.randi_range(1, 3):
					var fb := Basis.IDENTITY.scaled(
						Vector3(size * 0.16, size * 0.30, size * 0.16))
					g.add("Fruit", fruit_mesh, "fruit",
						Transform3D(fb, tip + Vector3(rng.randf_range(-0.12, 0.12) * size,
							size * 0.1, rng.randf_range(-0.1, 0.1) * size)),
						_lever(tip.y - base.y, height, 0.3), size * 0.3, phase,
						Color(1.0, 0.92, 0.86), 1.0, 0.2)
			continue
		for k in rng.randi_range(1, 2):
			var spread := rng.randf_range(0.42, 0.95) * (1.0 if k == 0 else -1.0)
			queue.append([tip, ang + spread, size * rng.randf_range(0.72, 0.88), depth + 1])


## A tuft of dry grass. Never a lawn: these go down as separated mounds with
## bare ground showing between them, because that is what actually grows on a
## salt plain and because continuous cover reads as a golf course.
static func _plant_grass(g: Grove, base: Vector3, height: float, opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 79)
	var phase := rng.randf() * TAU
	var n := rng.randi_range(1, 3)
	for i in n:
		var at := base + Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.3, 0.3))
		var h := height * rng.randf_range(0.65, 1.15) * (1.0 if i == 0 else 0.7)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(0.0, 0.0, 1.0), rng.randf_range(-0.18, 0.18)) \
			* Basis.IDENTITY.scaled(Vector3(h * rng.randf_range(0.7, 1.1), h,
				h * rng.randf_range(0.7, 1.1)))
		g.add("Tuft%d" % (i % 2), _mesh_tuft(i % 2), "grass",
			Transform3D(basis, at), 0.9, h, phase + float(i) * 0.8,
			Color(1.0, 1.0, 1.0).lerp(Color(0.92, 0.86, 0.72), rng.randf()),
			rng.randf_range(0.0, 0.22), 1.0)


## Tamarisk scrub: many stems from one root, feathery plumes, grey-green. The
## one thing that survives on the sabkha margin, and the only planting allowed
## to break the "bare ground between every plant" rule, because it grows as a
## thicket.
static func _plant_tamarisk(g: Grove, base: Vector3, height: float, opts: Dictionary) -> void:
	var rng := _rng_for(base, int(opts.get("seed", 0)) + 89)
	var phase := rng.randf() * TAU
	var stems := rng.randi_range(5, 9)
	for i in stems:
		var yaw := _bias_to_screen(float(i) * GOLDEN + phase, 0.3)
		var tilt := rng.randf_range(0.12, 0.42)
		var h := height * rng.randf_range(0.6, 1.0)
		var top := base + Vector3(cos(yaw) * sin(tilt), cos(tilt), sin(yaw) * sin(tilt)) * h
		var mid := base.lerp(top, 0.55) + Vector3(0.0, h * 0.06, 0.0)
		_limb(g, "Trunk", "bark", _v3a([base, mid, top]),
			_fa([h * 0.035, h * 0.022, h * 0.012]), phase + float(i) * 0.5,
			height, base.y, 0.45)
		for k in rng.randi_range(2, 4):
			var at := mid.lerp(top, rng.randf_range(0.25, 1.0))
			var plen := h * rng.randf_range(0.28, 0.5)
			g.add("Plume", _mesh_plume(), "scrub",
				Transform3D(_aim(yaw + rng.randf_range(-1.1, 1.1),
					deg_to_rad(rng.randf_range(-15.0, 45.0)), plen,
					rng.randf_range(-0.6, 0.6)), at),
				_lever(at.y - base.y, height, 1.0), plen, phase + float(k) * 0.7,
				Color(1.0, 1.0, 1.0).lerp(Color(0.90, 0.94, 0.86), rng.randf()),
				rng.randf_range(0.55, 0.95))


## Bougainvillea spilling over a wall. `from` and `to` run along the TOP of the
## wall; the mass climbs a little above it and falls down the face toward the
## camera.
##
## This is the one saturated magenta allowed in Ajdabiya, so it is rationed: the
## bracts sit on the outer and upper surface of the mass where the sun would
## actually be driving them, and the interior stays green. A uniformly magenta
## hedge would eat the level's colour script in one prop.
static func _plant_bougainvillea(g: Grove, from: Vector3, to: Vector3,
		opts: Dictionary) -> void:
	var rng := _rng_for(from, int(opts.get("seed", 0)) + 97)
	var phase := rng.randf() * TAU
	var run := to - from
	var length := run.length()
	if length < 0.01:
		return
	var depth: float = opts.get("depth", 2.4)          # how far it falls
	var face: Vector3 = opts.get("face", Vector3(0.0, 0.0, 1.0))
	var bloom: float = opts.get("bloom", 0.42)         # share of magenta clusters
	var samples := maxi(3, int(length / 0.85))
	for i in samples:
		var t := (float(i) + 0.5) / float(samples)
		var anchor := from + run * t
		# A ragged curtain: long falls, short falls, and a couple of places
		# where the wall shows through. A hedge with a level bottom edge is a
		# municipal planter, not a plant.
		var fall := depth * (0.30 + 0.70 * absf(sin(t * 7.3 + phase)) * rng.randf_range(0.6, 1.2))
		if rng.randf() < 0.10:
			continue
		var masses := maxi(2, int(fall / 0.55))
		for k in masses + 2:
			var u := float(k) / float(masses + 1)
			var bulge := sin(u * PI) * rng.randf_range(0.25, 0.55)
			var at := anchor + face * (0.2 + bulge) \
				+ Vector3(rng.randf_range(-0.25, 0.25),
					lerpf(rng.randf_range(0.1, 0.55), -fall, u), 0.0)
			var size := rng.randf_range(0.55, 1.0)
			var outer := u < 0.55 or bulge > 0.42
			if outer and rng.randf() < bloom:
				g.add("Bracts", _mesh_bracts(), "bloom",
					Transform3D(_aim(rng.randf_range(0.0, TAU),
						rng.randf_range(-0.9, 0.5), size * 0.55,
						rng.randf_range(0.0, TAU)), at),
					0.85, size * 0.5, phase + float(k) * 0.4,
					Color(1.0, 1.0, 1.0).lerp(Color(0.86, 0.78, 0.92), rng.randf() * 0.7))
			else:
				var occ := lerpf(0.62, 1.0, clampf(bulge * 2.0, 0.0, 1.0))
				g.add("Clump%d" % (k % 3), _mesh_clump(k % 3), "leaf",
					Transform3D(_aim(rng.randf_range(0.0, TAU),
						rng.randf_range(-0.5, 0.5), size,
						rng.randf_range(0.0, TAU)), at),
					0.8, size * 0.5, phase + float(k) * 0.33,
					Color(occ, occ * 1.02, occ * 0.92), rng.randf_range(0.85, 1.0))


# --- Dispatch ---------------------------------------------------------------

## Plant one of anything into an open grove. Species: `date_palm`, `fan_palm`,
## `eucalyptus`, `casuarina`, `ficus`, `prickly_pear`, `grass`, `tamarisk`.
static func plant(g: Grove, species: String, base: Vector3, height: float,
		opts := {}) -> void:
	match species:
		"date_palm":
			_plant_date_palm(g, base, height, opts)
		"fan_palm":
			_plant_fan_palm(g, base, height, opts)
		"eucalyptus":
			_plant_eucalyptus(g, base, height, opts)
		"casuarina":
			var o := opts.duplicate()
			o["casuarina"] = true
			_plant_eucalyptus(g, base, height, o)
		"ficus":
			_plant_ficus(g, base, height, opts)
		"prickly_pear":
			_plant_prickly_pear(g, base, height, opts)
		"grass":
			_plant_grass(g, base, height, opts)
		"tamarisk":
			_plant_tamarisk(g, base, height, opts)
		_:
			push_warning("FoliageKit: unknown species " + species)


## One plant, its own grove. Convenient for a hero tree; for anything that
## repeats, open a grove and use `plant` so the row shares its draw calls.
static func single(parent: Node3D, species: String, base: Vector3, height: float,
		opts := {}) -> Node3D:
	var g := grove(opts)
	plant(g, species, base, height, opts)
	return g.flush(parent, str(opts.get("name", species.capitalize())))


static func date_palm(parent: Node3D, base: Vector3, height := 8.5, opts := {}) -> Node3D:
	return single(parent, "date_palm", base, height, opts)


static func fan_palm(parent: Node3D, base: Vector3, height := 9.5, opts := {}) -> Node3D:
	return single(parent, "fan_palm", base, height, opts)


static func eucalyptus(parent: Node3D, base: Vector3, height := 9.0, opts := {}) -> Node3D:
	return single(parent, "eucalyptus", base, height, opts)


static func ficus(parent: Node3D, base: Vector3, height := 7.0, opts := {}) -> Node3D:
	return single(parent, "ficus", base, height, opts)


static func prickly_pear(parent: Node3D, base: Vector3, height := 1.6, opts := {}) -> Node3D:
	return single(parent, "prickly_pear", base, height, opts)


static func grass_tuft(parent: Node3D, base: Vector3, height := 0.55, opts := {}) -> Node3D:
	return single(parent, "grass", base, height, opts)


static func tamarisk(parent: Node3D, base: Vector3, height := 2.0, opts := {}) -> Node3D:
	return single(parent, "tamarisk", base, height, opts)


## Bougainvillea over a wall, from one end of the wall top to the other.
static func bougainvillea(parent: Node3D, from: Vector3, to: Vector3,
		opts := {}) -> Node3D:
	var g := grove(opts)
	_plant_bougainvillea(g, from, to, opts)
	return g.flush(parent, str(opts.get("name", "Bougainvillea")))


static func _v3a(items: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector3 in items:
		out.append(v)
	return out


static func _fa(items: Array) -> Array[float]:
	var out: Array[float] = []
	for v: float in items:
		out.append(v)
	return out


# --- Scatters ---------------------------------------------------------------
#
# All three are deterministic from a seed, so a level rebuilds identically and
# two screenshots a week apart are actually comparable. All three flush into one
# grove, so the draw-call cost of a row is flat in the number of plants.

const DEFAULT_HEIGHT := {
	"date_palm": Vector2(7.0, 10.5),
	"fan_palm": Vector2(8.0, 12.5),
	"eucalyptus": Vector2(7.5, 11.0),
	"casuarina": Vector2(8.0, 12.0),
	"ficus": Vector2(5.5, 7.5),
	"prickly_pear": Vector2(1.1, 2.1),
	"grass": Vector2(0.35, 0.75),
	"tamarisk": Vector2(1.4, 2.8),
}


static func _pick(rng: RandomNumberGenerator, mix: Dictionary) -> String:
	var total := 0.0
	for k: String in mix:
		total += float(mix[k])
	var r := rng.randf() * maxf(total, 0.0001)
	for k: String in mix:
		r -= float(mix[k])
		if r <= 0.0:
			return k
	return str(mix.keys()[0])


static func _height_for(rng: RandomNumberGenerator, species: String,
		opts: Dictionary) -> float:
	var band: Vector2 = DEFAULT_HEIGHT.get(species, Vector2(3.0, 5.0))
	var heights: Dictionary = opts.get("heights", {})
	if heights.has(species):
		band = heights[species]
	return rng.randf_range(band.x, band.y)


## The oil company's windbreak: eucalyptus and casuarina planted dead straight
## to hold the sand back, irrigation long since stopped, failing back to desert
## in visible rows. Most of it is dead and that is the point — a dead tree in a
## straight line is unmistakably planted, and the straightness is the story.
##
## `from` and `to` are the ends of the planted line. Gaps are ones that never
## took, not random deletions: they cluster, because whatever killed one killed
## its neighbour.
static func windbreak_row(parent: Node3D, from: Vector3, to: Vector3, count: int,
		opts := {}) -> Node3D:
	var g := grove(opts)
	var rng := _rng_for(from, int(opts.get("seed", 0)) + 101)
	var dead_ratio: float = opts.get("dead", 0.58)
	var gap_chance: float = opts.get("gap", 0.10)
	var wobble: float = opts.get("wobble", 0.35)
	var run_dead := false
	for i in maxi(count, 1):
		var t := float(i) / float(maxi(count - 1, 1))
		# The line was planted with a tape. Only the ground under it wanders.
		var at := from.lerp(to, t) + Vector3(rng.randf_range(-wobble, wobble), 0.0,
			rng.randf_range(-wobble, wobble) * 1.6)
		if rng.randf() < gap_chance:
			continue
		# Death runs along a row: a failed section is contiguous, not sprinkled.
		run_dead = rng.randf() < (0.75 if run_dead else dead_ratio)
		var species := "casuarina" if (i % 3 == 2) else "eucalyptus"
		plant(g, species, at, _height_for(rng, species, opts), {
			"seed": int(opts.get("seed", 0)) * 31 + i,
			"dead": run_dead,
		})
	return g.flush(parent, str(opts.get("name", "Windbreak")))


## A planted street: palms and ficus on a kerb line, alternating species so a
## row is never a clone line, whitewashed at the foot the way every municipal
## tree in eastern Libya is. Spacing is regular — these were planted by a
## council — but the species, heights and lean are not.
static func street_trees(parent: Node3D, from: Vector3, to: Vector3,
		spacing := 9.0, opts := {}) -> Node3D:
	var g := grove(opts)
	var rng := _rng_for(from, int(opts.get("seed", 0)) + 103)
	var mix: Dictionary = opts.get("mix", {"date_palm": 0.5, "fan_palm": 0.26, "ficus": 0.24})
	var whitewash: bool = opts.get("whitewash", true)
	var jitter: float = opts.get("jitter", 0.5)
	var run := to - from
	var length := run.length()
	var n := maxi(1, int(length / maxf(spacing, 0.5)))
	var last := ""
	for i in n + 1:
		var t := float(i) / float(n)
		var at := from + run * t + Vector3(rng.randf_range(-jitter, jitter), 0.0,
			rng.randf_range(-jitter, jitter) * 0.6)
		if rng.randf() < float(opts.get("gap", 0.06)):
			continue
		var species := _pick(rng, mix)
		if species == last and rng.randf() < 0.7:
			species = _pick(rng, mix)   # two of the same in a row reads as a copy
		last = species
		var h := _height_for(rng, species, opts)
		plant(g, species, at, h, {
			"seed": int(opts.get("seed", 0)) * 17 + i,
			"screen_bias": opts.get("screen_bias", 0.26),
		})
		if whitewash and species != "ficus":
			# The lime band. Municipal, ubiquitous, and it puts a bright value
			# at the foot of every trunk which is exactly where the eye needs a
			# ground contact.
			# Sized off the species' own trunk: a band narrower than the trunk
			# is invisible and a band much wider is a doughnut.
			var band_r := (h * 0.045) if species == "fan_palm" else (h * 0.032)
			for b in 3:
				_collar(g, "Trunk", "bark", at + Vector3(0.0, 0.18 + float(b) * 0.24, 0.0),
					band_r, 0.26, rng.randf_range(0.0, TAU), 0.0, h, at.y, 0.0,
					Color.WHITE, 0.0)
	return g.flush(parent, str(opts.get("name", "StreetTrees")))


## Wild growth along a verge or a sabkha margin: separated low mounds with bare
## ground between every one of them, never continuous cover. Nothing in eastern
## Libya grows as a carpet, and a carpet is what makes a desert level look like
## a golf course.
static func scrub_band(parent: Node3D, from: Vector3, to: Vector3,
		per_metre := 0.35, opts := {}) -> Node3D:
	var g := grove(opts)
	var rng := _rng_for(from, int(opts.get("seed", 0)) + 107)
	var mix: Dictionary = opts.get("mix",
		{"grass": 0.62, "tamarisk": 0.23, "prickly_pear": 0.15})
	var band: float = opts.get("band", 1.8)          # half-width across Z
	var min_gap: float = opts.get("min_gap", 0.9)    # bare ground between plants
	var run := to - from
	var length := run.length()
	var budget := int(length * maxf(per_metre, 0.01))
	var placed: Array[Vector3] = []
	var tries := budget * 4
	var made := 0
	for _i in tries:
		if made >= budget:
			break
		var t := rng.randf()
		var at := from + run * t + Vector3(0.0, 0.0, rng.randf_range(-band, band))
		var clear := true
		for p: Vector3 in placed:
			if at.distance_squared_to(p) < min_gap * min_gap:
				clear = false
				break
		if not clear:
			continue
		placed.append(at)
		made += 1
		var species := _pick(rng, mix)
		plant(g, species, at, _height_for(rng, species, opts), {
			"seed": int(opts.get("seed", 0)) * 13 + made,
		})
	return g.flush(parent, str(opts.get("name", "Scrub")))
