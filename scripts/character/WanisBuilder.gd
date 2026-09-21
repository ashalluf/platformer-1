class_name WanisBuilder
## Builds Wanis.
##
## The camera is side-on, so what matters is the profile in the local Z/Y plane:
## the hair mass, the nose, the beard line, the chest jutting forward, the jacket
## hem, and the chain arcing off the front. Width across X is nearly invisible
## and is spent only on keeping limbs from intersecting.
##
## Everything is lofted from ring lists. Tuning the silhouette means editing
## numbers in this file and looking at the next capture.

const HEIGHT := 1.78

enum B {
	ROOT, HIPS, SPINE, CHEST, NECK, HEAD,
	SHOULDER_L, ARM_L, FOREARM_L, HAND_L,
	SHOULDER_R, ARM_R, FOREARM_R, HAND_R,
	THIGH_L, SHIN_L, FOOT_L,
	THIGH_R, SHIN_R, FOOT_R,
}

## name, parent, offset from parent (rest)
const BONES := [
	["Root", -1, Vector3(0, 0, 0)],
	["Hips", B.ROOT, Vector3(0, 0.88, 0)],
	["Spine", B.HIPS, Vector3(0, 0.18, 0)],
	["Chest", B.SPINE, Vector3(0, 0.18, 0)],
	["Neck", B.CHEST, Vector3(0, 0.17, 0)],
	["Head", B.NECK, Vector3(0, 0.09, 0)],
	["ShoulderL", B.CHEST, Vector3(-0.07, 0.13, 0)],
	["ArmL", B.SHOULDER_L, Vector3(-0.135, 0.00, 0)],
	["ForearmL", B.ARM_L, Vector3(0, -0.27, 0)],
	["HandL", B.FOREARM_L, Vector3(0, -0.25, 0)],
	["ShoulderR", B.CHEST, Vector3(0.07, 0.13, 0)],
	["ArmR", B.SHOULDER_R, Vector3(0.135, 0.00, 0)],
	["ForearmR", B.ARM_R, Vector3(0, -0.27, 0)],
	["HandR", B.FOREARM_R, Vector3(0, -0.25, 0)],
	["ThighL", B.HIPS, Vector3(-0.072, -0.05, 0)],
	["ShinL", B.THIGH_L, Vector3(0, -0.40, 0)],
	["FootL", B.SHIN_L, Vector3(0, -0.36, 0)],
	["ThighR", B.HIPS, Vector3(0.072, -0.05, 0)],
	["ShinR", B.THIGH_R, Vector3(0, -0.40, 0)],
	["FootR", B.SHIN_R, Vector3(0, -0.36, 0)],
]

## Costume states. Level 1 opens in PRISON and transforms to STREET mid-level.
enum Outfit { STREET, PRISON }

const HEAD_CENTER := Vector3(0.0, 1.590, 0.012)
const HEAD_RADIUS := Vector3(0.168, 0.190, 0.186)

## Skull profile: jaw pushed forward, crown drawn back. Shared with the hair so
## the two surfaces are concentric and neither can punch through the other.
static var HEAD_SHAPE: Callable = func(t: float, _y: float) -> Dictionary:
	var jaw := 1.0 - smoothstep(0.0, 0.42, t)
	var crown := smoothstep(0.48, 1.0, t)
	return {
		"sx": 1.0 - 0.06 * crown - 0.10 * jaw,
		"sz": 1.0 + 0.06 * crown - 0.02 * jaw,
		"offset": Vector3(0.0, 0.0, 0.026 * jaw - 0.022 * crown),
	}


static func build_skeleton() -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton"
	for spec: Array in BONES:
		var i := sk.add_bone(spec[0])
		sk.set_bone_parent(i, spec[1])
		sk.set_bone_rest(i, Transform3D(Basis(), spec[2]))
	sk.reset_bone_poses()
	return sk


# --- Palette ----------------------------------------------------------------

static func palette(outfit: Outfit) -> Dictionary:
	if outfit == Outfit.PRISON:
		return {
			"skin": Color(0.72, 0.50, 0.34),
			"thobe": Color(0.46, 0.45, 0.42),
			"trouser": Color(0.40, 0.39, 0.37),
			"hair": Color(0.07, 0.06, 0.06),
			"shoe": Color(0.28, 0.26, 0.24),
		}
	return {
		"skin": Color(0.74, 0.50, 0.32),
		# Near-white, warmed slightly. He is the brightest value in every frame
		# he is in — that is the readability strategy for the whole game.
		"thobe": Color(0.955, 0.945, 0.915),
		"trouser": Color(0.60, 0.58, 0.53),
		"hair": Color(0.055, 0.048, 0.050),
		"shoe": Color(0.34, 0.22, 0.13),
	}


const THOBE_SHADER := preload("res://shaders/cloth_billow.gdshader")


## The thobe gets its own shader so it can billow. Vertex colour carries the
## hem weight, so the robe inflates from the hem up and the shoulders stay put.
static func thobe_material(tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = THOBE_SHADER
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("roughness_value", 0.86)
	m.set_shader_parameter("rim_strength", 0.55)
	m.set_shader_parameter("rim_tint", Color(1.0, 0.92, 0.80))
	m.set_shader_parameter("billow", 0.0)
	m.set_shader_parameter("billow_spread", 0.34)
	m.set_shader_parameter("flutter", 0.045)
	m.set_shader_parameter("flutter_speed", 9.0)
	m.set_shader_parameter("weave_scale", 26.0)
	m.set_shader_parameter("weave_depth", 0.22)
	return m


## Deep madder red with a warm rim. Kept under the project chroma cap for the
## world but above it for the hero, which is the whole readability strategy.
static func shemagh_material() -> ShaderMaterial:
	var m := thobe_material(Color(0.60, 0.115, 0.085))
	m.set_shader_parameter("roughness_value", 0.80)
	m.set_shader_parameter("rim_strength", 0.85)
	m.set_shader_parameter("rim_tint", Color(1.0, 0.62, 0.45))
	m.set_shader_parameter("billow_spread", 0.16)
	m.set_shader_parameter("flutter", 0.055)
	m.set_shader_parameter("trail_reach", 0.46)
	m.set_shader_parameter("weave_scale", 20.0)
	m.set_shader_parameter("weave_depth", 0.16)
	return m


static func materials(outfit: Outfit) -> Dictionary:
	var p := palette(outfit)
	var hair := MaterialLab.cloth(p["hair"], 0.74)
	hair.rim = 0.28
	hair.rim_tint = 0.10
	hair.metallic_specular = 0.12
	hair.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {
		"skin": MaterialLab.skin(p["skin"]),
		"thobe": thobe_material(p["thobe"]),
		"trouser": MaterialLab.cloth(p["trouser"], 0.88),
		"hair": hair,
		"shemagh": shemagh_material(),
		"shoe": MaterialLab.cloth(p["shoe"], 0.55),
		"gold": MaterialLab.gold(),
		"dark": MaterialLab.cloth(Color(0.04, 0.04, 0.05), 0.25),
	}


# --- Mesh -------------------------------------------------------------------

static func _w(bones: Array, weights: Array) -> Array:
	return [bones, weights]


## Build the whole character. Returns {mesh, surface_names}.
static func build_mesh(outfit: Outfit) -> Dictionary:
	var mesh := ArrayMesh.new()
	var names: Array[String] = []

	_append(mesh, names, "skin", _build_skin())
	_append(mesh, names, "trouser", _build_trousers())
	_append(mesh, names, "thobe", _build_thobe(outfit))
	if outfit == Outfit.STREET:
		_append(mesh, names, "shemagh", _build_shemagh())
	_append(mesh, names, "hair", _build_hair(outfit))
	_append(mesh, names, "shoe", _build_feet())
	_append(mesh, names, "dark", _build_shades())
	return {"mesh": mesh, "surfaces": names}


static func _append(mesh: ArrayMesh, names: Array[String], key: String,
		builder: MeshForge.Builder) -> void:
	builder.st.generate_normals()
	builder.st.generate_tangents()
	builder.st.commit(mesh)
	names.append(key)


# --- Head, neck, arms, hands ------------------------------------------------

static func _build_skin() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	var head_b := [B.HEAD]
	var head_w := [1.0]

	b.blob(HEAD_CENTER, HEAD_RADIUS, head_b, head_w, 12, 22, 2.25, HEAD_SHAPE)

	# Nose — small, but it is most of the silhouette's personality.
	b.blob(Vector3(0.0, 1.572, 0.176), Vector3(0.042, 0.058, 0.066),
		head_b, head_w, 6, 10, 2.0)
	# Ears, visible in profile.
	for side: float in [-1.0, 1.0]:
		b.blob(Vector3(side * 0.156, 1.594, -0.022), Vector3(0.028, 0.052, 0.044),
			head_b, head_w, 5, 8, 2.2)

	# Neck — short and thick. A long neck reads as fragile at this size.
	b.loft([
		MeshForge.ring(Vector3(0, 1.33, 0.004), 0.078, 0.082, [B.CHEST, B.NECK], [0.5, 0.5], 2.4),
		MeshForge.ring(Vector3(0, 1.40, 0.006), 0.073, 0.077, [B.NECK], [1.0], 2.4),
		MeshForge.ring(Vector3(0, 1.46, 0.008), 0.070, 0.074, [B.NECK, B.HEAD], [0.5, 0.5], 2.4),
	], 12, false, false)

	# Wrists and hands. The forearms are inside the thobe sleeves.
	for side: int in [-1, 1]:
		var fa: int = B.FOREARM_L if side < 0 else B.FOREARM_R
		var hd: int = B.HAND_L if side < 0 else B.HAND_R
		var x := side * 0.205
		b.loft([
			MeshForge.ring(Vector3(x, 0.96, 0), 0.052, 0.054, [fa], [1.0], 2.3),
			MeshForge.ring(Vector3(x, 0.88, 0), 0.045, 0.047, [fa, hd], [0.5, 0.5], 2.3),
		], 12, true, false)
		b.blob(Vector3(x, 0.815, 0.008), Vector3(0.048, 0.062, 0.056), [hd], [1.0], 7, 12, 2.4)
	return b


# --- Thobe ------------------------------------------------------------------

## The thobe: a single A-line robe from collar to mid-calf, weighted to the
## spine and hips so the legs stride out from under it instead of dragging it
## around. Vertex colour R is the billow weight (0 at the collar, 1 at the hem)
## and G is a per-ring phase offset so the flutter is not in lockstep.
static func _build_thobe(outfit: Outfit) -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()

	var hem_y := 0.44 if outfit == Outfit.STREET else 0.52
	var flare := 1.0 if outfit == Outfit.STREET else 0.72

	# y, rx, rz, bones, weights
	var spec := [
		[1.45, 0.124, 0.130, [B.NECK, B.CHEST], [0.45, 0.55]],
		[1.41, 0.190, 0.196, [B.CHEST], [1.0]],
		[1.33, 0.192, 0.214, [B.CHEST], [1.0]],
		[1.20, 0.178, 0.208, [B.CHEST, B.SPINE], [0.55, 0.45]],
		[1.06, 0.166, 0.192, [B.SPINE], [1.0]],
		[0.94, 0.172, 0.188, [B.SPINE, B.HIPS], [0.4, 0.6]],
		[0.80, 0.184, 0.192, [B.HIPS], [1.0]],
		[0.68, 0.194, 0.200, [B.HIPS], [1.0]],
		[0.56, 0.204, 0.210, [B.HIPS], [1.0]],
		[hem_y + 0.04, 0.212, 0.218, [B.HIPS], [1.0]],
		[hem_y, 0.216, 0.222, [B.HIPS], [1.0]],
	]

	var rings := []
	var top_y: float = spec[0][0]
	var bottom_y: float = spec[spec.size() - 1][0]
	for i in spec.size():
		var e: Array = spec[i]
		var y: float = e[0]
		var t := clampf(inverse_lerp(top_y, bottom_y, y), 0.0, 1.0)
		# Hem weight ramps in over the lower two thirds and squares off, so the
		# shoulders never move and the skirt does all the work.
		var hem_w: float = pow(smoothstep(0.25, 1.0, t), 1.35)
		var rx: float = lerpf(e[1], e[1] * (1.0 + 0.04 * flare), hem_w)
		var rz: float = lerpf(e[2], e[2] * (1.0 + 0.04 * flare), hem_w)
		var r := MeshForge.ring(Vector3(0, y, 0), rx, rz, e[3], e[4], 2.5)
		r["color"] = Color(hem_w, fmod(float(i) * 0.37, 1.0), 0.0, 1.0)
		rings.append(r)
	b.loft(rings, 20, true, false)

	# Sleeves: full length, wide at the cuff. They catch the wind too.
	for side: int in [-1, 1]:
		var sh: int = B.SHOULDER_L if side < 0 else B.SHOULDER_R
		var ar: int = B.ARM_L if side < 0 else B.ARM_R
		var fa: int = B.FOREARM_L if side < 0 else B.FOREARM_R
		var hd: int = B.HAND_L if side < 0 else B.HAND_R
		var x := side * 0.205
		var sleeve := [
			MeshForge.ring(Vector3(side * 0.160, 1.41, 0), 0.088, 0.094, [sh, B.CHEST], [0.65, 0.35], 2.4),
			MeshForge.ring(Vector3(x, 1.32, 0), 0.078, 0.084, [ar, sh], [0.7, 0.3], 2.4),
			MeshForge.ring(Vector3(x, 1.18, 0), 0.072, 0.078, [ar], [1.0], 2.4),
			MeshForge.ring(Vector3(x, 1.08, 0), 0.072, 0.078, [ar, fa], [0.45, 0.55], 2.4),
			MeshForge.ring(Vector3(x, 0.98, 0), 0.074, 0.082, [fa], [1.0], 2.4),
			MeshForge.ring(Vector3(x, 0.91, 0), 0.062, 0.068, [fa, hd], [0.8, 0.2], 2.4),
		]
		for i in sleeve.size():
			var w := clampf(float(i) / float(sleeve.size() - 1), 0.0, 1.0)
			sleeve[i]["color"] = Color(0.22 + pow(w, 1.6) * 0.58, fmod(float(i) * 0.23, 1.0), 0.0, 1.0)
		b.loft(sleeve, 12, true, true)

	return b


## The shemagh: over the shoulder and down the back, clear of the robe so it
## reads in profile. It is the only saturated colour Wanis carries, and the
## thing that tells you which way he was moving a quarter-second ago.
static func _build_shemagh() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	# y, z, rx, rz, bones, weights
	var spec := [
		[1.44, -0.170, 0.052, 0.062, [B.CHEST], [1.0]],
		[1.32, -0.225, 0.048, 0.082, [B.CHEST], [1.0]],
		[1.16, -0.262, 0.046, 0.094, [B.CHEST, B.SPINE], [0.5, 0.5]],
		[1.00, -0.282, 0.044, 0.098, [B.SPINE], [1.0]],
		[0.86, -0.292, 0.041, 0.096, [B.SPINE, B.HIPS], [0.4, 0.6]],
		[0.72, -0.292, 0.036, 0.086, [B.HIPS], [1.0]],
		[0.60, -0.284, 0.029, 0.068, [B.HIPS], [1.0]],
		[0.52, -0.274, 0.020, 0.046, [B.HIPS], [1.0]],
	]
	var rings := []
	for i in spec.size():
		var e: Array = spec[i]
		var t := float(i) / float(spec.size() - 1)
		var r := MeshForge.ring(Vector3(0.028, e[0], e[1]), e[2], e[3], e[4], e[5], 2.4)
		# Trail weight ramps fast: the tail whips, the shoulder does not.
		r["color"] = Color(pow(t, 0.85), fmod(float(i) * 0.41, 1.0), 0.0, 1.0)
		rings.append(r)
	b.loft(rings, 12, true, true)
	return b


# --- Legs -------------------------------------------------------------------

## Sirwal under the thobe. Mostly hidden; what shows below the hem carries a
## value step down from the robe so the hem line stays crisp.
static func _build_trousers() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	for side: int in [-1, 1]:
		var th: int = B.THIGH_L if side < 0 else B.THIGH_R
		var sn: int = B.SHIN_L if side < 0 else B.SHIN_R
		var ft: int = B.FOOT_L if side < 0 else B.FOOT_R
		var x := side * 0.072
		b.loft([
			MeshForge.ring(Vector3(x, 0.88, 0), 0.084, 0.096, [B.HIPS, th], [0.5, 0.5], 2.5),
			MeshForge.ring(Vector3(x, 0.70, 0), 0.080, 0.094, [th], [1.0], 2.5),
			MeshForge.ring(Vector3(x, 0.52, 0), 0.076, 0.090, [th, sn], [0.5, 0.5], 2.5),
			MeshForge.ring(Vector3(x, 0.36, 0), 0.070, 0.086, [sn], [1.0], 2.5),
			MeshForge.ring(Vector3(x, 0.22, 0), 0.062, 0.078, [sn], [1.0], 2.5),
			MeshForge.ring(Vector3(x, 0.14, 0), 0.054, 0.068, [sn, ft], [0.6, 0.4], 2.5),
		], 12, true, false)
	return b


## Bare feet in sandals. The sole is deliberately a readable slab: below a white
## hem, it is the only thing separating him from the ground in silhouette.
static func _build_feet() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	for side: int in [-1, 1]:
		var ft: int = B.FOOT_L if side < 0 else B.FOOT_R
		var sn: int = B.SHIN_L if side < 0 else B.SHIN_R
		var x := side * 0.072
		b.loft([
			MeshForge.ring(Vector3(x, 0.125, 0.004), 0.050, 0.058, [sn, ft], [0.4, 0.6], 2.4),
			MeshForge.ring(Vector3(x, 0.075, 0.012), 0.050, 0.070, [ft], [1.0], 2.6),
			MeshForge.ring(Vector3(x, 0.042, 0.030), 0.052, 0.098, [ft], [1.0], 3.0),
		], 12, true, false)
		b.loft([
			MeshForge.ring(Vector3(x, 0.036, 0.028), 0.055, 0.115, [ft], [1.0], 3.6),
			MeshForge.ring(Vector3(x, 0.014, 0.030), 0.058, 0.122, [ft], [1.0], 3.8),
			MeshForge.ring(Vector3(x, 0.003, 0.030), 0.054, 0.118, [ft], [1.0], 3.8),
		], 12, false, true)
	return b


# --- Hair, beard ------------------------------------------------------------

static func _build_hair(outfit: Outfit) -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	var head_b := [B.HEAD]
	var head_w := [1.0]

	# An open shell wrapping the skull from one temple round the back to the
	# other, leaving the face clear. The open edge IS the hairline.
	var hair_shape := func(t: float, y: float) -> Dictionary:
		var base: Dictionary = HEAD_SHAPE.call(t, y)
		# Thicker toward the crown, thinning to nothing at the nape.
		# 0.14 at the crown made the skull a helmet. Real hair on a man who has
		# been in a cell is a few millimetres of mass, not a few centimetres.
		var thick := 1.0 + lerpf(0.012, 0.055, smoothstep(0.30, 0.95, t))
		return {
			"sx": base["sx"] * thick,
			"sz": base["sz"] * thick,
			"offset": base["offset"] + Vector3(0.0, 0.0, -0.012 * smoothstep(0.4, 1.0, t)),
		}
	b.blob(HEAD_CENTER, HEAD_RADIUS, head_b, head_w, 12, 24, 2.25,
		# The hairline sits high at the temples. Starting it at a third of the
		# way up the skull put hair across his cheekbone.
		hair_shape, PI * 0.78, TAU * 0.745, 0.395, 1.0)

	# The shell is open across a 92-degree arc so the face can exist, and that
	# gap runs all the way to the crown — which left him with a forehead half
	# the height of his head. This is the hairline: a flat mass laid across the
	# brow, closing the gap at the front only.
	b.blob(Vector3(0.0, 1.700, 0.104), Vector3(0.152, 0.036, 0.098),
		head_b, head_w, 6, 14, 2.7)
	b.blob(Vector3(0.0, 1.724, 0.070), Vector3(0.160, 0.040, 0.132),
		head_b, head_w, 6, 14, 2.5)

	# Three small lifts in the crown, breaking the shell's outline without
	# leaving it. Anything approaching the head's own radius turns the whole
	# silhouette into a bunch of grapes, which is exactly what happened before.
	for lump: Array in [
			[Vector3(-0.006, 1.706, -0.034), Vector3(0.068, 0.030, 0.066)],
			[Vector3(0.050, 1.686, -0.118), Vector3(0.056, 0.038, 0.052)],
			[Vector3(-0.052, 1.652, -0.132), Vector3(0.054, 0.040, 0.050)],
		]:
		b.blob(lump[0], lump[1], head_b, head_w, 6, 10, 2.15)

	if outfit == Outfit.STREET:
		# Beard: follows the jaw, squared off at the chin.
		var beard_shape := func(t: float, _y: float) -> Dictionary:
			var low := 1.0 - smoothstep(0.0, 0.5, t)
			return {"sx": 1.0 - 0.18 * low, "sz": 1.0 - 0.10 * low,
				"offset": Vector3(0.0, 0.0, 0.016 * low)}
		# Flat and low: it follows the jaw and stops at the cheekbone. The old
		# one was a sphere the size of the skull and it ate the whole face.
		b.blob(Vector3(0.0, 1.492, 0.038), Vector3(0.150, 0.068, 0.166),
			head_b, head_w, 8, 16, 2.6, beard_shape)
		# Moustache, separate so the mouth line survives.
		b.blob(Vector3(0.0, 1.542, 0.142), Vector3(0.050, 0.015, 0.048),
			head_b, head_w, 5, 10, 2.4)
	else:
		# Prison: heavier, unkempt.
		b.blob(Vector3(0.0, 1.494, 0.034), Vector3(0.152, 0.080, 0.170),
			head_b, head_w, 8, 16, 2.4)
	return b


## The dark surface: eyes, brows, and the aviators pushed up on the forehead.
##
## He had no face at all before this. At the distance the gameplay camera uses
## a face is two dark marks and a brow — but without them the head is a ball,
## and in a close frame it is the first thing anyone looks for.
static func _build_shades() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	var head_b := [B.HEAD]
	var head_w := [1.0]

	for side: float in [-1.0, 1.0]:
		# Eye: a flattened almond set into the socket, not sitting on the face.
		# Set INTO the socket: a sphere on the surface of the face reads as a
		# bolt-on eye, which is worse than no eye at all.
		b.blob(Vector3(side * 0.066, 1.612, 0.138),
			Vector3(0.030, 0.017, 0.012), head_b, head_w, 5, 10, 2.8)
		# Brow: heavy and close to the eye. It is the whole expression.
		b.blob(Vector3(side * 0.070, 1.652, 0.140),
			Vector3(0.043, 0.011, 0.015), head_b, head_w, 4, 10, 3.0)

	# The aviators are gone. Front-on they stacked a third horizontal black bar
	# above the brow and the hairline, and a face reading as three dark bands
	# is not a face. If they come back they go on the chest pocket.
	return b
