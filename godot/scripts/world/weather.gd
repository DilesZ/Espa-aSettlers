class_name Weather
extends Node3D
## Ciclo de clima procedural: CLEAR (60-90s aleatorio) <-> RAIN (25-40s).
## Todo por código, sin escena: este nodo se instancia como hijo de Main.
## Efectos de la lluvia:
##   a) GPUParticles3D con 1500 gotas en caja de 70x20x70 sobre el mapa.
##      SIN audio: el sonido lo lleva otro sistema.
##   b) Freno global: Engine.time_scale 1.0 <-> 0.75 con lerp suave.
##      NOTA: time_scale es GLOBAL (Engine), asi que la lluvia frena TODO el
##      juego: fisica, timers, animaciones, DayNight, IA y el propio temporizador
##      de este ciclo (las duraciones son tiempo de juego, no real).
##   c) Niebla densa: solo toca fog_enabled / fog_density / fog_sky_affect del
##      Environment del WorldEnvironment de la escena (buscado por clase,
##      nulo-seguro). NO toca background/ambient: eso lo lleva DayNight.
##   d) Avisa cada cambio via GameState.message (+ senal message_changed).

enum State { CLEAR, RAIN }

const CLEAR_MIN := 60.0
const CLEAR_MAX := 90.0
const RAIN_MIN := 25.0
const RAIN_MAX := 40.0

const CLEAR_TIME_SCALE := 1.0
const RAIN_TIME_SCALE := 0.75
const LERP_RATE := 2.0

const RAIN_FOG_DENSITY := 0.02
const RAIN_FOG_SKY_AFFECT := 0.5
const CLEAR_FOG_DENSITY := 0.0

const RAIN_AMOUNT := 1500
const RAIN_CENTER := Vector3(0.0, 15.0, 0.0)
const RAIN_EXTENTS := Vector3(35.0, 10.0, 35.0) # Caja 70x20x70.
const RAIN_VELOCITY := 25.0 # Caida vertical (-Y).
const RAIN_LIFETIME := 1.2
const RAIN_COLOR := Color(0.55, 0.70, 1.0, 0.45) # Azul translucido.

const MSG_RAIN_START := "Comienza la lluvia..."
const MSG_RAIN_END := "Escampa."

var _state: State = State.CLEAR
var _timer := 0.0
var _target_time_scale := CLEAR_TIME_SCALE
var _target_fog_density := CLEAR_FOG_DENSITY

var _rain: GPUParticles3D
var _world_env: WorldEnvironment


func _ready() -> void:
	_build_rain()
	_enter_clear(false)


func _process(delta: float) -> void:
	_refresh_cache()
	_timer -= delta
	if _timer <= 0.0:
		if _state == State.CLEAR:
			_enter_rain()
		else:
			_enter_clear(true)
	_update_time_scale(delta)
	_update_fog(delta)
	_update_rain_emitting()


func _exit_tree() -> void:
	# No dejar el juego frenado si este nodo se libera.
	Engine.time_scale = CLEAR_TIME_SCALE


func _enter_clear(announce: bool) -> void:
	_state = State.CLEAR
	_timer = randf_range(CLEAR_MIN, CLEAR_MAX)
	_target_time_scale = CLEAR_TIME_SCALE
	_target_fog_density = CLEAR_FOG_DENSITY
	if announce:
		_set_message(MSG_RAIN_END)


func _enter_rain() -> void:
	_state = State.RAIN
	_timer = randf_range(RAIN_MIN, RAIN_MAX)
	_target_time_scale = RAIN_TIME_SCALE
	_target_fog_density = RAIN_FOG_DENSITY
	_set_message(MSG_RAIN_START)


func _update_time_scale(delta: float) -> void:
	if Engine.time_scale == _target_time_scale:
		return
	var w := 1.0 - exp(-LERP_RATE * delta)
	Engine.time_scale = lerpf(Engine.time_scale, _target_time_scale, w)
	if absf(Engine.time_scale - _target_time_scale) < 0.001:
		Engine.time_scale = _target_time_scale


func _update_fog(delta: float) -> void:
	var env := _get_env()
	if env == null:
		return
	if _target_fog_density > 0.0:
		env.fog_enabled = true
		env.fog_sky_affect = RAIN_FOG_SKY_AFFECT
		var w := 1.0 - exp(-LERP_RATE * delta)
		env.fog_density = lerpf(env.fog_density, _target_fog_density, w)
	else:
		var w0 := 1.0 - exp(-LERP_RATE * delta)
		env.fog_density = lerpf(env.fog_density, CLEAR_FOG_DENSITY, w0)
		if env.fog_density < 0.0005:
			env.fog_density = CLEAR_FOG_DENSITY
			env.fog_enabled = false


func _update_rain_emitting() -> void:
	if _rain == null or not is_instance_valid(_rain):
		return
	var want := _state == State.RAIN
	if _rain.emitting != want:
		_rain.emitting = want


## Construye la lluvia por codigo: 1500 gotas, caja 70x20x70, caida -25Y.
func _build_rain() -> void:
	if _rain != null and is_instance_valid(_rain):
		return
	var particles := GPUParticles3D.new()
	particles.name = "Rain"
	particles.amount = RAIN_AMOUNT
	particles.lifetime = RAIN_LIFETIME
	particles.preprocess = RAIN_LIFETIME # Lluvia visible desde el primer frame.
	particles.explosiveness = 0.0
	particles.one_shot = false
	particles.local_coords = false
	particles.emitting = false
	particles.position = RAIN_CENTER
	# Evita que las gotas desaparezcan por frustum culling.
	particles.visibility_aabb = AABB(Vector3(-40.0, -25.0, -40.0), Vector3(80.0, 45.0, 80.0))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = RAIN_EXTENTS
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 3.0
	pm.initial_velocity_min = RAIN_VELOCITY - 2.0
	pm.initial_velocity_max = RAIN_VELOCITY + 2.0
	pm.gravity = Vector3.ZERO
	pm.color = RAIN_COLOR
	particles.process_material = pm

	var drop := BoxMesh.new()
	drop.size = Vector3(0.04, 0.35, 0.04)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = RAIN_COLOR
	drop.material = mat
	particles.draw_pass_1 = drop

	add_child(particles)
	_rain = particles


## Rebusca el WorldEnvironment en la escena actual; nulo-seguro y con cache.
## (Mismo patron que DayNight; solo se usa para la niebla.)
func _refresh_cache() -> void:
	if is_instance_valid(_world_env):
		return
	_world_env = null
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	_world_env = _find_first(scene, &"WorldEnvironment") as WorldEnvironment


func _find_first(node: Node, cls: StringName) -> Node:
	if node == null:
		return null
	if node.is_class(cls):
		return node
	for child in node.get_children():
		var found := _find_first(child, cls)
		if found != null:
			return found
	return null


## Devuelve el Environment del WorldEnvironment (lo crea si falta, sin tocar
## background/ambient: solo se usara para fog_*). Nulo si no hay entorno.
func _get_env() -> Environment:
	if not is_instance_valid(_world_env):
		return null
	var env := _world_env.environment
	if env == null:
		env = Environment.new()
		_world_env.environment = env
	return env


## Aviso via GameState.message + senal, con guards (nulo-seguro fuera de Main).
func _set_message(text: String) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var gs := tree.root.get_node_or_null("GameState")
	if gs == null:
		return
	gs.set("message", text)
	if gs.has_signal("message_changed"):
		gs.emit_signal("message_changed", text)
