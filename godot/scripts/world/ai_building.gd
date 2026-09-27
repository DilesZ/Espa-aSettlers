class_name AiBuildingNode
extends Node3D
## Edificio enemigo Fase 03: caja roja + techo oscuro + barra HP con billboard.
## Lo instancia AiController (add_child + setup). `data` enlaza con el dict de
## GameState.ai_buildings por "id". La barra se refresca en _process leyendo el
## dict vivo, así refleja el daño sin cableado extra.

const COLOR_BODY := Color("#9d0208")
const COLOR_ROOF := Color("#370617")
const BAR_W := 1.6
const BAR_H := 0.18
const BAR_Y := 4.1
const COL_OK := Color("#38b000")
const COL_MID := Color("#ffbe0b")
const COL_LOW := Color("#e63946")

var data: Dictionary = {}

var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D
var _fg_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("ai_building_nodes")


func setup(d: Dictionary) -> void:
	add_to_group("ai_building_nodes")
	data = d.duplicate()
	var tipo: String = str(data.get("type", "granja"))
	position = Vector3(float(data.get("x", 0.0)), 0.0, float(data.get("z", 0.0)))
	if str(data.get("id", "")) != "":
		name = "AiBuilding_%s" % str(data.get("id"))

	var w := 3.2
	if Economy.BUILDINGS.has(tipo):
		w = float((Economy.BUILDINGS[tipo] as Dictionary).get("radio", 2.0)) * 1.6

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_BODY
	mat.roughness = 0.8

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(w, 2.0, w)
	box.mesh = box_mesh
	box.position = Vector3(0.0, 1.0, 0.0)
	box.set_surface_override_material(0, mat)
	add_child(box)

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = COLOR_ROOF
	roof_mat.roughness = 0.7

	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = w * 0.75
	cone.height = 1.5
	cone.radial_segments = 4
	roof.mesh = cone
	roof.position = Vector3(0.0, 2.75, 0.0)
	roof.rotation.y = deg_to_rad(45.0)
	roof.set_surface_override_material(0, roof_mat)
	add_child(roof)

	_build_bar()
	refresh_bar()


func _process(_delta: float) -> void:
	refresh_bar()


func refresh_bar() -> void:
	if _bar_fg == null or _fg_mat == null:
		return
	var live := _live_dict()
	var hp := float(live.get("hp", data.get("hp", 1.0)))
	var pct := clampf(hp / maxf(_max_hp(live), 1.0), 0.0, 1.0)
	if pct > 0.5:
		_fg_mat.albedo_color = COL_OK
	elif pct > 0.25:
		_fg_mat.albedo_color = COL_MID
	else:
		_fg_mat.albedo_color = COL_LOW
	_bar_fg.scale.x = maxf(pct, 0.001)
	_bar_fg.position.x = -BAR_W * (1.0 - pct) * 0.5


## Dict vivo de GameState.ai_buildings con el mismo id (refleja el daño);
## si ya no existe (destruido), usa la copia local.
func _live_dict() -> Dictionary:
	var my_id := str(data.get("id", ""))
	for b in GameState.ai_buildings:
		if b is Dictionary and str((b as Dictionary).get("id", "")) == my_id:
			return b as Dictionary
	return data


## El dict IA es {id,type,x,z,hp}: el máximo se deriva de Economy.BUILDING_HP.
func _max_hp(live: Dictionary) -> float:
	if live.has("max_hp"):
		return maxf(float(live.get("max_hp", 1.0)), 1.0)
	var tipo := str(live.get("type", data.get("type", "")))
	if Economy.BUILDING_HP.has(tipo):
		return maxf(float(Economy.BUILDING_HP[tipo]), 1.0)
	return maxf(float(live.get("hp", 1.0)), 1.0)


func _build_bar() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.7)
	_bar_bg = MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_W + 0.08, BAR_H + 0.08)
	_bar_bg.mesh = bg_mesh
	_bar_bg.set_surface_override_material(0, bg_mat)
	_bar_bg.position = Vector3(0.0, BAR_Y, 0.0)
	add_child(_bar_bg)

	_fg_mat = StandardMaterial3D.new()
	_fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fg_mat.no_depth_test = true
	_fg_mat.albedo_color = COL_OK
	_bar_fg = MeshInstance3D.new()
	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(BAR_W, BAR_H)
	_bar_fg.mesh = fg_mesh
	_bar_fg.set_surface_override_material(0, _fg_mat)
	_bar_fg.position = Vector3(0.0, BAR_Y, 0.01)
	add_child(_bar_fg)
