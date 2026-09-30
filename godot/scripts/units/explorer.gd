class_name Explorer
extends CharacterBody3D
## Explorador: HP 30, SIN ataque. Huye/explora: camina a un punto aleatorio
## del mapa cada 8s a speed 7. Visual Rogue.glb (fallback cápsula).
## SIN grupo "recruits" (los raiders buscan ese grupo, así lo ignoran).
## vision=20 para la niebla de guerra. CharacterBody3D + NavigationAgent3D
## construido por código (sin escena).

const SPEED := 7.0 ## Marcha rápida de exploración.
const WANDER_INTERVAL := 8.0 ## Segundos entre nuevos destinos.
const TRAIN_POS := Vector3(0.0, 0.0, 4.0) ## Punto de aparición al entrenar.
const MODEL_PATH := "res://assets/cc0/characters/Rogue.glb"
const EXPLORER_HP := 30.0
const TRAIN_COST := 10

static var _next_id := 0

var hp: float = 0.0
var explorer_id := ""
var vision := 20.0

var nav: NavigationAgent3D

var _wander_t := 0.0
var _target := Vector3.ZERO
var _has_target := false
var _gravity := 9.8
var _built := false


## Crea un explorador en `pos`, lo registra en GameState.recruits ({id},
## ocupa vivienda como el resto) y lo devuelve. El manager debe añadirlo
## al árbol con add_child(). NO se une al grupo "recruits".
static func spawn(pos: Vector3) -> Explorer:
	var e := Explorer.new()
	e.position = pos
	e._build()
	e.explorer_id = "explorer_%02d" % _next_id
	_next_id += 1
	GameState.recruits.append({"id": e.explorer_id})
	return e


## Entrena un explorador en TRAIN_POS. Devuelve "" si va bien o el mensaje
## de error: exige vivienda libre y comida >= TRAIN_COST (la descuenta).
static func train() -> String:
	var casas := 0
	for b in GameState.buildings:
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "casa":
			casas += 1
	# El centro aporta +2 alojamiento para no bloquear el inicio.
	var cap: int = mini(Economy.housing_cap(casas) + 2, Economy.MAX_SETTLERS)
	var ocup: int = GameState.settlers.size() + GameState.recruits.size()
	if ocup >= cap:
		return "Sin vivienda libre (%d/%d): construye una casa (+%d)" % [ocup, cap, Economy.CASA_COLONOS]
	var have: float = float(GameState.resources.get("comida", 0.0))
	if have < float(TRAIN_COST):
		return "Comida insuficiente: necesitas %d (tienes %d)" % [int(TRAIN_COST), int(have)]
	GameState.resources["comida"] = float(GameState.resources.get("comida", 0.0)) - float(TRAIN_COST)
	GameState.resources_changed.emit()
	var e := Explorer.spawn(TRAIN_POS)
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var st := ml as SceneTree
		if st.current_scene != null:
			st.current_scene.add_child(e)
		elif st.root != null:
			st.root.add_child(e)
	return ""


func _ready() -> void:
	_build()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


## Construye hijos por código (idempotente).
func _build() -> void:
	if _built:
		return
	_built = true
	hp = float(EXPLORER_HP)
	floor_snap_length = 0.3

	var col := CollisionShape3D.new()
	col.name = "Body"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0.0, 0.75, 0.0)
	add_child(col)

	_build_visual()

	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.max_speed = SPEED
	nav.path_desired_distance = 0.4
	nav.target_desired_distance = 0.5
	add_child(nav)


## Rogue.glb como hijo "Visual"; si no carga, cápsula de respaldo.
func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var packed: PackedScene = null
	if ResourceLoader.exists(MODEL_PATH):
		packed = load(MODEL_PATH) as PackedScene
	if packed != null and packed.can_instantiate():
		visual.add_child(packed.instantiate())
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#95d5b2")
	mat.roughness = 0.8
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.5
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = capsule
	body.material_override = mat
	body.position = Vector3(0.0, 0.85, 0.0)
	visual.add_child(body)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	_wander_t -= delta
	if _wander_t <= 0.0 or not _has_target:
		_wander_t = WANDER_INTERVAL
		_pick_random_target()
	if _has_target:
		if _flat_dist(_target) < 0.6:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			_move_to(_target)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


## Elige un punto aleatorio del mapa (evita el agua x > 22).
func _pick_random_target() -> void:
	_target = Vector3(randf_range(-28.0, 20.0), 0.0, randf_range(-28.0, 28.0))
	_has_target = true


## Avanza hacia `target` (vía nav si hay mapa, si no en línea recta).
func _move_to(target: Vector3) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if _nav_ready():
		nav.target_position = target
		var next := nav.get_next_path_position()
		var nd := next - global_position
		nd.y = 0.0
		if nd.length() > 0.05:
			var dir := nd.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			return
	var straight := to.normalized()
	velocity.x = straight.x * SPEED
	velocity.z = straight.z * SPEED


func _nav_ready() -> bool:
	return nav != null and is_inside_tree() and NavigationServer3D.map_is_active(nav.get_navigation_map())


func _flat_dist(p: Vector3) -> float:
	var d := p - global_position
	d.y = 0.0
	return d.length()
