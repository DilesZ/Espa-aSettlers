class_name Hud
extends CanvasLayer
## HUD construido por código (tema oscuro): barra superior de recursos,
## paleta de construcción, lista de producción, alertas, banners y mensaje.
## Lee GameState por polling cada 0.25 s y delega en el grupo "build_manager"
## (select_building / toggle_demolish / toggle_pause). No toca main.tscn.

const RES_KEYS: Array[String] = ["madera", "piedra", "comida", "tablon", "trigo", "harina", "pan"]
const RES_NAMES: Dictionary = {
	"madera": "Madera",
	"piedra": "Piedra",
	"comida": "Comida",
	"tablon": "Tablón",
	"trigo": "Trigo",
	"harina": "Harina",
	"pan": "Pan",
}
const POLL := 0.25
const LIGHT := Color(0.92, 0.93, 0.95)
const DIM := Color(0.70, 0.72, 0.78)
const GOOD := Color(0.50, 0.93, 0.60)
const BAD := Color(0.95, 0.45, 0.45)

var _accum := 0.0
var _res_labels: Dictionary = {}
var _settlers_label: Label
var _buildings_label: Label
var _palette_btns: Dictionary = {}
var _demolish_btn: Button
var _recruit_btn: Button
var _captain_btn: Button
var _explorer_btn: Button
var _quality_btns: Dictionary = {}
var _mute_btn: Button
var _prod_rows: VBoxContainer
var _alerts_label: Label
var _victory_banner: Label
var _victory02_banner: Label
var _victory03_banner: Label
var _defeat_banner: Label
var _message_label: Label


func _ready() -> void:
	layer = 10
	_build_topbar()
	_build_palette()
	_build_production()
	_build_alerts()
	_build_message()
	_build_banners()
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL:
		_accum = 0.0
		_refresh()


# ---------- construcción de UI ----------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.93)
	sb.border_color = Color(0.30, 0.33, 0.40)
	sb.set_border_width_all(1)
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


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", LIGHT)
	return l


func _dark_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.19, 0.26, 1.0)
	normal.border_color = Color(0.35, 0.39, 0.48)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 6.0
	normal.content_margin_right = 6.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.22, 0.26, 0.35, 1.0)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.13, 0.45, 0.55, 1.0)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", LIGHT)
	b.add_theme_color_override("font_hover_color", LIGHT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b


func _build_topbar() -> void:
	var top := _panel()
	top.anchor_left = 0.0
	top.anchor_top = 0.0
	top.anchor_right = 1.0
	top.anchor_bottom = 0.0
	top.offset_left = 0.0
	top.offset_top = 0.0
	top.offset_right = 0.0
	top.offset_bottom = 42.0
	add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(hb)
	for k in RES_KEYS:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", LIGHT)
		hb.add_child(l)
		_res_labels[k] = l
	var sep := VSeparator.new()
	hb.add_child(sep)
	_settlers_label = Label.new()
	_settlers_label.add_theme_font_size_override("font_size", 13)
	_settlers_label.add_theme_color_override("font_color", LIGHT)
	hb.add_child(_settlers_label)
	_buildings_label = Label.new()
	_buildings_label.add_theme_font_size_override("font_size", 13)
	_buildings_label.add_theme_color_override("font_color", LIGHT)
	hb.add_child(_buildings_label)
	var restart := _dark_button("Reiniciar")
	restart.alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.pressed.connect(_on_restart_pressed)
	hb.add_child(restart)
	var save_btn := _dark_button("Guardar")
	save_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_btn.pressed.connect(_on_save_pressed)
	hb.add_child(save_btn)
	var load_btn := _dark_button("Cargar")
	load_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_btn.pressed.connect(_on_load_pressed)
	hb.add_child(load_btn)


func _build_palette() -> void:
	var pal := _panel()
	pal.anchor_left = 0.0
	pal.anchor_top = 0.0
	pal.anchor_right = 0.0
	pal.anchor_bottom = 1.0
	pal.offset_left = 8.0
	pal.offset_top = 50.0
	pal.offset_right = 232.0
	pal.offset_bottom = -8.0
	add_child(pal)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pal.add_child(vb)
	vb.add_child(_title("Construir"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for t in _palette_types():
		var nombre := str(Economy.BUILDINGS[t]["nombre"])
		var b := _dark_button("%s\n%s" % [nombre, _cost_text(t)])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_palette_pressed.bind(t))
		box.add_child(b)
		_palette_btns[t] = b
	_demolish_btn = _dark_button("Demoler")
	_demolish_btn.toggle_mode = true
	_demolish_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demolish_btn.pressed.connect(_on_demolish_pressed)
	vb.add_child(_demolish_btn)
	_recruit_btn = _dark_button("Recluta (15 comida)")
	_recruit_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recruit_btn.pressed.connect(_on_recruit_pressed)
	vb.add_child(_recruit_btn)
	_captain_btn = _dark_button("Capitán (30 comida)")
	_captain_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_captain_btn.pressed.connect(_on_captain_pressed)
	vb.add_child(_captain_btn)
	_explorer_btn = _dark_button("Explorador (10 comida)")
	_explorer_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_explorer_btn.pressed.connect(_on_explorer_pressed)
	vb.add_child(_explorer_btn)
	vb.add_child(_title("Calidad"))
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 4)
	vb.add_child(qh)
	for lvl in ["alto", "medio", "bajo"]:
		var qb := _dark_button(lvl.capitalize())
		qb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.pressed.connect(_on_quality_pressed.bind(lvl))
		qh.add_child(qb)
		_quality_btns[lvl] = qb
	_mute_btn = _dark_button("Sonido: ON")
	_mute_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mute_btn.pressed.connect(_on_mute_pressed)
	vb.add_child(_mute_btn)
	_refresh_quality()
	_refresh_mute()


func _build_production() -> void:
	var prod := _panel()
	prod.anchor_left = 1.0
	prod.anchor_top = 0.0
	prod.anchor_right = 1.0
	prod.anchor_bottom = 1.0
	prod.offset_left = -320.0
	prod.offset_top = 50.0
	prod.offset_right = -8.0
	prod.offset_bottom = -8.0
	add_child(prod)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	prod.add_child(vb)
	vb.add_child(_title("Producción"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_prod_rows = VBoxContainer.new()
	_prod_rows.add_theme_constant_override("separation", 6)
	_prod_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_prod_rows)


func _build_alerts() -> void:
	var ap := _panel()
	ap.anchor_left = 0.0
	ap.anchor_top = 1.0
	ap.anchor_right = 0.0
	ap.anchor_bottom = 1.0
	ap.offset_left = 240.0
	ap.offset_top = -218.0
	ap.offset_right = 624.0
	ap.offset_bottom = -44.0
	add_child(ap)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	ap.add_child(vb)
	vb.add_child(_title("Alertas"))
	_alerts_label = Label.new()
	_alerts_label.add_theme_font_size_override("font_size", 13)
	_alerts_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_alerts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alerts_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_alerts_label)


func _build_message() -> void:
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_message_label.offset_left = 0.0
	_message_label.offset_top = -36.0
	_message_label.offset_right = 0.0
	_message_label.offset_bottom = -6.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 15)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message_label)


func _build_banners() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vb)
	_victory_banner = Label.new()
	_victory_banner.text = "¡Victoria! Madera y piedra conseguidas"
	_victory_banner.add_theme_font_size_override("font_size", 42)
	_victory_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_victory_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_banner.visible = false
	vb.add_child(_victory_banner)
	_victory02_banner = Label.new()
	_victory02_banner.text = "¡Victoria Fase 02! Tablones y pan completados"
	_victory02_banner.add_theme_font_size_override("font_size", 32)
	_victory02_banner.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
	_victory02_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory02_banner.visible = false
	vb.add_child(_victory02_banner)
	_victory03_banner = Label.new()
	_victory03_banner.text = "¡Victoria total! Centro enemigo destruido"
	_victory03_banner.add_theme_font_size_override("font_size", 36)
	_victory03_banner.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	_victory03_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory03_banner.visible = false
	vb.add_child(_victory03_banner)
	_defeat_banner = Label.new()
	_defeat_banner.text = "Derrota: la partida ha terminado"
	_defeat_banner.add_theme_font_size_override("font_size", 36)
	_defeat_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_defeat_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defeat_banner.visible = false
	vb.add_child(_defeat_banner)


# ---------- refresco por polling ----------

func _refresh() -> void:
	if _settlers_label == null:
		return
	var res: Dictionary = GameState.resources
	var almacenes := 0
	for b in GameState.buildings:
		if str((b as Dictionary).get("type", "")) == "almacen":
			almacenes += 1
	var cap: int = Economy.storage_cap(almacenes)
	for k in RES_KEYS:
		var lbl: Label = _res_labels.get(k)
		if lbl != null:
			lbl.text = "%s %d/%d" % [str(RES_NAMES.get(k, k)), int(res.get(k, 0)), cap]
	_settlers_label.text = "Colonos %d" % GameState.settlers.size()
	_buildings_label.text = "Edificios %d" % GameState.buildings.size()
	for t in _palette_btns.keys():
		var btn: Button = _palette_btns[t]
		if Economy.can_afford(res, str(t)):
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.45, 0.45, 0.45)
	var bm := _bm()
	if bm != null and _demolish_btn != null:
		var d: bool = bool(bm.get("demolish"))
		if _demolish_btn.button_pressed != d:
			_demolish_btn.set_pressed_no_signal(d)
	_refresh_production()
	_refresh_alerts(cap)
	_refresh_quality()
	_refresh_mute()
	_victory_banner.visible = bool(GameState.victory)
	_victory02_banner.visible = bool(GameState.victory02)
	_victory03_banner.visible = bool(GameState.victory03)
	_defeat_banner.visible = bool(GameState.defeat)
	var msg := str(GameState.message)
	_message_label.text = msg
	_message_label.visible = msg != ""


func _refresh_production() -> void:
	for c in _prod_rows.get_children():
		_prod_rows.remove_child(c)
		c.queue_free()
	var any := false
	for b in GameState.buildings:
		var bd: Dictionary = b
		var t := str(bd.get("type", ""))
		if not Economy.RECIPES.has(t):
			continue
		any = true
		_prod_rows.add_child(_make_prod_row(bd))
	if not any:
		var l := Label.new()
		l.text = "Sin producción (construye aserradero, granja…)"
		l.add_theme_color_override("font_color", DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prod_rows.add_child(l)


func _make_prod_row(bd: Dictionary) -> Control:
	var id := str(bd.get("id", ""))
	var t := str(bd.get("type", ""))
	var nombre := str(Economy.BUILDINGS.get(t, {}).get("nombre", t))
	var paused := bool(bd.get("paused", false))
	var blocked := bool(bd.get("blocked", false))
	var prog := clampf(float(bd.get("progress", 0.0)), 0.0, 1.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	var name_l := Label.new()
	name_l.text = "%s #%s" % [nombre, id]
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", LIGHT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var estado := "En marcha"
	var estado_col := GOOD
	if paused and blocked:
		estado = "Pausado · Bloqueado"
		estado_col = BAD
	elif paused:
		estado = "Pausado"
		estado_col = BAD
	elif blocked:
		estado = "Bloqueado"
		estado_col = BAD
	var estado_l := Label.new()
	estado_l.text = estado
	estado_l.add_theme_font_size_override("font_size", 12)
	estado_l.add_theme_color_override("font_color", estado_col)
	head.add_child(estado_l)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = prog
	bar.show_percentage = true
	bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(bar)
	var pb := _dark_button("Reanudar" if paused else "Pausar")
	pb.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb.pressed.connect(_on_pause_pressed.bind(id))
	box.add_child(pb)
	return box


func _refresh_alerts(cap: int) -> void:
	var lines: Array[String] = []
	var res: Dictionary = GameState.resources
	for k in RES_KEYS:
		if int(res.get(k, 0)) >= cap:
			lines.append("Almacén lleno: %s al máximo (%d/%d)" % [str(RES_NAMES.get(k, k)), int(res.get(k, 0)), cap])
	var puestos := 0
	var bloqueados: Array[String] = []
	for b in GameState.buildings:
		var bd: Dictionary = b
		var t := str(bd.get("type", ""))
		if Economy.RECIPES.has(t):
			puestos += int(Economy.RECIPES[t].get("workers", 1))
		if bool(bd.get("blocked", false)):
			bloqueados.append(str(Economy.BUILDINGS.get(t, {}).get("nombre", t)))
	var ncol: int = GameState.settlers.size()
	if puestos > ncol:
		lines.append("Faltan trabajadores: %d puestos / %d colonos" % [puestos, ncol])
	if not bloqueados.is_empty():
		lines.append("Bloqueados: " + ", ".join(bloqueados))
	if lines.is_empty():
		_alerts_label.text = "Sin alertas"
	else:
		_alerts_label.text = "\n".join(lines)


# ---------- callbacks ----------

func _bm() -> Node:
	for n in get_tree().get_nodes_in_group("build_manager"):
		return n
	return null


func _palette_types() -> Array:
	var out: Array = []
	for t in Economy.BUILDINGS.keys():
		if str(t) != "centro":
			out.append(str(t))
	return out


func _cost_text(t: String) -> String:
	var c: Dictionary = Economy.BUILDINGS[t]["coste"]
	var parts: Array[String] = []
	if int(c.get("madera", 0)) > 0:
		parts.append("%d madera" % int(c.get("madera", 0)))
	if int(c.get("piedra", 0)) > 0:
		parts.append("%d piedra" % int(c.get("piedra", 0)))
	if parts.is_empty():
		return "gratis"
	return " + ".join(parts)


func _on_palette_pressed(t: String) -> void:
	var bm := _bm()
	if bm != null and bm.has_method("select_building"):
		bm.call("select_building", t)


func _on_demolish_pressed() -> void:
	var bm := _bm()
	if bm != null and bm.has_method("toggle_demolish"):
		bm.call("toggle_demolish")


func _on_recruit_pressed() -> void:
	var err: String = Recruit.train()
	if err != "":
		GameState.message = err
		GameState.message_changed.emit(err)


func _on_captain_pressed() -> void:
	var err: String = Captain.train()
	if err != "":
		GameState.message = err
		GameState.message_changed.emit(err)


func _on_explorer_pressed() -> void:
	var err: String = Explorer.train()
	if err != "":
		GameState.message = err
		GameState.message_changed.emit(err)


func _on_quality_pressed(level: String) -> void:
	Quality.apply(level)
	_refresh_quality()


func _refresh_quality() -> void:
	var cur := str(GameState.quality).to_lower()
	for lvl in _quality_btns.keys():
		var btn: Button = _quality_btns[lvl]
		if str(lvl) == cur:
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.55, 0.55, 0.55)


func _on_mute_pressed() -> void:
	AudioManager.set_muted(not AudioManager.muted)
	_refresh_mute()


func _refresh_mute() -> void:
	if _mute_btn == null:
		return
	if AudioManager.muted:
		_mute_btn.text = "Sonido: OFF"
		_mute_btn.modulate = Color(0.55, 0.55, 0.55)
	else:
		_mute_btn.text = "Sonido: ON"
		_mute_btn.modulate = Color.WHITE


func _on_pause_pressed(id: String) -> void:
	var bm := _bm()
	if bm != null and bm.has_method("toggle_pause"):
		bm.call("toggle_pause", id)


## Resetea SOLO los datos de GameState a valores iniciales (testeable sin
## escena: no toca el árbol ni recarga). Lo usa _reset_full_state() y los tests.
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
	GameManager.elapsed = 0.0
	GameManager._grow_t = 0.0
	GameManager._spawned = false
	reset_state_data()


func _on_restart_pressed() -> void:
	_reset_full_state()
	get_tree().reload_current_scene()


func _on_save_pressed() -> void:
	var msg := SaveSystem.save_game()
	if msg != "":
		GameState.message = msg
		GameState.message_changed.emit(msg)


func _on_load_pressed() -> void:
	var msg := SaveSystem.load_game()
	if msg != "":
		GameState.message = msg
		GameState.message_changed.emit(msg)
