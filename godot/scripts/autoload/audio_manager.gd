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
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Master"
	_ambient.volume_db = -28.0
	_ambient.stream = sounds["ambient"] as AudioStreamWAV
	add_child(_ambient)
	_ambient.play()


# --- Síntesis ---

## Barrido de frecuencia con una sola forma de onda.
func _sweep(wave: int, f0: float, f1: float, seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / float(maxi(n - 1, 1)))
		phase += f / RATE
		data[i] = _to_byte(_wave_sample(wave, phase) * _envelope(i, n) * 0.5)
	return _to_stream(data)


## Secuencia de notas de igual duración con la misma forma de onda.
func _melody(wave: int, freqs: Array, note_seconds: float) -> AudioStreamWAV:
	var per := int(RATE * note_seconds)
	var data := PackedByteArray()
	data.resize(per * freqs.size())
	for ni in freqs.size():
		var f := float(freqs[ni])
		var phase := 0.0
		for i in per:
			phase += f / RATE
			data[ni * per + i] = _to_byte(_wave_sample(wave, phase) * _envelope(i, per) * 0.5)
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


func _to_byte(v: float) -> int:
	return clampi(int(roundf(v * 127.0)) + 128, 0, 255)


func _to_stream(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## Ruido blanco de 2 s en loop, suavizado con media móvil (lowpass aprox).
func _ambient_stream() -> AudioStreamWAV:
	var n := RATE * 2
	var window := 16
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		buf[i] = randf_range(-1.0, 1.0)
	var data := PackedByteArray()
	data.resize(n)
	var acc := 0.0
	for i in n:
		acc += buf[i]
		if i >= window:
			acc -= buf[i - window]
		var avg := acc / float(mini(i + 1, window))
		var edge := minf(1.0, float(mini(i, n - 1 - i)) / float(RATE / 4))
		data[i] = _to_byte(avg * edge * 0.5)
	var s := _to_stream(data)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s
