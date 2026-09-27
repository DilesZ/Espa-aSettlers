class_name AiController
extends Node
## IA enemiga Fase 03: construye su base por cola y lanza raids periódicas.
## Uso: añadir un nodo AiController a la escena principal (lo cablea otro trabajo;
## funciona en cuanto entra al árbol, sin configuración).
##
## ASUNCIONES (documentadas según spec):
## 1. El primer centro IA (hp 300 en Economy.AI_BASE) lo crea OTRO trabajo; este
##    script NUNCA crea centros, solo consume BUILD_QUEUE.
## 2. `scripts/units/raider.gd` (class_name Raider) lo crea otro trabajo en
##    paralelo y puede no existir aún: se carga con load() en runtime. Si expone
##    `static func spawn(pos)`, se usa; si no, se instancia con .new() + setup/id.
##    Si el script no existe, se genera un raider fallback (CharacterBody3D rojo
##    con hp en metadata, grupo "raiders") con movimiento/ataque mínimos aquí
##    mismo, de modo que Combat siempre puede matarlo y la partida funciona.
## 3. GameManager (otro trabajo) debe llamar a Combat.tick(dt) cada física; este
##    nodo NO llama a Combat para no duplicar ticks.
## 4. "Cap raids min(3+elapsed/120,8)": nº deseado de raiders vivos concurrentes.

const BUILD_INTERVAL := 35.0
const RAID_INTERVAL := 45.0
const RAIDER_PATH := "res://scripts/units/raider.gd"
const FALLBACK_SPEED := 4.0
const FALLBACK_REACH := 2.0
const FALLBACK_HIT_RANGE := 2.5

const BUILD_QUEUE: Array = [
	"granja", "aserradero", "casa", "torre", "molino",
	"panaderia", "casa", "torre", "granja", "aserradero",
]
const BUILD_OFFSETS: Array = [
	Vector2(7, 0), Vector2(-7, 2), Vector2(0, 7), Vector2(2, -7), Vector2(8, 6),
	Vector2(-6, -6), Vector2(6, -6), Vector2(-8, 6), Vector2(0, 10), Vector2(10, -2),
]

var _elapsed := 0.0
var _build_t := 0.0
var _raid_t := 0.0
var _build_idx := 0
var _next_raider := 0
var _next_ai := 1


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_build_t += delta
	_raid_t += delta
	if _build_t >= BUILD_INTERVAL:
		_build_t -= BUILD_INTERVAL
		_do_build()
	if _raid_t >= RAID_INTERVAL:
		_raid_t -= RAID_INTERVAL
		_do_raid()
	_tick_fallback_raiders(delta)


## Construye el siguiente edificio de la cola junto a AI_BASE: añade el dict a
## GameState.ai_buildings e instancia su AiBuildingNode. Sin centros (asunción 1).
func _do_build() -> void:
	if _build_idx >= BUILD_QUEUE.size() or _build_idx >= BUILD_OFFSETS.size():
		return
	var tipo := str(BUILD_QUEUE[_build_idx])
	var off: Vector2 = BUILD_OFFSETS[_build_idx]
	_build_idx += 1
	var bx := float(Economy.AI_BASE.get("x", 16.0)) + off.x
	var bz := float(Economy.AI_BASE.get("z", -20.0)) + off.y
	var hp := int(Economy.BUILDING_HP.get(tipo, 200))
	var d := {"id": _next_ai_id(), "type": tipo, "x": bx, "z": bz, "hp": hp}
	GameState.ai_buildings.append(d)
	var node := AiBuildingNode.new()
	add_child(node)
	node.setup(d)
	_check_tier3()


## Raid: genera raiders hasta el cap deseado (vivos concurrentes).
func _do_raid() -> void:
	var cap := mini(3 + int(_elapsed / 120.0), 8)
	var want := maxi(0, cap - GameState.raiders.size())
	for i in range(want):
		var ang := randf() * TAU
		var r := randf_range(1.0, 3.0)
		var pos := Vector3(
			float(Economy.AI_BASE.get("x", 16.0)) + cos(ang) * r, 0.0,
			float(Economy.AI_BASE.get("z", -20.0)) + sin(ang) * r
		)
		_spawn_raider(pos)


## Crea un raider: Raider.spawn(pos) si el script paralelo existe, si no
## instancia manual + setup/id, y como último recurso el fallback propio.
## Siempre acaba en grupo "raiders" y con dict {id} en GameState.raiders.
func _spawn_raider(pos: Vector3) -> Node3D:
	var rid := "raider_%d" % _next_raider
	_next_raider += 1
	var node: Node3D = null
	if ResourceLoader.exists(RAIDER_PATH):
		var sc: GDScript = load(RAIDER_PATH) as GDScript
		if sc != null and sc.can_instantiate():
			var spawned: Variant = null
			if _script_has_method(sc, "spawn"):
				spawned = sc.call("spawn", pos)
			else:
				var inst: Variant = sc.new()
				if inst is Node3D:
					(inst as Node3D).position = pos
					if (inst as Node).has_method("setup"):
						(inst as Node).call("setup", {"id": rid, "x": pos.x, "z": pos.z})
					else:
						_assign_id(inst as Node, rid)
					spawned = inst
			if spawned is Node3D:
				node = spawned as Node3D
	if node == null:
		node = _make_fallback_raider(rid, pos)
	if not node.is_in_group("raiders"):
		node.add_to_group("raiders")
	_assign_id(node, rid)
	if not node.is_inside_tree():
		var parent: Node = get_tree().current_scene if get_tree().current_scene != null else self
		parent.add_child(node)
	if _find_raider_dict(rid) < 0:
		GameState.raiders.append({"id": rid})
	return node


## Derrota Tier 3: 10+ edificios IA sin victory02 del jugador.
func _check_tier3() -> void:
	if GameState.ai_buildings.size() >= 10 and not GameState.victory02:
		GameState.defeat = true
		_set_message("Derrota: la IA alcanzó Tier 3 (10 edificios).")


## --- Fallback (solo si raider.gd aún no existe) ---

## Raider mínimo: cápsula roja con hp en metadata. Combat lo daña/mata por el
## canal de metadata; este controlador lo mueve y hace que pegue.
func _make_fallback_raider(rid: String, pos: Vector3) -> CharacterBody3D:
	var rb := CharacterBody3D.new()
	rb.name = rid
	rb.position = pos
	rb.set_meta("hp", float(Economy.RAIDER_HP))
	rb.set_meta("fallback_raider", true)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position = Vector3(0.0, 0.75, 0.0)
	rb.add_child(col)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d00000")
	mat.roughness = 0.8
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.5
	mesh.mesh = cm
	mesh.material_override = mat
	mesh.position = Vector3(0.0, 0.85, 0.0)
	rb.add_child(mesh)
	return rb


## Mueve los fallback hacia el centro del jugador y golpea edificios cercanos.
## Los raiders del script paralelo (sin meta) se ignoran: tienen su propia IA.
func _tick_fallback_raiders(dt: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var tgt := _player_target()
	for n in tree.get_nodes_in_group("raiders"):
		if not (n is CharacterBody3D):
			continue
		if not (n as Node).has_meta("fallback_raider"):
			continue
		var rb := n as CharacterBody3D
		if rb.is_on_floor():
			if rb.velocity.y < 0.0:
				rb.velocity.y = -0.5
		else:
			rb.velocity.y -= 9.8 * dt
		var to := tgt - rb.global_position
		to.y = 0.0
		if to.length() > FALLBACK_REACH:
			var dir := to.normalized()
			rb.velocity.x = dir.x * FALLBACK_SPEED
			rb.velocity.z = dir.z * FALLBACK_SPEED
		else:
			rb.velocity.x = 0.0
			rb.velocity.z = 0.0
			_fallback_hit(rb, dt)
		rb.move_and_slide()


## Objetivo: posición del centro propio; si no existe, el origen.
func _player_target() -> Vector3:
	for b in GameState.buildings:
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "centro":
			return Vector3(float((b as Dictionary).get("x", 0.0)), 0.0, float((b as Dictionary).get("z", 0.0)))
	return Vector3.ZERO


## Daño del fallback al edificio propio más cercano en rango (dict vivo).
func _fallback_hit(rb: CharacterBody3D, dt: float) -> void:
	var best := -1
	var best_d := FALLBACK_HIT_RANGE
	var rp := Vector2(rb.global_position.x, rb.global_position.z)
	for i in range(GameState.buildings.size()):
		var b: Variant = GameState.buildings[i]
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		var d := rp.distance_to(Vector2(float(bd.get("x", 0.0)), float(bd.get("z", 0.0))))
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		var target: Dictionary = GameState.buildings[best]
		target["hp"] = float(target.get("hp", 1.0)) - float(Economy.RAIDER_DPS) * dt


## --- Utilidades ---

func _next_ai_id() -> String:
	var candidate := "ai%d" % _next_ai
	while _find_ai_dict(candidate) >= 0:
		_next_ai += 1
		candidate = "ai%d" % _next_ai
	_next_ai += 1
	return candidate


func _find_ai_dict(id: String) -> int:
	for i in range(GameState.ai_buildings.size()):
		var b: Variant = GameState.ai_buildings[i]
		if b is Dictionary and str((b as Dictionary).get("id", "")) == id:
			return i
	return -1


func _find_raider_dict(rid: String) -> int:
	for i in range(GameState.raiders.size()):
		var r: Variant = GameState.raiders[i]
		if r is Dictionary and str((r as Dictionary).get("id", "")) == rid:
			return i
	return -1


func _script_has_method(sc: GDScript, mname: String) -> bool:
	for m in sc.get_script_method_list():
		if str((m as Dictionary).get("name", "")) == mname:
			return true
	return false


## Fija raider_id/id en el nodo si la propiedad existe y está vacía.
func _assign_id(n: Node, rid: String) -> void:
	for key in ["raider_id", "id"]:
		if _has_prop(n, key) and str(n.get(key)) == "":
			n.set(key, rid)


func _has_prop(n: Node, prop: String) -> bool:
	for p in n.get_property_list():
		if str((p as Dictionary).get("name", "")) == prop:
			return true
	return false


func _set_message(text: String) -> void:
	GameState.message = text
	if GameState.has_signal("message_changed"):
		GameState.message_changed.emit(text)
