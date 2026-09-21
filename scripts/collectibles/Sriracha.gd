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
	# survive being 12 px tall.
	var b := MeshForge.Builder.new()
	b.begin()
	b.loft([
		MeshForge.ring(Vector3(0, 0.000, 0), 0.056, 0.056, bones, weights, 3.0),
		MeshForge.ring(Vector3(0, 0.020, 0), 0.068, 0.068, bones, weights, 2.8),
		MeshForge.ring(Vector3(0, 0.140, 0), 0.070, 0.070, bones, weights, 2.6),
		MeshForge.ring(Vector3(0, 0.190, 0), 0.066, 0.066, bones, weights, 2.4),
		MeshForge.ring(Vector3(0, 0.225, 0), 0.040, 0.040, bones, weights, 2.2),
		MeshForge.ring(Vector3(0, 0.250, 0), 0.030, 0.030, bones, weights, 2.2),
	], 14, true, false)
	var body_mesh := b.commit()

	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	_mesh.mesh = body_mesh
	_mesh.material_override = sauce
	add_child(_mesh)

	# Glass shell, slightly proud of the sauce, so the sauce glows through it.
	var shell := MeshInstance3D.new()
	shell.name = "Glass"
	shell.mesh = body_mesh
	shell.material_override = glass
	shell.scale = Vector3(1.10, 1.02, 1.10)
	_mesh.add_child(shell)

	var neck := CylinderMesh.new()
	neck.top_radius = 0.026
	neck.bottom_radius = 0.030
	neck.height = 0.055
	neck.radial_segments = 12
	var n := MeshInstance3D.new()
	n.name = "Neck"
	n.mesh = neck
	n.material_override = glass
	n.position = Vector3(0, 0.272, 0)
	_mesh.add_child(n)

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.026
	cap_mesh.bottom_radius = 0.034
	cap_mesh.height = 0.072
	cap_mesh.radial_segments = 14
	var c := MeshInstance3D.new()
	c.name = "Cap"
	c.mesh = cap_mesh
	c.material_override = cap
	c.position = Vector3(0, 0.320, 0)
	_mesh.add_child(c)

	# Paper band with an abstract chilli mark — a curve and a stem, nothing that
	# could be mistaken for anyone's trademark.
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.0715
	band_mesh.bottom_radius = 0.0715
	band_mesh.height = 0.105
	band_mesh.radial_segments = 16
	var bd := MeshInstance3D.new()
	bd.name = "Band"
	bd.mesh = band_mesh
	bd.material_override = band
	bd.position = Vector3(0, 0.098, 0)
	_mesh.add_child(bd)

	var chilli := TorusMesh.new()
	chilli.inner_radius = 0.016
	chilli.outer_radius = 0.030
	chilli.rings = 10
	chilli.ring_segments = 5
	var ch := MeshInstance3D.new()
	ch.name = "Mark"
	ch.mesh = chilli
	ch.material_override = mark
	ch.position = Vector3(0, 0.098, 0.070)
	ch.rotation_degrees = Vector3(90, 0, 24)
	ch.scale = Vector3(1.0, 1.0, 0.55)
	_mesh.add_child(ch)

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
