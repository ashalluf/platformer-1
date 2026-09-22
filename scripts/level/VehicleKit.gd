class_name VehicleKit
## The World 1 vehicle library.
##
## Everything here is authored in PROFILE, because the gameplay camera sits
## side-on at z ≈ +16 and a parked car is read almost entirely by its outline
## against the road. Width across Z buys nothing. The silhouette buys
## everything.
##
## So the bodies here are not a box with a smaller box on top. Each one is a
## single closed 2D outline — bonnet, raked screen, greenhouse, boot deck,
## wheel arches cut out of the sill — lofted across Z with a chamfered side
## edge and a slight waist taper. One loft, one draw call, a real car shape.
##
## Four rules this library keeps, all of them learned from looking at captures:
##
##  1. The wheel is tucked INSIDE the arch. A wheel stuck on the side of a box
##     is the loudest "a programmer built this" tell there is. Here the arch is
##     a notch cut out of the body outline, the wheel sits ~40 mm inboard of
##     the body side, and a dark liner fills the hole behind it so you cannot
##     see daylight through the car.
##  2. Trim is built THICKER than it is in life, on purpose. A window seal is
##     20 mm on a real car; at gameplay distance anything under about 70 mm is
##     a sub-pixel line that dissolves into the panel behind it and the car
##     goes smooth and toy-like. Every seal, pillar, drip rail and rubbing
##     strip in this file is 70–120 mm. That is not sloppiness, it is the
##     correct exaggeration for the viewing distance.
##  3. Nothing on this coast is clean. The paint carries a road-film band that
##     is heaviest at the sill and gone by the waistline, plus sand on every
##     up-facing panel. That gradient is what stops a saturated body colour
##     reading as plastic.
##  4. Everything is symmetric across Z, so `facing` can simply yaw the root by
##     PI and the near side is still the detailed side. The far-side pillars
##     and shut lines cost about 200 triangles and buy immunity to a whole
##     class of "the car is inside out" bug.
##
## Cost: meshes are cached per variant, so a street of twelve cars is four body
## meshes and one wheel mesh with a handful of materials laid over them.
## Per-vehicle triangle budgets are measured, not estimated, and noted on each
## builder. A `parked_row` of 29 vehicles over 320 m of kerb measures 77 954
## triangles and 321 draw calls IN TOTAL — about eleven draws each —
## but the camera only ever sees four or five of them at once, so what is
## actually submitted per frame is under fifty. If that ever matters, thin the
## row with `density` rather than stripping detail off the vehicles: fewer good
## cars beats a kerb full of smooth ones.
##
## Everything is decorative unless the caller passes `collide`. Collision is
## normally the level builder's business, but the Ajdabiya minibus is climbed
## on, so the option lives here next to the shape it has to match.


## Plausible eastern-Libyan kerbside fleet, 1980s–2000s: nothing loud, a lot of
## white and beige because that is what survives the sun, and two blues because
## every rank of shared taxis on that coast has them.
const FLEET_COLOURS: Array[Color] = [
	Color(0.780, 0.762, 0.720),   # off-white, the default everything
	Color(0.735, 0.700, 0.618),   # beige
	Color(0.196, 0.268, 0.352),   # deep blue
	Color(0.330, 0.430, 0.470),   # faded petrol blue
	Color(0.470, 0.312, 0.180),   # brown/ochre
	Color(0.300, 0.330, 0.300),   # olive grey
	# MaterialLab's chroma law holds this down to a muted oxide — the red band
	# belongs to Wanis and the Sriracha, and a kerbside car does not get to
	# compete with him. Passed at full strength anyway so the intent is legible.
	Color(0.560, 0.180, 0.135),   # oxide red
	Color(0.180, 0.185, 0.195),   # near black
]

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


# =============================================================================
# MATERIALS
# =============================================================================

## Automotive paint. There is no clearcoat lobe in this renderer, so the
## finish is faked the way it has been faked since the first PBR car: a
## coloured base with a tight, low-roughness spec and just enough metallic to
## pick up a flake highlight off the sky. `gloss` 0 is a chalked-out repaint,
## 1 is a car somebody still washes.
##
## `ground_y` is the WORLD y of the road under the vehicle, not a local offset:
## the weathering shader reads world position, so the road-film band only lands
## in the right place if it is told where the road is.
## `seed_` is accepted for symmetry with every other builder here, but it is
## deliberately NOT part of the cache key and not fed to the noise. The
## weathering shader projects in WORLD space, so two cars parked six metres
## apart already sample different macro noise off the same material — the
## variation is free. Keying on the seed only meant a street of thirty cars
## compiled thirty materials that looked identical anyway.
static func paint_material(colour: Color, ground_y := 0.0, seed_ := 0,
		gloss := 1.0) -> ShaderMaterial:
	var key := "paint_%.3f_%.3f_%.3f_%.2f_%.2f" % [colour.r, colour.g, colour.b,
		ground_y, gloss]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := MaterialLab.surface({
		"color": colour,
		# Panels fade at different rates — a roof that has faced the sun for
		# twenty years is a different colour from the door beneath it — and the
		# macro noise at this scale is what carries that.
		"variation": colour.darkened(0.26).lerp(Color(0.72, 0.66, 0.55), 0.18),
		"variation_strength": 0.34,
		"metallic": 0.34 * gloss,
		"roughness_min": lerpf(0.44, 0.13, gloss),
		"roughness_max": lerpf(0.82, 0.36, gloss),
		"mask": NoiseBank.grain(3),
		# Orange peel. Weak, but without it the body is a mirror and the shape
		# stops reading at all in flat light.
		"normal": NoiseBank.detail_normal(9, 0.38, 0.30),
		"detail_scale": 2.6, "macro_scale": 0.42,
		"normal_strength": 0.28,
		# Sand on everything that faces the sky.
		"dust": 0.40, "dust_sharpness": 2.2,
		"dust_color": Color(0.700, 0.628, 0.472),
		# Road film. Sandy, not sooty — this is a coast road, not a city.
		# A 0.42 m falloff puts it at full strength on the sill, a third of the
		# way up the door, and gone by the window line.
		"grime": 0.62, "grime_origin": ground_y, "grime_falloff": 0.42,
		"grime_color": Color(0.372, 0.318, 0.236),
		"ao": 0.28,
	})
	_mat_cache[key] = m
	return m


## Glass read from outside at this angle. Almost black in albedo with a mirror
## roughness: what you actually see in it is the sky and whatever the
## reflection probe caught, which is exactly right for a car parked in the sun.
## The rim term fakes the fresnel brightening along the top of the screen.
static func glass_material(tint := Color(0.028, 0.038, 0.048)) -> StandardMaterial3D:
	if _mat_cache.has("glass"):
		return _mat_cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 0.85
	m.metallic_specular = 0.9
	m.roughness = 0.055
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.1
	_mat_cache["glass"] = m
	return m


## Tyre and rim in ONE mesh and ONE draw call, via vertex colour. The
## compromise is a single roughness across rubber and steel; at this distance a
## dusty steel wheel and a dusty tyre are close enough that nobody has ever
## noticed, and the draw call saved is worth more than the difference.
static func wheel_material() -> StandardMaterial3D:
	if _mat_cache.has("wheel"):
		return _mat_cache["wheel"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.68
	m.metallic = 0.18
	m.metallic_specular = 0.4
	_mat_cache["wheel"] = m
	return m


## Black plastic and rubber: bumpers, seals, rubbing strips, arch liners.
static func trim_material() -> ShaderMaterial:
	if _mat_cache.has("trim"):
		return _mat_cache["trim"]
	var m := MaterialLab.surface({
		"color": Color(0.062, 0.060, 0.062),
		"variation": Color(0.105, 0.100, 0.098),
		"variation_strength": 0.5,
		"metallic": 0.0,
		"roughness_min": 0.48, "roughness_max": 0.88,
		"mask": NoiseBank.grain(31),
		"normal": NoiseBank.detail_normal(57, 0.5, 0.5),
		"detail_scale": 3.0, "macro_scale": 0.5,
		"normal_strength": 0.4,
		"dust": 0.45, "grime": 0.35, "grime_falloff": 0.6,
		"grime_color": Color(0.36, 0.31, 0.23),
		"ao": 0.35,
	})
	_mat_cache["trim"] = m
	return m


## Dull chrome. Nothing on a twenty-year-old car is bright chrome any more, so
## this is pitted and slightly warm rather than a mirror.
static func chrome_material() -> StandardMaterial3D:
	if _mat_cache.has("chrome"):
		return _mat_cache["chrome"]
	var m := MaterialLab.chrome(Color(0.760, 0.762, 0.740), 0.26)
	_mat_cache["chrome"] = m
	return m


## Lamp lenses. Emission is low on purpose: these are parked cars in daylight,
## and a tail lamp that glows in the morning sun looks like a bug.
static func lamp_material(colour: Color, energy := 0.35) -> StandardMaterial3D:
	var key := "lamp_%.2f_%.2f_%.2f" % [colour.r, colour.g, colour.b]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.12
	m.metallic = 0.0
	m.metallic_specular = 0.8
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m


## Panel gaps, shut lines, the number plate recess. A flat quad, not a box:
## a shut line IS a line, and giving it thickness makes it a rib.
static func line_material() -> StandardMaterial3D:
	if _mat_cache.has("line"):
		return _mat_cache["line"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.030, 0.028, 0.028)
	m.roughness = 0.95
	m.metallic = 0.0
	_mat_cache["line"] = m
	return m


## Burnt-out bodywork: primer, oxide and soot, with the paint gone. Metallic
## is pushed up rather than down — a shell that has had the paint burned off it
## is bare steel, and bare steel is what catches the light on a wreck.
static func burnt_material(seed_ := 0) -> ShaderMaterial:
	var key := "burnt_%d" % (seed_ % 4)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := MaterialLab.surface({
		"color": Color(0.098, 0.086, 0.080),
		"variation": Color(0.230, 0.118, 0.068),   # oxide bloom through the soot
		"variation_strength": 0.78,
		"metallic": 0.42,
		"roughness_min": 0.46, "roughness_max": 0.98,
		"mask": NoiseBank.pits(41 + seed_),
		"normal": NoiseBank.rough_normal(91 + seed_, 0.22, 2.4),
		"detail_scale": 1.6, "macro_scale": 0.34,
		"normal_strength": 1.2,
		"dust": 0.30, "grime": 0.30, "grime_falloff": 0.7,
		"grime_color": Color(0.050, 0.044, 0.040),
		"ao": 0.55,
	})
	_mat_cache[key] = m
	return m


# =============================================================================
# BUILD RIG
# =============================================================================

## Per-vehicle build state.
##
## Everything small — pillars, seals, sills, handles, lamps, roof rack bars —
## goes into one of a handful of batches and comes out as a single MultiMesh
## each. A parked car that costs eleven draw calls is a parked car you can only
## afford three of, and Ajdabiya needs a dozen.
##
## Roles are tagged as node metadata rather than held as references, so `wreck`
## can walk a finished vehicle and re-skin it without this class having to stay
## alive or a dangling node reference being possible.
class Rig extends RefCounted:
	var root: Node3D
	var rng := RandomNumberGenerator.new()
	var ground_y := 0.0

	var mat_paint: Material
	var mat_accent: Material
	var mat_dark: Material
	var mat_bright: Material
	var mat_glass: Material
	var mat_line: Material
	var mat_lamp_red: Material
	var mat_lamp_clear: Material

	var wheel_mesh: Mesh
	var box_mesh: Mesh             # the shared unit trim box
	var quad_mesh: Mesh            # the shared unit decal quad
	var wheel_mat: Material
	var _trim: Dictionary = {}     # Material -> Array[Transform3D], unit box
	var _flat: Dictionary = {}     # Material -> Array[Transform3D], unit quad
	var _batch: Dictionary = {}    # (mesh, material) -> repeated custom mesh
	var _wheels: Array[Transform3D] = []

	func _init(parent: Node3D, at: Vector3, name_: String, yaw := false) -> void:
		root = Node3D.new()
		root.name = name_
		root.position = at
		ground_y = at.y
		parent.add_child(root)
		if yaw:
			# Yaw, not a mirrored scale: a negative determinant flips winding
			# and the whole car turns inside out in shadow. Everything in here
			# is symmetric across Z precisely so this is safe.
			root.rotation.y = PI

	## A solid mesh part, tagged with its role so `wreck` can find it.
	func part(name_: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO,
			rot := Vector3.ZERO, role := "paint") -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.name = name_
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		mi.set_meta("vk_role", role)
		root.add_child(mi)
		return mi

	## One piece of trim: a unit chamfered box scaled to `size`, optionally
	## rolled about Z so it can follow a pillar rake.
	func trim(mat: Material, size: Vector3, pos: Vector3, roll := 0.0) -> void:
		if not _trim.has(mat):
			_trim[mat] = [] as Array[Transform3D]
		var basis := Basis(Vector3(0, 0, 1), roll).scaled_local(size)
		_trim[mat].append(Transform3D(basis, pos))

	## The same piece on both sides. `pos.z` is the near-side offset.
	func trim_pair(mat: Material, size: Vector3, pos: Vector3, roll := 0.0) -> void:
		trim(mat, size, pos, roll)
		trim(mat, size, Vector3(pos.x, pos.y, -pos.z), roll)

	## A flat decal-style quad facing +Z.
	func flat(mat: Material, size: Vector2, pos: Vector3, roll := 0.0) -> void:
		if not _flat.has(mat):
			_flat[mat] = [] as Array[Transform3D]
		var basis := Basis(Vector3(0, 0, 1), roll).scaled_local(
			Vector3(size.x, size.y, 1.0))
		_flat[mat].append(Transform3D(basis, pos))

	func flat_pair(mat: Material, size: Vector2, pos: Vector3, roll := 0.0) -> void:
		flat(mat, size, pos, roll)
		var basis := Basis(Vector3.UP, PI) * Basis(Vector3(0, 0, 1), roll)
		if not _flat.has(mat):
			_flat[mat] = [] as Array[Transform3D]
		_flat[mat].append(Transform3D(basis.scaled_local(
			Vector3(size.x, size.y, 1.0)), Vector3(pos.x, pos.y, -pos.z)))

	## A repeated custom mesh — an arch flare, a mudguard. Same idea as `trim`,
	## but the mesh is not the unit box so it needs its own bucket.
	func batch(mesh: Mesh, mat: Material, xf: Transform3D,
			role := "paint") -> void:
		var key := "%d_%d" % [mesh.get_instance_id(), mat.get_instance_id()]
		if not _batch.has(key):
			_batch[key] = {"mesh": mesh, "mat": mat, "role": role,
				"xf": [] as Array[Transform3D]}
		_batch[key]["xf"].append(xf)

	func wheel(pos: Vector3, scale_ := Vector3.ONE) -> void:
		_wheels.append(Transform3D(Basis.IDENTITY.scaled(scale_), pos))

	## Both wheels of an axle.
	func axle(x: float, y: float, track: float, scale_ := Vector3.ONE) -> void:
		wheel(Vector3(x, y, track), scale_)
		wheel(Vector3(x, y, -track), Vector3(scale_.x, scale_.y, -scale_.z))

	## Collapse every batch into MultiMeshes and hand back the root.
	func flush() -> Node3D:
		for mat: Material in _trim:
			_emit(_trim[mat], box_mesh, mat, "Trim",
				"paint" if (mat == mat_paint or mat == mat_accent) else "trim")
		for mat: Material in _flat:
			_emit(_flat[mat], quad_mesh, mat, "Detail", "detail")
		for key: String in _batch:
			var b: Dictionary = _batch[key]
			_emit(b["xf"], b["mesh"], b["mat"], "Group", b["role"])
		if not _wheels.is_empty() and wheel_mesh:
			_emit(_wheels, wheel_mesh, wheel_mat, "Wheels", "wheel")
		return root

	func _emit(xf: Array, mesh: Mesh, mat: Material, name_: String,
			role: String) -> void:
		if xf.is_empty():
			return
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d" % [name_, root.get_child_count()]
		node.multimesh = mm
		node.material_override = mat
		node.set_meta("vk_role", role)
		root.add_child(node)


## Build a rig with the full material set for one vehicle. Lives out here
## rather than in `Rig._init` for the scope reason above, and it is also the
## single place a vehicle's palette is decided.
static func _rig(parent: Node3D, at: Vector3, name_: String, colour: Color,
		seed_: int, opts: Dictionary) -> Rig:
	var gloss := float(opts.get("gloss", 0.78))
	var rig := Rig.new(parent, at, name_, float(opts.get("facing", 1.0)) < 0.0)
	rig.rng.seed = seed_ * 7919 + 13
	# World y of the road under this vehicle. Normally `at.y`, but a vehicle
	# parented to another one (a tractor under its trailer) has to be told.
	var gy := float(opts.get("ground_y", at.y))
	rig.ground_y = gy
	rig.mat_paint = paint_material(colour, gy, seed_, gloss)
	var accent: Color = opts.get("accent", colour.darkened(0.42))
	rig.mat_accent = paint_material(accent, gy, seed_ + 5, gloss * 0.8)
	rig.mat_dark = trim_material()
	rig.mat_bright = chrome_material()
	rig.mat_glass = glass_material()
	rig.mat_line = line_material()
	rig.mat_lamp_red = lamp_material(Color(0.62, 0.055, 0.045), 0.5)
	rig.mat_lamp_clear = lamp_material(Color(0.86, 0.84, 0.74), 0.12)
	rig.box_mesh = _unit_box()
	rig.quad_mesh = _unit_quad()
	rig.wheel_mat = wheel_material()
	return rig


# =============================================================================
# CARS
# =============================================================================

## The everyday saloon. Four variants off one spec table, picked by `seed_`, so
## a kerb full of them is four shapes rather than twelve near-identical ones —
## which is both cheaper (four cached meshes) and better looking.
##
## Measured: 2 642 tris, 11 draw calls (body, glass, arch flares, wheels, and
## one MultiMesh per trim material). `at` is the ground contact point under the
## centre of the wheelbase, not the body's origin.
static func saloon(parent: Node3D, at: Vector3, body_colour := FLEET_COLOURS[0],
		seed_ := 0, opts := {}) -> Node3D:
	return _car(parent, at, body_colour, seed_, "notch", opts)


## Same platform, chopped tail: a two-box hatchback. 2 634 tris, 11 draws.
static func hatchback(parent: Node3D, at: Vector3, body_colour := FLEET_COLOURS[1],
		seed_ := 0, opts := {}) -> Node3D:
	return _car(parent, at, body_colour, seed_, "hatch", opts)


## Same platform, roof carried to the tail: the estate every family on that
## coast owns. 2 626 tris, 11 draws.
static func estate(parent: Node3D, at: Vector3, body_colour := FLEET_COLOURS[1],
		seed_ := 0, opts := {}) -> Node3D:
	return _car(parent, at, body_colour, seed_, "estate", opts)


static func _car(parent: Node3D, at: Vector3, colour: Color, seed_: int,
		tail: String, opts: Dictionary) -> Node3D:
	var v := seed_ % 4
	var rig := _rig(parent, at, str(opts.get("name", "Car")), colour, seed_, opts)

	# --- Spec ----------------------------------------------------------------
	# Four platforms rather than continuous randomisation, so the body meshes
	# cache. Lengths and roof heights are the two numbers that actually change
	# the read; everything else is derived.
	var hl: float = [2.15, 2.06, 2.24, 2.11][v]           # half length
	var roof: float = [1.378, 1.338, 1.402, 1.424][v]     # roof height
	var bw: float = [1.66, 1.60, 1.72, 1.64][v]           # body width across Z
	var wr: float = [0.305, 0.292, 0.318, 0.300][v]       # wheel radius
	var axf: float = hl - [0.80, 0.76, 0.84, 0.78][v]
	var axr: float = -hl + [0.95, 0.88, 1.00, 0.92][v]
	var hw: float = bw * 0.5
	var sill: float = wr * 0.86
	var belt: float = roof - [0.375, 0.352, 0.398, 0.420][v]

	var spec := {
		"half_len": hl, "sill_y": sill, "arch_r": wr * 1.31, "arch_cy": wr,
		"axle_r": axr, "axle_f": axf,
		"rear_low_y": sill + 0.14, "front_low_y": sill + 0.16,
	}

	# The top edge, front to back. This little table IS the car: the rake of
	# the screen and the length of the bonnet are the whole difference between
	# a 1985 saloon and a 2005 one, and they are two numbers here.
	var scuttle_x: float = axf - [0.68, 0.60, 0.74, 0.58][v]
	var screen_top_x: float = scuttle_x - [0.60, 0.56, 0.64, 0.50][v]
	var top: Array[Vector2] = [
		Vector2(hl + 0.015, sill + 0.42),         # front face, under the lamps
		Vector2(hl, roof * 0.565),                # lamp/grille band
		Vector2(hl - 0.20, roof * 0.625),         # bonnet leading edge
		Vector2(axf - 0.10, roof * 0.660),        # bonnet, rising to the scuttle
		Vector2(scuttle_x, belt - 0.035),         # base of the windscreen
		Vector2(screen_top_x, roof - 0.032),      # top of the windscreen
		Vector2(screen_top_x - 0.58, roof),       # roof crown
	]
	match tail:
		"estate":
			top.append(Vector2(-hl + 0.16, roof - 0.012))
			top.append(Vector2(-hl + 0.02, roof - 0.055))
			top.append(Vector2(-hl, belt - 0.02))
			top.append(Vector2(-hl - 0.01, sill + 0.48))
		"hatch":
			top.append(Vector2(-hl + 0.62, roof - 0.028))
			top.append(Vector2(-hl + 0.44, roof - 0.115))
			top.append(Vector2(-hl + 0.05, belt + 0.075))
			top.append(Vector2(-hl, belt - 0.11))
			top.append(Vector2(-hl - 0.012, sill + 0.44))
		_:
			top.append(Vector2(-hl + 1.06, roof - 0.030))     # rear of the roof
			top.append(Vector2(-hl + 0.58, belt + 0.070))     # base of the rear screen
			top.append(Vector2(-hl + 0.32, belt + 0.032))     # boot lid
			top.append(Vector2(-hl + 0.04, belt + 0.005))     # boot trailing edge
			top.append(Vector2(-hl, belt - 0.30))             # rear panel
			top.append(Vector2(-hl - 0.014, sill + 0.26))     # slight tumblehome
	spec["top"] = top

	var body_key := "car_%s_%d" % [tail, v]
	var body := _cached_mesh(body_key, func() -> Mesh:
		return _loft(_car_profile(spec), bw, {"edge": 0.062, "taper": 0.955}))
	rig.part("Body", body, rig.mat_paint, Vector3.ZERO, Vector3.ZERO, "paint")

	# --- Greenhouse -----------------------------------------------------------
	# One dark glass loft for the whole daylight opening, with the pillars laid
	# over it at the body's side plane. That is how a real car divides its
	# glass, and it means the panes cost nothing.
	var dlo_front: float = scuttle_x - 0.10
	var dlo_back: float = -hl + [0.60, 0.46, 0.20, 0.56][v]
	# How far forward the rear screen leans on its way to the roof. A saloon's
	# C-pillar is raked, a hatch's is steeper, an estate's is nearly upright —
	# and that one number is most of the difference between the three bodies.
	var c_rake := 0.42
	if tail == "estate":
		dlo_back = -hl + 0.24
		c_rake = 0.12
	elif tail == "hatch":
		dlo_back = -hl + 0.34
		c_rake = 0.30
	var glass_top := roof - 0.092
	# Four corners, front-bottom / rear-bottom / rear-top / front-top.
	var a_lo := Vector2(dlo_front, belt)
	var c_lo := Vector2(dlo_back, belt)
	var c_hi := Vector2(dlo_back + c_rake, glass_top)
	var a_hi := Vector2(screen_top_x + 0.055, glass_top - 0.012)
	var dlo := PackedVector2Array([a_lo, c_lo, c_hi, a_hi])
	var glass_key := "carglass_%s_%d" % [tail, v]
	var glass_mesh := _cached_mesh(glass_key, func() -> Mesh:
		return _loft(dlo, bw - 0.10, {"edge": 0.03, "taper": 0.99}))
	rig.part("Glass", glass_mesh, rig.mat_glass, Vector3(0, 0, 0),
		Vector3.ZERO, "glass")

	var side: float = hw - 0.012
	# A-pillar: follows the screen rake. 115 mm wide, which is about double
	# life size and exactly what it takes for the pillar to survive at 20 m.
	_raked_trim(rig, rig.mat_paint, a_lo, a_hi, 0.115, side)
	# B-pillar, upright, in black: the one pillar that is black on every car
	# ever made, and the thing that makes a window band read as two windows.
	var bx: float = (dlo_front + dlo_back) * 0.5 + 0.18
	rig.trim_pair(rig.mat_dark, Vector3(0.10, glass_top - belt + 0.04, 0.075),
		Vector3(bx, (belt + glass_top) * 0.5, side))
	# C-pillar.
	_raked_trim(rig, rig.mat_paint, c_lo, c_hi, 0.125, side)

	# Drip rail along the roof edge — both sides, because the far one is what
	# you see in silhouette against the sky when the camera looks down.
	rig.trim_pair(rig.mat_paint, Vector3(a_hi.x - c_hi.x + 0.14, 0.055, 0.072),
		Vector3((a_hi.x + c_hi.x) * 0.5, roof - 0.050, hw - 0.035))
	# Waist seal under the glass. This and the drip rail above are where the
	# DLO's rubber actually SHOWS from the kerb — the A and C edges are covered
	# by body-coloured pillar, which is how cars of this period were built and
	# is also the only place a seal would survive at gameplay distance. Chrome
	# on the older bodies, black rubber on the later ones.
	var waist: Material = rig.mat_bright if v % 2 == 0 else rig.mat_dark
	rig.trim_pair(waist, Vector3(dlo_front - dlo_back + 0.06, 0.052, 0.078),
		Vector3((dlo_front + dlo_back) * 0.5, belt - 0.012, hw + 0.004))

	# --- Body sides -----------------------------------------------------------
	# Sill / rocker: proud, dark, scuffed. It grounds the car — without it the
	# body floats above the wheels.
	rig.trim_pair(rig.mat_dark, Vector3(axf - axr + 0.10, 0.105, 0.062),
		Vector3((axf + axr) * 0.5, sill + 0.045, hw + 0.006))
	# Rubbing strip down the doors. Pure 1990s, and it breaks up the single
	# biggest flat area on the whole vehicle.
	rig.trim_pair(rig.mat_dark, Vector3(hl * 1.42, 0.082, 0.048),
		Vector3(-0.06, belt - 0.30, hw + 0.010))
	# Door handles.
	for hx: float in [bx + 0.52, bx - 0.52]:
		rig.trim_pair(rig.mat_paint, Vector3(0.20, 0.052, 0.055),
			Vector3(hx, belt - 0.155, hw + 0.012))
	# Shut lines. Two tris each and worth more than any of the above.
	for lx: float in [dlo_front + 0.02, bx, dlo_back + 0.06]:
		rig.flat_pair(rig.mat_line, Vector2(0.018, belt - sill - 0.10),
			Vector3(lx, (belt + sill) * 0.5 + 0.02, hw + 0.004))

	# Mirrors: small, but they are the only thing that breaks the body's
	# outline between the wheels, so they read far above their size.
	rig.trim_pair(rig.mat_dark, Vector3(0.11, 0.048, 0.10),
		Vector3(dlo_front + 0.04, belt + 0.02, hw + 0.055))
	rig.trim_pair(rig.mat_paint, Vector3(0.075, 0.135, 0.145),
		Vector3(dlo_front + 0.07, belt + 0.05, hw + 0.135), 0.12)
	# Wiper. Laid on the screen, not in the body: 35 mm out along the screen
	# edge's own normal, rolled to its rake.
	var scr_a := Vector2(scuttle_x, belt - 0.035)
	var scr_b := Vector2(screen_top_x, roof - 0.032)
	var scr_d := (scr_b - scr_a).normalized()
	var wip := scr_a.lerp(scr_b, 0.40) + Vector2(scr_d.y, -scr_d.x) * 0.038
	rig.trim(rig.mat_dark, Vector3(0.52, 0.030, 0.032),
		Vector3(wip.x, wip.y, hw * 0.40), scr_d.angle())

	# --- Ends -----------------------------------------------------------------
	var chrome_bumpers := v % 3 == 0
	var bump: Material = rig.mat_bright if chrome_bumpers else rig.mat_dark
	rig.trim(bump, Vector3(0.26, 0.26, bw + 0.03),
		Vector3(hl + 0.10, sill + 0.30, 0.0))
	rig.trim(bump, Vector3(0.24, 0.26, bw + 0.03),
		Vector3(-hl - 0.10, sill + 0.30, 0.0))
	# Grille and lamps. Headlamps sit outboard, tail lamps wrap the corner.
	rig.trim(rig.mat_dark, Vector3(0.07, 0.17, bw * 0.62),
		Vector3(hl + 0.035, roof * 0.505, 0.0))
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_lamp_clear, Vector3(0.075, 0.155, bw * 0.30),
			Vector3(hl + 0.035, roof * 0.520, s * bw * 0.31))
		rig.trim(rig.mat_lamp_red, Vector3(0.065, 0.215, bw * 0.28),
			Vector3(-hl - 0.030, belt - 0.235, s * bw * 0.33))
	# Number plate: a dark recess with a pale plate standing in it. In profile
	# this is a notch; from three-quarters, which is how you see every car in
	# the second half of the street, it is the detail that says "rear".
	rig.trim(rig.mat_line, Vector3(0.05, 0.19, 0.50),
		Vector3(-hl - 0.055, sill + 0.50, 0.0))
	rig.trim(rig.mat_bright, Vector3(0.035, 0.125, 0.42),
		Vector3(-hl - 0.085, sill + 0.50, 0.0))
	# Exhaust, offset to one side like every exhaust ever fitted.
	rig.trim(rig.mat_dark, Vector3(0.30, 0.075, 0.075),
		Vector3(-hl + 0.08, sill - 0.035, bw * 0.28))

	# --- Arches and wheels ----------------------------------------------------
	var arch_r: float = spec["arch_r"]
	var lip := _cached_mesh("lip_%.3f" % arch_r, func() -> Mesh:
		return _crescent(arch_r, arch_r + 0.075, 9))
	for ax: float in [axf, axr]:
		_arch_lip(rig, lip, Vector3(ax, wr, hw + 0.020))
		# Liner: the dark hole behind the wheel. Without it you see straight
		# through the arch to the sky and the car reads as a cardboard cutout.
		rig.trim(rig.mat_line, Vector3(arch_r * 1.85, arch_r * 1.15, bw - 0.60),
			Vector3(ax, wr + 0.06, 0.0))

	rig.wheel_mesh = _wheel_mesh(wr, wr * 0.68)
	var track: float = hw - wr * 0.45
	rig.axle(axf, wr, track)
	rig.axle(axr, wr, track)

	rig.root.set_meta("vk_size", Vector3(hl * 2.0, roof, bw))
	rig.root.set_meta("vk_ground", 0.0)
	var node := rig.flush()
	if opts.get("collide", false):
		_collider(node, Vector3(hl * 2.0, roof * 0.66, bw),
			Vector3(0, roof * 0.33, 0))
	if opts.get("wrecked", false):
		wreck(node, seed_)
	return node


## The side profile of a car, as a single closed outline.
##
## The underside is where the work is: the two wheel arches are notches cut out
## of it, and that is the entire reason the body is a loft instead of a box.
## An arch has to be a hole in the silhouette, or the wheel can only ever be a
## disc stuck on the outside of a brick.
static func _car_profile(s: Dictionary) -> PackedVector2Array:
	var p := PackedVector2Array()
	var hl: float = s["half_len"]
	var sill: float = s["sill_y"]
	var ar: float = s["arch_r"]
	var ac: float = s["arch_cy"]
	var axr: float = s["axle_r"]
	var axf: float = s["axle_f"]

	p.append(Vector2(-hl, s["rear_low_y"]))
	p.append(Vector2(axr - ar, sill))
	_arc(p, axr, ac, ar, PI, 0.0, 7)
	p.append(Vector2(axr + ar, sill))
	p.append(Vector2(axf - ar, sill))
	_arc(p, axf, ac, ar, PI, 0.0, 7)
	p.append(Vector2(axf + ar, sill))
	p.append(Vector2(hl, s["front_low_y"]))
	for v: Vector2 in s["top"]:
		p.append(v)
	return p


## A trim bar spanning two points in the profile plane, mirrored across Z.
static func _raked_trim(rig: Rig, mat: Material, a: Vector2, b: Vector2,
		thickness: float, z: float) -> void:
	var d := b - a
	rig.trim_pair(mat, Vector3(d.length() + thickness * 0.5, thickness, 0.085),
		Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z), d.angle())


## The arch flare. A flat crescent standing 20 mm proud of the body side: it
## costs 16 triangles and it is what catches the rim light around the wheel.
static func _arch_lip(rig: Rig, mesh: Mesh, pos: Vector3) -> void:
	rig.batch(mesh, rig.mat_paint, Transform3D(Basis.IDENTITY, pos))
	# Yawed, not mirrored: a PI rotation keeps the determinant positive, so the
	# far flare is still wound front-out.
	rig.batch(mesh, rig.mat_paint, Transform3D(Basis(Vector3.UP, PI),
		Vector3(pos.x, pos.y, -pos.z)))


# =============================================================================
# PICKUP
# =============================================================================

## The pickup: single cab, dropside bed, roll bar, and a load. The bed is the
## point — the notch between the cab and the bed front wall is a shape no box
## stack can make, and it is what tells you at a glance that this is a working
## vehicle and not a car.
##
## `load` is "mixed" (default), "sacks", "drums", "spare" or "empty".
## Measured: 3 558 tris with a mixed load, 13 draw calls.
static func pickup(parent: Node3D, at: Vector3, body_colour := FLEET_COLOURS[0],
		seed_ := 0, opts := {}) -> Node3D:
	var v := seed_ % 2
	var rig := _rig(parent, at, str(opts.get("name", "Pickup")), body_colour,
		seed_, opts)

	var hl: float = [2.62, 2.78][v]
	var bw: float = [1.82, 1.88][v]
	var hw: float = bw * 0.5
	var wr := 0.375
	var sill := 0.44
	var axf: float = hl - 0.90
	var axr: float = -hl + 1.08
	var roof: float = [1.76, 1.80][v]
	var belt: float = roof - 0.52
	var bed_top := 1.26
	var deck := 0.96

	var spec := {
		"half_len": hl, "sill_y": sill, "arch_r": wr * 1.26, "arch_cy": wr,
		"axle_r": axr, "axle_f": axf,
		"rear_low_y": sill + 0.10, "front_low_y": sill + 0.14,
		"top": [
			Vector2(hl + 0.02, sill + 0.46),
			Vector2(hl + 0.03, 0.98),              # grille band
			Vector2(hl - 0.08, 1.08),              # bonnet leading edge
			Vector2(axf - 0.10, 1.16),             # bonnet
			Vector2(axf - 0.62, 1.20),             # scuttle
			Vector2(axf - 1.18, roof - 0.045),     # top of the screen
			Vector2(axf - 1.36, roof),             # roof
			Vector2(-0.34, roof),
			Vector2(-0.50, roof - 0.055),
			Vector2(-0.56, belt - 0.14),           # cab rear panel
			Vector2(-0.58, deck + 0.02),
			# The notch. Cab back, a gap you can see the chassis through, then
			# the bed front wall standing up again.
			Vector2(-0.82, deck),
			Vector2(-0.88, bed_top),
			Vector2(-hl + 0.12, bed_top),          # bed top rail
			Vector2(-hl + 0.02, bed_top - 0.07),
			Vector2(-hl, deck - 0.10),             # tailgate
			Vector2(-hl - 0.012, sill + 0.42),
		] as Array[Vector2],
	}

	var body := _cached_mesh("pickup_%d" % v, func() -> Mesh:
		return _loft(_car_profile(spec), bw, {"edge": 0.060, "taper": 0.965}))
	rig.part("Body", body, rig.mat_paint, Vector3.ZERO, Vector3.ZERO, "paint")

	# Cab glass: a short, upright greenhouse. Two panes, one pillar.
	var dlo := PackedVector2Array([
		Vector2(axf - 0.70, belt),
		Vector2(-0.50, belt),
		Vector2(-0.42, roof - 0.10),
		Vector2(axf - 1.14, roof - 0.095),
	])
	var glass_mesh := _cached_mesh("pickupglass_%d" % v, func() -> Mesh:
		return _loft(dlo, bw - 0.10, {"edge": 0.03, "taper": 0.99}))
	rig.part("Glass", glass_mesh, rig.mat_glass, Vector3.ZERO, Vector3.ZERO, "glass")

	var side: float = hw - 0.012
	_raked_trim(rig, rig.mat_paint, Vector2(axf - 0.70, belt),
		Vector2(axf - 1.14, roof - 0.095), 0.12, side)
	rig.trim_pair(rig.mat_dark, Vector3(0.095, roof - belt - 0.10, 0.075),
		Vector3(axf - 1.30, belt + (roof - belt) * 0.5, side))
	rig.trim_pair(rig.mat_paint, Vector3(0.115, roof - belt - 0.14, 0.085),
		Vector3(-0.46, belt + (roof - belt) * 0.5 - 0.03, side))
	rig.trim_pair(rig.mat_dark, Vector3(1.20, 0.055, 0.075),
		Vector3(axf - 1.10, belt - 0.015, hw + 0.004))

	# Bed sides: vertical ribs, stake pockets on the top rail, a capping rail.
	# Ribs are the single thing that separates a bed from a coloured slab.
	rig.trim_pair(rig.mat_paint, Vector3(hl - 0.95, 0.075, 0.075),
		Vector3((-hl - 0.85) * 0.5 - 0.02, bed_top - 0.05, hw + 0.006))
	for i in 4:
		var rx: float = -0.98 - i * (hl - 1.15) / 3.5
		rig.trim_pair(rig.mat_paint, Vector3(0.085, bed_top - deck - 0.10, 0.058),
			Vector3(rx, (bed_top + deck) * 0.5 - 0.02, hw + 0.008))
		rig.trim_pair(rig.mat_dark, Vector3(0.11, 0.10, 0.085),
			Vector3(rx, bed_top - 0.01, hw - 0.02))
	# Tailgate: hinge line and the two drop latches.
	rig.flat_pair(rig.mat_line, Vector2(0.020, bed_top - deck + 0.05),
		Vector3(-hl + 0.10, (bed_top + deck) * 0.5, hw + 0.004))
	rig.trim(rig.mat_dark, Vector3(0.06, 0.09, 0.30),
		Vector3(-hl - 0.03, bed_top - 0.14, 0.0))

	# Roll bar. Behind the cab, and the one piece of this vehicle that breaks
	# the skyline — which is why it is worth five instances.
	var bar_y: float = roof + 0.14
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_bright, Vector3(0.085, bar_y - bed_top + 0.2, 0.085),
			Vector3(-0.98, (bar_y + bed_top) * 0.5, s * (hw - 0.22)))
		rig.trim(rig.mat_bright, Vector3(0.52, 0.070, 0.070),
			Vector3(-0.72, bar_y - 0.34, s * (hw - 0.22)), 0.62)
	rig.trim(rig.mat_bright, Vector3(0.085, 0.085, bw - 0.36),
		Vector3(-0.98, bar_y, 0.0))

	# Ends.
	rig.trim(rig.mat_dark, Vector3(0.28, 0.28, bw + 0.04),
		Vector3(hl + 0.11, sill + 0.30, 0.0))
	rig.trim(rig.mat_dark, Vector3(0.07, 0.20, bw * 0.66),
		Vector3(hl + 0.04, 0.92, 0.0))
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_lamp_clear, Vector3(0.075, 0.175, bw * 0.28),
			Vector3(hl + 0.04, 0.94, s * bw * 0.32))
		rig.trim(rig.mat_lamp_red, Vector3(0.060, 0.19, 0.16),
			Vector3(-hl - 0.03, deck + 0.10, s * bw * 0.40))
	rig.trim(rig.mat_dark, Vector3(1.05, 0.10, 0.10),
		Vector3(-hl + 0.55, sill - 0.10, bw * 0.26))

	# Arches, wheels, load.
	var arch_r: float = spec["arch_r"]
	var lip := _cached_mesh("lip_%.3f" % arch_r, func() -> Mesh:
		return _crescent(arch_r, arch_r + 0.085, 9))
	for ax: float in [axf, axr]:
		_arch_lip(rig, lip, Vector3(ax, wr, hw + 0.020))
		rig.trim(rig.mat_line, Vector3(arch_r * 1.85, arch_r * 1.15, bw - 0.62),
			Vector3(ax, wr + 0.06, 0.0))

	rig.wheel_mesh = _wheel_mesh(wr, wr * 0.74)
	var track: float = hw - wr * 0.42
	rig.axle(axf, wr, track)
	rig.axle(axr, wr, track)

	# The bed is a loft, so it is SOLID between its sides — there is no well to
	# drop things into. The load therefore sits just under the top rail and
	# rises above it, which is exactly what you see of a loaded bed from the
	# kerb anyway: the tops of the sacks over the side.
	_pickup_load(rig, str(opts.get("load", "mixed")), -hl, -0.85,
		bed_top - 0.13, bw, wr)

	rig.root.set_meta("vk_size", Vector3(hl * 2.0, roof, bw))
	var node := rig.flush()
	if opts.get("collide", false):
		_collider(node, Vector3(hl * 2.0, bed_top, bw), Vector3(0, bed_top * 0.5, 0))
	if opts.get("wrecked", false):
		wreck(node, seed_)
	return node


## What is actually in the back. A pickup with an empty bed is a model; a
## pickup with four sacks and a drum in it is somebody's livelihood.
static func _pickup_load(rig: Rig, kind: String, back_x: float, front_x: float,
		floor_y: float, bw: float, wr: float) -> void:
	if kind == "empty":
		return
	var sack := MaterialLab.cloth(Color(0.560, 0.500, 0.392), 0.95)
	var drum := MaterialLab.rusted_metal(Color(0.320, 0.176, 0.112), 0.9)
	var span := front_x - back_x
	var want_sacks := kind == "sacks" or kind == "mixed"
	var want_drums := kind == "drums" or kind == "mixed"
	var want_spare := kind == "spare" or kind == "mixed"

	if want_spare:
		# Spare tyre flat against the bulkhead, where every spare lives.
		rig.wheel(Vector3(front_x - 0.42, floor_y + wr * 0.42, 0.0),
			Vector3(0.94, 0.94, 0.94))
	if want_drums:
		var barrel := _cyl(0.28, 0.86, 12)
		for i in (3 if kind == "drums" else 2):
			var dx := back_x + 0.46 + i * 0.62
			rig.batch(barrel, drum, Transform3D(Basis.IDENTITY,
				Vector3(dx, floor_y + 0.40, (0.30 if i % 2 == 0 else -0.24))),
				"trim")
	if want_sacks:
		# Squashed boxes, tilted. Sacks never sit square and the tilt is most
		# of what sells them.
		for i in 4:
			var sx := back_x + 0.42 + rig.rng.randf_range(0.0, span * 0.55)
			var sw := rig.rng.randf_range(0.46, 0.62)
			var sh := rig.rng.randf_range(0.28, 0.38)
			rig.trim(sack, Vector3(sw, sh, rig.rng.randf_range(0.42, 0.60)),
				Vector3(sx, floor_y + sh * 0.5 + (0.0 if i < 3 else 0.32),
					rig.rng.randf_range(-bw * 0.22, bw * 0.22)),
				rig.rng.randf_range(-0.22, 0.22))
	# Strap over the load. One box, and it is the thing that makes the pile
	# look tied down rather than dropped in.
	rig.trim(rig.mat_dark, Vector3(0.045, 0.78, bw - 0.24),
		Vector3(back_x + span * 0.45, floor_y + 0.34, 0.0))


# =============================================================================
# MINIBUS
# =============================================================================

## The minibus. Forward control, one raked screen, a destination board over it,
## a continuous window band, a roof rack and a luggage door. This is the one
## stalled across the Ajdabiya junction that the player climbs, so it takes
## `collide` and its collider matches the roof line.
##
## Measured: 5 589 tris, 15 draw calls WITH a destination — the TextMesh is
## about 2 000 of those triangles even flat, so leave `destination` empty on
## background buses and spend it on the one the player climbs.
static func minibus(parent: Node3D, at: Vector3, body_colour := FLEET_COLOURS[2],
		seed_ := 0, opts := {}) -> Node3D:
	var rig := _rig(parent, at, str(opts.get("name", "Minibus")), body_colour,
		seed_, opts)
	var hl := float(opts.get("half_len", 3.80))
	var bw := float(opts.get("width", 2.28))
	var hw := bw * 0.5
	var wr := 0.435
	var sill := 0.46
	var roof := 2.86
	var belt := 1.74
	var glass_top := 2.60
	var axf := hl - 1.20
	var axr := -hl + 1.90

	var spec := {
		"half_len": hl, "sill_y": sill, "arch_r": wr * 1.22, "arch_cy": wr,
		"axle_r": axr, "axle_f": axf,
		"rear_low_y": sill + 0.10, "front_low_y": sill + 0.12,
		"top": [
			Vector2(hl + 0.04, 0.95),              # bumper / grille band
			Vector2(hl + 0.05, 1.34),
			Vector2(hl - 0.02, 1.44),              # base of the windscreen
			Vector2(hl - 0.30, glass_top + 0.03),  # screen rake: upright, slight
			Vector2(hl - 0.36, roof - 0.10),       # destination board header
			Vector2(hl - 0.50, roof),              # roof front
			Vector2(-hl + 0.42, roof),
			Vector2(-hl + 0.14, roof - 0.085),     # rear roof radius
			Vector2(-hl - 0.02, glass_top - 0.10),
			Vector2(-hl - 0.05, 1.30),             # rear panel
			Vector2(-hl - 0.03, sill + 0.44),
		] as Array[Vector2],
	}
	var body := _cached_mesh("minibus_%.2f_%.2f" % [hl, bw], func() -> Mesh:
		return _loft(_car_profile(spec), bw, {"edge": 0.070, "taper": 0.968}))
	rig.part("Body", body, rig.mat_paint, Vector3.ZERO, Vector3.ZERO, "paint")

	# Side window band: one loft, mullions laid over it.
	var band := PackedVector2Array([
		Vector2(hl - 0.52, belt),
		Vector2(-hl + 0.30, belt),
		Vector2(-hl + 0.26, glass_top),
		Vector2(hl - 0.56, glass_top),
	])
	var band_mesh := _cached_mesh("busband_%.2f" % hl, func() -> Mesh:
		return _loft(band, bw - 0.09, {"edge": 0.03, "taper": 0.995}))
	rig.part("Glass", band_mesh, rig.mat_glass, Vector3.ZERO, Vector3.ZERO, "glass")

	# Windscreen: a separate raked plate, because forward control means the
	# screen is not part of the side profile at all.
	var sa := Vector2(hl - 0.02, 1.44)
	var sb := Vector2(hl - 0.30, glass_top + 0.03)
	var sd := sb - sa
	var ws := rig.part("Windscreen", _unit_box(), rig.mat_glass,
		Vector3((sa.x + sb.x) * 0.5 - 0.05, (sa.y + sb.y) * 0.5, 0.0),
		Vector3.ZERO, "glass")
	ws.scale = Vector3(sd.length(), 0.05, bw - 0.18)
	ws.rotation.z = sd.angle()

	var side := hw - 0.014
	# Mullions. Five per side: enough to read as a bus, few enough to afford.
	var band_len := (hl - 0.56) - (-hl + 0.30)
	for i in 5:
		var mx := -hl + 0.55 + (float(i) + 0.5) * (band_len - 0.5) / 5.0
		rig.trim_pair(rig.mat_paint, Vector3(0.095, glass_top - belt + 0.04, 0.080),
			Vector3(mx, (belt + glass_top) * 0.5, side))
	# Window seals top and bottom — the two horizontals that make the band.
	rig.trim_pair(rig.mat_dark, Vector3(band_len + 0.10, 0.070, 0.082),
		Vector3(0.0, belt - 0.024, hw + 0.006))
	rig.trim_pair(rig.mat_dark, Vector3(band_len + 0.10, 0.060, 0.082),
		Vector3(0.0, glass_top + 0.022, hw + 0.006))

	# Livery stripe along the waist. Every bus on that coast has been repainted
	# at least twice and the stripe is where the second colour goes.
	rig.trim_pair(rig.mat_accent, Vector3(hl * 2.0 - 0.12, 0.30, 0.050),
		Vector3(0.0, belt - 0.30, hw + 0.012))

	# Luggage door low on the side, plus its shut lines.
	var lx := -hl + 1.05
	rig.trim(rig.mat_accent, Vector3(1.34, 0.72, 0.050),
		Vector3(lx, 1.02, hw + 0.010))
	rig.flat(rig.mat_line, Vector2(1.38, 0.016), Vector3(lx, 1.39, hw + 0.016))
	rig.flat(rig.mat_line, Vector2(1.38, 0.016), Vector3(lx, 0.65, hw + 0.016))
	rig.trim(rig.mat_bright, Vector3(0.20, 0.055, 0.060),
		Vector3(lx + 0.55, 1.02, hw + 0.030))
	# Passenger door shut line, forward.
	rig.flat_pair(rig.mat_line, Vector2(0.020, belt - sill - 0.28),
		Vector3(hl - 1.55, (belt + sill) * 0.5 + 0.10, hw + 0.006))

	# Destination board over the screen, and the header panel behind it.
	rig.trim(rig.mat_bright, Vector3(0.090, 0.32, bw - 0.34),
		Vector3(hl - 0.23, roof - 0.24, 0.0), 0.10)
	var dest := str(opts.get("destination", ""))
	if dest != "":
		# The board is raked back with the header, so the text goes with it.
		var text_mat := MaterialLab.emissive(Color(0.90, 0.86, 0.70), 0.6)
		var sign := PropKit.sign(rig.root, dest,
			Vector3(hl - 0.16, roof - 0.245, 0.0), 0.19, text_mat,
			PropKit.FONT_NASKH_BOLD, 0.0)
		sign.rotation = Vector3(0.0, PI * 0.5, 0.10)
		sign.set_meta("vk_role", "detail")

	# Roof rack: two rails and five cross bars, with a load under a net.
	var rack_y := roof + 0.10
	rig.trim_pair(rig.mat_dark, Vector3(hl * 1.72, 0.070, 0.085),
		Vector3(-0.20, rack_y, hw - 0.26))
	for i in 5:
		rig.trim(rig.mat_dark, Vector3(0.070, 0.070, bw - 0.46),
			Vector3(-hl + 0.90 + i * (hl * 1.6) / 5.0, rack_y - 0.02, 0.0))
	if opts.get("roof_load", true):
		var bundle := MaterialLab.cloth(Color(0.470, 0.420, 0.330), 0.96)
		for i in 2:
			rig.trim(bundle, Vector3(1.20, 0.44, bw - 0.60),
				Vector3(-hl + 1.5 + i * 1.55, rack_y + 0.26, 0.0),
				rig.rng.randf_range(-0.05, 0.05))

	# Ends: bumpers, grille, lamps, plate.
	rig.trim(rig.mat_dark, Vector3(0.30, 0.30, bw + 0.04),
		Vector3(hl + 0.18, sill + 0.34, 0.0))
	rig.trim(rig.mat_dark, Vector3(0.28, 0.28, bw + 0.04),
		Vector3(-hl - 0.18, sill + 0.32, 0.0))
	rig.trim(rig.mat_dark, Vector3(0.08, 0.26, bw * 0.60),
		Vector3(hl + 0.06, 1.14, 0.0))
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_lamp_clear, Vector3(0.085, 0.20, 0.30),
			Vector3(hl + 0.06, 1.02, s * bw * 0.34))
		rig.trim(rig.mat_lamp_red, Vector3(0.070, 0.30, 0.22),
			Vector3(-hl - 0.07, 1.30, s * bw * 0.36))
	rig.trim(rig.mat_bright, Vector3(0.035, 0.14, 0.46),
		Vector3(-hl - 0.10, sill + 0.48, 0.0))
	# Mirrors: a bracket off the A-pillar and a tall head on the end of it. A
	# bus mirror head floating with no arm behind it is one of those details
	# nobody names but everybody sees, and on a vehicle this square it is the
	# only thing breaking the front corner.
	rig.trim_pair(rig.mat_dark, Vector3(0.34, 0.055, 0.055),
		Vector3(hl - 0.22, glass_top - 0.22, hw + 0.05), -0.22)
	rig.trim_pair(rig.mat_dark, Vector3(0.075, 0.44, 0.17),
		Vector3(hl - 0.06, glass_top - 0.38, hw + 0.13))
	var wd := sd.normalized()
	var wip := sa.lerp(sb, 0.34) + Vector2(wd.y, -wd.x) * 0.075
	rig.trim(rig.mat_dark, Vector3(0.78, 0.032, 0.036),
		Vector3(wip.x, wip.y, hw * 0.42), wd.angle())

	# Arches, wheels. Dual rears if asked, which is the right look for the
	# heavier midibuses and costs two more instances in an existing MultiMesh.
	var arch_r: float = spec["arch_r"]
	var lip := _cached_mesh("lip_%.3f" % arch_r, func() -> Mesh:
		return _crescent(arch_r, arch_r + 0.09, 9))
	for ax: float in [axf, axr]:
		_arch_lip(rig, lip, Vector3(ax, wr, hw + 0.022))
		rig.trim(rig.mat_line, Vector3(arch_r * 1.9, arch_r * 1.2, bw - 0.70),
			Vector3(ax, wr + 0.08, 0.0))

	rig.wheel_mesh = _wheel_mesh(wr, wr * 0.52)
	var track := hw - wr * 0.34
	rig.axle(axf, wr, track)
	if opts.get("dual_rear", false):
		rig.axle(axr, wr, track)
		rig.axle(axr, wr, track - wr * 0.56)
	else:
		rig.axle(axr, wr, track)

	rig.root.set_meta("vk_size", Vector3(hl * 2.0, roof, bw))
	var node := rig.flush()
	if opts.get("collide", true):
		# Two boxes: the body, and the roof rack as a second standing surface.
		# The player lands on the roof, so the top of the first box has to BE
		# the roof line, not an approximation of it.
		_collider(node, Vector3(hl * 2.0, roof, bw), Vector3(0, roof * 0.5, 0))
	if opts.get("wrecked", false):
		wreck(node, seed_)
	return node


# =============================================================================
# TRUCKS
# =============================================================================

## Cab-over tractor unit. European forward control, which is what runs that
## coast road: a tall flat cab over the front axle, a sun visor, twin stacks,
## a bogie under a deep chassis notch.
##
## Built as two lofts — the cab (full width) and the chassis rail (narrow) —
## because a chassis rail as wide as a cab is the thing that makes every
## code-built lorry look like a bread van. Measured: 2 950 tris, 11 draws.
static func tractor_unit(parent: Node3D, at: Vector3,
		body_colour := FLEET_COLOURS[6], seed_ := 0, opts := {}) -> Node3D:
	var rig := _rig(parent, at, str(opts.get("name", "Tractor")), body_colour,
		seed_, opts)
	var bw := 2.46
	var hw := bw * 0.5
	var wr := 0.55
	var cab_front := 2.90
	var cab_back := 0.52
	var roof := 3.00
	var rail_top := 1.22
	var rail_bot := 0.98
	var axf := 1.88
	var axr := -1.28

	# Cab: from the bumper line up over the screen and down the back.
	var cab := PackedVector2Array([
		Vector2(cab_front - 0.06, rail_bot - 0.24),
		Vector2(cab_front + 0.02, 1.34),
		Vector2(cab_front, 1.62),                 # base of the screen
		Vector2(cab_front - 0.20, 2.84),          # top of the screen
		Vector2(cab_front - 0.34, roof),          # roof front, over the visor
		Vector2(cab_back + 0.16, roof + 0.02),
		Vector2(cab_back, roof - 0.12),
		Vector2(cab_back - 0.02, rail_bot - 0.20),
	])
	var cab_mesh := _cached_mesh("tractorcab", func() -> Mesh:
		return _loft(cab, bw, {"edge": 0.075, "taper": 0.962}))
	rig.part("Cab", cab_mesh, rig.mat_paint, Vector3.ZERO, Vector3.ZERO, "paint")

	# Chassis rail: narrow, and it runs the whole length under everything.
	rig.trim(rig.mat_accent, Vector3(cab_front + 3.30, rail_top - rail_bot, 0.94),
		Vector3(cab_front * 0.5 - 1.65, (rail_top + rail_bot) * 0.5, 0.0))
	rig.trim(rig.mat_accent, Vector3(cab_front + 3.30, 0.10, 0.20),
		Vector3(cab_front * 0.5 - 1.65, rail_top, 0.0))

	# Windscreen and side glass.
	var sa := Vector2(cab_front, 1.62)
	var sb := Vector2(cab_front - 0.20, 2.84)
	var sd := sb - sa
	var scr := rig.part("Windscreen", _unit_box(), rig.mat_glass,
		Vector3((sa.x + sb.x) * 0.5 - 0.055, (sa.y + sb.y) * 0.5, 0.0),
		Vector3.ZERO, "glass")
	scr.scale = Vector3(sd.length(), 0.05, bw - 0.22)
	scr.rotation.z = sd.angle()
	rig.trim_pair(rig.mat_glass, Vector3(1.05, 0.95, 0.05),
		Vector3(cab_front - 1.10, 2.06, hw - 0.035))
	rig.trim_pair(rig.mat_dark, Vector3(1.18, 0.070, 0.085),
		Vector3(cab_front - 1.10, 1.56, hw + 0.006))

	var wd := sd.normalized()
	for s: float in [0.30, -0.30]:
		var wip := sa.lerp(sb, 0.30) + Vector2(wd.y, -wd.x) * 0.075
		rig.trim(rig.mat_dark, Vector3(1.05, 0.036, 0.040),
			Vector3(wip.x, wip.y, s * bw * 0.5), wd.angle())
	# Sun visor over the screen: the single most recognisable thing on a
	# cab-over, and it is one box.
	rig.trim(rig.mat_accent, Vector3(0.38, 0.115, bw + 0.02),
		Vector3(cab_front - 0.24, roof + 0.03, 0.0), -0.16)
	# Grille, bumper, steps, lamps.
	rig.trim(rig.mat_dark, Vector3(0.09, 0.46, bw * 0.70),
		Vector3(cab_front + 0.045, 1.18, 0.0))
	rig.trim(rig.mat_dark, Vector3(0.30, 0.32, bw + 0.06),
		Vector3(cab_front + 0.14, rail_bot - 0.30, 0.0))
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_lamp_clear, Vector3(0.09, 0.22, 0.34),
			Vector3(cab_front + 0.05, 1.10, s * bw * 0.33))
		# Step into the cab, behind the front wheel.
		for st in 2:
			rig.trim(rig.mat_dark, Vector3(0.34, 0.055, 0.38),
				Vector3(cab_front - 1.62, 0.62 + st * 0.36, s * (hw - 0.14)))
	# Exhaust stack and the air tanks under the rail.
	rig.trim(rig.mat_bright, Vector3(0.14, 2.10, 0.14),
		Vector3(cab_back - 0.10, 1.90, hw - 0.18))
	rig.part("AirTank", _cyl(0.19, 0.80, 10), rig.mat_bright,
		Vector3(0.10, rail_bot - 0.18, -hw * 0.45), Vector3(0, 0, PI * 0.5), "trim")
	# Fuel tank: a big cylinder on the near side, under the cab door.
	rig.part("FuelTank", _cyl(0.33, 1.25, 14), rig.mat_bright,
		Vector3(0.62, rail_bot - 0.26, hw - 0.30), Vector3(0, 0, PI * 0.5), "trim")
	# Fifth wheel plate, where the trailer sits.
	rig.trim(rig.mat_dark, Vector3(1.10, 0.13, 1.00),
		Vector3(-1.05, rail_top + 0.08, 0.0))

	# Running gear.
	_mudguard(rig, axf, wr, hw, 1.34)
	_mudguard(rig, axr, wr, hw, 1.34)
	rig.wheel_mesh = _wheel_mesh(wr, wr * 0.48)
	var track := hw - wr * 0.30
	rig.axle(axf, wr, track)
	rig.axle(axr, wr, track)
	rig.axle(axr - 1.28, wr, track)
	_mudguard(rig, axr - 1.28, wr, hw, 1.34)

	rig.root.set_meta("vk_size", Vector3(cab_front + 3.30, roof, bw))
	var node := rig.flush()
	if opts.get("collide", false):
		_collider(node, Vector3(cab_front - cab_back + 0.4, roof, bw),
			Vector3((cab_front + cab_back) * 0.5, roof * 0.5, 0))
	if opts.get("wrecked", false):
		wreck(node, seed_)
	return node


## Tanker trailer. Barrel with dished ends, a top catwalk with a rail, three
## manhole domes, the discharge cabinet at the back, landing legs and a bogie.
## With `tractor` (default true) the unit is coupled on the front.
##
## Measured: 3 753 tris and 11 draws for the trailer alone, plus the tractor
## if asked. `at` is the ground point under the middle of the BARREL, not the
## middle of the whole artic — the unit is parented in front of it.
static func tanker_trailer(parent: Node3D, at: Vector3,
		body_colour := Color(0.700, 0.686, 0.648), seed_ := 0,
		opts := {}) -> Node3D:
	var rig := _rig(parent, at, str(opts.get("name", "Tanker")), body_colour,
		seed_, opts)
	var len_ := float(opts.get("length", 8.60))
	var hl := len_ * 0.5
	var r := 1.12
	var cy := 2.02
	var bw := 2.48
	var hw := bw * 0.5
	var wr := 0.52

	rig.part("Barrel", _cyl(r, len_, 20), rig.mat_paint, Vector3(0, cy, 0),
		Vector3(0, 0, PI * 0.5), "paint")
	var cap := _cyl(r * 0.99, r * 0.62, 20, r * 0.52)
	for s: float in [-1.0, 1.0]:
		rig.batch(cap, rig.mat_paint, Transform3D(
			Basis(Vector3(0, 0, 1), s * PI * 0.5),
			Vector3(s * (hl + r * 0.30), cy, 0)))
	# Baffle rings. A tanker barrel with no rings is a pipe, and the rings are
	# the only thing that gives its length any rhythm.
	var ring := _cyl(r * 1.02, 0.09, 20)
	for i in 5:
		rig.batch(ring, rig.mat_bright, Transform3D(
			Basis(Vector3(0, 0, 1), PI * 0.5),
			Vector3(-hl + (float(i) + 0.5) * len_ / 5.0, cy, 0)), "trim")
	# Catwalk along the top, with a fold-down rail on the near side.
	rig.trim(rig.mat_bright, Vector3(len_ * 0.86, 0.06, 0.52),
		Vector3(0, cy + r + 0.02, 0.0))
	for i in 7:
		rig.trim(rig.mat_bright, Vector3(0.055, 0.60, 0.055),
			Vector3(-hl * 0.86 + i * (len_ * 0.86) / 6.0, cy + r + 0.32, 0.30))
	rig.trim(rig.mat_bright, Vector3(len_ * 0.86, 0.055, 0.055),
		Vector3(0, cy + r + 0.62, 0.30))
	# Manholes.
	var dome := _cyl(0.34, 0.16, 12)
	for i in 3:
		rig.batch(dome, rig.mat_bright, Transform3D(Basis.IDENTITY,
			Vector3(-len_ * 0.30 + i * len_ * 0.30, cy + r + 0.05, -0.22)),
			"trim")
	# Discharge cabinet and hose tube at the tail.
	rig.trim(rig.mat_accent, Vector3(0.90, 0.95, bw - 0.30),
		Vector3(-hl - 0.10, 1.10, 0.0))
	rig.part("HoseTube", _cyl(0.17, 3.40, 10), rig.mat_bright,
		Vector3(0.40, 1.16, hw - 0.14), Vector3(0, 0, PI * 0.5), "trim")
	# Rear underrun bar and lamps — the legally required bit, and the detail
	# that stops the back of a trailer being a blank wall.
	rig.trim(rig.mat_dark, Vector3(0.12, 0.14, bw - 0.14),
		Vector3(-hl - 0.55, 0.62, 0.0))
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_dark, Vector3(0.10, 0.52, 0.10),
			Vector3(-hl - 0.55, 0.88, s * (hw - 0.22)))
		rig.trim(rig.mat_lamp_red, Vector3(0.07, 0.24, 0.20),
			Vector3(-hl - 0.60, 0.72, s * (hw - 0.45)))

	_trailer_gear(rig, hl, bw, wr, opts)
	rig.root.set_meta("vk_size", Vector3(len_, cy + r, bw))
	var node := rig.flush()
	if opts.get("tractor", true):
		tractor_unit(node, Vector3(hl + 1.70, 0, 0), body_colour.darkened(0.15),
			seed_ + 1, {"ground_y": at.y})
	if opts.get("collide", false):
		_collider(node, Vector3(len_, r * 2.0, bw), Vector3(0, cy, 0))
	if opts.get("wrecked", false):
		wreck(node, seed_)
	return node


## Flatbed trailer: deck, headboard, stake pockets, running gear and a strapped
## load. Measured: 4 093 tris, 7 draws with a pipe load.
static func flatbed_trailer(parent: Node3D, at: Vector3,
		body_colour := FLEET_COLOURS[5], seed_ := 0, opts := {}) -> Node3D:
	var rig := _rig(parent, at, str(opts.get("name", "Flatbed")), body_colour,
		seed_, opts)
	var len_ := float(opts.get("length", 8.60))
	var hl := len_ * 0.5
	var bw := 2.48
	var hw := bw * 0.5
	var wr := 0.52
	var deck := 1.36

	rig.trim(rig.mat_paint, Vector3(len_, 0.22, bw), Vector3(0, deck - 0.11, 0))
	# Side rave and stake pockets: the row of little uprights along the deck
	# edge is what reads as "trailer" from any distance at all.
	rig.trim_pair(rig.mat_accent, Vector3(len_, 0.20, 0.10),
		Vector3(0, deck - 0.10, hw + 0.004))
	for i in 9:
		var px := -hl + 0.45 + i * (len_ - 0.9) / 8.0
		rig.trim_pair(rig.mat_accent, Vector3(0.11, 0.30, 0.11),
			Vector3(px, deck + 0.04, hw - 0.02))
	# Headboard.
	rig.trim(rig.mat_accent, Vector3(0.13, 1.85, bw - 0.06),
		Vector3(hl - 0.10, deck + 0.92, 0.0))
	for i in 3:
		rig.trim(rig.mat_accent, Vector3(0.09, 0.09, bw - 0.10),
			Vector3(hl - 0.02, deck + 0.35 + i * 0.66, 0.0))
	# Chassis rails under the deck, narrow.
	rig.trim(rig.mat_dark, Vector3(len_ - 0.20, 0.26, 0.98),
		Vector3(0, deck - 0.36, 0.0))

	match str(opts.get("load", "pipes")):
		"crates":
			var crate := MaterialLab.cloth(Color(0.392, 0.268, 0.152), 0.94)
			for i in 5:
				rig.trim(crate, Vector3(1.05, 0.84, bw - 0.40),
					Vector3(-hl + 1.0 + i * 1.5, deck + 0.42, 0.0),
					rig.rng.randf_range(-0.02, 0.02))
		"tarp":
			var tarp := MaterialLab.cloth(Color(0.180, 0.220, 0.190), 0.96)
			rig.trim(tarp, Vector3(len_ - 1.2, 1.35, bw - 0.18),
				Vector3(-0.2, deck + 0.68, 0.0))
			for i in 5:
				rig.trim(rig.mat_dark, Vector3(0.05, 1.45, bw - 0.12),
					Vector3(-hl + 1.1 + i * 1.5, deck + 0.68, 0.0))
		"empty":
			pass
		_:
			# Pipes: a stack of cylinders under two straps. Cheap, reads
			# instantly, and it is what actually moves on that road.
			var pipe := MaterialLab.rusted_metal(Color(0.300, 0.176, 0.118), 0.8)
			var tube := _cyl(0.26, len_ - 1.4, 10)
			for row in 2:
				for i in (4 - row):
					rig.batch(tube, pipe, Transform3D(
						Basis(Vector3(0, 0, 1), PI * 0.5),
						Vector3(-0.2, deck + 0.28 + row * 0.46,
							-0.78 + i * 0.52 + row * 0.26)), "trim")
			for i in 2:
				rig.trim(rig.mat_dark, Vector3(0.05, 1.05, bw - 0.20),
					Vector3(-hl + 2.2 + i * 3.4, deck + 0.50, 0.0))

	_trailer_gear(rig, hl, bw, wr, opts)
	rig.root.set_meta("vk_size", Vector3(len_, deck + 1.9, bw))
	var node := rig.flush()
	if opts.get("tractor", true):
		tractor_unit(node, Vector3(hl + 1.70, 0, 0), body_colour.darkened(0.15),
			seed_ + 1, {"ground_y": at.y})
	if opts.get("collide", false):
		_collider(node, Vector3(len_, 0.3, bw), Vector3(0, deck - 0.15, 0))
	if opts.get("wrecked", false):
		wreck(node, seed_)
	return node


## Bogie, mudguards, landing legs and the kingpin plate — identical on both
## trailer types, so it lives once.
static func _trailer_gear(rig: Rig, hl: float, bw: float, wr: float,
		opts: Dictionary) -> void:
	var hw := bw * 0.5
	var axles := int(opts.get("axles", 2))
	rig.wheel_mesh = _wheel_mesh(wr, wr * 0.46)
	var track := hw - wr * 0.28
	for i in axles:
		var ax := -hl + 1.05 + i * 1.32
		_mudguard(rig, ax, wr, hw, 1.30)
		rig.axle(ax, wr, track)
		rig.axle(ax, wr, track - wr * 0.52)
	# Landing legs, forward, with their feet on the deck.
	for s: float in [1.0, -1.0]:
		rig.trim(rig.mat_dark, Vector3(0.14, 1.10, 0.14),
			Vector3(hl - 2.20, 0.62, s * (hw - 0.40)))
		rig.trim(rig.mat_dark, Vector3(0.36, 0.10, 0.30),
			Vector3(hl - 2.20, 0.08, s * (hw - 0.40)))
	rig.trim(rig.mat_dark, Vector3(0.10, 0.10, bw - 0.70),
		Vector3(hl - 2.20, 1.06, 0.0))
	# Kingpin plate.
	rig.trim(rig.mat_dark, Vector3(1.30, 0.10, 1.10),
		Vector3(hl - 0.70, 1.08, 0.0))


## A mudguard over an axle: a crescent plate on each side plus a dark valance
## between them. Reuses the wheel-arch crescent, which is the only shape a
## mudguard has ever been.
static func _mudguard(rig: Rig, x: float, wr: float, hw: float,
		scale_ := 1.30) -> void:
	var r := wr * scale_
	var mesh := _cached_mesh("lip_%.3f" % r, func() -> Mesh:
		return _crescent(r, r + 0.11, 9))
	rig.batch(mesh, rig.mat_accent,
		Transform3D(Basis.IDENTITY, Vector3(x, wr, hw + 0.02)))
	rig.batch(mesh, rig.mat_accent, Transform3D(Basis(Vector3.UP, PI),
		Vector3(x, wr, -hw - 0.02)))
	rig.trim(rig.mat_dark, Vector3(r * 1.9, 0.10, hw * 2.0 - 0.08),
		Vector3(x, wr + r * 0.92, 0.0))


# =============================================================================
# WRECKS
# =============================================================================

## Turn a finished vehicle into a burnt-out one, in place.
##
## Brega is full of these and they are the cheapest environmental storytelling
## in the game: a wreck says what happened here without a line of dialogue. The
## modifier does five things, in the order they matter visually:
##
##  1. Paint becomes bare, oxidised steel under soot.
##  2. Glass is gone entirely. An intact windscreen on a burnt shell is the
##     single fastest way to kill the read.
##  3. The suspension is collapsed — the body drops onto squashed tyres and
##     sits nose-down, which is the pose that says "this has been here years".
##  4. Some trim is stripped. Whole instances are scaled to zero rather than
##     the MultiMesh being rebuilt, so the strip costs nothing.
##  5. Soot fans above every opening.
static func wreck(vehicle: Node3D, seed_ := 0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 131 + 7
	var burnt := burnt_material(seed_)
	var soot := PropKit.gradient_decal(Color(0.040, 0.034, 0.030), 0.78, "streak")
	var size: Vector3 = vehicle.get_meta("vk_size", Vector3(4.0, 1.5, 1.8))

	var stack: Array[Node] = [vehicle]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var role := str(n.get_meta("vk_role", ""))
		if role == "glass":
			n.queue_free()
			continue
		var gi := n as GeometryInstance3D
		if gi == null:
			continue
		if role == "paint" or role == "trim":
			gi.material_override = burnt
		var mmi := n as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mm := mmi.multimesh
		if role == "trim" or role == "detail":
			# Strip about a fifth of the small parts. A wreck that still has
			# every seal and door handle on it is a repaint, not a wreck.
			# Scaling an instance to zero is free; rebuilding the MultiMesh
			# would not be.
			for i in mm.instance_count:
				if rng.randf() < 0.22:
					mm.set_instance_transform(i, Transform3D(
						Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		elif role == "wheel":
			for i in mm.instance_count:
				var xf := mm.get_instance_transform(i)
				if rng.randf() < 0.35:
					# Wheel gone: rim only, sunk into the ground.
					xf = xf.scaled_local(Vector3(0.62, 0.62, 1.0))
					xf.origin.y *= 0.42
				else:
					# Burst tyre, sitting on its rim.
					xf = xf.scaled_local(Vector3(1.0, 0.74, 1.0))
					xf.origin.y *= 0.80
				mm.set_instance_transform(i, xf)

	# Sit down and lean. Two degrees of roll is plenty — any more and it looks
	# like it was dropped rather than abandoned.
	var drop := size.y * 0.075
	vehicle.position.y -= drop
	# Negative roll about Z drops the nose, which is the way a shell always
	# settles: the engine is the heaviest thing on it and the front springs go
	# first. Two degrees is plenty — more and it reads as dropped, not left.
	vehicle.rotation.z += rng.randf_range(-0.045, -0.008)
	vehicle.rotation.x += rng.randf_range(-0.02, 0.02)

	# Soot fans above the window line, on both sides. This is the read: fire
	# comes out of the openings and paints the panel above them black.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _unit_quad()
	mm.instance_count = 6
	var k := 0
	for s: float in [1.0, -1.0]:
		for i in 3:
			var basis := Basis(Vector3.UP, 0.0 if s > 0.0 else PI).scaled_local(
				Vector3(rng.randf_range(0.5, 1.1), rng.randf_range(0.5, 0.9), 1.0))
			mm.set_instance_transform(k, Transform3D(basis, Vector3(
				rng.randf_range(-size.x * 0.34, size.x * 0.34),
				size.y * rng.randf_range(0.62, 0.92),
				s * (size.z * 0.5 + 0.02))))
			k += 1
	var soot_node := MultiMeshInstance3D.new()
	soot_node.name = "Soot"
	soot_node.multimesh = mm
	soot_node.material_override = soot
	soot_node.set_meta("vk_role", "soot")
	vehicle.add_child(soot_node)
	return vehicle


# =============================================================================
# STREETS
# =============================================================================

## Fill a stretch of kerb with parked vehicles from one call.
##
## `z` is the kerb line and `y` the road surface. Spacing, type, colour and
## facing all come off `seed_`, so a street is deterministic run to run but two
## streets in one level are different streets. Returns the container.
static func parked_row(parent: Node3D, from_x: float, to_x: float, y: float,
		z: float, seed_ := 0, opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = str(opts.get("name", "ParkedRow"))
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 5471 + 29
	var density := float(opts.get("density", 1.0))
	var wreck_chance := float(opts.get("wreck_chance", 0.0))

	var x := from_x
	var i := 0
	while x < to_x:
		# Gaps matter more than cars. A kerb parked solid reads as a wall; the
		# gaps are what make it read as a street somebody uses.
		x += rng.randf_range(6.5, 15.0) / maxf(density, 0.15)
		if x > to_x:
			break
		i += 1
		var colour: Color = FLEET_COLOURS[rng.randi() % FLEET_COLOURS.size()]
		var at := Vector3(x, y, z + rng.randf_range(-0.22, 0.22))
		var o := {
			"facing": 1.0 if rng.randf() < 0.62 else -1.0,
			"name": "Parked%d" % i,
			# Quantised, not continuous: gloss is part of the paint cache key,
			# so four steps means a street of thirty cars shares a handful of
			# materials instead of minting one apiece.
			"gloss": [0.50, 0.66, 0.80, 0.92][rng.randi() % 4],
			"wrecked": rng.randf() < wreck_chance,
		}
		match rng.randi() % 8:
			0, 1, 2:
				saloon(root, at, colour, seed_ + i, o)
			3, 4:
				hatchback(root, at, colour, seed_ + i, o)
			5:
				estate(root, at, colour, seed_ + i, o)
			_:
				o["load"] = ["mixed", "sacks", "drums", "empty"][rng.randi() % 4]
				pickup(root, at, colour, seed_ + i, o)
	return root


## A single wheel as a prop: spares leant against walls, a stack outside a tyre
## shop, the one thing every yard on that coast has too many of.
static func spare_wheel(parent: Node3D, at: Vector3, radius := 0.32,
		lean := 0.12) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "SpareWheel"
	mi.mesh = _wheel_mesh(radius, radius * 0.70)
	mi.material_override = wheel_material()
	mi.position = at + Vector3(0, radius, 0)
	# No quarter turn here: the wheel mesh already revolves about Z, which for
	# a side-on game IS upright. Rotating it to "stand it up" lays it flat on
	# the tarmac instead. All it wants is the lean, tipped away from camera as
	# though propped against something, because a wheel standing dead upright
	# on its own is the one thing a wheel never does.
	mi.rotation = Vector3(-lean, 0.0, 0.0)
	mi.set_meta("vk_role", "wheel")
	parent.add_child(mi)
	return mi


# =============================================================================
# GEOMETRY
# =============================================================================

## Loft a closed 2D outline across Z into a solid with chamfered side edges.
##
## This is the whole trick of the library. Four rings: an inset, tapered
## section at each extreme z, and the full section just inboard of it. The gap
## between them is the side chamfer, which is what catches the rim light along
## the top of a roof and down the edge of a bonnet — the same reason every box
## in this project is chamfered, applied to a shape that is not a box.
##
## Cost: 6 tris per outline edge, plus two caps. A 34-point car profile is
## about 270 triangles for the entire body.
static func _loft(outline: PackedVector2Array, width: float,
		opts := {}) -> ArrayMesh:
	var poly := _ccw(outline)
	var n := poly.size()
	var hw := width * 0.5
	var edge: float = minf(float(opts.get("edge", 0.055)), hw * 0.45)
	var taper: float = float(opts.get("taper", 0.97))

	var inner := poly
	var outer := _scaled(_inset(poly, edge), _bbox_centre(poly), taper)
	var zs := [-hw, -hw + edge, hw - edge, hw]
	var rings := [outer, inner, inner, outer]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for band in 3:
		var za: float = zs[band]
		var zb: float = zs[band + 1]
		var ra: PackedVector2Array = rings[band]
		var rb: PackedVector2Array = rings[band + 1]
		# Reference direction: the edge's outward normal in the profile plane,
		# tilted toward the face this band belongs to.
		var zbias: float = [-0.85, 0.0, 0.85][band]
		for i in n:
			var j := (i + 1) % n
			var d := (inner[j] - inner[i])
			if d.length_squared() < 1e-10:
				continue
			d = d.normalized()
			var nrm := Vector3(d.y, -d.x, zbias).normalized()
			_quad(st,
				Vector3(ra[i].x, ra[i].y, za),
				Vector3(ra[j].x, ra[j].y, za),
				Vector3(rb[j].x, rb[j].y, zb),
				Vector3(rb[i].x, rb[i].y, zb), nrm)

	if opts.get("cap", true):
		_cap(st, outer, -hw, Vector3(0, 0, -1))
		_cap(st, outer, hw, Vector3(0, 0, 1))
	return st.commit()


## Triangulate one end of a loft. Ear clipping rather than a centre fan,
## because a pickup's bed notch is not star-shaped and a fan would roof it over.
static func _cap(st: SurfaceTool, poly: PackedVector2Array, z: float,
		outward: Vector3) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		# Fan fallback. Only reachable if an outline self-intersects, which is
		# a bug in the spec table, but a hole in a car is worse than a wrong
		# triangle.
		for i in range(1, poly.size() - 1):
			_tri(st, Vector3(poly[0].x, poly[0].y, z),
				Vector3(poly[i].x, poly[i].y, z),
				Vector3(poly[i + 1].x, poly[i + 1].y, z), outward)
		return
	for t in range(0, idx.size(), 3):
		_tri(st, Vector3(poly[idx[t]].x, poly[idx[t]].y, z),
			Vector3(poly[idx[t + 1]].x, poly[idx[t + 1]].y, z),
			Vector3(poly[idx[t + 2]].x, poly[idx[t + 2]].y, z), outward)


## Quad with a flat normal, wound so it faces `outward`.
##
## Godot winds FRONT faces CLOCKWISE. Emitting the counter-clockwise order here
## hides every outward face and leaves the inside of the body visible, which on
## a car means you see the far side of the roof through the near side of it.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, outward: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		nrm = (c - a).cross(d - a)
		if nrm.length_squared() < 1e-12:
			return
	nrm = nrm.normalized()
	var order := [0, 2, 1, 0, 3, 2]
	if nrm.dot(outward) < 0.0:
		nrm = -nrm
		order = [0, 1, 2, 0, 2, 3]
	var q := [a, b, c, d]
	for i: int in order:
		st.set_normal(nrm)
		st.set_uv(_planar_uv(q[i], nrm))
		st.add_vertex(q[i])


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		outward: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	nrm = nrm.normalized()
	var order := [0, 2, 1]
	if nrm.dot(outward) < 0.0:
		nrm = -nrm
		order = [0, 1, 2]
	var t := [a, b, c]
	for i: int in order:
		st.set_normal(nrm)
		st.set_uv(_planar_uv(t[i], nrm))
		st.add_vertex(t[i])


## Planar UV from the two axes the face does NOT point down. Nothing in this
## file uses a UV-mapped material — the weathering shader is world triplanar —
## but a mesh with a degenerate UV chart generates garbage tangents, and
## garbage tangents are enough to light a panel as though it faced the sun.
static func _planar_uv(p: Vector3, n: Vector3) -> Vector2:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ax >= ay and ax >= az:
		return Vector2(p.z, -p.y)
	if ay >= az:
		return Vector2(p.x, p.z)
	return Vector2(p.x, -p.y)


## Append an arc, inclusive of both ends. Angles in radians, CCW positive.
static func _arc(out: PackedVector2Array, cx: float, cy: float, r: float,
		a0: float, a1: float, segs: int) -> void:
	for i in segs + 1:
		var a := lerpf(a0, a1, float(i) / float(segs))
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))


## Inward miter offset, keeping the vertex count so rings stay in step.
static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var n := poly.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var p := poly[i]
		var prev := poly[(i - 1 + n) % n]
		var next := poly[(i + 1) % n]
		var e0 := (p - prev)
		var e1 := (next - p)
		if e0.length_squared() < 1e-10:
			e0 = e1
		if e1.length_squared() < 1e-10:
			e1 = e0
		e0 = e0.normalized()
		e1 = e1.normalized()
		var n0 := Vector2(e0.y, -e0.x)
		var n1 := Vector2(e1.y, -e1.x)
		var m := n0 + n1
		if m.length_squared() < 1e-9:
			m = n0
		m = m.normalized()
		# Miter length is d / cos(half-angle). Clamped, because a near-reflex
		# corner — and a wheel arch meeting a sill is exactly that — sends it
		# to infinity and would fire a spike across the door.
		out[i] = p - m * (d / maxf(m.dot(n0), 0.38))
	return out


static func _ccw(poly: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return poly
	var out := PackedVector2Array()
	for i in range(n - 1, -1, -1):
		out.append(poly[i])
	return out


static func _bbox_centre(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var lo := poly[0]
	var hi := poly[0]
	for p: Vector2 in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return (lo + hi) * 0.5


static func _scaled(poly: PackedVector2Array, pivot: Vector2,
		f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in poly:
		out.append(pivot + (p - pivot) * f)
	return out


## A flat arc ribbon: the wheel-arch flare and every mudguard in the file.
## 2 triangles per segment, standing proud of the body side.
static func _crescent(r_in: float, r_out: float, segs := 9) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := lerpf(PI, 0.0, float(i) / float(segs))
		var a1 := lerpf(PI, 0.0, float(i + 1) / float(segs))
		_quad(st,
			Vector3(cos(a0) * r_in, sin(a0) * r_in, 0.0),
			Vector3(cos(a1) * r_in, sin(a1) * r_in, 0.0),
			Vector3(cos(a1) * r_out, sin(a1) * r_out, 0.0),
			Vector3(cos(a0) * r_out, sin(a0) * r_out, 0.0),
			Vector3(0, 0, 1))
	return st.commit()


## The wheel, built once and shared by everything.
##
## Rings of revolution around Z, with per-vertex colour carrying the tyre/rim
## split so the whole thing is one mesh and one draw call. The profile has the
## three things a wheel needs to read as a wheel rather than a disc:
##
##   * a tread band with a shoulder that rounds off — the visible tread EDGE,
##     which is what tells you the tyre has width;
##   * a sidewall that tucks back IN toward the rim at the bead, so the tyre
##     has a section rather than being a filled circle;
##   * a rim flange standing proud of that bead.
##
## The spokes cost nothing: the dished ring alternates its radius per segment,
## which turns a smooth cone into a star. Ten segments gives five spokes,
## sixteen gives eight.
##
## ~16 tris per segment: 160 for a car wheel, 260 for a lorry wheel.
static func _wheel_mesh(r: float, w: float, opts := {}) -> Mesh:
	var segs: int = int(opts.get("segments", clampi(int(r * 30.0), 10, 18)))
	segs = segs + (segs % 2)
	var rim: float = r * float(opts.get("rim", 0.60))
	var key := "wheel_%.3f_%.3f_%d" % [r, w, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]

	var tyre := Color(0.082, 0.080, 0.080)
	var tyre_lit := Color(0.135, 0.130, 0.128)
	var steel := Color(0.600, 0.592, 0.578)
	var steel_dark := Color(0.260, 0.252, 0.248)
	var hw := w * 0.5

	# (z, radius, colour, star)
	var rings: Array = [
		[-hw, 0.0, tyre, false],                   # back hub — never seen
		[-hw, r * 0.97, tyre, false],
		[-hw + 0.10 * w, r, tyre, false],
		# The shoulder needs real depth across Z or the "tread edge" collapses
		# into a flat annulus and the tyre goes back to being a disc. 12% of the
		# width is enough to catch a highlight and read as a rounded edge.
		[hw - 0.18 * w, r, tyre, false],           # tread band
		[hw - 0.055 * w, r * 0.945, tyre_lit, false],  # shoulder: the tread edge
		[hw, r * 0.830, tyre_lit, false],          # sidewall face
		[hw - 0.05 * w, rim * 1.10, tyre, false],  # bead tuck, concave
		[hw + 0.015 * w, rim, steel, false],       # rim flange, proud
		[hw - 0.055 * w, rim * 0.68, steel, true], # dished face: the spokes
		[hw - 0.045 * w, rim * 0.26, steel_dark, false],
		[hw + 0.010 * w, 0.0, steel, false],       # hub cap crown
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in rings.size() - 1:
		var A: Array = rings[b]
		var B: Array = rings[b + 1]
		var za: float = A[0]
		var zb: float = B[0]
		for i in segs:
			var t0 := TAU * float(i) / float(segs)
			var t1 := TAU * float(i + 1) / float(segs)
			var ra0 := _spoke_r(A, i, segs)
			var ra1 := _spoke_r(A, i + 1, segs)
			var rb0 := _spoke_r(B, i, segs)
			var rb1 := _spoke_r(B, i + 1, segs)
			# Outward for a truncated cone band: radial scaled by the z run,
			# plus Z scaled by the radius fall. Degenerates correctly to pure
			# radial on a cylinder and pure ±Z on a flat annulus.
			var mid := Vector3(cos((t0 + t1) * 0.5), sin((t0 + t1) * 0.5), 0.0)
			var out := (mid * (zb - za) + Vector3(0, 0, ra0 - rb0))
			if out.length_squared() < 1e-9:
				out = mid
			out = out.normalized()
			if ra0 <= 0.0001:
				_tri_c(st, Vector3(0, 0, za),
					Vector3(cos(t0) * rb0, sin(t0) * rb0, zb),
					Vector3(cos(t1) * rb1, sin(t1) * rb1, zb), out,
					A[2], B[2], B[2])
			elif rb0 <= 0.0001:
				_tri_c(st, Vector3(cos(t0) * ra0, sin(t0) * ra0, za),
					Vector3(cos(t1) * ra1, sin(t1) * ra1, za),
					Vector3(0, 0, zb), out, A[2], A[2], B[2])
			else:
				_quad_c(st,
					Vector3(cos(t0) * ra0, sin(t0) * ra0, za),
					Vector3(cos(t1) * ra1, sin(t1) * ra1, za),
					Vector3(cos(t1) * rb1, sin(t1) * rb1, zb),
					Vector3(cos(t0) * rb0, sin(t0) * rb0, zb),
					out, A[2], B[2])
	var mesh: ArrayMesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh


## Radius for a ring at segment `i`, alternating on starred rings. This is the
## whole spoke trick: no extra geometry, just a radius that pulses.
static func _spoke_r(ring: Array, i: int, segs: int) -> float:
	var r: float = ring[1]
	if not ring[3]:
		return r
	return r if (i % 2 == 0) else r * 0.54


static func _quad_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, outward: Vector3, ca: Color, cb: Color) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	nrm = nrm.normalized()
	var order := [0, 2, 1, 0, 3, 2]
	if nrm.dot(outward) < 0.0:
		nrm = -nrm
		order = [0, 1, 2, 0, 2, 3]
	var q := [a, b, c, d]
	var cols := [ca, ca, cb, cb]
	for i: int in order:
		st.set_normal(nrm)
		st.set_color(cols[i])
		st.set_uv(_planar_uv(q[i], nrm))
		st.add_vertex(q[i])


static func _tri_c(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		outward: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.length_squared() < 1e-12:
		return
	nrm = nrm.normalized()
	var order := [0, 2, 1]
	if nrm.dot(outward) < 0.0:
		nrm = -nrm
		order = [0, 1, 2]
	var t := [a, b, c]
	var cols := [ca, cb, cc]
	for i: int in order:
		st.set_normal(nrm)
		st.set_color(cols[i])
		st.set_uv(_planar_uv(t[i], nrm))
		st.add_vertex(t[i])


# --- Shared primitives ------------------------------------------------------

## The unit trim box: 1x1x1, chamfered, scaled per instance. The chamfer scales
## anisotropically with it, which is technically wrong and completely invisible
## on a 70 mm seal — and it means every piece of trim on a vehicle shares one
## mesh and therefore one MultiMesh.
static func _unit_box() -> Mesh:
	if not _mesh_cache.has("unit_box"):
		_mesh_cache["unit_box"] = LevelKit.chamfer_mesh(Vector3.ONE, 0.055)
	return _mesh_cache["unit_box"]


static func _unit_quad() -> Mesh:
	if not _mesh_cache.has("unit_quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_mesh_cache["unit_quad"] = q
	return _mesh_cache["unit_quad"]


static func _cyl(radius: float, height: float, sides := 14,
		top_radius := -1.0) -> CylinderMesh:
	var top := radius if top_radius < 0.0 else top_radius
	var key := "cyl_%.3f_%.3f_%d_%.3f" % [radius, height, sides, top]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	_mesh_cache[key] = m
	return m


static func _cached_mesh(key: String, factory: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = factory.call()
	return _mesh_cache[key]


## Collision, when a level asks for it. A plain box: the chamfers and arches
## are centimetres of silhouette and must not change where the player stands.
static func _collider(vehicle: Node3D, size: Vector3, centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collider"
	body.position = centre
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	body.add_child(cs)
	vehicle.add_child(body)
	return body
