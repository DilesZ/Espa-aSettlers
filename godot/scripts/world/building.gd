class_name BuildingNode
extends Node3D
## Placeholder visual de un edificio + colisión clicable.
## Otro trabajo cableará main.tscn; este nodo se instancia desde BuildManager.

var data: Dictionary = {}

const HP_BAR_W := 1.6
const HP_BAR_H := 0.18
const HP_BAR_Y := 4.1
const HP_OK := Color("#38b000")
const HP_MID := Color("#ffbe0b")
const HP_LOW := Color("#e63946")

var _hp_bg: MeshInstance3D
var _hp_fg: MeshInstance3D
var _hp_fg_mat: StandardMaterial3D

## Fases de obra estilo Settlers: el edificio tarda BUILD_TIME en levantarse.
const BUILD_TIME := 5.0
const STAGE_PATHS := [
	"res://assets/cc0/medieval/buildings/neutral/building_stage_A.gltf",
	"res://assets/cc0/medieval/buildings/neutral/building_stage_B.gltf",
	"res://assets/cc0/medieval/buildings/neutral/building_stage_C.gltf",
]
const SCAFFOLD_PATH := "res://assets/cc0/medieval/buildings/neutral/building_scaffolding.gltf"
const SCAFFOLD_OFFSET := Vector3(1.8, 0.0, 0.6)
const ROTOR_SPEED := 2.5

var _final_built := false
var _stage_shown := -1
var _rotor: Node3D = null


func _ready() -> void:
	add_to_group("building_nodes")


func setup(b: Dictionary) -> void:
	var tipo: String = str(b.get("type", "centro"))
	if not Economy.BUILDINGS.has(tipo):
		tipo = "centro"
	data = b.duplicate()
	data["type"] = tipo
	add_to_group("building_nodes")
	var def: Dictionary = Economy.BUILDINGS[tipo]
	var radio: float = float(def.get("radio", 2.0))
	var w: float = radio * 1.6
	position = Vector3(float(data.get("x", 0.0)), 0.0, float(data.get("z", 0.0)))
	if str(data.get("id", "")) != "":
		name = "Building_%s" % str(data.get("id"))

	_final_built = false
	_stage_shown = -1
	_rotor = null
	# Sin clave (partidas viejas / centro inicial) = ya construido.
	var bt := float(b.get("build_t", data.get("build_t", BUILD_TIME)))
	data["build_t"] = bt
	if bt < BUILD_TIME:
		_show_construction_stage(_stage_index_for(bt))
	else:
		_final_built = true
		_build_final_visual(tipo)

	var body := StaticBody3D.new()
	body.position = Vector3(0.0, 1.75, 0.0)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(w, 3.5, w)
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)
	body.input_event.connect(_on_body_input_event)

	_build_hp_bar()
	refresh_hp_bar()


func _on_body_input_event(_camera: Node, event: InputEvent, _event_pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var mgr := get_tree().get_first_node_in_group("build_manager")
			if mgr != null and mgr.has_method("click_building"):
				mgr.call("click_building", str(data.get("id", "")))
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	refresh_hp_bar()
	_tick_construction(delta)
	_tick_windmill(delta)


## Obra: avanza build_t en el dict vivo de GameState (como la HP) y al
## llegar a BUILD_TIME instancia el visual definitivo una sola vez.
func _tick_construction(delta: float) -> void:
	if _final_built:
		return
	if not is_inside_tree():
		return
	var my_id := str(data.get("id", ""))
	var live := _live_dict()
	if not _builds_has_id(my_id):
		return # demolido durante la obra: el manager libera el nodo
	var t := float(live.get("build_t", data.get("build_t", 0.0)))
	if t >= BUILD_TIME:
		_finish_construction()
		return
	t += delta
	live["build_t"] = t
	data["build_t"] = t
	if not is_instance_valid(self):
		return
	if t >= BUILD_TIME:
		_finish_construction()
		return
	var idx := _stage_index_for(t)
	if idx != _stage_shown:
		_show_construction_stage(idx)


func _builds_has_id(my_id: String) -> bool:
	if my_id == "":
		return true
	for b in GameState.buildings:
		if b is Dictionary and str((b as Dictionary).get("id", "")) == my_id:
			return true
	return false


func _stage_index_for(t: float) -> int:
	return clampi(int(t / BUILD_TIME * 3.0), 0, 2)


## Muestra stage A/B/C según tercio + andamio al lado. Fallback al visual
## final si el .gltf falta o no instancia.
func _show_construction_stage(idx: int) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_stage_shown = idx
	var old := get_node_or_null("Construction")
	if old != null and is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	var cons := Node3D.new()
	cons.name = "Construction"
	add_child(cons)
	var stage: Node = _instance_gltf(STAGE_PATHS[idx])
	if stage == null:
		stage = BuildingFactory.mesh_for(str(data.get("type", "centro")), "blue", str(data.get("id", "")))
	if is_instance_valid(stage):
		cons.add_child(stage)
	var scaf: Node = _instance_gltf(SCAFFOLD_PATH)
	if scaf != null and is_instance_valid(scaf):
		if scaf is Node3D:
			(scaf as Node3D).position = SCAFFOLD_OFFSET
		cons.add_child(scaf)


func _finish_construction() -> void:
	if _final_built:
		return
	if not is_instance_valid(self):
		return
	_final_built = true
	var live := _live_dict()
	live["build_t"] = BUILD_TIME
	data["build_t"] = BUILD_TIME
	var cons := get_node_or_null("Construction")
	if cons != null and is_instance_valid(cons):
		remove_child(cons)
		cons.queue_free()
	_stage_shown = -1
	if get_node_or_null("Visual") == null:
		_build_final_visual(str(data.get("type", "centro")))


## Visual definitivo (lógica original de setup, reutilizada tras la obra).
func _build_final_visual(tipo: String) -> void:
	if get_node_or_null("Visual") != null:
		_find_rotor()
		return
	var visual := BuildingFactory.mesh_for(tipo, "blue", str(data.get("id", "")))
	visual.name = "Visual"
	add_child(visual)
	_find_rotor()


func _instance_gltf(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed != null and packed.can_instantiate():
		return packed.instantiate()
	return null


## Molino: busca el hijo de aspas (blade/aspa/rotor/fan) sin tocar Visual.
func _find_rotor() -> void:
	_rotor = null
	var tipo := str(data.get("type", "")).to_lower()
	if not (tipo.contains("molino") or tipo.contains("windmill") or tipo.contains("mill")):
		return
	var vis := get_node_or_null("Visual")
	if vis == null or not is_instance_valid(vis):
		return
	for k in vis.find_children("*", "", true, false):
		if k is Node3D:
			var nn := (k as Node).name.to_lower()
			if nn.contains("blade") or nn.contains("aspa") or nn.contains("rotor") or nn.contains("fan") or nn.contains("molino"):
				_rotor = k as Node3D
				break


func _tick_windmill(delta: float) -> void:
	if _rotor == null or not is_instance_valid(_rotor):
		return
	if not _final_built:
		return
	var live := _live_dict()
	if bool(live.get("paused", data.get("paused", false))):
		return
	_rotor.rotate_z(ROTOR_SPEED * delta)


## Barra HP con billboard: verde >50%, amarilla >25%, roja; oculta si llena.
## Lee el dict vivo de GameState.buildings (refleja daño de raiders).
func refresh_hp_bar() -> void:
	if _hp_fg == null or _hp_fg_mat == null or _hp_bg == null:
		return
	var live := _live_dict()
	var hp := float(live.get("hp", data.get("hp", 1.0)))
	var max_hp := maxf(float(live.get("max_hp", data.get("max_hp", hp))), 1.0)
	var pct := clampf(hp / max_hp, 0.0, 1.0)
	var full := pct >= 1.0
	_hp_bg.visible = not full
	_hp_fg.visible = not full
	if full:
		return
	if pct > 0.5:
		_hp_fg_mat.albedo_color = HP_OK
	elif pct > 0.25:
		_hp_fg_mat.albedo_color = HP_MID
	else:
		_hp_fg_mat.albedo_color = HP_LOW
	_hp_fg.scale.x = maxf(pct, 0.001)
	_hp_fg.position.x = -HP_BAR_W * (1.0 - pct) * 0.5


func _live_dict() -> Dictionary:
	var my_id := str(data.get("id", ""))
	for b in GameState.buildings:
		if b is Dictionary and str((b as Dictionary).get("id", "")) == my_id:
			return b as Dictionary
	return data


func _build_hp_bar() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.7)
	_hp_bg = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(HP_BAR_W + 0.08, HP_BAR_H + 0.08)
	_hp_bg.mesh = bg_mesh
	_hp_bg.set_surface_override_material(0, bg_mat)
	_hp_bg.position = Vector3(0.0, HP_BAR_Y, 0.0)
	add_child(_hp_bg)

	_hp_fg_mat = StandardMaterial3D.new()
	_hp_fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hp_fg_mat.no_depth_test = true
	_hp_fg_mat.albedo_color = HP_OK
	_hp_fg = MeshInstance3D.new()
	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_fg.mesh = fg_mesh
	_hp_fg.set_surface_override_material(0, _hp_fg_mat)
	_hp_fg.position = Vector3(0.0, HP_BAR_Y, 0.01)
	add_child(_hp_fg)
