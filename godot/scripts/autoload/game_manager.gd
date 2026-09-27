extends Node
## GameManager: tick global determinista (ex-store tick).

const DT_CAP := 0.1
const GROW_TIME := 60.0
var elapsed := 0.0
var _spawned := false
var _grow_t := 0.0

func _ready() -> void:
	if GameState.buildings.is_empty():
		GameState.buildings.append({
			"id": 1, "type": "centro", "x": 0.0, "z": 0.0,
			"paused": false, "progress": 0.0, "blocked": false,
			"hp": Economy.BUILDING_HP["centro"], "max_hp": Economy.BUILDING_HP["centro"],
		})
	if GameState.ai_buildings.is_empty():
		GameState.ai_buildings.append({
			"id": "ai_centro", "type": "centro",
			"x": float(Economy.AI_BASE["x"]), "z": float(Economy.AI_BASE["z"]), "hp": 300.0,
		})
		var scene := get_tree().current_scene
		if scene:
			var node := AiBuildingNode.new()
			node.setup(GameState.ai_buildings[0])
			scene.add_child.call_deferred(node)

func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, DT_CAP)
	elapsed += dt
	if not _spawned:
		_spawned = true
		var scene := get_tree().current_scene
		for i in 6:
			var s := Settler.spawn(Vector3(randf_range(-2.0, 2.0), 0.0, 4.0 + randf_range(-2.0, 2.0)))
			scene.add_child.call_deferred(s)
	Production.tick(dt)
	Combat.tick(dt)
	_tick_growth(dt)
	_tick_victory()


## Crecimiento: +1 colono cada 60s si hay comida (10) y vivienda libre.
func _tick_growth(dt: float) -> void:
	_grow_t += dt
	if _grow_t < GROW_TIME:
		return
	_grow_t = 0.0
	var casas := 0
	for b in GameState.buildings:
		if b is Dictionary and String((b as Dictionary).get("type", "")) == "casa":
			casas += 1
	var hcap: int = mini(Economy.housing_cap(casas), Economy.MAX_SETTLERS)
	if GameState.settlers.size() < hcap and float(GameState.resources.get("comida", 0.0)) >= 10.0:
		GameState.resources["comida"] = float(GameState.resources.get("comida", 0.0)) - 10.0
		GameState.resources_changed.emit()
		var s := Settler.spawn(Vector3(0.0, 0.0, 4.0))
		get_tree().current_scene.add_child.call_deferred(s)


## Victorias: solo se escriben una vez (bandera previa), Fase 02 tiene prioridad.
func _tick_victory() -> void:
	if not GameState.victory and Economy.is_victory(GameState.resources):
		GameState.victory = true
		_set_message("¡Victoria del slice! %d madera + %d piedra." % [Economy.WIN_MADERA, Economy.WIN_PIEDRA])
		AudioManager.play("win")
	if not GameState.victory02 and Economy.is_victory02(GameState.stats):
		GameState.victory02 = true
		_set_message("¡Victoria Fase 02! %d tablones + %d pan producidos." % [Economy.WIN_TABLON, Economy.WIN_PAN])
		AudioManager.play("win")


func _set_message(text: String) -> void:
	GameState.message = text
	GameState.message_changed.emit(text)
