extends CanvasLayer
## Ayuda de controles abajo a la derecha: el boton "?" aparece apenas comienza
## la partida (con un pop de escala) y enseguida se transforma en el
## recordatorio de controles, "Click izquierdo para construir" y debajo
## "Click derecho para eliminar". Clickearlo lo transforma al instante.
## Cuando se juntan los turistas del primer monumento, arriba del recordatorio
## aparece suave un tercer mensaje dorado: "Pon el primer monumento" (se va
## igual de suave al construirlo).

## Cuanto queda el "?" en pantalla antes de transformarse solo.
const TRANSFORM_DELAY := 1.2
const HINT_TEXT := "Click izquierdo para construir\nClick derecho para eliminar"
const MONUMENT_TEXT := "Pon el primer monumento"
const MONUMENT_BORDER_COLOR := Color(1.0, 0.85, 0.4, 0.55)
const MONUMENT_TEXT_COLOR := Color(1.0, 0.92, 0.7)

@export var build_manager: Node3D

var _button: Button
var _panel: PanelContainer
var _label: Label
var _monument_panel: PanelContainer
var _monument_label: Label
var _monument_shown := false
var _transformed := false
var _began := false

func _ready() -> void:
	# Arranca oculto: la pantalla de carga lo activa con begin() al empezar.
	visible = false

	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	if ResourceLoader.exists("res://icons/question.svg"):
		_button.icon = load("res://icons/question.svg")
		_button.expand_icon = true
		_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_button.text = "?"
	_button.pressed.connect(_transform_to_hints)
	add_child(_button)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_label = Label.new()
	_label.text = HINT_TEXT
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	add_child(_panel)

	_monument_panel = PanelContainer.new()
	_monument_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monument_panel.visible = false
	_monument_label = Label.new()
	_monument_label.text = MONUMENT_TEXT
	_monument_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_monument_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monument_panel.add_child(_monument_label)
	add_child(_monument_panel)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## Mensaje del monumento: aparece suave cuando el primero esta desbloqueado y
## sin construir, y se va suave al construirlo (o si se borra, vuelve).
func _process(_delta: float) -> void:
	if not _began:
		return
	var ready: bool = build_manager.is_historic_unlocked(1) \
			and not build_manager.is_historic_placed(1)
	if ready == _monument_shown:
		return
	_monument_shown = ready
	if ready:
		_show_monument_hint()
	else:
		_hide_monument_hint()

## Lo llama la pantalla de carga al arrancar la partida: el "?" hace su pop
## y poco despues se transforma en el recordatorio de controles.
func begin() -> void:
	visible = true
	_began = true
	_button.pivot_offset = _button.size / 2.0
	_button.scale = Vector2.ONE * 0.2
	var tween := _button.create_tween()
	tween.tween_property(_button, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(TRANSFORM_DELAY).timeout.connect(_transform_to_hints)

## El "?" se encoge y en su lugar crece el cartel con los controles, ambos
## desde la misma esquina para que se lea como una transformacion.
func _transform_to_hints() -> void:
	if _transformed:
		return
	_transformed = true
	_button.pivot_offset = _button.size / 2.0
	var shrink := _button.create_tween()
	shrink.tween_property(_button, "scale", Vector2.ONE * 0.2, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shrink.parallel().tween_property(_button, "modulate:a", 0.0, 0.25)
	shrink.tween_callback(func() -> void: _button.visible = false)

	_panel.visible = true
	_panel.reset_size()
	_update_layout()
	_panel.pivot_offset = _panel.size  # Crece desde la esquina inferior derecha.
	_panel.scale = Vector2.ONE * 0.2
	_panel.modulate.a = 0.0
	var grow := _panel.create_tween()
	grow.tween_interval(0.18)
	grow.tween_property(_panel, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(_panel, "modulate:a", 1.0, 0.3)

## Aparicion suave del mensaje del monumento: crece desde su esquina inferior
## derecha con un fade, igual que el recordatorio de controles.
func _show_monument_hint() -> void:
	_monument_panel.visible = true
	_monument_panel.reset_size()
	_update_layout()
	_monument_panel.pivot_offset = _monument_panel.size
	_monument_panel.scale = Vector2.ONE * 0.2
	_monument_panel.modulate.a = 0.0
	var tween := _monument_panel.create_tween()
	tween.tween_property(_monument_panel, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_monument_panel, "modulate:a", 1.0, 0.3)

func _hide_monument_hint() -> void:
	_monument_panel.pivot_offset = _monument_panel.size
	var tween := _monument_panel.create_tween()
	tween.tween_property(_monument_panel, "scale", Vector2.ONE * 0.2, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_monument_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _monument_panel.visible = false)

## Mismo criterio de tamano que la barra de construccion: fraccion del alto
## del viewport, anclado abajo a la derecha.
func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var vw := get_viewport().get_visible_rect().size.x
	var side := maxf(vh * 0.09, 56.0)
	_button.custom_minimum_size = Vector2(side, side)
	_button.size = Vector2(side, side)
	_button.position = Vector2(vw - side * 1.25, vh - side * 1.25)
	_button.add_theme_stylebox_override("normal", _make_style(side, Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.12), 0.5))
	_button.add_theme_stylebox_override(
		"hover", _make_style(side, Color(0.16, 0.16, 0.16, 0.55), Color(1, 1, 1, 0.25), 0.5)
	)
	_button.add_theme_stylebox_override(
		"pressed", _make_style(side, Color(0.12, 0.25, 0.12, 0.75), Color(0.65, 0.9, 0.6), 0.5)
	)

	_label.add_theme_font_size_override("font_size", roundi(vh * 0.024))
	_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	_panel.add_theme_stylebox_override(
		"panel", _make_style(side, Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.12), 0.18)
	)
	_panel.reset_size()
	_panel.position = Vector2(vw - _panel.size.x - side * 0.25, vh - _panel.size.y - side * 0.25)

	# Mensaje del monumento: mismo estilo pero en dorado, apilado justo arriba
	# del recordatorio de controles.
	_monument_label.add_theme_font_size_override("font_size", roundi(vh * 0.024))
	_monument_label.add_theme_color_override("font_color", MONUMENT_TEXT_COLOR)
	_monument_panel.add_theme_stylebox_override(
		"panel", _make_style(side, Color(0, 0, 0, 0.4), MONUMENT_BORDER_COLOR, 0.18)
	)
	_monument_panel.reset_size()
	_monument_panel.position = Vector2(
		vw - _monument_panel.size.x - side * 0.25,
		_panel.position.y - _monument_panel.size.y - side * 0.12
	)

func _make_style(side: float, bg: Color, border: Color, corner: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(side * 0.035), 2))
	style.set_corner_radius_all(roundi(side * corner))
	style.set_content_margin_all(side * 0.2)
	return style
