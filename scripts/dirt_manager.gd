extends Node
## Sistema de basura: cada conjunto de casas conectadas (compartiendo al menos
## un lado) con GameConfig.dirt_cluster_size o mas casas genera un area de
## basura que cubre las tiles de esas casas. Cada tile de limpieza purifica un
## area NxN (GameConfig.clean_size) centrada en el. La mascara se pasa al
## shader del terreno como textura de 1 pixel por tile (r=1 tile sucio).

@export var build_manager: Node3D
@export var terrain: MeshInstance3D

var _image: Image
var _texture: ImageTexture
var _last_clean_size := -1
var _last_cluster_size := -1

func _ready() -> void:
	var grid: int = build_manager.GRID_SIZE
	_image = Image.create(grid, grid, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)
	terrain.mesh.material.set_shader_parameter("dirt_mask", _texture)
	terrain.mesh.material.set_shader_parameter("grid_extent", float(grid))
	build_manager.buildings_changed.connect(_recompute)
	_recompute()

func _process(_delta: float) -> void:
	# Los parametros pueden cambiar en vivo desde el menu F1.
	if GameConfig.clean_size != _last_clean_size \
			or GameConfig.dirt_cluster_size != _last_cluster_size:
		_recompute()

func is_dirty(cell: Vector2i) -> bool:
	return _image.get_pixel(cell.x, cell.y).r > 0.5

func _recompute() -> void:
	_last_clean_size = GameConfig.clean_size
	_last_cluster_size = GameConfig.dirt_cluster_size
	var grid: int = build_manager.GRID_SIZE
	_image.fill(Color.BLACK)

	# Los conjuntos grandes de casas ensucian sus propias tiles.
	for cluster in build_manager.house_clusters():
		if cluster.size() < _last_cluster_size:
			continue
		for house in cluster:
			for c in house.get_meta("cells"):
				_image.set_pixel(c.x, c.y, Color.WHITE)

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
	_texture.update(_image)
