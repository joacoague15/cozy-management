extends Node
## Sistema de basura: cada ventana de 3x3 de la grilla que contenga al menos
## GameConfig.dirt_house_threshold casas distintas ensucia sus 9 tiles. Cada
## tile de limpieza purifica un area NxN (GameConfig.clean_size) centrada en
## el. La mascara se pasa al shader del terreno como textura de 1 pixel por
## tile (r=1 tile sucio). Las casas sobre tiles sucias dejan de generar
## turistas (ver TouristManager).
##
## La mascara visual transiciona: la suciedad aparece rapido y se retira
## despacio (el borde ondulado del shader hace que la mancha "se encoja" en
## vez de desaparecer de golpe). Colocar un limpiador que purifica tiles suma
## un efecto resolutivo: destello celeste sobre las tiles limpiadas, chispas
## que suben y un sonido de barrido. El estado logico (is_dirty) cambia al
## instante: la transicion es solo visual.

const DIRT_WINDOW := 3

## Velocidades de la transicion visual (valor de mascara por segundo).
## Limpiar es bien mas lento que ensuciar, para que el barrido se aprecie.
const CLEAN_FADE_SPEED := 0.8
const DIRT_FADE_SPEED := 2.2

const CLEAN_FLASH_COLOR := Color(0.75, 0.93, 1.0)
const SPARKLE_COLOR := Color(0.85, 0.97, 1.0)

@export var build_manager: Node3D
@export var terrain: GeometryInstance3D

var _image: Image
var _texture: ImageTexture
var _grid := 0
## Estado logico (0/1) por tile y estado visual animado que lo persigue.
var _target := PackedFloat32Array()
var _shown := PackedFloat32Array()
var _cleaner_count := 0
var _last_clean_size := -1
var _last_house_threshold := -1
var _last_unlock_rect := Rect2i()
var _dirty_tiles := 0

## Tiles sucias actuales. Lo usa TouristManager para frenar el crecimiento.
func dirty_tile_count() -> int:
	return _dirty_tiles

func _ready() -> void:
	_grid = build_manager.GRID_SIZE
	_image = Image.create(_grid, _grid, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)
	_target.resize(_grid * _grid)
	_shown.resize(_grid * _grid)
	terrain.material_override.set_shader_parameter("dirt_mask", _texture)
	terrain.material_override.set_shader_parameter("grid_extent", float(_grid))
	build_manager.buildings_changed.connect(_recompute)
	_recompute()

func _process(delta: float) -> void:
	# Los parametros de GameConfig pueden cambiar en vivo, y la zona
	# desbloqueada se amplia al construir monumentos / juntar turistas.
	if GameConfig.clean_size != _last_clean_size \
			or GameConfig.dirt_house_threshold != _last_house_threshold \
			or build_manager.unlocked_rect() != _last_unlock_rect:
		_recompute()
	_animate_mask(delta)

func is_dirty(cell: Vector2i) -> bool:
	return _target[cell.y * _grid + cell.x] > 0.5

## Acerca la mascara visual al estado logico y recien ahi sube la textura:
## la mancha crece rapido al ensuciarse y se retira despacio al limpiarse.
func _animate_mask(delta: float) -> void:
	var changed := false
	for i in _target.size():
		var shown := _shown[i]
		var target := _target[i]
		if shown == target:
			continue
		var speed := DIRT_FADE_SPEED if target > shown else CLEAN_FADE_SPEED
		shown = move_toward(shown, target, speed * delta)
		_shown[i] = shown
		_image.set_pixel(i % _grid, i / _grid, Color(shown, 0.0, 0.0))
		changed = true
	if changed:
		_texture.update(_image)

func _recompute() -> void:
	_last_clean_size = GameConfig.clean_size
	_last_house_threshold = GameConfig.dirt_house_threshold
	_last_unlock_rect = build_manager.unlocked_rect()
	var new_target := PackedFloat32Array()
	new_target.resize(_grid * _grid)

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
					new_target[(wy + y) * _grid + wx + x] = 1.0

	# Los limpiadores purifican su area alrededor.
	var cleaner_count := 0
	for building in build_manager.get_buildings():
		if building.is_queued_for_deletion():
			continue
		if building.get_meta("type") != build_manager.TYPE_CLEANER:
			continue
		cleaner_count += 1
		var cell: Vector2i = building.get_meta("cell")
		var start := cell - Vector2i.ONE * ((_last_clean_size - 1) / 2)
		for x in range(_last_clean_size):
			for y in range(_last_clean_size):
				var c := start + Vector2i(x, y)
				if c.x >= 0 and c.y >= 0 and c.x < _grid and c.y < _grid:
					new_target[c.y * _grid + c.x] = 0.0

	# Tiles que pasaron de sucias a limpias en este recalculo. Si el cambio
	# vino de colocar un limpiador nuevo, se celebra con el efecto resolutivo
	# (borrar casas tambien limpia, pero sin fanfarria).
	var cleaned: Array[Vector2i] = []
	_dirty_tiles = 0
	for i in new_target.size():
		if new_target[i] > 0.5:
			_dirty_tiles += 1
		elif _target[i] > 0.5:
			cleaned.append(Vector2i(i % _grid, i / _grid))
	if cleaner_count > _cleaner_count and not cleaned.is_empty():
		_spawn_clean_effect(cleaned)
		Sfx.play("clean", 0.05)
	_cleaner_count = cleaner_count
	_target = new_target

## Efecto resolutivo sobre las tiles recien limpiadas: un destello celeste
## plano que cubre exactamente esas tiles y se desvanece, mas unas chispas
## que suben flotando. La mancha, mientras tanto, se retira por debajo.
func _spawn_clean_effect(cells: Array[Vector2i]) -> void:
	var lo := cells[0]
	var hi := cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var size := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1)
	var center := Vector3(lo.x + size.x * 0.5, 0.0, lo.y + size.y * 0.5)

	# Destello: quad celeste que aparece de golpe y se apaga suave.
	var flash := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(CLEAN_FLASH_COLOR, 0.0)
	plane.material = material
	flash.mesh = plane
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = center + Vector3(0.0, 0.04, 0.0)
	get_tree().current_scene.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.55, 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.1) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(flash.queue_free)

	# Chispas que suben desde el area limpiada y se desvanecen.
	var sparkles := CPUParticles3D.new()
	sparkles.one_shot = true
	sparkles.explosiveness = 0.85
	sparkles.amount = clampi(cells.size(), 10, 28)
	sparkles.lifetime = 1.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkles.emission_box_extents = Vector3(size.x * 0.5, 0.03, size.y * 0.5)
	sparkles.direction = Vector3.UP
	sparkles.spread = 12.0
	sparkles.initial_velocity_min = 0.7
	sparkles.initial_velocity_max = 1.4
	sparkles.gravity = Vector3(0.0, -0.3, 0.0)
	sparkles.scale_amount_min = 0.5
	sparkles.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(SPARKLE_COLOR, 1.0))
	ramp.set_color(1, Color(SPARKLE_COLOR, 0.0))
	sparkles.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var sparkle_material := StandardMaterial3D.new()
	sparkle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_material.vertex_color_use_as_albedo = true
	sparkle_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = sparkle_material
	sparkles.mesh = quad
	sparkles.position = center + Vector3(0.0, 0.1, 0.0)
	get_tree().current_scene.add_child(sparkles)
	sparkles.emitting = true
	sparkles.finished.connect(sparkles.queue_free)
