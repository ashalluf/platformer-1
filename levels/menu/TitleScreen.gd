extends "res://levels/brega/BregaBeauty.gd"
## The title screen is a place, not a picture.
##
## It is literally the beauty benchmark — same build, same colour script, same
## lighting — so the first frame of the game is the frame every level has to
## match, and the title can never look like a different game.
##
## What this file adds on top of that frame is TIME, because a screen that only
## breathes is a screenshot with a menu on it:
##
##   ARRIVAL   the camera cranes in and down while the key comes the last
##             couple of degrees over the horizon and the score opens up. The
##             first four seconds are a shot, not a load.
##   LIFE      left alone, the camera walks between three authored framings and
##             back, Wanis shifts his weight and looks out, the flare gusts,
##             birds cross the haze. Every one of those runs on its own clock,
##             so the screen never lands on the same combination twice.
##   COMMIT    choosing a row happens in the WORLD first — a hit, a push in, the
##             sun the rest of the way up, the music lifting — and only then
##             does SceneFlow take the screen with its frost wipe.
##
## Nothing here restates a number from BregaBeauty. The light rig is read back
## off the built nodes and dimmed down from whatever it turned out to be, so the
## benchmark can be retuned underneath this file and the entrance still lands on
## the frame the benchmark became.

enum Phase { ENTRANCE, LIVE, COMMIT }

# --- Camera staging ---------------------------------------------------------
#
# Framings, as (distance, height_offset, lateral_offset, fov).
#
# Two rules govern all of them.
#
# The lockup is fitted to a measure that runs to 0.55 of the frame width and the
# menu slabs sit under its left half, so the type block owns the left column
# outright and Wanis has to stand in the right third — between 0.64 and 0.74 of
# the frame width. Screen x for a given framing is
#     0.5 - lateral / (2 * distance * tan(fov/2) * 16/9)
# and every lateral below is solved from that, which is why they are not round
# numbers. Closer to the middle than 0.64 and the menu is standing on him;
# further right than 0.74 and he is falling off the edge of his own poster.
#
# And the camera cannot drop far below HOME's height: the foreground razor coil
# is parked on the bottom edge, and every 10 cm the lens drops walks it about 4%
# of the frame height upward, towards the menu column it was moved out of in the
# first place.

## The poster. Everything else is a departure from this and a return to it.
const HOME := Vector4(13.0, 1.15, -2.50, 34.0)   ## he lands at 0.68
## Where the screen arrives from: further out, higher, wider. Coming down as
## well as in makes it a crane move; a pure push is a zoom, and a zoom is what
## a menu does, not what a camera does.
const ARRIVAL := Vector4(16.4, 2.55, -3.20, 39.0)  ## 0.655, and he grows into it
## WIDE hands the distance back to him. CLOSE is the marketing portrait. RISE
## cranes up onto the flare and its plume, which is the only large slow movement
## in the far half of the frame.
const WIDE := Vector4(15.2, 2.05, -3.00, 36.0)     ## 0.673
const CLOSE := Vector4(10.9, 0.95, -2.60, 31.0)    ## 0.740
const RISE := Vector4(13.8, 2.30, -2.82, 34.5)     ## 0.685
## Added on top of the live framing while a row is being committed.
const PUSH := Vector4(-1.45, -0.08, -0.12, -2.80)

const CAM_SETTLE := 3.0     ## the crane, ARRIVAL -> HOME
const FIRST_LIGHT := 2.0    ## how long the key takes to come up
## The menu arrives between the logotype's rule wiping out and its tagline
## landing — TitleOverlay owns that timeline, this only has to not collide.
const MENU_IN := 1.05
## Idle after the entrance before the camera starts walking. Short on purpose:
## the frame should never come to a complete stop, so what the player reads is a
## living shot rather than an attract mode that switched itself on.
const FIRST_MOVE := 1.4
const HOLD_HOME := 6.2
const HOLD_AWAY := 4.6

var _overlay: TitleOverlay
var _menu: MenuList
var _rig: WanisRig
var _phase: Phase = Phase.ENTRANCE
var _t := 0.0

# Camera walk.
var _shot_from := ARRIVAL
var _shot_to := HOME
var _shot_t := 0.0
var _shot_dur := CAM_SETTLE
var _shot_settle := true     ## true = arrive-and-settle, false = glide both ends
var _hold := 0.0             ## seconds left before the next move
var _away := false           ## is the camera off the poster framing?
var _bag: Array[Vector4] = []
var _kick := Vector2.ZERO
var _kick_vel := Vector2.ZERO
var _punch := 0.0

# Light rig, read back off the built nodes rather than restated.
var _lights := {}
var _lit := {}
var _env: Environment

# Life.
var _flare: OmniLight3D
var _flame: MeshInstance3D
var _flare_base := 0.0
var _flame_rest := Vector3.ZERO
var _gust := 0.0
var _gust_wait := 5.0
var _shift := 0.0            ## seconds left off the marketing pose
var _shift_wait := 1.9
var _birds: Node3D
var _wing_near: Array[Node3D] = []
var _wing_far: Array[Node3D] = []
var _bird_pos := Vector3(-5.0, 10.4, -46.0)
var _bird_speed := 5.0
var _bird_flap := 3.9
var _bird_wait := 0.0


func _ready() -> void:
	# Set before super, because Stage reads these while it builds.
	show_hud = false
	music_theme = "brega"
	super._ready()
	level_id = "title"
	level_title = "LIBYAN GANGSTAS"

	# Stage has already started the score at its own level. Drop it to nothing
	# on this frame and let the entrance bring it up with the light — the two
	# have to arrive together or neither reads as an arrival.
	Music.intensity = 0.0
	Music.set_intensity(0.02)
	Audio.set_ambience("wind", -22.0)

	# He is on screen but not in play.
	player_spawned.connect(_on_player_spawned)
	if is_instance_valid(player):
		_on_player_spawned(player)

	_stage_camera()
	_stage_lights()
	_stage_ui()
	_stage_life()


## The GameCamera's follow rig is a gameplay tool. On the title every frame is
## authored, so it comes off process entirely and this file owns the transform.
func _stage_camera() -> void:
	camera.look_ahead = 0.0
	camera.speed_fov_gain = 0.0
	camera.set_process(false)
	camera.set_physics_process(false)
	_apply(ARRIVAL)


func _stage_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TitleUI"
	add_child(layer)

	# TitleOverlay stages itself off its own clock the moment it enters the
	# tree, so it goes in now and is left alone.
	_overlay = TitleOverlay.new()
	layer.add_child(_overlay)

	# The menu is built now but held off screen: MenuList's row cascade starts
	# when `open()` is called, and it should start after the rule under the
	# logotype has drawn itself, not alongside it.
	_menu = MenuList.new()
	_menu.origin = Vector2(TitleOverlay.MENU_X, TitleOverlay.MENU_TOP)
	_menu.width = 392.0
	_menu.visible = false
	_menu.accept_input = false
	layer.add_child(_menu)
	_menu.add_row("play", "WORLD ONE", "ابدأ")
	_menu.add_row("ice", "GLACIER RUN", "الجليد")
	_menu.add_row("chains", "THE CHAINS", "السلاسل")
	_menu.add_row("lab", "MOVEMENT LAB", "التدريب")
	_menu.add_row("settings", "SETTINGS", "الإعدادات")
	_menu.chosen.connect(_on_chosen)


## Nothing is supposed to respawn on a title screen — but the capture autopilot
## can and does walk him off the end of the walkway, and a stale rig reference
## would take the whole screen down with it. Take the pose again whenever a body
## appears, whoever put it there.
func _on_player_spawned(p: PlayerController) -> void:
	p.accept_player_input = false
	p.set_scripted_input(0.0, false)
	_rig = p.get_node_or_null("Rig") as WanisRig
	if _rig != null:
		_rig.beauty_pose = true
	_shift = 0.0


func _stage_life() -> void:
	_flare = geometry.get_node_or_null("FlareGlow") as OmniLight3D
	_flame = geometry.get_node_or_null("Flame") as MeshInstance3D
	if is_instance_valid(_flare):
		_flare_base = _flare.light_energy
	if is_instance_valid(_flame):
		_flame_rest = _flame.rotation_degrees


# --- Light ------------------------------------------------------------------

## Read the rig back off the tree. Every energy in the entrance is a fraction of
## whatever the benchmark actually built, so retuning the benchmark retunes the
## entrance with it and the two can never drift apart.
func _stage_lights() -> void:
	_env = world_env.environment
	for key: String in ["Sun", "Fill", "Bounce", "Rim", "HeroFill"]:
		var l := get_node_or_null(key) as DirectionalLight3D
		if l == null:
			continue
		_lights[key] = l
		_lit[key] = l.light_energy
	var sun := _sun()
	_lit["pitch"] = sun.rotation_degrees.x if sun != null else 0.0
	_lit["exposure"] = _env.tonemap_exposure
	_lit["ambient"] = _env.ambient_light_energy
	# The sky is dimmed through the Environment's own multiplier rather than
	# through the sky material's, because Stage may hand the level a SkyForge
	# shader sky instead of a ProceduralSkyMaterial and this has to hold either
	# way.
	_lit["sky"] = _env.background_energy_multiplier
	_light_ramp(0.0)


func _sun() -> DirectionalLight3D:
	return _lights.get("Sun", null) as DirectionalLight3D


## Pre-dawn to first light, on one parameter.
##
## `e` = 0 is the minute before the sun touches the horizon: the key is a
## rumour, the cool sabkha bounce is carrying the frame on its own, and the whole
## image sits half a stop down. `e` = 1 is the benchmark, to the number.
##
## It deliberately accepts e > 1 and extrapolates, which is what the commit uses:
## "the sun comes the rest of the way up" is the same move continued, not a
## second effect bolted on beside it.
func _light_ramp(e: float) -> void:
	# Multipliers at e = 0. The fill is the only one above 1.0 — before sunrise
	# the sky bounce is most of the light there is, and it losing ground to the
	# key is what makes the ramp read as a sunrise rather than a dimmer.
	_energy("Sun", 0.13, e)
	_energy("Rim", 0.16, e)
	_energy("HeroFill", 0.32, e)
	_energy("Fill", 1.60, e)
	_energy("Bounce", 0.45, e)

	# The key physically rises: three and a half degrees of pitch, all of it
	# below the horizon line, so the shadows lengthen and swing without the sky
	# ever painting a disc.
	var sun := _sun()
	if sun != null:
		sun.rotation_degrees.x = lerpf(float(_lit["pitch"]) - 3.4,
			float(_lit["pitch"]), e)

	_env.tonemap_exposure = lerpf(float(_lit["exposure"]) * 0.74,
		float(_lit["exposure"]), e)
	_env.ambient_light_energy = lerpf(float(_lit["ambient"]) * 0.55,
		float(_lit["ambient"]), e)
	_env.background_energy_multiplier = lerpf(float(_lit["sky"]) * 0.52,
		float(_lit["sky"]), e)


func _energy(key: String, start_mult: float, e: float) -> void:
	if not _lights.has(key):
		return
	var l := _lights[key] as DirectionalLight3D
	var target: float = _lit[key]
	l.light_energy = maxf(lerpf(target * start_mult, target, e), 0.0)


# --- Frame ------------------------------------------------------------------

## NOTE: BregaBeauty has no `_process` today, so there is no super call — GDScript
## rejects one against an undefined parent virtual. If the benchmark ever grows
## one, add `super._process(delta)` here or the title silently loses it.
func _process(delta: float) -> void:
	# Anything slower than 50 ms is a hitch, not time passing: clamp it, or one
	# stalled frame throws the kick spring and skips the entrance past a beat.
	# Everything downstream runs off this one number.
	delta = minf(delta, 1.0 / 20.0)
	_t += delta

	match _phase:
		Phase.ENTRANCE:
			_drive_entrance()
		Phase.LIVE:
			_drive_attract(delta)
		Phase.COMMIT:
			_punch = minf(_punch + delta * 3.2, 1.0)
			_light_ramp(1.0 + _punch * 0.42)

	_drive_camera(delta)
	_drive_pose(delta)
	_drive_flare(delta)
	_drive_birds(delta)


func _drive_entrance() -> void:
	_light_ramp(_out_quad(clampf(_t / FIRST_LIGHT, 0.0, 1.0)))
	# The score comes up with the key. MusicDirector eases toward the target at
	# its own rate, so this is a target curve, not a volume curve.
	Music.set_intensity(lerpf(0.02, 0.34, clampf(_t / (FIRST_LIGHT * 1.4), 0.0, 1.0)))

	if not _menu.visible and _t >= MENU_IN:
		_menu.visible = true
		_menu.open()

	if _t >= CAM_SETTLE:
		_phase = Phase.LIVE
		_menu.accept_input = true
		_hold = FIRST_MOVE
		_light_ramp(1.0)


func _drive_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	_shot_t = minf(_shot_t + delta, _shot_dur)
	var s := _current_shot() + PUSH * _punch

	# Two out-of-phase sines, slow enough that the loop never surfaces. Damped
	# while the camera is travelling, because a breath on top of a move is not a
	# breath, it is a wobble.
	var travel := 1.0 - clampf(_shot_t / maxf(_shot_dur, 0.0001), 0.0, 1.0)
	var gain := clampf(_t / CAM_SETTLE, 0.0, 1.0) * (1.0 - 0.7 * travel) * (1.0 - _punch)
	var sway := (sin(_t * 0.097) * 0.85 + sin(_t * 0.041) * 0.45) * gain
	var lift := sin(_t * 0.073 + 1.1) * 0.22 * gain
	var wob := sin(_t * 0.055) * 0.70 * gain

	# The commit kick, as a spring rather than a teleport: the frame gets shoved
	# and recovers. GameCamera's own shake is unreachable here because its
	# process is off, so this respects the accessibility slider itself.
	_kick_vel += (-_kick * 300.0 - _kick_vel * 24.0) * delta
	_kick += _kick_vel * delta

	camera.distance = s.x
	camera.height_offset = s.y
	camera.lateral_offset = s.z
	camera.base_fov = s.w
	camera.global_position = Vector3(
		spawn_point.x + s.z + sway + _kick.x,
		spawn_point.y + s.y + lift + _kick.y,
		s.x)
	camera.fov = s.w + wob


## The attract walk. It only runs when the screen has been left alone, and any
## input walks the frame back to the poster rather than cutting to it.
func _drive_attract(delta: float) -> void:
	if _shot_t < _shot_dur:
		return
	_hold -= delta
	if _hold > 0.0:
		return
	if _away:
		_goto(HOME, randf_range(4.4, 5.6))
		_hold = HOLD_HOME + randf_range(-1.0, 1.4)
		_away = false
		return
	# The first move away is always WIDE: it is the gentlest of the three and
	# the one most likely to be the only one anybody sees. After that the bag is
	# shuffled and drained, so the walk never repeats an order.
	var next := WIDE
	if not _bag.is_empty() or _shot_from != ARRIVAL:
		if _bag.is_empty():
			for f: Vector4 in [WIDE, CLOSE, RISE]:
				_bag.append(f)
			_bag.shuffle()
		next = _bag.pop_back()
	_goto(next, randf_range(3.8, 4.8))
	_hold = HOLD_AWAY + randf_range(-0.8, 1.2)
	_away = true
	if next == RISE:
		_gust = 1.0   ## the flare answers the camera finding it


## He does not stand still for a minute and a half. Every few seconds the
## contrapposto relaxes into the gameplay idle — weight comes off the back leg,
## the shoulders level, and the idle's own head turns take over — and then he
## settles back onto his mark. The rig blends both ways over about half a
## second, so what you read is a man shifting his weight, not a pose swap.
func _drive_pose(delta: float) -> void:
	if not is_instance_valid(_rig):
		return
	if _shift > 0.0:
		_shift -= delta
		if _shift <= 0.0:
			_rig.beauty_pose = true
		return
	if _phase != Phase.LIVE:
		return
	_shift_wait -= delta
	if _shift_wait <= 0.0:
		_shift_wait = randf_range(7.0, 13.0)
		_shift = 1.0
		_rig.beauty_pose = false


## The flare is the only fire in the frame and the focal point of its empty
## half. Burning gas is never steady: three sines at unrelated rates for the
## ripple, and an occasional gust that swells the flame and throws light across
## the plant.
func _drive_flare(delta: float) -> void:
	if not is_instance_valid(_flare):
		return
	_gust_wait -= delta
	if _gust_wait <= 0.0:
		_gust_wait = randf_range(6.0, 13.0)
		_gust = 1.0
	_gust = maxf(_gust - delta * 0.85, 0.0)

	var ripple := 1.0 + sin(_t * 7.1) * 0.13 + sin(_t * 11.3 + 1.7) * 0.09 \
		+ sin(_t * 23.0 + 0.4) * 0.05
	_flare.light_energy = _flare_base * (ripple + _gust * _gust * 0.55)
	if is_instance_valid(_flame):
		_flame.scale = Vector3(1.0 + sin(_t * 9.0) * 0.06,
			1.0 + sin(_t * 6.3) * 0.15 + _gust * 0.30, 1.0)
		_flame.rotation_degrees = _flame_rest + Vector3(0.0, 0.0, sin(_t * 3.1) * 2.6)


## Birds. At this distance each one is about a dozen pixels of movement, which
## is the whole point — the eye reads motion long before it reads shape, and a
## sky with nothing crossing it is a matte painting. They come over every twenty
## seconds or so, never on the same line twice.
func _drive_birds(delta: float) -> void:
	if not is_instance_valid(_birds):
		return
	if _bird_wait > 0.0:
		_bird_wait -= delta
		if _bird_wait <= 0.0:
			_bird_pos = Vector3(-32.0, randf_range(8.0, 13.5), randf_range(-54.0, -40.0))
			_bird_speed = randf_range(4.2, 6.0)
			_bird_flap = randf_range(3.3, 4.7)
		return

	_bird_pos.x += _bird_speed * delta
	if _bird_pos.x > 66.0:
		_bird_wait = randf_range(15.0, 28.0)
		_birds.visible = false
		return
	_birds.visible = true
	# A long shallow wave across the crossing, so the flock is never a ruler.
	_birds.position = _bird_pos + Vector3(0.0, sin(_bird_pos.x * 0.055) * 1.3, 0.0)
	for i in _wing_near.size():
		var beat := sin(_t * _bird_flap + float(i) * 0.8)
		var a := 0.26 + beat * 0.62
		_wing_near[i].rotation.x = a
		_wing_far[i].rotation.x = -a


# --- Interaction ------------------------------------------------------------

## Stage's handler pauses the tree and rebuilds the player on `restart`. Both
## are wrong here — a stray key would respawn him mid-pose — so this
## deliberately does not call up. It only notes that somebody is in the room.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_nudge()


## Somebody is here: give the poster framing back and start the idle clock over.
func _nudge() -> void:
	if _phase != Phase.LIVE:
		return
	_hold = HOLD_HOME
	if not _away:
		return
	_goto(HOME, 2.6)
	_away = false


func _on_chosen(_index: int, id: String) -> void:
	if id == "settings":
		# Settings does not leave the screen, so it gets a UI response and not a
		# world one. Nothing in the frame should imply a departure.
		_menu.accept_input = false
		var s := SettingsPanel.new()
		(_menu.get_parent() as CanvasLayer).add_child(s)
		s.closed.connect(func() -> void:
			_menu.accept_input = true
			_nudge())
		return
	match id:
		"play": _commit("res://levels/menu/WorldMap.tscn", false)
		"ice": _commit("res://levels/ice/IceBonus01.tscn", true)
		"chains": _commit("res://levels/menu/Collection.tscn", false)
		"lab": _commit("res://levels/greybox/Greybox.tscn", true)


## Choosing a row is an event in the world before it is a scene change.
##
## The frame stops dead for a couple of frames, takes a shove, then drops in on
## him while the sun finishes coming up and the score opens out. Only after all
## of that does SceneFlow's frost wipe take the screen. A menu that animates
## nothing but its own rectangle is a menu sitting on top of a picture, and this
## screen has spent four seconds insisting it is not one.
func _commit(path: String, reset_run: bool) -> void:
	if _phase == Phase.COMMIT:
		return
	_phase = Phase.COMMIT
	_menu.accept_input = false
	# Back on his mark for the departure, wherever the attract walk had got to.
	_goto(HOME, 0.55)
	if is_instance_valid(_rig):
		_rig.beauty_pose = true
	_shift = 0.0

	FX.hitstop(0.08)
	var shake: float = Gx.get_setting("screen_shake", 1.0)
	_kick_vel += Vector2(0.0, -1.0) * 2.4 * shake
	_gust = 1.0
	Audio.play_2d("dash_charged", -8.0, 0.72, "UI")
	Music.set_intensity(0.9)
	if reset_run:
		Gx.reset_run()

	# Real seconds: the hit-stop has the tree at time scale zero for the first
	# of them.
	await get_tree().create_timer(0.46, true, false, true).timeout
	SceneFlow.change_scene(path)


# --- Camera maths -----------------------------------------------------------

func _goto(to: Vector4, duration: float) -> void:
	_shot_from = _current_shot()
	_shot_to = to
	_shot_t = 0.0
	_shot_dur = maxf(duration, 0.0001)
	_shot_settle = false


func _current_shot() -> Vector4:
	var x := _shot_t / maxf(_shot_dur, 0.0001)
	return _shot_from.lerp(_shot_to, _settle(x) if _shot_settle else _glide(x))


func _apply(s: Vector4) -> void:
	camera.distance = s.x
	camera.height_offset = s.y
	camera.lateral_offset = s.z
	camera.base_fov = s.w
	camera.global_position = Vector3(spawn_point.x + s.z, spawn_point.y + s.y, s.x)
	camera.fov = s.w


## Cubic out with the tail stretched: almost all of the travel happens early and
## the last half metre takes a second. That late, slow crawl is what separates a
## crane settling on a tripod head from a lerp finishing.
static func _settle(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.2)


## Smootherstep — zero velocity AND zero acceleration at both ends. A camera
## move that starts or stops with any velocity at all reads as a cut.
static func _glide(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _out_quad(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


# --- Build ------------------------------------------------------------------

## The poster grade: a deeper sky so cream type has something to sit on, and a
## hotter rim because on this screen he is the only thing that has to read.
func _mood() -> LightingRig.Mood:
	var m := super._mood()
	m.sky_top = Color(0.125, 0.160, 0.268)
	m.rim_energy = 7.2
	m.hero_fill_energy = 2.5
	m.adjustment_contrast = 1.09
	return m


## Same foreground as the benchmark, with two changes the moving camera forces.
func _layer_foreground() -> void:
	super._layer_foreground()

	# The razor coil drops to the bottom edge. At benchmark height it crosses
	# the menu column, and a black tangle behind cream type is a fight neither
	# side wins.
	var coil := geometry.get_node_or_null("RazorCoilForeground")
	if coil != null:
		geometry.remove_child(coil)
		coil.queue_free()
	PropKit.razor_coil(geometry, Vector3(-8.6, 1.12, 9.0), Vector3(-1.8, 1.30, 9.0),
		0.30, mats["dark"], 12, "RazorCoilForeground")

	_tarp_post()


## Something for the camera to swing against.
##
## The benchmark's near layer is all on the left, because the benchmark's camera
## never moved; this one does, and parallax only exists where there is something
## close enough to show it. A stanchion with a torn tarp lashed to it, hard right
## and low at z = +6: at the poster framing it closes the bottom-right corner,
## it swings hard across the frame on every move, and by the time the camera has
## pushed in to CLOSE it has left the frame entirely.
##
## It stays near-black. The key is behind the geometry and the rim is hero-only,
## so nothing in front of the gameplay plane is allowed to catch light — which is
## also why it can sit under the chain tray without fighting it.
func _tarp_post() -> void:
	var dark: Material = mats["dark"]
	LevelKit.prop(geometry, Vector3(0.66, -0.18, 6.0), Vector3(0.17, 3.2, 0.17),
		dark, "TarpPost").rotation.z = deg_to_rad(-7.0)
	LevelKit.prop(geometry, Vector3(0.44, 1.30, 6.0), Vector3(0.96, 0.11, 0.11),
		dark, "TarpArm").rotation.z = deg_to_rad(9.0)

	# The sheet and two torn tatters hang off one pivot, so they move as one
	# piece of cloth. Three different lengths is what stops a dark rectangle in
	# the corner reading as a dark rectangle in the corner.
	var sway := Sway.new()
	sway.name = "TarpSway"
	sway.position = Vector3(0.28, 1.26, 6.0)
	sway.axis = Vector3(0.28, 0.12, 1.0)
	sway.amplitude = 0.13
	sway.speed = 0.85
	sway.gust_amplitude = 0.085
	sway.gust_speed = 2.4
	geometry.add_child(sway)
	LevelKit.prop(sway, Vector3(0.0, -0.64, 0.0), Vector3(0.80, 1.22, 0.04),
		dark, "Tarp")
	LevelKit.prop(sway, Vector3(-0.26, -1.52, 0.02), Vector3(0.24, 0.62, 0.03),
		dark, "TarpTearA").rotation.z = deg_to_rad(6.0)
	LevelKit.prop(sway, Vector3(0.22, -1.38, 0.02), Vector3(0.18, 0.36, 0.03),
		dark, "TarpTearB").rotation.z = deg_to_rad(-9.0)


func _atmosphere() -> void:
	super._atmosphere()
	_build_birds()


## Seven birds in a loose flock, each one a body, a tail and two wings on their
## own pivots. Built once and flown across the sky forever; the first crossing is
## seeded already in frame, because the screen should be alive on the frame it
## opens, not twenty seconds later.
func _build_birds() -> void:
	_birds = Node3D.new()
	_birds.name = "Birds"
	_birds.position = _bird_pos
	geometry.add_child(_birds)

	var dark: Material = mats["dark"]
	for i in 7:
		var b := Node3D.new()
		b.name = "Bird%d" % i
		# Deterministic scatter: a flock is not a grid and it is not a line.
		b.position = Vector3(fmod(float(i) * 2.9, 6.6) - 3.3,
			fmod(float(i) * 1.7, 2.4) - 1.2, fmod(float(i) * 3.1, 5.2) - 2.6)
		_birds.add_child(b)
		LevelKit.prop(b, Vector3.ZERO, Vector3(0.30, 0.11, 0.11), dark, "Body")
		LevelKit.prop(b, Vector3(-0.26, 0.01, 0.0), Vector3(0.22, 0.04, 0.09),
			dark, "Tail")
		# Wings spread along Z and beat about X: side-on, that is a stroke up
		# and down, which is the only bird read that survives at twelve pixels.
		for side: int in [1, -1]:
			var pivot := Node3D.new()
			pivot.name = "WingNear" if side > 0 else "WingFar"
			b.add_child(pivot)
			LevelKit.prop(pivot, Vector3(0.0, 0.0, float(side) * 0.30),
				Vector3(0.18, 0.045, 0.58), dark, "Feathers")
			if side > 0:
				_wing_near.append(pivot)
			else:
				_wing_far.append(pivot)
