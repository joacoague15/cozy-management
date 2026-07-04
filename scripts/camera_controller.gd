extends Node3D
## Camara estilo city-builder.
## Paneo con WASD/flechas, zoom con la rueda, rotacion arrastrando con el
## boton del medio o con el izquierdo (el izquierdo solo cuando el mouse no
## esta colocando edificios ni arrastrando modelos; con Alt/Option rota
## siempre). En trackpad (macOS): pinch = zoom, scroll de dos dedos vertical =
## zoom, horizontal = rotar (el trackpad no emite eventos de rueda: llegan
## como gestos Magnify/Pan).
## El pitch y el zoom estan acotados para que la camara nunca baje del terreno.

@export var move_speed := 15.0
@export var rotate_sensitivity := 0.005
@export var pitch_sensitivity := 0.005
@export var zoom_step := 1.15
## Zoom por unidad de scroll vertical de dos dedos (negativo para invertir).
@export var pan_zoom_sensitivity := 0.12
## Radianes de giro por unidad de scroll horizontal de dos dedos.
@export var pan_rotate_sensitivity := 0.008
@export var min_zoom := 5.0
@export var max_zoom := 40.0
## Angulo minimo/maximo mirando hacia abajo, en grados sobre el horizonte.
@export var min_pitch_deg := 15.0
@export var max_pitch_deg := 80.0
@export var smoothing := 10.0
## Limites de paneo (en el plano XZ), con un margen alrededor del terreno.
@export var bounds_min := Vector2(-3.0, -3.0)
@export var bounds_max := Vector2(23.0, 23.0)
## Para saber si el click izquierdo esta ocupado por el gameplay (colocar
## edificios / arrastrar modelos) antes de usarlo para rotar la camara.
@export var build_manager: Node3D
@export var model_editor: Node3D

@onready var _pitch_node: Node3D = $Pitch
@onready var _camera: Camera3D = $Pitch/Camera3D

var _target_position: Vector3
var _target_yaw: float
var _target_pitch: float
var _target_zoom := 18.0

func _ready() -> void:
	_target_position = position
	_target_yaw = rotation.y
	_target_pitch = deg_to_rad(45.0)
	_pitch_node.rotation.x = -_target_pitch
	_camera.position = Vector3(0.0, 0.0, _target_zoom)

func _process(delta: float) -> void:
	_read_movement(delta)
	_apply_smoothing(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom / zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom * zoom_step, min_zoom, max_zoom)
	elif event is InputEventMagnifyGesture:
		# Pinch del trackpad: factor > 1 acerca, < 1 aleja.
		_target_zoom = clampf(_target_zoom / event.factor, min_zoom, max_zoom)
	elif event is InputEventPanGesture:
		# Scroll de dos dedos del trackpad: vertical = zoom, horizontal = rotar.
		_target_zoom = clampf(
			_target_zoom * pow(zoom_step, event.delta.y * pan_zoom_sensitivity),
			min_zoom,
			max_zoom
		)
		_target_yaw -= event.delta.x * pan_rotate_sensitivity
	elif event is InputEventMouseMotion and _is_rotate_drag(event):
		_target_yaw -= event.relative.x * rotate_sensitivity
		_target_pitch = clampf(
			_target_pitch + event.relative.y * pitch_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)

## Arrastre que rota la camara: boton del medio siempre; click izquierdo
## cuando el mouse esta libre (sin edificio seleccionado para colocar y sin
## modelo en colocacion/arrastre). Con Alt/Option el izquierdo rota siempre.
func _is_rotate_drag(event: InputEventMouseMotion) -> bool:
	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		return true
	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		return false
	if event.alt_pressed:
		return true
	if build_manager != null and build_manager.has_selection():
		return false
	if model_editor != null and model_editor.is_mouse_busy():
		return false
	return true

func _read_movement(delta: float) -> void:
	var input_dir := Input.get_vector("cam_left", "cam_right", "cam_forward", "cam_back")
	if input_dir == Vector2.ZERO:
		return
	# Mover mas rapido cuanto mas alejada esta la camara.
	var speed := move_speed * (_target_zoom / 18.0)
	var direction := Basis(Vector3.UP, _target_yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	_target_position += direction * speed * delta
	_target_position.x = clampf(_target_position.x, bounds_min.x, bounds_max.x)
	_target_position.z = clampf(_target_position.z, bounds_min.y, bounds_max.y)

func _apply_smoothing(delta: float) -> void:
	var t := 1.0 - exp(-smoothing * delta)
	position = position.lerp(_target_position, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)
	_pitch_node.rotation.x = lerp_angle(_pitch_node.rotation.x, -_target_pitch, t)
	_camera.position.z = lerpf(_camera.position.z, _target_zoom, t)
