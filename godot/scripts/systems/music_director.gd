class_name MusicDirector
extends Node
## Director musical procedural: 3 capas en loop con fundido cruzado.
## Hijo de Main (lo cablea otro trabajo): sin escena propia, sin assets.
## Todo sintetizado en memoria como AudioStreamWAV 16-bit 22050 Hz
## (mismo patrón que AudioManager: encode_s16 + _to_stream).
##
## Capas (3 AudioStreamPlayer en bus "Master": respetan el mute global):
## - "calma": pad triangle con acordes lentos La-Do-Mi (Am -> F), 8 s.
## - "noche": notas sueltas espaciadas sine 220/174 Hz, 12 s.
## - "tensión": pulsos saw graves 110 Hz + redoble final, 4 s.
## Selección cada 1 s: tensión si hay raiders vivos en GameState,
## noche si DayNight.day_factor < 0.35, calma en otro caso.
## Fundido cruzado de 2 s por lerp, sin cortes (las 3 capas suenan siempre).
## Nulo-seguro: sin GameState/DayNight suena calma. Sin auto-quit.

const RATE := 22050
const CHECK_INTERVAL := 1.0 ## Revisión de la capa objetivo cada 1 s.
const FADE_TIME := 2.0 ## Fundido cruzado de 2 s.

const CALM_SECONDS := 8.0
const NIGHT_SECONDS := 12.0
const TENSION_SECONDS := 4.0

const CALM_DB := -30.0
const NIGHT_DB := -32.0
const TENSION_DB := -30.0
const SILENT_DB := -60.0 ## Suelo de la capa inactiva (inaudible, pero sigue sonando).

const NIGHT_THRESHOLD := 0.35

enum Layer { CALM, NIGHT, TENSION }
enum Wave { TRIANGLE, SINE, SAW }

var _calm: AudioStreamPlayer
var _night: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _target: int = Layer.CALM
var _timer := 0.0


func _ready() -> void:
	_calm = _make_player(_calm_stream(), SILENT_DB)
	_night = _make_player(_night_stream(), SILENT_DB)
	_tension = _make_player(_tension_stream(), SILENT_DB)
	# Estado inicial según contexto (evita el fundido de arranque).
	_target = _pick_target()
	_calm.volume_db = CALM_DB if _target == Layer.CALM else SILENT_DB
	_night.volume_db = NIGHT_DB if _target == Layer.NIGHT else SILENT_DB
	_tension.volume_db = TENSION_DB if _target == Layer.TENSION else SILENT_DB


func _process(delta: float) -> void:
	if _calm == null or _night == null or _tension == null:
		return
	_timer += delta
	if _timer >= CHECK_INTERVAL:
		_timer = 0.0
		_target = _pick_target()
	var k := clampf(delta / FADE_TIME, 0.0, 1.0)
	_calm.volume_db = _fade(_calm.volume_db, CALM_DB if _target == Layer.CALM else SILENT_DB, k)
	_night.volume_db = _fade(_night.volume_db, NIGHT_DB if _target == Layer.NIGHT else SILENT_DB, k)
	_tension.volume_db = _fade(_tension.volume_db, TENSION_DB if _target == Layer.TENSION else SILENT_DB, k)


func _fade(current: float, goal: float, k: float) -> float:
	var v := lerpf(current, goal, k)
	if absf(v - goal) < 0.05:
		v = goal
	return v


func _pick_target() -> int:
	if _has_live_raiders():
		return Layer.TENSION
	if _day_factor() < NIGHT_THRESHOLD:
		return Layer.NIGHT
	return Layer.CALM


## Nulo-seguro: sin GameState (o sin el array raiders) no hay tensión.
func _has_live_raiders() -> bool:
	if not is_inside_tree():
		return false
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return false
	var raiders: Variant = gs.get("raiders")
	return raiders is Array and not (raiders as Array).is_empty()


## Nulo-seguro (patrón de details.gd): sin DayNight se asume día (calma).
func _day_factor() -> float:
	if not ClassDB.class_exists("DayNight"):
		return 1.0
	var f: Variant = DayNight.day_factor
	if f is float or f is int:
		return float(f)
	return 1.0


func _make_player(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = volume_db
	p.stream = stream
	add_child(p)
	p.play()
	return p


# --- Síntesis (16-bit, loops sin clic) ---

## Pad triangle 8 s: Am (La-Do-Mi) 0-3 s, F (Fa-La-Do) 4-7 s, con
## fundidos raised-cosine de 1 s en [3,4] y [7,8]. En t=8 suena A puro y,
## por cuantización (_loop_freq), A(8 s) == A(0 s): el loop cierra exacto.
func _calm_stream() -> AudioStreamWAV:
	var n := int(RATE * CALM_SECONDS)
	var fa0 := _loop_freq(220.0, CALM_SECONDS) # La3
	var fa1 := _loop_freq(261.63, CALM_SECONDS) # Do4
	var fa2 := _loop_freq(329.63, CALM_SECONDS) # Mi4
	var fb0 := _loop_freq(174.61, CALM_SECONDS) # Fa3
	var fb1 := fa0 # La3
	var fb2 := fa1 # Do4
	var pa0 := 0.0
	var pa1 := 0.0
	var pa2 := 0.0
	var pb0 := 0.0
	var pb1 := 0.0
	var pb2 := 0.0
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		pa0 += fa0 / RATE
		pa1 += fa1 / RATE
		pa2 += fa2 / RATE
		pb0 += fb0 / RATE
		pb1 += fb1 / RATE
		pb2 += fb2 / RATE
		var w_b := _smooth(t - 3.0) * (1.0 - _smooth(t - 7.0))
		var w_a := 1.0 - w_b
		var va := (_wave_sample(Wave.TRIANGLE, pa0) + _wave_sample(Wave.TRIANGLE, pa1) + _wave_sample(Wave.TRIANGLE, pa2)) / 3.0
		var vb := (_wave_sample(Wave.TRIANGLE, pb0) + _wave_sample(Wave.TRIANGLE, pb1) + _wave_sample(Wave.TRIANGLE, pb2)) / 3.0
		# Oleaje de 8 s (período = loop): respira sin romper el ciclo.
		var swell := 0.7 + 0.3 * sin(TAU * t / CALM_SECONDS)
		data.encode_s16(i * 2, _to_s16((va * w_a + vb * w_b) * swell * 0.5))
	return _to_loop_stream(data, n)


## Noche 12 s: notas sueltas espaciadas (sine 220/174 Hz + leve 2º armónico),
## cada una con ataque/release en coseno. Silencio en ambos bordes del loop.
func _night_stream() -> AudioStreamWAV:
	var n := int(RATE * NIGHT_SECONDS)
	var f_hi := _loop_freq(220.0, NIGHT_SECONDS) # La3
	var f_lo := _loop_freq(174.61, NIGHT_SECONDS) # Fa3
	# [inicio, duración, freq]: 1-3 s, 5-7.5 s, 9-11 s (bordes en silencio).
	var notes := [[1.0, 2.0, f_hi], [5.0, 2.5, f_lo], [9.0, 2.0, f_hi]]
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for note in notes:
			if not (note is Array):
				continue
			var nb: Array = note
			var start := float(nb[0])
			var dur := float(nb[1])
			if t < start or t >= start + dur:
				continue
			var u := (t - start) / dur
			var env := _smooth(u / 0.3) * (1.0 - _smooth((u - 0.3) / 0.7))
			var f := float(nb[2])
			var dt := t - start
			v += (sin(TAU * f * dt) + 0.15 * sin(TAU * 2.0 * f * dt)) * env
		data.encode_s16(i * 2, _to_s16(v * 0.35))
	return _to_loop_stream(data, n)


## Tensión 4 s: colchón saw 55 Hz + 6 pulsos saw 110 Hz cada 0.5 s
## + redoble de 8 golpes saw 220 Hz en [3.0, 4.0). Todo cuantizado al
## loop y con envolventes que cierran en cero: sin clic.
func _tension_stream() -> AudioStreamWAV:
	var n := int(RATE * TENSION_SECONDS)
	var f_drone := _loop_freq(55.0, TENSION_SECONDS)
	var f_low := _loop_freq(110.0, TENSION_SECONDS)
	var f_hit := _loop_freq(220.0, TENSION_SECONDS)
	var ph_drone := 0.0
	var pulses: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]
	var rolls: Array[float] = []
	for k in 8:
		rolls.append(3.0 + float(k) * 0.125)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		ph_drone += f_drone / RATE
		var v := 0.18 * _wave_sample(Wave.SAW, ph_drone)
		for p in pulses:
			var d := t - p
			if d >= 0.0 and d < 0.35:
				v += _wave_sample(Wave.SAW, f_low * d) * _hit_env(d / 0.35) * 0.6
		for r in rolls:
			var d := t - r
			if d >= 0.0 and d < 0.11:
				v += _wave_sample(Wave.SAW, f_hit * d) * _hit_env(d / 0.11) * 0.35
		data.encode_s16(i * 2, _to_s16(v * 0.5))
	return _to_loop_stream(data, n)


## Golpe: ataque 10% en coseno y caída hasta cero (cierra en cero).
func _hit_env(u: float) -> float:
	return _smooth(u / 0.1) * (1.0 - clampf(u, 0.0, 1.0))


## Coseno elevado 0→1 (x en unidades de fundido, con clamp).
func _smooth(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return 0.5 - 0.5 * cos(t * PI)


## Cuantiza f al ciclo entero más cercano del loop: el oscilador cierra
## fase exacta al final (desafinación inaudible: <= 1/(2·segundos) Hz).
func _loop_freq(freq: float, seconds: float) -> float:
	return roundf(freq * seconds) / seconds


func _wave_sample(wave: int, phase: float) -> float:
	var frac := phase - floorf(phase)
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(frac - 0.5) - 1.0
		Wave.SINE:
			return sin(frac * TAU)
		_:
			return 2.0 * frac - 1.0


func _to_s16(v: float) -> int:
	return clampi(int(roundf(v * 32767.0)), -32768, 32767)


func _to_loop_stream(data: PackedByteArray, frames: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = frames
	return s
