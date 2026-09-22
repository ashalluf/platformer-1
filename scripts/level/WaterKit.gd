class_name WaterKit
## Sea and ice-sheet builder.
##
## Every body of water in World 1 comes from here: the Gulf of Sidra behind
## Brega, the Mediterranean off the Benghazi corniche, and the frozen sea in
## the ICE bonus levels. One shader serves all of them — `ice_amount`
## cross-fades open water to a frozen shelf — so the two never drift apart in
## look or in maintenance.
##
## The thing to understand before tuning any of this: our camera sits four to
## fourteen units above the waterline and looks along the surface at water a
## hundred to three hundred units away. The sea occupies a band a few percent
## of screen height tall. Wave amplitude barely registers; the glitter path,
## the Fresnel sky reflection and the aerial haze carry the whole read. Author
## against that view, not against a top-down preview.

const WATER_SHADER := preload("res://shaders/water.gdshader")

## Target size of one mesh cell, in world units.
##
## Along X we want roughly eight segments across the primary swell (40-46
## units) so the crest silhouette is a curve rather than a sawtooth. Along Z
## the grazing view compresses everything brutally — ten units of depth at the
## far edge of the sea is a fraction of a pixel — so Z can be far coarser than
## X without any visible cost. This asymmetry is where the vertex budget goes.
const CELL_X := 5.0
const CELL_Z := 8.0

## PlaneMesh subdivision ceilings. A 400-unit sea lands at 80 x 25, which is
## about 2,000 vertices — background geometry should not cost more than that.
const MAX_SUB_X := 100
const MAX_SUB_Z := 48

## Width of the surf strip, centred on the waterline.
const SURF_STRIP_WIDTH := 9.0


## World-space direction TO the sun, from the same `Vector2(pitch, yaw)` in
## degrees that `LightingRig.Mood.sun_angles` uses. Levels should always derive
## the water's sun from the rig's rather than typing a vector twice: a glitter
## path pointing somewhere the key light isn't is the fastest way to make an
## expensive sea look fake.
##
## The number to know when framing: for a camera looking down -Z, the glitter
## path lands at (180 - yaw) degrees to screen-right, and the frame only
## reaches about 29 degrees each side at our 34-degree FOV. Yaw 150 puts the
## path at 30 degrees — just off the edge. Yaw 160 puts it on the right third.
static func sun_from_angles(angles: Vector2) -> Vector3:
	# A DirectionalLight3D shines down its local -Z, so +Z of the same basis
	# points back at the sun. Euler order must match Node3D's (YXZ).
	var b := Basis.from_euler(
		Vector3(deg_to_rad(angles.x), deg_to_rad(angles.y), 0.0), EULER_ORDER_YXZ)
	return b.z.normalized()


## Point an existing water material at a sun, keeping colour and direction in
## step. `energy` scales the glitter so a level can dim the path without
## touching the preset.
static func aim_sun(mat: ShaderMaterial, angles: Vector2, color: Color, energy := -1.0) -> void:
	mat.set_shader_parameter("sun_direction", sun_from_angles(angles))
	mat.set_shader_parameter("sun_color", color)
	if energy >= 0.0:
		mat.set_shader_parameter("glitter_energy", energy)


# --- Presets ----------------------------------------------------------------

## Water material by name. Returns a fresh material every call so two seas in
## one level can be tuned apart.
##
## Presets:
##   "gulf_dawn" — the Gulf of Sidra behind Brega at 05:52. Backlit by a 2200 K
##                 sun three degrees off the horizon; the specular path is the
##                 brightest thing in the far half of the frame.
##   "gulf_day"  — the same water under a high clear sun. Full turquoise over
##                 white sand falling off a hard shelf to lapis.
##   "frozen"    — the ICE bonus sea. Swell frozen mid-motion, refracted
##                 internal cracks, no foam.
static func material(preset: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	match preset:
		"gulf_dawn": _gulf_dawn(m)
		"gulf_day": _gulf_day(m)
		"frozen": _frozen(m)
		_:
			push_warning("WaterKit: unknown preset '%s', falling back to gulf_day" % preset)
			_gulf_day(m)
	return m


static func _common(m: ShaderMaterial) -> void:
	# Ripples are a rolling mid-frequency field, not grain: at nine world units
	# per tile the features land around 0.6 units, which is the size of real
	# wind chop and small enough to disappear into roughness by the far edge.
	m.set_shader_parameter("ripple_normal", NoiseBank.detail_normal(131, 0.030, 1.4))
	m.set_shader_parameter("ripple_scale", 0.11)
	m.set_shader_parameter("ripple_speed", 0.05)
	m.set_shader_parameter("ripple_fade_start", 45.0)
	m.set_shader_parameter("ripple_fade_end", 280.0)
	m.set_shader_parameter("specular_value", 0.25)
	m.set_shader_parameter("strip_amount", 0.0)
	m.set_shader_parameter("ice_amount", 0.0)


static func _gulf_dawn(m: ShaderMaterial) -> void:
	_common(m)
	# Swell rolling onshore, i.e. toward +Z, so the crests run along X and read
	# as horizontal bands in the compressed view. Anything angled more than
	# this turns the horizon into a herringbone.
	m.set_shader_parameter("wind_dir", Vector2(0.30, 0.95))
	m.set_shader_parameter("wave_length", 46.0)
	# 0.42 units at 150 units away is about five pixels of vertical wander at
	# 1080p. Measured against the grazing view, not chosen from a top-down one.
	m.set_shader_parameter("wave_amplitude", 0.42)
	m.set_shader_parameter("wave_steepness", 0.34)
	m.set_shader_parameter("wave_spread", 0.45)
	m.set_shader_parameter("wave_speed", 1.0)
	m.set_shader_parameter("ripple_strength", 0.62)

	# Knocked back from the daytime turquoise: the sun has not reached the
	# water yet, and at this hour the sea is mostly reflecting a dark sky.
	m.set_shader_parameter("shallow_color", Color(0.232, 0.560, 0.565))
	m.set_shader_parameter("deep_color", Color(0.062, 0.175, 0.268))
	# What the band reflects away from the sun, and therefore the colour of
	# nine tenths of the sea. Cool on purpose: a real dawn sea is blue-grey
	# everywhere except in the path, and the shader warms it back toward the
	# sun colour along the sun's azimuth on its own. Reflecting a flat orange
	# here is what makes a CG sea look like bronze sheet metal.
	m.set_shader_parameter("sky_color", Color(0.60, 0.63, 0.72))
	m.set_shader_parameter("sky_reflect", 1.0)
	m.set_shader_parameter("fresnel_power", 3.8)
	m.set_shader_parameter("fresnel_strength", 0.94)
	m.set_shader_parameter("roughness_near", 0.05)
	m.set_shader_parameter("roughness_far", 0.26)

	m.set_shader_parameter("shelf_hardness", 0.66)
	m.set_shader_parameter("shelf_distance", 55.0)
	m.set_shader_parameter("surf_width", 7.0)
	m.set_shader_parameter("surf_amount", 0.70)

	m.set_shader_parameter("foam_noise", NoiseBank.grain(101))
	# Dawn foam is not white. It is lit by an orange sun and a blue sky and it
	# sits a long way down the value scale from Wanis's thobe.
	m.set_shader_parameter("foam_color", Color(0.88, 0.87, 0.85))
	m.set_shader_parameter("foam_scale", 0.16)
	m.set_shader_parameter("foam_amount", 0.85)
	m.set_shader_parameter("foam_threshold", 0.19)
	m.set_shader_parameter("foam_softness", 0.16)

	# BregaKit's key is at yaw 150, which puts the sun 30 degrees right of the
	# camera axis — and with a 34-degree vertical FOV the frame only reaches 29
	# degrees to the side, so the physically-correct glitter path lands just off
	# the right edge of frame. The water's sun is therefore cheated 11 degrees
	# round to yaw 161, which drops the path onto the right-third line. The rig
	# keeps the true angle; only the specular is moved. This is an old film
	# trick and it is the single most valuable number in this preset — if a
	# level reframes, move it, do not turn the glitter up.
	aim_sun(m, Vector2(-3.5, 161.0), Color(1.0, 0.565, 0.251), 6.0)
	# At this exponent the hot core is about 1.5 degrees wide and the gated
	# halo about 8, which at 1080p is a 100 px core inside a 500 px shimmer.
	m.set_shader_parameter("glitter_spread", 48.0)
	m.set_shader_parameter("glitter_sharpness", 1100.0)
	m.set_shader_parameter("sparkle_density", 2.4)
	m.set_shader_parameter("sparkle_threshold", 0.976)

	# Matches BregaKit.mood()'s fog colour, so the band sits into the horizon
	# instead of in front of it.
	m.set_shader_parameter("haze_color", Color(0.835, 0.804, 0.741))
	m.set_shader_parameter("haze_begin", 80.0)
	m.set_shader_parameter("haze_end", 400.0)
	m.set_shader_parameter("haze_strength", 0.62)


static func _gulf_day(m: ShaderMaterial) -> void:
	_gulf_dawn(m)
	m.set_shader_parameter("wave_amplitude", 0.34)
	m.set_shader_parameter("wave_length", 40.0)
	m.set_shader_parameter("ripple_strength", 0.70)

	# The art direction's Gulf: clear and pale over white sand, then off a
	# shelf to lapis, with a hard line between them rather than a gradient.
	m.set_shader_parameter("shallow_color", Color(0.310, 0.765, 0.753))
	m.set_shader_parameter("deep_color", Color(0.106, 0.310, 0.447))
	m.set_shader_parameter("sky_color", Color(0.66, 0.74, 0.86))
	m.set_shader_parameter("sky_reflect", 1.15)
	m.set_shader_parameter("shelf_hardness", 0.74)
	m.set_shader_parameter("roughness_far", 0.30)

	m.set_shader_parameter("foam_color", Color(0.94, 0.95, 0.94))
	m.set_shader_parameter("foam_amount", 1.0)
	m.set_shader_parameter("surf_amount", 0.85)

	# Level 2's key: 4900 K, 34 degrees up and to screen-right. A high sun has
	# no long path in it — the mirror point sits six units from the camera and
	# there is nothing left by the time the water is a hundred out. That is
	# what a real midday Mediterranean looks like from a low angle, so this
	# preset leans on Fresnel and foam instead and keeps only a broad sheen:
	# spread comes right down so the lobe still covers the band, and the energy
	# with it. Turning glitter up here to compensate is how you get tinfoil.
	aim_sun(m, Vector2(34.0, 118.0), Color(1.0, 0.855, 0.735), 2.6)
	m.set_shader_parameter("glitter_spread", 16.0)
	m.set_shader_parameter("glitter_sharpness", 420.0)

	m.set_shader_parameter("haze_color", Color(0.850, 0.816, 0.745))
	m.set_shader_parameter("haze_strength", 0.50)


static func _frozen(m: ShaderMaterial) -> void:
	_common(m)
	m.set_shader_parameter("ice_amount", 1.0)

	# Shorter and steeper than open water, because what we want is the memory
	# of a choppy sea caught mid-motion. Time stops at ice_amount 1.0, so
	# these values are read as relief, not as animation.
	m.set_shader_parameter("wind_dir", Vector2(0.72, 0.69))
	m.set_shader_parameter("wave_length", 30.0)
	m.set_shader_parameter("wave_amplitude", 0.62)
	m.set_shader_parameter("wave_steepness", 0.30)
	m.set_shader_parameter("wave_spread", 0.60)
	m.set_shader_parameter("ripple_strength", 0.35)

	m.set_shader_parameter("shallow_color", Color(0.46, 0.66, 0.80))
	m.set_shader_parameter("deep_color", Color(0.05, 0.20, 0.36))
	m.set_shader_parameter("sky_color", Color(0.62, 0.75, 0.93))
	m.set_shader_parameter("sky_reflect", 1.05)
	m.set_shader_parameter("fresnel_power", 4.4)
	m.set_shader_parameter("fresnel_strength", 0.90)
	m.set_shader_parameter("roughness_near", 0.05)
	m.set_shader_parameter("roughness_far", 0.22)
	# Under the ice there is no shelf worth drawing a line for; the depth term
	# becomes a slow tonal drift from the shore out to the horizon.
	m.set_shader_parameter("shelf_hardness", 0.22)
	m.set_shader_parameter("shelf_distance", 120.0)

	# Cellular noise, not fbm: its cell boundaries are already a fracture
	# network, which is exactly what a frozen sea surface is.
	m.set_shader_parameter("foam_noise", NoiseBank.pits(103))
	m.set_shader_parameter("foam_amount", 0.0)
	m.set_shader_parameter("surf_amount", 0.0)
	m.set_shader_parameter("surf_width", 5.0)

	m.set_shader_parameter("ice_color", Color(0.84, 0.91, 0.98))
	m.set_shader_parameter("crack_color", Color(0.58, 0.80, 0.95))
	m.set_shader_parameter("crack_scale", 0.26)
	m.set_shader_parameter("crack_power", 16.0)
	m.set_shader_parameter("crack_amount", 0.60)
	m.set_shader_parameter("crack_depth", 0.50)
	m.set_shader_parameter("frost_amount", 0.28)

	# The ICE levels' key is at yaw 138 — 42 degrees off the camera axis, which
	# is well outside the frame — so the specular is cheated round to 158 for
	# the same reason as gulf_dawn. Glints on ice are sparser and harder than
	# glints on water: fewer facets, and every one of them a mirror.
	aim_sun(m, Vector2(-8.0, 158.0), Color(0.76, 0.90, 1.0), 5.0)
	m.set_shader_parameter("glitter_spread", 90.0)
	m.set_shader_parameter("glitter_sharpness", 1600.0)
	m.set_shader_parameter("sparkle_density", 3.2)
	m.set_shader_parameter("sparkle_threshold", 0.968)

	m.set_shader_parameter("haze_color", Color(0.588, 0.729, 0.878))
	m.set_shader_parameter("haze_begin", 60.0)
	m.set_shader_parameter("haze_end", 320.0)
	m.set_shader_parameter("haze_strength", 0.62)


# --- Builders ---------------------------------------------------------------

## A sea. `size` is (X extent, Z extent) in world units; `centre` is the centre
## of the water plane, with Y the still waterline.
##
## The shoreward edge is the +Z edge — the one nearest the camera — and the
## shader's shelf is anchored there automatically, so water deepens away from
## the viewer. A "SurfLine" strip is parented to the returned node, centred on
## that waterline; move it in local space to put the break where the level's
## beach actually is, or free it if the sea has no shore in frame.
static func sea(parent: Node3D, centre: Vector3, size: Vector2,
		preset := "gulf_dawn") -> MeshInstance3D:
	var mat := material(preset)
	var shore_z := centre.z + size.y * 0.5
	mat.set_shader_parameter("shore_z", shore_z)

	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = _plane(size, subdivisions(size))
	mi.material_override = mat
	mi.position = centre
	# Animated geometry must never bake into a VoxelGI or it leaves ghost
	# lighting behind it, and a sea a hundred units out has no business in a
	# shadow map tuned to 50.
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Vertex displacement pushes verts outside the mesh AABB; without a margin
	# the whole sea pops out of view at the edge of frame.
	mi.extra_cull_margin = 4.0
	parent.add_child(mi)

	# An ice sheet has no surf line, so it does not get one.
	if preset != "frozen":
		# 0.12 rather than a hair's breadth: the strip is finer in Z than the sea
		# is, so the two chord the same wave differently and the sea can sit up
		# to about 0.06 above it in a trough. At 150 units that is one pixel.
		var surf := surf_line(mi, Vector3(0.0, 0.12, size.y * 0.5), size.x, preset, shore_z)
		surf.name = "SurfLine"
	return mi


## The breaking line at the waterline: a thin foam strip, alpha everywhere it
## is not foam, so it lies over both the sea and the sand without a seam.
## `world_shore_z` is the absolute Z the wash centres on — pass the sea's, so
## the strip and the sea agree about where the coast is.
static func surf_line(parent: Node3D, local_pos: Vector3, length: float,
		preset := "gulf_dawn", world_shore_z := 0.0) -> MeshInstance3D:
	var mat := material(preset)
	mat.set_shader_parameter("strip_amount", 1.0)
	mat.set_shader_parameter("shore_z", world_shore_z)
	# Half the strip width, so the wash peaks on the line and has faded out by
	# the strip's own edges — no hard rectangle anywhere.
	mat.set_shader_parameter("surf_width", SURF_STRIP_WIDTH * 0.5)
	mat.set_shader_parameter("surf_amount", 1.0)
	mat.set_shader_parameter("foam_amount", 1.2)
	# Forced after the sea in the transparent queue. The two are near enough
	# coplanar that distance sorting alone flickers between them.
	mat.render_priority = 1

	var size := Vector2(length, SURF_STRIP_WIDTH)
	var mi := MeshInstance3D.new()
	mi.name = "SurfLine"
	mi.mesh = _plane(size, Vector2i(subdivisions(size).x, 4))
	mi.material_override = mat
	mi.position = local_pos
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	parent.add_child(mi)
	return mi


## Mesh resolution for a water plane of this size — enough for the swell to
## read as a curve, and not one vertex more. See CELL_X / CELL_Z.
static func subdivisions(size: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(size.x / CELL_X), 4, MAX_SUB_X),
		clampi(int(size.y / CELL_Z), 2, MAX_SUB_Z))


static func _plane(size: Vector2, sub: Vector2i) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = size
	p.subdivide_width = sub.x
	p.subdivide_depth = sub.y
	p.orientation = PlaneMesh.FACE_Y
	return p
