extends Node
## Cel shading global y automatico: cada MeshInstance3D que entra al arbol
## recibe la version toon de sus materiales (bandas duras + contorno de tinta)
## sin tocar el codigo que los crea. Los materiales compartidos se convierten
## una sola vez (cache por material original), asi el batching se conserva.
##
## F1 abre un menu con sliders para ajustar los efectos graficos en vivo:
## los cambios se propagan a todos los materiales convertidos, al contorno,
## al terreno y al entorno. Los valores duran la sesion; para hacerlos
## permanentes hay que copiarlos a los defaults de los shaders / main.tscn.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/toon_outline.gdshader")

## Defaults de los uniforms de toon.gdshader que expone el menu (band_mix
## tambien existe en el shader del terreno y se actualiza a la par).
const TOON_DEFAULTS := {
	saturation_boost = 1.15,
	posterize_levels = 8.0,
	posterize_mix = 0.35,
	specular_strength = 0.25,
	rim_strength = 0.18,
	band_mix = 1.0,
}
const OUTLINE_WIDTH_DEFAULT := 1.0
const ENV_SATURATION_DEFAULT := 1.15
const ENV_CONTRAST_DEFAULT := 1.06

## Material original -> ShaderMaterial toon equivalente.
var _cache: Dictionary = {}
var _outline: ShaderMaterial
## Valores vivos de los uniforms toon (se aplican tambien a conversiones nuevas).
var _toon_params: Dictionary = TOON_DEFAULTS.duplicate()

var _panel: PanelContainer
var _sliders: Array[HSlider] = []
## Referencias para reescalar el menu segun la altura del viewport.
var _menu_theme: Theme
var _menu_margin: MarginContainer
var _title: Label
var _headers: Array[Label] = []
var _row_labels: Array[Label] = []
var _value_labels: Array[Label] = []

func _ready() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	get_tree().node_added.connect(_on_node_added)
	_build_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F1:
		toggle_menu()
		get_viewport().set_input_as_handled()

# --- Conversion de materiales --------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		# Diferido: le da tiempo al codigo que crea el nodo a terminar de
		# asignarle malla y materiales dentro del mismo frame.
		_convert.call_deferred(node)

func _convert(mesh_instance: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_instance) or not mesh_instance.is_inside_tree():
		return
	if mesh_instance.material_override != null:
		mesh_instance.material_override = _toonify(mesh_instance.material_override)
		return
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var source: Material = mesh_instance.get_surface_override_material(s)
		if source == null:
			source = mesh.surface_get_material(s)
		var toon := _toonify(source)
		if toon != source:
			mesh_instance.set_surface_override_material(s, toon)

## Version toon de un StandardMaterial3D, copiando lo que el juego usa de el:
## color, textura (UV o triplanar en mundo) y colores de vertice. Los
## materiales unshaded o transparentes (fantasmas de construccion, resaltados,
## turistas grises) cambian de color en vivo y se dejan como estan; los
## ShaderMaterial (terreno) ya manejan su propio estilo.
func _toonify(material: Material) -> Material:
	if not material is BaseMaterial3D:
		return material
	var source := material as BaseMaterial3D
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return material
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return material
	if _cache.has(material):
		return _cache[material]
	var toon := ShaderMaterial.new()
	toon.shader = TOON_SHADER
	toon.set_shader_parameter("albedo_color", source.albedo_color)
	toon.set_shader_parameter("albedo_texture", source.albedo_texture)
	toon.set_shader_parameter("use_vertex_color", source.vertex_color_use_as_albedo)
	toon.set_shader_parameter("triplanar", source.uv1_triplanar)
	toon.set_shader_parameter("uv1_scale", source.uv1_scale)
	for key in _toon_params:
		toon.set_shader_parameter(key, _toon_params[key])
	toon.next_pass = _outline
	_cache[material] = toon
	return toon

# --- Aplicacion en vivo de parametros ------------------------------------------

func _set_toon_param(key: String, value: float) -> void:
	_toon_params[key] = value
	for toon in _cache.values():
		toon.set_shader_parameter(key, value)
	if key == "band_mix":
		var terrain := _terrain_material()
		if terrain != null:
			terrain.set_shader_parameter("band_mix", value)

func _set_env_param(property: String, value: float) -> void:
	var environment := _environment()
	if environment != null:
		environment.set(property, value)

func _terrain_material() -> ShaderMaterial:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var terrain: GeometryInstance3D = scene.get_node_or_null("Terrain")
	return terrain.material_override as ShaderMaterial if terrain != null else null

func _environment() -> Environment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var world_env: WorldEnvironment = scene.get_node_or_null("WorldEnvironment")
	return world_env.environment if world_env != null else null

# --- Menu F1 --------------------------------------------------------------------

func toggle_menu() -> void:
	_panel.visible = not _panel.visible

func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5  # Sobre la UI del juego, debajo de la pantalla de carga.
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.visible = false
	_menu_theme = Theme.new()
	_panel.theme = _menu_theme
	layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	_menu_margin = MarginContainer.new()
	_panel.add_child(_menu_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_menu_margin.add_child(vbox)

	_title = Label.new()
	_title.text = "Efectos graficos (F1)"
	vbox.add_child(_title)

	_add_header(vbox, "Modelos")
	_add_slider(vbox, "Saturacion", 0.5, 2.0, 0.05, TOON_DEFAULTS.saturation_boost,
			func(v: float) -> void: _set_toon_param("saturation_boost", v))
	_add_slider(vbox, "Posterizado: niveles", 2.0, 16.0, 1.0, TOON_DEFAULTS.posterize_levels,
			func(v: float) -> void: _set_toon_param("posterize_levels", v))
	_add_slider(vbox, "Posterizado: mezcla", 0.0, 1.0, 0.05, TOON_DEFAULTS.posterize_mix,
			func(v: float) -> void: _set_toon_param("posterize_mix", v))
	_add_slider(vbox, "Brillo especular", 0.0, 1.0, 0.05, TOON_DEFAULTS.specular_strength,
			func(v: float) -> void: _set_toon_param("specular_strength", v))
	_add_slider(vbox, "Luz de borde (rim)", 0.0, 1.0, 0.05, TOON_DEFAULTS.rim_strength,
			func(v: float) -> void: _set_toon_param("rim_strength", v))

	_add_header(vbox, "Estilo")
	_add_slider(vbox, "Dureza de bandas", 0.0, 1.0, 0.05, TOON_DEFAULTS.band_mix,
			func(v: float) -> void: _set_toon_param("band_mix", v))
	_add_slider(vbox, "Grosor de contorno", 0.0, 10.0, 0.5, OUTLINE_WIDTH_DEFAULT,
			func(v: float) -> void: _outline.set_shader_parameter("outline_width", v))

	_add_header(vbox, "Entorno")
	_add_slider(vbox, "Saturacion global", 0.5, 1.6, 0.05, ENV_SATURATION_DEFAULT,
			func(v: float) -> void: _set_env_param("adjustment_saturation", v))
	_add_slider(vbox, "Contraste", 0.8, 1.3, 0.02, ENV_CONTRAST_DEFAULT,
			func(v: float) -> void: _set_env_param("adjustment_contrast", v))

	var reset := Button.new()
	reset.text = "Restaurar valores"
	reset.pressed.connect(_reset_values)
	vbox.add_child(reset)

	get_viewport().size_changed.connect(_apply_menu_scale)
	_apply_menu_scale()

## El menu se dibuja en pixeles fisicos: en pantallas grandes (fullscreen
## retina) los tamanos base quedan ilegibles, asi que todo escala con la
## altura del viewport (base: 900 px de alto = escala 1).
func _apply_menu_scale() -> void:
	var s := clampf(get_viewport().get_visible_rect().size.y / 900.0, 1.0, 3.5)
	_menu_theme.default_font_size = roundi(15.0 * s)
	_title.add_theme_font_size_override("font_size", roundi(17.0 * s))
	for margin_name in ["margin_left", "margin_right"]:
		_menu_margin.add_theme_constant_override(margin_name, roundi(14.0 * s))
	for margin_name in ["margin_top", "margin_bottom"]:
		_menu_margin.add_theme_constant_override(margin_name, roundi(10.0 * s))
	for header in _headers:
		header.add_theme_font_size_override("font_size", roundi(11.0 * s))
	for label in _row_labels:
		label.custom_minimum_size.x = 185.0 * s
	for slider in _sliders:
		slider.custom_minimum_size = Vector2(150.0 * s, 22.0 * s)
	for value_label in _value_labels:
		value_label.custom_minimum_size.x = 48.0 * s

func _add_header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1.0, 1.0, 1.0, 0.65)
	parent.add_child(label)
	_headers.append(label)

## Fila con nombre, slider y valor numerico. El slider arranca en el default y
## aplica el cambio en vivo via `apply`.
func _add_slider(parent: Control, text: String, lo: float, hi: float, step: float,
		default_value: float, apply: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	row.add_child(label)
	_row_labels.append(label)

	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.size_flags_vertical = Control.SIZE_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_value_labels.append(value_label)

	var fmt := func(v: float) -> String:
		return str(int(v)) if step >= 1.0 else "%.2f" % v
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = fmt.call(v)
		apply.call(v))
	slider.set_meta("default", default_value)
	slider.value = default_value
	value_label.text = fmt.call(default_value)
	_sliders.append(slider)

func _reset_values() -> void:
	for slider in _sliders:
		slider.value = slider.get_meta("default")
