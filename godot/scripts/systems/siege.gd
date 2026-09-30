class_name Siege
extends RefCounted
## Asedio IA: torres enemigas disparan catapultas a edificios propios cercanos.
## Uso: Siege.tick(dt, self) desde AiController._physics_process. Nulo-seguro.

const COOLDOWN := 4.0
const RANGE := 20.0
const DAMAGE := 15.0
const SHOT_TIME := 1.2
const ORIGIN_H := 3.5
const TARGET_H := 0.8


static func tick(dt: float, ai_node: Node) -> void:
	if dt <= 0.0:
		return
	if ai_node == null or not is_instance_valid(ai_node):
		return
	if not ai_node.is_inside_tree():
		return
	var gs: Node = ai_node.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var ai_list: Variant = gs.get("ai_buildings")
	var own_list: Variant = gs.get("buildings")
	if not (ai_list is Array):
		return
	if not (own_list is Array):
		return
	for ad in (ai_list as Array):
		if not (ad is Dictionary):
			continue
		var a := ad as Dictionary
		if str(a.get("type", "")) != "torre":
			continue
		var cd := float(a.get("siege_cd", 0.0))
		if cd > 0.0:
			a["siege_cd"] = maxf(0.0, cd - dt)
			continue
		var ax := float(a.get("x", 0.0))
		var az := float(a.get("z", 0.0))
		var best_id := ""
		var best_pos := Vector3.ZERO
		var best_d := RANGE
		var found := false
		for b in (own_list as Array):
			if not (b is Dictionary):
				continue
			var bd := b as Dictionary
			var d := Vector2(ax, az).distance_to(Vector2(float(bd.get("x", 0.0)), float(bd.get("z", 0.0))))
			if d <= best_d:
				best_d = d
				best_id = str(bd.get("id", ""))
				best_pos = Vector3(float(bd.get("x", 0.0)), TARGET_H, float(bd.get("z", 0.0)))
				found = true
		if not found or best_id == "":
			continue
		a["siege_cd"] = COOLDOWN
		_fire(ai_node, Vector3(ax, ORIGIN_H, az), best_pos, best_id)


static func _fire(ai_node: Node, from_pos: Vector3, to_pos: Vector3, target_id: String) -> void:
	if ai_node == null or not is_instance_valid(ai_node):
		return
	if not ai_node.is_inside_tree():
		return
	var shot := SiegeShot.new(from_pos, to_pos, target_id)
	ai_node.add_child(shot)


class SiegeShot:
	extends Node3D

	const PROJECTILE_GLB := "res://assets/cc0/medieval/buildings/neutral/projectile_catapult.gltf"
	const HIT_DAMAGE := 15.0
	const ARC_H := 3.5

	var _from := Vector3.ZERO
	var _to := Vector3.ZERO
	var _target_id := ""
	var _t := 0.0
	var _dur := 1.2

	func _init(p_from: Vector3 = Vector3.ZERO, p_to: Vector3 = Vector3.ZERO, p_target_id: String = "") -> void:
		_from = p_from
		_to = p_to
		_target_id = p_target_id
		_t = 0.0
		_dur = 1.2
		position = p_from

	func _ready() -> void:
		top_level = true
		global_position = _from
		_build_visual()

	func _physics_process(delta: float) -> void:
		if delta <= 0.0:
			return
		_t += delta
		var k := clampf(_t / _dur, 0.0, 1.0)
		var pos := _from.lerp(_to, k)
		pos.y += 4.0 * ARC_H * k * (1.0 - k)
		global_position = pos
		if k >= 1.0:
			_impact()
			queue_free()

	func _build_visual() -> void:
		var spawned := false
		if ResourceLoader.exists(PROJECTILE_GLB):
			var ps: PackedScene = load(PROJECTILE_GLB) as PackedScene
			if ps != null and ps.can_instantiate():
				var inst := ps.instantiate()
				if inst is Node3D:
					add_child(inst as Node3D)
					spawned = true
				else:
					(inst as Node).queue_free()
		if not spawned:
			_add_dark_sphere()

	func _add_dark_sphere() -> void:
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.1, 0.1)
		mat.roughness = 0.9
		sm.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		add_child(mi)

	func _impact() -> void:
		var tree := get_tree()
		var parent: Node = get_parent()
		var at := _to
		if is_inside_tree():
			at = global_position
			at.y = maxf(at.y, 0.5)
		_spawn_puff(parent, tree, at)
		_play_hit()
		_apply_damage()

	func _apply_damage() -> void:
		if _target_id == "":
			return
		var gs := get_node_or_null("/root/GameState")
		if gs == null or not is_instance_valid(gs):
			return
		var blist: Variant = gs.get("buildings")
		if not (blist is Array):
			return
		var arr := blist as Array
		var idx := -1
		for i in range(arr.size()):
			var b: Variant = arr[i]
			if b is Dictionary and str((b as Dictionary).get("id", "")) == _target_id:
				idx = i
				break
		if idx < 0:
			return
		var bd := arr[idx] as Dictionary
		bd["hp"] = float(bd.get("hp", 100.0)) - HIT_DAMAGE
		if float(bd.get("hp", 0.0)) <= 0.0:
			arr.remove_at(idx)
			var msg := "¡Catapulta enemiga destruye %s!" % _target_id
			gs.set("message", msg)
			if gs.has_signal("message_changed"):
				gs.emit_signal("message_changed", msg)
			if gs.has_signal("buildings_changed"):
				gs.emit_signal("buildings_changed")

	func _spawn_puff(parent: Node, tree: SceneTree, at: Vector3) -> void:
		if parent == null or not is_instance_valid(parent):
			return
		if tree == null:
			return
		if not parent.is_inside_tree():
			return
		var p := GPUParticles3D.new()
		p.amount = 12
		p.lifetime = 1.0
		p.one_shot = true
		p.explosiveness = 0.9
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.spread = 45.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 4.0
		pm.gravity = Vector3(0.0, -4.0, 0.0)
		pm.scale_min = 0.15
		pm.scale_max = 0.3
		pm.color = Color(0.6, 0.6, 0.6, 1.0)
		p.process_material = pm
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		var mmat := StandardMaterial3D.new()
		mmat.albedo_color = Color(0.6, 0.6, 0.6)
		mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = mmat
		p.draw_pass_1 = sm
		parent.add_child(p)
		p.global_position = at
		p.emitting = true
		var timer := tree.create_timer(1.3)
		if timer != null:
			timer.timeout.connect(func() -> void: if is_instance_valid(p): p.queue_free())

	func _play_hit() -> void:
		var am := get_node_or_null("/root/AudioManager")
		if am != null and is_instance_valid(am) and am.has_method("play"):
			am.call("play", "hit")
