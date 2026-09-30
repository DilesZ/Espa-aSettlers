class_name SaveSystem
extends RefCounted
## Guardado/cargado simple con ConfigFile en `user://savegame.cfg`.
##
## Qué se guarda:
## - resources: Dictionary {madera, piedra, comida, tablon, trigo, harina, pan} (float)
## - buildings: Array[Dictionary] {id,type,x,z,paused,progress,blocked,hp,max_hp}
## - nodes: Array[Dictionary] de recursos del mapa
## - stats: Dictionary {tablon, pan} (float)
## - ai: ai_buildings (Array) + ai_queue (int)
## - meta: version=1, settler_count (int), victory/victory02/victory03/defeat (bool), quality (String)
##
## Qué NO se guarda (documentado):
## - Posiciones exactas de colonos (se respawnean N=settler_count como idle en el centro).
## - Raiders / recruits activos (nodos liberados al cargar; arrays GameState.recruits/raiders se vacían).
## - Timers en curso (GameManager.elapsed, _grow_t, producción progress parcial más allá del
##   valor guardado en buildings[i].progress, cooldowns de combate/IA).
## - Fog of war (al cargar se resetea a ceros: sin explorar).
## - Nodos visuales de edificios (solo se restauran los datos en GameState.buildings/ai_buildings).

const PATH := "user://savegame.cfg"
const VERSION := 1


## Guarda la partida. Devuelve "" si ok, o texto de error para mostrar.
static func save_game() -> String:
	var cfg := ConfigFile.new()
	# resources (float)
	for k in GameState.resources.keys():
		cfg.set_value("resources", str(k), float(GameState.resources.get(k, 0.0)))
	# stats (float)
	for k in GameState.stats.keys():
		cfg.set_value("stats", str(k), float(GameState.stats.get(k, 0.0)))
	# buildings / nodes / ai (duplicado profundo para no guardar referencias)
	cfg.set_value("buildings", "list", GameState.buildings.duplicate(true))
	cfg.set_value("nodes", "list", GameState.nodes.duplicate(true))
	cfg.set_value("ai", "buildings", GameState.ai_buildings.duplicate(true))
	cfg.set_value("ai", "queue", int(GameState.ai_queue))
	# meta
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "settler_count", int(GameState.settlers.size()))
	cfg.set_value("meta", "victory", bool(GameState.victory))
	cfg.set_value("meta", "victory02", bool(GameState.victory02))
	cfg.set_value("meta", "victory03", bool(GameState.victory03))
	cfg.set_value("meta", "defeat", bool(GameState.defeat))
	cfg.set_value("meta", "quality", str(GameState.quality))
	var err := cfg.save(PATH)
	if err != OK:
		return "Error al guardar: %s" % error_string(err)
	return ""


## Carga la partida. Restaura datos, limpia actores y respawnea colonos.
## Devuelve "Partida cargada" si ok (también lo pone en GameState.message),
## o texto de error (el HUD lo muestra en GameState.message).
static func load_game() -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		return "Sin partida guardada"
	if int(cfg.get_value("meta", "version", 0)) != VERSION:
		return "Versión de guardado no compatible"
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return "Escena no lista para cargar"

	# --- restaura resources/stats con conversión float() ---
	var res: Dictionary = {}
	for k in GameState.resources.keys():
		res[k] = float(cfg.get_value("resources", str(k), float(GameState.resources.get(k, 0.0))))
	GameState.resources = res
	var st: Dictionary = {}
	for k in GameState.stats.keys():
		st[k] = float(cfg.get_value("stats", str(k), float(GameState.stats.get(k, 0.0))))
	GameState.stats = st

	# --- restaura arrays (conversión numérica defensiva) ---
	GameState.buildings = _to_buildings(cfg.get_value("buildings", "list", []))
	GameState.nodes = _to_generic_list(cfg.get_value("nodes", "list", []))
	GameState.ai_buildings = _to_generic_list(cfg.get_value("ai", "buildings", []))
	GameState.ai_queue = int(cfg.get_value("ai", "queue", 0))

	# --- meta: victory flags + quality + settler_count ---
	GameState.victory = bool(cfg.get_value("meta", "victory", false))
	GameState.victory02 = bool(cfg.get_value("meta", "victory02", false))
	GameState.victory03 = bool(cfg.get_value("meta", "victory03", false))
	GameState.defeat = bool(cfg.get_value("meta", "defeat", false))
	GameState.quality = str(cfg.get_value("meta", "quality", "alto"))
	var settler_count := int(cfg.get_value("meta", "settler_count", 0))

	# --- limpia actores existentes ---
	for n in tree.get_nodes_in_group("raiders"):
		if is_instance_valid(n):
			n.queue_free()
	for n in tree.get_nodes_in_group("recruits"):
		if is_instance_valid(n):
			n.queue_free()
	# Colonos: clase Settler sin grupo -> libera CharacterBody3D que sean Settler.
	for n in tree.current_scene.find_children("*", "CharacterBody3D", true, false):
		if n is Settler and is_instance_valid(n):
			n.queue_free()
	GameState.raiders.clear()
	GameState.recruits.clear()
	GameState.settlers.clear()

	# --- respawnea N colonos idle en el centro (igual que GameManager: deferred) ---
	var scene := tree.current_scene
	for i in settler_count:
		var s := Settler.spawn(Vector3(randf_range(-2.0, 2.0), 0.0, 4.0 + randf_range(-2.0, 2.0)))
		scene.add_child.call_deferred(s)

	# --- resetea fog a ceros ---
	GameState.fog.resize(32 * 32)
	GameState.fog.fill(0)

	_rebuild_visuals(tree)

	GameState.resources_changed.emit()
	GameState.buildings_changed.emit()
	GameState.fog_changed.emit()
	GameState.message = "Partida cargada"
	GameState.message_changed.emit(GameState.message)
	return "Partida cargada"


## Reconstruye nodos visuales desde los dicts (los nodos no se guardan):
## libera building_nodes/ai_building_nodes y reinstancia por dict.
static func _rebuild_visuals(tree: SceneTree) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	for n in tree.get_nodes_in_group("building_nodes"):
		n.queue_free()
	for n in tree.get_nodes_in_group("ai_building_nodes"):
		n.queue_free()
	for b in GameState.buildings:
		if b is Dictionary:
			var node := BuildingNode.new()
			scene.add_child(node)
			node.setup(b as Dictionary)
	for b in GameState.ai_buildings:
		if b is Dictionary:
			var node := AiBuildingNode.new()
			scene.add_child(node)
			node.setup(b as Dictionary)


static func _to_generic_list(v: Variant) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for e in (v as Array):
		if e is Dictionary:
			var d := (e as Dictionary).duplicate(true)
			for k in d.keys():
				var val: Variant = d[k]
				if val is int:
					d[k] = float(val)
			out.append(d)
		else:
			out.append(e)
	return out


static func _to_buildings(v: Variant) -> Array:
	var out := _to_generic_list(v)
	for e in out:
		if e is Dictionary:
			var d := e as Dictionary
			for k in ["x", "z", "progress", "hp", "max_hp"]:
				if d.has(k):
					d[k] = float(d.get(k, 0.0))
			for k in ["paused", "blocked"]:
				if d.has(k):
					d[k] = bool(d.get(k, false))
	return out
