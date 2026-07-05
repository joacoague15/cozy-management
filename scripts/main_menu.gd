extends CanvasLayer
## Menu inicial en tres pantallas sobre el juego ya corriendo (el mapa arranca
## sin tiles y sin UI de juego):
## 1) Portada: fondo a pantalla completa + logo + boton "Jugar".
## 2) Ciudades: el fondo se blurea y aparecen suave las tarjetas "Madrid" y
##    "Buenos Aires" (esta ultima bloqueada).
## 3) Mapas de Madrid: "Retiro" arranca la partida (tiles emergen animadas y
##    aparece la UI); los otros dos mapas estan bloqueados.

const FADE_SECONDS := 0.5
const BLUR_AMOUNT := 8.0
const IMAGE_CORNER_RADIUS := 20

@export var build_manager: Node3D
@export var toolbar: CanvasLayer
@export var question_button: CanvasLayer

var _root: Control
var _blur_material: ShaderMaterial
var _dim: ColorRect

var _start_screen: CenterContainer
var _maps_screen: CenterContainer
var _madrid_screen: CenterContainer

var _start_box: VBoxContainer
var _logo: TextureRect
var _jugar_button: Button

var _maps_box: HBoxContainer
var _madrid_frame: Panel
var _madrid_button: Button
var _bsas_frame: Panel
var _bsas_button: Button

var _madrid_box: VBoxContainer
var _retiro_button: Button
var _locked_buttons: Array[Button] = []

var _transitioning := false

func _ready() -> void:
	toolbar.visible = false
	# El boton de pregunta ya arranca oculto; se activa con begin() al empezar.

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fondo a pantalla completa; STOP bloquea clicks hacia el juego de abajo.
	var background := TextureRect.new()
	background.texture = load("res://main_background_image.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = load("res://shaders/menu_blur.gdshader")
	_blur_material.set_shader_parameter("blur_size", 0.0)
	background.material = _blur_material
	_root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Oscurece el fondo blureado para que las tarjetas y botones se lean bien.
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_start_screen()
	_build_maps_screen()
	_build_madrid_screen()

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## Pantalla 1: logo + "Jugar".
func _build_start_screen() -> void:
	_start_screen = _make_screen()
	_start_box = VBoxContainer.new()
	_start_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_start_screen.add_child(_start_box)

	_logo = TextureRect.new()
	_logo.texture = load("res://logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_start_box.add_child(_logo)

	_jugar_button = _make_button("Jugar", false)
	_jugar_button.pressed.connect(_on_jugar_pressed)
	_start_box.add_child(_jugar_button)

	_start_screen.visible = true

## Pantalla 2: tarjetas Madrid y Buenos Aires (bloqueada).
func _build_maps_screen() -> void:
	_maps_screen = _make_screen()
	_maps_box = HBoxContainer.new()
	_maps_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_maps_screen.add_child(_maps_box)

	var madrid := _make_card("res://madrid.jpeg", "Madrid", false)
	_madrid_frame = madrid["frame"]
	_madrid_button = madrid["button"]
	_madrid_button.pressed.connect(_on_madrid_pressed)
	_maps_box.add_child(madrid["card"])

	var bsas := _make_card("res://arg.jpeg", "Buenos Aires", true)
	_bsas_frame = bsas["frame"]
	_bsas_button = bsas["button"]
	_maps_box.add_child(bsas["card"])

## Pantalla 3: mapas de Madrid en vertical.
func _build_madrid_screen() -> void:
	_madrid_screen = _make_screen()
	_madrid_box = VBoxContainer.new()
	_madrid_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_madrid_screen.add_child(_madrid_box)

	_retiro_button = _make_button("Retiro", false)
	_retiro_button.pressed.connect(_on_retiro_pressed)
	_madrid_box.add_child(_retiro_button)

	for i in 2:
		var locked := _make_button("Mapa bloqueado", true)
		_locked_buttons.append(locked)
		_madrid_box.add_child(locked)

func _make_screen() -> CenterContainer:
	var screen := CenterContainer.new()
	screen.visible = false
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screen

func _make_button(text: String, disabled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_NONE
	return button

## Tarjeta de ciudad: imagen arriba (esquinas redondeadas) y boton abajo del
## mismo ancho. El Panel dibuja un rectangulo redondeado invisible que actua
## de mascara sobre la imagen via clip_children.
func _make_card(texture_path: String, label: String, disabled: bool) -> Dictionary:
	var card := VBoxContainer.new()
	var frame := Panel.new()
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.WHITE
	frame_style.set_corner_radius_all(IMAGE_CORNER_RADIUS)
	frame.add_theme_stylebox_override("panel", frame_style)
	var image := TextureRect.new()
	image.texture = load(texture_path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if disabled:
		# La ciudad bloqueada se ve apagada, en gris.
		image.modulate = Color(0.45, 0.45, 0.45)
	frame.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(frame)
	var button := _make_button(label, disabled)
	card.add_child(button)
	return {"card": card, "frame": frame, "button": button}

func _on_jugar_pressed() -> void:
	if _transitioning:
		return
	Sfx.play("select", 0.04)
	# El fondo se blurea y oscurece mientras la portada le deja el lugar,
	# de forma suave, a las tarjetas de ciudades.
	var blur_tween := create_tween().set_parallel()
	blur_tween.tween_property(
		_blur_material, "shader_parameter/blur_size", BLUR_AMOUNT, FADE_SECONDS * 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	blur_tween.tween_property(_dim, "color:a", 0.35, FADE_SECONDS * 2.0)
	_switch_screen(_start_screen, _maps_screen)

func _on_madrid_pressed() -> void:
	if _transitioning:
		return
	Sfx.play("select", 0.04)
	_switch_screen(_maps_screen, _madrid_screen)

func _on_retiro_pressed() -> void:
	if _transitioning:
		return
	Sfx.play("select", 0.04)
	build_manager.start_game()
	toolbar.visible = true
	question_button.begin()
	# El menu se desvanece y se libera: no vuelve en esta sesion.
	_retiro_button.disabled = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

## Fade out de una pantalla y fade in de la siguiente, en secuencia.
func _switch_screen(from: Control, to: Control) -> void:
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(from, "modulate:a", 0.0, FADE_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		from.visible = false
		to.modulate.a = 0.0
		to.visible = true
	)
	tween.tween_property(to, "modulate:a", 1.0, FADE_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _transitioning = false)

## Tamanos como fraccion del alto del viewport, igual que el resto de la UI.
func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var vw := get_viewport().get_visible_rect().size.x
	var button_width := maxf(vw * 0.3, 340.0)

	# Portada: logo grande y "Jugar" debajo.
	_start_box.add_theme_constant_override("separation", roundi(vh * 0.05))
	_logo.custom_minimum_size = Vector2(minf(vw * 0.55, vh * 1.0), vh * 0.32)
	_jugar_button.custom_minimum_size = Vector2(button_width, vh * 0.1)

	# Ciudades: dos tarjetas lado a lado.
	_maps_box.add_theme_constant_override("separation", roundi(vw * 0.04))
	var card_size := Vector2(minf(vw * 0.26, vh * 0.55), vh * 0.36)
	_madrid_frame.custom_minimum_size = card_size
	_bsas_frame.custom_minimum_size = card_size
	_madrid_button.custom_minimum_size = Vector2(0, vh * 0.09)
	_bsas_button.custom_minimum_size = Vector2(0, vh * 0.09)

	# Mapas de Madrid: tres opciones verticales.
	_madrid_box.add_theme_constant_override("separation", roundi(vh * 0.03))
	_retiro_button.custom_minimum_size = Vector2(button_width, vh * 0.1)
	for locked in _locked_buttons:
		locked.custom_minimum_size = Vector2(button_width, vh * 0.1)

	var buttons: Array[Button] = [_jugar_button, _madrid_button, _bsas_button, _retiro_button]
	buttons.append_array(_locked_buttons)
	for button in buttons:
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
		if button.disabled:
			button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))

func _make_style(vh: float, bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(vh * 0.004), 2))
	style.set_corner_radius_all(roundi(vh * 0.025))
	style.set_content_margin_all(vh * 0.02)
	return style
