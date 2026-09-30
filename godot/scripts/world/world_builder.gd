class_name WorldBuilder extends Node3D
## Construye el mundo inicial en _ready (se espera hijo de Main en el origen,
## junto a Ground / River / Camera3D de scenes/main.tscn; otro trabajo lo cableará).
##
## Qué hace, por partes:
## 1. Genera los nodos de recursos en GameState.nodes (12 árboles + 6 rocas).
## 2. Los dibuja con MultiMeshInstance3D: 2 para árboles (tronco cilindro +
##    copa cono) + 1 extra para rocas (BoxMesh con escala aleatoria, placeholder).
## 3. Crea un NavigationRegion3D sobre el suelo 64x64 y lo hornea en runtime;
##    el río (x > 22) queda como obstáculo: StaticBody3D caja 10x64 en x=27 en
##    la capa física 2 (excluida del bake) + poda de polígonos horneados con x > 22.

# --- Constantes de generación ---
const TREE_COUNT := 12 # Número de árboles a generar.
const ROCK_COUNT := 6 # Número de rocas a generar.
const TREE_AMOUNT := 100.0 # Recurso inicial por árbol.
const ROCK_AMOUNT := 100.0 # Recurso inicial por roca (balance placeholder).
const RIVER_CENTER_X := 27.0 # Centro del río (malla River de 10x64 en main.tscn).
const TRUNK_HEIGHT := 2.0 # Altura del tronco (el árbol ocupa y 0..~4.8).
const CANOPY_Y := 3.2 # Altura del centro de la copa (solapa la punta del tronco).
const RANDOM_SEED := 12345 # Semilla fija: distribución de rocas determinista.

# Región de navegación creada en runtime (se hornea con bake_navigation_mesh).
var _nav_region: NavigationRegion3D


func _ready() -> void:
	# Orden: primero datos (GameState.nodes), luego dibujo, luego navegación.
	_generate_resource_nodes() # 1. Datos lógicos de árboles y rocas.
	_build_tree_meshes() # 2a. Troncos + copas con 2 MultiMeshInstance3D.
	_build_rock_meshes() # 2b. Rocas con 1 MultiMeshInstance3D (placeholder).
	_build_navigation() # 3. Región de navegación + obstáculo del río + bake.


# --- 1. DATOS: puebla GameState.nodes con árboles y rocas ---
func _generate_resource_nodes() -> void:
	# Si la escena se recarga, no duplicar: solo genera cuando está vacío.
	# El dibujo (paso 2) siempre lee GameState.nodes, así que refleja el estado real.
	if not GameState.nodes.is_empty():
		return
	# 12 árboles en retícula 4x3 arriba-izquierda: x=-24+(i%4)*5, z=-20+(i/4)*6.
	for i in range(TREE_COUNT):
		var tx := -24.0 + float(i % 4) * 5.0
		var tz := -20.0 + float(i / 4) * 6.0 # i/4 es división entera: filas 0,0,0,0,1,...
		GameState.nodes.append({"id": "tree_%02d" % i, "type": "tree", "x": tx, "z": tz, "amount": TREE_AMOUNT})
	# 6 rocas en retícula 3x2: x=-20+(i%3)*6, z=12+(i/3)*6.
	for i in range(ROCK_COUNT):
		var rx := -20.0 + float(i % 3) * 6.0
		var rz := 12.0 + float(i / 3) * 6.0 # Filas 0,0,0,1,1,1.
		GameState.nodes.append({"id": "rock_%02d" % i, "type": "rock", "x": rx, "z": rz, "amount": ROCK_AMOUNT})


# --- 2a. DIBUJO: troncos (cilindro) y copas (cono) con 2 MultiMeshInstance3D ---
# --- 2a. DIBUJO: arboles con arte KayKit (tree_single_A.gltf) usando MultiMesh ---
func _build_tree_meshes() -> void:
	var trees: Array = GameState.nodes.filter(func(node: Dictionary) -> bool: return node.get("type") == "tree")
	if trees.is_empty():
		return
	var mesh_a: Mesh = _extract_mesh("res://assets/cc0/medieval/decoration/nature/tree_single_A.gltf")
	var mesh_b: Mesh = _extract_mesh("res://assets/cc0/medieval/decoration/nature/tree_single_B.gltf")
	if mesh_a == null and mesh_b == null:
		_build_tree_meshes_placeholder()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	# Reparte instancias entre A y B (50/50) en 2 MultiMesh, escala 1.35.
	var list_a: Array = []
	var list_b: Array = []
	for i in range(trees.size()):
		if i % 2 == 0 and mesh_a != null:
			list_a.append(i)
		elif mesh_b != null:
			list_b.append(i)
		elif mesh_a != null:
			list_a.append(i)
	for pair in [[mesh_a, list_a, "TreesA"], [mesh_b, list_b, "TreesB"]]:
		if (pair[1] as Array).is_empty() or pair[0] == null:
			continue
		var mmi := MultiMeshInstance3D.new()
		mmi.name = str(pair[2])
		mmi.multimesh = MultiMesh.new()
		mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mmi.multimesh.mesh = pair[0]
		mmi.multimesh.instance_count = (pair[1] as Array).size()
		var k := 0
		for i in (pair[1] as Array):
			var pos := Vector3(float(trees[i]["x"]), 0.0, float(trees[i]["z"]))
			var angle := rng.randf_range(0.0, TAU)
			var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * 1.35)
			mmi.multimesh.set_instance_transform(k, Transform3D(basis, pos))
			k += 1
		add_child(mmi)


## Extrae la primera malla de un .gltf importado (PackedScene). Null si falla.
func _extract_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		push_warning("WorldBuilder: no existe " + path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null or not packed.can_instantiate():
		push_warning("WorldBuilder: no se pudo cargar " + path)
		return null
	var scene := packed.instantiate()
	if scene == null:
		return null
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var mi: MeshInstance3D = null
	if not found.is_empty():
		mi = found[0] as MeshInstance3D
	var mesh: Mesh = null
	if mi != null and mi.mesh != null:
		mesh = mi.mesh
	else:
		push_warning("WorldBuilder: sin malla en " + path)
	scene.queue_free()
	return mesh


## Placeholder anterior (tronco + copa) si el arte no carga.
func _build_tree_meshes_placeholder() -> void:
	var trees: Array = GameState.nodes.filter(func(node: Dictionary) -> bool: return node.get("type") == "tree")
	if trees.is_empty():
		return
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.22, 0.12)
	trunk_mat.roughness = 1.0
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = TRUNK_HEIGHT
	var trunk_mmi := MultiMeshInstance3D.new()
	trunk_mmi.name = "TreesTrunk"
	trunk_mmi.material_override = trunk_mat
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	trunk_mm.instance_count = trees.size()
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.13, 0.35, 0.14)
	canopy_mat.roughness = 1.0
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.05
	canopy_mesh.bottom_radius = 1.7
	canopy_mesh.height = 3.2
	var canopy_mmi := MultiMeshInstance3D.new()
	canopy_mmi.name = "TreesCanopy"
	canopy_mmi.material_override = canopy_mat
	var canopy_mm := MultiMesh.new()
	canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
	canopy_mm.mesh = canopy_mesh
	canopy_mm.instance_count = trees.size()
	for i in range(trees.size()):
		var pos := Vector3(float(trees[i]["x"]), 0.0, float(trees[i]["z"]))
		trunk_mm.set_instance_transform(i, Transform3D(Basis(), pos + Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0)))
		canopy_mm.set_instance_transform(i, Transform3D(Basis(), pos + Vector3(0.0, CANOPY_Y, 0.0)))
	trunk_mmi.multimesh = trunk_mm
	canopy_mmi.multimesh = canopy_mm
	add_child(trunk_mmi)
	add_child(canopy_mmi)

# --- 2b. DIBUJO: rocas (BoxMesh con escala aleatoria, placeholder) con 1 MultiMeshInstance3D ---
# --- 2b. DIBUJO: rocas KayKit (rock_single_*) con 1 MultiMeshInstance3D ---
func _build_rock_meshes() -> void:
	var rocks: Array = GameState.nodes.filter(func(node: Dictionary) -> bool: return node.get("type") == "rock")
	if rocks.is_empty():
		return
	var variants: Array = []
	for suffix in ["rock_single_A.gltf", "rock_single_B.gltf", "rock_single_C.gltf", "rock_single_D.gltf", "rock_single_E.gltf"]:
		var m := _extract_mesh("res://assets/cc0/medieval/decoration/nature/" + suffix)
		if m != null:
			variants.append(m)
	if variants.is_empty():
		push_warning("WorldBuilder: sin arte de rocas, usando placeholder")
		_build_rock_meshes_placeholder()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	for i in range(rocks.size()):
		var mesh: Mesh = variants[i % variants.size()]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rocks_%d" % i
		mmi.multimesh = MultiMesh.new()
		mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mmi.multimesh.mesh = mesh
		mmi.multimesh.instance_count = 1
		var sc := Vector3(rng.randf_range(0.7, 1.8), rng.randf_range(0.5, 1.2), rng.randf_range(0.7, 1.8))
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(sc)
		var pos := Vector3(float(rocks[i]["x"]), sc.y * 0.5 - 0.1, float(rocks[i]["z"]))
		mmi.multimesh.set_instance_transform(0, Transform3D(basis, pos))
		add_child(mmi)


## Placeholder anterior (cajas con escala aleatoria).
func _build_rock_meshes_placeholder() -> void:
	var rocks: Array = GameState.nodes.filter(func(node: Dictionary) -> bool: return node.get("type") == "rock")
	if rocks.is_empty():
		return
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.45, 0.45, 0.48)
	rock_mat.roughness = 1.0
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.6, 1.0, 1.2)
	var rock_mmi := MultiMeshInstance3D.new()
	rock_mmi.name = "Rocks"
	rock_mmi.material_override = rock_mat
	var rock_mm := MultiMesh.new()
	rock_mm.transform_format = MultiMesh.TRANSFORM_3D
	rock_mm.mesh = rock_mesh
	rock_mm.instance_count = rocks.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	for i in range(rocks.size()):
		var scale := Vector3(rng.randf_range(0.7, 1.8), rng.randf_range(0.5, 1.2), rng.randf_range(0.7, 1.8))
		var angle := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, angle).scaled(scale)
		var pos := Vector3(float(rocks[i]["x"]), scale.y * 0.5 - 0.1, float(rocks[i]["z"]))
		rock_mm.set_instance_transform(i, Transform3D(basis, pos))
	rock_mmi.multimesh = rock_mm
	add_child(rock_mmi)

# --- 3. NAVEGACIÓN: región 64x64 horneada en runtime + río como obstáculo ---
func _build_navigation() -> void:
	# Malla de navegación: parámetros del agente colono típico.
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 0.3
	nav_mesh.agent_height = 1.5
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	# Solo la capa física 1 (suelo) contribuye al bake; la capa 2 queda excluida.
	nav_mesh.geometry_collision_mask = 1
	# Región sobre el suelo 64x64 (hija de WorldBuilder, en el origen = coords de mundo).
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "WorldNav"
	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)
	# Obstáculo del río: caja 10x64 en x=27 (cubre x 22..32) en la capa 2,
	# excluida de la máscara del bake, con máscara 0 para no colisionar físicamente.
	var river_body := StaticBody3D.new()
	river_body.name = "RiverObstacle"
	river_body.collision_layer = 2
	river_body.collision_mask = 0
	river_body.position = Vector3(RIVER_CENTER_X, 1.0, 0.0)
	var river_shape := CollisionShape3D.new()
	var river_box := BoxShape3D.new()
	river_box.size = Vector3(10.0, 4.0, 64.0)
	river_shape.shape = river_box
	river_body.add_child(river_shape)
	add_child(river_body)
	# El suelo de main.tscn (Ground 64x64) incluye la franja del río, así que tras
	# el bake se podan los polígonos con x > 22 (ver _on_nav_bake_finished).
	_nav_region.bake_finished.connect(_on_nav_bake_finished)
	# Diferido: el bake necesita a todos los cuerpos ya dentro del árbol.
	call_deferred("_bake_nav_deferred")


# Horneado en runtime (hilo de la región); al terminar emite bake_finished.
func _bake_nav_deferred() -> void:
	if is_instance_valid(_nav_region):
		_nav_region.bake_navigation_mesh()


# Talla el río de la malla horneada: elimina polígonos cuyo centroide cae en x > 22.
# (La región está en el origen, así que vértices locales == coordenadas de mundo.)
func _on_nav_bake_finished() -> void:
	if not is_instance_valid(_nav_region):
		return
	var nav_mesh := _nav_region.navigation_mesh
	if nav_mesh == null:
		return
	var verts := nav_mesh.get_vertices()
	var kept: Array[PackedInt32Array] = []
	for i in range(nav_mesh.get_polygon_count()):
		var poly := nav_mesh.get_polygon(i)
		if poly.is_empty():
			continue
		var center_x := 0.0
		for vertex_index in poly:
			center_x += verts[vertex_index].x
		center_x /= float(poly.size())
		if center_x <= GameState.WATER_X:
			kept.append(poly)
	nav_mesh.clear_polygons()
	for poly in kept:
		nav_mesh.add_polygon(poly)
