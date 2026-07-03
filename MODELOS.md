# Editor in-game de modelos 3D

Permite cargar archivos **FBX / GLB / GLTF** con el juego corriendo y probarlos sobre el terreno: colocarlos, moverlos, rotarlos y escalarlos. Todo vive en `scripts/model_editor.gd` (nodo `ModelEditor` de `main.tscn`).

## Cómo cargar un modelo

Dos maneras, con el juego corriendo:

1. **Arrastrar el archivo** desde el Explorador de Windows a la ventana del juego: el modelo aparece directamente donde se soltó, ya seleccionado.
2. **F2**: abre el diálogo de archivos (nativo de Windows). Al elegir el archivo, el modelo queda pegado al cursor (modo colocación, translúcido); click izquierdo lo coloca, click derecho cancela.

La carga usa `FBXDocument` / `GLTFDocument` en **runtime** (sin editor de Godot), así que también funciona en builds exportadas.

## Edición

Click izquierdo sobre un modelo colocado lo selecciona (se resalta con una caja amarilla y aparece el panel arriba a la derecha):

| Acción | Control |
|---|---|
| Mover | Mantener click izquierdo y arrastrar |
| Escalar | **Ctrl + rueda** del mouse, o SpinBox "Tamano (tiles)" del panel |
| Rotar | **Q / E** (pasos de 15°), o SpinBox "Rotacion" del panel |
| Borrar | **Supr** o el botón del panel |
| Deseleccionar | Click derecho o click en el piso |

La escala se maneja en **tiles de footprint**: el valor es cuánto mide el lado mayor del modelo en tiles del mapa.

## Normalización al cargar

Los FBX vienen de cualquier manera (unidades en cm, pivotes arbitrarios, escenas con basura), así que al cargar se normaliza:

- **Autoescala** a un footprint de 2 tiles (el árbol de ejemplo mide 28 unidades en crudo).
- **Pivote en la base**: el modelo queda apoyado en y=0, centrado en su AABB.
- **Se eliminan cámaras, luces y AnimationPlayers** que vengan dentro del archivo (pisarían la cámara e iluminación del juego).
- **Colores de vértice**: si la malla los trae, se activa `vertex_color_use_as_albedo` (los modelos low-poly suelen pintarse así y sin esto llegan blancos).

## Limitaciones conocidas

- **Texturas externas**: un FBX que referencia texturas por ruta solo las encuentra si están junto al archivo; las embebidas funcionan mejor. Es normal que algunos modelos lleguen con material gris/blanco.
- **Sin colisión**: los modelos son decorativos; los turistas los atraviesan y no ocupan celdas de la grilla de construcción.
- **Sin persistencia**: los modelos cargados viven solo durante la sesión.
- Las animaciones no se reproducen (el AnimationPlayer se descarta al importar).

## Convivencia con el resto del input

- `ModelEditor` va **después** de `BuildManager` en la escena: recibe el input primero y consume los clicks solo cuando está colocando o seleccionando modelos.
- Si hay un **edificio seleccionado** (teclas 1-8), los clicks son del `BuildManager` y el editor de modelos no roba la selección.
- Ctrl+rueda escala el modelo; la rueda sola sigue siendo el zoom de cámara.
