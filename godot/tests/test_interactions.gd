extends GutTest
## Interacciones jugables (reparación "solo construir"): placement de los 13
## tipos, costes, demolish 50%, pausa toggle, train con/sin vivienda (+2 del
## centro) y reset completo. Todo sin escena: lógica pura + BuildManager nuevo
## (sin árbol) + Hud.reset_state_data(). GameState reseteado en before_each.

const TIPOS_13: Array[String] = [
	"lenador", "cantera", "casa", "almacen", "aserradero", "granja",
	"molino", "panaderia", "pescador", "torre", "muralla", "puerta", "mercado",
]


func before_each() -> void:
	GameState.resources = {
		"madera": 200.0, "piedra": 200.0, "comida": 50.0,
		"tablon": 0.0, "trigo": 0.0, "harina": 0.0, "pan": 0.0,
	}
	GameState.buildings = [
		{
			"id": "c0", "type": "centro", "x": 0.0, "z": 0.0,
			"paused": false, "progress": 0.0, "blocked": false,
			"hp": 500.0, "max_hp": 500.0, "radio": 3.0, "build_t": 5.0,
		}
	]
	GameState.settlers = []
	GameState.recruits = []
	GameState.raiders = []
	GameState.ai_buildings = []
	GameState.ai_queue = 0
	GameState.nodes = []
	GameState.stats = {"tablon": 0.0, "pan": 0.0}
	GameState.fog.resize(32 * 32)
	GameState.fog.fill(0)
	GameState.message = ""
	GameState.victory = false
	GameState.victory02 = false
	GameState.victory03 = false
	GameState.defeat = false
	Settler._next_id = 0
	Recruit._next_id = 0
	Captain._next_id = 0
	Explorer._next_id = 0


func after_each() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("recruits"):
		if is_instance_valid(n):
			(n as Node).queue_free()
	var scopes: Array = []
	if tree.current_scene != null:
		scopes.append(tree.current_scene)
	if tree.root != null:
		scopes.append(tree.root)
	for scope in scopes:
		if not is_instance_valid(scope):
			continue
		for n in (scope as Node).find_children("*", "CharacterBody3D", true, false):
			if (n is Settler or n is Recruit or n is Captain or n is Explorer) and is_instance_valid(n):
				(n as Node).queue_free()


func _free_mgr(mgr: BuildManager) -> void:
	for c in mgr.get_children():
		c.free()
	mgr.free()


func test_13_tipos_existen_y_centro_bloqueado() -> void:
	for t in TIPOS_13:
		assert_true(Economy.BUILDINGS.has(t), "falta tipo colocable: " + t)
	assert_true(Economy.BUILDINGS.has("centro"))
	var mgr := BuildManager.new()
	mgr.select_building("centro")
	assert_eq(mgr.selected, "")
	assert_true(str(GameState.message).to_lower().contains("centro"))
	mgr.select_building("no_existe")
	assert_eq(mgr.selected, "")
	_free_mgr(mgr)


func test_placement_13_tipos_posicion_valida() -> void:
	for t in TIPOS_13:
		var pos := Vector2(-10.0, -10.0)
		if t == "pescador":
			pos = Vector2(15.0, 0.0) # junto al río x≥12, fuera del agua x≤22
		var err: String = Economy.placement_error(pos.x, pos.y, t, [])
		assert_eq(err, "", "tipo bloqueado: " + t + " -> " + err)


func test_placement_pescador_muralla_puerta_mercado() -> void:
	assert_eq(
		Economy.placement_error(0.0, 0.0, "pescador", []),
		"El pescador debe estar junto al río (x≥12)"
	)
	assert_eq(Economy.placement_error(15.0, 0.0, "pescador", []), "")
	assert_eq(Economy.placement_error(25.0, 0.0, "pescador", []), "En el agua")
	# Muralla/puerta/mercado colocan como un edificio normal (sin regla extra).
	assert_eq(Economy.placement_error(-10.0, -10.0, "muralla", []), "")
	assert_eq(Economy.placement_error(-10.0, -10.0, "puerta", []), "")
	assert_eq(Economy.placement_error(-10.0, -10.0, "mercado", []), "")


func test_placement_rechaza_agua_borde_colision() -> void:
	assert_eq(Economy.placement_error(25.0, 0.0, "casa", []), "En el agua")
	assert_eq(Economy.placement_error(40.0, 0.0, "casa", []), "Fuera del mapa")
	assert_eq(
		Economy.placement_error(0.5, 0.5, "casa", GameState.buildings),
		"Colisiona con otro edificio"
	)


func test_costes_muestran_lo_que_cuestan() -> void:
	# La paleta lee Economy.BUILDINGS[t]["coste"]: verifica valores esperados
	# y que can_afford/pay_cost cuadran con ellos.
	var esperados := {
		"casa": [15, 5], "muralla": [5, 0], "puerta": [8, 2], "mercado": [25, 15],
		"pescador": [15, 0], "torre": [15, 10], "lenador": [10, 0],
	}
	for t in esperados.keys():
		var c: Dictionary = Economy.BUILDINGS[t]["coste"]
		assert_eq(int(c.get("madera", -1)), (esperados[t] as Array)[0], "madera " + t)
		assert_eq(int(c.get("piedra", -1)), (esperados[t] as Array)[1], "piedra " + t)
		var res := {"madera": float((esperados[t] as Array)[0]), "piedra": float((esperados[t] as Array)[1])}
		assert_true(Economy.can_afford(res, t))
		var pagado: Dictionary = Economy.pay_cost(res, t)
		assert_eq(int(pagado["madera"]), 0)
		assert_eq(int(pagado["piedra"]), 0)


func test_try_place_coloca_descuenta_y_mensaje() -> void:
	var mgr := BuildManager.new()
	mgr.select_building("lenador")
	var antes_mad: float = float(GameState.resources["madera"])
	mgr._try_place(-10.0, -10.0)
	assert_eq(GameState.buildings.size(), 2)
	assert_eq(float(GameState.resources["madera"]), antes_mad - 10.0)
	assert_true(str(GameState.message).begins_with("Construido"))
	# Sin recursos no coloca y avisa.
	GameState.resources["madera"] = 0.0
	GameState.resources["piedra"] = 0.0
	mgr.select_building("casa")
	mgr._try_place(10.0, 10.0)
	assert_eq(GameState.buildings.size(), 2)
	assert_eq(GameState.message, "Sin recursos")
	_free_mgr(mgr)


func test_demoler_devuelve_50_y_libera() -> void:
	GameState.buildings.append({
		"id": "b9", "type": "casa", "x": -10.0, "z": -10.0,
		"paused": false, "progress": 0.0, "blocked": false,
		"hp": 150.0, "max_hp": 150.0, "radio": 2.0, "build_t": 5.0,
	})
	GameState.resources["madera"] = 0.0
	GameState.resources["piedra"] = 0.0
	var mgr := BuildManager.new()
	# Sin modo demolición no hace nada.
	mgr.click_building("b9")
	assert_eq(GameState.buildings.size(), 2)
	mgr.toggle_demolish()
	mgr.click_building("b9")
	assert_eq(GameState.buildings.size(), 1)
	assert_eq(float(GameState.resources["madera"]), 7.5) # 15 * 50%
	assert_eq(float(GameState.resources["piedra"]), 2.5) # 5 * 50%
	assert_eq(GameState.message, "Edificio demolido (+50%)")
	_free_mgr(mgr)


func test_demoler_centro_bloqueado() -> void:
	var mgr := BuildManager.new()
	mgr.toggle_demolish()
	mgr.click_building("c0")
	assert_eq(GameState.buildings.size(), 1)
	assert_eq(GameState.message, "No se puede demoler el centro")
	_free_mgr(mgr)


func test_pausa_toggle() -> void:
	GameState.buildings.append({
		"id": "p1", "type": "aserradero", "x": -10.0, "z": -10.0,
		"paused": false, "progress": 0.4, "blocked": false,
		"hp": 200.0, "max_hp": 200.0, "radio": 2.5, "build_t": 5.0,
	})
	var mgr := BuildManager.new()
	mgr.toggle_pause("p1")
	assert_true(bool(GameState.buildings[1].get("paused", false)))
	assert_eq(GameState.message, "Edificio pausado")
	mgr.toggle_pause("p1")
	assert_false(bool(GameState.buildings[1].get("paused", true)))
	assert_eq(GameState.message, "Edificio reanudado")
	mgr.toggle_pause("inexistente") # no debe romper
	_free_mgr(mgr)


func test_train_recluta_ok_con_bonus_centro() -> void:
	# 0 casas -> cap 6+2=8; 6 colonos iniciales ya no bloquean.
	for i in 6:
		GameState.settlers.append({"id": "s%d" % i})
	GameState.resources["comida"] = 20.0
	var err: String = Recruit.train()
	assert_eq(err, "")
	assert_eq(GameState.recruits.size(), 1)
	assert_eq(float(GameState.resources["comida"]), 5.0)


func test_train_bloqueado_sin_vivienda_pide_casas() -> void:
	for i in 6:
		GameState.settlers.append({"id": "s%d" % i})
	GameState.recruits = [{"id": "r0"}, {"id": "r1"}] # 8/8 con bonus centro
	GameState.resources["comida"] = 100.0
	assert_true(Recruit.train().to_lower().contains("casa"))
	assert_true(Captain.train().to_lower().contains("casa"))
	assert_true(Explorer.train().to_lower().contains("casa"))
	assert_eq(GameState.recruits.size(), 2)


func test_train_sin_comida_error_claro() -> void:
	GameState.resources["comida"] = 0.0
	var err_r: String = Recruit.train()
	assert_true(err_r.contains("15"))
	assert_true(err_r.to_lower().contains("comida"))
	GameState.resources["comida"] = 5.0
	assert_true(Explorer.train().contains("10"))
	GameState.resources["comida"] = 20.0
	assert_true(Captain.train().contains("30"))


func test_train_capitan_y_explorador_descuentan() -> void:
	GameState.resources["comida"] = 100.0
	assert_eq(Captain.train(), "")
	assert_eq(float(GameState.resources["comida"]), 70.0)
	assert_eq(Explorer.train(), "")
	assert_eq(float(GameState.resources["comida"]), 60.0)
	assert_eq(GameState.recruits.size(), 2)


func test_reset_completo() -> void:
	GameState.buildings.append({"id": "bx", "type": "casa", "x": 5.0, "z": 5.0})
	GameState.settlers = [{"id": "s0"}]
	GameState.recruits = [{"id": "r0"}]
	GameState.raiders = [{"id": "rd0"}]
	GameState.ai_buildings = [{"id": "ai9", "type": "torre", "x": 1.0, "z": 1.0, "hp": 10.0}]
	GameState.ai_queue = 3
	GameState.stats = {"tablon": 9.0, "pan": 9.0}
	GameState.fog.fill(2)
	GameState.victory = true
	GameState.victory02 = true
	GameState.defeat = true
	GameState.message = "algo"
	Hud.reset_state_data()
	assert_eq(float(GameState.resources["madera"]), 30.0)
	assert_eq(float(GameState.resources["piedra"]), 15.0)
	assert_eq(float(GameState.resources["comida"]), 10.0)
	assert_eq(GameState.buildings.size(), 1)
	assert_eq(str(GameState.buildings[0].get("type", "")), "centro")
	assert_true(GameState.settlers.is_empty())
	assert_true(GameState.recruits.is_empty())
	assert_true(GameState.raiders.is_empty())
	assert_eq(GameState.ai_buildings.size(), 1)
	assert_eq(str(GameState.ai_buildings[0].get("id", "")), "ai_centro")
	assert_eq(int(GameState.ai_queue), 0)
	assert_eq(float(GameState.stats.get("tablon", -1.0)), 0.0)
	assert_eq(float(GameState.stats.get("pan", -1.0)), 0.0)
	assert_false(GameState.victory)
	assert_false(GameState.victory02)
	assert_false(GameState.victory03)
	assert_false(GameState.defeat)
	assert_eq(str(GameState.message), "")
	for v in GameState.fog:
		assert_eq(v, 0)
