class_name TradeShip
extends Node3D
## Barco mercante procedural (sin assets externos): navega el río en x=27 en
## ping-pong (z de -28 a +28 y vuelta) y cada 60s atraca en un extremo para
## entregar +10 madera, +8 piedra y +6 comida.
## Hijo de Main (lo cablea otro trabajo). Todo por código, nulo-seguro.

const RIVER_X := 27.0
const Z_MIN := -28.0
const Z_MAX := 28.0
const SPEED := 3.0
const DELIVERY_INTERVAL := 60.0
const DOCK_TIME := 3.0
const NIGHT_THRESHOLD := 0.35
const WOOD_AMOUNT := 10.0
const STONE_AMOUNT := 8.0
const FOOD_AMOUNT := 6.0
const DELIVERY_MESSAGE := "Barco mercante: +10🪵 +8🪨 +6🌾"

var _dir := 1.0
var _delivery_t := 0.0
var _dock_t := 0.0
var _rock_t := 0.0
var _visual: Node3D
var _lantern: OmniLight3D


func _ready() -> void:
	_build()
	position = Vector3(RIVER_X, 0.0, Z_MIN)
	_apply_heading()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_rock_t += delta
	_apply_rocking()
	_update_lantern()
	# Atracado: pausa de 3s en el extremo; al terminar entrega la mercancía.
	if _dock_t > 0.0:
		_dock_t -= delta
		if _dock_t <= 0.0:
			_dock_t = 0.0
			_deliver()
		return
	_delivery_t += delta
	position.x = RIVER_X
	position.z += _dir * SPEED * delta
	if position.z >= Z_MAX:
		position.z = Z_MAX
		_arrive(-1.0)
	elif position.z <= Z_MIN:
		position.z = Z_MIN
		_arrive(1.0)


## Construcción procedural del barco: casco, mástil, vela y farolillo.
func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	# Casco: caja marrón 3x1x1.5 flotando (centro a y=0.6).
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(3.0, 1.0, 1.5)
	hull.mesh = hull_mesh
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.45, 0.27, 0.13)
	hull.material_override = hull_mat
	hull.position = Vector3(0.0, 0.6, 0.0)
	_visual.add_child(hull)
	# Mástil: cilindro centrado sobre el casco.
	var mast := MeshInstance3D.new()
	mast.name = "Mast"
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.09
	mast_mesh.bottom_radius = 0.12
	mast_mesh.height = 3.2
	mast.mesh = mast_mesh
	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.35, 0.22, 0.11)
	mast.material_override = mast_mat
	mast.position = Vector3(0.0, 2.7, 0.0)
	_visual.add_child(mast)
	# Vela: QuadMesh blanca 2x2.5 a doble cara, colgada del mástil.
	var sail := MeshInstance3D.new()
	sail.name = "Sail"
	var sail_mesh := QuadMesh.new()
	sail_mesh.size = Vector2(2.0, 2.5)
	sail.mesh = sail_mesh
	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = Color(0.96, 0.95, 0.9)
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = sail_mat
	sail.position = Vector3(0.0, 2.9, 0.16)
	_visual.add_child(sail)
	# Farolillo nocturno: luz naranja de rango 6, sin sombras.
	_lantern = OmniLight3D.new()
	_lantern.name = "Lantern"
	_lantern.light_color = Color(1.0, 0.6, 0.2)
	_lantern.omni_range = 6.0
	_lantern.shadow_enabled = false
	_lantern.position = Vector3(0.0, 4.4, 0.0)
	_visual.add_child(_lantern)


## Proa según el sentido de marcha (gira 180° al cambiar de sentido).
func _apply_heading() -> void:
	rotation.y = PI * 0.5 if _dir > 0.0 else -PI * 0.5


## Balanceo suave: roll/pitch sinusoidales sobre el nodo visual.
func _apply_rocking() -> void:
	if _visual == null or not is_instance_valid(_visual):
		return
	_visual.rotation.x = sin(_rock_t * 0.9) * 0.06
	_visual.rotation.z = sin(_rock_t * 1.3 + 0.7) * 0.08


## Farolillo encendido de noche (DayNight.day_factor < 0.35), nulo-seguro.
func _update_lantern() -> void:
	if _lantern == null or not is_instance_valid(_lantern):
		return
	var night := true
	if ClassDB.class_exists("DayNight"):
		var f: Variant = DayNight.day_factor
		if f is float or f is int:
			night = float(f) < NIGHT_THRESHOLD
	_lantern.visible = night


## Llegada a un extremo: gira 180° y, si tocan 60s, atraca 3s antes de entregar.
func _arrive(new_dir: float) -> void:
	_dir = new_dir
	_apply_heading()
	if _delivery_t >= DELIVERY_INTERVAL:
		_dock_t = DOCK_TIME


## Entrega la mercancía a GameState con clamp a Economy.storage_cap.
func _deliver() -> void:
	_delivery_t = 0.0
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not is_instance_valid(gs):
		return
	var res_v: Variant = gs.get("resources")
	if not (res_v is Dictionary):
		return
	var res := res_v as Dictionary
	_add_stock(res, "madera", WOOD_AMOUNT)
	_add_stock(res, "piedra", STONE_AMOUNT)
	_add_stock(res, "comida", FOOD_AMOUNT)
	if gs.has_signal("resources_changed"):
		gs.emit_signal("resources_changed")
	gs.set("message", DELIVERY_MESSAGE)
	if gs.has_signal("message_changed"):
		gs.emit_signal("message_changed", DELIVERY_MESSAGE)
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
