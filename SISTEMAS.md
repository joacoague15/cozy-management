# Sistemas de basura, naturaleza y construcciones históricas

Documentación de los tres sistemas de juego que complementan a las casas y turistas (ver `TURISTAS.md`).

## Basura

- El mapa arranca limpio. Cada **conjunto de `dirt_cluster_size` o más casas conectadas** (por defecto **4**; dos casas están conectadas si alguna de sus celdas comparte un **lado ortogonal**, las diagonales no cuentan) genera un **área de basura que cubre las tiles de esas casas** (zona oscura dibujada en el shader `shaders/grid.gdshader` con una textura-máscara de 1 pixel por tile).
- El **tile de limpieza** (tecla **4**, 1x1, celeste) purifica un área de `clean_size` x `clean_size` tiles **centrada en él** (por defecto **3x3**, configurable en el menú F1).
- La máscara se **recalcula desde cero** (clusters de casas menos áreas de limpiadores) cada vez que cambian los edificios o cambian `dirt_cluster_size` / `clean_size` en vivo: borrar un limpiador hace volver la basura, y achicar un cluster por debajo del umbral la elimina.
- La basura es visual: no afecta a los turistas (por ahora).

## Naturaleza

- Cada **`nature_ratio` tiles de casa** (celdas ocupadas por casas, por defecto **5**) se **exige colocar 1 tile de naturaleza** (tecla **5**).
- La naturaleza mide `nature_size` x `nature_size` (por defecto **2x2**, configurable) y es un parque plano **sin colisión**: los turistas la atraviesan.
- Las casas **siempre se pueden colocar**. Si hay déficit (`naturalezas colocadas < floor(tiles de casa / ratio)`), lo que se frena es la **generación de turistas**: ninguna casa genera hasta compensar. El HUD lo avisa con `[SIN TURISTAS NUEVOS: falta naturaleza]`.
- El requisito cuenta **unidades de naturaleza colocadas**, no sus tiles.

## Construcciones históricas

Tres grandes construcciones únicas de `historic_size` x `historic_size` (por defecto **5x5**, configurable) que se desbloquean con **turistas totales acumulados** (`total_spawned` del `TouristManager`, nunca baja aunque los turistas se vayan):

| Tecla | Nombre | Se desbloquea con (acumulado) | Default |
|---|---|---|---|
| 6 | Monumento | `historic_tourists_1` | 25 |
| 7 | Catedral | `historic_tourists_1 + historic_tourists_2` | 25 + 50 = 75 |
| 8 | Palacio | suma de las tres | 25 + 50 + 75 = 150 |

- Cada histórica se puede construir **una sola vez** (si se borra, se puede volver a construir).
- El HUD muestra el estado de cada una: turistas requeridos, "lista!" o "construida".

## Parámetros (menú F1)

El panel F1 (compartido con los turistas) edita en vivo el autoload `GameConfig`:

| Parámetro | Propiedad | Default |
|---|---|---|
| Basura: casas conectadas por foco | `dirt_cluster_size` | 4 |
| Limpieza: área purificada (NxN) | `clean_size` | 3 |
| Naturaleza: tiles de casa por naturaleza | `nature_ratio` | 5 |
| Naturaleza: tamaño del tile (NxN) | `nature_size` | 2 |
| Históricas: tamaño (NxN) | `historic_size` | 5 |
| Históricas: turistas 1ra / +2da / +3ra | `historic_tourists_1/2/3` | 25 / 50 / 75 |

Los tamaños se leen **en vivo**: cambiar `nature_size` o `historic_size` afecta al fantasma y a las próximas colocaciones (las ya construidas no cambian).

## Archivos involucrados

| Archivo | Rol |
|---|---|
| `scripts/game_config.gd` | Autoload `GameConfig` con todos los parámetros |
| `scripts/dirt_manager.gd` | Máscara de basura: clusters de casas menos áreas de limpieza (Image → ImageTexture → shader) |
| `shaders/grid.gdshader` | Dibuja la zona oscura sobre los tiles con basura (`dirt_mask`) |
| `scripts/build_manager.gd` | Tipos de edificio (`house`/`cleaner`/`nature`/`historic`), `house_clusters()`, desbloqueos históricos, HUD |
| `scripts/tourist_manager.gd` | Contador `total_spawned` para los desbloqueos, pausa por déficit de naturaleza |
| `scripts/tourist_menu.gd` | Secciones nuevas del panel F1 |
