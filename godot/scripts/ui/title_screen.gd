class_name TitleScreen
extends CanvasLayer
## TitleScreen: pantalla de título construida 100% por código (no toca main.tscn).
## layer=20, process_mode ALWAYS (funciona con el árbol en pausa).
## Al mostrarse pausa el juego; "Nueva partida" / "Continuar" hacen unpause.
##
## CABLEADO (lo hace otro trabajo, no este archivo): instanciar TitleScreen
## visible al inicio de cada carga de escena (p. ej. añadirlo en _ready de la
## escena principal) para que reaparezca tras cada reload_current_scene()
## (botón "Título" del PauseMenu / reinicios).

const SAVE_PATH := "user://savegame.cfg"
const WOOD_BG := Color("#3a2a1a")
const GOLD := Color("#c9a227")
const PARCHMENT := Color("#f5e6c8")
const DIM := Color(0.70, 0.72, 0.78)

var _continue_btn: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var tree := get_tree()
	if tree != null:
		tree.paused = true


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	var title := Label.new()
	title.text = "ESPAÑA SETTLERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD)
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "v1.x nativo · Godot 4.7"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", PARCHMENT)
	vb.add_child(subtitle)

	var panel := _panel()
	vb.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var new_btn := _menu_button("Nueva partida")
	new_btn.pressed.connect(_on_new_pressed)
	box.add_child(new_btn)

	_continue_btn = _menu_button("Continuar")
	_continue_btn.visible = FileAccess.file_exists(SAVE_PATH)
	_continue_btn.pressed.connect(_on_continue_pressed)
	box.add_child(_continue_btn)

	var quit_btn := _menu_button("Salir")
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)

	var bottom := _panel()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12.0
	bottom.offset_top = -64.0
	bottom.offset_right = -12.0
	bottom.offset_bottom = -12.0
	add_child(bottom)
	var controls := Label.new()
	controls.text = "Controles: clic construir · central arrastrar · rueda zoom · botón derecho rotar · F9 benchmark"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", DIM)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(controls)


# ---------- callbacks ----------

func _on_new_pressed() -> void:
	_reset_full_state()
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.reload_current_scene()
	queue_free()


func _on_continue_pressed() -> void:
	var msg := SaveSystem.load_game()
	if msg != "" and msg != "Partida cargada":
		GameState.message = msg
		GameState.message_changed.emit(msg)
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	queue_free()


func _on_quit_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.quit()


# ---------- reset (misma lógica que Hud._reset_full_state + reset_state_data) ----------

## Resetea SOLO los datos de GameState a valores iniciales (no toca el árbol).
static func reset_state_data() -> void:
	GameState.resources = {
		"madera": 30.0, "piedra": 15.0, "comida": 10.0,
		"tablon": 0.0, "trigo": 0.0, "harina": 0.0, "pan": 0.0,
	}
	var centro_hp: float = float(Economy.BUILDING_HP.get("centro", 500))
	var centro_radio: float = float((Economy.BUILDINGS["centro"] as Dictionary).get("radio", 3.0))
	GameState.buildings = [
		{
			"id": 1, "type": "centro", "x": 0.0, "z": 0.0,
			"paused": false, "progress": 0.0, "blocked": false,
			"hp": centro_hp, "max_hp": centro_hp,
			"radio": centro_radio, "build_t": 5.0,
		}
	]
	GameState.settlers = []
	GameState.recruits = []
	GameState.raiders = []
	GameState.ai_buildings = [
		{"id": "ai_centro", "type": "centro", "x": float(Economy.AI_BASE.get("x", 16.0)), "z": float(Economy.AI_BASE.get("z", -20.0)), "hp": 300.0}
	]
	GameState.ai_queue = 0
	GameState.nodes = []
	GameState.stats = {"tablon": 0.0, "pan": 0.0}
	GameState.fog.resize(32 * 32)
	GameState.fog.fill(0)
	GameState.message = ""
	GameState.victory = false
	GameState.victory02 = false
	GameState.victory03 = false
	GameState.defeat = false
	GameState.resources_changed.emit()
	GameState.buildings_changed.emit()
	GameState.fog_changed.emit()
	GameState.message_changed.emit("")


## Resetea partida completa: libera actores/nodos, resetea IDs y GameManager,
## restaura datos vía reset_state_data(). No recarga (lo hace el llamador).
func _reset_full_state() -> void:
	var tree := get_tree()
	if tree != null:
		for n in tree.get_nodes_in_group("raiders"):
			if is_instance_valid(n):
				n.queue_free()
		for n in tree.get_nodes_in_group("recruits"):
			if is_instance_valid(n):
				n.queue_free()
		for n in tree.get_nodes_in_group("building_nodes"):
			if is_instance_valid(n):
				n.queue_free()
		for n in tree.get_nodes_in_group("ai_building_nodes"):
			if is_instance_valid(n):
				n.queue_free()
		if tree.current_scene != null:
			for n in tree.current_scene.find_children("*", "CharacterBody3D", true, false):
				if (n is Settler or n is Recruit or n is Captain or n is Explorer) and is_instance_valid(n):
					n.queue_free()
	Settler._next_id = 0
	Recruit._next_id = 0
	Captain._next_id = 0
	Explorer._next_id = 0
	# GameManager es autoload persistente: si no se resetea, tras el reload
	# no reaparecen ni el centro ni los 6 colonos (_spawned seguiría true).
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set("elapsed", 0.0)
		gm.set("_grow_t", 0.0)
		gm.set("_spawned", false)
	reset_state_data()


# ---------- estilo madera/dorado (replica Hud._panel_style/_dark_button) ----------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WOOD_BG.r, WOOD_BG.g, WOOD_BG.b, 0.95)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	return p


func _dark_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#5a4028")
	normal.border_color = GOLD
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 6.0
	normal.content_margin_right = 6.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#6f502f")
	hover.border_color = Color("#e3c84b")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("#2a1e12")
	pressed.border_color = GOLD
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#3a2a1a")
	disabled.border_color = Color(0.45, 0.38, 0.25)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("#e3c84b"))
	return b


func _menu_button(text: String) -> Button:
	var b := _dark_button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(300, 46)
	b.add_theme_font_size_override("font_size", 18)
	return b
