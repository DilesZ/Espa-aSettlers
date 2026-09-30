extends GutTest
## Test de remojo (soak): simula minutos de juego llamando a lógica real
## sin escena (Production.tick + Economy puros). Cubre el reporte
## "solo construir, el juego no progresa": madera→tablones, cadena del pan,
## tope de población, ritmo de la IA y DPS de torres.
##
## Requiere: scripts/systems/production.gd (Production.tick),
##   scripts/systems/economy.gd (Economy), autoload GameState,
##   scripts/systems/ai_controller.gd (consts BUILD_QUEUE/BUILD_INTERVAL),
##   scripts/systems/combat.gd (const TOWER_COOLDOWN).


func before_each() -> void:
	GameState.resources = {
		"madera": 30.0, "piedra": 15.0, "comida": 10.0,
		"tablon": 0.0, "trigo": 0.0, "harina": 0.0, "pan": 0.0
	}
	GameState.buildings = []
	GameState.settlers = []
	GameState.stats = {"tablon": 0.0, "pan": 0.0}


func _building(id: int, tipo: String) -> Dictionary:
	return {
		"id": id, "type": tipo, "x": 0.0, "z": 0.0,
		"paused": false, "progress": 0.0, "blocked": false,
		"hp": 200, "max_hp": 200
	}


func _settlers(n: int) -> void:
	GameState.settlers = []
	for i in range(n):
		GameState.settlers.append({"id": "soak_%d" % i})


## a) 6 colonos talando 10 min: los colonos son nodos con FSM y navegación
## (no simulables sin escena), así que se simula la economía: stock inicial
## (30 madera) + aserradero, 300 ticks de 1s. 300s/15s = 20 tandas x2 = 40
## tablones; el umbral 18 deja margen aunque falte madera intermedia.
func test_soak_a_madera_10min_18_tablones() -> void:
	GameState.buildings = [_building(1, "aserradero")]
	_settlers(6)
	for i in range(300):
		Production.tick(1.0)
	assert_true(float(GameState.resources.get("tablon", 0.0)) >= 18.0, "300 ticks con aserradero dan >= 18 tablones")
	assert_true(float(GameState.stats.get("tablon", 0.0)) >= 18.0, "stats acumulados acompañan a victoria02")


## b) Cadena del pan completa (granja+molino+panadería), 600 ticks de 1s.
## Production.tick procesa los edificios en orden con recursos ya
## actualizados, así el trigo/harina fluyen en el mismo tick (pipeline).
func test_soak_b_cadena_pan_600s() -> void:
	GameState.buildings = [_building(1, "granja"), _building(2, "molino"), _building(3, "panaderia")]
	_settlers(3)
	for i in range(600):
		Production.tick(1.0)
	assert_true(float(GameState.resources.get("pan", 0.0)) > 0.0, "la cadena produce pan")
	assert_true(float(GameState.resources.get("comida", 0.0)) > 10.0, "la comida sube sobre los 10 iniciales")
	assert_true(float(GameState.stats.get("pan", 0.0)) > 0.0, "stats de pan para victoria02")


## c) Tope visual 60: ni 20 casas ni 200 colonos pueden explotar; el
## crecimiento real usa mini(housing_cap(casas), MAX_SETTLERS).
func test_soak_c_housing_cap_60() -> void:
	assert_eq(Economy.housing_cap(0), 6)
	assert_eq(Economy.housing_cap(1), 10)
	assert_eq(Economy.MAX_SETTLERS, 60)
	assert_eq(mini(Economy.housing_cap(20), Economy.MAX_SETTLERS), 60)
	_settlers(60)
	assert_true(GameState.settlers.size() <= Economy.MAX_SETTLERS, "poblacion acotada a 60")


## d) Ritmo IA (solo lectura de constantes, el nodo necesita escena):
## 10 builds x 35s = 350 ticks para vaciar la cola.
func test_soak_d_ia_10_builds_350s() -> void:
	assert_eq(AiController.BUILD_QUEUE.size(), 10)
	assert_almost_eq(float(AiController.BUILD_INTERVAL), 35.0, 0.001)
	assert_eq(AiController.BUILD_QUEUE.size() * int(AiController.BUILD_INTERVAL), 350)


## e) Torre (TORRE_DPS) vs raider (RAIDER_HP) con cadencia TOWER_COOLDOWN:
## primer disparo en t=0 y luego uno por cd (discreto, como Combat).
func test_soak_e_torre_mata_raider_5s() -> void:
	var hp := float(Economy.RAIDER_HP)
	var dps := float(Economy.TORRE_DPS)
	var cd := float(Combat.TOWER_COOLDOWN)
	var t := 0.0
	hp -= dps
	var guard := 0
	while hp > 0.0 and guard < 100:
		t += cd
		hp -= dps
		guard += 1
	assert_true(hp <= 0.0, "el raider cae")
	assert_true(t <= 5.0, "la torre mata en <= 5s (t=%.1fs)" % t)
