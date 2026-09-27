class_name BuildingNode
extends Node3D
## Placeholder visual de un edificio + colisión clicable.
## Otro trabajo cableará main.tscn; este nodo se instancia desde BuildManager.

var data: Dictionary = {}


func setup(b: Dictionary) -> void:
	var tipo: String = str(b.get("type", "centro"))
	if not Economy.BUILDINGS.has(tipo):
		tipo = "centro"
	data = b.duplicate()
	data["type"] = tipo
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


func _on_body_input_event(_camera: Node, event: InputEvent, _event_pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var mgr := get_tree().get_first_node_in_group("build_manager")
			if mgr != null and mgr.has_method("click_building"):
				mgr.call("click_building", str(data.get("id", "")))
			get_viewport().set_input_as_handled()
