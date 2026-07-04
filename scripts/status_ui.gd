extends CanvasLayer
## Cartel de fin de demo: al construir la tercera historica (el palacio)
## muestra un mensaje centrado con fade. El resto del estado del juego vive en
## la barra de construccion (build_toolbar.gd): turistas en el boton de casa,
## limpieza/naturaleza como rellenos y el progreso de monumentos en su boton.

@export var build_manager: Node3D

var _demo_end_shown := false

func _process(_delta: float) -> void:
	if not _demo_end_shown and build_manager.is_historic_placed(3):
		_demo_end_shown = true
		_show_demo_end()

## Mensaje unico de fin de demo al construir la tercera historica (el palacio).
## Aparece centrado con un fade suave, queda 10 segundos y se desvanece para
## no tapar la ciudad; no bloquea el mouse en ningun momento.
func _show_demo_end() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_corner_radius_all(roundi(vh * 0.02))
	style.set_content_margin_all(vh * 0.035)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var label := Label.new()
	label.text = "Fin de la demo, puedes quedarte\nmejorando la ciudad el tiempo que quieras :)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(vh * 0.032))
	panel.add_child(label)

	center.modulate.a = 0.0
	var tween := center.create_tween()
	tween.tween_property(center, "modulate:a", 1.0, 1.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(10.0)
	tween.tween_property(center, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(center.queue_free)
