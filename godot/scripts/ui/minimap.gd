class_name Minimap
extends Control
## Minimapa 2D: fondo verde oscuro, río azul (x > 22), edificios con el color
## de Economy.BUILDINGS y colonos como puntos amarillos.
## Escala: mapa [-32, 32] -> tamaño del control. Redibuja cada 0.5 s.

const WORLD_MIN := -32.0
const WORLD_SIZE := 64.0
const WATER_X := 22.0
const POLL := 0.5

const BG := Color(0.07, 0.23, 0.16)
const RIVER := Color(0.15, 0.45, 0.85)
const SETTLER := Color(0.95, 0.85, 0.25)
const FALLBACK := Color(0.80, 0.80, 0.80)

var _accum := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(140, 140)


func _ready() -> void:
	custom_minimum_size = Vector2(140, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL:
		_accum = 0.0
		queue_redraw()


func _to_map(x: float, z: float) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		(x - WORLD_MIN) / WORLD_SIZE * size.x,
		(z - WORLD_MIN) / WORLD_SIZE * size.y
	)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BG, true)
	# Río: franja x > 22.
	var x0 := (WATER_X - WORLD_MIN) / WORLD_SIZE * size.x
	if x0 < size.x:
		draw_rect(Rect2(x0, 0.0, size.x - x0, size.y), RIVER, true)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		for b in (gs.get("buildings") as Array):
			var bd: Dictionary = b
			var t := str(bd.get("type", ""))
			var col := FALLBACK
			var info: Dictionary = Economy.BUILDINGS.get(t, {})
			if info.has("color"):
				col = Color(str(info["color"]))
			var p := _to_map(float(bd.get("x", 0.0)), float(bd.get("z", 0.0)))
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), col, true)
		for s in (gs.get("settlers") as Array):
			draw_circle(_settler_pos(s), 2.0, SETTLER)
	draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)


func _settler_pos(s: Variant) -> Vector2:
	if s is Dictionary:
		var d: Dictionary = s
		return _to_map(float(d.get("x", 0.0)), float(d.get("z", 0.0)))
	if s is Node3D:
		var n: Node3D = s
		return _to_map(n.position.x, n.position.z)
	return Vector2.ZERO
