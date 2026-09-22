extends CanvasLayer
## SceneFlow — scene changes, and the Iced Out warp.
##
## Every transition in this game is authored. A fade to black says "loading";
## frost crawling in from the edges says "you touched the thing and now you are
## somewhere else". The warp out and the warp back are the same effect run in
## opposite directions, which is what makes the round trip feel like one move.

signal transition_covered()
signal bonus_finished(earned_chain: bool)

const WIPE_SHADER := preload("res://shaders/frost_wipe.gdshader")
const ICE_LEVELS := [
	"res://levels/ice/IceBonus01.tscn",
	"res://levels/ice/IceBonus02.tscn",
	"res://levels/ice/IceBonus03.tscn",
]

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false

## Where to come back to when the bonus level ends.
var _return_scene := ""
var _return_position := Vector3.ZERO
var _return_level_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_mat = ShaderMaterial.new()
	_mat.shader = WIPE_SHADER
	_mat.set_shader_parameter("noise_tex", NoiseBank.pits(71))
	_mat.set_shader_parameter("progress", 0.0)

	_rect = ColorRect.new()
	_rect.name = "Wipe"
	_rect.material = _mat
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


func is_busy() -> bool:
	return _busy


## Cover the screen, swap the scene, uncover. `hold` is how long the screen
## stays fully covered — long enough for the new scene to build without the
## player seeing it pop in.
func change_scene(path: String, cover := 0.45, hold := 0.15, uncover := 0.55) -> void:
	if _busy:
		return
	_busy = true
	await _cover(cover)
	get_tree().change_scene_to_file(path)
	await get_tree().create_timer(hold, true, false, true).timeout
	await _uncover(uncover)
	_busy = false


## Touching an Iced Out Sriracha: remember where we were, then warp.
func warp_to_bonus(from_scene: String, from_position: Vector3, level_id: String) -> void:
	if _busy:
		return
	_return_scene = from_scene
	_return_position = from_position
	_return_level_id = level_id
	Gx.reset_ice_run()

	FX.hitstop(0.12)
	FX.shake(0.9)
	FX.zoom_punch(-9.0, 0.8)
	FX.timewarp(0.25, 0.7)
	Audio.play_2d("life", 0.0, 0.7)
	Audio.play_2d("dash_charged", -2.0, 0.6)

	var pick: String = ICE_LEVELS[randi() % ICE_LEVELS.size()]
	await change_scene(pick, 0.75, 0.2, 0.7)


## Leaving a bonus level, with or without the chain.
func return_from_bonus(earned_chain: bool) -> void:
	if _return_scene == "":
		return
	if earned_chain and _return_level_id != "":
		Gx.award_chain(_return_level_id)
	bonus_finished.emit(earned_chain)
	var scene := _return_scene
	_return_scene = ""
	await change_scene(scene, 0.6, 0.2, 0.6)


func has_return() -> bool:
	return _return_scene != ""


func return_position() -> Vector3:
	return _return_position


func _cover(duration: float) -> void:
	_rect.visible = true
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_progress, 0.0, 1.0, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	transition_covered.emit()


func _uncover(duration: float) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_progress, 1.0, 0.0, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_rect.visible = false


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
