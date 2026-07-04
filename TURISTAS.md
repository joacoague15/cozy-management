# Sistema de turistas

Documentación del sistema de turistas: generación, comportamiento y parámetros.

## Generación (spawn)

- Cada **casa colocada genera turistas** de forma continua (solo las casas: limpieza, naturaleza e históricas no generan, ver `SISTEMAS.md`).
- Si hay **déficit de naturaleza** (ver `SISTEMAS.md`), la generación se **pausa por completo** hasta compensar.
- El manager acumula `total_spawned` (turistas generados desde el inicio, nunca baja): lo usa el sistema de **construcciones históricas** para sus desbloqueos.
- Cada casa: **1 turista cada `spawn_interval` segundos** (por defecto **1 seg**), con un **"+1" flotante sobre la casa** como feedback.
- Una casa con alguna **tile sucia** no genera hasta que un limpiador purifique la zona (ver `SISTEMAS.md`). Las casas que no generan (suciedad o déficit de naturaleza) se ven **grises/apagadas**.
- El turista aparece **sobre el borde interno de la zona desbloqueada** (nunca fuera del terreno existente) y camina hacia un punto interior al azar (estado `ENTERING`) antes de arrancar su ciclo normal de caminar/pausar.
- Al borrar una casa, deja de generar (los turistas ya generados siguen su vida normal).

## Comportamiento del turista

Cada turista es un `CharacterBody3D` (cápsula de color aleatorio) con una máquina de estados:

1. **Entrando** (`ENTERING`): aparece en el borde de la zona desbloqueada y camina derecho hacia un punto interior al azar; al estar adentro pasa a caminar. Si una casa del borde lo frena, apunta a otro punto interior.
2. **Caminando** (`WALKING`): elige una dirección al azar y camina en línea recta durante un tiempo sorteado entre `walk_min` y `walk_max` segundos.
3. **Quieto** (`IDLE`): se frena durante un tiempo sorteado entre `idle_min` e `idle_max` segundos, y vuelve a caminar.
4. **Yéndose** (`LEAVING`): cuando se agota su estadía (sorteada entre `stay_min` y `stay_max` al aparecer), se encoge durante 0.6 seg y desaparece. Esto mantiene la población en equilibrio.

Reglas de movimiento:

- **No atraviesan casas**: las casas tienen `StaticBody3D` (capa de colisión 2) y los turistas colisionan contra esa capa con `move_and_slide()`. Si una casa los frena casi por completo, eligen otra dirección al azar.
- **No se salen del terreno existente**: al tocar el borde de la zona desbloqueada rebotan hacia adentro (los límites se agrandan solos cuando la zona se amplía).
- Los turistas **no chocan entre sí** (pueden superponerse), solo contra casas.
- La **velocidad** de cada turista se sortea entre `speed_min` y `speed_max` una única vez al aparecer.
- Caben por los senderos: el pasillo entre dos casas vecinas mide 0.4 unidades y la cápsula tiene 0.22 de diámetro.

## Parámetros (menú F1)

Presionando **F1** en el juego se abre/cierra el panel de parámetros, que edita en vivo el autoload `TouristConfig`:

| Parámetro | Propiedad | Default | Cuándo se aplica |
|---|---|---|---|
| Velocidad (m/s) | `speed_min` / `speed_max` | 1.0 – 2.5 | Al aparecer cada turista |
| Pausa quieto (s) | `idle_min` / `idle_max` | 1.0 – 4.0 | En cada pausa (afecta a todos) |
| Caminata entre pausas (s) | `walk_min` / `walk_max` | 2.0 – 6.0 | En cada tramo de caminata |
| Estadía en el mapa (s) | `stay_min` / `stay_max` | 20 – 40 | Al aparecer cada turista |
| Spawn: segundos por turista | `spawn_interval` | 1.0 | Continuo (afecta a todas las casas) |

Si un mínimo queda mayor que su máximo, `randf_range` igual funciona (invierte el rango), no rompe nada.

El panel también muestra el **conteo de turistas en el mapa** en tiempo real.

## Archivos involucrados

| Archivo | Rol |
|---|---|
| `scripts/tourist_config.gd` | Autoload `TouristConfig` con todos los parámetros |
| `scripts/tourist.gd` | Comportamiento individual del turista (estados, colisión, bordes) |
| `scripts/tourist_manager.gd` | Spawner: itera las casas, aplica los gates de suciedad/naturaleza, crea turistas y el "+1" |
| `scripts/tourist_menu.gd` | Panel F1 (UI construida por código) |
| `scripts/build_manager.gd` | Casas con `StaticBody3D` (capa 2), señal `buildings_changed`, helpers `get_buildings()` y `building_at()` |

## Capas de colisión

| Capa | Uso |
|---|---|
| 2 | Casas (`StaticBody3D`) |
| 4 (bit 3) | Turistas (`CharacterBody3D`, mask = 2: solo chocan contra casas) |
