class_name FogOfWar
extends Node
## Niebla de guerra visual + lógica (tick 0.5 s).
##
## DECISIÓN DE VIEWERS (documentada, no se toca settler.gd ni main.tscn):
## - Los grupos "settlers"/"units" NO existen; "recruits" y "raiders" SÍ existen.
## - GameState.settlers/recruits son Array[Dictionary] {id} SIN posición fiable,
##   así que no sirven como viewers directos.
## - Por eso: viewers = GameState.buildings (siempre disponible: casa/etc rango 12,
##   "torre" rango 16) MÁS barrido de unidades vivas en el árbol con
##   `current_scene.find_children("*", "CharacterBody3D", true, false)` (60 nodos
##   máx, barato a 2 Hz), filtrado así:
##     * enemigos (grupos "raiders" / "ai_building_nodes") → se ignoran (no aportan visión)
##     * `node.get("carry") != null` → Settler (tiene `var carry`) → rango 8
##     * grupo "recruits" (o clase Recruit) → rango `vision` si existe, 8 si no
##     * `node.get("vision") != null` (Captain 8, Explorer 20) → rango vision
##     * resto de CharacterBody3D → se ignora (seguro por defecto)
## - Posición de unidad: `global_position` (nulo-seguro, solo si es Node3D válido).
##
## SALIDA:
## - `GameState.fog` vía `Fog.compute_fog(prev, viewers)` (conserva explorado).
## - Overlay 3D: `Image` FORMAT_R8 32x32 (byte = estado 0/1/2) → `ImageTexture`
##   → plano 64x64 a y=0.15 con ShaderMaterial (sampler2D fog_tex; v=r*255;
##   alpha 0.68 si v<0.5, 0.3 si v<1.5, 0.0 si no; usa UV; tinte #05080f).
##   NOTA R8: el canal R normaliza a 0..1, por eso el píxel se escribe como
##   `Color(byte/255)` y el shader recupera `texture(...).r * 255.0`.
## - Culling enemigo: `visible = Fog.is_cell_visible(...)` en grupos
##   "ai_building_nodes" y "raiders" (guardas nulo-seguras).

const POLL := 0.5
const RANGE_BUILDING := 12.0
const RANGE_TOWER := 16.0
const RANGE_UNIT := 8.0
const TEX_N := 32
const PLANE_SIZE := 64.0
const PLANE_Y := 0.15
const MAX_BODIES := 60

const SHADER_CODE := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D fog_tex;
void fragment() {
	float v = texture(fog_tex, UV).r * 255.0;
	float a = 0.0;
	if (v < 0.5) {
		a = 0.68;
	} else if (v < 1.5) {
		a = 0.3;
	}
	ALBEDO = vec3(0.0196, 0.0314, 0.0588);
	ALPHA = a;
}
"""

var _accum := 0.0
var _img: Image
var _tex: ImageTexture
var _plane: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	_ensure_plane()
	_tick()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL:
		_accum = 0.0
		_tick()


func _tick() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var viewers := _build_viewers(tree, gs)
	var prev: PackedInt32Array = gs.get("fog")
	if prev.size() != Fog.FOG_N * Fog.FOG_N:
		prev = PackedInt32Array()
		prev.resize(Fog.FOG_N * Fog.FOG_N)
		prev.fill(0)
	var next: PackedInt32Array = Fog.compute_fog(prev, viewers)
	gs.set("fog", next)
	if gs.has_signal("fog_changed"):
		gs.emit_signal("fog_changed")
	_update_texture(next)
	_cull_enemies(tree, next)


func _build_viewers(tree: SceneTree, gs: Node) -> Array:
	var viewers: Array = []
	for b in (gs.get("buildings") as Array):
		if not (b is Dictionary):
			continue
		var bd: Dictionary = b
		var rng := RANGE_BUILDING
		if str(bd.get("type", "")) == "torre":
			rng = RANGE_TOWER
		viewers.append({
			"x": float(bd.get("x", 0.0)),
			"z": float(bd.get("z", 0.0)),
			"range": rng,
		})
	var root: Node = tree.current_scene
	if root == null:
		return viewers
	var bodies := root.find_children("*", "CharacterBody3D", true, false)
	var count := 0
	for n in bodies:
		if count >= MAX_BODIES:
			break
		if not is_instance_valid(n):
			continue
		if not (n is Node3D):
			continue
		var node3d: Node3D = n
		# Enemigos: no aportan visión (guard nulo-seguro con is_instance_valid + has_group).
		if n.is_in_group("raiders") or n.is_in_group("ai_building_nodes"):
			continue
		var is_settler: bool = n.get("carry") != null
		var is_recruit: bool = n.is_in_group("recruits") or n is Recruit
		var has_vision: bool = n.get("vision") != null
		if not (is_settler or is_recruit or has_vision):
			continue
		var unit_range: float = RANGE_UNIT
		var vis: Variant = n.get("vision")
		if vis != null and float(vis) > 0.0:
			unit_range = float(vis)
		var p: Vector3 = node3d.global_position
		viewers.append({"x": p.x, "z": p.z, "range": unit_range})
		count += 1
	return viewers


func _ensure_plane() -> void:
	if is_instance_valid(_plane):
		return
	_plane = MeshInstance3D.new()
	_plane.name = "FogPlane"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(PLANE_SIZE, PLANE_SIZE)
	_plane.mesh = mesh
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.position = Vector3(0.0, PLANE_Y, 0.0)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat.shader = sh
	# ShaderMaterial no tiene texture_filter: se muestrea en centros de texel,
	# donde el filtrado lineal devuelve el valor exacto de la celda.
	_plane.material_override = _mat
	add_child(_plane)


func _update_texture(fog: PackedInt32Array) -> void:
	if fog.size() != TEX_N * TEX_N:
		return
	if _img == null:
		_img = Image.create(TEX_N, TEX_N, false, Image.FORMAT_R8)
	for cz in range(TEX_N):
		for cx in range(TEX_N):
			var b := clampi(int(fog[cz * TEX_N + cx]), 0, 2)
			_img.set_pixel(cx, cz, Color(b / 255.0, 0.0, 0.0))
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
		_ensure_plane()
		if _mat != null:
			_mat.set_shader_parameter("fog_tex", _tex)
	else:
		_tex.update(_img)


func _cull_enemies(tree: SceneTree, fog: PackedInt32Array) -> void:
	if fog.size() != Fog.FOG_N * Fog.FOG_N:
		return
	for group in ["ai_building_nodes", "raiders"]:
		for n in tree.get_nodes_in_group(group):
			if not is_instance_valid(n):
				continue
			if n.get("visible") == null:
				continue
			if n is Node3D:
				var p: Vector3 = (n as Node3D).global_position
				(n as Node3D).visible = Fog.is_cell_visible(fog, p.x, p.z)
