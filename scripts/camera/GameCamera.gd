class_name GameCamera extends Camera3D
## The expensive-feeling camera.
##
## Side-on 2.5D framing. Gameplay lives on the XY plane at z = 0; this camera
## sits at z ≈ +16 looking straight down -Z with a 34° FOV and never rotates
## (except a few thousandths of a radian of shake roll). Verticals stay vertical
## and background parallax stays honest, which is the whole reason the game is
## built in 3D.
##
## THE MODEL, in the order it is composed each frame:
##
##   focus   the damped follow — *where he is*. One asymmetric exponential on X
##           over a soft dead zone, one spring on Y over a grounded reference.
##   lead    the eased framing offset — *how we frame him*. Velocity lead,
##           rule-of-thirds bias, vertical fall/rise lead, glide drop, aim lift,
##           dash flick. All of it resolves to ZERO when he is parked.
##   impulse a second spring, driven by landings and FX hits. Shoves the frame
##           and recovers; never teleports it.
##   shake   trauma² noise. Decaying, band-limited, accessibility-scaled.
##   dolly   z movement. Speed, dash, glide, firing and damage change the
##           stand-off instead of the FOV wherever possible, because FOV
##           distorts the hero and a dolly does not.
##
## Two invariants hold everything together:
##
##   1. AT REST the whole rig collapses to the old, hand-tuned composition:
##      x = subject.x + lateral_offset, y = ground + height_offset,
##      z = distance, fov = base_fov. Every dynamic term is gated by motion, so
##      a parked camera (beauty shots, character lab, title screen) is exactly
##      where the art direction put it, to well under a pixel.
##   2. EVERYTHING IS DELTA-DRIVEN AND SEEDED. No randf, no wall clock. The
##      capture harness runs a fixed 1/60 timestep and gets the same frame every
##      time. The springs substep at a fixed 1/120 so a 30 fps machine and a
##      60 fps machine trace the same curve.
##
## Levels may write any exported property directly, or pass a dictionary to
## `apply_framing()` / a name to `apply_preset()` — see PRESETS at the bottom.
## Nothing here runs in _physics_process, and everything is written from
## _process, so `set_process(false)` followed by a manual `global_position` /
## `fov` write (the beauty-shot and cutscene override) always wins.

@export_group("Framing")
## Stand-off on Z. The canon value is 16: with a 34° FOV that shows 9.78 world
## units of height, which makes a 1.78 m Wanis 18.2% of frame height.
@export var distance := 16.0
@export var base_fov := 34.0
## Camera above the subject, so he sits below centre with headroom. Gameplay
## uses ~2.2; beauty framing drops to ~1.25 to lift the horizon.
@export var height_offset := 2.35
## Static sideways bias. Positive pushes the camera right, so HE sits left of
## centre with the space he is heading into ahead of him. Levels set this by
## eye; the dynamic lead below stacks on top of it.
@export var lateral_offset := 0.0

@export_group("Follow")
## Catching up is faster than falling behind. When he is outrunning the frame
## (error and velocity share a sign) the camera closes at `catch`; when he turns
## and runs back through the centre it holds at `settle` instead of whipping
## after him. That asymmetry is most of what separates a camera that feels
## authored from one that feels attached with a rubber band.
@export var follow_x_catch := 9.0       ## ~0.11 s to close 63% of the error
@export var follow_x_settle := 4.2      ## ~0.24 s — deliberately lazy on turns
## Used when he is standing still: the frame stops oozing and locks composition.
@export var follow_x_still := 12.0
## Soft dead zone, world units. Inside it the response is knee'd down, not
## switched off, so the camera never lurches when the subject crosses the edge.
## Kills the micro-wobble that acceleration and deceleration put in the frame.
@export var deadzone_x := 0.35
## Vertical is a spring, not a lerp, because a spring can *settle* — it arrives
## with a trace of weight instead of asymptoting into place. Values are angular
## frequencies (rad/s): higher = stiffer.
@export var vertical_spring_ground := 6.4
@export var vertical_spring_air := 4.4
## Stiffens as he falls, or a 34 u/s death plunge leaves him off the bottom of
## the frame: lag ≈ fall_speed / frequency.
@export var vertical_spring_fall := 12.0
@export var vertical_spring_still := 11.0
## 1.0 is critically damped. 0.9 gives ~1.5% overshoot — one soft dip past the
## mark on a landing, which reads as mass. Anything under 0.8 bounces.
@export var vertical_damping := 0.9

@export_group("Look-ahead")
## Lead at full run speed, world units. 3.1 puts roughly a third of a second of
## travel ahead of him.
@export var look_ahead := 3.1
## Lead arrives LATE on purpose: exponent > 1 means a walk barely moves the
## frame and a sprint moves it a lot.
@export var look_ahead_curve := 1.5
@export var look_ahead_speed := 3.2         ## swinging further out, ~0.3 s
## Swinging ACROSS on a turn is slower, so a direction change reads as a lean,
## not a snap. ~0.6 s to cross.
@export var look_ahead_turn_speed := 1.7
## Recentring when he stops. Fast, so the frame composes on him promptly.
@export var look_ahead_still_speed := 7.0
@export var look_ahead_vertical := 0.9
## Falling wants to see the floor: lead down hard. Rising wants to HOLD, or
## every hop pumps the frame.
@export var fall_lead_mult := 2.0
@export var rise_lead_mult := 0.25
## Optional rule-of-thirds bias, world units, signed by direction of travel.
## Separate from `look_ahead` because it is composition, not anticipation: it
## saturates at a walk while the velocity lead is still ramping. Eases across on
## a turn with the rest of the lead. Zero at a standstill, always.
@export var thirds_bias := 0.35
## Hard ceiling on the sum of lead + bias + dash flick, so no combination can
## shove him to the frame edge.
@export var max_lead_x := 4.6

@export_group("Air")
## Vertical band, world units, the subject may move through before the camera
## reference follows. Routine jumps happen inside it and never touch the frame.
@export var air_deadzone_up := 2.6
@export var air_deadzone_down := 1.9

@export_group("State framing")
## Glide is about the distance ahead: lead further, sit him a little lower in
## frame, and widen the stand-off.
@export var glide_lead_mult := 1.5
@export var glide_drop := 0.5
@export var glide_dolly := 0.9
## Dash: a short pull-back and a flick of lead in the dash direction. The flick
## snaps out in ~55 ms and takes ~0.35 s to come home, which is what sells the
## dash as an event rather than a speed change.
@export var dash_dolly := 1.15
@export var dash_lead_flick := 1.2
@export var dash_flick_attack := 18.0
@export var dash_flick_decay := 4.5
## Firing pushes in slightly — the frame tightens around the act.
@export var fire_dolly := -0.5
## And lifts toward what he is aiming at, so a steep shot has its target on
## screen. Only while the rifle is up.
@export var aim_lead := 0.8
## Damage: a brief tighten under the shake. Hard in, off in ~0.3 s.
@export var hurt_dolly := -0.9
@export var hurt_release := 3.4
## Death eases the other way — the world opens up and leaves him in it.
@export var death_dolly := 1.4

@export_group("Feel")
## Speed zoom is split: most of it is now a dolly (no lens distortion on the
## hero, correct parallax response), with a little FOV left in for the widening
## sensation at the frame edges.
@export var speed_fov_gain := 1.8
@export var speed_dolly := 1.1
@export var dash_fov_gain := 1.1
@export var fov_speed := 4.0
@export var dolly_speed := 5.0
@export var trauma_decay := 1.9
@export var max_shake_offset := 0.55
@export var max_shake_roll := 0.035
@export var shake_frequency := 22.0

@export_group("Bounds")
@export var use_bounds := false
@export var bounds_min := Vector2(-1000, -1000)
@export var bounds_max := Vector2(1000, 1000)

var target: Node3D
var controller: PlayerController

var _focus := Vector2.ZERO           ## smoothed world focus point
var _focus_vel_y := 0.0              ## vertical spring velocity
var _ground_ref := 0.0               ## the floor the frame composes to
var _lead := Vector2.ZERO            ## eased framing offset (before the dash flick)
var _move_gate := 0.0                ## 0 parked, 1 moving. Gates every dynamic term
var _flick_env := 0.0                ## dash envelope
var _flick_dir := 1.0
var _glide_env := 0.0
var _fire_env := 0.0
var _hurt_env := 0.0
var _death_env := 0.0
var _dolly := 0.0
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

## Springs integrate at a fixed step so the trajectory is identical at 30, 60 or
## 144 fps and under the capture harness.
const SPRING_STEP := 1.0 / 120.0
const MAX_SPRING_STEPS := 8


func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	# The 0.05 default wrecks depth precision, SSAO, SSR and contact shadows.
	near = 0.5
	far = 1400.0
	fov = base_fov
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.9
	_noise.seed = 1911   ## fixed: shake must replay identically in captures
	FX.camera_impulse.connect(_on_impulse)
	FX.camera_zoom_punch.connect(_on_zoom_punch)


func bind(t: Node3D) -> void:
	target = t
	controller = t as PlayerController
	if controller:
		# Guarded because a respawn rebinds, and a level could bind twice.
		if not controller.landed.is_connected(_on_landed):
			controller.landed.connect(_on_landed)
		if not controller.hit.is_connected(_on_hit):
			controller.hit.connect(_on_hit)
		if not controller.died.is_connected(_on_died):
			controller.died.connect(_on_died)
	snap_to_target()


## Hard cut to the composed rest pose. Everything dynamic is zeroed — a respawn
## must not inherit the trauma, lead or dolly of the death that caused it.
func snap_to_target() -> void:
	if target == null:
		return
	_ground_ref = target.global_position.y
	_focus = Vector2(target.global_position.x + lateral_offset, _ground_ref + height_offset)
	_focus_vel_y = 0.0
	_lead = Vector2.ZERO
	_move_gate = 0.0
	_flick_env = 0.0
	_glide_env = 0.0
	_fire_env = 0.0
	_hurt_env = 0.0
	_death_env = 0.0
	_dolly = 0.0
	_impulse = Vector2.ZERO
	_impulse_vel = Vector2.ZERO
	_trauma = 0.0
	_fov_offset = 0.0
	_zoom_punch = 0.0
	_zoom_punch_left = 0.0
	global_position = Vector3(_focus.x, _focus.y, distance)
	fov = base_fov
	look_at_target()


func look_at_target() -> void:
	rotation = Vector3.ZERO


# --- Level-facing API -------------------------------------------------------

## One entry point for per-level framing, so levels do not have to know which
## group a knob lives in and the camera does not grow a setter per feature:
##
##   camera.apply_framing({"look_ahead": 4.2, "thirds_bias": 0.6})
##
## Unknown keys are a warning, not a crash — a typo in a level should not take
## the level down.
func apply_framing(hints: Dictionary) -> void:
	for key: Variant in hints:
		var prop := str(key)
		if prop in self:
			set(prop, hints[key])
		else:
			push_warning("GameCamera: unknown framing hint '%s'" % prop)


## Named starting points, so a level author can say what kind of camera this is
## and then adjust one or two numbers.
func apply_preset(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		push_warning("GameCamera: unknown framing preset '%s'" % preset_name)
		return
	apply_framing(PRESETS[preset_name])


# --- Frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# A long hitch must not let the springs take a giant step; it would read as
	# a jump cut. Clamping loses a little tracking, which nobody sees.
	delta = minf(delta, 1.0 / 20.0)

	var tp := target.global_position
	var vel := controller.velocity if controller else Vector3.ZERO
	var grounded: bool = controller.is_on_floor() if controller else true

	_update_gates(delta, vel, grounded)
	_update_lead(delta, vel)
	_update_reference(tp, vel, grounded)
	_update_focus(delta, tp, vel)
	_update_lens(delta, vel)
	_integrate_springs(delta)
	_decay_trauma(delta)

	# The dash flick is applied here rather than eased into `_lead`, so it keeps
	# its snap instead of being smeared out by the lead easing — and so it
	# cannot integrate into the lead and compound frame over frame.
	var look := _lead
	look.x = clampf(look.x + _flick_env * dash_lead_flick * _flick_dir,
		-max_lead_x, max_lead_x)

	var pos := _focus + look + _impulse
	if use_bounds:
		pos.x = clampf(pos.x, bounds_min.x, bounds_max.x)
		pos.y = clampf(pos.y, bounds_min.y, bounds_max.y)

	# Shake is applied outside the bounds clamp on purpose: clamping it would
	# make the shake one-sided against a level edge, which looks like a bug.
	var shake := _shake_offset()
	global_position = Vector3(pos.x + shake.x, pos.y + shake.y, distance + _dolly)
	rotation.z = shake.z


## Motion gate plus the state envelopes. Every dynamic framing term is scaled by
## one of these, which is how the rig guarantees it collapses to the authored
## rest pose when nothing is happening.
func _update_gates(delta: float, vel: Vector3, grounded: bool) -> void:
	var moving := not grounded or absf(vel.x) > 0.55 or absf(vel.y) > 0.6
	# Into motion quickly (the frame must not lag the first step), out of it
	# more gently (a momentary stop mid-run should not slam the rig into lock-up).
	var gate_rate := 6.0 if moving else 3.0
	_move_gate = lerpf(_move_gate, 1.0 if moving else 0.0, 1.0 - exp(-gate_rate * delta))

	var dashing: bool = controller.is_dashing() if controller else false
	var gliding: bool = controller.is_gliding() if controller else false
	var firing: bool = controller.is_firing() if controller else false

	if dashing:
		_flick_dir = float(controller.facing)
	var flick_rate := dash_flick_attack if dashing else dash_flick_decay
	_flick_env = lerpf(_flick_env, 1.0 if dashing else 0.0, 1.0 - exp(-flick_rate * delta))
	_glide_env = lerpf(_glide_env, 1.0 if gliding else 0.0, 1.0 - exp(-5.0 * delta))
	_fire_env = lerpf(_fire_env, 1.0 if firing else 0.0, 1.0 - exp(-7.0 * delta))
	_hurt_env = maxf(_hurt_env - hurt_release * delta, 0.0)
	if _death_env > 0.0 or (controller and controller.state == PlayerController.State.DEAD):
		_death_env = lerpf(_death_env, 1.0, 1.0 - exp(-1.6 * delta))


## Anticipation. Lead the direction of TRAVEL (not facing — facing flips a frame
## before the body does, and the frame should follow the body), harder at speed
## and harder again on a glide.
func _update_lead(delta: float, vel: Vector3) -> void:
	var sr: float = controller.speed_ratio() if controller else 0.0
	var dir := 0.0
	if absf(vel.x) > 0.35:
		dir = signf(vel.x)

	# Velocity lead, late-arriving. Bias saturates earlier — it is composition,
	# not prediction, so a walk is already framed off-centre.
	var lead := look_ahead * pow(sr, look_ahead_curve)
	var bias := thirds_bias * smoothstep(0.12, 0.55, sr)
	var want_x := dir * (lead + bias)
	if _glide_env > 0.0:
		want_x = lerpf(want_x, want_x * glide_lead_mult, _glide_env)
	want_x = clampf(want_x, -max_lead_x, max_lead_x)

	# Vertical: falling opens the floor up, rising holds. The glide suppresses
	# the fall lead and substitutes its own framing, because a glide is a
	# controlled traverse, not a drop.
	var want_y := 0.0
	if vel.y < 0.0:
		var fall_t := clampf(-vel.y / 18.0, 0.0, 1.0)
		want_y = -look_ahead_vertical * fall_lead_mult * (fall_t * fall_t) * (1.0 - _glide_env)
	else:
		want_y = look_ahead_vertical * rise_lead_mult * clampf(vel.y / 12.0, 0.0, 1.0)
	want_y += glide_drop * _glide_env
	if controller:
		want_y += aim_lead * controller.aim() * _fire_env

	# Three rates: swinging out, swinging across (slow — this is the turn), and
	# coming home when he parks (fast, so composition settles).
	var rate_x := look_ahead_speed
	if want_x * _lead.x < -0.0001:
		rate_x = look_ahead_turn_speed
	rate_x = lerpf(look_ahead_still_speed, rate_x, _move_gate)
	_lead.x = lerpf(_lead.x, want_x, 1.0 - exp(-rate_x * delta))
	var rate_y := lerpf(look_ahead_still_speed, 4.0, _move_gate)
	_lead.y = lerpf(_lead.y, want_y, 1.0 - exp(-rate_y * delta))


## The grounded reference: the floor the camera composes to, rather than the
## subject's own Y. Without it the frame rides every jump arc and the horizon
## pumps up and down all level.
func _update_reference(tp: Vector3, vel: Vector3, grounded: bool) -> void:
	if grounded:
		# Instant on touchdown — the spring is the smoothing, and it is what
		# gives the landing a settle instead of a snap.
		_ground_ref = tp.y
		return

	# Airborne: the reference only moves when he leaves the composition band.
	# The downward half of the band tightens as he falls, so a long drop picks
	# him up early instead of letting him run off the bottom of the frame.
	var fall_t := clampf(-vel.y / 18.0, 0.0, 1.0)
	var band_down := lerpf(air_deadzone_down, air_deadzone_down * 0.45, fall_t)
	if tp.y > _ground_ref + air_deadzone_up:
		_ground_ref = tp.y - air_deadzone_up
	elif tp.y < _ground_ref - band_down:
		_ground_ref = tp.y + band_down


func _update_focus(delta: float, tp: Vector3, vel: Vector3) -> void:
	var want_x := tp.x + lateral_offset
	var err := want_x - _focus.x

	# Asymmetric response: closing on a subject that is running away is fast,
	# following one that is coming back at you is slow.
	var chasing := (err > 0.0 and vel.x > 0.0) or (err < 0.0 and vel.x < 0.0)
	var rate := follow_x_catch if chasing else follow_x_settle
	rate = lerpf(follow_x_still, rate, _move_gate)

	# Soft-knee dead zone. The zone itself shrinks as he slows, so a parked
	# camera has no dead zone at all and lands exactly on composition.
	var zone := deadzone_x * _move_gate
	if zone > 0.0001:
		var t := clampf(absf(err) / zone, 0.0, 1.0)
		rate *= clampf(t * t, 0.08, 1.0)
	_focus.x = lerpf(_focus.x, want_x, 1.0 - exp(-rate * delta))


func _update_lens(delta: float, vel: Vector3) -> void:
	var sr := clampf(absf(vel.x) / _max_speed(), 0.0, 1.0)
	var speed_t := sr * sr   ## late, like the lead — a jog should not zoom

	var want_fov := speed_t * speed_fov_gain
	if controller and controller.is_dashing():
		want_fov += dash_fov_gain
	_fov_offset = lerpf(_fov_offset, want_fov, 1.0 - exp(-fov_speed * delta))

	# Depth does the heavy lifting. Positive = pull back.
	var want_dolly := speed_t * speed_dolly
	want_dolly += dash_dolly * _flick_env
	want_dolly += glide_dolly * _glide_env
	want_dolly += fire_dolly * _fire_env
	want_dolly += hurt_dolly * _hurt_env
	want_dolly += death_dolly * _death_env
	want_dolly = clampf(want_dolly, -2.0, 2.5)
	# Expressed against the canon 16 m stand-off, so a 4 m character-lab camera
	# gets a proportional move and not a gameplay-sized one.
	want_dolly *= distance / 16.0
	_dolly = lerpf(_dolly, want_dolly, 1.0 - exp(-dolly_speed * delta))

	if _zoom_punch_left > 0.0:
		_zoom_punch_left -= delta
		var t := clampf(_zoom_punch_left / maxf(_zoom_punch_total, 0.0001), 0.0, 1.0)
		_zoom_punch = _zoom_punch_amount * (t * t)
	else:
		_zoom_punch = lerpf(_zoom_punch, 0.0, 1.0 - exp(-8.0 * delta))

	fov = base_fov + _fov_offset + _zoom_punch


func _max_speed() -> float:
	return controller.max_run_speed if controller else 9.2


## Vertical follow and the impulse recoil, both springs, both substepped at a
## fixed rate so the motion is identical on any machine and in any capture.
func _integrate_springs(delta: float) -> void:
	var grounded: bool = controller.is_on_floor() if controller else true
	var vy: float = controller.velocity.y if controller else 0.0
	var fall_t := clampf(-vy / 18.0, 0.0, 1.0)

	var w: float
	if grounded:
		w = lerpf(vertical_spring_still, vertical_spring_ground, _move_gate)
	else:
		# Stiffen with fall speed: lag ≈ speed / w, and a terminal fall at the
		# airborne frequency would put him below the bottom edge.
		w = lerpf(vertical_spring_air, vertical_spring_fall, fall_t)
	var k := w * w
	var c := 2.0 * vertical_damping * w
	var target_y := _ground_ref + height_offset

	var steps := clampi(int(ceil(delta / SPRING_STEP)), 1, MAX_SPRING_STEPS)
	var h := delta / float(steps)
	for _i in steps:
		_focus_vel_y += (k * (target_y - _focus.y) - c * _focus_vel_y) * h
		_focus.y += _focus_vel_y * h
		# Impulse spring: stiff and slightly underdamped, so a hit shoves the
		# frame and it comes back in about a quarter of a second.
		_impulse_vel += (-_impulse * 320.0 - _impulse_vel * 26.0) * h
		_impulse += _impulse_vel * h


# --- Shake ------------------------------------------------------------------

func _decay_trauma(delta: float) -> void:
	# Decay accelerates with trauma: a big hit clears out fast and a small one
	# tapers, so shake never outstays the event that caused it.
	_trauma = maxf(_trauma - trauma_decay * (0.45 + _trauma) * delta, 0.0)
	_shake_time += delta


## Trauma-squared, noise-driven, two bands. Squaring is what makes a 0.3 knock a
## nudge and a 1.0 hit violent. Simplex instead of random keeps it a shaken
## camera rather than white-noise jitter, and it is seeded, so captures replay.
func _shake_offset() -> Vector3:
	if _trauma <= 0.0001:
		return Vector3.ZERO
	var amount := _trauma * _trauma
	var fast := _shake_time * shake_frequency
	var slow := _shake_time * shake_frequency * 0.34   ## the operator recovering
	# Separate rows of the noise field: decorrelated axes, one noise object.
	var x := _noise.get_noise_2d(fast, 0.0) * 0.75 + _noise.get_noise_2d(slow, 53.0) * 0.25
	var y := _noise.get_noise_2d(fast, 137.0) * 0.75 + _noise.get_noise_2d(slow, 191.0) * 0.25
	var r := _noise.get_noise_2d(fast, 311.0)
	return Vector3(x * max_shake_offset * amount,
		y * max_shake_offset * amount,
		r * max_shake_roll * amount)


# --- Events -----------------------------------------------------------------

## FXDirector has already scaled both arguments by the screen-shake
## accessibility setting, so nothing here needs to check it again.
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
	# This one comes straight off the controller, bypassing FXDirector, so it
	# has to respect the accessibility setting itself. The downward shove stays
	# at full strength either way — it is framing, not shake.
	var shake_scale: float = Gx.get_setting("screen_shake", 1.0)
	_impulse_vel += Vector2(0.0, -1.0) * impact * 5.5
	_trauma = minf(_trauma + impact * 0.35 * shake_scale, 1.0)


## The hard shake on a hit already arrives through FXDirector (and therefore
## through the accessibility slider). All the camera adds is the tighten.
func _on_hit(_from: Vector3) -> void:
	_hurt_env = 1.0


func _on_died() -> void:
	_death_env = maxf(_death_env, 0.0001)   ## arms the slow pull-back


# --- Presets ----------------------------------------------------------------
#
# Starting points for `apply_preset()`. Keys are plain property names, so a
# level can take one and then override a single number.

const PRESETS := {
	# Standard on-foot platforming. These are the exported defaults.
	"gameplay": {},

	# Character / enemy lab and other close stands: no prediction, no zoom,
	# nothing that moves the frame while a silhouette is being judged.
	"tight": {
		"look_ahead": 0.0,
		"thirds_bias": 0.0,
		"speed_fov_gain": 0.0,
		"speed_dolly": 0.0,
		"dash_dolly": 0.0,
		"glide_dolly": 0.0,
	},

	# Long, fast, horizontal sections — the highway. Lead hard, stop reacting to
	# small vertical changes, and let the stand-off carry the speed sensation.
	"vehicle": {
		"look_ahead": 5.2,
		"look_ahead_curve": 1.2,
		"thirds_bias": 0.8,
		"max_lead_x": 6.5,
		"air_deadzone_up": 3.4,
		"air_deadzone_down": 2.6,
		"vertical_spring_ground": 4.6,
		"speed_dolly": 1.8,
		"speed_fov_gain": 2.4,
	},

	# Scripted moments: slow, centred, no anticipation, so the shot is the shot.
	"cinematic": {
		"look_ahead": 0.0,
		"thirds_bias": 0.0,
		"follow_x_catch": 3.0,
		"follow_x_settle": 2.4,
		"follow_x_still": 3.0,
		"vertical_spring_ground": 3.2,
		"vertical_spring_air": 2.8,
		"speed_fov_gain": 0.0,
		"speed_dolly": 0.0,
	},
}
