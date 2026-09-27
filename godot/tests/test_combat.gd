extends GutTest
## Tests puros de combate (Fase 03) sin escena: DPS de torre, coste de
## recluta, fórmula de tamaño de raid y condición de victoria03.
## Requiere: scripts/systems/economy.gd (class_name Economy con RAIDER_HP,
##   TORRE_DPS, RECRUIT_COST, housing_cap(), MAX_SETTLERS),
##   scripts/units/recruit.gd (class_name Recruit con static train())
##   y autoload GameState (reseteado en before_each).


func before_each() -> void:
	GameState.resources = {
		"madera": 100.0, "piedra": 50.0, "comida": 10.0,
		"tablon": 0.0, "trigo": 0.0, "harina": 0.0, "pan": 0.0
	}
	GameState.buildings = []
	GameState.settlers = []
	GameState.recruits = []
	GameState.raiders = []
	GameState.ai_buildings = []
	GameState.stats = {"tablon": 0.0, "pan": 0.0}
	GameState.victory = false
	GameState.victory02 = false
	GameState.victory03 = false
	GameState.defeat = false
	GameState.message = ""


func after_each() -> void:
	for n in get_tree().get_nodes_in_group("recruits"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("raiders"):
		n.queue_free()


## DPS: un raider de 40 HP bajo una torre de 10 DPS cae en 4s (bucle headless).
func test_dps_torre_40hp_10dps_mata_en_4s() -> void:
	var hp := float(Economy.RAIDER_HP) # 40
	var dps := float(Economy.TORRE_DPS) # 10
	var dt := 0.1
	var t := 0.0
	var iters := 0
	while hp > 0.0 and iters < 10000:
		hp -= dps * dt
		t += dt
		iters += 1
	assert_true(hp <= 0.0)
	assert_almost_eq(t, 4.0, 0.01)


## Coste de recluta: con 15 de comida, train() la deja a 0 y registra uno;
## sin comida devuelve error y no descuenta ni registra.
func test_coste_recluta_15_comida() -> void:
	GameState.resources["comida"] = 15.0
	GameState.buildings = [
		{"id": 1, "type": "centro", "x": 0.0, "z": 0.0, "hp": 500, "max_hp": 500}
	]
	var err: String = Recruit.train()
	assert_eq(err, "")
	assert_eq(float(GameState.resources["comida"]), 0.0)
	assert_eq(GameState.recruits.size(), 1)
	var err2: String = Recruit.train()
	assert_true(err2 != "")
	assert_eq(float(GameState.resources["comida"]), 0.0)
	assert_eq(GameState.recruits.size(), 1)


## Tamaño de raid: 3 + elapsed / 120, tope 8.
func _raid_size(elapsed: float) -> int:
	return mini(8, 3 + int(elapsed / 120.0))


func test_cap_raids_3_mas_elapsed_120_max_8() -> void:
	assert_eq(_raid_size(0.0), 3)
	assert_eq(_raid_size(119.0), 3)
	assert_eq(_raid_size(120.0), 4)
	assert_eq(_raid_size(240.0), 5)
	assert_eq(_raid_size(600.0), 8)
	assert_eq(_raid_size(3600.0), 8)


## Victoria03: no queda ningún centro de la IA en pie.
func _has_ai_centro() -> bool:
	for b in GameState.ai_buildings:
		if not (b is Dictionary):
			continue
		var d := b as Dictionary
		if str(d.get("type", "")) == "centro" and float(d.get("hp", 0.0)) > 0.0:
			return true
	return false


func test_victoria03_sin_centro_ia() -> void:
	GameState.ai_buildings = [
		{"id": "ai_torre_1", "type": "torre", "x": 16.0, "z": -20.0, "hp": 250.0}
	]
	assert_true(not _has_ai_centro())
	GameState.ai_buildings = [
		{"id": "ai_centro", "type": "centro", "x": 16.0, "z": -20.0, "hp": 500.0}
	]
	assert_true(_has_ai_centro())
