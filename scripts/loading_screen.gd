extends CanvasLayer
## Pantalla de carga: fondo calido que tapa todo desde el primer frame
## mientras build_manager carga los modelos FBX en hilos de fondo. Muestra
## "Cargando" con puntos animados y un pulso suave. Dura siempre al menos
## MIN_SECONDS aunque la carga haya terminado antes, y recien despues se
## desvanece hacia el menu.

const MIN_SECONDS := 3.0
const FADE_SECONDS := 0.7
const BACKGROUND_COLOR := Color(0.11, 0.1, 0.085)

@export var build_manager: Node3D

var _root: Control
var _loading_label: Label
var _elapsed := 0.0
var _models_done := false
var _fading := false

func _ready() -> void:
	layer = 10  # Por encima del menu y de toda la UI del juego.
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP: bloquea el mouse hacia el menu que espera abajo.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_loading_label = Label.new()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_root.add_child(_loading_label)

	if build_manager.models_ready:
		_models_done = true
	else:
		build_manager.models_loaded.connect(func() -> void: _models_done = true)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _process(delta: float) -> void:
	_elapsed += delta
	# "Cargando" con respiracion suave y puntos que avanzan.
	_loading_label.modulate.a = 0.8 + 0.2 * sin(_elapsed * 2.2)
	_loading_label.text = "Cargando" + ".".repeat(1 + int(_elapsed * 2.5) % 3)

	if _models_done and _elapsed >= MIN_SECONDS and not _fading:
		_fading = true
		var tween := _root.create_tween()
		tween.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(queue_free)

func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	_loading_label.anchor_left = 0.0
	_loading_label.anchor_right = 1.0
	_loading_label.anchor_top = 0.48
	_loading_label.anchor_bottom = 0.48
	_loading_label.add_theme_font_size_override("font_size", roundi(vh * 0.038))
