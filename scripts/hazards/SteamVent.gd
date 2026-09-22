class_name SteamVent extends Node3D
## A relief valve that still has something behind it.
##
## The plant's own hazards, not placed spikes: a pipe stub that hisses, spits a
## warning wisp, then blasts a column of superheated steam. It is on a fixed
## cycle and it always warns, so it is a rhythm to walk through rather than a
## trap — the player should lose a life to bad timing, never to bad luck.
##
## It is built from the same parts bin as the security units (see the design
## language at the top of Enemy.gd) and runs the same warning ramp on its
## collar that they run on their optics, because the player should only ever
## have to learn one sentence: amber breathing means not yet, amber going
## white means now.

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
var _collar_mat: ShaderMaterial
var _stub: Node3D
var _shudder := 0.0
var _shudder_vel := 0.0


func _ready() -> void:
	_timer = -phase
	_build()


func _build() -> void:
	var iron := Enemy.iron_material()
	var shell := Enemy.shell_material(Enemy.SHELL_DARK)
	var accent := Enemy.accent_material()
	_collar_mat = accent

	# --- Base: a real flanged connection into the deck --------------------
	# A hazard that grows out of the floor with no joint in it is a spike. A
	# flange with a bolt ring on it is a pipe someone once maintained.
	Enemy._part(self, "Pad", Enemy._cyl(0.38, 0.06, 14), shell,
		Vector3(0, 0.03, 0))
	Enemy._part(self, "Flange", Enemy._cyl(0.31, 0.09, 14), iron,
		Vector3(0, 0.10, 0))
	Enemy.bolt_ring(self, Vector3(0, 0.145, 0), 0.245, 8, iron, 0.018,
		Vector3.UP)
	# Dirt where it meets the floor, and rust running off the flange bolts.
	Enemy.dirt_band(self, Vector3(0, 0.10, 0.39), Vector2(0.78, 0.24), 0.62)
	# Runs start above the flange, not across it: a stain quad that cuts
	# through the flange plate reads as a sticker rather than as a stain.
	Enemy.rust_streak(self, Vector3(-0.105, 0.34, 0.240), Vector2(0.10, 0.30),
		0.55)
	Enemy.rust_streak(self, Vector3(0.125, 0.31, 0.235), Vector2(0.075, 0.24),
		0.42)

	# --- The stub, on its own node so it can shake ------------------------
	_stub = Node3D.new()
	_stub.name = "Stub"
	_stub.position = Vector3(0, 0.14, 0)
	add_child(_stub)

	Enemy._part(_stub, "Barrel", Enemy._cyl(0.185, 0.36, 12, 0.165), iron,
		Vector3(0, 0.18, 0))
	# A lagging band and its strap. Everything in this plant that carries heat
	# is wrapped in something, and the strap is the detail that says so.
	Enemy._part(_stub, "Lagging", Enemy._cyl(0.215, 0.16, 12), shell,
		Vector3(0, 0.14, 0))
	Enemy._part(_stub, "Strap", Enemy._cyl(0.225, 0.022, 12), iron,
		Vector3(0, 0.20, 0))
	# Cooling fins under the throat: it is a relief valve, so it sheds heat
	# between blasts and it should look like it.
	Enemy.fin_stack(_stub, Vector3(0, 0.30, 0), 3,
		Vector3(0.40, 0.012, 0.40), 0.034, iron)

	# THE hazard band, on the throat — the part that arrives first, exactly as
	# on the three security units. Same rule, same rake, same amber.
	Enemy.chevron_ring(_stub, Vector3(0, 0.40, 0), 0.215, 0.085, 8, accent,
		iron)

	Enemy._part(_stub, "Nozzle", Enemy._cyl(0.155, 0.10, 12, 0.185), iron,
		Vector3(0, 0.47, 0))
	Enemy._part(_stub, "Throat", Enemy._cyl(0.135, 0.05, 12),
		Enemy.recess_material(), Vector3(0, 0.525, 0))
	# The warning plate. Arabic-only safety signage, which is what the plant
	# actually uses; the stencil sits on it.
	Enemy._part(_stub, "Plate", LevelKit.chamfer_mesh(
		Vector3(0.20, 0.10, 0.016), 0.004), accent,
		Vector3(0.0, 0.055, 0.205))
	Enemy.stencil(_stub, "خطر", Vector3(0.0, 0.048, 0.218), 0.062,
		Color(0.16, 0.14, 0.12))

	_jet = _column(0.0, 34, 3.2)
	_wisp = _column(0.0, 10, 0.9)
	_wisp.emitting = false

	_light = OmniLight3D.new()
	_light.light_color = Color(0.86, 0.92, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 4.0
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
			_set_collar(0.0)
			if _timer >= interval:
				_mode = Mode.WARN
				_timer = 0.0
				_wisp.emitting = true
				Audio.play("wind", global_position, -18.0, 1.8)
		Mode.WARN:
			# The collar goes hot and the pulse tightens. Same tell as the
			# turret's optic, on purpose: one language for "it is about to".
			var t := clampf(_timer / warn_time, 0.0, 1.0)
			var pulse := 0.5 + 0.5 * sin(_timer * lerpf(9.0, 36.0, t))
			_set_collar(lerpf(0.25, 1.0, t) * (0.35 + 0.65 * pulse))
			# It shakes before it lets go. There is pressure behind it, and
			# something that is about to release pressure never sits still.
			_shudder_vel += (randf() - 0.5) * lerpf(2.0, 26.0, t) * delta
			if _timer >= warn_time:
				_mode = Mode.BLAST
				_timer = 0.0
				_wisp.emitting = false
				_jet.emitting = true
				_area.monitoring = true
				_light.light_energy = 6.0
				Audio.play("dash", global_position, -6.0, 0.55)
				FX.shake(0.18)
				# The stub kicks down on its flange as the jet leaves it.
				_shudder_vel -= 3.2
				blasted.emit()
		Mode.BLAST:
			_set_collar(1.0)
			_light.light_energy = lerpf(6.0, 1.0,
				clampf(_timer / blast_time, 0.0, 1.0))
			if _timer >= blast_time:
				_mode = Mode.IDLE
				_timer = 0.0
				_jet.emitting = false
				_area.monitoring = false
				_light.light_energy = 0.0
	_settle(delta)


## The same under-damped spring the security units use, on one axis. It costs
## two floats and it is the difference between a pipe and a pipe with three
## hundred PSI behind it.
func _settle(delta: float) -> void:
	var d := minf(delta, 0.05)
	_shudder_vel += (-_shudder * 2600.0 - _shudder_vel * 34.0) * d
	_shudder += _shudder_vel * d
	_stub.position.y = 0.14 + clampf(_shudder, -0.035, 0.035)


## Amber breathing to amber white-hot, on the same ramp as an optic.
func _set_collar(amount: float) -> void:
	if _collar_mat == null:
		return
	_collar_mat.set_shader_parameter("emission_color",
		Color(1.0, 0.55, 0.20).lerp(Color(1.0, 0.92, 0.78), amount))
	_collar_mat.set_shader_parameter("emission_strength", amount * 4.2)


func _on_body(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).take_hit(damage, global_position)
