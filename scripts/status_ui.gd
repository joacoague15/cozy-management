extends CanvasLayer
## Panel de estado arriba a la derecha: turistas totales y dos barras que
## muestran los factores de crecimiento de TouristManager. Barra baja =
## menos turistas nuevos (naturaleza faltante o tiles de casa sucias).

const NATURE_BAR_COLOR := Color(0.38, 0.72, 0.36)
const CLEAN_BAR_COLOR := Color(0.45, 0.75, 0.88)

@export var tourist_manager: Node3D
@export var build_manager: Node3D

var _tourists_label: Label
var _zone_label: Label
var _nature_bar: ProgressBar
var _clean_bar: ProgressBar

func _ready() -> void:
	_build_ui()

func _process(_delta: float) -> void:
	_tourists_label.text = "Turistas: %d" % tourist_manager.total_spawned
	var requirement: String = build_manager.next_zone_requirement()
	var side: int = build_manager.unlocked_side()
	if requirement == "":
		_zone_label.text = "Zona %dx%d completa" % [side, side]
	else:
		_zone_label.text = "Zona %dx%d — amplia: %s" % [side, side, requirement]
	_nature_bar.value = tourist_manager.nature_factor() * 100.0
	_clean_bar.value = tourist_manager.clean_factor() * 100.0

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_tourists_label = Label.new()
	_tourists_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_tourists_label)

	_zone_label = Label.new()
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zone_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_zone_label)

	_nature_bar = _add_bar_row(vbox, "Naturaleza", NATURE_BAR_COLOR)
	_clean_bar = _add_bar_row(vbox, "Limpieza", CLEAN_BAR_COLOR)

func _add_bar_row(parent: Control, text: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 80
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

	row.add_child(bar)
	return bar
