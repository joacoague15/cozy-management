class_name TerrainTiles
extends MultiMeshInstance3D
## Terreno por tiles: una caja por celda de la grilla via MultiMesh, con el
## shader de grilla/basura como material_override. Las celdas bloqueadas no
## existen visualmente (quedan escondidas bajo el mapa) y al desbloquear una
## zona las tiles nuevas emergen desde abajo, en ondas que avanzan desde el
## borde de la zona anterior, con un leve rebote al asentarse.

const GRID := 20
const TILE_DEPTH := 0.4
const RISE_DEPTH := 1.6
const RISE_SECONDS := 0.55
const RING_DELAY := 0.07
const HIDDEN_Y := -1000.0

var _unlocked := Rect2i()
var _anim: Array[Dictionary] = []

func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(1.0, TILE_DEPTH, 1.0)
	multimesh.mesh = box
	multimesh.instance_count = GRID * GRID
	for x in GRID:
		for z in GRID:
			_place(x, z, HIDDEN_Y)

func _process(delta: float) -> void:
	for i in range(_anim.size() - 1, -1, -1):
		var a: Dictionary = _anim[i]
		a.t += delta
		if a.t < a.delay:
			continue
		var t := clampf((a.t - a.delay) / RISE_SECONDS, 0.0, 1.0)
		_place(a.x, a.z, -RISE_DEPTH * (1.0 - _ease_out_back(t)))
		if t >= 1.0:
			_anim.remove_at(i)

## Deja visible exactamente `rect`. Con animate, las celdas que no estaban en
## el rectangulo anterior emergen desde abajo del terreno.
func set_unlocked_rect(rect: Rect2i, animate: bool) -> void:
	var old := _unlocked
	_unlocked = rect
	_anim.clear()
	for x in GRID:
		for z in GRID:
			var cell := Vector2i(x, z)
			if not rect.has_point(cell):
				_place(x, z, HIDDEN_Y)
			elif not animate or old.has_point(cell):
				_place(x, z, 0.0)
			else:
				# Escondida hasta que le llegue su turno en la onda.
				_place(x, z, HIDDEN_Y)
				_anim.append({
					x = x, z = z, t = 0.0,
					delay = _ring_distance(cell, old) * RING_DELAY + randf() * 0.05,
				})

## Distancia Chebyshev de la celda al rectangulo (0 si esta adentro): define
## el orden de la onda, anillo por anillo.
func _ring_distance(cell: Vector2i, rect: Rect2i) -> int:
	if rect.size == Vector2i.ZERO:
		return 0
	var dx := maxi(maxi(rect.position.x - cell.x, cell.x - rect.end.x + 1), 0)
	var dz := maxi(maxi(rect.position.y - cell.y, cell.y - rect.end.y + 1), 0)
	return maxi(dx, dz)

## Apoya la tile (x, z) con su cara superior en `top_y`.
func _place(x: int, z: int, top_y: float) -> void:
	var origin := Vector3(x + 0.5, top_y - TILE_DEPTH * 0.5, z + 0.5)
	multimesh.set_instance_transform(x * GRID + z, Transform3D(Basis.IDENTITY, origin))

## Ease con rebote: la tile sobrepasa apenas su posicion y se asienta.
func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)
