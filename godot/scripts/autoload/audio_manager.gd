extends Node
## AudioManager (autoload): SFX + ambiente 100% procedurales en memoria.
## Sin ficheros: los AudioStreamWAV se generan en _ready (8-bit 22050 Hz).

const RATE := 22050
const THROTTLE := 0.15
const POOL_SIZE := 8

enum Wave { TRIANGLE, SQUARE, SAW }

var sounds: Dictionary = {}
var muted := false

var _pool: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _last: Dictionary = {}


func _ready() -> void:
	_build_sounds()
	_build_pool()
	_start_ambient()


func play(name: String) -> void:
	if not sounds.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if name == "coin" or name == "hit":
		if now - float(_last.get(name, -10.0)) < THROTTLE:
			return
		_last[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = sounds[name] as AudioStreamWAV
			p.play()
			return
	# Pool saturado: recicla el primer canal.
	_pool[0].stream = sounds[name] as AudioStreamWAV
	_pool[0].play()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)


# --- Construcción de sonidos ---

func _build_sounds() -> void:
	sounds["build"] = _sweep(Wave.TRIANGLE, 200.0, 400.0, 0.3)
	sounds["coin"] = _melody(Wave.SQUARE, [988.0, 1319.0], 0.15)
	sounds["hit"] = _sweep(Wave.SAW, 150.0, 60.0, 0.3)
	sounds["alarm"] = _melody(Wave.SAW, [600.0, 450.0], 0.25)
	sounds["win"] = _melody(Wave.TRIANGLE, [523.0, 659.0, 784.0, 1046.0], 0.2)
	sounds["click"] = _sweep(Wave.SQUARE, 800.0, 800.0, 0.07)
	sounds["ambient"] = _ambient_stream()


func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _start_ambient() -> void:
	if _ambient != null and is_instance_valid(_ambient):
		return
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Master"
	_ambient.volume_db = -36.0
	_ambient.stream = sounds["ambient"] as AudioStreamWAV
	add_child(_ambient)
	_ambient.play()


# --- Síntesis ---

## Barrido de frecuencia con una sola forma de onda (16-bit, sin siseo).
func _sweep(wave: int, f0: float, f1: float, seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / float(maxi(n - 1, 1)))
		phase += f / RATE
		data.encode_s16(i * 2, _to_s16(_wave_sample(wave, phase) * _envelope(i, n) * 0.5))
	return _to_stream(data)


## Secuencia de notas de igual duración con la misma forma de onda.
func _melody(wave: int, freqs: Array, note_seconds: float) -> AudioStreamWAV:
	var per := int(RATE * note_seconds)
	var data := PackedByteArray()
	data.resize(per * freqs.size() * 2)
	for ni in freqs.size():
		var f := float(freqs[ni])
		var phase := 0.0
		for i in per:
			phase += f / RATE
			data.encode_s16((ni * per + i) * 2, _to_s16(_wave_sample(wave, phase) * _envelope(i, per) * 0.5))
	return _to_stream(data)


func _wave_sample(wave: int, phase: float) -> float:
	var frac := phase - floorf(phase)
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(frac - 0.5) - 1.0
		Wave.SQUARE:
			return 1.0 if frac < 0.5 else -1.0
		_:
			return 2.0 * frac - 1.0


## Ataque corto + caída al final para evitar clics.
func _envelope(i: int, n: int) -> float:
	if n <= 1:
		return 1.0
	var attack := maxi(1, int(n * 0.05))
	var tail := maxi(1, int(n * 0.15))
	var a := clampf(float(i) / float(attack), 0.0, 1.0)
	var d := clampf(float(n - 1 - i) / float(tail), 0.0, 1.0)
	return minf(a, d)


func _to_s16(v: float) -> int:
	return clampi(int(roundf(v * 32767.0)), -32768, 32767)


func _to_stream(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## Viento suave: ruido 4 s en loop con crossfade de 1 s (sin clic),
## lowpass fuerte (media de 64) y fundidos. 16-bit, volumen bajo.
func _ambient_stream() -> AudioStreamWAV:
	var n := RATE * 4
	var fade := RATE * 1
	var window := 64
	# Señal suavizada extendida para poder fundir el final con el inicio.
	var sm := PackedFloat32Array()
	sm.resize(n + fade)
	var buf := PackedFloat32Array()
	buf.resize(n + fade + window)
	for i in n + fade + window:
		buf[i] = randf_range(-1.0, 1.0)
	var acc := 0.0
	for i in n + fade:
		acc += buf[i + window / 2]
		if i >= window:
			acc -= buf[i - window + window / 2]
		sm[i] = acc / float(window)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = sm[i]
		if i >= n - fade:
			var w := float(i - (n - fade)) / float(fade)
			v = lerpf(sm[i], sm[i - (n - fade)], w)
		data.encode_s16(i * 2, _to_s16(v * 0.22))
	var s := _to_stream(data)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s
