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
		# The dark surface carries the eyes AND the brows, so its roughness is a
		# compromise: low enough that the eye takes a hard catchlight off the key
		# — which is the single cheapest thing that turns a black bead into a
		# living eye — and not so low that the brows read as wet.
		"dark": MaterialLab.cloth(Color(0.045, 0.042, 0.050), 0.17),
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


# --- Surface placement helpers ----------------------------------------------

## A point on a lofted blob's surface, in the same parameters `Builder.blob`
## sweeps: `t` runs 0 at the bottom pole to 1 at the top, `theta` runs round the
## cross-section with PI/2 facing forward (+Z) and 0 at +X.
##
## Detail masses go on through this rather than through hand-guessed world
## coordinates. Guessing is how the hair ended up as a helmet: a lump authored by
## eye at the head's centre depth sits entirely INSIDE the mass it was meant to
## disturb and contributes nothing but triangles, and there is no way to tell
## from the numbers that it happened.
static func _on_blob(center: Vector3, radius: Vector3, shape: Callable,
		roundness: float, t: float, theta: float) -> Vector3:
	var phi := PI * t
	var rx := radius.x * sin(phi)
	var rz := radius.z * sin(phi)
	var off := Vector3.ZERO
	if shape.is_valid():
		var m: Dictionary = shape.call(t, -cos(phi))
		rx *= float(m.get("sx", 1.0))
		rz *= float(m.get("sz", 1.0))
		off = m.get("offset", Vector3.ZERO)
	var c := cos(theta)
	var s := sin(theta)
	var e := 2.0 / roundness
	return center + off + Vector3(
		signf(c) * pow(absf(c), e) * rx,
		-cos(phi) * radius.y,
		signf(s) * pow(absf(s), e) * rz)


## Sink a detail mass into its parent so exactly `stand` metres of it protrude.
## `reach` is the ellipsoid's support along the outward direction, so an elongated
## lump laid flat against a surface still clears it by the amount asked for
## instead of disappearing.
static func _lump(b: MeshForge.Builder, anchor: Vector3, parent: Vector3,
		radius: Vector3, stand: float, bones: Array, weights: Array,
		rings := 5, segs := 9, roundness := 2.2) -> void:
	var out := (anchor - parent).normalized()
	var reach := sqrt(pow(out.x * radius.x, 2.0) + pow(out.y * radius.y, 2.0)
		+ pow(out.z * radius.z, 2.0))
	b.blob(anchor - out * maxf(reach - stand, 0.0), radius, bones, weights,
		rings, segs, roundness)


# --- Head, neck, arms, hands ------------------------------------------------

static func _build_skin() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	var head_b := [B.HEAD]
	var head_w := [1.0]

	# 14 rings rather than 12: at 12 the skull had no cross-section at all
	# between y 1.669 and y 1.714, which is exactly the forehead — the one
	# stretch of the head with no feature on it to hide a 45 mm shading gap.
	b.blob(HEAD_CENTER, HEAD_RADIUS, head_b, head_w, 14, 24, 2.25, HEAD_SHAPE)
	_face(b, head_b, head_w)
	_ears(b, head_b, head_w)

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
			MeshForge.ring(Vector3(x, 0.895, 0), 0.045, 0.047, [fa, hd], [0.5, 0.5], 2.3),
		], 12, true, false)
		_hand(b, x, side, hd)
	return b


## The face.
##
## Nothing here is subtracted — the whole character is additive lofts — so an eye
## socket is not a hole cut in the skull. It is the untouched skull left standing
## between a brow ridge, a nose bridge and a cheekbone that have all been pushed
## forward around it. Build the walls and the hollow appears for free.
##
## Read the depth ladder at the eye line as a list, because every number below is
## tuned against it: bare skull 0.185, eyeball 0.194, brow ridge 0.199, lower lid
## 0.199, upper lid 0.202, brow hair 0.207.
##
## The gaps used to be 4 mm and the first render came back with the whole midface
## covered in black speckle. Two large, nearly parallel surfaces sitting 4 mm
## apart do not read as two planes — they graze, and every crevice between them
## fills with contact shadow and ambient occlusion until the face looks like it
## has been sprayed with soot. A mass either clears its neighbour by 8 mm or more
## and reads as its own plane, or it stays decisively inside and is not built at
## all. There is no useful middle, and tangency is the failure mode to design
## against on an additive character.
static func _face(b: MeshForge.Builder, hb: Array, hw: Array) -> void:
	for side: float in [-1.0, 1.0]:
		# Brow ridge. The most valuable mass on the head and the only feature up
		# here that survives a pure PROFILE view, where it is the step between
		# forehead and nose root. Wide in X and thin in Y: a ridge, not a lump.
		# With the key light at -28 degrees it drops a shadow into the socket,
		# which is where the whole expression comes from.
		b.blob(Vector3(side * 0.070, 1.650, 0.171), Vector3(0.056, 0.020, 0.028),
			hb, hw, 5, 8, 2.9)
		# Cheekbone. This one is honest about being a three-quarter feature — it
		# runs across X and profile barely sees it. It earns its place anyway: it
		# is the outer wall of the socket and the thing that stops the midface
		# reading as a balloon under any light that moves.
		b.blob(Vector3(side * 0.092, 1.577, 0.155), Vector3(0.043, 0.032, 0.035),
			hb, hw, 5, 8, 2.6)
		# Lids. A bead on its own is a bead in a hole; these overhang it top and
		# bottom so what shows is a 12 mm almond with a lash line. The upper lid
		# is the heavier and the more forward of the two, which is true of every
		# real eye and is what makes the gaze read as level rather than startled.
		b.blob(Vector3(side * 0.068, 1.629, 0.179), Vector3(0.036, 0.013, 0.023),
			hb, hw, 4, 8, 2.7)
		b.blob(Vector3(side * 0.067, 1.590, 0.177), Vector3(0.034, 0.012, 0.022),
			hb, hw, 4, 8, 2.7)
		# Nose wing. Gives the nose a base instead of letting it taper away into
		# the cheek, and it is the only thing on the head casting a nostril
		# shadow — which in profile is what separates nose from lip.
		b.blob(Vector3(side * 0.038, 1.552, 0.178), Vector3(0.025, 0.022, 0.032),
			hb, hw, 4, 7, 2.5)
		# Nasolabial. The fold is the VALLEY where this meets the muzzle below,
		# not a line on either of them. Additive geometry cannot cut a crease, so
		# both walls get built and the crease is what is left between them.
		b.blob(Vector3(side * 0.059, 1.532, 0.164), Vector3(0.026, 0.034, 0.030),
			hb, hw, 4, 7, 2.4)

	# Nose bridge, brow to tip. Four millimetres proud of the forehead is enough:
	# all a bridge has to do at this scale is keep the two sockets apart.
	b.blob(Vector3(0.0, 1.634, 0.176), Vector3(0.024, 0.030, 0.026), hb, hw, 4, 7, 2.6)
	b.blob(Vector3(0.0, 1.604, 0.181), Vector3(0.027, 0.030, 0.030), hb, hw, 4, 7, 2.6)
	# Nose — small, but it is most of the silhouette's personality.
	#
	# Shorter and higher than it was. At centre 1.572 with a 58 mm half-height it
	# reached down to y 1.514, which is BELOW the upper lip, so the tip hung out
	# over the moustache and hid it everywhere except the last centimetre at each
	# end. A front-on ray-cast of the head is what caught it — a nose is the one
	# feature you cannot judge from its own numbers, because it is always the
	# frontmost thing on the face and always wins whatever it overlaps.
	b.blob(Vector3(0.0, 1.585, 0.176), Vector3(0.040, 0.050, 0.062), hb, hw, 6, 10, 2.0)

	# The muzzle: one barrel carrying both lips, so they sit on a mass instead of
	# being stuck flat onto the front of the skull.
	b.blob(Vector3(0.0, 1.527, 0.174), Vector3(0.054, 0.024, 0.028), hb, hw, 5, 10, 2.5)
	# Upper and lower lip as separate masses. Where the two meet is the mouth
	# line, and a seam between two forms holds up under a moving light in a way
	# that a painted line never does. Both sit proud of the beard by 7 mm so the
	# mouth stays a skin island instead of being swallowed.
	b.blob(Vector3(0.0, 1.5215, 0.188), Vector3(0.036, 0.0105, 0.024), hb, hw, 4, 10, 2.6)
	b.blob(Vector3(0.0, 1.5005, 0.185), Vector3(0.032, 0.012, 0.023), hb, hw, 4, 10, 2.5)
	# Chin. Mostly buried under the beard, but it gives the beard something to sit
	# on so the jaw does not read as a bag hanging off the mouth.
	b.blob(Vector3(0.0, 1.476, 0.163), Vector3(0.048, 0.027, 0.026), hb, hw, 4, 9, 2.7)


## The ear.
##
## Side-on this lands in the middle of the head's silhouette, which makes it the
## most-looked-at secondary form on the character. A featureless bump there is the
## cheapest-looking thing on the model, and it is directly in the eyeline.
static func _ears(b: MeshForge.Builder, hb: Array, hw: Array) -> void:
	for side: float in [-1.0, 1.0]:
		# The plate — flattened against the skull, not a ball stuck to it, and set
		# 6 mm further out than it was so it still clears the hair shell by 13 mm
		# rather than 8. The ear is a silhouette feature; it cannot be a bump
		# that the hair nearly swallows.
		b.blob(Vector3(side * 0.164, 1.596, -0.022), Vector3(0.025, 0.052, 0.042),
			hb, hw, 5, 8, 2.4)
		# Helix, as four beads round the rim. MeshForge sweeps rings in the XZ
		# plane, so a rim that loops through Y and Z cannot be lofted at all;
		# four small masses buy the same read for the same triangle count.
		for p: Array in [
				[Vector3(side * 0.172, 1.634, -0.004), Vector3(0.013, 0.015, 0.017)],
				[Vector3(side * 0.170, 1.630, -0.046), Vector3(0.013, 0.014, 0.018)],
				[Vector3(side * 0.166, 1.606, -0.062), Vector3(0.013, 0.019, 0.014)],
				[Vector3(side * 0.163, 1.578, -0.052), Vector3(0.012, 0.017, 0.013)],
			]:
			b.blob(p[0], p[1], hb, hw, 4, 6, 2.3)
		# Tragus and lobe. Two small notches, and between them they are the only
		# thing that tells a viewer which way the ear is facing.
		b.blob(Vector3(side * 0.157, 1.592, 0.010), Vector3(0.015, 0.014, 0.013),
			hb, hw, 4, 6, 2.4)
		b.blob(Vector3(side * 0.159, 1.556, -0.030), Vector3(0.017, 0.017, 0.017),
			hb, hw, 4, 6, 2.6)


## One hand.
##
## At the gameplay camera's distance four separate fingers are wasted triangles.
## The thumb and the knuckle break are not: those two are the entire difference
## between a hand and a mitten in PROFILE, where the palm's width across X is
## invisible and only the front-to-back outline survives.
static func _hand(b: MeshForge.Builder, x: float, side: int, hd: int) -> void:
	var bn := [hd]
	var wt := [1.0]
	# Palm, ending in a bulge ring followed immediately by a pinch. That pair is
	# the whole trick — one notch in the outline exactly where fingers begin.
	b.loft([
		MeshForge.ring(Vector3(x, 0.870, 0.004), 0.023, 0.043, bn, wt, 2.8),
		MeshForge.ring(Vector3(x, 0.834, 0.008), 0.026, 0.050, bn, wt, 3.0),
		MeshForge.ring(Vector3(x, 0.800, 0.010), 0.027, 0.053, bn, wt, 3.2),
		MeshForge.ring(Vector3(x, 0.789, 0.011), 0.023, 0.046, bn, wt, 3.0),
	], 10, true, false)
	# Fused finger mass, curled forward the way a relaxed hand hangs. Tapered to
	# a soft end rather than a flat cap, which catches a hard specular and is the
	# giveaway on every procedural hand.
	b.loft([
		MeshForge.ring(Vector3(x, 0.789, 0.011), 0.024, 0.048, bn, wt, 3.0),
		MeshForge.ring(Vector3(x, 0.760, 0.017), 0.023, 0.046, bn, wt, 3.0),
		MeshForge.ring(Vector3(x, 0.736, 0.025), 0.021, 0.040, bn, wt, 2.8),
		MeshForge.ring(Vector3(x, 0.722, 0.031), 0.015, 0.027, bn, wt, 2.6),
	], 10, false, true)
	# Thumb — forward and inboard, deliberately clear of the finger mass so a
	# sliver of background shows between the two. Negative space inside the
	# silhouette is what the art direction asks for everywhere else on him and
	# the hand is where it is cheapest to get.
	b.loft([
		MeshForge.ring(Vector3(x - float(side) * 0.005, 0.826, 0.030), 0.014, 0.016, bn, wt, 2.4),
		MeshForge.ring(Vector3(x - float(side) * 0.009, 0.804, 0.044), 0.013, 0.015, bn, wt, 2.4),
		MeshForge.ring(Vector3(x - float(side) * 0.012, 0.782, 0.050), 0.010, 0.012, bn, wt, 2.4),
	], 8, true, true)


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
	# Silhouette: broad at the shoulder, nipped at the waist, flared at the hem.
	# It was none of those -- shoulders measured ~0.50 across against a ~0.43
	# hem, which is a straight column, and a straight column under a robe reads
	# as a cone with a head on it. Widening the chest and taking the waist in
	# costs nothing and is most of what makes a character read at silhouette
	# size, which is the size this camera works at.
	var spec := [
		[1.45, 0.124, 0.130, [B.NECK, B.CHEST], [0.45, 0.55]],
		[1.41, 0.222, 0.204, [B.CHEST], [1.0]],
		[1.33, 0.226, 0.222, [B.CHEST], [1.0]],
		[1.20, 0.196, 0.212, [B.CHEST, B.SPINE], [0.55, 0.45]],
		[1.06, 0.152, 0.184, [B.SPINE], [1.0]],
		[0.94, 0.158, 0.182, [B.SPINE, B.HIPS], [0.4, 0.6]],
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
		# Creases. They gather from nothing at the collar to full depth at the
		# hem, which is where cloth actually pools, and each ring walks its
		# phase on a little so the folds drift down the robe instead of running
		# as straight pipes. This is the single difference between the thobe
		# reading as fabric and reading as a white cone.
		MeshForge.folded(r, 9, 0.052 * hem_w, float(i) * 0.21)
		rings.append(r)
	# 20 segments cannot resolve nine folds -- Nyquist, and the creases alias
	# into a wobble. 44 is the cheapest count that renders them cleanly.
	b.loft(rings, 44, true, false)

	# Sleeves: full length, wide at the cuff. They catch the wind too.
	for side: int in [-1, 1]:
		var sh: int = B.SHOULDER_L if side < 0 else B.SHOULDER_R
		var ar: int = B.ARM_L if side < 0 else B.ARM_R
		var fa: int = B.FOREARM_L if side < 0 else B.FOREARM_R
		var hd: int = B.HAND_L if side < 0 else B.HAND_R
		var x := side * 0.205
		var sleeve := [
			MeshForge.ring(Vector3(side * 0.188, 1.41, 0), 0.100, 0.100, [sh, B.CHEST], [0.65, 0.35], 2.4),
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


## Sandals (shibshib), at the art direction's one permitted exaggeration of
## 1.35x scale. Below a near-white hem these are the only thing separating Wanis
## from the ground in silhouette, so the sole gets a real welt rather than fading
## into the contact shadow under him.
##
## Both straps are built as raised RINGS in the sweep rather than as bars laid
## across the instep. A bar has to be aimed at a cone whose surface moves forward
## as it descends, and getting that wrong buries it; a ring cannot miss. Seen
## side-on the two read identically anyway — each is one hard horizontal notch in
## the foot's top line with its own shadow under it, which is the whole point.
static func _build_feet() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	for side: int in [-1, 1]:
		var ft: int = B.FOOT_L if side < 0 else B.FOOT_R
		var sn: int = B.SHIN_L if side < 0 else B.SHIN_R
		var x := side * 0.072
		var bn := [ft]
		var wt := [1.0]
		# Ankle down to the instep, through two strap bands. The 5-6 mm radius
		# steps are deliberately abrupt: smoothed normals turn each one into a
		# tight bevel, which is exactly what the edge of a leather strap is.
		b.loft([
			MeshForge.ring(Vector3(x, 0.128, 0.002), 0.050, 0.057, [sn, ft], [0.4, 0.6], 2.4),
			MeshForge.ring(Vector3(x, 0.104, 0.006), 0.049, 0.062, bn, wt, 2.5),
			MeshForge.ring(Vector3(x, 0.099, 0.007), 0.055, 0.070, bn, wt, 2.7),
			MeshForge.ring(Vector3(x, 0.087, 0.010), 0.056, 0.073, bn, wt, 2.7),
			MeshForge.ring(Vector3(x, 0.082, 0.012), 0.050, 0.068, bn, wt, 2.6),
			MeshForge.ring(Vector3(x, 0.069, 0.018), 0.051, 0.077, bn, wt, 2.7),
			MeshForge.ring(Vector3(x, 0.064, 0.020), 0.057, 0.086, bn, wt, 2.9),
			MeshForge.ring(Vector3(x, 0.052, 0.025), 0.058, 0.090, bn, wt, 2.9),
			MeshForge.ring(Vector3(x, 0.047, 0.028), 0.052, 0.086, bn, wt, 2.8),
			MeshForge.ring(Vector3(x, 0.042, 0.031), 0.053, 0.086, bn, wt, 3.0),
		], 12, true, false)
		# Footbed and sole. The third ring is the widest by 4 mm and sits 10 mm
		# off the ground: that overhang is the welt, and it is the line that says
		# "sandal" instead of "foot-shaped lump".
		b.loft([
			MeshForge.ring(Vector3(x, 0.040, 0.030), 0.055, 0.112, bn, wt, 3.6),
			MeshForge.ring(Vector3(x, 0.027, 0.032), 0.058, 0.121, bn, wt, 3.8),
			MeshForge.ring(Vector3(x, 0.021, 0.032), 0.062, 0.127, bn, wt, 3.8),
			MeshForge.ring(Vector3(x, 0.011, 0.031), 0.059, 0.123, bn, wt, 3.8),
			MeshForge.ring(Vector3(x, 0.002, 0.030), 0.054, 0.117, bn, wt, 3.8),
		], 12, false, true)
		# Toe break. The instep sweep above stops short at rz 0.086 so that this
		# pad stands ahead of it with a waist between the two — a transverse
		# groove across the front of the foot. Without it the sandal is one
		# continuous nose from ankle to toe, which is what a slipper looks like.
		b.blob(Vector3(x, 0.034, 0.116), Vector3(0.048, 0.021, 0.038), bn, wt, 5, 10, 3.0)
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
		# ...and it stops ABOVE the ear, not level with the jaw. At 0.395 the
		# shell ran down to y 1.53, so the black mass came past the ear on both
		# sides and squeezed the face into a narrow vertical slot between hair
		# and beard. The widest readable thing on a head is the face; nothing is
		# allowed to narrow it.
		hair_shape, PI * 0.78, TAU * 0.745, 0.445, 1.0)

	# The shell is open across a 92-degree arc so the face can exist, and that
	# gap runs all the way to the crown — which left him with a forehead half
	# the height of his head. These four masses close the gap at the front only.
	#
	# They are NOT one arc. A low centre, a higher corner at each temple, the
	# right carried further forward than the left, and the whole thing set 10 mm
	# off centre. A hairline that is a clean symmetric curve is the single
	# clearest tell that a head was generated rather than sculpted, and it is
	# read instantly even by someone who could not say why. Bottom edge is held
	# at y 1.686 so there is a real 20 mm of forehead above the brow ridge —
	# hair landing on the brow ages him twenty years and hides the expression.
	b.blob(Vector3(-0.012, 1.726, 0.094), Vector3(0.112, 0.030, 0.090),
		head_b, head_w, 6, 13, 2.4)
	b.blob(Vector3(0.070, 1.736, 0.074), Vector3(0.074, 0.027, 0.082),
		head_b, head_w, 5, 10, 2.3)
	b.blob(Vector3(-0.084, 1.730, 0.068), Vector3(0.068, 0.027, 0.078),
		head_b, head_w, 5, 10, 2.3)
	# The crown. The first render came back with a flat-topped black cap that
	# read as a beret, because the mass closing the hairline was wide, squared
	# off at roundness 2.5 and sat BELOW the top of the skull, so the highest
	# thing on his head was a horizontal slab. This one is domed, rounder than
	# the skull it sits on, and clears the crown by 20 mm — the hair has to be
	# the top of the silhouette or it is a hat.
	b.blob(Vector3(0.004, 1.748, 0.034), Vector3(0.146, 0.048, 0.126),
		head_b, head_w, 7, 14, 2.05)
	b.blob(Vector3(0.010, 1.756, -0.026), Vector3(0.120, 0.046, 0.108),
		head_b, head_w, 6, 12, 2.0)

	# Comb direction. Five masses riding the shell, placed through `_on_blob` so
	# each one is guaranteed to break the outline by the millimetre given rather
	# than sinking into the shell unnoticed.
	#
	# Every one is long in Z and shallow in Y, and they sit low on the back of
	# the head where the shell is widest. Long is the entire point: in PROFILE a
	# round lump is a bump and a long one is a sweep, and profile is the view
	# that ships. Placing them near the crown instead, where the shell narrows to
	# nothing, makes a 12 cm ellipsoid jut 4 cm off the back of his skull.
	# Unequal sizes at unequal heights, because a symmetric pair reads as horns.
	# Each stands 17-22 mm off the shell, not the 10-13 mm it was: at 10 mm a
	# long flat mass lying on a curved one is tangent over most of its length,
	# and tangency is what put soot all over the first render.
	for sweep: Array in [
			[0.78, 1.56, Vector3(0.050, 0.030, 0.062), 0.022],
			[0.70, 1.30, Vector3(0.044, 0.034, 0.054), 0.020],
			[0.72, 1.76, Vector3(0.042, 0.036, 0.052), 0.018],
			[0.60, 1.50, Vector3(0.052, 0.042, 0.046), 0.019],
			[0.84, 1.40, Vector3(0.046, 0.024, 0.048), 0.017],
		]:
		var a := _on_blob(HEAD_CENTER, HEAD_RADIUS, hair_shape, 2.25,
			float(sweep[0]), float(sweep[1]) * PI)
		_lump(b, a, HEAD_CENTER, sweep[2], float(sweep[3]), head_b, head_w, 5, 9, 2.15)

	if outfit == Outfit.STREET:
		# Beard: follows the jaw, squared off at the chin, and pulled back at the
		# front so the lips stay a skin island in it. It is a jaw shape, not a
		# chin sphere — the old one was a sphere the size of the skull and it ate
		# the whole face.
		var beard_c := Vector3(0.0, 1.492, 0.026)
		var beard_r := Vector3(0.150, 0.068, 0.170)
		var beard_shape := func(t: float, _y: float) -> Dictionary:
			var low := 1.0 - smoothstep(0.0, 0.5, t)
			# Thin toward the top so the beard runs OUT at the cheek rather than
			# ending on a hard line — a full-thickness mass ending on its own
			# silhouette edge is a strap-on mask.
			#
			# But taper it FAST. The first version faded over 38% of the sweep,
			# which meant the beard surface ran a hair's breadth outside the
			# cheek for two centimetres before it finally went under, and that
			# tangent band is what covered the midface in black speckle. Over
			# 0.76-0.92 it crosses the skin steeply and is either clearly on top
			# or clearly buried, with almost nothing in between.
			var high := smoothstep(0.76, 0.92, t)
			return {
				"sx": (1.0 - 0.18 * low) * (1.0 - 0.34 * high),
				"sz": (1.0 - 0.10 * low) * (1.0 - 0.30 * high),
				"offset": Vector3(0.0, 0.0, 0.016 * low - 0.006 * high),
			}
		b.blob(beard_c, beard_r, head_b, head_w, 9, 16, 2.6, beard_shape)
		# Break the jaw edge. Five unequal masses at five different heights: the
		# edge of a beard is a shape, and an unbroken arc along the jaw is the
		# first place a procedural head gives itself away. These read in PROFILE
		# — the jaw edge is the silhouette down there.
		for e: Array in [
				[0.34, 0.34, Vector3(0.030, 0.026, 0.030)],
				[0.46, 0.14, Vector3(0.026, 0.030, 0.026)],
				[0.30, 0.72, Vector3(0.034, 0.024, 0.032)],
				[0.52, 0.92, Vector3(0.024, 0.030, 0.024)],
				[0.40, 0.50, Vector3(0.036, 0.022, 0.034)],
			]:
			var a := _on_blob(beard_c, beard_r, beard_shape, 2.6,
				float(e[0]), float(e[1]) * PI)
			_lump(b, a, beard_c, e[2], 0.017, head_b, head_w, 4, 8, 2.3)
		# Sideburns. Without these the beard stops in mid-cheek with bare skin
		# between it and the hair, which no beard does. Anchored a third of the
		# way up the skull and standing 18 mm off it — a sideburn laid flat
		# against the cheek is tangent to it down its whole length, and tangent
		# is the one thing nothing on this head is allowed to be.
		for side: float in [-1.0, 1.0]:
			var a := _on_blob(HEAD_CENTER, HEAD_RADIUS, HEAD_SHAPE, 2.25, 0.415,
				(0.15 if side > 0.0 else 0.85) * PI)
			_lump(b, a, HEAD_CENTER, Vector3(0.026, 0.058, 0.040), 0.018,
				head_b, head_w, 5, 8, 2.4)
		# Moustache, separate so the mouth line survives. Its front face used to
		# land at z 0.210 — the upper lip's front face exactly — and two coplanar
		# surfaces at the middle of the face is the worst possible place to put
		# one. 8 mm clear now, which also gets it a shadow onto the lip.
		b.blob(Vector3(0.0, 1.5435, 0.182), Vector3(0.052, 0.017, 0.036),
			head_b, head_w, 5, 11, 2.4)
	else:
		# Prison: heavier, unkempt, and it comes further up the cheek.
		var rough := func(t: float, _y: float) -> Dictionary:
			var low := 1.0 - smoothstep(0.0, 0.5, t)
			var high := smoothstep(0.80, 0.95, t)
			return {
				"sx": (1.0 - 0.14 * low) * (1.0 - 0.24 * high),
				"sz": (1.0 - 0.08 * low) * (1.0 - 0.20 * high),
				"offset": Vector3(0.0, 0.0, 0.014 * low - 0.004 * high),
			}
		var pc := Vector3(0.0, 1.494, 0.024)
		var pr := Vector3(0.152, 0.080, 0.172)
		b.blob(pc, pr, head_b, head_w, 9, 16, 2.4, rough)
		for e: Array in [
				[0.36, 0.26, Vector3(0.034, 0.032, 0.034)],
				[0.44, 0.78, Vector3(0.030, 0.036, 0.030)],
				[0.28, 0.50, Vector3(0.038, 0.028, 0.036)],
			]:
			var a := _on_blob(pc, pr, rough, 2.4, float(e[0]), float(e[1]) * PI)
			_lump(b, a, pc, e[2], 0.018, head_b, head_w, 4, 8, 2.3)
	return b


## The dark surface: the eyes and the brows.
##
## At the distance the gameplay camera uses a face is two dark marks and a brow —
## but without them the head is a ball, and in a close frame it is the first thing
## anyone looks for.
static func _build_shades() -> MeshForge.Builder:
	var b := MeshForge.Builder.new()
	b.begin()
	var head_b := [B.HEAD]
	var head_w := [1.0]

	for side: float in [-1.0, 1.0]:
		# The eye. It has to sit BETWEEN the lids, not behind them. These were at
		# z 0.138 against a face surface at z 0.185 — three centimetres inside the
		# skull, invisible from every angle, and the head read as blank because it
		# WAS blank.
		#
		# Small and tight, because the dark surface is very nearly black and a
		# large patch of it in a shadowed socket is a hole, not an eye. What
		# makes it an eye is the 12 mm aperture the two lids leave and the
		# specular the material takes across the curve — so the bead is kept
		# round in Z rather than flattened onto the face.
		b.blob(Vector3(side * 0.067, 1.6085, 0.176),
			Vector3(0.025, 0.0145, 0.021), head_b, head_w, 5, 10, 2.4)
		# Brow hair riding the ridge. Heavy and close to the eye: it is the whole
		# expression, and in PROFILE it is the only dark mark left on the face
		# once the eye itself turns away.
		b.blob(Vector3(side * 0.070, 1.6555, 0.178),
			Vector3(0.048, 0.012, 0.029), head_b, head_w, 4, 10, 3.0)

	# The aviators are gone. Front-on they stacked a third horizontal black bar
	# above the brow and the hairline, and a face reading as three dark bands
	# is not a face. If they come back they go on the chest pocket.
	return b
