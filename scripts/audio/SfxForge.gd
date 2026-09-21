class_name SfxForge
## Synthesises every sound in the game.
##
## No audio files ship with this project. Each sound is generated as PCM on
## first use and cached as an AudioStreamWAV. That keeps the asset rules clean,
## keeps the repo small, and — more usefully — makes a sound a set of numbers
## that can be tuned in the same pass as the thing it belongs to.

const RATE := 44100


# --- Synthesis primitives ---------------------------------------------------

class Osc extends RefCounted:
	var phase := 0.0

	func sine(freq: float, dt: float) -> float:
		phase = fmod(phase + freq * dt, 1.0)
		return sin(phase * TAU)

	func saw(freq: float, dt: float) -> float:
		phase = fmod(phase + freq * dt, 1.0)
		return phase * 2.0 - 1.0

	func square(freq: float, dt: float, duty := 0.5) -> float:
		phase = fmod(phase + freq * dt, 1.0)
		return 1.0 if phase < duty else -1.0

	func triangle(freq: float, dt: float) -> float:
		phase = fmod(phase + freq * dt, 1.0)
		return 4.0 * absf(phase - 0.5) - 1.0


## One-pole filters. Crude, cheap, and completely adequate for impact sounds.
class Filter extends RefCounted:
	var lp := 0.0
	var hp_prev_in := 0.0
	var hp_prev_out := 0.0

	func lowpass(x: float, cutoff: float, dt: float) -> float:
		var a: float = clampf(TAU * cutoff * dt, 0.0, 1.0)
		lp += a * (x - lp)
		return lp

	func highpass(x: float, cutoff: float, dt: float) -> float:
		var rc := 1.0 / maxf(TAU * cutoff, 0.0001)
		var a := rc / (rc + dt)
		var y := a * (hp_prev_out + x - hp_prev_in)
		hp_prev_in = x
		hp_prev_out = y
		return y


## Attack / decay / sustain / release, in seconds. `t` and `dur` in seconds.
static func adsr(t: float, dur: float, a: float, d: float, s: float, r: float) -> float:
	if t < a:
		return t / maxf(a, 0.0001)
	if t < a + d:
		return lerpf(1.0, s, (t - a) / maxf(d, 0.0001))
	if t < dur - r:
		return s
	return s * clampf((dur - t) / maxf(r, 0.0001), 0.0, 1.0)


## Exponential decay — the envelope almost every impact sound wants.
static func decay(t: float, rate: float) -> float:
	return exp(-t * rate)


static func to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var a := PackedFloat32Array()
	a.resize(n)
	return a


# --- Sounds -----------------------------------------------------------------

## Sand, concrete, metal grating. Filtered noise with a short body thump; the
## surface changes the filter, not the sample.
static func footstep(surface := "concrete", seed_ := 0) -> AudioStreamWAV:
	var dur := 0.13
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + seed_ * 7
	var f := Filter.new()
	var body := Osc.new()

	var cutoff := 2600.0
	var thump := 96.0
	var noise_gain := 0.55
	match surface:
		"sand":
			cutoff = 5200.0; thump = 60.0; noise_gain = 0.72
		"metal":
			cutoff = 5800.0; thump = 320.0; noise_gain = 0.42
		"wood":
			cutoff = 2000.0; thump = 150.0; noise_gain = 0.40

	for i in buf.size():
		var t := float(i) * dt
		var env := decay(t, 42.0)
		var n := f.lowpass(rng.randf_range(-1.0, 1.0), cutoff, dt) * noise_gain
		var b := body.sine(thump * (1.0 - t * 2.0), dt) * 0.5 * decay(t, 70.0)
		buf[i] = (n + b) * env * 0.55
	return to_stream(buf)


## Jump: a short upward chirp with body. Rising pitch is the whole read.
static func jump() -> AudioStreamWAV:
	var dur := 0.20
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var o := Osc.new()
	var o2 := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		var k := t / dur
		var f := lerpf(210.0, 520.0, k * k)
		var env := adsr(t, dur, 0.004, 0.05, 0.55, 0.12)
		buf[i] = (o.triangle(f, dt) * 0.7 + o2.sine(f * 2.01, dt) * 0.3) * env * 0.42
	return to_stream(buf)


## Double jump: higher, brighter, with a flutter so it is audibly the second one.
static func air_jump() -> AudioStreamWAV:
	var dur := 0.24
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var o := Osc.new()
	var o2 := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		var k := t / dur
		var flutter := 1.0 + sin(t * 70.0) * 0.06
		var f := lerpf(330.0, 780.0, sqrt(k)) * flutter
		var env := adsr(t, dur, 0.003, 0.06, 0.45, 0.14)
		buf[i] = (o.sine(f, dt) * 0.6 + o2.triangle(f * 1.5, dt) * 0.4) * env * 0.38
	return to_stream(buf)


## Landing. `impact` 0..1 deepens and lengthens it.
static func land(impact := 0.5) -> AudioStreamWAV:
	var dur := lerpf(0.13, 0.30, impact)
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var f := Filter.new()
	var o := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		var env := decay(t, lerpf(48.0, 22.0, impact))
		var thud := o.sine(lerpf(120.0, 62.0, impact) * (1.0 - t * 1.4), dt)
		var grit := f.lowpass(rng.randf_range(-1.0, 1.0), 1800.0, dt) * 0.5
		buf[i] = (thud * 0.8 + grit * lerpf(0.25, 0.6, impact)) * env * lerpf(0.35, 0.8, impact)
	return to_stream(buf)


## The Heat Dash. A darbuka hit under a noise whoosh — the percussion is the
## identity, per DESIGN.md.
static func dash(charged := false) -> AudioStreamWAV:
	var dur := 0.34 if charged else 0.26
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var f := Filter.new()
	var head := Osc.new()
	var ring := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		var k := t / dur
		# Membrane: a fast downward pitch sweep is what makes a drum a drum.
		var drum_f := lerpf((220.0 if charged else 180.0), 68.0, sqrt(k))
		var drum := head.sine(drum_f, dt) * decay(t, 26.0)
		var snap := ring.sine(drum_f * 3.1, dt) * decay(t, 90.0) * 0.35
		# Whoosh: band-passed noise swelling then closing.
		var swell := sin(PI * clampf(k * 1.15, 0.0, 1.0))
		var n := f.lowpass(rng.randf_range(-1.0, 1.0), lerpf(900.0, 5200.0, k), dt)
		buf[i] = (drum * 0.75 + snap + n * 0.40 * swell) * (0.85 if charged else 0.6)
	return to_stream(buf)


## Collectible pickup. `step` walks up a maqam-flavoured scale so a trail plays
## a phrase instead of the same click forty times.
const SCALE := [0, 1, 4, 5, 7, 8, 11, 12]   ## Hijaz — the North African colour

static func collect(step := 0) -> AudioStreamWAV:
	var dur := 0.20
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var degree: int = SCALE[step % SCALE.size()]
	var octave: int = step / SCALE.size()
	var freq: float = 523.25 * pow(2.0, (degree + octave * 12) / 12.0)
	var o := Osc.new()
	var o2 := Osc.new()
	var o3 := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		var env := decay(t, 16.0)
		# Struck-metal partials, not a pure tone.
		var s := o.sine(freq, dt) * 0.55
		s += o2.sine(freq * 2.76, dt) * 0.25 * decay(t, 30.0)
		s += o3.sine(freq * 5.40, dt) * 0.12 * decay(t, 55.0)
		buf[i] = s * env * 0.34
	return to_stream(buf)


## Tuna sandwich — an extra life. A rising three-note flourish.
static func life() -> AudioStreamWAV:
	var dur := 0.62
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var notes := [523.25, 698.46, 1046.50]
	var oscs := [Osc.new(), Osc.new(), Osc.new()]
	for i in buf.size():
		var t := float(i) * dt
		var s := 0.0
		for n in notes.size():
			var start := n * 0.11
			if t < start:
				continue
			var lt := t - start
			s += (oscs[n] as Osc).sine(notes[n], dt) * decay(lt, 7.0) * 0.30
		buf[i] = s
	return to_stream(buf)


## Rifle. Noise crack over a low body thump, with a short tail.
static func gunshot(seed_ := 0) -> AudioStreamWAV:
	var dur := 0.26
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1301 + seed_ * 13
	var lp := Filter.new()
	var hp := Filter.new()
	var body := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		var crack := hp.highpass(rng.randf_range(-1.0, 1.0), 900.0, dt) * decay(t, 130.0)
		var tail := lp.lowpass(rng.randf_range(-1.0, 1.0), 2400.0, dt) * decay(t, 24.0) * 0.30
		var thump := body.sine(78.0 * (1.0 - t * 1.6), dt) * decay(t, 42.0) * 0.55
		buf[i] = (crack * 0.85 + tail + thump) * 0.62
	return to_stream(buf)


static func shell() -> AudioStreamWAV:
	var dur := 0.16
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var a := Osc.new()
	var b := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		buf[i] = (a.sine(2350.0, dt) * 0.6 + b.sine(3710.0, dt) * 0.4) \
			* decay(t, 46.0) * 0.16
	return to_stream(buf)


static func hurt() -> AudioStreamWAV:
	var dur := 0.30
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var o := Osc.new()
	var f := Filter.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in buf.size():
		var t := float(i) * dt
		var k := t / dur
		var freq := lerpf(340.0, 110.0, sqrt(k))
		var s := o.saw(freq, dt) * 0.5
		s += f.lowpass(rng.randf_range(-1.0, 1.0), 1400.0, dt) * 0.3
		buf[i] = s * decay(t, 12.0) * 0.45
	return to_stream(buf)


## Wind bed for ambience. Loops; the modulation period is chosen so the seam is
## inaudible.
static func wind(seconds := 6.0) -> AudioStreamWAV:
	var buf := _buf(seconds)
	var dt := 1.0 / float(RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 220
	var f1 := Filter.new()
	var f2 := Filter.new()
	for i in buf.size():
		var t := float(i) * dt
		# Two gust rates whose periods divide the loop length exactly.
		var g1 := 0.5 + 0.5 * sin(TAU * t / seconds * 2.0)
		var g2 := 0.5 + 0.5 * sin(TAU * t / seconds * 5.0 + 1.3)
		var gust := 0.25 + 0.75 * (g1 * 0.6 + g2 * 0.4)
		var n := f1.lowpass(rng.randf_range(-1.0, 1.0), lerpf(320.0, 1500.0, gust), dt)
		n = f2.highpass(n, 90.0, dt)
		buf[i] = n * gust * 0.30
	return to_stream(buf, true)


static func ui_click() -> AudioStreamWAV:
	var dur := 0.07
	var buf := _buf(dur)
	var dt := 1.0 / float(RATE)
	var o := Osc.new()
	for i in buf.size():
		var t := float(i) * dt
		buf[i] = o.square(1250.0, dt, 0.28) * decay(t, 95.0) * 0.16
	return to_stream(buf)
