extends Node
## FXDirector — global game-feel services: hit-stop, time warp, camera impulses.
##
## Anything that wants to punch the screen asks here instead of reaching for the
## camera directly, so a single screen-shake accessibility slider governs all of it.

signal camera_impulse(offset: Vector2, trauma: float)
signal camera_zoom_punch(amount: float, duration: float)

var _hitstop_left := 0.0
var _timewarp_left := 0.0
var _timewarp_scale := 1.0
var _last_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	# Hit-stop must tick in real time, not scaled time, or it never ends.
	#
	# `delta` cannot provide that. The engine has already multiplied it by
	# Engine.time_scale before _process sees it, so at scale 0.0 it arrives as
	# exactly 0.0, and dividing 0.0 by the scale is still 0.0: the countdown
	# never advanced, time scale never came back, and the first hit-stop of the
	# session froze the game permanently. Read the wall clock instead -- it is
	# the one source of time here that time_scale cannot reach.
	var now := Time.get_ticks_usec()
	var real_delta := float(now - _last_usec) / 1_000_000.0
	_last_usec = now

	if _hitstop_left > 0.0:
		_hitstop_left -= real_delta
		if _hitstop_left <= 0.0:
			Engine.time_scale = _timewarp_scale if _timewarp_left > 0.0 else 1.0

	if _timewarp_left > 0.0:
		_timewarp_left -= real_delta
		if _timewarp_left <= 0.0 and _hitstop_left <= 0.0:
			Engine.time_scale = 1.0


## Freeze frame for `duration` seconds of real time. The single most effective
## impact tool there is — used on landings, hits and collectible pickups.
func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, duration)
	Engine.time_scale = 0.0


func timewarp(scale: float, duration: float) -> void:
	_timewarp_scale = scale
	_timewarp_left = maxf(_timewarp_left, duration)
	if _hitstop_left <= 0.0:
		Engine.time_scale = scale


func shake(trauma: float, offset: Vector2 = Vector2.ZERO) -> void:
	var scale: float = Gx.get_setting("screen_shake", 1.0)
	if scale <= 0.0:
		return
	camera_impulse.emit(offset * scale, trauma * scale)


func zoom_punch(amount: float, duration: float = 0.25) -> void:
	camera_zoom_punch.emit(amount, duration)
