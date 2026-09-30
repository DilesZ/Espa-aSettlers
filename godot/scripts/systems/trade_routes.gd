class_name TradeRoutes
extends Node3D
## Rutas comerciales del Mercado: 1 mula por mercado propio en ping-pong
## Mercado<->Centro (0,0) a 4 m/s. Cada llegada al Centro entrega alternando
## +6 comida / +4 madera / +4 piedra con clamp a Economy.storage_cap.
## Mensaje solo 1 de cada 3 entregas + AudioManager.play("coin") nulo-seguro.
## Revisa cada 1s (crea/elimina mulas). Visual 100% procedural, sin deps nuevas.
## Hijo de Main (lo cablea otro trabajo). La paleta del HUD itera
## Economy.BUILDINGS dinamicamente, asi que el mercado aparece solo.

const SPEED := 4.0
const REVIEW_INTERVAL := 1.0
const CENTER := Vector3(0.0, 0.0, 0.0)

var _review_t := 0.0
var _deliveries := 0
var _next_cargo := 0
var _mules: Dictionary = {}


func _ready() -> void:
	_review()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_review_t += delta
	if _review_t >= REVIEW_INTERVAL:
		_review_t = 0.0
		_review()
	_update_mules(delta)


## Sincroniza mulas con mercados propios de GameState.buildings.
func _review() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not is_instance_valid(gs):
		return
	var b_v: Variant = gs.get("buildings")
	if not (b_v is Array):
		return
	var want: Dictionary = {}
	for b in (b_v as Array):
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		if str(bd.get("type", "")) != "mercado":
			continue
		var mid := str(bd.get("id", ""))
		if mid == "":
			mid = "%s_%s" % [str(bd.get("x", 0.0)), str(bd.get("z", 0.0))]
		var mp := Vector3(float(bd.get("x", 0.0)), 0.0, float(bd.get("z", 0.0)))
		want[mid] = mp
	for mid in _mules.keys():
		if not want.has(mid):
			var entry: Dictionary = _mules[mid]
			var n: Node = entry.get("node")
			if n != null and is_instance_valid(n):
				n.queue_free()
			_mules.erase(mid)
	for mid in want.keys():
		if _mules.has(mid):
			(_mules[mid] as Dictionary)["market"] = want[mid]
			continue
		_spawn_mule(str(mid), want[mid] as Vector3)


func _spawn_mule(mid: String, market_pos: Vector3) -> void:
	var mule := Node3D.new()
	mule.name = "mule_%s" % mid
	add_child(mule)
	mule.position = market_pos
	_build_mule_visual(mule)
	_mules[mid] = {"node": mule, "market": market_pos, "to_center": true}
	_face(mule, CENTER - market_pos)


## Visual procedural: cuerpo marron 1.2x0.8x0.6 + 4 patas + caja de carga.
func _build_mule_visual(mule: Node3D) -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.45, 0.29, 0.15)
	body_mat.roughness = 0.9
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.2, 0.8, 0.6)
	body.mesh = body_mesh
	body.material_override = body_mat
	body.position = Vector3(0.0, 0.9, 0.0)
	mule.add_child(body)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.32, 0.20, 0.10)
	leg_mat.roughness = 0.9
	for lx in [-0.45, 0.45]:
		for lz in [-0.20, 0.20]:
			var leg := MeshInstance3D.new()
			leg.name = "Leg"
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.18, 0.6, 0.18)
			leg.mesh = leg_mesh
			leg.material_override = leg_mat
			leg.position = Vector3(lx, 0.3, lz)
			mule.add_child(leg)
	var cargo_mat := StandardMaterial3D.new()
	cargo_mat.albedo_color = Color(0.76, 0.62, 0.38)
	cargo_mat.roughness = 0.8
	var cargo := MeshInstance3D.new()
	cargo.name = "Cargo"
	var cargo_mesh := BoxMesh.new()
	cargo_mesh.size = Vector3(0.7, 0.5, 0.5)
	cargo.mesh = cargo_mesh
	cargo.material_override = cargo_mat
	cargo.position = Vector3(0.0, 1.55, 0.0)
	mule.add_child(cargo)


func _update_mules(delta: float) -> void:
	var step := SPEED * delta
	for mid in _mules.keys():
		if not _mules.has(mid):
			continue
		var entry := _mules[mid] as Dictionary
		var mule: Node3D = entry.get("node")
		if mule == null or not is_instance_valid(mule):
			_mules.erase(mid)
			continue
		var market: Vector3 = entry.get("market", CENTER)
		var to_center := bool(entry.get("to_center", true))
		var target := CENTER if to_center else market
		var to: Vector3 = target - mule.position
		to.y = 0.0
		var dist := to.length()
		if dist <= maxf(step, 0.15):
			mule.position = Vector3(target.x, 0.0, target.z)
			var arrived_center := to_center
			entry["to_center"] = not to_center
			var next_target := market if arrived_center else CENTER
			_face(mule, next_target - mule.position)
			if arrived_center:
				_deliver()
		else:
			var dir: Vector3 = to / dist
			mule.position += dir * step
			mule.position.y = 0.0
			_face(mule, to)


func _face(mule: Node3D, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	mule.rotation.y = atan2(flat.x, flat.z)


## Entrega alterna + mensaje 1/3 + coin. Clamp a storage_cap con guards ClassDB.
func _deliver() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not is_instance_valid(gs):
		return
	var res_v: Variant = gs.get("resources")
	if not (res_v is Dictionary):
		return
	var res := res_v as Dictionary
	var text := ""
	match _next_cargo:
		0:
			_add_stock(res, "comida", 6.0)
			text = "Mula comercial: +6 comida"
		1:
			_add_stock(res, "madera", 4.0)
			text = "Mula comercial: +4 madera"
		_:
			_add_stock(res, "piedra", 4.0)
			text = "Mula comercial: +4 piedra"
	_next_cargo = (_next_cargo + 1) % 3
	_deliveries += 1
	if gs.has_signal("resources_changed"):
		gs.emit_signal("resources_changed")
	if _deliveries % 3 == 1:
		gs.set("message", text)
		if gs.has_signal("message_changed"):
			gs.emit_signal("message_changed", text)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and is_instance_valid(am) and am.has_method("play"):
		am.call("play", "coin")


## Suma con clamp a cap; suma directa si Economy no existe.
func _add_stock(res: Dictionary, key: String, amount: float) -> void:
	var v: float = float(res.get(key, 0.0)) + amount
	if ClassDB.class_exists("Economy"):
		v = minf(v, float(Economy.storage_cap(_count_almacenes())))
	res[key] = v


## Nº de almacenes en GameState.buildings (0 si GameState no disponible).
func _count_almacenes() -> int:
	var n := 0
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not is_instance_valid(gs):
		return n
	var b_v: Variant = gs.get("buildings")
	if not (b_v is Array):
		return n
	for b in (b_v as Array):
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "almacen":
			n += 1
	return n
