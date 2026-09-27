extends GutTest
## Espejo de lib/economy.test.ts — economía fases 01-02 (regresión).
## Requiere godot/scripts/systems/economy.gd con class_name Economy y API:
##   BUILDINGS / RECIPES (Dictionary), empty_resources(), can_afford(res, tipo),
##   pay_cost(res, tipo), placement_error(x, z, tipo, placed), is_victory(res),
##   is_victory02(stats), simulate_production(receta, stock, segundos),
##   storage_cap(n), housing_cap(n).
## placement_error devuelve String con el motivo o null/"" si es válido.
## placed: Array de Dictionary {x, z, radio}.


func _res(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = Economy.empty_resources()
	for k in overrides.keys():
		base[k] = overrides[k]
	return base


func _is_ok(err: Variant) -> bool:
	return err == null or (err is String and err == "")


func test_centro_gratis_casa_cuesta_15_5() -> void:
	assert_true(Economy.can_afford(_res({}), "centro"))
	assert_false(Economy.can_afford(_res({ "madera": 14.0, "piedra": 5.0 }), "casa"))
	assert_true(Economy.can_afford(_res({ "madera": 15.0, "piedra": 5.0 }), "casa"))


func test_pay_cost_descuenta() -> void:
	var r: Dictionary = Economy.pay_cost(_res({ "madera": 20.0, "piedra": 10.0 }), "almacen")
	assert_eq(r["madera"], 0.0)
	assert_eq(r["piedra"], 0.0)


func test_placement_rechaza_agua_borde_y_colision() -> void:
	assert_eq(Economy.placement_error(25.0, 0.0, "casa", []), "En el agua")
	assert_eq(Economy.placement_error(40.0, 0.0, "casa", []), "Fuera del mapa")
	assert_eq(
		Economy.placement_error(0.0, 0.0, "casa", [{ "x": 1.0, "z": 1.0, "radio": 3.0 }]),
		"Colisiona con otro edificio"
	)
	assert_true(_is_ok(Economy.placement_error(-10.0, -10.0, "casa", [])))


func test_victoria_50_30() -> void:
	assert_true(Economy.is_victory(_res({ "madera": 50.0, "piedra": 30.0 })))
	assert_false(Economy.is_victory(_res({ "madera": 49.0, "piedra": 30.0 })))
	assert_true(Economy.BUILDINGS.has("lenador"))


func test_pescador_exige_cercania_al_rio() -> void:
	assert_eq(
		Economy.placement_error(0.0, 0.0, "pescador", []),
		"El pescador debe estar junto al río (x≥12)"
	)
	assert_true(_is_ok(Economy.placement_error(15.0, 0.0, "pescador", [])))


func test_throughput_aserradero_300s_20_tandas() -> void:
	var recipe: Dictionary = Economy.RECIPES["aserradero"]
	var out: Dictionary = Economy.simulate_production(recipe, _res({ "madera": 100.0 }), 300.0)
	# 300s/15s = 20 tandas -> 40 tablones, 80 madera restante
	assert_eq(out["batches"], 20)
	assert_eq(out["stock"]["tablon"], 40.0)
	assert_eq(out["stock"]["madera"], 80.0)


func test_cadena_pan_encadenada_10_10() -> void:
	var trigo: Dictionary = Economy.simulate_production(Economy.RECIPES["granja"], _res({}), 200.0)
	assert_eq(trigo["batches"], 10) # 200/20
	var harina: Dictionary = Economy.simulate_production(Economy.RECIPES["molino"], trigo["stock"], 120.0)
	assert_eq(harina["batches"], 10) # 120/12, trigo justo
	var pan: Dictionary = Economy.simulate_production(Economy.RECIPES["panaderia"], harina["stock"], 150.0)
	assert_eq(pan["batches"], 10)
	assert_eq(pan["stock"]["pan"], 10.0)
	assert_eq(pan["stock"]["comida"], 50.0)


func test_sin_inputs_no_produce_bloqueo() -> void:
	var out: Dictionary = Economy.simulate_production(Economy.RECIPES["molino"], _res({}), 600.0)
	assert_eq(out["batches"], 0)


func test_caps_almacen_100_casa_4_colonos() -> void:
	assert_eq(Economy.storage_cap(0), 200)
	assert_eq(Economy.storage_cap(2), 400)
	assert_eq(Economy.housing_cap(0), 6)
	assert_eq(Economy.housing_cap(3), 18)


func test_victoria02_20_tablones_15_pan() -> void:
	assert_true(Economy.is_victory02({ "tablon": 20.0, "pan": 15.0 }))
	assert_false(Economy.is_victory02({ "tablon": 19.0, "pan": 15.0 }))
