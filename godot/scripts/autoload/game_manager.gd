extends Node
## GameManager: tick global determinista (ex-store tick).

const DT_CAP := 0.1
var elapsed := 0.0
var _spawned := false

func _ready() -> void:
	if GameState.buildings.is_empty():
		GameState.buildings.append({
			"id": 1, "type": "centro", "x": 0.0, "z": 0.0,
			"paused": false, "progress": 0.0, "blocked": false,
			"hp": Economy.BUILDING_HP["centro"], "max_hp": Economy.BUILDING_HP["centro"],
		})

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
