extends Node
## GameManager: tick global determinista (ex-store tick). F1+ rellenará sistemas.

const DT_CAP := 0.1
var elapsed := 0.0

func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, DT_CAP)
	elapsed += dt
	# F1: economía. F3: colonos. F5: combate+IA. F6: niebla.
