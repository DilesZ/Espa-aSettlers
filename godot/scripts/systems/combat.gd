class_name Combat
extends RefCounted
## Combate Fase 03: torres propias disparan y limpieza de muertos.
## Lógica estática llamada cada física desde GameManager (lo cablea otro trabajo):
##   Combat.tick(dt)
##
## Asunciones de nodos (grupos):
## - "raiders": nodos Node3D con `hp` (float) y algún id (`raider_id` / `id` /
##   `data.id` / nombre del nodo). El `hp` también puede venir en metadata "hp"
##   (canal fallback que usa AiController cuando raider.gd aún no existe).
## - "building_nodes": nodos con `data` Dictionary con "id" (BuildingNode).
## - "ai_building_nodes": nodos con `data` Dictionary con "id" (AiBuildingNode).

const TOWER_COOLDOWN := 1.0
const RETRY_NO_TARGET := 0.2


## Tick principal: torres disparan + barrido de raiders/edificios muertos.
static func tick(dt: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_tick_towers(tree, dt)
	_sweep_raiders(tree)
	_sweep_buildings(tree)
	_sweep_ai_buildings(tree)


## Torres propias (!paused): cada 1.0s dañan TORRE_DPS al raider vivo más
## cercano en rango TORRE_RANGE. El cooldown vive en el dict ("cd", default 0.0).
static func _tick_towers(tree: SceneTree, dt: float) -> void:
	var raider_nodes := tree.get_nodes_in_group("raiders")
	for b in GameState.buildings:
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		if str(bd.get("type", "")) != "torre":
			continue
		if bool(bd.get("paused", false)):
			continue
		var cd := float(bd.get("cd", 0.0)) - dt
		if cd > 0.0:
			bd["cd"] = cd
			continue
		var target := _nearest_raider(
			raider_nodes,
			Vector2(float(bd.get("x", 0.0)), float(bd.get("z", 0.0)))
		)
		if target != null and is_instance_valid(target):
			_damage_raider(target, float(Economy.TORRE_DPS))
			bd["cd"] = TOWER_COOLDOWN
		else:
			bd["cd"] = RETRY_NO_TARGET


## Raider vivo (hp > 0) más cercano a `pos` dentro de TORRE_RANGE; null si no hay.
static func _nearest_raider(nodes: Array, pos: Vector2) -> Node:
	var best: Node = null
	var best_d := float(Economy.TORRE_RANGE)
	for n in nodes:
		if not (n is Node3D):
			continue
		if _raider_hp(n) == INF or _raider_hp(n) <= 0.0:
			continue
		var p := (n as Node3D).global_position
		var d := pos.distance_to(Vector2(p.x, p.z))
		if d <= best_d:
			best_d = d
			best = n
	return best


## Lee el hp de un raider: propiedad `hp` del script, o metadata "hp"
## (fallback). Devuelve INF si el nodo no expone hp (no se puede dañar).
static func _raider_hp(n: Node) -> float:
	var v: Variant = n.get("hp")
	if not (v is float or v is int):
		if n.has_meta("hp"):
			v = n.get_meta("hp")
		else:
			return INF
	if v is float or v is int:
		return float(v)
	return INF


## Resta daño al raider por ambos canales (propiedad + metadata si existen).
static func _damage_raider(n: Node, dmg: float) -> void:
	var hp := _raider_hp(n)
	if hp == INF:
		return
	var nhp: float = hp - dmg
	if _has_prop(n, "hp"):
		n.set("hp", nhp)
	if n.has_meta("hp"):
		n.set_meta("hp", nhp)


## Limpieza: raiders con hp <= 0 → free del nodo + borra su dict en raiders.
static func _sweep_raiders(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("raiders"):
		if not (n is Node):
			continue
		var hp := _raider_hp(n)
		if hp == INF or hp > 0.0:
			continue
		_remove_raider_dict(_node_rid(n))
		(n as Node).queue_free()


## Limpieza: edificios propios con hp <= 0 → borra dict + free del nodo
## "building_nodes" con mismo id. Si era el centro → derrota.
static func _sweep_buildings(tree: SceneTree) -> void:
	for i in range(GameState.buildings.size() - 1, -1, -1):
		var b: Variant = GameState.buildings[i]
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		if float(bd.get("hp", 1.0)) > 0.0:
			continue
		var bid := str(bd.get("id", ""))
		var tipo := str(bd.get("type", ""))
		GameState.buildings.remove_at(i)
		_free_in_group(tree, "building_nodes", bid)
		if tipo == "centro":
			GameState.defeat = true
			_set_message("¡Derrota! Tu centro urbano fue destruido.")
		_emit_buildings_changed()


## Limpieza: edificios IA con hp <= 0 → borra dict + free del nodo
## "ai_building_nodes". Si era el centro IA → victory03.
static func _sweep_ai_buildings(tree: SceneTree) -> void:
	for i in range(GameState.ai_buildings.size() - 1, -1, -1):
		var b: Variant = GameState.ai_buildings[i]
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		if float(bd.get("hp", 1.0)) > 0.0:
			continue
		var bid := str(bd.get("id", ""))
		var tipo := str(bd.get("type", ""))
		GameState.ai_buildings.remove_at(i)
		_free_in_group(tree, "ai_building_nodes", bid)
		if tipo == "centro":
			GameState.victory03 = true
			_set_message("¡Victoria Fase 03! Centro de la IA destruido.")
		_emit_buildings_changed()


## Libera el nodo del grupo cuyo `data.id` (o nombre "…_<id>") coincida.
static func _free_in_group(tree: SceneTree, group: String, id: String) -> void:
	for n in tree.get_nodes_in_group(group):
		if not (n is Node):
			continue
		var d: Variant = (n as Node).get("data")
		if d is Dictionary and str((d as Dictionary).get("id", "")) == id:
			(n as Node).queue_free()
			return
		if str((n as Node).name).ends_with("_" + id):
			(n as Node).queue_free()
			return


## Id de un nodo raider: raider_id / id / data.id / nombre (en ese orden).
static func _node_rid(n: Node) -> String:
	for key in ["raider_id", "id"]:
		var v: Variant = n.get(key)
		if v != null and str(v) != "":
			return str(v)
	var d: Variant = n.get("data")
	if d is Dictionary and str((d as Dictionary).get("id", "")) != "":
		return str((d as Dictionary).get("id", ""))
	return n.name


static func _remove_raider_dict(rid: String) -> void:
	for i in range(GameState.raiders.size() - 1, -1, -1):
		var r: Variant = GameState.raiders[i]
		if r is Dictionary and str((r as Dictionary).get("id", "")) == rid:
			GameState.raiders.remove_at(i)
			return


static func _has_prop(n: Node, prop: String) -> bool:
	for p in n.get_property_list():
		if str((p as Dictionary).get("name", "")) == prop:
			return true
	return false


static func _set_message(text: String) -> void:
	GameState.message = text
	if GameState.has_signal("message_changed"):
		GameState.message_changed.emit(text)


static func _emit_buildings_changed() -> void:
	if GameState.has_signal("buildings_changed"):
		GameState.buildings_changed.emit()
