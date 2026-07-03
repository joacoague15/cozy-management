extends Node3D
## Genera turistas por cada casa colocada.
## Casa sola: 1 turista cada TouristConfig.spawn_interval segundos.
## Casa con al menos una casa vecina (ortogonal): al doble de velocidad.
## Si falta naturaleza (ver GameConfig.nature_ratio), la generacion se pausa
## hasta que se coloque la necesaria. Los turistas aparecen fuera del terreno,
## en un punto al azar del borde, y caminan hacia adentro.

const TouristScript := preload("res://scripts/tourist.gd")

## Distancia fuera del borde del terreno a la que aparece cada turista.
const SPAWN_OUTSIDE_DISTANCE := 1.0

@export var build_manager: Node3D

## Turistas generados desde el inicio de la partida (nunca baja).
## Lo usa el sistema de construcciones historicas para los desbloqueos.
var total_spawned := 0

## Acumulador de spawn por casa (instance_id -> progreso 0..1).
var _spawn_accum: Dictionary = {}

func _ready() -> void:
	build_manager.buildings_changed.connect(_on_buildings_changed)

func _process(delta: float) -> void:
	# Con deficit de naturaleza las casas dejan de atraer turistas.
	if build_manager.nature_needed() > build_manager.nature_count():
		return
	var interval: float = maxf(TouristConfig.spawn_interval, 0.05)
	for building in build_manager.get_buildings():
		if building.is_queued_for_deletion():
			continue
		if building.get_meta("type") != build_manager.TYPE_HOUSE:
			continue
		var rate := 2.0 if build_manager.house_has_neighbor(building) else 1.0
		var id: int = building.get_instance_id()
		var accum: float = _spawn_accum.get(id, 0.0) + delta * rate / interval
		while accum >= 1.0:
			accum -= 1.0
			_spawn_tourist()
		_spawn_accum[id] = accum

func _spawn_tourist() -> void:
	var tourist: CharacterBody3D = TouristScript.new()
	tourist.position = _random_border_point()
	add_child(tourist)
	total_spawned += 1

## Punto al azar fuera del terreno, pegado a uno de los cuatro bordes.
func _random_border_point() -> Vector3:
	var grid := float(build_manager.GRID_SIZE)
	var t := randf() * grid
	match randi() % 4:
		0:
			return Vector3(t, 0.0, -SPAWN_OUTSIDE_DISTANCE)
		1:
			return Vector3(t, 0.0, grid + SPAWN_OUTSIDE_DISTANCE)
		2:
			return Vector3(-SPAWN_OUTSIDE_DISTANCE, 0.0, t)
		_:
			return Vector3(grid + SPAWN_OUTSIDE_DISTANCE, 0.0, t)

func _on_buildings_changed() -> void:
	# Limpia acumuladores de casas que ya no existen.
	var valid := {}
	for building in build_manager.get_buildings():
		if not building.is_queued_for_deletion():
			valid[building.get_instance_id()] = true
	for id in _spawn_accum.keys():
		if not valid.has(id):
			_spawn_accum.erase(id)
