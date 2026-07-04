extends Node3D
## Cursor de mouse cozy: reemplaza la flecha del sistema por icons/cursor.svg
## (flecha redondeada crema con contorno marron, a tono con la UI). El hotspot
## apunta a la punta de la flecha dibujada en el SVG.

func _ready() -> void:
	var texture: Texture2D = load("res://icons/cursor.svg")
	if texture != null:
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(9, 6))
