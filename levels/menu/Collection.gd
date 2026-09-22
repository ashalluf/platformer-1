extends Node3D
## THE CHAINS — the collection screen.
##
## Five chains hang on a rail in a dark room, one per World 1 level. The ones
## you have earned are gold under a warm key; the ones you have not are the
## same chain in cold dead metal, because an empty slot tells you nothing and a
## chain you can see but have not got tells you everything.
##
## It is a case in a room somebody owns, not a void with objects floating in
## it: velvet boards on a counter, a brass rail with real fittings, dust in the
## lamps. Real geometry, because these are the trophies the whole game is about
## and they get built and lit like it.

const SPACING := 2.30
const SPAN := 1.90
const RAIL_Y := 2.05
const SLOT_Y := 1.95
## Top of the counter the display boards stand on.
const COUNTER_Y := -1.15
const BOARD_W := 1.80
const BOARD_TOP := 2.40
const BOARD_Z := -0.55
## How far the selected chain leans out of the row, toward the camera.
const LEAN := 1.42

## Per-slot sag. Five identical curves in a row is the tell that nobody hung
## them by hand, so each chain is a slightly different length of rope.
const SAGS := [0.402, 0.437, 0.391, 0.449, 0.414]

var entries: Array = []
var selected := 0
var _slots: Array[Node3D] = []
var _cards: Array[Node3D] = []
var _spots: Array[SpotLight3D] = []
var _washes: Array[SpotLight3D] = []
var _overlay: CollectionOverlay
var _camera: Camera3D
var _t := 0.0
var _slide := 0.0


func _ready() -> void:
	entries = World.chain_slots()
	_apply_capture_override()
	_build_room()
	_build_cases()
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
	m.volumetric_density = 0.010
	m.fog_color = Color(0.20, 0.14, 0.11)
	m.fog_density = 0.0
	m.fog_anisotropy = 0.84
	m.tonemap = Environment.TONE_MAPPER_AGX
	m.exposure = 1.22
	m.white = 7.0
	m.glow_intensity = 0.42
	m.glow_hdr_threshold = 1.15
	m.adjustment_saturation = 1.10
	m.adjustment_contrast = 1.12
	LightingRig.build(self, m)

	# A probe so the gold has the room in it, not just the sky. The vignette
	# quad rides on the camera and would otherwise fill the whole capture, so
	# its layer is excluded.
	var probe := ReflectionProbe.new()
	probe.name = "CaseProbe"
	probe.size = Vector3(28.0, 12.0, 14.0)
	probe.origin_offset = Vector3.ZERO
	probe.intensity = 1.0
	probe.max_distance = 40.0
	probe.cull_mask = 0xFFFFF & ~VIGNETTE_LAYER
	probe.position = Vector3(0.0, 0.9, -0.5)
	add_child(probe)

	# Back wall, far enough behind that the volumetrics have room to work.
	var wall := MeshInstance3D.new()
	wall.name = "BackWall"
	wall.mesh = LevelKit.chamfer_mesh(Vector3(48.0, 20.0, 0.4))
	wall.material_override = MaterialLab.plaster(Color(0.132, 0.112, 0.110), 1.0)
	wall.position = Vector3(0.0, 2.0, -7.0)
	add_child(wall)

	# Two washes on the back wall. Spots rather than omnis: an omni here also
	# lights the floor straight into the lens, and that pool lands exactly
	# where the caption goes.
	for i in 2:
		var wash := SpotLight3D.new()
		wash.name = "Wash%d" % i
		wash.light_color = Color(0.92, 0.55, 0.28)
		wash.light_energy = 8.0
		wash.spot_range = 9.0
		wash.spot_angle = 48.0
		wash.spot_attenuation = 0.9
		wash.shadow_enabled = false
		wash.light_volumetric_fog_energy = 0.8
		add_child(wash)
		var wx := -7.6 + 15.2 * i
		wash.look_at_from_position(Vector3(wx, 2.6, -3.4),
			Vector3(wx, 0.6, -6.8), Vector3.UP)
		_washes.append(wash)

	_build_counter()
	_build_rail()


## The counter the whole case stands on. Two slabs: a matte body and a polished
## top, because the only reflection this room can afford is the one the lamps
## leave on a dark stone surface.
func _build_counter() -> void:
	var width := SPACING * entries.size() + 3.4

	var body := MeshInstance3D.new()
	body.name = "Counter"
	body.mesh = LevelKit.chamfer_mesh(Vector3(width, 0.62, 3.60))
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Color(0.036, 0.032, 0.035)
	matte.roughness = 0.88
	matte.metallic = 0.0
	body.material_override = matte
	body.position = Vector3(0.0, COUNTER_Y - 0.31, -0.10)
	add_child(body)

	var top := MeshInstance3D.new()
	top.name = "CounterTop"
	top.mesh = LevelKit.chamfer_mesh(Vector3(width + 0.22, 0.10, 3.78))
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.040, 0.036, 0.042)
	# Low roughness with real specular: the counter's whole job is to hand the
	# lamps back as long soft streaks under the chains.
	stone.roughness = 0.17
	stone.metallic = 0.0
	stone.metallic_specular = 0.95
	top.material_override = stone
	top.position = Vector3(0.0, COUNTER_Y - 0.05, -0.10)
	add_child(top)

	# A dark floor well below, so the counter has something to stand in rather
	# than ending in nothing.
	var floor_ := MeshInstance3D.new()
	floor_.name = "Floor"
	floor_.mesh = LevelKit.chamfer_mesh(Vector3(40.0, 0.6, 22.0))
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.028, 0.024, 0.026)
	floor_mat.roughness = 0.34
	floor_mat.metallic = 0.0
	floor_mat.metallic_specular = 0.7
	floor_.material_override = floor_mat
	floor_.position = Vector3(0.0, -4.6, 0.0)
	add_child(floor_)


## The rail and its fittings. The rail was always here; what was missing was
## any sign of how it is held up, and a bar floating in front of a wall is the
## fastest way to make a room read as a render.
func _build_rail() -> void:
	var steel := MaterialLab.chrome(Color(0.16, 0.155, 0.16), 0.42)
	var fitting := ChainForge.brass()
	var half := SPACING * entries.size() * 0.5 + 1.20

	var rail := MeshInstance3D.new()
	rail.name = "Rail"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.055
	cyl.height = half * 2.0
	cyl.radial_segments = 16
	rail.mesh = cyl
	rail.material_override = steel
	rail.rotation_degrees = Vector3(0, 0, 90)
	rail.position = Vector3(0.0, RAIL_Y, 0.0)
	add_child(rail)

	for s: float in [-1.0, 1.0]:
		# Finials, so the rail ends rather than being cropped by the frame.
		var ball := MeshInstance3D.new()
		ball.name = "Finial"
		var sph := SphereMesh.new()
		sph.radius = 0.105
		sph.height = 0.21
		sph.radial_segments = 20
		sph.rings = 10
		ball.mesh = sph
		ball.material_override = fitting
		ball.position = Vector3(half * s, RAIL_Y, 0.0)
		add_child(ball)
		_rod(Vector3(half * s - 0.10 * s, RAIL_Y, 0.0),
			Vector3(half * s - 0.24 * s, RAIL_Y, 0.0), 0.075, fitting, "FinialCollar")

	# One bracket per bay, reaching back to the boards.
	for i in entries.size():
		var x := _slot_x(i)
		_rod(Vector3(x, RAIL_Y, 0.0), Vector3(x, RAIL_Y + 0.10, BOARD_Z - 0.02),
			0.030, fitting, "Bracket%d" % i)
		var collar := MeshInstance3D.new()
		collar.name = "Collar%d" % i
		var tor := TorusMesh.new()
		tor.inner_radius = 0.058
		tor.outer_radius = 0.086
		tor.rings = 20
		tor.ring_segments = 8
		collar.mesh = tor
		collar.material_override = fitting
		# TorusMesh's hole runs along Y; lay it along the rail.
		collar.rotation_degrees = Vector3(0, 0, 90)
		collar.position = Vector3(x, RAIL_Y, 0.0)
		add_child(collar)


## A cylinder between two points. CylinderMesh stands on Y, so the basis is
## built from the direction rather than guessed at with Euler angles.
func _rod(a: Vector3, b: Vector3, radius: float, mat: Material,
		name_ := "Rod") -> MeshInstance3D:
	var dir := b - a
	var length := dir.length()
	var mi := MeshInstance3D.new()
	mi.name = name_
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 12
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat
	var up := dir / maxf(length, 0.0001)
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	mi.basis = Basis(side, up, side.cross(up))
	mi.position = (a + b) * 0.5
	add_child(mi)
	return mi


## The case cards: a brass backplate, a velvet board, an inlaid border and an
## engraved tag. These do NOT move with the selection — the chain lifts off its
## board toward you, which is what makes the lean read as depth instead of as
## the whole row sliding about.
func _build_cases() -> void:
	var board_h := BOARD_TOP - COUNTER_Y
	var centre_y := (BOARD_TOP + COUNTER_Y) * 0.5
	var fitting := ChainForge.brass()

	var velvet := MaterialLab.cloth(Color(0.205, 0.100, 0.112), 0.90)
	# Velvet is a sheen material: almost no specular straight on, a bright edge
	# at grazing angles. The rim term is doing the work the nap would.
	velvet.rim = 0.62
	velvet.rim_tint = 0.20
	# Nap as a value break-up in the albedo rather than a normal map: chamfered
	# boxes carry UVs but no tangents, and a normal map without a tangent
	# shades to garbage. The base colour is lifted because the noise averages
	# well under one and would otherwise take the cloth to black.
	velvet.albedo_texture = NoiseBank.grain(31)
	velvet.uv1_scale = Vector3(4.0, 4.0, 1.0)

	for i in entries.size():
		var x := _slot_x(i)
		var card := Node3D.new()
		card.name = "Case%d" % i
		card.position = Vector3(x, 0.0, 0.0)
		add_child(card)
		_cards.append(card)

		var plate := MeshInstance3D.new()
		plate.name = "Backplate"
		plate.mesh = LevelKit.chamfer_mesh(Vector3(BOARD_W + 0.11, board_h + 0.11, 0.07))
		plate.material_override = fitting
		plate.position = Vector3(0.0, centre_y, BOARD_Z - 0.06)
		card.add_child(plate)

		var board := MeshInstance3D.new()
		board.name = "Velvet"
		board.mesh = LevelKit.chamfer_mesh(Vector3(BOARD_W, board_h, 0.06))
		board.material_override = velvet
		board.position = Vector3(0.0, centre_y, BOARD_Z)
		card.add_child(board)

		# An inlaid border, because a plain rectangle of cloth is a backdrop
		# and a bordered one is a mount.
		var inset := 0.16
		for pair: Array in [
				[Vector3(0.0, centre_y + board_h * 0.5 - inset, 0.0),
					Vector3(BOARD_W - inset * 2.0, 0.020, 0.018)],
				[Vector3(0.0, centre_y - board_h * 0.5 + inset, 0.0),
					Vector3(BOARD_W - inset * 2.0, 0.020, 0.018)],
				[Vector3(-BOARD_W * 0.5 + inset, centre_y, 0.0),
					Vector3(0.020, board_h - inset * 2.0, 0.018)],
				[Vector3(BOARD_W * 0.5 - inset, centre_y, 0.0),
					Vector3(0.020, board_h - inset * 2.0, 0.018)]]:
			var bar := MeshInstance3D.new()
			bar.name = "Inlay"
			bar.mesh = LevelKit.chamfer_mesh(pair[1] as Vector3)
			bar.material_override = fitting
			bar.position = (pair[0] as Vector3) + Vector3(0.0, 0.0, BOARD_Z + 0.04)
			card.add_child(bar)

		_build_tag(card, i, fitting)


## The museum label: a brass plate carrying the level's number, low on the
## board where the velvet would otherwise be a metre of nothing.
func _build_tag(card: Node3D, i: int, fitting: Material) -> void:
	var y := COUNTER_Y + 0.42
	var plate := MeshInstance3D.new()
	plate.name = "Tag"
	plate.mesh = LevelKit.chamfer_mesh(Vector3(0.50, 0.20, 0.035))
	plate.material_override = fitting
	plate.position = Vector3(0.0, y, BOARD_Z + 0.05)
	card.add_child(plate)

	var tm := TextMesh.new()
	tm.text = ChainForge.hallmark_of((entries[i] as World.Entry).chain_id)
	tm.font = PropKit.font(PropKit.FONT_KUFI)
	tm.font_size = 96
	tm.pixel_size = 0.105 / 96.0
	tm.depth = 0.008
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mark := MeshInstance3D.new()
	mark.name = "TagNumber"
	mark.mesh = tm
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.030, 0.022, 0.018)
	ink.roughness = 0.35
	mark.material_override = ink
	mark.position = Vector3(0.0, y - 0.042, BOARD_Z + 0.075)
	card.add_child(mark)


func _build_chains() -> void:
	for i in entries.size():
		var e: World.Entry = entries[i]
		var earned := _earned(i)
		var slot := Node3D.new()
		slot.name = "Slot%d" % i
		slot.position = Vector3(_slot_x(i), SLOT_Y, 0.0)
		add_child(slot)
		_slots.append(slot)

		var spin := Node3D.new()
		spin.name = "Spin"
		slot.add_child(spin)
		spin.add_child(ChainForge.chain(e.chain_id, SPAN, earned, float(SAGS[i % SAGS.size()])))

		# One lamp per chain. Earned chains get a warm key; unearned get a
		# quarter of it in cold blue, so the row reads as progress at a glance.
		var spot := SpotLight3D.new()
		spot.name = "Key"
		spot.light_color = Color(1.0, 0.80, 0.50) if earned else Color(0.55, 0.66, 0.86)
		spot.light_energy = 16.0 if earned else 5.0
		spot.light_volumetric_fog_energy = 3.0 if earned else 0.6
		# Long enough to die on the counter and leave a pool at the foot of
		# the board, short enough that it never reaches the floor where the
		# caption sits.
		spot.spot_range = 7.2
		spot.spot_angle = 25.0
		spot.spot_attenuation = 1.05
		spot.shadow_enabled = earned
		spot.shadow_bias = 0.020
		# The 2.0 default peter-pans geometry this thin clean off its own
		# shadow, and the chain's shadow on the velvet is half the shot.
		spot.shadow_normal_bias = 0.6
		slot.add_child(spot)
		# Aim after parenting: look_at works off the global transform, and a
		# node that is not in the tree yet does not have one. The lamp is a
		# child of the slot, so when the chain leans out of the row its light
		# leans with it.
		spot.look_at_from_position(Vector3(_slot_x(i) + 0.28, 4.55, 2.30),
			Vector3(_slot_x(i), 0.35, 0.10), Vector3.UP)
		_spots.append(spot)

		# A cold kicker just in front of the velvet, so the chain has an edge
		# against its board instead of dissolving into it. It belongs to the
		# CARD, not the slot: a rim light that leans forward with the chain
		# stops being behind it and stops being a rim light.
		var back := OmniLight3D.new()
		back.name = "Kicker%d" % i
		back.light_color = Color(0.52, 0.64, 0.92)
		back.light_energy = 2.4
		back.omni_range = 2.8
		back.omni_attenuation = 1.4
		back.shadow_enabled = false
		back.position = Vector3(0.0, 0.55, BOARD_Z + 0.22)
		_cards[i].add_child(back)

		if earned:
			_build_dust(i)


## Dust in the beam. The volumetrics give the cone; these give it grain, which
## is the difference between a lit fog and air with something in it.
func _build_dust(i: int) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.62, 1.35, 0.42)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.005
	pm.initial_velocity_max = 0.035
	pm.gravity = Vector3(0.0, -0.012, 0.0)
	pm.scale_min = 0.45
	pm.scale_max = 1.7
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.07
	pm.turbulence_noise_scale = 2.6
	pm.color = Color(1.0, 0.86, 0.66, 0.55)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.88, 0.70, 0.5)
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.013, 0.013)
	quad.material = mat

	var ps := GPUParticles3D.new()
	ps.name = "Dust%d" % i
	ps.process_material = pm
	ps.draw_pass_1 = quad
	ps.amount = 90
	ps.lifetime = 16.0
	# Pre-rolled, or the first capture frame catches an empty emitter.
	ps.preprocess = 9.0
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.visibility_aabb = AABB(Vector3(-1.1, -1.8, -1.0), Vector3(2.2, 3.6, 2.0))
	ps.position = Vector3(_slot_x(i), 0.95, 0.10)
	add_child(ps)


func _slot_x(i: int) -> float:
	return (float(i) - (entries.size() - 1) * 0.5) * SPACING


## Layer 20, reserved for the vignette quad so the reflection probe can ignore
## it. A quad hanging a metre in front of the lens is not part of the room.
const VIGNETTE_LAYER := 1 << 19


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 36.0
	_camera.near = 0.5
	_camera.far = 260.0
	# Far enough back that the whole case is in frame at once. A collection
	# screen that only shows you one slot is not a collection screen.
	_camera.position = Vector3(0.0, 0.42, 12.60)
	add_child(_camera)
	_camera.current = true
	_build_vignette()


## A vignette, as geometry. Godot's Environment has no vignette, and the alt-
## ernative — crushing the whole image — costs the gold its highlights.
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.82))
	grad.add_point(0.52, Color(1, 1, 1, 0.0))
	grad.add_point(0.80, Color(1, 1, 1, 0.30))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.012, 0.009, 0.013, 1.0)
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
	_slide = lerpf(_slide, float(selected), 1.0 - exp(-9.0 * delta))

	# The camera holds the whole row and only leans toward the selection, so
	# you never lose sight of what you have not got. The breathing is slow
	# enough to be felt rather than seen.
	var want_x := _slide_x() * 0.17
	_camera.position = Vector3(
		want_x + sin(_t * 0.21) * 0.055,
		0.42 + sin(_t * 0.33) * 0.05,
		12.60 + sin(_t * 0.17) * 0.09)
	_camera.rotation.y = -want_x * 0.008
	_camera.rotation.z = sin(_t * 0.13) * 0.0035

	# The washes drift across the back wall. Nothing in this room moves on its
	# own, so the light has to.
	for i in _washes.size():
		var w := _washes[i]
		var wx := -7.6 + 15.2 * i + sin(_t * 0.11 + i * 2.1) * 0.85
		w.look_at_from_position(Vector3(wx, 2.6 + cos(_t * 0.09 + i) * 0.25, -3.4),
			Vector3(wx * 1.05, 0.6, -6.8), Vector3.UP)

	for i in _slots.size():
		var slot := _slots[i]
		var focus := 1.0 - clampf(absf(_slide - i), 0.0, 1.0)
		# The selected chain leans out of the row and turns to show the emblem.
		var ease := focus * focus * (3.0 - 2.0 * focus)
		slot.position.z = lerpf(0.0, LEAN, ease)
		slot.position.y = SLOT_Y + ease * 0.14
		var spin := slot.get_node("Spin") as Node3D
		spin.rotation.y = sin(_t * 0.55 + i) * (0.08 + ease * 0.20)
		_spots[i].light_energy = lerpf(
			13.0 if _earned(i) else 6.0, 30.0 if _earned(i) else 15.0, ease)


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
