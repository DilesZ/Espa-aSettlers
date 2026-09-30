class_name BuildingFactory
extends RefCounted
## Factoría visual KayKit CC0 (Medieval) para edificios jugador (blue) e IA (red).
## `mesh_for()` carga el .gltf adecuado y lo instancia (en Godot 4 `load()` de un
## .gltf/.glb importado devuelve PackedScene). Si la carga falla, devuelve el
## placeholder anterior (caja + cono con el color de Economy) para no romper nada.
## La escala se ajusta para que la huella (X/Z) aproxime `radio*2` de
## Economy.BUILDINGS, con clamp uniforme 0.5..2.0.

const BASE := "res://assets/cc0/medieval"
const MIN_SCALE := 0.5
const MAX_SCALE := 2.0


## Ruta .gltf para (tipo, facción). `id` solo se usa en "casa" para alternar A/B
## por hash (determinista por edificio). Facción: "red" = IA, resto = "blue".
static func path_for(tipo: String, faction: String, id: String = "") -> String:
	var f := faction.strip_edges().to_lower()
	if f != "red":
		f = "blue"
	match tipo:
		"centro":
			return "%s/buildings/%s/building_castle_%s.gltf" % [BASE, f, f]
		"casa":
			var alt_b := false
			if id != "":
				alt_b = (absi(hash(id)) % 2) == 1
			if alt_b:
				return "%s/buildings/%s/building_home_B_%s.gltf" % [BASE, f, f]
			return "%s/buildings/%s/building_home_A_%s.gltf" % [BASE, f, f]
		"lenador":
			return "%s/buildings/%s/building_home_B_%s.gltf" % [BASE, f, f]
		"cantera":
			return "%s/buildings/%s/building_mine_%s.gltf" % [BASE, f, f]
		"almacen":
			return "%s/buildings/%s/building_market_%s.gltf" % [BASE, f, f]
		"aserradero":
			return "%s/buildings/%s/building_lumbermill_%s.gltf" % [BASE, f, f]
		"granja":
			return "%s/buildings/neutral/building_grain.gltf" % BASE
		"molino":
			return "%s/buildings/%s/building_windmill_%s.gltf" % [BASE, f, f]
		"panaderia":
			return "%s/buildings/%s/building_tavern_%s.gltf" % [BASE, f, f]
		"pescador":
			return "%s/decoration/props/tent.gltf" % BASE
		"torre":
			return "%s/buildings/%s/building_tower_A_%s.gltf" % [BASE, f, f]
	return ""


## Instancia visual escalada. Nunca devuelve null: ante cualquier fallo,
## devuelve el placeholder caja+cono.
static func mesh_for(tipo: String, faction: String, id: String = "") -> Node3D:
	var t := tipo
	if not Economy.BUILDINGS.has(t):
		t = "centro"
	var path := path_for(t, faction, id)
	var node: Node3D = null
	if path != "" and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is PackedScene:
			var inst := (res as PackedScene).instantiate()
			if inst is Node3D:
				node = inst as Node3D
			else:
				if inst is Node:
					(inst as Node).free()
				push_warning("BuildingFactory: %s no instanció Node3D" % path)
		else:
			push_warning("BuildingFactory: %s no es PackedScene" % path)
	else:
		push_warning("BuildingFactory: no existe %s (tipo %s)" % [path, t])
	if node == null:
		return _make_placeholder(t)
	var radio := 2.0
	if Economy.BUILDINGS.has(t):
		radio = float((Economy.BUILDINGS[t] as Dictionary).get("radio", 2.0))
	var size := _footprint_size(node)
	var footprint := maxf(size.x, size.z)
	if footprint > 0.01:
		var s := clampf((radio * 2.0) / footprint, MIN_SCALE, MAX_SCALE)
		node.scale = Vector3.ONE * s
	return node


## Variante fantasma: misma malla con material translúcido y sin sombras.
static func ghost_for(tipo: String, faction: String, mat: Material, id: String = "") -> Node3D:
	var n := mesh_for(tipo, faction, id)
	apply_ghost_material(n, mat)
	return n


## Aplica `mat` como override a todas las mallas y desactiva sombras.
static func apply_ghost_material(root: Node, mat: Material) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = mat
		(root as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		apply_ghost_material(child, mat)


## Tamaño (x,y,z) de la huella real: acumula los AABB de todas las mallas
## transformados al espacio del root. Vector3.ZERO si no hay mallas.
static func _footprint_size(root: Node3D) -> Vector3:
	var have := false
	var minv := Vector3.ZERO
	var maxv := Vector3.ZERO
	# Parejas [nodo, transformada_acumulada_desde_root].
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xf: Transform3D = entry[1]
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var mesh: Mesh = mi.mesh
			if mesh != null:
				var aabb := mesh.get_aabb()
				for c in range(8):
					var corner := Vector3(
						aabb.position.x + (aabb.size.x if (c & 1) != 0 else 0.0),
						aabb.position.y + (aabb.size.y if (c & 2) != 0 else 0.0),
						aabb.position.z + (aabb.size.z if (c & 4) != 0 else 0.0)
					)
					var wp: Vector3 = xf * corner
					if not have:
						minv = wp
						maxv = wp
						have = true
					else:
						minv = Vector3(minf(minv.x, wp.x), minf(minv.y, wp.y), minf(minv.z, wp.z))
						maxv = Vector3(maxf(maxv.x, wp.x), maxf(maxv.y, wp.y), maxf(maxv.z, wp.z))
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, xf * (child as Node3D).transform])
	if not have:
		return Vector3.ZERO
	return maxv - minv


## Placeholder anterior (caja + cono a 45°) con color/radio de Economy.
static func _make_placeholder(tipo: String) -> Node3D:
	var def: Dictionary = Economy.BUILDINGS.get(tipo, {"color": "#ffffff", "radio": 2.0})
	var radio := float(def.get("radio", 2.0))
	var base_col := Color(str(def.get("color", "#ffffff")))
	var w: float = radio * 1.6
	var root := Node3D.new()
	root.name = "Placeholder_%s" % tipo
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_col
	mat.roughness = 0.8
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(w, 2.0, w)
	box.mesh = box_mesh
	box.position = Vector3(0.0, 1.0, 0.0)
	box.set_surface_override_material(0, mat)
	root.add_child(box)
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
	root.add_child(roof)
	return root
