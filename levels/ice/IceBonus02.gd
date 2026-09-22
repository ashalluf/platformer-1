extends IceBonusStage
## ICE BONUS — "THE SHAFT".
##
## Glacier Run is a run. This one is a climb: a frozen chimney with the sky at
## the top of it and the route spiralling up the walls, so the whole level is
## read vertically and the double jump is the verb instead of the dash.
##
## The bottom is deep blue and almost dark; the top is white and blown out.
## That gradient is the level — you can see how far you have left by how bright
## it is around you.
##
## Exactly 100 ICE SRIRACHAS.
##
## READABILITY IS THE BRIEF HERE, not a style note. In a climb the player has to
## answer "can I stand on that" in a single frame, and three rules do it:
##
##   1. Every standable surface is SNOW: the brightest material in the level,
##      with a lip of fresh snow proud of its front edge and a hard shadow
##      immediately under the lip. Bright line over dark line is an edge.
##   2. No standable surface is a slab of snow all the way down. A metre of
##      snow on a dark ice body reads as a ledge; seven metres of snow reads as
##      a wall, and the route is full of seven-metre platforms.
##   3. Nothing else in the level is allowed near the top of the value range.
##      The walls recede in value going back — near chimney darkest, back wall
##      lighter, far shoulder nearly fog — and every shelf additionally gets a
##      darker patch of wall staged directly behind it, so the contrast does
##      not depend on the camera finding a good angle.

const ICE_VARIANT := 1   ## Sriracha.Variant.ICE

## The gradient runs between these two heights, and everything that reads as
## wall is coloured from it.
const SHAFT_BOTTOM := -8.0
const SHAFT_TOP := 54.0

var m := {}

var _rng := RandomNumberGenerator.new()
var _icicles: Array[Transform3D] = []
var _flutes_by_mat: Dictionary = {}
var _wall_cache: Dictionary = {}


func _ready() -> void:
	level_id = "ice_shaft"
	level_title = "THE SHAFT"
	spawn_point = Vector3(0.0, 2.0, 0.0)
	time_limit = 52.0
	music_theme = "ice"
	use_camera_bounds = true
	camera_bounds_min = Vector2(-9.0, -2.0)
	camera_bounds_max = Vector2(9.0, 86.0)
	super._ready()
	camera.height_offset = 2.2
	camera.distance = 17.0


func _mood() -> LightingRig.Mood:
	var mood := LightingRig.Mood.new()
	# The key comes straight down the shaft. Everything else is bounce off blue
	# ice, which is why the walls go violet as they recede.
	mood.sun_angles = Vector2(-78.0, 20.0)
	mood.sun_color = Color(0.92, 0.97, 1.0)
	mood.sun_energy = 3.4
	mood.sun_angular_distance = 0.5
	mood.sun_fog_energy = 4.5
	mood.sun_disc_size = 0.0

	mood.fill_angles = Vector2(12.0, -150.0)
	mood.fill_color = Color(0.30, 0.38, 0.78)
	mood.fill_energy = 0.60

	mood.rim_angles = Vector2(-4.0, 152.0)
	mood.rim_color = Color(0.72, 0.92, 1.0)
	mood.rim_energy = 4.4
	mood.rim_cull_mask = 2
	mood.hero_fill_energy = 1.5
	mood.hero_fill_color = Color(0.82, 0.88, 1.0)
	mood.hero_fill_angles = Vector2(-20.0, -30.0)

	mood.sky_top = Color(0.780, 0.880, 0.980)
	mood.sky_horizon = Color(0.420, 0.560, 0.780)
	mood.ground_horizon = Color(0.120, 0.170, 0.300)
	mood.ground_bottom = Color(0.030, 0.045, 0.100)
	mood.sky_energy = 1.3
	mood.sky_curve = 0.30
	mood.ambient_energy = 0.36

	mood.fog_color = Color(0.480, 0.620, 0.840)
	mood.fog_density = 0.0055
	mood.fog_sun_scatter = 0.40
	mood.fog_emission = Color(0.06, 0.10, 0.22)
	mood.fog_anisotropy = 0.70
	mood.volumetric_density = 0.0070

	# The far shoulder and the peaks beyond the rim are modelled, so they get a
	# real lens response rather than sitting sharp at two hundred metres.
	mood.dof_distance = 56.0
	mood.dof_transition = 48.0
	mood.dof_amount = 0.10

	mood.tonemap = Environment.TONE_MAPPER_ACES
	mood.exposure = 0.90
	mood.white = 7.0
	mood.glow_intensity = 0.50
	mood.glow_hdr_threshold = 1.30
	mood.adjustment_saturation = 1.12
	mood.adjustment_contrast = 1.05
	return mood


func _build_level() -> void:
	_rng.seed = 8821
	_materials()
	_beyond_the_rim()
	_walls()
	_route()
	_foreground()
	_flush_icicles()
	_flush_flutes()
	_atmosphere_shaft()
	_no_prop_shadows()


## Dressing does not cast shadows.
##
## Everything parented straight to `geometry` is decoration; the shadow that
## carries this level is the one a platform throws down the shaft, and that
## comes from the platform bodies, which are StaticBody3D and so are untouched
## by this. Two hundred decorative boxes in the directional shadow atlas is a
## fixed per-frame cost that does not shrink with resolution.
func _no_prop_shadows() -> void:
	for child in geometry.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Materials --------------------------------------------------------------

## One place to build ice. MaterialLab.ice does not set the uniforms that decide
## whether a big mass reads as atmosphere or as a hole in the sky — a 60 m wall
## run through Beer-Lambert at thickness_scale 1.0 comes out opaque navy — so
## everything goes through here and distance costs thickness, then interior
## detail, then sparkle.
func _ice(clarity: float, tint: Color, o := {}) -> ShaderMaterial:
	var mat := MaterialLab.ice(clarity, tint)
	mat.set_shader_parameter("clarity", o.get("clarity", clarity))
	mat.set_shader_parameter("thickness_scale", o.get("thickness", 1.0))
	mat.set_shader_parameter("crack_density", o.get("cracks", 1.0))
	mat.set_shader_parameter("crack_scale", o.get("crack_scale", 0.45))
	mat.set_shader_parameter("bubble_amount", o.get("bubbles", 0.7))
	mat.set_shader_parameter("rime_amount", o.get("rime", 1.0))
	mat.set_shader_parameter("frost_relief", o.get("relief", 0.9))
	mat.set_shader_parameter("sheen", o.get("sheen", 0.6))
	mat.set_shader_parameter("refraction", o.get("refraction", 0.45))
	mat.set_shader_parameter("ice_bright", o.get("bright", Color(0.54, 0.80, 0.97)))
	mat.set_shader_parameter("frost_color", o.get("frost", Color(0.88, 0.94, 1.0)))
	if o.has("sparkle"):
		mat.set_shader_parameter("sparkle_amount", o["sparkle"])
	if bool(o.get("interior", true)):
		mat.set_shader_parameter("interior_fade_start", o.get("fade_start", 13.0))
		mat.set_shader_parameter("interior_fade_end", o.get("fade_end", 30.0))
	else:
		mat.set_shader_parameter("interior_fade_start", 0.1)
		mat.set_shader_parameter("interior_fade_end", 0.2)
	return mat


## Fresh snow and nothing else: no dust, no grime, no warmth. The one material
## allowed at the top of the value range, because it is the line the eye lands
## on when it is looking for the next hold.
func _snow_lip() -> ShaderMaterial:
	return MaterialLab.surface({
		"color": Color(0.93, 0.96, 1.00),
		"variation": Color(0.78, 0.86, 0.97),
		"variation_strength": 0.30,
		"roughness_min": 0.58, "roughness_max": 0.86,
		"mask": NoiseBank.grain(29),
		"normal": NoiseBank.detail_normal(44, 0.22, 1.2),
		"detail_scale": 1.10, "macro_scale": 0.14,
		"normal_strength": 0.80,
		"dust": 0.0, "grime": 0.0,
		"emission": Color(0.44, 0.60, 0.86), "emission_strength": 0.22,
		"ao": 0.28,
	})


func _materials() -> void:
	m = {
		# Standable surfaces. Brightest thing in the level, by law.
		"snow": _ice(0.05, Color(0.780, 0.860, 0.965),
			{"rime": 1.35, "sparkle": 1.8, "relief": 1.3, "interior": false}),
		"lip": _snow_lip(),
		# The body under every standable surface, and the brackets into the wall.
		"body": _ice(0.85, Color(0.030, 0.105, 0.225), {"cracks": 1.25, "sheen": 0.75}),
		# Darkest in the level: the shadow under every lip, and fissures.
		"void": _ice(0.85, Color(0.010, 0.030, 0.078),
			{"thickness": 1.5, "interior": false, "sparkle": 0.0, "refraction": 0.0}),
		"melt": _ice(1.0, Color(0.020, 0.100, 0.215),
			{"sheen": 1.0, "rime": 0.0, "cracks": 0.0, "bubbles": 0.0,
			 "refraction": 0.9, "sparkle": 0.4, "thickness": 0.9}),
		"icicle": _ice(1.0, Color(0.120, 0.360, 0.580),
			{"thickness": 0.55, "interior": false, "sparkle": 4.2, "sheen": 0.9,
			 "refraction": 0.7}),
		# Everything above and beyond the rim.
		"peak": _ice(0.20, Color(0.430, 0.570, 0.760),
			{"thickness": 0.06, "interior": false, "sparkle": 0.0,
			 "refraction": 0.0, "rime": 0.8}),
		"vast": _ice(0.08, Color(0.600, 0.720, 0.880),
			{"thickness": 0.02, "interior": false, "sparkle": 0.0,
			 "refraction": 0.0, "rime": 0.5, "sheen": 0.2}),
	}
	# Flutes are batched by material key, so every key used for one has to exist
	# in `m`. One wall-flute material per height band, taken from the same
	# gradient the wall blocks use, so the ribs climb out of dark into blown
	# white with the wall instead of cutting across it.
	for band in 4:
		m["wall_flute%d" % band] = _wall_mat(SHAFT_BOTTOM + band * 16.0 + 8.0,
			0, true)


## The shaft is a value gradient and the gradient IS the level. Band steps that
## gradient backwards in Z as well:
##
##   0  the near chimney   darkest, full detail
##   1  the back wall      lifted toward fog
##   2  the far shoulder   nearly fog
##   3  staging patch      the local gradient, deliberately darkened, used only
##                         directly behind a shelf so the contrast there never
##                         depends on the camera finding a good angle
##
## Cached in nine steps: a hundred wall blocks do not need a hundred materials.
##
## `unit_scaled` is for flutes. They are instanced from a UNIT cylinder, so
## their model-space extents are half a metre however large they are drawn —
## the shader's thickness term would read every rib as a thin sliver and blow it
## white, which would cut pale stripes straight through the one thing this level
## cannot afford to lose.
func _wall_mat(y: float, band: int, unit_scaled := false) -> ShaderMaterial:
	var step := roundi(clampf(inverse_lerp(SHAFT_BOTTOM, SHAFT_TOP, y), 0.0, 1.0) * 8.0)
	var key := "w%d_%d%s" % [step, band, "f" if unit_scaled else ""]
	if _wall_cache.has(key):
		return _wall_cache[key]

	var t := float(step) / 8.0
	## Positive recedes toward fog; the negative entry is band 3, the staging
	## patch, which goes the other way on purpose.
	var recede: float = [0.0, 0.36, 0.70, -0.34][band]
	# pow() on the way up keeps the bottom third genuinely dark instead of
	# giving the whole shaft a lazy linear ramp.
	var tint := Color(0.004, 0.020, 0.062).lerp(Color(0.62, 0.755, 0.925), pow(t, 1.4))
	if recede > 0.0:
		tint = tint.lerp(Color(0.46, 0.63, 0.87), recede)
	else:
		tint = tint.darkened(-recede)

	var mat := _ice(lerpf(0.92, 0.12, t), tint, {
		"thickness": maxf(lerpf(1.30, 0.16, t) * (1.0 - maxf(recede, 0.0) * 0.85)
			* (9.0 if unit_scaled else 1.0), 0.03),
		# Only the near wall, and only in the dark half, is worth marching: that
		# is where an interior can be seen at all.
		"interior": band == 0 and t < 0.55,
		"sparkle": lerpf(2.4, 0.5, t) * (1.0 - maxf(recede, 0.0)),
		"cracks": 1.15,
		"rime": lerpf(0.45, 1.45, t),
	})
	_wall_cache[key] = mat
	return mat


# --- Primitive vocabulary ---------------------------------------------------

## Icicles. Every overhang in a cold place grows them, and under the front lip
## of a shelf they draw a hard bright-over-dark line exactly where the player
## reads the edge. They cluster — an evenly spaced fringe reads as a comb.
## Collected and emitted as one MultiMesh.
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.add_child(mi)
	_icicles.clear()


## Wind-carved flutes: vertical channels cut into a big ice face, and the only
## scale reference a sixty-metre wall has. Batched per material key — a whole
## wall of them is one instanced draw.
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


## Snow piles on the leeward side of anything that stops the wind. A drift at
## the foot of a box is the cheapest way to stop the box looking placed.
func _drift(at: Vector3, length: float, height: float, depth: float,
		lean := 0.16) -> void:
	var d := LevelKit.prop(geometry, at + Vector3(0.0, height * 0.32, 0.0),
		Vector3(length, height, depth), m["snow"], "Drift")
	d.rotation = Vector3(0.0, _rng.randf_range(-0.3, 0.3), lean)


## Sastrugi: one wind, blowing for months, carves the snow into hard parallel
## ridges. Kept off the walk line so the player never clips through one.
func _sastrugi(left: float, right: float, y: float, z_min: float, z_max: float,
		count: int) -> void:
	for _i in count:
		var ridge := LevelKit.prop(geometry,
			Vector3(_rng.randf_range(left, right), y + 0.04,
				_rng.randf_range(z_min, z_max)),
			Vector3(_rng.randf_range(1.2, 3.2), 0.12,
				_rng.randf_range(0.24, 0.55)), m["lip"], "Sastruga")
		ridge.rotation.y = _rng.randf_range(-0.12, 0.12)


## Meltwater. What sells a pool is not the water, it is the bright refrozen
## collar around it — on a flat white top it is the only hard bright line.
func _pool(at: Vector3, size: Vector2) -> void:
	LevelKit.prop(geometry, at + Vector3(0.0, 0.03, 0.0),
		Vector3(size.x + 0.7, 0.16, size.y + 0.7), m["lip"], "PoolRim")
	LevelKit.prop(geometry, at, Vector3(size.x, 0.12, size.y), m["melt"], "Pool")


# --- Beyond the rim ---------------------------------------------------------

## Two things the player can only see once they are near the top: a range of
## peaks and one enormous mass behind them. The pay-off for the climb is that
## the world opens, so there has to be a world to open into.
func _beyond_the_rim() -> void:
	for i in 9:
		var h := _rng.randf_range(26.0, 74.0)
		var w := _rng.randf_range(22.0, 58.0)
		var peak := LevelKit.prop(geometry,
			Vector3(-190.0 + i * 48.0 + _rng.randf_range(-9.0, 9.0), 20.0 + h * 0.5,
				_rng.randf_range(-150.0, -108.0)),
			Vector3(w, h, 24.0), m["peak"], "Peak%d" % i)
		peak.rotation = Vector3(0.0, _rng.randf_range(-0.4, 0.4),
			_rng.randf_range(-0.09, 0.09))

	# The mass behind everything. Stepped, because ice does not make cones — it
	# makes a stack of shelves the wind has rounded off.
	for i in 5:
		var t := float(i) / 4.0
		LevelKit.prop(geometry,
			Vector3(-40.0 + 16.0 * t, 8.0 + 150.0 * t * 0.78,
				-300.0 + 26.0 * t),
			Vector3(330.0 * (1.0 - t * 0.76), 48.0 - t * 5.0, 90.0 * (1.0 - t * 0.6)),
			m["vast"], "MassifStep%d" % i)
	_flutes(-180.0, 110.0, 8.0, 86.0, -258.0, 14, 5.0, "vast")


# --- The chimney ------------------------------------------------------------

func _walls() -> void:
	# Band 0 — the chimney itself. Blocks stacked with a rhythm so the climb has
	# a measurable height rather than sliding past a smooth tube, and the odd
	# one jutting inward so the wall has overhangs to hang ice off.
	for side: float in [-1.0, 1.0]:
		var y := SHAFT_BOTTOM
		while y < 58.0:
			var h := _rng.randf_range(2.4, 5.2)
			var d := _rng.randf_range(0.0, 1.6)
			var jut := _rng.randf() < 0.24
			var w := 6.4 + d + (1.7 if jut else 0.0)
			var cx := side * (9.2 + d * 0.5 - (0.85 if jut else 0.0))
			var blk := LevelKit.prop(geometry, Vector3(cx, y + h * 0.5, -5.5),
				Vector3(w, h, 8.0), _wall_mat(y + h * 0.5, 0), "WallA")
			blk.rotation.z = _rng.randf_range(-0.045, 0.045)
			if jut:
				var inner := cx - side * w * 0.5
				_icicle_fringe(inner + side * 0.1, inner - side * 1.7,
					y - 0.05, -1.58, 7, 1.5, 0.11)
			y += h
		# Fluting in four height bands rather than one run: a sixty-metre
		# unbroken channel is a rod, and real flutes are interrupted every time
		# the wall steps.
		for band in 4:
			_flutes(side * 6.4, side * 11.2, SHAFT_BOTTOM + band * 16.0, 15.0,
				-1.45, 7, 0.34, "wall_flute%d" % band)

	# Band 1 — the back of the shaft. Without it you see sky through the gap
	# between the two side walls, and the whole thing reads as two stacks of
	# boxes instead of a hole in a mountain.
	var yb := SHAFT_BOTTOM
	while yb < 53.0:
		var hb := _rng.randf_range(3.0, 6.5)
		LevelKit.prop(geometry,
			Vector3(_rng.randf_range(-2.5, 2.5), yb + hb * 0.5, -13.5),
			Vector3(_rng.randf_range(28.0, 42.0), hb, 7.0),
			_wall_mat(yb + hb * 0.5, 1), "WallBack")
		yb += hb

	# Band 2 — the far shoulder. Nearly fog; it exists so the chimney has
	# something to be a notch in.
	for side2: float in [-1.0, 1.0]:
		var yc := SHAFT_BOTTOM
		while yc < 64.0:
			var hc := _rng.randf_range(5.0, 11.0)
			LevelKit.prop(geometry,
				Vector3(side2 * _rng.randf_range(20.0, 29.0), yc + hc * 0.5, -31.0),
				Vector3(_rng.randf_range(14.0, 26.0), hc, 14.0),
				_wall_mat(yc + hc * 0.5, 2), "WallFar")
			yc += hc

	# Fissures: vertical slots of the darkest material, half sunk into the near
	# wall face. A wall with a crack in it has a thickness; a wall without one
	# is a panel.
	for i in 8:
		var fside := -1.0 if i % 2 == 0 else 1.0
		var fy := -6.0 + i * 7.6 + _rng.randf_range(-2.0, 2.0)
		var fh := _rng.randf_range(4.0, 9.5)
		LevelKit.prop(geometry,
			Vector3(fside * _rng.randf_range(6.2, 9.0), fy + fh * 0.5, -1.9),
			Vector3(_rng.randf_range(0.45, 1.2), fh, 1.2), m["void"], "Fissure%d" % i)
		_icicle_fringe(fside * 6.4, fside * 8.6, fy + fh, -1.55, 5, 1.2, 0.08)

	# The floor of the shaft, far below, so a fall reads as a fall.
	LevelKit.prop(geometry, Vector3(0.0, -9.0, -6.0), Vector3(30.0, 4.0, 18.0),
		_wall_mat(SHAFT_BOTTOM, 0), "ShaftFloor")


# --- The route --------------------------------------------------------------

## The climb: eight turns of a spiral, alternating sides, each landing visible
## from the one below it. 100 bottles exactly. Positions and counts are tuned —
## everything `_dress_rung` adds is decoration and none of it collides.
func _route() -> void:
	# 0 — the floor of the shaft. 10.
	LevelKit.platform(geometry, -6.0, 0.0, 12.0, m["snow"], 8.0, 3.4, "Base")
	_dress_rung(0.0, 0.0, 12.0, 8.0, 22)
	_pool(Vector3(-3.4, 0.0, -1.05), Vector2(3.2, 1.25))
	TrailBuilder.line(geometry, Vector3(-4.0, 1.0, 0.0), Vector3(4.0, 1.0, 0.0),
		10, ICE_VARIANT)

	# 1..8 — the spiral. Each rung is a shelf off one wall with a cluster over
	# it; the count per rung is tuned so the total lands on 100.
	var rungs := [
		[-4.6, 4.4, 5.0, 9], [3.8, 8.2, 5.0, 9], [-4.2, 12.4, 5.4, 9],
		[3.6, 16.6, 5.0, 9], [-4.6, 21.0, 5.4, 9], [3.8, 25.4, 5.0, 9],
		[-4.2, 30.0, 5.4, 9], [3.6, 34.6, 5.0, 9],
	]
	var prev := Vector3(0.0, 1.0, 0.0)
	for i in rungs.size():
		var r: Array = rungs[i]
		var left: float = r[0] - r[2] * 0.5
		LevelKit.platform(geometry, left, r[1], r[2], m["snow"], 7.0, 3.4,
			"Rung%d" % i)
		_dress_rung(r[0], r[1], r[2], 7.0, 11)
		var over := Vector3(r[0], r[1] + 2.3, 0.0)
		TrailBuilder.curve(geometry, prev + Vector3(0.0, 0.4, 0.0), over, 1.5,
			int(r[3]), ICE_VARIANT)
		prev = over

	# 9 — the last stretch is a straight column of bottles up the middle, which
	# is the one moment the level asks for the double jump twice in a row. 18.
	LevelKit.platform(geometry, -2.2, 39.6, 4.4, m["snow"], 7.0, 3.4, "Ledge")
	_dress_rung(0.0, 39.6, 4.4, 7.0, 10)
	TrailBuilder.column(geometry, Vector3(0.0, 41.0, 0.0), 9.0, 18, ICE_VARIANT)

	# 10 — the lip, in daylight. 4.
	LevelKit.platform(geometry, -5.0, 51.0, 10.0, m["snow"], 9.0, 3.6, "Lip")
	_dress_rung(0.0, 51.0, 10.0, 9.0, 20, 3.6)
	TrailBuilder.line(geometry, Vector3(-3.0, 52.0, 0.0), Vector3(2.0, 52.0, 0.0),
		4, ICE_VARIANT)


## Everything that makes a platform legible as a platform. See the three rules
## in the file header — this function is where all three are enforced.
func _dress_rung(cx: float, top: float, w: float, thickness: float,
		icicles := 12, depth := 3.4) -> void:
	var left := cx - w * 0.5
	var right := cx + w * 0.5
	var front := depth * 0.5

	# Rule 2: snow on a dark ice body. The body is a shell three centimetres
	# proud of the platform, so everything below half a metre from the top is
	# hidden by it. Read down the front face the stack is now
	#   bright lip / white snow edge / black contact line / deep blue body,
	# which is a ledge. Seven metres of unbroken white is a wall.
	LevelKit.prop(geometry,
		Vector3(cx, top - 0.50 - (thickness - 0.50) * 0.5, 0.0),
		Vector3(w + 0.06, thickness - 0.50, depth + 0.06), m["body"], "RungBody")

	# Rule 1: the lip, proud of the front edge, and a hard shadow under it.
	LevelKit.prop(geometry, Vector3(cx, top + 0.11, front - 0.16),
		Vector3(w + 0.45, 0.26, 0.56), m["lip"], "RungLip")
	LevelKit.prop(geometry, Vector3(cx, top - 0.44, front - 0.01),
		Vector3(w + 0.30, 0.28, 0.22), m["void"], "RungShadow")
	_icicle_fringe(left + 0.25, right - 0.25, top - 0.62, front - 0.04, icicles)

	# Rule 3: a darker patch of wall staged directly behind the shelf.
	LevelKit.prop(geometry, Vector3(cx, top + 1.5, -3.6),
		Vector3(w + 3.2, 5.2, 1.1), _wall_mat(top, 3), "RungBacking")

	# A bracket into the wall, so the shelf grows out of the chimney rather than
	# floating in it. Dead centre shelves get one on each side.
	var sides: Array = [1.0, -1.0] if absf(cx) < 1.0 else [signf(cx)]
	for s: float in sides:
		var br := LevelKit.prop(geometry,
			Vector3(cx + s * w * 0.42, top - 1.7, -2.3),
			Vector3(w * 0.55, 2.8, 2.4), m["body"], "RungBracket")
		br.rotation.z = -s * 0.22
		_drift(Vector3(cx + s * w * 0.30, top, -1.05), w * 0.34, 0.42, 0.95,
			-s * 0.16)
	_sastrugi(left + 0.5, right - 0.5, top, -1.42, -0.72, 2)
	_flutes(left + 0.4, right - 0.4, top - thickness + 0.4, thickness - 1.4,
		front - 0.08, maxi(3, int(w / 1.8)), 0.17, "body")


# --- Foreground -------------------------------------------------------------

## Brows of ice jutting in from both sides in front of the gameplay plane. They
## crop at the frame edges, which frames the climb and gives the camera
## something to travel past — the cheapest parallax in the renderer.
func _foreground() -> void:
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var y := 2.0 + i * 6.4 + _rng.randf_range(-1.6, 1.6)
		var brow := LevelKit.prop(geometry,
			Vector3(side * _rng.randf_range(9.6, 11.6), y, 3.4),
			Vector3(_rng.randf_range(2.6, 4.4), _rng.randf_range(1.4, 2.6),
				_rng.randf_range(1.6, 2.6)), m["body"], "Brow%d" % i)
		brow.rotation = Vector3(0.0, _rng.randf_range(-0.6, 0.6),
			-side * _rng.randf_range(0.1, 0.35))
		_icicle_fringe(side * 9.2, side * 11.4, y - 0.9, 3.9, 6, 1.6, 0.11)


# --- Atmosphere -------------------------------------------------------------

func _atmosphere_shaft() -> void:
	# A column of light down the middle of the shaft, and spindrift falling
	# through it. Both exist to make the vertical readable.
	var fv := FogVolume.new()
	fv.name = "ShaftLight"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(14.0, 70.0, 12.0)
	fv.position = Vector3(0.0, 26.0, -3.0)
	var fm := FogMaterial.new()
	fm.density = 0.030
	fm.albedo = Color(0.88, 0.95, 1.0)
	fm.emission = Color(0.04, 0.07, 0.14)
	fm.height_falloff = 0.0
	fm.edge_fade = 0.35
	fv.material = fm
	add_child(fv)

	# Blown-out haze at the rim. The top of the level is supposed to be hard to
	# look at; this is the thing that makes the last few metres feel like
	# climbing out into daylight rather than arriving at another ledge.
	var rim := FogVolume.new()
	rim.name = "RimGlare"
	rim.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	rim.size = Vector3(46.0, 26.0, 30.0)
	rim.position = Vector3(0.0, 54.0, -8.0)
	var rfm := FogMaterial.new()
	rfm.density = 0.075
	rfm.albedo = Color(0.95, 0.98, 1.0)
	rfm.emission = Color(0.30, 0.42, 0.62)
	rfm.height_falloff = -0.6
	rfm.edge_fade = 0.55
	rim.material = rfm
	add_child(rim)

	# And a cold, dense pool at the floor, so the bottom of the shaft reads as
	# depth rather than as the end of the geometry.
	var sump := FogVolume.new()
	sump.name = "Sump"
	sump.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	sump.size = Vector3(34.0, 12.0, 22.0)
	sump.position = Vector3(0.0, -5.0, -6.0)
	var sfm := FogMaterial.new()
	sfm.density = 0.11
	sfm.albedo = Color(0.58, 0.74, 0.96)
	sfm.emission = Color(0.012, 0.030, 0.075)
	sfm.height_falloff = 1.6
	sfm.edge_fade = 0.45
	sump.material = sfm
	add_child(sump)

	var p := GPUParticles3D.new()
	p.name = "Spindrift"
	p.amount = 340
	p.lifetime = 11.0
	p.preprocess = 10.0
	p.fixed_fps = 30
	p.local_coords = false
	p.position = Vector3(0.0, 56.0, -2.0)
	p.visibility_aabb = AABB(Vector3(-16, -70, -16), Vector3(32, 80, 32))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(8.0, 1.0, 5.0)
	pm.direction = Vector3(0.1, -1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0.2, -1.2, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 1.4
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.92, 0.97, 1.0, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true

	# Big, slow flakes crossing the lens between the camera and the climb. There
	# is no cheaper depth cue anywhere in the renderer.
	var near_p := GPUParticles3D.new()
	near_p.name = "NearFlurry"
	near_p.amount = 80
	near_p.lifetime = 8.0
	near_p.preprocess = 6.0
	near_p.fixed_fps = 30
	near_p.local_coords = false
	near_p.position = Vector3(0.0, 50.0, 7.0)
	near_p.visibility_aabb = AABB(Vector3(-18, -64, -8), Vector3(36, 76, 16))
	var npm := ParticleProcessMaterial.new()
	npm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	npm.emission_box_extents = Vector3(11.0, 2.0, 3.0)
	npm.direction = Vector3(0.2, -1.0, 0.0)
	npm.spread = 20.0
	npm.initial_velocity_min = 2.0
	npm.initial_velocity_max = 4.4
	npm.gravity = Vector3(0.5, -2.0, 0.0)
	npm.turbulence_enabled = true
	npm.turbulence_noise_strength = 0.9
	npm.turbulence_noise_scale = 1.1
	npm.scale_min = 1.8
	npm.scale_max = 4.4
	near_p.process_material = npm
	var nquad := QuadMesh.new()
	nquad.size = Vector2(0.07, 0.07)
	var nmat := StandardMaterial3D.new()
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	nmat.albedo_color = Color(0.86, 0.93, 1.0, 0.24)
	nmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	nmat.disable_receive_shadows = true
	nquad.material = nmat
	near_p.draw_pass_1 = nquad
	add_child(near_p)
