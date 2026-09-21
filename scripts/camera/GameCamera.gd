class_name GameCamera extends Camera3D
## The expensive-feeling camera.
##
## Side-on 2.5D framing with predictive look-ahead, an airborne vertical
## deadzone, grounded snap-to-floor, speed-driven FOV, landing kicks and
## trauma-based shake. Every effect is additive on top of a critically damped
## follow so control never fights the camera.

@export_group("Framing")
@export var distance := 16.0
@export var base_fov := 34.0
@export var height_offset := 2.35
## Shifts the frame sideways relative to the subject, so he can sit off-centre
## with the space he is heading into ahead of him.
@export var lateral_offset := 0.0
@export var follow_speed_x := 7.5
@export var follow_speed_y_grounded := 5.0
@export var follow_speed_y_air := 3.0

@export_group("Look-ahead")
@export var look_ahead := 3.1
@export var look_ahead_speed := 2.6
@export var look_ahead_vertical := 0.9

@export_group("Air")
## Vertical band, in world units, the target may move through before the camera
## follows. Keeps routine jumps from sloshing the frame.
@export var air_deadzone_up := 2.6
@export var air_deadzone_down := 1.9

@export_group("Feel")
@export var speed_fov_gain := 4.2
@export var dash_fov_gain := 3.0
@export var fov_speed := 4.0
@export var trauma_decay := 1.9
@export var max_shake_offset := 0.55
@export var max_shake_roll := 0.035

@export_group("Bounds")
@export var use_bounds := false
@export var bounds_min := Vector2(-1000, -1000)
@export var bounds_max := Vector2(1000, 1000)

var target: Node3D
var controller: PlayerController

var _focus := Vector2.ZERO          ## smoothed world focus point
var _look := Vector2.ZERO
var _anchor_y := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _impulse := Vector2.ZERO
var _impulse_vel := Vector2.ZERO
var _fov_offset := 0.0
var _zoom_punch := 0.0
var _zoom_punch_left := 0.0
var _zoom_punch_total := 0.0
var _zoom_punch_amount := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	# The 0.05 default wrecks depth precision, SSAO, SSR and contact shadows.
	near = 0.5
	far = 1400.0
	fov = base_fov
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.9
	FX.camera_impulse.connect(_on_impulse)
	FX.camera_zoom_punch.connect(_on_zoom_punch)


func bind(t: Node3D) -> void:
	target = t
	controller = t as PlayerController
	if controller:
		controller.landed.connect(_on_landed)
	snap_to_target()


func snap_to_target() -> void:
	if target == null:
		return
	_focus = Vector2(target.global_position.x, target.global_position.y + height_offset)
	_anchor_y = _focus.y
	_look = Vector2.ZERO
	global_position = Vector3(_focus.x, _focus.y, distance)
	look_at_target()


func look_at_target() -> void:
	rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if target == null:
		return
	delta = minf(delta, 1.0 / 20.0)

	var tp := target.global_position
	var vel := controller.velocity if controller else Vector3.ZERO
	var grounded: bool = controller.is_on_floor() if controller else true

	_update_look_ahead(delta, vel)
	_update_focus(delta, tp, grounded)
	_update_fov(delta, vel)
	_update_shake(delta)

	var pos := _focus + _look + _impulse
	if use_bounds:
		pos.x = clampf(pos.x, bounds_min.x, bounds_max.x)
		pos.y = clampf(pos.y, bounds_min.y, bounds_max.y)

	var shake := _shake_offset()
	global_position = Vector3(pos.x + shake.x, pos.y + shake.y, distance)
	rotation.z = shake.z


func _update_look_ahead(delta: float, vel: Vector3) -> void:
	var want := Vector2(
		clampf(vel.x / 9.2, -1.0, 1.0) * look_ahead,
		clampf(vel.y / 18.0, -1.0, 1.0) * look_ahead_vertical
	)
	# Look-ahead leads the player but eases in slowly, so a quick direction
	# change does not whip the frame.
	_look = _look.lerp(want, 1.0 - exp(-look_ahead_speed * delta))


func _update_focus(delta: float, tp: Vector3, grounded: bool) -> void:
	var want_x := tp.x + lateral_offset
	_focus.x = lerpf(_focus.x, want_x, 1.0 - exp(-follow_speed_x * delta))

	var want_y := tp.y + height_offset
	if grounded:
		_anchor_y = want_y
		_focus.y = lerpf(_focus.y, _anchor_y, 1.0 - exp(-follow_speed_y_grounded * delta))
	else:
		# Airborne: only chase once the player leaves the composition band.
		var over := want_y - (_anchor_y + air_deadzone_up)
		var under := (_anchor_y - air_deadzone_down) - want_y
		if over > 0.0:
			_anchor_y += over
		elif under > 0.0:
			_anchor_y -= under
		_focus.y = lerpf(_focus.y, _anchor_y, 1.0 - exp(-follow_speed_y_air * delta))


func _update_fov(delta: float, vel: Vector3) -> void:
	var speed_t := clampf(absf(vel.x) / 9.2, 0.0, 1.0)
	var want := speed_t * speed_fov_gain
	if controller and controller.is_dashing():
		want += dash_fov_gain
	_fov_offset = lerpf(_fov_offset, want, 1.0 - exp(-fov_speed * delta))

	if _zoom_punch_left > 0.0:
		_zoom_punch_left -= delta
		var t := clampf(_zoom_punch_left / maxf(_zoom_punch_total, 0.0001), 0.0, 1.0)
		_zoom_punch = _zoom_punch_amount * (t * t)
	else:
		_zoom_punch = lerpf(_zoom_punch, 0.0, 1.0 - exp(-8.0 * delta))

	fov = base_fov + _fov_offset + _zoom_punch


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	_shake_time += delta
	# Impulses are a spring, not a teleport: the frame gets shoved and recovers.
	_impulse_vel += (-_impulse * 320.0 - _impulse_vel * 26.0) * delta
	_impulse += _impulse_vel * delta


func _shake_offset() -> Vector3:
	if _trauma <= 0.0:
		return Vector3.ZERO
	var amount := _trauma * _trauma
	var t := _shake_time * 22.0
	return Vector3(
		_noise.get_noise_2d(t, 0.0) * max_shake_offset * amount,
		_noise.get_noise_2d(0.0, t) * max_shake_offset * amount,
		_noise.get_noise_2d(t, t) * max_shake_roll * amount
	)


func _on_impulse(offset: Vector2, trauma: float) -> void:
	_trauma = minf(_trauma + trauma, 1.0)
	_impulse_vel += offset * 6.0


func _on_zoom_punch(amount: float, duration: float) -> void:
	_zoom_punch_amount = amount
	_zoom_punch_total = duration
	_zoom_punch_left = duration


func _on_landed(impact: float) -> void:
	if impact < 0.12:
		return
	_impulse_vel += Vector2(0.0, -1.0) * impact * 5.5
	_trauma = minf(_trauma + impact * 0.35, 1.0)
