class_name Enemy extends CharacterBody3D
## Base for everything that can be destroyed, and the parts bin they are all
## built from.
##
## World 1's prison enemies are Brega's automated security — drones, turrets and
## walkers. That is a tonal decision as much as a design one: this is an
## affectionate, larger-than-life game, and full-auto gunplay against machines
## stays playful in a way that gunplay against people would not.
##
## The contract every enemy keeps: it telegraphs before it commits, it flashes
## and recoils when hit, and it dies in a way worth watching.
##
##
## ============================================================================
## BREGA SECURITY — THE DESIGN LANGUAGE
## ============================================================================
##
## Fiction first, because the fiction decides every proportion. Nobody bought
## these as a system. The plant's own maintenance shop bolted them together in
## the eighties out of whatever was on the shelf — the same flanges, the same
## glanded junction boxes, the same louvred cabinet doors that are on every
## pump skid in the yard — and nobody has been back since. They are oilfield
## kit that happens to walk, not military robotics, and every rule below exists
## to keep them on that side of the line. Where a part could plausibly come out
## of DetailKit, it does: that is the point.
##
## MODULE — 90 mm. Every panel, vent, hatch and band is a whole number of
## modules on a side, and never square: 3x2 or 5x2, long axis running the way
## the machine points. A square panel reads as a texture. A long one reads as a
## part that was cut to fit something.
##
## PANELS stand 12 mm PROUD of the housing under them. Never flush, never
## recessed. Proud is what buys the shadow line, and on a backlit machine in a
## backlit level the shadow line is the only detail that survives to gameplay
## distance. Recessing is reserved for things that genuinely are holes: vents
## and optics.
##
## FASTENERS — 10 mm hex bosses at one module pitch, and they only ever run
## along an edge or around a flange. A row of bolts is a manufacturing
## decision; a field of bolts scattered over a face is a decal pretending to be
## one.
##
## HAZARD STRIPE RULE — 38-degree chevrons, amber over near-black, on a band no
## taller than 1.5 modules, and EXACTLY ONE BAND PER UNIT: on the part that
## moves toward you. The drone's rotor guard, the turret's swinging yoke cheek,
## the walker's shield plate. That makes the stripe information instead of
## decoration — wherever the chevrons are is the end of the machine that will
## hurt you, and the player learns that once and keeps it.
##
## ONE ACCENT — plant amber, sun-bleached (ACCENT below). Nothing else on these
## machines is saturated, ever. The red sector belongs to Wanis and to the
## Sriracha and these are not allowed to compete with either.
##
## THE OPTIC — every unit has the same eye, because the shop only stocked one
## part: a short can with a chamfered hood over the top of it, a glass disc set
## deep enough inside the can that the hood catches its glow, and four emitter
## beads around the disc. It is the only emissive thing on a unit and its
## colour IS the state machine, identically on all three:
##
##     amber, slow breath      it has not seen you
##     white-hot, fast pulse   it has, and it is committing
##     ember, decaying         it has spent itself — this is your window
##     dead blue-grey          it is scrap
##
## Learn it on the drone in the first thirty seconds and it reads on a turret
## from the far side of the yard. The steam vent collar runs the same ramp on
## purpose: one language for "it is about to".
##
## WEAR — twenty years unattended in a salt wind off the Gulf of Sidra. Upward
## faces are sun-bleached a stop lighter and desaturated, every bolt and
## bracket bleeds a rust streak straight down from it, and there is a hard dirt
## line where a housing meets whatever it is bolted to. The shader does the
## first two from world normals; the streaks and the dirt line are decal quads,
## because gravity stains are placed, not noisy.
##
## VALUE — and this is the one that mattered most. The first pass had these at
## albedo 0.11 and every capture came back with three black blobs on a grey
## card: at that value there is no light left to put a panel line in. The
## family sits at 0.30-0.42 now, which is a dusty machine grey in shade, and
## every piece of surface detail below only exists because of that decision.

## Can the player kill this by landing on it, and how high is its head.
@export var stompable := true
@export var stomp_height := 0.72

var _stomped := false

signal damaged(amount: float, from: Vector3)
signal died()

@export var max_health := 3.0
@export var contact_damage := 1.0
@export var knockback := 3.0
@export var flash_time := 0.09
@export var hitstop := 0.035
@export var score_value := 1

## Purely cosmetic death shaping, set by subclasses in _setup(). A drone spins
## out of the air; a turret is bolted to a wall and barely moves.
var death_tip := 1.4      ## radians the wreck rolls through
var death_sink := 0.45    ## metres it drops while it dies

var health: float
var facing := -1
var _flash_left := 0.0
var _dead := false
var _materials: Array[Material] = []
var _base_albedo: Array[Color] = []
var _base_emission: Array[float] = []
var _visual: Node3D
var _pivot: Node3D            ## recoil/settle spring sits between body and visual
var _recoil := Vector3.ZERO
var _recoil_vel := Vector3.ZERO
var _spin := 0.0
var _spin_vel := 0.0


# =============================================================================
# The parts bin
# =============================================================================

const MODULE := 0.09

## The family palette. Nothing here goes below sRGB 0.20: see the VALUE note.
const SHELL := Color(0.395, 0.385, 0.358)     ## main housings, bleached grey
const SHELL_DARK := Color(0.288, 0.282, 0.268) ## secondary plate, sponsons
const IRON := Color(0.242, 0.238, 0.232)      ## structure, barrels, joints
const RECESS := Color(0.205, 0.200, 0.196)    ## inside a vent or an optic can
const ACCENT := Color(0.815, 0.585, 0.125)    ## plant amber — the only chroma

const OPTIC_IDLE := Color(1.0, 0.62, 0.16)
const OPTIC_HOT := Color(1.0, 0.95, 0.86)
const OPTIC_EMBER := Color(1.0, 0.36, 0.14)
const OPTIC_DEAD := Color(0.30, 0.34, 0.38)

static var _mat_cache: Dictionary = {}


## Painted sheet steel, bleached on top, dirty underneath. Every housing on
## every unit is this with a different tint.
static func shell_material(tint := SHELL, wear := 1.0) -> ShaderMaterial:
	var key := "shell_%.3f_%.3f_%.3f_%.2f" % [tint.r, tint.g, tint.b, wear]
	if _mat_cache.has(key):
		return (_mat_cache[key] as ShaderMaterial).duplicate()
	var m := MaterialLab.surface({
		"color": tint,
		"variation": tint.darkened(0.26),
		"variation_strength": 0.44,
		"metallic": 0.30,
		"roughness_min": 0.33, "roughness_max": 0.72,
		"seed": 31,
		"mask": NoiseBank.pits(31),
		"normal": NoiseBank.detail_normal(65, 0.55, 0.85),
		# Small scales: these are 200 mm parts, not 4 m walls, and the macro
		# blotching has to fit inside a panel or it reads as camouflage.
		"detail_scale": 3.4, "macro_scale": 0.55,
		"normal_strength": 0.55,
		"dust": 0.44 * wear, "dust_color": Color(0.70, 0.63, 0.47),
		"dust_sharpness": 2.4,
		"grime": 0.20 * wear, "grime_color": Color(0.27, 0.15, 0.08),
		"grime_falloff": 1.1,
		"ao": 0.48,
	})
	# The rust it has grown, not the rust it was painted. Edge wear picks out
	# every chamfer on the unit in one uniform, which is most of why the
	# chamfers were worth building.
	m.set_shader_parameter("wear_color", Color(0.46, 0.27, 0.16, 1.0))
	m.set_shader_parameter("edge_wear", 0.62)
	m.set_shader_parameter("edge_wear_lift", 0.30)
	m.set_shader_parameter("curvature_gain", 2.4)
	_mat_cache[key] = m
	return m.duplicate()


## Unpainted structure: pivots, barrels, ribs, actuator bodies. Dirtier and
## rougher than the housings so a joint never reads as part of a panel.
static func iron_material(tint := IRON) -> ShaderMaterial:
	var key := "iron_%.3f_%.3f_%.3f" % [tint.r, tint.g, tint.b]
	if _mat_cache.has(key):
		return (_mat_cache[key] as ShaderMaterial).duplicate()
	var m := MaterialLab.surface({
		"color": tint,
		"variation": Color(0.31, 0.22, 0.17),
		"variation_strength": 0.55,
		"metallic": 0.55,
		"roughness_min": 0.40, "roughness_max": 0.88,
		"seed": 41,
		"mask": NoiseBank.pits(41),
		"normal": NoiseBank.rough_normal(91, 0.36, 1.6),
		"detail_scale": 2.6, "macro_scale": 0.62,
		"normal_strength": 0.85,
		"dust": 0.26, "grime": 0.34, "grime_color": Color(0.30, 0.16, 0.09),
		"grime_falloff": 1.4,
		"ao": 0.52,
	})
	m.set_shader_parameter("wear_color", Color(0.52, 0.31, 0.18, 1.0))
	m.set_shader_parameter("edge_wear", 0.70)
	_mat_cache[key] = m
	return m.duplicate()


## The one saturated material in the family. Bleached, chalked and scuffed —
## a hazard stripe that still looks freshly painted after twenty years is the
## fastest way to make a machine read as new.
static func accent_material() -> ShaderMaterial:
	if _mat_cache.has("accent"):
		return (_mat_cache["accent"] as ShaderMaterial).duplicate()
	var m := MaterialLab.surface({
		"color": ACCENT,
		# Opted out of the world chroma clamp, and this is the only place in the
		# file that is. ART_DIRECTION.md states plainly that danger is signalled
		# with hazard yellow-black chevrons; clamped to the world cap the amber
		# comes out a sandy beige and the stripe stops being a warning. Hue 40
		# is nowhere near the band reserved for Wanis, so nothing is competing.
		"hero": true,
		"variation": Color(0.62, 0.49, 0.22),
		"variation_strength": 0.62,
		"metallic": 0.10,
		"roughness_min": 0.46, "roughness_max": 0.86,
		"seed": 17,
		"mask": NoiseBank.streaks(53),
		"normal": NoiseBank.detail_normal(67, 0.60, 0.7),
		"detail_scale": 3.0, "macro_scale": 0.70,
		"normal_strength": 0.45,
		"dust": 0.40, "grime": 0.26, "grime_color": Color(0.28, 0.18, 0.09),
		"grime_falloff": 1.0,
		"ao": 0.40,
	})
	# Chipped back to bare primer along every edge, which is exactly where a
	# painted hazard stripe wears first.
	m.set_shader_parameter("wear_color", Color(0.40, 0.36, 0.31, 1.0))
	m.set_shader_parameter("edge_wear", 0.78)
	_mat_cache["accent"] = m
	return m.duplicate()


## The inside of a hole. Flat, dark, barely specular, so a vent does not glint
## back at the camera and stop being a hole.
static func recess_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = RECESS
	m.roughness = 0.94
	m.metallic = 0.0
	m.metallic_specular = 0.30
	return m


## Rubber loom, cable sheath, foot pads. Non-metallic and it needs to read that
## way against all the steel.
static func rubber_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.215, 0.210, 0.208)
	m.roughness = 0.82
	m.metallic = 0.0
	m.metallic_specular = 0.30
	return m


static func _part(parent: Node3D, name_: String, mesh: Mesh, mat: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _batch(parent: Node3D, name_: String, mesh: Mesh,
		xforms: Array[Transform3D], mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = mm
	node.material_override = mat
	parent.add_child(node)
	return node


static func _cyl(radius: float, height: float, sides := 12,
		top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


## A proud panel: a plate standing 12 mm off the face it is bolted to, with a
## bolt row down its long edge. `size` is the plate; it is laid in the local XY
## plane and stands off in +Z, and the caller orients the parent.
static func panel(parent: Node3D, center: Vector3, size: Vector2,
		mat: Material, bolts := 0, bolt_mat: Material = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Panel"
	root.position = center
	parent.add_child(root)
	_part(root, "Plate", LevelKit.chamfer_mesh(Vector3(size.x, size.y, 0.024),
		0.006), mat)
	if bolts > 0:
		var bm: Material = bolt_mat if bolt_mat != null else mat
		bolt_row(root, Vector3(-size.x * 0.5 + MODULE * 0.4, 0.0, 0.016),
			Vector3(size.x * 0.5 - MODULE * 0.4, 0.0, 0.016), bolts, bm)
	return root


## A basis whose local +Y runs down `dir` — the axis every CylinderMesh is
## built on, so this is how anything tubular gets pointed at something.
static func _basis_y_to(dir: Vector3) -> Basis:
	var d := dir.normalized()
	if absf(d.dot(Vector3.UP)) > 0.999:
		return Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI)
	var x := Vector3.UP.cross(d).normalized()
	# x.cross(d), not d.cross(x). Get that backwards and the basis comes out
	# with a negative determinant, which mirrors every instance in the batch
	# and renders the whole row of bolt heads inside out — a mistake that is
	# almost impossible to see in a screenshot and impossible to unsee after.
	return Basis(x, d, x.cross(d).normalized())


## Hex bosses along an edge. One MultiMesh, because a row of eight bolts is not
## worth eight draw calls. `normal` is the way the heads face.
static func bolt_row(parent: Node3D, from: Vector3, to: Vector3, count: int,
		mat: Material, radius := 0.011,
		normal := Vector3.BACK) -> MultiMeshInstance3D:
	var xf: Array[Transform3D] = []
	var n := maxi(count, 1)
	var b := _basis_y_to(normal)
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		xf.append(Transform3D(b, from.lerp(to, t)))
	return _batch(parent, "Bolts", _cyl(radius, 0.022, 6), xf, mat)


## A ring of bosses around a flange, in the plane perpendicular to `normal`.
static func bolt_ring(parent: Node3D, center: Vector3, ring_r: float,
		count: int, mat: Material, radius := 0.011,
		normal := Vector3.BACK) -> MultiMeshInstance3D:
	var b := _basis_y_to(normal)
	var u := b.x
	var v := b.z
	var xf: Array[Transform3D] = []
	var n := maxi(count, 3)
	for i in n:
		var a := TAU * float(i) / float(n)
		xf.append(Transform3D(b, center + u * cos(a) * ring_r
			+ v * sin(a) * ring_r))
	return _batch(parent, "BoltRing", _cyl(radius, 0.022, 6), xf, mat)


## A recessed louvred vent, opening along local +Z. A dark box set into the
## face with tilted fins across it: the fins catch the key and the recess stays
## black, which is the whole read at distance.
static func louvre(parent: Node3D, center: Vector3, size: Vector2, fins: int,
		fin_mat: Material, depth := 0.055) -> Node3D:
	var root := Node3D.new()
	root.name = "Vent"
	root.position = center
	parent.add_child(root)
	_part(root, "Recess", LevelKit.chamfer_mesh(
		Vector3(size.x, size.y, depth), 0.005), recess_material(),
		Vector3(0, 0, -depth * 0.5))
	var xf: Array[Transform3D] = []
	var n := maxi(fins, 1)
	var pitch := size.y / float(n)
	# 35 degrees: enough that the top edge of every fin catches light and the
	# gap under it goes black. Flat fins vanish, vertical fins read as bars.
	var b := Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	for i in n:
		var y := size.y * 0.5 - pitch * (float(i) + 0.5)
		xf.append(Transform3D(b, Vector3(0.0, y, 0.004)))
	_batch(root, "Fins", LevelKit.chamfer_mesh(
		Vector3(size.x * 0.93, 0.013, pitch * 0.92), 0.004), xf, fin_mat)
	# Side rails, so the vent is a fabricated part and not a hole someone cut.
	for s in [-1.0, 1.0]:
		_part(root, "Rail", LevelKit.chamfer_mesh(
			Vector3(0.016, size.y + 0.02, 0.030), 0.005), fin_mat,
			Vector3(s * (size.x * 0.5 + 0.006), 0.0, 0.010))
	return root


## A stack of cooling fins along local Y. Heat has to go somewhere and a fin
## stack is the cheapest silhouette in the kit that says "this thing runs hot".
static func fin_stack(parent: Node3D, center: Vector3, count: int,
		fin: Vector3, pitch: float, mat: Material) -> MultiMeshInstance3D:
	var xf: Array[Transform3D] = []
	var n := maxi(count, 1)
	for i in n:
		var y := (float(i) - float(n - 1) * 0.5) * pitch
		xf.append(Transform3D(Basis.IDENTITY, center + Vector3(0.0, y, 0.0)))
	return _batch(parent, "Fins", LevelKit.chamfer_mesh(fin, 0.004), xf, mat)


## THE hazard band. Amber ground with near-black chevrons raked 38 degrees,
## built in a local frame that runs along X, stands `height` in Y and faces +Z.
## One per unit, on the part that moves toward the player. See the rule at the
## top of the file.
static func chevron_band(parent: Node3D, center: Vector3, length: float,
		height: float, count: int, accent: Material,
		dark: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Hazard"
	root.position = center
	parent.add_child(root)
	_part(root, "Band", LevelKit.chamfer_mesh(
		Vector3(length, height, 0.026), 0.006), accent)
	var rake := deg_to_rad(38.0)
	var w := height * 0.40
	# A raked bar of height h overhangs by h*cos + w*sin; solve back so the
	# stripes finish flush with the band instead of hanging off it.
	var slat_h := (height - w * sin(rake)) / cos(rake)
	var xf: Array[Transform3D] = []
	var n := maxi(count, 1)
	var span := length - height * 0.9
	var b := Basis(Vector3(0, 0, 1), rake)
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		xf.append(Transform3D(b, Vector3(-span * 0.5 + span * t, 0.0, 0.014)))
	_batch(root, "Stripes", LevelKit.chamfer_mesh(
		Vector3(w, slat_h, 0.018), 0.004), xf, dark)
	return root


## The same band wrapped round a guard ring, for anything whose leading face is
## circular. Slats rake about the radial axis, which is what keeps them reading
## as one continuous stripe rather than as a row of separate blocks.
static func chevron_ring(parent: Node3D, center: Vector3, ring_r: float,
		height: float, count: int, accent: Material,
		dark: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "HazardRing"
	root.position = center
	parent.add_child(root)
	var torus := TorusMesh.new()
	torus.inner_radius = ring_r - height * 0.42
	torus.outer_radius = ring_r + height * 0.42
	torus.rings = 24
	torus.ring_segments = 6
	_part(root, "Ring", torus, accent)
	var rake := deg_to_rad(38.0)
	var w := height * 0.34
	var slat_h := (height * 1.25 - w * sin(rake)) / cos(rake)
	var xf: Array[Transform3D] = []
	var n := maxi(count, 3)
	for i in n:
		var a := TAU * float(i) / float(n)
		xf.append(Transform3D(
			Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, rake),
			Vector3(cos(a) * ring_r, 0.0, sin(a) * ring_r)))
	_batch(root, "Stripes", LevelKit.chamfer_mesh(
		Vector3(height * 1.15, slat_h, w), 0.004), xf, dark)
	return root


## An access hatch: a proud lid, four quarter-turn fasteners and the small
## amber warning plate that every panel with mains behind it carries.
static func hatch(parent: Node3D, center: Vector3, size: Vector2,
		mat: Material, fastener: Material, accent: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Hatch"
	root.position = center
	parent.add_child(root)
	_part(root, "Lid", LevelKit.chamfer_mesh(Vector3(size.x, size.y, 0.028),
		0.007), mat)
	var xf: Array[Transform3D] = []
	var b := Basis(Vector3.RIGHT, PI * 0.5)
	for i in 4:
		var sx := (-1.0 if i % 2 == 0 else 1.0) * (size.x * 0.5 - MODULE * 0.30)
		var sy := (-1.0 if i < 2 else 1.0) * (size.y * 0.5 - MODULE * 0.30)
		xf.append(Transform3D(b, Vector3(sx, sy, 0.018)))
	_batch(root, "Fasteners", _cyl(0.014, 0.020, 6), xf, fastener)
	# A hinge line down one edge, so the lid opens somewhere.
	_part(root, "Hinge", LevelKit.chamfer_mesh(
		Vector3(0.016, size.y * 0.8, 0.034), 0.004), fastener,
		Vector3(-size.x * 0.5 - 0.005, 0.0, 0.012))
	_part(root, "Warning", LevelKit.chamfer_mesh(
		Vector3(size.x * 0.46, MODULE * 0.44, 0.016), 0.004), accent,
		Vector3(size.x * 0.16, -size.y * 0.5 + MODULE * 0.34, 0.018))
	return root


## Stencilled unit markings. Arabic only, Western digits — the plant's own
## signage convention, and the one thing on these machines that was applied by
## a person rather than pressed out of a die.
static func stencil(parent: Node3D, text: String, at: Vector3, height: float,
		tint := Color(0.70, 0.68, 0.62)) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.90
	m.metallic = 0.0
	m.metallic_specular = 0.30
	var s := PropKit.sign(parent, text, at, height, m, PropKit.FONT_NASKH, 0.006)
	s.name = "Stencil"
	return s


## A gravity stain, facing +Z. Rust runs from every bolt and bracket on a
## twenty-year-old machine and the run is always longer than feels right.
static func rust_streak(parent: Node3D, at: Vector3, size: Vector2,
		strength := 0.55) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Rust"
	mi.mesh = q
	mi.material_override = PropKit.gradient_decal(
		Color(0.36, 0.19, 0.10), strength, "streak")
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The dirt line where a housing meets its mount. Strong at the bottom, fading
## up — the opposite falloff to a rust run, and the pair of them is most of
## what makes a machine look bolted down rather than placed.
static func dirt_band(parent: Node3D, at: Vector3, size: Vector2,
		strength := 0.62) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Dirt"
	mi.mesh = q
	mi.material_override = PropKit.gradient_decal(
		Color(0.19, 0.16, 0.13), strength, "band")
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A flexible cable run between two assemblies. Catenary, via PropKit, because
## a straight cable is the fastest way to make something look un-built.
static func loom(parent: Node3D, from: Vector3, to: Vector3, sag: float,
		thickness := 0.024) -> MultiMeshInstance3D:
	return PropKit.cable(parent, from, to, sag, rubber_material(), 8, thickness)


## The family eye. Returns a pivot the caller aims; everything inside it is the
## same part on all three units. See THE OPTIC in the header.
class Optic extends RefCounted:
	var pivot: Node3D
	var hood: MeshInstance3D
	var lens: MeshInstance3D
	var mat: StandardMaterial3D
	var bead_mat: StandardMaterial3D
	var light: OmniLight3D
	var beads: MultiMeshInstance3D
	var beam: MeshInstance3D
	var beam_mat: StandardMaterial3D
	var _radius := 0.11

	## Colour and energy in one call, so no caller can set the lens and forget
	## the light and leave a dark eye glowing.
	func set_state(tint: Color, energy: float) -> void:
		# emission_enabled is set explicitly every call because the base class
		# hit flash turns it off again on its way out, and an eye that goes
		# dark for a frame after every round lands reads as a bug.
		mat.emission_enabled = true
		mat.albedo_color = tint
		mat.emission = tint
		mat.emission_energy_multiplier = energy
		bead_mat.emission_enabled = true
		bead_mat.albedo_color = tint
		bead_mat.emission = tint
		bead_mat.emission_energy_multiplier = energy * 0.7
		light.light_color = tint
		light.light_energy = energy * 0.85
		# The pool it throws grows with the state. A telegraph you can see on
		# the floor is one the player reads without looking at the enemy.
		light.omni_range = lerpf(2.6, 7.5, clampf(energy / 6.0, 0.0, 1.0))

	## The visible sight line. `reach` in metres, `alpha` 0 hides it.
	func set_beam(reach: float, alpha: float, tint: Color) -> void:
		if beam == null:
			return
		beam.visible = alpha > 0.002
		if not beam.visible:
			return
		var r := maxf(reach, 0.01)
		# The cone is a unit mesh centred on its own origin, so it has to be
		# pushed out by half of whatever it was just scaled to or it grows
		# backwards through the lens as well as forwards.
		beam.scale = Vector3(1.0, r, 1.0)
		beam.position = Vector3(0.0, r * 0.5, 0.0)
		beam_mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)


static func optic(parent: Node3D, at: Vector3, radius := 0.11) -> Optic:
	var o := Optic.new()
	o._radius = radius
	o.pivot = Node3D.new()
	o.pivot.name = "Optic"
	o.pivot.position = at
	parent.add_child(o.pivot)

	var iron := iron_material()
	# The can. Built on +X because every unit aims along X.
	_part(o.pivot, "Can", _cyl(radius, radius * 1.5, 14), iron,
		Vector3(radius * 0.55, 0, 0), Vector3(0, 0, PI * 0.5))
	# A ring at the mouth, so the can has a lip to catch the key.
	_part(o.pivot, "Lip", _cyl(radius * 1.12, radius * 0.24, 14), iron,
		Vector3(radius * 1.24, 0, 0), Vector3(0, 0, PI * 0.5))
	# The hood. This is the part that makes the eye read as an eye and not as a
	# bright dot: it shades the glass and it catches the glow from above.
	o.hood = _part(o.pivot, "Hood", LevelKit.chamfer_mesh(
		Vector3(radius * 2.0, radius * 0.34, radius * 2.3), radius * 0.10),
		iron, Vector3(radius * 1.30, radius * 0.92, 0.0),
		Vector3(0, 0, deg_to_rad(-9.0)))
	# Around the can's mouth and facing forward, so it reads as the flange it
	# is rather than as a ring of studs stood on edge.
	bolt_ring(o.pivot, Vector3(radius * 0.28, 0, 0), radius * 1.02, 6, iron,
		0.009, Vector3.RIGHT)

	o.mat = MaterialLab.emissive(OPTIC_IDLE, 2.0)
	# The glass is not a light source, it is glass with a light behind it: a
	# little roughness keeps a specular on it so it stays a physical part.
	o.mat.roughness = 0.18
	o.mat.metallic_specular = 0.30
	o.lens = _part(o.pivot, "Lens", _cyl(radius * 0.70, radius * 0.16, 16),
		o.mat, Vector3(radius * 1.02, 0, 0), Vector3(0, 0, PI * 0.5))

	o.bead_mat = MaterialLab.emissive(OPTIC_IDLE, 1.2)
	var xf: Array[Transform3D] = []
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		xf.append(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5),
			Vector3(radius * 1.14, sin(a) * radius * 0.86,
				cos(a) * radius * 0.86)))
	o.beads = _batch(o.pivot, "Emitters", _cyl(radius * 0.13, radius * 0.10, 6),
		xf, o.bead_mat)

	o.light = OmniLight3D.new()
	o.light.light_color = OPTIC_IDLE
	o.light.light_energy = 1.6
	o.light.omni_range = 3.0
	o.light.shadow_enabled = false
	o.light.light_volumetric_fog_energy = 2.4
	o.light.position = Vector3(radius * 1.6, 0, 0)
	o.pivot.add_child(o.light)

	# The sight line, built once and scaled per frame. A tapered cone rather
	# than a cylinder so it reads as coming FROM the lens.
	var cone := CylinderMesh.new()
	cone.top_radius = radius * 0.16
	cone.bottom_radius = radius * 0.028
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 1
	o.beam_mat = StandardMaterial3D.new()
	o.beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	o.beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	o.beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	o.beam_mat.albedo_color = Color(1, 1, 1, 0.0)
	o.beam_mat.disable_receive_shadows = true
	o.beam = MeshInstance3D.new()
	o.beam.name = "Sightline"
	o.beam.mesh = cone
	o.beam.material_override = o.beam_mat
	o.beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Origin at the lens, running out along +X: the cylinder is built centred
	# on Y, so it is shifted half a unit and then scaled from that pivot.
	var holder := Node3D.new()
	holder.name = "BeamPivot"
	holder.position = Vector3(radius * 1.2, 0, 0)
	# -90 about Z, not +90: +90 maps local +Y onto -X and the sight line comes
	# out of the back of the machine.
	holder.rotation = Vector3(0, 0, -PI * 0.5)
	o.pivot.add_child(holder)
	o.beam.position = Vector3(0, 0.5, 0)
	holder.add_child(o.beam)
	o.beam.visible = false
	return o


## The warning strobe. It sits on TOP of every unit, against the sky, because a
## telegraph has to be visible across the yard and the top edge is the only
## part of a machine that is never occluded by the machine.
class Beacon extends RefCounted:
	var mesh: MeshInstance3D
	var mat: StandardMaterial3D
	var light: OmniLight3D

	func set_state(tint: Color, energy: float) -> void:
		mat.emission_enabled = true
		mat.albedo_color = tint
		mat.emission = tint
		mat.emission_energy_multiplier = energy
		light.light_color = tint
		light.light_energy = energy * 0.55


static func beacon(parent: Node3D, at: Vector3, radius := 0.048) -> Beacon:
	var b := Beacon.new()
	var iron := iron_material()
	_part(parent, "BeaconBase", _cyl(radius * 1.25, radius * 0.5, 8), iron,
		at + Vector3(0, -radius * 0.55, 0))
	# A cage over the lamp. Three bars is enough to read and it is what every
	# beacon in a plant actually has on it.
	var xf: Array[Transform3D] = []
	for i in 3:
		var a := TAU * float(i) / 3.0
		xf.append(Transform3D(Basis(Vector3.UP, a),
			at + Vector3(cos(a) * radius * 0.95, radius * 0.45,
				sin(a) * radius * 0.95)))
	_batch(parent, "BeaconCage", LevelKit.chamfer_mesh(
		Vector3(0.010, radius * 1.9, 0.010), 0.003), xf, iron)

	b.mat = MaterialLab.emissive(OPTIC_IDLE, 0.0)
	b.mat.roughness = 0.25
	var dome := SphereMesh.new()
	dome.radius = radius
	dome.height = radius * 1.7
	dome.radial_segments = 10
	dome.rings = 5
	b.mesh = _part(parent, "Beacon", dome, b.mat, at + Vector3(0, radius * 0.4, 0))
	b.light = OmniLight3D.new()
	b.light.light_color = OPTIC_IDLE
	b.light.light_energy = 0.0
	b.light.omni_range = 4.2
	b.light.shadow_enabled = false
	b.light.light_volumetric_fog_energy = 3.0
	b.mesh.add_child(b.light)
	b.set_state(OPTIC_IDLE, 0.0)
	return b


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	health = max_health
	collision_layer = 8
	collision_mask = 1
	add_to_group("enemy")
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_visual = _build()
	_install_pivot()
	_cache_materials(self)
	_setup()
	_build_hurtbox()
	_build_stompbox()


## A spring node between the body and the visual, so recoil and the settle
## after a stop can be driven without fighting whatever the subclass is already
## animating on its own nodes. Inserted rather than required, so a subclass's
## _build() stays the simple "make geometry, return it" it was.
func _install_pivot() -> void:
	if _visual == null or _visual.get_parent() != self:
		return
	_pivot = Node3D.new()
	_pivot.name = "Recoil"
	remove_child(_visual)
	add_child(_pivot)
	_pivot.add_child(_visual)


## The stomp zone: a shallow Area sitting on the enemy's head. A player who
## arrives here going DOWN kills it and bounces; a player who arrives any other
## way is handled by the hurtbox below and takes the hit.
##
## Head and body are separate volumes on purpose. The alternative -- one contact
## test resolved by comparing positions -- gets the edge cases wrong exactly
## where the player cares most, clipping a shoulder on the way past.
func _build_stompbox() -> void:
	if not stompable:
		return
	var area := Area3D.new()
	area.name = "StompBox"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.92, 0.34, 0.92)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, stomp_height, 0.0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_stomp)


func _on_stomp(body: Node3D) -> void:
	if _dead or not (body is PlayerController):
		return
	var p := body as PlayerController
	if not _is_stomping(p):
		return
	# One stomp kills, the way it does in the games this is built after. An
	# enemy that survives being jumped on teaches the player not to jump on it.
	_stomped = true
	p.stomp_bounce()
	FX.shake(0.30)
	Audio.play("shell", global_position, -5.0, randf_range(0.9, 1.1))
	hurt(maxf(health, 1.0), p.global_position + Vector3.UP,
		Vector3.DOWN * knockback * 0.4)


## Falling, and above the head. Both, or a player running into a shoulder at
## the top of a jump reads as a stomp and the enemy dies to nothing.
func _is_stomping(p: PlayerController) -> bool:
	if p.velocity.y > -0.5:
		return false
	return p.global_position.y > global_position.y + stomp_height * 0.55


## Contact damage lives on an Area, not on the body, so an enemy's dangerous
## volume can differ from the shape it collides with.
func _build_hurtbox() -> void:
	if contact_damage <= 0.0:
		return
	var area := Area3D.new()
	area.name = "HurtBox"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var shape := SphereShape3D.new()
	shape.radius = 0.52
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.35, 0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_touch)


func _on_touch(body: Node3D) -> void:
	if _dead or _stomped or not (body is PlayerController):
		return
	var p := body as PlayerController
	# Landing on the head is a stomp, never a hit, even though both volumes
	# overlap the player on the same frame.
	if stompable and _is_stomping(p):
		return
	if p.has_method("take_hit"):
		p.take_hit(contact_damage, global_position)


## Override: build geometry, return its root.
func _build() -> Node3D:
	return null


## Override: per-enemy init after the body exists.
func _setup() -> void:
	pass


## Override: per-frame behaviour. Base handles flash, death and plane lock.
func _behaviour(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_behaviour(delta)
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0


func _process(delta: float) -> void:
	_settle(delta)
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	var t := clampf(_flash_left / maxf(flash_time, 0.001), 0.0, 1.0)
	for i in _materials.size():
		# Additive white, not a replacement: the silhouette stays readable and
		# the hit reads even on an already-bright surface.
		_set_flash(_materials[i], _base_albedo[i].lerp(Color(1, 1, 1), t),
			t * 3.0)
	if _flash_left <= 0.0:
		for i in _materials.size():
			_set_flash(_materials[i], _base_albedo[i], _base_emission[i])


## A critically-under-damped spring on the whole visual. Everything mechanical
## in this game overshoots and settles — a servo stopping dead is the single
## clearest tell that a machine is a keyframe rather than a mechanism — and one
## spring here gives the drone its hover wobble, the turret its recoil bounce
## and the walker its stop-settle for the price of six floats.
func _settle(delta: float) -> void:
	if _pivot == null:
		return
	var d := minf(delta, 0.05)
	_recoil_vel += (-_recoil * 780.0 - _recoil_vel * 26.0) * d
	_recoil += _recoil_vel * d
	_spin_vel += (-_spin * 620.0 - _spin_vel * 22.0) * d
	_spin += _spin_vel * d
	_pivot.position = _recoil
	_pivot.rotation.z = _spin


## Kick the spring. Used by hits, by firing and by anything that should cost
## the machine something.
func nudge(impulse: Vector3, spin := 0.0) -> void:
	_recoil_vel += impulse
	_spin_vel += spin


func _set_flash(m: Material, albedo: Color, energy: float) -> void:
	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		sm.albedo_color = albedo
		sm.emission_enabled = energy > 0.0
		sm.emission = Color(1, 1, 1)
		sm.emission_energy_multiplier = energy
	elif m is ShaderMaterial:
		var shm := m as ShaderMaterial
		shm.set_shader_parameter("base_color", albedo)
		shm.set_shader_parameter("emission_color", Color(1, 1, 1))
		shm.set_shader_parameter("emission_strength", energy)


## Walk the unit and register every material on it for the hit flash.
##
## It does NOT copy them, and that is deliberate. It used to, so that flashing
## one machine could not flash every machine sharing a preset — but every
## factory in the parts bin already hands back a fresh instance per unit, so
## the copy bought nothing and cost a great deal: the subclass kept a reference
## to the material it built, the copy went onto the mesh, and every lens and
## lamp in the game was being driven on an object nothing was drawing. The
## turret's eye had not changed colour in weeks. Register, do not copy, and a
## subclass's own reference stays the one on screen.
func _cache_materials(node: Node) -> void:
	if node is GeometryInstance3D:
		var m := (node as GeometryInstance3D).material_override
		if m != null and _flashable(m) and not _materials.has(m):
			_materials.append(m)
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				_base_albedo.append(sm.albedo_color)
				_base_emission.append(sm.emission_energy_multiplier
					if sm.emission_enabled else 0.0)
			else:
				var shm := m as ShaderMaterial
				_base_albedo.append(shm.get_shader_parameter("base_color"))
				var e: Variant = shm.get_shader_parameter("emission_strength")
				_base_emission.append(float(e) if e != null else 0.0)
	for c in node.get_children():
		_cache_materials(c)


## Alpha-blended decals are excluded: flashing a dirt streak to white turns a
## stain into a bright rectangle, which is worse than not flashing it at all.
func _flashable(m: Material) -> bool:
	if m is ShaderMaterial:
		return (m as ShaderMaterial).shader == MaterialLab.SURFACE_SHADER
	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		return sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and sm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	return false


func hurt(amount: float, from: Vector3, impulse := Vector3.ZERO) -> void:
	if _dead:
		return
	health -= amount
	_flash_left = flash_time
	damaged.emit(amount, from)
	FX.hitstop(hitstop)
	FX.shake(0.10)
	Audio.play("shell", global_position, -8.0, randf_range(1.3, 1.7))
	_spark(from)
	# Recoil: the whole unit rocks away from the round and springs back. Rotary
	# component is signed off the hit height, so a hit low in the chassis tips
	# it and a hit high rolls it the other way.
	var away := (global_position - from)
	away.z = 0.0
	if away.length_squared() > 1e-5:
		away = away.normalized()
		nudge(away * 3.4, -signf(away.x) * 3.0)
	if impulse != Vector3.ZERO:
		velocity += impulse.normalized() * knockback
	if health <= 0.0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	set_collision_layer_value(4, false)
	FX.hitstop(0.075)
	FX.shake(0.34)
	Audio.play("hurt", global_position, -4.0, randf_range(1.1, 1.3))
	_death_sequence()


## The death, and it is the one piece of feedback in the game the player will
## see thousands of times, so it is authored in beats rather than tweened in
## one go:
##
##   0.00  stagger — it takes the hit, jolts, and the eye goes out
##   0.00  internal flash: something behind the panels lets go
##   0.06  a panel blows off, the debris sprays, the scorch lands
##   0.06  it starts to tip and sink; the motors are gone
##   0.34  the second pop — the cell — and it collapses
##   0.46  smoke settles on the spot for another second and a half
##
## The gap between the first flash and the blow-out is the whole trick: it lets
## the player register that they killed it before the screen fills with debris.
func _death_sequence() -> void:
	if _visual == null:
		queue_free()
		return

	# Dead eyes. Anything still glowing after the kill reads as "not dead yet".
	for m in _materials:
		if m is StandardMaterial3D:
			var sm := m as StandardMaterial3D
			if sm.emission_enabled:
				sm.emission = OPTIC_DEAD
				sm.emission_energy_multiplier = 0.25
	for c in _lights_in(self):
		var tw_l := c.create_tween()
		tw_l.tween_property(c, "light_energy", 0.0, 0.10)

	nudge(Vector3(-signf(float(facing)) * 6.5, 2.2, 0.0),
		signf(float(facing)) * 9.0)

	var flash := OmniLight3D.new()
	flash.name = "Overload"
	flash.light_color = Color(1.0, 0.86, 0.62)
	flash.light_energy = 0.0
	flash.omni_range = 5.5
	flash.shadow_enabled = false
	flash.light_volumetric_fog_energy = 5.0
	flash.position = Vector3(0, 0.45, 0)
	_visual.add_child(flash)

	var tw := create_tween()
	tw.set_parallel(true)
	# Beat 1: squash and the internal flash.
	tw.tween_property(flash, "light_energy", 9.0, 0.03)
	tw.tween_property(_visual, "scale", Vector3(0.88, 1.16, 0.88), 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(flash, "light_energy", 1.2, 0.12)
	tw.parallel().tween_property(_visual, "scale", Vector3(1.12, 0.92, 1.12), 0.06)
	tw.parallel().tween_callback(_blow_out)

	# Beat 2: it tips and sinks. No motors left, so nothing arrests it.
	tw.chain().tween_property(_visual, "rotation:z",
		_visual.rotation.z + randf_range(0.6, 1.0) * death_tip * signf(
			float(facing)) * -1.0, 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "position:y",
		_visual.position.y - death_sink, 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "scale", Vector3.ONE, 0.14)

	# Beat 3: the cell goes, and what is left of it collapses.
	tw.chain().tween_property(flash, "light_energy", 7.0, 0.04)
	tw.parallel().tween_callback(_final_pop)
	tw.chain().tween_property(flash, "light_energy", 0.0, 0.10)
	tw.parallel().tween_property(_visual, "scale", Vector3(1.2, 0.05, 1.2), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _lights_in(node: Node) -> Array[Light3D]:
	var out: Array[Light3D] = []
	if node is Light3D:
		out.append(node as Light3D)
	for c in node.get_children():
		out.append_array(_lights_in(c))
	return out


## The moment the housing loses containment: panels away, sparks, smoke, and
## the scorch mark on the floor that says something happened here.
func _blow_out() -> void:
	Audio.play("land_1.00", global_position, -2.0, randf_range(0.48, 0.58))
	FX.shake(0.20)
	_panels(4)
	_debris()
	_smoke(14, 1.7, 1.9)
	_scorch()


func _final_pop() -> void:
	FX.shake(0.16)
	Audio.play("shell", global_position, -2.0, randf_range(0.42, 0.50))
	_particles(20, Color(1.0, 0.72, 0.30), 0.55, Vector3.UP, 6.5)
	_panels(2)
	_smoke(10, 2.4, 1.2)


static var _debris_mat: ShaderMaterial


## Panels, not particles. A billboard spray reads as an explosion; a chunk of
## the actual housing tumbling out of it and landing on the floor reads as the
## thing coming apart, and it is the single cheapest upgrade available to a
## death effect.
func _panels(count: int) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	if _debris_mat == null:
		_debris_mat = shell_material(SHELL_DARK, 1.0)
	var base_y := global_position.y - 0.1
	for i in count:
		var s := Vector3(MODULE * randf_range(1.6, 3.4),
			MODULE * randf_range(1.0, 2.2), MODULE * randf_range(0.18, 0.30))
		var mi := MeshInstance3D.new()
		mi.name = "Panel"
		mi.mesh = LevelKit.chamfer_mesh(s, 0.006)
		mi.material_override = _debris_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
		var p0 := global_position + Vector3(randf_range(-0.25, 0.25),
			randf_range(0.25, 0.95), randf_range(-0.22, 0.22))
		mi.global_position = p0
		var v := Vector3(randf_range(-4.2, 4.2), randf_range(3.4, 6.8),
			randf_range(-1.4, 1.4))
		var spin := Vector3(randf_range(-16.0, 16.0), randf_range(-10.0, 10.0),
			randf_range(-16.0, 16.0))
		var dur := randf_range(1.1, 1.7)
		var tw := mi.create_tween()
		# Ballistic by hand: a tween cannot do a parabola, and a parabola is
		# what makes a thrown object read as having mass.
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(mi):
				return
			var p := p0 + v * t + Vector3(0, -13.0, 0) * 0.5 * t * t
			# Once it is on the floor it stays on the floor and slides out.
			if p.y < base_y:
				p.y = base_y
			mi.global_position = p
			mi.rotation = spin * minf(t, dur * 0.55)
		, 0.0, dur, dur)
		tw.chain().tween_property(mi, "scale", Vector3.ZERO, 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)


## A scorch on whatever it was standing over. Projected, not a quad, so it
## takes the floor's curvature and its normal instead of z-fighting with it.
func _scorch() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0),
		global_position + Vector3(0, -8.0, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var d := Decal.new()
	d.name = "Scorch"
	d.texture_albedo = PropKit._decal_texture("radial")
	d.modulate = Color(0.075, 0.062, 0.055)
	d.albedo_mix = 0.0
	var w := randf_range(1.9, 2.6)
	d.size = Vector3(w, 1.6, w)
	d.upper_fade = 0.8
	d.lower_fade = 0.6
	d.distance_fade_enabled = true
	d.distance_fade_begin = 40.0
	d.distance_fade_length = 16.0
	root.add_child(d)
	d.global_position = (hit["position"] as Vector3) + Vector3(0, 0.05, 0)
	d.rotation.y = randf_range(0.0, TAU)
	var tw := d.create_tween()
	tw.tween_property(d, "albedo_mix", 0.88, 0.16)
	tw.tween_interval(24.0)
	tw.tween_property(d, "albedo_mix", 0.0, 6.0)
	tw.tween_callback(d.queue_free)


func _spark(from: Vector3) -> void:
	_particles(14, Color(1.0, 0.82, 0.42), 0.30, (global_position - from).normalized(), 5.0)


func _debris() -> void:
	_particles(30, Color(0.88, 0.80, 0.62), 0.80, Vector3.UP, 8.5)
	_particles(22, Color(1.0, 0.58, 0.20), 0.50, Vector3.UP, 5.5)


## Dark, slow and alpha-blended — the opposite of every other particle in the
## file. Additive smoke is just a bright cloud; a kill needs something that
## takes light out of the frame so the sparks in front of it have somewhere to
## be bright against.
func _smoke(count: int, life: float, speed: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.72
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 10, 8))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.24
	pm.direction = Vector3.UP
	pm.spread = 46.0
	pm.initial_velocity_min = speed * 0.35
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, 0.85, 0)
	pm.damping_min = 2.2
	pm.damping_max = 4.5
	pm.angular_velocity_min = -55.0
	pm.angular_velocity_max = 55.0
	pm.scale_min = 0.8
	pm.scale_max = 2.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1.0, 1.7))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(0.16, 0.14, 0.13, 0.80))
	g.set_color(1, Color(0.34, 0.31, 0.28, 0.0))
	g.add_point(0.18, Color(0.21, 0.18, 0.17, 0.68))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.albedo_texture = PropKit._decal_texture("radial")
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad

	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p)
	p.global_position = global_position + Vector3(0, 0.45, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _particles(count: int, color: Color, life: float, dir: Vector3, speed: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = dir
	pm.spread = 70.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -14.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.scale_curve = Collectible._shrink_curve()
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad

	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(p)
	p.global_position = global_position + Vector3(0, 0.4, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)


func is_dead() -> bool:
	return _dead
