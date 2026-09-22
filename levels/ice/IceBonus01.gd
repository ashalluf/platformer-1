extends IceBonusStage
## ICE BONUS — "GLACIER RUN".
##
## A short, bright, cold place built out of one material the rest of the game
## never uses. The route reads from the first second: a rising serpentine across
## a frozen shelf, with the trail always visible one segment ahead.
##
## Exactly 100 ICE SRIRACHAS are placed. Finishing the route finishes the count.
##
## Everything that is not the route is dressing and none of it collides. One
## rule governs all of it: the gameplay plane is the brightest, sharpest,
## highest-contrast thing on screen, and every band behind it gives up a little
## more value and a little more detail until it is fog with a shape in it. The
## bands are numbered in the code so the order is never guessed at:
##
##   0  foreground   z  +3 .. +5   dark, low, cropped by the frame edge
##   1  near field   z  -7 .. -32  seracs, crevasses, the pressure ridge
##   2  mid field    z -45 .. -95  bigger, paler, no interior detail
##   3  far range    z -110..-160  a ridge line and the frozen sea
##   4  vast         z -240..-340  two forms that exist to state the scale
##   5  sky          aurora curtains and a star field

const ICE_VARIANT := 1   ## Sriracha.Variant.ICE
const AURORA_SHADER := preload("res://shaders/aurora.gdshader")

var m := {}

var _rng := RandomNumberGenerator.new()
## Icicles and flutes are collected across the whole build and emitted as
## MultiMeshes. Several hundred cones should cost one draw call, not several
## hundred — and on a level this densely dressed the draw call count is the
## budget that runs out first.
var _icicles: Array[Transform3D] = []
var _flutes_by_mat: Dictionary = {}


func _ready() -> void:
	level_id = "ice_glacier"
	level_title = "GLACIER RUN"
	spawn_point = Vector3(-4.0, 3.0, 0.0)
	time_limit = 50.0
	music_theme = ""   # no score: the game runs on ambience and SFX alone
	use_camera_bounds = true
	camera_bounds_min = Vector2(-2.0, -8.0)
	camera_bounds_max = Vector2(128.0, 30.0)
	super._ready()
	camera.height_offset = 2.6


func _mood() -> LightingRig.Mood:
	var mood := LightingRig.Mood.new()
	# Twilight over ice: a low cold key, a strong sky, and a violet fill. The
	# whole level is lit to make white read as white and ice read as deep.
	mood.sun_angles = Vector2(-8.0, 138.0)

	# --- contrast budget (see LightingRig.Mood.set_contrast) ---
	# This level is BACKLIT: the key runs (-0.66, -0.14, +0.74) at eight degrees
	# of elevation, so the sun is behind the serac field shining toward camera.
	# Nothing the camera can see is lit by it and every cast shadow falls away
	# from the lens.
	#
	# That makes the usual reasoning about snow backwards here. A low ratio was
	# set on the grounds that snow bounces — and with no key reaching the
	# visible faces, all a low ratio does is flood the near field with ambient
	# until it matches the sky. Measured: 2.3:1 contrast, 0.1% of the frame in
	# shadow, and a serac field whose four authored value bands (0.07 / 0.17 /
	# 0.34 / 0.50 albedo) all arrived on screen as the same pale blue. An image
	# with no form reads as out of focus, which is what every capture of this
	# level looked like.
	#
	# A backlit glacier is a HIGH-contrast subject: dark masses against a blown
	# sky, with the rim doing the separating. 6:1, and the sky's share of the
	# shade side cut from 0.78 to 0.55 so the near band can actually be dark.
	mood.set_contrast(3.2, 6.0, 0.55)
	mood.sun_color = Color(0.76, 0.90, 1.0)
	mood.sun_angular_distance = 0.9
	mood.sun_fog_energy = 2.6
	mood.sun_disc_size = 2.4

	mood.fill_angles = Vector2(22.0, -40.0)
	mood.fill_color = Color(0.46, 0.44, 0.78)

	mood.rim_angles = Vector2(-6.0, 106.0)
	mood.rim_color = Color(0.70, 0.94, 1.0)
	mood.rim_energy = 5.0
	mood.rim_cull_mask = 2
	mood.hero_fill_energy = 1.7
	mood.hero_fill_color = Color(0.80, 0.86, 1.0)
	mood.hero_fill_angles = Vector2(-16.0, -34.0)

	mood.sky_top = Color(0.043, 0.055, 0.153)
	mood.sky_horizon = Color(0.302, 0.482, 0.690)
	mood.ground_horizon = Color(0.322, 0.404, 0.522)
	mood.ground_bottom = Color(0.086, 0.114, 0.184)
	mood.sky_curve = 0.16

	mood.fog_color = Color(0.588, 0.729, 0.878)
	mood.fog_density = 0.0040
	mood.fog_sun_scatter = 0.55
	mood.fog_emission = Color(0.10, 0.16, 0.28)
	mood.fog_anisotropy = 0.72
	# 0.0045 was eleven times Brega's. Volumetric fog is rendered at a low
	# internal resolution, so at that density in an already-white scene it does
	# not read as atmosphere, it reads as the whole frame being out of focus —
	# which is exactly what the capture showed.
	mood.volumetric_density = 0.0018

	# The far bands are modelled, not painted, so they get a real lens response:
	# past the mid field the eye should not be able to resolve an edge.
	mood.dof_distance = 96.0
	mood.dof_transition = 58.0
	mood.dof_amount = 0.09

	# Was ACES while Brega, Ajdabiya, the menus and IceBonus03 all run AgX.
	# Two levels in one game on different response curves is the definition of
	# scenes built to different standards: different highlight rolloff,
	# different saturation behaviour under exposure. The canon numbers are in
	# ART_DIRECTION.md and IceBonus03 already uses them.
	mood.tonemap = Environment.TONE_MAPPER_AGX
	mood.exposure = 0.86
	mood.agx_white = 9.5
	mood.agx_contrast = 1.45
	# Aerial perspective: the ice levels are built in receding bands and this is
	# what separates them.
	# Aerial perspective tints distance toward the sky. In a desert that gives
	# depth; in a white scene under a white sky it dissolves the serac field
	# into the background entirely. Half as much, so the ridgelines survive.
	mood.fog_aerial = 0.30
	# GLOW, and the reason these levels looked out of focus.
	#
	# A white snowfield puts nearly every pixel it has above an HDR threshold
	# of 1.3, so glow was not picking out speculars and sparkle — it was
	# picking up the entire image, blurring it at the two widest mip levels and
	# compositing it back over itself. That is a full-frame haze, and it is
	# what made the seracs, the hero and the near ledge all read as soft in
	# every capture of these levels.
	#
	# The threshold now sits well above the snow's own level, so only the ice
	# speculars, the collectibles and the aurora cross it, and the levels are
	# weighted toward the tight mips so what crosses reads as a halo rather
	# than as fog. Brega, which never had this problem, runs 0.12 at 2.2.
	mood.glow_intensity = 0.18
	mood.glow_hdr_threshold = 3.0
	mood.glow_luminance_cap = 6.0
	mood.glow_levels = [0.0, 0.8, 1.0, 0.5, 0.0, 0.0, 0.0]
	mood.adjustment_saturation = 1.14
	mood.adjustment_contrast = 1.06
	return mood


## SkyForge has a purpose-built ice preset and these two levels never asked
## for it, so they rendered a flat ProceduralSkyMaterial gradient while a
## shader with five octaves of cloud and anisotropic cirrus sat unused.
func _sky_preset() -> String:
	return "ice_twilight"


func _build_level() -> void:
	_rng.seed = 90210
	_materials()
	_sky()
	_vast()
	_far_range()
	_mid_field()
	_near_field()
	_route()
	_foreground()
	_flush_icicles()
	_flush_flutes()
	_atmosphere_ice()
	_no_prop_shadows()


## Dressing does not cast shadows.
##
## Everything parented straight to `geometry` here is decoration; the shadows
## that carry the level come from the platform bodies, which are StaticBody3D
## and so are not touched by this. Three hundred decorative boxes in the
## directional shadow atlas is a fixed per-frame cost that does not shrink with
## resolution and buys nothing the eye can find in a twilight scene lit by a sun
## eight degrees above the horizon.
## ...except the big ones.
##
## The blanket version of this turned cast_shadow off for every decorative
## child of `geometry`, which is every serac in the field. Measured result:
## 0.1% of the frame below 0.25 luminance and a contrast ratio of 2.3:1 in a
## level whose lighting budget was set to 3.2:1. A serac field where nothing
## shadows anything has no form at all, and an image with no form reads to the
## eye as out of focus — which is exactly what four separate captures of this
## level looked like, and what sent four wrong diagnoses (depth of field,
## glow, fog volumes, refraction) chasing a blur that was never there. The
## framebuffer was 1280x720 at render scale 1.0 the whole time.
##
## The cost argument in the original was sound for the dressing and wrong for
## the masses. Three hundred small boxes in the shadow atlas buy nothing; a
## twelve-metre serac casting across the route is the only thing that says the
## route has a shape. So the rule is size, not category.
const SHADOW_MIN_SIZE := 3.2

func _no_prop_shadows() -> void:
	for child in geometry.get_children():
		if child is not GeometryInstance3D:
			continue
		var gi := child as GeometryInstance3D
		var span := 0.0
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var ab := (gi as MeshInstance3D).get_aabb().size * gi.scale
			span = maxf(ab.x, maxf(ab.y, ab.z))
		if span < SHADOW_MIN_SIZE:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Materials --------------------------------------------------------------

## One place to build ice.
##
## The shader has more knobs than MaterialLab.ice sets, and the ones it does not
## set are exactly the ones that decide whether a background mass reads as
## atmosphere or as a hole in the sky: a 130 m massif run through Beer-Lambert
## at thickness_scale 1.0 comes out as an opaque navy rectangle. Distance costs
## thickness, interior detail and sparkle, in that order.
func _ice(clarity: float, tint: Color, o := {}) -> ShaderMaterial:
	var mat := MaterialLab.ice(clarity, tint)
	mat.set_shader_parameter("clarity", o.get("clarity", clarity))
	mat.set_shader_parameter("thickness_scale", o.get("thickness", 1.0))
	mat.set_shader_parameter("crack_density", o.get("cracks", 1.0))
	mat.set_shader_parameter("crack_scale", o.get("crack_scale", 0.45))
	mat.set_shader_parameter("crack_sharpness", o.get("crack_sharpness", 9.0))
	mat.set_shader_parameter("bubble_amount", o.get("bubbles", 0.7))
	mat.set_shader_parameter("rime_amount", o.get("rime", 1.0))
	mat.set_shader_parameter("frost_relief", o.get("relief", 0.9))
	mat.set_shader_parameter("sheen", o.get("sheen", 0.6))
	mat.set_shader_parameter("refraction", o.get("refraction", 0.18))
	mat.set_shader_parameter("refraction_offset", o.get("refract_px", 0.008))
	mat.set_shader_parameter("ice_bright", o.get("bright", Color(0.54, 0.80, 0.97)))
	mat.set_shader_parameter("frost_color", o.get("frost", Color(0.87, 0.93, 1.0)))
	if o.has("sparkle"):
		mat.set_shader_parameter("sparkle_amount", o["sparkle"])
	if bool(o.get("interior", true)):
		mat.set_shader_parameter("interior_fade_start", o.get("fade_start", 15.0))
		mat.set_shader_parameter("interior_fade_end", o.get("fade_end", 34.0))
	else:
		# The off switch. The ray march is the most expensive thing in the
		# shader and it is invisible past a few metres; anything in bands 2-4
		# pays nothing for it.
		mat.set_shader_parameter("interior_fade_start", 0.1)
		mat.set_shader_parameter("interior_fade_end", 0.2)
	return mat


## Fresh snow and nothing else: no dust, no grime, no warmth. This is the one
## material in the level allowed to sit at the top of the value range, because
## it is the line the eye lands on when it is looking for somewhere to stand.
func _snow_lip() -> ShaderMaterial:
	return MaterialLab.surface({
		"color": Color(0.90, 0.94, 1.00),
		"variation": Color(0.74, 0.82, 0.95),
		"variation_strength": 0.34,
		"roughness_min": 0.60, "roughness_max": 0.88,
		"mask": NoiseBank.grain(29),
		"normal": NoiseBank.detail_normal(44, 0.22, 1.2),
		"detail_scale": 1.10, "macro_scale": 0.14,
		"normal_strength": 0.80,
		"dust": 0.0, "grime": 0.0,
		"emission": Color(0.40, 0.58, 0.84), "emission_strength": 0.16,
		"ao": 0.30,
	})


func _materials() -> void:
	m = {
		# Gameplay plane: clear, bright, full interior detail.
		"ice": _ice(1.0, Color(0.055, 0.225, 0.400), {"cracks": 1.3, "sheen": 0.72}),
		"packed": _ice(0.42, Color(0.100, 0.300, 0.500),
			{"cracks": 0.9, "fade_start": 12.0, "fade_end": 28.0}),
		# Snow is opaque: there is nothing inside it to march for, so the
		# march is switched off and a lot of screen area stops paying for it.
		"snow": _ice(0.06, Color(0.620, 0.740, 0.900),
			{"rime": 1.3, "sparkle": 1.6, "relief": 1.3, "interior": false}),
		"lip": _snow_lip(),
		# The darkest thing in the level. Crevasse throats and the hard shadow
		# under every lit edge.
		"void": _ice(0.9, Color(0.012, 0.040, 0.095),
			{"thickness": 1.4, "interior": false, "sparkle": 0.0, "refraction": 0.0}),
		# Meltwater: almost no roughness, no rime, and it takes the sky.
		"melt": _ice(1.0, Color(0.020, 0.110, 0.230),
			{"sheen": 1.0, "rime": 0.0, "cracks": 0.0, "bubbles": 0.0,
			 "refraction": 0.36, "sparkle": 0.4, "thickness": 0.9}),
		"icicle": _ice(1.0, Color(0.130, 0.380, 0.600),
			{"thickness": 0.55, "interior": false, "sparkle": 4.2, "sheen": 0.9,
			 "refraction": 0.28}),

		# Band 1 — near field. Deep, so the route sits on top of it in value.
		"near": _ice(0.82, Color(0.070, 0.220, 0.400), {"thickness": 0.42}),
		# Band 2 — mid field.
		"mid": _ice(0.50, Color(0.175, 0.335, 0.540),
			{"thickness": 0.16, "interior": false, "sparkle": 0.5}),
		# Band 3 — far range.
		"far": _ice(0.26, Color(0.345, 0.490, 0.680),
			{"thickness": 0.07, "interior": false, "sparkle": 0.0,
			 "refraction": 0.0, "rime": 0.7}),
		# Band 4 — vast. Almost pure aerial perspective with an edge on it.
		"vast": _ice(0.10, Color(0.500, 0.640, 0.820),
			{"thickness": 0.025, "interior": false, "sparkle": 0.0,
			 "refraction": 0.0, "rime": 0.5, "sheen": 0.2}),
	}


# --- Primitive vocabulary ---------------------------------------------------

## A serac: the block a glacier breaks into where it goes over a step. Never one
## box. Always two or three leaning against each other, because a single tilted
## box reads as a placed prop and a cluster reads as something that fractured.
func _serac(base: Vector3, w: float, h: float, d: float, mat: Material) -> void:
	var lean := _rng.randf_range(-0.13, 0.13)
	var main := LevelKit.prop(geometry, base + Vector3(0.0, h * 0.5, 0.0),
		Vector3(w, h, d), mat, "Serac")
	main.rotation = Vector3(0.0, _rng.randf_range(-0.5, 0.5), lean)
	var shard := LevelKit.prop(geometry,
		base + Vector3(w * _rng.randf_range(0.42, 0.80), h * _rng.randf_range(0.20, 0.42),
			d * _rng.randf_range(-0.4, 0.4)),
		Vector3(w * 0.55, h * 0.64, d * 0.72), mat, "SeracShard")
	shard.rotation = Vector3(0.0, _rng.randf_range(-0.7, 0.7),
		lean - _rng.randf_range(0.12, 0.34))
	if _rng.randf() < 0.65:
		var foot := LevelKit.prop(geometry,
			base + Vector3(-w * 0.44, h * 0.15, d * -0.32),
			Vector3(w * 0.46, h * 0.32, d * 0.62), mat, "SeracFoot")
		foot.rotation = Vector3(0.0, _rng.randf_range(-0.6, 0.6),
			lean + _rng.randf_range(0.14, 0.36))


## A pressure ridge: where two sheets meet and neither gives way the ice
## fractures into plates and stands them on edge. A run of thin slabs leaning
## alternately is what that looks like at distance, and it gives a flat
## midground a horizon line with teeth in it.
func _ridge(from: Vector3, to: Vector3, plates: int, size: Vector3,
		mat: Material) -> void:
	for i in plates:
		var t := float(i) / float(maxi(plates - 1, 1))
		var p := from.lerp(to, t) + Vector3(
			_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-2.4, 2.4))
		var s := size * _rng.randf_range(0.62, 1.4)
		var plate := LevelKit.prop(geometry, p + Vector3(0.0, s.y * 0.42, 0.0),
			s, mat, "Plate")
		plate.rotation = Vector3(
			_rng.randf_range(-0.10, 0.10),
			_rng.randf_range(-0.8, 0.8),
			(1.0 if i % 2 == 0 else -1.0) * _rng.randf_range(0.16, 0.46))


## Wind-carved flutes. On a big ice face the wind cuts vertical channels, and
## those channels are the only scale reference a hundred-metre wall has. Half
## buried cylinders read as flutes from every angle this camera can reach.
##
## Batched per material: a flute is one scaled unit cylinder, so a whole face
## worth of them is a single instanced draw.
func _flutes(left: float, right: float, base_y: float, height: float, z: float,
		count: int, radius: float, key: String) -> void:
	if not _flutes_by_mat.has(key):
		# Typed on creation: the reader below binds it to a typed local, and a
		# plain [] stored here would fail that assignment at runtime.
		var fresh: Array[Transform3D] = []
		_flutes_by_mat[key] = fresh
	var into: Array[Transform3D] = _flutes_by_mat[key]
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var x := lerpf(left, right, t) + _rng.randf_range(-1.0, 1.0) * radius
		var h := height * _rng.randf_range(0.5, 1.0)
		var r := radius * _rng.randf_range(0.65, 1.35)
		into.append(Transform3D(Basis().scaled(Vector3(r * 2.0, h, r * 2.0)),
			Vector3(x, base_y + h * 0.5, z)))


func _flush_flutes() -> void:
	var unit := CylinderMesh.new()
	unit.top_radius = 0.5
	unit.bottom_radius = 0.5
	unit.height = 1.0
	unit.radial_segments = 7
	unit.rings = 0
	for key: String in _flutes_by_mat.keys():
		var xforms: Array[Transform3D] = _flutes_by_mat[key]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Flutes_%s" % key
		mi.multimesh = mm
		mi.material_override = m[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.add_child(mi)
	_flutes_by_mat.clear()


## Snow does not lie evenly. It piles on the leeward side of anything that stops
## the wind, and a drift at the foot of a box is the cheapest way to stop the
## box looking placed.
func _drift(at: Vector3, length: float, height: float, depth: float,
		lean := 0.16) -> void:
	var d := LevelKit.prop(geometry, at + Vector3(0.0, height * 0.32, 0.0),
		Vector3(length, height, depth), m["snow"], "Drift")
	d.rotation = Vector3(0.0, _rng.randf_range(-0.3, 0.3), lean)


## Sastrugi: one wind, blowing for months, carves the snow surface into hard
## parallel ridges. It is the most recognisable thing about a polar surface and
## a flat white box has none of it. Kept off the walk line so the player never
## clips through one.
func _sastrugi(left: float, right: float, y: float, z_min: float, z_max: float,
		count: int) -> void:
	for _i in count:
		var ridge := LevelKit.prop(geometry,
			Vector3(_rng.randf_range(left, right), y + 0.04,
				_rng.randf_range(z_min, z_max)),
			Vector3(_rng.randf_range(1.6, 4.4), 0.13,
				_rng.randf_range(0.26, 0.62)), m["lip"], "Sastruga")
		# All of them within a few degrees of one heading. Scattered angles say
		# "random placement"; a common heading says "wind".
		ridge.rotation.y = _rng.randf_range(-0.12, 0.12)


## Icicles. Every overhang in a cold place grows them, and a fringe under the
## front lip of a platform does two jobs: it says the edge is ice, and it draws
## a hard bright-over-dark line exactly where the player reads the edge.
##
## They cluster. An evenly spaced fringe reads as a comb, so a slow sine along
## the run gives runs of long ones where the meltwater ran and gaps between.
func _icicle_fringe(left: float, right: float, y: float, z: float, count: int,
		max_len := 1.15, max_r := 0.095) -> void:
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var x := lerpf(left, right, t) + _rng.randf_range(-0.14, 0.14)
		var cluster := 0.28 + 0.72 * absf(sin(t * 9.3 + 1.7))
		var l := max_len * cluster * _rng.randf_range(0.35, 1.0)
		var r := max_r * _rng.randf_range(0.5, 1.0) * (0.45 + 0.55 * cluster)
		var b := Basis().scaled(Vector3(r * 2.0, l, r * 2.0))
		b = b.rotated(Vector3.FORWARD, _rng.randf_range(-0.10, 0.10))
		_icicles.append(Transform3D(b,
			Vector3(x, y - l * 0.5, z + _rng.randf_range(-0.07, 0.07))))


func _flush_icicles() -> void:
	if _icicles.is_empty():
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.0     ## the point hangs down
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = _icicles.size()
	for i in _icicles.size():
		mm.set_instance_transform(i, _icicles[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Icicles"
	mi.multimesh = mm
	mi.material_override = m["icicle"]
	# A few hundred cones casting shadows buys nothing and costs a lot; they
	# read on their own silhouette against the dark under the lip.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(mi)
	_icicles.clear()


## A crevasse mouth. The read is entirely in the interior — a crevasse you can
## see the bottom of is a ditch. So the throat is the darkest material in the
## level, the two lips lean in over it, and icicles hang off both into the dark.
func _crevasse(at: Vector3, width: float, length: float, depth: float) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, -depth * 0.5 - 0.15, 0.0),
		Vector3(width * 1.2, depth, length * 0.9), m["void"], "CrevasseThroat")
	for side: float in [-1.0, 1.0]:
		var lip := LevelKit.prop(geometry,
			at + Vector3(side * (width * 0.5 + 0.5), -0.15, 0.0),
			Vector3(1.5, 0.95, length), m["packed"], "CrevasseLip")
		lip.rotation.z = -side * 0.17
		_icicle_fringe(at.x + side * width * 0.30, at.x + side * (width * 0.5 + 0.1),
			at.y - 0.40, at.z + length * 0.28, 5, 0.85, 0.07)


## Meltwater. The thing that sells a pool is not the water — it is the bright
## refrozen collar around it, which on a flat white top is the only hard bright
## line there is.
func _pool(at: Vector3, size: Vector2) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 0.03, 0.0),
		Vector3(size.x + 0.7, 0.16, size.y + 0.7), m["lip"], "PoolRim")
	LevelKit.prop(geometry, at, Vector3(size.x, 0.12, size.y), m["melt"], "Pool")


## The standard treatment for every standable surface in the level: a bright lip
## proud of the front edge, a hard shadow immediately under it, an icicle fringe
## below that, carved snow on top and drifts at both ends. Bright line over dark
## line is a readable edge; bright line over more ice is a smudge.
func _dress_shelf(left: float, right: float, top: float, front_z := 1.70,
		icicles := 18) -> void:
	var w := right - left
	var cx := (left + right) * 0.5
	LevelKit.prop(geometry, Vector3(cx, top + 0.10, front_z - 0.18),
		Vector3(w + 0.35, 0.26, 0.58), m["lip"], "Lip")
	LevelKit.prop(geometry, Vector3(cx, top - 0.27, front_z - 0.05),
		Vector3(w + 0.18, 0.34, 0.22), m["void"], "LipShadow")
	_icicle_fringe(left + 0.4, right - 0.4, top - 0.44, front_z - 0.04, icicles)
	_sastrugi(left + 0.8, right - 0.8, top, -1.45, -0.72, maxi(2, int(w / 9.0)))
	_sastrugi(left + 0.8, right - 0.8, top, 0.86, 1.34, maxi(1, int(w / 14.0)))
	_drift(Vector3(left + 0.8, top, -1.15), w * 0.22, 0.42, 0.9, 0.14)
	_drift(Vector3(right - 0.8, top, 1.25), w * 0.18, 0.34, 0.8, -0.12)


# --- Band 5: the sky --------------------------------------------------------

func _sky() -> void:
	_stars()
	_aurora()


## Twilight, and the sky is the emptiest thing in the frame. A few hundred
## unshaded points at the back of the world cost one draw call and give the
## aurora something to hang in front of.
func _stars() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 240
	for i in mm.instance_count:
		var s := _rng.randf_range(0.30, 1.5)
		mm.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(s, s, s)),
			Vector3(_rng.randf_range(-340.0, 580.0), _rng.randf_range(40.0, 210.0),
				-430.0)))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Stars"
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.86, 0.92, 1.00, 0.80)
	mat.disable_receive_shadows = true
	# Four hundred metres of depth fog would erase them completely.
	mat.disable_fog = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(mi)


## Five sheets at different distances, widths and swing rates, so the sky has
## parallax in it instead of one painted band.
##
## QuadMesh on purpose: LevelKit's chamfered boxes carry planar UVs measured in
## METRES, which would put the whole aurora profile outside its 0..1 range and
## kill the shader silently — which is exactly what the previous version did.
func _aurora() -> void:
	var sheets := [
		# x,     y,    z,      w,     h,    roll, strength, hem, crown, rays
		[ 20.0, 50.0, -132.0, 190.0, 54.0,  0.07, 1.15,
			Color(0.28, 1.00, 0.60), Color(0.66, 0.34, 1.00), 14.0],
		[ 74.0, 42.0, -158.0, 230.0, 46.0, -0.05, 0.86,
			Color(0.40, 1.00, 0.74), Color(0.42, 0.52, 1.00), 19.0],
		[-18.0, 58.0, -184.0, 200.0, 62.0,  0.11, 0.62,
			Color(0.26, 0.92, 0.78), Color(0.80, 0.40, 0.96), 11.0],
		[112.0, 46.0, -172.0, 170.0, 50.0, -0.09, 0.70,
			Color(0.34, 1.00, 0.66), Color(0.90, 0.46, 0.86), 23.0],
		[ 52.0, 68.0, -212.0, 300.0, 70.0,  0.03, 0.44,
			Color(0.46, 0.94, 0.82), Color(0.56, 0.44, 1.00), 8.0],
	]
	for i in sheets.size():
		var s: Array = sheets[i]
		var mat := ShaderMaterial.new()
		mat.shader = AURORA_SHADER
		mat.set_shader_parameter("tint_hem", s[7])
		mat.set_shader_parameter("tint_crown", s[8])
		mat.set_shader_parameter("strength", float(s[6]))
		mat.set_shader_parameter("noise_tex", NoiseBank.streaks(53 + i * 13))
		mat.set_shader_parameter("ray_scale", float(s[9]))
		mat.set_shader_parameter("drift_speed", 0.008 + i * 0.004)
		mat.set_shader_parameter("base_fade", 0.72 - i * 0.07)
		mat.set_shader_parameter("hem_height", 0.20 + i * 0.05)
		mat.set_shader_parameter("hem_speed", 0.22 + i * 0.09)
		mat.set_shader_parameter("presence_scale", 1.0 + i * 0.4)

		var q := QuadMesh.new()
		q.size = Vector2(float(s[3]), float(s[4]))
		var mi := MeshInstance3D.new()
		mi.name = "Aurora%d" % i
		mi.mesh = q
		mi.material_override = mat
		mi.position = Vector3(float(s[0]), float(s[1]), float(s[2]))
		mi.rotation.z = float(s[5])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.add_child(mi)


# --- Band 4: vast -----------------------------------------------------------

## Two forms whose only job is to state how big this place is. Both sit far
## enough back that depth fog does most of the work, and both are built at a
## near-zero thickness scale so the volumetric term does not turn them black.
func _vast() -> void:
	_massif(Vector3(-70.0, -12.0, -330.0), 320.0, 128.0, 70.0)
	_ice_front(Vector3(230.0, -12.0, -262.0), 460.0, 84.0, 44.0)


## A domed massif, stepped rather than smooth: ice does not make cones, it makes
## a stack of shelves the wind has rounded off.
func _massif(base: Vector3, width: float, height: float, depth: float) -> void:
	var steps := 5
	for i in steps:
		var t := float(i) / float(steps - 1)
		var w := width * (1.0 - t * 0.78)
		var h := height * (0.30 - t * 0.035)
		var y := base.y + height * (t * 0.82)
		LevelKit.prop(geometry,
			Vector3(base.x + width * 0.06 * t, y + h * 0.5, base.z + depth * 0.18 * t),
			Vector3(w, h, depth * (1.0 - t * 0.6)), m["vast"], "MassifStep%d" % i)
	_flutes(base.x - width * 0.45, base.x + width * 0.45, base.y, height * 0.52,
		base.z + depth * 0.42, 14, 4.2, "vast")


## A tabular ice front: a long cliff with a broken top edge. The broken edge is
## the whole point — a straight one reads as a wall, a jagged one reads as ice
## that calved.
func _ice_front(at: Vector3, width: float, height: float, depth: float) -> void:
	LevelKit.prop(geometry, Vector3(at.x, at.y + height * 0.5, at.z),
		Vector3(width, height, depth), m["vast"], "IceFront")
	var blocks := 10
	for i in blocks:
		var t := float(i) / float(blocks - 1)
		var w := width / float(blocks) * _rng.randf_range(0.7, 1.25)
		var h := height * _rng.randf_range(0.05, 0.22)
		LevelKit.prop(geometry,
			Vector3(at.x - width * 0.5 + width * t, at.y + height + h * 0.4,
				at.z + _rng.randf_range(-depth * 0.2, depth * 0.2)),
			Vector3(w, h, depth * 0.7), m["vast"], "FrontCrown%d" % i)
	_flutes(at.x - width * 0.46, at.x + width * 0.46, at.y, height * 0.8,
		at.z + depth * 0.46, 20, 3.0, "vast")


# --- Band 3: far range ------------------------------------------------------

func _far_range() -> void:
	# The frozen sea, flat to the horizon, catching the low sun. Its top sits
	# two metres under the shelves so the route reads as rising off a plain.
	var sea := _ice(0.9, Color(0.10, 0.28, 0.46), {
		"thickness": 0.05, "interior": false, "sparkle": 0.6, "sheen": 0.85,
		"rime": 0.55, "refraction": 0.0,
	})
	LevelKit.prop(geometry, Vector3(60.0, -13.0, -168.0),
		Vector3(1100.0, 6.0, 300.0), sea, "FrozenSea")

	# A ridge line across the whole back of the level, with the peaks broken so
	# nothing repeats at a readable interval.
	for i in 8:
		var x := -140.0 + i * 62.0 + _rng.randf_range(-12.0, 12.0)
		var h := _rng.randf_range(30.0, 62.0)
		var w := _rng.randf_range(24.0, 54.0)
		var peak := LevelKit.prop(geometry,
			Vector3(x, -10.0 + h * 0.5, _rng.randf_range(-160.0, -118.0)),
			Vector3(w, h, 22.0), m["far"], "FarPeak%d" % i)
		peak.rotation = Vector3(0.0, _rng.randf_range(-0.4, 0.4),
			_rng.randf_range(-0.08, 0.08))
	_ridge(Vector3(-120.0, -10.5, -112.0), Vector3(260.0, -10.5, -128.0), 12,
		Vector3(11.0, 15.0, 5.0), m["far"])


# --- Band 2: mid field ------------------------------------------------------

func _mid_field() -> void:
	for i in 8:
		var x := -70.0 + i * 31.0 + _rng.randf_range(-6.0, 6.0)
		_serac(Vector3(x, -10.0, _rng.randf_range(-95.0, -46.0)),
			_rng.randf_range(7.0, 15.0), _rng.randf_range(12.0, 34.0),
			_rng.randf_range(6.0, 13.0), m["mid"])
	_ridge(Vector3(-60.0, -10.0, -44.0), Vector3(200.0, -10.0, -62.0), 13,
		Vector3(6.0, 9.0, 3.0), m["mid"])


# --- Band 1: near field -----------------------------------------------------

func _near_field() -> void:
	# Seracs behind the route. They are the deepest value in the frame, which is
	# what lets the white shelves sit on top of them without a rim light.
	for i in 10:
		var x := -26.0 + i * 17.0 + _rng.randf_range(-3.2, 3.2)
		_serac(Vector3(x, -8.6 - _rng.randf_range(0.0, 1.4),
				_rng.randf_range(-31.0, -8.5)),
			_rng.randf_range(2.6, 5.6), _rng.randf_range(5.0, 15.0),
			_rng.randf_range(2.2, 4.6), m["near"])

	# The pressure ridge runs diagonally so it is never parallel to the route.
	_ridge(Vector3(-24.0, -8.8, -12.0), Vector3(146.0, -8.8, -27.0), 16,
		Vector3(3.2, 5.2, 1.4), m["near"])

	# Crevasse mouths on the plain between the shelves, where the camera looks
	# down past the front edge.
	for spec: Vector3 in [Vector3(12.0, -8.4, -11.0), Vector3(46.0, -8.4, -17.0),
			Vector3(88.0, -8.4, -13.5), Vector3(124.0, -8.4, -19.0)]:
		_crevasse(spec, _rng.randf_range(3.0, 6.0), _rng.randf_range(9.0, 16.0), 9.0)

	# Drifts banked against the near seracs, which is where the wind drops them.
	for i in 7:
		_drift(Vector3(-20.0 + i * 23.0 + _rng.randf_range(-4.0, 4.0), -8.6,
				_rng.randf_range(-26.0, -9.0)),
			_rng.randf_range(6.0, 14.0), _rng.randf_range(1.0, 2.4),
			_rng.randf_range(3.0, 7.0), _rng.randf_range(-0.2, 0.2))


# --- Band 0: foreground -----------------------------------------------------

## In front of the gameplay plane and deliberately cropped by the bottom of the
## frame. It gives the camera something to travel past, which is most of what
## sells lateral speed, and it is kept below the walk line so it can never hide
## the player or a bottle.
func _foreground() -> void:
	for i in 12:
		var x := -16.0 + i * 12.4 + _rng.randf_range(-2.4, 2.4)
		var shard := LevelKit.prop(geometry,
			Vector3(x, _rng.randf_range(-2.8, -1.1), _rng.randf_range(2.95, 4.9)),
			Vector3(_rng.randf_range(2.2, 5.6), _rng.randf_range(1.2, 2.8),
				_rng.randf_range(0.9, 2.0)), m["near"], "ForeShard%d" % i)
		shard.rotation = Vector3(0.0, _rng.randf_range(-0.9, 0.9),
			_rng.randf_range(-0.45, 0.45))


# --- The route --------------------------------------------------------------

## Every segment has a platform under it and the next segment is always visible
## from the one before. Positions, counts and spacing are tuned — the dressing
## calls below add nothing that collides and nothing above the walk line.
func _route() -> void:
	var shelf: Material = m["packed"]
	var slab: Material = m["ice"]

	# 1 — a flat run in. 12 bottles.
	LevelKit.platform(geometry, -8.0, 0.0, 26.0, shelf, 8.0, 3.4, "Shelf1")
	_dress_shelf(-8.0, 18.0, 0.0, 1.70, 26)
	_pool(Vector3(6.5, 0.0, -1.05), Vector2(4.2, 1.3))
	_flutes(-7.0, 17.0, -7.4, 6.2, 1.62, 9, 0.30, "packed")
	TrailBuilder.line(geometry, Vector3(-4.0, 1.0, 0.0), Vector3(14.0, 1.0, 0.0), 12, ICE_VARIANT)

	# 2 — a jump arc onto a higher slab. 8.
	LevelKit.platform(geometry, 22.0, 2.6, 12.0, slab, 9.0, 3.4, "Slab2")
	_dress_shelf(22.0, 34.0, 2.6, 1.70, 16)
	_flutes(23.0, 33.0, -6.0, 8.0, 1.62, 6, 0.34, "ice")
	TrailBuilder.jump_arc(geometry, Vector3(17.0, 1.1, 0.0), 1.0, 1.0, 8, 1.0, ICE_VARIANT)

	# 3 — run along the top. 10.
	TrailBuilder.line(geometry, Vector3(24.0, 3.6, 0.0), Vector3(33.0, 3.6, 0.0), 10, ICE_VARIANT)

	# 4 — a dip across a gap. 8.
	LevelKit.platform(geometry, 38.0, 1.4, 16.0, shelf, 8.0, 3.4, "Shelf3")
	_dress_shelf(38.0, 54.0, 1.4, 1.70, 20)
	_pool(Vector3(41.5, 1.4, -1.0), Vector2(3.0, 1.2))
	_flutes(39.0, 53.0, -6.0, 6.4, 1.62, 7, 0.30, "packed")
	TrailBuilder.curve(geometry, Vector3(34.5, 3.6, 0.0), Vector3(40.5, 2.4, 0.0), 1.7, 8, ICE_VARIANT)

	# 5 — a reward ring over an ice arch. 9.
	_arch(Vector3(48.0, 1.4, 0.0), 7.4, 3.4)
	TrailBuilder.cluster(geometry, Vector3(48.0, 5.2, 0.0), 1.0, 8, ICE_VARIANT)

	# 6 — the long shelf. 12.
	LevelKit.platform(geometry, 56.0, 1.4, 24.0, shelf, 8.0, 3.4, "Shelf4")
	_dress_shelf(56.0, 80.0, 1.4, 1.70, 26)
	_pool(Vector3(70.0, 1.4, -1.05), Vector2(5.0, 1.35))
	_flutes(57.0, 79.0, -6.0, 6.4, 1.62, 9, 0.30, "packed")
	TrailBuilder.line(geometry, Vector3(60.0, 2.4, 0.0), Vector3(76.0, 2.4, 0.0), 12, ICE_VARIANT)

	# 7 — up onto a stack. 8.
	LevelKit.platform(geometry, 84.0, 3.8, 11.0, slab, 11.0, 3.4, "Slab5")
	_dress_shelf(84.0, 95.0, 3.8, 1.70, 15)
	_flutes(85.0, 94.0, -7.0, 10.0, 1.62, 6, 0.34, "ice")
	TrailBuilder.jump_arc(geometry, Vector3(78.0, 2.4, 0.0), 1.0, 1.0, 8, 1.0, ICE_VARIANT)

	# 8 — across to the last shelf. 8.
	LevelKit.platform(geometry, 100.0, 3.0, 18.0, shelf, 10.0, 3.4, "Shelf6")
	_dress_shelf(100.0, 118.0, 3.0, 1.70, 22)
	_pool(Vector3(104.0, 3.0, -1.0), Vector2(3.4, 1.25))
	_flutes(101.0, 117.0, -6.8, 8.2, 1.62, 8, 0.30, "packed")
	TrailBuilder.curve(geometry, Vector3(93.0, 4.8, 0.0), Vector3(101.5, 4.0, 0.0), 1.6, 8, ICE_VARIANT)

	# 9 — the last ring. 9.
	_arch(Vector3(109.0, 3.0, 0.0), 6.4, 3.0)
	TrailBuilder.cluster(geometry, Vector3(109.0, 6.6, 0.0), 1.0, 8, ICE_VARIANT)

	# 10 — the run out. 12.
	TrailBuilder.line(geometry, Vector3(102.0, 4.0, 0.0), Vector3(113.0, 4.0, 0.0), 12, ICE_VARIANT)

	LevelKit.box(geometry, Vector3(119.4, 6.0, 0.0), Vector3(1.6, 7.0, 3.4),
		slab, "EndWall")
	# The wall the run ends against: fluted, rimed on top, and dripping.
	_flutes(118.8, 120.0, 2.6, 6.6, 1.58, 4, 0.22, "ice")
	LevelKit.prop(geometry, Vector3(119.4, 9.60, 0.0), Vector3(2.0, 0.30, 3.6),
		m["lip"], "EndWallCap")
	_icicle_fringe(118.8, 120.0, 9.3, 1.75, 6, 1.4, 0.10)
	_drift(Vector3(118.2, 3.0, -1.1), 2.6, 0.7, 1.2, 0.22)

	# 11 — and the last four, stacked, so the hundredth is above his head.
	TrailBuilder.column(geometry, Vector3(114.0, 4.2, 0.0), 2.6, 4, ICE_VARIANT)


## A frozen arch: two legs and a span, with the reward ring sitting over it.
## The span grows the longest icicles in the level, which is the cue that the
## ring underneath is worth flying through.
func _arch(base: Vector3, width: float, height: float) -> void:
	for side: float in [-1.0, 1.0]:
		var leg := LevelKit.prop(geometry,
			base + Vector3(side * width * 0.5, height * 0.5, -2.6),
			Vector3(1.3, height, 1.6), m["ice"], "ArchLeg")
		leg.rotation.z = -side * 0.09
		_drift(base + Vector3(side * width * 0.5, 0.0, -1.9), 2.6, 0.55, 1.5,
			-side * 0.24)
		_flutes(base.x + side * width * 0.5 - 0.4, base.x + side * width * 0.5 + 0.4,
			base.y, height * 0.9, base.z - 1.85, 3, 0.16, "ice")
	var span := LevelKit.prop(geometry, base + Vector3(0.0, height + 0.5, -2.6),
		Vector3(width + 1.6, 1.1, 1.8), m["ice"], "ArchSpan")
	span.rotation.z = 0.0
	LevelKit.prop(geometry, base + Vector3(0.0, height + 1.12, -2.6),
		Vector3(width + 1.9, 0.24, 2.0), m["lip"], "ArchCap")
	_icicle_fringe(base.x - width * 0.5 - 0.6, base.x + width * 0.5 + 0.6,
		base.y + height - 0.06, base.z - 1.78, 16, 1.9, 0.11)


# --- Atmosphere -------------------------------------------------------------

func _atmosphere_ice() -> void:
	# Snow drifting across, plus a low mist that the spires rise out of.
	var p := GPUParticles3D.new()
	p.name = "Snow"
	p.amount = 420
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.fixed_fps = 30
	p.interpolate = true
	p.local_coords = false
	p.position = Vector3(56.0, 12.0, -6.0)
	p.visibility_aabb = AABB(Vector3(-90, -40, -30), Vector3(180, 80, 60))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(80.0, 22.0, 14.0)
	pm.direction = Vector3(-0.8, -1.0, 0.0)
	pm.spread = 24.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(-0.6, -1.6, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 1.6
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	p.process_material = pm

	p.draw_pass_1 = FXKit.sprite_pass(0.075, Color(0.86, 0.95, 1.0),
		{"alpha": 0.55, "additive": false})
	add_child(p)

	# A second flurry between the camera and the action. Big, slow, soft flakes
	# crossing the lens are worth more depth cue than another hundred distant
	# ones, and there is no cheaper parallax anywhere in the renderer.
	var near_p := GPUParticles3D.new()
	near_p.name = "NearFlurry"
	near_p.amount = 90
	near_p.lifetime = 7.0
	near_p.preprocess = 5.0
	near_p.fixed_fps = 30
	near_p.interpolate = true
	near_p.local_coords = false
	near_p.position = Vector3(56.0, 10.0, 7.0)
	near_p.visibility_aabb = AABB(Vector3(-90, -34, -8), Vector3(180, 70, 16))
	var npm := ParticleProcessMaterial.new()
	npm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	npm.emission_box_extents = Vector3(70.0, 16.0, 3.0)
	npm.direction = Vector3(-1.0, -0.8, 0.0)
	npm.spread = 26.0
	npm.initial_velocity_min = 2.4
	npm.initial_velocity_max = 5.0
	npm.gravity = Vector3(-1.4, -2.2, 0.0)
	npm.turbulence_enabled = true
	npm.turbulence_noise_strength = 0.8
	npm.turbulence_noise_scale = 1.1
	npm.scale_min = 1.6
	npm.scale_max = 4.2
	near_p.process_material = npm
	# Alpha-blended, not additive: these cross in front of a white glacier, and
	# an additive flake over white adds nothing.
	near_p.draw_pass_1 = FXKit.sprite_pass(0.075, Color(0.80, 0.90, 1.0),
		{"alpha": 0.26, "additive": false})
	add_child(near_p)

	var fv := FogVolume.new()
	fv.name = "GlacierMist"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	# BEHIND the play plane, not across it. At size 80 centred on z -34 this
	# volume ran from z -74 to z +6 — and the camera sits at about z +16, so
	# the hero was being viewed THROUGH eighty units of it. Volumetric fog is
	# rendered into a low-resolution froxel grid, so what that produced was not
	# atmosphere, it was the whole upper two-thirds of the frame out of focus
	# in every capture of this level. The bottom band stayed sharp because it
	# was the only thing in front of the volume.
	#
	# Now z -79 .. -17: it fogs the serac field, which is what it is for, and
	# nothing between the camera and the action.
	fv.size = Vector3(300.0, 9.0, 62.0)
	fv.position = Vector3(56.0, -6.5, -48.0)
	var fm := FogMaterial.new()
	fm.density = 0.024
	fm.albedo = Color(0.80, 0.90, 1.0)
	fm.emission = Color(0.05, 0.10, 0.20)
	fm.height_falloff = 1.0
	fm.edge_fade = 0.4
	fv.material = fm
	add_child(fv)

	# A denser, colder pool sitting in the crevasse band. The crevasses read as
	# holes because the mist stops at their lips instead of filling them.
	var deep := FogVolume.new()
	deep.name = "CrevasseMist"
	deep.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	deep.size = Vector3(200.0, 5.0, 24.0)
	deep.position = Vector3(62.0, -7.4, -20.0)
	var dfm := FogMaterial.new()
	dfm.density = 0.034
	dfm.albedo = Color(0.72, 0.86, 1.0)
	dfm.emission = Color(0.03, 0.08, 0.18)
	dfm.height_falloff = 1.8
	dfm.edge_fade = 0.5
	deep.material = dfm
	add_child(deep)
