class_name MusicForge
## Synthesises the score.
##
## The game's musical identity is Hijaz — the maqam whose augmented second
## between the second and third degrees is the single most recognisable sound in
## North African music — over a darbuka pulse, with a modern low end under it.
## Nothing here is a sample. Stems are rendered once as PCM loops and layered by
## MusicDirector, so intensity is a mix decision rather than a different track.
##
## Rendered at 22 kHz: this is pads, drums and a plucked lead, and the top
## octave it loses is octave the mix does not use.

const RATE := 22050

enum Layer { PAD, BASS, DRUMS, OUD, TENSION }

const LAYER_NAMES := ["pad", "bass", "drums", "oud", "tension"]
const BARS := 4

## Per-theme: tempo, tonic, lead register, pad register, filter brightness.
const THEMES := {
	"brega": {
		"bpm": 88.0, "root": 73.42, "lead": 293.66, "pad": 146.83,
		"bright": 0.32, "seed": 7,
	},
	"ice": {
		"bpm": 104.0, "root": 82.41, "lead": 329.63, "pad": 164.81,
		"bright": 0.85, "seed": 19,
	},
}

## Mix level in dB per layer, at intensity 0 and at intensity 1.
const MIX := {
	Layer.PAD: [-9.0, -7.0],
	Layer.BASS: [-16.0, -6.0],
	Layer.DRUMS: [-24.0, -5.0],
	Layer.OUD: [-30.0, -9.0],
	Layer.TENSION: [-60.0, -12.0],
}


## All five stems for a theme, in Layer order.
static func stems(theme: String) -> Array:
	var t: Dictionary = THEMES[theme]
	return [
		pad(BARS, t["bpm"], t["pad"], t["bright"]),
		bass(BARS, t["bpm"], t["root"]),
		darbuka(BARS, t["bpm"], t["seed"]),
		oud(BARS, t["bpm"], t["lead"], t["seed"] + 5),
		tension(BARS, t["bpm"], t["lead"] * 2.0),
	]


## Hijaz on the tonic: 1, b2, 3, 4, 5, b6, 7. Semitone offsets.
const HIJAZ := [0, 1, 4, 5, 7, 8, 11]
## The scale one fourth up, used for the answering phrase.
const HIJAZ_ALT := [5, 6, 9, 10, 12, 13, 16]


static func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(RATE * seconds))
	return a


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()
	return w


static func bar_seconds(bpm: float) -> float:
	return 4.0 * 60.0 / bpm


static func note_hz(root_hz: float, semitones: int) -> float:
	return root_hz * pow(2.0, float(semitones) / 12.0)


## Additive mix helper: writes `value` into `buf` at `at`, clipped to range.
static func _add(buf: PackedFloat32Array, at: int, value: float) -> void:
	if at < 0 or at >= buf.size():
		return
	buf[at] += value


# --- Stems ------------------------------------------------------------------

## Darbuka. Maqsoum: DOUM . TEK TEK | DOUM DOUM . TEK — the spine of the groove.
## Doum is a low membrane hit with a fast pitch drop; tek is a rim snap.
static func darbuka(bars := 4, bpm := 92.0, seed_ := 7) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var buf := _buf(bar * bars)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_

	# Sixteenth-note grid. 1 = doum, 2 = tek, 3 = ghost tek.
	var pattern := [1, 0, 0, 3, 2, 0, 2, 0, 1, 0, 1, 0, 0, 3, 2, 0]
	var step := bar / 16.0

	for b in bars:
		for i in pattern.size():
			var kind: int = pattern[i]
			if kind == 0:
				continue
			# Last bar gets a fill: extra ghost notes on the final beat.
			if b == bars - 1 and i >= 12 and kind == 0:
				kind = 3
			var start := int((b * bar + i * step) * RATE)
			_hit(buf, start, kind, rng, dt)

		if b == bars - 1:
			for k in 4:
				_hit(buf, int((b * bar + (12 + k) * step + step * 0.5) * RATE), 3, rng, dt)
	return _to_stream(buf)


static func _hit(buf: PackedFloat32Array, start: int, kind: int,
		rng: RandomNumberGenerator, dt: float) -> void:
	var dur := 0.34 if kind == 1 else 0.10
	var n := int(dur * RATE)
	var gain := 0.85 if kind == 1 else (0.45 if kind == 2 else 0.18)
	var phase := 0.0
	var lp := 0.0
	for j in n:
		var t := float(j) * dt
		var s := 0.0
		if kind == 1:
			# Doum: 150 Hz falling to 55, plus a short noise transient.
			var f := lerpf(150.0, 55.0, clampf(t * 9.0, 0.0, 1.0))
			phase = fmod(phase + f * dt, 1.0)
			s = sin(phase * TAU) * exp(-t * 11.0)
			s += rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.35
		else:
			# Tek: high band-passed noise with a short pitched ring.
			lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.55
			s = (rng.randf_range(-1.0, 1.0) - lp) * exp(-t * 55.0)
			phase = fmod(phase + 420.0 * dt, 1.0)
			s += sin(phase * TAU) * exp(-t * 70.0) * 0.25
		_add(buf, start + j, s * gain)


## Bass: the tonic with a fifth above it, pulsing on the beat. Deliberately
## simple — it is the floor the rest of the mix stands on.
static func bass(bars := 4, bpm := 92.0, root_hz := 73.42) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var buf := _buf(bar * bars)
	var dt := 1.0 / float(RATE)
	var beat := bar / 4.0
	# Root, root, fifth, b6 — the b6 is what keeps it in Hijaz.
	var degrees := [0, 0, 7, 8]

	for b in bars:
		for i in 4:
			var semis: int = degrees[i]
			if b % 2 == 1 and i == 3:
				semis = 5
			var f := note_hz(root_hz, semis)
			var start := int((b * bar + i * beat) * RATE)
			var n := int(beat * 0.92 * RATE)
			var phase := 0.0
			var sub := 0.0
			for j in n:
				var t := float(j) * dt
				var env: float = min(t * 60.0, 1.0) * exp(-t * 2.2)
				phase = fmod(phase + f * dt, 1.0)
				sub = fmod(sub + f * 0.5 * dt, 1.0)
				# Slight saw content gives it edge under the drums.
				var s := sin(phase * TAU) * 0.62 + (sub * 2.0 - 1.0) * 0.22
				_add(buf, start + j, s * env * 0.55)
	return _to_stream(buf)


## Oud-ish lead: a plucked line that walks the maqam. Phrases answer each other
## across the loop rather than repeating, which is what stops a four-bar loop
## sounding like a four-bar loop.
static func oud(bars := 4, bpm := 92.0, root_hz := 293.66, seed_ := 3) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var buf := _buf(bar * bars)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var eighth := bar / 8.0

	for b in bars:
		var scale: Array = HIJAZ if b % 2 == 0 else HIJAZ_ALT
		# Sparse: a note on roughly half the eighths, always landing on beat 1.
		for i in 8:
			if i != 0 and rng.randf() > 0.55:
				continue
			var degree: int = scale[rng.randi() % scale.size()]
			if i == 0:
				degree = scale[0]
			var f := note_hz(root_hz, degree)
			var start := int((b * bar + i * eighth) * RATE)
			var n := int(eighth * 2.4 * RATE)
			var phase := 0.0
			var p2 := 0.0
			for j in n:
				var t := float(j) * dt
				# Plucked: fast attack, long decay, a slightly detuned second
				# voice for the doubled-string sound an oud has.
				var env: float = min(t * 260.0, 1.0) * exp(-t * 4.6)
				phase = fmod(phase + f * dt, 1.0)
				p2 = fmod(p2 + f * 1.006 * dt, 1.0)
				var s := sin(phase * TAU) * 0.55 + sin(p2 * TAU) * 0.30
				s += sin(phase * TAU * 2.0) * 0.14 * exp(-t * 9.0)
				_add(buf, start + j, s * env * 0.34)
	return _to_stream(buf)


## Pad: a slow drone with two detuned voices and a breathing filter. This is the
## layer that carries mood, so it is the one that changes between levels.
static func pad(bars := 4, bpm := 92.0, root_hz := 146.83, bright := 0.5) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var total := bar * bars
	var buf := _buf(total)
	var dt := 1.0 / float(RATE)
	var voices := [0, 7, 12, 15]   ## root, fifth, octave, b6 above
	var phases := [0.0, 0.0, 0.0, 0.0]
	var detune := [1.0, 1.003, 0.997, 1.006]
	var lp := 0.0

	for j in buf.size():
		var t := float(j) * dt
		# Filter breathes once per loop, so the seam is inaudible.
		var cutoff := lerpf(420.0, 2400.0, bright) * (0.55 + 0.45 * sin(TAU * t / total))
		var s := 0.0
		for v in voices.size():
			var f: float = note_hz(root_hz, voices[v]) * float(detune[v])
			phases[v] = fmod(float(phases[v]) + f * dt, 1.0)
			# Saw, so the filter has something to work on.
			s += (float(phases[v]) * 2.0 - 1.0) * (0.30 - float(v) * 0.05)
		var a: float = clampf(TAU * cutoff * dt, 0.0, 1.0)
		lp += a * (s - lp)
		# Gentle swell across the loop.
		var env := 0.75 + 0.25 * sin(TAU * t / total - PI * 0.5)
		buf[j] = lp * env * 0.30
	return _to_stream(buf)


## Tension layer: a high shimmering drone that only comes in during combat.
static func tension(bars := 4, bpm := 92.0, root_hz := 587.33) -> AudioStreamWAV:
	var total := bar_seconds(bpm) * bars
	var buf := _buf(total)
	var dt := 1.0 / float(RATE)
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	for j in buf.size():
		var t := float(j) * dt
		# A minor second beating against itself: unease without a melody.
		p1 = fmod(p1 + root_hz * dt, 1.0)
		p2 = fmod(p2 + note_hz(root_hz, 1) * dt, 1.0)
		p3 = fmod(p3 + note_hz(root_hz, 8) * 0.5 * dt, 1.0)
		var trem := 0.72 + 0.28 * sin(TAU * t * 5.5)
		var env := 0.6 + 0.4 * sin(TAU * t / total)
		buf[j] = (sin(p1 * TAU) * 0.4 + sin(p2 * TAU) * 0.3 + sin(p3 * TAU) * 0.3) \
			* trem * env * 0.16
	return _to_stream(buf)
