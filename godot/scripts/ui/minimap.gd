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
const BG2 := Color(0.10, 0.29, 0.19)
const RELIEF_CELLS := 16
const RIVER := Color(0.15, 0.45, 0.85)
const SETTLER := Color(0.95, 0.85, 0.25)
const FALLBACK := Color(0.80, 0.80, 0.80)
const FOG_HIDDEN := Color(0, 0, 0, 0.85)
const FOG_EXPLORED := Color(0, 0, 0, 0.4)

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
	_draw_relief(r)
	# Río: franja x > 22.
	var x0 := (WATER_X - WORLD_MIN) / WORLD_SIZE * size.x
	if x0 < size.x:
		draw_rect(Rect2(x0, 0.0, size.x - x0, size.y), RIVER, true)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		_draw_fog(gs)
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


func _draw_relief(r: Rect2) -> void:
	# Fondo verde con 2 tonos: ruido determinista por celda para dar relieve.
	# Hash entero estable (sin rand): misma celda -> mismo tono siempre.
	if size.x <= 0.0 or size.y <= 0.0:
		draw_rect(r, BG, true)
		return
	var cw := size.x / float(RELIEF_CELLS)
	var ch := size.y / float(RELIEF_CELLS)
	for cy in range(RELIEF_CELLS):
		for cx in range(RELIEF_CELLS):
			var h := (cx * 73 + cy * 137 + cx * cy * 31) & 0x7fffffff
			var col := BG if h % 2 == 0 else BG2
			draw_rect(Rect2(Vector2(cx * cw, cy * ch), Vector2(cw + 0.5, ch + 0.5)), col, true)


func _draw_fog(gs: Node) -> void:
	# Overlay por celda 32x32: 0=inexplorado (oscuro), 1=explorado (semi),
	# 2=visible (sin overlay). Se dibuja antes que edificios/colonos.
	var fog: PackedInt32Array = gs.get("fog")
	if fog.size() != 32 * 32:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var cw := size.x / 32.0
	var ch := size.y / 32.0
	for cz in range(32):
		for cx in range(32):
			var v := int(fog[cz * 32 + cx])
			if v == 2:
				continue
			var col := FOG_HIDDEN if v == 0 else FOG_EXPLORED
			draw_rect(Rect2(Vector2(cx * cw, cz * ch), Vector2(cw + 0.5, ch + 0.5)), col, true)


func _settler_pos(s: Variant) -> Vector2:
	if s is Dictionary:
		var d: Dictionary = s
		return _to_map(float(d.get("x", 0.0)), float(d.get("z", 0.0)))
	if s is Node3D:
		var n: Node3D = s
		return _to_map(n.position.x, n.position.z)
	return Vector2.ZERO
