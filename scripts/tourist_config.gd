extends Node
## Autoload (TouristConfig): parametros globales de los turistas.
## Ver TURISTAS.md.

## Velocidad de caminata (m/s). Se sortea una vez por turista al aparecer.
var speed_min := 1.0
var speed_max := 2.5

## Duracion de la pausa quieto (segundos). Se sortea en cada pausa.
var idle_min := 1.0
var idle_max := 4.0

## Tiempo caminando entre pausa y pausa (segundos). Se sortea en cada tramo.
var walk_min := 2.0
var walk_max := 6.0

## Estadia total del turista antes de irse (segundos). Se sortea al aparecer.
var stay_min := 20.0
var stay_max := 40.0

## Segundos que tarda cada casa en generar 1 turista.
var spawn_interval := 1.0
