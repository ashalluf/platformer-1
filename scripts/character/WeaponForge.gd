class_name WeaponForge
## Builds Wanis's rifle.
##
## A stamped-receiver 7.62 pattern rifle: flat-sided receiver, wood furniture, a
## long gas tube floating above the barrel, a front sight tower, and the curved
## magazine that carries the whole silhouette. Original design, but the family
## is unmistakable, and that is the point — it has to read in one frame.
##
## Three rules run through this file.
##
## 1. Stamped sheet metal is FLAT with crisp edges, so every hard-surface part
##    is a LevelKit chamfered box, not a loft. Builder.commit() smooths normals,
##    and smoothed normals turn a receiver flat into a soft cylinder — that is
##    the single biggest reason the first pass of this rifle read as a toy.
##    Lofts are kept for what is genuinely round or genuinely curved: barrel,
##    gas tube, furniture, magazine, sling.
## 2. Detail is authored for two distances. At gameplay framing the rifle is
##    ~15% of screen height and only three things survive: the magazine curve,
##    the angled stock, and the gap between barrel and gas tube. Everything
##    finer than that exists for camera moves and the result card, and where it
##    is kept anyway the comment says why.
## 3. Nothing moves the grip. The rig poses hands with hand-tuned rotations
##    rather than IK (see WanisRig SLUNG_POS/READY_POS), so the origin-at-the-
##    grip convention and the front-end reach are load-bearing: shift them and
##    the hero holds air.

## --- Master dimensions ------------------------------------------------------
##
## The rifle is about 1.4x a real 7.62 pattern rifle relative to a 1.78 m hero.
## That is deliberate, not drift. A scale-accurate rifle on a stylized mascot
## with oversized hands and head reads as a twig, and at gameplay framing its
## magazine curve — the one shape the whole silhouette hangs on — falls under a
## couple of pixels. Internal proportions are honest to the real thing; only the
## multiplier is heroic. LENGTH is derived from the two ends so it cannot drift
## away from the geometry again.

const BORE_Y := 0.104          ## barrel centreline, above the grip origin
const GAS_Y := 0.166           ## gas tube centreline; the gap between is silhouette
const MUZZLE_Z := 0.868        ## front corner of the slant brake
const BUTT_Z := -0.372         ## back face of the butt plate
const LENGTH := MUZZLE_Z - BUTT_Z   ## muzzle to butt, in world units


## Hard-surface parts are queued here and merged per material before they reach
## the tree. An honestly built receiver is twenty separate stampings, and twenty
## MeshInstance3Ds on a prop the hero never puts down is twenty draw calls plus
## twenty shadow draws, every frame, forever.
class Batch extends RefCounted:
	var _parts: Array = []

	## `size` is the box, `pos` its centre, `rot_deg` an optional euler in
	## degrees. Bevels are explicit: LevelKit's default floor is 14 mm, which on
	## a 7 mm selector lever is not a chamfer, it is the whole part.
	func box(size: Vector3, pos: Vector3, mat: Material,
			rot_deg := Vector3.ZERO, bevel := -1.0) -> void:
		var smallest := minf(size.x, minf(size.y, size.z))
		var b := bevel if bevel > 0.0 else clampf(smallest * 0.20, 0.0012, 0.0040)
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
		_parts.append({
			"mesh": LevelKit.chamfer_mesh(size, b),
			"xform": Transform3D(basis, pos),
			"mat": mat,
		})

	func flush(root: Node3D) -> void:
		var groups: Dictionary = {}
		for p: Dictionary in _parts:
			var key: Material = p["mat"]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(p)

		var index := 0
		for key in groups:
			var mat: Material = key
			var list: Array = groups[key]
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p: Dictionary in list:
				st.append_from(p["mesh"], 0, p["xform"])
			var merged: ArrayMesh = st.commit()
			if merged != null and merged.get_surface_count() > 0:
				var mi := MeshInstance3D.new()
				mi.name = "Stamping%d" % index
				mi.mesh = merged
				mi.material_override = mat
				root.add_child(mi)
			else:
				# If the merge ever refuses a format, ship the parts loose
				# rather than ship a rifle with holes in it.
				for p: Dictionary in list:
					var mi2 := MeshInstance3D.new()
					mi2.mesh = p["mesh"]
					mi2.material_override = mat
					mi2.transform = p["xform"]
					root.add_child(mi2)
			index += 1


## --- Materials --------------------------------------------------------------

static func materials() -> Dictionary:
	# All StandardMaterial3D, never the weathering shader. That shader is
	# world-space triplanar with grime keyed to world height: on a prop that is
	# carried, swung and slung the texture would swim across the metal and the
	# dirt would slide up and down the rifle every time the hero jumps.
	var wood := MaterialLab.cloth(Color(0.352, 0.152, 0.066), 0.46)
	wood.rim = 0.22
	wood.rim_tint = 0.40
	wood.metallic_specular = 0.44
	wood.vertex_color_use_as_albedo = true

	# Parkerized stampings: dark, matte, barely specular. This is the value the
	# whole rifle sits at, which is why the furniture and the magazine are warm
	# — they are the only things that separate it from the hero's shadow side.
	var park := MaterialLab.chrome(Color(0.074, 0.071, 0.068), 0.58)
	park.metallic = 0.70
	park.metallic_specular = 0.45

	# Blued steel: barrel, gas tube, trigger. Smoother than the stampings so the
	# round parts catch a moving highlight and read as round.
	var blued := MaterialLab.chrome(Color(0.108, 0.105, 0.101), 0.33)
	blued.metallic = 0.92

	# Where a rifle is held and carried the finish simply goes. Charging handle,
	# selector, sight post, muzzle brake: bare steel, polished by hands and by
	# everything the muzzle has ever been dragged against.
	var worn := MaterialLab.chrome(Color(0.335, 0.330, 0.322), 0.21)
	worn.metallic = 1.0

	# Bakelite magazine. A warm magazine on a near-black rifle is the reason the
	# banana curve survives at gameplay size: the silhouette's most important
	# shape gets the only strong value break on the prop.
	#
	# It sits inside the reserved hero hue band, which cloth() deliberately does
	# not clamp — and that is fine, because the separation here is VALUE, not
	# chroma. At v=0.39 against a shemagh at v=0.78 the magazine can be warm
	# without ever competing with the red it belongs to.
	var mag := MaterialLab.cloth(Color(0.392, 0.176, 0.074), 0.38)
	mag.rim = 0.30
	mag.rim_tint = 0.35
	mag.metallic_specular = 0.48
	mag.vertex_color_use_as_albedo = true

	# Faded canvas sling.
	var sling := MaterialLab.cloth(Color(0.215, 0.198, 0.146), 0.88)
	sling.rim = 0.22
	sling.vertex_color_use_as_albedo = true

	# Openings. There is no boolean subtraction in this pipeline, so a hole is a
	# near-black plate sitting a millimetre proud of the surface. Not pure black
	# — a true void reads as missing geometry rather than as a port.
	var void_ := MaterialLab.cloth(Color(0.028, 0.026, 0.024), 0.86)
	void_.rim_enabled = false
	void_.metallic_specular = 0.2

	return {
		"wood": wood, "park": park, "blued": blued, "worn": worn,
		"mag": mag, "sling": sling, "void": void_,
		# Lofts always write a vertex colour (MeshForge defaults rings to BLACK,
		# so "no colour" is not an option), which is how wear gets painted along
		# a part's length for free. Boxes carry no COLOR array at all, so they
		# keep the plain variant: vertex colours enabled with no data behind
		# them is a black part waiting to happen.
		"blued_vc": _vc(blued), "worn_vc": _vc(worn),
	}


static func _vc(src: StandardMaterial3D) -> StandardMaterial3D:
	var d: StandardMaterial3D = src.duplicate()
	d.vertex_color_use_as_albedo = true
	return d


## Returns a Node3D holding the rifle, muzzle-forward along +Z, grip down.
## Origin sits at the grip, which is where a hand goes.
static func build() -> Node3D:
	var m := materials()
	var root := Node3D.new()
	root.name = "AK"
	var hard := Batch.new()

	_receiver(root, hard, m)
	_furniture(root, hard, m)
	_barrel(root, hard, m)
	_magazine(root, hard, m)
	_sling(root, m)
	hard.flush(root)

	# Muzzle marker: flash, tracers and shells all reference this. On the bore
	# line, not above it, so the flash sits where the hole is.
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.108, MUZZLE_Z)
	root.add_child(muzzle)

	# Ejection port, right side, so brass leaves through the actual opening.
	var eject := Marker3D.new()
	eject.name = "Eject"
	eject.position = Vector3(0.040, 0.150, 0.112)
	root.add_child(eject)

	return root


## --- Receiver group ---------------------------------------------------------
##
## The stamped box, everything bolted to it, and the two details that tell you
## at a glance which side of the rifle you are looking at: the selector on the
## right, the sling mounts on the left. The hero turns to face both ways, so
## neither flank is allowed to be blank.
static func _receiver(_root: Node3D, hard: Batch, m: Dictionary) -> void:
	var park: Material = m["park"]
	var worn: Material = m["worn"]

	# 118 mm tall, 54 mm wide. A real stamping is better than twice as tall as
	# it is wide, and holding that ratio is most of what separates a rifle from
	# a length of pipe — the old model was 92 mm wide and read as exactly that.
	hard.box(Vector3(0.054, 0.118, 0.380), Vector3(0.0, 0.112, 0.020), park)
	# Front trunnion. The barrel does not come out of sheet metal, it comes out
	# of a solid block, and the block is proud of the receiver on both sides.
	hard.box(Vector3(0.060, 0.100, 0.062), Vector3(0.0, 0.110, 0.222), park)
	# Rear tang the stock bolts into.
	hard.box(Vector3(0.046, 0.086, 0.052), Vector3(0.0, 0.112, -0.188), park)
	# Magwell flare: hides the seam where the magazine enters and gives the
	# underside of the receiver a lit edge instead of one dead flat.
	hard.box(Vector3(0.062, 0.015, 0.106), Vector3(0.0, 0.056, 0.100), park)

	# Dust cover — the line along the top that says which rifle this is.
	hard.box(Vector3(0.050, 0.028, 0.330), Vector3(0.0, 0.181, 0.010), park)
	# Two longitudinal stiffening ribs pressed into it. Four millimetres proud,
	# so they are gone by gameplay distance; they stay because without them the
	# entire top of the rifle is one unbroken specular in every close camera
	# move, and the top of the rifle is what a side-on camera sees most of.
	for x: float in [-0.014, 0.014]:
		hard.box(Vector3(0.007, 0.006, 0.290), Vector3(x, 0.196, 0.010), park)

	# Rear sight block and its leaf. The leaf standing proud is a genuine
	# silhouette bump at the back of the receiver and survives at any size.
	hard.box(Vector3(0.058, 0.032, 0.054), Vector3(0.0, 0.196, 0.152), park)
	hard.box(Vector3(0.036, 0.034, 0.011), Vector3(0.0, 0.208, 0.133), park,
		Vector3(-18.0, 0.0, 0.0))

	# Selector lever, right side: a long stamped bar running most of the
	# receiver's height. Bare steel because a thumb rides it every time the
	# rifle comes up, and a thumb takes a finish off in about a week.
	hard.box(Vector3(0.008, 0.082, 0.022), Vector3(0.031, 0.128, 0.052), worn,
		Vector3(4.0, 0.0, 0.0))
	hard.box(Vector3(0.008, 0.014, 0.038), Vector3(0.031, 0.164, 0.070), worn)

	# Ejection port. A near-black plate a millimetre proud of the receiver flat
	# reads as a hole from any distance and costs one box; the bright strip
	# behind it is the carrier, and it is the only moving-looking thing on an
	# otherwise dead slab.
	hard.box(Vector3(0.005, 0.030, 0.092), Vector3(0.0285, 0.150, 0.112), m["void"])
	hard.box(Vector3(0.005, 0.014, 0.064), Vector3(0.0295, 0.147, 0.112), worn)

	# Charging handle: the stub hanging off the carrier. Reaches 66 mm off the
	# centreline, which is roughly a real one scaled up with everything else,
	# and it breaks the receiver's flat profile in three-quarter views.
	hard.box(Vector3(0.032, 0.016, 0.017), Vector3(0.043, 0.152, 0.156), worn)
	hard.box(Vector3(0.011, 0.021, 0.023), Vector3(0.060, 0.152, 0.156), worn)

	# Trigger guard, tucked tight under the receiver. Authored SHORT on purpose:
	# the firing hand lands on the origin, and a guard at true length would
	# swallow it. Its rear runs into the pistol grip, which is where a real
	# one goes anyway.
	hard.box(Vector3(0.030, 0.034, 0.011), Vector3(0.0, 0.036, 0.030), park)
	hard.box(Vector3(0.030, 0.010, 0.078), Vector3(0.0, 0.021, -0.005), park)
	hard.box(Vector3(0.030, 0.026, 0.012), Vector3(0.0, 0.040, -0.038), park)
	hard.box(Vector3(0.011, 0.028, 0.009), Vector3(0.0, 0.040, 0.008), m["blued"],
		Vector3(10.0, 0.0, 0.0))
	# Magazine catch — the paddle behind the well that a rocking magazine locks
	# into. It is the shape that explains why the magazine sits at that angle.
	hard.box(Vector3(0.022, 0.030, 0.014), Vector3(0.0, 0.046, 0.044), park)


## --- Furniture --------------------------------------------------------------
##
## Two handguards rather than one tube, a grip with a palm swell, and a stock
## whose comb line rises into the butt. The wood is the only warm mass on the
## prop, so its shapes do more work than their size suggests.
static func _furniture(root: Node3D, hard: Batch, m: Dictionary) -> void:
	var wood: Material = m["wood"]

	# Lower handguard. The finger grooves are cut by modulating the loft rings,
	# so they cost nothing and they show up in silhouette as a scalloped
	# underside rather than as a smooth sausage. The palm swell on top of them
	# is what stops the front end tapering like a rolling pin.
	var lower := []
	var lower_tint := []
	for i in 15:
		var t := float(i) / 14.0
		var groove := 1.0 - 0.12 * maxf(sin(t * PI * 4.0), 0.0)
		var swell := 1.0 + 0.10 * sin(t * PI)
		lower.append([lerpf(0.246, 0.446, t), 0.036 * groove * swell, 0.030 * swell])
		# Hand oil, darkest where the support hand actually sits.
		lower_tint.append(1.0 - 0.20 * sin(t * PI))
	_loft(root, "Handguard", lower, wood, Vector3(0.0, 0.094, 0.0), 2.6, 12,
		lower_tint, true, false)
	# Retaining ferrule: a metal band capping the wood, and the one crisp
	# machined edge in the middle of an otherwise soft front end.
	hard.box(Vector3(0.066, 0.078, 0.016), Vector3(0.0, 0.094, 0.450), m["park"])

	# Upper handguard, a separate piece over the gas tube. The dark slot between
	# the two halves is the tell that this is two-piece furniture and not one
	# extruded block, and it is one of the few 8 mm details that survives at
	# gameplay size because it is a shadow, not a shape.
	var upper := []
	var upper_tint := []
	for i in 9:
		var t := float(i) / 8.0
		var groove := 1.0 - 0.09 * maxf(sin(t * PI * 3.0), 0.0)
		upper.append([lerpf(0.262, 0.424, t), 0.026 * groove, 0.028 * groove])
		upper_tint.append(1.0 - 0.10 * sin(t * PI))
	_loft(root, "UpperHandguard", upper, wood, Vector3(0.0, GAS_Y + 0.002, 0.0),
		2.6, 12, upper_tint)

	# Pistol grip, raked back off the receiver. The old one was rotated 194
	# degrees with negative ring offsets, which pointed it UP through the
	# receiver where nothing could see it — the rifle has had no visible grip at
	# all until now. Positive offsets down the same axis put it where a hand is.
	_part(root, "Grip", _tube([
		[0.000, 0.040, 0.026],
		[0.034, 0.039, 0.028],
		[0.068, 0.037, 0.0295],   # palm swell
		[0.104, 0.034, 0.0275],
		[0.135, 0.035, 0.025],
	], 2.8, 12, [1.00, 0.92, 0.86, 0.90, 1.00], true, false),
		wood, Vector3(0.0, 0.052, -0.040), Vector3(197.0, 0.0, 0.0))
	# Grip cap. Also closes the loft: an uncapped end is cheaper than a domed
	# one and a flat plate is what is actually down there.
	hard.box(Vector3(0.054, 0.020, 0.076), Vector3(0.0, -0.0866, -0.0823),
		m["park"], Vector3(17.0, 0.0, 0.0))

	# Stock. The angle off the receiver is the second silhouette cue after the
	# magazine, and the wedge — thin at the wrist, deep at the butt — is what
	# makes that angle legible. A constant-section stock reads as a stick.
	_part(root, "Stock", _tube([
		[-0.018, 0.046, 0.025],
		[-0.052, 0.039, 0.027],   # wrist
		[-0.100, 0.042, 0.029],
		[-0.155, 0.052, 0.030],
		[-0.205, 0.062, 0.030],   # butt
	], 2.8, 12, [0.90, 0.86, 0.94, 1.00, 1.00], true, false),
		wood, Vector3(0.0, 0.100, -0.150), Vector3(83.0, 0.0, 0.0))
	# Butt plate, square to the stock axis and oversized enough to close the
	# loft's open end.
	hard.box(Vector3(0.066, 0.020, 0.132), Vector3(0.0, 0.074, -0.362),
		m["park"], Vector3(83.0, 0.0, 0.0))
	# Rear sling swivel, left side. Sling mounts live on the left on this
	# pattern and the selector lives on the right; the hero faces both ways, so
	# each flank gets one thing worth looking at.
	hard.box(Vector3(0.008, 0.026, 0.022), Vector3(-0.032, 0.082, -0.274), m["park"])


## --- Barrel assembly --------------------------------------------------------
##
## Everything forward of the trunnion. This is where the third silhouette cue
## lives: a thin barrel with a gas tube floating 33 mm above it and daylight in
## between. The old model had a 42 mm barrel, which closed that gap and turned
## the front end into one solid bar.
static func _barrel(root: Node3D, hard: Batch, m: Dictionary) -> void:
	var park: Material = m["park"]
	var worn: Material = m["worn"]

	# Barrel. Tints darken toward the chamber: a barrel that has run through a
	# few magazines colours there first, and it keeps the one long cylinder on
	# the prop from being a single flat value.
	_loft(root, "Barrel", [
		[0.236, 0.0170, 0.0170],
		[0.300, 0.0145, 0.0145],
		[0.640, 0.0132, 0.0132],
		[0.762, 0.0132, 0.0132],
	], m["blued_vc"], Vector3(0.0, BORE_Y, 0.0), 2.0, 12, [0.70, 0.84, 1.00, 1.00])

	_loft(root, "GasTube", [
		[0.250, 0.0165, 0.0165],
		[0.300, 0.0155, 0.0155],
		[0.500, 0.0155, 0.0155],
	], m["blued_vc"], Vector3(0.0, GAS_Y, 0.0), 2.0, 10, [0.78, 0.92, 1.00])

	# Cleaning rod under the barrel. Two millimetres of steel, and at gameplay
	# size it is one dark line under a lit barrel — exactly the high-frequency
	# cue that makes a front end look engineered instead of moulded.
	_loft(root, "CleaningRod", [
		[0.400, 0.0055, 0.0055],
		[0.690, 0.0050, 0.0050],
	], m["blued_vc"], Vector3(0.0, 0.0855, 0.0), 2.2, 8, [1.0, 1.0])

	# Gas block: the machined lump that bridges barrel and gas tube, and the one
	# place the two lines are allowed to meet.
	hard.box(Vector3(0.046, 0.086, 0.062), Vector3(0.0, 0.138, 0.512), park)
	# Angled front shoulder — what makes a gas block read as machined rather
	# than as a cube someone left there.
	hard.box(Vector3(0.044, 0.050, 0.030), Vector3(0.0, 0.122, 0.482), park,
		Vector3(-22.0, 0.0, 0.0))
	# Front sling swivel, left side, under the gas block.
	hard.box(Vector3(0.008, 0.030, 0.020), Vector3(-0.030, 0.104, 0.512), park)

	# Front sight tower. The block, two protective ears and the post between
	# them. At 15% of screen height the ears are a couple of pixels each, but
	# the NOTCH between them is what makes the front of the rifle read as a
	# sight and not as a lump, and a notch survives at sizes a shape does not.
	hard.box(Vector3(0.042, 0.058, 0.052), Vector3(0.0, 0.122, 0.672), park)
	for x: float in [-0.015, 0.015]:
		hard.box(Vector3(0.009, 0.044, 0.038), Vector3(x, 0.168, 0.672), park)
	hard.box(Vector3(0.007, 0.034, 0.008), Vector3(0.0, 0.163, 0.672), worn)

	# Slant muzzle brake. Body is a loft because it is round; the angled face is
	# a rotated chamfered box, because a real cut plane with a real lit edge is
	# something a lofted cap simply cannot produce.
	_loft(root, "MuzzleBrake", [
		[0.762, 0.0155, 0.0155],
		[0.774, 0.0260, 0.0260],
		[0.836, 0.0265, 0.0265],
	], m["worn_vc"], Vector3(0.0, BORE_Y, 0.0), 2.2, 12, [0.85, 1.00, 1.00])
	hard.box(Vector3(0.056, 0.058, 0.022), Vector3(0.0, BORE_Y, 0.848), worn,
		Vector3(-26.0, 0.0, 0.0))
	# The port, cut into the top where the gas goes. Same trick as the ejection
	# port: near-black, a hair proud, reads as an opening.
	hard.box(Vector3(0.024, 0.012, 0.034), Vector3(0.009, 0.128, 0.796), m["void"])
	# Bore.
	hard.box(Vector3(0.020, 0.020, 0.007), Vector3(0.0, 0.1085, 0.857), m["void"],
		Vector3(-26.0, 0.0, 0.0))


## --- Magazine ---------------------------------------------------------------
##
## The banana curve, built by walking rings down an arc. This is the single
## most important shape on the rifle: it is the one thing that is still legible
## when the whole prop is sixty pixels long, which is why it gets the ribs, the
## floor plate and the only warm-but-not-wood material on the weapon.
static func _magazine(root: Node3D, hard: Batch, m: Dictionary) -> void:
	var b := MeshForge.Builder.new()
	b.begin()
	var rings := []
	var steps := 19
	for i in steps:
		var t := float(i) / float(steps - 1)
		# Arc sweeps forward as it descends — that is the whole shape.
		var y := -t * 0.242
		var z := sin(t * 1.05) * 0.062
		# Three pressed ribs down the body. They are a millimetre deep, so they
		# never read as geometry; what they do is break the long specular that
		# runs down a smooth magazine and make it look pressed rather than cast.
		var rib := 1.0 + 0.030 * sin(t * TAU * 3.0)
		var w := lerpf(0.0215, 0.0200, t) * rib
		var d := lerpf(0.0470, 0.0400, t) * rib
		var r := MeshForge.ring(Vector3(0.0, y, z), w, d, [0], [1.0], 3.4)
		# Scuffed and dirty toward the floor plate, which is the end that meets
		# every wall, vehicle floor and patch of Brega gravel.
		var v := 1.0 - 0.18 * t
		r["color"] = Color(v, v, v)
		rings.append(r)
	b.loft(rings, 12, true, false)

	var mi := MeshInstance3D.new()
	mi.name = "Magazine"
	mi.mesh = b.commit()
	mi.material_override = m["mag"]
	mi.position = Vector3(0.0, 0.068, 0.100)
	mi.rotate_x(deg_to_rad(-15.0))
	root.add_child(mi)

	# Floor plate, square to the magazine's tangent at the bottom and proud of
	# the body on every side, the way a stamped plate that has to be knocked off
	# with a punch actually sits. Also closes the loft.
	hard.box(Vector3(0.052, 0.016, 0.100), Vector3(0.0, -0.157, 0.225),
		m["park"], Vector3(-23.0, 0.0, 0.0))


## --- Sling ------------------------------------------------------------------

## A strap from the front swivel to the rear one. This is the thing that makes
## a slung rifle read as slung: without it the weapon looks stuck to the hero's
## back, and the hero spends most of the game with it slung.
##
## Cheap on purpose — eleven rings, six segments. The cross-section is thin
## across X and tall in Y, so a side-on camera sees the strap's WIDTH, which is
## the only view that matters in a 2.5D game.
static func _sling(root: Node3D, m: Dictionary) -> void:
	var b := MeshForge.Builder.new()
	b.begin()
	var rings := []
	var span := 0.775
	for i in 11:
		var t := float(i) / 10.0
		# A quadratic sag is indistinguishable from a real catenary over 77 cm
		# and costs one multiply. The depth is chosen to clear the magazine
		# floor plate: a sling that clips through the magazine is worse than no
		# sling at all.
		var sag := 4.0 * t * (1.0 - t) * 0.118
		var taper := lerpf(0.62, 1.0, sin(t * PI))
		var r := MeshForge.ring(Vector3(0.0, -span * t, sag), 0.0048,
			0.021 * taper, [0], [1.0], 2.6)
		# Grimiest where it is gripped and where it rubs the anchors.
		var v := 0.86 + 0.14 * sin(t * PI)
		r["color"] = Color(v, v, v)
		rings.append(r)
	b.loft(rings, 6, true, true)

	var mi := MeshInstance3D.new()
	mi.name = "Sling"
	mi.mesh = b.commit()
	mi.material_override = m["sling"]
	# Same axis convention as the lofted parts: local +Y runs down the barrel
	# axis, local +Z hangs downward.
	mi.position = Vector3(-0.030, 0.074, 0.500)
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	root.add_child(mi)


## --- Loft plumbing ----------------------------------------------------------

## Rings are [z_along_barrel, half_height, half_width]. `tints` is one
## brightness per ring, multiplied into albedo through vertex colour — the
## cheapest wear there is, and the only kind that costs no texture and no
## draw call. Rings ALWAYS get a colour written: MeshForge defaults them to
## black, so a missing entry is not "no tint", it is a black part.
static func _tube(spec: Array, roundness := 3.0, segments := 10, tints := [],
		cap_start := true, cap_end := true) -> ArrayMesh:
	var b := MeshForge.Builder.new()
	b.begin()
	var rings := []
	for i in spec.size():
		var e: Array = spec[i]
		# Built lying along Y then rotated, so the loft's own axis still applies.
		var r := MeshForge.ring(Vector3(0.0, e[0], 0.0), e[2], e[1], [0], [1.0], roundness)
		var v: float = tints[i] if i < tints.size() else 1.0
		r["color"] = Color(v, v, v)
		rings.append(r)
	b.loft(rings, segments, cap_start, cap_end)
	return b.commit()


## `pos` is the part's position in rifle space. The default rotation turns the
## loft's +Y axis to run down the barrel; the grip and the stock override it.
static func _part(root: Node3D, name_: String, mesh: Mesh, mat: Material,
		pos: Vector3, rot_deg := Vector3(90.0, 0.0, 0.0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	mi.position = pos
	root.add_child(mi)
	return mi


static func _loft(root: Node3D, name_: String, spec: Array, mat: Material,
		pos: Vector3, roundness := 3.0, segments := 10, tints := [],
		cap_start := true, cap_end := true) -> MeshInstance3D:
	return _part(root, name_, _tube(spec, roundness, segments, tints, cap_start, cap_end),
		mat, pos)
