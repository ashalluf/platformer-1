extends Node
## MusicDirector — layered, synthesised score.
##
## Every theme is the same five stems at the same tempo and length: pad, bass,
## darbuka, oud, tension. They are started together and never restarted, so they
## stay in phase forever; intensity is a mix decision, not a different track.
## That means combat can come in on the next frame instead of the next bar.
##
## Stems are rendered on a worker thread, because synthesising a four-bar loop
## at 22 kHz is a second or two of arithmetic and the game should not wait.

const LAYER_NAMES := MusicForge.LAYER_NAMES
const MIX := MusicForge.MIX

var intensity := 0.0
var _players: Array[AudioStreamPlayer] = []
var _theme := ""
var _cache: Dictionary = {}
var _thread: Thread
var _pending := ""
var _target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in LAYER_NAMES.size():
		var p := AudioStreamPlayer.new()
		p.name = "Music_" + LAYER_NAMES[i]
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	# Intensity eases; a hard cut between layers reads as a bug.
	intensity = lerpf(intensity, _target, 1.0 - exp(-2.2 * delta))
	if _theme == "":
		return
	for i in _players.size():
		var pair: Array = MIX[i]
		_players[i].volume_db = lerpf(pair[0], pair[1], clampf(intensity, 0.0, 1.0))


## 0 = exploring, 1 = everything on.
func set_intensity(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)


func play(theme: String, start_intensity := 0.25) -> void:
	if theme == _theme or not MusicForge.THEMES.has(theme):
		return
	_target = start_intensity
	intensity = start_intensity
	if _cache.has(theme):
		_start(theme)
		return
	_pending = theme
	if _thread and _thread.is_started():
		return
	_thread = Thread.new()
	_thread.start(_render_pending)


func stop() -> void:
	_theme = ""
	for p in _players:
		p.stop()


func _render_pending() -> void:
	var theme := _pending
	var stems := MusicForge.stems(theme)
	call_deferred("_on_rendered", theme, stems)


func _on_rendered(theme: String, stems: Array) -> void:
	_cache[theme] = stems
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	if _pending == theme:
		_start(theme)
		_pending = ""


## All five start on the same frame, which is what keeps them locked.
func _start(theme: String) -> void:
	_theme = theme
	var stems: Array = _cache[theme]
	for i in _players.size():
		_players[i].stream = stems[i]
		_players[i].volume_db = -60.0
		_players[i].play()


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_cache.clear()
