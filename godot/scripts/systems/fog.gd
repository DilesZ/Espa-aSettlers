class_name Fog
extends RefCounted
## Niebla de guerra: grid 32x32 sobre mapa 64x64 (celda 2m). 0=inexplorado,1=explorado,2=visible.
## Port de lib/fog.ts.

const FOG_N := 32
const FOG_CELL := 2


static func cell_of(x: float, z: float) -> int:
	var cx: int = clampi(int(floor((x + 32.0) / float(FOG_CELL))), 0, FOG_N - 1)
	var cz: int = clampi(int(floor((z + 32.0) / float(FOG_CELL))), 0, FOG_N - 1)
	return cz * FOG_N + cx


static func compute_fog(prev: PackedInt32Array, viewers: Array) -> PackedInt32Array:
	var next: PackedInt32Array = prev.duplicate()
	# Decae visible->explorado
	for i in range(next.size()):
		if next[i] == 2:
			next[i] = 1
	for v in viewers:
		var vx: float
		var vz: float
		var vrange: float
		if v is Dictionary:
			vx = float(v.get("x", 0.0))
			vz = float(v.get("z", 0.0))
			vrange = float(v.get("range", 0.0))
		else:
			vx = float(v.x)
			vz = float(v.z)
			vrange = float(v.range)
		var r: int = int(ceil(vrange / float(FOG_CELL)))
		var ccx: int = int(floor((vx + 32.0) / float(FOG_CELL)))
		var ccz: int = int(floor((vz + 32.0) / float(FOG_CELL)))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cx: int = ccx + dx
				var cz: int = ccz + dz
				if cx < 0 or cz < 0 or cx >= FOG_N or cz >= FOG_N:
					continue
				if Vector2(float(dx * FOG_CELL), float(dz * FOG_CELL)).length() <= vrange:
					next[cz * FOG_N + cx] = 2
	return next


static func is_cell_visible(fog: PackedInt32Array, x: float, z: float) -> bool:
	return fog[cell_of(x, z)] == 2
