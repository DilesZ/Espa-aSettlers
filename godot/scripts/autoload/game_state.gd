extends Node
## GameState: datos globales del juego (ex-zustand store). Solo datos + señales.

signal resources_changed
signal buildings_changed
signal fog_changed
signal message_changed(text: String)

const MAP_HALF := 30.0
const WATER_X := 22.0

var resources := { "madera": 30.0, "piedra": 15.0, "comida": 10.0, "tablon": 0.0, "trigo": 0.0, "harina": 0.0, "pan": 0.0 }
var buildings: Array = []  # Array[Dictionary] {id,type,x,z,paused,progress,blocked,hp,max_hp}
var settlers: Array = []
var recruits: Array = []  # Array[Dictionary] {id} (nodos Recruit en árbol)
var raiders: Array = []  # Array[Dictionary] {id} (nodos Raider en árbol)
var ai_buildings: Array = []  # Array[Dictionary] {id,type,x,z,hp}
var ai_queue := 0
var nodes: Array = []
var stats := { "tablon": 0.0, "pan": 0.0 }
var fog: PackedInt32Array = PackedInt32Array()
var message := ""
var victory := false
var victory02 := false
var victory03 := false
var defeat := false
var quality := "alto"

func _ready() -> void:
	fog.resize(32 * 32)
	fog.fill(0)
