extends Node3D
## Cursor de mouse cozy: reemplaza la flecha del sistema por icons/cursor.svg
## (flecha redondeada crema con contorno marron, a tono con la UI). El hotspot
## apunta a la punta de la flecha dibujada en el SVG.
##
## Ademas, en builds web devuelve el foco del teclado al canvas en cada click:
## itch.io embebe el juego en un iframe y su overlay suele quedarse con el
## foco, con lo que el mouse funciona pero WASD no llega al juego.

func _ready() -> void:
	var texture: Texture2D = load("res://icons/cursor.svg")
	if texture != null:
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(9, 6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and OS.has_feature("web"):
		JavaScriptBridge.eval(
			"var c = document.getElementById('canvas') || document.querySelector('canvas');"
			+ " if (c && document.activeElement !== c) c.focus();",
			true
		)
