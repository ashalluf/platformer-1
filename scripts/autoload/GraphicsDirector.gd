extends Node
## GraphicsDirector — one place that decides how heavy the renderer runs.
##
## Levels author their WorldEnvironment for the *look*; this scales the *cost*
## of that look to the selected quality tier, so art direction stays identical
## from low to ultra. It never changes colours, only sample counts and ranges.

enum Tier { LOW, MEDIUM, HIGH, ULTRA }

const TIERS := {
	Tier.LOW: {
		"render_scale": 0.72, "taa": false, "msaa": Viewport.MSAA_DISABLED,
		"fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "shadow_size": 2048,
		"sdfgi": false, "ssao": false, "ssil": false, "ssr": false,
		"volumetric": false, "dof": false, "shadow_distance": 70.0,
	},
	Tier.MEDIUM: {
		"render_scale": 0.85, "taa": false, "msaa": Viewport.MSAA_2X,
		"fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "shadow_size": 3072,
		"sdfgi": false, "ssao": true, "ssil": false, "ssr": false,
		"volumetric": true, "dof": true, "shadow_distance": 110.0,
	},
	Tier.HIGH: {
		"render_scale": 1.0, "taa": true, "msaa": Viewport.MSAA_2X,
		"fxaa": Viewport.SCREEN_SPACE_AA_DISABLED, "shadow_size": 4096,
		"sdfgi": true, "ssao": true, "ssil": true, "ssr": true,
		"volumetric": true, "dof": true, "shadow_distance": 160.0,
	},
	Tier.ULTRA: {
		"render_scale": 1.0, "taa": true, "msaa": Viewport.MSAA_4X,
		"fxaa": Viewport.SCREEN_SPACE_AA_DISABLED, "shadow_size": 8192,
		"sdfgi": true, "ssao": true, "ssil": true, "ssr": true,
		"volumetric": true, "dof": true, "shadow_distance": 220.0,
	},
}

var tier: Tier = Tier.HIGH
## Capture runs disable temporal effects so a single frame is fully resolved.
var capture_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tier = clampi(int(Gx.get_setting("quality", Tier.HIGH)), 0, Tier.size() - 1) as Tier
	Gx.setting_changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("apply_all")


func _on_setting_changed(key: String) -> void:
	if key == "quality":
		tier = clampi(int(Gx.get_setting("quality", Tier.HIGH)), 0, Tier.size() - 1) as Tier
		apply_all()
	elif key == "fullscreen":
		var want: bool = Gx.get_setting("fullscreen", false)
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if want else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		# Apply on the next idle frame so the level finishes building first.
		(node as WorldEnvironment).ready.connect(apply_all, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func spec() -> Dictionary:
	return TIERS[tier]


func apply_all() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	apply_to_viewport(vp)
	for env: WorldEnvironment in get_tree().get_nodes_in_group("world_environment"):
		apply_to_environment(env.environment)
	for light: Node in get_tree().get_nodes_in_group("sun"):
		if light is DirectionalLight3D:
			apply_to_sun(light)


func apply_to_viewport(vp: Viewport) -> void:
	var s := spec()
	vp.scaling_3d_scale = s["render_scale"]
	vp.msaa_3d = s["msaa"]
	vp.screen_space_aa = s["fxaa"]
	vp.use_taa = s["taa"] and not capture_mode
	vp.positional_shadow_atlas_size = s["shadow_size"]


func apply_to_environment(env: Environment) -> void:
	if env == null:
		return
	var s := spec()
	env.sdfgi_enabled = s["sdfgi"]
	env.ssao_enabled = s["ssao"]
	env.ssil_enabled = s["ssil"]
	env.ssr_enabled = s["ssr"]
	env.volumetric_fog_enabled = s["volumetric"]


func apply_to_sun(sun: DirectionalLight3D) -> void:
	var s := spec()
	sun.directional_shadow_max_distance = s["shadow_distance"]
	sun.shadow_enabled = true


## Called by the capture tool: deterministic single frames, no temporal noise.
func enter_capture_mode(force_tier: int = -1) -> void:
	capture_mode = true
	if force_tier >= 0:
		tier = clampi(force_tier, 0, Tier.size() - 1) as Tier
	apply_all()
