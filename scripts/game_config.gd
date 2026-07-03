extends Node
## Autoload (GameConfig): parametros globales de los sistemas de juego
## (suciedad, naturaleza y construcciones historicas).
## El menu F1 modifica estos valores en vivo.

## Cantidad minima de casas conectadas (compartiendo al menos un lado)
## para que el conjunto genere basura sobre sus tiles.
var dirt_cluster_size := 4

## Lado del area (NxN) que purifica cada tile de limpieza, centrada en el.
var clean_size := 3

## Cada cuantos tiles de casa se exige colocar una naturaleza.
var nature_ratio := 5

## Lado del tile de naturaleza (NxN).
var nature_size := 2

## Lado de las construcciones historicas (NxN).
var historic_size := 5

## Turistas totales necesarios para desbloquear la primera historica.
var historic_tourists_1 := 25

## Turistas adicionales (despues de la primera) para la segunda.
var historic_tourists_2 := 50

## Turistas adicionales (despues de la segunda) para la tercera.
var historic_tourists_3 := 75
