class_name PlayerController extends CharacterBody3D
## Wanis — the Libyan Gangsta.
##
## 2.5D character controller: simulation is locked to the X/Y plane, presentation
## is fully 3D. Everything here exists to serve *feel* — acceleration curves,
## coyote time, buffered and variable jumps, apex hang, corner correction and a
## momentum-preserving dash that chains into jumps.
##
## Tunables are grouped and exported so the whole kit can be re-feel'd without
## touching logic.

signal jumped(from_coyote: bool)
signal landed(impact: float)      ## 0..1, how hard the landing was
signal air_jumped(index: int)
signal fired()
signal weapon_ready_changed(ready: bool)
signal glide_changed(active: bool)
signal dash_started(charged: bool)
signal dash_ended()
signal footstep(speed_ratio: float)
signal turned(facing: int)
signal died()

enum State { IDLE, RUN, RISE, FALL, GLIDE, DASH, HURT, DEAD }

@export_group("Run")
@export var max_run_speed := 9.2
@export var ground_accel := 82.0
@export var ground_decel := 104.0
@export var turn_accel := 165.0
@export var air_accel := 54.0
@export var air_decel := 16.0
@export var air_turn_accel := 98.0
## Below this input magnitude the stick reads as neutral; above it the analog
## ramp is remapped to the full range so light stick pressure still feels sharp.
@export var input_deadzone := 0.2

@export_group("Jump")
@export var jump_height := 3.15
@export var jump_time_to_apex := 0.375
@export var fall_gravity_mult := 1.78
## Gravity is softened near the top of the arc — the "hang" that makes a jump
## read as generous without actually making it floaty.
@export var apex_gravity_mult := 0.62
@export var apex_threshold := 2.6
@export var jump_cut_mult := 0.42
@export var max_fall_speed := 34.0
@export var fast_fall_mult := 1.35
@export var coyote_time := 0.11
@export var jump_buffer := 0.13
## Horizontal boost applied on jump, so jumping out of a run feels committed.
@export var jump_horizontal_kick := 0.7
## Double jump. Refunded on landing, like the air dash.
@export var air_jumps := 1
@export var air_jump_mult := 0.92

@export_group("Glide")
## The thobe catches the wind. Hold jump while falling and the descent flattens
## out to a drift, with more lateral authority than a normal fall.
@export var glide_fall_speed := 3.4
@export var glide_ease := 34.0
@export var glide_accel := 40.0
@export var glide_max_speed := 7.4
## Must already be falling this fast before the robe can catch — otherwise a
## held jump would turn every hop into a float.
@export var glide_engage_speed := 1.4
@export var glide_spin_up := 0.16

@export_group("Dash")
@export var dash_speed := 23.0
@export var dash_time := 0.165
@export var dash_cooldown := 0.34
@export var dash_exit_speed := 12.5
@export var dash_gravity_scale := 0.0
@export var charged_dash_speed := 30.0
@export var charged_dash_time := 0.22
## Sriracha spent from the HEAT gauge for a Blaze Dash.
@export var charged_dash_cost := 30.0

@export_group("Rifle")
## Recoil is deliberately a movement tool: fired airborne it pushes him back
## hard enough to extend a jump backwards or stall a fall.
@export var recoil_air := 1.05
@export var recoil_ground := 0.20
@export var recoil_lift := 0.55
@export var weapon_raise_time := 0.14
## He keeps the rifle up for a moment after the trigger, so tapping does not
## strobe the pose.
@export var weapon_hold_time := 0.55

@export_group("World")
@export var plane_z := 0.0
@export var terminal_fall_y := -40.0

# --- Derived movement constants ---
var gravity: float
var jump_velocity: float

# --- Runtime state ---
var state: State = State.IDLE
var facing: int = 1
var move_input: float = 0.0
var want_jump_held: bool = false

var _coyote_left := 0.0
var _buffer_left := 0.0
var _dash_left := 0.0
var _dash_cd_left := 0.0
var _dash_dir := 1
var _dash_charged := false
var _air_dash_used := false
var _jump_cut_armed := false
var _air_jumps_left := 0
var _gliding := false
var _glide_blend := 0.0
var _was_on_floor := true
var _fall_peak_speed := 0.0
var _step_distance := 0.0
var _control_locked := 0.0
var _firing := false
var _weapon_up := 0.0
var rifle: Rifle

## Set false by cutscenes and the capture harness's scripted-input mode.
var accept_player_input := true


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.45
	floor_stop_on_slope = true
	_air_jumps_left = air_jumps
	slide_on_ceiling = true
	_recompute_jump()


func _recompute_jump() -> void:
	gravity = (2.0 * jump_height) / (jump_time_to_apex * jump_time_to_apex)
	jump_velocity = (2.0 * jump_height) / jump_time_to_apex


# --- Input ------------------------------------------------------------------

func _gather_input() -> void:
	if not accept_player_input:
		return
	var raw := Input.get_axis("move_left", "move_right")
	move_input = _apply_deadzone(raw)
	want_jump_held = Input.is_action_pressed("jump")
	if Input.is_action_just_pressed("jump"):
		_buffer_left = jump_buffer
		_try_air_jump()
	if Input.is_action_just_released("jump"):
		_jump_cut_armed = true
	if Input.is_action_just_pressed("dash"):
		_try_dash()
	_firing = Input.is_action_pressed("attack")


func _apply_deadzone(raw: float) -> float:
	var mag := absf(raw)
	if mag < input_deadzone:
		return 0.0
	var remapped := (mag - input_deadzone) / (1.0 - input_deadzone)
	return signf(raw) * minf(remapped, 1.0)


## Used by the capture harness and cutscenes to drive the character directly.
func set_scripted_input(axis: float, jump_held: bool) -> void:
	move_input = _apply_deadzone(axis)
	want_jump_held = jump_held


func scripted_jump() -> void:
	_buffer_left = jump_buffer
	_try_air_jump()


func scripted_jump_release() -> void:
	_jump_cut_armed = true


func scripted_dash() -> void:
	_try_dash()


func set_scripted_fire(held: bool) -> void:
	_firing = held


# --- Physics ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_gather_input()
	_tick_timers(delta)

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_on_land()
	elif not on_floor and _was_on_floor and state != State.RISE:
		# Walked off a ledge — coyote applies. Jumping off does not re-arm it.
		_coyote_left = coyote_time

	match state:
		State.DASH:
			_physics_dash(delta)
		_:
			_physics_normal(delta, on_floor)

	_update_weapon(delta)
	_was_on_floor = on_floor
	_apply_plane_lock()
	move_and_slide()
	_apply_plane_lock()
	_post_move(delta)


func _update_weapon(delta: float) -> void:
	if rifle == null:
		return
	var want := _firing and state != State.DEAD
	var before := _weapon_up > 0.0
	if want:
		_weapon_up = weapon_hold_time
	else:
		_weapon_up = maxf(_weapon_up - delta, 0.0)
	if before != (_weapon_up > 0.0):
		weapon_ready_changed.emit(_weapon_up > 0.0)

	if not want:
		return
	var grounded := is_on_floor()
	if rifle.try_fire(facing, grounded):
		var kick: float = recoil_ground if grounded else recoil_air
		velocity.x -= facing * kick
		if not grounded and velocity.y < 2.0:
			velocity.y += recoil_lift
		FX.shake(0.10 if grounded else 0.14, Vector2(-facing * 0.9, 0.25))
		Audio.play_shot(rifle.muzzle.global_position)
		Audio.play("shell", global_position, -14.0, randf_range(0.9, 1.15))
		fired.emit()


func _tick_timers(delta: float) -> void:
	_coyote_left = maxf(_coyote_left - delta, 0.0)
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	_dash_cd_left = maxf(_dash_cd_left - delta, 0.0)
	_control_locked = maxf(_control_locked - delta, 0.0)


func _physics_normal(delta: float, on_floor: bool) -> void:
	_apply_horizontal(delta, on_floor)
	_apply_gravity(delta, on_floor)
	_try_consume_jump(on_floor)
	_update_locomotion_state(on_floor)


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	var target := move_input * max_run_speed
	var vx := velocity.x
	var accel: float

	if _gliding:
		target = move_input * glide_max_speed
		velocity.x = move_toward(vx, target, glide_accel * delta)
		if not is_zero_approx(move_input):
			var want_g := int(signf(move_input))
			if want_g != facing:
				facing = want_g
				turned.emit(facing)
		return

	if _control_locked > 0.0:
		accel = air_decel
	elif is_zero_approx(move_input):
		accel = ground_decel if on_floor else air_decel
	elif signf(move_input) != signf(vx) and not is_zero_approx(vx):
		accel = turn_accel if on_floor else air_turn_accel
	else:
		accel = ground_accel if on_floor else air_accel

	velocity.x = move_toward(vx, target, accel * delta)

	if not is_zero_approx(move_input) and _control_locked <= 0.0:
		var want := int(signf(move_input))
		if want != facing:
			facing = want
			turned.emit(facing)


func _apply_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
		# A small downward bias keeps the body glued through slope transitions.
		velocity.y = minf(velocity.y, 0.0) - 0.1
		_set_gliding(false)
		return

	if _update_glide(delta):
		return

	var g := gravity
	if velocity.y < 0.0:
		g *= fall_gravity_mult
		if move_input != 0.0 and Input.is_action_pressed("move_down") and accept_player_input:
			g *= fast_fall_mult
	elif not want_jump_held and _jump_cut_armed:
		g *= fall_gravity_mult

	if absf(velocity.y) < apex_threshold:
		g *= apex_gravity_mult

	velocity.y = maxf(velocity.y - g * delta, -max_fall_speed)


## True while the robe is carrying him, in which case it owns vertical motion.
func _update_glide(delta: float) -> bool:
	var want := want_jump_held and velocity.y < -glide_engage_speed and state != State.DASH
	_set_gliding(want)
	if not _gliding:
		_glide_blend = maxf(_glide_blend - delta / glide_spin_up, 0.0)
		return false

	# Ease into the drift rather than snapping — the robe has to fill first.
	_glide_blend = minf(_glide_blend + delta / glide_spin_up, 1.0)
	var target := -lerpf(maxf(-velocity.y, glide_fall_speed), glide_fall_speed, _glide_blend)
	velocity.y = move_toward(velocity.y, target, glide_ease * delta)
	return true


func _set_gliding(value: bool) -> void:
	if _gliding == value:
		return
	_gliding = value
	glide_changed.emit(value)


func _try_air_jump() -> void:
	if is_on_floor() or _coyote_left > 0.0 or state == State.DASH or state == State.DEAD:
		return
	if _air_jumps_left <= 0:
		return
	_air_jumps_left -= 1
	_buffer_left = 0.0
	_jump_cut_armed = false
	_set_gliding(false)
	_glide_blend = 0.0
	velocity.y = jump_velocity * air_jump_mult
	if not is_zero_approx(move_input):
		velocity.x += move_input * jump_horizontal_kick
		velocity.x = clampf(velocity.x, -max_run_speed * 1.45, max_run_speed * 1.45)
	state = State.RISE
	Audio.play("air_jump", global_position, -4.0, randf_range(0.98, 1.04))
	air_jumped.emit(air_jumps - _air_jumps_left)


func _try_consume_jump(on_floor: bool) -> void:
	if _buffer_left <= 0.0:
		return
	var grounded := on_floor or _coyote_left > 0.0
	if not grounded:
		return

	var from_coyote := not on_floor
	_buffer_left = 0.0
	_coyote_left = 0.0
	_jump_cut_armed = false
	_air_dash_used = false
	_air_jumps_left = air_jumps
	velocity.y = jump_velocity
	if not is_zero_approx(move_input):
		velocity.x += move_input * jump_horizontal_kick
		velocity.x = clampf(velocity.x, -max_run_speed * 1.45, max_run_speed * 1.45)
	state = State.RISE
	Audio.play("jump", global_position, -4.0, randf_range(0.97, 1.05))
	jumped.emit(from_coyote)


func _update_locomotion_state(on_floor: bool) -> void:
	# A jump consumed this frame already set RISE off a still-true on_floor
	# reading; don't let the ground branch stomp it.
	if velocity.y > 0.01:
		state = State.RISE
		return
	if on_floor:
		state = State.IDLE if absf(velocity.x) < 0.35 else State.RUN
	elif _gliding:
		state = State.GLIDE
	else:
		state = State.RISE if velocity.y > 0.0 else State.FALL
	if velocity.y < 0.0:
		_fall_peak_speed = maxf(_fall_peak_speed, -velocity.y)


# --- Jump cut ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not accept_player_input:
		return
	if event.is_action_released("jump") and velocity.y > 0.0 and state == State.RISE:
		velocity.y *= jump_cut_mult


# --- Dash -------------------------------------------------------------------

func _try_dash() -> void:
	if state == State.DASH or state == State.DEAD or _dash_cd_left > 0.0:
		return
	if not is_on_floor() and _air_dash_used:
		return

	_dash_charged = Gx.heat_ratio() >= 1.0 and Gx.spend_heat(charged_dash_cost)
	_dash_dir = facing if is_zero_approx(move_input) else int(signf(move_input))
	facing = _dash_dir
	_dash_left = charged_dash_time if _dash_charged else dash_time
	if not is_on_floor():
		_air_dash_used = true
	state = State.DASH
	Audio.play("dash_charged" if _dash_charged else "dash", global_position, -2.0)
	dash_started.emit(_dash_charged)


func _physics_dash(delta: float) -> void:
	var speed := charged_dash_speed if _dash_charged else dash_speed
	velocity.x = _dash_dir * speed
	velocity.y = lerpf(velocity.y, 0.0, 1.0 - exp(-24.0 * delta))
	velocity.y -= gravity * dash_gravity_scale * delta

	_dash_left -= delta

	# Dash-jump cancel: buffered jump during a dash exits early and keeps speed.
	if _buffer_left > 0.0 and (is_on_floor() or _coyote_left > 0.0):
		_end_dash(true)
		_try_consume_jump(is_on_floor())
		return

	if _dash_left <= 0.0:
		_end_dash(false)


func _end_dash(keep_speed: bool) -> void:
	state = State.FALL
	_dash_cd_left = dash_cooldown
	if not keep_speed:
		velocity.x = _dash_dir * maxf(dash_exit_speed, absf(velocity.x) * 0.55)
	_dash_charged = false
	dash_ended.emit()


# --- Landing, plane lock, housekeeping --------------------------------------

func _on_land() -> void:
	var impact := clampf(_fall_peak_speed / max_fall_speed, 0.0, 1.0)
	_fall_peak_speed = 0.0
	_air_dash_used = false
	_air_jumps_left = air_jumps
	_jump_cut_armed = false
	_set_gliding(false)
	_glide_blend = 0.0
	Audio.play_land(global_position, impact)
	landed.emit(impact)
	if impact > 0.45:
		FX.hitstop(lerpf(0.0, 0.055, inverse_lerp(0.45, 1.0, impact)))
		FX.shake(impact * 0.45, Vector2(0.0, -1.0))


func _apply_plane_lock() -> void:
	velocity.z = 0.0
	global_position.z = plane_z


func _post_move(delta: float) -> void:
	_corner_correct()
	_accumulate_steps(delta)
	if global_position.y < terminal_fall_y:
		kill()


## Nudge the body sideways when a rising jump clips a ledge corner by a hair.
## Without this, "I definitely cleared that" jumps stop dead against a lip.
func _corner_correct() -> void:
	if velocity.y <= 0.0 or not is_on_ceiling():
		return
	for nudge in [0.22, -0.22, 0.34, -0.34]:
		var offset := Vector3(nudge, 0.0, 0.0)
		if not test_move(global_transform.translated(offset), Vector3(0.0, 0.1, 0.0)):
			global_position += offset
			return
	velocity.y = 0.0


func _accumulate_steps(delta: float) -> void:
	if not is_on_floor() or state == State.DASH:
		return
	var speed := absf(velocity.x)
	if speed < 0.6:
		_step_distance = 0.0
		return
	_step_distance += speed * delta
	if _step_distance >= 1.55:
		_step_distance = 0.0
		Audio.play_footstep(global_position, surface_under_foot(), speed / max_run_speed)
		footstep.emit(speed / max_run_speed)


# --- Damage / death ---------------------------------------------------------

func kill() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	Audio.play("hurt", global_position, -1.0)
	Audio.reset_combo()
	died.emit()


# --- Queries used by camera, rig, HUD ---------------------------------------

## Surface-aware footsteps: the collider under his feet names its own material
## via a group, so a level can change how the ground sounds by tagging it.
func surface_under_foot() -> String:
	if get_slide_collision_count() == 0:
		return "concrete"
	var col := get_slide_collision(0).get_collider()
	if col is Node:
		for s: String in ["sand", "metal", "wood"]:
			if (col as Node).is_in_group("surface_" + s):
				return s
	return "concrete"


func speed_ratio() -> float:
	return clampf(absf(velocity.x) / max_run_speed, 0.0, 1.0)


func is_dashing() -> bool:
	return state == State.DASH


func is_airborne() -> bool:
	return state == State.RISE or state == State.FALL or state == State.GLIDE


## 0..1 — how far the rifle is up. Drives the arm pose and the HUD.
func weapon_blend() -> float:
	return clampf(_weapon_up / maxf(weapon_hold_time, 0.001), 0.0, 1.0)


func is_firing() -> bool:
	return _firing


func is_gliding() -> bool:
	return _gliding


func glide_blend() -> float:
	return _glide_blend


func air_jumps_left() -> int:
	return _air_jumps_left
