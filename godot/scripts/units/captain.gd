class_name Captain
extends CharacterBody3D
## Capitán: como Recruit pero élite (HP 120, DPS 14, speed 5.5).
## Knight.glb tintado dorado (fallback cápsula dorada) + penacho rojo.
## Grupo "recruits" (raiders/torres lo tratan como combatiente) + vision=8.
## CharacterBody3D + NavigationAgent3D construido por código (sin escena).
## Reelige objetivo cada 0.5s: raider vivo más cercano o edificio IA más
## cercano. Ataca raiders a < 2.0 m y edificios IA a < 3.0 m con CAPTAIN_DPS.

const SPEED := 5.5 ## Marcha (igual que max_speed del agente).
const RETARGET := 0.5 ## Segundos entre reelecciones de objetivo.
const RAIDER_RANGE := 2.0 ## Distancia de ataque contra raiders.
const BUILDING_RANGE := 3.0 ## Distancia de ataque contra edificios IA.
const TRAIN_POS := Vector3(0.0, 0.0, 4.0) ## Punto de aparición al entrenar.
const MODEL_PATH := "res://assets/cc0/characters/Knight.glb"
const CAPTAIN_HP := 120.0
const CAPTAIN_DPS := 14.0
const TRAIN_COST := 30

static var _next_id := 0

var hp: float = 0.0
var recruit_id := ""
var vision := 8.0

var _target_raider: Node3D = null
var _target_ai_id := ""
var _retarget_t := 0.0
var _gravity := 9.8
var _built := false

var nav: NavigationAgent3D


## Crea un capitán en `pos`, lo registra en GameState.recruits ({id}) y lo
## devuelve. El manager debe añadirlo al árbol con add_child().
static func spawn(pos: Vector3) -> Captain:
	var r := Captain.new()
	r.position = pos
	r._build()
	r.recruit_id = "captain_%02d" % _next_id
	_next_id += 1
	if not r.is_in_group("recruits"):
		r.add_to_group("recruits")
	GameState.recruits.append({"id": r.recruit_id})
	return r


## Entrena un capitán en TRAIN_POS. Devuelve "" si va bien o el mensaje de
## error: exige vivienda libre (settlers+recruits < min(housing_cap(casas),
## MAX_SETTLERS)) y comida >= TRAIN_COST (la descuenta).
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
	var r := Captain.spawn(TRAIN_POS)
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var st := ml as SceneTree
		if st.current_scene != null:
			st.current_scene.add_child(r)
		elif st.root != null:
			st.root.add_child(r)
	return ""


func _ready() -> void:
	_build()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_in_group("recruits"):
		add_to_group("recruits")


## Construye hijos por código (idempotente).
func _build() -> void:
	if _built:
		return
	_built = true
	hp = float(CAPTAIN_HP)
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


## Knight.glb como hijo "Visual"; si no carga, cápsula dorada + lanza.
## En ambos casos penacho rojo encima.
func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var packed: PackedScene = null
	if ResourceLoader.exists(MODEL_PATH):
		packed = load(MODEL_PATH) as PackedScene
	if packed != null and packed.can_instantiate():
		visual.add_child(packed.instantiate())
		_add_plume(visual)
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d4af37")
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

	var lance_mat := StandardMaterial3D.new()
	lance_mat.albedo_color = Color(0.6, 0.6, 0.65)
	lance_mat.roughness = 0.5
	var lance_mesh := BoxMesh.new()
	lance_mesh.size = Vector3(0.12, 0.12, 1.3)
	var lance := MeshInstance3D.new()
	lance.name = "Lance"
	lance.mesh = lance_mesh
	lance.material_override = lance_mat
	lance.position = Vector3(0.35, 1.1, 0.25)
	visual.add_child(lance)
	_add_plume(visual)


## Penacho: caja roja pequeña encima del casco.
func _add_plume(parent: Node3D) -> void:
	var plume_mat := StandardMaterial3D.new()
	plume_mat.albedo_color = Color("#e63946")
	plume_mat.roughness = 0.7
	var plume_mesh := BoxMesh.new()
	plume_mesh.size = Vector3(0.12, 0.22, 0.4)
	var plume := MeshInstance3D.new()
	plume.name = "Plume"
	plume.mesh = plume_mesh
	plume.material_override = plume_mat
	plume.position = Vector3(0.0, 1.95, -0.05)
	parent.add_child(plume)


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
	if _target_raider == null and _target_ai_id == "":
		_retarget()
		_validate_target()
	if _target_raider != null:
		var tp: Vector3 = _target_raider.global_position
		if _flat_dist(tp) <= RAIDER_RANGE:
			velocity.x = 0.0
			velocity.z = 0.0
			_hit_raider(delta)
		else:
			_move_to(tp)
	elif _target_ai_id != "":
		var b := _find_ai_building(_target_ai_id)
		if b.is_empty():
			_target_ai_id = ""
		else:
			var bp := _bpos(b)
			if _flat_dist(bp) <= BUILDING_RANGE:
				velocity.x = 0.0
				velocity.z = 0.0
				_hit_ai_building(b, delta)
			else:
				_move_to(bp)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


## Reelige objetivo: raider vivo más cercano, o edificio IA más cercano.
func _retarget() -> void:
	_target_raider = _nearest_raider()
	if _target_raider != null:
		_target_ai_id = ""
		return
	var b := _nearest_ai_building()
	if b.is_empty():
		_target_ai_id = ""
	else:
		_target_ai_id = str(b.get("id", ""))


## Limpia objetivos muertos/destruidos/liberados.
func _validate_target() -> void:
	if _target_raider != null:
		if (not is_instance_valid(_target_raider) or _target_raider.is_queued_for_deletion()
				or _target_raider.get("hp") == null
				or float(_target_raider.get("hp")) <= 0.0):
			_target_raider = null
	if _target_ai_id != "" and _find_ai_building(_target_ai_id).is_empty():
		_target_ai_id = ""


func _nearest_raider() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("raiders"):
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


func _nearest_ai_building() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for b in GameState.ai_buildings:
		if not (b is Dictionary):
			continue
		var d := b as Dictionary
		if float(d.get("hp", 0.0)) <= 0.0:
			continue
		var dist := _flat_dist(_bpos(d))
		if dist < best_d:
			best_d = dist
			best = d
	return best


## Daña al raider; si muere lo libera y borra su dict de GameState.raiders.
func _hit_raider(delta: float) -> void:
	if _target_raider == null or not is_instance_valid(_target_raider):
		_target_raider = null
		return
	var cur := float(_target_raider.get("hp")) - float(CAPTAIN_DPS) * delta
	_target_raider.set("hp", cur)
	if cur <= 0.0:
		var rid := str(_target_raider.get("raider_id"))
		for i in range(GameState.raiders.size()):
			var d: Variant = GameState.raiders[i]
			if d is Dictionary and str((d as Dictionary).get("id", "")) == rid:
				GameState.raiders.remove_at(i)
				break
		_target_raider.queue_free()
		_target_raider = null


## Daña el edificio IA (dict por referencia); si cae lo borra de
## GameState.ai_buildings.
func _hit_ai_building(b: Dictionary, delta: float) -> void:
	b["hp"] = float(b.get("hp", 0.0)) - float(CAPTAIN_DPS) * delta
	if float(b.get("hp", 0.0)) > 0.0:
		return
	var bid := str(b.get("id", ""))
	for i in range(GameState.ai_buildings.size()):
		var d: Variant = GameState.ai_buildings[i]
		if d is Dictionary and str((d as Dictionary).get("id", "")) == bid:
			GameState.ai_buildings.remove_at(i)
			break
	_target_ai_id = ""


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


func _find_ai_building(bid: String) -> Dictionary:
	for b in GameState.ai_buildings:
		if b is Dictionary and str((b as Dictionary).get("id", "")) == bid:
			return b as Dictionary
	return {}


static func _bpos(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
