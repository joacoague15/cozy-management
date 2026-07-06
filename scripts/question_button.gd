extends CanvasLayer
## Ayuda de controles abajo a la derecha: el boton "?" aparece apenas comienza
## la partida (con un pop de escala) y enseguida se transforma en el
## recordatorio de controles, "Click izquierdo para construir" y debajo
## "Click derecho para eliminar". Clickearlo lo transforma al instante.

## Cuanto queda el "?" en pantalla antes de transformarse solo.
const TRANSFORM_DELAY := 1.2
const HINT_TEXT := "Click izquierdo para construir\nClick derecho para eliminar"

var _button: Button
var _panel: PanelContainer
var _label: Label
var _transformed := false

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
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	add_child(_panel)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## Lo llama la pantalla de carga al arrancar la partida: el "?" hace su pop
## y poco despues se transforma en el recordatorio de controles.
func begin() -> void:
	visible = true
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

func _make_style(side: float, bg: Color, border: Color, corner: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(side * 0.035), 2))
	style.set_corner_radius_all(roundi(side * corner))
	style.set_content_margin_all(side * 0.2)
	return style
