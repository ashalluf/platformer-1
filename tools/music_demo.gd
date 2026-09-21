extends SceneTree
## Renders the score to a WAV so it can be listened to, the way captures let
## the art be looked at.
##
##   godot --path . --headless -s tools/music_demo.gd

const RATE := 22050


func _init() -> void:
	var out := PackedFloat32Array()
	var _unused := 0
	var sections := [
		# theme, loops, intensity at start, intensity at end
		["brega", 2, 0.15, 0.30],
		["brega", 2, 0.55, 1.00],
		["ice", 2, 0.45, 0.85],
	]

	for spec: Array in sections:
		var theme: String = spec[0]
		var t: Dictionary = MusicForge.THEMES[theme]
		var stems := MusicForge.stems(theme)
		var loop_len: int = _samples(stems[0]).size()
		var loops: int = spec[1]
		var start := out.size()
		out.resize(start + loop_len * loops)

		var tracks := []
		for st: AudioStreamWAV in stems:
			tracks.append(_samples(st))

		for j in loop_len * loops:
			var k := float(j) / float(loop_len * loops)
			var inten: float = lerpf(spec[2], spec[3], k)
			var s := 0.0
			for i in tracks.size():
				var pair: Array = MusicForge.MIX[i]
				var db: float = lerpf(pair[0], pair[1], inten)
				var arr: PackedFloat32Array = tracks[i]
				s += arr[j % arr.size()] * db_to_linear(db)
			out[start + j] = s

	for i in out.size():
		out[i] = tanh(out[i] * 1.4) * 0.9

	var stream := _to_stream(out)
	var err := stream.save_to_wav("res://docs/music_demo.wav")
	print("music demo -> docs/music_demo.wav (err=%d, %.1fs)" % [err, float(out.size()) / RATE])
	quit(0 if err == OK else 1)


func _samples(w: AudioStreamWAV) -> PackedFloat32Array:
	var data := w.data
	var n := data.size() / 2
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = float(data.decode_s16(i * 2)) / 32768.0
	return a


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
