class_name Economy
extends RefCounted
## Lógica pura Fases 01-02 — testeable sin nodos.
## Port fiel de lib/economy.ts. Solo lógica pura, sin nodos.

const WIN_MADERA: int = 50
const WIN_PIEDRA: int = 30
## Victoria Fase 02: producción acumulada.
const WIN_TABLON: int = 20
const WIN_PAN: int = 15
const MAP_HALF: int = 30
## Franja de agua: x > 22 es inválida (río).
const WATER_X: int = 22
## El pescador debe estar cerca del río.
const FISH_MIN_X: int = 12
const RECRUIT_COST: int = 15
const RECRUIT_HP: int = 50
const RECRUIT_DPS: int = 8
const RAIDER_HP: int = 40
const RAIDER_DPS: int = 5
const TORRE_RANGE: int = 14
const TORRE_DPS: int = 10
const AI_BASE: Dictionary = {"x": 16, "z": -20}
const BASE_CAP: int = 200
const ALMACEN_BONUS: int = 100
const CASA_COLONOS: int = 4
const MAX_SETTLERS: int = 60

const BUILDINGS: Dictionary = {
	"centro": {"nombre": "Centro Urbano", "coste": {"madera": 0, "piedra": 0}, "color": "#e9c46a", "radio": 3.0},
	"lenador": {"nombre": "Leñador", "coste": {"madera": 10, "piedra": 0}, "color": "#90be6d", "radio": 2.0},
	"cantera": {"nombre": "Cantera", "coste": {"madera": 10, "piedra": 0}, "color": "#adb5bd", "radio": 2.0},
	"casa": {"nombre": "Casa (+4 colonos)", "coste": {"madera": 15, "piedra": 5}, "color": "#f4a261", "radio": 2.0},
	"almacen": {"nombre": "Almacén (+100 cap)", "coste": {"madera": 20, "piedra": 10}, "color": "#2a9d8f", "radio": 2.5},
	"aserradero": {"nombre": "Aserradero", "coste": {"madera": 25, "piedra": 10}, "color": "#b5835a", "radio": 2.5},
	"granja": {"nombre": "Granja", "coste": {"madera": 20, "piedra": 5}, "color": "#d4a373", "radio": 2.5},
	"molino": {"nombre": "Molino", "coste": {"madera": 30, "piedra": 15}, "color": "#e5e5e5", "radio": 2.5},
	"panaderia": {"nombre": "Panadería", "coste": {"madera": 30, "piedra": 20}, "color": "#c08552", "radio": 2.5},
	"pescador": {"nombre": "Pescador (río)", "coste": {"madera": 15, "piedra": 0}, "color": "#48cae4", "radio": 2.0},
	"torre": {"nombre": "Torre defensiva", "coste": {"madera": 20, "piedra": 15}, "color": "#6c757d", "radio": 2.0},
	"muralla": {"nombre": "Muralla", "coste": {"madera": 5, "piedra": 0}, "color": "#9aa0a6", "radio": 1.5},
	"puerta": {"nombre": "Puerta", "coste": {"madera": 8, "piedra": 2}, "color": "#7d8590", "radio": 1.5},
	"mercado": {"nombre": "Mercado", "coste": {"madera": 25, "piedra": 15}, "color": "#e8c547", "radio": 2.5},
}

const BUILDING_HP: Dictionary = {
	"centro": 500,
	"lenador": 150,
	"cantera": 150,
	"casa": 150,
	"almacen": 200,
	"aserradero": 200,
	"granja": 180,
	"molino": 200,
	"panaderia": 200,
	"pescador": 150,
	"torre": 250,
	"muralla": 300,
	"puerta": 200,
	"mercado": 220,
}

const RECIPES: Dictionary = {
	"aserradero": {"building": "aserradero", "inputs": {"madera": 1}, "outputs": {"tablon": 2}, "time": 15.0, "workers": 1},
	"granja": {"building": "granja", "inputs": {}, "outputs": {"trigo": 1}, "time": 20.0, "workers": 1},
	"molino": {"building": "molino", "inputs": {"trigo": 1}, "outputs": {"harina": 1}, "time": 12.0, "workers": 1},
	"panaderia": {"building": "panaderia", "inputs": {"harina": 1}, "outputs": {"pan": 1, "comida": 5}, "time": 15.0, "workers": 1},
	"pescador": {"building": "pescador", "inputs": {}, "outputs": {"comida": 3}, "time": 18.0, "workers": 1},
}


static func empty_resources() -> Dictionary:
	return {"madera": 0, "piedra": 0, "comida": 0, "tablon": 0, "trigo": 0, "harina": 0, "pan": 0}


static func storage_cap(almacenes: int) -> int:
	return BASE_CAP + almacenes * ALMACEN_BONUS


static func housing_cap(casas: int) -> int:
	return 6 + casas * CASA_COLONOS


static func can_afford(res: Dictionary, t: String) -> bool:
	var c: Dictionary = BUILDINGS[t]["coste"]
	return int(res.get("madera", 0)) >= int(c.get("madera", 0)) and int(res.get("piedra", 0)) >= int(c.get("piedra", 0))


static func pay_cost(res: Dictionary, t: String) -> Dictionary:
	var c: Dictionary = BUILDINGS[t]["coste"]
	var out: Dictionary = res.duplicate()
	out["madera"] = int(out.get("madera", 0)) - int(c.get("madera", 0))
	out["piedra"] = int(out.get("piedra", 0)) - int(c.get("piedra", 0))
	return out


## Devuelve "" si la posición es válida; si no, el mensaje de error (igual que TS).
static func placement_error(x: float, z: float, t: String, placed: Array) -> String:
	if absf(x) > MAP_HALF or absf(z) > MAP_HALF:
		return "Fuera del mapa"
	if x > WATER_X:
		return "En el agua"
	# Pendiente simulada: esquinas montañosas inválidas
	if absf(x) + absf(z) > 52.0:
		return "Pendiente >30°"
	# Pescador junto al río
	if t == "pescador" and x < FISH_MIN_X:
		return "El pescador debe estar junto al río (x≥12)"
	var r: float = float(BUILDINGS[t]["radio"])
	for b in placed:
		var bx: float = float((b as Dictionary).get("x", 0.0))
		var bz: float = float((b as Dictionary).get("z", 0.0))
		var br: float = float((b as Dictionary).get("radio", 0.0))
		var d: float = Vector2(bx, bz).distance_to(Vector2(x, z))
		if d < br + r + 0.5:
			return "Colisiona con otro edificio"
	return ""


static func is_victory(res: Dictionary) -> bool:
	return int(res.get("madera", 0)) >= WIN_MADERA and int(res.get("piedra", 0)) >= WIN_PIEDRA


static func is_victory02(stats: Dictionary) -> bool:
	return int(stats.get("tablon", 0)) >= WIN_TABLON and int(stats.get("pan", 0)) >= WIN_PAN


## Sim headless determinista: produce durante `seconds` con stock dado.
static func simulate_production(recipe: Dictionary, stock: Dictionary, seconds: float) -> Dictionary:
	var s: Dictionary = stock.duplicate()
	var batches: int = int(floor(seconds / float(recipe.get("time", 1.0))))
	var done: int = 0
	var inputs: Dictionary = recipe.get("inputs", {})
	var outputs: Dictionary = recipe.get("outputs", {})
	for i in range(batches):
		var ok: bool = true
		for k in inputs.keys():
			if int(s.get(k, 0)) < int(inputs[k]):
				ok = false
				break
		if not ok:
			break
		for k in inputs.keys():
			s[k] = int(s.get(k, 0)) - int(inputs[k])
		for k in outputs.keys():
			s[k] = int(s.get(k, 0)) + int(outputs[k])
		done += 1
	return {"batches": done, "stock": s}
