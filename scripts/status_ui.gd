extends CanvasLayer
## Panel de estado arriba a la derecha: turistas totales, zona actual y dos
## barras de crecimiento (naturaleza y limpieza) con los mismos iconos que la
## barra de construccion. Barra baja = menos turistas nuevos.
##
## Cuando un valor cae por debajo del 100% la fila entra en modo alerta: la
## barra se pone roja y el icono pulsa (el borde del panel tambien pulsa para
## llamar la atencion del jugador).
##
## Todos los tamanos son fracciones del alto del viewport, igual que en
## build_toolbar.gd: el panel se ve igual de grande en cualquier resolucion.

const NATURE_BAR_COLOR := Color(0.38, 0.72, 0.36)
const CLEAN_BAR_COLOR := Color(0.45, 0.75, 0.88)
const WARNING_COLOR := Color(0.95, 0.35, 0.28)

@export var tourist_manager: Node3D
@export var build_manager: Node3D

var _panel: PanelContainer
var _margin: MarginContainer
var _vbox: VBoxContainer
var _tourists_label: Label
var _zone_label: Label
var _panel_style: StyleBoxFlat
var _nature_row: Dictionary
var _clean_row: Dictionary
var _demo_end_shown := false

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _process(_delta: float) -> void:
	_tourists_label.text = "Turistas: %d" % tourist_manager.total_spawned
	var requirement: String = build_manager.next_zone_requirement()
	var side: int = build_manager.unlocked_side()
	if requirement == "":
		_zone_label.text = "Zona %dx%d completa" % [side, side]
	else:
		_zone_label.text = "Zona %dx%d — amplia: %s" % [side, side, requirement]

	# Parpadeo compartido por todas las alertas (~1 ciclo por segundo).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	var nature_factor: float = tourist_manager.nature_factor()
	var clean_factor: float = tourist_manager.clean_factor()
	_update_row(_nature_row, nature_factor, pulse)
	_update_row(_clean_row, clean_factor, pulse)

	# Borde del panel en rojo pulsante mientras haya cualquier deficit.
	var border := WARNING_COLOR
	border.a = (0.35 + 0.65 * pulse) if nature_factor < 1.0 or clean_factor < 1.0 else 0.0
	_panel_style.border_color = border

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

func _update_row(row: Dictionary, factor: float, pulse: float) -> void:
	var bar: ProgressBar = row.bar
	bar.value = factor * 100.0
	var warning := factor < 1.0
	var fill: StyleBoxFlat = row.fill
	fill.bg_color = WARNING_COLOR if warning else row.base_color
	var icon: TextureRect = row.icon
	icon.modulate = Color.WHITE.lerp(WARNING_COLOR, pulse) if warning else Color.WHITE

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_margin)

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_vbox)

	_tourists_label = Label.new()
	_tourists_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_vbox.add_child(_tourists_label)

	_zone_label = Label.new()
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_vbox.add_child(_zone_label)

	_nature_row = _add_status_row("res://icons/leaf.svg", NATURE_BAR_COLOR)
	_clean_row = _add_status_row("res://icons/recycle.svg", CLEAN_BAR_COLOR)

func _add_status_row(icon_path: String, color: Color) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(hbox)

	var icon := TextureRect.new()
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	hbox.add_child(bar)

	return {
		hbox = hbox,
		icon = icon,
		bar = bar,
		background = background,
		fill = fill,
		base_color = color,
	}

## Recalcula todos los tamanos como fracciones del alto del viewport.
func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	_panel_style.set_corner_radius_all(roundi(vh * 0.012))
	_panel_style.set_border_width_all(maxi(roundi(vh * 0.004), 2))
	_panel_style.border_color = Color(0, 0, 0, 0)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, roundi(vh * 0.012)
	)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END

	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_margin.add_theme_constant_override(side, roundi(vh * 0.014))
	_vbox.add_theme_constant_override("separation", roundi(vh * 0.010))

	_tourists_label.add_theme_font_size_override("font_size", roundi(vh * 0.030))
	_zone_label.add_theme_font_size_override("font_size", roundi(vh * 0.018))

	for row in [_nature_row, _clean_row]:
		var hbox: HBoxContainer = row.hbox
		hbox.add_theme_constant_override("separation", roundi(vh * 0.012))
		var icon: TextureRect = row.icon
		icon.custom_minimum_size = Vector2.ONE * vh * 0.045
		var bar: ProgressBar = row.bar
		bar.custom_minimum_size = Vector2(vh * 0.26, vh * 0.024)
		var radius := roundi(vh * 0.005)
		(row.background as StyleBoxFlat).set_corner_radius_all(radius)
		(row.fill as StyleBoxFlat).set_corner_radius_all(radius)
