class_name PauseMenu
extends CanvasLayer
## PauseMenu: menú de pausa construido 100% por código (no toca main.tscn).
## layer=15, process_mode ALWAYS (funciona con el árbol en pausa),
## oculto al inicio. Tecla Esc alterna abrir/cerrar.
## Todo nulo-seguro: comprueba get_tree() y los autoloads antes de usarlos.
##
## CABLEADO (lo hace otro trabajo): instanciar PauseMenu oculto junto a la
## escena principal, e instanciar TitleScreen visible al inicio de cada carga
## para que el botón "Título" lo muestre de nuevo tras el reload.

const WOOD_BG := Color("#3a2a1a")
const GOLD := Color("#c9a227")
const PARCHMENT := Color("#f5e6c8")
const DIM := Color(0.70, 0.72, 0.78)

var _sound_btn: Button


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	_refresh_sound()
	var tree := get_tree()
	if tree != null:
		tree.paused = true


func close() -> void:
	visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := _panel()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	vb.add_child(title)

	var continue_btn := _menu_button("Continuar")
	continue_btn.pressed.connect(_on_continue_pressed)
	vb.add_child(continue_btn)

	var save_btn := _menu_button("Guardar")
	save_btn.pressed.connect(_on_save_pressed)
	vb.add_child(save_btn)

	var load_btn := _menu_button("Cargar")
	load_btn.pressed.connect(_on_load_pressed)
	vb.add_child(load_btn)

	var restart_btn := _menu_button("Reiniciar")
	restart_btn.pressed.connect(_on_restart_pressed)
	vb.add_child(restart_btn)

	_sound_btn = _menu_button("Sonido: ON")
	_sound_btn.pressed.connect(_on_sound_pressed)
	vb.add_child(_sound_btn)

	var title_btn := _menu_button("Título")
	title_btn.pressed.connect(_on_title_pressed)
	vb.add_child(title_btn)

	var quit_btn := _menu_button("Salir")
	quit_btn.pressed.connect(_on_quit_pressed)
	vb.add_child(quit_btn)

	var hint := Label.new()
	hint.text = "Esc: continuar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", DIM)
	vb.add_child(hint)


# ---------- callbacks ----------

func _on_continue_pressed() -> void:
	close()


func _on_save_pressed() -> void:
	var msg := SaveSystem.save_game()
	if msg != "":
		GameState.message = msg
		GameState.message_changed.emit(msg)
	else:
		GameState.message = "Partida guardada"
		GameState.message_changed.emit(GameState.message)


func _on_load_pressed() -> void:
	var msg := SaveSystem.load_game()
	if msg != "" and msg != "Partida cargada":
		GameState.message = msg
		GameState.message_changed.emit(msg)


func _on_restart_pressed() -> void:
	_reset_full_state()
	GameState.started = true
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	visible = false
	tree.reload_current_scene()


func _on_sound_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	var cur := bool(am.get("muted"))
	if am.has_method("set_muted"):
		am.call("set_muted", not cur)
	else:
		am.set("muted", not cur)
	_refresh_sound()


func _on_title_pressed() -> void:
	# Resetea + recarga; el TitleScreen (instanciado visible al inicio por el
	# cableado) aparece de nuevo: started=false para que NO se auto-libere
	# y pause el juego en su _ready.
	_reset_full_state()
	GameState.started = false
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	visible = false
	tree.reload_current_scene()


func _on_quit_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.quit()


func _refresh_sound() -> void:
	if _sound_btn == null:
		return
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		_sound_btn.text = "Sonido: ON"
		return
	if bool(am.get("muted")):
		_sound_btn.text = "Sonido: OFF"
		_sound_btn.modulate = Color(0.55, 0.55, 0.55)
	else:
		_sound_btn.text = "Sonido: ON"
		_sound_btn.modulate = Color.WHITE


# ---------- reset (misma lógica que Hud._reset_full_state + reset_state_data) ----------
# NOTA: los resets NO tocan GameState.started; cada callback lo fija explícitamente.

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
	b.custom_minimum_size = Vector2(260, 40)
	b.add_theme_font_size_override("font_size", 16)
	return b
