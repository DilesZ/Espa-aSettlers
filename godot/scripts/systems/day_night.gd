class_name DayNight
extends Node
## Ciclo día/noche procedural: sol orbitando + color/ambiente del Environment.
## Todo por código, sin escena. Otros sistemas leen `DayNight.day_factor`.

## Factor de luz diurna: 0.0 (noche) .. 1.0 (mediodía).
static var day_factor := 1.0

const DAY_LENGTH := 240.0
const SUN_RADIUS := 30.0

const NIGHT_COLOR := Color8(6, 11, 24) # #060b18
const DAY_COLOR := Color8(135, 181, 224) # #87b5e0
const SUNSET_COLOR := Color8(232, 149, 107) # #e8956b
const DAY_SUN := Color(1.0, 0.96, 0.88)
const WARM_SUN := Color(1.0, 0.55, 0.30)

## Empieza al mediodía (ángulo TAU/4 → elevación máxima).
var t := 60.0

var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
## Compatibility no tiene HDR: misma escena se ve lavada; se compensa bajando
## exposición (verificado en captura: todo verde lima sobreexpuesto).
var _exposure_fix := 1.0


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_exposure_fix = 0.62


func _process(delta: float) -> void:
	t += delta
	var angle := t * TAU / DAY_LENGTH
	var elev := sin(angle)
	var day := clampf((elev + 0.25) / 0.5, 0.0, 1.0)
	var warm := clampf(1.0 - absf(elev - 0.1) * 3.0, 0.0, 1.0)
	day_factor = day
	_refresh_cache()
	_update_sun(angle, day, warm)
	_update_environment(day, warm)


## Rebusca sol y entorno en la escena actual; nulo-seguro y con caché.
func _refresh_cache() -> void:
	if not is_instance_valid(_sun):
		_sun = null
	if not is_instance_valid(_world_env):
		_world_env = null
	if _sun != null and _world_env != null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	if _sun == null:
		_sun = _find_first(scene, &"DirectionalLight3D") as DirectionalLight3D
	if _world_env == null:
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


func _update_sun(angle: float, day: float, warm: float) -> void:
	if _sun == null:
		return
	_sun.position = Vector3(cos(angle) * SUN_RADIUS, sin(angle) * SUN_RADIUS, 12.0)
	if _sun.is_inside_tree():
		# Mira al origen con up alternativo cerca del cénit/nadir (evita error de look_at).
		var dir := (Vector3.ZERO - _sun.position).normalized()
		var up := Vector3.UP
		if absf(dir.dot(up)) > 0.98:
			up = Vector3.FORWARD
		_sun.look_at(Vector3.ZERO, up)
	_sun.light_energy = (0.05 + day * 1.25) * _exposure_fix
	_sun.light_color = DAY_SUN.lerp(WARM_SUN, warm)
	_sun.shadow_enabled = true


func _update_environment(day: float, warm: float) -> void:
	if _world_env == null:
		return
	var env := _world_env.environment
	if env == null:
		env = Environment.new()
		_world_env.environment = env
	# Cielo Settlers: ProceduralSkyMaterial en el Sky del Environment.
	# Funciona en Forward+ y Compatibility (sky procedural soportado en ambos).
	env.background_mode = Environment.BG_SKY
	if env.sky == null:
		env.sky = Sky.new()
		env.sky.sky_material = ProceduralSkyMaterial.new()
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	if mat == null:
		mat = ProceduralSkyMaterial.new()
		env.sky.sky_material = mat
	# Colores base: noche casi negro -> día azul -> atardecer naranja.
	var horizon := NIGHT_COLOR.lerp(DAY_COLOR, day)
	horizon = horizon.lerp(SUNSET_COLOR, warm * 0.75)
	var top_day := Color(0.25, 0.5, 0.9)
	var top_night := Color(0.005, 0.01, 0.03)
	var top := top_night.lerp(top_day, day)
	top = top.lerp(Color(0.9, 0.45, 0.25), warm * 0.4)
	var ground_h := horizon.darkened(0.45)
	var ground_b := Color(0.01, 0.01, 0.02).lerp(Color(0.16, 0.12, 0.08), warm * 0.5 + day * 0.2)
	mat.sky_top_color = top
	mat.sky_horizon_color = horizon
	mat.ground_horizon_color = ground_h
	mat.ground_bottom_color = ground_b
	mat.sun_angle_max = 8.0 + day * 92.0
	mat.sun_curve = clampf(0.03 + day * 0.12 - warm * 0.04, 0.01, 0.2)
	var e := (0.04 + day * 1.0) * _exposure_fix
	mat.sky_energy_multiplier = e
	mat.ground_energy_multiplier = e * 0.6
	env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.ambient_light_energy = (0.1 + day * 0.6) * _exposure_fix
