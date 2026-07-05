extends CharacterBody3D
## Un turista: aparece en el borde interno del terreno existente (la zona
## desbloqueada) y deambula por los senderos entre casas, se frena cada tanto
## y se va del mapa cuando termina su estadia. Nunca pisa fuera de la zona
## desbloqueada. No atraviesa casas (colisiona contra la capa 2, donde viven
## los StaticBody3D de las casas).

const BOUNDS_MARGIN := 0.2
const LEAVE_FADE_TIME := 0.6

## Paletas fijas de ropa y piel: cada color es un material compartido entre
## todos los turistas (misma malla + mismo material = mejor batching que un
## material unico por turista).
const SHIRT_COLORS: Array[Color] = [
	Color(0.85, 0.45, 0.4), Color(0.45, 0.62, 0.82), Color(0.55, 0.72, 0.45),
	Color(0.88, 0.72, 0.42), Color(0.72, 0.55, 0.75), Color(0.92, 0.88, 0.8),
	Color(0.42, 0.68, 0.66), Color(0.82, 0.6, 0.55),
]
const PANTS_COLORS: Array[Color] = [
	Color(0.25, 0.3, 0.42), Color(0.35, 0.28, 0.22),
	Color(0.32, 0.34, 0.36), Color(0.55, 0.5, 0.42),
]
const SKIN_COLORS: Array[Color] = [
	Color(0.95, 0.8, 0.68), Color(0.85, 0.65, 0.5),
	Color(0.7, 0.5, 0.35), Color(0.5, 0.36, 0.26),
]

enum State { ENTERING, WALKING, IDLE, LEAVING, SEEKING, TASK }

## Mallas y materiales compartidos por todos los turistas (se crean una vez).
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

## Lo setea TouristManager al crearlo: limita el paseo a la zona desbloqueada
## (que puede ampliarse durante la vida del turista).
var build_manager: Node3D

var _state := State.ENTERING
var _speed := 1.5
var _state_timer := 0.0
var _stay_timer := 30.0
var _direction := Vector3.FORWARD
var _visual: Node3D
var _bob_time := 0.0
var _task_pos := Vector3.ZERO
var _task_duration := 0.0
var _task_y := 0.0

func _ready() -> void:
	add_to_group("tourists")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 2
	_speed = randf_range(TouristConfig.speed_min, TouristConfig.speed_max)
	_stay_timer = randf_range(TouristConfig.stay_min, TouristConfig.stay_max)
	_build_visual()
	_start_entering()

func _physics_process(delta: float) -> void:
	if _state != State.LEAVING:
		_stay_timer -= delta
		if _stay_timer <= 0.0:
			_state = State.LEAVING
			_state_timer = LEAVE_FADE_TIME

	match _state:
		State.LEAVING:
			_state_timer -= delta
			_visual.scale = Vector3.ONE * maxf(_state_timer / LEAVE_FADE_TIME, 0.01)
			if _state_timer <= 0.0:
				queue_free()
		State.IDLE:
			_state_timer -= delta
			# Al frenarse, el rebote de la caminata se asienta suave.
			_visual.position.y = lerpf(_visual.position.y, 0.0, minf(delta * 10.0, 1.0))
			if _state_timer <= 0.0:
				_start_walking()
		State.WALKING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.IDLE
				_state_timer = randf_range(TouristConfig.idle_min, TouristConfig.idle_max)
				return
			velocity = _direction * _speed
			move_and_slide()
			position.y = 0.0
			_bob(delta)
			# Si una casa lo frena casi por completo, busca otra direccion.
			if get_slide_collision_count() > 0 and get_real_velocity().length() < _speed * 0.3:
				_pick_new_direction()
			_keep_in_bounds()
		State.ENTERING:
			velocity = _direction * _speed
			move_and_slide()
			position.y = 0.0
			_bob(delta)
			# Si una casa del borde lo frena, apunta a otro punto interior.
			if get_slide_collision_count() > 0 and get_real_velocity().length() < _speed * 0.3:
				_aim_at_interior()
			var bounds := _bounds()
			if position.x >= bounds.position.x and position.x <= bounds.end.x \
					and position.z >= bounds.position.y and position.z <= bounds.end.y:
				_start_walking()
		State.SEEKING:
			var to_target := _task_pos - position
			to_target.y = 0.0
			if to_target.length() < 0.1:
				_state = State.TASK
				_state_timer = _task_duration
				position = _task_pos
			else:
				_direction = to_target.normalized()
				velocity = _direction * _speed
				move_and_slide()
				position.y = 0.0
				_bob(delta)
		State.TASK:
			_state_timer -= delta
			# Se acomoda suave en su lugar (arriba del banco o parado en fila).
			_visual.position.y = lerpf(_visual.position.y, _task_y, minf(delta * 8.0, 1.0))
			if _state_timer <= 0.0:
				_end_task()

## Rebote sutil de caminata: el cuerpo entero sube y baja al ritmo del paso.
func _bob(delta: float) -> void:
	_bob_time += delta * _speed * 7.0
	_visual.position.y = absf(sin(_bob_time)) * 0.035

# --- Tareas (sentarse en un banco, hacer fila en el puesto) -------------------

## True si esta deambulando y se lo puede mandar a una tarea.
func is_free() -> bool:
	return _state == State.WALKING or _state == State.IDLE

func is_on_task() -> bool:
	return _state == State.SEEKING or _state == State.TASK

## Lo manda caminando derecho a `pos`; al llegar se queda `duration` segundos
## con el cuerpo elevado a `visual_y` (0 = parado en el piso, alto del banco =
## sentado arriba). Mientras dura la tarea no colisiona con casas, asi puede
## llegar a lugares pegados a un edificio sin trabarse.
func assign_task(pos: Vector3, duration: float, visual_y := 0.0) -> void:
	_task_pos = Vector3(pos.x, 0.0, pos.z)
	_task_duration = duration
	_task_y = visual_y
	_state = State.SEEKING
	collision_mask = 0

func _end_task() -> void:
	collision_mask = 2
	_visual.position.y = 0.0
	_start_walking()

## Entra al mapa caminando derecho hacia un punto interior al azar.
func _start_entering() -> void:
	_state = State.ENTERING
	_aim_at_interior()

func _aim_at_interior() -> void:
	var bounds := _bounds()
	var target := Vector3(
		randf_range(bounds.position.x, bounds.end.x),
		0.0,
		randf_range(bounds.position.y, bounds.end.y)
	)
	_direction = (target - position).normalized()

## Rectangulo caminable en coordenadas de mundo (x, z), con margen al borde.
func _bounds() -> Rect2:
	if build_manager == null:
		return Rect2(BOUNDS_MARGIN, BOUNDS_MARGIN, 20.0 - BOUNDS_MARGIN * 2.0, 20.0 - BOUNDS_MARGIN * 2.0)
	var rect: Rect2i = build_manager.unlocked_rect()
	return Rect2(
		rect.position.x + BOUNDS_MARGIN,
		rect.position.y + BOUNDS_MARGIN,
		rect.size.x - BOUNDS_MARGIN * 2.0,
		rect.size.y - BOUNDS_MARGIN * 2.0
	)

func _start_walking() -> void:
	_state = State.WALKING
	_state_timer = randf_range(TouristConfig.walk_min, TouristConfig.walk_max)
	_pick_new_direction()

func _pick_new_direction() -> void:
	var angle := randf() * TAU
	_direction = Vector3(cos(angle), 0.0, sin(angle))

func _keep_in_bounds() -> void:
	# Al llegar al borde del terreno existente, rebota hacia adentro.
	var bounds := _bounds()
	if position.x < bounds.position.x:
		position.x = bounds.position.x
		_direction.x = absf(_direction.x)
	elif position.x > bounds.end.x:
		position.x = bounds.end.x
		_direction.x = -absf(_direction.x)
	if position.z < bounds.position.y:
		position.z = bounds.position.y
		_direction.z = absf(_direction.z)
	elif position.z > bounds.end.y:
		position.z = bounds.end.y
		_direction.z = -absf(_direction.z)

## Personita low-poly de tres piezas: piernas (pantalon), torso (remera) y
## cabeza (piel), con colores sorteados de las paletas. Las mallas son
## compartidas y de pocos segmentos: menos vertices que la capsula default
## que se usaba antes.
func _build_visual() -> void:
	var meshes := _mesh_library()
	_visual = Node3D.new()
	add_child(_visual)

	var legs := MeshInstance3D.new()
	legs.mesh = meshes.legs
	legs.material_override = _material_for(PANTS_COLORS.pick_random())
	legs.position.y = 0.08
	_visual.add_child(legs)

	var torso := MeshInstance3D.new()
	torso.mesh = meshes.torso
	torso.material_override = _material_for(SHIRT_COLORS.pick_random())
	torso.position.y = 0.27
	_visual.add_child(torso)

	var head := MeshInstance3D.new()
	head.mesh = meshes.head
	head.material_override = _material_for(SKIN_COLORS.pick_random())
	head.position.y = 0.46
	_visual.add_child(head)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.11
	shape.height = 0.42
	collision.shape = shape
	collision.position.y = 0.21
	add_child(collision)

## Mallas compartidas por todos los turistas, creadas una sola vez y con
## pocos segmentos (los defaults de Godot son mucho mas densos).
static func _mesh_library() -> Dictionary:
	if _meshes.is_empty():
		var legs := CylinderMesh.new()
		legs.top_radius = 0.068
		legs.bottom_radius = 0.075
		legs.height = 0.16
		legs.radial_segments = 10
		legs.rings = 1
		var torso := CapsuleMesh.new()
		torso.radius = 0.078
		torso.height = 0.26
		torso.radial_segments = 12
		torso.rings = 4
		var head := SphereMesh.new()
		head.radius = 0.06
		head.height = 0.12
		head.radial_segments = 12
		head.rings = 6
		_meshes = {legs = legs, torso = torso, head = head}
	return _meshes

## Un material por color de las paletas, compartido entre turistas.
static func _material_for(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]
