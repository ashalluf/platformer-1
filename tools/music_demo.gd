extends SceneTree
## Renders the score to a WAV so it can be listened to, the way captures let the
## art be looked at. Stereo, at MusicForge's own rate.
##
##   godot --path . --headless -s tools/music_demo.gd

const RATE := MusicForge.RATE


func _init() -> void:
	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	var sections := [
		# theme, loops, intensity at start, intensity at end
		["brega", 1, 0.15, 0.45],
		["brega", 1, 0.70, 1.00],
		["ajdabiya", 1, 0.40, 0.90],
		["ice", 1, 0.50, 1.00],
	]

	for spec: Array in sections:
		var theme: String = spec[0]
		var stems := MusicForge.stems(theme)
		var tracks := []
		for st: AudioStreamWAV in stems:
			tracks.append(_samples(st))
		var first: Array = tracks[0]
		var loop_len: int = (first[0] as PackedFloat32Array).size()
		var loops: int = spec[1]
		var start := out_l.size()
		out_l.resize(start + loop_len * loops)
		out_r.resize(start + loop_len * loops)

		for j in loop_len * loops:
			var k := float(j) / float(loop_len * loops)
			var inten: float = lerpf(spec[2], spec[3], k)
			var sl := 0.0
			var sr := 0.0
			for i in tracks.size():
				var pair: Array = MusicForge.MIX[i]
				var g: float = db_to_linear(lerpf(pair[0], pair[1], inten))
				var pair_arr: Array = tracks[i]
				var al: PackedFloat32Array = pair_arr[0]
				var ar: PackedFloat32Array = pair_arr[1]
				sl += al[j % al.size()] * g
				sr += ar[j % ar.size()] * g
			out_l[start + j] = sl
			out_r[start + j] = sr

	for i in out_l.size():
		out_l[i] = tanh(out_l[i] * 1.5) * 0.92
		out_r[i] = tanh(out_r[i] * 1.5) * 0.92

	var stream := _to_stream(out_l, out_r)
	var err := stream.save_to_wav("res://docs/music_demo.wav")
	print("music demo -> docs/music_demo.wav (err=%d, %.1fs stereo @ %d Hz)"
		% [err, float(out_l.size()) / RATE, RATE])
	quit(0 if err == OK else 1)


## Returns [left, right] for a stereo AudioStreamWAV.
func _samples(w: AudioStreamWAV) -> Array:
	var data := w.data
	var n := data.size() / 4
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	l.resize(n)
	r.resize(n)
	for i in n:
		l[i] = float(data.decode_s16(i * 4)) / 32768.0
		r[i] = float(data.decode_s16(i * 4 + 2)) / 32768.0
	return [l, r]


func _to_stream(l: PackedFloat32Array, r: PackedFloat32Array) -> AudioStreamWAV:
	var n := l.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in n:
		bytes.encode_s16(i * 4, int(clampf(l[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(clampf(r[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = true
	w.data = bytes
	return w
