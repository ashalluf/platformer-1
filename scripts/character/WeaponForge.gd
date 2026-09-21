class_name WeaponForge
## Builds Wanis's rifle.
##
## A stamped-receiver 7.62 pattern rifle: wood furniture, a long gas tube above
## the barrel, a front sight block, and the curved magazine that carries the
## whole silhouette. Lofted like everything else in this project.
##
## Scale matters more than detail here. At 15% of screen height the rifle is
## about 60 px long, so the read comes from three things and three only: the
## magazine curve, the angled stock, and the gap between barrel and gas tube.

const LENGTH := 0.88   ## muzzle to butt, in world units


static func materials() -> Dictionary:
	var wood := MaterialLab.cloth(Color(0.380, 0.196, 0.098), 0.52)
	wood.rim = 0.25
	var steel := MaterialLab.chrome(Color(0.165, 0.161, 0.157), 0.38)
	steel.metallic = 0.85
	var park := MaterialLab.chrome(Color(0.098, 0.094, 0.090), 0.55)
	park.metallic = 0.7
	return {"wood": wood, "steel": steel, "park": park}


## Returns a Node3D holding the rifle, muzzle-forward along +Z, grip down.
## Origin sits at the grip, which is where a hand goes.
static func build() -> Node3D:
	var m := materials()
	var root := Node3D.new()
	root.name = "AK"

	_part(root, "Receiver", _tube([
		[-0.16, 0.060, 0.046], [-0.02, 0.065, 0.050],
		[0.16, 0.062, 0.048], [0.22, 0.052, 0.042],
	]), m["park"], 0.115)

	# Dust cover ridge: the line along the top that says which rifle this is.
	_part(root, "DustCover", _tube([
		[-0.15, 0.020, 0.014], [0.14, 0.022, 0.016],
	]), m["park"], 0.170)

	_part(root, "Handguard", _tube([
		[0.22, 0.048, 0.040], [0.30, 0.052, 0.044],
		[0.40, 0.048, 0.040], [0.44, 0.038, 0.032],
	]), m["wood"], 0.108)

	# Gas tube rides above the barrel; the gap between them is silhouette.
	_part(root, "GasTube", _tube([
		[0.24, 0.022, 0.020], [0.46, 0.022, 0.020],
	]), m["park"], 0.166)
	_part(root, "Barrel", _tube([
		[0.44, 0.021, 0.021], [0.70, 0.019, 0.019],
	]), m["steel"], 0.104)
	_part(root, "FrontSight", _tube([
		[0.66, 0.026, 0.022], [0.70, 0.024, 0.020], [0.72, 0.012, 0.010],
	]), m["park"], 0.128)
	_part(root, "RearSight", _tube([
		[0.18, 0.020, 0.018], [0.21, 0.018, 0.016],
	]), m["park"], 0.152)
	_part(root, "MuzzleBrake", _tube([
		[0.76, 0.029, 0.027], [0.84, 0.028, 0.026],
	]), m["steel"], 0.104)

	# Pistol grip, raked back.
	var grip := _part(root, "Grip", _tube([
		[0.0, 0.030, 0.042], [-0.10, 0.026, 0.036], [-0.14, 0.022, 0.030],
	]), m["wood"], 0.0)
	# Raked back off the receiver; this is where the firing hand goes.
	grip.position = Vector3(0.0, 0.055, -0.055)
	grip.rotation = Vector3(deg_to_rad(90.0 + 104.0), 0.0, 0.0)

	# Stock: the angle off the receiver is the second silhouette cue.
	var stock := _part(root, "Stock", _tube([
		[-0.04, 0.036, 0.030], [-0.20, 0.042, 0.034], [-0.30, 0.052, 0.038],
	]), m["wood"], 0.0)
	stock.position = Vector3(0.0, 0.098, -0.15)
	stock.rotation = Vector3(deg_to_rad(90.0 - 7.0), 0.0, 0.0)

	_magazine(root, m["park"])

	# Muzzle marker: flash, tracers and shells all reference this.
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.118, 0.86)
	root.add_child(muzzle)

	var eject := Marker3D.new()
	eject.name = "Eject"
	eject.position = Vector3(0.045, 0.145, 0.12)
	root.add_child(eject)

	return root


## The banana curve, built by walking rings down an arc.
static func _magazine(root: Node3D, mat: Material) -> void:
	var b := MeshForge.Builder.new()
	b.begin()
	var rings := []
	var steps := 7
	for i in steps:
		var t := float(i) / float(steps - 1)
		# Arc sweeps forward as it descends — that is the whole shape.
		var y := -t * 0.185
		var z := 0.055 + sin(t * 1.15) * 0.085
		var w := lerpf(0.030, 0.024, t)
		var d := lerpf(0.058, 0.046, t)
		rings.append(MeshForge.ring(Vector3(0.0, y, z), w, d, [0], [1.0], 3.2))
	b.loft(rings, 10, true, true)
	var mi := MeshInstance3D.new()
	mi.name = "Magazine"
	mi.mesh = b.commit()
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.020, 0.10)
	mi.rotate_x(deg_to_rad(-16.0))
	root.add_child(mi)


## Rings are [z_along_barrel, half_height, half_width].
static func _tube(spec: Array) -> ArrayMesh:
	var b := MeshForge.Builder.new()
	b.begin()
	var rings := []
	for e: Array in spec:
		# Built lying along Y then rotated, so the loft's own axis still applies.
		rings.append(MeshForge.ring(Vector3(0.0, e[0], 0.0), e[2], e[1], [0], [1.0], 3.0))
	b.loft(rings, 10, true, true)
	return b.commit()


## `lift` is the part's height above the grip origin, applied after the loft is
## turned to run down the barrel axis.
static func _part(root: Node3D, name_: String, mesh: Mesh, mat: Material,
		lift := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	# Lofts run along +Y; the rifle runs along +Z.
	mi.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	mi.position = Vector3(0.0, lift, 0.0)
	root.add_child(mi)
	return mi
