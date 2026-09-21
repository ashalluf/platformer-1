extends Node
## AudioDirector — buses, pooled players, and one place that owns every sound.
##
## Streams are synthesised on first request and cached, so the game ships with
## no audio files. Callers ask for a sound by id and never touch a player.

enum Bus { MASTER, MUSIC, SFX, AMBIENCE, UI }

const BUS_NAMES := ["Master", "Music", "SFX", "Ambience", "UI"]
const POOL_3D := 24
const POOL_2D := 8

## How long a collect can follow the last one and still count as the same run.
const COMBO_WINDOW := 0.85
const COMBO_MAX := 15

var _streams: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _combo := 0
var _combo_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buses()
	_build_pools()
	_apply_volumes()
	Gx.setting_changed.connect(_on_setting_changed)


func _process(delta: float) -> void:
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_combo = 0


# --- Buses ------------------------------------------------------------------

func _build_buses() -> void:
	for i in range(1, BUS_NAMES.size()):
		var name_: String = BUS_NAMES[i]
		if AudioServer.get_bus_index(name_) >= 0:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name_)
		AudioServer.set_bus_send(idx, "Master")


func _bus_name(bus: Bus) -> String:
	return BUS_NAMES[bus]


func _apply_volumes() -> void:
	_set_bus_volume("Master", Gx.get_setting("master_volume", 1.0))
	_set_bus_volume("Music", Gx.get_setting("music_volume", 0.85))
	_set_bus_volume("SFX", Gx.get_setting("sfx_volume", 1.0))
	_set_bus_volume("Ambience", Gx.get_setting("sfx_volume", 1.0) * 0.8)
	_set_bus_volume("UI", Gx.get_setting("sfx_volume", 1.0))


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _on_setting_changed(key: String) -> void:
	if key.ends_with("_volume"):
		_apply_volumes()


# --- Pools ------------------------------------------------------------------

func _build_pools() -> void:
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sfx3D_%d" % i
		p.bus = "SFX"
		p.max_distance = 48.0
		p.unit_size = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)

	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx2D_%d" % i
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)

	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.bus = "Ambience"
	add_child(_ambience)


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	# All busy: steal the oldest rather than dropping the sound. A missing
	# footstep is more noticeable than a clipped one.
	return _pool3d[0]


func _free_2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	return _pool2d[0]


# --- Stream registry --------------------------------------------------------

func stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var s := _synth(id)
	if s:
		_streams[id] = s
	return s


func _synth(id: String) -> AudioStream:
	match id:
		"jump": return SfxForge.jump()
		"air_jump": return SfxForge.air_jump()
		"dash": return SfxForge.dash(false)
		"dash_charged": return SfxForge.dash(true)
		"life": return SfxForge.life()
		"hurt": return SfxForge.hurt()
		"shell": return SfxForge.shell()
		"ui": return SfxForge.ui_click()
		"wind": return SfxForge.wind()
	if id.begins_with("step_"):
		return SfxForge.footstep(id.substr(5), 0)
	if id.begins_with("land_"):
		return SfxForge.land(float(id.substr(5)))
	if id.begins_with("collect_"):
		return SfxForge.collect(int(id.substr(8)))
	if id.begins_with("shot_"):
		return SfxForge.gunshot(int(id.substr(5)))
	push_warning("AudioDirector: unknown sound id " + id)
	return null


# --- Playback ---------------------------------------------------------------

func play(id: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(id)
	if s == null:
		return
	var p := _free_3d()
	p.stream = s
	p.global_position = at
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_2d(id: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	var s := stream(id)
	if s == null:
		return
	var p := _free_2d()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Collect sounds walk up a scale while the player keeps picking things up, so
## a Sriracha trail plays a phrase rather than repeating one click.
func play_collect(at: Vector3) -> void:
	play("collect_%d" % _combo, at, -3.0, randf_range(0.99, 1.01))
	_combo = mini(_combo + 1, COMBO_MAX)
	_combo_left = COMBO_WINDOW


func reset_combo() -> void:
	_combo = 0
	_combo_left = 0.0


func play_footstep(at: Vector3, surface := "concrete", speed_ratio := 1.0) -> void:
	play("step_" + surface, at, linear_to_db(clampf(0.35 + speed_ratio * 0.65, 0.05, 1.0)),
		randf_range(0.92, 1.08))


func play_land(at: Vector3, impact: float) -> void:
	var bucket := snappedf(clampf(impact, 0.0, 1.0), 0.25)
	play("land_%.2f" % bucket, at, 0.0, randf_range(0.96, 1.04))


func play_shot(at: Vector3) -> void:
	play("shot_%d" % (randi() % 4), at, -2.0, randf_range(0.96, 1.05))


func set_ambience(id: String, volume_db := -12.0) -> void:
	var s := stream(id)
	if s == null:
		return
	_ambience.stream = s
	_ambience.volume_db = volume_db
	_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()
