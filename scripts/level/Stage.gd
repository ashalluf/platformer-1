class_name Stage extends Node3D
## Base class for every playable level.
##
## Subclasses implement `_build_level()` and declare a mood; Stage handles the
## boilerplate every level needs: lighting, camera, player spawn, checkpoints,
## respawn and the kill plane. Nothing here knows what a level looks like.

signal player_spawned(player: PlayerController)
signal checkpoint_reached(index: int)
signal level_complete()

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")

@export var level_id := "greybox"
@export var level_title := "GREYBOX"
@export var spawn_point := Vector3(0.0, 2.0, 0.0)
@export var kill_plane_y := -24.0
@export var camera_bounds_min := Vector2(-1e6, -1e6)
@export var camera_bounds_max := Vector2(1e6, 1e6)
@export var use_camera_bounds := false
## 0 = street, 1 = prison. Level 1 opens in prison and changes mid-level.
@export var player_outfit := 0
@export var show_hud := true
## Theme id from MusicDirector.THEMES, or "" for silence.
@export var music_theme := ""

var player: PlayerController
var camera: GameCamera
var world_env: WorldEnvironment
var geometry: Node3D
var checkpoints: Array[Vector3] = []
var active_checkpoint := -1

var _respawning := false
## Wall-clock time in the level, for the result card. Taken from the clock
## rather than accumulated in _process, because subclasses override _process
## to drive their own music and lighting and none of them call super.
var _started_msec := 0
var elapsed := 0.0
var _result: ResultScreen
var _result_layer: CanvasLayer


func _ready() -> void:
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)

	_apply_spawn_override()
	Gx.current_level_id = level_id
	world_env = LightingRig.build(self, _mood())
	var preset := _sky_preset()
	if preset != "":
		SkyForge.apply(world_env.environment, preset)
	_build_level()
	_spawn_camera()
	_spawn_player(_current_spawn())
	if music_theme != "":
		Music.play(music_theme, 0.2)
	if show_hud:
		var layer := CanvasLayer.new()
		layer.name = "HUDLayer"
		add_child(layer)
		layer.add_child(HUD_SCENE.instantiate())
	GraphicsDirector.apply_all()
	level_complete.connect(_on_level_complete)
	_started_msec = Time.get_ticks_msec()


## Override: the level's lighting identity.
## `--spawn=X,Y` lets the capture tool shoot any section of a long level
## without playing through to it. Applied here, after the subclass has set its
## own spawn point in its _ready.
func _apply_spawn_override() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--spawn="):
			continue
		var parts := arg.substr(8).split(",")
		if parts.size() < 2:
			continue
		spawn_point = Vector3(float(parts[0]), float(parts[1]), 0.0)
		if parts.size() > 2:
			player_outfit = int(parts[2])
		return


func _mood() -> LightingRig.Mood:
	return LightingRig.neutral_studio()


## Override: which SkyForge preset this level's sky uses. An empty string keeps
## the plain [ProceduralSkyMaterial] LightingRig installs.
##
## It is a hook on Stage rather than a line in each level's _mood because the
## sky is not part of the mood: SkyForge reads the scene's own key light for the
## sun, so the disc, the warm band around it and the aerial haze all follow
## wherever the rig aimed, and a level that re-times its sun gets a correct sky
## for free. Presets: brega_gold, ajdabiya_morning, ice_twilight, studio.
func _sky_preset() -> String:
	return ""


## Override: build geometry, props, collectibles under `geometry`.
func _build_level() -> void:
	pass


func _spawn_camera() -> void:
	camera = GameCamera.new()
	camera.name = "GameCamera"
	camera.use_bounds = use_camera_bounds
	camera.bounds_min = camera_bounds_min
	camera.bounds_max = camera_bounds_max
	add_child(camera)
	camera.current = true


func _spawn_player(at: Vector3) -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = at
	add_child(player)
	player.terminal_fall_y = kill_plane_y
	player.died.connect(_on_player_died)
	var rig := player.get_node_or_null("Rig")
	if rig and rig.has_method("set_outfit"):
		rig.set_outfit(player_outfit)
	camera.bind(player)
	camera.snap_to_target()
	player_spawned.emit(player)


func _current_spawn() -> Vector3:
	if active_checkpoint >= 0 and active_checkpoint < checkpoints.size():
		return checkpoints[active_checkpoint]
	return spawn_point


func register_checkpoint(at: Vector3) -> int:
	checkpoints.append(at)
	return checkpoints.size() - 1


func reach_checkpoint(index: int) -> void:
	if index <= active_checkpoint:
		return
	active_checkpoint = index
	checkpoint_reached.emit(index)


func _on_player_died() -> void:
	if _respawning or _result != null:
		return
	_respawning = true
	FX.hitstop(0.08)
	await get_tree().create_timer(0.75, true, false, true).timeout
	if Gx.lives <= 0:
		_show_result(ResultScreen.Kind.GAME_OVER)
		return
	respawn()


# --- Result card ------------------------------------------------------------

func _on_level_complete() -> void:
	if _result != null:
		return
	# Let the hit-stop and the zoom punch land before the card arrives.
	await get_tree().create_timer(0.55, true, false, true).timeout
	_show_result(ResultScreen.Kind.CLEARED)


func _show_result(kind: ResultScreen.Kind) -> void:
	if _result != null:
		return
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_result_layer = CanvasLayer.new()
	_result_layer.name = "ResultLayer"
	_result_layer.layer = 95
	add_child(_result_layer)

	_result = ResultScreen.new()
	_result.kind = kind
	_result.entry = World.entry(level_id)
	_result.sriracha = Gx.sriracha
	_result.iced_out = Gx.iced_out_found.has(level_id)
	_result.chain = Gx.chains.has(level_id)
	elapsed = float(Time.get_ticks_msec() - _started_msec) * 0.001
	_result.elapsed = elapsed
	_result.dismissed.connect(_on_result_dismissed)
	_result_layer.add_child(_result)
	get_tree().paused = true


func _on_result_dismissed(action: String) -> void:
	get_tree().paused = false
	if action == "retry":
		# Out of lives: a clean run from the top of the level, not the map. The
		# level is the unit of failure in this game.
		Gx.reset_run()
		active_checkpoint = -1
		_result_layer.queue_free()
		_result = null
		_result_layer = null
		_respawning = false
		respawn()
		return
	SceneFlow.change_scene("res://levels/menu/WorldMap.tscn")


func respawn() -> void:
	if is_instance_valid(player):
		player.queue_free()
		await player.tree_exited
	_respawning = false
	_spawn_player(_current_spawn())


var _pause_menu: PauseMenu


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and show_hud:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		active_checkpoint = -1
		respawn()


func _toggle_pause() -> void:
	if is_instance_valid(_pause_menu):
		return
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.name = "PauseLayer"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_menu = PauseMenu.new()
	layer.add_child(_pause_menu)
	_pause_menu.resumed.connect(func() -> void:
		get_tree().paused = false
		layer.queue_free())
	_pause_menu.quit_to_title.connect(func() -> void:
		get_tree().paused = false
		layer.queue_free()
		SceneFlow.change_scene("res://levels/menu/TitleScreen.tscn"))
