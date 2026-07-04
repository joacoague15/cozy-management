extends CanvasLayer
## Barra de construccion a la izquierda: botones con icono que equivalen a las
## teclas de build_manager.gd (casa 1x1, limpieza, naturaleza, monumento).
##
## Los botones de limpieza y naturaleza llevan un relleno vertical con el
## estado global del mapa (clean_factor / nature_factor de tourist_manager):
## se vacian suavemente cuando la limpieza o la naturaleza caen y se vuelven a
## llenar al construir lo que falta. Con deficit el relleno pulsa hacia rojo.
##
## El boton de monumento representa siempre la proxima historica sin construir
## (estatua -> catedral -> palacio). Mientras faltan turistas queda
## deshabilitado (no se puede presionar) y se va llenando de dorado; al
## desbloquearse hace un "pop", el relleno se desvanece y el borde pulsa
## dorado hasta que se construye.
##
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
const NORMAL_BORDER_COLOR := Color(1, 1, 1, 0.12)
const MONUMENT_FILL_COLOR := Color(0.95, 0.78, 0.35, 0.5)
const NATURE_FILL_COLOR := Color(0.38, 0.72, 0.36, 0.4)
const CLEAN_FILL_COLOR := Color(0.45, 0.75, 0.88, 0.4)
const WARNING_FILL_COLOR := Color(0.95, 0.35, 0.28, 0.55)
const READY_GLOW_COLOR := Color(1.0, 0.85, 0.4)
## Velocidad del suavizado exponencial de los rellenos (mayor = mas rapido).
const FILL_SMOOTH_SPEED := 5.0

@export var build_manager: Node3D
@export var tourist_manager: Node3D

var _vbox: VBoxContainer
var _buttons: Array[Button] = []
var _house_button: Button
var _cleaner_button: Button
var _nature_button: Button
var _monument_button: Button
## Rellenos verticales: Dictionary {panel, style, base_color, shown}.
var _clean_fill: Dictionary
var _nature_fill: Dictionary
var _monument_fill: Dictionary
var _monument_normal_style: StyleBoxFlat
var _monument_variant := 1
var _monument_was_ready := false

func _ready() -> void:
	_vbox = VBoxContainer.new()
	add_child(_vbox)

	_house_button = _add_button("house", "Casa 1x1  [1]")
	_cleaner_button = _add_button("recycle", "Limpieza  [4]")
	_nature_button = _add_button("leaf", "Naturaleza  [5]")
	_monument_button = _add_button("monument", "Monumento")

	_clean_fill = _make_fill(_cleaner_button, CLEAN_FILL_COLOR)
	_nature_fill = _make_fill(_nature_button, NATURE_FILL_COLOR)
	_monument_fill = _make_fill(_monument_button, MONUMENT_FILL_COLOR)

	# El icono se atenua solo cuando el boton esta deshabilitado (el relleno
	# dorado queda a brillo completo, bien legible).
	_monument_button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))

	_house_button.toggled.connect(_on_button_toggled.bind(BuildManager.TYPE_HOUSE, 1))
	_cleaner_button.toggled.connect(_on_button_toggled.bind(BuildManager.TYPE_CLEANER, 0))
	_nature_button.toggled.connect(_on_button_toggled.bind(BuildManager.TYPE_NATURE, 0))
	_monument_button.toggled.connect(_on_monument_toggled)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## El estado (seleccion, historica que toca, desbloqueos, rellenos) se sondea
## por frame, igual que hace build_manager con su info label.
func _process(delta: float) -> void:
	_monument_variant = build_manager.next_historic_variant()
	var type: String = build_manager.selected_type()
	var variant: int = build_manager.selected_variant()
	_house_button.set_pressed_no_signal(type == BuildManager.TYPE_HOUSE and variant == 1)
	_cleaner_button.set_pressed_no_signal(type == BuildManager.TYPE_CLEANER)
	_nature_button.set_pressed_no_signal(type == BuildManager.TYPE_NATURE)
	_monument_button.set_pressed_no_signal(
		type == BuildManager.TYPE_HISTORIC and variant == _monument_variant
	)

	# Parpadeo compartido por alertas y por el brillo de "monumento listo"
	# (~1 ciclo por segundo).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	var clean: float = tourist_manager.clean_factor()
	var nature: float = tourist_manager.nature_factor()
	_update_fill(_clean_fill, clean, delta, pulse, clean < 1.0)
	_update_fill(_nature_fill, nature, delta, pulse, nature < 1.0)
	_update_monument_state(delta, pulse)

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

## Estado del boton de monumento segun la historica que representa:
## - Bloqueado (faltan turistas): deshabilitado, relleno dorado de progreso.
## - Listo: habilitado, pop de escala una vez y borde dorado pulsante.
## - Construida: deshabilitado y atenuado (pasa a representar la siguiente).
func _update_monument_state(delta: float, pulse: float) -> void:
	var monument_name: String = BuildManager.HISTORIC_NAMES[_monument_variant]
	var tooltip := "%s  [%d]" % [monument_name, 5 + _monument_variant]
	var placed: bool = build_manager.is_historic_placed(_monument_variant)
	var unlocked: bool = build_manager.is_historic_unlocked(_monument_variant)
	var progress := 0.0 if placed else 1.0
	if placed:
		tooltip += " — construida"
	elif not unlocked:
		var threshold: int = build_manager.historic_threshold(_monument_variant)
		var tourists: int = build_manager.total_tourists()
		tooltip += " — faltan turistas (%d/%d)" % [tourists, threshold]
		progress = clampf(float(tourists) / threshold, 0.0, 1.0)
	var ready := unlocked and not placed

	_monument_button.disabled = not ready

	# El relleno sube suavemente con los turistas; al desbloquearse termina de
	# llenarse y se desvanece (el brillo del borde toma la posta).
	_update_fill(_monument_fill, progress, delta, pulse, false)
	var panel: Panel = _monument_fill.panel
	var alpha_target := 0.0 if ready else 1.0
	panel.modulate.a = lerpf(panel.modulate.a, alpha_target, 1.0 - exp(-FILL_SMOOTH_SPEED * delta))

	if _monument_normal_style != null:
		if ready:
			var glow := READY_GLOW_COLOR
			glow.a = 0.35 + 0.65 * pulse
			_monument_normal_style.border_color = glow
		else:
			_monument_normal_style.border_color = NORMAL_BORDER_COLOR

	if ready and not _monument_was_ready:
		_pop_monument()
	_monument_was_ready = ready

	if _monument_button.tooltip_text != tooltip:
		_monument_button.tooltip_text = tooltip

## Pop de escala al pasar de bloqueado a listo: "ya lo podes construir".
func _pop_monument() -> void:
	_monument_button.pivot_offset = _monument_button.size / 2.0
	var tween := _monument_button.create_tween()
	tween.tween_property(_monument_button, "scale", Vector2.ONE * 1.15, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_monument_button, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Relleno vertical dentro de un boton: un panel translucido anclado abajo con
## una linea de "superficie" arriba, que sube y baja con _update_fill.
func _make_fill(button: Button, color: Color) -> Dictionary:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	button.add_child(panel)
	return {panel = panel, style = style, base_color = color, shown = -1.0}

## Acerca el nivel mostrado al objetivo con suavizado exponencial (mismo ritmo
## a cualquier framerate) y pinta el deficit pulsando hacia rojo.
func _update_fill(fill: Dictionary, target: float, delta: float, pulse: float, warning: bool) -> void:
	var shown: float = fill.shown
	if shown < 0.0:
		shown = target  # Primer frame: arrancar en el valor real, sin animar.
	else:
		shown = lerpf(shown, target, 1.0 - exp(-FILL_SMOOTH_SPEED * delta))
		if absf(shown - target) < 0.002:
			shown = target
	fill.shown = shown

	var panel: Panel = fill.panel
	panel.anchor_top = 1.0 - shown
	panel.visible = shown > 0.003

	var style: StyleBoxFlat = fill.style
	# Cuando el nivel entra en la zona curva del boton, las esquinas superiores
	# del relleno se curvan en proporcion: lleno calza exacto con el boton.
	var radius: int = fill.get("radius", 0)
	var side: float = fill.get("side", 0.0)
	if radius > 0 and side > 0.0:
		var corner_frac := radius / side
		var t := clampf((shown - (1.0 - corner_frac)) / corner_frac, 0.0, 1.0)
		var top_radius := roundi(radius * t)
		style.corner_radius_top_left = top_radius
		style.corner_radius_top_right = top_radius
	var base: Color = fill.base_color
	var bg := base.lerp(WARNING_FILL_COLOR, 0.35 + 0.5 * pulse) if warning else base
	style.bg_color = bg
	var edge := bg.lightened(0.3)
	edge.a = minf(bg.a * 2.0, 0.9)
	style.border_color = edge

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
		var normal_style := _make_style(side, Color(0, 0, 0, 0.4), NORMAL_BORDER_COLOR)
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override(
			"hover", _make_style(side, Color(0.16, 0.16, 0.16, 0.55), Color(1, 1, 1, 0.25))
		)
		var pressed_style := _make_style(side, Color(0.12, 0.25, 0.12, 0.75), PRESSED_BORDER_COLOR)
		button.add_theme_stylebox_override("pressed", pressed_style)
		button.add_theme_stylebox_override("hover_pressed", pressed_style)
		button.add_theme_stylebox_override(
			"disabled", _make_style(side, Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.05))
		)
		if button == _monument_button:
			# Referencia viva para pulsar el borde dorado cuando esta listo.
			_monument_normal_style = normal_style

	# Esquinas inferiores de los rellenos a juego con el boton (arriba, una
	# linea clara que marca la "superficie" del liquido). El radio y el lado se
	# guardan en cada relleno: _update_fill curva las esquinas superiores cuando
	# el nivel llega arriba, para que lleno calce exacto con el boton.
	var radius := roundi(side * 0.15)
	for fill in [_clean_fill, _nature_fill, _monument_fill]:
		var style: StyleBoxFlat = fill.style
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		style.border_width_top = maxi(roundi(side * 0.02), 2)
		fill.radius = radius
		fill.side = side

func _make_style(side: float, bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(side * 0.035), 2))
	style.set_corner_radius_all(roundi(side * 0.15))
	style.set_content_margin_all(side * 0.17)
	return style
