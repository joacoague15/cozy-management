extends CanvasLayer
## Menu inicial minimalista sobre el juego ya corriendo: el mapa arranca sin
## tiles y sin UI de juego (barra de construccion y boton de pregunta ocultos).
## Dos botones centrados: "Madrid" arranca la partida (las 9 tiles emergen
## animadas y aparece la UI) y "Buenos Aires" es un coming soon deshabilitado.

@export var build_manager: Node3D
@export var toolbar: CanvasLayer
@export var question_button: CanvasLayer

var _root: Control
var _vbox: VBoxContainer
var _madrid_button: Button
var _bsas_button: Button

func _ready() -> void:
	toolbar.visible = false
	# El boton de pregunta ya arranca oculto; se activa con begin() al empezar.

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_vbox)

	_madrid_button = _add_button("Madrid", false)
	_madrid_button.pressed.connect(_on_madrid_pressed)
	_bsas_button = _add_button("Buenos Aires — coming soon", true)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _add_button(text: String, disabled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_NONE
	_vbox.add_child(button)
	return button

func _on_madrid_pressed() -> void:
	Sfx.play("select", 0.04)
	build_manager.start_game()
	toolbar.visible = true
	question_button.begin()
	# El menu se desvanece y se libera: no vuelve en esta sesion.
	_madrid_button.disabled = true
	var tween := _root.create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

## Tamanos como fraccion del alto del viewport, igual que el resto de la UI.
func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var vw := get_viewport().get_visible_rect().size.x
	var width := maxf(vw * 0.3, 340.0)
	_vbox.add_theme_constant_override("separation", roundi(vh * 0.03))
	_vbox.anchor_left = 0.5
	_vbox.anchor_right = 0.5
	_vbox.anchor_top = 0.5
	_vbox.anchor_bottom = 0.5
	_vbox.offset_left = -width / 2.0
	_vbox.offset_right = width / 2.0
	_vbox.offset_top = -vh * 0.14
	_vbox.offset_bottom = vh * 0.14

	for button in [_madrid_button, _bsas_button]:
		button.custom_minimum_size = Vector2(0, vh * 0.1)
		button.add_theme_font_size_override("font_size", roundi(vh * 0.036))
		button.add_theme_stylebox_override(
			"normal", _make_style(vh, Color(0.0, 0.0, 0.0, 0.45), Color(1, 1, 1, 0.15))
		)
		button.add_theme_stylebox_override(
			"hover", _make_style(vh, Color(0.16, 0.16, 0.16, 0.6), Color(1, 1, 1, 0.3))
		)
		button.add_theme_stylebox_override(
			"pressed", _make_style(vh, Color(0.12, 0.25, 0.12, 0.8), Color(0.65, 0.9, 0.6))
		)
		button.add_theme_stylebox_override(
			"disabled", _make_style(vh, Color(0.0, 0.0, 0.0, 0.3), Color(1, 1, 1, 0.06))
		)
	_bsas_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))

func _make_style(vh: float, bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(vh * 0.004), 2))
	style.set_corner_radius_all(roundi(vh * 0.025))
	style.set_content_margin_all(vh * 0.02)
	return style
