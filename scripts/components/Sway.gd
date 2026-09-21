class_name Sway extends Node3D
## Rigid-body wind, for things that hang or are caught on something.
##
## Snagged bags, hanging signs, loose shutters, chains, washing on a line.
## Two sine scales plus a per-instance phase, so a row of them never ticks
## together. Cheaper than cloth and, at the distances this camera uses,
## indistinguishable from it.

@export var axis := Vector3(0.0, 0.0, 1.0)
@export var amplitude := 0.35
@export var speed := 1.4
@export var gust_amplitude := 0.22
@export var gust_speed := 3.9
@export var position_amplitude := 0.0
@export var phase := 0.0

var _rest_rotation: Vector3
var _rest_position: Vector3
var _t := 0.0


func _ready() -> void:
	_rest_rotation = rotation
	_rest_position = position
	if is_zero_approx(phase):
		phase = fposmod(global_position.x * 1.7 + global_position.y * 2.3, TAU)


func _process(delta: float) -> void:
	_t += delta
	var a := sin(_t * speed + phase) * amplitude
	var g := sin(_t * gust_speed + phase * 2.1) * gust_amplitude
	var total := a + g
	rotation = _rest_rotation + axis.normalized() * total
	if position_amplitude > 0.0:
		position = _rest_position + Vector3(total, absf(total) * -0.3, 0.0) * position_amplitude
