extends CanvasLayer
## Personaje consejero abajo a la derecha: cuando se coloca el primer
## monumento, character.png asoma desde el borde inferior derecho junto a una
## burbuja de dialogo a su izquierda (papel calido semitransparente, titulo en
## negrita y texto oscuro) con las curiosidades del Retiro, a modo de
## instructivo. El consejo se desvanece solo y el personaje reaparece cada
## APPEAR_MIN-APPEAR_MAX segundos con el siguiente.

const APPEAR_MIN := 12.0
const APPEAR_MAX := 18.0
const MESSAGE_SECONDS := 10.0
## Relacion ancho/alto de character.png (446x1072).
const CHARACTER_ASPECT := 446.0 / 1072.0

## Titulo del primer consejo y de todos los siguientes.
const FIRST_TITLE := "¡Lo estás increíble!"
const NEXT_TITLE := "Sabías que..."

## Curiosidades del Retiro: se sortean sin repetir hasta agotar la lista
## (recien ahi se vuelve a barajar).
const MESSAGES: Array[String] = [
	"El Palacio de Cristal fue construida en el siglo XIX. Hoy alberga exposiciones de arte junto a un hermoso estanque.",
	"El Palacio de Velázquez fue diseñado por Ricardo Velázquez Bosco. Actualmente funciona como sala de exposiciones.",
	"La estatua del Ángel Caído es una de las pocas esculturas dedicadas a Lucifer y se encuentra a 666 metros sobre el nivel del mar.",
	"La Fuente de los Galápagos fue creada para celebrar el primer año de vida de la reina Isabel II. Está decorada con tortugas y delfines.",
]

@export var build_manager: Node3D

var _root: Control
var _character: TextureRect
var _bubble: Panel
var _title: Label
var _label: Label
var _appear_timer := 0.0
var _active := false
var _started := false
var _showing := false
var _tips_shown := 0
var _pending_messages: Array[String] = []
var _character_base := Vector2.ZERO

func _ready() -> void:
	# Arranca oculto e inactivo: el menu inicial lo activa con begin().
	visible = false

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_character = TextureRect.new()
	_character.texture = load("res://character.png")
	_character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_character.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character.modulate.a = 0.0
	_root.add_child(_character)

	_bubble = Panel.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate.a = 0.0
	_root.add_child(_bubble)

	_title = Label.new()
	_title.add_theme_font_override("font", load("res://fonts/ComicNeue-Bold.ttf"))
	_title.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05, 0.95))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_title)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05, 0.9))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_label)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## Lo llama el menu inicial al empezar la partida. El personaje recien se
## muestra cuando el jugador coloca el primer monumento.
func begin() -> void:
	visible = true
	_active = true

func _process(delta: float) -> void:
	if not _active or _showing:
		return
	if not _started:
		# El primer consejo sale junto con el primer monumento.
		if build_manager.is_historic_placed(1):
			_started = true
			_show_tip()
		return
	_appear_timer -= delta
	if _appear_timer <= 0.0:
		_show_tip()

## El personaje asoma desde el borde con un fade suave y la burbuja aparece
## apenas despues; todo se desvanece solo pasados MESSAGE_SECONDS.
func _show_tip() -> void:
	_showing = true
	if _pending_messages.is_empty():
		_pending_messages = MESSAGES.duplicate()
		_pending_messages.shuffle()
	_title.text = FIRST_TITLE if _tips_shown == 0 else NEXT_TITLE
	_label.text = _pending_messages.pop_back()
	_tips_shown += 1
	_layout_bubble()

	var slide := _character.size.y * 0.25
	_character.position = _character_base + Vector2(0, slide)
	var tween := create_tween()
	tween.tween_property(_character, "modulate:a", 1.0, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_character, "position:y", _character_base.y, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_bubble, "modulate:a", 1.0, 0.9).set_delay(0.35)
	tween.tween_interval(MESSAGE_SECONDS)
	tween.tween_property(_character, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_character, "position:y", _character_base.y + slide, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_bubble, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_tip_hidden)

func _on_tip_hidden() -> void:
	_showing = false
	_appear_timer = randf_range(APPEAR_MIN, APPEAR_MAX)

## Mismo criterio de tamano que el resto de la UI: fraccion del alto del
## viewport. Personaje pegado al borde inferior derecho; burbuja a su
## izquierda, apoyada abajo.
func _update_layout() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var vw := get_viewport().get_visible_rect().size.x

	var char_height := vh * 0.38
	var char_width := char_height * CHARACTER_ASPECT
	_character.size = Vector2(char_width, char_height)
	_character_base = Vector2(vw - char_width - vw * 0.005, vh - char_height)
	if not _showing:
		_character.position = _character_base

	_title.add_theme_font_size_override("font_size", roundi(vh * 0.03))
	_label.add_theme_font_size_override("font_size", roundi(vh * 0.026))
	_bubble.add_theme_stylebox_override("panel", _make_bubble_style(vh))
	_layout_bubble()

## La altura de la burbuja se ajusta al contenido: titulo de una linea mas el
## texto medido con la fuente al ancho disponible.
func _layout_bubble() -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var vw := get_viewport().get_visible_rect().size.x
	var margin := vh * 0.022
	var gap := vh * 0.008
	var bubble_width := vw * 0.3
	var inner_width := bubble_width - margin * 2.0

	var title_font := _title.get_theme_font("font")
	var title_font_size := roundi(vh * 0.03)
	var title_height := title_font.get_string_size(
		_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size
	).y
	var body_font := _label.get_theme_font("font")
	var body_font_size := roundi(vh * 0.026)
	var body_height := body_font.get_multiline_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, inner_width, body_font_size
	).y

	_title.position = Vector2(margin, margin)
	_title.size = Vector2(inner_width, title_height)
	_label.position = Vector2(margin, margin + title_height + gap)
	_label.size = Vector2(inner_width, body_height)
	_bubble.size = Vector2(bubble_width, margin * 2.0 + title_height + gap + body_height)
	_bubble.position = Vector2(
		_character_base.x - bubble_width - vw * 0.012,
		vh - _bubble.size.y - vh * 0.06
	)

## Fondo tipo papel calido semitransparente con esquinas redondeadas y una
## sombra suave, para que el texto se lea sobre el verde del terreno.
func _make_bubble_style(vh: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.92, 0.85)
	style.border_color = Color(0.35, 0.28, 0.18, 0.35)
	style.set_border_width_all(maxi(roundi(vh * 0.002), 1))
	style.set_corner_radius_all(roundi(vh * 0.02))
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = maxi(roundi(vh * 0.008), 4)
	return style
