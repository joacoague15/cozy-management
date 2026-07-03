extends Node3D
## Maneja la colocacion y borrado de edificios sobre la grilla del terreno.
## Teclas 1/2/3: casas (geometria procedural via HouseGenerator: cada una sale
## distinta). 4: tile de limpieza (purifica la suciedad alrededor; al elegirla
## se previsualiza el area NxN que va a purificar). 5: naturaleza (se exigen
## GameConfig.nature_amount por cada nature_per_houses casas). 6/7/8:
## construcciones historicas (se desbloquean con turistas totales, una de cada
## una; la 6 es la estatua de Alfonso XIII, ocupa 1x1 y construirla amplia la
## zona construible). Click izquierdo coloca, click derecho cancela o borra.

signal buildings_changed

const GRID_SIZE := 20

const TYPE_HOUSE := "house"
const TYPE_CLEANER := "cleaner"
const TYPE_NATURE := "nature"
const TYPE_HISTORIC := "historic"

const CLEANER_COLOR := Color(0.55, 0.83, 0.93)
const CLEANER_HEIGHT := 0.6
const NATURE_COLOR := Color(0.25, 0.56, 0.27)
const NATURE_HEIGHT := 0.15
const HISTORIC_COLORS := {
	1: Color(0.87, 0.72, 0.35),
	2: Color(0.63, 0.45, 0.72),
	3: Color(0.92, 0.88, 0.78),
}
const HISTORIC_HEIGHTS := {
	1: 3.2,
	2: 3.8,
	3: 4.5,
}
const HISTORIC_NAMES := {
	1: "Estatua",
	2: "Catedral",
	3: "Palacio",
}
const STATUE_PATH := "res://models/Estatua_AlfonsoXIII.fbx"
const GHOST_VALID_COLOR := Color(0.3, 0.9, 0.3, 0.45)
const GHOST_INVALID_COLOR := Color(0.9, 0.25, 0.25, 0.45)
const CLEAN_PREVIEW_COLOR := Color(0.55, 0.83, 0.93)

## Lados de las zonas construibles (centradas en la grilla). Se arranca en la
## primera; ver _update_unlocks para los requisitos de cada ampliacion.
const UNLOCK_SIZES: Array[int] = [3, 9, 20]

@export var info_label: Label
@export var tourist_manager: Node3D
@export var terrain: TerrainTiles
## Margen caminable que deja cada edificio en los bordes de su tile.
## El gap entre dos edificios vecinos es el doble de este valor.
@export var building_margin := 0.2

@onready var _buildings: Node3D = $Buildings

var _selected_type := ""
var _selected_variant := 0  # tamano de casa (1-3) o numero de historica (1-3)
var _occupancy: Dictionary = {}  # Vector2i -> Node3D
var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _hover_cell := Vector2i.ZERO
var _hover_valid := false
var _area_ghost: MeshInstance3D
var _area_ghost_material: StandardMaterial3D
var _statue_template: Node3D
var _last_statue_size := -1.0
var _last_statue_offset := 0.0
var _unlock_stage := 0

func _ready() -> void:
	_create_ghost()
	_load_statue()
	terrain.set_unlocked_rect(unlocked_rect(), false)

func _exit_tree() -> void:
	if _statue_template != null:
		_statue_template.free()

func _process(_delta: float) -> void:
	_update_unlocks()
	_update_ghost()
	_update_info_label()
	_update_placed_statues()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_select(TYPE_HOUSE, 1)
			KEY_2:
				_select(TYPE_HOUSE, 2)
			KEY_3:
				_select(TYPE_HOUSE, 3)
			KEY_4:
				_select(TYPE_CLEANER, 0)
			KEY_5:
				_select(TYPE_NATURE, 0)
			KEY_6:
				_select(TYPE_HISTORIC, 1)
			KEY_7:
				_select(TYPE_HISTORIC, 2)
			KEY_8:
				_select(TYPE_HISTORIC, 3)
			KEY_ESCAPE:
				_select("", 0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _selected_type != "":
			if _hover_valid:
				_place_building(_hover_cell)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _selected_type != "":
				_select("", 0)
			else:
				_delete_building_under_mouse()
			get_viewport().set_input_as_handled()

func _select(type: String, variant: int) -> void:
	_selected_type = type
	_selected_variant = variant
	_ghost.visible = type != ""
	_area_ghost.visible = false

## Lado en tiles de la seleccion actual (los configurables se leen en vivo).
func _selection_size() -> int:
	match _selected_type:
		TYPE_HOUSE:
			return _selected_variant
		TYPE_CLEANER:
			return 1
		TYPE_NATURE:
			return maxi(GameConfig.nature_size, 1)
		TYPE_HISTORIC:
			# Estatua 1x1, Catedral 3x3; el Palacio usa el tamano configurable.
			match _selected_variant:
				1:
					return 1
				2:
					return 3
			return maxi(GameConfig.historic_size, 1)
	return 0

func _selection_height() -> float:
	match _selected_type:
		TYPE_HOUSE:
			return HouseGenerator.BASE_HEIGHTS[_selected_variant]
		TYPE_CLEANER:
			return CLEANER_HEIGHT
		TYPE_NATURE:
			return NATURE_HEIGHT
		TYPE_HISTORIC:
			return HISTORIC_HEIGHTS[_selected_variant]
	return 1.0

func _selection_color() -> Color:
	match _selected_type:
		TYPE_HOUSE:
			return HouseGenerator.BASE_COLORS[_selected_variant]
		TYPE_CLEANER:
			return CLEANER_COLOR
		TYPE_NATURE:
			return NATURE_COLOR
		TYPE_HISTORIC:
			return HISTORIC_COLORS[_selected_variant]
	return Color.WHITE

## Razon por la que la seleccion actual no se puede construir ("" si se puede).
## No incluye chequeos de celdas: eso lo hace _can_place por posicion.
## Las casas siempre se pueden colocar: el deficit de naturaleza no bloquea
## la construccion, solo pausa la generacion de turistas (TouristManager).
func _selection_error() -> String:
	match _selected_type:
		TYPE_HISTORIC:
			if not is_historic_unlocked(_selected_variant):
				return "faltan turistas (%d/%d)" % [total_tourists(), historic_threshold(_selected_variant)]
			if is_historic_placed(_selected_variant):
				return "ya construida"
	return ""

func _create_ghost() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = GHOST_VALID_COLOR
	_ghost.mesh.material = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)

	# Quad translucido que previsualiza el area que purificara la limpieza.
	_area_ghost = MeshInstance3D.new()
	_area_ghost.mesh = PlaneMesh.new()
	_area_ghost_material = StandardMaterial3D.new()
	_area_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_area_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_area_ghost.mesh.material = _area_ghost_material
	_area_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_area_ghost.visible = false
	add_child(_area_ghost)

func _update_ghost() -> void:
	if _selected_type == "":
		return
	var ground: Variant = mouse_to_ground()
	if ground == null:
		_ghost.visible = false
		_area_ghost.visible = false
		_hover_valid = false
		return
	var hit: Vector3 = ground
	var size := _selection_size()
	var height := _selection_height()
	# El tamano puede cambiar en vivo desde el menu F1: refrescar siempre.
	var box: BoxMesh = _ghost.mesh
	var side := size - building_margin * 2.0
	box.size = Vector3(side, height, side)
	# Centrar el footprint del edificio en el cursor antes de snapear a la grilla.
	var half := (size - 1) * 0.5
	_hover_cell = Vector2i(floori(hit.x - half), floori(hit.z - half))
	_hover_valid = _can_place(_hover_cell, size) and _selection_error() == ""
	_ghost.position = Vector3(
		_hover_cell.x + size * 0.5,
		height * 0.5 + 0.02,
		_hover_cell.y + size * 0.5
	)
	_ghost_material.albedo_color = GHOST_VALID_COLOR if _hover_valid else GHOST_INVALID_COLOR
	_ghost.visible = true
	_update_clean_preview()

## Feedback del area NxN que va a purificar el tile de limpieza antes de
## colocarlo: un quad apenas visible con un pulso suave de opacidad.
func _update_clean_preview() -> void:
	if _selected_type != TYPE_CLEANER:
		_area_ghost.visible = false
		return
	var clean := maxi(GameConfig.clean_size, 1)
	var plane: PlaneMesh = _area_ghost.mesh
	plane.size = Vector2(clean, clean)
	_area_ghost.position = Vector3(_hover_cell.x + 0.5, 0.03, _hover_cell.y + 0.5)
	var color := CLEAN_PREVIEW_COLOR
	color.a = 0.16 + 0.07 * sin(Time.get_ticks_msec() / 350.0)
	_area_ghost_material.albedo_color = color
	_area_ghost.visible = true

func _can_place(cell: Vector2i, size: int) -> bool:
	if not unlocked_rect().encloses(Rect2i(cell, Vector2i(size, size))):
		return false
	for x in range(size):
		for y in range(size):
			if _occupancy.has(cell + Vector2i(x, y)):
				return false
	return true

func _place_building(cell: Vector2i) -> void:
	var size := _selection_size()
	var height := _selection_height()

	var building: Node3D
	if _selected_type == TYPE_NATURE:
		# La naturaleza es un parque: sin colision, los turistas la atraviesan.
		building = Node3D.new()
	else:
		# StaticBody3D en capa 2: los turistas colisionan contra esta capa.
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		building = body
	# El pivote queda en el centro del footprint, con la base apoyada en y=0.
	building.position = Vector3(cell.x + size * 0.5, 0.0, cell.y + size * 0.5)

	# La naturaleza cubre sus tiles completas; el resto deja margen caminable.
	var side := float(size) if _selected_type == TYPE_NATURE else size - building_margin * 2.0

	if _selected_type == TYPE_HOUSE:
		var house := HouseGenerator.build(_selected_variant, size, building_margin)
		building.add_child(house)
		# La colision cubre solo el cuerpo (el techo sobresale sin colision).
		height = house.get_meta("wall_height")
	elif _selected_type == TYPE_HISTORIC and _selected_variant == 1 and _statue_template != null:
		building.add_child(_make_statue_visual())
	else:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(side, height, side)
		var material := StandardMaterial3D.new()
		material.albedo_color = _selection_color()
		mesh.material = material
		mesh_instance.mesh = mesh
		mesh_instance.position.y = height * 0.5
		building.add_child(mesh_instance)

	if building is StaticBody3D:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(side, height, side)
		collision.shape = shape
		collision.position.y = height * 0.5
		building.add_child(collision)

	_buildings.add_child(building)

	var cells: Array[Vector2i] = []
	for x in range(size):
		for y in range(size):
			var c := cell + Vector2i(x, y)
			cells.append(c)
			_occupancy[c] = building
	building.set_meta("cells", cells)
	building.set_meta("cell", cell)
	building.set_meta("size", size)
	building.set_meta("height", height)
	building.set_meta("type", _selected_type)
	building.set_meta("variant", _selected_variant)
	buildings_changed.emit()

func _delete_building_under_mouse() -> void:
	var ground: Variant = mouse_to_ground()
	if ground == null:
		return
	var hit: Vector3 = ground
	var cell := Vector2i(floori(hit.x), floori(hit.z))
	if not _occupancy.has(cell):
		return
	var building: Node3D = _occupancy[cell]
	for c in building.get_meta("cells"):
		_occupancy.erase(c)
	building.queue_free()
	buildings_changed.emit()

func get_buildings() -> Array[Node]:
	return _buildings.get_children()

func _valid_buildings() -> Array[Node]:
	return get_buildings().filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())

## Edificio que ocupa la celda, o null. Lo usa DirtManager para contar las
## casas de cada ventana de 3x3.
func building_at(cell: Vector2i) -> Node3D:
	return _occupancy.get(cell)

# --- Sistema de naturaleza -------------------------------------------------

## Cantidad de casas colocadas.
func house_count() -> int:
	var total := 0
	for building in _valid_buildings():
		if building.get_meta("type") == TYPE_HOUSE:
			total += 1
	return total

## Tiles (celdas) ocupadas por casas.
func house_tile_count() -> int:
	var total := 0
	for building in _valid_buildings():
		if building.get_meta("type") == TYPE_HOUSE:
			total += (building.get_meta("cells") as Array).size()
	return total

func nature_count() -> int:
	var total := 0
	for building in _valid_buildings():
		if building.get_meta("type") == TYPE_NATURE:
			total += 1
	return total

## Naturalezas exigidas: nature_amount por cada nature_per_houses casas.
func nature_needed() -> int:
	return house_count() / maxi(GameConfig.nature_per_houses, 1) * GameConfig.nature_amount

# --- Sistema de construcciones historicas -----------------------------------

func total_tourists() -> int:
	return tourist_manager.total_spawned if tourist_manager != null else 0

## Turistas totales acumulados que exige la historica `variant` (1-3).
func historic_threshold(variant: int) -> int:
	var threshold := GameConfig.historic_tourists_1
	if variant >= 2:
		threshold += GameConfig.historic_tourists_2
	if variant >= 3:
		threshold += GameConfig.historic_tourists_3
	return threshold

func is_historic_unlocked(variant: int) -> bool:
	return total_tourists() >= historic_threshold(variant)

func is_historic_placed(variant: int) -> bool:
	for building in _valid_buildings():
		if building.get_meta("type") == TYPE_HISTORIC and building.get_meta("variant") == variant:
			return true
	return false

# --- Zonas desbloqueables ----------------------------------------------------

## Rectangulo (en celdas) donde se puede construir en la etapa actual.
func unlocked_rect() -> Rect2i:
	var side: int = UNLOCK_SIZES[_unlock_stage]
	var start := (GRID_SIZE - side) / 2
	return Rect2i(start, start, side, side)

func unlocked_side() -> int:
	return UNLOCK_SIZES[_unlock_stage]

## Que falta para la proxima ampliacion de zona ("" si esta todo abierto).
## Lo muestra el StatusUI.
func next_zone_requirement() -> String:
	match _unlock_stage:
		0:
			return "construi la estatua (%d turistas)" % historic_threshold(1)
		1:
			return "construi la catedral (%d turistas)" % historic_threshold(2)
	return ""

## Cada ampliacion se dispara al CONSTRUIR un monumento: la estatua abre la
## zona 9x9 y la catedral la 20x20.
func _update_unlocks() -> void:
	if _unlock_stage == 0 and is_historic_placed(1):
		_advance_unlock()
	if _unlock_stage == 1 and is_historic_placed(2):
		_advance_unlock()

func _advance_unlock() -> void:
	_unlock_stage += 1
	terrain.set_unlocked_rect(unlocked_rect(), true)

# --- Estatua de Alfonso XIII (historica 1) -----------------------------------

## Carga el modelo de la estatua una sola vez; cada colocacion lo duplica.
## Si el asset no esta importado por el editor, se parsea el FBX en runtime.
func _load_statue() -> void:
	if ResourceLoader.exists(STATUE_PATH):
		var scene: PackedScene = load(STATUE_PATH)
		if scene != null:
			_statue_template = scene.instantiate()
	if _statue_template == null:
		var doc := FBXDocument.new()
		var state := FBXState.new()
		if doc.append_from_file(STATUE_PATH, state) == OK:
			_statue_template = doc.generate_scene(state)
	if _statue_template == null:
		push_warning("No se pudo cargar %s: la historica 1 usara la caja." % STATUE_PATH)
		return
	ModelEditor._strip_non_visual_nodes(_statue_template)
	ModelEditor._enable_vertex_colors(_statue_template)

## Contenedor con el pivote en el centro de la base de la estatua, escalado
## al footprint configurado (GameConfig.statue_size, ajustable en vivo por F1).
func _make_statue_visual() -> Node3D:
	var model := _statue_template.duplicate()
	var container := Node3D.new()
	var aabb := ModelEditor._combined_aabb(model, Transform3D.IDENTITY)
	var center := aabb.get_center()
	model.position = -Vector3(center.x, aabb.position.y, center.z)
	container.add_child(model)
	container.set_meta("fit_scale", 1.0 / maxf(maxf(aabb.size.x, aabb.size.z), 0.001))
	container.add_to_group("statue_visual")
	_apply_statue_config(container)
	return container

func _apply_statue_config(container: Node3D) -> void:
	container.scale = Vector3.ONE * container.get_meta("fit_scale") * GameConfig.statue_size
	container.position.y = GameConfig.statue_offset_y

## Aplica en vivo los cambios de escala/altura del menu F1 a las estatuas ya
## colocadas.
func _update_placed_statues() -> void:
	if GameConfig.statue_size == _last_statue_size \
			and GameConfig.statue_offset_y == _last_statue_offset:
		return
	_last_statue_size = GameConfig.statue_size
	_last_statue_offset = GameConfig.statue_offset_y
	for container in get_tree().get_nodes_in_group("statue_visual"):
		_apply_statue_config(container)

# ---------------------------------------------------------------------------

## True si hay un tipo de edificio seleccionado para colocar.
## Lo consulta ModelEditor para no robarle clicks a la construccion.
func has_selection() -> bool:
	return _selected_type != ""

## Proyecta el mouse sobre el plano del terreno (y = 0). Devuelve Vector3 o null.
func mouse_to_ground() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return null
	var t := -origin.y / direction.y
	if t < 0.0:
		return null
	return origin + direction * t

func _historic_status(variant: int) -> String:
	if is_historic_placed(variant):
		return "construida"
	if is_historic_unlocked(variant):
		return "lista!"
	return "%d turistas" % historic_threshold(variant)

func _update_info_label() -> void:
	if info_label == null:
		return
	var selected_text := "nada (elegi con 1-8)"
	match _selected_type:
		TYPE_HOUSE:
			selected_text = "casa %dx%d" % [_selected_variant, _selected_variant]
		TYPE_CLEANER:
			selected_text = "limpieza 1x1 (purifica %dx%d)" % [GameConfig.clean_size, GameConfig.clean_size]
		TYPE_NATURE:
			selected_text = "naturaleza %dx%d" % [_selection_size(), _selection_size()]
		TYPE_HISTORIC:
			selected_text = "%s %dx%d" % [HISTORIC_NAMES[_selected_variant], _selection_size(), _selection_size()]
	var error := _selection_error()
	if error != "":
		selected_text += "  [BLOQUEADO: %s]" % error
	var text := (
		"[1-3] Casa   [4] Limpieza   [5] Naturaleza %dx%d\n" % [_selection_nature_size(), _selection_nature_size()]
		+ "[6] %s: %s   [7] %s: %s   [8] %s: %s\n" % [
			HISTORIC_NAMES[1], _historic_status(1),
			HISTORIC_NAMES[2], _historic_status(2),
			HISTORIC_NAMES[3], _historic_status(3),
		]
		+ "Click izq: colocar   |   Click der: cancelar / borrar   |   F1: parametros   |   F2: cargar modelo 3D\n"
		+ "Turistas totales: %d   |   Naturaleza: %d colocadas / %d necesarias%s\n" % [
			total_tourists(), nature_count(), nature_needed(),
			"   [SIN TURISTAS NUEVOS: falta naturaleza]" if nature_needed() > nature_count() else "",
		]
		+ "Seleccionado: " + selected_text
	)
	if info_label.text != text:
		info_label.text = text

func _selection_nature_size() -> int:
	return maxi(GameConfig.nature_size, 1)
