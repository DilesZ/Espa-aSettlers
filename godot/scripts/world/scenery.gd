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
const CLOUD_WRAP := 45.0
const MOUNTAIN_EDGE := 34.0
const MOUNTAIN_STEP := 8.0
const MOUNTAIN_RANGE := 32.0
const FLAG_Y := 4.0

var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node3D] = []
var _seen_player := {}
var _seen_ai := {}
var _warned := {}
var _flag_timer := 0.0


func _ready() -> void:
	_rng.seed = 7
	_spawn_clouds()
	_spawn_mountains()
	_spawn_waterplants()
	_spawn_well_and_props()
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
			_rng.randf_range(-40.0, 40.0),
			_rng.randf_range(25.0, 35.0),
			_rng.randf_range(-40.0, 40.0)
		)
		var n := _place(path, pos)
		if n != null:
			_clouds.append(n)


func _spawn_mountains() -> void:
	var idx := 0
	var t := -MOUNTAIN_RANGE
	while t <= MOUNTAIN_RANGE:
		for pos in [
			Vector3(MOUNTAIN_EDGE, 0.0, t),
			Vector3(-MOUNTAIN_EDGE, 0.0, t),
			Vector3(t, 0.0, MOUNTAIN_EDGE),
			Vector3(t, 0.0, -MOUNTAIN_EDGE),
		]:
			_place(MOUNTAINS[idx % MOUNTAINS.size()], pos)
			idx += 1
		t += MOUNTAIN_STEP


func _spawn_waterplants() -> void:
	var idx := 0
	var z := -28.0
	while z <= 28.0:
		var pos := Vector3(
			_rng.randf_range(23.0, 31.0),
			0.05,
			z + _rng.randf_range(-1.0, 1.0)
		)
		_place(WATERPLANTS[idx % WATERPLANTS.size()], pos)
		idx += 1
		z += 4.0


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
