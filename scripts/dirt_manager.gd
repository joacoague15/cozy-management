extends Node
## Sistema de basura: cada ventana de 3x3 de la grilla que contenga al menos
## GameConfig.dirt_house_threshold casas distintas ensucia sus 9 tiles. Cada
## tile de limpieza purifica un area NxN (GameConfig.clean_size) centrada en
## el. La mascara se pasa al shader del terreno como textura de 1 pixel por
## tile (r=1 tile sucio). Las casas sobre tiles sucias dejan de generar
## turistas (ver TouristManager).

const DIRT_WINDOW := 3

@export var build_manager: Node3D
@export var terrain: GeometryInstance3D

var _image: Image
var _texture: ImageTexture
var _last_clean_size := -1
var _last_house_threshold := -1
var _last_unlock_rect := Rect2i()
var _dirty_tiles := 0

## Tiles sucias actuales. Lo usa TouristManager para frenar el crecimiento.
func dirty_tile_count() -> int:
	return _dirty_tiles

func _ready() -> void:
	var grid: int = build_manager.GRID_SIZE
	_image = Image.create(grid, grid, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)
	terrain.material_override.set_shader_parameter("dirt_mask", _texture)
	terrain.material_override.set_shader_parameter("grid_extent", float(grid))
	build_manager.buildings_changed.connect(_recompute)
	_recompute()

func _process(_delta: float) -> void:
	# Los parametros de GameConfig pueden cambiar en vivo, y la zona
	# desbloqueada se amplia al construir monumentos / juntar turistas.
	if GameConfig.clean_size != _last_clean_size \
			or GameConfig.dirt_house_threshold != _last_house_threshold \
			or build_manager.unlocked_rect() != _last_unlock_rect:
		_recompute()

func is_dirty(cell: Vector2i) -> bool:
	return _image.get_pixel(cell.x, cell.y).r > 0.5

func _recompute() -> void:
	_last_clean_size = GameConfig.clean_size
	_last_house_threshold = GameConfig.dirt_house_threshold
	_last_unlock_rect = build_manager.unlocked_rect()
	var grid: int = build_manager.GRID_SIZE
	_image.fill(Color.BLACK)

	# Cada ventana de 3x3 con demasiadas casas distintas ensucia sus 9 tiles.
	# Solo se recorren ventanas completamente adentro de la zona desbloqueada:
	# la basura nunca aparece fuera de ella.
	for wx in range(_last_unlock_rect.position.x, _last_unlock_rect.end.x - DIRT_WINDOW + 1):
		for wy in range(_last_unlock_rect.position.y, _last_unlock_rect.end.y - DIRT_WINDOW + 1):
			var houses := {}
			for x in range(DIRT_WINDOW):
				for y in range(DIRT_WINDOW):
					var building: Node3D = build_manager.building_at(Vector2i(wx + x, wy + y))
					if building != null and not building.is_queued_for_deletion() \
							and building.get_meta("type") == build_manager.TYPE_HOUSE:
						houses[building.get_instance_id()] = true
			if houses.size() < _last_house_threshold:
				continue
			for x in range(DIRT_WINDOW):
				for y in range(DIRT_WINDOW):
					_image.set_pixel(wx + x, wy + y, Color.WHITE)

	# Los limpiadores purifican su area alrededor.
	for building in build_manager.get_buildings():
		if building.is_queued_for_deletion():
			continue
		if building.get_meta("type") != build_manager.TYPE_CLEANER:
			continue
		var cell: Vector2i = building.get_meta("cell")
		var start := cell - Vector2i.ONE * ((_last_clean_size - 1) / 2)
		for x in range(_last_clean_size):
			for y in range(_last_clean_size):
				var c := start + Vector2i(x, y)
				if c.x >= 0 and c.y >= 0 and c.x < grid and c.y < grid:
					_image.set_pixel(c.x, c.y, Color.BLACK)

	_dirty_tiles = 0
	for x in range(grid):
		for y in range(grid):
			if _image.get_pixel(x, y).r > 0.5:
				_dirty_tiles += 1
	_texture.update(_image)
