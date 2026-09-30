class_name GameEvents
extends Node
## Sistema de eventos aleatorios: la peste.
## Uso: otro trabajo lo añadira como hijo de Main; no requiere escena ni cableado.
## Reloj propio (`elapsed`): sin eventos antes del minuto 5; luego un evento
## cada 4-6 min aleatorios. Al saltar: aviso 30 s antes y al llegar resolucion
## (banquete protector si hay 20 de comida: 15% de bajas; si no: 30%).
## Siempre deja al menos MIN_SURVIVORS colonos vivos. Sin dependencias nuevas.

signal plague_warned(message: String)
signal plague_resolved(deaths: int, banquet: bool)

const START_DELAY := 300.0 ## Minuto 5: antes no hay eventos.
const MIN_INTERVAL := 240.0 ## 4 min entre eventos.
const MAX_INTERVAL := 360.0 ## 6 min entre eventos.
const WARNING_TIME := 30.0 ## Aviso previo a la llegada de la peste.
const BANQUET_COST := 20.0 ## Comida que consume el banquete protector.
const BANQUET_RATE := 0.15 ## Mortalidad con banquete.
const PLAGUE_RATE := 0.30 ## Mortalidad sin banquete.
const MIN_SURVIVORS := 3 ## Siempre quedan al menos 3 colonos vivos.

const WARNING_MESSAGE := "¡Se acerca la peste! Acumula 20🌾 para un banquete protector."

var elapsed := 0.0 ## Reloj propio de partida (segundos).

var _next_event_at := START_DELAY
var _pending := false
var _plague_at := 0.0


func _ready() -> void:
	_next_event_at = START_DELAY
	_pending = false


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta
	if _pending:
		if elapsed >= _plague_at:
			_resolve_plague()
	elif elapsed >= _next_event_at:
		_warn_plague()


## Aviso 30 s antes: mensaje + alarma (nulo-segura).
func _warn_plague() -> void:
	_pending = true
	_plague_at = elapsed + WARNING_TIME
	_set_message(WARNING_MESSAGE)
	_play_alarm()
	if has_signal("plague_warned"):
		plague_warned.emit(WARNING_MESSAGE)


## Llegada de la peste: banquete si hay comida, matanza y reprogramacion.
func _resolve_plague() -> void:
	_pending = false
	_next_event_at = elapsed + randf_range(MIN_INTERVAL, MAX_INTERVAL)
	var food := float(GameState.resources.get("comida", 0.0))
	var banquet := food >= BANQUET_COST
	if banquet:
		GameState.resources["comida"] = food - BANQUET_COST
		_emit_resources_changed()
	var rate := BANQUET_RATE if banquet else PLAGUE_RATE
	var deaths := _kill_settlers(rate)
	var text := ""
	if banquet:
		text = "El banquete contiene la peste (%d bajas)." % deaths
	else:
		text = "La peste se lleva a %d colonos." % deaths
	if deaths <= 0:
		text = "La peste pasa sin llevarse a nadie."
	_set_message(text)
	if has_signal("plague_resolved"):
		plague_resolved.emit(deaths, banquet)


## Mata al azar la fraccion `rate` de colonos, dejando MIN_SURVIVORS vivos.
## Devuelve el numero de bajas. queue_free del nodo + borra dict por id.
func _kill_settlers(rate: float) -> int:
	var candidates := _collect_settler_nodes()
	var count := candidates.size()
	if count <= MIN_SURVIVORS:
		return 0
	var want := int(floor(float(count) * rate))
	var deaths := clampi(want, 0, count - MIN_SURVIVORS)
	if deaths <= 0:
		return 0
	candidates.shuffle()
	var ids: Dictionary = {}
	for i in deaths:
		var n: Node = candidates[i] as Node
		if n == null or not is_instance_valid(n):
			continue
		var sid := String(n.get("settler_id")) if _has_prop(n, "settler_id") else ""
		if sid != "":
			ids[sid] = true
		n.queue_free()
	if not ids.is_empty():
		for i in range(GameState.settlers.size() - 1, -1, -1):
			var d: Variant = GameState.settlers[i]
			if d is Dictionary and ids.has(String((d as Dictionary).get("id", ""))):
				GameState.settlers.remove_at(i)
	return deaths


## Recoge los nodos de colono vivos: por clase `Settler` (global) con guard
## ClassDB, con fallback a nodos con propiedad `settler_id`.
func _collect_settler_nodes() -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	var root: Node = tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return out
	var use_class := ClassDB.class_exists("Settler")
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n == null or not is_instance_valid(n):
			continue
		if n != self and n != root:
			var is_settler := false
			if use_class and (n is Settler):
				is_settler = true
			elif _has_prop(n, "settler_id"):
				is_settler = true
			if is_settler:
				out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


static func _has_prop(n: Node, prop: String) -> bool:
	for p in n.get_property_list():
		if str((p as Dictionary).get("name", "")) == prop:
			return true
	return false


func _set_message(text: String) -> void:
	GameState.message = text
	if GameState.has_signal("message_changed"):
		GameState.message_changed.emit(text)


func _emit_resources_changed() -> void:
	if GameState.has_signal("resources_changed"):
		GameState.resources_changed.emit()


## Alarma nulo-segura: no falla si el autoload falta (p. ej. en tests).
func _play_alarm() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play"):
		am.call("play", "alarm")
