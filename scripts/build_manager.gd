extends Node3D
## Maneja la colocacion y borrado de edificios sobre la grilla del terreno.
## Teclas 1/2/3: casas (geometria procedural via HouseGenerator: cada una sale
## distinta). 4: tile de limpieza (purifica la suciedad alrededor; al elegirla
## se previsualiza el area NxN que va a purificar). 5: naturaleza (se exigen
## GameConfig.nature_amount por cada nature_per_houses casas). 6/7/8:
## construcciones historicas (se desbloquean con turistas totales, una de cada
## una; la 6 es la estatua de Alfonso XIII, ocupa 1x1 y construirla amplia la
## zona construible). Click izquierdo coloca, click derecho cancela o borra.
## La barra de botones (build_toolbar.gd) selecciona via select_building().

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
## Modelos FBX que reemplazan a las cajas de color cuando estan disponibles.
const MODEL_PATHS := {
	"statue": "res://models/Estatua_AlfonsoXIII.fbx",
	"mausoleo": "res://models/MOD_Mausoleo.fbx",
	"arco": "res://models/Arco_Estatua_Alonso_XIII.fbx",
	"leones": "res://models/Leones_y_plataforma.fbx",
	"maceta1": "res://models/MOD_Maceta01.fbx",
	"maceta2": "res://models/MOD_Maceta02.fbx",
}
const TRASH_BODY_COLOR := Color(0.23, 0.35, 0.28)
const TRASH_LID_COLOR := Color(0.16, 0.17, 0.18)
const TRASH_BASE_COLOR := Color(0.55, 0.55, 0.52)
const TRASH_RING_COLOR := Color(0.75, 0.78, 0.72)
const GHOST_VALID_COLOR := Color(0.3, 0.9, 0.3, 0.45)
const GHOST_INVALID_COLOR := Color(0.9, 0.25, 0.25, 0.45)
const CLEAN_PREVIEW_COLOR := Color(0.55, 0.83, 0.93)

## Lados de las zonas construibles (centradas en la grilla). Se arranca en la
## primera; ver _update_unlocks para los requisitos de cada ampliacion.
const UNLOCK_SIZES: Array[int] = [3, 9, 20]

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
var _templates: Dictionary = {}  # clave de MODEL_PATHS -> Node3D o null
var _last_statue_size := -1.0
var _last_statue_offset := 0.0
var _unlock_stage := 0

func _ready() -> void:
	_create_ghost()
	_load_models()
	terrain.set_unlocked_rect(unlocked_rect(), false)

func _exit_tree() -> void:
	for template in _templates.values():
		if template != null:
			template.free()

func _process(_delta: float) -> void:
	_update_unlocks()
	_update_ghost()
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
	# El tamano puede cambiar en vivo (GameConfig): refrescar siempre.
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
	else:
		var visual: Node3D = null
		match _selected_type:
			TYPE_CLEANER:
				visual = _make_trash_can()
			TYPE_NATURE:
				visual = _make_nature_visual(size)
			TYPE_HISTORIC:
				visual = _make_historic_visual(_selected_variant, size)
		if visual == null:
			# Caja de color como fallback si falta el modelo.
			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(side, height, side)
			var material := StandardMaterial3D.new()
			material.albedo_color = _selection_color()
			mesh.material = material
			mesh_instance.mesh = mesh
			mesh_instance.position.y = height * 0.5
			visual = mesh_instance
		building.add_child(visual)

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
	_animate_construction(building)
	buildings_changed.emit()

# --- Feedback de construccion --------------------------------------------------

## Al construir, las partes del edificio aparecen sobre su posicion final y
## van cayendo en secuencia (las mas bajas primero), asentandose con un rebote
## suave. El palacio cae en tres tandas bien marcadas: arco, estatua y leones.
func _animate_construction(building: Node3D) -> void:
	var is_palace: bool = building.get_meta("type") == TYPE_HISTORIC \
			and building.get_meta("variant") == 3
	var parts := _construction_parts(building)
	if parts.is_empty():
		return
	if not is_palace:
		parts.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.y < b.position.y)
	var interval := 0.45 if is_palace else 0.07
	var drop := 7.0 if is_palace else 4.0
	var duration := 0.65 if is_palace else 0.5
	var delay := 0.0
	for part in parts:
		var target_y: float = part.position.y
		part.position.y = target_y + drop
		part.visible = false
		var tween := part.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: part.visible = true)
		tween.tween_property(part, "position:y", target_y, duration) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		delay += interval

## Nodos que caen por separado. Los grupos visuales (casa, tacho, parque,
## palacio) se desarman en sus hijos; los contenedores de modelos FBX
## (tienen "fit_scale") caen enteros para no desarmar el modelo.
func _construction_parts(building: Node3D) -> Array[Node3D]:
	var parts: Array[Node3D] = []
	for child in building.get_children():
		if child is CollisionShape3D or not child is Node3D:
			continue
		if child.has_meta("fit_scale") or child.get_child_count() <= 1:
			parts.append(child)
		else:
			for grandchild in child.get_children():
				if grandchild is Node3D:
					parts.append(grandchild)
	return parts

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

## Proxima historica sin construir (1=estatua, 2=catedral, 3=palacio); si ya
## estan todas devuelve 3. La usa la barra de botones para su boton monumento.
func next_historic_variant() -> int:
	for variant in [1, 2]:
		if not is_historic_placed(variant):
			return variant
	return 3

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

# --- Modelos FBX de edificios --------------------------------------------------

## Carga cada modelo de MODEL_PATHS una sola vez; cada colocacion lo duplica.
## Si el asset no esta importado por el editor, se parsea el FBX en runtime.
func _load_models() -> void:
	for key in MODEL_PATHS:
		var path: String = MODEL_PATHS[key]
		var template: Node3D = null
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path)
			if scene != null:
				template = scene.instantiate()
		if template == null:
			var doc := FBXDocument.new()
			var state := FBXState.new()
			if doc.append_from_file(path, state) == OK:
				template = doc.generate_scene(state)
		if template == null:
			push_warning("No se pudo cargar %s: se usara la caja de color." % path)
		else:
			ModelEditor._strip_non_visual_nodes(template)
			ModelEditor._enable_vertex_colors(template)
		_templates[key] = template

## Contenedor con el modelo apoyado en y=0 y centrado en su AABB, escalado
## para que su lado mayor en XZ mida `tiles` tiles. Guarda "fit_scale" (escala
## que lleva el footprint a 1 tile) para reescalados en vivo. Null si el
## modelo no se pudo cargar.
func _make_model_visual(key: String, tiles: float) -> Node3D:
	var template: Node3D = _templates.get(key)
	if template == null:
		return null
	var model := template.duplicate()
	var container := Node3D.new()
	var aabb := ModelEditor._combined_aabb(model, Transform3D.IDENTITY)
	var center := aabb.get_center()
	model.position = -Vector3(center.x, aabb.position.y, center.z)
	container.add_child(model)
	var fit := 1.0 / maxf(maxf(aabb.size.x, aabb.size.z), 0.001)
	container.set_meta("fit_scale", fit)
	container.scale = Vector3.ONE * fit * tiles
	return container

## Visual de la historica `variant`, o null si faltan sus modelos.
func _make_historic_visual(variant: int, size: int) -> Node3D:
	match variant:
		1:
			return _make_statue_visual()
		2:
			return _make_model_visual("mausoleo", size * 0.95)
		3:
			return _make_palace_visual(size)
	return null

## Palacio (historica 3): composicion dentro del footprint NxN, de atras hacia
## adelante: el arco, la estatua de Alfonso XIII y los leones con su
## plataforma. El frente mira a +Z (hacia la camara).
func _make_palace_visual(size: int) -> Node3D:
	var arco := _make_model_visual("arco", size * 0.9)
	var estatua := _make_model_visual("statue", size * 0.22)
	var leones := _make_model_visual("leones", size * 0.55)
	if arco == null and estatua == null and leones == null:
		return null
	var group := Node3D.new()
	if arco != null:
		arco.position.z = -size * 0.25
		group.add_child(arco)
	if estatua != null:
		estatua.position.z = 0.0
		group.add_child(estatua)
	if leones != null:
		leones.position.z = size * 0.3
		group.add_child(leones)
	return group

## Parque de naturaleza: base verde plana que cubre las tiles, con una maceta
## (elegida al azar entre las dos) encima.
func _make_nature_visual(size: int) -> Node3D:
	var group := Node3D.new()
	var base := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, NATURE_HEIGHT, size)
	var material := StandardMaterial3D.new()
	material.albedo_color = NATURE_COLOR
	mesh.material = material
	base.mesh = mesh
	base.position.y = NATURE_HEIGHT * 0.5
	group.add_child(base)
	var pot := _make_model_visual("maceta1" if randi() % 2 == 0 else "maceta2", size * 0.7)
	if pot != null:
		pot.position.y = NATURE_HEIGHT
		group.add_child(pot)
	return group

## Tacho de basura urbano procedural (limpieza): base de hormigon, cuerpo
## cilindrico levemente conico con un aro claro y tapa oscura.
func _make_trash_can() -> Node3D:
	var group := Node3D.new()
	group.add_child(_make_cylinder(0.24, 0.24, 0.05, TRASH_BASE_COLOR, 0.025))
	group.add_child(_make_cylinder(0.2, 0.16, 0.42, TRASH_BODY_COLOR, 0.26))
	group.add_child(_make_cylinder(0.205, 0.205, 0.04, TRASH_RING_COLOR, 0.4))
	group.add_child(_make_cylinder(0.22, 0.22, 0.07, TRASH_LID_COLOR, 0.505))
	return group

func _make_cylinder(top: float, bottom: float, height: float, color: Color, y: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = y
	return mesh_instance

# --- Estatua de Alfonso XIII (historica 1) -----------------------------------

## Contenedor con el pivote en el centro de la base de la estatua, escalado
## al footprint configurado (GameConfig.statue_size, ajustable en vivo).
func _make_statue_visual() -> Node3D:
	var container := _make_model_visual("statue", 1.0)
	if container == null:
		return null
	container.add_to_group("statue_visual")
	_apply_statue_config(container)
	return container

func _apply_statue_config(container: Node3D) -> void:
	container.scale = Vector3.ONE * container.get_meta("fit_scale") * GameConfig.statue_size
	container.position.y = GameConfig.statue_offset_y

## Aplica en vivo los cambios de escala/altura de GameConfig a las estatuas ya
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

## Seleccion actual, para que la barra de botones refleje tambien lo que se
## elige por teclado.
func selected_type() -> String:
	return _selected_type

func selected_variant() -> int:
	return _selected_variant

## Cambia la seleccion desde afuera (barra de botones). Tipo "" deselecciona.
func select_building(type: String, variant: int) -> void:
	_select(type, variant)

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
