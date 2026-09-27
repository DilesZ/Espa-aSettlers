extends GutTest
## Tests del sistema de producción (Fase 02).
## Requiere: scripts/systems/production.gd (class_name Production),
##   scripts/systems/economy.gd (class_name Economy) y autoload GameState.


func before_each() -> void:
	GameState.resources = {
		"madera": 100.0, "piedra": 50.0, "comida": 10.0,
		"tablon": 0.0, "trigo": 0.0, "harina": 0.0, "pan": 0.0
	}
	GameState.buildings = [
		{
			"id": 1, "type": "aserradero", "x": 0.0, "z": 0.0,
			"paused": false, "progress": 0.0, "blocked": false,
			"hp": 200, "max_hp": 200
		}
	]
	GameState.settlers = [{"id": 0}]
	GameState.stats = {"tablon": 0.0, "pan": 0.0}


func test_aserradero_300s_20_tandas_40_tablon() -> void:
	for i in range(20):
		Production.tick(15.0)
	assert_eq(float(GameState.resources["tablon"]), 40.0)
	assert_eq(float(GameState.resources["madera"]), 80.0)
	assert_eq(float(GameState.stats["tablon"]), 40.0)
	assert_eq(float(GameState.buildings[0].get("progress", -1.0)), 0.0)


func test_bloqueo_sin_inputs() -> void:
	GameState.resources["madera"] = 0.0
	var out: Dictionary = Production.tick(15.0)
	assert_eq(float(out.get("tablon_made", -1.0)), 0.0)
	assert_eq(float(GameState.resources["tablon"]), 0.0)
	assert_eq(float(GameState.stats["tablon"]), 0.0)
	assert_true(bool(GameState.buildings[0].get("blocked", false)))


func test_pausa_no_produce_y_progress_cero() -> void:
	var b: Dictionary = GameState.buildings[0]
	b["paused"] = true
	b["progress"] = 0.5
	GameState.buildings[0] = b
	var out: Dictionary = Production.tick(15.0)
	assert_eq(float(out.get("tablon_made", -1.0)), 0.0)
	assert_eq(float(GameState.resources["tablon"]), 0.0)
	assert_eq(float(GameState.buildings[0].get("progress", -1.0)), 0.0)


func test_workers_insuficientes_sin_produccion() -> void:
	GameState.settlers = []
	var out: Dictionary = Production.tick(15.0)
	assert_eq(float(out.get("tablon_made", -1.0)), 0.0)
	assert_eq(float(GameState.resources["tablon"]), 0.0)
	assert_eq(float(GameState.resources["madera"]), 100.0)
	assert_eq(float(GameState.stats["tablon"]), 0.0)


func test_cap_storage_clamp() -> void:
	assert_eq(Economy.storage_cap(0), 200)
	assert_eq(Economy.storage_cap(1), 300)
	GameState.resources["tablon"] = 199.0
	GameState.resources["madera"] = 100.0
	Production.tick(15.0)
	# 199 + 2 = 201 -> clamp a 200.
	assert_eq(float(GameState.resources["tablon"]), 200.0)
	assert_eq(float(GameState.stats["tablon"]), 2.0)
