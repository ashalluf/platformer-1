class_name TunaSandwich extends Collectible
## One extra life.
##
## A Libyan tuna sandwich: a split baguette, tuna, harissa, olives, a boiled
## egg slice. Placed as a reward for a risk, never on the path — that is a level
## design rule, enforced by where designers put it rather than by code.

const LENGTH := 0.42


func _ready() -> void:
	burst_color = Color(1.0, 0.72, 0.30)
	burst_count = 22
	hitstop = 0.045
	shake = 0.22
	magnet_radius = 2.3
	pop_scale = 1.7
	super._ready()


func _on_collected(_by: Node3D) -> void:
	Gx.add_life(1)
	Audio.play_2d("life", -4.0)


func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Sandwich"
	add_child(root)

	var crust := MaterialLab.cloth(Color(0.76, 0.55, 0.28), 0.62)
	var crumb := MaterialLab.cloth(Color(0.94, 0.88, 0.72), 0.80)
	var tuna := MaterialLab.cloth(Color(0.80, 0.56, 0.42), 0.75)
	var harissa := MaterialLab.emissive(Color(0.82, 0.16, 0.08), 1.1)
	var olive := MaterialLab.cloth(Color(0.24, 0.30, 0.16), 0.55)
	var egg := MaterialLab.cloth(Color(0.97, 0.95, 0.88), 0.70)

	# Bottom half of the baguette, cut side up.
	var b := MeshForge.Builder.new()
	b.begin()
	var rings := []
	var steps := 9
	for i in steps:
		var t := float(i) / float(steps - 1)
		# Fat in the middle, tapering to both ends — a baguette, not a tube.
		var fat := sin(PI * t)
		rings.append(MeshForge.ring(
			Vector3(0.0, -LENGTH * 0.5 + LENGTH * t, 0.0),
			0.055 + 0.030 * fat, 0.050 + 0.026 * fat, [0], [1.0], 2.6))
	b.loft(rings, 12, true, true)
	var loaf := MeshInstance3D.new()
	loaf.name = "Loaf"
	loaf.mesh = b.commit()
	loaf.material_override = crust
	loaf.rotation = Vector3(0.0, 0.0, PI * 0.5)
	root.add_child(loaf)

	var fill := MeshInstance3D.new()
	fill.name = "Filling"
	var fill_mesh := LevelKit.chamfer_mesh(Vector3(LENGTH * 0.86, 0.040, 0.086))
	fill.mesh = fill_mesh
	fill.material_override = tuna
	fill.position = Vector3(0.0, 0.040, 0.0)
	root.add_child(fill)

	var crumb_mesh := LevelKit.chamfer_mesh(Vector3(LENGTH * 0.90, 0.018, 0.072))
	var cr := MeshInstance3D.new()
	cr.name = "Crumb"
	cr.mesh = crumb_mesh
	cr.material_override = crumb
	cr.position = Vector3(0.0, 0.018, 0.0)
	root.add_child(cr)

	# Harissa stripe — the emissive line that makes it read at distance.
	var stripe := LevelKit.chamfer_mesh(Vector3(LENGTH * 0.80, 0.012, 0.030))
	var st := MeshInstance3D.new()
	st.name = "Harissa"
	st.mesh = stripe
	st.material_override = harissa
	st.position = Vector3(0.0, 0.062, 0.030)
	root.add_child(st)

	for i in 3:
		var o := SphereMesh.new()
		o.radius = 0.020
		o.height = 0.036
		o.radial_segments = 8
		o.rings = 4
		var om := MeshInstance3D.new()
		om.mesh = o
		om.material_override = olive
		om.position = Vector3(-0.11 + i * 0.11, 0.066, -0.016)
		root.add_child(om)

	var e := CylinderMesh.new()
	e.top_radius = 0.030
	e.bottom_radius = 0.030
	e.height = 0.012
	e.radial_segments = 12
	var em := MeshInstance3D.new()
	em.mesh = e
	em.material_override = egg
	em.position = Vector3(0.06, 0.070, 0.012)
	em.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(em)

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.74, 0.34)
	glow.light_energy = 1.1
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	root.add_child(glow)
	return root


func _process(delta: float) -> void:
	if _visual == null:
		return
	_visual.rotation.y += delta * 1.1
	_visual.position.y = sin(Time.get_ticks_msec() * 0.0021) * 0.05
