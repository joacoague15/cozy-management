class_name HouseGenerator
extends RefCounted
## Genera la geometria procedural de las casas (1x1, 2x2, 3x3). Cada casa
## colocada sale distinta: altura y tono de pared sorteados, techo a dos aguas
## o losa plana con color propio, ventanas por piso con huecos aleatorios y
## una puerta en una fachada al azar.

const BASE_HEIGHTS := {
	1: 1.0,
	2: 1.6,
	3: 2.4,
}
const BASE_COLORS := {
	1: Color(0.93, 0.76, 0.42),
	2: Color(0.78, 0.52, 0.42),
	3: Color(0.55, 0.62, 0.79),
}
const ROOF_COLORS: Array[Color] = [
	Color(0.72, 0.32, 0.26),  # teja
	Color(0.38, 0.38, 0.42),  # pizarra
	Color(0.47, 0.31, 0.22),  # madera
	Color(0.36, 0.47, 0.40),  # cobre viejo
]
const WINDOW_COLOR := Color(0.76, 0.87, 0.96)
const DOOR_COLOR := Color(0.33, 0.23, 0.15)
const GABLE_CHANCE := 0.6
const WINDOW_SKIP_CHANCE := 0.2

## Devuelve un Node3D con el pivote en el centro del footprint y la base
## apoyada en y=0. Deja en meta "wall_height" la altura del cuerpo, que el
## BuildManager usa para la caja de colision.
static func build(variant: int, size: int, margin: float) -> Node3D:
	var root := Node3D.new()
	var side := size - margin * 2.0
	var wall_height: float = BASE_HEIGHTS[variant] * randf_range(0.85, 1.25)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(side, wall_height, side)
	body_mesh.material = _flat_material(_jitter(BASE_COLORS[variant]))
	body.mesh = body_mesh
	body.position.y = wall_height * 0.5
	root.add_child(body)

	_add_roof(root, side, wall_height)
	_add_openings(root, variant, side, wall_height)

	root.set_meta("wall_height", wall_height)
	return root

static func _add_roof(root: Node3D, side: float, wall_height: float) -> void:
	var material := _flat_material(ROOF_COLORS[randi() % ROOF_COLORS.size()])
	var roof := MeshInstance3D.new()
	if randf() < GABLE_CHANCE:
		# Techo a dos aguas: prisma con alero, cumbrera en orientacion sorteada.
		var prism := PrismMesh.new()
		var roof_height := side * randf_range(0.25, 0.45)
		prism.size = Vector3(side + 0.12, roof_height, side + 0.12)
		prism.material = material
		roof.mesh = prism
		roof.position.y = wall_height + roof_height * 0.5
		if randf() < 0.5:
			roof.rotation_degrees.y = 90.0
	else:
		# Losa plana con borde saliente.
		var slab := BoxMesh.new()
		var thickness := randf_range(0.1, 0.18)
		slab.size = Vector3(side + 0.15, thickness, side + 0.15)
		slab.material = material
		roof.mesh = slab
		roof.position.y = wall_height + thickness * 0.5
	root.add_child(roof)

## Ventanas en las 4 fachadas (una fila por piso, columnas segun el ancho,
## algunas salteadas al azar) y puerta en la planta baja de una fachada.
static func _add_openings(root: Node3D, floors: int, side: float, wall_height: float) -> void:
	var floor_height := wall_height / floors
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.16, 0.24, 0.05)
	window_mesh.material = _flat_material(WINDOW_COLOR)
	var cols := maxi(1, roundi(side / 0.7))
	var door_face := randi() % 4

	for face in 4:
		var rot := Basis(Vector3.UP, face * PI * 0.5)
		for floor_i in floors:
			var y := floor_height * (floor_i + 0.5) + 0.06
			for i in cols:
				# El hueco central de la planta baja lo ocupa la puerta.
				if face == door_face and floor_i == 0 and i == cols / 2:
					continue
				if randf() < WINDOW_SKIP_CHANCE:
					continue
				var x := (float(i) + 0.5) / cols * side - side * 0.5
				var window := MeshInstance3D.new()
				window.mesh = window_mesh
				window.basis = rot
				window.position = rot * Vector3(x, y, side * 0.5)
				root.add_child(window)

	var door_mesh := BoxMesh.new()
	var door_height := minf(0.5, floor_height * 0.75)
	door_mesh.size = Vector3(0.24, door_height, 0.05)
	door_mesh.material = _flat_material(DOOR_COLOR)
	var door := MeshInstance3D.new()
	door.mesh = door_mesh
	var door_rot := Basis(Vector3.UP, door_face * PI * 0.5)
	door.basis = door_rot
	door.position = door_rot * Vector3(0.0, door_height * 0.5, side * 0.5)
	root.add_child(door)

static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material

## Variacion sutil de tono/saturacion/valor para que dos casas del mismo
## tamano no compartan exactamente el mismo color.
static func _jitter(color: Color) -> Color:
	var h := wrapf(color.h + randf_range(-0.02, 0.02), 0.0, 1.0)
	var s := clampf(color.s * randf_range(0.85, 1.1), 0.0, 1.0)
	var v := clampf(color.v * randf_range(0.85, 1.12), 0.0, 1.0)
	return Color.from_hsv(h, s, v)
