extends CanvasLayer
## Barra de construccion a la izquierda: botones con icono que equivalen a las
## teclas de build_manager.gd (casa 1x1, limpieza, naturaleza, monumento).
## El boton de monumento representa siempre la proxima historica sin construir
## (estatua -> catedral -> palacio) y se atenua mientras no este desbloqueada.
## Clickear un boton ya activo deselecciona; la seleccion por teclado (1-8)
## tambien se refleja en los botones.
##
## El tamano de los botones es una fraccion del alto del viewport, asi la barra
## se ve igual de grande en cualquier resolucion (se recalcula al redimensionar).

## Script de build_manager, para usar sus constantes TYPE_* y HISTORIC_NAMES.
## Preload directo (y no class_name) para no depender del cache de clases
## globales del editor.
const BuildManager := preload("res://scripts/build_manager.gd")

## Lado de cada boton como fraccion del alto del viewport.
const BUTTON_HEIGHT_RATIO := 0.19
const MIN_BUTTON_SIDE := 96.0
const PRESSED_BORDER_COLOR := Color(0.65, 0.9, 0.6)
const MONUMENT_FILL_COLOR := Color(0.55, 0.85, 0.55, 0.3)

@export var build_manager: Node3D

var _vbox: VBoxContainer
var _buttons: Array[Button] = []
var _house_button: Button
var _cleaner_button: Button
var _nature_button: Button
var _monument_button: Button
var _monument_fill: Panel
var _monument_fill_style: StyleBoxFlat
var _monument_variant := 1

func _ready() -> void:
	_vbox = VBoxContainer.new()
	add_child(_vbox)

	_house_button = _add_button("house", "Casa 1x1  [1]")
	_cleaner_button = _add_button("recycle", "Limpieza  [4]")
	_nature_button = _add_button("leaf", "Naturaleza  [5]")
	_monument_button = _add_button("monument", "Monumento")

	# Relleno que sube desde abajo del boton: progreso de turistas hacia el
	# desbloqueo de la historica actual. Desaparece al desbloquearse.
	_monument_fill = Panel.new()
	_monument_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monument_fill_style = StyleBoxFlat.new()
	_monument_fill_style.bg_color = MONUMENT_FILL_COLOR
	_monument_fill.add_theme_stylebox_override("panel", _monument_fill_style)
	_monument_fill.anchor_left = 0.0
	_monument_fill.anchor_right = 1.0
	_monument_fill.anchor_top = 1.0
	_monument_fill.anchor_bottom = 1.0
	_monument_button.add_child(_monument_fill)

	_house_button.toggled.connect(_on_button_toggled.bind(BuildManager.TYPE_HOUSE, 1))
	_cleaner_button.toggled.connect(_on_button_toggled.bind(BuildManager.TYPE_CLEANER, 0))
	_nature_button.toggled.connect(_on_button_toggled.bind(BuildManager.TYPE_NATURE, 0))
	_monument_button.toggled.connect(_on_monument_toggled)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## El estado (seleccion, historica que toca, desbloqueos) se sondea por frame,
## igual que hace build_manager con su info label.
func _process(_delta: float) -> void:
	_monument_variant = build_manager.next_historic_variant()
	var type: String = build_manager.selected_type()
	var variant: int = build_manager.selected_variant()
	_house_button.set_pressed_no_signal(type == BuildManager.TYPE_HOUSE and variant == 1)
	_cleaner_button.set_pressed_no_signal(type == BuildManager.TYPE_CLEANER)
	_nature_button.set_pressed_no_signal(type == BuildManager.TYPE_NATURE)
	_monument_button.set_pressed_no_signal(
		type == BuildManager.TYPE_HISTORIC and variant == _monument_variant
	)
	_update_monument_state()

func _on_button_toggled(pressed: bool, type: String, variant: int) -> void:
	if pressed:
		build_manager.select_building(type, variant)
	else:
		build_manager.select_building("", 0)

func _on_monument_toggled(pressed: bool) -> void:
	if pressed:
		build_manager.select_building(BuildManager.TYPE_HISTORIC, _monument_variant)
	else:
		build_manager.select_building("", 0)

## Tooltip y atenuado del boton de monumento segun la historica que representa.
## Se puede seleccionar aunque falten turistas (igual que por teclado): el
## fantasma sale rojo y el HUD explica por que.
func _update_monument_state() -> void:
	var monument_name: String = BuildManager.HISTORIC_NAMES[_monument_variant]
	var tooltip := "%s  [%d]" % [monument_name, 5 + _monument_variant]
	var dimmed := false
	var progress := 1.0
	if build_manager.is_historic_placed(_monument_variant):
		tooltip += " — construida"
		dimmed = true
	elif not build_manager.is_historic_unlocked(_monument_variant):
		var threshold: int = build_manager.historic_threshold(_monument_variant)
		tooltip += " — faltan turistas (%d/%d)" % [build_manager.total_tourists(), threshold]
		dimmed = true
		progress = clampf(float(build_manager.total_tourists()) / threshold, 0.0, 1.0)
	_monument_button.modulate.a = 0.5 if dimmed else 1.0
	# El relleno solo se ve mientras falta progreso: sube de 0 a lleno y al
	# desbloquearse desaparece (el boton pasa a brillo completo).
	_monument_fill.visible = progress < 1.0
	_monument_fill.anchor_top = 1.0 - progress
	if _monument_button.tooltip_text != tooltip:
		_monument_button.tooltip_text = tooltip

func _add_button(icon_name: String, tooltip: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	var icon_path := "res://icons/%s.svg" % icon_name
	if ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		# Si el SVG todavia no fue importado por el editor, al menos una letra.
		button.text = tooltip.left(1)
	_vbox.add_child(button)
	_buttons.append(button)
	return button

## Recalcula tamanos de botones, separacion y estilos en funcion del alto del
## viewport, para que la barra ocupe la misma fraccion de pantalla en cualquier
## resolucion.
func _update_layout() -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	var side := maxf(viewport_height * BUTTON_HEIGHT_RATIO, MIN_BUTTON_SIDE)
	var separation := side * 0.14
	# Si la columna no entra en pantalla (ventana muy baja), achicar todo.
	var total := side * _buttons.size() + separation * (_buttons.size() - 1)
	var max_total := viewport_height * 0.95
	if total > max_total:
		var factor := max_total / total
		side *= factor
		separation *= factor
		total = max_total

	_vbox.add_theme_constant_override("separation", roundi(separation))
	# Columna centrada verticalmente, pegada al borde izquierdo. Se posiciona
	# con offsets calculados a mano: el preset CENTER_LEFT centraria usando el
	# minimum size viejo del contenedor (los hijos cambian en esta misma pasada).
	_vbox.anchor_left = 0.0
	_vbox.anchor_right = 0.0
	_vbox.anchor_top = 0.5
	_vbox.anchor_bottom = 0.5
	_vbox.offset_left = side * 0.12
	_vbox.offset_right = side * 0.12 + side
	_vbox.offset_top = -total / 2.0
	_vbox.offset_bottom = total / 2.0

	for button in _buttons:
		button.custom_minimum_size = Vector2(side, side)
		button.add_theme_stylebox_override(
			"normal", _make_style(side, Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.12))
		)
		button.add_theme_stylebox_override(
			"hover", _make_style(side, Color(0.16, 0.16, 0.16, 0.55), Color(1, 1, 1, 0.25))
		)
		var pressed_style := _make_style(side, Color(0.12, 0.25, 0.12, 0.75), PRESSED_BORDER_COLOR)
		button.add_theme_stylebox_override("pressed", pressed_style)
		button.add_theme_stylebox_override("hover_pressed", pressed_style)

	# Esquinas inferiores del relleno a juego con el boton (arriba recto).
	var radius := roundi(side * 0.15)
	_monument_fill_style.corner_radius_bottom_left = radius
	_monument_fill_style.corner_radius_bottom_right = radius

func _make_style(side: float, bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(side * 0.035), 2))
	style.set_corner_radius_all(roundi(side * 0.15))
	style.set_content_margin_all(side * 0.17)
	return style
