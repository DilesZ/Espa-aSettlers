class_name Production
extends RefCounted
## Sistema de producción Fase 02 — opera sobre el autoload GameState.
## Lógica con estado: asigna workers, avanza progress, consume/produce, clamp a cap.


static func has_inputs(res: Dictionary, recipe: Dictionary) -> bool:
	var inputs: Dictionary = recipe.get("inputs", {})
	for k in inputs.keys():
		if float(res.get(k, 0.0)) < float(inputs[k]):
			return false
	return true


static func tick(dt: float) -> Dictionary:
	var tablon_made: float = 0.0
	var pan_made: float = 0.0
	if dt <= 0.0:
		return {"tablon_made": tablon_made, "pan_made": pan_made}
	# Cap de almacenamiento según nº de almacenes.
	var n_almacenes: int = 0
	for b in GameState.buildings:
		if (b as Dictionary).get("type", "") == "almacen":
			n_almacenes += 1
	var cap_f: float = float(Economy.storage_cap(n_almacenes))
	# Workers libres = nº de colonos; se asignan por orden a edificios con receta.
	var workers: int = GameState.settlers.size()
	for i in range(GameState.buildings.size()):
		var b: Dictionary = GameState.buildings[i]
		var t: String = str(b.get("type", ""))
		if not Economy.RECIPES.has(t):
			continue
		var recipe: Dictionary = Economy.RECIPES[t]
		var need: int = int(recipe.get("workers", 1))
		# Pausado: progress a 0, sin producir.
		if bool(b.get("paused", false)):
			b["progress"] = 0.0
			b["blocked"] = false
			GameState.buildings[i] = b
			continue
		# Sin workers suficientes: inactivo (la alerta de workers la deriva el HUD).
		if workers < need:
			b["blocked"] = false
			GameState.buildings[i] = b
			continue
		workers -= need
		# Sin inputs: bloqueado, sin avance.
		if not has_inputs(GameState.resources, recipe):
			b["blocked"] = true
			GameState.buildings[i] = b
			continue
		b["blocked"] = false
		var time: float = float(recipe.get("time", 1.0))
		if time <= 0.0:
			time = 1.0
		b["progress"] = float(b.get("progress", 0.0)) + dt / time
		while float(b.get("progress", 0.0)) >= 1.0:
			if not has_inputs(GameState.resources, recipe):
				b["blocked"] = true
				break
			var inputs: Dictionary = recipe.get("inputs", {})
			for k in inputs.keys():
				GameState.resources[k] = float(GameState.resources.get(k, 0.0)) - float(inputs[k])
			var outputs: Dictionary = recipe.get("outputs", {})
			for k in outputs.keys():
				GameState.resources[k] = float(GameState.resources.get(k, 0.0)) + float(outputs[k])
				if float(GameState.resources[k]) > cap_f:
					GameState.resources[k] = cap_f
				if k == "tablon":
					tablon_made += float(outputs[k])
					GameState.stats["tablon"] = float(GameState.stats.get("tablon", 0.0)) + float(outputs[k])
				if k == "pan":
					pan_made += float(outputs[k])
					GameState.stats["pan"] = float(GameState.stats.get("pan", 0.0)) + float(outputs[k])
			b["progress"] = float(b.get("progress", 0.0)) - 1.0
		if float(b.get("progress", 0.0)) < 0.0:
			b["progress"] = 0.0
		GameState.buildings[i] = b
	return {"tablon_made": tablon_made, "pan_made": pan_made}
