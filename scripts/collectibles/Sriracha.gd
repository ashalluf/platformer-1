class_name Sriracha extends Collectible
## The Sriracha bottle — the game's signature collectible.
##
## Original design: no real brand's label, logo or bird. A squat pressed-glass
## bottle with a high shoulder, a ribbed cap, and a paper band carrying an
## abstract chilli mark. The sauce inside is emissive, so a trail of these reads
## as a line of light against a pastel world even at 15% of screen height —
## which is the whole reason the collectible works as a guidance device.

enum Variant { NORMAL, ICE, ICED_OUT }

@export var variant: Variant = Variant.NORMAL
@export var spin_speed := 1.6
@export var bob_height := 0.055
@export var bob_speed := 2.2
@export var glow_energy := 3.2

const HEIGHT := 0.34

var _t := 0.0
var _mesh: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	burst_color = palette()["sauce"]
	burst_count = 10 if variant == Variant.NORMAL else 26
	hitstop = 0.0 if variant == Variant.NORMAL else 0.05
	shake = 0.0 if variant == Variant.NORMAL else 0.28
	magnet_radius = 2.1
	super._ready()
	# Desync bob/spin by world position, so a trail never pulses in lockstep.
	_t = fposmod(global_position.x * 0.7 + global_position.y * 0.3, TAU)


func palette() -> Dictionary:
	match variant:
		Variant.ICE:
			# Deep cyan with a dark cap and band: on an ice level everything
			# else is white, so the collectible has to be the dark thing.
			return {"sauce": Color(0.06, 0.62, 0.92), "cap": Color(0.07, 0.16, 0.28),
				"band": Color(0.12, 0.26, 0.42), "mark": Color(0.55, 0.92, 1.0),
				"glass": Color(0.30, 0.70, 0.95)}
		Variant.ICED_OUT:
			return {"sauce": Color(1.0, 0.96, 0.98), "cap": Color(0.92, 0.94, 1.0),
				"band": Color(1.0, 1.0, 1.0), "mark": Color(0.60, 0.82, 1.0),
				"glass": Color(0.95, 0.98, 1.0)}
		_:
			return {"sauce": Color(0.86, 0.10, 0.06), "cap": Color(0.14, 0.42, 0.20),
				"band": Color(0.96, 0.93, 0.86), "mark": Color(0.72, 0.10, 0.08),
				"glass": Color(0.90, 0.40, 0.28)}


func _build_visual() -> Node3D:
	_build()
	return _mesh


func _on_collected(_by: Node3D) -> void:
	match variant:
		Variant.ICE:
			Gx.add_ice_sriracha(1)
		Variant.ICED_OUT:
			Gx.find_iced_out()
			var scene_path := ""
			var stage := get_tree().current_scene
			if stage and stage.scene_file_path != "":
				scene_path = stage.scene_file_path
			var at := global_position
			if _by is Node3D:
				at = (_by as Node3D).global_position
			SceneFlow.warp_to_bonus(scene_path, at, Gx.current_level_id)
		_:
			Gx.add_sriracha(1)
	Audio.play_collect(global_position)


func _build() -> void:
	var p := palette()

	var sauce := MaterialLab.emissive(p["sauce"],
		glow_energy * (1.6 if variant == Variant.ICE else 1.0))
	sauce.roughness = 0.22
	var cap := MaterialLab.cloth(p["cap"], 0.38)
	var band := MaterialLab.cloth(p["band"], 0.85)
	var mark := MaterialLab.emissive(p["mark"], 0.6)
	var glass := MaterialLab.glass(Color(p["glass"].r, p["glass"].g, p["glass"].b, 0.34))

	var bones: Array = [0]
	var weights: Array = [1.0]

	# Body: squat, high-shouldered, with a pinched neck. The silhouette has to
	# survive being 12 px tall, so the shoulder is the shape that carries it —
	# a straight-sided bottle at that size is a pill.
	#
	# More rings than the read strictly needs. This is the object the player
	# looks at more than any other in the game, and the cost of twelve extra
	# rings on a mesh that is instanced a thousand times is still nothing
	# compared to the cost of it looking moulded.
	var b := MeshForge.Builder.new()
	b.begin()
	b.loft([
		MeshForge.ring(Vector3(0, 0.000, 0), 0.050, 0.050, bones, weights, 3.4),
		MeshForge.ring(Vector3(0, 0.010, 0), 0.062, 0.062, bones, weights, 3.2),
		MeshForge.ring(Vector3(0, 0.026, 0), 0.069, 0.069, bones, weights, 2.9),
		MeshForge.ring(Vector3(0, 0.060, 0), 0.071, 0.071, bones, weights, 2.7),
		MeshForge.ring(Vector3(0, 0.110, 0), 0.071, 0.071, bones, weights, 2.6),
		MeshForge.ring(Vector3(0, 0.152, 0), 0.070, 0.070, bones, weights, 2.6),
		MeshForge.ring(Vector3(0, 0.182, 0), 0.066, 0.066, bones, weights, 2.5),
		MeshForge.ring(Vector3(0, 0.206, 0), 0.058, 0.058, bones, weights, 2.4),
		MeshForge.ring(Vector3(0, 0.224, 0), 0.046, 0.046, bones, weights, 2.3),
		MeshForge.ring(Vector3(0, 0.238, 0), 0.036, 0.036, bones, weights, 2.2),
		MeshForge.ring(Vector3(0, 0.250, 0), 0.031, 0.031, bones, weights, 2.2),
	], 18, true, false)
	var body_mesh := b.commit()

	# The sauce is a SEPARATE, shorter loft. A bottle filled to the cap reads as
	# a solid lump of plastic; the air gap and the line where the liquid stops
	# are most of what says "there is something in this".
	var l := MeshForge.Builder.new()
	l.begin()
	l.loft([
		MeshForge.ring(Vector3(0, 0.004, 0), 0.046, 0.046, bones, weights, 3.4),
		MeshForge.ring(Vector3(0, 0.024, 0), 0.064, 0.064, bones, weights, 2.9),
		MeshForge.ring(Vector3(0, 0.110, 0), 0.066, 0.066, bones, weights, 2.6),
		MeshForge.ring(Vector3(0, 0.178, 0), 0.062, 0.062, bones, weights, 2.5),
		MeshForge.ring(Vector3(0, 0.196, 0), 0.058, 0.058, bones, weights, 2.4),
	], 18, true, true)
	var liquid_mesh := l.commit()

	_mesh = MeshInstance3D.new()
	_mesh.name = "Sauce"
	_mesh.mesh = liquid_mesh
	_mesh.material_override = sauce
	add_child(_mesh)

	# Glass shell over the lot. Proud of the sauce so the sauce glows through
	# it, and it carries the bottle's real silhouette.
	var shell := MeshInstance3D.new()
	shell.name = "Glass"
	shell.mesh = body_mesh
	shell.material_override = glass
	_mesh.add_child(shell)

	# Moulded base ring: a real pressed bottle sits on a rim, not on its belly,
	# and that rim is the one thing that catches light from below.
	var base_ring := TorusMesh.new()
	base_ring.inner_radius = 0.040
	base_ring.outer_radius = 0.052
	base_ring.rings = 18
	base_ring.ring_segments = 6
	var br := MeshInstance3D.new()
	br.name = "BaseRim"
	br.mesh = base_ring
	br.material_override = glass
	br.position = Vector3(0, 0.006, 0)
	_mesh.add_child(br)

	# Neck with a thread. Four shallow torus turns is cheaper than a helix and
	# at this size nobody can tell the difference.
	var neck := CylinderMesh.new()
	neck.top_radius = 0.026
	neck.bottom_radius = 0.031
	neck.height = 0.058
	neck.radial_segments = 14
	var n := MeshInstance3D.new()
	n.name = "Neck"
	n.mesh = neck
	n.material_override = glass
	n.position = Vector3(0, 0.276, 0)
	_mesh.add_child(n)

	for i in 3:
		var thread := TorusMesh.new()
		thread.inner_radius = 0.026
		thread.outer_radius = 0.031
		thread.rings = 14
		thread.ring_segments = 5
		var tm := MeshInstance3D.new()
		tm.name = "Thread%d" % i
		tm.mesh = thread
		tm.material_override = glass
		tm.position = Vector3(0, 0.262 + i * 0.013, 0)
		_mesh.add_child(tm)

	# The spout insert under the cap: a small warm dot that reads even when the
	# bottle is a dozen pixels tall, because it is the only saturated thing
	# above the shoulder.
	var spout := CylinderMesh.new()
	spout.top_radius = 0.010
	spout.bottom_radius = 0.017
	spout.height = 0.022
	spout.radial_segments = 10
	var sp := MeshInstance3D.new()
	sp.name = "Spout"
	sp.mesh = spout
	sp.material_override = sauce
	sp.position = Vector3(0, 0.306, 0)
	_mesh.add_child(sp)

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.030
	cap_mesh.bottom_radius = 0.035
	cap_mesh.height = 0.070
	cap_mesh.radial_segments = 16
	var c := MeshInstance3D.new()
	c.name = "Cap"
	c.mesh = cap_mesh
	c.material_override = cap
	c.position = Vector3(0, 0.322, 0)
	_mesh.add_child(c)

	# Knurling. Ten ribs round a cap is the detail that makes a cap a cap, and
	# a MultiMesh means it costs one draw call.
	var rib := LevelKit.chamfer_mesh(Vector3(0.008, 0.052, 0.010))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rib
	mm.instance_count = 10
	for i in 10:
		var a := TAU * float(i) / 10.0
		mm.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, -a),
			Vector3(cos(a) * 0.033, 0.322, sin(a) * 0.033)))
	var knurl := MultiMeshInstance3D.new()
	knurl.name = "Knurl"
	knurl.multimesh = mm
	knurl.material_override = cap
	_mesh.add_child(knurl)

	# A flat top disc so the cap is closed rather than an open tube.
	var cap_top := CylinderMesh.new()
	cap_top.top_radius = 0.030
	cap_top.bottom_radius = 0.030
	cap_top.height = 0.008
	cap_top.radial_segments = 16
	var ct := MeshInstance3D.new()
	ct.name = "CapTop"
	ct.mesh = cap_top
	ct.material_override = cap
	ct.position = Vector3(0, 0.358, 0)
	_mesh.add_child(ct)

	# Paper band with an abstract chilli mark — a curve and a stem, nothing that
	# could be mistaken for anyone's trademark.
	#
	# It is modelled as a wrapped paper label rather than painted on the glass:
	# a band standing 1 mm proud with a lip top and bottom. That 1 mm is the
	# difference between a sticker and a bottle, and it costs two cylinders.
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.0725
	band_mesh.bottom_radius = 0.0725
	band_mesh.height = 0.112
	band_mesh.radial_segments = 18
	var bd := MeshInstance3D.new()
	bd.name = "Band"
	bd.mesh = band_mesh
	bd.material_override = band
	bd.position = Vector3(0, 0.098, 0)
	_mesh.add_child(bd)

	for i in 2:
		var lip := TorusMesh.new()
		lip.inner_radius = 0.0718
		lip.outer_radius = 0.0742
		lip.rings = 18
		lip.ring_segments = 5
		var lp := MeshInstance3D.new()
		lp.name = "BandLip%d" % i
		lp.mesh = lip
		lp.material_override = band
		lp.position = Vector3(0, 0.042 + i * 0.112, 0)
		_mesh.add_child(lp)

	# A printed rule above and below the mark. At twelve pixels tall this is
	# two dark lines and that is exactly what a label reads as from across a
	# yard — the eye wants the horizontal, not the artwork.
	for i in 2:
		var rule := TorusMesh.new()
		rule.inner_radius = 0.0726
		rule.outer_radius = 0.0736
		rule.rings = 18
		rule.ring_segments = 4
		var rl := MeshInstance3D.new()
		rl.name = "BandRule%d" % i
		rl.mesh = rule
		rl.material_override = mark
		rl.position = Vector3(0, 0.062 + i * 0.072, 0)
		_mesh.add_child(rl)

	# The mark itself: a chilli as a tapered curve with a stem, built from a
	# short loft rather than a torus so it has a point at one end. A ring reads
	# as a doughnut; a chilli has to taper.
	var cb := MeshForge.Builder.new()
	cb.begin()
	var pod := []
	for i in 7:
		var t := float(i) / 6.0
		# The curve is the whole character of the shape.
		var ang := lerpf(-0.5, 1.5, t)
		var r := sin(t * PI) * 0.013 + 0.002
		pod.append(MeshForge.ring(
			Vector3(sin(ang) * 0.030, -cos(ang) * 0.030 + 0.030, 0.0),
			r, r * 0.6, bones, weights, 2.6))
	cb.loft(pod, 8, true, true)
	var ch := MeshInstance3D.new()
	ch.name = "Mark"
	ch.mesh = cb.commit()
	ch.material_override = mark
	ch.position = Vector3(0, 0.082, 0.0735)
	ch.rotation_degrees = Vector3(90, 0, 0)
	_mesh.add_child(ch)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.0035
	stem.bottom_radius = 0.005
	stem.height = 0.018
	stem.radial_segments = 6
	var st := MeshInstance3D.new()
	st.name = "MarkStem"
	st.mesh = stem
	st.material_override = cap
	st.position = Vector3(-0.014, 0.112, 0.0735)
	st.rotation_degrees = Vector3(90, 0, -38)
	_mesh.add_child(st)

	# A small light so the bottle writes into the volumetrics and lifts whatever
	# it is sitting on. This is what makes a trail read at distance.
	_light = OmniLight3D.new()
	_light.name = "Glow"
	# Warm amber rather than the sauce red: a saturated red omni sitting 160 mm
	# above a dark deck pools on it and reads as a stain, which is the last
	# thing this game should be putting on the floor.
	_light.light_color = Color(1.0, 0.62, 0.30) if variant == Variant.NORMAL \
		else Color(0.55, 0.86, 1.0)
	_light.light_energy = 0.7 if variant == Variant.NORMAL else 1.2
	_light.omni_range = 1.5
	# The level went a stop and a half darker in the colour-script pass, so
	# every accent light in it is now relatively brighter. This was blowing a
	# glowing ball around each bottle.
	_light.light_volumetric_fog_energy = 0.7
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.16, 0)
	add_child(_light)


func _process(delta: float) -> void:
	if _mesh == null:
		return
	_t += delta
	_mesh.rotation.y = _t * spin_speed
	_mesh.position.y = sin(_t * bob_speed) * bob_height
	if _light:
		_light.light_energy = (0.55 if variant == Variant.NORMAL else 1.0) \
			* (0.88 + 0.12 * sin(_t * bob_speed * 2.0))
