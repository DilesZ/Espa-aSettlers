extends GutTest
## Espejo de lib/fog.test.ts — niebla de guerra.


func _empty_fog() -> PackedInt32Array:
	var fog := PackedInt32Array()
	fog.resize(Fog.FOG_N * Fog.FOG_N)
	fog.fill(0)
	return fog


func test_celda_centro_y_esquinas() -> void:
	assert_eq(Fog.cell_of(0.0, 0.0), 16 * Fog.FOG_N + 16)
	assert_eq(Fog.cell_of(-40.0, -40.0), 0)
	assert_eq(Fog.cell_of(40.0, 40.0), Fog.FOG_N * Fog.FOG_N - 1)


func test_viewer_revela_y_resto_decae_a_explorado() -> void:
	var prev := _empty_fog()
	var v1 := Fog.compute_fog(prev, [{ "x": 0.0, "z": 0.0, "range": 8.0 }])
	assert_true(Fog.is_cell_visible(v1, 0.0, 0.0))
	assert_false(Fog.is_cell_visible(v1, 20.0, 20.0))
	var v2 := Fog.compute_fog(v1, [])
	assert_eq(v2[16 * Fog.FOG_N + 16], 1) # explorado, no visible


func test_torre_ve_mas_lejos_que_colono() -> void:
	var prev := _empty_fog()
	assert_false(Fog.is_cell_visible(Fog.compute_fog(prev, [{ "x": 0.0, "z": 0.0, "range": 5.0 }]), 0.0, 7.0))
	assert_true(Fog.is_cell_visible(Fog.compute_fog(prev, [{ "x": 0.0, "z": 0.0, "range": 16.0 }]), 0.0, 7.0))
