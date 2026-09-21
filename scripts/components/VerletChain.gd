class_name VerletChain extends MeshInstance3D
## Secondary motion for cloth-ish things: Wanis's sash, his chain, banners, wires.
##
## A verlet point chain pinned at the first node, rendered as a camera-facing
## ribbon. Cheap enough to run several per scene and it is the single biggest
## "this was animated by a person" cue on an otherwise procedural character.

@export var segments := 9
@export var segment_length := 0.16
@export var thickness := 0.09
@export var taper := 0.75            ## width at the free end, relative
@export var gravity := 14.0
@export var damping := 0.86
@export var stiffness := 0.55        ## constraint iterations blend
@export var wind_strength := 0.6
## Constant acceleration in the ANCHOR's local space — used to hold cloth away
## from the body. Local, not world: in a side-scroller "behind him" is local -Z,
## which becomes world -X once he is facing along the screen.
@export var bias := Vector3.ZERO
@export var wind_speed := 2.4
@export var inertia := 1.0           ## how much anchor motion whips the chain
@export var chain_material: Material

var _points: PackedVector3Array
var _prev: PackedVector3Array
var _anchor_prev := Vector3.ZERO
var _time := 0.0
var _im: ImmediateMesh


func _ready() -> void:
	top_level = true   ## simulate in world space; the anchor drives us manually
	_im = ImmediateMesh.new()
	mesh = _im
	if chain_material:
		material_override = chain_material
	_reset()


func _reset() -> void:
	var origin := get_parent_node_3d().global_position if get_parent_node_3d() else global_position
	_points = PackedVector3Array()
	_prev = PackedVector3Array()
	for i in segments:
		var p := origin + Vector3.DOWN * segment_length * i
		_points.append(p)
		_prev.append(p)
	_anchor_prev = origin


func _process(delta: float) -> void:
	var parent := get_parent_node_3d()
	if parent == null or _points.is_empty():
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta

	var anchor := parent.global_position
	var world_bias := parent.global_transform.basis * bias
	var anchor_vel := (anchor - _anchor_prev) / maxf(delta, 0.0001)
	_anchor_prev = anchor

	_points[0] = anchor
	_prev[0] = anchor

	var wind := Vector3(
		sin(_time * wind_speed) * 0.6 + sin(_time * wind_speed * 2.3) * 0.4,
		cos(_time * wind_speed * 1.7) * 0.35,
		0.0
	) * wind_strength

	for i in range(1, _points.size()):
		var cur := _points[i]
		var vel := (cur - _prev[i]) * damping
		vel -= anchor_vel * delta * inertia * 0.35
		_prev[i] = cur
		var acc := Vector3(0.0, -gravity, 0.0) + wind + world_bias
		_points[i] = cur + vel + acc * delta * delta

	# Distance constraints, anchored end first.
	for _iter in 3:
		for i in range(_points.size() - 1):
			var a := _points[i]
			var b := _points[i + 1]
			var d := b - a
			var len := d.length()
			if len < 0.0001:
				continue
			var correction := d * ((len - segment_length) / len)
			if i == 0:
				_points[i + 1] = b - correction * stiffness * 2.0
			else:
				_points[i] = a + correction * 0.5 * stiffness
				_points[i + 1] = b - correction * 0.5 * stiffness
		_points[0] = anchor

	_rebuild_ribbon()
	if OS.get_cmdline_user_args().has("--debug-cloth") and Engine.get_process_frames() % 60 == 0:
		print("CLOTH %s pts=%d head=%s tail=%s vis=%s" % [name, _points.size(), _points[0], _points[_points.size() - 1], is_visible_in_tree()])


func _rebuild_ribbon() -> void:
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _points.size()
	for i in n:
		var t := float(i) / float(n - 1)
		var half := thickness * lerpf(1.0, taper, t) * 0.5
		var dir: Vector3
		if i == 0:
			dir = (_points[1] - _points[0])
		elif i == n - 1:
			dir = (_points[n - 1] - _points[n - 2])
		else:
			dir = (_points[i + 1] - _points[i - 1])
		dir = dir.normalized() if dir.length() > 0.0001 else Vector3.DOWN
		# Ribbon faces the camera plane (+Z) — this is a 2.5D side-on game.
		var side := dir.cross(Vector3.BACK).normalized() * half
		if side.length() < 0.0001:
			side = Vector3.RIGHT * half
		var local_a := to_local(_points[i] + side)
		var local_b := to_local(_points[i] - side)
		_im.surface_set_normal(Vector3.BACK)
		_im.surface_set_uv(Vector2(0.0, t))
		_im.surface_add_vertex(local_a)
		_im.surface_set_normal(Vector3.BACK)
		_im.surface_set_uv(Vector2(1.0, t))
		_im.surface_add_vertex(local_b)
	_im.surface_end()
