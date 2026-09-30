class_name Details
extends Node3D
## Detalles procedurales del asentamiento: caminos de tierra desde el centro
## a cada edificio propio y antorchas nocturnas en centro + torres.
## Todo por código, sin escena ni dependencias nuevas. Nulo-seguro.

const ROAD_WIDTH := 2.2
const ROAD_Y := 0.03
const ROAD_COLOR := Color8(138, 111, 77) # #8a6f4d tierra
const ROAD_CHECK := 2.0

const TORCH_CHECK := 0.5
const NIGHT_THRESHOLD := 0.35
const MAX_LIGHTS := 6
const TORCH_ENERGY := 1.2
const TORCH_RANGE := 8.0
const TORCH_COLOR := Color(1.0, 0.6, 0.25)
const TORCH_Y_TOWER := 4.0
const TORCH_Y_CENTER := 3.5

var _roads_root: Node3D
var _torch_root: Node3D
var _road_mat: StandardMaterial3D
## id (String) -> Node3D contenedor de la antorcha.
var _torches: Dictionary = {}
var _road_timer := 0.0
var _torch_timer := 0.0


func _ready() -> void:
	_roads_root = Node3D.new()
	_roads_root.name = "Roads"
	add_child(_roads_root)
	_torch_root = Node3D.new()
	_torch_root.name = "Torches"
	add_child(_torch_root)
	_connect_signals()
	_rebuild_roads()
	_sync_torches()


func _process(delta: float) -> void:
	_road_timer += delta
	if _road_timer >= ROAD_CHECK:
		_road_timer = 0.0
		_rebuild_roads()
	_torch_timer += delta
	if _torch_timer >= TORCH_CHECK:
		_torch_timer = 0.0
		_sync_torches()


func _connect_signals() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs.has_signal("buildings_changed"):
		if not gs.is_connected("buildings_changed", _on_buildings_changed):
			gs.connect("buildings_changed", _on_buildings_changed)


func _on_buildings_changed() -> void:
	_rebuild_roads()
	_sync_torches()


func _get_buildings() -> Array:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return []
	var v: Variant = gs.get("buildings")
	return v if v is Array else []


# --- Caminos de tierra: franja plana del centro (0,0) a cada edificio propio ---

func _rebuild_roads() -> void:
	if _roads_root == null or not is_instance_valid(_roads_root):
		return
	for c in _roads_root.get_children():
		_roads_root.remove_child(c)
		c.queue_free()
	if _road_mat == null:
		_road_mat = StandardMaterial3D.new()
		_road_mat.albedo_color = ROAD_COLOR
		_road_mat.roughness = 1.0
	for b in _get_buildings():
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		if str(bd.get("type", "")) == "centro":
			continue
		var bx := float(bd.get("x", 0.0))
		var bz := float(bd.get("z", 0.0))
		var dist := Vector2(bx, bz).length()
		if dist < 0.5:
			continue
		var key := "road_" + _safe_id(bd.get("id", "noid"))
		if _roads_root.has_node(key):
			continue
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(ROAD_WIDTH, dist)
		var mi := MeshInstance3D.new()
		mi.name = key
		mi.mesh = mesh
		mi.material_override = _road_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(bx * 0.5, ROAD_Y, bz * 0.5)
		mi.add_to_group("roads")
		_roads_root.add_child(mi)
		if mi.is_inside_tree():
			mi.look_at(Vector3(bx, ROAD_Y, bz), Vector3.UP)


# --- Antorchas nocturnas: fuego + luz en centro y torres (máx 6 luces) ---

## Candidatos ordenados: centro primero, luego torres por cercanía al centro.
## Cada entrada: {"key": String, "pos": Vector3}.
func _torch_candidates() -> Array:
	var out: Array = []
	var towers: Array = []
	for b in _get_buildings():
		if not (b is Dictionary):
			continue
		var bd := b as Dictionary
		var t := str(bd.get("type", ""))
		if t != "torre" and t != "centro":
			continue
		var bx := float(bd.get("x", 0.0))
		var bz := float(bd.get("z", 0.0))
		var key := "torch_" + _safe_id(bd.get("id", "noid"))
		var y := TORCH_Y_CENTER if t == "centro" else TORCH_Y_TOWER
		var entry := {"key": key, "pos": Vector3(bx, y, bz), "dist": Vector2(bx, bz).length()}
		if t == "centro":
			out.append(entry)
		else:
			towers.append(entry)
	towers.sort_custom(func(a: Dictionary, d: Dictionary) -> bool: return float(a["dist"]) < float(d["dist"]))
	out.append_array(towers)
	return out


func _sync_torches() -> void:
	if _torch_root == null or not is_instance_valid(_torch_root):
		return
	var cands := _torch_candidates()
	var wanted: Dictionary = {}
	for c in cands:
		wanted[c["key"]] = c["pos"]
	for key in wanted.keys():
		var holder := _torches.get(key) as Node3D
		if holder == null or not is_instance_valid(holder):
			holder = _make_torch(key, wanted[key] as Vector3)
			_torch_root.add_child(holder)
			_torches[key] = holder
		else:
			holder.position = wanted[key] as Vector3
	var stale: Array = []
	for key in _torches.keys():
		if not wanted.has(key):
			stale.append(key)
	for key in stale:
		var n := _torches[key] as Node
		if is_instance_valid(n):
			n.queue_free()
		_torches.erase(key)
	_refresh_torch_lights(cands)
	_apply_night()


## Solo las primeras MAX_LIGHTS candidatas (centro + torres cercanas) tienen luz.
func _refresh_torch_lights(cands: Array) -> void:
	var lit: Dictionary = {}
	for i in range(mini(MAX_LIGHTS, cands.size())):
		lit[str((cands[i] as Dictionary)["key"])] = true
	for key in _torches.keys():
		var holder := _torches.get(key) as Node3D
		if holder == null or not is_instance_valid(holder):
			continue
		var light := holder.get_node_or_null("TorchLight") as OmniLight3D
		if lit.has(key):
			if light == null:
				light = _make_torch_light()
				holder.add_child(light)
		else:
			if light != null and is_instance_valid(light):
				light.queue_free()


func _apply_night() -> void:
	var night := _is_night()
	for key in _torches.keys():
		var holder := _torches.get(key) as Node3D
		if holder == null or not is_instance_valid(holder):
			continue
		holder.visible = night
		var flame := holder.get_node_or_null("Flame") as GPUParticles3D
		if flame != null:
			flame.emitting = night
		var light := holder.get_node_or_null("TorchLight") as OmniLight3D
		if light != null:
			light.light_energy = TORCH_ENERGY if night else 0.0


## Nulo-seguro: sin DayNight las antorchas quedan siempre encendidas.
func _is_night() -> bool:
	if not ClassDB.class_exists("DayNight"):
		return true
	var f: Variant = DayNight.day_factor
	if f is float or f is int:
		return float(f) < NIGHT_THRESHOLD
	return true


func _make_torch(key: String, pos: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = key
	holder.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 18.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.0, 0.5, 0.0)
	pm.scale_min = 0.12
	pm.scale_max = 0.25
	pm.color = Color(1.0, 0.55, 0.15, 1.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.65, 0.2, 1.0))
	ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var dot := SphereMesh.new()
	dot.radius = 0.08
	dot.height = 0.16
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1.0, 0.55, 0.15)
	dot_mat.emission_enabled = true
	dot_mat.emission = Color(1.0, 0.5, 0.12)
	dot_mat.emission_energy_multiplier = 2.0
	dot.material = dot_mat
	var flame := GPUParticles3D.new()
	flame.name = "Flame"
	flame.amount = 12
	flame.lifetime = 1.0
	flame.process_material = pm
	flame.draw_pass_1 = dot
	flame.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 4, 2))
	flame.emitting = true
	holder.add_child(flame)
	return holder


func _make_torch_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = TORCH_COLOR
	light.light_energy = TORCH_ENERGY
	light.omni_range = TORCH_RANGE
	light.shadow_enabled = false
	return light


func _safe_id(raw: Variant) -> String:
	return str(raw).replace("/", "_").replace(".", "_").replace(" ", "_")
