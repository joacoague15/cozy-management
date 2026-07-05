extends CanvasLayer
## Boton de pregunta abajo a la izquierda: aparece en momentos aleatorios de
## la partida (con un pop de escala). Al presionarlo desaparece (mas tarde
## puede volver a aparecer) y muestra un texto plano en 3D al costado de la
## zona jugable — nunca encima de ella — que se desvanece a los 10 segundos.

const APPEAR_MIN := 15.0
const APPEAR_MAX := 45.0
const MESSAGE := "esto es un ejemplo"
const MESSAGE_SECONDS := 10.0

@export var build_manager: Node3D

var _button: Button
var _appear_timer := 0.0

func _ready() -> void:
	_appear_timer = randf_range(APPEAR_MIN, APPEAR_MAX)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.visible = false
	if ResourceLoader.exists("res://icons/question.svg"):
		_button.icon = load("res://icons/question.svg")
		_button.expand_icon = true
		_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_button.text = "?"
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _process(delta: float) -> void:
	if _button.visible:
		return
	_appear_timer -= delta
	if _appear_timer <= 0.0:
		_show_button()

## Aparece con un pop suave para que se note sin ser invasivo.
func _show_button() -> void:
	_button.visible = true
	_button.pivot_offset = _button.size / 2.0
	_button.scale = Vector2.ONE * 0.2
	var tween := _button.create_tween()
	tween.tween_property(_button, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_pressed() -> void:
	Sfx.play("select", 0.04)
	_button.visible = false
	_appear_timer = randf_range(APPEAR_MIN, APPEAR_MAX)
	_show_message()

## Texto 3D al costado de la zona desbloqueada, del lado de la camara (+Z):
## siempre queda pegado al borde pero fuera de las tiles jugables.
func _show_message() -> void:
	var rect: Rect2i = build_manager.unlocked_rect()
	var label := Label3D.new()
	label.text = MESSAGE
	label.font = preload("res://fonts/cozy_font.tres")
	label.font_size = 72
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.97, 0.88)
	label.outline_modulate = Color(0.25, 0.17, 0.1)
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.6, rect.end.y + 1.0)
	get_tree().current_scene.add_child(label)

	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_interval(MESSAGE_SECONDS - 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

## Mismo criterio de tamano que la barra de construccion: fraccion del alto
## del viewport, anclado abajo a la izquierda.
func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var side := maxf(vh * 0.09, 56.0)
	_button.custom_minimum_size = Vector2(side, side)
	_button.size = Vector2(side, side)
	_button.position = Vector2(side * 0.25, vh - side * 1.25)

	var normal := _make_style(side, Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.12))
	_button.add_theme_stylebox_override("normal", normal)
	_button.add_theme_stylebox_override(
		"hover", _make_style(side, Color(0.16, 0.16, 0.16, 0.55), Color(1, 1, 1, 0.25))
	)
	_button.add_theme_stylebox_override(
		"pressed", _make_style(side, Color(0.12, 0.25, 0.12, 0.75), Color(0.65, 0.9, 0.6))
	)

func _make_style(side: float, bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(side * 0.035), 2))
	style.set_corner_radius_all(roundi(side * 0.5))
	style.set_content_margin_all(side * 0.2)
	return style
