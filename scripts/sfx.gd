class_name Sfx
extends Node
## Every sound is generated here when the game starts (no audio files): casts, plops, bites,
## chimes, footsteps, bird calls and a soft water-and-wind bed.

const RATE := 22050
static var inst: Sfx

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bird_timer := 3.0
var muted := false

func _ready() -> void:
	inst = self
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["cast"] = _wav(_noise_sweep(0.3, 0.45))
	_streams["plop"] = _wav(_sweep(0.2, 520.0, 130.0, 0.6))
	_streams["bite"] = _wav(_blips([[0.0, 950.0], [0.1, 950.0]], 0.06, 0.2, 0.55))
	_streams["catch"] = _wav(_blips([[0.0, 523.0], [0.09, 659.0], [0.18, 784.0], [0.27, 1047.0]], 0.22, 0.55, 0.5))
	_streams["wrong"] = _wav(_buzz(0.32, 150.0))
	_streams["step"] = _wav(_thump(0.07))
	_streams["click"] = _wav(_blips([[0.0, 720.0]], 0.05, 0.06, 0.4))
	_streams["win"] = _wav(_blips([[0.0, 523.0], [0.12, 659.0], [0.24, 784.0], [0.36, 1047.0], [0.52, 1319.0]], 0.4, 0.95, 0.5))
	_streams["over"] = _wav(_blips([[0.0, 440.0], [0.18, 349.0], [0.36, 262.0]], 0.35, 0.75, 0.45))
	_streams["enter"] = _wav(_blips([[0.0, 587.0], [0.1, 880.0]], 0.2, 0.32, 0.4))
	_streams["bird"] = _wav(_bird())
	_streams["thunder"] = _wav(_rumble(1.4))
	# The bed: soft filtered noise, looped.
	var bed := _wav(_bed(4.0))
	bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed.loop_end = int(4.0 * RATE)
	var amb := AudioStreamPlayer.new()
	amb.stream = bed
	amb.volume_db = -24.0
	add_child(amb)
	amb.play()

func _process(delta: float) -> void:
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(2.5, 7.0)
		_play("bird", randf_range(0.8, 1.35), -16.0)

static func play(sound: String, pitch: float = 1.0, db: float = -6.0) -> void:
	if inst:
		inst._play(sound, pitch, db)

func _play(sound: String, pitch: float, db: float) -> void:
	if muted or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()

# ---------- generators (samples in -1..1) ----------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

## Short sine notes: [[start time, frequency], ...].
func _blips(notes: Array, note_len: float, dur: float, gain: float) -> PackedFloat32Array:
	var b := _buf(dur)
	for n: Array in notes:
		var start := int(float(n[0]) * RATE)
		var count := int(note_len * RATE)
		for i in count:
			if start + i >= b.size():
				break
			var t := float(i) / RATE
			var env := exp(-t * 9.0 / note_len * 0.35) * minf(1.0, t * 400.0)
			b[start + i] += (sin(TAU * float(n[1]) * t) + 0.3 * sin(TAU * float(n[1]) * 2.0 * t)) * env * gain
	return b

## A pitch that falls (a plop).
func _sweep(dur: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += TAU * lerpf(f0, f1, t) / RATE
		b[i] = sin(phase) * exp(-t * 5.0) * gain
	return b

## Air rushing past (the cast).
func _noise_sweep(dur: float, gain: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var last := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var k := lerpf(0.08, 0.6, t)
		last = lerpf(last, randf_range(-1.0, 1.0), k)
		b[i] = last * sin(PI * t) * gain
	return b

func _buzz(dur: float, freq: float) -> PackedFloat32Array:
	var b := _buf(dur)
	for i in b.size():
		var t := float(i) / RATE
		var s := signf(sin(TAU * freq * t)) * 0.5 + sin(TAU * freq * 0.5 * t) * 0.5
		b[i] = s * exp(-t * 6.0) * 0.45
	return b

func _thump(dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var last := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		last = lerpf(last, randf_range(-1.0, 1.0), 0.12)
		b[i] = (last + sin(TAU * 90.0 * t * dur) * 0.6) * exp(-t * 7.0) * 0.5
	return b

func _bird() -> PackedFloat32Array:
	var b := _buf(0.5)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var chirp := fmod(t, 0.16) / 0.16
		var f := 2600.0 + 1400.0 * chirp + 250.0 * sin(TAU * 28.0 * t)
		phase += TAU * f / RATE
		b[i] = sin(phase) * sin(PI * chirp) * (1.0 if t < 0.45 else 0.0) * 0.22
	return b

func _rumble(dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var last := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		last = lerpf(last, randf_range(-1.0, 1.0), 0.02)
		b[i] = last * exp(-t * 2.5) * 3.2
	return b

func _bed(dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var a := 0.0
	var c := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		a = lerpf(a, randf_range(-1.0, 1.0), 0.03)
		c = lerpf(c, randf_range(-1.0, 1.0), 0.25)
		# Fade the ends into each other so the loop has no click.
		var edge := minf(1.0, minf(t, 1.0 - t) * 12.0)
		b[i] = (a * 1.6 + c * 0.12 * (0.6 + 0.4 * sin(TAU * t * 3.0))) * edge
	return b

# ---------- speech: the device's own Tamil voice ----------

static var _voice := ""

## Reads Tamil text aloud with the device's Tamil voice, if it has one. Browsers load their
## voices a moment after the page opens, so the list is asked for again until a voice turns up.
## Where the device has no Tamil voice, nothing is said.
static func say(text: String, interrupt: bool = true) -> void:
	if inst == null or inst.muted:
		return
	if _voice == "":
		for v: Dictionary in DisplayServer.tts_get_voices():
			if str(v.get("language", "")).to_lower().begins_with("ta"):
				_voice = str(v.get("id", ""))
				break
	if _voice == "":
		return
	DisplayServer.tts_speak(text, _voice, 90, 1.0, 0.85, 0, interrupt)
