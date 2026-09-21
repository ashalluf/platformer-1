class_name SteamVent extends Node3D
## A relief valve that still has something behind it.
##
## The plant's own hazards, not placed spikes: a pipe stub that hisses, spits a
## warning wisp, then blasts a column of superheated steam. It is on a fixed
## cycle and it always warns, so it is a rhythm to walk through rather than a
## trap — the player should lose a life to bad timing, never to bad luck.

signal blasted()

@export var interval := 2.8
@export var warn_time := 0.65
@export var blast_time := 0.9
@export var height := 4.2
@export var damage := 1.0
@export var phase := 0.0          ## offset, so a row of them ripples
@export var direction := Vector3.UP

enum Mode { IDLE, WARN, BLAST }

var _mode: Mode = Mode.IDLE
var _timer := 0.0
var _area: Area3D
var _jet: GPUParticles3D
var _wisp: GPUParticles3D
var _light: OmniLight3D
var _collar: MeshInstance3D
var _collar_mat: StandardMaterial3D


func _ready() -> void:
	_timer = -phase
	_build()


func _build() -> void:
	var steel := MaterialLab.chrome(Color(0.140, 0.136, 0.140), 0.5)
	var hazard := MaterialLab.cloth(Color(0.84, 0.58, 0.10), 0.7)

	var flange := MeshInstance3D.new()
	flange.name = "Flange"
	var fm := CylinderMesh.new()
	fm.top_radius = 0.30
	fm.bottom_radius = 0.34
	fm.height = 0.14
	fm.radial_segments = 14
	flange.mesh = fm
	flange.material_override = steel
	add_child(flange)

	var stub := MeshInstance3D.new()
	stub.name = "Stub"
	var sm := CylinderMesh.new()
	sm.top_radius = 0.17
	sm.bottom_radius = 0.20
	sm.height = 0.42
	sm.radial_segments = 12
	stub.mesh = sm
	stub.material_override = steel
	stub.position = Vector3(0, 0.22, 0)
	add_child(stub)

	# The collar is the tell: it is the only saturated thing here and it goes
	# hot before the blast.
	_collar = MeshInstance3D.new()
	_collar.name = "Collar"
	var cm := TorusMesh.new()
	cm.inner_radius = 0.19
	cm.outer_radius = 0.25
	cm.rings = 16
	cm.ring_segments = 6
	_collar.mesh = cm
	_collar_mat = (hazard as StandardMaterial3D).duplicate()
	_collar.material_override = _collar_mat
	_collar.position = Vector3(0, 0.40, 0)
	add_child(_collar)

	_jet = _column(0.0, 34, 3.2)
	_wisp = _column(0.0, 10, 0.9)
	_wisp.emitting = false

	_light = OmniLight3D.new()
	_light.light_color = Color(0.86, 0.92, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_light.position = direction * height * 0.35
	add_child(_light)

	_area = Area3D.new()
	_area.name = "Jet"
	_area.collision_layer = 0
	_area.collision_mask = 2
	_area.monitoring = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.75, height, 0.75)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = direction * height * 0.5
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)


func _column(_unused: float, amount: int, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = height / maxf(speed, 0.1)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, height + 2, 4))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = direction
	pm.spread = 7.0
	pm.initial_velocity_min = speed * 0.8
	pm.initial_velocity_max = speed * 1.25
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.4
	pm.damping_max = 1.1
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(0.55, 1.0))
	sc.add_point(Vector2(1.0, 1.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.70))
	ramp.set_color(1, Color(0.90, 0.93, 0.98, 0.0))
	ramp.add_point(0.25, Color(0.97, 0.98, 1.0, 0.55))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.85, 0.85)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 1)
	m.albedo_texture = PropKit._decal_texture("radial")
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	quad.material = m
	p.draw_pass_1 = quad
	p.emitting = false
	add_child(p)
	return p


func _process(delta: float) -> void:
	_timer += delta
	match _mode:
		Mode.IDLE:
			_collar_mat.emission_enabled = false
			if _timer >= interval:
				_mode = Mode.WARN
				_timer = 0.0
				_wisp.emitting = true
				Audio.play("wind", global_position, -18.0, 1.8)
		Mode.WARN:
			# The collar goes hot and the pulse tightens. Same tell as the
			# turret, on purpose: one language for "it is about to".
			var t := clampf(_timer / warn_time, 0.0, 1.0)
			var pulse := 0.5 + 0.5 * sin(_timer * lerpf(9.0, 36.0, t))
			_collar_mat.emission_enabled = true
			_collar_mat.emission = Color(1.0, 0.55, 0.20)
			_collar_mat.emission_energy_multiplier = lerpf(0.6, 4.5, t) * pulse
			if _timer >= warn_time:
				_mode = Mode.BLAST
				_timer = 0.0
				_wisp.emitting = false
				_jet.emitting = true
				_area.monitoring = true
				_light.light_energy = 6.0
				Audio.play("dash", global_position, -6.0, 0.55)
				FX.shake(0.18)
				blasted.emit()
		Mode.BLAST:
			_collar_mat.emission_energy_multiplier = 5.0
			_light.light_energy = lerpf(6.0, 1.0,
				clampf(_timer / blast_time, 0.0, 1.0))
			if _timer >= blast_time:
				_mode = Mode.IDLE
				_timer = 0.0
				_jet.emitting = false
				_area.monitoring = false
				_light.light_energy = 0.0


func _on_body(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).take_hit(damage, global_position)
