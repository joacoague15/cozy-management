# Sistemas de basura, naturaleza, zonas y construcciones históricas

Documentación de los sistemas de juego que complementan a las casas y turistas (ver `TURISTAS.md`).

## Basura

- El mapa arranca limpio. Cada **ventana de 3x3 que contenga al menos `dirt_house_threshold` casas distintas** (por defecto **4**) ensucia **sus 9 tiles completas** (dibujada en el shader `shaders/grid.gdshader` con una textura-máscara de 1 pixel por tile). La zona sucia no es un cuadrado plano: lleva **manchas orgánicas de ruido, un vaho que deriva lento y una mancha por tile que palpita**, para que se lea claramente como mugre. Solo se evalúan ventanas **completamente adentro de la zona desbloqueada**: la basura nunca aparece fuera de ella.
- El **tile de limpieza** (tecla **4**, 1x1, celeste) purifica un área de `clean_size` x `clean_size` tiles **centrada en él** (por defecto **5x5**, configurable en el menú F1). Al seleccionarlo, un quad celeste translúcido con pulso suave previsualiza las tiles que va a purificar (la naturaleza tiene el mismo feedback en verde con las tiles que va a cubrir). Cuando hay suciedad, el botón de limpieza de la barra **titila cada tanto** (doble pulso de escala con destello) para invitar a clickearlo.
- La máscara se **recalcula desde cero** (ventanas sucias menos áreas de limpiadores) cada vez que cambian los edificios o cambian `dirt_house_threshold` / `clean_size` en vivo: borrar un limpiador hace volver la basura.
- La máscara **transiciona en vez de cambiar de golpe**: la suciedad aparece rápido y se retira despacio (~1.2 seg), con la mancha encogiéndose por su borde ondulado. Al colocar un limpiador que purifica tiles hay además un **efecto resolutivo**: un destello celeste plano sobre las tiles limpiadas, chispas que suben flotando y un sonido de barrido con un brillo final. El estado lógico (casas que vuelven a generar) cambia al instante; la transición es solo visual.
- **Una casa con alguna tile sucia deja de generar turistas** hasta que un limpiador purifique la zona. Las casas desactivadas (por suciedad o déficit de naturaleza) se ven **grises/apagadas** (película translúcida animada) y recuperan su color al reactivarse.

## Naturaleza

- Cada **`nature_per_houses` casas colocadas** (por defecto **4**) se exigen **`nature_amount` tiles de naturaleza** (por defecto **2**, tecla **5**).
- La naturaleza mide `nature_size` x `nature_size` (por defecto **1x1**, configurable) y es un parque plano **sin colisión**: los turistas la atraviesan.
- Las casas **siempre se pueden colocar**. Si hay déficit (`naturalezas colocadas < floor(casas / nature_per_houses) * nature_amount`), **ninguna casa genera turistas** hasta compensar. El HUD lo avisa con `[SIN TURISTAS NUEVOS: falta naturaleza]` y el **relleno del botón de naturaleza** (barra de construcción) se vacía suavemente y pulsa en rojo; el botón de limpieza hace lo mismo con la suciedad. Además, con déficit el botón de naturaleza **titila cada tanto** (igual que el de limpieza con basura), y al seleccionar naturaleza un quad verde translúcido previsualiza las tiles que va a cubrir.

## Generación de turistas

- Cada casa **desbloqueada** (sin tiles sucias y sin déficit global de naturaleza) genera **1 turista cada `spawn_interval` segundos** (por defecto **1/s**), con un **"+1" flotante sobre la casa** como feedback.
- `total_spawned` acumula todos los turistas generados (nunca baja) y maneja los desbloqueos.

## Zonas construibles

El mapa de 20x20 arranca con solo el **3x3 central** habilitado. El terreno es una tile (caja) por celda vía MultiMesh (`scripts/terrain_tiles.gd`): las celdas bloqueadas **no se ven** hasta desbloquearse.

| Zona | Lado | Se desbloquea con |
|---|---|---|
| 1 | 3x3 | inicio |
| 2 | 9x9 | **construir** el cartel (disponible con `historic_tourists_1` = 25 turistas) |
| 3 | 20x20 | **construir** la catedral (disponible con 25 + 50 = 75 turistas) |

Al desbloquear, las tiles nuevas **emergen desde abajo del terreno**, en ondas anillo por anillo desde el borde de la zona anterior, con un leve rebote al asentarse.

## Construcciones históricas

Tres construcciones únicas que se desbloquean con **turistas totales acumulados**. El cartel ocupa **1x1**, la catedral **3x3** y el palacio `historic_size` x `historic_size` (por defecto **5x5**, configurable):

| Tecla | Nombre | Tamaño | Se desbloquea con (acumulado) | Default |
|---|---|---|---|---|
| 6 | Cartel "Parque de el Retiro coming soon..." (`CartelT1.fbx`) | 1x1 | `historic_tourists_1` — **construirlo abre la zona 9x9** | 25 |
| 7 | Catedral | 3x3 | `historic_tourists_1 + historic_tourists_2` — **construirla abre la zona 20x20** | 25 + 50 = 75 |
| 8 | Palacio (`Parcela_Alfonso_XIII_Combined.fbx`: arco, estatua, leones y estanque en un solo modelo; sobre el agua se sortean 1-2 barcas y 2-3 nenúfares) | 5x5 | suma de las tres | 25 + 50 + 75 = 150 |

- Cada histórica se puede construir **una sola vez** (si se borra, se puede volver a construir).
- El cartel usa `models/CartelT1.fbx` con un **texto flotante** ("Parque de el Retiro coming soon...") sobre el modelo. El palacio usa la parcela completa (`Parcela_Alfonso_XIII_Combined.fbx`); los FBX sueltos del arco, la estatua, los leones y las totoras ya no se cargan.
- El HUD muestra el estado de cada una: turistas requeridos, "lista!" o "construida".
- El **botón de monumento** de la barra de construcción representa siempre la próxima histórica sin construir: mientras faltan turistas está **deshabilitado** y se llena de dorado según el progreso; al desbloquearse hace un "pop" y su borde pulsa dorado hasta construirla.

## Parámetros (menú F1)

El panel F1 (compartido con los turistas) edita en vivo el autoload `GameConfig`:

| Parámetro | Propiedad | Default |
|---|---|---|
| Basura: casas en un 3x3 para ensuciarlo | `dirt_house_threshold` | 4 |
| Limpieza: área purificada (NxN) | `clean_size` | 5 |
| Naturaleza: cada cuántas casas se exige | `nature_per_houses` | 4 |
| Naturaleza: naturalezas por grupo | `nature_amount` | 2 |
| Naturaleza: tamaño del tile (NxN) | `nature_size` | 1 |
| Palacio: tamaño (NxN) | `historic_size` | 5 |
| Históricas: turistas 1ra / +2da / +3ra | `historic_tourists_1/2/3` | 25 / 50 / 75 |

Los tamaños se leen **en vivo**: cambiar `nature_size` o `historic_size` afecta al fantasma y a las próximas colocaciones (las ya construidas no cambian).

## Archivos involucrados

| Archivo | Rol |
|---|---|
| `scripts/game_config.gd` | Autoload `GameConfig` con todos los parámetros |
| `scripts/dirt_manager.gd` | Máscara de basura: ventanas 3x3 con ≥N casas menos áreas de limpieza (Image → ImageTexture → shader), transición animada de la máscara y efecto resolutivo (destello + chispas + sonido) al limpiar |
| `shaders/grid.gdshader` | Grilla y basura (`dirt_mask`) en la cara superior de las tiles; costados color tierra |
| `scripts/terrain_tiles.gd` | Terreno por tiles (MultiMesh): esconde las celdas bloqueadas y anima la emergida al desbloquear |
| `scripts/build_manager.gd` | Tipos de edificio (`house`/`cleaner`/`nature`/`historic`), zonas desbloqueables, desbloqueos históricos, modelos FBX, HUD |
| `scripts/house_generator.gd` | Geometría procedural de las casas (altura, techo, ventanas, puerta). El 60% de las casas la usa; el resto sale como prop FBX (15% puesto, 10% columna, 7.5% banco T1, 7.5% banco T2) con la misma mecánica |
| `scripts/loading_screen.gd` | Pantalla de carga: tapa todo mientras los FBX cargan en hilos de fondo; al terminar arranca la partida directamente (sin menú: las tiles emergen animadas mientras se desvanece) |
| `scripts/tourist_manager.gd` | Spawn por casa (1/s), gates de suciedad/naturaleza, "+1" flotante, `total_spawned` |
| `scripts/status_ui.gd` | Cartel de fin de demo al construir el palacio |
| `scripts/build_toolbar.gd` | Barra de botones: rellenos de limpieza/naturaleza, botón de monumento con progreso y titileo tutorial (casa hasta la primera colocada; limpieza/naturaleza cuando hacen falta) |
| `scripts/sfx.gd` | Autoload `Sfx`: sonidos sintetizados en runtime (seleccionar, construir, borrar, monumento listo, barrido de limpieza) y música de fondo en loop |
| `scripts/question_button.gd` | Ayuda de controles abajo a la derecha: el "?" aparece al arrancar la partida y se transforma en "Click izquierdo para construir / Click derecho para eliminar" |
| `scripts/tourist_menu.gd` | Secciones del panel F1 |
