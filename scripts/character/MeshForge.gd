class_name MeshForge
## Procedural skinned-mesh construction.
##
## Characters in this project are lofted, not modelled: a chain of cross-section
## rings is swept along a bone chain and skinned to it. Rings carry their own
## radii, roundness and bone weights, so a silhouette is authored as a list of
## numbers that can be tuned from a screenshot instead of a DCC package.
##
## Cross-sections are superellipses — |x/rx|^n + |z/rz|^n = 1. n=2 is an ellipse,
## higher n squares it off. Stylized characters live between 2.2 and 4.

## A cross-section. `bones`/`weights` are up to four pairs, normalised on use.
static func ring(pos: Vector3, rx: float, rz: float, bones: Array, weights: Array,
		roundness := 2.4, offset := Vector3.ZERO) -> Dictionary:
	return {
		"pos": pos, "rx": rx, "rz": rz, "bones": bones, "weights": weights,
		"roundness": roundness, "offset": offset, "color": Color.BLACK,
	}


static func _superellipse(theta: float, rx: float, rz: float, n: float) -> Vector2:
	var c := cos(theta)
	var s := sin(theta)
	# Signed power keeps the shape symmetric through all four quadrants.
	var e := 2.0 / n
	var x := signf(c) * pow(absf(c), e) * rx
	var z := signf(s) * pow(absf(s), e) * rz
	return Vector2(x, z)


static func _pad(arr: Array, size: int, fill: Variant) -> Array:
	var out := arr.duplicate()
	while out.size() < size:
		out.append(fill)
	return out.slice(0, size)


static func _normalised_weights(weights: Array) -> PackedFloat32Array:
	var total := 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	var out := PackedFloat32Array()
	for w: float in weights:
		out.append(w / total)
	return out


## Builder keeps a running vertex count, which SurfaceTool does not expose.
class Builder extends RefCounted:
	var st := SurfaceTool.new()
	var count := 0

	func begin() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		count = 0

	func _vertex(p: Vector3, uv: Vector2, bones: Array, weights: Array,
			color := Color.BLACK) -> int:
		st.set_color(color)
		st.set_uv(uv)
		st.set_bones(PackedInt32Array(MeshForge._pad(bones, 4, 0)))
		st.set_weights(MeshForge._normalised_weights(MeshForge._pad(weights, 4, 0.0)))
		st.add_vertex(p)
		count += 1
		return count - 1

	## Sweep a tube through the given rings.
	## `arc_span` under TAU produces an open shell — used for the hair, which has
	## to wrap the skull without covering the face.
	func loft(rings: Array, segments := 16, cap_start := false, cap_end := false,
			arc_start := 0.0, arc_span := TAU) -> void:
		if rings.size() < 2:
			return
		var closed := arc_span >= TAU - 0.0001
		var steps := segments if closed else segments + 1
		var first := count
		for r in rings.size():
			var ring: Dictionary = rings[r]
			var v := float(r) / float(rings.size() - 1)
			for s in steps:
				var theta := arc_start + arc_span * float(s) / float(segments)
				var xz := MeshForge._superellipse(theta, ring["rx"], ring["rz"], ring["roundness"])
				var p: Vector3 = ring["pos"] + ring["offset"] + Vector3(xz.x, 0.0, xz.y)
				_vertex(p, Vector2(float(s) / float(segments), v), ring["bones"],
					ring["weights"], ring.get("color", Color.BLACK))

		for r in rings.size() - 1:
			for s in (steps if closed else steps - 1):
				var s2 := (s + 1) % steps
				var a := first + r * steps + s
				var b := first + r * steps + s2
				var c := first + (r + 1) * steps + s2
				var d := first + (r + 1) * steps + s
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(a); st.add_index(d); st.add_index(c)

		if cap_start and closed:
			var up_start: float = signf(rings[0]["pos"].y - rings[1]["pos"].y)
			_cap(rings[0], first, steps, true, up_start if up_start != 0.0 else -1.0)
		if cap_end and closed:
			var n := rings.size() - 1
			var up_end: float = signf(rings[n]["pos"].y - rings[n - 1]["pos"].y)
			_cap(rings[n], first + n * steps, steps, false, up_end if up_end != 0.0 else 1.0)

	## Close an end with a fan to a slightly domed pole, so caps read as rounded
	## rather than as a flat disc catching a hard specular.
	## `outward` is +1 when this end faces up the Y axis and -1 when it faces
	## down; the dome and the winding both follow it.
	func _cap(ring: Dictionary, ring_start: int, segments: int, is_start: bool,
			outward := -1.0) -> void:
		var dome: float = maxf(ring["rx"], ring["rz"]) * 0.55 * outward
		var pole: Vector3 = ring["pos"] + ring["offset"] + Vector3(0.0, dome, 0.0)
		var pi := _vertex(pole, Vector2(0.5, 0.0 if is_start else 1.0), ring["bones"],
			ring["weights"], ring.get("color", Color.BLACK))
		var flip := outward < 0.0
		for s in segments:
			var s2 := (s + 1) % segments
			var a := ring_start + s
			var b := ring_start + s2
			if flip:
				st.add_index(pi); st.add_index(a); st.add_index(b)
			else:
				st.add_index(pi); st.add_index(b); st.add_index(a)

	## Lofted sphere-ish blob — heads, hands, hair shells.
	func blob(center: Vector3, radius: Vector3, bones: Array, weights: Array,
			rings := 9, segments := 16, roundness := 2.2,
			shape: Callable = Callable(), arc_start := 0.0, arc_span := TAU,
			t_from := 0.0, t_to := 1.0) -> void:
		var ring_list := []
		for i in rings:
			var t := lerpf(t_from, t_to, float(i) / float(rings - 1))
			var phi := PI * t
			var y := -cos(phi)
			var r := sin(phi)
			var rx := radius.x * r
			var rz := radius.z * r
			var offset := Vector3.ZERO
			if shape.is_valid():
				var mod: Dictionary = shape.call(t, y)
				rx *= mod.get("sx", 1.0)
				rz *= mod.get("sz", 1.0)
				offset = mod.get("offset", Vector3.ZERO)
			ring_list.append(MeshForge.ring(
				center + Vector3(0.0, y * radius.y, 0.0),
				maxf(rx, 0.0005), maxf(rz, 0.0005), bones, weights, roundness, offset))
		loft(ring_list, segments, false, false, arc_start, arc_span)

	func commit(smooth := true) -> ArrayMesh:
		if smooth:
			st.generate_normals()
		st.generate_tangents()
		return st.commit()
