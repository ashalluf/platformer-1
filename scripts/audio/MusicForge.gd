class_name MusicForge
## Synthesises the score. Nothing here is a sample.
##
## The old score was four bars of a dark maqam drone at 22 kHz mono, with the
## lead picking its notes at random -- which is a guarantee of no tune. This is
## the rewrite: 44.1 kHz stereo, eight bars, real chord movement under an
## authored hook that a person could hum back.
##
## The sound is eastern Libya's green side -- Jebel Akhdar, not the sand sea.
## Marimba and kalimba carry the melody because struck wood is the brightest
## tuned sound there is, the pads are major sevenths and add-nines so the
## harmony glows rather than broods, and the percussion is a full hand-drum kit
## instead of one darbuka. Hijaz is still in here, but as an accent inside a
## major home rather than the whole world, so the music reads Libyan without
## reading sombre.
##
## Stems are rendered once as PCM and layered by MusicDirector, so intensity is
## a mix decision and combat can enter on the next frame, not the next bar.

const RATE := 44100
const BARS := 8
const STEPS := 16            ## sixteenths per bar

enum Layer { PAD, BASS, DRUMS, LEAD, SHIMMER }

const LAYER_NAMES := ["pad", "bass", "drums", "lead", "shimmer"]

## Mix level in dB per layer, at intensity 0 and at intensity 1.
const MIX := {
	Layer.PAD:     [-11.0, -9.0],
	Layer.BASS:    [-15.0, -6.0],
	Layer.DRUMS:   [-22.0, -5.0],
	Layer.LEAD:    [-17.0, -7.0],
	Layer.SHIMMER: [-30.0, -11.0],
}

# --- Harmony ----------------------------------------------------------------

## Major pentatonic. The hook lives here: it has no semitone clashes, so it
## stays consonant over every chord in every progression below. That is the
## whole reason a fixed melody can sit over moving harmony without minding.
const PENT := [0, 2, 4, 7, 9]

## Hijaz, kept for accent phrases -- the augmented second is the single most
## recognisable interval in North African music and the identity rests on it.
const HIJAZ := [0, 1, 4, 5, 7, 8, 11]

## Chords as semitone offsets from the tonic. Sevenths and ninths throughout:
## a bare triad is what makes synthesised music sound like a test tone.
const CH_I    := [0, 4, 7, 11, 14]      ## Imaj9
const CH_IV   := [5, 9, 12, 16, 19]     ## IVmaj9
const CH_V    := [7, 11, 14, 17]        ## V7
const CH_VI   := [9, 12, 16, 19]        ## vi7
const CH_III  := [4, 7, 11, 14]         ## iii7
const CH_bVII := [10, 14, 17, 21]       ## bVII -- the Mixolydian lift

## Per theme: tempo, tonic, the eight-bar progression, which hook, how bright
## the pad filter opens, and the seed for everything stochastic.
const THEMES := {
	"brega": {
		"bpm": 112.0, "root": 130.81, "bright": 0.62, "seed": 7, "hook": 0,
		"prog": [CH_I, CH_bVII, CH_IV, CH_I, CH_VI, CH_bVII, CH_IV, CH_V],
	},
	"ajdabiya": {
		"bpm": 124.0, "root": 146.83, "bright": 0.80, "seed": 23, "hook": 1,
		"prog": [CH_I, CH_V, CH_VI, CH_IV, CH_I, CH_V, CH_IV, CH_IV],
	},
	"ice": {
		"bpm": 118.0, "root": 164.81, "bright": 0.94, "seed": 19, "hook": 2,
		"prog": [CH_I, CH_III, CH_IV, CH_V, CH_I, CH_VI, CH_IV, CH_V],
	},
	"title": {
		"bpm": 100.0, "root": 130.81, "bright": 0.70, "seed": 41, "hook": 0,
		"prog": [CH_I, CH_I, CH_IV, CH_IV, CH_VI, CH_bVII, CH_I, CH_I],
	},
}

## Authored two-bar motifs: [sixteenth, semitone above tonic, length in
## sixteenths]. Written to be singable -- that is the entire point, and it is
## what the random walk this replaces could never produce.
const HOOKS := [
	# 0 -- the march. Rising, confident, lands on the fifth.
	[[0, 7, 3], [3, 9, 3], [6, 12, 4], [10, 9, 2], [12, 7, 4],
	 [16, 12, 3], [19, 14, 3], [22, 16, 4], [26, 14, 2], [28, 12, 4]],
	# 1 -- the street. Faster, skipping, answers itself.
	[[0, 12, 2], [2, 14, 2], [4, 16, 4], [8, 14, 2], [10, 12, 2], [12, 9, 4],
	 [16, 7, 2], [18, 9, 2], [20, 12, 4], [24, 16, 3], [27, 19, 5]],
	# 2 -- the glacier. Wide leaps, lots of air between notes.
	[[0, 19, 4], [4, 16, 4], [8, 12, 6], [16, 21, 4], [20, 19, 4], [24, 16, 8]],
]

# --- Buffers ----------------------------------------------------------------

static func bar_seconds(bpm: float) -> float:
	return 4.0 * 60.0 / bpm


static func note_hz(root_hz: float, semitones: int) -> float:
	return root_hz * pow(2.0, float(semitones) / 12.0)


static func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(RATE * seconds))
	return a


## Write one sample into a stereo pair with equal-power panning. `pan` is -1
## hard left to +1 hard right.
static func _add(l: PackedFloat32Array, r: PackedFloat32Array, at: int,
		value: float, pan := 0.0) -> void:
	if at < 0 or at >= l.size():
		return
	var a := (clampf(pan, -1.0, 1.0) + 1.0) * 0.25 * PI
	l[at] += value * cos(a)
	r[at] += value * sin(a)


## Interleave to a looping 16-bit stereo stream.
static func _to_stream(l: PackedFloat32Array, r: PackedFloat32Array) -> AudioStreamWAV:
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
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


## Ping-pong delay, wrapped around the loop end so the tail of bar 8 feeds the
## head of bar 1 and the seam cannot be heard.
static func _echo(l: PackedFloat32Array, r: PackedFloat32Array,
		delay_s: float, feedback: float, wet: float) -> void:
	var d := int(delay_s * RATE)
	if d <= 0:
		return
	var n := l.size()
	for i in n:
		var src := (i - d + n) % n
		l[i] += r[src] * feedback * wet
		r[i] += l[src] * feedback * wet


# --- Stems ------------------------------------------------------------------

## All five stems for a theme, in Layer order.
static func stems(theme: String) -> Array:
	var t: Dictionary = THEMES[theme]
	var prog: Array = t["prog"]
	return [
		pad(t["bpm"], t["root"], prog, t["bright"]),
		bass(t["bpm"], t["root"], prog),
		drums(t["bpm"], t["seed"]),
		lead(t["bpm"], t["root"], t["hook"], t["seed"]),
		shimmer(t["bpm"], t["root"], prog, t["seed"]),
	]


## Pad: the chord bed. Detuned saws through a breathing filter, re-voiced every
## bar by the progression. This is the layer that stops the loop being a drone.
static func pad(bpm: float, root_hz: float, prog: Array, bright := 0.6) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var total := bar * BARS
	var l := _buf(total)
	var r := _buf(total)
	var dt := 1.0 / float(RATE)
	var detune := [0.997, 1.0, 1.003, 0.9985, 1.0045]
	var lp_l := 0.0
	var lp_r := 0.0

	for b in BARS:
		var chord: Array = prog[b % prog.size()]
		var start := int(b * bar * RATE)
		var n := int(bar * RATE)
		var phases := []
		phases.resize(chord.size())
		phases.fill(0.0)
		for j in n:
			var t := float(j) * dt
			# Each bar swells in and out so chord changes glide rather than cut.
			var env := sin(PI * clampf(t / bar, 0.0, 1.0))
			env = 0.35 + 0.65 * env
			var cutoff := lerpf(380.0, 3200.0, bright) * (0.7 + 0.3 * sin(TAU * t / bar))
			var s := 0.0
			for v in chord.size():
				# An octave down on the lowest voice gives the bed some floor.
				var semis: int = chord[v] - (12 if v == 0 else 0)
				var f := note_hz(root_hz, semis) * float(detune[v % detune.size()])
				phases[v] = fmod(float(phases[v]) + f * dt, 1.0)
				s += (float(phases[v]) * 2.0 - 1.0) * (0.26 - float(v) * 0.035)
			var a := clampf(TAU * cutoff * dt, 0.0, 1.0)
			lp_l += a * (s - lp_l)
			lp_r += a * 0.97 * (s - lp_r)     # the channels drift, which is the width
			var at := start + j
			if at < l.size():
				l[at] += lp_l * env * 0.26
				r[at] += lp_r * env * 0.26
	return _to_stream(l, r)


## Bass: chord roots with an octave lift on the back half of each bar, so the
## floor moves instead of sitting.
static func bass(bpm: float, root_hz: float, prog: Array) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var l := _buf(bar * BARS)
	var r := _buf(bar * BARS)
	var dt := 1.0 / float(RATE)
	var step := bar / float(STEPS)
	# Root on 1, root on the and-of-2, fifth on 3, octave pickup on the and-of-4.
	var figure := [[0, 0], [6, 0], [8, 7], [11, 0], [14, 12]]

	for b in BARS:
		var chord: Array = prog[b % prog.size()]
		var base: int = int(chord[0]) - 24
		for f in figure:
			var semis: int = base + int(f[1])
			var hz := note_hz(root_hz, semis)
			var start := int((b * bar + float(f[0]) * step) * RATE)
			var n := int(step * 2.1 * RATE)
			var phase := 0.0
			var saw := 0.0
			for j in n:
				var t := float(j) * dt
				var env: float = minf(t * 90.0, 1.0) * exp(-t * 3.4)
				phase = fmod(phase + hz * dt, 1.0)
				saw = fmod(saw + hz * dt, 1.0)
				var s := sin(phase * TAU) * 0.70 + (saw * 2.0 - 1.0) * 0.16
				_add(l, r, start + j, s * env * 0.52, 0.0)
	return _to_stream(l, r)


## Percussion: a hand-drum kit, not one darbuka. Kick and doum hold the centre,
## congas and shaker sit out to the sides, and the eighth bar takes a fill.
static func drums(bpm: float, seed_ := 7) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var l := _buf(bar * BARS)
	var r := _buf(bar * BARS)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var step := bar / float(STEPS)

	#                 1 e & a 2 e & a 3 e & a 4 e & a
	var kick   := [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0]
	var snare  := [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1]
	var shaker := [2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1]
	var conga  := [0, 0, 1, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 2, 1, 0]

	for b in BARS:
		var fill := b == BARS - 1
		for i in STEPS:
			var at := int((b * bar + i * step) * RATE)
			if kick[i] == 1 and not (fill and i >= 12):
				_kick(l, r, at, dt)
			if snare[i] == 1:
				_snare(l, r, at, rng, dt, 0.0)
			if shaker[i] > 0:
				_shaker(l, r, at, rng, dt, 0.55, 0.30 if shaker[i] == 2 else 0.16)
			if conga[i] > 0:
				var hi: bool = conga[i] == 2
				_conga(l, r, at, dt, -0.5 if hi else 0.45, hi)
		if fill:
			# Tom run into the downbeat: the thing that tells you the loop turned.
			for k in 6:
				var at2 := int((b * bar + (12.0 + k * 0.62) * step) * RATE)
				_conga(l, r, at2, dt, lerpf(-0.6, 0.6, float(k) / 5.0), k % 2 == 1)
				_shaker(l, r, at2, rng, dt, 0.7, 0.22)
	return _to_stream(l, r)


static func _kick(l: PackedFloat32Array, r: PackedFloat32Array, start: int, dt: float) -> void:
	var n := int(0.40 * RATE)
	var phase := 0.0
	for j in n:
		var t := float(j) * dt
		var f := lerpf(165.0, 48.0, clampf(t * 13.0, 0.0, 1.0))
		phase = fmod(phase + f * dt, 1.0)
		var s := sin(phase * TAU) * exp(-t * 9.0)
		s += sin(phase * TAU * 2.0) * exp(-t * 40.0) * 0.20
		_add(l, r, start + j, s * 0.95, 0.0)


static func _snare(l: PackedFloat32Array, r: PackedFloat32Array, start: int,
		rng: RandomNumberGenerator, dt: float, pan: float) -> void:
	var n := int(0.20 * RATE)
	var hp := 0.0
	var phase := 0.0
	for j in n:
		var t := float(j) * dt
		var white := rng.randf_range(-1.0, 1.0)
		hp += (white - hp) * 0.42
		var s := (white - hp) * exp(-t * 26.0) * 0.8
		phase = fmod(phase + 235.0 * dt, 1.0)
		s += sin(phase * TAU) * exp(-t * 34.0) * 0.28
		_add(l, r, start + j, s * 0.46, pan)


static func _shaker(l: PackedFloat32Array, r: PackedFloat32Array, start: int,
		rng: RandomNumberGenerator, dt: float, pan: float, gain: float) -> void:
	var n := int(0.07 * RATE)
	var hp := 0.0
	for j in n:
		var t := float(j) * dt
		var white := rng.randf_range(-1.0, 1.0)
		hp += (white - hp) * 0.70
		# Soft attack: a shaker is a swarm of beads, not a click.
		var env: float = minf(t * 120.0, 1.0) * exp(-t * 48.0)
		_add(l, r, start + j, (white - hp) * env * gain, pan)


static func _conga(l: PackedFloat32Array, r: PackedFloat32Array, start: int,
		dt: float, pan: float, high: bool) -> void:
	var n := int(0.24 * RATE)
	var f0 := 305.0 if high else 190.0
	var phase := 0.0
	for j in n:
		var t := float(j) * dt
		var f := lerpf(f0 * 1.5, f0, clampf(t * 26.0, 0.0, 1.0))
		phase = fmod(phase + f * dt, 1.0)
		var s := sin(phase * TAU) * exp(-t * 14.0)
		s += sin(phase * TAU * 2.61) * exp(-t * 30.0) * 0.22
		_add(l, r, start + j, s * 0.40, pan)


## Lead: marimba. Struck wood is the brightest tuned sound there is, and its
## strong partial two octaves up is what makes it read as marimba and not as a
## sine. Plays the authored hook, an octave up on the third phrase, and answers
## with a Hijaz turn on the last two bars so the identity lands.
static func lead(bpm: float, root_hz: float, hook_index: int, seed_ := 3) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var l := _buf(bar * BARS)
	var r := _buf(bar * BARS)
	var dt := 1.0 / float(RATE)
	var step := bar / float(STEPS)
	var hook: Array = HOOKS[hook_index % HOOKS.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_

	# Bars 0-1 state it, 2-3 restate an octave up, 4-5 state it again, 6-7 answer.
	for phrase in 4:
		var shift := 12 if phrase == 1 else 0
		var pan := lerpf(-0.22, 0.22, float(phrase) / 3.0)
		if phrase == 3:
			# The answer: Hijaz, descending, deliberately not the hook.
			for k in 6:
				var semis: int = 12 + HIJAZ[(5 - k) % HIJAZ.size()]
				var at := int((6 * bar + k * 2.0 * step) * RATE)
				_marimba(l, r, at, note_hz(root_hz, semis), dt, 1.9 * step, 0.30, pan)
			continue
		for note in hook:
			var semis2: int = int(note[1]) + shift
			var at2 := int((phrase * 2 * bar + float(note[0]) * step) * RATE)
			var dur := float(note[2]) * step
			_marimba(l, r, at2, note_hz(root_hz, semis2), dt, dur, 0.34, pan)

	_echo(l, r, bar / 8.0, 0.34, 0.5)
	return _to_stream(l, r)


static func _marimba(l: PackedFloat32Array, r: PackedFloat32Array, start: int,
		hz: float, dt: float, dur: float, gain: float, pan: float) -> void:
	var n := int(minf(dur * 2.6, 1.3) * RATE)
	var p1 := 0.0
	var p4 := 0.0
	var p10 := 0.0
	for j in n:
		var t := float(j) * dt
		# Fast mallet attack, long woody tail.
		var env: float = minf(t * 420.0, 1.0) * exp(-t * 4.2)
		p1 = fmod(p1 + hz * dt, 1.0)
		p4 = fmod(p4 + hz * 4.0 * dt, 1.0)
		p10 = fmod(p10 + hz * 9.2 * dt, 1.0)
		var s := sin(p1 * TAU) * 0.72
		s += sin(p4 * TAU) * 0.20 * exp(-t * 11.0)     # the marimba partial
		s += sin(p10 * TAU) * 0.08 * exp(-t * 34.0)    # mallet knock
		_add(l, r, start + j, s * env * gain, pan)


## Shimmer: kalimba arpeggios high above the chord, wide and drenched in echo.
## This is the glitter that comes up with intensity -- the old tension layer was
## a dissonant drone, which is the wrong feeling for this game entirely.
static func shimmer(bpm: float, root_hz: float, prog: Array, seed_ := 11) -> AudioStreamWAV:
	var bar := bar_seconds(bpm)
	var l := _buf(bar * BARS)
	var r := _buf(bar * BARS)
	var dt := 1.0 / float(RATE)
	var step := bar / float(STEPS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_

	for b in BARS:
		var chord: Array = prog[b % prog.size()]
		for i in range(0, STEPS, 2):
			# Walk the chord up and down instead of choosing at random.
			var idx := i / 2
			var up := (b % 2) == 0
			var pick: int = idx % chord.size() if up else (chord.size() - 1 - idx % chord.size())
			var semis: int = int(chord[pick]) + 24
			var at := int((b * bar + i * step) * RATE)
			var pan := sin(float(idx) * 0.9) * 0.6
			_kalimba(l, r, at, note_hz(root_hz, semis), dt, 0.22 + rng.randf() * 0.06, pan)

	_echo(l, r, bar * 0.375, 0.42, 0.62)
	return _to_stream(l, r)


static func _kalimba(l: PackedFloat32Array, r: PackedFloat32Array, start: int,
		hz: float, dt: float, gain: float, pan: float) -> void:
	var n := int(0.7 * RATE)
	var p1 := 0.0
	var p3 := 0.0
	for j in n:
		var t := float(j) * dt
		var env: float = minf(t * 700.0, 1.0) * exp(-t * 6.5)
		p1 = fmod(p1 + hz * dt, 1.0)
		p3 = fmod(p3 + hz * 3.0 * dt, 1.0)
		var s := sin(p1 * TAU) * 0.8 + sin(p3 * TAU) * 0.16 * exp(-t * 18.0)
		_add(l, r, start + j, s * env * gain, pan)
