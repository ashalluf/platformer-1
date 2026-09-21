extends "res://levels/brega/BregaBeauty.gd"
## The title screen is a place, not a picture.
##
## It is literally the beauty benchmark — same build, same colour script — so
## the first frame of the game is the frame every level has to match. Wanis
## stands on the walkway at first light in his own clothes, the camera breathes,
## and the menu sits in the left column where the cell block is in shadow.

var _overlay: TitleOverlay
var _menu: MenuList
var _drift := 0.0
var _home := Vector3.ZERO


func _ready() -> void:
	# Set before super, because Stage reads these while it builds.
	show_hud = false
	music_theme = "brega"
	super._ready()
	level_id = "title"
	level_title = "LIBYAN GANGSTAS"
	Music.set_intensity(0.3)

	# He is on screen but not in play.
	if is_instance_valid(player):
		player.accept_player_input = false
		player.set_scripted_input(0.0, false)

	# Poster framing: pulled back and dropped a little so the sky carries the
	# logotype, with him off to the right of the menu column.
	camera.height_offset = 1.15
	camera.distance = 13.0
	camera.base_fov = 34.0
	camera.lateral_offset = -2.2
	camera.look_ahead = 0.0
	camera.speed_fov_gain = 0.0
	camera.set_process(false)
	camera.set_physics_process(false)
	_home = Vector3(spawn_point.x + camera.lateral_offset,
		spawn_point.y + camera.height_offset, camera.distance)
	camera.global_position = _home
	camera.fov = camera.base_fov

	var layer := CanvasLayer.new()
	layer.name = "TitleUI"
	add_child(layer)
	_overlay = TitleOverlay.new()
	layer.add_child(_overlay)

	_menu = MenuList.new()
	_menu.origin = Vector2(96.0, 336.0)
	_menu.width = 392.0
	layer.add_child(_menu)
	_menu.add_row("play", "WORLD ONE", "ابدأ")
	_menu.add_row("ice", "GLACIER RUN", "الجليد")
	_menu.add_row("chains", "THE CHAINS", "السلاسل")
	_menu.add_row("lab", "MOVEMENT LAB", "التدريب")
	_menu.add_row("settings", "SETTINGS", "الإعدادات")
	_menu.chosen.connect(_on_chosen)


## The poster grade: a deeper sky so cream type has something to sit on, and a
## hotter rim because on this screen he is the only thing that has to read.
func _mood() -> LightingRig.Mood:
	var m := super._mood()
	m.sky_top = Color(0.125, 0.160, 0.268)
	m.rim_energy = 7.2
	m.hero_fill_energy = 2.5
	m.adjustment_contrast = 1.09
	return m


## Same foreground as the benchmark, except the razor coil drops to the bottom
## edge. At benchmark height it crosses the menu column, and a black tangle
## behind cream type is a fight neither side wins.
func _layer_foreground() -> void:
	super._layer_foreground()
	var coil := geometry.get_node_or_null("RazorCoilForeground")
	if coil != null:
		geometry.remove_child(coil)
		coil.queue_free()
	PropKit.razor_coil(geometry, Vector3(-8.6, 1.12, 9.0), Vector3(-1.8, 1.30, 9.0),
		0.30, mats["dark"], 12, "RazorCoilForeground")


## A slow breath, long enough that you never see it loop.
func _process(delta: float) -> void:
	_drift += delta
	if not is_instance_valid(camera):
		return
	var sway := sin(_drift * 0.097) * 0.85 + sin(_drift * 0.041) * 0.45
	var lift := sin(_drift * 0.073 + 1.1) * 0.22
	camera.global_position = _home + Vector3(sway, lift, 0.0)
	camera.fov = camera.base_fov + sin(_drift * 0.055) * 0.7


func _on_chosen(_index: int, id: String) -> void:
	match id:
		"play":
			SceneFlow.change_scene("res://levels/menu/WorldMap.tscn")
		"ice":
			Gx.reset_run()
			SceneFlow.change_scene("res://levels/ice/IceBonus01.tscn")
		"chains":
			SceneFlow.change_scene("res://levels/menu/Collection.tscn")
		"lab":
			Gx.reset_run()
			SceneFlow.change_scene("res://levels/greybox/Greybox.tscn")
		"settings":
			_menu.accept_input = false
			var s := SettingsPanel.new()
			(_menu.get_parent() as CanvasLayer).add_child(s)
			s.closed.connect(func() -> void: _menu.accept_input = true)
