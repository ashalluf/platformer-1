class_name IceBonusStage extends Stage
## Base for ICE bonus levels.
##
## The deal is fixed by canon: 100 ICE SRIRACHAS, and all 100 earns the chain.
## What makes it a *moment* rather than a checklist is that the level is short,
## the route is legible from the first second, and the whole place is built out
## of one material the rest of the game never uses.
##
## A timer gives it stakes. Running out is not a punishment — it returns you to
## the level you came from, just without the chain.

const TARGET := 100

@export var time_limit := 48.0

var _time_left := 0.0
var _finished := false
var _collected := 0
var _hud: IceHUD


func _ready() -> void:
	kill_plane_y = -26.0
	show_hud = false          ## this level has its own
	super._ready()
	_time_left = time_limit
	Gx.reset_ice_run()
	Gx.ice_sriracha_changed.connect(_on_ice_changed)

	var layer := CanvasLayer.new()
	layer.name = "IceHUDLayer"
	add_child(layer)
	_hud = IceHUD.new()
	layer.add_child(_hud)

	Audio.set_ambience("wind", -10.0)


func _process(delta: float) -> void:
	if _finished:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _hud:
		_hud.set_state(_collected, TARGET, _time_left, time_limit)
	if _time_left <= 0.0:
		_finish(false)


func _on_ice_changed(count: int, _needed: int) -> void:
	_collected = count
	if count >= TARGET:
		_finish(true)


## All 100. The chain drops in, the world stops, and it is loud.
func _finish(earned: bool) -> void:
	if _finished:
		return
	_finished = true
	if _hud:
		# The HUD stops updating once finished, so push the final count first.
		_hud.set_state(TARGET if earned else _collected, TARGET, _time_left, time_limit)
	if earned:
		FX.hitstop(0.16)
		FX.shake(1.0)
		FX.zoom_punch(-10.0, 1.0)
		FX.timewarp(0.22, 1.1)
		Audio.play_2d("life", 0.0, 1.0)
		if _hud:
			_hud.celebrate()
		_chain_burst()
	else:
		Audio.play_2d("hurt", -4.0, 0.8)
	await get_tree().create_timer(1.6 if earned else 0.8, true, false, true).timeout
	SceneFlow.return_from_bonus(earned)


func _chain_burst() -> void:
	if not is_instance_valid(player):
		return
	var p := GPUParticles3D.new()
	p.amount = 140
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.8
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -5.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 2.2
	pm.scale_curve = Collectible._shrink_curve()
	p.process_material = pm

	p.draw_pass_1 = FXKit.sprite_pass(0.12, Color(0.85, 0.96, 1.0), {"alpha": 0.95})

	add_child(p)
	p.global_position = player.global_position + Vector3(0, 1.2, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)

	# The chain itself, hanging in the air where he earned it.
	var chain := MeshInstance3D.new()
	chain.name = "ChainReward"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.60
	torus.rings = 36
	torus.ring_segments = 10
	chain.mesh = torus
	var gold := MaterialLab.gold(Color(1.0, 0.80, 0.34))
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.72, 0.26)
	gold.emission_energy_multiplier = 1.8
	gold.roughness = 0.24
	chain.material_override = gold
	chain.rotation_degrees = Vector3(74, 0, 0)
	add_child(chain)
	chain.global_position = player.global_position + Vector3(0, 2.2, 0)
	var halo := OmniLight3D.new()
	halo.light_color = Color(1.0, 0.82, 0.42)
	halo.light_energy = 7.0
	halo.omni_range = 7.0
	halo.light_volumetric_fog_energy = 5.0
	halo.shadow_enabled = false
	chain.add_child(halo)
	var tw := create_tween()
	tw.tween_property(chain, "scale", Vector3.ONE * 1.6, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(chain, "rotation:y", TAU, 1.4)
