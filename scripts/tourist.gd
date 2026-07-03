extends CharacterBody3D
## Un turista: aparece fuera del terreno, entra caminando por el borde y
## deambula por los senderos entre casas, se frena cada tanto y se va del
## mapa cuando termina su estadia. No atraviesa casas (colisiona contra la
## capa 2, donde viven los StaticBody3D de las casas).

const BOUNDS_MIN := 0.2
const BOUNDS_MAX := 19.8
const LEAVE_FADE_TIME := 0.6

enum State { ENTERING, WALKING, IDLE, LEAVING }

var _state := State.ENTERING
var _speed := 1.5
var _state_timer := 0.0
var _stay_timer := 30.0
var _direction := Vector3.FORWARD
var _mesh_instance: MeshInstance3D

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
			_mesh_instance.scale = Vector3.ONE * maxf(_state_timer / LEAVE_FADE_TIME, 0.01)
			if _state_timer <= 0.0:
				queue_free()
		State.IDLE:
			_state_timer -= delta
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
			# Si una casa lo frena casi por completo, busca otra direccion.
			if get_slide_collision_count() > 0 and get_real_velocity().length() < _speed * 0.3:
				_pick_new_direction()
			_keep_in_bounds()
		State.ENTERING:
			velocity = _direction * _speed
			move_and_slide()
			position.y = 0.0
			# Si una casa del borde lo frena, apunta a otro punto interior.
			if get_slide_collision_count() > 0 and get_real_velocity().length() < _speed * 0.3:
				_aim_at_interior()
			if position.x >= BOUNDS_MIN and position.x <= BOUNDS_MAX \
					and position.z >= BOUNDS_MIN and position.z <= BOUNDS_MAX:
				_start_walking()

## Entra al mapa caminando derecho hacia un punto interior al azar.
func _start_entering() -> void:
	_state = State.ENTERING
	_aim_at_interior()

func _aim_at_interior() -> void:
	var target := Vector3(randf_range(2.0, 18.0), 0.0, randf_range(2.0, 18.0))
	_direction = (target - position).normalized()

func _start_walking() -> void:
	_state = State.WALKING
	_state_timer = randf_range(TouristConfig.walk_min, TouristConfig.walk_max)
	_pick_new_direction()

func _pick_new_direction() -> void:
	var angle := randf() * TAU
	_direction = Vector3(cos(angle), 0.0, sin(angle))

func _keep_in_bounds() -> void:
	# Al llegar al borde del terreno, rebota hacia adentro.
	if position.x < BOUNDS_MIN:
		position.x = BOUNDS_MIN
		_direction.x = absf(_direction.x)
	elif position.x > BOUNDS_MAX:
		position.x = BOUNDS_MAX
		_direction.x = -absf(_direction.x)
	if position.z < BOUNDS_MIN:
		position.z = BOUNDS_MIN
		_direction.z = absf(_direction.z)
	elif position.z > BOUNDS_MAX:
		position.z = BOUNDS_MAX
		_direction.z = -absf(_direction.z)

func _build_visual() -> void:
	_mesh_instance = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.11
	capsule.height = 0.42
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(randf(), 0.55, 0.9)
	capsule.material = material
	_mesh_instance.mesh = capsule
	_mesh_instance.position.y = 0.21
	add_child(_mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.11
	shape.height = 0.42
	collision.shape = shape
	collision.position.y = 0.21
	add_child(collision)
