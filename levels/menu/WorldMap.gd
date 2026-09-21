extends Node3D
## WORLD 1 — the map.
##
## Not a menu with level names on it: a table map of the eastern coast, seen
## from above at an angle, with the Gulf of Sidra on one side and the five
## stops of World 1 pinned along the road between Brega and Benghazi. The
## geography is real and in the right order, because that order is canon.
##
## Nodes reuse the collection screen's medallion emblems, so a pin on the map
## and the chain you earn there are obviously the same object.

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
var _t := 0.0
var _slide := 0.0
var _unlocked := 1


func _ready() -> void:
	entries = World.world_one()
	_apply_capture_override()
	_unlocked = World.unlocked_count()
	selected = clampi(_unlocked - 1, 0, entries.size() - 1)
	_slide = float(selected)

	_build_mood()
	_build_sea()
	_build_land()
	_build_ground_patches()
	_build_road()
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


# --- Build ------------------------------------------------------------------

func _build_mood() -> void:
	var m := LightingRig.Mood.new()
	# Late afternoon over the table: a low warm key so every pin throws a long
	# shadow across the land, which is what makes a flat map read as an object.
	m.sun_angles = Vector2(-38.0, 118.0)
	m.sun_color = Color(1.0, 0.82, 0.58)
	m.sun_energy = 3.2
	m.sun_angular_distance = 1.6
	m.sun_disc_size = 0.0
	m.sun_fog_energy = 1.0
	m.fill_angles = Vector2(-22.0, -46.0)
	m.fill_color = Color(0.52, 0.62, 0.86)
	m.fill_energy = 0.55
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


func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	# Wide enough that the horizon is sea, not the end of a box.
	sea.name = "Sea"
	var box := BoxMesh.new()
	box.size = Vector3(140.0, 0.6, 120.0)
	sea.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.048, 0.125, 0.155)
	mat.roughness = 0.26
	mat.metallic = 0.10
	mat.metallic_specular = 0.75
	sea.material_override = mat
	sea.position = Vector3(-14.0, -0.42, -6.0)
	add_child(sea)


## The shoreline, walked west to east along the Gulf of Sidra and then north
## up to Benghazi. The sea is north and west of it; the land is east and south.
func _shore() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-7.20, 1.05), Vector2(-4.80, 0.92), Vector2(-2.60, 0.80),
		Vector2(-0.90, 0.78), Vector2(0.40, 0.92), Vector2(1.35, 1.45),
		Vector2(1.95, 2.45), Vector2(1.85, 3.70), Vector2(1.35, 5.10),
		Vector2(0.95, 6.35), Vector2(1.15, 7.45), Vector2(1.95, 8.35),
		Vector2(3.00, 8.90), Vector2(3.90, 10.60), Vector2(4.60, 13.40),
		Vector2(5.10, 17.00),
	])


## The land slab: the shoreline, then round the inland edges.
func _coast() -> PackedVector2Array:
	var pts := _shore()
	# The inland edge runs well outside the frame: a visible edge turns the
	# country into a tabletop prop.
	pts.append(Vector2(26.0, 17.00))
	pts.append(Vector2(26.0, -20.0))
	pts.append(Vector2(-22.0, -20.0))
	pts.append(Vector2(-22.0, 1.05))
	return pts


func _build_land() -> void:
	var land := MeshInstance3D.new()
	land.name = "Land"
	land.mesh = _slab(_coast(), 0.9)
	# Flat, not the weathered sand shader: at map scale that shader's noise is
	# metres across and the country ends up in camouflage.
	var land_mat := StandardMaterial3D.new()
	land_mat.albedo_color = Color(0.352, 0.288, 0.198)
	land_mat.roughness = 0.94
	land_mat.metallic = 0.0
	land.material_override = land_mat
	add_child(land)

	# A thin line of salt and surf along the waterline, so the coast reads as
	# an edge rather than as where one flat colour stops.
	var surf := MaterialLab.emissive(Color(0.80, 0.85, 0.80), 0.55)
	var coast := _shore()
	for i in coast.size() - 1:
		var a := coast[i]
		var b := coast[i + 1]
		var seg := MeshInstance3D.new()
		seg.name = "Surf%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3((b - a).length(), 0.02, 0.075)
		seg.mesh = bm
		seg.material_override = surf
		seg.position = Vector3((a.x + b.x) * 0.5, 0.452, -(a.y + b.y) * 0.5)
		seg.rotation.y = atan2(b.y - a.y, b.x - a.x)
		add_child(seg)


## A flat slab from a map-space polygon: the points are read as (east, north)
## and laid into XZ with the top face up. Built here rather than by rotating an
## extrusion, because which way a rotated extrusion ends up facing depends on
## the winding the triangulator happened to return, and a map lit from
## underneath renders black.
static func _slab(points: PackedVector2Array, thickness: float) -> ArrayMesh:
	var idx := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := thickness * 0.5
	var n := points.size()

	# Both faces, wound from the triangulation and then forced: the top face is
	# emitted in whichever order makes its normal point up.
	for face in 2:
		var y := top if face == 0 else -top
		var normal := Vector3(0, 1, 0) if face == 0 else Vector3(0, -1, 0)
		var i := 0
		while i < idx.size():
			var tri := [idx[i], idx[i + 1], idx[i + 2]]
			var p0: Vector2 = points[tri[0]]
			var p1: Vector2 = points[tri[1]]
			var p2: Vector2 = points[tri[2]]
			# Signed area in map space; positive is counter-clockwise, which
			# becomes clockwise seen from above once north maps to -z.
			var area := (p1 - p0).cross(p2 - p0)
			if (area > 0.0) == (face == 0):
				tri.reverse()
			for k: int in tri:
				var p: Vector2 = points[k]
				st.set_normal(normal)
				st.set_uv(Vector2(p.x, -p.y) * 0.25)
				st.add_vertex(Vector3(p.x, y, -p.y))
			i += 3

	for i in n:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % n]
		var edge := Vector3(b.x - a.x, 0.0, -(b.y - a.y)).normalized()
		var nrm := Vector3(-edge.z, 0.0, edge.x)
		var quad := [
			Vector3(a.x, top, -a.y), Vector3(b.x, top, -b.y),
			Vector3(b.x, -top, -b.y), Vector3(a.x, top, -a.y),
			Vector3(b.x, -top, -b.y), Vector3(a.x, -top, -a.y),
		]
		for v: Vector3 in quad:
			st.set_normal(nrm)
			st.set_uv(Vector2(v.x, v.y) * 0.25)
			st.add_vertex(v)
	return st.commit()


## Patches of ground colour. The country is not one flat orange: there is pale
## sabkha behind Brega and the first green of the Jebel above Benghazi.
##
## They are soft-edged on purpose. A polygon of a second colour laid on a map
## reads as a sticker however irregular you make its outline; what sells it is
## the edge going away, so each patch is a quad with a radial alpha falloff and
## the outline never exists.
func _build_ground_patches() -> void:
	# centre, size, rotation, colour
	var patches := [
		[Vector2(-2.60, -0.70), Vector2(7.40, 4.20), 0.18, Color(0.62, 0.58, 0.49)],
		[Vector2(1.10, -1.60), Vector2(5.00, 3.20), -0.30, Color(0.60, 0.55, 0.45)],
		[Vector2(-5.80, 0.10), Vector2(4.60, 2.60), 0.10, Color(0.58, 0.54, 0.46)],
		[Vector2(5.20, 6.40), Vector2(7.60, 6.20), 0.24, Color(0.26, 0.27, 0.17)],
		[Vector2(7.40, 2.20), Vector2(6.40, 5.00), -0.20, Color(0.28, 0.28, 0.19)],
		[Vector2(3.40, 3.10), Vector2(4.20, 3.60), 0.40, Color(0.31, 0.29, 0.20)],
	]
	for i in patches.size():
		var at: Vector2 = patches[i][0]
		var size: Vector2 = patches[i][1]
		var mi := MeshInstance3D.new()
		mi.name = "Patch%d" % i
		var quad := QuadMesh.new()
		quad.size = size
		mi.mesh = quad
		mi.material_override = _patch_material(patches[i][3])
		mi.position = Vector3(at.x, 0.452 + i * 0.004, -at.y)
		mi.rotation = Vector3(-PI * 0.5, patches[i][2], 0.0)
		add_child(mi)


## A radial alpha falloff, generated rather than authored, so terrain blending
## costs one gradient instead of a texture in the repository.
static func _patch_material(tint: Color) -> StandardMaterial3D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.92))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.55, Color(1, 1, 1, 0.66))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128

	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.98
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m


func _build_road() -> void:
	var mat := MaterialLab.asphalt(Color(0.115, 0.108, 0.105))
	var route: Array[Vector3] = []
	for e: World.Entry in entries:
		route.append(node_pos(e.chain_id))
	for i in route.size() - 1:
		var a: Vector3 = route[i]
		var b: Vector3 = route[i + 1]
		var seg := MeshInstance3D.new()
		seg.name = "Road%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(a.distance_to(b), 0.05, 0.135)
		seg.mesh = bm
		seg.material_override = mat
		seg.position = (a + b) * 0.5 + Vector3(0.0, 0.47, 0.0)
		seg.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		add_child(seg)


func _build_pins() -> void:
	for i in entries.size():
		var e: World.Entry = entries[i]
		var pin := Node3D.new()
		pin.name = "Pin_" + e.chain_id
		pin.position = node_pos(e.chain_id) + Vector3(0.0, 0.45, 0.0)
		add_child(pin)
		_pins.append(pin)

		var open := i < _unlocked and e.built()
		var metal: Material = ChainForge.trophy_gold() if Gx.chains.has(e.chain_id) \
			else ChainForge.ghost_metal()

		# The post, so the marker is standing on the map rather than floating.
		var post := MeshInstance3D.new()
		post.name = "Post"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.030
		cyl.height = 0.72
		cyl.radial_segments = 10
		post.mesh = cyl
		post.material_override = MaterialLab.rusted_metal(Color(0.30, 0.20, 0.14), 0.8)
		post.position = Vector3(0.0, 0.36, 0.0)
		pin.add_child(post)

		var head := Node3D.new()
		head.name = "Head"
		head.position = Vector3(0.0, 0.88, 0.0)
		pin.add_child(head)
		var med := ChainForge.medallion(e.chain_id, 0.58, metal,
			Gx.chains.has(e.chain_id))
		head.add_child(med)

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
		var label := PropKit.sign(self, e.short_ar,
			node_pos(e.chain_id) + Vector3(0.62, 0.47, 0.30), 0.26,
			MaterialLab.emissive(Color(1.0, 0.94, 0.84), 0.55),
			PropKit.FONT_KUFI, 0.008)
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 40.0
	_camera.near = 0.2
	_camera.far = 220.0
	add_child(_camera)
	_camera.current = true


# --- Drive ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_slide = lerpf(_slide, float(selected), 1.0 - exp(-8.0 * delta))

	var centre := Vector3(0.9, 0.0, -2.7)
	var focus: Vector3 = centre.lerp(_focus_point(), 0.45)
	# Held at a table angle, drifting slowly so the map is never a still image.
	var orbit := 0.30 + sin(_t * 0.09) * 0.045
	var height := 10.9
	var back := 9.8
	_camera.position = focus + Vector3(sin(orbit) * back, height, cos(orbit) * back)
	_camera.look_at(focus + Vector3(0.0, 0.25, 0.0), Vector3.UP)

	for i in _pins.size():
		var f := 1.0 - clampf(absf(_slide - i), 0.0, 1.0)
		var ease := f * f * (3.0 - 2.0 * f)
		var head := _pins[i].get_node("Head") as Node3D
		head.position.y = 0.88 + ease * 0.30 + sin(_t * 1.3 + i) * 0.015
		head.rotation.y = _camera.rotation.y + sin(_t * 0.5 + i) * 0.12 * (1.0 - ease)
		_lamps[i].light_energy = lerpf(1.0, 4.2, ease)


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
	elif event.is_action_pressed("jump") or event.is_action_pressed("attack"):
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
