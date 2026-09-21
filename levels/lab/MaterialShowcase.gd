extends Node3D
## Material test chart.
##
## Two rows of the same geometry — a sphere for curvature, a block for the flat
## planes and hard edges the real levels are made of — under one fixed lighting
## setup. This is how a material gets signed off before it reaches a level.

const COLUMNS := 7


func _ready() -> void:
	LightingRig.build(self, _mood())
	_build_chart()
	_build_camera()


func _mood() -> LightingRig.Mood:
	var m := LightingRig.neutral_studio()
	m.sun_energy = 3.0
	m.sun_angles = Vector2(-34.0, 28.0)
	m.fill_energy = 0.45
	m.rim_energy = 2.2
	m.fog_density = 0.0012
	m.sky_top = Color(0.13, 0.22, 0.42)
	m.sky_horizon = Color(0.66, 0.68, 0.70)
	return m


func _build_chart() -> void:
	var entries := [
		["concrete", MaterialLab.concrete()],
		["plaster", MaterialLab.plaster()],
		["rusted", MaterialLab.rusted_metal()],
		["painted", MaterialLab.painted_metal()],
		["corrugated", MaterialLab.corrugated()],
		["sand", MaterialLab.sand()],
		["asphalt", MaterialLab.asphalt()],
	]

	var spacing := 3.0
	var x0 := -(entries.size() - 1) * spacing * 0.5

	for i in entries.size():
		var label: String = entries[i][0]
		var mat: Material = entries[i][1]
		var x := x0 + i * spacing

		var sphere := SphereMesh.new()
		sphere.radius = 1.05
		sphere.height = 2.1
		sphere.radial_segments = 48
		sphere.rings = 24
		var s := MeshInstance3D.new()
		s.name = "Sphere_" + label
		s.mesh = sphere
		s.material_override = mat
		s.position = Vector3(x, 3.4, 0.0)
		add_child(s)

		var box := LevelKit.chamfer_mesh(Vector3(2.1, 2.1, 2.1))
		var b := MeshInstance3D.new()
		b.name = "Box_" + label
		b.mesh = box
		b.material_override = mat
		b.position = Vector3(x, 1.05, 0.0)
		b.rotation_degrees = Vector3(0.0, 22.0, 0.0)
		add_child(b)

	# Ground plane so the weathering has a datum to run up from.
	var ground := LevelKit.chamfer_mesh(Vector3(40.0, 0.4, 14.0))
	var g := MeshInstance3D.new()
	g.name = "Ground"
	g.mesh = ground
	g.material_override = MaterialLab.sand(Color(0.60, 0.53, 0.40))
	g.position = Vector3(0.0, -0.2, 0.0)
	add_child(g)

	# Backwall catches the rim light and gives the spheres something to sit against.
	var wall := LevelKit.chamfer_mesh(Vector3(40.0, 16.0, 0.6))
	var wl := MeshInstance3D.new()
	wl.name = "BackWall"
	wl.mesh = wall
	wl.material_override = MaterialLab.plaster(Color(0.72, 0.66, 0.55))
	wl.position = Vector3(0.0, 6.0, -6.0)
	add_child(wl)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "ChartCamera"
	cam.fov = 38.0
	cam.position = Vector3(0.0, 3.2, 17.0)
	cam.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
	add_child(cam)
	cam.current = true
