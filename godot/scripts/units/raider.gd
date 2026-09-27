class_name Raider
extends CharacterBody3D
## Asaltante de la IA: persigue reclutas o asedia edificios propios.
## Como Settler pero rojo: colisión + cápsula #e63946 + NavigationAgent3D,
## construido por código (sin escena). Reelige objetivo cada 0.5s: recluta vivo
## más cercano (grupo "recruits") o, si no hay, edificio propio más cercano
## (GameState.buildings). Ataca a < 2.0 m con Economy.RAIDER_DPS.
## El manager lo añade al árbol (ver spawn()).

const SPEED := 5.0 ## Marcha (igual que max_speed del agente).
const RETARGET := 0.5 ## Segundos entre reelecciones de objetivo.
const ATTACK_RANGE := 2.0 ## Distancia de ataque cuerpo a cuerpo.

static var _next_id := 0

var hp: float = 0.0
var raider_id := ""

var _target_recruit: Node3D = null
var _target_building_id := ""
var _retarget_t := 0.0
var _gravity := 9.8
var _built := false

var nav: NavigationAgent3D


## Crea un raider en `pos`, lo registra en GameState.raiders ({id}) y lo
## devuelve. El manager debe añadirlo al árbol con add_child().
static func spawn(pos: Vector3) -> Raider:
	var r := Raider.new()
	r.position = pos
	r._build()
	r.raider_id = "raider_%02d" % _next_id
	_next_id += 1
	if not r.is_in_group("raiders"):
		r.add_to_group("raiders")
	GameState.raiders.append({"id": r.raider_id})
	return r


func _ready() -> void:
	_build()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_in_group("raiders"):
		add_to_group("raiders")


## Construye hijos por código (idempotente): funciona tanto si el nodo se
## creó vía spawn() antes de entrar al árbol como si se añade directamente.
func _build() -> void:
	if _built:
		return
	_built = true
	hp = float(Economy.RAIDER_HP)
	floor_snap_length = 0.3

	var col := CollisionShape3D.new()
	col.name = "Body"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0.0, 0.75, 0.0)
	add_child(col)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e63946")
	mat.roughness = 0.8
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.5
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = capsule
	body.material_override = mat
	body.position = Vector3(0.0, 0.85, 0.0)
	add_child(body)

	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.max_speed = SPEED
	nav.path_desired_distance = 0.4
	nav.target_desired_distance = 0.5
	add_child(nav)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = RETARGET
		_retarget()
	_validate_target()
	if _target_recruit == null and _target_building_id == "":
		_retarget()
		_validate_target()
	if _target_recruit != null:
		var tp: Vector3 = _target_recruit.global_position
		if _flat_dist(tp) <= ATTACK_RANGE:
			velocity.x = 0.0
			velocity.z = 0.0
			_hit_recruit(delta)
		else:
			_move_to(tp)
	elif _target_building_id != "":
		var b := _find_building(_target_building_id)
		if b.is_empty():
			_target_building_id = ""
		else:
			var bp := _bpos(b)
			if _flat_dist(bp) <= ATTACK_RANGE:
				velocity.x = 0.0
				velocity.z = 0.0
				_hit_building(b, delta)
			else:
				_move_to(bp)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


## Reelige objetivo: recluta vivo más cercano, o edificio propio más cercano.
func _retarget() -> void:
	_target_recruit = _nearest_recruit()
	if _target_recruit != null:
		_target_building_id = ""
		return
	var b := _nearest_building()
	if b.is_empty():
		_target_building_id = ""
	else:
		_target_building_id = str(b.get("id", ""))


## Limpia objetivos muertos/destruidos/liberados.
func _validate_target() -> void:
	if _target_recruit != null:
		if (not is_instance_valid(_target_recruit) or _target_recruit.is_queued_for_deletion()
				or _target_recruit.get("hp") == null
				or float(_target_recruit.get("hp")) <= 0.0):
			_target_recruit = null
	if _target_building_id != "" and _find_building(_target_building_id).is_empty():
		_target_building_id = ""


func _nearest_recruit() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("recruits"):
		if not (n is Node3D):
			continue
		var nd := n as Node3D
		if nd.is_queued_for_deletion():
			continue
		var h: Variant = nd.get("hp")
		if h == null or float(h) <= 0.0:
			continue
		var d := _flat_dist(nd.global_position)
		if d < best_d:
			best_d = d
			best = nd
	return best


func _nearest_building() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for b in GameState.buildings:
		if not (b is Dictionary):
			continue
		var d := b as Dictionary
		var dist := _flat_dist(_bpos(d))
		if dist < best_d:
			best_d = dist
			best = d
	return best


## Daña al recluta; si muere lo libera y borra su dict de GameState.recruits.
func _hit_recruit(delta: float) -> void:
	if _target_recruit == null or not is_instance_valid(_target_recruit):
		_target_recruit = null
		return
	var cur := float(_target_recruit.get("hp")) - float(Economy.RAIDER_DPS) * delta
	_target_recruit.set("hp", cur)
	if cur <= 0.0:
		_kill_recruit(_target_recruit)
		_target_recruit = null


func _kill_recruit(r: Node3D) -> void:
	var rid := str(r.get("recruit_id"))
	for i in range(GameState.recruits.size()):
		var d: Variant = GameState.recruits[i]
		if d is Dictionary and str((d as Dictionary).get("id", "")) == rid:
			GameState.recruits.remove_at(i)
			break
	r.queue_free()


## Daña el edificio (dict por referencia); si cae lo borra de
## GameState.buildings, libera su nodo ("building_nodes" con mismo id) y
## avisa si era el centro.
func _hit_building(b: Dictionary, delta: float) -> void:
	b["hp"] = float(b.get("hp", 0.0)) - float(Economy.RAIDER_DPS) * delta
	if float(b.get("hp", 0.0)) > 0.0:
		return
	var bid := str(b.get("id", ""))
	var btype := str(b.get("type", ""))
	for i in range(GameState.buildings.size()):
		var d: Variant = GameState.buildings[i]
		if d is Dictionary and str((d as Dictionary).get("id", "")) == bid:
			GameState.buildings.remove_at(i)
			break
	GameState.buildings_changed.emit()
	_free_building_node(bid)
	if btype == "centro":
		GameState.message = "¡Tu Centro Urbano ha sido destruido!"
		GameState.message_changed.emit(GameState.message)
	_target_building_id = ""


## Libera el nodo visual del edificio destruido (grupo "building_nodes",
## campo id en `data`; ver scripts/world/building.gd).
func _free_building_node(bid: String) -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("building_nodes"):
		var data: Variant = n.get("data")
		if data is Dictionary and str((data as Dictionary).get("id", "")) == bid:
			n.queue_free()
			break


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


func _find_building(bid: String) -> Dictionary:
	for b in GameState.buildings:
		if b is Dictionary and str((b as Dictionary).get("id", "")) == bid:
			return b as Dictionary
	return {}


static func _bpos(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
