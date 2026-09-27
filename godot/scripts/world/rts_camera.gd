class_name RtsCamera extends Camera3D
## Cámara RTS con objetivo suavizado.
##
## Controles (todo se lee con Input directo en _process, sin InputMap custom):
## - Botón central arrastrando o WASD / flechas: desplaza el objetivo (pan).
## - Rueda del ratón: zoom cambiando la distancia (limitada a 8..60).
## - Botón derecho arrastrando: rota el yaw (libre) y el pitch (clamp [-1.2, -0.35]).
## El objetivo se limita a x,z en ±32 y la posición se suaviza con lerp.

# --- Constantes de configuración ---
const MIN_DISTANCE := 8.0 # Distancia mínima de zoom.
const MAX_DISTANCE := 60.0 # Distancia máxima de zoom.
const PITCH_MIN := -1.2 # Pitch máximo hacia abajo (casi cenital).
const PITCH_MAX := -0.35 # Pitch mínimo (vista más horizontal).
const BOUND := 32.0 # Límite del objetivo en x,z.
const KEYBOARD_SPEED := 14.0 # Velocidad base del pan por teclado (m/s).
const DRAG_PAN_FACTOR := 0.0016 # Mundo por píxel y por metro de distancia (arrastre central).
const ROTATE_SPEED := 0.005 # Radianes por píxel (arrastre derecho).
const WHEEL_STEP := 2.0 # Metros por "clic" de rueda.
const SMOOTH := 10.0 # Factor de suavizado exponencial del lerp.

# --- Estado interno (valores objetivo; la cámara interpola hacia ellos) ---
var _target := Vector3.ZERO # Punto del suelo mirado (y siempre 0).
var _yaw := 0.7853982 # Rotación horizontal (radianes).
var _pitch := -0.7 # Inclinación (negativa = mirando hacia abajo).
var _distance := 30.0 # Distancia al objetivo (zoom).
var _last_mouse := Vector2.ZERO # Posición del ratón en el frame anterior.
var _has_mouse := false # True cuando _last_mouse ya es válido.


func _ready() -> void:
	# Reconstruye objetivo / yaw / pitch / distancia desde el transform colocado
	# en scenes/main.tscn (Main/Camera3D en 20,16,20 mirando al origen) para que
	# la cámara no pegue un salto al arrancar el juego.
	var origin := global_position
	var fwd := -global_transform.basis.z # Dirección de mirada de la cámara.
	if absf(fwd.y) > 0.0001:
		var t := -origin.y / fwd.y # Intersección del rayo de mirada con el plano y=0.
		if t > 0.0:
			_target = origin + fwd * t
	_target.y = 0.0
	var offset := origin - _target
	var length := offset.length()
	if length > 0.001:
		_distance = clampf(length, MIN_DISTANCE, MAX_DISTANCE)
		_yaw = atan2(offset.x, offset.z)
		# offset.y / length = sin(elevación); pitch = -elevación.
		_pitch = clampf(-asin(clampf(offset.y / length, -1.0, 1.0)), PITCH_MIN, PITCH_MAX)
	_target.x = clampf(_target.x, -BOUND, BOUND)
	_target.z = clampf(_target.z, -BOUND, BOUND)
	_last_mouse = get_viewport().get_mouse_position()
	_has_mouse = true


# Dirección "adelante" de la cámara proyectada sobre el suelo (para WASD).
func _ground_forward() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


# Dirección "derecha" de la cámara proyectada sobre el suelo (para WASD).
func _ground_right() -> Vector3:
	return Vector3(cos(_yaw), 0.0, -sin(_yaw))


func _process(delta: float) -> void:
	# Delta del ratón calculada a mano (en _process no hay InputEvent con "relative").
	var mouse := get_viewport().get_mouse_position()
	if not _has_mouse:
		_last_mouse = mouse
		_has_mouse = true
	var mouse_delta := mouse - _last_mouse
	_last_mouse = mouse

	# --- Pan por teclado: WASD + flechas (Input directo, sin InputMap) ---
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move += _ground_forward()
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move -= _ground_forward()
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move += _ground_right()
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move -= _ground_right()
	if move.length_squared() > 0.0:
		move = move.normalized()
		# Más rápido cuando la cámara está alta/lejos para mantener la sensación.
		var speed := KEYBOARD_SPEED * (0.5 + _distance / MAX_DISTANCE)
		_target += move * speed * delta

	# --- Pan arrastrando con el botón central (sensación de "agarrar el mapa") ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var factor := _distance * DRAG_PAN_FACTOR
		_target -= _ground_right() * mouse_delta.x * factor
		_target += _ground_forward() * mouse_delta.y * factor

	# --- Rotar con el botón derecho: yaw libre + pitch limitado ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= mouse_delta.x * ROTATE_SPEED
		_pitch = clampf(_pitch - mouse_delta.y * ROTATE_SPEED, PITCH_MIN, PITCH_MAX)

	# --- Zoom con la rueda (el evento de rueda se ve en _process como pulsación momentánea) ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
		_distance = clampf(_distance - WHEEL_STEP, MIN_DISTANCE, MAX_DISTANCE)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
		_distance = clampf(_distance + WHEEL_STEP, MIN_DISTANCE, MAX_DISTANCE)

	# --- El objetivo vive en el plano del suelo y dentro de ±32 ---
	_target.x = clampf(_target.x, -BOUND, BOUND)
	_target.z = clampf(_target.z, -BOUND, BOUND)
	_target.y = 0.0

	# --- Aplicar con suavizado: la posición interpola (lerp) hacia la deseada ---
	var cos_pitch := cos(_pitch)
	var sin_pitch := sin(_pitch)
	var desired := _target + Vector3(sin(_yaw) * cos_pitch, -sin_pitch, cos(_yaw) * cos_pitch) * _distance
	var weight := 1.0 - exp(-SMOOTH * delta)
	global_position = global_position.lerp(desired, weight)
	look_at(_target, Vector3.UP)
