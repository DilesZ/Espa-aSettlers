class_name Quality
extends RefCounted
## Calidad gráfica: escala 3D, sombras y glow. Guarda en GameState.quality.
## alto → 1.0, sombras on, glow on; medio → 0.85, sombras on, glow off;
## bajo → 0.7, sombras off, glow off.


static func apply(level: String) -> void:
	var lvl := level.strip_edges().to_lower()
	var scale := 1.0
	var shadows := true
	var glow := true
	var ssao := true
	match lvl:
		"alto":
			scale = 1.0
			shadows = true
			glow = true
			ssao = true
		"medio":
			scale = 0.85
			shadows = true
			glow = false
			ssao = false
		"bajo":
			scale = 0.7
			shadows = false
			glow = false
			ssao = false
		_:
			return
	GameState.quality = lvl
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root: Viewport = tree.root
	if root != null:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		root.scaling_3d_scale = scale
	var scene: Node = tree.current_scene
	if scene == null:
		return
	_apply_recursive(scene, shadows, glow, ssao)


static func _apply_recursive(n: Node, shadows: bool, glow: bool, ssao: bool) -> void:
	if n is DirectionalLight3D:
		(n as DirectionalLight3D).shadow_enabled = shadows
	if n is WorldEnvironment:
		var we := n as WorldEnvironment
		if we.environment != null:
			we.environment.glow_enabled = glow
			# Existe en 4.7 (Forward+/Mobile lo usan, Compatibility lo ignora).
			we.environment.ssao_enabled = ssao
			# NOTA: no tocar ssil (costoso), queda siempre off.
	for c in n.get_children():
		_apply_recursive(c, shadows, glow, ssao)
