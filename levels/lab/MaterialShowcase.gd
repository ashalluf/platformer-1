extends Node3D
## Material test chart — every preset in MaterialLab, on one screen.
##
## A sphere for curvature and a chamfered block for the flat planes and hard
## edges the real levels are actually made of, under one fixed key. This is how
## a material gets signed off before it reaches a level: if it does not read
## here, at this size, against this neutral wall, it will not read in Brega.
##
## The chart is the whole library on purpose. A preset that exists but is not
## on the chart is a preset nobody has looked at, and the library grew by
## fourteen presets in one pass — metals moved to physically correct 0.0/1.0,
## and that is exactly the kind of change that has to be eyeballed, not
## reasoned about.

const COLUMNS := 7
const CELL_X := 3.05
const CELL_Y := 3.70


func _ready() -> void:
	var we := LightingRig.build(self, _mood())
	# A polished metal is a mirror, and a mirror in a room with nothing in it
	# renders black — which is exactly what gold and chrome did on the first
	# chart. They are not broken; they had nothing to reflect. A real sky gives
	# every metal here an environment, and judging a metal without one is
	# judging the absence of one.
	SkyForge.apply(we.environment, "studio")
	_build_chart()
	_build_camera()


func _mood() -> LightingRig.Mood:
	var m := LightingRig.neutral_studio()
	# A chart is not a level: the key sits near the exposure reference (a 1.0
	# key puts a white surface at linear 1.0) so the values printed here are
	# the values a level author can trust when they reuse the preset.
	m.sun_energy = 1.5
	m.sun_angles = Vector2(-34.0, 28.0)
	m.fill_energy = 0.45
	m.rim_energy = 1.4
	m.fog_density = 0.0008
	m.sky_top = Color(0.13, 0.22, 0.42)
	m.sky_horizon = Color(0.66, 0.68, 0.70)
	return m


## Everything MaterialLab offers, in family order: mineral, then timber and
## ceramic, then metal, then cloth, then the transparent and the fantastical.
func _entries() -> Array:
	return [
		["concrete", MaterialLab.concrete()],
		["plaster", MaterialLab.plaster()],
		["limewash", MaterialLab.limewash()],
		["salt masonry", MaterialLab.salt_masonry()],
		["wet concrete", MaterialLab.wet_concrete()],
		["asphalt", MaterialLab.asphalt()],
		["bitumen", MaterialLab.bitumen()],

		["sand", MaterialLab.sand()],
		["packed earth", MaterialLab.packed_earth()],
		["terracotta", MaterialLab.terracotta()],
		["ceramic tile", MaterialLab.ceramic_tile()],
		["painted wood", MaterialLab.painted_wood()],
		["canvas", MaterialLab.canvas()],
		["sacking", MaterialLab.sacking()],

		["rusted", MaterialLab.rusted_metal()],
		["painted metal", MaterialLab.painted_metal()],
		["corrugated", MaterialLab.corrugated()],
		["galvanised", MaterialLab.galvanised()],
		["brushed alu", MaterialLab.brushed_aluminium()],
		["auto paint", MaterialLab.auto_paint()],
		["chrome", MaterialLab.chrome()],

		["gold", MaterialLab.gold()],
		["cloth", MaterialLab.cloth()],
		["skin", MaterialLab.skin()],
		["glass", MaterialLab.glass()],
		["dusty glass", MaterialLab.dusty_glass()],
		["ice", MaterialLab.ice()],
		["emissive", MaterialLab.emissive(Color(1.0, 0.55, 0.18), 1.6)],
	]


func _build_chart() -> void:
	var entries := _entries()
	var rows := int(ceil(float(entries.size()) / float(COLUMNS)))
	var x0 := -(COLUMNS - 1) * CELL_X * 0.5
	var y0 := (rows - 1) * CELL_Y * 0.5

	var sphere := SphereMesh.new()
	sphere.radius = 0.86
	sphere.height = 1.72
	sphere.radial_segments = 48
	sphere.rings = 24
	var box := LevelKit.chamfer_mesh(Vector3(1.9, 1.5, 1.9))

	for i in entries.size():
		var label: String = entries[i][0]
		var mat: Material = entries[i][1]
		var x := x0 + (i % COLUMNS) * CELL_X
		var y := y0 - float(i / COLUMNS) * CELL_Y

		var s := MeshInstance3D.new()
		s.name = "Sphere_%d" % i
		s.mesh = sphere
		s.material_override = mat
		s.position = Vector3(x, y + 0.98, 0.0)
		add_child(s)

		var b := MeshInstance3D.new()
		b.name = "Box_%d" % i
		b.mesh = box
		b.material_override = mat
		b.position = Vector3(x, y - 0.62, 0.0)
		# Turned off axis so one face takes the key, one takes the fill, and the
		# vertical edge between them is where a chamfer either works or doesn't.
		b.rotation_degrees = Vector3(0.0, 24.0, 0.0)
		add_child(b)

		var l := Label3D.new()
		l.name = "Label_%d" % i
		l.text = label
		l.font_size = 64
		l.pixel_size = 0.0042
		l.modulate = Color(0.92, 0.90, 0.86)
		l.outline_size = 14
		l.outline_modulate = Color(0.04, 0.04, 0.05, 0.85)
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.shaded = false
		l.position = Vector3(x, y - 1.50, 0.9)
		add_child(l)

	# Neutral backwall. Deliberately a flat grey, not a plaster preset: the
	# chart must not judge a material against another material.
	var wall := LevelKit.chamfer_mesh(Vector3(COLUMNS * CELL_X + 6.0, rows * CELL_Y + 6.0, 0.6))
	var wl := MeshInstance3D.new()
	wl.name = "BackWall"
	wl.mesh = wall
	wl.material_override = LevelKit.material(Color(0.24, 0.24, 0.25), 0.92)
	wl.position = Vector3(0.0, 0.0, -3.2)
	add_child(wl)


func _build_camera() -> void:
	var entries := _entries().size()
	var rows := int(ceil(float(entries) / float(COLUMNS)))
	var cam := Camera3D.new()
	cam.name = "ChartCamera"
	cam.fov = 38.0

	# Frame by whichever dimension binds. Solving for width alone cropped the
	# top and bottom rows clean off the frame, which on a chart is not a
	# composition choice — it is four materials nobody signed off.
	var half_w := COLUMNS * CELL_X * 0.5 + 0.7
	var half_h := rows * CELL_Y * 0.5 + 0.4
	var vfov := deg_to_rad(cam.fov) * 0.5
	var hfov := atan(tan(vfov) * 16.0 / 9.0)
	cam.position = Vector3(0.0, 0.0, maxf(half_w / tan(hfov), half_h / tan(vfov)))
	add_child(cam)
	cam.current = true
