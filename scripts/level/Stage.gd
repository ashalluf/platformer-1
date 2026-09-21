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

@export var level_id := "greybox"
@export var level_title := "GREYBOX"
@export var spawn_point := Vector3(0.0, 2.0, 0.0)
@export var kill_plane_y := -24.0
@export var camera_bounds_min := Vector2(-1e6, -1e6)
@export var camera_bounds_max := Vector2(1e6, 1e6)
@export var use_camera_bounds := false

var player: PlayerController
var camera: GameCamera
var world_env: WorldEnvironment
var geometry: Node3D
var checkpoints: Array[Vector3] = []
var active_checkpoint := -1

var _respawning := false


func _ready() -> void:
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)

	world_env = LightingRig.build(self, _mood())
	_build_level()
	_spawn_camera()
	_spawn_player(_current_spawn())
	GraphicsDirector.apply_all()


## Override: the level's lighting identity.
func _mood() -> LightingRig.Mood:
	return LightingRig.neutral_studio()


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
	if _respawning:
		return
	_respawning = true
	FX.hitstop(0.08)
	await get_tree().create_timer(0.75, true, false, true).timeout
	respawn()


func respawn() -> void:
	if is_instance_valid(player):
		player.queue_free()
		await player.tree_exited
	_respawning = false
	_spawn_player(_current_spawn())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		active_checkpoint = -1
		respawn()
