class_name Settler
extends CharacterBody3D
## Colono autónomo con FSM: IDLE -> TO_TREE/TO_ROCK -> CHOP/MINE -> RETURN -> IDLE.
## Lee nodos de GameState.nodes y entrega el recurso en GameState.resources.
## Todo construido por código (sin escena): colisión + personaje Rogue_Hooded
## (hijo "Visual"; fallback a cápsula amarilla si el .glb no carga) + caja
## de carga + NavigationAgent3D. El manager lo añade al árbol (ver spawn()).

enum State { IDLE, TO_TREE, CHOP, TO_ROCK, MINE, RETURN }

const SPEED := 5.0 ## Velocidad de marcha (igual que max_speed del agente).
const WORK_TIME := 3.0 ## Segundos picando/talando en CHOP/MINE.
const ARRIVE_DIST := 0.6 ## Distancia horizontal que cuenta como "llegado".
const WOOD_YIELD := 5.0 ## Madera entregada por viaje.
const STONE_YIELD := 4.0 ## Piedra entregada por viaje.
const STONE_CHANCE := 0.4 ## Probabilidad de elegir roca cuando hay de ambos.
const IDLE_RETRY := 1.0 ## Espera en IDLE cuando no hay nodos con amount > 0.
const DROP_CENTER := Vector3(0.0, 0.0, 2.0) ## Punto de entrega (centro urbano).
const TRAVEL_GRACE := 0.15 ## Gracia antes de fiarse de nav.is_navigation_finished().
const MODEL_PATH := "res://assets/cc0/characters/Rogue_Hooded.glb" ## Personaje KayKit.
const WALK_FREQ := 10.0 ## Frecuencia del balanceo de marcha (rad/s).
const WALK_BOB := 0.08 ## Amplitud vertical del balanceo al moverse.
const WALK_TILT := 0.03 ## Inclinación lateral del balanceo (rad).

static var _next_id := 0

var state: State = State.IDLE
var carry := "" ## "" | "madera" | "piedra".
var settler_id := ""

var _target_node: Dictionary = {}
var _work_t := 0.0
var _idle_t := 0.0
var _travel_t := 0.0
var _gravity := 9.8
var _built := false

var nav: NavigationAgent3D
var _body_mesh: MeshInstance3D
var _carry_mesh: MeshInstance3D
var _visual: Node3D ## Contenedor del personaje .glb (o la cápsula fallback).
var _walk_t := 0.0 ## Reloj del balanceo de marcha.


## Crea un colono en `pos`, lo registra en GameState.settlers ({id}) y lo
## devuelve. El manager debe añadirlo al árbol con add_child().
static func spawn(pos: Vector3) -> Settler:
	var s := Settler.new()
	s.position = pos
	s._build()
	s.settler_id = "settler_%02d" % _next_id
	_next_id += 1
	GameState.settlers.append({"id": s.settler_id})
	return s


func _ready() -> void:
	_build()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


## Construye hijos por código (idempotente): funciona tanto si el nodo se
## creó vía spawn() antes de entrar al árbol como si se añade directamente.
func _build() -> void:
	if _built:
		return
	_built = true
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

	var carry_mat := StandardMaterial3D.new()
	carry_mat.albedo_color = Color(0.55, 0.35, 0.15)
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.3, 0.4)
	_carry_mesh = MeshInstance3D.new()
	_carry_mesh.name = "Carry"
	_carry_mesh.mesh = box
	_carry_mesh.material_override = carry_mat
	_carry_mesh.position = Vector3(0.0, 1.7, 0.0)
	_carry_mesh.visible = false
	add_child(_carry_mesh)

	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.max_speed = SPEED
	nav.path_desired_distance = 0.4
	nav.target_desired_distance = 0.5
	add_child(nav)


## Instancia el .glb de MODEL_PATH como hijo "Visual" (conserva colisión,
## agente, FSM, carry, hp y grupos: solo cambia lo visible). Si no carga
## (ruta ausente o import roto), fallback a la cápsula amarilla de siempre.
func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var packed: PackedScene = null
	if ResourceLoader.exists(MODEL_PATH):
		packed = load(MODEL_PATH) as PackedScene
	if packed != null and packed.can_instantiate():
		_visual.add_child(packed.instantiate())
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f1fa8c")
	mat.roughness = 0.8
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.5
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "Body"
	_body_mesh.mesh = capsule
	_body_mesh.material_override = mat
	_body_mesh.position = Vector3(0.0, 0.85, 0.0)
	_visual.add_child(_body_mesh)


## Balanceo de marcha procedural: en movimiento, Visual bota
## (|sin(t*10)|*0.08) con leve inclinación; parado vuelve a y=0.
func _update_walk_visual(delta: float) -> void:
	_walk_t += delta
	if _visual == null or not is_instance_valid(_visual):
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.5:
		_visual.position.y = absf(sin(_walk_t * WALK_FREQ)) * WALK_BOB
		_visual.rotation.z = sin(_walk_t * WALK_FREQ) * WALK_TILT
	else:
		_visual.position.y = 0.0
		_visual.rotation.z = 0.0


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	match state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			if _idle_t > 0.0:
				_idle_t -= delta
			elif not _pick_node():
				_idle_t = IDLE_RETRY
		State.TO_TREE, State.TO_ROCK:
			_travel_t += delta
			if _target_node.is_empty():
				state = State.IDLE
			elif _steer_to(_node_pos(_target_node)):
				state = State.CHOP if state == State.TO_TREE else State.MINE
				velocity.x = 0.0
				velocity.z = 0.0
				_work_t = WORK_TIME
		State.CHOP, State.MINE:
			velocity.x = 0.0
			velocity.z = 0.0
			_work_t -= delta
			if _work_t <= 0.0:
				_finish_work()
		State.RETURN:
			_travel_t += delta
			if _steer_to(DROP_CENTER):
				velocity.x = 0.0
				velocity.z = 0.0
				_deliver()
	move_and_slide()
	_update_walk_visual(delta)


## Elige nodo con amount > 0 (40% piedra si hay de ambos) y arranca el viaje.
## Devuelve false si no hay candidatos (el llamador reintenta tras IDLE_RETRY).
func _pick_node() -> bool:
	var trees: Array = []
	var rocks: Array = []
	for n in GameState.nodes:
		if not (n is Dictionary):
			continue
		var d := n as Dictionary
		if float(d.get("amount", 0.0)) <= 0.0:
			continue
		if _is_tree(d):
			trees.append(d)
		else:
			rocks.append(d)
	var want_stone := (not rocks.is_empty()) and (trees.is_empty() or randf() < STONE_CHANCE)
	var pool: Array = rocks if want_stone else trees
	if pool.is_empty():
		return false
	_target_node = pool[randi() % pool.size()] as Dictionary
	state = State.TO_ROCK if want_stone else State.TO_TREE
	_travel_t = 0.0
	if nav != null:
		nav.target_position = _node_pos(_target_node)
	return true


## Avanza hacia `target` (vía nav si hay mapa, si no en línea recta).
## Devuelve true al llegar (nav finished —tras la gracia— o dist < 0.6).
func _steer_to(target: Vector3) -> bool:
	var to := target - global_position
	to.y = 0.0
	if to.length() < ARRIVE_DIST:
		return true
	if _nav_ready():
		if nav.is_navigation_finished() and _travel_t > TRAVEL_GRACE:
			return true
		var next := nav.get_next_path_position()
		var nd := next - global_position
		nd.y = 0.0
		if nd.length() > 0.05:
			var dir := nd.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			return false
	var dir := to.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	return false


func _nav_ready() -> bool:
	return nav != null and is_inside_tree() and NavigationServer3D.map_is_active(nav.get_navigation_map())


## Fin de CHOP/MINE: fija carry, descuenta amount del nodo y vuelve al centro.
func _finish_work() -> void:
	var wood := state == State.CHOP
	carry = "madera" if wood else "piedra"
	_deplete_target(WOOD_YIELD if wood else STONE_YIELD)
	_target_node = {}
	state = State.RETURN
	_travel_t = 0.0
	if nav != null:
		nav.target_position = DROP_CENTER
	_carry_mesh.visible = true
	var cm := _carry_mesh.material_override as StandardMaterial3D
	if cm != null:
		cm.albedo_color = Color(0.55, 0.35, 0.15) if wood else Color(0.5, 0.5, 0.55)


## Entrega en el centro: +5 madera o +4 piedra a GameState.resources.
func _deliver() -> void:
	if carry == "madera":
		GameState.resources["madera"] = float(GameState.resources.get("madera", 0.0)) + WOOD_YIELD
	elif carry == "piedra":
		GameState.resources["piedra"] = float(GameState.resources.get("piedra", 0.0)) + STONE_YIELD
	GameState.resources_changed.emit()
	AudioManager.play("coin")
	carry = ""
	_carry_mesh.visible = false
	state = State.IDLE
	_idle_t = 0.0


## Resta `amount` al nodo objetivo (referencia directa + espejo por id).
func _deplete_target(amount: float) -> void:
	if _target_node.is_empty():
		return
	_target_node["amount"] = maxf(0.0, float(_target_node.get("amount", 0.0)) - amount)
	var tid := String(_target_node.get("id", ""))
	if tid == "":
		return
	for n in GameState.nodes:
		if n is Dictionary and String((n as Dictionary).get("id", "")) == tid:
			(n as Dictionary)["amount"] = _target_node["amount"]
			break


static func _node_pos(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))


## Acepta ambas convenciones: kind/type y tree/rock/arbol/roca/madera/piedra.
static func _is_tree(d: Dictionary) -> bool:
	var t := String(d.get("kind", d.get("type", "tree"))).to_lower()
	return t == "tree" or t == "arbol" or t == "árbol" or t == "madera"
