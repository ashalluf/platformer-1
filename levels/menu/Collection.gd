extends Node3D
## THE CHAINS — the collection screen.
##
## Five chains hang on a rail in a dark room, one per World 1 level. The ones
## you have earned are gold under a spotlight; the ones you have not are the
## same chain in cold dead metal, because an empty slot tells you nothing and a
## chain you can see but have not got tells you everything.
##
## Real geometry, not drawn icons: these are the trophies the whole game is
## about, and they get lit like it.

const SPACING := 2.30
const SPAN := 1.90

var entries: Array = []
var selected := 0
var _slots: Array[Node3D] = []
var _spots: Array[SpotLight3D] = []
var _overlay: CollectionOverlay
var _camera: Camera3D
var _t := 0.0
var _slide := 0.0


func _ready() -> void:
	entries = World.chain_slots()
	_apply_capture_override()
	_build_room()
	_build_chains()
	_build_camera()

	var layer := CanvasLayer.new()
	layer.name = "CollectionUI"
	add_child(layer)
	_overlay = CollectionOverlay.new()
	layer.add_child(_overlay)
	_overlay.set_entry(entries[selected], _earned(selected), _count())
	Music.set_intensity(0.15)


## Capture-only: `--chains=brega,ajdabiya` fills in progression so the screen
## can be signed off in a state a new save cannot reach.
func _apply_capture_override() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--chains="):
			continue
		for id: String in arg.substr(9).split(",", false):
			Gx.chains[id] = true


func _earned(i: int) -> bool:
	return Gx.chains.has((entries[i] as World.Entry).chain_id)


func _count() -> int:
	var n := 0
	for i in entries.size():
		if _earned(i):
			n += 1
	return n


# --- Build ------------------------------------------------------------------

func _build_room() -> void:
	var m := LightingRig.Mood.new()
	# A room, not a sky: the backdrop is nearly black and every bit of light in
	# frame is a lamp someone hung.
	# The sky is never seen — the back wall covers the whole frame — but it is
	# what the gold reflects, and a metal with nothing to reflect renders
	# black. So the sky is a warm studio grey and the room stays dark because
	# the wall is dark, not because the environment is.
	m.sky_top = Color(0.240, 0.205, 0.190)
	m.sky_horizon = Color(0.330, 0.255, 0.205)
	m.ground_horizon = Color(0.180, 0.140, 0.120)
	m.ground_bottom = Color(0.090, 0.072, 0.066)
	m.sky_energy = 1.15
	m.sun_energy = 0.0
	m.sun_disc_size = 0.0
	m.fill_energy = 0.22
	m.fill_color = Color(0.42, 0.50, 0.78)
	m.fill_angles = Vector2(-26.0, -52.0)
	m.rim_energy = 1.1
	m.rim_color = Color(1.0, 0.72, 0.40)
	m.rim_angles = Vector2(-8.0, 172.0)
	m.ambient_energy = 0.55
	m.volumetric_density = 0.006
	m.fog_color = Color(0.20, 0.14, 0.11)
	m.fog_density = 0.0
	m.fog_anisotropy = 0.80
	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.22
	m.white = 7.0
	m.glow_intensity = 0.42
	m.glow_hdr_threshold = 1.15
	m.adjustment_saturation = 1.10
	m.adjustment_contrast = 1.12
	LightingRig.build(self, m)

	# A probe so the gold has the room in it, not just the sky.
	var probe := ReflectionProbe.new()
	probe.name = "CaseProbe"
	probe.size = Vector3(28.0, 12.0, 14.0)
	probe.origin_offset = Vector3.ZERO
	probe.intensity = 1.0
	probe.max_distance = 40.0
	probe.position = Vector3(0.0, 1.2, -0.5)
	add_child(probe)

	# Back wall, far enough behind that the volumetrics have room to work.
	var wall := MeshInstance3D.new()
	wall.name = "BackWall"
	var box := BoxMesh.new()
	box.size = Vector3(48.0, 20.0, 0.4)
	wall.mesh = box
	wall.material_override = MaterialLab.plaster(Color(0.150, 0.128, 0.124), 1.0)
	wall.position = Vector3(0.0, 2.0, -7.0)
	add_child(wall)

	# Two washes on the back wall. Spots rather than omnis: an omni here also
	# lights the floor straight into the lens, and that pool lands exactly
	# where the caption goes.
	for i in 2:
		var wash := SpotLight3D.new()
		wash.name = "Wash%d" % i
		wash.light_color = Color(0.92, 0.55, 0.28)
		wash.light_energy = 9.0
		wash.spot_range = 9.0
		wash.spot_angle = 48.0
		wash.spot_attenuation = 0.9
		wash.shadow_enabled = false
		wash.light_volumetric_fog_energy = 0.8
		add_child(wash)
		var wx := -7.2 + 14.4 * i
		wash.look_at_from_position(Vector3(wx, 2.6, -3.4),
			Vector3(wx, 0.6, -6.8), Vector3.UP)

	# The rail the chains hang from, and its two hanging rods.
	var steel := MaterialLab.chrome(Color(0.16, 0.155, 0.16), 0.42)
	var rail := MeshInstance3D.new()
	rail.name = "Rail"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.055
	cyl.height = SPACING * entries.size() + 2.2
	cyl.radial_segments = 14
	rail.mesh = cyl
	rail.material_override = steel
	rail.rotation_degrees = Vector3(0, 0, 90)
	rail.position = Vector3(0.0, 2.05, 0.0)
	add_child(rail)

	# A plinth line under the chains so they are standing somewhere.
	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	var pb := BoxMesh.new()
	pb.size = Vector3(SPACING * entries.size() + 3.0, 0.5, 2.6)
	plinth.mesh = pb
	var plinth_mat := StandardMaterial3D.new()
	plinth_mat.albedo_color = Color(0.040, 0.036, 0.038)
	plinth_mat.roughness = 1.0
	plinth_mat.metallic = 0.0
	plinth.material_override = plinth_mat
	plinth.position = Vector3(0.0, -4.7, -0.9)
	add_child(plinth)


func _build_chains() -> void:
	for i in entries.size():
		var e: World.Entry = entries[i]
		var earned := _earned(i)
		var slot := Node3D.new()
		slot.name = "Slot%d" % i
		slot.position = Vector3(_slot_x(i), 1.95, 0.0)
		add_child(slot)
		_slots.append(slot)

		var spin := Node3D.new()
		spin.name = "Spin"
		slot.add_child(spin)
		spin.add_child(ChainForge.chain(e.chain_id, SPAN, earned))

		# One lamp per chain. Earned chains get a warm key; unearned get a
		# quarter of it in cold blue, so the row reads as progress at a glance.
		var spot := SpotLight3D.new()
		spot.name = "Key"
		spot.light_color = Color(1.0, 0.80, 0.50) if earned else Color(0.55, 0.66, 0.86)
		spot.light_energy = 16.0 if earned else 5.0
		spot.light_volumetric_fog_energy = 2.4 if earned else 0.5
		# Short on purpose: the cone has to die just past the medallion, or it
		# carries on and paints a hot pool on the floor under the caption.
		spot.spot_range = 6.9
		spot.spot_angle = 30.0
		spot.spot_attenuation = 1.1
		spot.shadow_enabled = earned
		slot.add_child(spot)
		# Aim after parenting: look_at works off the global transform, and a
		# node that is not in the tree yet does not have one. The lamp is a
		# child of the slot, so when the chain leans out of the row its light
		# leans with it.
		spot.look_at_from_position(Vector3(_slot_x(i) + 0.35, 5.6, 3.0),
			Vector3(_slot_x(i), 0.55, 0.0), Vector3.UP)

		_spots.append(spot)

		var back := OmniLight3D.new()
		back.name = "Back%d" % i
		back.light_color = Color(0.52, 0.64, 0.92)
		back.light_energy = 3.0
		back.omni_range = 5.0
		back.omni_attenuation = 1.3
		back.shadow_enabled = false
		back.position = Vector3(0.0, -0.85, -1.5)
		slot.add_child(back)


func _slot_x(i: int) -> float:
	return (float(i) - (entries.size() - 1) * 0.5) * SPACING


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 36.0
	_camera.near = 0.5
	_camera.far = 260.0
	# Far enough back that the whole case is in frame at once. A collection
	# screen that only shows you one slot is not a collection screen.
	_camera.position = Vector3(0.0, 0.62, 12.2)
	add_child(_camera)
	_camera.current = true


# --- Drive ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_slide = lerpf(_slide, float(selected), 1.0 - exp(-9.0 * delta))

	# The camera holds the whole row and only leans toward the selection, so
	# you never lose sight of what you have not got.
	var want_x := _slide_x() * 0.17
	_camera.position = Vector3(want_x, 0.62 + sin(_t * 0.33) * 0.05, 12.2)
	_camera.rotation.y = -want_x * 0.008

	for i in _slots.size():
		var slot := _slots[i]
		var focus := 1.0 - clampf(absf(_slide - i), 0.0, 1.0)
		# The selected chain leans out of the row and turns to show the emblem.
		var ease := focus * focus * (3.0 - 2.0 * focus)
		slot.position.z = lerpf(0.0, 1.95, ease)
		slot.position.y = 1.95 + ease * 0.16
		var spin := slot.get_node("Spin") as Node3D
		spin.rotation.y = sin(_t * 0.55 + i) * (0.10 + ease * 0.22)
		_spots[i].light_energy = lerpf(
			15.0 if _earned(i) else 7.0, 30.0 if _earned(i) else 15.0, ease)


func _slide_x() -> float:
	var lo := floori(_slide)
	var hi := mini(lo + 1, entries.size() - 1)
	return lerpf(_slot_x(lo), _slot_x(hi), _slide - lo)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left", true):
		_step(-1)
	elif event.is_action_pressed("move_right", true):
		_step(1)
	elif event.is_action_pressed("pause") or event.is_action_pressed("dash"):
		Audio.play_2d("ui", -4.0, 0.85, "UI")
		SceneFlow.change_scene("res://levels/menu/TitleScreen.tscn")


func _step(dir: int) -> void:
	var next := clampi(selected + dir, 0, entries.size() - 1)
	if next == selected:
		return
	selected = next
	Audio.play_2d("ui", -9.0, 1.0 + dir * 0.05, "UI")
	_overlay.set_entry(entries[selected], _earned(selected), _count())
