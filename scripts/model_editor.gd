class_name ModelEditor
extends Node3D
## Editor in-game de modelos 3D: carga archivos FBX / GLB / GLTF en runtime
## (con F2 o arrastrando el archivo a la ventana del juego), los apoya sobre
## el terreno y permite moverlos (arrastrar), rotarlos (Q/E) y escalarlos
## (Ctrl+rueda o el panel). Ver MODELOS.md.

const SUPPORTED_EXTENSIONS: Array[String] = ["fbx", "glb", "gltf"]
## Lado inicial (en tiles) al que se autoescala el footprint del modelo.
const DEFAULT_SIZE_TILES := 2.0
const SCALE_WHEEL_FACTOR := 1.1
const ROTATE_STEP_DEG := 15.0
const PLACING_TRANSPARENCY := 0.5
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2, 0.2)
const STATUS_SECONDS := 4.0

enum Mode { NONE, PLACING, SELECTED }

@export var build_manager: Node3D

var _mode := Mode.NONE
var _active: Node3D
var _dragging := false

var _models: Node3D
var _dialog: FileDialog
var _panel: PanelContainer
var _name_label: Label
var _size_spin: SpinBox
var _rotation_spin: SpinBox
var _status_label: Label
var _status_timer: Timer

func _ready() -> void:
	_models = Node3D.new()
	_models.name = "Models"
	add_child(_models)
	_build_dialog()
	_build_ui()
	get_window().files_dropped.connect(_on_files_dropped)

func _process(_delta: float) -> void:
	if _active != null and (_mode == Mode.PLACING or _dragging):
		var ground: Variant = build_manager.mouse_to_ground()
		if ground != null:
			_move_active_to(ground)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F2:
				_dialog.popup_centered(Vector2i(800, 500))
				get_viewport().set_input_as_handled()
			KEY_Q:
				if _active != null:
					_rotate_active(ROTATE_STEP_DEG)
					get_viewport().set_input_as_handled()
			KEY_E:
				if _active != null:
					_rotate_active(-ROTATE_STEP_DEG)
					get_viewport().set_input_as_handled()
			KEY_DELETE:
				if _mode == Mode.SELECTED:
					_delete_active()
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _mode == Mode.PLACING:
			_confirm_placement()
			get_viewport().set_input_as_handled()
		elif not build_manager.has_selection():
			var picked := _pick_model(event.position)
			if picked != null:
				_select_model(picked)
				_dragging = true
				get_viewport().set_input_as_handled()
			elif _mode == Mode.SELECTED:
				_deselect()
				get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _mode == Mode.PLACING:
			_active.queue_free()
			_deselect()
			get_viewport().set_input_as_handled()
		elif _mode == Mode.SELECTED:
			_deselect()
			get_viewport().set_input_as_handled()
	elif _active != null and event.pressed and event.ctrl_pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var factor := SCALE_WHEEL_FACTOR if event.button_index == MOUSE_BUTTON_WHEEL_UP \
				else 1.0 / SCALE_WHEEL_FACTOR
		_set_active_size_tiles(_get_active_size_tiles() * factor)
		get_viewport().set_input_as_handled()

# --- Carga de modelos --------------------------------------------------------

## Carga un modelo desde el disco. Devuelve "" si salio bien o el mensaje de
## error. El modelo queda activo en el modo indicado.
func load_model(path: String, mode: Mode = Mode.PLACING) -> String:
	var ext := path.get_extension().to_lower()
	if ext not in SUPPORTED_EXTENSIONS:
		return "Formato no soportado: .%s (usa FBX, GLB o GLTF)" % ext
	var doc: GLTFDocument
	var state: GLTFState
	if ext == "fbx":
		doc = FBXDocument.new()
		state = FBXState.new()
	else:
		doc = GLTFDocument.new()
		state = GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		return "No se pudo leer %s (%s)" % [path.get_file(), error_string(err)]
	var scene := doc.generate_scene(state)
	if scene == null:
		return "No se pudo generar la escena de %s" % path.get_file()
	_strip_non_visual_nodes(scene)
	_enable_vertex_colors(scene)
	var aabb := _combined_aabb(scene, Transform3D.IDENTITY)
	if aabb.size.length() < 0.0001:
		scene.free()
		return "%s no tiene mallas visibles" % path.get_file()

	# Contenedor con el pivote en el centro de la base del modelo, apoyado
	# en y=0, autoescalado a DEFAULT_SIZE_TILES tiles de footprint.
	var container := Node3D.new()
	var center := aabb.get_center()
	scene.position = -Vector3(center.x, aabb.position.y, center.z)
	container.add_child(scene)
	container.add_child(_make_highlight(aabb.size))
	var fit := 1.0 / maxf(maxf(aabb.size.x, aabb.size.z), 0.001)
	container.set_meta("fit_scale", fit)
	container.set_meta("aabb_size", aabb.size)
	container.set_meta("source_file", path.get_file())
	container.scale = Vector3.ONE * fit * DEFAULT_SIZE_TILES
	container.position = Vector3(build_manager.GRID_SIZE * 0.5, 0.0, build_manager.GRID_SIZE * 0.5)
	_models.add_child(container)

	_active = container
	_mode = mode
	_set_transparency(container, PLACING_TRANSPARENCY if mode == Mode.PLACING else 0.0)
	_highlight_of(container).visible = mode == Mode.SELECTED
	_refresh_panel()
	_show_status("Modelo cargado: " + path.get_file())
	return ""

## Camaras, luces y settings de render que vienen dentro del archivo pisarian
## la camara e iluminacion del juego: se eliminan, quedan solo las mallas.
static func _strip_non_visual_nodes(node: Node) -> void:
	for child in node.get_children():
		_strip_non_visual_nodes(child)
	if node is Camera3D or node is Light3D or node is AnimationPlayer:
		node.get_parent().remove_child(node)
		node.free()

## Los modelos low-poly suelen pintar con colores de vertice que el material
## importado no usa por defecto.
static func _enable_vertex_colors(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var material := mesh.surface_get_material(s)
			if arrays[Mesh.ARRAY_COLOR] != null and material is BaseMaterial3D:
				material.vertex_color_use_as_albedo = true
	for child in node.get_children():
		_enable_vertex_colors(child)

## AABB combinada de todas las mallas, acumulando transforms de la jerarquia.
static func _combined_aabb(node: Node, parent_transform: Transform3D) -> AABB:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	var result := AABB()
	var has_result := false
	if node is MeshInstance3D and node.mesh != null:
		result = transform * (node as MeshInstance3D).get_aabb()
		has_result = true
	for child in node.get_children():
		var child_aabb := _combined_aabb(child, transform)
		if child_aabb.size.length() > 0.0001 or child_aabb.position != Vector3.ZERO:
			result = result.merge(child_aabb) if has_result else child_aabb
			has_result = true
	return result

func _make_highlight(size: Vector3) -> MeshInstance3D:
	var highlight := MeshInstance3D.new()
	highlight.name = "Highlight"
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = HIGHLIGHT_COLOR
	box.material = material
	highlight.mesh = box
	highlight.position.y = size.y * 0.5
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.visible = false
	return highlight

# --- Seleccion y edicion ------------------------------------------------------

func _confirm_placement() -> void:
	_set_transparency(_active, 0.0)
	_select_model(_active)

func _select_model(model: Node3D) -> void:
	if _active != null and _active != model:
		_highlight_of(_active).visible = false
	_active = model
	_mode = Mode.SELECTED
	_highlight_of(model).visible = true
	_refresh_panel()

func _deselect() -> void:
	if _active != null and _mode == Mode.SELECTED:
		_highlight_of(_active).visible = false
	_active = null
	_mode = Mode.NONE
	_dragging = false
	_panel.visible = false

func _delete_active() -> void:
	_active.queue_free()
	_deselect()

func _move_active_to(ground: Vector3) -> void:
	var grid := float(build_manager.GRID_SIZE)
	_active.position = Vector3(clampf(ground.x, 0.0, grid), 0.0, clampf(ground.z, 0.0, grid))

func _rotate_active(degrees: float) -> void:
	_active.rotation_degrees.y = wrapf(_active.rotation_degrees.y + degrees, 0.0, 360.0)
	_refresh_panel()

## El tamano visible del modelo se maneja en tiles de footprint (lado mayor).
func _get_active_size_tiles() -> float:
	return _active.scale.x / _active.get_meta("fit_scale")

func _set_active_size_tiles(tiles: float) -> void:
	tiles = clampf(tiles, 0.1, 40.0)
	_active.scale = Vector3.ONE * _active.get_meta("fit_scale") * tiles
	_refresh_panel()

func _highlight_of(model: Node3D) -> MeshInstance3D:
	return model.get_node("Highlight")

func _set_transparency(model: Node3D, value: float) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if node.name != "Highlight":
			node.transparency = value

## Busca el modelo bajo el cursor intersectando el rayo de la camara con la
## caja (AABB) de cada modelo. Devuelve el mas cercano o null.
func _pick_model(mouse: Vector2) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var best: Node3D = null
	var best_distance := INF
	for model in _models.get_children():
		if model.is_queued_for_deletion():
			continue
		var size: Vector3 = model.get_meta("aabb_size")
		var box := AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)
		var inverse: Transform3D = model.global_transform.affine_inverse()
		var hit: Variant = box.intersects_ray(inverse * from, (inverse.basis * direction).normalized())
		if hit == null:
			continue
		var distance := from.distance_squared_to(model.global_transform * (hit as Vector3))
		if distance < best_distance:
			best_distance = distance
			best = model
	return best

# --- Entrada de archivos ------------------------------------------------------

func _on_files_dropped(files: PackedStringArray) -> void:
	for file in files:
		if file.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
			# Soltado con el mouse: se coloca directo donde cayo.
			var error := load_model(file, Mode.SELECTED)
			if error != "":
				_show_status(error)
				return
			var ground: Variant = build_manager.mouse_to_ground()
			if ground != null:
				_move_active_to(ground)
			return
	_show_status("Ningun archivo soportado (FBX, GLB, GLTF)")

func _build_dialog() -> void:
	_dialog = FileDialog.new()
	_dialog.title = "Cargar modelo 3D"
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.filters = ["*.fbx ; Modelos FBX", "*.glb, *.gltf ; Modelos glTF"]
	_dialog.file_selected.connect(func(path: String) -> void:
		var error := load_model(path, Mode.PLACING)
		if error != "":
			_show_status(error))
	add_child(_dialog)

# --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.visible = false
	layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Corrido hacia abajo para no pisar el panel de estado (StatusUI).
	_panel.offset_top += 110
	_panel.offset_bottom += 110

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_name_label = Label.new()
	vbox.add_child(_name_label)

	_size_spin = _add_spin_row(vbox, "Tamano (tiles)", 0.1, 40.0, 0.1)
	_size_spin.value_changed.connect(func(value: float) -> void:
		if _active != null:
			_set_active_size_tiles(value))
	_rotation_spin = _add_spin_row(vbox, "Rotacion (grados)", 0.0, 359.0, 5.0)
	_rotation_spin.value_changed.connect(func(value: float) -> void:
		if _active != null:
			_active.rotation_degrees.y = value)

	var delete_button := Button.new()
	delete_button.text = "Borrar modelo (Supr)"
	delete_button.pressed.connect(func() -> void:
		if _mode == Mode.SELECTED:
			_delete_active())
	vbox.add_child(delete_button)

	var hint := Label.new()
	hint.text = "Arrastrar: mover  |  Ctrl+rueda: escala\nQ/E: rotar  |  Click der: deseleccionar"
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	_status_label = Label.new()
	_status_label.visible = false
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_status_label)
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_status_timer = Timer.new()
	_status_timer.one_shot = true
	_status_timer.timeout.connect(func() -> void: _status_label.visible = false)
	add_child(_status_timer)

func _add_spin_row(parent: Control, text: String, lo: float, hi: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 130
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	row.add_child(spin)
	return spin

func _refresh_panel() -> void:
	if _active == null:
		_panel.visible = false
		return
	_panel.visible = true
	_name_label.text = str(_active.get_meta("source_file"))
	_size_spin.set_value_no_signal(_get_active_size_tiles())
	_rotation_spin.set_value_no_signal(wrapf(_active.rotation_degrees.y, 0.0, 360.0))

func _show_status(text: String) -> void:
	_status_label.text = text
	_status_label.visible = true
	_status_timer.start(STATUS_SECONDS)
