class_name Atmosphere
extends Node
## Atmósfera procedural: agua animada del río, humo de edificios productivos
## y luciérnagas nocturnas. Todo por código, sin escena.

const WATER_X := 27.0
const WATER_SIZE := Vector2(10.0, 64.0)
const SMOKE_CHECK := 1.0
const SMOKE_Y := 2.5

var _t := 0.0
var _water_a: MeshInstance3D
var _water_b: MeshInstance3D
var _mat_a: StandardMaterial3D
var _mat_b: StandardMaterial3D
## id edificio (String) -> GPUParticles3D de humo.
var _smoke: Dictionary = {}
var _smoke_timer := 0.0
var _fireflies: GPUParticles3D


func _ready() -> void:
	_build_water()
	_build_fireflies()
	_sync_smoke()


func _process(delta: float) -> void:
	_t += delta
	_animate_water()
	_smoke_timer += delta
	if _smoke_timer >= SMOKE_CHECK:
		_smoke_timer = 0.0
		_sync_smoke()
	if _fireflies != null:
		_fireflies.visible = DayNight.day_factor < 0.35


# --- Agua: 2 planos 10x64 solapados que derivan en z + pulso de alfa ---

func _build_water() -> void:
	_mat_a = _water_material(Color(0.20, 0.50, 0.90, 0.55))
	_mat_b = _water_material(Color(0.30, 0.62, 0.95, 0.40))
	_water_a = _make_plane(_mat_a, Vector3(WATER_X, 0.06, 0.0))
	_water_b = _make_plane(_mat_b, Vector3(WATER_X, 0.10, 0.0))


func _water_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.roughness = 0.25
	m.metallic = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _make_plane(mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = WATER_SIZE
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _animate_water() -> void:
	if _water_a != null:
		_water_a.position.z = sin(_t * 0.3) * 1.5
		_pulse_alpha(_mat_a, 0.55, 0.10, _t)
	if _water_b != null:
		_water_b.position.z = cos(_t * 0.3) * 1.5
		_pulse_alpha(_mat_b, 0.40, 0.08, _t + 2.0)


func _pulse_alpha(mat: StandardMaterial3D, base: float, amp: float, phase: float) -> void:
	if mat == null:
		return
	var c := mat.albedo_color
	c.a = clampf(base + sin(phase) * amp, 0.05, 0.9)
	mat.albedo_color = c


# --- Humo: un GPUParticles3D por edificio productivo no pausado ---

func _sync_smoke() -> void:
	var buildings := _get_buildings()
	var wanted: Dictionary = {}
	for i in buildings.size():
		if not (buildings[i] is Dictionary):
			continue
		var b := buildings[i] as Dictionary
		if not Economy.RECIPES.has(str(b.get("type", ""))):
			continue
		if bool(b.get("paused", false)):
			continue
		var key := str(b.get("id", "noid_%d" % i))
		wanted[key] = Vector3(float(b.get("x", 0.0)), SMOKE_Y, float(b.get("z", 0.0)))
	for key in wanted.keys():
		if not _smoke.has(key):
			var p := _make_smoke(wanted[key] as Vector3)
			add_child(p)
			_smoke[key] = p
		else:
			(_smoke[key] as Node3D).position = wanted[key] as Vector3
	var stale: Array = []
	for key in _smoke.keys():
		if not wanted.has(key):
			stale.append(key)
	for key in stale:
		(_smoke[key] as Node).queue_free()
		_smoke.erase(key)


func _get_buildings() -> Array:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return []
	var v: Variant = gs.get("buildings")
	return v if v is Array else []


func _make_smoke(pos: Vector3) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0.0, 0.8, 0.0)
	pm.scale_min = 0.15
	pm.scale_max = 0.35
	pm.color = Color(0.6, 0.6, 0.6, 0.7)
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.6, 0.6, 0.55)
	mesh.material = mat
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 2.5
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 8, 4))
	p.emitting = true
	return p


# --- Luciérnagas: nube amarilla 40x6x40, solo de noche ---

func _build_fireflies() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20.0, 3.0, 20.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.06
	pm.scale_max = 0.14
	pm.color = Color(1.0, 0.9, 0.3, 1.0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.3)
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	_fireflies = GPUParticles3D.new()
	_fireflies.amount = 30
	_fireflies.lifetime = 3.0
	_fireflies.process_material = pm
	_fireflies.draw_pass_1 = mesh
	_fireflies.position = Vector3(0.0, 1.5, 0.0)
	_fireflies.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 15, 50))
	_fireflies.emitting = true
	add_child(_fireflies)
