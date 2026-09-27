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
	var base_col := Color(str(def.get("color", "#ffffff")))
	var w: float = radio * 1.6
	position = Vector3(float(data.get("x", 0.0)), 0.0, float(data.get("z", 0.0)))
	if str(data.get("id", "")) != "":
		name = "Building_%s" % str(data.get("id"))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_col
	mat.roughness = 0.8

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(w, 2.0, w)
	box.mesh = box_mesh
	box.position = Vector3(0.0, 1.0, 0.0)
	box.set_surface_override_material(0, mat)
	add_child(box)

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = base_col.darkened(0.25)
	roof_mat.roughness = 0.7

	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = w * 0.75
	cone.height = 1.5
	cone.radial_segments = 4
	roof.mesh = cone
	roof.position = Vector3(0.0, 2.75, 0.0)
	roof.rotation.y = deg_to_rad(45.0)
	roof.set_surface_override_material(0, roof_mat)
	add_child(roof)

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


func _process(_delta: float) -> void:
	refresh_hp_bar()


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
