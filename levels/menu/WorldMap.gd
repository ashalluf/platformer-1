extends Node3D
## WORLD 1 — the map.
##
## Not a menu with level names on it: a relief map of the eastern coast in a
## brass tray, seen from above at an angle, with the Gulf of Sidra on one side
## and the five stops of World 1 pinned along the road between Brega and
## Benghazi. The geography is real and in the right order, because that order
## is canon.
##
## The land is a heightfield, not a coloured slab. That buys three things at
## once: the Jebel actually rises toward Benghazi, the coastline is where the
## ground crosses sea level instead of where one flat colour stops, and the
## terrain colours can be painted into the vertices so nothing on the map has
## an outline. A polygon of a second colour laid on a map reads as a sticker
## however irregular you make its edge; a continuous field never does.
##
## Nodes reuse the collection screen's medallions, so a pin on the map and the
## chain you earn there are obviously the same object.

## Map space is (east, north) in quarter-degrees from Brega, so the shape of
## the coast and the order of the stops are the real ones. Godot gets north as
## -z, which is the only conversion in this file.
const NODE_MAP := {
	"brega": Vector2(0.00, 0.00),
	"ajdabiya": Vector2(2.48, 1.44),
	"highway": Vector2(2.55, 3.90),
	"garyounis": Vector2(2.55, 5.85),
	"benghazi": Vector2(1.70, 7.05),
}

## The piece of coast the tray holds, in map space.
const MAP_MIN := Vector2(-9.0, -4.5)
const MAP_MAX := Vector2(7.5, 11.0)
## Heightfield cell size. Small enough that the waterline is a curve rather
## than a staircase, large enough that building it is not a visible hitch.
const CELL := 0.17
## Sea level. Everything on this map is measured from it.
const SEA_Y := 0.0
## How far the tray wall overlaps the terrain, so the sheet's cut edge is
## buried rather than showing as a cliff of nothing.
const RAIL_BITE := 0.25
const RAIL_W := 0.70
const RAIL_TOP := 0.52
const RAIL_BOTTOM := -0.95

## Layer 20, reserved for the vignette quad that rides on the camera.
const VIGNETTE_LAYER := 1 << 19


static func world_of(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, -p.y)


static func node_pos(chain_id: String) -> Vector3:
	return world_of(NODE_MAP[chain_id])

var entries: Array = []
var selected := 0
var _pins: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _camera: Camera3D
var _overlay: MapOverlay
var _sun: DirectionalLight3D
var _sea_mat: StandardMaterial3D
var _surf_mat: StandardMaterial3D
var _t := 0.0
var _slide := 0.0
var _unlocked := 1

# The heightfield, kept so the road, the pins and the labels can sit ON the
# land instead of hovering at a guessed height.
var _cols := 0
var _rows := 0
var _height := PackedFloat32Array()


func _ready() -> void:
	entries = World.world_one()
	_apply_capture_override()
	_unlocked = World.unlocked_count()
	selected = clampi(_unlocked - 1, 0, entries.size() - 1)
	_slide = float(selected)

	_build_mood()
	_build_land()
	_build_sea()
	_build_surf()
	_build_tray()
	_build_road()
	_build_rose()
	_build_pins()
	_build_camera()

	var layer := CanvasLayer.new()
	layer.name = "MapUI"
	add_child(layer)
	_overlay = MapOverlay.new()
	layer.add_child(_overlay)
	_overlay.set_entry(entries[selected], _state(selected))
	Music.set_intensity(0.22)


## Capture-only: `--cleared=brega,ajdabiya` walks the unlock line forward so the
## map can be signed off in a state a new save cannot reach.
func _apply_capture_override() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cleared="):
			for id: String in arg.substr(10).split(",", false):
				Gx.levels_cleared[id] = {"time": 0.0}
		elif arg.begins_with("--chains="):
			for id: String in arg.substr(9).split(",", false):
				Gx.chains[id] = true


func _state(i: int) -> String:
	var e: World.Entry = entries[i]
	if not e.built():
		return "coming"
	if i >= _unlocked:
		return "locked"
	if Gx.levels_cleared.has(e.chain_id):
		return "cleared"
	return "open"


# --- Mood -------------------------------------------------------------------

func _build_mood() -> void:
	var m := LightingRig.Mood.new()
	# Late afternoon over the table: a low warm key so every pin and every ridge
	# throws a long shadow across the land, which is what makes a map read as an
	# object rather than as a picture of one.
	m.sun_angles = Vector2(-34.0, 118.0)
	m.sun_color = Color(1.0, 0.82, 0.58)
	m.sun_energy = 3.6
	m.sun_angular_distance = 1.2
	m.sun_disc_size = 0.0
	m.sun_fog_energy = 1.0
	m.fill_angles = Vector2(-22.0, -46.0)
	m.fill_color = Color(0.52, 0.62, 0.86)
	m.fill_energy = 0.52
	m.rim_energy = 0.0
	m.sky_top = Color(0.055, 0.060, 0.086)
	m.sky_horizon = Color(0.130, 0.115, 0.125)
	m.ground_horizon = Color(0.075, 0.065, 0.062)
	m.ground_bottom = Color(0.030, 0.026, 0.028)
	m.sky_energy = 0.9
	m.ambient_energy = 0.42
	m.volumetric_density = 0.004
	m.fog_density = 0.0
	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.10
	m.white = 7.0
	m.glow_intensity = 0.34
	m.glow_hdr_threshold = 1.25
	m.adjustment_saturation = 1.12
	m.adjustment_contrast = 1.10
	LightingRig.build(self, m)
	_sun = get_node_or_null("Sun") as DirectionalLight3D


# --- The coastline ----------------------------------------------------------

## The shoreline control points, walked west to east along the Gulf of Sidra
## and then north up to Benghazi. The sea is always on the LEFT of this walk
## and the land always on the right — the whole heightfield leans on that, so
## the order of these points is not cosmetic.
##
## Both ends run well outside the tray: the sign of the signed distance is
## taken from the nearest segment, and a point past the end of the curve has
## no reliable nearest segment.
func _shore() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-13.50, 1.15), Vector2(-10.20, 1.10), Vector2(-7.20, 1.05),
		Vector2(-4.80, 0.92), Vector2(-2.60, 0.80), Vector2(-0.90, 0.78),
		Vector2(0.40, 0.92), Vector2(1.35, 1.45), Vector2(1.95, 2.45),
		Vector2(1.85, 3.70), Vector2(1.35, 5.10), Vector2(0.95, 6.35),
		Vector2(1.15, 7.45), Vector2(1.95, 8.35), Vector2(3.00, 8.90),
		Vector2(3.90, 10.60), Vector2(4.60, 13.40), Vector2(5.10, 17.00),
	])


## Catmull-Rom through the control points. The raw polyline's corners are
## visible as kinks in the surf line at this zoom; the terrain does not care,
## but the white line drawn on top of it does.
static func _spline(control: PackedVector2Array, per_seg: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := control.size()
	for i in n - 1:
		var p0: Vector2 = control[maxi(i - 1, 0)]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[i + 1]
		var p3: Vector2 = control[mini(i + 2, n - 1)]
		for s in per_seg:
			var t := float(s) / float(per_seg)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (
				2.0 * p1 + (p2 - p0) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(control[n - 1])
	return out


## Distance to the shore, negative at sea. Sign comes from which side of the
## nearest segment the point falls on, which is free — a polygon test would be
## a second pass over the same geometry for an answer we already have.
static func _shore_distance(p: Vector2, pts: PackedVector2Array) -> float:
	var best := 1.0e20
	var side := 1.0
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 <= 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var d2 := p.distance_squared_to(a + ab * t)
		if d2 < best:
			best = d2
			# Cross > 0 means the point is to the left of the walk, which is
			# the sea.
			side = -1.0 if ab.cross(p - a) > 0.0 else 1.0
	return sqrt(best) * side


# --- The land ---------------------------------------------------------------

## Gaussian bump about a line segment in map space, for ridges.
static func _ridge(p: Vector2, a: Vector2, b: Vector2, width: float) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 <= 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	var d := p.distance_to(a + ab * t) / width
	return exp(-d * d)


static func _blob(p: Vector2, at: Vector2, r: float) -> float:
	var d := p.distance_to(at) / r
	return exp(-d * d)


func _build_land() -> void:
	var coast := _spline(_shore(), 3)
	_cols = int((MAP_MAX.x - MAP_MIN.x) / CELL) + 1
	_rows = int((MAP_MAX.y - MAP_MIN.y) / CELL) + 1
	var count := _cols * _rows
	_height.resize(count)
	var colors := PackedColorArray()
	colors.resize(count)

	for iy in _rows:
		var north := MAP_MIN.y + iy * CELL
		for ix in _cols:
			var east := MAP_MIN.x + ix * CELL
			var p := Vector2(east, north)
			var d := _shore_distance(p, coast)
			var h := 0.0
			var col := Color.BLACK

			if d <= 0.0:
				# Offshore: a narrow shelf, then away. The sea is transparent,
				# so this is the gradient that becomes "shallow" and "deep".
				var off := -d
				h = -0.030 - 0.30 * smoothstep(0.0, 1.10, off) \
					- 0.32 * smoothstep(0.9, 5.0, off)
				col = Color(0.46, 0.43, 0.32).lerp(Color(0.055, 0.075, 0.078),
					smoothstep(0.05, 1.8, off))
			else:
				# The coastal plain, climbing inland.
				h = 0.032 + 0.150 * smoothstep(0.0, 1.30, d) \
					+ 0.105 * smoothstep(1.0, 5.0, d)
				col = Color(0.735, 0.660, 0.495).lerp(Color(0.545, 0.450, 0.300),
					smoothstep(0.03, 0.85, d))

				# Dunes: long ridges out of the Sirte basin, south and east,
				# fading out as the ground rises toward the Jebel.
				var dune_mask := smoothstep(3.4, 0.4, north) * smoothstep(0.55, 2.0, d)
				if dune_mask > 0.001:
					var ridge := 0.5 + 0.5 * sin((east * 0.74 + north * 1.02) * 2.15)
					h += 0.062 * ridge * dune_mask
					col = col.lerp(Color(0.660, 0.535, 0.340),
						dune_mask * (0.35 + 0.45 * ridge))

				# Sabkha: the salt pans behind Brega. Flat, pale, and the one
				# place on this coast where the ground is lighter than the sand.
				var sabkha := maxf(maxf(_blob(p, Vector2(-2.60, -0.85), 2.35),
					_blob(p, Vector2(1.30, -1.90), 1.85)),
					_blob(p, Vector2(-6.10, -0.20), 1.95))
				sabkha *= smoothstep(0.35, 1.1, d)
				if sabkha > 0.001:
					h = lerpf(h, 0.048, sabkha * 0.85)
					col = col.lerp(Color(0.715, 0.695, 0.630), sabkha * 0.92)

				# The Jebel Akhdar. It starts just inland of Benghazi and runs
				# northeast; the escarpment in front of it is the reason the
				# coast road hugs the water all the way up.
				# The crest sits well east of the city: Benghazi itself is on
				# the coastal plain, and a pin standing halfway up a mountain
				# is the kind of error a Libyan spots in one frame.
				var jebel := 0.70 * _ridge(p, Vector2(4.20, 6.60),
					Vector2(9.00, 10.60), 1.90)
				jebel += 0.30 * _ridge(p, Vector2(3.00, 8.20),
					Vector2(7.20, 11.80), 1.10)
				jebel *= smoothstep(0.05, 0.60, d)
				if jebel > 0.001:
					h += jebel
					col = col.lerp(Color(0.355, 0.335, 0.205),
						clampf(jebel * 3.4, 0.0, 1.0) * 0.92)
					col = col.lerp(Color(0.225, 0.285, 0.160),
						clampf((jebel - 0.26) * 2.6, 0.0, 1.0))

				# Roll the land down toward the tray wall. Without this the
				# Jebel walks straight over the northeast corner of the frame
				# and the map stops being a thing in a box.
				var edge := minf(minf(east - MAP_MIN.x, MAP_MAX.x - east),
					minf(north - MAP_MIN.y, MAP_MAX.y - north))
				h = lerpf(0.10, h, smoothstep(0.0, 2.2, edge))

			# A little deterministic roughness so no slope is ever a clean
			# plane. Cheaper than a noise texture and it moves the normals.
			h += 0.0115 * sin(east * 7.31) * sin(north * 6.07)
			h += 0.0070 * sin(east * 17.1 + north * 11.3)

			var k := iy * _cols + ix
			_height[k] = h
			# Vertex colours go into the shader raw. albedo_color is converted
			# from sRGB on the way in and these are not, so they have to be
			# handed over already linear or the whole country comes out washed.
			colors[k] = col.srgb_to_linear()

	_commit_land(colors)


## Build the mesh from the height grid. Normals come from neighbouring heights
## rather than from four more evaluations of the field, which is the difference
## between one pass and five.
func _commit_land(colors: PackedColorArray) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tans := PackedFloat32Array()
	verts.resize(_cols * _rows)
	norms.resize(_cols * _rows)
	uvs.resize(_cols * _rows)
	tans.resize(_cols * _rows * 4)

	for iy in _rows:
		var north := MAP_MIN.y + iy * CELL
		for ix in _cols:
			var east := MAP_MIN.x + ix * CELL
			var k := iy * _cols + ix
			var xm := _height[iy * _cols + maxi(ix - 1, 0)]
			var xp := _height[iy * _cols + mini(ix + 1, _cols - 1)]
			var ym := _height[maxi(iy - 1, 0) * _cols + ix]
			var yp := _height[mini(iy + 1, _rows - 1) * _cols + ix]
			var gx := (xp - xm) / (2.0 * CELL)
			var gn := (yp - ym) / (2.0 * CELL)
			verts[k] = Vector3(east, _height[k], -north)
			# dP/de = (1, gx, 0) and dP/dn = (0, gn, -1); their cross is this.
			norms[k] = Vector3(-gx, 1.0, gn).normalized()
			uvs[k] = Vector2(east, -north)
			# U runs along east, so the tangent is dP/de. Handedness is -1
			# because V runs along -north.
			var tg := Vector3(1.0, gx, 0.0).normalized()
			tans[k * 4] = tg.x
			tans[k * 4 + 1] = tg.y
			tans[k * 4 + 2] = tg.z
			tans[k * 4 + 3] = -1.0

	var idx := PackedInt32Array()
	idx.resize((_cols - 1) * (_rows - 1) * 6)
	var w := 0
	for iy in _rows - 1:
		for ix in _cols - 1:
			var a := iy * _cols + ix
			var b := a + 1
			var c := a + _cols + 1
			var d := a + _cols
			# Seen from above, a->b->c->d runs counter-clockwise, and Godot
			# keeps the clockwise face. So it goes round the other way.
			idx[w] = a; idx[w + 1] = d; idx[w + 2] = c
			idx[w + 3] = a; idx[w + 4] = c; idx[w + 5] = b
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.94
	mat.metallic = 0.0
	# Fine grain only. The weathered surface shader's macro noise is metres
	# across, and at map scale that puts the country in camouflage.
	mat.normal_enabled = true
	mat.normal_texture = NoiseBank.detail_normal(43, 0.38, 0.75)
	mat.normal_scale = 0.55
	mat.uv1_scale = Vector3(2.6, 2.6, 1.0)

	var land := MeshInstance3D.new()
	land.name = "Land"
	land.mesh = mesh
	land.material_override = mat
	add_child(land)


## Bilinear lookup into the height grid, so anything standing on the map knows
## where the ground is.
func _height_at(p: Vector2) -> float:
	if _height.is_empty():
		return 0.0
	var fx := clampf((p.x - MAP_MIN.x) / CELL, 0.0, float(_cols - 1))
	var fy := clampf((p.y - MAP_MIN.y) / CELL, 0.0, float(_rows - 1))
	var ix := mini(int(fx), _cols - 2)
	var iy := mini(int(fy), _rows - 2)
	var tx := fx - ix
	var ty := fy - iy
	var h00 := _height[iy * _cols + ix]
	var h10 := _height[iy * _cols + ix + 1]
	var h01 := _height[(iy + 1) * _cols + ix]
	var h11 := _height[(iy + 1) * _cols + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)


# --- Water ------------------------------------------------------------------

func _build_sea() -> void:
	var size := MAP_MAX - MAP_MIN
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.y)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.position = Vector3((MAP_MIN.x + MAP_MAX.x) * 0.5, SEA_Y,
		-(MAP_MIN.y + MAP_MAX.y) * 0.5)

	_sea_mat = StandardMaterial3D.new()
	# Transparent, so the shelf underneath is what makes the water shallow at
	# the beach and black out to sea. Depth painted onto a flat blue plane is
	# always a gradient; depth you can see through is depth.
	_sea_mat.albedo_color = Color(0.026, 0.094, 0.126, 0.88)
	_sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sea_mat.roughness = 0.10
	_sea_mat.metallic = 0.0
	_sea_mat.metallic_specular = 1.0
	# Fades the water out where it meets the ground, which is the entire trick
	# behind a beach that does not look like a cut.
	_sea_mat.proximity_fade_enabled = true
	_sea_mat.proximity_fade_distance = 0.42
	_sea_mat.normal_enabled = true
	_sea_mat.normal_texture = NoiseBank.detail_normal(59, 0.42, 0.55)
	_sea_mat.normal_scale = 0.35
	_sea_mat.uv1_scale = Vector3(11.0, 11.0, 1.0)
	_sea_mat.render_priority = -2
	sea.material_override = _sea_mat
	add_child(sea)

	_build_sun_path()


## The sun's path across the water. A directional specular alone gives a hard
## little dot at this roughness; the band is what a low sun on open water
## actually looks like from above.
func _build_sun_path() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.55))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.38, Color(1, 1, 1, 0.18))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.62, 1.0)
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2

	var quad := QuadMesh.new()
	quad.size = Vector2(15.0, 4.2)
	var mi := MeshInstance3D.new()
	mi.name = "SunPath"
	mi.mesh = quad
	mi.material_override = mat
	mi.position = Vector3(-5.4, SEA_Y + 0.016, -3.6)
	# Flat on the water, turned to run along the sun's azimuth.
	mi.rotation = Vector3(-PI * 0.5, deg_to_rad(28.0), 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The surf. A ribbon laid along the coastline with the foam broken up along
## its length, rather than a row of white boxes: a beach is a line that varies,
## and a constant-width stripe reads as a drawn border.
func _build_surf() -> void:
	var line := _spline(_shore(), 6)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.42, Color(1, 1, 1, 1.0))
	grad.add_point(0.66, Color(1, 1, 1, 0.72))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 96

	_surf_mat = StandardMaterial3D.new()
	_surf_mat.albedo_color = Color(0.92, 0.96, 0.94, 1.0)
	_surf_mat.albedo_texture = tex
	_surf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_surf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_surf_mat.vertex_color_use_as_albedo = true
	_surf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surf_mat.render_priority = 4

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var run := 0.0
	for i in line.size():
		var p: Vector2 = line[i]
		var prev: Vector2 = line[maxi(i - 1, 0)]
		var next: Vector2 = line[mini(i + 1, line.size() - 1)]
		var dir := (next - prev).normalized()
		var out := Vector2(-dir.y, dir.x)   # seaward: the sea is on the left
		if i > 0:
			run += p.distance_to(prev)
		# Foam is not a stripe. Two beats out of phase keep the line alive
		# without any of it ever going fully dark.
		var a := 0.48 + 0.34 * sin(run * 5.3) + 0.18 * sin(run * 13.1 + 1.7)
		var tint := Color(1, 1, 1, clampf(a, 0.12, 1.0))
		var width := 0.115 + 0.055 * sin(run * 3.1)
		for s: float in [1.0, -0.65]:
			var q := p + out * width * s
			verts.append(Vector3(q.x, SEA_Y + 0.014, -q.y))
			uvs.append(Vector2(run * 0.9, 0.0 if s > 0.0 else 1.0))
			cols.append(tint)
			norms.append(Vector3.UP)

	var idx := PackedInt32Array()
	for i in line.size() - 1:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = "Surf"
	mi.mesh = mesh
	mi.material_override = _surf_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- The object the map is ---------------------------------------------------

## The tray, its plinth and the table it stands on. Without an edge the map is
## an infinite plane with a country printed on it; with one it is a thing
## somebody carried into a room and put down.
func _build_tray() -> void:
	var brass := ChainForge.brass(Color(0.50, 0.38, 0.19))
	var centre := Vector3((MAP_MIN.x + MAP_MAX.x) * 0.5, 0.0,
		-(MAP_MIN.y + MAP_MAX.y) * 0.5)
	var span := MAP_MAX - MAP_MIN
	var outer_x := span.x + (RAIL_W - RAIL_BITE) * 2.0
	var outer_z := span.y + (RAIL_W - RAIL_BITE) * 2.0
	var h := RAIL_TOP - RAIL_BOTTOM
	var mid_y := (RAIL_TOP + RAIL_BOTTOM) * 0.5

	var walls := [
		[Vector3(centre.x, mid_y, centre.z - span.y * 0.5 - RAIL_W * 0.5 + RAIL_BITE),
			Vector3(outer_x, h, RAIL_W)],
		[Vector3(centre.x, mid_y, centre.z + span.y * 0.5 + RAIL_W * 0.5 - RAIL_BITE),
			Vector3(outer_x, h, RAIL_W)],
		[Vector3(centre.x - span.x * 0.5 - RAIL_W * 0.5 + RAIL_BITE, mid_y, centre.z),
			Vector3(RAIL_W, h, outer_z)],
		[Vector3(centre.x + span.x * 0.5 + RAIL_W * 0.5 - RAIL_BITE, mid_y, centre.z),
			Vector3(RAIL_W, h, outer_z)],
	]
	for i in walls.size():
		var mi := MeshInstance3D.new()
		mi.name = "TrayWall%d" % i
		mi.mesh = LevelKit.chamfer_mesh(walls[i][1] as Vector3, 0.055)
		mi.material_override = brass
		mi.position = walls[i][0]
		add_child(mi)

	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	plinth.mesh = LevelKit.chamfer_mesh(
		Vector3(outer_x + 1.0, 0.95, outer_z + 1.0), 0.085)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.072, 0.046, 0.034)
	wood.roughness = 0.36
	wood.metallic = 0.0
	wood.metallic_specular = 0.62
	# Grain as a roughness break-up: the chamfered box has UVs but no tangents,
	# and a normal map without a tangent shades to garbage.
	wood.roughness_texture = NoiseBank.streaks(67)
	wood.uv1_scale = Vector3(0.35, 2.6, 1.0)
	plinth.material_override = wood
	plinth.position = Vector3(centre.x, RAIL_BOTTOM - 0.475, centre.z)
	add_child(plinth)

	var table := MeshInstance3D.new()
	table.name = "Table"
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	table.mesh = plane
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.026, 0.022, 0.024)
	felt.roughness = 0.95
	felt.metallic = 0.0
	table.material_override = felt
	table.position = Vector3(centre.x, RAIL_BOTTOM - 0.96, centre.z)
	add_child(table)


## A compass rose inlaid into the empty desert southwest of Brega. Maps have
## one, and this corner of the frame was a hectare of flat orange.
func _build_rose() -> void:
	var at := Vector2(-5.60, -1.00)
	var star := PackedVector2Array()
	for i in 16:
		var th := TAU * float(i) / 16.0 + PI * 0.5
		# The cardinal points are longer than the ordinals, the way they are on
		# every rose ever engraved.
		var r := (0.50 if i % 4 == 0 else 0.34) if i % 2 == 0 else 0.10
		star.append(Vector2(cos(th) * r, sin(th) * r))

	var brass := ChainForge.brass(Color(0.56, 0.43, 0.22))
	var mi := MeshInstance3D.new()
	mi.name = "CompassRose"
	mi.mesh = ChainForge.relief(star, 0.030, 0.028)
	mi.material_override = brass
	mi.scale = Vector3.ONE * 1.75
	mi.position = Vector3(at.x, _height_at(at) + 0.012, -at.y)
	mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(mi)

	var ring := MeshInstance3D.new()
	ring.name = "RoseRing"
	var tor := TorusMesh.new()
	tor.inner_radius = 1.02
	tor.outer_radius = 1.09
	tor.rings = 48
	tor.ring_segments = 6
	ring.mesh = tor
	ring.material_override = brass
	ring.position = Vector3(at.x, _height_at(at) + 0.018, -at.y)
	add_child(ring)


# --- The road ---------------------------------------------------------------

## The coast road, as a ribbon that follows the ground. The old version was a
## chain of boxes at a fixed height, which floated over the rises and sank into
## the dips — and a road that does not touch the land is a line drawn on a
## picture of a map.
func _build_road() -> void:
	var control := PackedVector2Array()
	for e: World.Entry in entries:
		control.append(NODE_MAP[e.chain_id])
	var route := _spline(control, 16)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.72
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var run := 0.0
	for i in route.size():
		var p: Vector2 = route[i]
		var prev: Vector2 = route[maxi(i - 1, 0)]
		var next: Vector2 = route[mini(i + 1, route.size() - 1)]
		var dir := (next - prev).normalized()
		var side := Vector2(-dir.y, dir.x)
		if i > 0:
			run += p.distance_to(prev)
		# Half the ribbon is shoulder: a hard-edged strip of black reads as
		# tape, a graded one reads as a road with gravel either side.
		for pair: Array in [[-1.0, 0.0], [-0.55, 1.0], [0.55, 1.0], [1.0, 0.0]]:
			var q := p + side * 0.115 * (pair[0] as float)
			verts.append(Vector3(q.x, _height_at(q) + 0.016, -q.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2(run, pair[0] as float))
			cols.append(Color(0.30, 0.27, 0.23).lerp(
				Color(0.085, 0.082, 0.086), pair[1] as float).srgb_to_linear())

	var idx := PackedInt32Array()
	for i in route.size() - 1:
		var a := i * 4
		for k in 3:
			idx.append_array([a + k, a + k + 1, a + k + 4,
				a + k + 1, a + k + 5, a + k + 4])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	_build_road_dashes(route)


## Centre line, as real dashes rather than a repeating texture: forty quads is
## cheaper to reason about than a UV wrap, and each one can sit at its own
## ground height.
func _build_road_dashes(route: PackedVector2Array) -> void:
	var paint := MaterialLab.emissive(Color(0.95, 0.88, 0.62), 0.30)
	paint.roughness = 0.6

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var step := 4
	var i := 2
	while i < route.size() - step:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 2]
		var dir := (route[mini(i + 1, route.size() - 1)] - route[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x) * 0.021
		var base := verts.size()
		for q: Vector2 in [a - side, a + side, b + side, b - side]:
			verts.append(Vector3(q.x, _height_at(q) + 0.024, -q.y))
			norms.append(Vector3.UP)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		i += step

	if idx.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = "RoadDashes"
	mi.mesh = mesh
	var two_sided: StandardMaterial3D = paint.duplicate()
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = two_sided
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Pins -------------------------------------------------------------------

func _build_pins() -> void:
	for i in entries.size():
		var e: World.Entry = entries[i]
		var at: Vector2 = NODE_MAP[e.chain_id]
		var ground := _height_at(at)
		var pin := Node3D.new()
		pin.name = "Pin_" + e.chain_id
		pin.position = Vector3(at.x, ground, -at.y)
		add_child(pin)
		_pins.append(pin)

		var open := i < _unlocked and e.built()
		var earned := Gx.chains.has(e.chain_id)
		var metal: Material = ChainForge.trophy_gold() if earned \
			else ChainForge.ghost_metal()
		var steel := ChainForge.brass(Color(0.42, 0.33, 0.18))

		# Machined, not whittled: a flange that sits on the ground, a turned
		# shaft, a collar under the head. A plain tapered cylinder is a peg.
		var flange := MeshInstance3D.new()
		flange.name = "Flange"
		var fc := CylinderMesh.new()
		fc.top_radius = 0.082
		fc.bottom_radius = 0.105
		fc.height = 0.040
		fc.radial_segments = 20
		fc.rings = 1
		flange.mesh = fc
		flange.material_override = steel
		flange.position = Vector3(0.0, 0.020, 0.0)
		pin.add_child(flange)

		var post := MeshInstance3D.new()
		post.name = "Post"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.021
		cyl.bottom_radius = 0.034
		cyl.height = 0.64
		cyl.radial_segments = 14
		cyl.rings = 1
		post.mesh = cyl
		post.material_override = steel
		post.position = Vector3(0.0, 0.36, 0.0)
		pin.add_child(post)

		var collar := MeshInstance3D.new()
		collar.name = "Collar"
		var tor := TorusMesh.new()
		tor.inner_radius = 0.026
		tor.outer_radius = 0.052
		tor.rings = 20
		tor.ring_segments = 7
		collar.mesh = tor
		collar.material_override = steel
		collar.position = Vector3(0.0, 0.655, 0.0)
		pin.add_child(collar)

		var head := Node3D.new()
		head.name = "Head"
		head.position = Vector3(0.0, 0.90, 0.0)
		pin.add_child(head)
		head.add_child(ChainForge.medallion(e.chain_id, 0.56, metal, earned))

		var lamp := OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.light_color = Color(1.0, 0.62, 0.26) if open else Color(0.42, 0.52, 0.76)
		lamp.light_energy = 1.2
		lamp.omni_range = 1.5
		lamp.shadow_enabled = false
		lamp.position = Vector3(0.0, 0.2, 0.42)
		head.add_child(lamp)
		_lamps.append(lamp)

		# The place name is printed on the map, lying flat next to its pin, the
		# way a name is printed on a paper map — not floating above it.
		var label_at := at + Vector2(0.70, -0.34)
		var label := PropKit.sign(self, e.short_ar,
			Vector3(label_at.x, _height_at(label_at) + 0.02, -label_at.y), 0.30,
			MaterialLab.emissive(Color(1.0, 0.95, 0.86), 0.50),
			PropKit.FONT_KUFI, 0.010)
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Camera -----------------------------------------------------------------

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 40.0
	_camera.near = 0.2
	_camera.far = 260.0
	add_child(_camera)
	_camera.current = true
	_build_vignette()


## Same vignette as the chain room, for the same reason: Godot's Environment
## has none, and crushing the whole image to fake one costs the brass its
## highlights.
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.74))
	grad.add_point(0.50, Color(1, 1, 1, 0.0))
	grad.add_point(0.80, Color(1, 1, 1, 0.26))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.014, 0.011, 0.014, 1.0)
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = 120
	mat.disable_receive_shadows = true

	var half_h := tan(deg_to_rad(_camera.fov * 0.5))
	var quad := QuadMesh.new()
	quad.size = Vector2(half_h * 2.0 * (16.0 / 9.0) * 1.08, half_h * 2.0 * 1.08)
	var mi := MeshInstance3D.new()
	mi.name = "Vignette"
	mi.mesh = quad
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.0, -1.0)
	mi.layers = VIGNETTE_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_camera.add_child(mi)


# --- Drive ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_slide = lerpf(_slide, float(selected), 1.0 - exp(-8.0 * delta))

	var centre := Vector3(0.6, 0.0, -3.1)
	var focus: Vector3 = centre.lerp(_focus_point(), 0.42)
	# Held at a table angle, drifting slowly so the map is never a still image.
	var orbit := 0.26 + sin(_t * 0.075) * 0.050
	var height := 13.0 + sin(_t * 0.11) * 0.22
	var back := 11.8
	_camera.position = focus + Vector3(sin(orbit) * back, height, cos(orbit) * back)
	_camera.look_at(focus + Vector3(0.0, 0.25, 0.0), Vector3.UP)
	_camera.rotation.z += sin(_t * 0.14) * 0.004

	# The key drifts too. Two degrees of yaw is nothing to look at and
	# everything to feel: every ridge shadow on the map creeps.
	if _sun:
		_sun.rotation_degrees.y = 118.0 + sin(_t * 0.055) * 2.4
		_sun.rotation_degrees.x = -34.0 + sin(_t * 0.041) * 1.1

	# Slow swell, so the water is moving even when nothing else is.
	if _sea_mat:
		_sea_mat.uv1_offset += Vector3(0.0055, 0.0032, 0.0) * delta
	if _surf_mat:
		_surf_mat.albedo_color.a = 0.80 + 0.20 * sin(_t * 0.9)

	for i in _pins.size():
		var f := 1.0 - clampf(absf(_slide - i), 0.0, 1.0)
		var ease := f * f * (3.0 - 2.0 * f)
		var head := _pins[i].get_node("Head") as Node3D
		head.position.y = 0.90 + ease * 0.26 + sin(_t * 1.3 + i) * 0.014
		head.rotation.y = _camera.rotation.y + sin(_t * 0.5 + i) * 0.12 * (1.0 - ease)
		_lamps[i].light_energy = lerpf(1.0, 4.4, ease)


func _focus_point() -> Vector3:
	var lo := floori(_slide)
	var hi := mini(lo + 1, entries.size() - 1)
	var a: Vector3 = node_pos((entries[lo] as World.Entry).chain_id)
	var b: Vector3 = node_pos((entries[hi] as World.Entry).chain_id)
	return a.lerp(b, _slide - lo)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left", true):
		_step(-1)
	elif event.is_action_pressed("move_right", true):
		_step(1)
	elif event.is_action_pressed("confirm") or event.is_action_pressed("jump") \
			or event.is_action_pressed("attack"):
		_enter()
	elif event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		Audio.play_2d("ui", -4.0, 0.85, "UI")
		SceneFlow.change_scene("res://levels/menu/TitleScreen.tscn")


func _step(dir: int) -> void:
	var next := clampi(selected + dir, 0, entries.size() - 1)
	if next == selected:
		return
	selected = next
	Audio.play_2d("ui", -9.0, 1.0 + dir * 0.05, "UI")
	_overlay.set_entry(entries[selected], _state(selected))


func _enter() -> void:
	var e: World.Entry = entries[selected]
	if _state(selected) == "locked" or not e.built():
		Audio.play_2d("ui", -6.0, 0.6, "UI")
		_overlay.refuse()
		return
	Audio.play_2d("ui", -4.0, 1.25, "UI")
	Gx.reset_run()
	SceneFlow.change_scene(e.scene)
