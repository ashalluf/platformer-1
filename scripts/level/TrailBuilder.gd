class_name TrailBuilder
## Sriracha trail placement.
##
## Trails are the game's only tutorial. A line says "run here"; an arc says
## "jump, and this is the arc you will fly"; a cluster says "there is something
## here worth the detour". The arcs are computed from the controller's real
## constants, so a trail the player follows is a trajectory the player can
## actually fly — which is the whole trick.

const SRIRACHA := preload("res://scripts/collectibles/Sriracha.gd")

## Must match PlayerController. Duplicated deliberately: a level builder should
## not be able to change the physics by editing a trail.
const JUMP_HEIGHT := 3.15
const JUMP_TIME_TO_APEX := 0.375
const FALL_MULT := 1.78
const RUN_SPEED := 9.2


static func _bottle(parent: Node3D, pos: Vector3, variant := 0) -> Sriracha:
	var s := SRIRACHA.new()
	s.variant = variant
	parent.add_child(s)
	s.position = pos
	return s


## Straight run of bottles. `count` includes both ends.
static func line(parent: Node3D, from: Vector3, to: Vector3, count: int,
		variant := 0) -> Array:
	var out := []
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		out.append(_bottle(parent, from.lerp(to, t), variant))
	return out


## The real jump arc: up under `gravity`, down under `gravity * FALL_MULT`,
## travelling at `speed_ratio` of top speed. Follow it and you land where the
## last bottle is.
static func jump_arc(parent: Node3D, from: Vector3, facing := 1.0,
		speed_ratio := 1.0, count := 9, height_scale := 1.0, variant := 0) -> Array:
	var g := (2.0 * JUMP_HEIGHT) / (JUMP_TIME_TO_APEX * JUMP_TIME_TO_APEX)
	var v0 := (2.0 * JUMP_HEIGHT * height_scale) / JUMP_TIME_TO_APEX
	var rise := v0 / g
	var apex := v0 * v0 / (2.0 * g)
	var fall := sqrt(2.0 * apex / (g * FALL_MULT))
	var total := rise + fall
	var vx := RUN_SPEED * speed_ratio * facing

	var out := []
	for i in count:
		var t := total * float(i) / float(maxi(count - 1, 1))
		var y: float
		if t <= rise:
			y = v0 * t - 0.5 * g * t * t
		else:
			var ft := t - rise
			y = apex - 0.5 * g * FALL_MULT * ft * ft
		out.append(_bottle(parent, from + Vector3(vx * t, y, 0.0), variant))
	return out


## An arc between two points, bulging by `bulge`. For gaps where the shape
## matters more than the physics.
static func curve(parent: Node3D, from: Vector3, to: Vector3, bulge: float,
		count := 7, variant := 0) -> Array:
	var out := []
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var p := from.lerp(to, t)
		p.y += sin(PI * t) * bulge
		out.append(_bottle(parent, p, variant))
	return out


## Reward cluster: a ring with a centre, so it reads as a deliberate prize.
static func cluster(parent: Node3D, center: Vector3, radius := 0.75,
		count := 8, variant := 0) -> Array:
	var out := [_bottle(parent, center, variant)]
	for i in count:
		var a := TAU * float(i) / float(count)
		out.append(_bottle(parent, center + Vector3(cos(a), sin(a), 0.0) * radius, variant))
	return out


## Vertical column, for pointing at something above.
static func column(parent: Node3D, base: Vector3, height: float, count := 5,
		variant := 0) -> Array:
	return line(parent, base, base + Vector3(0.0, height, 0.0), count, variant)
