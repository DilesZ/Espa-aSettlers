class_name BuildManager
extends Node3D
## Gestión de construcción: selección, fantasma, colocar, demoler, pausar.
## Otro trabajo cableará main.tscn; solo expone métodos públicos.

var selected: String = ""
var demolish := false

var _ghost: Node3D
var _ghost_mat: StandardMaterial3D
var _ground := Vector3.ZERO
var _ground_valid := false

const GHOST_OK := Color("#80ed99")
const GHOST_BAD := Color("#e63946")


func _ready() -> void:
	add_to_group("build_manager")
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(GHOST_OK, 0.45)
	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	_ghost.visible = false
	add_child(_ghost)
	_sync_nodes.call_deferred()


## Crea nodos para edificios que ya existen en el estado (centro inicial,
## recargas de escena): evita Capitales invisibles.
func _sync_nodes() -> void:
	for b in GameState.buildings:
		if not (b is Dictionary):
			continue
		var bid := str((b as Dictionary).get("id", ""))
		if bid == "" or _find_node(bid) != null:
			continue
		var node := BuildingNode.new()
		add_child(node)
		node.setup(b as Dictionary)


func select_building(t: String) -> void:
	if t != "" and not Economy.BUILDINGS.has(t):
		_set_message("Edificio desconocido")
		return
	if t == "centro":
		_set_message("El centro ya existe, no se puede construir")
		return
	selected = t
	demolish = false
	_refresh_ghost_mesh()
	if _ghost != null:
		_ghost.visible = selected != ""


func toggle_demolish() -> void:
	demolish = not demolish
	if demolish:
		selected = ""
		if _ghost != null:
			_ghost.visible = false
		_set_message("Modo demolición: clic en un edificio (no centro)")
	else:
		_set_message("")


func _process(_delta: float) -> void:
	if _ghost == null:
		return
	if selected == "" or not Economy.BUILDINGS.has(selected):
		_ground_valid = false
		_ghost.visible = false
		return
	if _pick_ground():
		_ghost.visible = true
		_ghost.position = Vector3(_ground.x, 0.0, _ground.z)
		var err: String = Economy.placement_error(_ground.x, _ground.z, selected, GameState.buildings)
		if err == "":
			_ghost_mat.albedo_color = Color(GHOST_OK, 0.45)
		else:
			_ghost_mat.albedo_color = Color(GHOST_BAD, 0.45)
	else:
		_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and selected != "":
			if _pick_ground():
				_try_place(_ground.x, _ground.z)
				get_viewport().set_input_as_handled()


func click_building(id: String) -> void:
	if id == "":
		return
	if not demolish:
		return
	var idx := _find_index(id)
	if idx < 0:
		return
	var b: Dictionary = GameState.buildings[idx]
	var tipo: String = str(b.get("type", ""))
	if tipo == "centro":
		_set_message("No se puede demoler el centro")
		return
	var cost: Dictionary = (Economy.BUILDINGS.get(tipo, {"coste": {"madera": 0, "piedra": 0}}) as Dictionary).get("coste", {"madera": 0, "piedra": 0})
	GameState.resources["madera"] = float(GameState.resources.get("madera", 0.0)) + float(cost.get("madera", 0)) * 0.5
	GameState.resources["piedra"] = float(GameState.resources.get("piedra", 0.0)) + float(cost.get("piedra", 0)) * 0.5
	GameState.resources_changed.emit()
	GameState.buildings.remove_at(idx)
	GameState.buildings_changed.emit()
	var n := _find_node(id)
	if n != null:
		n.queue_free()
	_set_message("Edificio demolido (+50%)")


func toggle_pause(id: String) -> void:
	var idx := _find_index(id)
	if idx < 0:
		return
	var b: Dictionary = GameState.buildings[idx]
	b["paused"] = not bool(b.get("paused", false))
	GameState.buildings_changed.emit()
	if bool(b.get("paused", false)):
		_set_message("Edificio pausado")
	else:
		_set_message("Edificio reanudado")


func _try_place(x: float, z: float) -> void:
	if selected == "" or not Economy.BUILDINGS.has(selected):
		return
	var tipo: String = selected
	if tipo == "centro":
		_set_message("El centro ya existe, no se puede construir")
		return
	var err: String = Economy.placement_error(x, z, tipo, GameState.buildings)
	if err != "":
		_set_message(err)
		return
	if not Economy.can_afford(GameState.resources, tipo):
		_set_message("Sin recursos")
		return
	GameState.resources = Economy.pay_cost(GameState.resources, tipo)
	GameState.resources_changed.emit()
	var hp: int = int(Economy.BUILDING_HP.get(tipo, 150))
	var radio: float = float((Economy.BUILDINGS[tipo] as Dictionary).get("radio", 2.0))
	var b := {
		"id": _next_id(),
		"type": tipo,
		"x": x,
		"z": z,
		"paused": false,
		"progress": 0.0,
		"blocked": false,
		"hp": hp,
		"max_hp": hp,
		"radio": radio,
		"build_t": 0.0,
	}
	GameState.buildings.append(b)
	GameState.buildings_changed.emit()
	AudioManager.play("build")
	var node := BuildingNode.new()
	add_child(node)
	node.setup(b)
	_set_message("Construido: %s" % str((Economy.BUILDINGS[tipo] as Dictionary).get("nombre", tipo)))


func _pick_ground() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_ground_valid = false
		return false
	var mp := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		_ground_valid = false
		return false
	var t: float = -origin.y / dir.y
	if t < 0.0:
		_ground_valid = false
		return false
	_ground = origin + dir * t
	_ground_valid = true
	return true


func _refresh_ghost_mesh() -> void:
	if _ghost == null or _ghost_mat == null:
		return
	for c in _ghost.get_children():
		_ghost.remove_child(c)
		c.queue_free()
	if selected == "" or not Economy.BUILDINGS.has(selected):
		return
	var preview := BuildingFactory.ghost_for(selected, "blue", _ghost_mat, "ghost")
	preview.name = "GhostVisual"
	_ghost.add_child(preview)


func _find_index(id: String) -> int:
	for i in range(GameState.buildings.size()):
		var b: Dictionary = GameState.buildings[i]
		if str(b.get("id", "")) == id:
			return i
	return -1


func _find_node(id: String) -> BuildingNode:
	for c in get_children():
		if c is BuildingNode and str((c as BuildingNode).data.get("id", "")) == id:
			return c as BuildingNode
	return null


func _next_id() -> String:
	var n := GameState.buildings.size() + 1
	var candidate := "b%d" % n
	while _find_index(candidate) >= 0:
		n += 1
		candidate = "b%d" % n
	return candidate


func _set_message(text: String) -> void:
	GameState.message = text
	GameState.message_changed.emit(text)
