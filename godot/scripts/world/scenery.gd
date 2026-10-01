class_name Scenery
extends Node3D
## Scenery: decorado no jugable (nubes, montanas de borde, plantas de rio,
## banderas por edificio y props centrales). Hijo de Main en el origen
## (lo cablea otro trabajo). Todo asset es opcional: si falta, se omite.

const CLOUD_BIG := "res://assets/cc0/medieval/decoration/nature/cloud_big.gltf"
const CLOUD_SMALL := "res://assets/cc0/medieval/decoration/nature/cloud_small.gltf"
const MOUNTAINS := [
	"res://assets/cc0/medieval/decoration/nature/mountain_A.gltf",
	"res://assets/cc0/medieval/decoration/nature/mountain_B.gltf",
	"res://assets/cc0/medieval/decoration/nature/mountain_C.gltf",
]
const MOUNTAINS_GREEN := [
	"res://assets/cc0/medieval/decoration/nature/mountain_A_grass_trees.gltf",
	"res://assets/cc0/medieval/decoration/nature/mountain_B_grass_trees.gltf",
	"res://assets/cc0/medieval/decoration/nature/mountain_C_grass_trees.gltf",
]
const WATERLILIES := [
	"res://assets/cc0/medieval/decoration/nature/waterlily_A.gltf",
	"res://assets/cc0/medieval/decoration/nature/waterlily_B.gltf",
]
const WATERPLANTS := [
	"res://assets/cc0/medieval/decoration/nature/waterplant_A.gltf",
	"res://assets/cc0/medieval/decoration/nature/waterplant_B.gltf",
	"res://assets/cc0/medieval/decoration/nature/waterplant_C.gltf",
]
const FLAG_BLUE := "res://assets/cc0/medieval/decoration/props/flag_blue.gltf"
const FLAG_RED := "res://assets/cc0/medieval/decoration/props/flag_red.gltf"
const WELL_BLUE := "res://assets/cc0/medieval/buildings/blue/building_well_blue.gltf"
const CRATE_SMALL := "res://assets/cc0/medieval/decoration/props/crate_A_small.gltf"
const BARREL := "res://assets/cc0/medieval/decoration/props/barrel.gltf"

const CLOUD_COUNT := 6
const CLOUD_SPEED := 0.8
const CLOUD_WRAP := 60.0
const MOUNTAIN_EDGE := 38.0
const MOUNTAIN_STEP := 8.0
const MOUNTAIN_RANGE := 32.0
const FLAG_Y := 4.0

var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node3D] = []
var _seen_player := {}
var _seen_ai := {}
var _warned := {}
var _flag_timer := 0.0
var _settlers_t := 0.0
var _foam_mat: StandardMaterial3D
var _wave_mi: MeshInstance3D
var _wave_mat: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 7
	_spawn_clouds()
	_spawn_mountains()
	_spawn_waterplants()
	_spawn_well_and_props()
	_spawn_ground_cover()
	_spawn_foam_shore()
	_spawn_tall_grass_and_flowers()
	_spawn_wave_cap()
	_refresh_flags()
	if GameState.has_signal("buildings_changed"):
		if not GameState.buildings_changed.is_connected(_refresh_flags):
			GameState.buildings_changed.connect(_refresh_flags)


func _process(delta: float) -> void:
	for c in _clouds:
		if is_instance_valid(c):
			c.position.x += CLOUD_SPEED * delta
			if c.position.x > CLOUD_WRAP:
				c.position.x = -CLOUD_WRAP
	_flag_timer += delta
	if _flag_timer >= 0.5:
		_flag_timer = 0.0
		_refresh_flags()
	_animate_settlers(delta)


func _inst(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		_warn_once(path)
		return null
	var ps: PackedScene = load(path)
	if ps == null or not ps.can_instantiate():
		_warn_once(path)
		return null
	var n: Node = ps.instantiate()
	if not (n is Node3D):
		n.queue_free()
		return null
	return n


func _warn_once(path: String) -> void:
	if _warned.has(path):
		return
	_warned[path] = true
	push_warning("[Scenery] asset ausente, se omite: %s" % path)


func _place(path: String, pos: Vector3) -> Node3D:
	var n := _inst(path)
	if n == null:
		return null
	n.position = pos
	add_child(n)
	return n


func _spawn_clouds() -> void:
	for i in CLOUD_COUNT:
		var path := CLOUD_BIG if i % 2 == 0 else CLOUD_SMALL
		var pos := Vector3(
			_rng.randf_range(-55.0, 55.0),
			_rng.randf_range(48.0, 58.0),
			_rng.randf_range(-55.0, 55.0)
		)
		var n := _place(path, pos)
		if n != null:
			# NOTA: solo transform (posición + escala). No se toca material_override:
			# las nubes .gltf usan atlas/textura y color por vértice; pisar el
			# material las dejaría blancas/planas y rompería el ordenado alfa.
			n.scale = Vector3.ONE * 1.4
			_clouds.append(n)


func _spawn_mountains() -> void:
	# Bordes x/z=±38 cada ~8m. Mezcla _grass_trees (verdes, no cubos blancos)
	# con base para variedad. RNG local semilla 7: no consume _rng global y
	# conserva determinismo de nubes/waterplants. Fallback silencioso a base.
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 7
	var idx := 0
	var t := -MOUNTAIN_RANGE
	while t <= MOUNTAIN_RANGE:
		for pos in [
			Vector3(MOUNTAIN_EDGE, 0.0, t),
			Vector3(-MOUNTAIN_EDGE, 0.0, t),
			Vector3(t, 0.0, MOUNTAIN_EDGE),
			Vector3(t, 0.0, -MOUNTAIN_EDGE),
		]:
			var path: String = MOUNTAINS_GREEN[idx % MOUNTAINS_GREEN.size()]
			# 1 de cada 4 en versión rocosa base para variar silueta.
			if idx % 4 == 3:
				path = MOUNTAINS[idx % MOUNTAINS.size()]
			var n := _place(path, pos)
			if n == null and path != MOUNTAINS[idx % MOUNTAINS.size()]:
				n = _place(MOUNTAINS[idx % MOUNTAINS.size()], pos)
			if n != null:
				var s := mrng.randf_range(1.2, 1.8)
				n.scale = Vector3.ONE * s
				n.rotation.y = mrng.randf_range(0.0, TAU)
			idx += 1
		t += MOUNTAIN_STEP


func _spawn_waterplants() -> void:
	# Río x 23..31 con jitter. _rng semilla 7 (determinista, la fija _ready).
	# Doble densidad (paso 2m) + nenúfares intercalados flotando (y=0.14 sobre
	# la capa wave de scenery y=0.12 / agua atmosphere y 0.06/0.10).
	var idx := 0
	var z := -28.0
	while z <= 28.0:
		var pos := Vector3(
			_rng.randf_range(23.0, 31.0),
			0.05,
			z + _rng.randf_range(-1.0, 1.0)
		)
		var n := _place(WATERPLANTS[idx % WATERPLANTS.size()], pos)
		if n != null:
			var s := _rng.randf_range(0.9, 1.4)
			n.scale = Vector3.ONE * s
		idx += 1
		z += 2.0
	var lidx := 0
	var lz := -27.0
	while lz <= 27.0:
		var lpos := Vector3(
			_rng.randf_range(23.0, 31.0),
			0.14,
			lz + _rng.randf_range(-1.2, 1.2)
		)
		var ln := _place(WATERLILIES[lidx % WATERLILIES.size()], lpos)
		if ln != null:
			var ls := _rng.randf_range(0.8, 1.3)
			ln.scale = Vector3.ONE * ls
		lidx += 1
		lz += 4.5


func _spawn_well_and_props() -> void:
	_place(WELL_BLUE, Vector3(5.0, 0.0, 8.0))
	_place(CRATE_SMALL, Vector3(2.0, 0.0, 3.0))
	_place(BARREL, Vector3(3.2, 0.0, 3.6))


func _refresh_flags() -> void:
	for b in GameState.buildings:
		if not (b is Dictionary):
			continue
		var bid = b.get("id", null)
		if bid == null or _seen_player.has(bid):
			continue
		var n := _place(FLAG_BLUE, Vector3(float(b.get("x", 0.0)), FLAG_Y, float(b.get("z", 0.0))))
		if n != null:
			_seen_player[bid] = n
	if GameState.get("ai_buildings") == null:
		return
	var ai_list: Array = GameState.get("ai_buildings")
	for b in ai_list:
		if not (b is Dictionary):
			continue
		var bid = b.get("id", null)
		if bid == null or _seen_ai.has(bid):
			continue
		var n := _place(FLAG_RED, Vector3(float(b.get("x", 0.0)), FLAG_Y, float(b.get("z", 0.0))))
		if n != null:
			_seen_ai[bid] = n


# --- Look Settlers: todo procedural por código, sin assets nuevos ---

func _animate_settlers(delta: float) -> void:
	_settlers_t += delta
	if _foam_mat != null:
		var fc := _foam_mat.albedo_color
		fc.a = clampf(0.35 + sin(_settlers_t * 2.0) * 0.12, 0.08, 0.6)
		_foam_mat.albedo_color = fc
	if _wave_mi != null and is_instance_valid(_wave_mi):
		_wave_mi.position.z = sin(_settlers_t * 0.9) * 0.6
	if _wave_mat != null:
		var wc := _wave_mat.albedo_color
		wc.a = clampf(0.25 + sin(_settlers_t * 1.3 + 1.0) * 0.07, 0.05, 0.5)
		_wave_mat.albedo_color = wc


# 1) Manto de hierba: plano propio 64x64 a y=0.02 (el suelo de main.tscn
# no se toca) con ImageTexture 512 procedural y uv1_scale (1,1,1).
# Escala 1:1 para que u = (x+32)/64 mapee orilla este sin repetir
# (con 3,3,3 la arena se triplicaría por el tiling).
func _spawn_ground_cover() -> void:
	var tex := _make_grass_texture()
	if tex == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(64.0, 64.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.02, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _make_grass_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	# Manchas de tierra: ruido aparte de baja frecuencia + umbral alto
	# (~6 blobs en 512px). Misma semilla 99 para determinismo.
	var dirt_noise := FastNoiseLite.new()
	dirt_noise.seed = 99
	dirt_noise.frequency = 0.012
	dirt_noise.fractal_octaves = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var base := Color8(51, 88, 42) # #33582a
	var dark := Color8(36, 63, 30) # #243f1e
	var mid := Color8(64, 104, 47) # #40682f
	var light := Color8(79, 122, 53) # #4f7a35
	var dry := Color8(122, 143, 63) # #7a8f3f, solo en parches (cola alta del ruido)
	var dirt := Color8(107, 84, 51) # #6b5433 tierra
	var sand := Color8(194, 168, 120) # #c2a878 arena orilla este/oeste
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	if img == null:
		return null
	for y in 512:
		for x in 512:
			var n := noise.get_noise_2d(float(x), float(y))
			var c := base
			if n < -0.35:
				c = dark
			elif n < -0.05:
				c = base
			elif n < 0.3:
				c = mid
			elif n < 0.6:
				c = light
			else:
				c = dry
			# Tierra: umbral alto rompe la monotonía con pocos blobs.
			var d := dirt_noise.get_noise_2d(float(x), float(y))
			if d > 0.6:
				c = dirt
			# Arena junto al río: plano 64m con uv 1:1 → u=(x_mundo+32)/64.
			# x 20..24 → u [0.81,0.88], x 30..34 → u [0.97,1.0] (recortado a
			# borde del plano en 32). Wobble con n para borde natural, sin
			# consumir rng (conserva speckle determinista semilla 99).
			var u := float(x) / 512.0 + n * 0.015
			if (u >= 0.81 and u <= 0.88) or (u >= 0.965):
				c = sand
			var r := rng.randf()
			if r < 0.08:
				c = c.darkened(0.18)
			# Baja saturación/brillo global.
			c = Color(c.r * 0.9, c.g * 0.9, c.b * 0.9)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# 2) Orilla con espuma: franja 2x64 en x=21 (borde oeste del río) a y=0.08
# + 2ª línea en x=31 (borde este). Atmosphere solo deriva agua en x=27
# (10x64, y 0.06/0.10) sin espuma: no duplica. Mismo _foam_mat compartido
# para animar ambas en _animate_settlers, sin surface_get_material.
func _spawn_foam_shore() -> void:
	_foam_mat = StandardMaterial3D.new()
	_foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foam_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	_foam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_make_foam_strip(Vector3(21.0, 0.08, 0.0))
	_make_foam_strip(Vector3(31.0, 0.08, 0.0))


func _make_foam_strip(pos: Vector3) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 64.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _foam_mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# 3) Hierba alta (300 matas en cruz) + flores (80 con color por instancia).
func _spawn_tall_grass_and_flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_spawn_grass_clumps(rng)
	_spawn_flowers(rng)


func _spawn_grass_clumps(rng: RandomNumberGenerator) -> void:
	if rng == null:
		return
	var mesh := _make_cross_quad_mesh(0.3, 0.3)
	if mesh == null:
		return
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.25, 0.5, 0.2)
	green.roughness = 1.0
	green.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = mesh
	mm.instance_count = 300
	var placed := 0
	var attempts := 0
	while placed < 300 and attempts < 3000:
		attempts += 1
		var pos := _settlers_spot(rng)
		if pos == Vector3.INF:
			continue
		var ang := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(0.8, 1.3)
		var b := Basis(Vector3.UP, ang).scaled(Vector3(s, s, s))
		mm.set_instance_transform(placed, Transform3D(b, pos))
		placed += 1
	if placed == 0:
		return
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = green
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _spawn_flowers(rng: RandomNumberGenerator) -> void:
	if rng == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.2)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1.0, 1.0, 1.0)
	white.roughness = 1.0
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 80
	var palette := [Color(1, 1, 1), Color(1.0, 0.85, 0.2), Color(0.9, 0.2, 0.2)]
	var placed := 0
	var attempts := 0
	while placed < 80 and attempts < 2000:
		attempts += 1
		var pos := _settlers_spot(rng)
		if pos == Vector3.INF:
			continue
		pos.y = 0.12
		var ang := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(0.8, 1.2)
		var b := Basis(Vector3.UP, ang).scaled(Vector3(s, s, s))
		mm.set_instance_transform(placed, Transform3D(b, pos))
		mm.set_instance_color(placed, palette[rng.randi_range(0, palette.size() - 1)])
		placed += 1
	if placed == 0:
		return
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = white
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _make_cross_quad_mesh(w: float, h: float) -> ArrayMesh:
	var hw := w * 0.5
	var verts := PackedVector3Array([
		Vector3(-hw, 0.0, 0.0), Vector3(hw, 0.0, 0.0),
		Vector3(hw, h, 0.0), Vector3(-hw, h, 0.0),
		Vector3(0.0, 0.0, -hw), Vector3(0.0, 0.0, hw),
		Vector3(0.0, h, hw), Vector3(0.0, h, -hw),
	])
	var normals := PackedVector3Array([
		Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1),
		Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0),
	])
	var uvs := PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
	])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


# Punto válido: evita el río (x<21) y el centro (dist>4).
func _settlers_spot(rng: RandomNumberGenerator) -> Vector3:
	if rng == null:
		return Vector3.INF
	for i in 20:
		var x := rng.randf_range(-32.0, 20.9)
		var z := rng.randf_range(-32.0, 32.0)
		if Vector2(x, z).length() < 4.0:
			continue
		if x >= 21.0:
			continue
		return Vector3(x, 0.02, z)
	return Vector3.INF


# 4) Tercera capa de agua: Atmosphere ya deriva 2 planos (y 0.06/0.10,
# sin/cos lento 0.3 + pulso de alfa). Aquí rizo rápido de amplitud
# pequeña (sin 0.9 x0.6) + pulso de alfa en contrafase a y=0.12.
func _spawn_wave_cap() -> void:
	_wave_mat = StandardMaterial3D.new()
	_wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_mat.albedo_color = Color(0.25, 0.55, 0.92, 0.25)
	_wave_mat.roughness = 0.25
	_wave_mat.metallic = 0.35
	_wave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(10.0, 64.0)
	_wave_mi = MeshInstance3D.new()
	_wave_mi.mesh = mesh
	_wave_mi.material_override = _wave_mat
	_wave_mi.position = Vector3(27.0, 0.12, 0.0)
	_wave_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wave_mi)
