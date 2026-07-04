extends Node3D
## Genera turistas por cada casa colocada: 1 turista cada
## TouristConfig.spawn_interval segundos (1/s por defecto), con un "+1"
## flotante sobre la casa como feedback. Una casa deja de generar si alguna de
## sus tiles esta sucia (necesita un tile de limpieza cerca) o si falta
## naturaleza en el mapa (GameConfig.nature_per_houses / nature_amount); las
## barras del StatusUI muestran ambos estados. Los turistas aparecen sobre el
## borde interno de la zona desbloqueada (nunca fuera del terreno existente)
## y deambulan hacia adentro.

const TouristScript := preload("res://scripts/tourist.gd")

## Distancia hacia adentro del borde de la zona a la que aparece cada turista.
const SPAWN_INSET := 0.3

## Solo 1 de cada N turistas generados aparece caminando en el mapa: el
## conteo real (total_spawned, el que desbloquea historicas) no cambia, pero
## la pantalla no se satura de capsulas.
const VISUAL_SPAWN_DIVISOR := 4

@export var build_manager: Node3D
@export var dirt_manager: Node

## Turistas generados desde el inicio de la partida (nunca baja).
## Lo usa el sistema de construcciones historicas para los desbloqueos.
var total_spawned := 0

## Acumulador de spawn por casa (instance_id -> progreso 0..1).
var _spawn_accum: Dictionary = {}

func _ready() -> void:
	build_manager.buildings_changed.connect(_on_buildings_changed)

func _process(delta: float) -> void:
	# Con deficit de naturaleza ninguna casa atrae turistas.
	if build_manager.nature_needed() > build_manager.nature_count():
		return
	var interval: float = maxf(TouristConfig.spawn_interval, 0.05)
	for building in build_manager.get_buildings():
		if building.is_queued_for_deletion():
			continue
		if building.get_meta("type") != build_manager.TYPE_HOUSE:
			continue
		if _is_house_dirty(building):
			continue
		var id: int = building.get_instance_id()
		var accum: float = _spawn_accum.get(id, 0.0) + delta / interval
		while accum >= 1.0:
			accum -= 1.0
			_spawn_tourist()
			_spawn_feedback(building)
		_spawn_accum[id] = accum

func _is_house_dirty(building: Node3D) -> bool:
	if dirt_manager == null:
		return false
	for c in building.get_meta("cells"):
		if dirt_manager.is_dirty(c):
			return true
	return false

## "+1" flotante sobre la casa: sube y se desvanece al generar cada turista.
func _spawn_feedback(building: Node3D) -> void:
	var label := Label3D.new()
	label.text = "+1"
	label.font_size = 64
	label.modulate = Color(1.0, 1.0, 0.85)
	label.outline_size = 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = building.position + Vector3(0.0, building.get_meta("height") + 0.5, 0.0)
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

## Proporcion (0..1) de la naturaleza exigida que esta colocada. Con menos de
## 1.0 ninguna casa genera turistas; la barra del StatusUI muestra el avance.
func nature_factor() -> float:
	var needed: int = build_manager.nature_needed()
	if needed <= 0:
		return 1.0
	return clampf(float(build_manager.nature_count()) / needed, 0.0, 1.0)

## Proporcion (0..1) de tiles de casa que estan limpias. Las casas con tiles
## sucias no generan turistas.
func clean_factor() -> float:
	var house_tiles: int = build_manager.house_tile_count()
	if house_tiles <= 0 or dirt_manager == null:
		return 1.0
	return clampf(1.0 - float(dirt_manager.dirty_tile_count()) / house_tiles, 0.0, 1.0)

func _spawn_tourist() -> void:
	total_spawned += 1
	if total_spawned % VISUAL_SPAWN_DIVISOR != 0:
		return
	var tourist: CharacterBody3D = TouristScript.new()
	tourist.build_manager = build_manager
	tourist.position = _random_border_point()
	add_child(tourist)

## Punto al azar sobre el borde interno de la zona desbloqueada: el turista
## aparece siempre sobre terreno que existe.
func _random_border_point() -> Vector3:
	var rect: Rect2i = build_manager.unlocked_rect()
	var lo_x := rect.position.x + SPAWN_INSET
	var hi_x := rect.end.x - SPAWN_INSET
	var lo_z := rect.position.y + SPAWN_INSET
	var hi_z := rect.end.y - SPAWN_INSET
	match randi() % 4:
		0:
			return Vector3(randf_range(lo_x, hi_x), 0.0, lo_z)
		1:
			return Vector3(randf_range(lo_x, hi_x), 0.0, hi_z)
		2:
			return Vector3(lo_x, 0.0, randf_range(lo_z, hi_z))
		_:
			return Vector3(hi_x, 0.0, randf_range(lo_z, hi_z))

func _on_buildings_changed() -> void:
	# Limpia acumuladores de casas que ya no existen.
	var valid := {}
	for building in build_manager.get_buildings():
		if not building.is_queued_for_deletion():
			valid[building.get_instance_id()] = true
	for id in _spawn_accum.keys():
		if not valid.has(id):
			_spawn_accum.erase(id)
