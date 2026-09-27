class_name Benchmark
extends Node
## Overlay de rendimiento con F9 y volcado a fichero con F10.
## F9: Label con FPS, draw calls, tris y VRAM. F10: escribe user://benchmark.txt.
## Sin auto-quit. Usa _unhandled_key_input.


var _label: Label
var _show := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.offset_left = 8.0
	_label.offset_top = 46.0
	_label.offset_right = 340.0
	_label.offset_bottom = 150.0
	layer.add_child(_label)


func _process(_delta: float) -> void:
	if _show and _label != null:
		_label.text = _stats_text()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_F9 or k.physical_keycode == KEY_F9:
		_show = not _show
		if _label != null:
			_label.visible = _show
			if _show:
				_label.text = _stats_text()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_F10 or k.physical_keycode == KEY_F10:
		_write_file()
		get_viewport().set_input_as_handled()


func _stats_text() -> String:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var mem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) + Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) + Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	var mem_mb := float(mem) / (1024.0 * 1024.0)
	return "FPS: %d\nDraw calls: %d\nTris: %d\nVRAM: %.2f MB" % [int(fps), int(draws), int(tris), mem_mb]


func _write_file() -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var mem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) + Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) + Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	var quality := str(GameState.quality)
	var stamp := Time.get_datetime_string_from_system()
	var text := "benchmark %s\nquality=%s\nfps=%d\ndraw_calls=%d\ntris=%d\nmem_used=%d\n" % [stamp, quality, int(fps), int(draws), int(tris), int(mem)]
	var f := FileAccess.open("user://benchmark.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
