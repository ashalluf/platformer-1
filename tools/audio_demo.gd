extends SceneTree
## Renders a demo of every synthesised sound to a WAV, so audio can be reviewed
## the same way screenshots are: by actually experiencing the output.
##
##   godot --path . --headless -s tools/audio_demo.gd

const RATE := 44100


func _init() -> void:
	var timeline := [
		# [time_seconds, sound]
		[0.05, SfxForge.footstep("concrete", 0)],
		[0.38, SfxForge.footstep("concrete", 1)],
		[0.71, SfxForge.footstep("concrete", 2)],
		[1.04, SfxForge.jump()],
		[1.52, SfxForge.air_jump()],
		[2.10, SfxForge.land(0.75)],
		[2.55, SfxForge.footstep("sand", 3)],
		[2.85, SfxForge.footstep("sand", 4)],
		[3.20, SfxForge.dash(false)],
		[3.90, SfxForge.dash(true)],
	]
	# A Sriracha trail: the pickup walks up the Hijaz scale.
	var t := 4.65
	for i in 9:
		timeline.append([t, SfxForge.collect(i)])
		t += 0.17
	timeline.append([6.45, SfxForge.life()])
	# Full auto, at the rifle's real 9.5 rounds per second.
	t = 7.45
	for i in 11:
		timeline.append([t, SfxForge.gunshot(i % 4)])
		timeline.append([t + 0.09, SfxForge.shell()])
		t += 1.0 / 9.5
	timeline.append([9.10, SfxForge.hurt()])

	var total := 10.4
	var mix := PackedFloat32Array()
	mix.resize(int(RATE * total))

	# Wind bed underneath the whole thing.
	var wind := SfxForge.wind(6.0)
	_mix_into(mix, _samples(wind), 0, 0.42, true)

	for entry: Array in timeline:
		_mix_into(mix, _samples(entry[1]), int(float(entry[0]) * RATE), 1.0, false)

	# Soft clip rather than hard clip: overlapping gunshots would otherwise
	# square off into a buzz.
	for i in mix.size():
		mix[i] = tanh(mix[i] * 1.25) * 0.92

	var out := SfxForge.to_stream(mix)
	var path := "res://docs/audio_demo.wav"
	var err := out.save_to_wav(path)
	print("audio demo -> %s (err=%d, %.1fs)" % [path, err, total])
	quit(0 if err == OK else 1)


func _samples(w: AudioStreamWAV) -> PackedFloat32Array:
	var data := w.data
	var n := data.size() / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = float(data.decode_s16(i * 2)) / 32768.0
	return out


func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at: int,
		gain: float, loop: bool) -> void:
	if loop:
		for i in dst.size():
			dst[i] += src[i % src.size()] * gain
		return
	for i in src.size():
		var j := at + i
		if j < 0 or j >= dst.size():
			continue
		dst[j] += src[i] * gain
