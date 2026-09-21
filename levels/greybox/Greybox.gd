class_name GreyboxLevel extends Stage
## Movement laboratory.
##
## Not a level — a calibration range. Every section isolates one property of the
## controller so regressions in feel show up in a capture instead of in a
## playtest: flat run-up, jump heights at the edge of reach, gap widths, a
## corner-correction lip, slopes, a dash-only gap and a pit for respawn.

const GROUND_Y := 0.0

var _pal := {}


func _ready() -> void:
	level_id = "greybox"
	level_title = "MOVEMENT LAB"
	spawn_point = Vector3(-26.0, 2.0, 0.0)
	kill_plane_y = -18.0
	super._ready()


func _mood() -> LightingRig.Mood:
	return LightingRig.neutral_studio()


func _build_level() -> void:
	_pal = {
		"floor": LevelKit.material(Color(0.255, 0.265, 0.285), 0.88),
		"block": LevelKit.material(Color(0.38, 0.395, 0.425), 0.80),
		"accent": LevelKit.material(Color(0.42, 0.28, 0.20), 0.72),
		"marker": LevelKit.material(Color(0.30, 0.33, 0.37), 0.62),
		"back": LevelKit.material(Color(0.30, 0.29, 0.31), 0.95),
	}

	_section_runway()
	_section_jump_heights()
	_section_gaps()
	_section_corner_and_slopes()
	_section_dash_gap()
	_backdrop()


## 0. Run-up: enough flat ground to reach and read top speed.
func _section_runway() -> void:
	LevelKit.platform(geometry, -34.0, GROUND_Y, 30.0, _pal["floor"], 14.0, 3.2, "Runway")
	# Height reference posts every 4 units — a ruler for capture screenshots.
	for i in 7:
		var x := -32.0 + i * 4.0
		LevelKit.prop(geometry, Vector3(x, GROUND_Y + 1.0, -2.2),
			Vector3(0.10, 2.0, 0.10), _pal["marker"], "Ruler%d" % i)


## 1. Jump heights: the tallest step should be exactly clearable from standstill.
func _section_jump_heights() -> void:
	var heights := [1.0, 2.0, 3.0]
	var x := -4.0
	for h: float in heights:
		LevelKit.platform(geometry, x, GROUND_Y + h, 3.4, _pal["block"], h + 14.0, 3.2,
			"Step%.0f" % h)
		x += 3.4
	LevelKit.platform(geometry, x, GROUND_Y + 3.0, 6.0, _pal["block"], 17.0, 3.2, "StepTop")


## 2. Gaps: widths that bracket a running jump, so one is a fail and one is not.
func _section_gaps() -> void:
	var x := 12.4
	for width: float in [3.0, 5.0, 7.0]:
		x += width
		LevelKit.platform(geometry, x, GROUND_Y + 3.0, 4.0, _pal["block"], 6.5, 3.2,
			"GapLanding%.0f" % width)
		x += 4.0


## 3. Corner correction lip + slopes.
func _section_corner_and_slopes() -> void:
	LevelKit.platform(geometry, 38.0, GROUND_Y + 3.0, 8.0, _pal["block"], 17.0, 3.2, "SlopeBase")
	# A low lip directly over the landing: without corner correction, a rising
	# jump clips it and stops dead.
	LevelKit.box(geometry, Vector3(41.0, GROUND_Y + 6.4, 0.0), Vector3(2.2, 0.5, 5.0),
		_pal["accent"], "CornerLip")
	LevelKit.ramp(geometry, Vector2(46.0, GROUND_Y + 3.0), Vector2(54.0, GROUND_Y + 6.2),
		3.2, _pal["block"], 1.4, "RampUp")
	LevelKit.platform(geometry, 54.0, GROUND_Y + 6.2, 6.0, _pal["block"], 20.0, 3.2, "RampTop")
	LevelKit.ramp(geometry, Vector2(60.0, GROUND_Y + 6.2), Vector2(68.0, GROUND_Y + 2.0),
		3.2, _pal["block"], 1.4, "RampDown")


## 4. Dash gap: too wide for a running jump, exactly right for a dash-jump.
func _section_dash_gap() -> void:
	LevelKit.platform(geometry, 68.0, GROUND_Y + 2.0, 6.0, _pal["block"], 16.0, 3.2, "DashTakeoff")
	LevelKit.platform(geometry, 81.0, GROUND_Y + 2.0, 15.0, _pal["accent"], 16.0, 3.2, "DashLanding")
	# Pit between them — falling here exercises the respawn path.
	LevelKit.prop(geometry, Vector3(77.0, GROUND_Y - 8.0, -3.0), Vector3(13.0, 0.4, 4.0),
		_pal["marker"], "PitFloorMarker")


## Simple parallax slabs so the frame is not empty behind the gameplay layer.
func _backdrop() -> void:
	var far := LevelKit.material(Color(0.115, 0.125, 0.165), 0.98)
	var mid := LevelKit.material(Color(0.175, 0.180, 0.215), 0.95)
	# Skyline tops are chosen in world units so they land in the upper third of
	# the frame and leave sky above — silhouette, not wallpaper.
	for i in 16:
		var x := -44.0 + i * 9.0
		var top := 1.6 + fmod(float(i) * 5.37, 4.4)
		var base := -6.0
		LevelKit.prop(geometry, Vector3(x, (top + base) * 0.5, -14.0),
			Vector3(6.0, top - base, 3.0), mid, "MidSlab%d" % i)
	for i in 11:
		var x := -52.0 + i * 14.0
		var top := 4.5 + fmod(float(i) * 7.13, 5.0)
		var base := -10.0
		LevelKit.prop(geometry, Vector3(x, (top + base) * 0.5, -30.0),
			Vector3(11.0, top - base, 4.0), far, "FarSlab%d" % i)
	# Foreground silhouette band: occludes the bottom corners and gives the
	# frame a near layer to read depth against.
	var fg := LevelKit.material(Color(0.045, 0.048, 0.062), 1.0)
	for i in 9:
		var x := -44.0 + i * 16.0
		LevelKit.prop(geometry, Vector3(x, -3.1, 7.5), Vector3(9.0, 5.2, 1.2), fg,
			"ForeSlab%d" % i)
