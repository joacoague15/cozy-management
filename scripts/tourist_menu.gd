extends CanvasLayer
## Menu de parametros. Se abre/cierra con F1.
## Edita en vivo los autoloads TouristConfig (turistas) y GameConfig
## (limpieza, naturaleza y construcciones historicas).

var _panel: PanelContainer
var _count_label: Label

func _ready() -> void:
	_build_ui()
	_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F1:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _panel.visible:
		_count_label.text = "Turistas en el mapa: %d" % get_tree().get_nodes_in_group("tourists").size()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 140)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Parametros (F1 para cerrar)"
	vbox.add_child(title)

	_count_label = Label.new()
	vbox.add_child(_count_label)

	_add_section(vbox, "Turistas")
	_add_range_row(vbox, "Velocidad (m/s)", "speed_min", "speed_max", 0.2, 10.0, 0.1)
	_add_range_row(vbox, "Pausa quieto (s)", "idle_min", "idle_max", 0.0, 30.0, 0.5)
	_add_range_row(vbox, "Caminata entre pausas (s)", "walk_min", "walk_max", 0.5, 30.0, 0.5)
	_add_range_row(vbox, "Estadia en el mapa (s)", "stay_min", "stay_max", 1.0, 300.0, 1.0)
	_add_single_row(vbox, "Spawn: segundos por turista", TouristConfig, "spawn_interval", 0.1, 10.0, 0.1)

	_add_section(vbox, "Basura y limpieza")
	_add_int_row(vbox, "Casas en un 3x3 para ensuciarlo", "dirt_house_threshold", 2, 9)
	_add_int_row(vbox, "Area purificada (NxN)", "clean_size", 1, 9)

	_add_section(vbox, "Naturaleza")
	_add_int_row(vbox, "Cada cuantas casas se exige", "nature_per_houses", 1, 20)
	_add_int_row(vbox, "Naturalezas por grupo de casas", "nature_amount", 1, 10)
	_add_int_row(vbox, "Tamano del tile (NxN)", "nature_size", 1, 5)

	_add_section(vbox, "Construcciones historicas")
	_add_int_row(vbox, "Palacio: tamano (NxN)", "historic_size", 3, 10)
	_add_single_row(vbox, "Estatua: tamano (tiles)", GameConfig, "statue_size", 0.5, 10.0, 0.1)
	_add_single_row(vbox, "Estatua: altura base (m)", GameConfig, "statue_offset_y", -2.0, 5.0, 0.1)
	_add_int_row(vbox, "Estatua (construirla abre 9x9): turistas", "historic_tourists_1", 1, 1000)
	_add_int_row(vbox, "Catedral (construirla abre 20x20): +turistas", "historic_tourists_2", 1, 1000)
	_add_int_row(vbox, "Palacio: +turistas", "historic_tourists_3", 1, 1000)

	var hint := Label.new()
	hint.text = "Velocidad y estadia se sortean al aparecer cada turista."
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

func _add_section(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = "--- " + text + " ---"
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)

## Fila con dos SpinBox (minimo y maximo) atados a propiedades de TouristConfig.
func _add_range_row(parent: Control, text: String, prop_min: String, prop_max: String,
		lo: float, hi: float, step: float) -> void:
	var row := _make_row(parent, text)
	row.add_child(_make_spinbox(TouristConfig, prop_min, lo, hi, step))
	var dash := Label.new()
	dash.text = "a"
	row.add_child(dash)
	row.add_child(_make_spinbox(TouristConfig, prop_max, lo, hi, step))

func _add_single_row(parent: Control, text: String, target: Object, prop: String,
		lo: float, hi: float, step: float) -> void:
	var row := _make_row(parent, text)
	row.add_child(_make_spinbox(target, prop, lo, hi, step))

## Fila con un SpinBox entero atado a una propiedad de GameConfig.
func _add_int_row(parent: Control, text: String, prop: String, lo: int, hi: int) -> void:
	var row := _make_row(parent, text)
	row.add_child(_make_spinbox(GameConfig, prop, lo, hi, 1.0, true))

func _make_row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 210
	row.add_child(label)
	return row

func _make_spinbox(target: Object, prop: String, lo: float, hi: float, step: float,
		as_int := false) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.value = target.get(prop)
	spin.value_changed.connect(func(value: float) -> void:
		target.set(prop, roundi(value) if as_int else value))
	return spin
